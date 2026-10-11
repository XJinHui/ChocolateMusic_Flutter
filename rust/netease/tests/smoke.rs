//! 对**真实网易云 API** 的冒烟测试
//!
//! 只跑不需要登录的接口，验证协议层（weapi / eapi）能跑通。
//!
//! ```bash
//! cargo test --test smoke -- --ignored --nocapture
//! ```
//!
//! ⚠️ 默认 `cargo test` 不会跑它（标了 `#[ignore]`），因为它要联网。

use netease::{Crypto, DeviceIdentity, RequestOptions, Transport};
use serde_json::json;

/// 一个稳定的公开歌曲 ID
const SONG_ID: &str = "347230";

fn transport() -> Transport {
    Transport::new(DeviceIdentity::generate())
}

#[tokio::test]
#[ignore = "需要联网；用 cargo test --test smoke -- --ignored 运行"]
async fn eapi_lyric() {
    let t = transport();

    let r = t
        .send(RequestOptions::new(
            "/api/song/lyric",
            Crypto::Eapi,
            json!({"id": SONG_ID, "tv": -1, "lv": -1, "rv": -1, "kv": -1, "_nmclfl": 1}),
        ))
        .await
        .expect("请求失败");

    println!("status = {}  code = {:?}", r.status, r.code());
    let lyric = r
        .str_at(&["lrc", "lyric"])
        .expect("缺少 lrc.lyric");
    assert!(!lyric.is_empty(), "歌词为空");
    println!("歌词前 80 字: {}", &lyric[..lyric.len().min(80)]);
}

#[tokio::test]
#[ignore = "需要联网；用 cargo test --test smoke -- --ignored 运行"]
async fn weapi_song_detail() {
    let t = transport();

    let r = t
        .send(RequestOptions::new(
            "/api/v3/song/detail",
            Crypto::Weapi,
            json!({"c": format!(r#"[{{"id":{SONG_ID}}}]"#)}),
        ))
        .await
        .expect("请求失败");

    println!("status = {}  code = {:?}", r.status, r.code());
    let songs = r.body.get("songs").and_then(|v| v.as_array()).expect("缺少 songs");
    assert!(!songs.is_empty());

    let s = &songs[0];
    println!(
        "歌曲: {} / {} / {}",
        s.get("name").and_then(|v| v.as_str()).unwrap_or("?"),
        s.pointer("/al/name").and_then(|v| v.as_str()).unwrap_or("?"),
        s.pointer("/ar/0/name").and_then(|v| v.as_str()).unwrap_or("?")
    );

    // 客户端读的字段路径
    assert!(s.get("id").is_some());
    assert!(s.pointer("/ar/0/id").is_some());
    assert!(s.pointer("/al/picUrl").is_some());
    assert!(s.get("dt").is_some());
}

#[tokio::test]
#[ignore = "需要联网；用 cargo test --test smoke -- --ignored 运行"]
async fn eapi_search() {
    let t = transport();

    let r = t
        .send(RequestOptions::new(
            "/api/search/get",
            Crypto::Eapi,
            json!({"s": "海阔天空", "type": 1, "limit": 5, "offset": 0}),
        ))
        .await
        .expect("请求失败");

    println!("status = {}  code = {:?}", r.status, r.code());
    let songs = r
        .body
        .pointer("/result/songs")
        .and_then(|v| v.as_array())
        .expect("缺少 result.songs");
    assert!(!songs.is_empty());
    println!("搜到 {} 首", songs.len());
    for s in songs.iter().take(3) {
        println!(
            "  {} - {}",
            s.pointer("/ar/0/name").and_then(|v| v.as_str()).unwrap_or("?"),
            s.get("name").and_then(|v| v.as_str()).unwrap_or("?")
        );
    }
}

#[tokio::test]
#[ignore = "需要联网；用 cargo test --test smoke -- --ignored 运行"]
async fn eapi_song_url() {
    let t = transport();

    let r = t
        .send(RequestOptions::new(
            "/api/song/enhance/player/url",
            Crypto::Eapi,
            json!({"ids": format!(r#"["{SONG_ID}"]"#), "br": 999000}),
        ))
        .await
        .expect("请求失败");

    println!("status = {}  code = {:?}", r.status, r.code());
    let data = r.body.get("data").and_then(|v| v.as_array()).expect("缺少 data");
    assert!(!data.is_empty());
    println!(
        "播放地址: {:?}",
        data[0].get("url").and_then(|v| v.as_str())
    );
}

#[tokio::test]
#[ignore = "需要联网；用 cargo test --test smoke -- --ignored 运行"]
async fn eapi_qr_key() {
    let t = transport();

    let r = t
        .send(RequestOptions::new(
            "/api/login/qrcode/unikey",
            Crypto::Eapi,
            json!({"type": 3}),
        ))
        .await
        .expect("请求失败");

    println!("status = {}  code = {:?}", r.status, r.code());
    println!("unikey = {:?}", r.str_at(&["unikey"]));
    println!("Set-Cookie 条数 = {}", r.cookies.len());
    assert!(r.code() == Some(200), "二维码 key 接口应返回 200: {}", r.body);
}
