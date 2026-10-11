//! 专辑相关
//!
//! 对应 `KuGou.dart` 的 `getAlbumDetails` / `getAlbumMusic`。

use crate::models::Album;
use crate::request::{now_millis, RequestOptions, Transport};
use crate::sign::sign_params_key;
use crate::Result;
use serde_json::{json, Value};

/// 专辑信息（支持批量）
///
/// 对应 Dart 的 `getAlbumDetails(albumId)`。
///
/// ⚠️ 本接口的 `clienttime` 是 **毫秒**（其他接口多为秒），且 `key` 用毫秒时间戳计算。
///
/// `fields` 传空串时返回默认字段集；需要 `authors` 数组时必须显式指定。
/// 构造「专辑信息」请求
pub(crate) fn build_album(t: &Transport, album_ids: &[String], fields: &str) -> RequestOptions {
    let date_time = now_millis();

    let data: Vec<Value> = album_ids
        .iter()
        .map(|id| json!({ "album_id": id, "album_name": "", "author_name": "" }))
        .collect();

    let mut body = json!({
        "appid": t.platform.appid(),
        // ⚠️ 毫秒
        "clienttime": date_time,
        "clientver": t.platform.clientver(),
        "data": data,
        "dfid": t.dfid(),
        "fields": fields,
        "key": sign_params_key(t.platform, &date_time.to_string(), None, None),
        "mid": t.device.mid
    });

    if !t.account.token.is_empty() {
        body["token"] = json!(t.account.token);
    }
    if !t.account.userid.is_empty() && t.account.userid != "0" {
        body["userid"] = json!(t.account.userid);
    }

    RequestOptions::post("/v1/album")
        .base_url("http://kmr.service.kugou.com")
        .router("kmr.service.kugou.com")
        .header("Content-Type", "application/json")
        .json_body(&body)
}

pub async fn album(t: &Transport, album_ids: &[String], fields: &str) -> Result<Vec<Album>> {
    if album_ids.is_empty() {
        return Ok(Vec::new());
    }

    let resp = t.send(build_album(t, album_ids, fields)).await?;

    Ok(resp
        .data()
        .as_array()
        .map(|arr| {
            arr.iter()
                .map(|i| Album {
                    album: str_of(i, "album_name"),
                    album_id: str_of(i, "album_id"),
                    singer: str_of(i, "author_name"),
                    cover: crate::models::get_cover(&str_of(i, "sizable_cover"), "500"),
                    audio_count: i.get("song_count").and_then(|v| v.as_i64()).unwrap_or(0),
                })
                .collect()
        })
        .unwrap_or_default())
}

/// 专辑歌曲列表
///
/// 对应 Dart 的 `getAlbumMusic(albumId)`。
///
/// ⚠️ 参数名是 `id`（不是 `album_id`），服务端映射成 `album_id` 发给上游。
/// ⚠️ `hash` 藏在 `audio_info` 里，与 `/artist/audios` 的顶层 `hash` 不同。
///
/// 返回歌曲 hash 列表。
/// 构造「专辑歌曲列表」请求
pub(crate) fn build_album_songs(album_id: &str) -> RequestOptions {
    let body = json!({
        "album_id": album_id,
        "is_buy": "",
        "page": 1,
        "pagesize": 30
    });

    RequestOptions::post("/v1/album_audio/lite")
        .router("openapi.kugou.com")
        .header("kg-tid", "255")
        .json_body(&body)
}

pub async fn album_songs(t: &Transport, album_id: &str) -> Result<Vec<String>> {
    let resp = t.send(build_album_songs(album_id)).await?;

    Ok(resp
        .arr_at(&["data", "songs"])
        .iter()
        .filter_map(|s| {
            s.pointer("/audio_info/hash")
                .and_then(|v| v.as_str())
                .map(str::to_string)
        })
        .collect())
}

/// 专辑歌曲的完整条目（含歌名、歌手、封面）
///
/// 比 [`album_songs`] 多返回元数据，可直接构造 [`crate::Music`]，省掉一次
/// `/privilege/lite` 往返。
pub async fn album_songs_detail(t: &Transport, album_id: &str) -> Result<Vec<Value>> {
    let resp = t.send(build_album_songs(album_id)).await?;

    Ok(resp.arr_at(&["data", "songs"]))
}

fn str_of(v: &Value, k: &str) -> String {
    match v.get(k) {
        Some(Value::String(x)) => x.clone(),
        Some(Value::Number(x)) => x.to_string(),
        _ => String::new(),
    }
}
