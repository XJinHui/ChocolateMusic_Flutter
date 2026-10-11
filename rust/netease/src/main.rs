//! 演示程序
//!
//! ```bash
//! # 任意路由直通（不登录也能跑一部分）
//! cargo run -- raw /song/detail ids=347230
//! cargo run -- raw /song/url id=347230 level=exhigh
//! cargo run -- raw /search keywords=海阔天空 type=1 limit=3
//!
//! # 二维码登录（打印 data URL，粘到浏览器地址栏即可看到图）
//! cargo run -- qr
//!
//! # 看看设备身份与路由清单
//! cargo run -- info
//! ```

use std::collections::HashMap;

use netease::{NetEaseClient, Result};

const IDENTITY_FILE: &str = "netease_identity.json";

#[tokio::main]
async fn main() {
    if let Err(e) = run().await {
        eprintln!("错误: {e}");
        std::process::exit(1);
    }
}

async fn run() -> Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let cmd = args.first().map(String::as_str).unwrap_or("help");

    let client = NetEaseClient::with_identity_file(IDENTITY_FILE);

    match cmd {
        "help" | "-h" | "--help" => print_help(),

        // ---------- 设备身份 ----------
        "info" => {
            println!("deviceId = {}", client.device_id());
            println!("WNMCID   = {}", client.wnmcid());
            println!("MUSIC_A  = {}", if client.has_music_a() { "已获取" } else { "未获取" });
            println!();
            println!("已实现路由（{} 条）:", NetEaseClient::supported_routes().len());
            for r in NetEaseClient::supported_routes() {
                println!("  {r}");
            }
            println!();
            println!("待实现路由（{} 条，需要 xeapi）:", NetEaseClient::unsupported_routes().len());
            for r in NetEaseClient::unsupported_routes() {
                println!("  {r}");
            }
        }

        // ---------- 任意路由直通 ----------
        "raw" => {
            let path = resolve_route(args.get(1).map(String::as_str).unwrap_or("/song/detail"));

            // 其余参数形如 k=v
            let query: HashMap<String, String> = args[2..]
                .iter()
                .filter_map(|a| a.split_once('='))
                .map(|(k, v)| (k.to_string(), v.to_string()))
                .collect();

            let cookie = std::env::var("NETEASE_COOKIE").unwrap_or_default();

            println!("→ {path}  {query:?}");
            let json = client.raw_request(path, query, cookie).await?;
            println!("{}", pretty(&json));
        }

        // ---------- 二维码登录 ----------
        "qr" => {
            let key_body = client.qr_key("").await?;
            let unikey = key_body
                .body
                .pointer("/data/unikey")
                .and_then(|v| v.as_str())
                .unwrap_or_default()
                .to_string();

            if unikey.is_empty() {
                println!("未拿到 unikey: {}", key_body.to_json());
                return Ok(());
            }
            println!("unikey = {unikey}");

            let img = client.qr_create(&unikey, "pc", true);
            let url = img.body["data"]["qrimg"].as_str().unwrap_or_default();
            println!("把下面这行粘到浏览器地址栏可看到二维码：");
            println!("{url}");
            println!();
            println!("之后用 `cargo run -- raw /login/qr/check key={unikey}` 轮询扫码状态");
        }

        other => {
            eprintln!("未知命令: {other}\n");
            print_help();
        }
    }

    Ok(())
}

fn print_help() {
    println!(
        r#"NetEaseCloud —— 网易云 API 的本地 Rust 实现

用法:
  cargo run -- info                         查看设备身份与路由清单
  cargo run -- raw <路由> [k=v ...]         直通任意路由
  cargo run -- qr                           生成登录二维码

示例:
  cargo run -- raw /song/detail ids=347230
  cargo run -- raw /song/url id=347230 level=exhigh
  cargo run -- raw /search keywords=海阔天空 type=1 limit=3
  cargo run -- raw /lyric id=347230
  cargo run -- raw /album id=347230
  cargo run -- raw /artist/detail id=347230

需要登录的接口请先设置环境变量 NETEASE_COOKIE（登录后拿到的 Cookie 串）。
"#
    );
}

/// 简易美化输出
fn pretty(json: &str) -> String {
    serde_json::from_str::<serde_json::Value>(json)
        .ok()
        .and_then(|v| serde_json::to_string_pretty(&v).ok())
        .unwrap_or_else(|| json.to_string())
}

/// 把命令行里的路由参数修成规范形式
///
/// 处理两件事：
/// 1. 补前导斜杠 —— 允许 `song/detail` 这种写法
/// 2. **Git Bash 的 MSYS 路径转换** —— `/song/detail` 会被自动转成
///    `D:/Git/song/detail`。这里按「路由表后缀匹配」救回来。
fn resolve_route(arg: &str) -> String {
    let with_slash = if arg.starts_with('/') {
        arg.to_string()
    } else {
        format!("/{arg}")
    };

    let mut all = NetEaseClient::supported_routes();
    all.extend(NetEaseClient::unsupported_routes());

    if all.iter().any(|r| *r == with_slash) {
        return with_slash;
    }

    // 取「匹配到的最长路由」，避免 `/ad/listening/rights/gain` 被 `/ad/listening/rights` 截胡
    all.iter()
        .filter(|r| with_slash.ends_with(r.as_str()))
        .max_by_key(|r| r.len())
        .cloned()
        .unwrap_or(with_slash)
}
