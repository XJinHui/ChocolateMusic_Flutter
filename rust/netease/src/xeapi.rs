//! xeapi 协议（X25519 + 非标准 HKDF + AES-128-GCM）
//!
//! 网易云新版 Android 客户端（`interface3.music.163.com`）的协议，
//! 精简版里只有 3 条广告路由 + 匿名注册在用。
//!
//! ## 三层结构
//!
//! ```text
//! B = AES-256-ECB(dynamicKey, midTransform(AES-256-ECB(staticKey, plaintext)))
//! S = X25519-ECDH + 非标准 HKDF + AES-128-GCM
//! R = AES-256-ECB(staticKey, "{version}|{sessionId}")
//! ```
//!
//! ## ⚠️ 与 eapi 的三处关键差异
//!
//! | 项 | eapi | xeapi |
//! | --- | --- | --- |
//! | AES 填充 | Pkcs7（CryptoJS 默认） | **也是 Pkcs7**（Node `createCipheriv` 的默认） |
//! | 响应解密密钥 | `eapiKey` | 也是 `eapiKey`（**不是** `staticKey`） |
//! | 请求体形态 | `params=<hex>` | `B=<b64>&S=<b64>&R=<b64>` |
//!
//! ⚠️ **`createCipheriv` 默认是 `autopadding: true`** —— 也就是 PKCS7。
//! 源码没写 `autopadding: false`，所以三条 AES 全部**带填充**，
//! 不存在「明文长度必须是 16 倍数」的约束。

use std::io::Read;

use aes::cipher::{BlockDecrypt, BlockEncrypt, KeyInit};
use aes::{Aes128, Aes256};
use aes_gcm::aead::Aead;
use aes_gcm::{Aes128Gcm, Nonce};
use base64::Engine;
use rand::RngCore;
use serde_json::{json, Map, Value};
use x25519_dalek::{PublicKey, StaticSecret};

use crate::request::API_DOMAIN;
use crate::crypto::{
    aes_ecb_decrypt, aes_ecb_encrypt, hmac_sha256, random_digits, EAPI_KEY, XEAPI_STATIC_KEY,
};
use crate::{now_ms, Error, Result};

/// xeapi 公钥接口的路径
pub const KEY_GET_PATH: &str = "/api/gorilla/anti/crawler/security/key/get";

/// 公钥接口的 User-Agent（**写死的**，与其他接口不同）
pub const XEAPI_UA: &str =
    "NeteaseMusic/9.5.61.260802021928(9005061);Dalvik/2.1.0 (Linux; U; Android 12; HBN-AL00 Build/cd737a2.0)";

/// 公钥接口的 `appVersion`
pub const APP_VERSION: &str = "9.5.61";

// ============================================================
//  公钥状态
// ============================================================

/// 从 `register_xeapikey` 拿到的公钥状态
///
/// 对应 Node 里 `os.tmpdir()/xeapi_public_key` 文件的内容。
#[derive(Debug, Clone, Default)]
pub struct PublicKeyState {
    /// 版本号（如 `"1"`），参与 `R` 的明文
    pub version: String,
    /// **32 字节裸 X25519 公钥**的 Base64
    pub public_key: String,
    /// 设备侧密钥（原样回填进 `S` 的明文）
    pub sk: String,
    pub device_id: String,
}

impl PublicKeyState {
    pub fn is_ready(&self) -> bool {
        !self.public_key.is_empty()
    }
}

// ============================================================
//  请求体明文
// ============================================================

/// `buildXeapiPlaintext` 的选项
#[derive(Debug, Clone)]
pub struct PlaintextOptions {
    pub method: String,
    pub content_type: String,
}

impl Default for PlaintextOptions {
    fn default() -> Self {
        Self {
            method: "POST".into(),
            content_type: "application/x-www-form-urlencoded;charset=utf-8".into(),
        }
    }
}

/// 构造 xeapi 的请求体明文（**一个 JSON 字符串**）
///
/// ```text
/// {"queryString":"e_r=true","body":"<base64 of urlencoded body>"}
/// ```
///
/// ⚠️ 字段顺序固定为 `contentType` → `method` → `queryString` → `body`，
/// 这个顺序会直接影响后续 AES 的字节，必须与 JS 一致。
///
/// ⚠️ `queryString` **恒存在**，即使 uri 没有 query 也会是 `e_r=true`。
///
/// ⚠️ `e_r` 字段会从 body 里**删掉**，改由 `queryString` 传递。
pub fn build_plaintext(uri: &str, data: &Value, opt: &PlaintextOptions) -> Result<String> {
    // 用 Map 保证插入顺序（依赖 serde_json 的 preserve_order）
    let mut fields = Map::new();

    let media_type = opt
        .content_type
        .split(';')
        .next()
        .unwrap_or("")
        .to_lowercase();
    if media_type != "application/x-www-form-urlencoded" {
        fields.insert("contentType".into(), json!(opt.content_type));
    }

    let method = opt.method.to_uppercase();
    if method != "POST" {
        fields.insert("method".into(), json!(method));
    }

    // ⚠️ **只有 uri 自带 query 时才在这里设置 `queryString`**。
    //    没有 query 时它会留到**最后**才插入 —— 位置不同，JSON 字节就不同。
    let query = uri.split_once('?').map(|(_, q)| q).unwrap_or("");
    if !query.is_empty() {
        fields.insert("queryString".into(), json!(query));
    }

    if !data.is_null() {
        let mut body_data = data.clone();
        if let Some(obj) = body_data.as_object_mut() {
            obj.shift_remove("e_r");
        }
        let encoded = urlencoded(&body_data);
        fields.insert(
            "body".into(),
            json!(base64::engine::general_purpose::STANDARD.encode(encoded.as_bytes())),
        );
    }

    // ⚠️ `queryString` **恒存在**，即使 uri 没有 query 也会是 `e_r=true`。
    //    已存在时 `insert` 会保留原位置（IndexMap 语义，与 JS 对象一致）。
    let qs = fields
        .get("queryString")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();
    fields.insert(
        "queryString".into(),
        json!(if qs.is_empty() {
            "e_r=true".to_string()
        } else {
            format!("{qs}&e_r=true")
        }),
    );

    serde_json::to_string(&Value::Object(fields)).map_err(|e| Error::Json(e.to_string()))
}

/// `new URLSearchParams(obj).toString()`
///
/// 编码规则（`application/x-www-form-urlencoded`）：字母数字与 `* - . _` 原样，
/// 空格变 `+`，其余按 UTF-8 逐字节 `%XX`（**大写 hex**）。
fn urlencoded(v: &Value) -> String {
    let obj = match v.as_object() {
        Some(o) => o,
        None => return String::new(),
    };

    obj.iter()
        .map(|(k, val)| format!("{}={}", form_encode(k), form_encode(&js_string(val))))
        .collect::<Vec<_>>()
        .join("&")
}

/// 单个值的 form 编码
fn form_encode(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for b in s.as_bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'*' | b'-' | b'.' | b'_' => {
                out.push(*b as char)
            }
            b' ' => out.push('+'),
            _ => out.push_str(&format!("%{b:02X}")),
        }
    }
    out
}

/// 模仿 JS 的 `String(v)`
fn js_string(v: &Value) -> String {
    match v {
        Value::String(s) => s.clone(),
        Value::Null => String::new(),
        other => other.to_string(),
    }
}

// ============================================================
//  加密
// ============================================================

/// `xeapiMidTransform`：16 字节随机前缀 + base64 串旋转
///
/// ```js
/// xored[i] = ciphertext[i] ^ random[i & 0x0f]
/// b64      = Buffer.from(xored.toString('base64'))     // ⚠️ base64 字符串的 UTF-8 字节
/// rot      = (random[0] & 0x0f) % b64.length
/// out      = random || b64[rot..] || b64[..rot]
/// ```
///
/// ⚠️ `Buffer.from(str)` 默认 UTF-8 —— 这里把 **base64 字符串当文本转字节**，
/// 不是 base64 解码。照做。
pub fn mid_transform(ciphertext: &[u8]) -> Vec<u8> {
    let mut random = [0u8; 16];
    rand::thread_rng().fill_bytes(&mut random);

    let xored: Vec<u8> = ciphertext
        .iter()
        .enumerate()
        .map(|(i, b)| b ^ random[i & 0x0f])
        .collect();

    let b64 = base64::engine::general_purpose::STANDARD.encode(&xored);
    let b64 = b64.as_bytes();

    let rot = if b64.is_empty() {
        0
    } else {
        (random[0] & 0x0f) as usize % b64.len()
    };

    let mut out = Vec::with_capacity(16 + b64.len());
    out.extend_from_slice(&random);
    out.extend_from_slice(&b64[rot..]);
    out.extend_from_slice(&b64[..rot]);
    out
}

/// 非标准 HKDF-SHA256：`prk = HMAC(0x00*32, shared)`，`okm = HMAC(prk, ephemeral || 0x01)`
///
/// ⚠️ 标准 HKDF-Extract 的 salt 是空或指定值，这里用**全零 32 字节**；
/// 标准的 info 是任意串，这里用 `ephemeralRaw || 0x01`。照做。
pub fn derive_aes_key(shared_secret: &[u8], ephemeral_raw: &[u8]) -> [u8; 16] {
    let shared = if shared_secret.is_empty() {
        [0u8; 32].to_vec()
    } else {
        shared_secret.to_vec()
    };

    let prk = hmac_sha256(&[0u8; 32], &shared);

    let mut msg = ephemeral_raw.to_vec();
    msg.push(1);
    let okm = hmac_sha256(&prk, &msg);

    let mut key = [0u8; 16];
    key.copy_from_slice(&okm[..16]);
    key
}

/// `xeapiEncryptS`：把 `dynamicKey` 用 X25519 + AES-GCM 封给上游
///
/// 明文：`base64(dynamicKey) + "|" + os + "|" + sk`
///
/// 容器：`ephemeralRaw(32) || iv(12) || ciphertext(n) || gcmTag(16)`
pub fn encrypt_s(dynamic_key: &[u8], state: &PublicKeyState, os: &str) -> Result<Vec<u8>> {
    let peer_raw = base64::engine::general_purpose::STANDARD
        .decode(&state.public_key)
        .map_err(|e| Error::Crypto(format!("X25519 公钥不是合法 Base64: {e}")))?;
    if peer_raw.len() != 32 {
        return Err(Error::Crypto(format!(
            "X25519 公钥应为 32 字节，实际 {}",
            peer_raw.len()
        )));
    }

    let peer = PublicKey::from(<[u8; 32]>::try_from(peer_raw.as_slice()).unwrap());

    // 每次调用生成临时密钥对（不复用会话）
    let mut sk_bytes = [0u8; 32];
    rand::thread_rng().fill_bytes(&mut sk_bytes);
    let ephemeral_secret = StaticSecret::from(sk_bytes);
    let ephemeral_public = PublicKey::from(&ephemeral_secret);
    let ephemeral_raw = ephemeral_public.as_bytes();

    let shared = ephemeral_secret.diffie_hellman(&peer);
    let aes_key = derive_aes_key(shared.as_bytes(), ephemeral_raw);

    let mut iv = [0u8; 12];
    rand::thread_rng().fill_bytes(&mut iv);

    let cipher = Aes128Gcm::new_from_slice(&aes_key)
        .map_err(|e| Error::Crypto(format!("AES-GCM 初始化失败: {e}")))?;

    let plaintext = format!(
        "{}|{}|{}",
        base64::engine::general_purpose::STANDARD.encode(dynamic_key),
        os,
        state.sk
    );

    // aes-gcm 的 encrypt 输出 = 密文 || tag(16)
    let ct = cipher
        .encrypt(Nonce::from_slice(&iv), plaintext.as_bytes())
        .map_err(|e| Error::Crypto(format!("AES-GCM 加密失败: {e}")))?;

    let mut out = Vec::with_capacity(32 + 12 + ct.len());
    out.extend_from_slice(ephemeral_raw);
    out.extend_from_slice(&iv);
    out.extend_from_slice(&ct);
    Ok(out)
}

/// 一次 xeapi 加密的结果
#[derive(Debug, Clone)]
pub struct XeapiBody {
    pub b: String,
    pub s: String,
    pub r: String,
}

impl XeapiBody {
    /// `B=<b64>&S=<b64>&R=<b64>`
    pub fn to_form(&self) -> String {
        format!(
            "B={}&S={}&R={}",
            urlencoding::encode(&self.b),
            urlencoding::encode(&self.s),
            urlencoding::encode(&self.r)
        )
    }
}

/// 完整加密一次 xeapi 请求
///
/// ⚠️ 不使用会话密钥轮换：每次都用随机 `dynamicKey`、`R` 的第二段留空。
/// 代价是每次多一次 ECDH（约 0.1ms），换来的是**无跨账号状态污染**
/// （原实现把 `xeapiSessionId/Key` 放在进程级全局，多账号并发会串）。
pub fn xeapi(
    uri: &str,
    data: &Value,
    state: &PublicKeyState,
    opt: &PlaintextOptions,
) -> Result<XeapiBody> {
    if !state.is_ready() {
        return Err(Error::Invalid(
            "xeapi 公钥未就绪（需先调用 register_xeapikey）".into(),
        ));
    }

    let plaintext = build_plaintext(uri, data, opt)?;

    // 调试：`NETEASE_DEBUG=1` 时打印明文，可与原 Node 实现逐字节对比
    if std::env::var("NETEASE_DEBUG").is_ok() {
        eprintln!("┌─ xeapi 明文 ({uri}) ─────────────");
        eprintln!("│ {plaintext}");
        eprintln!("│ {} 字节", plaintext.len());
        eprintln!("└──────────────────────────────────");
    }

    // ① t1 = AES-256-ECB(staticKey, plaintext)（PKCS7）
    let t1 = aes_ecb_encrypt(&XEAPI_STATIC_KEY, plaintext.as_bytes())?;
    // ② t2 = midTransform(t1)
    let t2 = mid_transform(&t1);

    // ③ dynamicKey：随机 16 字节
    let mut dynamic_key = [0u8; 16];
    rand::thread_rng().fill_bytes(&mut dynamic_key);

    // ④ B = AES-256-ECB(dynamicKey, t2)（PKCS7）
    let b = aes_ecb_encrypt(&dynamic_key, &t2)?;

    // ⑤ S
    let s = encrypt_s(&dynamic_key, state, "android")?;

    // ⑥ R = AES-256-ECB(staticKey, "{version}|{sessionId}")（PKCS7）
    //    无会话 → 第二段为空
    let r = aes_ecb_encrypt(&XEAPI_STATIC_KEY, format!("{}|", state.version).as_bytes())?;

    let b64 = base64::engine::general_purpose::STANDARD;
    Ok(XeapiBody {
        b: b64.encode(&b),
        s: b64.encode(&s),
        r: b64.encode(&r),
    })
}

// ============================================================
//  响应解密
// ============================================================

/// 解密 xeapi 响应
///
/// ⚠️ 用的是 **`eapiKey`（AES-128）**，不是 `xeapiStaticKey`。这是最容易搞混的一点。
///
/// 明文可能是 gzip（魔数 `1f 8b`）。
pub fn res_decrypt(body: &[u8]) -> Result<Value> {
    let decrypted = aes_ecb_decrypt(EAPI_KEY.as_bytes(), body)?;

    let plaintext = if decrypted.len() >= 2 && decrypted[0] == 0x1f && decrypted[1] == 0x8b {
        let mut out = Vec::new();
        flate2::read::GzDecoder::new(&decrypted[..])
            .read_to_end(&mut out)
            .map_err(|e| Error::Crypto(format!("xeapi 响应 gunzip 失败: {e}")))?;
        out
    } else {
        decrypted
    };

    serde_json::from_slice(&plaintext)
        .map_err(|e| Error::Json(format!("xeapi 响应不是 JSON: {e}")))
}

// ============================================================
//  公钥获取
// ============================================================

/// `xeapiSign(timestamp, nonce)` = `base64(HMAC-SHA256(signKey, timestamp + nonce))`
///
/// ## ⚠️ `xeapiSignKey` 是**当字符串用的**，不是 base64 解码
///
/// 源码里它是**字符串字面量**：
///
/// ```js
/// const xeapiSignKey = 'mUHCwVNWJbunMqAHf5MImuirT6plvs6VSFW62MGHstFQxhBGdEoIhLItH3djc4+FB/OKty3+lL2rGeoFBpVe5g=='
/// crypto.createHmac('sha256', xeapiSignKey)     // 字符串 → UTF-8 字节（88 字节）
/// ```
///
/// 它**看起来**像 Base64（也确实能解出 64 字节），但 Node 的 `createHmac`
/// 收到字符串时按 UTF-8 处理，不会解码。实测：
///
/// ```text
/// 当字符串(UTF-8) → data.code = 200  success
/// 当 base64 解码   → data.code = 403  Invalid signature
/// ```
///
/// ⚠️ 注意区分：`xeapiStaticKey` 是 `Buffer.from(hex,'hex')`（真的是字节），
/// 只有 `xeapiSignKey` 是字符串。
pub fn sign(timestamp: &str, nonce: &str) -> Result<String> {
    let mac = hmac_sha256(
        crate::crypto::XEAPI_SIGN_KEY.as_bytes(),
        format!("{timestamp}{nonce}").as_bytes(),
    );
    Ok(base64::engine::general_purpose::STANDARD.encode(mac))
}

/// 拉取 xeapi 公钥
///
/// ```text
/// POST {apiDomain}/api/gorilla/anti/crawler/security/key/get
/// Headers: User-Agent: <XEAPI_UA>; Cookie: deviceId=<urlencoded>
/// Body: appVersion=9.5.61 & currentKeyVersion= & deviceId= & nonce=<16位数字>
///       & os=android & requestType=active & signature=<HMAC>
///       & t1= & t2= & uid= & timestamp=<毫秒>
/// ```
///
/// ⚠️ 这条**不走普通的加密请求层** —— 它自己就是用来换取加密所需公钥的。
pub async fn fetch_public_key(
    http: &reqwest::Client,
    device_id: &str,
    old_version: &str,
) -> Result<PublicKeyState> {
    let timestamp = now_ms().to_string();
    let nonce = random_digits(16);
    let signature = sign(&timestamp, &nonce)?;

    // 顺序必须与 JS 的对象字面量一致
    let body = format!(
        "appVersion={APP_VERSION}&currentKeyVersion={}&deviceId={}&nonce={nonce}\
&os=android&requestType=active&signature={}&t1=&t2=&uid=&timestamp={timestamp}",
        urlencoding::encode(old_version),
        urlencoding::encode(device_id),
        urlencoding::encode(&signature),
    );

    let resp = http
        .post(format!("{API_DOMAIN}{KEY_GET_PATH}"))
        .header("User-Agent", XEAPI_UA)
        .header(
            "Cookie",
            if device_id.is_empty() {
                String::new()
            } else {
                format!("deviceId={}", urlencoding::encode(device_id))
            },
        )
        .header("Content-Type", "application/x-www-form-urlencoded")
        .body(body)
        .send()
        .await
        .map_err(Error::http)?;

    let raw = resp
        .bytes()
        .await
        .map_err(Error::http)?;
    let v: Value = serde_json::from_slice(&raw)
        .map_err(|e| Error::Json(format!("公钥接口响应不是 JSON: {e}")))?;

    parse_public_key_response(&v, &nonce)
}

/// 校验并解析公钥接口的响应
///
/// 三步校验，任一失败报错：
/// 1. `code == 200` 且 `data.encryptedData` 存在
/// 2. `sign(data.timestamp, nonce) == data.signature`
/// 3. 解密后 `sk` 存在
pub fn parse_public_key_response(v: &Value, nonce: &str) -> Result<PublicKeyState> {
    if v.get("code").and_then(Value::as_i64) != Some(200) {
        return Err(Error::Api {
            message: "公钥接口返回非 200".into(),
            code: v.get("code").and_then(Value::as_i64),
            status: 502,
            body: v.to_string(),
        });
    }

    let data = v
        .get("data")
        .ok_or_else(|| Error::Invalid("公钥响应缺少 data".into()))?;

    // ⚠️ 外层 code 恒为 200，真正的结果在 `data.code` 里。
    //    签名错时是 `data.code = 403, message = "Invalid signature"`，
    //    此时 `encryptedData` 为 null —— 不单独检查的话会报一个莫名其妙的
    //    「缺少 data.encryptedData」。
    if let Some(inner) = data.get("code").and_then(Value::as_i64) {
        if inner != 200 {
            return Err(Error::Api {
                message: data
                    .get("message")
                    .and_then(Value::as_str)
                    .unwrap_or("公钥接口失败")
                    .to_string(),
                code: Some(inner),
                status: 502,
                body: v.to_string(),
            });
        }
    }

    let encrypted = data
        .get("encryptedData")
        .and_then(Value::as_str)
        .ok_or_else(|| Error::Invalid("公钥响应缺少 data.encryptedData".into()))?;

    // ⚠️ 用**本次请求的 nonce** + **响应里的 timestamp** 重新签名
    let resp_ts = js_string(data.get("timestamp").unwrap_or(&Value::Null));
    let expect = sign(&resp_ts, nonce)?;
    let actual = data.get("signature").and_then(Value::as_str).unwrap_or("");
    if expect != actual {
        return Err(Error::Crypto(format!(
            "公钥响应验签失败: 期望 {expect}, 实际 {actual}"
        )));
    }

    let raw = base64::engine::general_purpose::STANDARD
        .decode(encrypted)
        .map_err(|e| Error::Crypto(format!("encryptedData 不是合法 Base64: {e}")))?;
    let plain = aes_ecb_decrypt(&XEAPI_STATIC_KEY, &raw)?;
    let obj: Value = serde_json::from_slice(&plain)
        .map_err(|e| Error::Json(format!("公钥明文不是 JSON: {e}")))?;

    let s = |k: &str| obj.get(k).and_then(Value::as_str).unwrap_or("").to_string();

    let state = PublicKeyState {
        version: s("version"),
        public_key: s("publicKey"),
        sk: s("sk"),
        device_id: s("deviceId"),
    };

    if state.sk.is_empty() {
        return Err(Error::Invalid("公钥响应缺少 sk".into()));
    }
    Ok(state)
}

// ============================================================
//  内部工具
// ============================================================

/// 显式引用，避免 `aes` 的 `KeyInit` 与 `aes_gcm` 的同名 trait 冲突告警
#[allow(dead_code)]
fn _assert_traits() {
    fn f<K: KeyInit + BlockEncrypt + BlockDecrypt>() {}
    f::<Aes128>();
    f::<Aes256>();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn form_encoding_matches_urlsearchparams() {
        // 字母数字与 * - . _ 原样；空格 → +；其余 %XX 大写
        assert_eq!(form_encode("abcXYZ019"), "abcXYZ019");
        assert_eq!(form_encode("a b"), "a+b");
        assert_eq!(form_encode(r#"["400002_0"]"#), "%5B%22400002_0%22%5D");
        assert_eq!(form_encode("a&b=c"), "a%26b%3Dc");
        assert_eq!(form_encode("海"), "%E6%B5%B7");
    }

    #[test]
    fn plaintext_has_exactly_expected_shape() {
        let p = build_plaintext(
            "/api/ad/get",
            &json!({"type_ids": "[\"400002_0\"]"}),
            &PlaintextOptions::default(),
        )
        .unwrap();

        let v: Value = serde_json::from_str(&p).unwrap();
        // ⚠️ uri 没有 query 时，`queryString` 是**最后**插入的 —— `body` 在前。
        //    这个顺序会影响 AES 的输入字节，实测搞反会让 /register/anonimous 报 400。
        assert!(
            p.find("body").unwrap() < p.find("queryString").unwrap(),
            "body 应在 queryString 之前: {p}"
        );
        assert_eq!(v["queryString"], "e_r=true");
        assert!(v.get("contentType").is_none(), "默认 content-type 不该出现");
        assert!(v.get("method").is_none(), "POST 不该出现 method");

        // body 是 base64，解出来是 urlencoded
        let body = base64::engine::general_purpose::STANDARD
            .decode(v["body"].as_str().unwrap())
            .unwrap();
        assert_eq!(
            String::from_utf8(body).unwrap(),
            "type_ids=%5B%22400002_0%22%5D"
        );
    }

    #[test]
    fn plaintext_puts_query_string_first_when_uri_has_query() {
        let p = build_plaintext("/api/x?a=1", &json!({"b": "2"}), &PlaintextOptions::default())
            .unwrap();
        // uri 自带 query 时 queryString 先插入 → 排在 body 前面
        assert!(
            p.find("queryString").unwrap() < p.find("body").unwrap(),
            "带 query 时应是 queryString 在前: {p}"
        );
        assert!(p.contains(r#""queryString":"a=1&e_r=true""#), "{p}");
    }

    #[test]
    fn plaintext_drops_e_r_from_body() {
        let p = build_plaintext(
            "/api/x",
            &json!({"a": "1", "e_r": false}),
            &PlaintextOptions::default(),
        )
        .unwrap();
        let v: Value = serde_json::from_str(&p).unwrap();
        let body = base64::engine::general_purpose::STANDARD
            .decode(v["body"].as_str().unwrap())
            .unwrap();
        let s = String::from_utf8(body).unwrap();
        assert!(!s.contains("e_r"), "e_r 应被移出 body: {s}");
        assert_eq!(v["queryString"], "e_r=true");
    }

    #[test]
    fn mid_transform_layout() {
        let ct = vec![0xabu8; 32];
        let out = mid_transform(&ct);
        // 16 字节随机 + ceil(32/3)*4 = 44 字节的 base64 文本
        assert_eq!(out.len(), 16 + 44);
    }

    #[test]
    fn derive_key_is_deterministic_and_16_bytes() {
        let shared = [7u8; 32];
        let eph = [9u8; 32];
        let a = derive_aes_key(&shared, &eph);
        let b = derive_aes_key(&shared, &eph);
        assert_eq!(a, b);
        assert_eq!(a.len(), 16);

        // 换共享密钥结果必须变
        assert_ne!(a, derive_aes_key(&[8u8; 32], &eph));
    }

    #[test]
    fn derive_key_falls_back_on_empty_shared() {
        // 空共享密钥 → 用 32 个零字节（防御性写法）
        assert_eq!(
            derive_aes_key(&[], &[1u8; 32]),
            derive_aes_key(&[0u8; 32], &[1u8; 32])
        );
    }

    #[test]
    fn encrypt_s_layout() {
        let state = PublicKeyState {
            version: "1".into(),
            // 32 字节裸公钥（base64）
            public_key: base64::engine::general_purpose::STANDARD.encode([5u8; 32]),
            sk: "SK".into(),
            device_id: String::new(),
        };
        let s = encrypt_s(&[0u8; 16], &state, "android").unwrap();
        // ephemeralRaw(32) + iv(12) + 密文 + tag(16)
        assert!(s.len() >= 32 + 12 + 16);
        // 明文 "base64(16B)|android|SK" = 24 + 1 + 7 + 1 + 2 = 35 字节 → 密文 35
        assert_eq!(s.len(), 32 + 12 + 35 + 16);
    }

    #[test]
    fn sign_is_base64_hmac() {
        let s = sign("1700000000000", "1234567890123456").unwrap();
        let raw = base64::engine::general_purpose::STANDARD.decode(&s).unwrap();
        assert_eq!(raw.len(), 32, "HMAC-SHA256 应为 32 字节");
    }

    #[test]
    fn res_decrypt_rejects_bad_length() {
        // 带 PKCS7 的 ECB 仍要求密文是整块
        assert!(res_decrypt(&[0u8; 15]).is_err());
    }

    #[test]
    fn public_key_response_rejects_bad_signature() {
        let v = json!({"code": 200, "data": {"encryptedData": "AAAA", "timestamp": "1", "signature": "x"}});
        assert!(parse_public_key_response(&v, "n").is_err());
    }
}
