//! flutter_rust_bridge 对外层
//!
//! # 为什么单独开一个模块
//!
//! FRB 的 `generate` 会扫描 `rust_input` 指定的模块，**并对其中的所有 `pub` 项
//! 生成绑定**。本 crate 的内部实现里有几类 FRB 无法转换的类型：
//!
//! | 类型 | 问题 |
//! | --- | --- |
//! | [`crate::request::Transport`] | 含 `reqwest::Client` |
//! | [`crate::request::RequestOptions`] | 含 `serde_json::Value` 与 `BTreeMap` |
//! | [`crate::api::song::privilege_lite`] 等 | 返回 `Vec<Value>` |
//! | [`crate::crypto`] 各函数 | 处理原始字节，无 FFI 意义 |
//!
//! 所以 `flutter_rust_bridge.yaml` 里配的是：
//!
//! ```yaml
//! rust_input: crate::frb_api
//! ```
//!
//! FRB 只会扫描**本模块**，内部实现完全不受影响。
//!
//! # Dart 侧调用形态
//!
//! ```dart
//! import 'package:chocolate_music/src/rust/api/frb_api.dart';
//!
//! final client = createClient(platform: 'lite', identityPath: dir.path);
//! await client.registerDevice();
//!
//! final songs = await client.getRecommendMusics(num: 10);
//! for (final s in songs) {
//!   print('${s.singer} - ${s.name}');
//! }
//!
//! final url = await client.getMusicUrl(hash: songs.first.id, quality: '320');
//! ```

// ============================================================
//  对外类型
// ============================================================
//
// 全部为纯数据结构（String / i64 / Vec / 嵌套结构体），FRB 可直接镜像。

pub use crate::api::login::{LoginResult, QrStatus};
pub use crate::api::playlist::TrackItem;
pub use crate::client::KuGouClient;
pub use crate::models::{Album, KugouData, MatchInfo, Music, Playlist, SearchResult, Singer};
pub use crate::Error;

// ============================================================
//  构造
// ============================================================

/// 创建客户端
///
/// - `platform`：`"lite"`（概念版）或 `"standard"`（标准版，默认）
/// - `identity_path`：设备身份文件的**绝对路径**。
///   移动端请用 `path_provider` 的 `getApplicationDocumentsDirectory()`，
///   **不要传相对路径**（移动端的当前工作目录不可写）。
///   传空串则不持久化（每次运行都是新设备，仅用于调试）。
///
/// ```dart
/// final dir = await getApplicationDocumentsDirectory();
/// final client = createClient(
///   platform: 'lite',
///   identityPath: '${dir.path}/kugou_identity.json',
/// );
/// ```
pub fn create_client(platform: String, identity_path: String) -> KuGouClient {
    let p = crate::platform::Platform::parse(&platform);
    if identity_path.is_empty() {
        KuGouClient::new(p)
    } else {
        KuGouClient::with_identity_file(p, identity_path)
    }
}

/// 创建客户端（不持久化身份）
///
/// 每次调用都是全新设备，会导致风控信誉归零。**仅用于测试**。
pub fn create_ephemeral_client(platform: String) -> KuGouClient {
    KuGouClient::new(crate::platform::Platform::parse(&platform))
}

/// 库版本
pub fn version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

// ============================================================
//  纯函数工具（无需客户端）
// ============================================================

/// 清洗 LRC：只保留含时间标签的行，剔除 `[ti:]`/`[ar:]` 等元数据
pub fn process_lyric(lrc: String) -> String {
    crate::lyric::process_lyric(&lrc)
}

/// KRC 逐字歌词 → LRC
pub fn krc_to_lrc(krc: String) -> String {
    crate::lyric::krc_to_lrc(&krc)
}

/// 毫秒 → LRC 时间格式 `mm:ss.xx`
pub fn ms_to_lrc_time(ms: i64) -> String {
    crate::lyric::ms_to_lrc_time(ms)
}

/// 替换封面 URL 的尺寸占位符
///
/// `{size}` → `size`，`/240/` → `/{size}/`
pub fn get_cover(url: String, size: String) -> String {
    crate::models::get_cover(&url, &size)
}

/// 由 GUID 计算 MID（39 位十进制）
///
/// 供调试/展示用。正常流程不需要手动调用 —— 客户端会自动算。
pub fn calculate_mid(guid: String) -> String {
    crate::device::calculate_mid(&guid)
}

/// 生成 UUID v4
pub fn uuid_v4() -> String {
    crate::device::uuid_v4()
}

/// 判断字符串是否为合法 UUID v4
pub fn is_uuid_v4(s: String) -> bool {
    crate::device::is_uuid_v4(&s)
}
