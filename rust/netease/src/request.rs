//! 请求层
//!
//! 对应 `util/request.js` 的 `createRequest`。负责：
//!
//! ```text
//! ① 解析 cookie（字符串 → 有序表）
//! ② processCookieObject：补齐设备身份
//! ③ 按 crypto 分支组装 Header + Cookie + 加密体
//! ④ POST 发送
//! ⑤ 解析响应 + 收集 Set-Cookie
//! ⑥ body.code → status 映射
//! ```
//!
//! ## 精简版砍掉的
//!
//! 代理（`tunnel` / `PacProxyAgent`）、随机中国 IP、响应缓存、`e_r` 响应加密、
//! `linuxapi` / `api` 两种 crypto、`ua`/`headers`/`domain`/`timeout` 覆盖参数 ——
//! 客户端都不需要。详见 `docs/rewrite/10-client-subset.md` §3.7。

use serde_json::{json, Value};

use crate::cookie::{
    cookie_to_json, cookie_to_string, eapi_header_cookie, extract_nmtid, process_cookie,
};
use crate::device::DeviceIdentity;
use crate::protocol::{self, eapi_body, weapi_body};
use crate::{now_ms, Crypto, Error, Result};

// ============================================================
//  域名
// ============================================================

/// weapi 的域名（也用于 `/api/...` 直连路由）
pub const DOMAIN: &str = "https://music.163.com";

/// 未加密 `api` 的域名（精简版无路由使用，保留备查）
pub const API_DOMAIN: &str = "https://interface.music.163.com";

/// eapi 的域名
pub const EAPI_DOMAIN: &str = "https://interfacepc.music.163.com";

/// xeapi 的域名
pub const XEAPI_DOMAIN: &str = "https://interface3.music.163.com";

// ============================================================
//  User-Agent
// ============================================================

const UA_WEAPI: &str = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 \
(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Edg/124.0.0.0";

const UA_API_IPHONE: &str = "NeteaseMusic 9.0.90/5038 (iPhone; iOS 16.2; zh_CN)";

const UA_API_OSX: &str = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 \
(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

/// 选 User-Agent（对应 `chooseUserAgent`）
///
/// ⚠️ eapi 分支：`cookie.os === 'osx'` 时用 macOS 浏览器 UA，否则用 iPhone 客户端 UA。
pub fn choose_user_agent(crypto: Crypto, os: &str) -> &'static str {
    match crypto {
        Crypto::Weapi => UA_WEAPI,
        Crypto::Eapi | Crypto::Xeapi => {
            if os == "osx" {
                UA_API_OSX
            } else {
                UA_API_IPHONE
            }
        }
    }
}

// ============================================================
//  响应
// ============================================================

/// 统一响应
#[derive(Debug, Clone)]
pub struct ApiResponse {
    /// 归一化后的状态码：`200` 成功，`502` 业务失败
    pub status: u16,
    /// 解析后的响应体
    pub body: Value,
    /// `Set-Cookie` 原始串（已剥掉 `Domain=` 属性）
    pub cookies: Vec<String>,
}

impl ApiResponse {
    pub fn ok(&self) -> bool {
        self.status == 200
    }

    /// 上游 `code`
    pub fn code(&self) -> Option<i64> {
        self.body.get("code").and_then(|v| v.as_i64())
    }

    /// 取 `data` 字段
    pub fn data(&self) -> &Value {
        self.body.get("data").unwrap_or(&Value::Null)
    }

    /// 按路径取字符串
    pub fn str_at(&self, path: &[&str]) -> Option<String> {
        let mut cur = &self.body;
        for p in path {
            cur = cur.get(*p)?;
        }
        match cur {
            Value::String(s) => Some(s.clone()),
            Value::Number(n) => Some(n.to_string()),
            _ => None,
        }
    }

    /// `Set-Cookie` 合并成一个 Cookie 串（`; ` 连接各条的 `k=v` 部分）
    ///
    /// 对应 `result.cookie.join(';')` —— ⚠️ 原版是把**整条** Set-Cookie
    /// （含 `Path=/` 等属性）拼起来，客户端再自己 `extractCookieString` 清洗。
    pub fn cookie_joined(&self) -> String {
        self.cookies.join(";")
    }
}

// ============================================================
//  请求配置
// ============================================================

/// 一次请求的配置
#[derive(Debug, Clone)]
pub struct RequestOptions {
    /// 上游路径，必须以 `/api/` 开头（如 `/api/song/lyric`）
    pub uri: String,
    /// 加密方案
    pub crypto: Crypto,
    /// 请求体（明文，会被加密）
    pub data: Value,
    /// 账号 Cookie 串（来自调用方，未登录时传空串）
    pub cookie: String,
    /// 是否需要 `X-antiCheatToken`
    pub check_token: bool,
}

impl RequestOptions {
    pub fn new(uri: impl Into<String>, crypto: Crypto, data: Value) -> Self {
        Self {
            uri: uri.into(),
            crypto,
            data,
            cookie: String::new(),
            check_token: false,
        }
    }

    pub fn cookie(mut self, c: impl Into<String>) -> Self {
        self.cookie = c.into();
        self
    }

    pub fn check_token(mut self, yes: bool) -> Self {
        self.check_token = yes;
        self
    }
}

// ============================================================
//  传输层
// ============================================================

/// 持有 HTTP 客户端与设备身份
pub struct Transport {
    pub http: reqwest::Client,
    pub device: DeviceIdentity,

    /// xeapi 公钥（懒加载 + 进程内缓存）
    ///
    /// 原实现把它存在 `os.tmpdir()/xeapi_public_key`；这里只放内存 ——
    /// 反正每次启动都会重新拉一次，省一个文件。
    xeapi_key: std::sync::Mutex<Option<crate::xeapi::PublicKeyState>>,

    /// NMTID 探测状态（见 [`crate::cookie::NmtidState`]）
    ///
    /// 用 `Mutex` 是因为它在 `send(&self)` 里被写 —— 响应的 `Set-Cookie`
    /// 会把服务端下发的值捡回来。
    nmtid: std::sync::Mutex<crate::cookie::NmtidState>,

    /// 身份文件路径。有它才能把探测到的 NMTID 落盘（没有就只活在内存里）。
    identity_path: Option<std::path::PathBuf>,
}

// ============================================================
//  HTTP 客户端
// ============================================================

/// 构建全局 HTTP 客户端
///
/// ## ⚠️ 默认**只连 IPv4**
///
/// 网易云的 CDN（`interface.music.163.com` / `interfacepc.…` / `interface3.…`）
/// 都发 AAAA 记录，而很多网络的 IPv6 出口到它们是**坏的**：TCP 看着能连上，
/// 紧接着被对端 RST。表现就是**概率性**失败：
///
/// ```text
/// 网络错误: error sending request for url (https://interface3.music.163.com/xeapi/ad/get)
///   ← client error (SendRequest) ← connection error
///   ← 远程主机强迫关闭了一个现有的连接。 (os error 10054)
/// ```
///
/// 实测（手机热点环境，`interface3.music.163.com`，**交错对照**各 25 次全新连接）：
///
/// | 地址族偏好 | 成功 |
/// | --- | :-: |
/// | 默认（hyper 按 DNS 返回的**第一条**选，本机是 IPv6） | 18/25 |
/// | 强制 IPv4 | **25/25** |
///
/// `curl -4` 15/15、`curl -6` 5/15，同样印证。
///
/// ### 为什么是 `local_address` 而不是别的
///
/// hyper-util 的 `SocketAddrs::split_by_preference` 里：
///
/// ```ignore
/// (Some(_), None) => (self.filter(SocketAddr::is_ipv4), SocketAddrs::new(vec![])),
/// //                 ↑ IPv6 地址被**整个过滤掉**，连 fallback 都不留
/// ```
///
/// 也就是说 `local_address` 设成 IPv4 时，连接器**根本不会去尝试 IPv6**，
/// 而不是「IPv6 试失败了再回落」。这正是我们要的。
///
/// 需要走 IPv6 时设环境变量 `NETEASE_IPV4_ONLY=0`。
pub fn http_client() -> reqwest::Client {
    let mut b = reqwest::Client::builder()
        .connect_timeout(std::time::Duration::from_secs(10))
        .timeout(std::time::Duration::from_secs(30));

    if ipv4_only() {
        // `0.0.0.0` = 不指定具体网卡，只是用它来声明「只连 IPv4」
        b = b.local_address(std::net::IpAddr::V4(std::net::Ipv4Addr::UNSPECIFIED));
    }

    b.build().expect("构建 HTTP 客户端失败")
}

/// 是否强制 IPv4（默认是；`NETEASE_IPV4_ONLY=0` / `=false` 关闭）
fn ipv4_only() -> bool {
    !matches!(
        std::env::var("NETEASE_IPV4_ONLY").as_deref(),
        Ok("0") | Ok("false") | Ok("no")
    )
}

/// 域名覆盖（**仅调试用**）
///
/// 设 `NETEASE_DOMAIN=http://127.0.0.1:9999` 后，weapi / eapi / xeapi 三个
/// **请求**域名全部改指它 —— 把请求打到本地 echo server，就能逐字节对比
/// 与原 Node 服务发出的那条请求的差异。排查签名 / 风控类问题很有用。
///
/// ⚠️ **不覆盖** xeapi 公钥接口（`interface.music.163.com`）—— 那是换取加密
///    公钥用的，必须走真服务器，否则整条 xeapi 链路起不来。
pub fn domain(default: &str) -> String {
    std::env::var("NETEASE_DOMAIN").unwrap_or_else(|_| default.to_string())
}

impl Transport {
    pub fn new(device: DeviceIdentity) -> Self {
        Self::with_identity_path(device, None)
    }

    /// 带身份文件路径构造 —— NMTID 探测到之后会写回去
    pub fn with_identity_path(
        device: DeviceIdentity,
        identity_path: Option<std::path::PathBuf>,
    ) -> Self {
        let nmtid = crate::cookie::NmtidState::new(device.nmtid.clone());

        Self {
            http: http_client(),
            device,
            xeapi_key: std::sync::Mutex::new(None),
            nmtid: std::sync::Mutex::new(nmtid),
            identity_path,
        }
    }

    /// 当前 NMTID 状态（克隆一份，避免锁跨 await）
    pub fn nmtid_state(&self) -> crate::cookie::NmtidState {
        self.nmtid.lock().unwrap().clone()
    }

    /// 记下服务端下发的 NMTID，并尽力落盘
    ///
    /// 落盘失败不影响本次运行 —— 只是下次启动要重新探测一遍。
    fn capture_nmtid(&self, value: String) {
        {
            let mut g = self.nmtid.lock().unwrap();
            if g.value.is_some() {
                return; // 已经有了，不再覆盖
            }
            g.value = Some(value.clone());
        }

        if let Some(p) = &self.identity_path {
            let mut device = self.device.clone();
            device.nmtid = value;
            let _ = device.save(p);
        }
    }

    /// 消耗一次 NMTID 探测机会（对应 Node 的 `NMTID_RETRIES_LEFT--`）
    fn consume_nmtid_probe(&self) {
        self.nmtid.lock().unwrap().consume_retry();
    }

    /// 发一次请求，**连接阶段**失败时重试
    ///
    /// ## 为什么只重试连接阶段的失败
    ///
    /// `is_connect()` 为真 = TCP / TLS 都没建起来，请求**一个字节都没发出去**，
    /// 重试绝不会造成重复执行。这一点对本项目是硬要求 ——
    /// `/ad/listening/rights/gain`、`/login/*` 这些 POST 都不是幂等的。
    ///
    /// 反过来 **不重试**这两类：
    ///
    /// - `is_request()`（请求发到一半被 RST）—— 服务器可能已经收到了
    /// - `is_timeout()`（读超时）—— 服务器很可能已经处理完了，只是响应丢了
    ///
    /// 拿不准就不重试：宁可报错让用户重来，也不能凭空多领一次时长 / 多登一次。
    ///
    /// `build` 是个闭包 —— 重试要能重新构造一次 `RequestBuilder`。
    pub async fn send_retry(
        &self,
        build: impl Fn() -> reqwest::RequestBuilder,
    ) -> Result<reqwest::Response> {
        /// 总尝试次数（首次 + 2 次重试）
        const MAX: usize = 3;

        let mut attempt = 1usize;
        loop {
            match build().send().await {
                Ok(r) => return Ok(r),
                Err(e) if e.is_connect() && attempt < MAX => {
                    // 递增退避：200ms / 400ms
                    tokio::time::sleep(std::time::Duration::from_millis(200 * attempt as u64)).await;
                    attempt += 1;
                }
                Err(e) => return Err(Error::http(e)),
            }
        }
    }

    /// 取（必要时拉取）xeapi 公钥
    ///
    /// ⚠️ 锁只在读写时短暂持有，**不跨 await**。
    pub async fn xeapi_key(&self) -> Result<crate::xeapi::PublicKeyState> {
        // ① 命中缓存直接返回
        {
            let guard = self.xeapi_key.lock().unwrap();
            if let Some(k) = guard.as_ref() {
                if k.is_ready() {
                    return Ok(k.clone());
                }
            }
        }

        // ② 未命中：带上旧 version 去拉
        let old_version = {
            let guard = self.xeapi_key.lock().unwrap();
            guard.as_ref().map(|k| k.version.clone()).unwrap_or_default()
        };

        let state =
            crate::xeapi::fetch_public_key(&self.http, &self.device.device_id, &old_version).await?;

        *self.xeapi_key.lock().unwrap() = Some(state.clone());
        Ok(state)
    }

    /// 清掉缓存的公钥（拉取失败时调用，下次重新拉）
    pub fn clear_xeapi_key(&self) {
        *self.xeapi_key.lock().unwrap() = None;
    }

    /// 发一次 **xeapi** 请求（广告族 + 匿名注册）
    ///
    /// xeapi 与 weapi/eapi 差别很大，单独走一条路径：
    ///
    /// - 请求体是 `B=..&S=..&R=..`（三层加密）
    /// - **响应也是加密的**，要用 `eapiKey` 解（不是 `staticKey`）
    /// - 需要 `X-Client-Enc-State: ENCRYPTED` 等一批专属头
    /// - Cookie 在完整表基础上覆盖 6 个字段
    pub async fn send_xeapi(
        &self,
        uri: &str,
        data: Value,
        cookie_str: &str,
        check_token: bool,
    ) -> Result<ApiResponse> {
        let state = self.xeapi_key().await?;

        let raw_cookie = cookie_to_json(cookie_str);
        let cookie = process_cookie(raw_cookie, Crypto::Xeapi, &self.device, &self.nmtid_state());

        // ---- 这几个字段既进请求头，也覆盖进 Cookie ----
        let os = match cookie.get("os").map(String::as_str) {
            Some("android") => "android",
            _ => "android",
        };
        let appver = match (cookie.get("os").map(String::as_str), cookie.get("appver")) {
            (Some("android"), Some(v)) if !v.is_empty() => v.clone(),
            _ => "9.1.65".to_string(),
        };
        let osver = match (cookie.get("os").map(String::as_str), cookie.get("osver")) {
            (Some("android"), Some(v)) if !v.is_empty() => v.clone(),
            _ => "16".to_string(),
        };
        let buildver = match cookie.get("buildver") {
            Some(v) if !v.is_empty() => v.clone(),
            _ => now_ms().to_string()[..10].to_string(),
        };
        let device_id = cookie.get("deviceId").cloned().unwrap_or_default();
        let sdevice_id = match cookie.get("sDeviceId") {
            Some(v) if !v.is_empty() => v.clone(),
            _ => device_id.clone(),
        };

        let mut xeapi_cookie = cookie.clone();
        xeapi_cookie.insert("os".into(), os.to_string());
        xeapi_cookie.insert("osver".into(), osver.clone());
        xeapi_cookie.insert("appver".into(), appver.clone());
        xeapi_cookie.insert("buildver".into(), buildver.clone());
        xeapi_cookie.insert("deviceId".into(), device_id.clone());
        xeapi_cookie.insert("sDeviceId".into(), sdevice_id.clone());

        // ---- 加密 ----
        let body = crate::xeapi::xeapi(uri, &data, &state, &crate::xeapi::PlaintextOptions::default())?;

        let url = format!("{}/xeapi/{}", domain(XEAPI_DOMAIN), strip_api(uri));

        // 这两个头在**每次重试里都一样**，先算好 —— 放进闭包会重复请求反作弊服务
        let music_u = cookie.get("MUSIC_U").filter(|s| !s.is_empty()).cloned();
        let anti_cheat = if check_token {
            let t = crate::anticheat::token_v3(&self.http).await;
            if t.is_empty() {
                None
            } else {
                Some(t)
            }
        } else {
            None
        };

        let form = body.to_form();
        let cookie_header = cookie_to_string(&xeapi_cookie);

        let resp = self
            .send_retry(|| {
                let mut req = self
                    .http
                    .post(&url)
                    .header("User-Agent", crate::xeapi::XEAPI_UA)
                    .header("X-Client-Enc-State", "ENCRYPTED")
                    .header("x-aeapi", "true")
                    .header("content-type", "application/x-www-form-urlencoded;charset=utf-8")
                    .header("x-deviceid", &device_id)
                    .header("x-os", os)
                    .header("x-osver", &osver)
                    .header("x-appver", &appver)
                    .header("x-sdeviceid", &sdevice_id)
                    .header("x-buildver", &buildver)
                    .header("Cookie", &cookie_header)
                    .body(form.clone());

                if let Some(u) = music_u.as_deref() {
                    req = req.header("x-music-u", u);
                }
                if let Some(t) = anti_cheat.as_deref() {
                    req = req.header("X-antiCheatToken", t);
                }
                req
            })
            .await?;

        let cookies: Vec<String> = resp
            .headers()
            .get_all(reqwest::header::SET_COOKIE)
            .iter()
            .filter_map(|v| v.to_str().ok())
            .map(clean_set_cookie)
            .collect();

        let raw = resp.bytes().await.map_err(Error::http)?;

        // ---- 响应是加密的，用 eapiKey 解 ----
        let body = crate::xeapi::res_decrypt(&raw)?;
        let status = map_status(&body);

        Ok(ApiResponse {
            status,
            body,
            cookies,
        })
    }

    /// 发一次请求
    pub async fn send(&self, opt: RequestOptions) -> Result<ApiResponse> {
        // ① 解析 + 注入设备身份
        let raw_cookie = cookie_to_json(&opt.cookie);
        let nmtid_state = self.nmtid_state();

        // 本次是不是一次「NMTID 探测请求」—— 对应 Node 里那两处同名判断：
        //
        //     crypto === 'eapi' && !NMTID && NMTID_RETRIES_LEFT > 0 && !cookie.NMTID
        //
        // ⚠️ 看的是**调用方传进来的** cookie（`opt.cookie`）里有没有 NMTID，
        //    不是 `process_cookie` 之后的产物 —— 与 Node 一致。
        let probing = opt.crypto == Crypto::Eapi
            && !raw_cookie.contains_key("NMTID")
            && nmtid_state.should_probe();

        let cookie = process_cookie(raw_cookie, opt.crypto, &self.device, &nmtid_state);

        // ② 反作弊 token（xeapi / 部分 weapi 需要）
        let anti_cheat = if opt.check_token {
            crate::anticheat::token_v3(&self.http).await
        } else {
            String::new()
        };
        let anti_cheat_opt = (!anti_cheat.is_empty()).then_some(anti_cheat.as_str());

        // ③ 按 crypto 组装
        let (url, headers, body) = match opt.crypto {
            Crypto::Weapi => {
                // ⚠️ weapi 用完整的 processCookieObject 结果
                let mut data = opt.data.clone();
                data["csrf_token"] = json!(cookie.get("__csrf").cloned().unwrap_or_default());
                data["e_r"] = json!(false);

                // 调试：`NETEASE_DEBUG=1` 时打印明文 JSON，可与原 Node 实现逐字段对比
                if std::env::var("NETEASE_DEBUG").is_ok() {
                    eprintln!("┌─ weapi 明文 ({}) ──", opt.uri);
                    eprintln!("│ {data}");
                    eprintln!("└──────────────────────");
                }

                let p = protocol::weapi(&data)?;
                let mut h = vec![
                    ("Cookie".to_string(), cookie_to_string(&cookie)),
                    ("Referer".to_string(), DOMAIN.to_string()),
                    (
                        "User-Agent".to_string(),
                        choose_user_agent(Crypto::Weapi, "").to_string(),
                    ),
                ];
                if let Some(t) = anti_cheat_opt {
                    // ⚠️ weapi 下反作弊 token 在 **Header**
                    h.push(("X-antiCheatToken".to_string(), t.to_string()));
                }
                (format!("{}/weapi/{}", domain(DOMAIN), strip_api(&opt.uri)), h, weapi_body(&p))
            }

            Crypto::Eapi => {
                // ⚠️ eapi 用**独立的 13 键**表，且该表同时进 Cookie 与请求体
                let header = eapi_header_cookie(&cookie, &self.device, anti_cheat_opt);

                let mut data = opt.data.clone();
                data["header"] = serde_json::to_value(&header)
                    .map_err(|e| Error::Json(e.to_string()))?;
                data["e_r"] = json!(false);

                let params = protocol::eapi(&opt.uri, &data)?;
                let h = vec![
                    ("Cookie".to_string(), cookie_to_string(&header)),
                    (
                        "User-Agent".to_string(),
                        choose_user_agent(
                            Crypto::Eapi,
                            cookie.get("os").map(String::as_str).unwrap_or(""),
                        )
                        .to_string(),
                    ),
                ];
                (
                    format!("{}/eapi/{}", domain(EAPI_DOMAIN), strip_api(&opt.uri)),
                    h,
                    eapi_body(&params),
                )
            }

            Crypto::Xeapi => {
                return Err(Error::Invalid(
                    "xeapi 请用 api::ad 里的专用实现（需要公钥与会话）".into(),
                ));
            }
        };

        // ④ 发送
        //
        // ⚠️ 包成闭包，好让 `send_retry` 能重新构造一次请求
        let resp = self
            .send_retry(|| {
                let mut req = self
                    .http
                    .post(&url)
                    .header("Content-Type", "application/x-www-form-urlencoded")
                    .body(body.clone());
                for (k, v) in &headers {
                    req = req.header(k, v);
                }
                req
            })
            .await?;

        // ⑤ Set-Cookie（剥掉属性，只留 k=v）
        //
        // ⚠️ NMTID 采集必须在 `clean_set_cookie` **之前** —— 对应 Node 是在
        //    `Set-Cookie` **原文**上跑 `/(?:^|;\s*)NMTID=([^;]+)/`。
        if probing {
            self.consume_nmtid_probe();
            for v in resp.headers().get_all(reqwest::header::SET_COOKIE).iter() {
                if let Some(t) = v.to_str().ok().and_then(extract_nmtid) {
                    self.capture_nmtid(t);
                    break;
                }
            }
        }

        let cookies: Vec<String> = resp
            .headers()
            .get_all(reqwest::header::SET_COOKIE)
            .iter()
            .filter_map(|v| v.to_str().ok())
            .map(clean_set_cookie)
            .collect();

        let raw = resp
            .bytes()
            .await
            .map_err(Error::http)?;

        let body: Value = serde_json::from_slice(&raw).map_err(|e| {
            Error::Json(format!(
                "响应不是 JSON: {e}; 原文前 200 字节: {}",
                String::from_utf8_lossy(&raw[..raw.len().min(200)])
            ))
        })?;

        // ⑥ 状态映射
        let status = map_status(&body);
        let resp = ApiResponse {
            status,
            body,
            cookies,
        };

        if resp.status == 200 {
            Ok(resp)
        } else {
            Err(Error::Api {
                message: api_message(&resp.body),
                code: resp.code(),
                status: resp.status,
                body: resp.body.to_string(),
            })
        }
    }

    /// 发一次请求并返回**原始响应**，不做业务状态判定
    ///
    /// 与原服务器一致：业务失败（`code != 200`）也照常把响应体返回，由调用方判断。
    /// 只有网络 / 解析错误才返回 `Err`。
    ///
    /// 供 [`crate::api`] 与 [`crate::raw`] 使用 —— 它们要复刻服务器的行为，
    /// 而服务器是「无论业务成败都回 200 + body」。
    pub async fn send_raw(&self, opt: RequestOptions) -> Result<ApiResponse> {
        match self.send(opt).await {
            Ok(r) => Ok(r),
            // 业务失败：响应体原样在 `Error::Api.body` 里，解回来当作正常返回
            Err(e) => match recover_body(e.clone()) {
                Some((body, status)) => Ok(ApiResponse {
                    status,
                    body,
                    cookies: Vec::new(),
                }),
                // ⚠️ 网络 / 解析 / 加密错误必须**原样上抛**。
                //
                //    这里曾经是 `Err(Error::Http("请求失败".into()))` —— 把真正的
                //    原因整个吃掉了。二维码登录、手机验证码、广告三条链路在 Dart
                //    侧看到的都只是「网络错误: 请求失败」，完全无法定位。
                //    （`recover_body` 的文档也写着「非业务错误返回 None」，
                //     说明本意就是要上抛，那个替换是笔误。）
                None => Err(e),
            },
        }
    }
}

/// 从 [`Error::Api`] 里取回响应体
///
/// 业务失败在 [`Transport::send`] 里被转成了 `Err`，但响应体原样保存在
/// `Error::Api.body` 中，这里解回来。非业务错误返回 `None`。
pub fn recover_body(e: Error) -> Option<(Value, u16)> {
    match e {
        Error::Api { body, status, .. } => {
            let v = serde_json::from_str(&body).unwrap_or_else(|_| json!({ "code": status }));
            Some((v, status))
        }
        _ => None,
    }
}

/// 从响应体里挑一句可读的错误描述
fn api_message(body: &Value) -> String {
    for k in ["msg", "message", "error", "errmsg"] {
        if let Some(s) = body.get(k).and_then(|v| v.as_str()) {
            if !s.is_empty() {
                return s.to_string();
            }
        }
    }
    match body.get("code").and_then(|v| v.as_i64()) {
        Some(c) => format!("code={c}"),
        None => "未知错误".to_string(),
    }
}

/// `/api/song/lyric` → `song/lyric`
///
/// 对应 `uri.substr(5)` —— 去掉 `/api/` 这 5 个字符。
fn strip_api(uri: &str) -> &str {
    uri.strip_prefix("/api/").unwrap_or(uri)
}

/// 剥掉 `Set-Cookie` 的属性，只留 `k=v`
///
/// 对应 `request.js` 里的 `Domain=` 清理；顺带去掉 `Path` / `Expires` 等，
/// 因为客户端会拿这个串直接当 Cookie 头用。
fn clean_set_cookie(raw: &str) -> String {
    raw.split(';')
        .next()
        .unwrap_or("")
        .trim()
        .to_string()
}

/// `body.code` → 归一化状态码
///
/// 必须逐字复刻 `request.js` 的逻辑：
///
/// ```text
/// SPECIAL_STATUS_CODES = {201, 302, 400, 502, 800, 801, 802, 803}
/// status = Number(body.code or http_status)
/// if body.code in SPECIAL: status = 200
/// if not (100 < status < 600): status = 400
/// ```
///
/// ⚠️ `code: 301`（需要登录）**不在**这张表里 → 失败。
pub fn map_status(body: &Value) -> u16 {
    const SPECIAL: [i64; 8] = [201, 302, 400, 502, 800, 801, 802, 803];

    let code = body
        .get("code")
        .and_then(|v| v.as_i64())
        .unwrap_or(200);

    if SPECIAL.contains(&code) {
        return 200;
    }
    if code > 100 && code < 600 {
        code as u16
    } else {
        400
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn strips_api_prefix() {
        assert_eq!(strip_api("/api/song/lyric"), "song/lyric");
        assert_eq!(strip_api("/api/v3/song/detail"), "v3/song/detail");
        assert_eq!(strip_api("no-prefix"), "no-prefix");
    }

    #[test]
    fn status_mapping_follows_special_table() {
        // 正常成功
        assert_eq!(map_status(&json!({"code": 200})), 200);
        // 特殊码一律当 200 —— 二维码轮询的 800/801/802/803 靠 body.code 表达
        for c in [201, 302, 400, 502, 800, 801, 802, 803] {
            assert_eq!(map_status(&json!({"code": c})), 200, "code={c}");
        }
        // ⚠️ 301（需要登录）不在表里 → 失败
        assert_eq!(map_status(&json!({"code": 301})), 301);
        // 其他正常码原样
        assert_eq!(map_status(&json!({"code": 404})), 404);
        // 超出 100..600 → 400
        assert_eq!(map_status(&json!({"code": 999})), 400);
        assert_eq!(map_status(&json!({"code": 0})), 400);
        // 无 code → 默认 200
        assert_eq!(map_status(&json!({})), 200);
    }

    #[test]
    fn set_cookie_is_cleaned() {
        assert_eq!(
            clean_set_cookie("MUSIC_U=abc; Path=/; Domain=.music.163.com; HttpOnly"),
            "MUSIC_U=abc"
        );
        assert_eq!(clean_set_cookie("__csrf=xyz"), "__csrf=xyz");
    }

    #[test]
    fn user_agent_by_crypto() {
        assert!(choose_user_agent(Crypto::Weapi, "").contains("Chrome/124"));
        assert!(choose_user_agent(Crypto::Eapi, "pc").starts_with("NeteaseMusic"));
        // ⚠️ osx 走 macOS 浏览器 UA
        assert!(choose_user_agent(Crypto::Eapi, "osx").contains("Macintosh"));
    }

    #[test]
    fn response_cookie_joined() {
        let r = ApiResponse {
            status: 200,
            body: json!({}),
            cookies: vec!["a=1".into(), "b=2".into()],
        };
        assert_eq!(r.cookie_joined(), "a=1;b=2");
        assert!(r.ok());
    }
}
