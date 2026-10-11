//! `raw_request` 的联网冒烟测试
//!
//! 验证透传层返回的确实是**原服务器形状**的原始 JSON —— 即 `KuGou.dart`
//! 里那些 `response.data["status"]` / `response.data['data']['songs']`
//! 之类的取值路径都能照常命中。
//!
//! ```bash
//! cargo test --test raw_smoke -- --ignored --nocapture
//! ```
//!
//! ⚠️ 默认 `cargo test` **不会**跑它（标了 `#[ignore]`），因为它要联网。
//!
//! 只跑免登录接口，不会改动任何账号数据。

use std::collections::HashMap;

use kugou::{KuGouClient, Platform};
use serde_json::Value;

fn q(pairs: &[(&str, &str)]) -> HashMap<String, String> {
    pairs
        .iter()
        .map(|(k, v)| (k.to_string(), v.to_string()))
        .collect()
}

async fn raw(client: &mut KuGouClient, path: &str, query: HashMap<String, String>) -> Value {
    let text = client
        .raw_request(path.to_string(), query)
        .await
        .unwrap_or_else(|e| panic!("{path} 请求失败: {e}"));
    serde_json::from_str(&text).unwrap_or_else(|e| panic!("{path} 返回的不是 JSON: {e}\n{text}"))
}

#[tokio::test]
#[ignore = "需要联网；用 cargo test --test raw_smoke -- --ignored 运行"]
async fn raw_roundtrip() {
    // ⚠️ 身份文件**不删除**：`/register/dev` 有频率限制，反复注册会被上游
    //    挡回 `{"data":[],"error_code":0,"status":1}`。复用同一份身份即可。
    let path = std::env::temp_dir().join("kugou_raw_smoke_identity.json");
    let mut client = KuGouClient::with_identity_file(Platform::Lite, &path);

    // ① 存活探测：本地没有服务器，恒为成功
    let body = raw(&mut client, "/", HashMap::new()).await;
    assert_eq!(body["status"], 1, "存活探测: {body}");

    // ② /register/dev —— 验证响应体已 AES 解密
    let body = raw(&mut client, "/register/dev", HashMap::new()).await;
    assert_eq!(body["status"], 1, "register/dev: {body}");
    match body["data"]["dfid"].as_str() {
        Some(dfid) if !dfid.is_empty() => {
            // 副作用：dfid 必须写回客户端，否则后续接口会提示「需要验证」
            assert_eq!(client.dfid(), dfid, "dfid 未写回客户端");
            println!("① dfid = {dfid}");
        }
        _ => {
            // 被频率限制挡回：`data` 是空数组。用已持久化的 dfid 继续。
            println!("① register/dev 被限流（data 为空），沿用已保存的 dfid");
        }
    }
    assert!(!client.dfid().is_empty(), "没有可用的 dfid，无法继续");
    println!("   dfid = {}", client.dfid());

    // ③ /everyday/recommend —— 原始形状是 data.song_list
    let body = raw(&mut client, "/everyday/recommend", HashMap::new()).await;
    assert_eq!(body["status"], 1, "recommend: {body}");
    let songs = body["data"]["song_list"]
        .as_array()
        .expect("缺少 data.song_list")
        .clone();
    assert!(!songs.is_empty());
    let hashes: Vec<String> = songs
        .iter()
        .filter_map(|s| s["hash"].as_str().map(str::to_string))
        .collect();
    let hash = hashes[0].clone();
    println!("② 推荐歌曲 {} 首，首曲 hash = {hash}", songs.len());

    // ④ /privilege/lite —— data 直接是数组（不是对象）
    let body = raw(&mut client, "/privilege/lite", q(&[("hash", &hash)])).await;
    assert_eq!(body["status"], 1, "privilege/lite: {body}");
    let arr = body["data"].as_array().expect("data 应是数组");
    assert_eq!(arr[0]["hash"].as_str().unwrap(), hash);
    // KuGou.dart 取的是这几个字段，确认它们都在
    for key in ["name", "singername", "albumname", "album_audio_id", "info"] {
        assert!(!arr[0][key].is_null(), "privilege/lite 缺少字段 {key}");
    }
    assert!(arr[0]["info"]["duration"].is_number(), "缺少 info.duration");
    println!("③ 详情字段齐全（name/singername/albumname/info.duration）");

    // ⑤ /song/url —— 地址在**顶层** url 数组，不在 data 下
    //
    // ⚠️ `status` 可能是 2（无版权 / 需购买），这是上游的正常业务响应，
    // 原 Dart 代码也是据此判断并返回 ''。这里只校验形状。
    // ⑤ /song/url —— 地址在**顶层** url 数组，不在 data 下
    //
    // ⚠️ `status` 常见 2（无版权 / 需购买），这是上游的正常业务响应，
    //    原 Dart 代码也是据此判断并返回 ''。这里挑一首能播的来验证 url 形状。
    let mut played = false;
    for h in hashes.iter().take(10) {
        let body = raw(
            &mut client,
            "/song/url",
            q(&[("hash", h), ("quality", "128")]),
        )
        .await;
        assert!(body["status"].is_number(), "song/url 缺少 status: {body}");

        if body["status"] == 1 {
            // 有版权时地址在**顶层** `url` 数组（不是 `data.url`）
            assert!(body["url"].is_array(), "song/url 缺少顶层 url 数组: {body}");
            println!("④ 播放地址 = {:?}", body["url"][0]);
            played = true;
            break;
        }
        // 无版权（status=2）时上游**完全不返回** `url` 字段 —— 这也是原样透传
    }
    if !played {
        println!("④ 前 10 首均无版权（status=2），只验证了响应形状");
    }

    // ⑥ /search/complex —— PascalCase 字段
    //
    // ⚠️ 未登录时上游返回 `status:1, error_code:152`（业务失败但 HTTP 成功）。
    //    原服务器会把这个体**原样**返回，所以透传层也必须返回它而不是报错 ——
    //    `KuGou.dart` 正是靠 `response.data["status"] != 1` 判断的。
    let body = raw(
        &mut client,
        "/search/complex",
        q(&[("keywords", "海阔天空")]),
    )
    .await;
    assert!(body["status"].is_number(), "search/complex 缺少 status: {body}");
    assert!(
        body["data"]["lists"].is_array(),
        "search/complex 缺少 data.lists: {body}"
    );
    println!(
        "⑤ 搜索分组 {} 个（error_code={}）",
        body["data"]["lists"].as_array().unwrap().len(),
        body["error_code"]
    );

    // ⑦ 未实现的路径要明确报错，而不是静默返回空
    assert!(client
        .raw_request("/not/a/route".into(), HashMap::new())
        .await
        .is_err());


}
