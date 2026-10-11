//! 平台配置
//!
//! 原项目通过全局环境变量 `process.env.platform` 判断平台，导致同一进程无法同时服务
//! 标准版与概念版。这里改为**显式值对象**，随 `KuGouClient` 实例传递。

use crate::crypto::{PUBLIC_LITE_RSA_KEY, PUBLIC_RSA_KEY};

/// 酷狗客户端平台
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum Platform {
    /// 标准版（手机版）
    Standard,
    /// 概念版（Young / lite）
    #[default]
    Lite,
}

impl Platform {
    /// `appid`
    pub const fn appid(self) -> u32 {
        match self {
            Platform::Standard => 1005,
            Platform::Lite => 3116,
        }
    }

    /// `clientver`
    pub const fn clientver(self) -> u32 {
        match self {
            Platform::Standard => 20489,
            Platform::Lite => 11440,
        }
    }

    /// Android 签名盐值（同时也是 cloudlist 的 appkey）
    pub const fn android_salt(self) -> &'static str {
        match self {
            Platform::Standard => "OIlwieks28dk2k092lksi2UIkp",
            Platform::Lite => "LnT6xpN3khm36zse0QzvmgTZ3waWdRSA",
        }
    }

    /// `signKey` 的盐值
    pub const fn sign_key_salt(self) -> &'static str {
        match self {
            Platform::Standard => "57ae12eb6890223e355ccfcb74edf70d",
            Platform::Lite => "185672dd44712f60bb1736df5a377e82",
        }
    }

    /// cloudlist 通道的 appkey
    pub const fn cloudlist_appkey(self) -> &'static str {
        self.android_salt()
    }

    /// 1024-bit RSA 公钥（PEM）
    pub const fn rsa_public_key(self) -> &'static str {
        match self {
            Platform::Standard => PUBLIC_RSA_KEY,
            Platform::Lite => PUBLIC_LITE_RSA_KEY,
        }
    }

    /// 默认 `User-Agent`
    ///
    /// ⚠️ 原实现里 UA **不随平台变化**，即使概念版也用 Android15 的 UA。
    pub const fn user_agent(self) -> &'static str {
        "Android15-1070-11083-46-0-DiscoveryDRADProtocol-wifi"
    }

    /// 解析字符串（`"lite"` → `Lite`，其余含空串 → `Standard`）
    ///
    /// ⚠️ **空串映射到 `Standard`**，与原项目 `.env` 的默认值一致
    /// （`KuGouMusicApi/.env.example` 里 `platform=''`，注释写「默认为手机版」）。
    /// 注意这与 [`Platform::default`] 的 `Lite` **不同** —— 那个是给
    /// 「没显式指定平台」的 Rust 调用方用的默认值。
    pub fn parse(s: &str) -> Self {
        if s.eq_ignore_ascii_case("lite") {
            Platform::Lite
        } else {
            Platform::Standard
        }
    }

    /// 从环境变量 `KUGOU_PLATFORM` 读平台
    ///
    /// 这是对原项目 `.env` 里 `platform=lite` 的等价物，但**只是 CLI 的便利入口** ——
    /// 库本身把平台做成随客户端实例传递的值对象，所以同一进程可以同时跑两个平台。
    ///
    /// ⚠️ 与原项目不同：原项目 `process.env.platform` 是**全局**的，一个进程只能是一种。
    /// 未设置时返回 [`Platform::Lite`]（与原部署一致），而不是 `Standard`。
    pub fn from_env() -> Self {
        match std::env::var("KUGOU_PLATFORM") {
            Ok(s) if !s.trim().is_empty() => Self::parse(s.trim()),
            _ => Platform::Lite,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_maps_empty_to_standard() {
        // 与原项目 .env 默认值一致
        assert_eq!(Platform::parse(""), Platform::Standard);
        assert_eq!(Platform::parse("standard"), Platform::Standard);
        assert_eq!(Platform::parse("LITE"), Platform::Lite);
        assert_eq!(Platform::parse("lite"), Platform::Lite);
    }

    #[test]
    fn default_is_lite() {
        assert_eq!(Platform::default(), Platform::Lite);
    }

    #[test]
    fn platform_constants_differ() {
        // 两个平台的所有常量都必须不同 —— 否则切换平台就失去意义了
        assert_ne!(Platform::Lite.appid(), Platform::Standard.appid());
        assert_ne!(Platform::Lite.clientver(), Platform::Standard.clientver());
        assert_ne!(Platform::Lite.android_salt(), Platform::Standard.android_salt());
        assert_ne!(Platform::Lite.sign_key_salt(), Platform::Standard.sign_key_salt());
        assert_ne!(
            Platform::Lite.rsa_public_key(),
            Platform::Standard.rsa_public_key()
        );
    }
}
