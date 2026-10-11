//! 设备身份（**持久化**）
//!
//! 对应 Node 实现里散落在 `util/request.js` 顶部与 `global.deviceId` 的那几项：
//!
//! | 字段 | Node 来源 | 形态 |
//! | --- | --- | --- |
//! | `device_id` | `global.deviceId`（`generateDeviceId()`） | 52 个**大写 hex** 字符 |
//! | `wnmcid` | `WNMCID`（模块加载时算一次） | `<6 个小写字母>.<毫秒>.01.0` |
//! | `ntes_nuid` | `CryptoJS.lib.WordArray.random(32)` | 64 个小写 hex 字符 |
//! | `ntes_nnid` | `` `${_ntes_nuid},${now()}` `` | 逗号分隔 |
//! | `music_a` | `anonymous_token` 文件 | 匿名注册得到的 token |
//!
//! ## ⚠️ 与 Node 实现的**有意偏离**
//!
//! 原版每次启动都重新生成 `deviceId`（`generateConfig.js` 写 `global.deviceId`），
//! 这是最明显的风控特征。本实现把它**持久化到身份文件**，重启不变。

use serde::{Deserialize, Serialize};
use std::path::Path;

use crate::crypto::{random_hex_lower, random_hex_upper, random_lower_alpha};
use crate::{now_ms, Error, Result};

/// 设备身份
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct DeviceIdentity {
    /// 52 个**大写** hex 字符
    #[serde(default)]
    pub device_id: String,

    /// `<6 个小写字母>.<毫秒>.01.0`
    #[serde(default)]
    pub wnmcid: String,

    /// 64 个小写 hex 字符（32 随机字节）
    #[serde(default)]
    pub ntes_nuid: String,

    /// `"{ntes_nuid},{毫秒}"`
    #[serde(default)]
    pub ntes_nnid: String,

    /// 匿名注册得到的 `MUSIC_A`；未注册时为空
    #[serde(default)]
    pub music_a: String,
}

impl DeviceIdentity {
    /// 生成一份全新的设备身份
    pub fn generate() -> Self {
        let ntes_nuid = random_hex_lower(64);
        let now = now_ms();

        Self {
            device_id: random_hex_upper(52),
            // ⚠️ 原版是 `<6 个小写字母>.<毫秒>.01.0`，不是随机数字
            wnmcid: format!("{}.{now}.01.0", random_lower_alpha(6)),
            ntes_nnid: format!("{ntes_nuid},{now}"),
            ntes_nuid,
            music_a: String::new(),
        }
    }

    /// 从身份文件加载；文件不存在或损坏则生成一份并写回
    pub fn load_or_create(path: impl AsRef<Path>) -> Self {
        let path = path.as_ref();

        let identity = std::fs::read_to_string(path)
            .ok()
            .and_then(|t| serde_json::from_str::<Self>(&t).ok())
            .filter(|d| !d.device_id.is_empty())
            .unwrap_or_else(Self::generate);

        let _ = identity.save(path);
        identity
    }

    /// 写入身份文件
    pub fn save(&self, path: impl AsRef<Path>) -> Result<()> {
        let text = serde_json::to_string_pretty(self).map_err(|e| Error::Json(e.to_string()))?;
        std::fs::write(path, text).map_err(|e| Error::Io(e.to_string()))
    }

    /// 是否已拿到匿名 token
    pub fn has_music_a(&self) -> bool {
        !self.music_a.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn generated_fields_have_expected_shape() {
        let d = DeviceIdentity::generate();

        assert_eq!(d.device_id.len(), 52);
        assert!(d.device_id.chars().all(|c| c.is_ascii_hexdigit()));
        assert_eq!(d.device_id, d.device_id.to_uppercase());

        assert_eq!(d.ntes_nuid.len(), 64);
        assert!(d.ntes_nuid.chars().all(|c| c.is_ascii_hexdigit()));
        assert_eq!(d.ntes_nuid, d.ntes_nuid.to_lowercase());

        // wnmcid = "<6 小写字母>.<毫秒>.01.0"
        let parts: Vec<&str> = d.wnmcid.split('.').collect();
        assert_eq!(parts.len(), 4);
        assert_eq!(parts[0].len(), 6);
        assert!(parts[0].chars().all(|c| c.is_ascii_lowercase()));
        assert!(parts[1].parse::<i64>().unwrap() > 1_600_000_000_000);
        assert_eq!(parts[2], "01");
        assert_eq!(parts[3], "0");

        assert!(d.ntes_nnid.starts_with(&d.ntes_nuid));
        assert!(d.ntes_nnid.ends_with(&parts[1]));

        assert!(!d.has_music_a());
    }

    #[test]
    fn roundtrips_through_file() {
        let path = std::env::temp_dir().join("netease_identity_unit_test.json");
        let _ = std::fs::remove_file(&path);

        let a = DeviceIdentity::load_or_create(&path);
        let b = DeviceIdentity::load_or_create(&path);

        // 第二次必须读到同一份（这正是「持久化」的意义）
        assert_eq!(a.device_id, b.device_id);
        assert_eq!(a.wnmcid, b.wnmcid);

        let _ = std::fs::remove_file(&path);
    }
}
