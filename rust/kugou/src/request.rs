//! 请求层
//!
//! 复刻 `KuGouMusicApi/util/request.js` 的 `createRequest`：注入设备标识与默认参数、
//! 计算签名、发送请求、归一化响应。

use crate::crypto::random_string;
use crate::device::DeviceIdentity;
use crate::platform::Platform;
use crate::sign::{
    sign_key, signature_android_params, signature_register_params, signature_web_params, Params,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::BTreeMap;

/// 默认网关
pub const DEFAULT_BASE_URL: &str = "https://gateway.kugou.com";

// ============================================================
//  账号凭据
// ============================================================

/// 账号级凭据（与设备身份分离）
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Account {
    #[serde(default)]
    pub token: String,
    #[serde(default)]
    pub userid: String,
    #[serde(default)]
    pub vip_token: String,
    #[serde(default)]
    pub vip_type: i64,
    /// 手机验证码登录返回的会话标记
    #[serde(default)]
    pub t1: String,
    /// 歌曲授权串（`/song/auth` 或 `/user/verify` 返回）
    #[serde(default)]
    pub auth: String,
}

impl Account {
    pub fn is_logged_in(&self) -> bool {
        !self.token.is_empty() && !self.userid.is_empty() && self.userid != "0"
    }
}

// ============================================================
//  请求配置
// ============================================================

/// 签名类型
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum EncryptType {
    /// Android 版（默认，最常用）
    #[default]
    Android,
    /// Web 版
    Web,
    /// 设备注册
    Register,
}

/// 响应类型
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum ResponseType {
    /// 按 JSON 解析
    #[default]
    Json,
    /// 保留原始字节（AES 类接口自行解密）
    Bytes,
}

/// HTTP 方法
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum Method {
    #[default]
    Get,
    Post,
}

/// 单次请求的配置
#[derive(Debug, Clone, Default)]
pub struct RequestOptions {
    pub method: Method,
    /// 上游路径，如 `/v2/search/song`
    pub url: String,
    /// 目标域名，缺省为 [`DEFAULT_BASE_URL`]
    pub base_url: Option<String>,
    /// 业务参数（会与默认参数合并）
    pub params: Params,
    /// 请求体（已序列化的字节）
    pub data: Option<Vec<u8>>,
    /// 额外请求头
    pub headers: Vec<(String, String)>,
    pub encrypt_type: EncryptType,
    /// 是否生成 `params.key`（`signKey`）
    pub encrypt_key: bool,
    /// 不注入默认参数
    pub clear_default_params: bool,
    /// 只用 `headers` 里声明的头
    pub clear_default_headers: bool,
    /// 跳过签名
    pub not_signature: bool,
    pub response_type: ResponseType,
    /// 强制覆盖本次请求的 `dfid`
    ///
    /// 原项目里 `captcha_sent` 等接口的 cookie 只带 `mid`，导致 `dfid` 退化为 `-`。
    /// 为保持协议一致，这些接口需要显式指定。
    pub dfid_override: Option<String>,
}

impl RequestOptions {
    pub fn new(url: impl Into<String>) -> Self {
        Self {
            url: url.into(),
            ..Default::default()
        }
    }

    pub fn get(url: impl Into<String>) -> Self {
        Self::new(url)
    }

    pub fn post(url: impl Into<String>) -> Self {
        Self {
            method: Method::Post,
            ..Self::new(url)
        }
    }

    pub fn base_url(mut self, b: impl Into<String>) -> Self {
        self.base_url = Some(b.into());
        self
    }

    pub fn param(mut self, k: impl Into<String>, v: impl Into<Value>) -> Self {
        self.params.insert(k.into(), v.into());
        self
    }

    /// 仅当 `Some` 时插入
    pub fn param_opt<V: Into<Value>>(mut self, k: impl Into<String>, v: Option<V>) -> Self {
        if let Some(v) = v {
            self.params.insert(k.into(), v.into());
        }
        self
    }

    pub fn params(mut self, pairs: impl IntoIterator<Item = (String, Value)>) -> Self {
        self.params.extend(pairs);
        self
    }

    pub fn json_body(mut self, v: &Value) -> Self {
        self.data = Some(v.to_string().into_bytes());
        self
    }

    pub fn body_bytes(mut self, b: Vec<u8>) -> Self {
        self.data = Some(b);
        self
    }

    pub fn header(mut self, k: impl Into<String>, v: impl Into<String>) -> Self {
        self.headers.push((k.into(), v.into()));
        self
    }

    pub fn router(self, host: impl Into<String>) -> Self {
        self.header("x-router", host)
    }

    pub fn encrypt_type(mut self, t: EncryptType) -> Self {
        self.encrypt_type = t;
        self
    }

    pub fn encrypt_key(mut self, yes: bool) -> Self {
        self.encrypt_key = yes;
        self
    }

    pub fn clear_default_params(mut self, yes: bool) -> Self {
        self.clear_default_params = yes;
        self
    }

    pub fn clear_default_headers(mut self, yes: bool) -> Self {
        self.clear_default_headers = yes;
        self
    }

    pub fn not_signature(mut self, yes: bool) -> Self {
        self.not_signature = yes;
        self
    }

    pub fn response_type(mut self, t: ResponseType) -> Self {
        self.response_type = t;
        self
    }

    /// 强制本次请求的 `dfid`（如 `"-"`）
    pub fn dfid(mut self, d: impl Into<String>) -> Self {
        self.dfid_override = Some(d.into());
        self
    }
}

// ============================================================
//  响应
// ============================================================

/// 统一响应
#[derive(Debug, Clone)]
pub struct ApiResponse {
    /// `200` 表示业务成功；`502` 表示上游业务失败或网络错误
    pub status: u16,
    /// 解析后的响应体
    pub body: Value,
    /// 原始字节（二进制接口自行解密）
    pub raw: Vec<u8>,
    /// `Set-Cookie` 清洗后的列表
    pub cookies: Vec<String>,
    /// 上游返回的 `ssa-code`（需要二次验证时出现）
    pub ssa_code: Option<String>,
}

impl ApiResponse {
    pub fn ok(&self) -> bool {
        self.status == 200
    }

    /// 取 `data` 字段
    pub fn data(&self) -> &Value {
        self.body.get("data").unwrap_or(&Value::Null)
    }

    /// 取 `data` 下的字符串字段
    pub fn str_at(&self, path: &[&str]) -> Option<String> {
        let mut cur = &self.body;
        for p in path {
            cur = cur.get(*p)?;
        }
        match cur {
            Value::String(s) => Some(s.clone()),
            Value::Number(n) => Some(n.to_string()),
            _ => None,
        }
    }

    pub fn i64_at(&self, path: &[&str]) -> Option<i64> {
        let mut cur = &self.body;
        for p in path {
            cur = cur.get(*p)?;
        }
        match cur {
            Value::Number(n) => n.as_i64(),
            Value::String(s) => s.parse().ok(),
            _ => None,
        }
    }

    pub fn arr_at(&self, path: &[&str]) -> Vec<Value> {
        let mut cur = &self.body;
        for p in path {
            match cur.get(*p) {
                Some(v) => cur = v,
                None => return Vec::new(),
            }
        }
        cur.as_array().cloned().unwrap_or_default()
    }
}

// ============================================================
//  传输层
// ============================================================

/// 持有 reqwest 客户端与设备/账号状态，供 API 模块调用
pub struct Transport {
    pub http: reqwest::Client,
    pub platform: Platform,
    pub device: DeviceIdentity,
    pub account: Account,
}

impl Transport {
    pub fn new(platform: Platform, device: DeviceIdentity, account: Account) -> Self {
        let http = reqwest::Client::builder()
            .connect_timeout(std::time::Duration::from_secs(10))
            .timeout(std::time::Duration::from_secs(30))
            .build()
            .expect("构建 HTTP 客户端失败");
        Self {
            http,
            platform,
            device,
            account,
        }
    }

    /// 构造默认参数（对应 `request.js` 的 `defaultParams`）
    fn default_params(&self, clienttime: i64, dfid: &str) -> Params {
        let mut p = Params::new();
        p.insert("dfid".into(), Value::String(dfid.to_string()));
        p.insert("mid".into(), Value::String(self.device.mid.clone()));
        p.insert("uuid".into(), Value::String("-".into()));
        p.insert("appid".into(), Value::from(self.platform.appid()));
        p.insert("clientver".into(), Value::from(self.platform.clientver()));
        p.insert("clienttime".into(), Value::from(clienttime));

        // ⚠️ 只有账号里确实有凭据时才带上。
        //
        // 原实现是从 **Cookie** 取（`options.cookie.token`），而 Dart 客户端
        // 从不发 Cookie —— 所以对 KuGou.dart 的请求，这两个值只进 body、不进 query。
        // 但带上它们本身不影响上游校验（已实测），所以这里保持「有就带」。
        if !self.account.token.is_empty() {
            p.insert("token".into(), Value::String(self.account.token.clone()));
        }
        if !self.account.userid.is_empty() && self.account.userid != "0" {
            p.insert(
                "userid".into(),
                Value::String(self.account.userid.clone()),
            );
        }
        p
    }

    /// 当前 `dfid`，未注册时为 `-`
    pub fn dfid(&self) -> String {
        self.device
            .dfid
            .clone()
            .filter(|s| !s.is_empty())
            .unwrap_or_else(|| "-".to_string())
    }

    /// 构造基础请求头（对应 `request.js` 的 `headers`）
    fn base_headers(&self, clienttime: i64, dfid: &str) -> Vec<(String, String)> {
        vec![
            ("dfid".into(), dfid.to_string()),
            ("clienttime".into(), clienttime.to_string()),
            ("mid".into(), self.device.mid.clone()),
            ("kg-rc".into(), "1".into()),
            ("kg-thash".into(), "5d816a0".into()),
            ("kg-rec".into(), "1".into()),
            (
                "kg-rf".into(),
                "B9EDA08A64250DEFFBCADDEE00F8F25F".into(),
            ),
        ]
    }

    /// 发送请求，完整复刻 `createRequest`
    pub async fn send(&self, opt: RequestOptions) -> Result<ApiResponse, crate::Error> {
        let clienttime = now_secs();
        let dfid = opt.dfid_override.clone().unwrap_or_else(|| self.dfid());

        // ⑤ 合并默认参数
        let mut params = if opt.clear_default_params {
            opt.params.clone()
        } else {
            let mut merged = self.default_params(clienttime, &dfid);
            merged.extend(opt.params.clone());
            merged
        };

        // ⑥ signKey
        if opt.encrypt_key {
            let hash = params
                .get("hash")
                .map(crate::sign::js_value_to_string)
                .unwrap_or_default();
            let mid = params
                .get("mid")
                .map(crate::sign::js_value_to_string)
                .unwrap_or_default();
            let userid = params
                .get("userid")
                .map(crate::sign::js_value_to_string)
                .unwrap_or_default();
            let appid = params
                .get("appid")
                .and_then(|v| v.as_u64())
                .map(|v| v as u32);
            params.insert(
                "key".into(),
                Value::String(sign_key(self.platform, &hash, &mid, &userid, appid)),
            );
        }

        // ⑦ 请求体字节（仅用于签名）
        let body_bytes = opt.data.clone().unwrap_or_default();

        // ⑧ 签名
        if !params.contains_key("signature") && !opt.not_signature {
            let sig = match opt.encrypt_type {
                EncryptType::Register => signature_register_params(&params),
                EncryptType::Web => signature_web_params(&params, &body_bytes),
                EncryptType::Android => {
                    signature_android_params(self.platform, &params, &body_bytes)
                }
            };
            params.insert("signature".into(), Value::String(sig));
        }

        // ⑨ 组装
        //
        // `KUGOU_BASE_URL` 可覆盖目标域名 —— 排障用：指向本地回显服务器就能
        // 抓到 Rust 实际发出的原始 HTTP 请求，再和原 Node 服务的对比。
        let base_url = std::env::var("KUGOU_BASE_URL")
            .ok()
            .filter(|s| !s.is_empty())
            .or_else(|| opt.base_url.clone())
            .unwrap_or_else(|| DEFAULT_BASE_URL.to_string());
        let url = format!("{}{}", base_url.trim_end_matches('/'), opt.url);

        let mut req = self.http.request(
            match opt.method {
                Method::Get => reqwest::Method::GET,
                Method::Post => reqwest::Method::POST,
            },
            &url,
        );

        if opt.clear_default_headers {
            for (k, v) in &opt.headers {
                req = req.header(k, v);
            }
        } else {
            req = req.header("User-Agent", self.platform.user_agent());
            for (k, v) in &opt.headers {
                req = req.header(k, v);
            }
            for (k, v) in self.base_headers(clienttime, &dfid) {
                req = req.header(k, v);
            }
        }

        // ⚠️ 必须显式设置。
        //
        // axios 在 `data` 是对象时会自动带上 `Content-Type: application/json`，
        // 而 reqwest 对 `Vec<u8>` 请求体**不会**自动加。
        // 缺了它上游可能不解析 body，导致签名（覆盖 body 文本）对不上 ——
        // 表现就是 `error_code: 20006`（err signature）。
        if opt.data.is_some() {
            req = req.header("Content-Type", "application/json");
        }

        // query 参数：全部转成字符串
        let query: Vec<(String, String)> = params
            .iter()
            .map(|(k, v)| (k.clone(), crate::sign::js_value_to_string(v)))
            .collect();
        req = req.query(&query);

        if let Some(data) = &opt.data {
            req = req.body(data.clone());
        }

        // 调试：`KUGOU_DEBUG=1` 时把实际发出去的请求打出来
        //
        // 排查 `error_code: 20006`（err signature）时很有用 —— 对照原 Node 服务
        // 发出的同一条请求，逐字段比对 query 与 body。
        if std::env::var("KUGOU_DEBUG").is_ok() {
            eprintln!("┌─ KuGou 请求 ─────────────────────────────");
            eprintln!("│ {url}");
            eprintln!("│ query:");
            for (k, v) in &query {
                eprintln!("│   {k} = {v}");
            }
            match &opt.data {
                Some(d) => eprintln!("│ body: {}", String::from_utf8_lossy(d)),
                None => eprintln!("│ body: (空)"),
            }
            eprintln!("└──────────────────────────────────────────");
        }

        // ⑬ 发送
        let resp = match req.send().await {
            Ok(r) => r,
            Err(e) => {
                return Ok(ApiResponse {
                    status: 502,
                    body: serde_json::json!({ "status": 0, "msg": e.to_string() }),
                    raw: Vec::new(),
                    cookies: Vec::new(),
                    ssa_code: None,
                });
            }
        };

        let ssa_code = resp
            .headers()
            .get("ssa-code")
            .or_else(|| resp.headers().get("SSA-CODE"))
            .and_then(|v| v.to_str().ok())
            .map(str::to_string);

        let cookies: Vec<String> = resp
            .headers()
            .get_all(reqwest::header::SET_COOKIE)
            .iter()
            .filter_map(|v| v.to_str().ok())
            .map(parse_cookie_string)
            .collect();

        let raw = resp.bytes().await.map(|b| b.to_vec()).unwrap_or_default();

        // 业务状态判定（与原实现一致：看原始响应里的 status / error_code）
        let (body, parse_failed) = if opt.response_type == ResponseType::Bytes {
            (Value::Null, false)
        } else {
            match serde_json::from_slice::<Value>(&raw) {
                Ok(v) => (v, false),
                Err(_) => {
                    // 酷狗对未认证请求会把 JSON 包在 HTML 注释里：
                    //   <!--KG_TAG_RES_START-->{...}<!--KG_TAG_RES_END-->
                    // 先剥掉再解析，否则会被静默当成「成功但无数据」。
                    match strip_html_wrapper(&raw).and_then(|b| serde_json::from_slice::<Value>(&b).ok()) {
                        Some(v) => (v, false),
                        None => (Value::Null, !raw.is_empty()),
                    }
                }
            }
        };

        let failed = body.get("status").and_then(|v| v.as_i64()) == Some(0)
            || body
                .get("error_code")
                .map(|v| {
                    let n = match v {
                        Value::Number(n) => n.as_i64().unwrap_or(0),
                        Value::String(s) => s.parse().unwrap_or(0),
                        _ => 0,
                    };
                    n != 0
                })
                .unwrap_or(false)
            // 非空响应体但无法解析为 JSON：视为失败，避免静默丢数据
            || parse_failed;

        let status = if failed { 502 } else { 200 };

        let resp = ApiResponse {
            status,
            body,
            raw,
            cookies,
            ssa_code,
        };

        if resp.status == 200 {
            Ok(resp)
        } else {
            Err(crate::Error::from_api(resp))
        }
    }

    /// 便捷方法：GET + JSON
    pub async fn get_json(&self, opt: RequestOptions) -> Result<ApiResponse, crate::Error> {
        self.send(opt).await
    }

    /// 发一次请求并返回**原始响应体**，不做业务状态判定
    ///
    /// 与原服务器一致：业务失败（`status: 0` / `error_code != 0`）也照常把响应体
    /// 返回，由调用方自己判断。只有网络层错误才返回 `Err`。
    ///
    /// 供 [`crate::raw`] 透传用 —— `KuGou.dart` 里到处是
    /// `response.data["status"] != 1` 这种判断，必须拿到原始体才做得了。
    pub async fn send_raw(&self, opt: RequestOptions) -> Result<Value, crate::Error> {
        match self.send(opt).await {
            Ok(r) => Ok(r.body),
            Err(e) => recover_body(e),
        }
    }
}

/// 从 [`crate::Error::Api`] 里取回响应体（原服务器会照常返回它）
///
/// 业务失败在 [`Transport::send`] 里被转成了 `Err`，但响应体原样保存在
/// `Error::Api.body` 中，这里解回来。非业务错误（网络等）继续向上抛。
pub fn recover_body(e: crate::Error) -> Result<Value, crate::Error> {
    match e {
        crate::Error::Api { body, .. } => Ok(serde_json::from_str(&body).unwrap_or_else(|_| {
            serde_json::json!({ "status": 0, "error_code": -1, "error_msg": body })
        })),
        other => Err(other),
    }
}

// ============================================================
//  工具
// ============================================================

/// 当前秒级时间戳
pub fn now_secs() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

/// 当前毫秒级时间戳
pub fn now_millis() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

/// 剥离酷狗的 HTML 注释包裹
///
/// 未认证请求的响应形如：
/// ```text
/// <!--KG_TAG_RES_START-->{"status":1,"error_code":152,...}<!--KG_TAG_RES_END-->
/// ```
/// `Content-Type` 仍是 `application/json`，直接解析会失败。
pub fn strip_html_wrapper(raw: &[u8]) -> Option<Vec<u8>> {
    const START: &str = "<!--KG_TAG_RES_START-->";
    const END: &str = "<!--KG_TAG_RES_END-->";

    let text = std::str::from_utf8(raw).ok()?;
    let s = text.find(START)?;
    let body_start = s + START.len();
    let body_end = text[body_start..]
        .find(END)
        .map(|i| body_start + i)
        .unwrap_or(text.len());
    Some(text[body_start..body_end].trim().as_bytes().to_vec())
}

/// 清洗 `Set-Cookie`：剥离 `Domain`/`path`/`expires` 与 `;HttpOnly`
///
/// 对应 `util/util.js` 的 `parseCookieString`
pub fn parse_cookie_string(cookie: &str) -> String {
    let mut out = cookie.to_string();
    // 逐段过滤属性
    let parts: Vec<&str> = out.split(';').collect();
    let kept: Vec<String> = parts
        .iter()
        .filter_map(|p| {
            let t = p.trim();
            if t.is_empty() {
                return None;
            }
            let lower = t.to_ascii_lowercase();
            if lower.starts_with("domain=")
                || lower.starts_with("path=")
                || lower.starts_with("expires=")
                || lower.starts_with("max-age=")
                || lower == "httponly"
                || lower == "secure"
                || lower.starts_with("samesite=")
            {
                return None;
            }
            Some(t.to_string())
        })
        .collect();
    out = kept.join("; ");
    out
}

/// 生成随机 dfid（24 位）
pub fn random_dfid() -> String {
    random_string(24).to_lowercase()
}

/// 便捷构造参数表
pub fn params_from(pairs: impl IntoIterator<Item = (&'static str, Value)>) -> Params {
    pairs.into_iter().map(|(k, v)| (k.to_string(), v)).collect()
}

/// 便捷：从 `BTreeMap` 构造
pub fn p() -> Params {
    BTreeMap::new()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cookie_cleaning() {
        let c = "token=abc; Domain=.kugou.com; path=/; HttpOnly";
        assert_eq!(parse_cookie_string(c), "token=abc");
    }

    #[test]
    fn cookie_keeps_multiple_pairs() {
        let c = "token=abc; userid=1; Path=/";
        assert_eq!(parse_cookie_string(c), "token=abc; userid=1");
    }
}
