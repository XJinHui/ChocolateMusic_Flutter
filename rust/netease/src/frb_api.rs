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
//! | [`crate::request::RequestOptions`] | 含 `serde_json::Value` 与 `HashMap` |
//! | [`crate::xeapi::PublicKeyState`] | 含 `Mutex<Option<..>>` 之类 |
//! | [`crate::crypto`] 各函数 | 处理原始字节，无 FFI 意义 |
//!
//! 所以 `flutter_rust_bridge.yaml` 里配的是 `crate::frb_api,crate::client` ——
//! 只扫本模块与 `client`（后者是为了拿到 `impl NetEaseClient` 里的方法）。
//!
//! # Dart 侧调用形态
//!
//! ```dart
//! import 'package:chocolate_music/src/rust/netease/frb_api.dart';
//!
//! final client = createClient(identityPath: dir.path);
//!
//! // 按原服务器路由透传（供 NetEaseCloud.dart 无改动迁移）
//! final json = await client.rawRequest(
//!   path: '/song/detail',
//!   query: {'ids': '347230'},
//!   cookie: myCookie,
//! );
//! ```
//!
//! ⚠️ **凭据走 `cookie` 参数**，不是 query —— 网易云是 Cookie 认证，
//! 与酷狗那边把 token 塞 query 的做法不同。

use crate::client::NetEaseClient;

// ============================================================
//  构造
// ============================================================

/// 创建客户端
///
/// - `identity_path`：设备身份文件的**绝对路径**。
///   移动端请用 `path_provider` 的 `getApplicationDocumentsDirectory()`，
///   **不要传相对路径**（移动端的当前工作目录不可写）。
///   传空串则不持久化（每次运行都是新设备，仅用于调试）。
///
/// ⚠️ 设备身份**必须持久化** —— 原 Node 实现每次启动都换 `deviceId`，
/// 这是最明显的风控特征。
pub fn create_client(identity_path: String) -> NetEaseClient {
    if identity_path.is_empty() {
        NetEaseClient::new()
    } else {
        NetEaseClient::with_identity_file(identity_path)
    }
}

/// 创建客户端（不持久化身份）
///
/// 每次调用都是全新设备，会导致风控信誉归零。**仅用于测试**。
pub fn create_ephemeral_client() -> NetEaseClient {
    NetEaseClient::new()
}

/// 库版本
pub fn version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

// ============================================================
//  路由能力查询
// ============================================================

/// 已实现的路由清单
pub fn supported_routes() -> Vec<String> {
    NetEaseClient::supported_routes()
}

/// 尚未实现的路由（当前为空）
pub fn unsupported_routes() -> Vec<String> {
    NetEaseClient::unsupported_routes()
}
