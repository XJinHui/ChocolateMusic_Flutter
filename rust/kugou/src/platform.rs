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

    /// 解析字符串（`"lite"` → `Lite`，其余 → `Standard`）
    pub fn parse(s: &str) -> Self {
        if s.eq_ignore_ascii_case("lite") {
            Platform::Lite
        } else {
            Platform::Standard
        }
    }
}
