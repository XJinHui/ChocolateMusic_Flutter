//! 业务接口
//!
//! 每个子模块对应 `KuGou.dart` 里的一组方法。函数签名与 Dart 侧一一对应，
//! 但把「HTTP 请求」换成了「函数调用」。

pub mod album;
pub mod artist;
pub mod login;
pub mod playlist;
pub mod recommend;
pub mod search;
pub mod song;
pub mod user;
pub mod user_vip;

pub use login::{LoginResult, QrStatus};
pub use playlist::TrackItem;
pub use song::LyricCandidate;
