//! 搜索
//!
//! 对应 `KuGou.dart` 的 `search(keyword)`。

use crate::models::{Album, Music, SearchResult, Singer};
use crate::request::{RequestOptions, Transport};
use crate::Result;
use serde_json::Value;

/// 综合搜索
///
/// 对应 Dart 的 `search(keyword)`。
///
/// ```text
/// GET https://complexsearch.kugou.com/v6/search/complex
/// ```
///
/// ⚠️ **必须携带登录凭据**。未登录时上游返回 `error_code: 152`，且响应体被
/// `<!--KG_TAG_RES_START-->` 包裹，导致 JSON 解析失败。
/// 本实现通过默认参数自动带上 `token`/`userid`/`dfid`，因此登录后即可正常工作。
///
/// ⚠️ 返回字段是 **PascalCase**（`FileHash` / `AuthorId` / `albumid`），
/// 三种命名风格混用，详见 `docs/rewrite/api/endpoints/search_complex.md`。
/// 构造「综合搜索」请求
pub(crate) fn build_search_complex(keyword: &str, page: u32, pagesize: u32) -> RequestOptions {
    RequestOptions::get("/v6/search/complex")
        .base_url("https://complexsearch.kugou.com")
        .param("platform", "AndroidFilter")
        .param("keyword", keyword)
        .param("page", if page == 0 { 1 } else { page })
        .param("pagesize", if pagesize == 0 { 30 } else { pagesize })
        .param("cursor", 0)
}

pub async fn search_complex(
    t: &Transport,
    keyword: &str,
    page: u32,
    pagesize: u32,
) -> Result<SearchResult> {
    let resp = t
        .send(build_search_complex(keyword, page, pagesize))
        .await?;

    let mut out = SearchResult::default();

    for group in resp.arr_at(&["data", "lists"]) {
        let ty = group.get("type").and_then(|v| v.as_str()).unwrap_or("");
        let lists = group
            .get("lists")
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default();

        match ty {
            "song" => {
                for item in &lists {
                    // ⚠️ PascalCase 字段名
                    if let Some(hash) = item.get("FileHash").and_then(|v| v.as_str()) {
                        out.music.push(Music {
                            id: hash.to_string(),
                            name: s(item, "SongName"),
                            singer: s(item, "SingerName"),
                            album: s(item, "AlbumName"),
                            album_id: s(item, "AlbumID"),
                            time: item.get("Duration").and_then(|v| v.as_i64()).unwrap_or(0),
                            cover: crate::models::get_cover(&s(item, "Image"), "500"),
                            ..Default::default()
                        });
                    }
                }
            }
            "author" => {
                for item in &lists {
                    out.singer.push(Singer {
                        singer: s(item, "AuthorName"),
                        singer_id: n(item, "AuthorId"),
                        cover: crate::models::get_cover(&s(item, "Avatar"), "500"),
                        audio_count: item
                            .get("AudioCount")
                            .and_then(|v| v.as_i64())
                            .unwrap_or(0),
                        album_count: item
                            .get("AlbumCount")
                            .and_then(|v| v.as_i64())
                            .unwrap_or(0),
                    });
                }
            }
            "album" => {
                for item in &lists {
                    // ⚠️ 这里是小写 `albumid` / `albumname`
                    out.album.push(Album {
                        album: s(item, "albumname"),
                        album_id: n(item, "albumid"),
                        singer: s(item, "singer"),
                        cover: crate::models::get_cover(&s(item, "img"), "500"),
                        audio_count: 0,
                    });
                }
            }
            _ => {}
        }
    }

    Ok(out)
}

fn s(v: &Value, k: &str) -> String {
    match v.get(k) {
        Some(Value::String(x)) => x.clone(),
        Some(Value::Number(x)) => x.to_string(),
        _ => String::new(),
    }
}

fn n(v: &Value, k: &str) -> String {
    match v.get(k) {
        Some(Value::Number(x)) => x.to_string(),
        Some(Value::String(x)) => x.clone(),
        _ => String::new(),
    }
}
