//! Cookie 解析与组装
//!
//! 对应 `util/request.js` 的 `processCookieObject` / `createHeaderCookie`，
//! 以及 `util/index.js` 的 `cookieToJson` / `cookieObjToString`。
//!
//! ## 三种 crypto 的 Cookie 形态**完全不同**
//!
//! | crypto | Cookie 内容 |
//! | --- | --- |
//! | `weapi` | [`process_cookie`] 产出的**完整**表，[`cookie_to_string`] 序列化 |
//! | `eapi` | 独立的 **13 键**表（[`eapi_header_cookie`]），与上面毫无关系 |
//! | `xeapi` | 完整表 + 覆盖 6 个字段（见 `xeapi` 模块） |
//!
//! ⚠️ 同一个 `header` 表在 eapi 下**同时进 Cookie 和请求体**（`data.header`）。

use indexmap::IndexMap;

use crate::crypto::{random_digits, random_hex_lower};
use crate::device::DeviceIdentity;
use crate::{now_ms, Crypto};

/// 有序 Cookie 表
///
/// 顺序会影响服务端解析与风控特征，所以用 [`IndexMap`] 而不是 `HashMap`。
pub type CookieMap = IndexMap<String, String>;

// ============================================================
//  OS 配置表
// ============================================================

/// 一套 OS 伪装参数
pub struct OsProfile {
    /// `os` 字段的值
    pub os: &'static str,
    pub appver: &'static str,
    pub osver: &'static str,
    pub channel: &'static str,
}

/// 5 套 OS 伪装
///
/// ⚠️ 查找用的是 **key**（`iphone`），而 `os` 字段的值是 `iPhone OS` ——
/// 两者不一致。传 `os=iPhone OS` 会查不到 → 回退到 `pc`。**正确用法是传 `os=iphone`**。
pub fn os_profile(key: &str) -> &'static OsProfile {
    match key {
        "linux" => &LINUX,
        "android" => &ANDROID,
        "iphone" => &IPHONE,
        "osx" => &OSX,
        _ => &PC,
    }
}

static PC: OsProfile = OsProfile {
    os: "pc",
    appver: "3.1.17.204416",
    osver: "Microsoft-Windows-10-Professional-build-19045-64bit",
    channel: "netease",
};
static LINUX: OsProfile = OsProfile {
    os: "linux",
    appver: "1.2.1.0428",
    osver: "Deepin 20.9",
    channel: "netease",
};
static ANDROID: OsProfile = OsProfile {
    os: "android",
    appver: "8.20.20.231215173437",
    osver: "14",
    channel: "xiaomi",
};
static IPHONE: OsProfile = OsProfile {
    os: "iPhone OS",
    appver: "9.0.90",
    osver: "16.2",
    channel: "distribution",
};
static OSX: OsProfile = OsProfile {
    os: "osx",
    appver: "3.1.10.5100",
    osver: "15.5",
    channel: "netease",
};

// ============================================================
//  解析 / 序列化
// ============================================================

/// Cookie 字符串 → 有序表
///
/// ⚠️ 与 Node 的 `cookieToJson` **有意不同**：原版要求 `=` 恰好出现 1 次，
/// 含 `=` 的 Cookie（如 Base64 值）会被**整条丢弃**（其缺陷 #13）。
/// 本实现用 `indexOf('=')` 取第一个等号，行为更正确。
pub fn cookie_to_json(cookie: &str) -> CookieMap {
    let mut out = CookieMap::new();
    if cookie.is_empty() {
        return out;
    }

    for item in cookie.split(';') {
        if let Some(i) = item.find('=') {
            let k = item[..i].trim();
            if k.is_empty() {
                continue;
            }
            out.insert(k.to_string(), item[i + 1..].trim().to_string());
        }
    }
    out
}

/// 有序表 → Cookie 字符串
///
/// 对应 `cookieObjToString`：key 与 value 都过 `encodeURIComponent`，用 `; ` 连接。
pub fn cookie_to_string(cookie: &CookieMap) -> String {
    cookie
        .iter()
        .map(|(k, v)| format!("{}={}", encode(k), encode(v)))
        .collect::<Vec<_>>()
        .join("; ")
}

/// `encodeURIComponent`
fn encode(s: &str) -> String {
    urlencoding::encode(s).into_owned()
}

/// 从一条 `Set-Cookie` **原文**里取 `NMTID` 的值
///
/// 对应 Node 的 `x.match(/(?:^|;\s*)NMTID=([^;]+)/)` —— 注意是在**原文**上匹配，
/// 所以必须在剥属性（`clean_set_cookie`）**之前**调用。
pub fn extract_nmtid(set_cookie: &str) -> Option<String> {
    set_cookie
        .split(';')
        .map(str::trim)
        .find_map(|p| p.strip_prefix("NMTID="))
        .filter(|v| !v.is_empty())
        .map(str::to_string)
}

// ============================================================
//  设备身份注入
// ============================================================

/// NMTID 探测状态
///
/// 对应 Node `util/request.js` 顶部的两个模块级变量：
///
/// ```js
/// let NMTID = ''
/// let NMTID_RETRIES_LEFT = 3
/// ```
///
/// ## 为什么要探测
///
/// `NMTID` 是网易云的**设备识别 cookie**，由服务端下发。原实现的做法是：
/// 前几次 eapi 请求**故意不带** NMTID，从响应的 `Set-Cookie` 里把服务端下发的
/// 值捡回来，之后全局复用；3 次都没捡到才永久伪造一个。
///
/// ⚠️ **伪造的值过不了风控**。实测（本机，同一时刻）：
///
/// | NMTID | `/login/cellphone` 结果 |
/// | --- | --- |
/// | 伪造的 `00O`+hex | `code: -462`「请完成验证操作」 |
/// | 服务端下发的值 | `账号或密码错误`（与 Node 服务逐字一致） |
///
/// 精简版最初「跳过探测、直接伪造」（见其文档里记的原实现缺陷 #2：
/// 计数只减不增），结果就是登录类接口恒返回 -462。
#[derive(Debug, Clone, Default)]
pub struct NmtidState {
    /// 服务端下发的 NMTID；`None` = 还没探测到
    pub value: Option<String>,

    /// 还能探测几次（Node 初值 3，**只减不增** —— 这一点保持原样）
    pub retries_left: u8,
}

impl NmtidState {
    /// 用已持久化的值初始化；没有则进入「可探测」状态
    pub fn new(persisted: String) -> Self {
        Self {
            value: (!persisted.is_empty()).then_some(persisted),
            retries_left: 3,
        }
    }

    /// 是否还应该发探测请求（即：本次 eapi 请求**故意不带** NMTID）
    pub fn should_probe(&self) -> bool {
        self.value.is_none() && self.retries_left > 0
    }

    /// 消耗一次探测机会
    pub fn consume_retry(&mut self) {
        self.retries_left = self.retries_left.saturating_sub(1);
    }
}

/// 补齐设备身份（对应 `processCookieObject`）
///
/// 未登录时补 `MUSIC_A` 匿名回退；`MUSIC_U` 存在时不补。
pub fn process_cookie(
    cookie: CookieMap,
    crypto: Crypto,
    device: &DeviceIdentity,
    nmtid: &NmtidState,
) -> CookieMap {
    let profile = os_profile(cookie.get("os").map(String::as_str).unwrap_or(""));

    let mut out = cookie;

    // ① 无条件覆盖
    out.insert("__remember_me".into(), "true".into());
    out.insert("ntes_kaola_ad".into(), "1".into());

    // ② 设备身份（缺什么补什么）
    entry(&mut out, "_ntes_nuid", || device.ntes_nuid.clone());
    entry(&mut out, "_ntes_nnid", || device.ntes_nnid.clone());
    entry(&mut out, "WNMCID", || device.wnmcid.clone());
    entry(&mut out, "WEVNSM", || "1.0.0".into());
    entry(&mut out, "osver", || profile.osver.into());
    entry(&mut out, "deviceId", || device.device_id.clone());
    entry(&mut out, "os", || profile.os.to_string());
    entry(&mut out, "channel", || profile.channel.into());
    entry(&mut out, "appver", || profile.appver.into());

    // ③ NMTID —— 三分支，与 Node 的 `processCookieObject` 逐条对应：
    //
    //   ① 调用方传进来的 cookie 里已有     → 用它的
    //   ② 已探测到服务端下发的值           → 用服务端的
    //   ③ 没机会探测（非 eapi / 次数用完）  → 伪造
    //   ④ 其余（eapi 且还能探测）          → **整个不带**，让服务端下发
    //
    // ⚠️ 第 ④ 条是关键。见 [`NmtidState`] 的文档：伪造的 NMTID 会触发 -462。
    if !out.contains_key("NMTID") {
        if let Some(v) = &nmtid.value {
            out.insert("NMTID".into(), v.clone());
        } else if crypto != Crypto::Eapi || !nmtid.should_probe() {
            out.insert("NMTID".into(), format!("00O{}", random_hex_lower(38)));
        }
    }

    // ④ 匿名 MUSIC_A 回退
    if !out.contains_key("MUSIC_U") && !device.music_a.is_empty() {
        entry(&mut out, "MUSIC_A", || device.music_a.clone());
    }

    out
}

/// 只在键不存在或为空时插入
fn entry<F: FnOnce() -> String>(map: &mut CookieMap, key: &str, f: F) {
    let need = map.get(key).map(|v| v.is_empty()).unwrap_or(true);
    if need {
        map.insert(key.to_string(), f());
    }
}

// ============================================================
//  eapi 专用的 13 键 Cookie
// ============================================================

/// eapi 的 `header` 表（11 个固定键 + 可选的 `MUSIC_U`/`MUSIC_A`/`X-antiCheatToken`/`NMTID`）
///
/// ⚠️ 这个表**同时**是 Cookie 和请求体里的 `data.header` —— 别只塞一处。
/// ⚠️ 与 [`process_cookie`] 的产出**完全不同**，两者不可混用。
///
/// 顺序即插入顺序，序列化后必须与 Node 一致。
pub fn eapi_header_cookie(
    cookie: &CookieMap,
    device: &DeviceIdentity,
    anti_cheat_token: Option<&str>,
) -> CookieMap {
    let profile = os_profile(cookie.get("os").map(String::as_str).unwrap_or(""));
    let now = now_ms();

    let mut h = CookieMap::new();

    h.insert("osver".into(), get_or(cookie, "osver", profile.osver));
    h.insert("deviceId".into(), get_or(cookie, "deviceId", &device.device_id));
    h.insert("os".into(), get_or(cookie, "os", profile.os));
    h.insert("appver".into(), get_or(cookie, "appver", profile.appver));
    h.insert("versioncode".into(), get_or(cookie, "versioncode", "140"));
    h.insert("mobilename".into(), get_or(cookie, "mobilename", ""));
    h.insert(
        "buildver".into(),
        get_or(cookie, "buildver", &now.to_string()[..10]),
    );
    h.insert(
        "resolution".into(),
        get_or(cookie, "resolution", "1920x1080"),
    );
    h.insert(
        "__csrf".into(),
        cookie.get("__csrf").cloned().unwrap_or_default(),
    );
    h.insert("channel".into(), get_or(cookie, "channel", profile.channel));
    h.insert("requestId".into(), generate_request_id());

    if let Some(v) = cookie.get("MUSIC_U").filter(|s| !s.is_empty()) {
        h.insert("MUSIC_U".into(), v.clone());
    }
    if let Some(v) = cookie.get("MUSIC_A").filter(|s| !s.is_empty()) {
        h.insert("MUSIC_A".into(), v.clone());
    } else if !device.music_a.is_empty() {
        h.insert("MUSIC_A".into(), device.music_a.clone());
    }
    if let Some(t) = anti_cheat_token.filter(|s| !s.is_empty()) {
        // ⚠️ eapi 下反作弊 token 塞进 **Cookie**，不是 Header
        h.insert("X-antiCheatToken".into(), t.to_string());
    }
    if let Some(v) = cookie.get("NMTID").filter(|s| !s.is_empty()) {
        h.insert("NMTID".into(), v.clone());
    }

    h
}

fn get_or(cookie: &CookieMap, key: &str, default: &str) -> String {
    match cookie.get(key) {
        Some(v) if !v.is_empty() => v.clone(),
        _ => default.to_string(),
    }
}

/// `${now_ms}_${4 位随机数字}`
pub fn generate_request_id() -> String {
    format!("{}_{}", now_ms(), random_digits(4))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn device() -> DeviceIdentity {
        DeviceIdentity {
            device_id: "ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCD".into(),
            wnmcid: "abcdef.1700000000000.01.0".into(),
            ntes_nuid: "0".repeat(64),
            ntes_nnid: format!("{},1700000000000", "0".repeat(64)),
            music_a: "MUSIC_A_TOKEN".into(),
            nmtid: String::new(),
        }
    }

    /// 还没探测到 NMTID 的初始状态（Node 的 `NMTID=''` + `RETRIES_LEFT=3`）
    fn fresh_nmtid() -> NmtidState {
        NmtidState::new(String::new())
    }

    #[test]
    fn parses_cookie_string() {
        let m = cookie_to_json("MUSIC_U=abc; __csrf=xyz; os=pc");
        assert_eq!(m.get("MUSIC_U").unwrap(), "abc");
        assert_eq!(m.get("__csrf").unwrap(), "xyz");
        assert_eq!(m.len(), 3);
    }

    #[test]
    fn keeps_values_containing_equals() {
        // 缺陷 #13 的修正：原版会把这条整条丢掉
        let m = cookie_to_json("MUSIC_U=YWJjZA==; a=b");
        assert_eq!(m.get("MUSIC_U").unwrap(), "YWJjZA==");
        assert_eq!(m.get("a").unwrap(), "b");
    }

    #[test]
    fn empty_input_yields_empty_map() {
        assert!(cookie_to_json("").is_empty());
    }

    #[test]
    fn serializes_with_uri_encoding() {
        let mut m = CookieMap::new();
        m.insert("a".into(), "1 2".into());
        m.insert("b".into(), "x/y".into());
        assert_eq!(cookie_to_string(&m), "a=1%202; b=x%2Fy");
    }

    #[test]
    fn process_cookie_injects_device_identity() {
        let d = device();
        let out = process_cookie(CookieMap::new(), Crypto::Weapi, &d, &fresh_nmtid());

        assert_eq!(out.get("deviceId").unwrap(), &d.device_id);
        assert_eq!(out.get("_ntes_nuid").unwrap(), &d.ntes_nuid);
        assert_eq!(out.get("WNMCID").unwrap(), &d.wnmcid);
        assert_eq!(out.get("__remember_me").unwrap(), "true");
        assert_eq!(out.get("ntes_kaola_ad").unwrap(), "1");
        assert_eq!(out.get("WEVNSM").unwrap(), "1.0.0");
        // 未指定 os → pc 档
        assert_eq!(out.get("os").unwrap(), "pc");
        assert_eq!(out.get("channel").unwrap(), "netease");
        assert_eq!(
            out.get("osver").unwrap(),
            "Microsoft-Windows-10-Professional-build-19045-64bit"
        );
        // 匿名回退
        assert_eq!(out.get("MUSIC_A").unwrap(), "MUSIC_A_TOKEN");

        // weapi 不在探测之列 → 直接伪造 NMTID = "00O" + 38 hex
        let nmtid = out.get("NMTID").unwrap();
        assert!(nmtid.starts_with("00O"));
        assert_eq!(nmtid.len(), 41);
    }

    // ---- NMTID 三分支（对应 Node `processCookieObject` 的 if/else-if）----

    #[test]
    fn eapi_probe_omits_nmtid_entirely() {
        // 还没探测到、还有次数、又是 eapi → **整个不带**，等服务端下发
        let out = process_cookie(CookieMap::new(), Crypto::Eapi, &device(), &fresh_nmtid());
        assert!(
            !out.contains_key("NMTID"),
            "探测请求不该带 NMTID，实际: {:?}",
            out.get("NMTID")
        );
    }

    #[test]
    fn uses_server_issued_nmtid_once_captured() {
        let state = NmtidState {
            value: Some("00OXs5_AHPHOyIjYEwlpVTh31nhj8QAAAGhK-ICkQ".into()),
            retries_left: 3,
        };

        // eapi 与 weapi 都用服务端下发的值
        for crypto in [Crypto::Eapi, Crypto::Weapi] {
            let out = process_cookie(CookieMap::new(), crypto, &device(), &state);
            assert_eq!(
                out.get("NMTID").unwrap(),
                "00OXs5_AHPHOyIjYEwlpVTh31nhj8QAAAGhK-ICkQ",
                "crypto = {crypto:?}"
            );
        }
    }

    #[test]
    fn fabricates_nmtid_when_probe_budget_exhausted() {
        let state = NmtidState {
            value: None,
            retries_left: 0,
        };
        let out = process_cookie(CookieMap::new(), Crypto::Eapi, &device(), &state);
        let nmtid = out.get("NMTID").expect("次数用完就该伪造");
        assert!(nmtid.starts_with("00O"));
        assert_eq!(nmtid.len(), 41);
    }

    #[test]
    fn caller_supplied_nmtid_wins() {
        // cookie 里本来就有 → 谁都不覆盖（Node: `if (cookie.NMTID)`）
        let mut input = CookieMap::new();
        input.insert("NMTID".into(), "CALLER".into());

        let state = NmtidState {
            value: Some("SERVER".into()),
            retries_left: 3,
        };
        let out = process_cookie(input, Crypto::Eapi, &device(), &state);
        assert_eq!(out.get("NMTID").unwrap(), "CALLER");
    }

    #[test]
    fn probe_budget_only_decreases() {
        let mut s = fresh_nmtid();
        assert!(s.should_probe());
        for _ in 0..3 {
            s.consume_retry();
        }
        assert!(!s.should_probe());
        // 再消耗也不会下溢（Node 的计数只减不增）
        s.consume_retry();
        assert_eq!(s.retries_left, 0);
    }

    #[test]
    fn extract_nmtid_reads_from_raw_set_cookie() {
        assert_eq!(
            extract_nmtid("NMTID=ABC; Path=/; Domain=.music.163.com"),
            Some("ABC".into())
        );
        assert_eq!(
            extract_nmtid("MUSIC_U=x; NMTID=DEF; Expires=Wed, 08 Oct 2036"),
            Some("DEF".into())
        );
        // 空值不算
        assert_eq!(extract_nmtid("NMTID=; Path=/"), None);
        // 只是键名里含 NMTID 不算（Node 的正则要求是完整键名）
        assert_eq!(extract_nmtid("X-NMTID=BAD; Path=/"), None);
        assert_eq!(extract_nmtid("MUSIC_U=x"), None);
    }

    #[test]
    fn process_cookie_respects_existing_values() {
        let d = device();
        let mut input = CookieMap::new();
        input.insert("os".into(), "iphone".into());
        input.insert("MUSIC_U".into(), "U".into());

        let out = process_cookie(input, Crypto::Weapi, &d, &fresh_nmtid());

        // ⚠️ `os` 是「cookie 优先，缺了才用 profile」——
        //    所以传 'iphone' 后它**保持** 'iphone'，不会被换成 profile 里的 'iPhone OS'。
        //    （Node: `os: cookie.os || os.os`）
        assert_eq!(out.get("os").unwrap(), "iphone");

        // 但 osver / channel / appver 是从 profile 取的（cookie 里没有）
        assert_eq!(out.get("appver").unwrap(), "9.0.90");
        assert_eq!(out.get("osver").unwrap(), "16.2");
        assert_eq!(out.get("channel").unwrap(), "distribution");

        // 已登录 → 不补 MUSIC_A
        assert!(!out.contains_key("MUSIC_A"));
    }

    #[test]
    fn eapi_cookie_has_the_13_keys() {
        let d = device();
        let mut input = CookieMap::new();
        input.insert("MUSIC_U".into(), "U_TOKEN".into());
        input.insert("__csrf".into(), "CSRF".into());

        let h = eapi_header_cookie(&input, &d, None);

        // 11 个固定键 + MUSIC_U + MUSIC_A（device 里有） = 13
        assert_eq!(h.len(), 13, "键: {:?}", h.keys().collect::<Vec<_>>());

        let keys: Vec<&str> = h.keys().map(String::as_str).collect();
        // 顺序必须与 `util/request.js` 里 `header` 对象的字面量顺序一致
        assert_eq!(
            keys,
            vec![
                "osver",
                "deviceId",
                "os",
                "appver",
                "versioncode",
                "mobilename",
                "buildver",
                "resolution",
                "__csrf",
                "channel",
                "requestId",
                "MUSIC_U",
                "MUSIC_A",
            ]
        );

        assert_eq!(h.get("__csrf").unwrap(), "CSRF");
        assert_eq!(h.get("versioncode").unwrap(), "140");
        assert_eq!(h.get("mobilename").unwrap(), "");
        assert_eq!(h.get("resolution").unwrap(), "1920x1080");
        assert_eq!(h.get("buildver").unwrap().len(), 10);
    }

    #[test]
    fn eapi_puts_anti_cheat_token_in_cookie() {
        let d = device();
        let h = eapi_header_cookie(&CookieMap::new(), &d, Some("TOKEN"));
        assert_eq!(h.get("X-antiCheatToken").unwrap(), "TOKEN");
    }

    #[test]
    fn request_id_has_expected_shape() {
        let id = generate_request_id();
        let (ts, rand) = id.split_once('_').unwrap();
        assert!(ts.parse::<i64>().unwrap() > 1_600_000_000_000);
        assert_eq!(rand.len(), 4);
        assert!(rand.chars().all(|c| c.is_ascii_digit()));
    }

    #[test]
    fn unknown_os_falls_back_to_pc() {
        // ⚠️ 传 'iPhone OS'（值）而非 'iphone'（key）→ 查不到 → 回退 pc
        assert_eq!(os_profile("iPhone OS").os, "pc");
        assert_eq!(os_profile("iphone").os, "iPhone OS");
    }
}
