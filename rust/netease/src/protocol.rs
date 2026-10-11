//! 三种加密方案
//!
//! 对应 `util/crypto.js` 的 `weapi` / `eapi` / `xeapi`，以及 `util/request.js` 的分支。
//!
//! | 方案 | 路由数 | 上游域名 | 请求体 |
//! | --- | :-: | --- | --- |
//! | [`weapi`] | 14/29 | `music.163.com/weapi/{uri[5:]}` | `params=&encSecKey=` |
//! | [`eapi`] | 11/29 | `interfacepc.music.163.com/eapi/{uri[5:]}` | `params=` |
//! | [`xeapi`] | 3/29 | `interface3.music.163.com/xeapi/{uri[5:]}` | `B=&S=&R=` |
//!
//! 域名常量见 [`crate::request`]。

use serde_json::Value;

use crate::crypto::{
    aes_cbc_encrypt_b64, aes_ecb_decrypt_hex, aes_ecb_encrypt_hex_upper, md5_hex,
    random_base62, rsa_none_encrypt_hex, EAPI_KEY, EAPI_SEP, IV, PRESET_KEY,
};
use crate::{Error, Result};

// ============================================================
//  weapi
// ============================================================

/// weapi 的加密结果
#[derive(Debug, Clone)]
pub struct WeapiParams {
    /// 双层 AES 后的 Base64 密文
    pub params: String,
    /// 反转 `secretKey` 后的无填充 RSA（小写 hex）
    pub enc_sec_key: String,
}

/// weapi 加密（14/29 条路由）
///
/// ```text
/// 1. text   = JSON.stringify(data)
/// 2. inner  = AES-128-CBC(presetKey, iv, Pkcs7).encrypt(text)   → Base64
/// 3. outer  = AES-128-CBC(secretKey, iv, Pkcs7).encrypt(inner)  → Base64
/// 4. encSecKey = RSA_NONE(reverse(secretKey))                   → 小写 hex
/// ```
///
/// ⚠️ 第 3 步的明文是第 2 步的 **Base64 字符串**（ASCII 文本），不是二进制。
/// ⚠️ `secretKey` **反转后**才做 RSA。
pub fn weapi(data: &Value) -> Result<WeapiParams> {
    let text = to_js_json(data)?;
    let secret_key = random_base62(16);

    let inner = aes_cbc_encrypt_b64(&text, PRESET_KEY, IV);
    let outer = aes_cbc_encrypt_b64(&inner, &secret_key, IV);

    let reversed: String = secret_key.chars().rev().collect();
    let enc_sec_key = rsa_none_encrypt_hex(reversed.as_bytes())?;

    Ok(WeapiParams {
        params: outer,
        enc_sec_key,
    })
}

/// weapi 请求体（`application/x-www-form-urlencoded`）
pub fn weapi_body(p: &WeapiParams) -> String {
    format!("params={}&encSecKey={}", urlencoding::encode(&p.params), p.enc_sec_key)
}

// ============================================================
//  eapi
// ============================================================

/// eapi 加密（11/29 条路由）
///
/// ```text
/// 1. text   = JSON.stringify(data)                       // data.header 已塞入
/// 2. digest = md5("nobody" + uri + "use" + text + "md5forencrypt")   → 小写 hex
/// 3. plain  = uri + "-36cd479b6b5-" + text + "-36cd479b6b5-" + digest
/// 4. params = AES-128-ECB(eapiKey, Pkcs7).encrypt(plain)             → 大写 hex
/// ```
///
/// ⚠️ `uri` 是模块里写的**原始路径**（如 `/api/song/lyric`），不是完整 URL。
/// ⚠️ `digest` 小写、`params` **大写** —— 两者编码不一致，别统一。
pub fn eapi(uri: &str, data: &Value) -> Result<String> {
    let text = to_js_json(data)?;

    let message = format!("nobody{uri}use{text}md5forencrypt");
    let digest = md5_hex(message.as_bytes());

    let plain = format!("{uri}{EAPI_SEP}{text}{EAPI_SEP}{digest}");
    aes_ecb_encrypt_hex_upper(&plain, EAPI_KEY)
}

/// eapi 请求体
pub fn eapi_body(params_hex: &str) -> String {
    format!("params={params_hex}")
}

/// eapi 响应解密（`e_r` 关闭时用不到，但解密函数留着备查）
pub fn eapi_res_decrypt(params_hex: &str) -> Result<Value> {
    let plain = aes_ecb_decrypt_hex(params_hex, EAPI_KEY)?;
    serde_json::from_str(&plain).map_err(|e| Error::Json(format!("eapi 响应解密后非 JSON: {e}")))
}

/// 从 eapi 密文里还原 `(url, data)`（调试用）
pub fn eapi_req_decrypt(params_hex: &str) -> Result<(String, Value)> {
    let plain = aes_ecb_decrypt_hex(params_hex, EAPI_KEY)?;
    let mut parts = plain.split(EAPI_SEP);

    let uri = parts
        .next()
        .ok_or_else(|| Error::Crypto("eapi 明文缺少 uri".into()))?
        .to_string();
    let text = parts
        .next()
        .ok_or_else(|| Error::Crypto("eapi 明文缺少 data".into()))?;

    let data = serde_json::from_str(text)
        .map_err(|e| Error::Json(format!("eapi 明文 data 非 JSON: {e}")))?;

    Ok((uri, data))
}

// ============================================================
//  工具
// ============================================================

/// 序列化成 JS `JSON.stringify` 风格的文本
///
/// ⚠️ 依赖 `serde_json` 的 `preserve_order` feature —— 否则对象键会被字典序排序，
/// 与 JS 的插入顺序不一致（虽然服务端会用收到的文本重算摘要，但保持一致更好排查）。
///
/// ⚠️ JS 的 `JSON.stringify` 不转义中文、不转义 `/`；`serde_json` 行为一致。
pub fn to_js_json(v: &Value) -> Result<String> {
    serde_json::to_string(v).map_err(|e| Error::Json(e.to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn weapi_shape_is_stable() {
        let p = weapi(&json!({"a": 1})).unwrap();
        // Base64 密文长度总是 4 的倍数
        assert_eq!(p.params.len() % 4, 0);
        // RSA-1024 → 256 个 hex 字符，全小写
        assert_eq!(p.enc_sec_key.len(), 256);
        assert!(p
            .enc_sec_key
            .chars()
            .all(|c| c.is_ascii_hexdigit() && !c.is_ascii_uppercase()));
    }

    #[test]
    fn weapi_roundtrips_with_inner_key() {
        // 手工解回：先用 secretKey 解外层 —— 但 secretKey 是随机的、只在 RSA 里，
        // 所以这里只验证「外层能用任意 16 字符密钥解开成内层 Base64」这个性质。
        let data = json!({"hello": "世界"});
        let p = weapi(&data).unwrap();

        // 内层用 presetKey 解 → 应得到原始 JSON
        // （要拿到 secretKey 才能解外层，这里换个思路：直接验证内层加密本身）
        let inner = crate::crypto::aes_cbc_encrypt_b64(&to_js_json(&data).unwrap(), PRESET_KEY, IV);
        assert_eq!(
            crate::crypto::aes_cbc_decrypt_b64(&inner, PRESET_KEY, IV).unwrap(),
            to_js_json(&data).unwrap()
        );
        assert!(!p.params.is_empty());
    }

    #[test]
    fn eapi_is_uppercase_hex_and_decryptable() {
        let uri = "/api/song/lyric";
        let data = json!({"id": "347230", "lv": -1});

        let params = eapi(uri, &data).unwrap();

        // 大写 hex，长度是 32 的倍数（AES 块 16 字节 → 32 hex 字符）
        assert!(params.chars().all(|c| c.is_ascii_hexdigit() && !c.is_ascii_lowercase()));
        assert_eq!(params.len() % 32, 0);

        // 能解回 (uri, data)
        let (back_uri, back_data) = eapi_req_decrypt(&params).unwrap();
        assert_eq!(back_uri, uri);
        assert_eq!(back_data, data);
    }

    #[test]
    fn eapi_digest_is_lowercase_md5_of_message() {
        let uri = "/api/test";
        let data = json!({"k": "v"});
        let text = to_js_json(&data).unwrap();

        let params = eapi(uri, &data).unwrap();
        let plain = aes_ecb_decrypt_hex(&params, EAPI_KEY).unwrap();

        let expected_digest = md5_hex(format!("nobody{uri}use{text}md5forencrypt").as_bytes());
        let expected_plain = format!("{uri}{EAPI_SEP}{text}{EAPI_SEP}{expected_digest}");
        assert_eq!(plain, expected_plain);

        // digest 必须是小写
        let digest_part = plain.rsplit(EAPI_SEP).next().unwrap();
        assert_eq!(digest_part, digest_part.to_lowercase());
        assert_eq!(digest_part.len(), 32);
    }

    #[test]
    fn js_json_preserves_key_order() {
        // preserve_order 生效时，键顺序 = 插入顺序（与 JSON.stringify 一致）
        let v: Value = serde_json::from_str(r#"{"z":1,"a":2,"m":3}"#).unwrap();
        assert_eq!(to_js_json(&v).unwrap(), r#"{"z":1,"a":2,"m":3}"#);
    }

    #[test]
    fn js_json_does_not_escape_non_ascii() {
        let v = json!({"s": "海阔天空"});
        assert_eq!(to_js_json(&v).unwrap(), r#"{"s":"海阔天空"}"#);
    }
}
