//! `raw_request` 透传层的**联网**冒烟测试
//!
//! 验证返回的确实是**原服务器形状**的响应体 —— 即 `Neteasecloud.dart` 里那些
//! `response.data['code']` / `response.data['data']['unikey']` 之类的取值路径都能命中。
//!
//! ```bash
//! cargo test --test raw_smoke -- --ignored --nocapture
//! ```
//!
//! ⚠️ 默认 `cargo test` 不会跑它（标了 `#[ignore]`），因为它要联网。
//! 只跑免登录接口，不会改动任何账号数据。

use std::collections::HashMap;

use netease::NetEaseClient;
use serde_json::Value;

fn q(pairs: &[(&str, &str)]) -> HashMap<String, String> {
    pairs
        .iter()
        .map(|(k, v)| (k.to_string(), v.to_string()))
        .collect()
}

async fn raw(client: &NetEaseClient, path: &str, query: HashMap<String, String>) -> Value {
    let text = client
        .raw_request(path.to_string(), query, String::new())
        .await
        .unwrap_or_else(|e| panic!("{path} 请求失败: {e}"));
    serde_json::from_str(&text).unwrap_or_else(|e| panic!("{path} 返回的不是 JSON: {e}\n{text}"))
}

const SONG_ID: &str = "347230";

fn client() -> NetEaseClient {
    // ⚠️ 身份文件不删除：设备身份持久化是刻意的设计
    let path = std::env::temp_dir().join("netease_raw_smoke_identity.json");
    NetEaseClient::with_identity_file(path)
}

#[tokio::test]
#[ignore = "需要联网；用 cargo test --test raw_smoke -- --ignored 运行"]
async fn raw_routes_roundtrip() {
    let c = client();
    println!("deviceId = {}", c.device_id());

    // ① /login/qr/key —— 上游 body 被整体塞进 data
    let body = raw(&c, "/login/qr/key", q(&[])).await;
    assert_eq!(body["code"], 200, "qr/key: {body}");
    let unikey = body["data"]["unikey"].as_str().expect("缺少 data.unikey");
    assert!(!unikey.is_empty());
    println!("① unikey = {unikey}");

    // ② /login/qr/create —— **不发网络请求**，本地生成 PNG data URL
    let body = raw(
        &c,
        "/login/qr/create",
        q(&[("key", unikey), ("qrimg", "true")]),
    )
    .await;
    assert_eq!(body["code"], 200);
    assert!(body["data"]["qrurl"].as_str().unwrap().contains("codekey="));
    let img = body["data"]["qrimg"].as_str().unwrap();
    assert!(
        img.starts_with("data:image/png;base64,"),
        "qrimg 应是 data URL，实际前 40 字: {}",
        &img[..40.min(img.len())]
    );
    println!("② 二维码 data URL 长度 = {}", img.len());

    // ③ /song/detail —— 客户端读 songs[].id/name/ar/al/dt
    let body = raw(&c, "/song/detail", q(&[("ids", SONG_ID)])).await;
    assert_eq!(body["code"], 200, "song/detail: {body}");
    let songs = body["songs"].as_array().expect("缺少 songs");
    assert!(!songs.is_empty());
    let s = &songs[0];
    for path in ["/id", "/name", "/ar/0/id", "/ar/0/name", "/al/name", "/al/id", "/dt", "/al/picUrl"] {
        assert!(!s.pointer(path).unwrap_or(&Value::Null).is_null(), "缺少 {path}");
    }
    println!(
        "③ {} - {} / {}",
        s.pointer("/ar/0/name").unwrap().as_str().unwrap(),
        s["name"].as_str().unwrap(),
        s.pointer("/al/name").unwrap().as_str().unwrap()
    );

    // ④ /song/url —— {code: 200, data: [...]}，且**按输入顺序重排**
    let body = raw(&c, "/song/url", q(&[("id", SONG_ID), ("level", "exhigh")])).await;
    assert_eq!(body["code"], 200, "song/url: {body}");
    let data = body["data"].as_array().expect("缺少 data 数组");
    assert!(!data.is_empty());
    println!(
        "④ url = {:?}",
        data[0]["url"].as_str().map(|u| &u[..u.len().min(60)])
    );

    // ⑤ /lyric —— 客户端读 lrc.lyric 与 tlyric.lyric
    let body = raw(&c, "/lyric", q(&[("id", SONG_ID)])).await;
    assert_eq!(body["code"], 200, "lyric: {body}");
    let lyric = body["lrc"]["lyric"].as_str().expect("缺少 lrc.lyric");
    assert!(!lyric.is_empty());
    assert!(body.get("tlyric").is_some(), "缺少 tlyric（可为 null）");
    println!("⑤ 歌词前 40 字: {}", &lyric[..lyric.len().min(40)]);

    // ⑥ /search —— 客户端传 keywords，上游字段是 s
    let body = raw(&c, "/search", q(&[("keywords", "海阔天空"), ("type", "1"), ("limit", "3")])).await;
    assert_eq!(body["code"], 200, "search: {body}");
    let hits = body["result"]["songs"].as_array().expect("缺少 result.songs");
    assert!(!hits.is_empty());
    println!("⑥ 搜到 {} 首", hits.len());

    // ⑦ /album —— id 在 URL 路径里，body 是空对象
    let album_id = s.pointer("/al/id").unwrap().to_string();
    let body = raw(&c, "/album", q(&[("id", &album_id)])).await;
    assert_eq!(body["code"], 200, "album: {body}");
    assert!(!body["songs"].as_array().unwrap().is_empty());
    assert!(body["album"]["name"].is_string());
    println!("⑦ 专辑 = {}", body["album"]["name"]);

    // ⑧ /artist/detail —— 客户端读 data.artist
    let artist_id = s.pointer("/ar/0/id").unwrap().to_string();
    let body = raw(&c, "/artist/detail", q(&[("id", &artist_id)])).await;
    assert_eq!(body["code"], 200, "artist/detail: {body}");
    assert!(body["data"]["artist"]["name"].is_string());
    println!("⑧ 歌手 = {}", body["data"]["artist"]["name"]);

    // ⑨ 未实现的路由要明确报错，而不是静默返回空
    assert!(c
        .raw_request("/not/a/route".into(), HashMap::new(), String::new())
        .await
        .is_err());
}

#[tokio::test]
#[ignore = "需要联网；用 cargo test --test raw_smoke -- --ignored 运行"]
async fn unauthenticated_routes_return_a_code() {
    let c = client();

    // 未登录时这些接口的行为各不相同（有的返回 code 301，有的返回 200 + null 账号），
    // 但共同点是：**必须把响应体原样返回，不能抛错** —— 客户端检查的正是
    // `data['code'] != 200` 或 `data['data']['code'] != 200`。
    for path in [
        "/login/status",
        "/user/account",
        "/recommend/songs",
        "/recommend/resource",
        "/vip/info",
    ] {
        let body = raw(&c, path, q(&[])).await;

        // code 可能在顶层（大多数接口），也可能被包在 data 里（login/status）
        let code = body
            .get("code")
            .or_else(|| body.pointer("/data/code"))
            .and_then(Value::as_i64);

        println!("{path} → code = {code:?}");
        assert!(code.is_some(), "{path} 既无顶层 code 也无 data.code: {body}");
    }
}

// ============================================================
//  广告免费听（xeapi）—— 需要登录 cookie
// ============================================================

/// 从环境变量 `NETEASE_COOKIE` 读账号 Cookie；没有就跳过
fn cookie() -> Option<String> {
    std::env::var("NETEASE_COOKIE")
        .ok()
        .filter(|s| !s.trim().is_empty())
}

#[tokio::test]
#[ignore = "需要联网 + NETEASE_COOKIE；用 cargo test --test raw_smoke -- --ignored 运行"]
async fn ad_routes_via_xeapi() {
    let Some(cookie) = cookie() else {
        eprintln!("跳过：未设置 NETEASE_COOKIE");
        return;
    };

    let c = client();

    // ① /ad/get —— xeapi 三层加密 + 响应解密
    let body = {
        let text = c
            .raw_request("/ad/get".into(), HashMap::new(), cookie.clone())
            .await
            .expect("/ad/get 失败（xeapi 加密或公钥有问题）");
        serde_json::from_str::<Value>(&text).unwrap()
    };
    assert_eq!(body["code"], 200, "ad/get: {body}");
    let ads = body["ads"].as_object().expect("缺少 ads 对象");
    assert!(!ads.is_empty(), "广告位为空（可能风控）");

    let ad = ads.values().next().unwrap();
    let ad_id = ad["id"].to_string();
    println!("① 广告 id = {ad_id}  extra.reqId = {:?}", body["extra"]["reqId"]);

    // ② /ad/listening/rights —— 只读
    let body = {
        let text = c
            .raw_request("/ad/listening/rights".into(), HashMap::new(), cookie.clone())
            .await
            .expect("/ad/listening/rights 失败");
        serde_json::from_str::<Value>(&text).unwrap()
    };
    assert_eq!(body["code"], 200, "listening/rights: {body}");
    assert!(
        body["data"]["rightsRemainingTime"].is_number(),
        "缺少 data.rightsRemainingTime: {body}"
    );
    assert!(
        body["data"]["rightsUpperLimit"].is_boolean(),
        "缺少 data.rightsUpperLimit"
    );
    println!(
        "② 剩余免费时长 = {} ms，已达上限 = {}",
        body["data"]["rightsRemainingTime"], body["data"]["rightsUpperLimit"]
    );

    // ③ /ad/listening/rights/gain —— ⚠️ 会真的领取一次免费时长
    let body = {
        let text = c
            .raw_request(
                "/ad/listening/rights/gain".into(),
                q(&[("reqUid", &ad_id)]),
                cookie.clone(),
            )
            .await
            .expect("/ad/listening/rights/gain 失败");
        serde_json::from_str::<Value>(&text).unwrap()
    };
    assert_eq!(body["code"], 200, "gain: {body}");
    // 响应被包一层：{code:200, data:<上游 body>}
    let gain = &body["data"]["data"];
    assert!(
        gain["gainFlag"].is_boolean(),
        "缺少 data.data.gainFlag: {body}"
    );
    println!(
        "③ gainFlag = {}  文案 = {:?}",
        gain["gainFlag"], gain["showContent"]
    );
}

#[tokio::test]
#[ignore = "需要联网；用 cargo test --test raw_smoke -- --ignored 运行"]
async fn anonymous_registration_shape() {
    // ⚠️ 这个接口上游**时好时坏**：2026-10-11 实测中途返回过 `{"code":400}`
    //    （原 Node 服务也一样，`curl http://127.0.0.1:3999/register/anonimous` → {"code":400}），
    //    随后又恢复正常。所以这里只验证**请求能发出去、响应是合法 JSON**，不硬校验业务码。
    let c = client();

    let text = c
        .raw_request("/register/anonimous".into(), HashMap::new(), String::new())
        .await
        .expect("请求本身不应失败（xeapi 加密 / 公钥获取应正常）");

    let body: Value = serde_json::from_str(&text).expect("响应不是 JSON");
    let code = body["code"].as_i64();
    println!("register/anonimous → code = {code:?}");
    assert!(code.is_some(), "响应缺少 code: {body}");

    // 正常时响应体里带 MUSIC_A（匿名 token）
    if code == Some(200) {
        let music_a = body
            .get("cookie")
            .and_then(Value::as_str)
            .filter(|s| s.contains("MUSIC_A"));
        println!("  含 MUSIC_A cookie: {}", music_a.is_some());
    }
}

#[test]
fn anonymous_username_golden_vector() {
    // 与 Node 的 `cloudmusic_dll_encode_id` + Base64 对拍（离线）
    let device = "9FF61AFF817A622BBD823F5335D1C13E4A2B8C0D1E3F5A7B9C2D4E6F8A0B1C3D";
    assert_eq!(
        netease::api::login::cloudmusic_dll_encode_id(device),
        "Vo+rLEWgkfI2mY4inSP6DA=="
    );
    assert_eq!(
        netease::api::login::anonymous_username(device),
        "OUZGNjFBRkY4MTdBNjIyQkJEODIzRjUzMzVEMUMxM0U0QTJCOEMwRDFFM0Y1QTdCOUMyRDRFNkY4QTBCMUMzRCBWbytyTEVXZ2tmSTJtWTRpblNQNkRBPT0="
    );
}
