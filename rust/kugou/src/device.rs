//! 设备身份
//!
//! 酷狗的风控以「设备」为单位。原项目每次启动都随机生成 GUID，导致重启即变新设备、
//! `dfid` 失效、风控信誉归零。这里改为**可持久化**的身份。

use crate::crypto::{md5, random_string};
use rand::Rng;
use serde::{Deserialize, Serialize};
use std::path::Path;

/// 一组设备标识
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceIdentity {
    /// 32 位 hex。来源：UUID v4 的 MD5，或直接给定的 32 位 hex
    pub guid: String,
    /// 39 位十进制大数，由 `calculate_mid(guid)` 得出
    pub mid: String,
    /// 10 位大写开发设备标识
    pub dev: String,
    /// MAC 地址（大写）
    pub mac: String,
    /// WebGL 指纹（十进制字符串）
    pub webgl: String,
    /// 设备指纹 ID，由 `/register/dev` 获取。未注册时为 `None`
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub dfid: Option<String>,
}

impl Default for DeviceIdentity {
    fn default() -> Self {
        Self::generate()
    }
}

impl DeviceIdentity {
    /// 随机生成一套全新身份
    pub fn generate() -> Self {
        let guid = md5(uuid_v4());
        Self::from_guid(&guid)
    }

    /// 由已有的 GUID 构造（补全 mid / dev / mac / webgl）
    ///
    /// 若传入的是合法 UUID v4，会先取 MD5；否则视为 32 位 hex 原样使用。
    pub fn from_guid(guid: &str) -> Self {
        let guid = normalize_guid(guid);
        let mid = calculate_mid(&guid);
        let mut rng = rand::thread_rng();
        Self {
            guid,
            mid,
            dev: random_string(10).to_uppercase(),
            mac: "02:00:00:00:00:00".to_string(),
            webgl: (rng.gen::<u64>()).to_string(),
            dfid: None,
        }
    }

    /// 从 JSON 文件读取；文件不存在或解析失败时生成新的
    pub fn load_or_create(path: impl AsRef<Path>) -> Self {
        let path = path.as_ref();
        if let Ok(text) = std::fs::read_to_string(path) {
            if let Ok(id) = serde_json::from_str::<DeviceIdentity>(&text) {
                return id;
            }
        }
        let id = Self::generate();
        let _ = id.save(path);
        id
    }

    /// 写入 JSON 文件
    pub fn save(&self, path: impl AsRef<Path>) -> std::io::Result<()> {
        let path = path.as_ref();
        if let Some(dir) = path.parent() {
            if !dir.as_os_str().is_empty() {
                std::fs::create_dir_all(dir)?;
            }
        }
        std::fs::write(path, serde_json::to_string_pretty(self)?)
    }
}

/// 把 GUID 规范化为 32 位 hex
///
/// 对应原实现的分支：
/// - 合法 UUID v4 → `MD5(uuid)`
/// - 其他 → 原样使用
pub fn normalize_guid(s: &str) -> String {
    if is_uuid_v4(s) {
        md5(s)
    } else {
        s.to_string()
    }
}

/// 计算 MID：**`decimal(MD5(guid))`**
///
/// ⚠️ 注意是**两轮 MD5**：GUID 本身已经是 `MD5(uuid)`，这里再哈希一次。
///
/// ```text
/// guid   = 9ff61aff817a622bbd823f5335d1c13e
/// MD5    = 78e0f116da1cbbbf1a9c26838a24daca
/// mid    = 160675323861738230175415575945740081866   (39 位)
/// ```
///
/// 等价于 JS 的 `bigInt(MD5(str), 16).toString()`。
pub fn calculate_mid(guid: &str) -> String {
    let digest = md5(guid);
    // 128 bit → 最长 39 位十进制，必须用大整数
    num_bigint::BigUint::parse_bytes(digest.as_bytes(), 16)
        .expect("MD5 hex 必然可解析")
        .to_str_radix(10)
}

/// 判断是否为合法 UUID v4
pub fn is_uuid_v4(s: &str) -> bool {
    let b = s.as_bytes();
    if b.len() != 36 {
        return false;
    }
    // 8-4-4-4-12
    for (i, &c) in b.iter().enumerate() {
        match i {
            8 | 13 | 18 | 23 => {
                if c != b'-' {
                    return false;
                }
            }
            14 => {
                if c != b'4' {
                    return false;
                }
            }
            19 => {
                if !matches!(c, b'8' | b'9' | b'a' | b'b' | b'A' | b'B') {
                    return false;
                }
            }
            _ => {
                if !c.is_ascii_hexdigit() {
                    return false;
                }
            }
        }
    }
    true
}

/// 生成 UUID v4（小写，标准格式）
pub fn uuid_v4() -> String {
    let mut rng = rand::thread_rng();
    let mut b = [0u8; 16];
    rng.fill(&mut b);
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // variant 10
    let h = hex::encode(b);
    format!(
        "{}-{}-{}-{}-{}",
        &h[0..8],
        &h[8..12],
        &h[12..16],
        &h[16..20],
        &h[20..32]
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mid_is_double_md5_in_decimal() {
        // 用实测抓到的真实值对拍
        let guid = "9ff61aff817a622bbd823f5335d1c13e";
        let mid = calculate_mid(guid);
        assert_eq!(mid, "160675323861738230175415575945740081866");
        assert_eq!(mid.len(), 39);
    }

    #[test]
    fn uuid_v4_is_valid() {
        let u = uuid_v4();
        assert_eq!(u.len(), 36);
        assert!(is_uuid_v4(&u), "生成的 UUID 应当合法: {u}");
    }

    #[test]
    fn normalize_md5s_uuid_but_keeps_hex() {
        let uuid = "550e8400-e29b-41d4-a716-446655440000";
        assert_eq!(normalize_guid(uuid), md5(uuid));

        let hex = "9ff61aff817a622bbd823f5335d1c13e";
        assert_eq!(normalize_guid(hex), hex);
    }

    #[test]
    fn guid_mid_are_consistent() {
        let d = DeviceIdentity::generate();
        assert_eq!(d.guid.len(), 32);
        assert_eq!(d.mid, calculate_mid(&d.guid));
        assert_eq!(d.dev.len(), 10);
    }
}
