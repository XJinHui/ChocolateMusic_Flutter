# flutter_rust_bridge 集成记录

> 本文记录 **KuGou crate 接入 chocolate_music 的实际过程**与踩到的坑。
> 集成已完成并验证通过（2026-10-11）。

## 当前状态

| 项 | 状态 |
| --- | --- |
| 目录布局 | ✅ Cargo workspace，可容纳多个 Rust crate |
| Rust 编译 | ✅ `cargo build` 通过 |
| Rust 单元测试 | ✅ 40 个全过 |
| FRB 代码生成 | ✅ `Done!` |
| 生成的 Dart | ✅ `dart analyze` 零问题 |
| Flutter 集成 | ✅ `rust_builder/` 已就位 |
| 集成测试 | `integration_test/kugou_test.dart` |

## 目录布局

```
chocolate_music/
├── flutter_rust_bridge.yaml      ← FRB 配置（必须在项目根）
├── pubspec.yaml
├── lib/
│   ├── main.dart                 ← 你的代码，未被改动
│   └── src/rust/                 ← FRB 生成物（勿手改）
│       ├── frb_generated.dart
│       ├── frb_api.dart          ← 顶层函数
│       ├── client.dart           ← KuGouClient（54 个方法）
│       ├── models.dart           ← Music / Singer / Album / Playlist
│       └── api/login.dart        ← LoginResult / QrStatus
├── rust/                         ← Rust workspace
│   ├── Cargo.toml                ← workspace 根（虚拟 manifest）
│   └── kugou/                    ← 酷狗 crate
│       ├── Cargo.toml
│       ├── src/
│       └── MOVE_GUIDE.md
└── rust_builder/                 ← FRB 的构建插件（integrate 生成）
```

### 后续新增 Rust crate

```
rust/
├── Cargo.toml                    ← 把新 crate 加进 members
├── kugou/
└── <新crate>/                    ← 新建
```

然后在 `flutter_rust_bridge.yaml` 的 `rust_input` 里追加该 crate 要扫描的模块，
再跑一次 `generate`。

---

## ⚠️ 踩过的坑（按严重程度）

### 1. `integrate` 会覆盖 `lib/main.dart`

`flutter_rust_bridge_codegen integrate` 默认：

- **把 `lib/main.dart` 的原始内容整个注释掉**，替换成 demo（引用 `Hello, Tom!`）
- 对 `lib/` 下**所有**文件跑 `dart fix` + `dart format`（本次改了 40 个文件）

**规避方式**：以后在别的项目集成时用

```bash
flutter_rust_bridge_codegen integrate \
  --no-write-lib \
  --no-dart-fix \
  --no-dart-format
```

本次已用 `git checkout -- lib/ analysis_options.yaml` 全部还原，你的代码未受影响。

### 2. `rust_input` 必须包含 `crate::client`

只写 `crate::frb_api` 时，`KuGouClient` 会生成成**空类** —— 因为 `#[frb(opaque)]`
只标记类型，方法来自 `impl` 块，而 impl 块在 `client.rs` 里。

```yaml
rust_input: crate::frb_api,crate::client
```

### 3. FRB 把 `mod frb_generated;` 注入到第 1 行

这会插在 `//!` 内部文档注释**之前**，而 Rust 要求 `//!` 必须在所有 item 之前，
导致解析失败：

```
Error: expected square brackets
```

**处理**：generate 后确认它仍在**模块声明区**（`pub mod api;` 附近），
不在文件开头。已在 `lib.rs` 里加了注释说明。

### 4. `rust_root` 必须指向 crate，不是 workspace 根

指向 `rust/` 会报：

```
manifest path ... is a virtual manifest, but this command requires
running against an actual package in this workspace
```

因为 workspace 根的 `Cargo.toml` 只有 `[workspace]`，没有 `[package]`，
而 FRB 要在该目录跑 `cargo expand`。

```yaml
rust_root: rust/kugou/
```

### 5. 公开 API 里不能出现 `PathBuf`

原来 `client.rs` 有个 `pub fn default_identity_path() -> PathBuf`，
FRB 为它生成了 `impl SseDecode for PathBuf` 却没导入 `std::path::PathBuf`，
导致 `frb_generated.rs` 编译失败。

**已删除**（Dart 侧自己用 `path_provider` 拼路径）。

### 6. `usize` 在 Dart 侧是 `BigInt`

FRB 把 `usize`/`u64` 映射为 `BigInt`，调用时要写 `num: BigInt.from(3)`，很难用。

**已把所有公开方法的 `usize` 参数改成 `u32`**（映射为 `int`）。

### 7. opaque 类型的 `pub` 字段会自动生成 getter

`playlists` / `collection_list_id` / `collection_hashes` 曾是 `pub`，
FRB 提示要为它们生成 getter。**已改为私有**，改用显式访问器：

| 字段 | 访问器 |
| --- | --- |
| `playlists` | `cachedPlaylists()` |
| `collection_list_id` | `favoritePlaylistId()` |
| `collection_hashes` | `favoriteHashes()` |

---

## 必需依赖

### 系统

| 依赖 | 用途 | 安装 |
| --- | --- | --- |
| **LLVM** | ffigen 需要 `libclang.dll` | `winget install LLVM.LLVM` |
| Rust toolchain | 编译 crate | — |
| Flutter | — | — |

> ⚠️ LLVM 装完需**重开终端**，或手动把 `C:\Program Files\LLVM\bin` 加进 PATH。

### Dart（`pubspec.yaml`）

`integrate` + `generate` 过程中按提示逐步补齐：

```yaml
dependencies:
  flutter_rust_bridge: 2.13.0
  freezed_annotation: ^3.1.0
  kugou:                    # 指向 rust_builder
    path: rust_builder

dev_dependencies:
  ffigen: ^21.0.0
  freezed: ^4.0.0-dev.3
  build_runner: ^2.15.1
  integration_test:
    sdk: flutter
```

> ⚠️ `flutter_rust_bridge` 的 Dart 包版本必须与 `flutter_rust_bridge_codegen`
> 以及 Rust 侧 `Cargo.toml` 的依赖版本**三者一致**。

---

## 日常开发流程

改了 Rust 代码后：

```bash
cd rust && cargo build && cd ..

# 仅当改了 frb_api.rs / client.rs 的**公开签名**时才需要
flutter_rust_bridge_codegen generate

flutter run
```

只改内部实现（如 `crypto.rs`）**不需要** generate，但要重新编译。

### 在 Cursor / VSCode 终端里 LLVM 不在 PATH 时

```bash
export PATH="/c/Program Files/LLVM/bin:$PATH"   # Git Bash
```

---

## Dart 侧调用

```dart
import 'package:chocolate_music/src/rust/frb_generated.dart';
import 'package:chocolate_music/src/rust/frb_api.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();          // ⚠️ 必须最先调用
  runApp(const MyApp());
}

Future<void> demo() async {
  final dir = await getApplicationDocumentsDirectory();

  final client = await createClient(
    platform: 'lite',
    identityPath: '${dir.path}/kugou_identity.json',
  );

  if (!await client.hasDfid()) {
    await client.registerDevice();
  }

  final songs = await client.getRecommendMusics(num: 10);
  final url = await client.getMusicUrl(hash: songs.first.id, quality: '320');
}
```

### 注意事项

| 项 | 说明 |
| --- | --- |
| `RustLib.init()` | 必须在使用任何 Rust 函数前调用，否则崩 |
| 身份文件路径 | **必须绝对路径**，移动端工作目录不可写 |
| `kugou_identity.json` | 含 dfid/token，已在 `.gitignore` 中 |
| 错误类型 | Rust `Error` → Dart `Error`，`Error_Api` 是上游业务失败变体 |
| 方法名 | Rust snake_case 自动转 Dart camelCase；`&self` 方法变实例方法 |
| `u32` 参数 | 映射为 Dart `int`；若用 `usize` 会是 `BigInt` |
| `i64` 参数 | 映射为 `PlatformInt64`（native 是 `BigInt`，web 是 `int`） |

---

## 完整重建步骤（换机器 / 清理后）

```bash
# 1. 系统依赖
winget install LLVM.LLVM

# 2. 生成器
cargo install flutter_rust_bridge_codegen --locked

# 3. Dart 依赖
flutter pub get

# 4. 生成绑定
flutter_rust_bridge_codegen generate

# 5. 验证
cd rust && cargo test && cd ..
dart analyze lib/src/rust
flutter test integration_test/kugou_test.dart -d windows
```
