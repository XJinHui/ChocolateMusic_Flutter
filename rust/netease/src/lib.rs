//! # NetEaseCloud —— 网易云音乐 API 的本地 Rust 实现
//!
//! 把 [api-enhanced](https://github.com/neteasecloudmusicapienhanced/api)（Node.js 服务）
//! 里 `chocolate_music` 客户端实际用到的 **29 条路由**搬到本地：
//! **直连网易云上游**，自己完成参数组装、`weapi`/`eapi`/`xeapi` 加密与 Cookie 管理，
//! 不再需要中间服务器。
//!
//! ## 与 Node 实现的对应关系
//!
//! | Node | 本 crate |
//! | --- | --- |
//! | `util/crypto.js` | [`crypto`] + [`protocol`] |
//! | `util/index.js` 的 `processCookieObject` | [`cookie`] |
//! | `util/request.js` | [`request`] |
//! | `module/*.js`（29 个） | [`api`] |
//! | `server.js` 的路由分发 | [`raw`] |
//!
//! ## 快速开始
//!
//! ```no_run
//! use netease::NetEaseClient;
//!
//! # async fn run() -> Result<(), netease::Error> {
//! let client = NetEaseClient::with_identity_file("netease_identity.json");
//!
//! // 取播放地址（未登录也能拿到部分歌曲）
//! let url = client.song_url_str("", "347230").await?;
//! println!("{url}");
//!
//! // 或者按原服务器路由直通（供 Dart 侧无改动迁移）
//! let mut q = std::collections::HashMap::new();
//! q.insert("ids".to_string(), "347230".to_string());
//! let json = client.raw_request("/song/detail".into(), q, String::new()).await?;
//! # Ok(()) }
//! ```
//!
//! ## ⚠️ 两处与 Node 实现的**有意偏离**
//!
//! 1. **设备身份持久化**。Node 版每次启动都随机生成 `deviceId`，这是最明显的风控特征。
//!    本实现把它存进身份文件，重启不变。
//! 2. **不使用 xeapi 会话轮换**。Node 版把 `xeapiSessionId/Key` 放在进程级全局，
//!    多账号并发会串（其缺陷 #6）。本实现每次请求用随机 `dynamicKey`，
//!    代价是多一次 ECDH（约 0.1ms），换来无跨账号污染。

// ⚠️ 由 flutter_rust_bridge 生成，勿删。
// 注意：FRB 会把它注入到第 1 行，那样会插在 `//!` 文档注释之前导致解析失败，
// 因此每次 generate 后需确认它仍在**模块声明区**而非文件开头。
mod frb_generated;

pub mod anticheat;
pub mod api;
pub mod client;
pub mod frb_api;
pub mod cookie;
pub mod crypto;
pub mod device;
pub mod protocol;
pub mod xeapi;
pub mod raw;
pub mod request;

pub use api::{ServerRequest, ServerResponse};
pub use client::NetEaseClient;
pub use device::DeviceIdentity;
pub use request::{ApiResponse, RequestOptions, Transport};

/// 加密方案
///
/// 对应 `util/request.js` 里 `crypto` 参数的取值。精简版只用得到前三种；
/// `api` / `linuxapi` 无路由使用。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Crypto {
    /// 双层 AES-CBC + 无填充 RSA（14/29 条路由）
    Weapi,
    /// AES-ECB + MD5 摘要（11/29 条路由）
    Eapi,
    /// X25519 + AES-GCM（3/29 条路由，广告免费听）
    Xeapi,
}

impl Crypto {
    /// 对应的上游域名
    pub fn domain(self) -> &'static str {
        match self {
            Crypto::Weapi => request::DOMAIN,
            Crypto::Eapi => request::EAPI_DOMAIN,
            Crypto::Xeapi => request::XEAPI_DOMAIN,
        }
    }

    /// URL 前缀，如 `weapi` / `eapi` / `xeapi`
    pub fn path_prefix(self) -> &'static str {
        match self {
            Crypto::Weapi => "weapi",
            Crypto::Eapi => "eapi",
            Crypto::Xeapi => "xeapi",
        }
    }
}

/// 查询参数（值统一为字符串）
///
/// 与 `serde_json::Map` 不同，这里不需要顺序保证 —— 顺序在组装 query string 时才重要。
pub type Query = std::collections::HashMap<String, String>;

/// 当前毫秒时间戳（对应 JS 的 `Date.now()`）
pub fn now_ms() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

/// 当前秒时间戳
pub fn now_secs() -> i64 {
    now_ms() / 1000
}

/// 统一 `Result`
pub type Result<T> = std::result::Result<T, Error>;

/// 统一错误
///
/// 字段刻意只用 `String` / 数字 —— 便于将来接 FFI 时直接映射。
#[derive(Debug, Clone, thiserror::Error)]
pub enum Error {
    /// 上游业务失败（`body.code != 200`）
    #[error("上游返回失败: {message}")]
    Api {
        /// 错误描述
        message: String,
        /// 上游 `code`
        code: Option<i64>,
        /// 归一化后的状态码（`502` 表示上游业务失败）
        status: u16,
        /// 完整响应体（JSON 文本，便于排查）
        body: String,
    },

    /// 网络错误
    #[error("网络错误: {0}")]
    Http(String),

    /// JSON 解析错误
    #[error("JSON 错误: {0}")]
    Json(String),

    /// 加密 / 解密错误
    #[error("加密错误: {0}")]
    Crypto(String),

    /// IO 错误
    #[error("IO 错误: {0}")]
    Io(String),

    /// 参数缺失或非法
    #[error("参数错误: {0}")]
    Invalid(String),

    /// 需要登录
    #[error("需要登录")]
    NotLoggedIn,
}

impl Error {
    /// 上游给的可读消息（若有）
    pub fn api_message(&self) -> Option<&str> {
        match self {
            Error::Api { message, .. } => Some(message),
            _ => None,
        }
    }

    /// 上游 `code`
    pub fn api_code(&self) -> Option<i64> {
        match self {
            Error::Api { code, .. } => *code,
            _ => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn error_exposes_api_fields() {
        let e = Error::Api {
            message: "需要登录".into(),
            code: Some(301),
            status: 502,
            body: "{}".into(),
        };
        assert_eq!(e.api_message(), Some("需要登录"));
        assert_eq!(e.api_code(), Some(301));

        assert!(Error::NotLoggedIn.api_message().is_none());
    }
}
