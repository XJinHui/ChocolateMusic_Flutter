//! 歌单族（6 条路由）
//!
//! | 路由 | 上游 | 加密 |
//! | --- | --- | --- |
//! | `/user/playlist` | `/api/user/playlist` | weapi |
//! | `/playlist/detail` | `/api/v6/playlist/detail` | eapi |
//! | `/playlist/track/all` | `/api/v6/playlist/detail` → `/api/v3/song/detail` | eapi ×2 |
//! | `/playlist/create` | `/api/playlist/create` | weapi |
//! | `/playlist/delete` | `/api/playlist/remove` | weapi |
//! | `/playlist/tracks` | `/api/playlist/manipulate/tracks` | eapi |

use serde_json::{json, Value};

use crate::api::song::js_string;
use crate::api::{song_detail_c, ServerRequest, ServerResponse};
use crate::{Error, Result};

// ============================================================
//  /user/playlist
// ============================================================

/// 用户歌单
///
/// ⚠️ `includeVideo` 恒为 `true`。
/// ⚠️ 客户端传 `limit=300`，读 `playlist[].name / id / trackCount / coverImgUrl`。
pub async fn user_playlist(
    t: &ServerRequest<'_>,
    uid: &str,
    limit: u32,
    offset: u32,
) -> Result<ServerResponse> {
    let r = t
        .send_weapi(
            "/api/user/playlist",
            json!({
                "uid": uid,
                "limit": if limit == 0 { 30 } else { limit },
                "offset": offset,
                "includeVideo": true,
            }),
        )
        .await?;

    Ok(ServerResponse::passthrough(r))
}

// ============================================================
//  /playlist/detail
// ============================================================

/// 歌单详情
pub async fn playlist_detail(t: &ServerRequest<'_>, id: &str, s: u32) -> Result<ServerResponse> {
    let r = t
        .send_eapi(
            "/api/v6/playlist/detail",
            json!({ "id": id, "n": 100_000, "s": if s == 0 { 8 } else { s } }),
        )
        .await?;

    Ok(ServerResponse::passthrough(r))
}

// ============================================================
//  /playlist/track/all（两条请求串联）
// ============================================================

/// 歌单全部歌曲
///
/// ```text
/// 第 1 步: POST /api/v6/playlist/detail   eapi   { id, n: 100000, s: 8 }
/// 第 2 步: POST /api/v3/song/detail       eapi   { c: '[{"id":..},..]' }
/// 响应:   第 2 步的响应（第 1 步的 cookie 被丢弃）
/// ```
///
/// ⚠️ 客户端**不传 `limit` / `offset`** → 默认取前 1000 首。
/// ⚠️ 第 2 步虽然也是 `v3/song/detail`，但 crypto 是 **eapi**（不是 `/song/detail` 路由的 weapi）。
/// ⚠️ 客户端读 `response.data['songs']` —— 第 2 步的响应正好有 `songs` 字段。
pub async fn playlist_track_all(
    t: &ServerRequest<'_>,
    id: &str,
    limit: usize,
    offset: usize,
) -> Result<ServerResponse> {
    let limit = if limit == 0 { 1000 } else { limit };

    // 第 1 步：拿 trackIds
    let first = t
        .send_eapi(
            "/api/v6/playlist/detail",
            json!({ "id": id, "n": 100_000, "s": 8 }),
        )
        .await?;

    let track_ids = extract_track_ids(&first.body);

    let slice: Vec<String> = track_ids
        .into_iter()
        .skip(offset)
        .take(limit)
        .collect();

    // 第 2 步：取歌曲详情
    let r = t
        .send_eapi(
            "/api/v3/song/detail",
            json!({ "c": song_detail_c(&slice) }),
        )
        .await?;

    Ok(ServerResponse::passthrough(r))
}

/// 从 `playlist/trackIds` 里取出 ID 列表（转成字符串）
fn extract_track_ids(body: &Value) -> Vec<String> {
    body.pointer("/playlist/trackIds")
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|item| item.get("id").map(js_string))
                .collect()
        })
        .unwrap_or_default()
}

// ============================================================
//  /playlist/create
// ============================================================

/// 新建歌单
///
/// 客户端读 `response.data['id']`。
pub async fn playlist_create(
    t: &ServerRequest<'_>,
    name: &str,
    privacy: &str,
    ty: &str,
) -> Result<ServerResponse> {
    let r = t
        .send_weapi(
            "/api/playlist/create",
            json!({
                "name": name,
                "privacy": if privacy.is_empty() { "0" } else { privacy },
                "type": if ty.is_empty() { "NORMAL" } else { ty },
            }),
        )
        .await?;

    Ok(ServerResponse::passthrough(r))
}

// ============================================================
//  /playlist/delete
// ============================================================

/// 删除歌单
///
/// ⚠️ 上游是 `/api/playlist/remove` —— **不是** `/api/playlist/delete`。
/// 客户端路由名与服务端上游名不一致，别搞混。
pub async fn playlist_delete(t: &ServerRequest<'_>, id: &str) -> Result<ServerResponse> {
    let r = t
        .send_weapi("/api/playlist/remove", json!({ "ids": format!("[{id}]") }))
        .await?;

    Ok(ServerResponse::passthrough(r))
}

// ============================================================
//  /playlist/tracks（加 / 删歌）
// ============================================================

/// 歌单加 / 删歌
///
/// ```text
/// data = { op: 'add'|'del', pid, trackIds: JSON.stringify(tracks), imme: 'true' }
/// ```
///
/// ## 失败重试
///
/// `code === 512` 时把 tracks **翻倍**再提交。
///
/// ## ⚠️ 成功路径的嵌套结构
///
/// 原实现成功时返回 `{ status: 200, body: { ...res } }`，即
/// `{status, body:{status, body, cookie}}` —— **三层嵌套**。
/// 客户端 `addMusicToPlaylist` 用 `containsKey('code')` 判断走哪个分支，
/// `deleteMusicFromPlaylist` 直接读 `response.data['body']['code']`，**两者都在适配这个嵌套**。
///
/// 这里**原样保留** —— 改掉会让客户端判断失效。
///
/// ## ⚠️ 失败路径
///
/// 恒返回 HTTP 200，靠 `body.code` 表达失败。
pub async fn playlist_tracks(
    t: &ServerRequest<'_>,
    op: &str,
    pid: &str,
    tracks: &[String],
) -> Result<ServerResponse> {
    let data = |tracks: &[String]| -> Result<Value> {
        Ok(json!({
            "op": op,
            "pid": pid,
            "trackIds": serde_json::to_string(tracks).map_err(|e| Error::Json(e.to_string()))?,
            "imme": "true",
        }))
    };

    let r = t
        .send_eapi("/api/playlist/manipulate/tracks", data(tracks)?)
        .await?;

    // `code == 512` → 把 tracks 翻倍再提交
    if r.code() == Some(512) {
        let mut doubled = tracks.to_vec();
        doubled.extend(tracks.iter().cloned());

        let retry = t
            .send_eapi("/api/playlist/manipulate/tracks", data(&doubled)?)
            .await?;

        return Ok(ServerResponse::passthrough(retry));
    }

    // ⚠️ 成功路径：保留三层嵌套
    Ok(ServerResponse::new(
        json!({
            "status": 200,
            "body": {
                "status": r.status,
                "body": r.body,
                "cookie": r.cookies,
            }
        }),
        Vec::new(),
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extracts_track_ids_as_strings() {
        let body = json!({"playlist": {"trackIds": [{"id": 1}, {"id": "2"}, {}]}});
        assert_eq!(extract_track_ids(&body), vec!["1", "2"]);
    }

    #[test]
    fn missing_track_ids_yields_empty() {
        assert!(extract_track_ids(&json!({})).is_empty());
    }
}
