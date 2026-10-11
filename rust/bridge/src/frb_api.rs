//! FRB 的 root 模块（当前为空）
//!
//! ⚠️ FRB 要求 `rust_input` 里至少有一个以 `crate::` 开头的模块，否则会警告。
//! 真正的绑定都在 `kugou` 与 `netease` 两个 crate 里，它们的 Dart 产物落在
//! `lib/src/rust/third_party/<crate>/`。
//!
//! 如果将来需要一个「跨 crate」的顶层函数（比如统一的版本号），放这里。

/// 桥接层版本
pub fn bridge_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}
