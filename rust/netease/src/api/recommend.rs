//! 发现族（3 条路由）
//!
//! | 路由 | 上游 | 加密 |
//! | --- | --- | --- |
//! | `/recommend/songs` | `/api/v3/discovery/recommend/songs` | weapi |
//! | `/recommend/resource` | `/api/v1/discovery/recommend/resource` | weapi |
//! | `/top/artists` | `/api/artist/top` | weapi |

use serde_json::json;

use crate::api::{ServerRequest, ServerResponse};
use crate::Result;

/// 每日推荐歌曲
///
/// ⚠️ `afresh` 可能为空 —— 此时**不要**把它塞进 body（JS 里 `undefined` 会被
/// `JSON.stringify` 丢掉，但显式的 `null` 会保留）。
///
/// ⚠️ 客户端读 `response.data['data']['dailySongs']`。
pub async fn recommend_songs(t: &ServerRequest<'_>, afresh: &str) -> Result<ServerResponse> {
    let data = if afresh.is_empty() {
        json!({})
    } else {
        json!({ "afresh": afresh })
    };

    let r = t
        .send_weapi("/api/v3/discovery/recommend/songs", data)
        .await?;

    Ok(ServerResponse::passthrough(r))
}

/// 每日推荐歌单
///
/// ⚠️ 客户端读 `response.data['recommend']`。
pub async fn recommend_resource(t: &ServerRequest<'_>) -> Result<ServerResponse> {
    let r = t
        .send_weapi("/api/v1/discovery/recommend/resource", json!({}))
        .await?;

    Ok(ServerResponse::passthrough(r))
}

/// 热门歌手
///
/// ⚠️ 客户端传 `limit=100`，读 `response.data['artists']`。
pub async fn top_artists(
    t: &ServerRequest<'_>,
    limit: u32,
    offset: u32,
) -> Result<ServerResponse> {
    let r = t
        .send_weapi(
            "/api/artist/top",
            json!({
                "limit": if limit == 0 { 50 } else { limit },
                "offset": offset,
                "total": true,
            }),
        )
        .await?;

    Ok(ServerResponse::passthrough(r))
}
