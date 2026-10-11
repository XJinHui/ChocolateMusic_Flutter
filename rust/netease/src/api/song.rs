//! 音乐族（3 条路由）
//!
//! | 路由 | 上游 | 加密 |
//! | --- | --- | --- |
//! | `/song/detail` | `/api/v3/song/detail` | **weapi** |
//! | `/song/url` | `/api/song/enhance/player/url` | eapi |
//! | `/lyric` | `/api/song/lyric` | eapi |

use serde_json::json;

use crate::api::{song_detail_c, ServerRequest, ServerResponse};
use crate::{Error, Result};

/// 歌曲详情
///
/// ⚠️ 客户端把 ID 用 `,` 拼成字符串传 `ids`。
/// ⚠️ 客户端读 `songs[].id / name / ar[].name / ar[0].id / al.name / al.id / dt / al.picUrl`。
pub async fn song_detail(t: &ServerRequest<'_>, ids: &[String]) -> Result<ServerResponse> {
    let r = t
        .send_weapi(
            "/api/v3/song/detail",
            json!({ "c": song_detail_c(ids) }),
        )
        .await?;
    Ok(ServerResponse::passthrough(r))
}

/// 播放地址
///
/// ```text
/// data = { ids: JSON.stringify(String(query.id).split(',')), br: parseInt(query.br || 999000) }
/// 响应 = { status:200, body:{ code:200, data: <按输入顺序重排后的 data> } }
/// ```
///
/// ⚠️ **`level` 与 `unblock` 被完全忽略** —— 客户端传的 `level=exhigh` / `unblock=true`
/// 在服务端没有任何效果（`song_url.js` 只读 `br`）。所以音质不可控、解灰从未生效。
/// 这是原实现的行为，**保留**（改掉会与客户端预期不符）。
///
/// ⚠️ 响应被重排为输入顺序，且 `code` 恒为 200（上游 code 被丢弃）。
pub async fn song_url(
    t: &ServerRequest<'_>,
    ids: &[String],
    br: u32,
) -> Result<ServerResponse> {
    let r = t
        .send_eapi(
            "/api/song/enhance/player/url",
            json!({
                "ids": serde_json::to_string(ids).map_err(|e| Error::Json(e.to_string()))?,
                "br": if br == 0 { 999_000 } else { br },
            }),
        )
        .await?;

    let mut data = r
        .body
        .get("data")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();

    // 按输入顺序重排（对应 `result.sort((a,b) => ids.indexOf(String(a.id)) - ids.indexOf(String(b.id)))`）
    // ⚠️ Rust 的 `sort_by_key` 是稳定排序，与 V8 一致
    data.sort_by_key(|item| {
        let id = item.get("id").map(js_string).unwrap_or_default();
        ids.iter().position(|x| *x == id).unwrap_or(usize::MAX)
    });

    Ok(ServerResponse::new(
        json!({ "code": 200, "data": data }),
        Vec::new(),
    ))
}

/// 歌词
///
/// ⚠️ 客户端读 `lrc.lyric` 与 `tlyric.lyric` 并**拼接**；`tlyric` 可能为 `null`。
pub async fn lyric(t: &ServerRequest<'_>, id: &str) -> Result<ServerResponse> {
    let r = t
        .send_eapi(
            "/api/song/lyric",
            json!({ "id": id, "tv": -1, "lv": -1, "rv": -1, "kv": -1, "_nmclfl": 1 }),
        )
        .await?;
    Ok(ServerResponse::passthrough(r))
}

/// 模仿 JS 的 `String(v)`：字符串原样，数字取 JSON 表示
pub fn js_string(v: &serde_json::Value) -> String {
    match v {
        serde_json::Value::String(s) => s.clone(),
        other => other.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn js_string_matches_js_semantics() {
        assert_eq!(js_string(&json!(347230)), "347230");
        assert_eq!(js_string(&json!("347230")), "347230");
    }

    #[test]
    fn song_url_reorders_to_input_order() {
        // 复刻 sort 的排序键计算
        let input = ["3".to_string(), "1".to_string(), "2".to_string()];
        let mut data = vec![json!({"id": 1}), json!({"id": 2}), json!({"id": 3})];

        data.sort_by_key(|item| {
            let id = item.get("id").map(js_string).unwrap_or_default();
            input.iter().position(|x| *x == id).unwrap_or(usize::MAX)
        });

        let order: Vec<String> = data.iter().map(js_string_id).collect();
        assert_eq!(order, vec!["3", "1", "2"]);
    }

    fn js_string_id(v: &serde_json::Value) -> String {
        js_string(v.get("id").unwrap())
    }
}
