//! 专辑族（1 条路由）
//!
//! | 路由 | 上游 | 加密 |
//! | --- | --- | --- |
//! | `/album` | `/api/v1/album/{id}` | weapi |

use serde_json::json;

use crate::api::{ServerRequest, ServerResponse};
use crate::Result;

/// 专辑信息
///
/// ⚠️ **`id` 在 URL 路径里**，body 是**空对象**。
///
/// ⚠️ 客户端用**同一个路由**做两件事：
/// - `getAlbumMusic` 读 `songs[]`
/// - `getAlbumDetails` 读 `album.{name,id,artists,picUrl,size}`
pub async fn album(t: &ServerRequest<'_>, id: &str) -> Result<ServerResponse> {
    let r = t.send_weapi(&format!("/api/v1/album/{id}"), json!({})).await?;
    Ok(ServerResponse::passthrough(r))
}
