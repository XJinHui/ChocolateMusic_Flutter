//! 歌手族（3 条路由）
//!
//! | 路由 | 上游 | 加密 |
//! | --- | --- | --- |
//! | `/artist/songs` | `/api/v1/artist/songs` | eapi |
//! | `/artist/album` | `/api/artist/albums/{id}` | weapi |
//! | `/artist/detail` | `/api/artist/head/info/get` | eapi |

use serde_json::json;

use crate::api::{ServerRequest, ServerResponse};
use crate::Result;

/// 歌手单曲
///
/// ⚠️ 客户端 `getSingerAllMusic` 用 `limit=200` 循环翻页，**直到 `songs.length == 0`**。
pub async fn artist_songs(
    t: &ServerRequest<'_>,
    id: &str,
    order: &str,
    offset: u32,
    limit: u32,
) -> Result<ServerResponse> {
    let r = t
        .send_eapi(
            "/api/v1/artist/songs",
            json!({
                "id": id,
                "private_cloud": "true",
                "work_type": 1,
                "order": if order.is_empty() { "hot" } else { order },
                "offset": offset,
                "limit": if limit == 0 { 100 } else { limit },
            }),
        )
        .await?;

    Ok(ServerResponse::passthrough(r))
}

/// 歌手专辑
///
/// ⚠️ **`id` 在 URL 路径里**，不在 body。
/// 客户端读 `hotAlbums[]` 与 `artist.name`。
pub async fn artist_album(
    t: &ServerRequest<'_>,
    id: &str,
    limit: u32,
    offset: u32,
) -> Result<ServerResponse> {
    let r = t
        .send_weapi(
            &format!("/api/artist/albums/{id}"),
            json!({
                "limit": if limit == 0 { 30 } else { limit },
                "offset": offset,
                "total": true,
            }),
        )
        .await?;

    Ok(ServerResponse::passthrough(r))
}

/// 歌手详情
///
/// ⚠️ 客户端读 `response.data['data']['artist']`。
pub async fn artist_detail(t: &ServerRequest<'_>, id: &str) -> Result<ServerResponse> {
    let r = t
        .send_eapi("/api/artist/head/info/get", json!({ "id": id }))
        .await?;

    Ok(ServerResponse::passthrough(r))
}
