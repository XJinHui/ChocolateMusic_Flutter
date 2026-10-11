//! 易盾反作弊 token（checkToken v3）
//!
//! 只有 `ad/get` 与 `ad/listening/rights/gain` 需要（精简版里）。
//!
//! ```text
//! GET https://ac.dun.163yun.com/v3/b?pn=YD00000558929251
//! 响应: null([200,<数字>,"<token>"])
//! ```
//!
//! ## 行为约定
//!
//! - 第 1 段必须是 `'200'`，否则失败
//! - 第 3 段是 token
//! - **任何异常都返回空串，不抛错** —— 调用方继续发请求，由上游决定是否拒绝
//! - **每次请求都重新获取，不缓存**（避免 token 复用触发风控）
//! - 裸 GET：无 User-Agent / Referer / Cookie
//!
//! `X-antiCheatToken` 的放置位置与 crypto 有关：
//!
//! | crypto | 位置 |
//! | --- | --- |
//! | `weapi` | Header |
//! | `xeapi` | Header |
//! | `eapi` | **Cookie 里的 `X-antiCheatToken` 键** |

/// 易盾的固定产品编号
const PN: &str = "YD00000558929251";
const URL: &str = "https://ac.dun.163yun.com/v3/b";

/// 获取 checkToken v3 token；失败返回空串
pub async fn token_v3(http: &reqwest::Client) -> String {
    match fetch(http).await {
        Ok(t) => t,
        // ⚠️ 不抛错：拿不到 token 就照常请求，让上游决定
        Err(_) => String::new(),
    }
}

async fn fetch(http: &reqwest::Client) -> Result<String, reqwest::Error> {
    let text = http
        .get(URL)
        .query(&[("pn", PN)])
        .send()
        .await?
        .text()
        .await?;

    Ok(parse(&text))
}

/// 从 `null([200,<数字>,"<token>"])` 里取 token
///
/// 解析不出来时返回空串。
pub fn parse(text: &str) -> String {
    let Some(start) = text.find("null([") else {
        return String::new();
    };
    let inner = &text[start + 6..];

    let Some(end) = inner.find("])") else {
        return String::new();
    };
    let inner = &inner[..end];

    // 三段：200,<数字>,"<token>"
    let parts: Vec<&str> = inner.split(',').collect();
    if parts.len() < 3 {
        return String::new();
    }
    if parts[0].trim() != "200" {
        return String::new();
    }

    // 第 3 段可能含逗号（token 里），把剩下的拼回来
    let token_part = parts[2..].join(",");
    token_part
        .trim()
        .trim_start_matches('"')
        .trim_end_matches('"')
        .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_normal_response() {
        assert_eq!(parse(r#"null([200,1234,"abcDEF123"])"#), "abcDEF123");
    }

    #[test]
    fn rejects_non_200_first_segment() {
        assert_eq!(parse(r#"null([400,1234,"abc"])"#), "");
    }

    #[test]
    fn tolerates_commas_inside_token() {
        assert_eq!(parse(r#"null([200,1,"a,b,c"])"#), "a,b,c");
    }

    #[test]
    fn returns_empty_on_garbage() {
        assert_eq!(parse(""), "");
        assert_eq!(parse("<html>"), "");
        assert_eq!(parse("null([200,1])"), "");
    }
}
