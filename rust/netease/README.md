# NetEaseCloud —— 网易云音乐 API 的本地 Rust 实现

把 [api-enhanced](https://github.com/neteasecloudmusicapienhanced/api)（Node.js 服务）里
`chocolate_music` 客户端实际用到的 **29 条路由**搬到本地：**直连网易云上游**，
自己完成参数组装、`weapi`/`eapi`/`xeapi` 加密与 Cookie 管理，不再需要中间服务器。

> 分析文档见 `api-enhanced/docs/rewrite/`，本文的实现依据是其中的
> [`10-client-subset.md`](../../Music/api-enhanced/docs/rewrite/10-client-subset.md)。

## 实测验证状态

以下已对**真实网易云 API** 跑通（`2026-10-11`）：

| 路由 | 结果 |
| --- | --- |
| `/login/qr/key` | ✅ 返回真实 unikey |
| `/login/qr/create` | ✅ 本地生成 PNG（不发网络请求） |
| `/song/detail` | ✅ Beyond - 海阔天空 |
| `/song/url` | ✅ 返回带签名的 CDN 地址 |
| `/lyric` | ✅ 返回真实 LRC |
| `/search` | ✅ 返回真实结果 |
| `/album` | ✅ 返回专辑与歌曲 |
| `/artist/detail` | ✅ 返回 Beyond |
| `/user/account`、`/vip/info` 等 | ✅ 未登录时正确返回 301 / 200+null |
| `/ad/get`（xeapi） | ✅ 返回真实广告 + `extra.reqId` |
| `/ad/listening/rights`（xeapi） | ✅ 返回剩余免费时长 |
| `/ad/listening/rights/gain`（xeapi） | ✅ 实际领取成功（`gainFlag: true`） |
| `/register/anonimous`（xeapi） | ✅ 返回 200（**上游时好时坏**，见下） |

跑一遍：

```bash
cargo test --lib                                    # 60 个单元测试
cargo test --test smoke -- --ignored --nocapture    # 协议层对真实 API
cargo test --test raw_smoke -- --ignored --nocapture # 透传层对真实 API
```

## 快速开始

```bash
# 看设备身份与路由清单
cargo run -- info

# 任意路由直通
cargo run -- raw /song/detail ids=347230
cargo run -- raw /song/url id=347230 level=exhigh
cargo run -- raw /search keywords=海阔天空 type=1 limit=3

# 二维码登录
cargo run -- qr
```

需要登录的接口先设 `NETEASE_COOKIE` 环境变量（登录后拿到的 Cookie 串）。

```rust
use netease::NetEaseClient;

# async fn demo() -> Result<(), netease::Error> {
let client = NetEaseClient::with_identity_file("netease_identity.json");

// 强类型调用
let url = client.song_url_str("", "347230").await?;

// 或按原服务器路由直通（供 Dart 侧无改动迁移）
let mut q = std::collections::HashMap::new();
q.insert("ids".to_string(), "347230".to_string());
let json = client.raw_request("/song/detail".into(), q, String::new()).await?;
# Ok(()) }
```

## 架构

```
src/
├── lib.rs          Error / Result / Crypto 枚举
├── crypto.rs       加密原语：MD5 · AES-CBC · AES-ECB · 无填充 RSA · HMAC
├── protocol.rs     weapi · eapi（两种加密方案）
├── xeapi.rs        xeapi：X25519 + 非标准 HKDF + AES-GCM + 公钥获取
├── device.rs       设备身份（**持久化**）
├── cookie.rs       cookieToJson/cookieObjToString · processCookieObject · eapi 的 13 键 Cookie
├── request.rs      请求层：Header/Cookie 组装 · 发送 · 状态映射 · Set-Cookie
├── anticheat.rs    易盾 checkToken v3
├── client.rs       NetEaseClient 门面
├── raw.rs          路由透传分发（29 条客户端路由 + 1 条启动流程）
└── api/
    ├── login.rs     登录与会话（9 条）
    ├── playlist.rs  歌单（6 条）
    ├── song.rs      音乐（3 条）
    ├── search.rs    搜索（1 条）
    ├── artist.rs    歌手（3 条）
    ├── album.rs     专辑（1 条）
    ├── recommend.rs 发现（3 条）
    └── ad.rs        广告免费听（3 条，全部 xeapi）
```

## 三种加密方案

| 方案 | 路由数 | 上游域名 | 请求体 |
| --- | :-: | --- | --- |
| `weapi` | 14 | `music.163.com/weapi/{uri[5:]}` | `params=&encSecKey=` |
| `eapi` | 11 | `interfacepc.music.163.com/eapi/{uri[5:]}` | `params=` |
| `xeapi` | 4 | `interface3.music.163.com/xeapi/{uri[5:]}` | `B=&S=&R=` |

### weapi

```
1. text   = JSON.stringify(data)
2. inner  = AES-128-CBC(presetKey, iv, Pkcs7).encrypt(text)   → Base64
3. outer  = AES-128-CBC(secretKey, iv, Pkcs7).encrypt(inner)  → Base64
4. encSecKey = RSA_NONE(reverse(secretKey))                   → 小写 hex
```

⚠️ 第 3 步的明文是第 2 步的 **Base64 字符串**（ASCII 文本），不是二进制。
⚠️ `secretKey` **反转后**才做 RSA。

### eapi

```
1. text   = JSON.stringify(data)                       // data.header 已塞入
2. digest = md5("nobody" + uri + "use" + text + "md5forencrypt")   → 小写 hex
3. plain  = uri + "-36cd479b6b5-" + text + "-36cd479b6b5-" + digest
4. params = AES-128-ECB(eapiKey, Pkcs7).encrypt(plain)             → 大写 hex
```

⚠️ `digest` 小写、`params` **大写** —— 两者编码不一致，别统一。
⚠️ eapi 的 Cookie 是**独立的 13 键表**，与 `weapi` 的完整表完全不同，
且该表**同时进 Cookie 和请求体**（`data.header`）。

### xeapi

```text
B = AES-256-ECB(dynamicKey, midTransform(AES-256-ECB(staticKey, plaintext)))
S = X25519-ECDH + 非标准 HKDF + AES-128-GCM
R = AES-256-ECB(staticKey, "{version}|{sessionId}")
```

明文是一个 JSON 字符串：

```json
{"body":"<base64 of urlencoded body>","queryString":"e_r=true"}
```

⚠️ **字段顺序随 uri 是否带 query 而变**：uri **没有** query 时 `queryString` 是
**最后**插入的（`body` 在前）；**有** query 时它先插入（`queryString` 在前）。
这个顺序会影响 AES 的输入字节 —— 实测搞反会让 `/register/anonimous` 报 400。

⚠️ 响应也是加密的，用 **`eapiKey`（AES-128）** 解，**不是** `xeapiStaticKey`。

⚠️ 不使用会话密钥轮换：每次都用随机 `dynamicKey`、`R` 的第二段留空。
代价是每次多一次 ECDH（约 0.1ms），换来的是**无跨账号状态污染**
（原实现把 `xeapiSessionId/Key` 放在进程级全局，多账号并发会串 —— 其缺陷 #6）。

## ⚠️ 与 Node 实现的差异

### 有意的偏离

| # | 项 | Node 实现 | 本实现 | 理由 |
| :-: | --- | --- | --- | --- |
| 1 | 设备身份 | 每次启动随机 | **持久化到身份文件** | 原行为是最明显的风控特征 |
| 2 | NMTID | 探测 3 次后永久伪造 | 直接伪造 | 原机制本身有缺陷（计数只减不增） |
| 3 | xeapi 会话 | 进程级全局，多账号会串 | 不使用 | 无跨账号污染 |
| 4 | `cookieToJson` | `=` 必须恰好 1 个，含 `=` 的整条丢弃 | 用 `indexOf('=')` | 修正其缺陷 #13 |
| 5 | 代理 / 随机 IP / 响应缓存 / `e_r` 加密 | 支持 | **不实现** | 客户端不需要 |
| 6 | xeapi 会话密钥 | 进程级全局，会串 | **不使用**（每次随机 key） | 无跨账号污染 |
| 7 | 匿名注册的 deviceId | 每次重新生成 | 复用持久化的身份 | 原行为是最明显的风控特征 |

### 刻意保留的「怪癖」

这些是**能跑通的现状**，改掉会与客户端预期不符，所以原样保留：

| 位置 | 行为 |
| --- | --- |
| `/song/url` | **完全忽略** `level` 与 `unblock`，只读 `br` → 音质不可控、解灰从未生效 |
| `/playlist/tracks` | 成功路径返回 `{status, body:{status, body, cookie}}` **三层嵌套**，客户端正是靠这个嵌套做判断 |
| `/login/cellphone` | `avatarImgId_str` → `avatarImgIdStr` 是**全局文本替换**（键名和值都会命中） |
| `/playlist/delete` | 上游是 `/api/playlist/remove`，不是 `/api/playlist/delete` |
| `/artist/album`、`/album` | `id` 在 **URL 路径**里，不在 body |
| `osMap` 查找 | 用 key `iphone`，但 `os` 字段的值是 `iPhone OS` —— 传值会查不到并回退 `pc` |

## 状态映射（必须逐字复刻）

```
SPECIAL_STATUS_CODES = {201, 302, 400, 502, 800, 801, 802, 803}

status = Number(body.code)
if body.code in SPECIAL: status = 200
if not (100 < status < 600): status = 400
```

⚠️ `code: 301`（需要登录）**不在**表里 → 失败。
⚠️ 二维码轮询的 `800`/`801`/`802`/`803` 会被映射成 HTTP 200，但 **body 里的 `code` 不变** ——
客户端读的正是 body 里的值。

## 实测踩到的两个坑

这两处**分析文档 `docs/rewrite/02-crypto-and-signing.md` 写错了**，
都以真实上游为准修正：

### 1. `xeapiSignKey` 是**字符串**，不是 base64

```js
const xeapiSignKey = 'mUHCwVNWJbunMqAHf5MImuirT6plvs6VSFW62MGHstFQxhBGdEoIhLItH3djc4+FB/OKty3+lL2rGeoFBpVe5g=='
crypto.createHmac('sha256', xeapiSignKey)     // 字符串 → UTF-8 字节（88 字节）
```

它**看起来**像 Base64、也解得出来（64 字节），但 Node 的 `createHmac` 收到字符串时
按 UTF-8 处理。实测：

```text
当字符串(UTF-8) → data.code = 200  success
当 base64 解码   → data.code = 403  Invalid signature
```

⚠️ 别混淆：`xeapiStaticKey` 是 `Buffer.from(hex,'hex')`（真的是字节）。

### 2. xeapi 的 AES **带 PKCS7 填充**，不是「无填充」

文档说 `crypto.createCipheriv('aes-256-ecb', key, null)` 不带填充 ——
但 Node 的 `createCipheriv` **默认 `autopadding: true`**，也就是 PKCS7。

所以文档里那两条「明文长度必须是 16 的倍数，否则抛异常」的警告**根本不存在**：
`B`、`R`、以及公钥解密的明文长度都不受约束。

## 已知问题

| 项 | 说明 |
| --- | --- |
| `/register/anonimous` 时好时坏 | 2026-10-11 实测中途返回过 `{"code":400}` —— **原 Node 服务也一样**（`curl http://127.0.0.1:3999/register/anonimous` → `{"code":400}`），随后又恢复 200。上游侧问题，非实现缺陷 |
| 取 xeapi 公钥必须带 `deviceId` | 传空字符串时响应**不含 `sk`**，会报 "missing sk"。传真实 deviceId 才有 |

`X-antiCheatToken` 的获取（[`anticheat`]）与放置位置（weapi/xeapi 在 Header、
eapi 在 Cookie 里）均已按 crypto 分流实现。

## 免责声明

仅供学习研究使用。请尊重版权，支持正版。
