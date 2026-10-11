//! 原始响应透传层
//!
//! `KuGou.dart` 原先通过自建服务器（KuGouMusicApi）请求酷狗，而那个服务器是个
//! **纯透传** —— `server.js` 的收尾就一句：
//!
//! ```js
//! res.header(moduleResponse.headers).status(moduleResponse.status).send(moduleResponse.body);
//! ```
//!
//! `moduleResponse.body` 就是酷狗上游返回的原始 JSON，服务器只额外挂 `Set-Cookie`。
//!
//! 所以本模块把**同一份原始体**原样吐给 Dart，客户端就只需把 `KuGou.dio.get(...)`
//! 换成 FFI 调用，其余解析代码一行都不用动。
//!
//! ## 与服务器不一致的三处（已在此补齐）
//!
//! | 路径 | 服务器的额外处理 |
//! | --- | --- |
//! | `/register/dev` | 响应体是二进制，需 AES 解密 |
//! | `/login/cellphone`、`/login/token` | 把 `secu_params` 解密后合并进 `data` |
//! | `/lyric?decode=true` | base64 / KRC 解码后挂到 `decodeContent` |
//!
//! 这三处的处理逻辑直接复用 [`crate::api`] 里已有的实现，不重复写。

use std::collections::HashMap;

use crate::api;
use crate::request::{RequestOptions, Transport};
use crate::{Error, Result};
use serde_json::{json, Value};

/// 查询参数（已从 URL 中解析出来，值统一为字符串）
pub type Query = HashMap<String, String>;

/// 一次原始请求的结果
pub struct RawOutcome {
    /// 上游返回的完整响应体（与原服务器返回的一致）
    pub body: Value,
    /// `/register/dev` 拿到的 `dfid`，需要写回客户端并持久化
    pub dfid: Option<String>,
    /// 登录接口拿到的凭据，需要写回客户端并持久化
    pub login: Option<api::login::LoginResult>,
}

impl RawOutcome {
    /// 只有响应体、没有副作用的普通结果
    fn body(body: Value) -> Self {
        Self {
            body,
            dfid: None,
            login: None,
        }
    }

    /// 带登录凭据的结果（凭据无效时退化为普通结果）
    fn maybe_login(body: Value) -> Self {
        let login = body
            .get("data")
            .filter(|d| d.is_object())
            .map(|_| api::login::login_result_from(&body));
        Self {
            body,
            dfid: None,
            login,
        }
    }
}

// ============================================================
//  入口
// ============================================================

/// 按原服务器的路由分发一次请求
pub(crate) async fn dispatch(t: &Transport, path: &str, query: &Query) -> Result<RawOutcome> {
    let path = normalize_path(path);

    let out = match path.as_str() {
        // 本地没有服务器，存活探测恒为成功。
        // 原代码 `KuGou.dio.get('')` 只是为了确认服务器可达。
        "" | "/" => RawOutcome::body(json!({ "status": 1, "data": {} })),

        // ---------------- 设备与登录 ----------------
        "/register/dev" => {
            let body = with_recover(api::login::register_dev_body(t)).await?;
            let dfid = body
                .pointer("/data/dfid")
                .and_then(|v| v.as_str())
                .map(str::to_string);
            RawOutcome {
                body,
                dfid,
                login: None,
            }
        }
        "/captcha/sent" => {
            RawOutcome::body(send(t, api::login::build_captcha_sent(s(query, "mobile"))).await?)
        }
        "/login/qr/key" => RawOutcome::body(send(t, api::login::build_qr_key(t)).await?),
        "/login/qr/check" => {
            let body = send(t, api::login::build_qr_check(t, s(query, "key"))).await?;
            // status == 4 表示授权成功，此时响应体里带 token/userid
            let login = match body.pointer("/data/status").and_then(|v| v.as_i64()) {
                Some(4) => Some(api::login::login_result_from(&body)),
                _ => None,
            };
            RawOutcome {
                body,
                dfid: None,
                login,
            }
        }
        "/login/cellphone" => {
            let body = with_recover(api::login::login_cellphone_body(
                t,
                s(query, "mobile"),
                s(query, "code"),
            ))
            .await?;
            RawOutcome::maybe_login(body)
        }
        "/login/token" => {
            let body = with_recover(api::login::login_token_body(t)).await?;
            RawOutcome::maybe_login(body)
        }

        // ---------------- VIP ----------------
        "/youth/day/vip" => RawOutcome::body(
            send(t, api::user_vip::build_youth_day_vip(s(query, "receive_day"))).await?,
        ),
        "/youth/day/vip/upgrade" => {
            RawOutcome::body(send(t, api::user_vip::build_youth_day_vip_upgrade(t)).await?)
        }
        "/youth/vip" => RawOutcome::body(send(t, api::user_vip::build_youth_vip()).await?),

        // ---------------- 歌单 ----------------
        "/user/playlist" => RawOutcome::body(
            send(
                t,
                api::user::build_user_playlist(t, u32_or(query, "page", 1), u32_or(query, "pagesize", 30)),
            )
            .await?,
        ),
        "/playlist/track/all" => RawOutcome::body(
            send(
                t,
                api::playlist::build_playlist_track_all(
                    s(query, "id"),
                    u32_or(query, "page", 1),
                    u32_or(query, "pagesize", 300),
                ),
            )
            .await?,
        ),
        "/playlist/detail" => RawOutcome::body(
            send(
                t,
                api::playlist::build_playlist_detail(t, &split_csv(s(query, "ids"))),
            )
            .await?,
        ),
        "/playlist/add" => RawOutcome::body(
            send(t, api::playlist::build_playlist_add(t, s(query, "name"), 0)).await?,
        ),
        // ⚠️ 这个接口的响应本身就是加密的，`playlist_del` 返回的已是解密后的体
        "/playlist/del" => RawOutcome::body(with_recover(api::playlist::playlist_del(
            t,
            s(query, "listid"),
        ))
        .await?),
        "/playlist/tracks/add" => RawOutcome::body(
            send(
                t,
                api::playlist::build_playlist_tracks_add(
                    t,
                    s(query, "listid"),
                    s(query, "data"),
                ),
            )
            .await?,
        ),
        "/playlist/tracks/del" => RawOutcome::body(
            send(
                t,
                api::playlist::build_playlist_tracks_del(
                    t,
                    s(query, "listid"),
                    s(query, "fileids"),
                ),
            )
            .await?,
        ),

        // ---------------- 歌曲 ----------------
        "/song/url" => RawOutcome::body(
            send(
                t,
                api::song::build_song_url(t, s(query, "hash"), s(query, "quality")),
            )
            .await?,
        ),
        "/privilege/lite" => RawOutcome::body(
            send(
                t,
                api::song::build_privilege_lite(t, &split_csv(s(query, "hash"))),
            )
            .await?,
        ),
        "/krm/audio" => RawOutcome::body(
            send(
                t,
                api::song::build_krm_audio(
                    &split_csv(s(query, "album_audio_id")),
                    s(query, "fields"),
                ),
            )
            .await?,
        ),
        "/search/lyric" => {
            RawOutcome::body(send(t, api::song::build_search_lyric(t, s(query, "hash"))).await?)
        }
        "/lyric" => RawOutcome::body(with_recover(api::song::lyric_by_id_body(
            t,
            s(query, "id"),
            s(query, "accesskey"),
            s(query, "fmt"),
        ))
        .await?),

        // ---------------- 搜索 ----------------
        "/search/complex" => RawOutcome::body(
            send(
                t,
                api::search::build_search_complex(
                    s(query, "keywords"),
                    u32_or(query, "page", 1),
                    u32_or(query, "pagesize", 30),
                ),
            )
            .await?,
        ),

        // ---------------- 歌手 ----------------
        "/artist/lists" => RawOutcome::body(
            send(t, api::artist::build_artist_lists(u32_or(query, "hotsize", 30))).await?,
        ),
        "/artist/audios" => RawOutcome::body(
            send(
                t,
                api::artist::build_artist_audios(
                    t,
                    s(query, "id"),
                    u32_or(query, "pagesize", 30),
                    s(query, "sort"),
                ),
            )
            .await?,
        ),
        "/artist/albums" => RawOutcome::body(
            send(
                t,
                api::artist::build_artist_albums(
                    s(query, "id"),
                    u32_or(query, "pagesize", 30),
                    s(query, "sort"),
                ),
            )
            .await?,
        ),
        "/artist/detail" => {
            RawOutcome::body(send(t, api::artist::build_artist_detail(s(query, "id"))).await?)
        }

        // ---------------- 专辑 ----------------
        "/album" => RawOutcome::body(
            send(
                t,
                api::album::build_album(
                    t,
                    &split_csv(s(query, "album_id")),
                    s(query, "fields"),
                ),
            )
            .await?,
        ),
        "/album/songs" => {
            RawOutcome::body(send(t, api::album::build_album_songs(s(query, "id"))).await?)
        }

        // ---------------- 推荐 ----------------
        "/everyday/recommend" => {
            RawOutcome::body(send(t, api::recommend::build_everyday_recommend()).await?)
        }
        "/top/ip" => RawOutcome::body(send(t, api::recommend::build_top_ip()).await?),

        other => {
            return Err(Error::Invalid(format!("raw_request 未实现的路径: {other}")));
        }
    };

    Ok(out)
}

// ============================================================
//  内部工具
// ============================================================

/// 发一次请求，取原始响应体（**业务失败也照常返回**，由 Dart 侧判断）
async fn send(t: &Transport, opt: RequestOptions) -> Result<Value> {
    t.send_raw(opt).await
}

/// 调用「带后处理的接口」，业务失败时退回原始响应体
///
/// `/register/dev`、登录、歌词这几个接口要先做解密/解码，它们内部用的是严格的
/// [`Transport::send`]。原服务器对业务失败也是照常返回响应体的，这里补回这个语义。
async fn with_recover<F>(fut: F) -> Result<Value>
where
    F: std::future::Future<Output = Result<Value>>,
{
    match fut.await {
        Ok(v) => Ok(v),
        Err(e) => crate::request::recover_body(e),
    }
}

/// 取字符串参数，缺失时返回空串
fn s<'a>(query: &'a Query, key: &str) -> &'a str {
    query.get(key).map(String::as_str).unwrap_or("")
}

/// 取数字参数
fn u32_or(query: &Query, key: &str, default: u32) -> u32 {
    s(query, key).parse().unwrap_or(default)
}

/// `"a,b,c"` → `["a", "b", "c"]`（忽略空段）
fn split_csv(v: &str) -> Vec<String> {
    v.split(',')
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(str::to_string)
        .collect()
}

/// 归一化路径：剥掉查询串与尾部斜杠，容忍传进来的是完整 URL
fn normalize_path(path: &str) -> String {
    let p = match path.find("://") {
        Some(i) => {
            // 完整 URL：跳过 scheme://host
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn path_normalization() {
        assert_eq!(normalize_path("/song/url?hash=x&quality=320"), "/song/url");
        assert_eq!(normalize_path("/song/url"), "/song/url");
        assert_eq!(normalize_path("/song/url/"), "/song/url");
        assert_eq!(normalize_path(""), "");
        assert_eq!(normalize_path("/"), "/");
        assert_eq!(
            normalize_path("https://kugou.xjinhui.asia/song/url?hash=x"),
            "/song/url"
        );
    }

    #[test]
    fn csv_splitting() {
        assert_eq!(split_csv("a,b,c"), vec!["a", "b", "c"]);
        assert_eq!(split_csv(""), Vec::<String>::new());
        assert_eq!(split_csv("a,,b"), vec!["a", "b"]);
        assert_eq!(split_csv(" a , b "), vec!["a", "b"]);
    }

    #[test]
    fn param_lookup() {
        let mut q = Query::new();
        q.insert("page".into(), "3".into());
        assert_eq!(u32_or(&q, "page", 1), 3);
        assert_eq!(u32_or(&q, "missing", 7), 7);
        assert_eq!(u32_or(&q, "missing", 0), 0);
        assert_eq!(s(&q, "missing"), "");
    }
}
