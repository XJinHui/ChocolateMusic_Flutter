//! 连通性探针 —— 验证「强制 IPv4」能否消除概率性 `WSAECONNRESET`
//!
//! ```text
//! cargo run --release --example probe
//! ```
//!
//! ## 背景
//!
//! `*.music.163.com` 都发 AAAA 记录，本机 IPv6 出口（手机热点）到该 CDN 的路径
//! 不稳定 —— 约 2/3 的新连接被 RST（`os error 10054`）。而 hyper-util 默认按
//! DNS 返回的**第一条**地址决定地址族偏好，本机解析结果 IPv6 在前 → 走 IPv6。
//!
//! `ClientBuilder::local_address` 设为 IPv4 时，hyper-util 会把 IPv6 地址
//! **整个过滤掉**（`split_by_preference` 的 `(Some(_), None)` 分支），
//! 于是只连 IPv4。
//!
//! ## 对照设计
//!
//! 逐个交错：同一轮先发「默认」再发「强制 IPv4」，两者都是**全新连接**
//! （每次新建 Client），唯一变量就是地址族偏好。

use std::net::Ipv4Addr;
use std::time::Duration;

const N: usize = 25;
const URL: &str = "https://interface3.music.163.com/xeapi/ad/get";

fn client(force_v4: bool) -> reqwest::Client {
    let b = reqwest::Client::builder()
        .connect_timeout(Duration::from_secs(10))
        .timeout(Duration::from_secs(30));
    if force_v4 {
        b.local_address(std::net::IpAddr::V4(Ipv4Addr::UNSPECIFIED))
            .build()
            .unwrap()
    } else {
        b.build().unwrap()
    }
}

/// 一次全新连接的 POST；失败返回**带 source 链**的描述
async fn once(force_v4: bool) -> Result<(), String> {
    let c = client(force_v4);
    match c.post(URL).body("B=&S=&R=").send().await {
        Ok(_) => Ok(()),
        Err(e) => {
            let mut chain = e.to_string();
            let mut src = std::error::Error::source(&e);
            while let Some(s) = src {
                let m = s.to_string();
                if !chain.contains(&m) {
                    chain.push_str(" ← ");
                    chain.push_str(&m);
                }
                src = s.source();
            }
            Err(chain)
        }
    }
}

#[tokio::main]
async fn main() {
    println!("【交错对照】{URL}");
    println!("每轮各发一次全新连接请求，唯一变量是地址族偏好\n");

    let (mut a_ok, mut b_ok) = (0usize, 0usize);
    let mut a_err: Vec<String> = Vec::new();
    let mut b_err: Vec<String> = Vec::new();

    for i in 1..=N {
        // A：默认（happy eyeballs，IPv6 优先）
        match once(false).await {
            Ok(()) => {
                a_ok += 1;
                print!(".");
            }
            Err(e) => {
                print!("x");
                a_err.push(format!("  #{i}: {e}"));
            }
        }
        // B：强制 IPv4
        match once(true).await {
            Ok(()) => {
                b_ok += 1;
                print!("+");
            }
            Err(e) => {
                print!("-");
                b_err.push(format!("  #{i}: {e}"));
            }
        }
        tokio::time::sleep(Duration::from_millis(120)).await;
    }

    println!("\n\n  A 默认（IPv6 优先） : {a_ok}/{N}");
    for e in &a_err {
        println!("{e}");
    }
    println!("\n  B 强制 IPv4         : {b_ok}/{N}");
    for e in &b_err {
        println!("{e}");
    }
}
