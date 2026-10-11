//! 演示程序：验证各条链路是否跑通
//!
//! ```bash
//! # 只跑不需要登录的部分（搜索 / 推荐 / 取 URL）
//! cargo run -- search 海阔天空
//! cargo run -- recommend
//! cargo run -- url <hash>
//!
//! # 需要登录
//! cargo run -- captcha 13800138000
//! cargo run -- login 13800138000 123456
//! cargo run -- qr
//! cargo run -- playlists
//! ```

use kugou::{KuGouClient, Platform, Result};

#[tokio::main]
async fn main() {
    if let Err(e) = run().await {
        eprintln!("错误: {e}");
        if let Some(msg) = e.api_message() {
            eprintln!("上游消息: {msg}");
        }
        std::process::exit(1);
    }
}

async fn run() -> Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let cmd = args.first().map(String::as_str).unwrap_or("help");

    // 平台从环境变量读，默认概念版（与原部署一致）
    let platform = Platform::parse(&std::env::var("KUGOU_PLATFORM").unwrap_or_default());
    println!("平台: {platform:?}  appid={} clientver={}", platform.appid(), platform.clientver());

    let mut client = KuGouClient::with_identity_file(platform, "kugou_identity.json");
    println!("设备 MID: {}", client.device_mid());
    println!("设备 GUID: {}", client.device_guid());

    match cmd {
        // ---------- 帮助 ----------
        "help" | _ if cmd == "help" => {
            print_help();
        }

        // ---------- 设备注册 ----------
        "register" => {
            let dfid = client.register_device().await?;
            println!("dfid = {dfid}");
        }

        // ---------- 搜索 ----------
        "search" => {
            let kw = args.get(1).map(String::as_str).unwrap_or("海阔天空");
            ensure_dfid(&mut client).await;

            let r = client.search_with_details(kw).await?;
            println!("\n=== 歌曲 ({}) ===", r.music.len());
            for m in r.music.iter().take(10) {
                println!("  {} - {}  [{}]", m.singer, m.name, &m.id[..m.id.len().min(12)]);
            }
            println!("\n=== 歌手 ({}) ===", r.singer.len());
            for s in r.singer.iter().take(5) {
                println!("  {}  id={}", s.singer, s.singer_id);
            }
            println!("\n=== 专辑 ({}) ===", r.album.len());
            for a in r.album.iter().take(5) {
                println!("  {} - {}", a.singer, a.album);
            }
        }

        // ---------- 推荐 ----------
        "recommend" => {
            ensure_dfid(&mut client).await;

            let songs = client.get_recommend_musics(5).await?;
            println!("\n=== 每日推荐 ({} 首) ===", songs.len());
            for m in &songs {
                println!("  {} - {}  [{}]", m.singer, m.name, m.id);
            }

            let singers = client.get_recommend_singers(5).await?;
            println!("\n=== 推荐歌手 ({}) ===", singers.len());
            for s in &singers {
                println!("  {}  id={}", s.singer, s.singer_id);
            }

            let playlists = client.get_recommend_playlists(5).await?;
            println!("\n=== 推荐歌单 ({}) ===", playlists.len());
            for p in &playlists {
                println!("  {}", p.name);
            }
        }

        // ---------- 播放地址 ----------
        "url" => {
            let hash = args.get(1).expect("用法: url <hash> [quality]");
            let quality = args.get(2).map(String::as_str).unwrap_or("128");
            ensure_dfid(&mut client).await;

            let url = client.get_music_url(hash, quality).await?;
            if url.is_empty() {
                println!("未取得播放地址（无版权 / 需 VIP / 未登录）");
            } else {
                println!("{url}");
            }
        }

        // ---------- 歌词 ----------
        "lyric" => {
            let hash = args.get(1).expect("用法: lyric <hash>");
            ensure_dfid(&mut client).await;
            let lrc = client.get_lyric(hash).await?;
            println!("{lrc}");
        }

        // ---------- 歌手 ----------
        "singer" => {
            let id = args.get(1).expect("用法: singer <singerId>");
            ensure_dfid(&mut client).await;

            let s = client.get_singer_detail(id).await?;
            println!("歌手: {}  (歌曲 {} / 专辑 {})", s.singer, s.audio_count, s.album_count);

            let albums = client.get_singer_albums(id).await?;
            println!("\n=== 专辑 ({}) ===", albums.len());
            for a in albums.iter().take(10) {
                println!("  {}  ({})", a.album, a.album_id);
            }

            let songs = client.get_singer_music(id).await?;
            println!("\n=== 单曲 ({}) ===", songs.len());
            for m in songs.iter().take(10) {
                println!("  {} - {}", m.singer, m.name);
            }
        }

        // ---------- 专辑 ----------
        "album" => {
            let id = args.get(1).expect("用法: album <albumId>");
            ensure_dfid(&mut client).await;

            let a = client.get_album_detail(id).await?;
            println!("专辑: {} - {}", a.singer, a.album);

            let songs = client.get_album_music(id).await?;
            println!("\n=== 歌曲 ({}) ===", songs.len());
            for m in &songs {
                println!("  {} - {}", m.singer, m.name);
            }
        }

        // ---------- 验证码 ----------
        "captcha" => {
            let mobile = args.get(1).expect("用法: captcha <mobile>");
            client.send_captcha(mobile).await?;
            println!("验证码已发送");
        }

        // ---------- 手机登录 ----------
        "login" => {
            let mobile = args.get(1).expect("用法: login <mobile> <code>");
            let code = args.get(2).expect("用法: login <mobile> <code>");

            let r = client.login_cellphone(mobile, code).await?;
            println!("登录成功!");
            println!("  userid: {}", r.userid);
            println!("  nickname: {}", r.nickname);
            println!("  token: {}...", &r.token[..r.token.len().min(16)]);
            println!("  过期时间: {}", r.t_expire_time);

            list_playlists(&mut client).await?;
        }

        // ---------- 二维码登录 ----------
        "qr" => {
            let (key, img) = client.qr_key().await?;
            println!("二维码 key: {key}");
            if !img.is_empty() {
                println!("二维码图片: {}... ({} 字节)", &img[..img.len().min(48)], img.len());
            }
            println!("请用酷狗 App 扫码…");

            let r = client.qr_login_wait(&key, 2, 90).await?;
            println!("\n登录成功!");
            println!("  userid: {}", r.userid);
            println!("  nickname: {}", r.nickname);

            list_playlists(&mut client).await?;
        }

        // ---------- 歌单 ----------
        "playlists" => {
            list_playlists(&mut client).await?;
        }

        // ---------- VIP ----------
        "vip" => {
            println!("领取广告 VIP（8 次，间隔 15 秒）…");
            let n = client.claim_ad_vip().await?;
            println!("成功 {n} 次");
            client.claim_daily_vip().await?;
            println!("每日 VIP 已领取");
            client.upgrade_vip().await?;
            println!("VIP 升级已提交");
        }

        other => {
            eprintln!("未知命令: {other}");
            print_help();
            std::process::exit(1);
        }
    }

    Ok(())
}

/// 若尚无 dfid，先注册
async fn ensure_dfid(client: &mut KuGouClient) {
    if client.dfid() == "-" {
        print!("首次使用，正在获取 dfid… ");
        match client.register_device().await {
            Ok(d) => println!("{d}"),
            Err(e) => println!("失败({e})，继续尝试（可能触发风控）"),
        }
    }
}

async fn list_playlists(client: &mut KuGouClient) -> Result<()> {
    let list = client.get_playlists().await?;
    println!("\n=== 歌单 ({}) ===", list.len());
    for p in &list {
        println!("  {:<20} 歌曲 {:>4}  gid={}", p.name, p.audio_count, p.list_id);
    }

    if !client.favorite_playlist_id().is_empty() {
        let hashes = client.get_collection_hashes().await?;
        println!("\n收藏歌单「我喜欢的音乐」共 {} 首", hashes.len());
    }
    Ok(())
}

fn print_help() {
    println!(
        r#"
KuGou —— 酷狗音乐 API 本地实现

用法: cargo run -- <命令> [参数]

设备
  register                     获取 dfid（首次必须）

搜索与浏览
  search <关键词>              综合搜索（歌曲/歌手/专辑）
  recommend                    每日推荐 + 推荐歌手 + 推荐歌单
  singer <singerId>            歌手详情 + 专辑 + 单曲
  album <albumId>              专辑详情 + 歌曲

播放
  url <hash> [quality]         取播放地址（quality: 128/320/flac）
  lyric <hash>                 取歌词

登录
  captcha <mobile>             发送验证码
  login <mobile> <code>        验证码登录
  qr                           二维码登录
  playlists                    列出歌单

VIP
  vip                          领取每日 VIP

环境变量
  KUGOU_PLATFORM=lite|standard 平台（默认 lite）

身份文件
  kugou_identity.json          首次运行自动生成并持久化
"#
    );
}
