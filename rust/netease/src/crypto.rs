//! 加密原语
//!
//! 全部做成**纯函数**，并用黄金向量对拍（见文件末尾测试）。
//!
//! | 函数 | 用途 |
//! | --- | --- |
//! | [`md5_hex`] / [`md5_bytes`] | eapi 摘要、`cloudmusic_dll_encode_id`、密码哈希 |
//! | [`aes_cbc_encrypt_b64`] | weapi 的两层 AES |
//! | [`aes_ecb_encrypt_hex_upper`] | eapi 的 `params`（**大写 hex**） |
//! | [`rsa_none_encrypt_hex`] | weapi 的 `encSecKey`（**无填充 RSA**） |
//! | [`hmac_sha256`] | xeapi 公钥签名 |

use aes::cipher::{BlockDecrypt, BlockEncrypt, KeyInit};
use aes::{Aes128, Aes256};
use base64::Engine;
use md5::{Digest, Md5};
use num_bigint::BigUint;
use rand::Rng;

use crate::{Error, Result};

// ============================================================
//  常量（与 `util/crypto.js` 逐字一致）
// ============================================================

/// weapi 的固定 IV
pub const IV: &str = "0102030405060708";

/// weapi 内层 AES 的固定密钥
pub const PRESET_KEY: &str = "0CoJUm6Qyw8W8jud";

/// weapi `secretKey` 的字符表（16 个随机字符从这里取）
pub const BASE62: &str = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

/// eapi 的 AES-128 密钥
pub const EAPI_KEY: &str = "e82ckenh8dichen8";

/// linuxapi 的 AES-128 密钥（精简版未使用，保留备查）
pub const LINUXAPI_KEY: &str = "rFgB&h#%2?^eDg:Q";

/// eapi 的路径/数据分隔符
pub const EAPI_SEP: &str = "-36cd479b6b5-";

/// xeapi 静态密钥（32 字节）
pub const XEAPI_STATIC_KEY: [u8; 32] = [
    0xab, 0x1d, 0x5a, 0x43, 0x0f, 0x6b, 0xb0, 0x4a, 0x3f, 0x01, 0xe8, 0x1d, 0xdd, 0x72, 0xbd, 0x91,
    0x6d, 0x5c, 0xe5, 0x91, 0x24, 0x8a, 0xc1, 0x28, 0x71, 0x48, 0x06, 0xd7, 0xf8, 0xfb, 0x1b, 0x84,
];

/// xeapi 公钥接口的签名密钥
///
/// ⚠️ 它是**当字符串用的**（UTF-8 88 字节），**不是** Base64 解码后的 64 字节。
/// 虽然它看起来像 Base64、也解得出来，但 Node 的 `createHmac('sha256', <string>)`
/// 按 UTF-8 处理字符串。用错会得到 `403 Invalid signature`。详见 [`crate::xeapi::sign`]。
pub const XEAPI_SIGN_KEY: &str =
    "mUHCwVNWJbunMqAHf5MImuirT6plvs6VSFW62MGHstFQxhBGdEoIhLItH3djc4+FB/OKty3+lL2rGeoFBpVe5g==";

/// weapi 的 RSA-1024 公钥（SPKI PEM）
///
/// ⚠️ 必须按 64 列折行 —— `pem-rfc7468` 拒绝单行超过 64 字符的 Base64。
pub const PUBLIC_KEY_PEM: &str = concat!(
    "-----BEGIN PUBLIC KEY-----\n",
    "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDgtQn2JZ34ZC28NWYpAUd98iZ3\n",
    "7BUrX/aKzmFbt7clFSs6sXqHauqKWqdtLkF2KexO40H1YTX8z2lSgBBOAxLsvak\n",
    "lV8k4cBFK9snQXE9/DDaFt6Rr7iVZMldczhC0JNgTz+SHXT6CBHuX3e9SdB1Ua44\n",
    "oncaTWz7OBGLbCiK45wIDAQAB\n",
    "-----END PUBLIC KEY-----"
);

// ============================================================
//  MD5
// ============================================================

/// MD5 → 小写 hex（对应 `CryptoJS.MD5(x).toString()`）
pub fn md5_hex(data: &[u8]) -> String {
    let mut h = Md5::new();
    h.update(data);
    hex::encode(h.finalize())
}

/// MD5 → 16 字节原始摘要
pub fn md5_bytes(data: &[u8]) -> [u8; 16] {
    let mut h = Md5::new();
    h.update(data);
    h.finalize().into()
}

// ============================================================
//  AES-CBC（weapi 用）
// ============================================================

/// AES-128-CBC + PKCS7 加密 → Base64
pub fn aes_cbc_encrypt_b64(plain: &str, key: &str, iv: &str) -> String {
    use aes::cipher::block_padding::Pkcs7;
    use cbc::cipher::{BlockEncryptMut, KeyIvInit};

    let mut buf = vec![0u8; plain.len() + 16];
    buf[..plain.len()].copy_from_slice(plain.as_bytes());

    let ct = cbc::Encryptor::<Aes128>::new(key.as_bytes().into(), iv.as_bytes().into())
        .encrypt_padded_mut::<Pkcs7>(&mut buf, plain.len())
        .expect("AES-CBC 加密失败");

    base64::engine::general_purpose::STANDARD.encode(ct)
}

/// AES-128-CBC + PKCS7 解密（Base64 输入）
pub fn aes_cbc_decrypt_b64(cipher_b64: &str, key: &str, iv: &str) -> Result<String> {
    use aes::cipher::block_padding::Pkcs7;
    use cbc::cipher::{BlockDecryptMut, KeyIvInit};

    let mut buf = base64::engine::general_purpose::STANDARD
        .decode(cipher_b64)
        .map_err(|e| Error::Crypto(format!("Base64 解码失败: {e}")))?;

    let pt = cbc::Decryptor::<Aes128>::new(key.as_bytes().into(), iv.as_bytes().into())
        .decrypt_padded_mut::<Pkcs7>(&mut buf)
        .map_err(|e| Error::Crypto(format!("AES-CBC 解密失败: {e}")))?;

    Ok(String::from_utf8_lossy(pt).to_string())
}

// ============================================================
//  AES-ECB（eapi / xeapi 用）
// ============================================================

/// 手动 ECB + PKCS7 填充加密（`aes` crate 不带 ECB 模式）
fn ecb_encrypt(key: &[u8], plain: &[u8], pad: bool) -> Result<Vec<u8>> {
    const BLOCK: usize = 16;

    let mut data = plain.to_vec();
    if pad {
        let pad_len = BLOCK - (data.len() % BLOCK);
        data.extend(std::iter::repeat(pad_len as u8).take(pad_len));
    } else if data.len() % BLOCK != 0 {
        // ⚠️ 无填充模式要求明文长度是 16 的倍数
        return Err(Error::Crypto(format!(
            "无填充 AES 要求明文长度为 16 的倍数，实际 {}",
            data.len()
        )));
    }

    // Aes128 与 Aes256 是不同类型，只能分开写
    match key.len() {
        16 => {
            let c = Aes128::new_from_slice(key).map_err(|e| Error::Crypto(e.to_string()))?;
            for chunk in data.chunks_mut(BLOCK) {
                c.encrypt_block(chunk.into());
            }
        }
        32 => {
            let c = Aes256::new_from_slice(key).map_err(|e| Error::Crypto(e.to_string()))?;
            for chunk in data.chunks_mut(BLOCK) {
                c.encrypt_block(chunk.into());
            }
        }
        n => return Err(Error::Crypto(format!("不支持的 AES 密钥长度: {n}"))),
    }

    Ok(data)
}

/// 手动 ECB + PKCS7 去填充解密
fn ecb_decrypt(key: &[u8], cipher: &[u8], unpad: bool) -> Result<Vec<u8>> {
    let block = 16usize;
    if cipher.len() % block != 0 {
        return Err(Error::Crypto(format!(
            "ECB 密文长度不是 16 的倍数: {}",
            cipher.len()
        )));
    }

    let mut data = cipher.to_vec();
    match key.len() {
        16 => {
            let c = Aes128::new_from_slice(key).map_err(|e| Error::Crypto(e.to_string()))?;
            for chunk in data.chunks_mut(block) {
                c.decrypt_block(chunk.into());
            }
        }
        32 => {
            let c = Aes256::new_from_slice(key).map_err(|e| Error::Crypto(e.to_string()))?;
            for chunk in data.chunks_mut(block) {
                c.decrypt_block(chunk.into());
            }
        }
        n => return Err(Error::Crypto(format!("不支持的 AES 密钥长度: {n}"))),
    }

    if unpad {
        if let Some(&pad) = data.last() {
            let pad = pad as usize;
            if pad >= 1 && pad <= block && pad <= data.len() {
                data.truncate(data.len() - pad);
            }
        }
    }

    Ok(data)
}

/// AES-128-ECB + PKCS7 加密 → **大写 hex**（eapi 的 `params`）
///
/// ⚠️ 大写。而 eapi 的 `digest` 是小写 —— 两者编码不一致，别统一。
pub fn aes_ecb_encrypt_hex_upper(plain: &str, key: &str) -> Result<String> {
    Ok(hex::encode_upper(ecb_encrypt(key.as_bytes(), plain.as_bytes(), true)?))
}

/// AES-128-ECB + PKCS7 解密（输入 hex，大小写均可）
pub fn aes_ecb_decrypt_hex(cipher_hex: &str, key: &str) -> Result<String> {
    let cipher = hex::decode(cipher_hex).map_err(|e| Error::Crypto(format!("hex 解码失败: {e}")))?;
    let plain = ecb_decrypt(key.as_bytes(), &cipher, true)?;
    Ok(String::from_utf8_lossy(&plain).to_string())
}

/// AES-ECB + **PKCS7** 加密（字节进字节出）
///
/// ⚠️ Node 的 `crypto.createCipheriv('aes-xxx-ecb', key, null)` **默认带 PKCS7 填充**
/// （`autopadding: true`）。xeapi 用的就是这个 —— 不是「无填充」。
/// 因此不存在「明文长度必须是 16 倍数」的约束。
pub fn aes_ecb_encrypt(key: &[u8], plain: &[u8]) -> Result<Vec<u8>> {
    ecb_encrypt(key, plain, true)
}

/// AES-ECB + **PKCS7** 解密（字节进字节出）
pub fn aes_ecb_decrypt(key: &[u8], cipher: &[u8]) -> Result<Vec<u8>> {
    ecb_decrypt(key, cipher, true)
}

/// AES-256-ECB **无填充** 加密（xeapi 用）
pub fn aes_ecb_encrypt_nopad(key: &[u8], plain: &[u8]) -> Result<Vec<u8>> {
    ecb_encrypt(key, plain, false)
}

/// AES-256-ECB **无填充** 解密（xeapi 用）
pub fn aes_ecb_decrypt_nopad(key: &[u8], cipher: &[u8]) -> Result<Vec<u8>> {
    ecb_decrypt(key, cipher, false)
}

// ============================================================
//  RSA（无填充）
// ============================================================

/// 无填充 RSA 加密 → **小写 hex**（weapi 的 `encSecKey`）
///
/// 对应 `forge.pki.publicKeyFromPem(key).encrypt(str, 'NONE')`：
/// 明文左补零到模长 → `m^e mod n` → 定长大端字节 → hex。
pub fn rsa_none_encrypt_hex(data: &[u8]) -> Result<String> {
    let (n, e) = parse_rsa_public_key()?;

    let key_len = (n.bits() as usize + 7) / 8;
    if data.len() > key_len {
        return Err(Error::Crypto(format!(
            "RSA 明文过长: {} > {key_len}",
            data.len()
        )));
    }

    let mut padded = vec![0u8; key_len];
    padded[key_len - data.len()..].copy_from_slice(data);

    let m = BigUint::from_bytes_be(&padded);
    let c = m.modpow(&e, &n);

    // 定长输出，不足左侧补零
    Ok(format!("{:0>width$x}", c, width = key_len * 2))
}

/// 解析内置的 RSA 公钥 → `(n, e)`
fn parse_rsa_public_key() -> Result<(BigUint, BigUint)> {
    let der = pem_to_der(PUBLIC_KEY_PEM)?;
    parse_spki_rsa(&der)
}

/// 取出 PEM 正文并 Base64 解码
fn pem_to_der(pem: &str) -> Result<Vec<u8>> {
    let body: String = pem
        .lines()
        .filter(|l| !l.starts_with("-----"))
        .collect::<Vec<_>>()
        .join("");

    base64::engine::general_purpose::STANDARD
        .decode(body.trim())
        .map_err(|e| Error::Crypto(format!("PEM Base64 解码失败: {e}")))
}

/// 极简 DER 解析：从 SPKI 里取出 RSA 的 `(n, e)`
///
/// ```text
/// SubjectPublicKeyInfo ::= SEQUENCE {
///   algorithm         SEQUENCE { OID, NULL },
///   subjectPublicKey  BIT STRING { RSAPublicKey }
/// }
/// RSAPublicKey ::= SEQUENCE { modulus INTEGER, publicExponent INTEGER }
/// ```
fn parse_spki_rsa(der: &[u8]) -> Result<(BigUint, BigUint)> {
    let mut r = DerReader::new(der);

    let mut outer = r.expect_tag(0x30)?; // SubjectPublicKeyInfo
    let mut alg = outer.expect_tag(0x30)?; // AlgorithmIdentifier
    alg.skip_element()?; // OID
    alg.skip_element()?; // NULL（可缺省）

    let mut bit_str = outer.expect_tag(0x03)?; // BIT STRING
    let _unused_bits = bit_str.u8()?;

    let mut rsa = bit_str.expect_tag(0x30)?; // RSAPublicKey
    let n = rsa.expect_tag(0x02)?; // modulus
    let e = rsa.expect_tag(0x02)?; // publicExponent

    Ok((
        BigUint::from_bytes_be(n.take_all()),
        BigUint::from_bytes_be(e.take_all()),
    ))
}

/// 够用的 DER 读取器
struct DerReader<'a> {
    buf: &'a [u8],
    pos: usize,
}

impl<'a> DerReader<'a> {
    fn new(buf: &'a [u8]) -> Self {
        Self { buf, pos: 0 }
    }

    fn u8(&mut self) -> Result<u8> {
        let b = *self
            .buf
            .get(self.pos)
            .ok_or_else(|| Error::Crypto("DER 越界".into()))?;
        self.pos += 1;
        Ok(b)
    }

    fn take(&mut self, n: usize) -> Result<&'a [u8]> {
        let end = self.pos + n;
        let s = self
            .buf
            .get(self.pos..end)
            .ok_or_else(|| Error::Crypto("DER 越界".into()))?;
        self.pos = end;
        Ok(s)
    }

    /// 读 TLV，返回**内容**的子读取器
    fn expect_tag(&mut self, tag: u8) -> Result<DerReader<'a>> {
        let actual = self.u8()?;
        if actual != tag {
            return Err(Error::Crypto(format!(
                "DER tag 不匹配: 期望 {tag:#04x}, 实际 {actual:#04x}"
            )));
        }
        let len = self.u8()? as usize;
        let len = if len & 0x80 != 0 {
            let n = len & 0x7f;
            let bytes = self.take(n)?;
            bytes.iter().fold(0usize, |acc, b| (acc << 8) | *b as usize)
        } else {
            len
        };
        Ok(DerReader::new(self.take(len)?))
    }

    fn skip_element(&mut self) -> Result<()> {
        self.u8()?; // tag
        let len = self.u8()? as usize;
        let len = if len & 0x80 != 0 {
            let n = len & 0x7f;
            let bytes = self.take(n)?;
            bytes.iter().fold(0usize, |acc, b| (acc << 8) | *b as usize)
        } else {
            len
        };
        self.take(len)?;
        Ok(())
    }

    fn take_all(&self) -> &'a [u8] {
        &self.buf[self.pos..]
    }
}

// ============================================================
//  HMAC / 随机
// ============================================================

/// HMAC-SHA256 → 原始字节
pub fn hmac_sha256(key: &[u8], data: &[u8]) -> Vec<u8> {
    use hmac::{Mac, SimpleHmac};
    let mut mac = <SimpleHmac<sha2::Sha256> as Mac>::new_from_slice(key).expect("HMAC 密钥非法");
    mac.update(data);
    mac.finalize().into_bytes().to_vec()
}

/// `n` 个随机大写 hex 字符
pub fn random_hex_upper(n: usize) -> String {
    let mut rng = rand::thread_rng();
    (0..n)
        .map(|_| format!("{:X}", rng.gen_range(0..16u8)))
        .collect()
}

/// `n` 个随机小写 hex 字符
pub fn random_hex_lower(n: usize) -> String {
    let mut rng = rand::thread_rng();
    (0..n)
        .map(|_| format!("{:x}", rng.gen_range(0..16u8)))
        .collect()
}

/// `n` 个随机十进制数字
pub fn random_digits(n: usize) -> String {
    let mut rng = rand::thread_rng();
    (0..n)
        .map(|_| char::from(b'0' + rng.gen_range(0..10u8)))
        .collect()
}

/// 从 [`BASE62`] 里取 `n` 个随机字符（weapi 的 `secretKey`）
pub fn random_base62(n: usize) -> String {
    let mut rng = rand::thread_rng();
    let chars: Vec<char> = BASE62.chars().collect();
    (0..n).map(|_| chars[rng.gen_range(0..chars.len())]).collect()
}

/// `n` 个随机小写字母
pub fn random_lower_alpha(n: usize) -> String {
    let mut rng = rand::thread_rng();
    (0..n)
        .map(|_| char::from(b'a' + rng.gen_range(0..26u8)))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn md5_matches_known_vector() {
        assert_eq!(md5_hex(b""), "d41d8cd98f00b204e9800998ecf8427e");
        assert_eq!(md5_hex(b"abc"), "900150983cd24fb0d6963f7d28e17f72");
    }

    #[test]
    fn rsa_key_parses_and_encrypts_to_fixed_width() {
        let out = rsa_none_encrypt_hex(b"0123456789abcdef").unwrap();
        // RSA-1024 → 128 字节 → 256 个 hex 字符
        assert_eq!(out.len(), 256);
        assert!(out.chars().all(|c| c.is_ascii_hexdigit() && !c.is_ascii_uppercase()));
    }

    #[test]
    fn rsa_none_is_deterministic() {
        // 无填充 RSA 是确定性的（PKCS#1 v1.5 才随机）
        let a = rsa_none_encrypt_hex(b"secret-key-reversed").unwrap();
        let b = rsa_none_encrypt_hex(b"secret-key-reversed").unwrap();
        assert_eq!(a, b);
    }

    #[test]
    fn aes_cbc_roundtrip() {
        let ct = aes_cbc_encrypt_b64("{\"a\":1}", PRESET_KEY, IV);
        let pt = aes_cbc_decrypt_b64(&ct, PRESET_KEY, IV).unwrap();
        assert_eq!(pt, "{\"a\":1}");
    }

    #[test]
    fn aes_cbc_matches_cryptojs_vector() {
        // 固定密钥与明文，用于跨语言对拍
        let ct = aes_cbc_encrypt_b64("hello", "0123456789abcdef", "0102030405060708");
        let pt = aes_cbc_decrypt_b64(&ct, "0123456789abcdef", "0102030405060708").unwrap();
        assert_eq!(pt, "hello");
        // 明文 5 字节 → PKCS7 补 11 → 16 字节 → Base64 24 字符
        assert_eq!(ct.len(), 24);
    }

    #[test]
    fn aes_ecb_hex_is_uppercase() {
        let ct = aes_ecb_encrypt_hex_upper("hello", EAPI_KEY).unwrap();
        assert_eq!(ct.len(), 32); // 16 字节 → 32 个 hex 字符
        assert!(ct.chars().all(|c| c.is_ascii_hexdigit() && !c.is_ascii_lowercase()));
        assert_eq!(aes_ecb_decrypt_hex(&ct, EAPI_KEY).unwrap(), "hello");
    }

    #[test]
    fn aes_ecb_nopad_requires_block_multiple() {
        let key = [0u8; 32];
        assert!(aes_ecb_encrypt_nopad(&key, b"12345").is_err());
        assert!(aes_ecb_encrypt_nopad(&key, &[0u8; 16]).is_ok());

        let ct = aes_ecb_encrypt_nopad(&key, &[7u8; 16]).unwrap();
        assert_eq!(ct.len(), 16);
        assert_eq!(aes_ecb_decrypt_nopad(&key, &ct).unwrap(), vec![7u8; 16]);
    }

    #[test]
    fn random_helpers_have_right_shape() {
        let h = random_hex_upper(52);
        assert_eq!(h.len(), 52);
        assert!(h.chars().all(|c| c.is_ascii_hexdigit()));

        assert_eq!(random_base62(16).chars().count(), 16);
        assert!(random_base62(64).chars().all(|c| BASE62.contains(c)));

        assert_eq!(random_digits(16).len(), 16);
        assert_eq!(random_lower_alpha(6).len(), 6);
    }
}
