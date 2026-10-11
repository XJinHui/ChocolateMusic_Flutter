//! 登录与设备注册
//!
//! 对应 `KuGou.dart` 的 `getDfid` / `getVerificationCode` / `getQrCode` /
//! `loginByQrCode` / `loginByMobile` / `refreshToken`。

use crate::crypto::{crypto_aes_decrypt, crypto_aes_encrypt, playlist_aes_decrypt,
                    playlist_aes_encrypt, rsa_encrypt2, rsa_raw_encrypt};
use crate::platform::Platform;
use crate::request::{now_millis, EncryptType, RequestOptions, ResponseType, Transport};
use crate::{Error, Result};
use serde_json::{json, Value};

// ============================================================
//  常量
// ============================================================

/// `login_cellphone` / `login_token` 共用的固定 AES 密钥
const LITE_T2_KEY: &str = "fd14b35e3f81af3817a20ae7adae7020";
const LITE_T2_IV: &str = "17a20ae7adae7020";
const LITE_T1_KEY: &str = "5e4ef500e9597fe004bd09a46d8add98";
const LITE_T1_IV: &str = "04bd09a46d8add98";

/// 标准版登录请求体里的固定 `t3` 字段（Base64 of `"0,0,0,0,0,0,0,0,0"`）
const LOGIN_T3: &str = "MCwwLDAsMCwwLDAsMCwwLDA=";

/// `login_token` 的 `p3` 字段密钥（随平台）
const TOKEN_KEY: &str = "90b8382a1bb4ccdcf063102053fd75b8";
const TOKEN_IV: &str = "f063102053fd75b8";
const TOKEN_LITE_KEY: &str = "c24f74ca2820225badc01946dba4fdf7";
const TOKEN_LITE_IV: &str = "adc01946dba4fdf7";


// ============================================================
//  设备注册
// ============================================================

/// 设备注册
///
/// 对应 Dart 的 `getDfid()`。
///
/// ```text
/// POST https://userservice.kugou.com/risk/v2/r_register_dev
/// data   = Base64(AES-128-CBC(31 个设备字段))      ← playlistAesEncrypt
/// params = { part: 1, platid: 1, p: RSA_PKCS1({aes, uid, token}) }
/// 响应   = AES-128-CBC 解密 → { status, data: { dfid } }
/// ```
///
/// 返回**解密后的完整响应体**（未做状态判断），供 [`crate::raw`] 原样透传给 Dart。
/// 需要 `dfid` 本身请用 [`register_dev`]。
pub(crate) async fn register_dev_body(t: &Transport) -> Result<Value> {
    let guid = t.device.guid.clone();

    // 31 个设备字段
    let data_map = json!({
        "availableRamSize": 4983533568u64,
        "availableRomSize": 48114719,
        "availableSDSize": 48114717,
        "basebandVer": "",
        "batteryLevel": 100,
        "batteryStatus": 3,
        "brand": "Redmi",
        "buildSerial": "unknown",
        "device": "marble",
        "imei": guid,
        "imsi": "",
        "manufacturer": "Xiaomi",
        "uuid": guid,
        "accelerometer": false, "accelerometerValue": "",
        "gravity": false, "gravityValue": "",
        "gyroscope": false, "gyroscopeValue": "",
        "light": false, "lightValue": "",
        "magnetic": false, "magneticValue": "",
        "orientation": false, "orientationValue": "",
        "pressure": false, "pressureValue": "",
        "step_counter": false, "step_counterValue": "",
        "temperature": false, "temperatureValue": ""
    });

    // ① AES 加密设备信息
    let aes = playlist_aes_encrypt(&data_map.to_string());

    // ② RSA 加密会话串
    let p = rsa_encrypt2(
        json!({ "aes": aes.key, "uid": t.account.userid, "token": t.account.token })
            .to_string()
            .as_bytes(),
        t.platform.rsa_public_key(),
    )?;

    let resp = t
        .send(
            RequestOptions::post("/risk/v2/r_register_dev")
                .base_url("https://userservice.kugou.com")
                .param("part", 1)
                .param("platid", 1)
                .param("p", p)
                .body_bytes(aes.str.into_bytes())
                .response_type(ResponseType::Bytes),
        )
        .await?;

    // ③ 解密响应
    let plain = playlist_aes_decrypt(&base64_encode(&resp.raw), &aes.key);
    serde_json::from_str(&plain)
        .map_err(|e| Error::Invalid(format!("register_dev 响应解密失败: {e}")))
}

/// 获取 `dfid`（设备指纹 ID）
///
/// 对应 Dart 的 `getDfid()`。成功后返回 `dfid`，调用方应持久化。
pub async fn register_dev(t: &Transport) -> Result<String> {
    let body = register_dev_body(t).await?;

    if body.get("status").and_then(|v| v.as_i64()) != Some(1) {
        return Err(Error::Invalid(format!("register_dev 失败: {body}")));
    }

    body.pointer("/data/dfid")
        .and_then(|v| v.as_str())
        .map(str::to_string)
        .ok_or_else(|| Error::Invalid(format!("register_dev 未返回 dfid: {body}")))
}

// ============================================================
//  验证码
// ============================================================

/// 发送手机验证码
///
/// 对应 Dart 的 `getVerificationCode(mobile, _)`。
///
/// ⚠️ 原实现此接口的 cookie 只带 `mid`，因此 `dfid` 为 `-`。
/// 构造「发送手机验证码」请求
pub(crate) fn build_captcha_sent(mobile: &str) -> RequestOptions {
    let body = json!({
        "businessid": 5,
        "mobile": mobile,
        "plat": 3
    });

    RequestOptions::post("/v7/send_mobile_code")
        .base_url("http://login.user.kugou.com")
        .dfid("-")
        .json_body(&body)
}

pub async fn captcha_sent(t: &Transport, mobile: &str) -> Result<()> {
    t.send(build_captcha_sent(mobile)).await?;
    Ok(())
}

// ============================================================
//  二维码登录
// ============================================================

/// 生成二维码 key
///
/// 对应 Dart 的 `getQrCode` 的第一步。
///
/// 返回 `(key, qrcode_img)`：
/// - `key` 传给 [`qr_check`]
/// - `qrcode_img` 是 `data:image/png;base64,...`，可直接渲染
/// 构造「生成二维码 key」请求
pub(crate) fn build_qr_key(t: &Transport) -> RequestOptions {
    let appid = t.platform.appid();
    let qrcode_txt = format!(
        "https://h5.kugou.com/apps/loginQRCode/html/index.html?appid={appid}&"
    );

    RequestOptions::get("/v2/qrcode")
        .base_url("https://login-user.kugou.com")
        .encrypt_type(EncryptType::Web)
        .param("appid", 1001)
        .param("type", 1)
        .param("plat", 4)
        .param("qrcode_txt", qrcode_txt)
        .param("srcappid", 2919)
}

pub async fn qr_key(t: &Transport) -> Result<(String, String)> {
    let resp = t.send(build_qr_key(t)).await?;

    let key = resp
        .str_at(&["data", "qrcode"])
        .ok_or_else(|| Error::Invalid(format!("未返回 qrcode: {}", resp.body)))?;
    let img = resp.str_at(&["data", "qrcode_img"]).unwrap_or_default();
    Ok((key, img))
}

/// 二维码扫码状态
#[derive(Debug, Clone)]
pub enum QrStatus {
    /// 二维码已过期（`0`）
    Expired,
    /// 等待扫码（`1`）
    Waiting,
    /// 已扫码，待确认（`2`）
    Scanned,
    /// 授权成功（`4`），携带凭据
    Success {
        token: String,
        userid: String,
        nickname: String,
        pic: String,
    },
    /// 未知状态码
    Unknown(i64),
}

impl QrStatus {
    pub fn is_terminal(&self) -> bool {
        matches!(self, QrStatus::Expired | QrStatus::Success { .. })
    }
}

/// 检测扫码状态
///
/// 对应 Dart 的 `loginByQrCode` 循环体。
///
/// ⚠️ 状态码**没有 3**，是上游定义的跳跃取值。
/// 构造「检测扫码状态」请求
pub(crate) fn build_qr_check(t: &Transport, key: &str) -> RequestOptions {
    RequestOptions::get("/v2/get_userinfo_qrcode")
        .base_url("https://login-user.kugou.com")
        .encrypt_type(EncryptType::Web)
        .param("plat", 4)
        .param("appid", t.platform.appid())
        .param("srcappid", 2919)
        .param("qrcode", key)
        .param("dev", t.device.dev.clone())
}

pub async fn qr_check(t: &Transport, key: &str) -> Result<QrStatus> {
    let resp = t.send(build_qr_check(t, key)).await?;

    let code = resp.i64_at(&["data", "status"]).unwrap_or(-1);
    Ok(match code {
        0 => QrStatus::Expired,
        1 => QrStatus::Waiting,
        2 => QrStatus::Scanned,
        4 => QrStatus::Success {
            token: resp.str_at(&["data", "token"]).unwrap_or_default(),
            userid: resp.str_at(&["data", "userid"]).unwrap_or_default(),
            nickname: resp.str_at(&["data", "nickname"]).unwrap_or_default(),
            pic: resp.str_at(&["data", "pic"]).unwrap_or_default(),
        },
        other => QrStatus::Unknown(other),
    })
}

// ============================================================
//  手机验证码登录
// ============================================================

/// 登录结果
#[derive(Debug, Clone, Default)]
pub struct LoginResult {
    pub token: String,
    pub userid: String,
    pub vip_type: i64,
    pub vip_token: String,
    pub t_expire_time: i64,
    pub nickname: String,
    pub pic: String,
    /// 概念版返回的会话标记
    pub t1: String,
}

/// 手机验证码登录
///
/// 对应 Dart 的 `loginByMobile(mobile, _, code)`。
///
/// 服务端会用请求时的 AES 密钥加密 `data.secu_params`，这里自动解密并合并。
///
/// 返回**合并后的完整响应体**，供 [`crate::raw`] 原样透传。
pub(crate) async fn login_cellphone_body(
    t: &Transport,
    mobile: &str,
    code: &str,
) -> Result<Value> {
    let is_lite = t.platform == Platform::Lite;
    let date_time = now_millis();

    // ① 加密 {mobile, code}
    let encrypt = crypto_aes_encrypt(&json!({ "mobile": mobile, "code": code }).to_string(), None);

    // ② 手机号脱敏：13800138000 → 13*****0
    let masked = mask_mobile(mobile);

    // ③ t1 / t2
    let t2_plain = format!(
        "{}|0f607264fc6318a92b9e13c65db7cd3c|{}|{}|{}",
        t.device.guid, t.device.mac, t.device.dev, date_time
    );
    let t2 = crypto_aes_encrypt(&t2_plain, Some((LITE_T2_KEY, LITE_T2_IV)));
    let t1 = crypto_aes_encrypt(&format!("|{date_time}"), Some((LITE_T1_KEY, LITE_T1_IV)));

    // ④ pk：裸 RSA
    let pk = rsa_raw_encrypt(
        json!({ "clienttime_ms": date_time, "key": encrypt.key })
            .to_string()
            .as_bytes(),
        t.platform.rsa_public_key(),
    )?
    .to_uppercase();

    let mut body = json!({
        "plat": 1,
        "support_multi": 1,
        "t1": if is_lite { json!(t1.str) } else { json!(0) },
        "t2": if is_lite { json!(t2.str) } else { json!(0) },
        "clienttime_ms": date_time,
        "mobile": masked,
        "key": crate::sign::sign_params_key(t.platform, &date_time.to_string(), None, None),
        "pk": pk,
        "params": encrypt.str
    });

    if !t.account.userid.is_empty() {
        body["userid"] = json!(t.account.userid);
    }

    if is_lite {
        body["dfid"] = json!(t.dfid());
        body["dev"] = json!(t.device.dev);
        body["gitversion"] = json!("5f0b7c4");
    } else {
        body["t3"] = json!(LOGIN_T3);
    }

    let resp = t
        .send(
            RequestOptions::post("/v7/login_by_verifycode")
                .base_url("https://loginserviceretry.kugou.com")
                .header("support-calm", "1")
                .header("User-Agent", "Android16-1070-11440-130-0-LOGIN-wifi")
                .json_body(&body),
        )
        .await?;

    Ok(merge_login_body(&resp, &encrypt.key))
}

/// 手机验证码登录（强类型）
pub async fn login_cellphone(t: &Transport, mobile: &str, code: &str) -> Result<LoginResult> {
    let body = login_cellphone_body(t, mobile, code).await?;
    ensure_login_ok(&body)?;
    Ok(login_result_from(&body))
}

// ============================================================
//  刷新 token
// ============================================================

/// 刷新登录令牌
///
/// 对应 Dart 的 `refreshToken()`。
///
/// ⚠️ 本接口有三处与其他登录接口不一致：
/// 1. `pk` **没有** `.to_uppercase()`
/// 2. `params` 是**空对象**的 AES
/// 3. `secu_params` 用 `encrypt_params.key` 解密（不是 `p3` 的密钥）
///
/// 返回**合并后的完整响应体**，供 [`crate::raw`] 原样透传。
pub(crate) async fn login_token_body(t: &Transport) -> Result<Value> {
    let is_lite = t.platform == Platform::Lite;
    let date_now = now_millis();

    // ① p3：固定密钥加密 {clienttime(秒), token}
    let (key, iv) = if is_lite {
        (TOKEN_LITE_KEY, TOKEN_LITE_IV)
    } else {
        (TOKEN_KEY, TOKEN_IV)
    };
    let p3 = crypto_aes_encrypt(
        &json!({ "clienttime": crate::request::now_secs(), "token": t.account.token }).to_string(),
        Some((key, iv)),
    );

    // ② 空对象的随机密钥，用于 params 与 pk
    let encrypt_params = crypto_aes_encrypt("{}", None);
    let pk = rsa_raw_encrypt(
        json!({ "clienttime_ms": date_now, "key": encrypt_params.key })
            .to_string()
            .as_bytes(),
        t.platform.rsa_public_key(),
    )?;
    // ⚠️ 此处不 to_uppercase，与原实现一致

    // ③ t1 / t2
    let t2_plain = format!(
        "{}|0f607264fc6318a92b9e13c65db7cd3c|{}|{}|{}",
        t.device.guid, t.device.mac, t.device.dev, date_now
    );
    let t2 = crypto_aes_encrypt(&t2_plain, Some((LITE_T2_KEY, LITE_T2_IV)));

    let t1_plain = if t.account.t1.is_empty() {
        format!("|{date_now}")
    } else {
        format!("{}|{date_now}", t.account.t1)
    };
    let t1 = crypto_aes_encrypt(&t1_plain, Some((LITE_T1_KEY, LITE_T1_IV)));

    let mut body = json!({
        "dfid": t.dfid(),
        "p3": p3.str,
        "plat": 1,
        "t1": if is_lite { json!(t1.str) } else { json!(0) },
        "t2": if is_lite { json!(t2.str) } else { json!(0) },
        "t3": LOGIN_T3,
        "pk": pk,
        "params": encrypt_params.str,
        "userid": t.account.userid,
        "clienttime_ms": date_now
    });
    if is_lite {
        body["dev"] = json!(t.device.dev);
    }

    let resp = t
        .send(
            RequestOptions::post("/v5/login_by_token")
                .base_url("http://login.user.kugou.com")
                .json_body(&body),
        )
        .await?;

    Ok(merge_login_body(&resp, &encrypt_params.key))
}

/// 刷新登录令牌（强类型）
pub async fn login_token(t: &Transport) -> Result<LoginResult> {
    let body = login_token_body(t).await?;
    ensure_login_ok(&body)?;
    Ok(login_result_from(&body))
}

// ============================================================
//  内部工具
// ============================================================

/// 解密 `secu_params` 并合并进 `data`，返回**合并后的完整响应体**
///
/// 与原服务器行为一致 —— 服务器也是把 `body.data` 整个换成合并后的对象再返回。
/// `data` 不是对象时原样返回，由调用方判断（[`ensure_login_ok`]）。
pub(crate) fn merge_login_body(resp: &crate::ApiResponse, aes_key: &str) -> Value {
    let mut body = resp.body.clone();
    let Some(mut data) = body.get("data").cloned().filter(Value::is_object) else {
        return body;
    };

    // 解密 secu_params
    if let Some(secu) = data.get("secu_params").and_then(|v| v.as_str()) {
        if !secu.is_empty() {
            let plain = crypto_aes_decrypt(secu, aes_key, None);
            match serde_json::from_str::<Value>(&plain) {
                Ok(Value::Object(map)) => {
                    for (k, v) in map {
                        data[k] = v;
                    }
                }
                Ok(other) => {
                    data["token"] = other;
                }
                Err(_) => {
                    // 明文不是 JSON，当作 token 字符串
                    if !plain.is_empty() {
                        data["token"] = json!(plain);
                    }
                }
            }
        }
    }

    body["data"] = data;
    body
}

/// 校验登录响应里确实带 `data` 对象
fn ensure_login_ok(body: &Value) -> Result<()> {
    if body.get("data").map(Value::is_object).unwrap_or(false) {
        Ok(())
    } else {
        Err(Error::Invalid(format!("登录响应异常: {body}")))
    }
}

/// 从合并后的响应体提取登录结果
pub(crate) fn login_result_from(body: &Value) -> LoginResult {
    let data = body.get("data").cloned().unwrap_or(Value::Null);

    let s = |k: &str| data.get(k).and_then(|v| v.as_str()).map(str::to_string);
    let n = |k: &str| data.get(k).and_then(|v| v.as_i64());

    LoginResult {
        token: s("token").unwrap_or_default(),
        userid: s("userid").unwrap_or_default(),
        vip_type: n("vip_type").unwrap_or(0),
        vip_token: s("vip_token").unwrap_or_default(),
        t_expire_time: n("t_expire_time").unwrap_or(0),
        nickname: s("nickname").unwrap_or_default(),
        pic: s("pic").unwrap_or_default(),
        t1: s("t1").unwrap_or_default(),
    }
}

/// 手机号脱敏：`13800138000` → `13*****0`
fn mask_mobile(mobile: &str) -> String {
    let chars: Vec<char> = mobile.chars().collect();
    if chars.len() < 11 {
        return mobile.to_string();
    }
    format!(
        "{}*****{}",
        chars[0..2].iter().collect::<String>(),
        chars[10]
    )
}

/// 标准 Base64 编码
fn base64_encode(b: &[u8]) -> String {
    use base64::Engine;
    base64::engine::general_purpose::STANDARD.encode(b)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mobile_masking() {
        assert_eq!(mask_mobile("13800138000"), "13*****0");
        assert_eq!(mask_mobile("13912345678"), "13*****8");
    }

    #[test]
    fn short_mobile_untouched() {
        assert_eq!(mask_mobile("123"), "123");
    }
}
