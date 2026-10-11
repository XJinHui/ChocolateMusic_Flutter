//! 原始响应透传层
//!
//! 按原服务器的路由分发，返回**原服务器会返回的响应体**。
//!
//! ## 与 KuGou 那边的重要差异
//!
//! `api-enhanced` **不是纯透传** —— `server.js` 的收尾虽然也是
//! `res.status(...).send(moduleResponse.body)`，但 `moduleResponse.body` 是
//! `module/*.js` **重新包装过**的，而不是上游原始响应：
//!
//! ```js
//! // module/login_qr_key.js
//! return { status: 200, body: { data: result.body, code: 200 }, cookie: result.cookie }
//! ```
//!
//! 所以透传层不能简单回放上游 body，而要让 [`crate::api`] 各接口负责包装 ——
//! 本模块只做**路由分发**。
//!
//! ## 凭据来源
//!
//! NetEase 与 KuGou 不同：凭据走 **Cookie 头**，不是 query 参数。
//! 客户端调用形如 `Options(headers: {'Cookie': this.cookies})`。

use serde_json::{json, Value};

use crate::api::{self, split_csv, ServerRequest};
use crate::request::Transport;
use crate::{Error, Result};

pub use crate::Query;

/// 按原服务器的路由分发一次请求
///
/// `path` 是原服务器的路由（如 `/song/url`），`query` 是查询参数，
/// `cookie` 是账号 Cookie 串（未登录传空串）。
pub async fn dispatch(
    transport: &Transport,
    path: &str,
    query: &Query,
    cookie: &str,
) -> Result<Value> {
    let path = normalize_path(path);
    let t = ServerRequest::new(transport, cookie);

    let body = match path.as_str() {
        // ---------------- 登录与会话 ----------------
        "/login/status" => api::login::login_status(&t).await?.body,
        "/login/refresh" => api::login::login_refresh(&t).await?.body,
        "/login/cellphone" => {
            api::login::login_cellphone(
                &t,
                s(query, "phone"),
                s(query, "captcha"),
                s(query, "password"),
                s(query, "countrycode"),
            )
            .await?
            .body
        }
        "/captcha/sent" => {
            api::login::captcha_sent(&t, s(query, "phone"), s(query, "ctcode"))
                .await?
                .body
        }
        "/login/qr/key" => api::login::qr_key(&t).await?.body,

        // ⚠️ 这条**不发任何网易请求** —— 本地生成二维码
        "/login/qr/create" => {
            api::login::qr_create(
                s(query, "key"),
                s(query, "platform"),
                truthy(s(query, "qrimg")),
                &transport.device.device_id,
            )
            .body
        }

        "/login/qr/check" => api::login::qr_check(&t, s(query, "key")).await?.body,
        // 启动流程用（不属于客户端调用的 29 条）
        "/register/anonimous" => {
            api::login::register_anonimous(&t, &transport.device.device_id).await?.body
        }
        "/user/account" => api::login::user_account(&t).await?.body,
        "/vip/info" => api::login::vip_info(&t, s(query, "uid")).await?.body,

        // ---------------- 歌单 ----------------
        "/user/playlist" => {
            api::playlist::user_playlist(
                &t,
                s(query, "uid"),
                u32_or(query, "limit", 30),
                u32_or(query, "offset", 0),
            )
            .await?
            .body
        }
        "/playlist/detail" => {
            api::playlist::playlist_detail(&t, s(query, "id"), u32_or(query, "s", 8))
                .await?
                .body
        }
        "/playlist/track/all" => {
            api::playlist::playlist_track_all(
                &t,
                s(query, "id"),
                usize_or(query, "limit", 1000),
                usize_or(query, "offset", 0),
            )
            .await?
            .body
        }
        "/playlist/create" => {
            api::playlist::playlist_create(
                &t,
                s(query, "name"),
                s(query, "privacy"),
                s(query, "type"),
            )
            .await?
            .body
        }
        "/playlist/delete" => api::playlist::playlist_delete(&t, s(query, "id")).await?.body,
        "/playlist/tracks" => {
            api::playlist::playlist_tracks(
                &t,
                s(query, "op"),
                s(query, "pid"),
                &split_csv(s(query, "tracks")),
            )
            .await?
            .body
        }

        // ---------------- 音乐 ----------------
        "/song/detail" => {
            api::song::song_detail(&t, &split_csv(s(query, "ids")))
                .await?
                .body
        }
        "/song/url" => {
            // ⚠️ 客户端的 `level` / `unblock` 被服务端**完全忽略**（原实现行为，保留）
            api::song::song_url(
                &t,
                &split_csv(s(query, "id")),
                u32_or(query, "br", 999_000),
            )
            .await?
            .body
        }
        "/lyric" => api::song::lyric(&t, s(query, "id")).await?.body,

        // ---------------- 歌手 / 专辑 ----------------
        "/artist/songs" => {
            api::artist::artist_songs(
                &t,
                s(query, "id"),
                s(query, "order"),
                u32_or(query, "offset", 0),
                u32_or(query, "limit", 100),
            )
            .await?
            .body
        }
        "/artist/album" => {
            api::artist::artist_album(
                &t,
                s(query, "id"),
                u32_or(query, "limit", 30),
                u32_or(query, "offset", 0),
            )
            .await?
            .body
        }
        "/artist/detail" => api::artist::artist_detail(&t, s(query, "id")).await?.body,
        "/album" => api::album::album(&t, s(query, "id")).await?.body,

        // ---------------- 搜索 / 发现 ----------------
        "/search" => {
            api::search::search(
                &t,
                s(query, "keywords"),
                u32_or(query, "type", 1),
                u32_or(query, "limit", 30),
                u32_or(query, "offset", 0),
            )
            .await?
            .body
        }
        "/recommend/songs" => {
            api::recommend::recommend_songs(&t, s(query, "afresh")).await?.body
        }
        "/recommend/resource" => api::recommend::recommend_resource(&t).await?.body,
        "/top/artists" => {
            api::recommend::top_artists(
                &t,
                u32_or(query, "limit", 50),
                u32_or(query, "offset", 0),
            )
            .await?
            .body
        }

        // ---------------- 广告免费听（xeapi） ----------------
        //
        // ⚠️ 这三条走的是完全独立的一条路径：三层加密 + 响应也加密。
        "/ad/get" => {
            api::ad::ad_get(&t, s(query, "type_ids")).await?.body
        }
        "/ad/listening/rights" => api::ad::ad_listening_rights(&t).await?.body,
        "/ad/listening/rights/gain" => {
            api::ad::ad_listening_rights_gain(&t, query).await?.body
        }

        other => {
            return Err(Error::Invalid(format!("raw_request 未实现的路径: {other}")));
        }
    };

    Ok(body)
}

/// 尚未实现的路由（当前为空）
pub const UNIMPLEMENTED: &[&str] = &[];

// ============================================================
//  内部工具
// ============================================================

/// 取字符串参数，缺失时返回空串
fn s<'a>(query: &'a Query, key: &str) -> &'a str {
    query.get(key).map(String::as_str).unwrap_or("")
}

/// 取数字参数
fn u32_or(query: &Query, key: &str, default: u32) -> u32 {
    s(query, key).parse().unwrap_or(default)
}

/// 取 `usize` 参数
fn usize_or(query: &Query, key: &str, default: usize) -> usize {
    s(query, key).parse().unwrap_or(default)
}

/// 模仿 JS 的 truthy：`'true'` / `'1'` / `'yes'` 为真
fn truthy(v: &str) -> bool {
    matches!(v, "true" | "1" | "yes")
}

/// 归一化路径：剥掉查询串与尾部斜杠，容忍传进来的是完整 URL
pub fn normalize_path(path: &str) -> String {
    let p = match path.find("://") {
        Some(i) => {
            let rest = &path[i + 3..];
            match rest.find('/') {
                Some(j) => &rest[j..],
                None => "/",
            }
        }
        None => path,
    };

    let p = match p.find('?') {
        Some(i) => &p[..i],
        None => p,
    };

    let p = p.trim();
    if p.len() > 1 && p.ends_with('/') {
        p[..p.len() - 1].to_string()
    } else {
        p.to_string()
    }
}

/// 全部已实现的路由（供文档与测试用）
pub const ROUTES: &[&str] = &[
    "/login/status",
    "/login/refresh",
    "/login/cellphone",
    "/captcha/sent",
    "/login/qr/key",
    "/login/qr/create",
    "/login/qr/check",
    "/user/account",
    "/vip/info",
    "/user/playlist",
    "/playlist/track/all",
    "/playlist/detail",
    "/playlist/create",
    "/playlist/delete",
    "/playlist/tracks",
    "/song/detail",
    "/song/url",
    "/lyric",
    "/artist/songs",
    "/artist/album",
    "/artist/detail",
    "/album",
    "/search",
    "/recommend/songs",
    "/recommend/resource",
    "/top/artists",
    "/ad/get",
    "/ad/listening/rights",
    "/ad/listening/rights/gain",
    // 客户端不调用，但属于启动流程（拿匿名 MUSIC_A）
    "/register/anonimous",
];

/// 一个空响应体（占位）
pub fn empty_body() -> Value {
    json!({ "code": 200 })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn path_normalization() {
        assert_eq!(normalize_path("/song/url?id=1"), "/song/url");
        assert_eq!(normalize_path("/song/url/"), "/song/url");
        assert_eq!(normalize_path(""), "");
        assert_eq!(normalize_path("/"), "/");
        assert_eq!(
            normalize_path("https://neteasecloud.xjinhui.asia/song/url?id=1"),
            "/song/url"
        );
    }

    #[test]
    fn param_helpers() {
        let mut q = Query::new();
        q.insert("limit".into(), "300".into());
        q.insert("qrimg".into(), "true".into());

        assert_eq!(u32_or(&q, "limit", 30), 300);
        assert_eq!(u32_or(&q, "missing", 30), 30);
        assert_eq!(usize_or(&q, "limit", 1000), 300);
        assert_eq!(s(&q, "missing"), "");

        assert!(truthy("true"));
        assert!(truthy("1"));
        assert!(!truthy(""));
        assert!(!truthy("false"));
    }

    #[test]
    fn route_table_covers_all_29() {
        // 客户端用到的 29 条 + 启动流程的 1 条（匿名注册）
        assert_eq!(ROUTES.len(), 30);
        assert!(UNIMPLEMENTED.is_empty());
    }

    #[test]
    fn routes_are_unique_and_well_formed() {
        let mut seen = std::collections::HashSet::new();
        for r in ROUTES.iter().chain(UNIMPLEMENTED) {
            assert!(r.starts_with('/'), "路由必须以 / 开头: {r}");
            assert!(seen.insert(*r), "重复路由: {r}");
        }
    }
}
