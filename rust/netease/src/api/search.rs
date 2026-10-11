//! 搜索（1 条路由）
//!
//! | 路由 | 上游 | 加密 |
//! | --- | --- | --- |
//! | `/search` | `/api/search/get` | eapi |

use serde_json::json;

use crate::api::{ServerRequest, ServerResponse};
use crate::Result;

/// 综合搜索
///
/// ⚠️ **参数别名**：客户端传 `keywords`（通过 `queryParameters`），上游字段是 `s`。
///
/// ⚠️ 客户端用三种 `type`：`1`（单曲，limit 50）、`100`（歌手，limit 5）、`10`（专辑，limit 10）。
/// ⚠️ 客户端读 `result.songs` / `result.artists` / `result.albums`。
/// ⚠️ 客户端**并发发起 3 个 `/search` 请求**（`Future.wait`）。
pub async fn search(
    t: &ServerRequest<'_>,
    keywords: &str,
    ty: u32,
    limit: u32,
    offset: u32,
) -> Result<ServerResponse> {
    let r = t
        .send_eapi(
            "/api/search/get",
            json!({
                "s": keywords,
                "type": if ty == 0 { 1 } else { ty },
                "limit": if limit == 0 { 30 } else { limit },
                "offset": offset,
            }),
        )
        .await?;

    Ok(ServerResponse::passthrough(r))
}
