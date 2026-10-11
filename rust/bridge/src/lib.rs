//! flutter_rust_bridge 桥接 crate
//!
//! 把各 API crate 汇成**一个**动态库供 Flutter 调用。
//!
//! # 为什么需要它
//!
//! FRB 的 `rust_root` 只能有一个，且只有「root crate」用 `crate::` 路径；
//! 其余 crate 一律走 `cargo expand -p <包名>`，生成的 Dart 落在
//! `lib/src/rust/third_party/<包名>/`。
//!
//! 所以这里放一个**只做汇总、不含业务逻辑**的 crate：
//!
//! ```text
//! bridge（cdylib，FRB 的 root）
//!   ├── kugou     → 酷狗音乐 API
//!   └── netease   → 网易云音乐 API
//! ```
//!
//! 这样各 API crate 之间**互不依赖** —— 否则「kugou 依赖 netease」这种
//! 只为让 FRB 扫到而存在的假依赖会污染依赖图。
//!
//! ## 新增一个 API crate
//!
//! 1. `rust/<名字>/` 建 crate
//! 2. 加进 `rust/Cargo.toml` 的 `members`
//! 3. 加进本文件的 `Cargo.toml` 依赖
//! 4. 加进 `flutter_rust_bridge.yaml` 的 `rust_input`
//! 5. 重新 `flutter_rust_bridge_codegen generate`

// ⚠️ 由 flutter_rust_bridge 生成，勿删。
// 注意：FRB 会把它注入到第 1 行，那样会插在 `//!` 文档注释之前导致解析失败，
// 因此每次 generate 后需确认它仍在**模块声明区**而非文件开头。
mod frb_generated;

pub mod frb_api;
