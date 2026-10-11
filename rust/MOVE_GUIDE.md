# flutter_rust_bridge 集成记录（workspace 级）

> 本文记录 **Rust crate 接入 chocolate_music 的实际过程**与踩到的坑。
> 已有两个 crate：`kugou`（酷狗）与 `netease`（网易云），均已完成并验证通过。

## 目录布局

```
chocolate_music/
├── flutter_rust_bridge.yaml      ← FRB 配置（必须在项目根）
├── rust/
│   ├── Cargo.toml                ← workspace 根
│   ├── bridge/                   ← ⚠️ FRB 唯一的 root crate（cdylib）
│   │   ├── Cargo.toml            ← 只声明对各 API crate 的依赖
│   │   └── src/{lib,frb_api,frb_generated}.rs
│   ├── kugou/                    ← 酷狗音乐 API
│   └── netease/                  ← 网易云音乐 API
├── rust_builder/                 ← Flutter 构建插件（构建 rust/bridge）
└── lib/
    ├── Cloud/{KuGou,NetEaseCloud}RustAdapter.dart
    └── src/rust/
        ├── frb_generated.dart    ← 入口 RustLib
        └── third_party/
            ├── kugou/
            └── netease/
```

## 为什么要有 bridge crate

FRB 的 `rust_root` **只能有一个**，且只有「root crate」走 `crate::` 路径；
其余 crate 一律 `cargo expand -p <包名>`，Dart 产物落在 `third_party/<包名>/`。

如果让 kugou 当 root 并依赖 netease，那个依赖就是**只为让 FRB 扫到而存在的假依赖**，
会污染依赖图；而且每加一个 crate 都要挂到 kugou 上。

所以 `bridge` 只做汇总、不含业务逻辑，各 API crate 之间**互不依赖**：

```
bridge (cdylib)
  ├── kugou
  └── netease
```

### 新增一个 API crate

1. `rust/<名字>/` 建 crate，包名用**小写**（FRB 走 `cargo expand -p <包名>`）
2. 加进 `rust/Cargo.toml` 的 `members`
3. 加进 `rust/bridge/Cargo.toml` 的依赖
4. 加进 `flutter_rust_bridge.yaml` 的 `rust_input`
5. `flutter_rust_bridge_codegen generate`

## 当前状态

| 项 | 状态 |
| --- | --- |
| 目录布局 | ✅ Cargo workspace，可容纳多个 Rust crate |
| Rust 编译 | ✅ `cargo build` 通过 |
| Rust 单元测试 | ✅ 40 个全过 |
| FRB 代码生成 | ✅ `Done!` |
| 生成的 Dart | ✅ `dart analyze` 零问题 |
| Flutter 集成 | ✅ `rust_builder/` 已就位 |
| 集成测试 | `integration_test/kugou_test.dart`（10/10）、`netease_test.dart`（9/9） |

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
rust_input: crate::frb_api,kugou::frb_api,kugou::client,netease::frb_api,netease::client
rust_root: rust/bridge/
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

--- | --- |
| `playlists` | `cachedPlaylists()` |
| `collection_list_id` | `favoritePlaylistId()` |
| `collection_hashes` | `favoriteHashes()` |

---

### 7. 两份 `src/` 会分叉（本次踩到）

`D:\XJH\Rust\KuGou`（独立项目）与 `chocolate_music/rust/kugou`（Flutter 里的副本）
**不是简单的复制关系** —— 后者有几处 FRB 专属调整：

| 文件 | Flutter 副本的不同 |
| --- | --- |
| `lib.rs` | 多一行 `mod frb_generated;` |
| `client.rs` | 字段改私有、`usize` → `u32`、删掉 `default_identity_path()` |
| `main.rs` | `client.collection_list_id` → `client.favorite_playlist_id()` |
| — | 多出 `src/frb_generated.rs` |

所以**不能整目录覆盖**。改完独立项目后，按下面同步：

```bash
SRC=/d/XJH/Rust/KuGou
DST=/d/XJH/Flutter/chocolate_music/rust/kugou

# ① 整份复制（这几个文件两边一致）
cp "$SRC/src/api/"*.rs "$DST/src/api/"
cp "$SRC/src/raw.rs" "$SRC/src/request.rs" "$DST/src/"

# ② lib.rs / client.rs 要手工改（两边内容不同）
```

> 反过来改 Flutter 副本时同理 —— 先想清楚改的是哪一边，再决定要不要回灌。

---

### 8. bridge crate 需要被扫 crate 的依赖

生成的 `frb_generated.rs` 会用到被扫 crate 的类型 —— 比如 netease 的
`ServerResponse.body: serde_json::Value`。这些依赖**必须在 root crate 里也有**：

```toml
# rust/bridge/Cargo.toml
serde_json = { version = "1", features = ["preserve_order"] }
flutter_rust_bridge = { version = "=2.13.0", features = ["serde_json"] }
```

⚠️ 还要给 `flutter_rust_bridge` 开 `serde_json` feature，否则 `Value` 没有
`IntoIntoDart` impl。

漏了会报：

```
error[E0433]: cannot find module or crate `serde_json` in this scope
error[E0599]: no method named `into_into_dart` found for enum `Value`
```

### 9. opaque 类型上不能有 pub 字段

`NetEaseClient.transport` 曾是 `pub`，FRB 会提示为它生成 getter ——
但 `Transport` 内含 `reqwest::Client`，转换不了。**改成 `pub(crate)`**。

同理，公开方法**不要返回引用**：

| 签名 | 结果 |
| --- | --- |
| `fn device(&self) -> &DeviceIdentity` | FRB 退化成 unit |
| `fn supported_routes() -> &'static [&'static str]` | FRB 退化成 unit |
| `fn supported_routes() -> Vec<String>` | ✅ |

---

### 10. ⚠️ 概率性「连接被重置」—— 根因是 IPv6

这是本项目**最费劲**的一个坑：症状完全随机，重跑就好，日志里没有任何线索。

#### 症状

```text
DioException [unknown]: AnyhowException(网络错误: error sending request for url
  (https://interface3.music.163.com/xeapi/ad/get))
```

`/ad/get`、二维码登录、手机验证码都会中招，**概率性**出现。

#### 两个叠加的坑

**① Rust 侧把真实错误吃掉了**（诊断盲区）

`Transport::send_raw` 里，`recover_body` 返回 `None` 时统一换成
`Error::Http("请求失败".into())` —— 把 reqwest 的原始错误整个丢了。
所以 Dart 侧看到的永远只是「网络错误: 请求失败」，看不出是 DNS、TLS 还是被 RST。

同时 `Error::Http(e.to_string())` 只取 reqwest 的**顶层**信息。reqwest 的
`Display` 只有一句 `error sending request for url (...)`，真正的原因全在
`source()` 链上。两处都要修：

```rust
// ① 上抛原错误，不要替换
Err(e) => match recover_body(e.clone()) {
    Some((body, status)) => Ok(ApiResponse { status, body, cookies: Vec::new() }),
    None => Err(e),          // ← 曾经是 Err(Error::Http("请求失败".into()))
},

// ② 拼出整条 source 链（见 Error::http）
.map_err(Error::http)?
```

修完后错误信息变成：

```text
网络错误: error sending request for url (https://interface3.music.163.com/xeapi/ad/get)
  ← client error (SendRequest) ← connection error
  ← 远程主机强迫关闭了一个现有的连接。 (os error 10054)
```

`10054` = `WSAECONNRESET`，**连接被对端 RST**。

**② 根因：DNS 返回的 IPv6 排在前面，而本机 IPv6 出口是坏的**

`*.music.163.com` 都发 AAAA 记录，且排在 A 前面：

```text
interface3.music.163.com
  → 240e:938:a07:6:0:4:0:3      ← IPv6 在前
    111.124.200.67
```

hyper-util 默认按 **DNS 返回的第一条**地址决定地址族偏好，于是走 IPv6。
而手机热点这类网络的 IPv6 出口到该 CDN 是坏的：TCP 看着能连上，紧接着被 RST。

#### 怎么定位的

| 步骤 | 结果 |
| --- | --- |
| `cargo run --release --example probe`（交错对照，各 25 次全新连接） | 默认 18/25、**强制 IPv4 25/25** |
| `curl -4` ×15 | 15/15 |
| `curl -6` ×15 | 5/15 |
| 三个域名（interface / interfacepc / interface3）分别测 | 都是约 50%，**不是某一个域名的问题** |
| 先试过 `.http1_only()` | 没用（第一轮 20/20 是运气，样本大了就露馅） |
| 对照部署的 Node 服务器（同路由） | 正常 —— 排除了「实现差异」 |

#### 修法

```rust
// Transport::new —— 见 request.rs 的 http_client()
b = b.local_address(std::net::IpAddr::V4(std::net::Ipv4Addr::UNSPECIFIED));
```

hyper-util 的 `SocketAddrs::split_by_preference`：

```rust
(Some(_), None) => (self.filter(SocketAddr::is_ipv4), SocketAddrs::new(vec![])),
//                 ↑ IPv6 地址被**整个过滤掉**，连 fallback 都不留
```

所以这不是「IPv6 试失败了再回落」，而是**根本不去试**。

`0.0.0.0` 不指定具体网卡，只是用它来声明「只连 IPv4」。

#### 顺带加的：连接阶段重试

`Transport::send_retry` 只在 `e.is_connect()` 时重试（最多 3 次）。
**不重试** `is_request()` / `is_timeout()` —— 那两种情况下服务器可能已经处理了，
而 `/ad/listening/rights/gain`、`/login/*` 都不是幂等的。宁可报错也不能多领一次。

#### 酷狗那边

实测**是好的**（`gateway.kugou.com` / `login-user.kugou.com` 各 IPv4 15/15、
IPv6 15/15；完整链路的 `recommend` 15/15）。但仍然加了同样的 `local_address`
作为防御 —— 两个 crate 跑在同一个 App、同一台设备、同一张网上，
何况 `gateway.kugou.com` 的 CNAME 就叫 **`kgnopipv6.kugou.com`**。

需要走 IPv6 时：`NETEASE_IPV4_ONLY=0` / `KUGOU_IPV4_ONLY=0`。

#### 复现/验证工具

`rust/netease/examples/probe.rs` —— 交错对照「默认 vs 强制 IPv4」，
每个变体都新建客户端（保证是全新连接）：

```bash
cd rust/netease && cargo run --release --example probe
```

---

## Dart 侧接入：dio adapter

`KuGou.dart`（1600+ 行）与 `NetEaseCloud.dart`（1500+ 行）的解析代码**一行都没改** ——
靠的是各 crate 的 `raw` 透传层 + `lib/Cloud/*RustAdapter.dart` 这两个自定义 dio adapter。

| | 酷狗 | 网易云 |
| --- | --- | --- |
| adapter | `KuGouRustAdapter` | `NetEaseCloudRustAdapter` |
| 身份文件 | `kugou_identity.json` | `netease_identity.json`（**分开存**） |
| **凭据位置** | **query 参数**（`token`/`userid`/`dfid`） | **Cookie 头**（`Options(headers: {'Cookie': ...})`） |
| 平台切换 | `platform: 'lite' \| 'standard'` | 无 |

⚠️ **凭据位置是两者最大的差异** —— adapter 必须分别处理：
酷狗从 query 里拿，网易云要从 `options.headers['Cookie']` 里取。

详见 [README.md](README.md) 的「Dart 侧改造：`raw_request` 透传层」。

调用链：

```text
KuGou.dio.get('/login/qr/key?timestamp=1')
  → KuGouRustAdapter.fetch()             ← lib/Cloud/KuGouRustAdapter.dart，进程内
  → KuGouClient.rawRequest(path, query)  ← FFI，进程内
  → Rust 直连酷狗上游                     ← 唯一一次真实网络请求
```

⚠️ `KuGou.dio` 名字里虽然有 dio，但**不发 HTTP** —— 换 adapter 之后所有请求都走 FFI。

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
