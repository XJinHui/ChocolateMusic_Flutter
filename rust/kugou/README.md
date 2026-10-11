# KuGou —— 酷狗音乐 API 的本地 Rust 实现

把 `KuGouMusicApi`（Node.js 服务）搬到本地：**直连酷狗上游**，自己完成参数注入、签名、加解密，不再需要中间服务器。

## 实测验证状态

以下接口已对**真实酷狗上游**跑通（`2026-10-11`）：

| 功能 | 结果 |
| --- | --- |
| 设备注册（`register_dev`） | ✅ 返回真实 `dfid` |
| 每日推荐（`everyday_recommend`） | ✅ 返回 30 首真实歌曲 |
| 推荐歌手（`artist_lists`） | ✅ 返回热门歌手 |
| 推荐歌单（`top_ip`） | ✅ 返回真实歌单 |
| 播放地址（`song_url`） | ✅ 返回带签名的 CDN 地址 |
| 歌词（`search_lyric` + `lyric`） | ✅ 返回真实 LRC |
| 歌手详情/专辑/单曲 | ✅ 全部返回真实数据 |
| 专辑详情/歌曲 | ✅ 全部返回真实数据 |
| 二维码 key（`login_qr_key`） | ✅ 返回 key + 图片 |
| 登录相关 | ⏳ 需凭据，未实测 |

## 快速开始

```bash
# 首次运行会生成 kugou_identity.json（设备身份，务必保留）
cargo run -- register                    # 获取 dfid
# 免登录可用
cargo run -- recommend                   # 每日推荐 + 推荐歌手 + 推荐歌单
cargo run -- url <hash> 320              # 取播放地址
cargo run -- lyric <hash>                # 取歌词
cargo run -- singer <singerId>           # 歌手详情 + 专辑 + 单曲
cargo run -- album <albumId>             # 专辑详情 + 歌曲

# 需要登录
cargo run -- qr                          # 二维码登录
cargo run -- captcha <mobile>            # 发送验证码
cargo run -- login <mobile> <code>       # 验证码登录
cargo run -- playlists                   # 列出歌单
cargo run -- vip                         # 领取每日 VIP
```

环境变量：`KUGOU_PLATFORM=lite|standard`（默认 `standard`；原部署是 `lite`）。

## 在 Flutter 中使用（flutter_rust_bridge）

本 crate 已配置为 **FRB ready**。完整迁移步骤见 **[MOVE_GUIDE.md](./MOVE_GUIDE.md)**。

要点：

```dart
await RustLib.init();                                    // 必须最先调用

final dir = await getApplicationDocumentsDirectory();
final client = createClient(                            // 传绝对路径
  platform: 'lite',
  identityPath: '${dir.path}/kugou_identity.json',
);

if (!client.hasDfid()) await client.registerDevice();    // 首次需要
final songs = await client.getRecommendMusics(num: 10);
final url = await client.getMusicUrl(hash: songs.first.id, quality: '320');
```

为适配 FFI 做的改造：

| 改造 | 原因 |
| --- | --- |
| `crate-type` 加 `cdylib`/`staticlib` | Flutter 各平台需要 |
| 新增 `src/frb_api.rs` 模块 | FRB 只扫描它，隔离内部实现 |
| `KuGouClient` 标 `#[frb(opaque)]` | 含 `reqwest::Client`，只能当不透明句柄 |
| `transport` 字段改私有 + 补访问器 | 同上 |
| `Error` 变体全改 `String`/数字 | 原含 `reqwest::Error`，FRB 无法镜像 |
| `&str` 返回值全改 `String` | FFI 边界不能传引用 |

> ⚠️ **codegen 需要 LLVM**（ffigen 依赖 libclang）。当前机器未安装，见 MOVE_GUIDE 第 0 步。


## Dart → Rust 方法映射

`KuGou.dart` 的每个方法都有对应实现。转换时把 `dio.get(...)` 换成方法调用即可。

| Dart 方法 | Rust 方法 | 说明 |
| --- | --- | --- |
| `getDfid()` | `client.register_device()` | 首次必须调用 |
| `getVerificationCode(mobile, _)` | `client.send_captcha(mobile)` | |
| `getQrCode(_)` | `client.qr_key()` | 返回 `(key, img)` |
| `loginByQrCode(_)` | `client.qr_login_wait(key, 2, 90)` | 内部完成轮询 |
| `loginByMobile(m, _, code)` | `client.login_cellphone(m, code)` | |
| `refreshToken()` | `client.refresh_token()` | |
| `getPlaylist()` | `client.get_playlists()` | 自动把「我喜欢的音乐」提到首位 |
| `getCollectionList()` | `client.get_collection_hashes()` | |
| `getPlaylistMusic(listId)` | `client.get_playlist_music(list_id)` | |
| `getPlaylistDetails(listId)` | `client.get_playlist_detail(list_id)` | |
| `getSingerMusic(singerId)` | `client.get_singer_music(singer_id)` | |
| `getSingerAlbum(singerId)` | `client.get_singer_albums(singer_id)` | |
| `getSingerDetails(singerId)` | `client.get_singer_detail(singer_id)` | |
| `getAlbumMusic(albumId)` | `client.get_album_music(album_id)` | |
| `getAlbumDetails(albumId)` | `client.get_album_detail(album_id)` | |
| `getRecommendMusics(num)` | `client.get_recommend_musics(num)` | |
| `getRecommendSingers(num)` | `client.get_recommend_singers(num)` | |
| `getRecommendPlaylists(num)` | `client.get_recommend_playlists(num)` | |
| `search(keyword)` | `client.search_with_details(keyword)` | 含详情补全 |
| `getMusicUrl(hash, bitrate:)` | `client.get_music_url(hash, quality)` | |
| `chooseMusicQuality(hash, quality:)` | `client.choose_music_quality(hash, idx)` | `0`=128 `1`=320 `2`=flac |
| `getMusicsDetails(ids)` | `client.get_musics_details(&hashes)` | 两步合并（`privilege_lite` + `krm_audio`） |
| `getAlbumAudioId(ids)` | `api::song::krm_audio(&t, ids, fields)` | |
| `getLyric(hash)` | `client.get_lyric(hash)` | 纯文本 LRC |
| `createPlaylist(name)` | `client.create_playlist(name)` | |
| `deletePlaylist(listId)` | `client.delete_playlist(list_id)` | 自动换算数字 `listid` |
| `addMusicToPlaylist(l, m)` | `client.add_music_to_playlist(l, m)` | |
| `deleteMusicFromPlaylist(l, m)` | `client.delete_music_from_playlist(l, m)` | 自动查 `fileid` |
| `getMusicInPlaylistFileid(l, m)` | `api::playlist::find_fileid(&t, l, m)` | |
| `getVip()` | `client.claim_vip_all()` | |
| `getVip8()` | `client.claim_ad_vip()` | 8 次 / 15 秒间隔 |
| `processLyric(lrc)` | `kugou::lyric::process_lyric(lrc)` | |
| `krcToLrc(krc)` | `kugou::lyric::krc_to_lrc(krc)` | |
| `msToLrcTime(ms)` | `kugou::lyric::ms_to_lrc_time(ms)` | |
| `getCover(url, size:)` | `kugou::models::get_cover(url, size)` | |
| `shuffleArray(ids)` | `kugou::client::shuffle(&mut v)` | |

## Dart 侧改造：`raw_request` 透传层

`KuGou.dart` 有 1600+ 行，全是 `KuGou.dio.get('/xxx')` + `response.data[...]` 的解析。
逐方法改写成强类型调用要重写上千行，风险高。

**更好的办法**：原服务器（KuGouMusicApi）其实是个**纯透传** ——

```js
// server.js:420
res.header(moduleResponse.headers).status(moduleResponse.status).send(moduleResponse.body);
```

`moduleResponse.body` 就是酷狗上游的原始 JSON。所以只要 Rust 把同一份原始体
原样吐回来，`KuGou.dart` 的解析代码**一行都不用改**。

```dart
// KuGou.dart 里只改这一处：给 dio 换上 adapter
static Dio _createDio() {
  final dio = Dio(BaseOptions(baseUrl: "https://kugou.xjinhui.asia/"));
  dio.options.validateStatus = (status) => true;
  dio.httpClientAdapter = KuGouRustAdapter();   // ← 新增
  return dio;
}
```

`KuGouRustAdapter`（在 Flutter 项目里，`lib/Cloud/KuGouRustAdapter.dart`）把 dio 的
请求截下来转给 [`KuGouClient::raw_request`]，**不发起任何 HTTP**，返回与原服务器
一致的响应体。

### 与服务器的三处不一致（已补齐）

| 路径 | 服务器的额外处理 |
| --- | --- |
| `/register/dev` | 响应体是二进制，需 AES 解密 |
| `/login/cellphone`、`/login/token` | 把 `secu_params` 解密后合并进 `data` |
| `/lyric?decode=true` | base64 / KRC 解码后挂到 `decodeContent` |

### 凭据语义

与原服务器一致：**`query` 里的 `token` / `userid` / `dfid` 即权威凭据**，
非空时覆盖客户端内部持有的值（服务器也是把它们转成 Cookie 发给上游的）。

### 业务失败不算异常

`status: 0` / `error_code != 0` 这类业务失败，原服务器是用 HTTP 200 返回响应体的。
`raw_request` 同样照常返回响应体，由 `KuGou.dart` 自己判断 `status` ——
否则 `getVip8()` 里 `error_msg == '今天次数已用光'` 这种判断就没法做了。

### 想用强类型接口也可以

`raw_request` 只是兼容层。新代码可以直接用 [`KuGouClient`] 上的强类型方法：

```dart
final url = await client.getMusicUrl(hash: musicId, quality: bitrate);
```

> 完整映射见上面的「Dart → Rust 方法映射」表。

## 架构

```
src/
├── lib.rs          Error / Result 定义，模块导出
├── crypto.rs       MD5 · SHA1 · AES-CBC(128/256) · 裸RSA · RSA PKCS#1v1.5
├── sign.rs         7 个签名函数（Android/Web/Register/signKey/signParamsKey/…）
├── platform.rs     标准版 / 概念版配置（显式值对象，非全局 env）
├── device.rs       设备身份（GUID / MID / DEV / MAC / WEBGL）+ 持久化
├── request.rs      请求层（参数注入 · 签名 · 发送 · 响应归一化）
├── raw.rs          原始响应透传（按原服务器路由分发，供 KuGou.dart 无改动迁移）
├── models.rs       Music · Singer · Album · Playlist · KugouData
├── lyric.rs        LRC 清洗 · KRC 转 LRC
├── client.rs       KuGouClient 门面（与 KuGou.dart 的 KuGou 类对应）
└── api/
    ├── login.rs    设备注册 · 验证码 · 二维码 · 手机登录 · 刷新 token
    ├── user.rs     用户歌单
    ├── song.rs     播放地址 · 歌曲详情 · 歌词
    ├── search.rs   综合搜索
    ├── artist.rs   歌手列表 / 单曲 / 专辑 / 详情
    ├── album.rs    专辑信息 / 歌曲列表
    ├── playlist.rs 歌单全部歌曲 / 详情 / 新建 / 删除 / 加歌 / 删歌
    ├── recommend.rs 每日推荐 · 推荐歌单
    └── user_vip.rs VIP 领取
```

> `api/` 里每个接口都拆成了「构造请求」+「解析响应」两部分
> （`build_xxx()` / `xxx_body()`），typed 版本与 `raw.rs` 的透传版本共用同一份请求构造。

## 关键实现要点

### 1. 设备身份必须持久化

原项目每次启动随机生成 GUID，导致重启即变新设备、`dfid` 失效、风控信誉归零。

本实现把身份写入 `kugou_identity.json`，**首次运行后请保留该文件**。

`mid` 的算法是**两轮 MD5**：

```
uuid v4  →  MD5  →  GUID (32 hex)
GUID     →  MD5  →  十进制大数  →  MID (39 位)
```

### 2. 三种 RSA 用法

| 用途 | 算法 | 特征 |
| --- | --- | --- |
| `pk` 参数 | **裸 RSA（无填充）** | 确定性；明文上限 128 字节 |
| `p` 参数 | RSA PKCS#1 v1.5 | 随机填充；明文上限 117 字节 |
| SID（未实现） | RSA-OAEP-SHA256 | 2048-bit 公钥 |

### 3. 三种 AES 用法

| 函数 | 密钥 | 输出 |
| --- | --- | --- |
| `crypto_aes_encrypt(data, None)` | 随机 16 字符 → `MD5[0..32]` → **AES-256** | hex |
| `playlist_aes_encrypt` | 随机 6 字符 → `MD5[0..16]` → **AES-128** | Base64 |
| `crypto_aes_encrypt(data, Some((k,iv)))` | 给定 ASCII 密钥 | hex |

⚠️ 密钥是 **ASCII 字符串**，不是 hex 解码后的字节。

### 4. 修正的两处原实现问题

**`<!--KG_TAG_RES_START-->` 包裹**：未认证请求的响应被 HTML 注释包裹，原实现会导致 JSON 解析失败并被静默当成「成功但无数据」。本实现先剥离再解析，且解析失败时正确报错。

**`signKey` 的 `||` 语义**：JS 的 `userid || 0` 会把空串变成 `0`，`appid || useAppid` 会把 `0` 变成默认值。不对齐会算出错误的 `key`，上游报 `illegal key`。

## 测试

```bash
cargo test          # 38 个单元测试
```

覆盖：MD5 参考值、AES 往返（128/256/固定密钥）、裸 RSA 确定性、PKCS#1 随机性、
签名拼接顺序、`||` 语义、MID 双重 MD5（用实测值对拍）、LRC/KRC 转换、封面 URL 替换。

## 依赖

| crate | 用途 |
| --- | --- |
| `reqwest` | HTTP 客户端 |
| `tokio` | 异步运行时 |
| `md-5` / `sha1` / `sha2` | 哈希 |
| `aes` + `cbc` | AES-CBC/PKCS7 |
| `rsa` | PKCS#1 v1.5 与 PEM 解析 |
| `num-bigint` | 裸 RSA 与 MID 的大整数运算 |
| `flate2` | KRC 歌词的 zlib 解压 |
| `serde` / `serde_json` | 序列化 |
| `rand` | 随机数 |
