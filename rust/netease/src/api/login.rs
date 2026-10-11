//! 登录与会话（9 条路由）
//!
//! | 路由 | 上游 | 加密 |
//! | --- | --- | --- |
//! | `/login/status` | `/api/w/nuser/account/get` | weapi |
//! | `/login/refresh` | `/api/login/token/refresh` | eapi |
//! | `/login/cellphone` | `/api/w/login/cellphone` | weapi |
//! | `/captcha/sent` | `/api/sms/captcha/sent` | weapi |
//! | `/login/qr/key` | `/api/login/qrcode/unikey` | eapi |
//! | `/login/qr/create` | **无请求**（本地生成） | — |
//! | `/login/qr/check` | `/api/login/qrcode/client/login` | eapi |
//! | `/user/account` | `/api/nuser/account/get` | weapi |
//! | `/vip/info` | `/api/music-vip-membership/front/vip/info` | weapi |

use base64::Engine;
use serde_json::{json, Value};

use crate::api::{ServerResponse, ServerRequest};
use crate::crypto::md5_hex;
use crate::{now_ms, Result};

// ============================================================
//  /login/status
// ============================================================

/// 登录状态
///
/// ⚠️ 上游路径是 `/api/w/nuser/account/get`（**带 `/w/`**），
/// weapi 分支会去掉 `/api/` 再拼 `/weapi/`，所以完整 URL 是
/// `https://music.163.com/weapi/w/nuser/account/get`。
///
/// ⚠️ 响应被**包一层 `data`** —— 客户端读的是 `response.data['data']['code']`。
pub async fn login_status(t: &ServerRequest<'_>) -> Result<ServerResponse> {
    let r = t.send_weapi("/api/w/nuser/account/get", json!({})).await?;
    Ok(ServerResponse::wrap_data(r))
}

// ============================================================
//  /user/account
// ============================================================

/// 用户账号信息
///
/// ⚠️ 与 [`login_status`] 的上游**不同**：这里是 `/api/nuser/account/get`（**无 `/w/`**）。
///
/// 客户端读 `['account']['id']`、`['profile']['avatarUrl']`、`['profile']['nickname']`。
pub async fn user_account(t: &ServerRequest<'_>) -> Result<ServerResponse> {
    let r = t.send_weapi("/api/nuser/account/get", json!({})).await?;
    Ok(ServerResponse::passthrough(r))
}

// ============================================================
//  /login/cellphone
// ============================================================

/// 手机验证码登录
///
/// ⚠️ **动态 key**：有 `captcha` 时字段名是 `captcha`，否则是 `password`。
/// ⚠️ `password` 做 **MD5（小写 hex）**。
/// ⚠️ `avatarImgId_str` → `avatarImgIdStr` 是**全局字符串替换**（会命中所有嵌套层级）。
pub async fn login_cellphone(
    t: &ServerRequest<'_>,
    phone: &str,
    captcha: &str,
    password: &str,
    countrycode: &str,
) -> Result<ServerResponse> {
    let mut data = json!({
        "type": "1",
        "https": "true",
        "phone": phone,
        "countrycode": if countrycode.is_empty() { "86" } else { countrycode },
        "remember": "true",
        "secureCaptcha": "",
    });

    if !captcha.is_empty() {
        data["captcha"] = json!(captcha);
    } else {
        data["password"] = json!(md5_hex(password.as_bytes()));
    }

    let r = t.send_weapi("/api/w/login/cellphone", data).await?;
    let r = rename_avatar_img_id(r);

    Ok(ServerResponse::with_cookie_field(r))
}

/// 把响应体里的 `avatarImgId_str` 全部换成 `avatarImgIdStr`
///
/// 对应 `JSON.parse(JSON.stringify(body).replace(/avatarImgId_str/g,'avatarImgIdStr'))`
/// —— 是**对序列化后的整段文本**做替换，所以键名与值里都会命中。
fn rename_avatar_img_id(r: crate::request::ApiResponse) -> crate::request::ApiResponse {
    let text = r.body.to_string().replace("avatarImgId_str", "avatarImgIdStr");
    crate::request::ApiResponse {
        body: serde_json::from_str(&text).unwrap_or(r.body),
        ..r
    }
}

// ============================================================
//  /captcha/sent
// ============================================================

/// 发送手机验证码
///
/// ⚠️ 参数名是 `phone` → 上游字段 `cellphone`。
pub async fn captcha_sent(t: &ServerRequest<'_>, phone: &str, ctcode: &str) -> Result<ServerResponse> {
    let r = t
        .send_weapi(
            "/api/sms/captcha/sent",
            json!({
                "ctcode": if ctcode.is_empty() { "86" } else { ctcode },
                "secrete": "music_middleuser_pclogin",
                "cellphone": phone,
            }),
        )
        .await?;
    Ok(ServerResponse::passthrough(r))
}

// ============================================================
//  /login/refresh
// ============================================================

/// 刷新登录令牌
///
/// ⚠️ 客户端只在 `loginType == 1`（手机登录）时调用。
pub async fn login_refresh(t: &ServerRequest<'_>) -> Result<ServerResponse> {
    let r = t.send_eapi("/api/login/token/refresh", json!({})).await?;
    Ok(ServerResponse::with_cookie_field(r))
}

// ============================================================
//  /login/qr/key
// ============================================================

/// 生成二维码 key
///
/// ⚠️ 上游 body **整体塞进 `body.data`**，并在外层补 `code: 200`。
/// 客户端读 `response.data['data']['unikey']`。
pub async fn qr_key(t: &ServerRequest<'_>) -> Result<ServerResponse> {
    let r = t
        .send_eapi("/api/login/qrcode/unikey", json!({ "type": 3 }))
        .await?;

    let body = json!({
        "data": r.body,
        "code": 200,
    });

    Ok(ServerResponse::new(body, r.cookies))
}

// ============================================================
//  /login/qr/create
// ============================================================

/// 生成二维码图片（**不发任何网易请求**）
///
/// ```text
/// url = "https://music.163.com/login?codekey=<key>"
/// platform == "web" 时追加 "&chainId=v1_<deviceId>_web_login_<now_ms>"
/// ```
///
/// ⚠️ 客户端传 `qrimg=true`，需要返回 **data URL**（`data:image/png;base64,...`）。
/// ⚠️ 顶层多一个 `code` 字段（其他接口没有），无害但保留。
pub fn qr_create(key: &str, platform: &str, want_image: bool, device_id: &str) -> ServerResponse {
    let mut url = format!("https://music.163.com/login?codekey={key}");

    if platform == "web" {
        // `generateChainId` 里 `deviceId = cookie['sDeviceId'] || 'unknown-' + rand(1e6)`
        // HTTP 形态下 cookie 是对象、取不到 sDeviceId，所以这里也用 device_id 兜底。
        let dev = if device_id.is_empty() {
            format!("unknown-{}", crate::now_ms() % 1_000_000)
        } else {
            device_id.to_string()
        };
        url += &format!("&chainId=v1_{dev}_web_login_{}", now_ms());
    }

    let qrimg = if want_image {
        qr_data_url(&url).unwrap_or_default()
    } else {
        String::new()
    };

    ServerResponse::new(
        json!({
            "code": 200,
            "data": {
                "qrurl": url,
                "qrimg": qrimg,
            }
        }),
        Vec::new(),
    )
}

/// 把文本编码成 PNG 的 data URL
fn qr_data_url(text: &str) -> Option<String> {
    use std::io::Cursor;

    let code = qrcode::QrCode::new(text.as_bytes()).ok()?;
    let img = code
        .render::<image::Luma<u8>>()
        .min_dimensions(200, 200)
        .build();

    let mut png = Vec::new();
    image::DynamicImage::ImageLuma8(img)
        .write_to(&mut Cursor::new(&mut png), image::ImageFormat::Png)
        .ok()?;

    Some(format!(
        "data:image/png;base64,{}",
        base64::engine::general_purpose::STANDARD.encode(png)
    ))
}

// ============================================================
//  /login/qr/check
// ============================================================

/// 检测扫码状态
///
/// ⚠️ 客户端轮询读 `response.data['code']`，`803` 表示成功、`800` 表示过期。
/// 这些码在 `SPECIAL_STATUS_CODES` 里会被映射成 HTTP 200，但 **body 里的 `code`
/// 保持不变** —— 客户端读的正是 body 里的值，所以正确。
pub async fn qr_check(t: &ServerRequest<'_>, key: &str) -> Result<ServerResponse> {
    let r = t
        .send_eapi(
            "/api/login/qrcode/client/login",
            json!({ "key": key, "type": 3 }),
        )
        .await?;

    Ok(ServerResponse::with_cookie_field(r))
}

// ============================================================
//  /vip/info
// ============================================================

/// VIP 信息
///
/// ⚠️ 客户端读 `response.data['data']['redVipAnnualCount']`，`== -1` 表示非 VIP。
pub async fn vip_info(t: &ServerRequest<'_>, uid: &str) -> Result<ServerResponse> {
    let r = t
        .send_weapi(
            "/api/music-vip-membership/front/vip/info",
            json!({ "userId": uid }),
        )
        .await?;
    Ok(ServerResponse::passthrough(r))
}

// ============================================================
//  匿名注册（xeapi，需要公钥）
// ============================================================

/// `cloudmusic_dll_encode_id` 的 XOR 密钥
///
/// ⚠️ 长度是 **18**，不是 22 —— 重写时数一遍：
/// `3 g o 8 & $ 8 * 3 * 3 h 0 k ( 2 ) 2`
const ID_XOR_KEY_1: &str = "3go8&$8*3*3h0k(2)2";

/// `cloudmusic_dll_encode_id(device_id)`
///
/// ```text
/// 1. xored[i] = deviceId.charCodeAt(i) XOR ID_XOR_KEY_1.charCodeAt(i % 18)
/// 2. digest   = MD5(UTF8(xoredString))
/// 3. 返回 base64(digest)
/// ```
///
/// ⚠️ `xoredString` 在 JS 里是**码元串**（charCode 可能 > 127），
/// `CryptoJS.enc.Utf8.parse` 会把它按 UTF-8 **重新编码** —— 这与原始字节不等价。
/// 这里精确复刻这个往返：先按 `u32` 码点收集，再各自编码成 UTF-8。
pub fn cloudmusic_dll_encode_id(some_id: &str) -> String {
    let key: Vec<u32> = ID_XOR_KEY_1.chars().map(|c| c as u32).collect();

    // ① XOR（按 UTF-16 码元，与 JS 的 charCodeAt 一致）
    let units: Vec<u16> = some_id.encode_utf16().collect();
    let xored: String = units
        .iter()
        .enumerate()
        .map(|(i, u)| {
            let c = (*u as u32) ^ key[i % key.len()];
            // 代理区码点无法成为合法 char，按 JS 的行为退化成替换字符
            char::from_u32(c).unwrap_or('\u{FFFD}')
        })
        .collect();

    // ② MD5(UTF8(xoredString))
    let digest = crate::crypto::md5_bytes(xored.as_bytes());

    // ③ base64
    base64::engine::general_purpose::STANDARD.encode(digest)
}

/// 匿名注册的 `username` 参数
///
/// `base64(UTF8("{device_id} {cloudmusic_dll_encode_id(device_id)}"))`
pub fn anonymous_username(device_id: &str) -> String {
    let inner = format!("{device_id} {}", cloudmusic_dll_encode_id(device_id));
    base64::engine::general_purpose::STANDARD.encode(inner.as_bytes())
}

/// 从响应体里取出 `MUSIC_A`（匿名 token）
pub fn extract_music_a(body: &Value) -> Option<String> {
    body.pointer("/data/anonymousToken")
        .or_else(|| body.get("anonymousToken"))
        .and_then(|v| v.as_str())
        .map(str::to_string)
}

/// 匿名注册（xeapi）
///
/// 对应 `module/register_anonimous.js`。**这是启动流程的关键依赖** ——
/// 没有它未登录状态下没有 `MUSIC_A` 回退，部分接口会返回 `code: 301`（需要登录）。
///
/// ```text
/// data = { username: base64(UTF8("<deviceId> <cloudmusic_dll_encode_id(deviceId)>")) }
/// POST {xeapiDomain}/xeapi/register/anonimous   crypto=xeapi
/// ```
///
/// ⚠️ 原实现每次调用都**重新生成 deviceId** 并写进 `global.deviceId`。
/// 这里不这么做 —— 设备身份由 [`crate::DeviceIdentity`] 持有且持久化，
/// 传进来即可（原行为是最明显的风控特征，见精简版文档 §07 差异表 #2）。
pub async fn register_anonimous(
    t: &ServerRequest<'_>,
    device_id: &str,
) -> Result<ServerResponse> {
    let username = anonymous_username(device_id);

    let r = t
        .send_xeapi(
            "/api/register/anonimous",
            json!({ "username": username }),
        )
        .await?;

    Ok(ServerResponse::with_cookie_field(r))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn xor_key_is_18_chars() {
        assert_eq!(ID_XOR_KEY_1.chars().count(), 18);
    }

    #[test]
    fn encode_id_is_deterministic_and_base64() {
        let a = cloudmusic_dll_encode_id("ABCDEF0123456789");
        let b = cloudmusic_dll_encode_id("ABCDEF0123456789");
        assert_eq!(a, b);
        // 16 字节摘要 → Base64 24 字符
        assert_eq!(a.len(), 24);
        assert!(a.ends_with("=="));
    }

    #[test]
    fn anonymous_username_shape() {
        let u = anonymous_username("ABC123");
        // base64 解码后应是 "ABC123 <24字符摘要>"
        let raw = base64::engine::general_purpose::STANDARD.decode(&u).unwrap();
        let s = String::from_utf8(raw).unwrap();
        assert!(s.starts_with("ABC123 "));
        assert_eq!(s.len(), 7 + 24);
    }

    #[test]
    fn qr_create_builds_url_without_network() {
        let r = qr_create("KEY123", "pc", false, "");
        assert_eq!(r.body["code"], 200);
        assert_eq!(
            r.body["data"]["qrurl"],
            "https://music.163.com/login?codekey=KEY123"
        );
        assert_eq!(r.body["data"]["qrimg"], "");
        assert!(r.cookies.is_empty());
    }

    #[test]
    fn qr_create_web_platform_adds_chain_id() {
        let r = qr_create("K", "web", false, "DEV");
        let url = r.body["data"]["qrurl"].as_str().unwrap();
        assert!(url.contains("&chainId=v1_DEV_web_login_"));
    }

    #[test]
    fn qr_create_makes_a_png_data_url() {
        let r = qr_create("KEY123", "pc", true, "");
        let img = r.body["data"]["qrimg"].as_str().unwrap();
        assert!(img.starts_with("data:image/png;base64,"), "实际: {}", &img[..40.min(img.len())]);
        assert!(img.len() > 200);
    }

    #[test]
    fn avatar_rename_hits_nested_keys_and_values() {
        let r = crate::request::ApiResponse {
            status: 200,
            body: json!({"profile": {"avatarImgId_str": "v_str"}, "note": "avatarImgId_str"}),
            cookies: vec![],
        };
        let out = rename_avatar_img_id(r);
        assert_eq!(out.body["profile"]["avatarImgIdStr"], "v_str");
        assert_eq!(out.body["note"], "avatarImgIdStr");
    }

    #[test]
    fn extract_music_a_from_nested_data() {
        assert_eq!(
            extract_music_a(&json!({"data": {"anonymousToken": "T"}})),
            Some("T".into())
        );
        assert_eq!(extract_music_a(&json!({"code": 200})), None);
    }
}
