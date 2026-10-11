//! 签名层
//!
//! 逐字节复刻 `KuGouMusicApi/util/helper.js`。全部输出 **32 位小写 hex**。

use crate::crypto::md5;
use crate::platform::Platform;
use serde_json::Value;
use std::collections::BTreeMap;

/// 参数表类型：键有序（等价于 JS 的 `Object.keys().sort()`，键均为 ASCII 时行为一致）
pub type Params = BTreeMap<String, Value>;

/// 把一个 JSON 值按 JS 的规则转成字符串
///
/// 对应 JS 里 `` `${v}` `` 与 `typeof v === 'object' ? JSON.stringify(v) : v` 两条路径：
/// - `null` → `"null"`
/// - `true`/`false` → `"true"`/`"false"`
/// - 数字 → 十进制字面量
/// - 字符串 → 原样
/// - 数组/对象 → `JSON.stringify`
pub fn js_value_to_string(v: &Value) -> String {
    match v {
        Value::Null => "null".to_string(),
        Value::Bool(b) => b.to_string(),
        Value::Number(n) => n.to_string(),
        Value::String(s) => s.clone(),
        // 数组与对象走 JSON.stringify
        other => other.to_string(),
    }
}

/// 构造 `k=v` 拼接串（**按 key 排序**）
///
/// 用于 `signatureAndroidParams` 与 `signatureWebParams` 的 Android 分支。
fn kv_string(params: &Params) -> String {
    let mut out = String::new();
    for (k, v) in params {
        out.push_str(k);
        out.push('=');
        out.push_str(&js_value_to_string(v));
    }
    out
}

/// Android 版 `signature`
///
/// ```text
/// salt         = 标准版 "OIlwieks28dk2k092lksi2UIkp" / 概念版 "LnT6xpN3khm36zse0QzvmgTZ3waWdRSA"
/// paramsString = sort(keys(params)).map(k => `${k}=${v}`).join('')
/// signature    = MD5(salt + paramsString + data + salt)
/// ```
///
/// `data` 为请求体字符串（GET 传 `""`）。
pub fn signature_android_params(platform: Platform, params: &Params, data: &[u8]) -> String {
    let salt = platform.android_salt();
    let mut buf = Vec::with_capacity(data.len() + 128);
    buf.extend_from_slice(salt.as_bytes());
    buf.extend_from_slice(kv_string(params).as_bytes());
    buf.extend_from_slice(data);
    buf.extend_from_slice(salt.as_bytes());
    md5(&buf)
}

/// Web 版 `signature`
///
/// ```text
/// salt         = "NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt"
/// paramsString = keys(params).map(k => `${k}=${v}`).sort().join('')   ← 对整串 "k=v" 排序
/// signature    = MD5(salt + paramsString + data + salt)
/// ```
///
/// ⚠️ 与 Android 版有两处差异：盐值不同；**不对 object 做 `JSON.stringify`**。
/// 因此 Web 接口的参数必须全是标量。
pub fn signature_web_params(params: &Params, data: &[u8]) -> String {
    const SALT: &str = "NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt";

    let mut pairs: Vec<String> = params
        .iter()
        .map(|(k, v)| format!("{k}={}", js_value_to_string(v)))
        .collect();
    pairs.sort();

    let mut buf = Vec::with_capacity(data.len() + 128);
    buf.extend_from_slice(SALT.as_bytes());
    buf.extend_from_slice(pairs.concat().as_bytes());
    buf.extend_from_slice(data);
    buf.extend_from_slice(SALT.as_bytes());
    md5(&buf)
}

/// 设备注册 `signature`
///
/// ```text
/// paramsString = sort(values(params).map(String)).join('')   ← 只取值，丢弃 key
/// signature    = MD5("1014" + paramsString + "1014")
/// ```
///
/// 当前代码库中无调用点，保留规格备用。
pub fn signature_register_params(params: &Params) -> String {
    let mut values: Vec<String> = params.values().map(js_value_to_string).collect();
    values.sort();
    md5(format!("1014{}1014", values.concat()))
}

/// 通用 `sign`（盐值在末尾）
///
/// ```text
/// paramsString = sort(keys(params)).map(k => `${k}${v}`).join('')   ← 无等号
/// sign         = MD5(paramsString + data + salt)
/// ```
pub fn sign_params(params: &Params, data: &str) -> String {
    const SALT: &str = "R6snCXJgbCaj9WFRJKefTMIFp0ey6Gza";
    let params_string: String = params
        .iter()
        .map(|(k, v)| format!("{k}{}", js_value_to_string(v)))
        .collect();
    md5(format!("{params_string}{data}{SALT}"))
}

/// 请求密钥签名，生成 `params.key`
///
/// ```text
/// salt = 标准版 "57ae12eb6890223e355ccfcb74edf70d" / 概念版 "185672dd44712f60bb1736df5a377e82"
/// key  = MD5(hash + salt + appid + mid + userid)
/// ```
///
/// ⚠️ 必须复刻 JS 的 `||` 语义：`userid || 0` 会把**空串**也变成 `0`，
/// `appid || useAppid` 会把 `0` 变成默认值。传空串会算出错误的 key（上游报 `illegal key`）。
///
/// ⚠️ 原实现里 `appid` 缺省值恒为 `1005`（**不随平台变**）。
pub fn sign_key(
    platform: Platform,
    hash: &str,
    mid: &str,
    userid: &str,
    appid: Option<u32>,
) -> String {
    // 对应 JS 的 `appid || useAppid`
    let appid = match appid {
        Some(0) | None => 1005,
        Some(v) => v,
    };
    // 对应 JS 的 `userid || 0`
    let userid = if userid.is_empty() { "0" } else { userid };

    md5(format!(
        "{hash}{}{appid}{mid}{userid}",
        platform.sign_key_salt()
    ))
}

/// 参数密钥签名，生成 `params.key`
///
/// ```text
/// key = MD5(appid + salt + clientver + data)
/// ```
pub fn sign_params_key(platform: Platform, data: &str, appid: Option<u32>, clientver: Option<u32>) -> String {
    let appid = appid.unwrap_or_else(|| platform.appid());
    let clientver = clientver.unwrap_or_else(|| platform.clientver());
    md5(format!(
        "{appid}{}{clientver}{data}",
        platform.android_salt()
    ))
}

/// 云盘 PID 签名
///
/// ```text
/// key = MD5("musicclound" + hash + pid + salt)
/// ```
///
/// ⚠️ `"musicclound"` 是原实现的拼写错误，必须原样保留。
pub fn sign_cloud_key(hash: &str, pid: &str) -> String {
    const SALT: &str = "ebd1ac3134c880bda6a2194537843caa0162e2e7";
    md5(format!("musicclound{hash}{pid}{SALT}"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn p(pairs: &[(&str, Value)]) -> Params {
        pairs.iter().map(|(k, v)| (k.to_string(), v.clone())).collect()
    }

    #[test]
    fn android_signature_is_stable() {
        let params = p(&[("b", json!(2)), ("a", json!(1))]);
        let sig = signature_android_params(Platform::Standard, &params, b"");
        // 拼接顺序应为 a=1b=2
        let expect = md5("OIlwieks28dk2k092lksi2UIkp".to_string() + "a=1b=2" + "" + "OIlwieks28dk2k092lksi2UIkp");
        assert_eq!(sig, expect);
    }

    #[test]
    fn object_values_are_json_stringified() {
        let params = p(&[("a", json!({"x": 1}))]);
        let expect = md5("OIlwieks28dk2k092lksi2UIkp".to_string() + r#"a={"x":1}"# + "" + "OIlwieks28dk2k092lksi2UIkp");
        assert_eq!(signature_android_params(Platform::Standard, &params, b""), expect);
    }

    #[test]
    fn lite_uses_different_salt() {
        let params = p(&[("a", json!(1))]);
        let std = signature_android_params(Platform::Standard, &params, b"");
        let lite = signature_android_params(Platform::Lite, &params, b"");
        assert_ne!(std, lite);
    }

    #[test]
    fn sign_key_defaults_appid_to_1005() {
        let a = sign_key(Platform::Standard, "h", "m", "u", None);
        let b = sign_key(Platform::Standard, "h", "m", "u", Some(1005));
        assert_eq!(a, b);
    }

    #[test]
    fn sign_params_key_orders_appid_first() {
        let got = sign_params_key(Platform::Standard, "123", Some(1005), Some(20489));
        let expect = md5("1005OIlwieks28dk2k092lksi2UIkp20489123");
        assert_eq!(got, expect);
    }

    #[test]
    fn js_stringify_rules() {
        assert_eq!(js_value_to_string(&Value::Null), "null");
        assert_eq!(js_value_to_string(&json!(true)), "true");
        assert_eq!(js_value_to_string(&json!(128)), "128");
        assert_eq!(js_value_to_string(&json!("s")), "s");
        assert_eq!(js_value_to_string(&json!([1, 2])), "[1,2]");
    }
}

#[cfg(test)]
mod sign_key_semantics {
    use super::*;

    #[test]
    fn empty_userid_becomes_zero() {
        let a = sign_key(Platform::Standard, "h", "m", "", None);
        let b = sign_key(Platform::Standard, "h", "m", "0", None);
        assert_eq!(a, b, "空 userid 应等价于 0（JS 的 `|| 0` 语义）");
    }

    #[test]
    fn zero_appid_falls_back_to_default() {
        let a = sign_key(Platform::Standard, "h", "m", "1", Some(0));
        let b = sign_key(Platform::Standard, "h", "m", "1", Some(1005));
        assert_eq!(a, b, "appid=0 应回退到 1005（JS 的 `||` 语义）");
    }
}
