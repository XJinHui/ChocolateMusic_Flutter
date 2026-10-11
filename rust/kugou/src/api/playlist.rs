//! 歌单相关
//!
//! 对应 `KuGou.dart` 的 `getPlaylist` / `getPlaylistMusic` / `getPlaylistDetails` /
//! `createPlaylist` / `deletePlaylist` / `addMusicToPlaylist` /
//! `deleteMusicFromPlaylist` / `getMusicInPlaylistFileid`。
//!
//! ## ⚠️ 两个 ID 不可互换
//!
//! | ID | 类型 | 用途 |
//! | --- | --- | --- |
//! | `global_collection_id` | 字符串 | **读**：`playlist_track_all`、`playlist_detail` |
//! | `listid` | 数字 | **写**：`playlist_del`、`playlist_tracks_add/del` |

use crate::crypto::{playlist_aes_decrypt, playlist_aes_encrypt, rsa_encrypt2};
use crate::models::Playlist;
use crate::request::{now_secs, RequestOptions, ResponseType, Transport};
use crate::sign::sign_params_key;
use crate::{Error, Result};
use serde_json::{json, Value};

/// 歌单内的一首歌（含删除所需的 `fileid`）
#[derive(Debug, Clone, Default)]
pub struct TrackItem {
    pub hash: String,
    /// ⚠️ 数字文件 ID，删除歌曲时必需
    pub fileid: String,
    pub name: String,
    pub singer: String,
    pub album_id: String,
    pub duration: i64,
}

/// 获取歌单全部歌曲（分页）
///
/// 对应 Dart 的 `getCollectionList` / `getPlaylistMusic` / `getMusicInPlaylistFileid`
/// 里的 `/playlist/track/all` 循环。
///
/// `id` 是 **`global_collection_id`**。
pub async fn playlist_track_all(
    t: &Transport,
    global_collection_id: &str,
    page: u32,
    pagesize: u32,
) -> Result<Vec<TrackItem>> {
    let pagesize = if pagesize == 0 { 300 } else { pagesize };
    let page = if page == 0 { 1 } else { page };

    let resp = t
        .send(
            RequestOptions::get("/pubsongs/v2/get_other_list_file_nofilt")
                .param("area_code", 1)
                // ⚠️ 用 begin_idx 而非 page
                .param("begin_idx", (page - 1) * pagesize)
                .param("plat", 1)
                .param("type", 1)
                .param("mode", 1)
                .param("personal_switch", 1)
                .param("extend_fields", "abtags,hot_cmt,popularization")
                .param("pagesize", pagesize)
                .param("global_collection_id", global_collection_id),
        )
        .await?;

    Ok(resp
        .arr_at(&["data", "songs"])
        .iter()
        .map(|s| TrackItem {
            hash: s
                .get("hash")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            fileid: match s.get("fileid") {
                Some(Value::Number(n)) => n.to_string(),
                Some(Value::String(x)) => x.clone(),
                _ => String::new(),
            },
            name: s
                .get("name")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            singer: s
                .get("singername")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            album_id: match s.get("album_id") {
                Some(Value::Number(n)) => n.to_string(),
                Some(Value::String(x)) => x.clone(),
                _ => String::new(),
            },
            duration: s
                .get("duration")
                .or_else(|| s.get("timelen"))
                .and_then(|v| v.as_i64())
                .unwrap_or(0),
        })
        .collect())
}

/// 拉取歌单**全部**歌曲（自动翻页）
///
/// ⚠️ 终止条件只能是「返回空数组」——`data.total` 字段不可靠。
pub async fn playlist_track_all_full(
    t: &Transport,
    global_collection_id: &str,
) -> Result<Vec<TrackItem>> {
    let mut out = Vec::new();
    let mut page = 1u32;
    loop {
        let batch = playlist_track_all(t, global_collection_id, page, 300).await?;
        if batch.is_empty() {
            break;
        }
        out.extend(batch);
        page += 1;
        if page > 100 {
            // 防御性上限（30000 首）
            break;
        }
    }
    Ok(out)
}

/// 在歌单里查找某首歌的 `fileid`
///
/// 对应 Dart 的 `getMusicInPlaylistFileid(listId, musicId)`。
///
/// ⚠️ 原实现是 **O(n) 全量扫描**：需要翻完整个歌单才能找到。
/// 若已知目标在靠前位置，可自行用 [`playlist_track_all`] 分页查找。
pub async fn find_fileid(
    t: &Transport,
    global_collection_id: &str,
    hash: &str,
) -> Result<Option<String>> {
    let mut page = 1u32;
    loop {
        let batch = playlist_track_all(t, global_collection_id, page, 300).await?;
        if batch.is_empty() {
            return Ok(None);
        }
        if let Some(item) = batch.iter().find(|i| i.hash == hash) {
            return Ok(Some(item.fileid.clone()));
        }
        page += 1;
        if page > 100 {
            return Ok(None);
        }
    }
}

/// 歌单详情（支持批量）
///
/// 对应 Dart 的 `getPlaylistDetails(listId)`。
///
/// `ids` 是 **`global_collection_id`**（逗号分隔）。
pub async fn playlist_detail(t: &Transport, ids: &[String]) -> Result<Vec<Playlist>> {
    if ids.is_empty() {
        return Ok(Vec::new());
    }

    let data: Vec<Value> = ids
        .iter()
        .map(|id| json!({ "global_collection_id": id }))
        .collect();

    let body = json!({
        "data": data,
        "userid": t.account.userid,
        "token": t.account.token
    });

    let resp = t
        .send(
            RequestOptions::post("/v3/get_list_info")
                .router("pubsongs.kugou.com")
                .json_body(&body),
        )
        .await?;

    Ok(resp
        .data()
        .as_array()
        .map(|arr| {
            arr.iter()
                .map(|i| Playlist {
                    name: str_of(i, "name"),
                    list_id: str_of(i, "global_collection_id"),
                    audio_count: i
                        .get("count")
                        .or_else(|| i.get("m_count"))
                        .and_then(|v| v.as_i64())
                        .unwrap_or(0),
                    cover: crate::models::get_cover(&str_of(i, "pic"), "500"),
                    numeric_id: num_of(i, "listid"),
                })
                .collect()
        })
        .unwrap_or_default())
}

/// 新建 / 收藏歌单
///
/// 对应 Dart 的 `createPlaylist(name)`。
///
/// `kind` 传 `0` 新建（默认），传 `1` 收藏他人歌单（此时需要 `create_from`）。
///
/// 返回新歌单的 `(global_collection_id, listid)`。
pub async fn playlist_add(t: &Transport, name: &str, kind: i64) -> Result<(String, String)> {
    let clienttime = now_secs();

    let mut body = json!({
        "userid": t.account.userid,
        "token": t.account.token,
        "total_ver": 0,
        "name": name,
        "type": kind,
        "source": 1,
        "is_pri": 0,
        "list_create_userid": t.account.userid,
        "list_create_listid": "",
        "list_create_gid": "",
        "from_shupinmv": 0
    });

    if kind == 0 {
        body["is_pri"] = json!(0);
    }

    let mut opt = RequestOptions::post("/cloudlist.service/v5/add_list").json_body(&body);

    if kind == 0 {
        opt = opt
            .param("last_time", clienttime)
            .param("last_area", "gztx")
            .param("userid", t.account.userid.clone())
            .param("token", t.account.token.clone());
    }

    let resp = t.send(opt).await?;

    Ok((
        resp.str_at(&["data", "info", "global_collection_id"])
            .unwrap_or_default(),
        resp.str_at(&["data", "info", "listid"]).unwrap_or_default(),
    ))
}

/// 删除 / 取消收藏歌单
///
/// 对应 Dart 的 `deletePlaylist(listId)`。
///
/// ⚠️ 传入的是**数字 `listid`**，不是 `global_collection_id`。
/// ⚠️ 这是**加密接口**：请求体 AES-128-CBC 加密，`p` 是 RSA 加密的会话串，响应也加密。
pub async fn playlist_del(t: &Transport, listid: &str) -> Result<Value> {
    let clienttime = now_secs();

    let data_map = json!({
        "listid": listid.parse::<i64>().unwrap_or(0),
        "total_ver": 0,
        "type": 1
    });

    let aes = playlist_aes_encrypt(&data_map.to_string());
    let p = rsa_encrypt2(
        json!({ "aes": aes.key, "uid": t.account.userid, "token": t.account.token })
            .to_string()
            .as_bytes(),
        t.platform.rsa_public_key(),
    )?
    .to_uppercase();

    let resp = t
        .send(
            RequestOptions::post("/v2/delete_list")
                .router("cloudlist.service.kugou.com")
                .param("clienttime", clienttime)
                .param(
                    "key",
                    sign_params_key(t.platform, &clienttime.to_string(), None, None),
                )
                .param("last_area", "gztx")
                .param("last_time", clienttime)
                .param("p", p)
                .body_bytes(aes.str.clone().into_bytes())
                .response_type(ResponseType::Bytes),
        )
        .await?;

    decrypt_playlist_response(&resp.raw, &aes.key)
}

/// 歌单添加歌曲
///
/// 对应 Dart 的 `addMusicToPlaylist(listId, musicId)`。
///
/// `data` 的格式是竖线分隔、逗号分组的字符串：
///
/// ```text
/// name|hash|album_id|mixsongid,name2|hash2|album_id2|mixsongid2
/// ```
///
/// ⚠️ **歌名里不能含逗号**（服务端先按 `,` 分割）。
/// ⚠️ 只传 3 段时 `mixsongid` 为 0，部分歌曲可能添加失败。
///
/// 便捷入口见 [`add_music_by_hash`]。
pub async fn playlist_tracks_add(t: &Transport, listid: &str, data: &str) -> Result<()> {
    let clienttime = now_secs();

    let resource: Vec<Value> = data
        .split(',')
        .filter(|s| !s.is_empty())
        .map(|s| {
            let d: Vec<&str> = s.split('|').collect();
            json!({
                "number": 1,
                "name": d.first().copied().unwrap_or(""),
                "hash": d.get(1).copied().unwrap_or(""),
                "size": 0,
                "sort": 0,
                "timelen": 0,
                "bitrate": 0,
                "album_id": d.get(2).and_then(|x| x.parse::<i64>().ok()).unwrap_or(0),
                "mixsongid": d.get(3).and_then(|x| x.parse::<i64>().ok()).unwrap_or(0)
            })
        })
        .collect();

    let body = json!({
        "userid": t.account.userid,
        "token": t.account.token,
        "listid": listid,
        "list_ver": 0,
        "type": 0,
        "slow_upload": 1,
        "scene": "false;null",
        "data": resource
    });

    t.send(
        RequestOptions::post("/cloudlist.service/v6/add_song")
            .param("last_time", clienttime)
            .param("last_area", "gztx")
            .param("userid", t.account.userid.clone())
            .param("token", t.account.token.clone())
            .json_body(&body),
    )
    .await?;
    Ok(())
}

/// 便捷：按歌曲信息添加（自动拼 `data` 字符串）
///
/// 比 Dart 客户端的 3 段格式多传 `mixsongid`，避免部分歌曲添加失败。
pub async fn add_music_by_hash(
    t: &Transport,
    listid: &str,
    name: &str,
    hash: &str,
    album_id: &str,
    mixsongid: &str,
) -> Result<()> {
    let data = format!("{name}|{hash}|{album_id}|{mixsongid}");
    playlist_tracks_add(t, listid, &data).await
}

/// 歌单删除歌曲
///
/// 对应 Dart 的 `deleteMusicFromPlaylist(listId, musicId)` 的第二步。
///
/// ⚠️ 需要 **`fileid`**（数字），不是 `hash`。用 [`find_fileid`] 获取。
pub async fn playlist_tracks_del(t: &Transport, listid: &str, fileids: &str) -> Result<()> {
    let resource: Vec<Value> = fileids
        .split(',')
        .filter(|s| !s.is_empty())
        .map(|s| json!({ "fileid": s.parse::<i64>().unwrap_or(0) }))
        .collect();

    let body = json!({
        "listid": listid,
        "userid": t.account.userid,
        "data": resource,
        "type": 0,
        "token": t.account.token,
        "list_ver": 0
    });

    t.send(
        RequestOptions::post("/v4/delete_songs")
            .router("cloudlist.service.kugou.com")
            .json_body(&body),
    )
    .await?;
    Ok(())
}

// ============================================================
//  内部工具
// ============================================================

/// 解密云歌单加密接口的响应
fn decrypt_playlist_response(raw: &[u8], key: &str) -> Result<Value> {
    use base64::Engine;
    let b64 = base64::engine::general_purpose::STANDARD.encode(raw);
    let plain = playlist_aes_decrypt(&b64, key);
    serde_json::from_str(&plain)
        .map_err(|e| Error::Invalid(format!("云歌单响应解密失败: {e}; 原文: {plain}")))
}

fn str_of(v: &Value, k: &str) -> String {
    match v.get(k) {
        Some(Value::String(x)) => x.clone(),
        Some(Value::Number(x)) => x.to_string(),
        _ => String::new(),
    }
}

fn num_of(v: &Value, k: &str) -> String {
    str_of(v, k)
}
