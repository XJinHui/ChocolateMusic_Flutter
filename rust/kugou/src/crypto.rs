//! 加密原语层
//!
//! 逐字节复刻 `KuGouMusicApi/util/crypto.js`。三处**非标准**用法务必注意：
//!
//! 1. [`rsa_raw_encrypt`] —— **裸 RSA（无填充）**，确定性输出，明文上限 = 模长字节数
//! 2. [`crypto_aes_encrypt`] 的密钥是 **ASCII 字符串**（32 字符 → AES-256），不是 hex 解码后的字节
//! 3. [`playlist_aes_encrypt`] 用的是 **AES-128**（16 字符密钥）且输出 **Base64**（不是 hex）

use aes::cipher::{block_padding::Pkcs7, BlockDecryptMut, BlockEncryptMut, KeyIvInit};
use base64::Engine;
use num_bigint::BigUint;
use rand::Rng;
use rsa::pkcs8::DecodePublicKey;
use rsa::traits::PublicKeyParts;
use rsa::{Pkcs1v15Encrypt, RsaPublicKey};

type Aes128CbcEnc = cbc::Encryptor<aes::Aes128>;
type Aes128CbcDec = cbc::Decryptor<aes::Aes128>;
type Aes256CbcEnc = cbc::Encryptor<aes::Aes256>;
type Aes256CbcDec = cbc::Decryptor<aes::Aes256>;

// ============================================================
//  公钥常量
// ============================================================

/// 标准版 1024-bit RSA 公钥（SPKI/PEM，用于 `pk` 与 `p`）
///
/// ⚠️ PEM 的 base64 必须按 64 列折行 —— `pem-rfc7468` 会拒绝超长行。
pub const PUBLIC_RSA_KEY: &str = concat!(
    "-----BEGIN PUBLIC KEY-----
",
    "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDIAG7QOELSYoIJvTFJhMpe1s/g
",
    "bjDJX51HBNnEl5HXqTW6lQ7LC8jr9fWZTwusknp+sVGzwd40MwP6U5yDE27M/X1+
",
    "UR4tvOGOqp94TJtQ1EPnWGWXngpeIW5GxoQGao1rmYWAu6oi1z9XkChrsUdC6DJE
",
    "5E221wf/4WLFxwAtRQIDAQAB
",
    "-----END PUBLIC KEY-----",
);

/// 概念版（lite）1024-bit RSA 公钥
pub const PUBLIC_LITE_RSA_KEY: &str = concat!(
    "-----BEGIN PUBLIC KEY-----
",
    "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDECi0Np2UR87scwrvTr72L6oO0
",
    "1rBbbBPriSDFPxr3Z5syug0O24QyQO8bg27+0+4kBzTBTBOZ/WWU0WryL1JSXRTX
",
    "LgFVxtzIY41Pe7lPOgsfTCn5kZcvKhYKJesKnnJDNr5/abvTGf+rHG3YRwsCHcQ0
",
    "8/q6ifSioBszvb3QiwIDAQAB
",
    "-----END PUBLIC KEY-----",
);

// ============================================================
//  哈希
// ============================================================

/// MD5 → 32 位小写 hex
pub fn md5(data: impl AsRef<[u8]>) -> String {
    use md5::{Digest, Md5};
    hex::encode(Md5::digest(data.as_ref()))
}

/// SHA1 → 40 位小写 hex
pub fn sha1(data: impl AsRef<[u8]>) -> String {
    use sha1::{Digest, Sha1};
    hex::encode(Sha1::digest(data.as_ref()))
}

// ============================================================
//  随机串
// ============================================================

const RANDOM_CHARSET: &[u8] = b"1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ";

/// 生成随机串（字符池 `1234567890A-Z`，共 36 字符）
///
/// 对应 `util/util.js` 的 `randomString`
pub fn random_string(len: usize) -> String {
    let mut rng = rand::thread_rng();
    (0..len)
        .map(|_| RANDOM_CHARSET[rng.gen_range(0..RANDOM_CHARSET.len())] as char)
        .collect()
}

/// 生成 [min, max] 闭区间内的随机整数
pub fn rand_range(min: i64, max: i64) -> i64 {
    let mut rng = rand::thread_rng();
    rng.gen_range(min..=max)
}

// ============================================================
//  AES
// ============================================================

/// AES-CBC/PKCS7 加密的结果
#[derive(Debug, Clone)]
pub struct AesResult {
    /// 密文（hex 小写）
    pub str: String,
    /// 密钥（ASCII 字符串，非 hex）
    pub key: String,
}

/// AES 加密，对应 `cryptoAesEncrypt`
///
/// - `opt` 为 `Some((key, iv))` 时：用给定的 ASCII 密钥与 IV，返回 hex 字符串
/// - `opt` 为 `None` 时：随机 16 字符密钥 → `MD5(key)[0..32]` 作为密钥、`[16..32]` 作为 IV
///   → 返回 `AesResult`
///
/// ⚠️ 密钥是 **ASCII 字符串**（32 字符 = 32 字节 → AES-256），**不要**做 hex 解码。
pub fn crypto_aes_encrypt(data: &str, opt: Option<(&str, &str)>) -> AesResult {
    let (key, iv, temp_key) = match opt {
        Some((k, i)) => (k.to_string(), i.to_string(), None),
        None => {
            let temp = random_string(16).to_lowercase();
            let digest = md5(&temp);
            let k = digest[0..32].to_string();
            // IV = 密钥的后 16 个字符（对应 JS 的 key.substring(key.length - 16)）
            let i = k[k.len() - 16..].to_string();
            (k, i, Some(temp))
        }
    };

    let ct = aes_cbc_encrypt(data.as_bytes(), key.as_bytes(), iv.as_bytes());
    AesResult {
        str: hex::encode(ct),
        key: temp_key.unwrap_or(key),
    }
}

/// AES 解密，对应 `cryptoAesDecrypt`
///
/// `iv` 为 `None` 时：`key = MD5(key)[0..32]`，`iv = key[key.len()-16..]`
pub fn crypto_aes_decrypt(data_hex: &str, key: &str, iv: Option<&str>) -> String {
    let (key, iv) = match iv {
        Some(i) => (key.to_string(), i.to_string()),
        None => {
            let k = md5(key)[0..32].to_string();
            let i = k[k.len() - 16..].to_string();
            (k, i)
        }
    };

    let ct = match hex::decode(data_hex) {
        Ok(v) => v,
        Err(_) => return String::new(),
    };

    match aes_cbc_decrypt(&ct, key.as_bytes(), iv.as_bytes()) {
        Some(pt) => String::from_utf8_lossy(&pt).to_string(),
        None => String::new(),
    }
}

/// 歌单 AES 加密，对应 `playlistAesEncrypt`
///
/// - 密钥：**6 字符**随机串
/// - `enc_key = MD5(key)[0..16]`（16 字符 → **AES-128**）
/// - `iv = MD5(key)[16..32]`
/// - 输出：**Base64**（不是 hex）
pub fn playlist_aes_encrypt(data: &str) -> AesResult {
    let key = random_string(6).to_lowercase();
    let digest = md5(&key);
    let enc_key = &digest[0..16];
    let iv = &digest[16..32];

    let ct = aes_cbc_encrypt(data.as_bytes(), enc_key.as_bytes(), iv.as_bytes());
    AesResult {
        str: base64::engine::general_purpose::STANDARD.encode(&ct),
        key,
    }
}

/// 歌单 AES 解密，对应 `playlistAesDecrypt`
pub fn playlist_aes_decrypt(data_b64: &str, key: &str) -> String {
    let digest = md5(key);
    let enc_key = &digest[0..16];
    let iv = &digest[16..32];

    let ct = match base64::engine::general_purpose::STANDARD.decode(data_b64) {
        Ok(v) => v,
        Err(_) => return String::new(),
    };

    match aes_cbc_decrypt(&ct, enc_key.as_bytes(), iv.as_bytes()) {
        Some(pt) => String::from_utf8_lossy(&pt).to_string(),
        None => String::new(),
    }
}

/// 底层 AES-CBC/PKCS7 加密，密钥与 IV 均为原始字节
fn aes_cbc_encrypt(plain: &[u8], key: &[u8], iv: &[u8]) -> Vec<u8> {
    // 手工准备缓冲区，避免依赖 cipher 的 alloc feature
    let buf_len = plain.len() + (16 - plain.len() % 16);
    let mut buf = vec![0u8; buf_len];
    buf[..plain.len()].copy_from_slice(plain);
    let pt_len = plain.len();

    let ct = match key.len() {
        32 => Aes256CbcEnc::new(key.into(), iv.into())
            .encrypt_padded_mut::<Pkcs7>(&mut buf, pt_len)
            .expect("缓冲区已按 PKCS7 预留空间"),
        16 => Aes128CbcEnc::new(key.into(), iv.into())
            .encrypt_padded_mut::<Pkcs7>(&mut buf, pt_len)
            .expect("缓冲区已按 PKCS7 预留空间"),
        n => panic!("不支持的 AES 密钥长度: {n} 字节（应为 16 或 32）"),
    };
    ct.to_vec()
}

/// 底层 AES-CBC/PKCS7 解密
fn aes_cbc_decrypt(ct: &[u8], key: &[u8], iv: &[u8]) -> Option<Vec<u8>> {
    let mut buf = ct.to_vec();
    let pt = match key.len() {
        32 => Aes256CbcDec::new(key.into(), iv.into()).decrypt_padded_mut::<Pkcs7>(&mut buf),
        16 => Aes128CbcDec::new(key.into(), iv.into()).decrypt_padded_mut::<Pkcs7>(&mut buf),
        _ => return None,
    }
    .ok()?;
    Some(pt.to_vec())
}

// ============================================================
//  RSA
// ============================================================

/// **裸 RSA 加密（无填充）**，对应 `cryptoRSAEncrypt`
///
/// 算法：`c = m^e mod n`，`m` 是把明文**右侧补零**到模长后的字节按大端解释。
///
/// - 输出：小写 hex，左侧补零到 `2 × 模长字节数`（1024-bit → 恒为 256 字符）
/// - 明文上限：**128 字节**，超出直接报错
/// - **确定性**：同一明文每次结果相同（与 PKCS#1 v1.5 不同）
///
/// 调用方通常会 `.to_uppercase()`。
///
/// ## ⚠️ 是「右侧补零」，不是「左补零」
///
/// 原实现是：
///
/// ```js
/// padded = new Uint8Array(keyLength);
/// padded.set(buffer);          // ⚠️ set() 默认从 offset 0 开始 → 消息在**开头**
/// ```
///
/// 也就是消息占**高位**、低位补零。写成「左补零」会得到完全不同的密文，
/// 上游解不出来 —— 表现为 `error_code: 20006`（err signature）。
pub fn rsa_raw_encrypt(data: &[u8], public_key_pem: &str) -> Result<String, CryptoError> {
    let key = parse_public_key(public_key_pem)?;

    // 显式转成自己的 BigUint，避免 rsa crate 内部 num-bigint 版本差异
    let n = BigUint::from_bytes_be(&key.n().to_bytes_be());
    let e = BigUint::from_bytes_be(&key.e().to_bytes_be());
    let key_len = (n.bits() as usize + 7) / 8;

    if data.len() > key_len {
        return Err(CryptoError::DataTooLong {
            len: data.len(),
            max: key_len,
        });
    }

    // ⚠️ 消息在**前**，右侧补零
    let mut padded = vec![0u8; key_len];
    padded[..data.len()].copy_from_slice(data);

    let m = BigUint::from_bytes_be(&padded);
    let c = m.modpow(&e, &n);

    let hex = c.to_str_radix(16);
    Ok(format!("{:0>width$}", hex, width = key_len * 2))
}

/// **RSA PKCS#1 v1.5 加密**，对应 `rsaEncrypt2`
///
/// - 输出：小写 hex
/// - 明文上限：`模长 - 11` 字节（1024-bit → 117 字节）
/// - **非确定性**：含随机填充
///
/// 调用方通常会 `.to_uppercase()`。
pub fn rsa_encrypt2(data: &[u8], public_key_pem: &str) -> Result<String, CryptoError> {
    let key = parse_public_key(public_key_pem)?;
    let mut rng = rand::thread_rng();
    let ct = key
        .encrypt(&mut rng, Pkcs1v15Encrypt, data)
        .map_err(|e| CryptoError::Rsa(e.to_string()))?;
    Ok(hex::encode(ct))
}

/// 解析 PEM 公钥
fn parse_public_key(pem: &str) -> Result<RsaPublicKey, CryptoError> {
    RsaPublicKey::from_public_key_pem(pem)
        .map_err(|e| CryptoError::Rsa(format!("公钥解析失败: {e}")))
}

// ============================================================
//  错误
// ============================================================

#[derive(Debug, thiserror::Error)]
pub enum CryptoError {
    #[error("明文长度 {len} 超过 RSA 模长上限 {max} 字节")]
    DataTooLong { len: usize, max: usize },
    #[error("RSA 错误: {0}")]
    Rsa(String),
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn md5_matches_reference() {
        assert_eq!(md5("abc"), "900150983cd24fb0d6963f7d28e17f72");
    }

    #[test]
    fn aes_roundtrip_random_key() {
        let e = crypto_aes_encrypt(r#"{"x":1}"#, None);
        let d = crypto_aes_decrypt(&e.str, &e.key, None);
        assert_eq!(d, r#"{"x":1}"#);
    }

    #[test]
    fn aes_roundtrip_fixed_key() {
        let e = crypto_aes_encrypt("hello", Some(("0123456789abcdef", "fedcba9876543210")));
        let d = crypto_aes_decrypt(&e.str, "0123456789abcdef", Some("fedcba9876543210"));
        assert_eq!(d, "hello");
    }

    #[test]
    fn playlist_aes_roundtrip() {
        let e = playlist_aes_encrypt(r#"{"y":2}"#);
        assert_eq!(e.key.len(), 6);
        let d = playlist_aes_decrypt(&e.str, &e.key);
        assert_eq!(d, r#"{"y":2}"#);
    }

    #[test]
    fn raw_rsa_is_deterministic() {
        let a = rsa_raw_encrypt(br#"{"a":1}"#, PUBLIC_RSA_KEY).unwrap();
        let b = rsa_raw_encrypt(br#"{"a":1}"#, PUBLIC_RSA_KEY).unwrap();
        assert_eq!(a, b, "裸 RSA 应当确定性输出");
        assert_eq!(a.len(), 256, "1024-bit 裸 RSA 输出应为 256 位 hex");
    }

    #[test]
    fn pkcs1v15_is_random() {
        let a = rsa_encrypt2(br#"{"a":1}"#, PUBLIC_RSA_KEY).unwrap();
        let b = rsa_encrypt2(br#"{"a":1}"#, PUBLIC_RSA_KEY).unwrap();
        assert_ne!(a, b, "PKCS#1 v1.5 应含随机填充");
    }

    #[test]
    fn raw_rsa_rejects_oversize() {
        let big = vec![0u8; 129];
        assert!(rsa_raw_encrypt(&big, PUBLIC_RSA_KEY).is_err());
    }

    /// 黄金向量：与 Node 的 `cryptoRSAEncrypt` 对拍（无填充 RSA 是确定性的）
    ///
    /// ⚠️ 这个向量锁死的是「**右侧补零**」这个方向。
    ///
    /// 曾经写成「左补零」（消息在低位），结果 `/login/token` 与 `/login/cellphone`
    /// 全部报 `error_code: 20006`（err signature）—— 上游用私钥解 `pk` 解不出来，
    /// 就拿不到解密 `params` 用的 AES 密钥，于是判定签名错。
    ///
    /// 根源是 JS 的 `Uint8Array.prototype.set(array)` **默认从 offset 0 开始写**：
    ///
    /// ```js
    /// padded = new Uint8Array(keyLength);
    /// padded.set(buffer);      // ⚠️ 消息在开头，右侧补零 —— 不是左补零
    /// ```
    #[test]
    fn raw_rsa_matches_node_golden_vector() {
        let plain = br#"{"clienttime_ms":1234567890123,"key":"0123456789abcdef"}"#;

        assert_eq!(
            rsa_raw_encrypt(plain, PUBLIC_LITE_RSA_KEY).unwrap(),
            "235c2bb114bbeb83c294282e15b665edebd695cef9a4a4456c7482fd484be72b7c6aeaf9692f3db7dfb101ce8513349c68f603c3855b5cff741311e77fa0ad1d562b61688118e164f02bcc4f7eb3b2dce55e1d0d7566f18fd0b1ee27ef2a4cf621ed09c22e3b4a2a35b56795625569a35cd82254cbb922bb13324d59a301be58"
        );
        assert_eq!(
            rsa_raw_encrypt(plain, PUBLIC_RSA_KEY).unwrap(),
            "b4a0f95451613ca41e562014b8e0050a2a5c2a589133c3a1a12db82c7d7fffa5ed3cbf9c81819f94add989a358cf4abcd7c559abbe2350969aefb823916d4438277a01f5ee515c6eb7fb13cb7b4c2c5974e504f8cc0088ffecbd8d861a7c115d0b717948678ab061a8d3f67af3bf00b0269e18aea9a84f659604d4e6f3df0298"
        );
    }
}
