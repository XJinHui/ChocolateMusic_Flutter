# 巧克力音乐（Chocolate Music）

一个用 Flutter 写的音乐播放器（PC 端），支持**酷狗音乐**、**网易云音乐**、**Navidrome** 与**本地音乐**四个来源。

## 功能

- **账号**：二维码扫码登录、短信验证码登录，支持多账号并存与切换（账号页可用独立小窗打开）
- **浏览**：每日推荐、推荐歌手 / 歌单、搜索（歌曲 / 专辑 / 歌手）、歌单页、歌手页、专辑页
- **播放**：播放队列（当前播放列表）、上一首 / 下一首 / 随机 / 循环、歌词页与歌词滚动高亮、封面过渡动画
- **歌单**：新建 / 删除歌单、收藏歌曲、加入歌单、从歌单移除
- **下载**：在线歌曲下载到本地，独立下载页管理任务
- **本地音乐**：扫描本地目录，读取音频元数据（封面 / 标题 / 歌手 / 时长）并入库
- **设置**：在线播放音质（标准 / 高品 / 无损）、下载音质、下载目录

## 音乐源

| 来源 | 说明 |
| --- | --- |
| 酷狗音乐 | 登录、歌单、搜索、推荐、播放地址、歌词、VIP 领取 |
| 网易云音乐 | 登录、歌单、搜索、歌手 / 专辑、播放地址、歌词、广告免费听 |
| Navidrome | 自建音乐服务器，走 Subsonic API |
| 本地音乐 | 扫描本地文件，SQLite 建库 |

四个来源都实现同一套 `CloudService` 接口（见 [lib/Cloud/CloudService.dart](lib/Cloud/CloudService.dart)），上层页面不关心数据来自哪里。

## 架构

```
lib/
├── main.dart              入口：初始化 media_kit / sqflite FFI / RustLib，分发主窗口与子窗口
├── Management.dart        全局状态（ChangeNotifier 单例），持有各管理器
├── Cloud/                 各音乐源实现
│   ├── CloudService.dart      统一接口
│   ├── KuGou.dart             酷狗
│   ├── NetEaseCloud.dart      网易云
│   ├── Navidrome.dart         Navidrome
│   └── *RustAdapter.dart      把 dio 请求截流转给本地 Rust
├── pages/computer/        页面（推荐 / 搜索 / 歌单 / 歌词 / 下载 / 设置 / 账号等）
├── components/            公共组件（播放控制条、播放列表、登录弹窗、歌词过渡等）
├── MusicManagement.dart   本地音乐库（sqflite + 元数据解析）
├── PlayMusicControl.dart  播放控制
└── src/rust/              flutter_rust_bridge 生成的 Dart 绑定

rust/                     Rust workspace
├── bridge/               FRB 唯一的 root crate（cdylib），只做汇总
├── kugou/                酷狗 API 的本地 Rust 实现
└── netease/              网易云 API 的本地 Rust 实现
```

### 为什么有 Rust

酷狗和网易云的接口原先依赖两台自建 Node.js 服务器（见下方「致谢」）。现在把客户端实际用到的路由搬进了本地 Rust crate：**直连上游**，参数组装、签名与加解密都在进程内完成，不再需要中间服务器。

对上层是透明的：`KuGou.dart` / `NetEaseCloud.dart` 里依旧是 `dio.get('/xxx')` 加解析代码，只是给 `Dio` 换上了 `KuGouRustAdapter` / `NetEaseCloudRustAdapter`，把请求转给 Rust 并返回与原服务器**格式一致**的响应体。

两个 crate 各自的实现细节（加密方案、与 Node 实现的差异、已知问题）写在 [rust/kugou/README.md](rust/kugou/README.md) 与 [rust/netease/README.md](rust/netease/README.md)，FRB 的接入过程见 [rust/MOVE_GUIDE.md](rust/MOVE_GUIDE.md)。

## 环境要求

- Flutter（Dart SDK `^3.12.1`，见 [pubspec.yaml](pubspec.yaml)）
- Rust 工具链（构建 `rust/` 下的 crate 时需要）
- 仅当要重新生成 FFI 绑定时才需要 LLVM / libclang（`ffigen` 依赖）

## 运行

```bash
flutter pub get
```

```bash
flutter run -d windows
```

修改了 Rust 侧 `frb_api.rs` 或 `client.rs` 的公开签名后，需要重新生成绑定：

```bash
flutter_rust_bridge_codegen generate
```

跑 Rust 侧的测试：

```bash
cd rust && cargo test
```

## 致谢 / 参考

本项目的接口实现参考了以下开源项目，在此致谢：

- [NeteaseCloudMusicApiEnhanced/api-enhanced](https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced) —— 网易云音乐 API 的 Node.js 实现，`rust/netease` 的加密方案、路由与响应格式均以其为参照
- [XJinHui/KuGouMusicApi](https://github.com/XJinHui/KuGouMusicApi) —— 酷狗音乐 API 的 Node.js 实现，`rust/kugou` 的签名与参数注入以其为参照

同时感谢 [media_kit](https://github.com/media-kit/media-kit)（播放内核）、[flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge)（Rust ↔ Dart 绑定）等开源项目。

## 免责声明

本项目仅供学习与研究使用，所有音乐数据与版权归各平台所有。请勿用于商业用途，请支持正版音乐。
