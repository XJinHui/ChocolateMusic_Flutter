//! # KuGou —— 酷狗音乐 API 的本地 Rust 实现
//!
//! 把 `KuGouMusicApi`（Node.js 服务）的功能搬到本地：**直连酷狗上游**，自己完成
//! 参数注入、签名、加解密，不再需要中间服务器。
//!
//! ## 快速开始
//!
//! ```no_run
//! use kugou::{KuGouClient, Platform, QrStatus};
//!
//! # async fn run() -> Result<(), kugou::Error> {
//! let mut client = KuGouClient::with_identity_file(Platform::Lite, "kugou_identity.json");
//!
//! // 1. 获取设备指纹（首次运行必须）
//! client.register_device().await?;
//!
//! // 2. 二维码登录
//! let (key, _img) = client.qr_key().await?;
//! loop {
//!     match client.qr_check(&key).await? {
//!         QrStatus::Success { .. } => {
//!             // qr_login_wait 内部会处理凭据写入
//!             break;
//!         }
//!         QrStatus::Expired => break,
//!         _ => tokio::time::sleep(std::time::Duration::from_secs(2)).await,
//!     }
//! }
//!
//! // 3. 搜索并取播放地址
//! let result = client.search_with_details("海阔天空").await?;
//! if let Some(song) = result.music.first() {
//!     let url = client.get_music_url(&song.id, "128").await?;
//!     println!("{url}");
//! }
//! # Ok(())
//! # }
//! ```
//!
//! ## 模块结构
//!
//! | 模块 | 职责 |
//! | --- | --- |
//! | [`crypto`] | MD5 / AES-CBC / RSA（裸、PKCS#1 v1.5） |
//! | [`sign`] | 全部签名函数 |
//! | [`device`] | 设备身份与持久化 |
//! | [`platform`] | 标准版 / 概念版配置 |
//! | [`request`] | 请求层（参数注入、签名、发送、响应归一化） |
//! | [`api`] | 各业务接口 |
//! | [`client`] | [`KuGouClient`] 门面 |
//! | [`models`] | 数据类型 |
//! | [`lyric`] | 歌词处理 |

pub mod api;
pub mod client;
pub mod frb_api;
pub mod crypto;
pub mod device;
pub mod lyric;
pub mod models;
pub mod platform;
pub mod raw;
pub mod request;
pub mod sign;

pub use api::login::QrStatus;
pub use client::KuGouClient;
pub use device::DeviceIdentity;
pub use models::{Album, KugouData, MatchInfo, Music, Playlist, SearchResult, Singer};
pub use platform::Platform;
pub use request::{Account, ApiResponse, EncryptType, Method, RequestOptions, ResponseType};

// ============================================================
//  错误
// ============================================================

/// 统一错误类型
///
/// ⚠️ 所有变体都只含 `String` / 数字 / `Option` —— 这是为了能被
/// **flutter_rust_bridge** 镜像成 Dart 异常类。若在此加入 `reqwest::Error`
/// 之类的外部类型，FFI 生成会失败。
#[derive(Debug, Clone, thiserror::Error)]
pub enum Error {
    /// 上游业务失败（`status: 0` 或 `error_code != 0`）
    #[error("上游返回失败: {message}")]
    Api {
        /// 错误描述（`error_msg` / `msg` / `error`）
        message: String,
        /// `error_code`
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

    /// 加密错误
    #[error("加密错误: {0}")]
    Crypto(String),

    /// IO 错误
    #[error("IO 错误: {0}")]
    Io(String),

    /// 参数缺失或非法
    #[error("参数错误: {0}")]
    Invalid(String),

    /// 未登录
    #[error("需要登录")]
    NotLoggedIn,
}

impl Error {
    /// 由 [`ApiResponse`] 构造
    pub fn from_api(resp: ApiResponse) -> Self {
        let pick = |k: &str| {
            resp.body
                .get(k)
                .and_then(|v| v.as_str())
                .map(str::to_string)
        };
        let message = pick("error_msg")
            .or_else(|| pick("msg"))
            .or_else(|| pick("error"))
            .unwrap_or_else(|| "未知错误".to_string());

        Error::Api {
            message,
            code: resp.body.get("error_code").and_then(|v| v.as_i64()),
            status: resp.status,
            body: resp.body.to_string(),
        }
    }

    /// 若是上游业务失败，取出错误消息
    pub fn api_message(&self) -> Option<String> {
        match self {
            Error::Api { message, .. } => Some(message.clone()),
            _ => None,
        }
    }

    /// 若是上游业务失败，取出 `error_code`
    pub fn api_code(&self) -> Option<i64> {
        match self {
            Error::Api { code, .. } => *code,
            _ => None,
        }
    }

    /// 若是上游业务失败，把响应体解析成 JSON
    pub fn api_body(&self) -> Option<serde_json::Value> {
        match self {
            Error::Api { body, .. } => serde_json::from_str(body).ok(),
            _ => None,
        }
    }

    pub fn invalid(msg: impl Into<String>) -> Self {
        Error::Invalid(msg.into())
    }
}

impl From<reqwest::Error> for Error {
    fn from(e: reqwest::Error) -> Self {
        Error::Http(e.to_string())
    }
}

impl From<serde_json::Error> for Error {
    fn from(e: serde_json::Error) -> Self {
        Error::Json(e.to_string())
    }
}

impl From<crypto::CryptoError> for Error {
    fn from(e: crypto::CryptoError) -> Self {
        Error::Crypto(e.to_string())
    }
}

impl From<std::io::Error> for Error {
    fn from(e: std::io::Error) -> Self {
        Error::Io(e.to_string())
    }
}

/// 便捷 `Result`
pub type Result<T> = std::result::Result<T, Error>;
