//! 接口层
//!
//! 每个子模块对应 `module/*.js` 里的一组路由。函数返回 [`ServerResponse`] ——
//! 即**原服务器会返回的东西**（`server.js` 的 `res.status(...).send(moduleResponse.body)`）。
//!
//! 这么设计是为了让 [`crate::raw`] 只需序列化，而不必重复实现各接口的包装规则。

use serde_json::{json, Value};

use crate::request::{ApiResponse, RequestOptions, Transport};
use crate::{Crypto, Result};

pub mod ad;
pub mod album;
pub mod artist;
pub mod login;
pub mod playlist;
pub mod recommend;
pub mod search;
pub mod song;

/// 一次请求的上下文：传输层 + 账号 Cookie
///
/// 各接口函数都收这个，而不是直接收 [`Transport`] —— 因为账号 Cookie 是
/// 每个请求都要带的东西（对应 Dart 侧 `Options(headers: {'Cookie': this.cookies})`）。
pub struct ServerRequest<'a> {
    pub transport: &'a Transport,
    /// 账号 Cookie 串（未登录时为空）
    pub cookie: String,
}

impl<'a> ServerRequest<'a> {
    pub fn new(transport: &'a Transport, cookie: impl Into<String>) -> Self {
        Self {
            transport,
            cookie: cookie.into(),
        }
    }

    /// 发一次 weapi 请求
    ///
    /// ⚠️ 用 [`Transport::send_raw`] —— 业务失败也返回响应体，
    /// 因为原服务器就是「无论成败都回 body，由客户端看 `code`」。
    pub async fn send_weapi(&self, uri: &str, data: Value) -> Result<ApiResponse> {
        self.transport
            .send_raw(RequestOptions::new(uri, Crypto::Weapi, data).cookie(self.cookie.clone()))
            .await
    }

    /// 发一次 eapi 请求
    pub async fn send_eapi(&self, uri: &str, data: Value) -> Result<ApiResponse> {
        self.transport
            .send_raw(RequestOptions::new(uri, Crypto::Eapi, data).cookie(self.cookie.clone()))
            .await
    }

    /// 发一次需要反作弊 token 的 eapi 请求
    pub async fn send_eapi_checked(&self, uri: &str, data: Value) -> Result<ApiResponse> {
        self.transport
            .send_raw(
                RequestOptions::new(uri, Crypto::Eapi, data)
                    .cookie(self.cookie.clone())
                    .check_token(true),
            )
            .await
    }

    /// 发一次需要反作弊 token 的 weapi 请求
    pub async fn send_weapi_checked(&self, uri: &str, data: Value) -> Result<ApiResponse> {
        self.transport
            .send_raw(
                RequestOptions::new(uri, Crypto::Weapi, data)
                    .cookie(self.cookie.clone())
                    .check_token(true),
            )
            .await
    }

    /// 发一次 xeapi 请求（广告族 + 匿名注册）
    ///
    /// ⚠️ 走的是完全独立的一条路径：三层加密 + **响应也加密**。
    pub async fn send_xeapi(&self, uri: &str, data: Value) -> Result<ApiResponse> {
        self.transport
            .send_xeapi(uri, data, &self.cookie, false)
            .await
    }

    /// 发一次需要反作弊 token 的 xeapi 请求
    pub async fn send_xeapi_checked(&self, uri: &str, data: Value) -> Result<ApiResponse> {
        self.transport
            .send_xeapi(uri, data, &self.cookie, true)
            .await
    }
}

/// 原服务器返回的响应体
///
/// `body` 就是 HTTP 响应体（`res.send(...)` 的实参），`cookies` 是 `Set-Cookie`。
#[derive(Debug, Clone)]
pub struct ServerResponse {
    pub body: Value,
    pub cookies: Vec<String>,
}

impl ServerResponse {
    pub fn new(body: Value, cookies: Vec<String>) -> Self {
        Self { body, cookies }
    }

    /// **直通**：上游 body 原样返回
    ///
    /// 大多数接口都是这个模式（`module/*.js` 直接 `return request(...)`）。
    pub fn passthrough(r: ApiResponse) -> Self {
        Self {
            body: r.body,
            cookies: r.cookies,
        }
    }

    /// 在 body 上加一个 `cookie` 字段（**字符串**，`;` 连接）
    ///
    /// 对应 `{...result.body, cookie: result.cookie.join(';')}`。
    ///
    /// ⚠️ 登录族必须有这个字段，否则客户端报「登录成功但未获取到cookie」。
    pub fn with_cookie_field(r: ApiResponse) -> Self {
        let cookie = r.cookies.join(";");
        let mut body = r.body;

        if let Some(obj) = body.as_object_mut() {
            obj.insert("cookie".into(), json!(cookie));
        }

        Self {
            body,
            cookies: r.cookies,
        }
    }

    /// 把整个上游 body 包进 `data` 字段
    ///
    /// 对应 `{status: 200, body: {data: {...result.body}}}`。
    ///
    /// ⚠️ 只在上游 `code == 200` 时才包 —— 否则原样返回。
    pub fn wrap_data(r: ApiResponse) -> Self {
        if r.code() != Some(200) {
            return Self::passthrough(r);
        }

        let body = json!({ "data": r.body });
        Self {
            body,
            cookies: r.cookies,
        }
    }

    /// 序列化成 JSON 文本（供 FFI / HTTP 层使用）
    pub fn to_json(&self) -> String {
        self.body.to_string()
    }
}

/// 把 `a,b,c` 拆成 `[a, b, c]`（去掉空白段）
pub fn split_csv(s: &str) -> Vec<String> {
    s.split(',')
        .map(str::trim)
        .filter(|x| !x.is_empty())
        .map(str::to_string)
        .collect()
}

/// 拼上游 `song/detail` 的 `c` 参数：`[{"id":1},{"id":2}]`
///
/// ⚠️ 这是**字符串**，不是 JSON 数组 —— 服务端要的就是这个字面形态。
pub fn song_detail_c(ids: &[String]) -> String {
    let inner = ids
        .iter()
        .map(|id| format!(r#"{{"id":{id}}}"#))
        .collect::<Vec<_>>()
        .join(",");
    format!("[{inner}]")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn resp(body: Value, cookies: &[&str]) -> ApiResponse {
        ApiResponse {
            status: 200,
            body,
            cookies: cookies.iter().map(|s| s.to_string()).collect(),
        }
    }

    #[test]
    fn passthrough_keeps_body() {
        let s = ServerResponse::passthrough(resp(json!({"code": 200, "x": 1}), &[]));
        assert_eq!(s.body["x"], 1);
    }

    #[test]
    fn cookie_field_is_a_string() {
        let s = ServerResponse::with_cookie_field(resp(
            json!({"code": 200, "account": {"id": 42}}),
            &["MUSIC_U=abc", "__csrf=xyz"],
        ));
        assert_eq!(s.body["cookie"], "MUSIC_U=abc;__csrf=xyz");
        assert_eq!(s.body["account"]["id"], 42);
        assert_eq!(s.cookies.len(), 2);
    }

    #[test]
    fn wrap_data_only_on_success() {
        let ok = ServerResponse::wrap_data(resp(json!({"code": 200, "profile": {}}), &[]));
        assert_eq!(ok.body["data"]["profile"], json!({}));

        // 失败时不包
        let bad = ServerResponse::wrap_data(resp(json!({"code": 301, "msg": "需要登录"}), &[]));
        assert_eq!(bad.body["code"], 301);
        assert!(bad.body.get("data").is_none());
    }

    #[test]
    fn csv_splitting() {
        assert_eq!(split_csv("1,2,3"), vec!["1", "2", "3"]);
        assert_eq!(split_csv(" 1 , 2 "), vec!["1", "2"]);
        assert!(split_csv("").is_empty());
        assert_eq!(split_csv("1,,2"), vec!["1", "2"]);
    }

    #[test]
    fn song_detail_c_format() {
        assert_eq!(
            song_detail_c(&["1".into(), "2".into()]),
            r#"[{"id":1},{"id":2}]"#
        );
    }
}
