//! `KuGouClient` —— 与 `KuGou.dart` 的 `KuGou` 类一一对应的门面
//!
//! Dart 侧每个 `dio.get(...)` 在这里都是一个方法。持有登录态、设备身份与本地缓存。

use crate::api::{self, login::QrStatus};
use crate::device::DeviceIdentity;
use crate::models::{Album, Music, Playlist, SearchResult, Singer};
use crate::platform::Platform;
use crate::request::{Account, Transport};
use crate::{Error, Result};
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::path::{Path, PathBuf};

pub use crate::api::login::LoginResult;

/// 酷狗客户端
///
/// `#[frb(opaque)]`：对 flutter_rust_bridge 而言这是个**不透明句柄**，
/// Dart 侧拿到的是 `RustOpaque<KuGouClient>`，只能通过方法交互（不镜像字段）。
/// 这样 `reqwest::Client` 之类的字段就不会进入 FFI 转换。
///
/// ```no_run
/// # async fn run() -> Result<(), kugou::Error> {
/// use kugou::{KuGouClient, Platform};
///
/// let mut client = KuGouClient::new(Platform::Lite);
/// client.register_device().await?;                       // 首次必须
/// let url = client.get_music_url("hash", "320").await?;  // 取播放地址
/// # Ok(()) }
/// ```
#[frb(opaque)]
pub struct KuGouClient {
    /// 请求层：持有 HTTP 客户端、设备身份与账号凭据
    ///
    /// ⚠️ 故意**不是** `pub` —— 它内含 `reqwest::Client`，FFI 层（flutter_rust_bridge）
    /// 无法转换。对外请用下面的访问器方法。
    transport: Transport,

    /// 本地歌单缓存（对外用 [`Self::cached_playlists`]）
    playlists: Vec<Playlist>,
    /// 收藏歌单的 `global_collection_id`（对外用 [`Self::favorite_playlist_id`]）
    collection_list_id: String,
    /// 收藏歌单的歌曲 hash 缓存（对外用 [`Self::favorite_hashes`]）
    collection_hashes: Vec<String>,

    /// 身份文件路径（`None` 表示不持久化）
    identity_path: Option<PathBuf>,
}

/// 可持久化的会话快照
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Session {
    pub device: DeviceIdentity,
    pub account: Account,
    #[serde(default)]
    pub platform: String,
}

impl KuGouClient {
    // ========================================================
    //  构造
    // ========================================================

    /// 创建客户端（不读写磁盘）
    pub fn new(platform: Platform) -> Self {
        let device = DeviceIdentity::generate();
        Self::with_parts(platform, device, Account::default(), None)
    }

    /// 从身份文件加载；文件不存在则生成并写入
    pub fn with_identity_file(platform: Platform, path: impl AsRef<Path>) -> Self {
        let path = path.as_ref();
        let session = Self::load_session(path).unwrap_or_default();

        let device = if session.device.guid.is_empty() {
            DeviceIdentity::generate()
        } else {
            session.device
        };

        let c = Self::with_parts(platform, device, session.account, Some(path.to_path_buf()));
        let _ = c.save_session();
        c
    }

    fn with_parts(
        platform: Platform,
        device: DeviceIdentity,
        account: Account,
        identity_path: Option<PathBuf>,
    ) -> Self {
        Self {
            transport: Transport::new(platform, device, account),
            playlists: Vec::new(),
            collection_list_id: String::new(),
            collection_hashes: Vec::new(),
            identity_path,
        }
    }

    /// 读取会话文件
    fn load_session(path: &Path) -> Option<Session> {
        let text = std::fs::read_to_string(path).ok()?;
        serde_json::from_str(&text).ok()
    }

    /// 写入会话文件
    pub fn save_session(&self) -> Result<()> {
        let Some(path) = &self.identity_path else {
            return Ok(());
        };
        let s = Session {
            device: self.transport.device.clone(),
            account: self.transport.account.clone(),
            platform: match self.transport.platform {
                Platform::Standard => "standard".into(),
                Platform::Lite => "lite".into(),
            },
        };
        if let Some(dir) = path.parent() {
            if !dir.as_os_str().is_empty() {
                std::fs::create_dir_all(dir)?;
            }
        }
        std::fs::write(path, serde_json::to_string_pretty(&s)?)?;
        Ok(())
    }

    // ========================================================
    //  状态访问
    // ========================================================

    pub fn platform(&self) -> Platform {
        self.transport.platform
    }

    pub fn token(&self) -> String {
        self.transport.account.token.clone()
    }

    pub fn userid(&self) -> String {
        self.transport.account.userid.clone()
    }

    pub fn dfid(&self) -> String {
        self.transport.dfid()
    }

    pub fn is_logged_in(&self) -> bool {
        self.transport.account.is_logged_in()
    }

    // ---- 设备身份访问器（供 FFI / 展示用）----
    //
    // 均返回 owned String：FFI 边界不能传引用。

    /// 设备 MID（39 位十进制）
    pub fn device_mid(&self) -> String {
        self.transport.device.mid.clone()
    }

    /// 设备 GUID（32 位 hex）
    pub fn device_guid(&self) -> String {
        self.transport.device.guid.clone()
    }

    /// 开发设备标识（10 位大写）
    pub fn device_dev(&self) -> String {
        self.transport.device.dev.clone()
    }

    /// WebGL 指纹
    pub fn device_webgl(&self) -> String {
        self.transport.device.webgl.clone()
    }

    /// 设备指纹 ID（未注册时为 `None`）
    pub fn device_dfid(&self) -> Option<String> {
        self.transport.device.dfid.clone()
    }

    /// 是否已注册设备
    pub fn has_dfid(&self) -> bool {
        self.device_dfid().map(|s| !s.is_empty()).unwrap_or(false)
    }

    // ---- 本地缓存访问器 ----
    //
    // `KuGouClient` 是 opaque 类型，Dart 侧读不到字段，因此提供这些方法。

    /// 缓存的歌单列表（由 [`Self::get_playlists`] 填充）
    pub fn cached_playlists(&self) -> Vec<Playlist> {
        self.playlists.clone()
    }

    /// 收藏歌单（「我喜欢的音乐」）的 `global_collection_id`
    pub fn favorite_playlist_id(&self) -> String {
        self.collection_list_id.clone()
    }

    /// 收藏歌单的歌曲 hash 缓存
    pub fn favorite_hashes(&self) -> Vec<String> {
        self.collection_hashes.clone()
    }

    /// 设置登录凭据
    pub fn set_login(&mut self, token: &str, userid: &str) {
        self.transport.account.token = token.to_string();
        self.transport.account.userid = userid.to_string();
    }

    /// 应用一次登录结果
    ///
    /// ⚠️ 只在字段**非空**时覆盖 —— 登录失败的响应体里 `data` 可能是个空对象，
    /// 无条件覆盖会把已有的 token 清掉。
    pub fn apply_login(&mut self, r: &LoginResult) {
        if !r.token.is_empty() {
            self.transport.account.token = r.token.clone();
        }
        if !r.userid.is_empty() {
            self.transport.account.userid = r.userid.clone();
        }
        if r.vip_type != 0 {
            self.transport.account.vip_type = r.vip_type;
        }
        if !r.vip_token.is_empty() {
            self.transport.account.vip_token = r.vip_token.clone();
        }
        if !r.t1.is_empty() {
            self.transport.account.t1 = r.t1.clone();
        }
    }

    // ========================================================
    //  原始响应透传
    // ========================================================

    /// 按原服务器的路由发一次请求，返回**酷狗上游的原始响应体**（JSON 文本）
    ///
    /// `path` 是原服务器的路由（如 `/song/url`），`query` 是原样的查询参数。
    /// 返回值与自建服务器返回的**完全一致**，因此 `KuGou.dart` 只需把
    /// `KuGou.dio.get(...)` 换成 FFI 调用，解析代码一行都不用改。
    ///
    /// ```no_run
    /// # async fn run() -> Result<(), kugou::Error> {
    /// # let mut client = kugou::KuGouClient::new(kugou::Platform::Lite);
    /// let mut q = std::collections::HashMap::new();
    /// q.insert("hash".to_string(), "abc".to_string());
    /// q.insert("quality".to_string(), "320".to_string());
    /// let json = client.raw_request("/song/url".into(), q).await?;
    /// # Ok(()) }
    /// ```
    ///
    /// ## ⚠️ 凭据来源
    ///
    /// 与原服务器一致：**`query` 里的 `token` / `userid` / `dfid` 即权威凭据**，
    /// 非空时会覆盖客户端内部持有的值。原服务器也是把 query 里的这三个值
    /// 转成 Cookie 发给上游的。
    ///
    /// ## 副作用
    ///
    /// `/register/dev` 拿到的 `dfid`、登录接口拿到的 `token`/`userid`
    /// 会自动写回客户端并持久化到身份文件。
    pub async fn raw_request(
        &mut self,
        path: String,
        query: std::collections::HashMap<String, String>,
    ) -> Result<String> {
        // ① query 里的凭据覆盖本地状态（保持「query 即凭据」语义）
        if let Some(v) = query.get("token").filter(|s| !s.is_empty()) {
            self.transport.account.token = v.clone();
        }
        if let Some(v) = query.get("userid").filter(|s| !s.is_empty()) {
            self.transport.account.userid = v.clone();
        }
        if let Some(v) = query.get("dfid").filter(|s| !s.is_empty()) {
            self.transport.device.dfid = Some(v.clone());
        }

        // ② 分发
        let out = crate::raw::dispatch(&self.transport, &path, &query).await?;

        // ③ 回写副作用并持久化
        let mut dirty = false;

        if let Some(dfid) = out.dfid {
            if self.transport.device.dfid.as_deref() != Some(dfid.as_str()) {
                self.transport.device.dfid = Some(dfid);
                dirty = true;
            }
        }
        if let Some(login) = out.login {
            self.apply_login(&login);
            dirty = true;
        }
        if dirty {
            let _ = self.save_session();
        }

        Ok(out.body.to_string())
    }

    // ========================================================
    //  设备与登录
    // ========================================================

    /// 获取 `dfid`（对应 `getDfid()`）
    ///
    /// ⚠️ 使用取 URL 等接口前**必须先调用**，否则会提示「本次请求需要验证」。
    /// 成功后写入设备身份并持久化。
    pub async fn register_device(&mut self) -> Result<String> {
        let dfid = api::login::register_dev(&self.transport).await?;
        self.transport.device.dfid = Some(dfid.clone());
        let _ = self.save_session();
        Ok(dfid)
    }

    /// 生成二维码 key（对应 `getQrCode()` 的第一步）
    ///
    /// 返回 `(key, qrcode_img)`。
    pub async fn qr_key(&self) -> Result<(String, String)> {
        api::login::qr_key(&self.transport).await
    }

    /// 检测扫码状态（对应 `loginByQrCode()` 循环体）
    pub async fn qr_check(&self, key: &str) -> Result<QrStatus> {
        api::login::qr_check(&self.transport, key).await
    }

    /// 轮询直到登录成功或二维码过期
    ///
    /// 对应 Dart 的 `loginByQrCode()` 整个循环。
    /// `interval_secs` 默认 2 秒；`max_attempts` 默认 90 次（约 3 分钟）。
    pub async fn qr_login_wait(
        &mut self,
        key: &str,
        interval_secs: u64,
        max_attempts: u32,
    ) -> Result<LoginResult> {
        let interval = if interval_secs == 0 { 2 } else { interval_secs };
        let max = if max_attempts == 0 { 90 } else { max_attempts };

        for _ in 0..max {
            match self.qr_check(key).await? {
                QrStatus::Success {
                    token,
                    userid,
                    nickname,
                    pic,
                } => {
                    self.set_login(&token, &userid);
                    // 补全 t_expire_time 等信息
                    let full = self.refresh_token().await.unwrap_or(LoginResult {
                        token,
                        userid,
                        nickname,
                        pic,
                        ..Default::default()
                    });
                    let _ = self.save_session();
                    return Ok(full);
                }
                QrStatus::Expired => {
                    return Err(Error::Invalid("二维码已过期".into()));
                }
                _ => {
                    tokio::time::sleep(std::time::Duration::from_secs(interval)).await;
                }
            }
        }
        Err(Error::Invalid("二维码登录超时".into()))
    }

    /// 发送手机验证码（对应 `getVerificationCode(mobile, _)`）
    pub async fn send_captcha(&self, mobile: &str) -> Result<()> {
        api::login::captcha_sent(&self.transport, mobile).await
    }

    /// 手机验证码登录（对应 `loginByMobile(mobile, _, code)`）
    pub async fn login_cellphone(&mut self, mobile: &str, code: &str) -> Result<LoginResult> {
        let r = api::login::login_cellphone(&self.transport, mobile, code).await?;
        self.apply_login(&r);
        // 补 dfid
        if self.transport.device.dfid.is_none() {
            let _ = self.register_device().await;
        }
        let _ = self.save_session();
        Ok(r)
    }

    /// 刷新 token（对应 `refreshToken()`）
    pub async fn refresh_token(&mut self) -> Result<LoginResult> {
        let r = api::login::login_token(&self.transport).await?;
        self.apply_login(&r);
        let _ = self.save_session();
        Ok(r)
    }

    /// token 是否临近过期（默认阈值 1 天）
    pub fn token_needs_refresh(&self, expire_time: i64, threshold_secs: i64) -> bool {
        let threshold = if threshold_secs == 0 { 86_400 } else { threshold_secs };
        expire_time - crate::request::now_secs() < threshold
    }

    // ========================================================
    //  歌单
    // ========================================================

    /// 获取歌单列表（对应 `getPlaylist()`）
    ///
    /// 结果同时写入 `self.playlists`。
    /// 「我喜欢的音乐」会被移到首位（对应 Dart 里的交换逻辑，但做了越界保护）。
    pub async fn get_playlists(&mut self) -> Result<Vec<Playlist>> {
        let mut list = api::user::user_playlist(&self.transport, 1, 30).await?;

        // 把「我喜欢的音乐」提到首位
        if let Some(pos) = list.iter().position(|p| p.name.starts_with("我喜欢")) {
            let fav = list.remove(pos);
            list.insert(0, fav);
        }

        self.collection_list_id = api::user::find_favorite_playlist(&list)
            .map(|p| p.list_id.clone())
            .unwrap_or_default();
        self.playlists = list.clone();
        Ok(list)
    }

    /// 拉取收藏歌单的全部 hash（对应 `getCollectionList()`）
    pub async fn get_collection_hashes(&mut self) -> Result<Vec<String>> {
        if self.collection_list_id.is_empty() {
            self.get_playlists().await?;
        }
        if self.collection_list_id.is_empty() {
            return Ok(Vec::new());
        }

        let tracks =
            api::playlist::playlist_track_all_full(&self.transport, &self.collection_list_id)
                .await?;

        let mut seen = std::collections::HashSet::new();
        self.collection_hashes = tracks
            .into_iter()
            .filter(|t| !t.hash.is_empty() && seen.insert(t.hash.clone()))
            .map(|t| t.hash)
            .collect();

        Ok(self.collection_hashes.clone())
    }

    /// 获取歌单内歌曲（对应 `getPlaylistMusic(listId)`）
    ///
    /// `list_id` 是 `global_collection_id`。
    pub async fn get_playlist_music(&self, list_id: &str) -> Result<Vec<Music>> {
        let tracks = api::playlist::playlist_track_all_full(&self.transport, list_id).await?;
        let hashes: Vec<String> = {
            let mut seen = std::collections::HashSet::new();
            tracks
                .into_iter()
                .filter(|t| !t.hash.is_empty() && seen.insert(t.hash.clone()))
                .map(|t| t.hash)
                .collect()
        };
        self.get_musics_details(&hashes).await
    }

    /// 歌单详情（对应 `getPlaylistDetails(listId)`）
    pub async fn get_playlist_detail(&self, list_id: &str) -> Result<Playlist> {
        let v = api::playlist::playlist_detail(&self.transport, &[list_id.to_string()]).await?;
        v.into_iter()
            .next()
            .ok_or_else(|| Error::Invalid("歌单不存在".into()))
    }

    /// 新建歌单（对应 `createPlaylist(name)`）
    pub async fn create_playlist(&mut self, name: &str) -> Result<Playlist> {
        let (gid, listid) = api::playlist::playlist_add(&self.transport, name, 0).await?;
        let p = Playlist {
            name: name.to_string(),
            list_id: gid,
            numeric_id: listid,
            ..Default::default()
        };
        self.playlists.push(p.clone());
        Ok(p)
    }

    /// 删除歌单（对应 `deletePlaylist(listId)`）
    ///
    /// `list_id` 是 `global_collection_id`，内部自动换成数字 `listid`。
    ///
    /// ⚠️ 收藏歌单不可删除。
    pub async fn delete_playlist(&mut self, list_id: &str) -> Result<()> {
        if list_id == self.collection_list_id {
            return Err(Error::Invalid("无法删除收藏歌单".into()));
        }

        let numeric = self.resolve_numeric_id(list_id).await?;
        api::playlist::playlist_del(&self.transport, &numeric).await?;

        self.playlists.retain(|p| p.list_id != list_id);
        Ok(())
    }

    /// 添加歌曲到歌单（对应 `addMusicToPlaylist(listId, musicId)`）
    ///
    /// 内部先查歌曲详情拿到歌名与专辑 ID（与 Dart 行为一致）。
    pub async fn add_music_to_playlist(&mut self, list_id: &str, hash: &str) -> Result<()> {
        let musics = self.get_musics_details(&[hash.to_string()]).await?;
        let m = musics
            .first()
            .ok_or_else(|| Error::Invalid(format!("获取歌曲详情失败: {hash}")))?;

        let numeric = self.resolve_numeric_id(list_id).await?;

        // ⚠️ 歌名不能含逗号（服务端按 , 分割）
        let safe_name = m.name.replace(',', " ");
        api::playlist::add_music_by_hash(
            &self.transport,
            &numeric,
            &safe_name,
            &m.id,
            &m.album_id,
            "",
        )
        .await?;

        if list_id == self.collection_list_id && !self.collection_hashes.contains(&hash.to_string())
        {
            self.collection_hashes.push(hash.to_string());
        }
        if let Some(p) = self.playlists.iter_mut().find(|p| p.list_id == list_id) {
            p.audio_count += 1;
        }
        Ok(())
    }

    /// 从歌单删除歌曲（对应 `deleteMusicFromPlaylist(listId, musicId)`）
    ///
    /// ⚠️ 内部会**翻完整个歌单**找 `fileid`，大歌单较慢。
    pub async fn delete_music_from_playlist(
        &mut self,
        list_id: &str,
        hash: &str,
    ) -> Result<()> {
        let Some(fileid) = api::playlist::find_fileid(&self.transport, list_id, hash).await? else {
            return Err(Error::Invalid(format!("歌单中未找到该歌曲: {hash}")));
        };

        let numeric = self.resolve_numeric_id(list_id).await?;
        api::playlist::playlist_tracks_del(&self.transport, &numeric, &fileid).await?;

        if list_id == self.collection_list_id {
            self.collection_hashes.retain(|h| h != hash);
        }
        if let Some(p) = self.playlists.iter_mut().find(|p| p.list_id == list_id) {
            p.audio_count = (p.audio_count - 1).max(0);
        }
        Ok(())
    }

    /// `global_collection_id` → 数字 `listid`
    ///
    /// 优先用本地缓存，未命中则查一次歌单详情。
    async fn resolve_numeric_id(&self, list_id: &str) -> Result<String> {
        if let Some(p) = self.playlists.iter().find(|p| p.list_id == list_id) {
            if !p.numeric_id.is_empty() {
                return Ok(p.numeric_id.clone());
            }
        }
        let d = self.get_playlist_detail(list_id).await?;
        if d.numeric_id.is_empty() {
            return Err(Error::Invalid(format!("无法解析 listid: {list_id}")));
        }
        Ok(d.numeric_id)
    }

    // ========================================================
    //  歌曲
    // ========================================================

    /// 获取播放地址（对应 `getMusicUrl(musicId, bitrate:)`）
    pub async fn get_music_url(&self, hash: &str, quality: &str) -> Result<String> {
        api::song::song_url(&self.transport, hash, quality).await
    }

    /// 按音质档位取地址（对应 `chooseMusicQuality(musicId, quality:)`）
    ///
    /// `quality`：`0` = 128，`1` = 320，`2` = flac。
    pub async fn choose_music_quality(&self, hash: &str, quality: u32) -> Result<String> {
        let grades = ["128", "320", "flac"];
        let q = grades.get(quality as usize).copied().unwrap_or("128");
        self.get_music_url(hash, q).await
    }

    /// 批量取歌曲详情（对应 `getMusicsDetails(ids)`）
    ///
    /// 内部两步：`/privilege/lite` 取基础信息 → `/krm/audio` 补全歌手/专辑 ID。
    pub async fn get_musics_details(&self, hashes: &[String]) -> Result<Vec<Music>> {
        if hashes.is_empty() {
            return Ok(Vec::new());
        }

        let raw = api::song::privilege_lite(&self.transport, hashes).await?;

        // 第一步：解析基础字段
        struct Row {
            hash: String,
            name: String,
            singer: String,
            album: String,
            cover: String,
            duration: i64,
            album_audio_id: String,
        }

        let rows: Vec<Row> = raw
            .iter()
            .map(|i| {
                let full_name = i
                    .get("name")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string();

                // ⚠️ 与原 Dart 行为一致：名称含 " - " 时按它分割
                let (name, singer) = if full_name.contains(" - ") {
                    match full_name.split_once(" - ") {
                        Some((a, b)) => (b.to_string(), a.to_string()),
                        None => (full_name.clone(), String::new()),
                    }
                } else {
                    (
                        full_name.clone(),
                        i.get("singername")
                            .and_then(|v| v.as_str())
                            .unwrap_or("")
                            .to_string(),
                    )
                };

                // 封面三级回退
                let cover = i
                    .pointer("/info/image")
                    .and_then(|v| v.as_str())
                    .or_else(|| i.pointer("/trans_param/union_cover").and_then(|v| v.as_str()))
                    .unwrap_or("");

                Row {
                    hash: i
                        .get("hash")
                        .and_then(|v| v.as_str())
                        .unwrap_or("")
                        .to_string(),
                    name,
                    singer,
                    album: i
                        .get("albumname")
                        .and_then(|v| v.as_str())
                        .unwrap_or("")
                        .to_string(),
                    cover: crate::models::get_cover(cover, "500"),
                    duration: i
                        .pointer("/info/duration")
                        .and_then(|v| v.as_i64())
                        .unwrap_or(0),
                    album_audio_id: match i.get("album_audio_id") {
                        Some(Value::Number(n)) => n.to_string(),
                        Some(Value::String(s)) => s.clone(),
                        _ => String::new(),
                    },
                }
            })
            .collect();

        // 第二步：分批补全专辑/歌手 ID（每批 50）
        let aaid_list: Vec<String> = rows
            .iter()
            .map(|r| r.album_audio_id.clone())
            .filter(|s| !s.is_empty())
            .collect();

        let mut id_map: std::collections::HashMap<String, (String, String)> =
            std::collections::HashMap::new();

        for chunk in aaid_list.chunks(50) {
            if let Ok(items) = api::song::krm_audio(
                &self.transport,
                chunk,
                "album_info,base,authors.base",
            )
            .await
            {
                for (aaid, album_id, singer_id) in items {
                    id_map.insert(aaid, (album_id, singer_id));
                }
            }
        }

        Ok(rows
            .into_iter()
            .map(|r| {
                let (album_id, singer_id) = id_map
                    .get(&r.album_audio_id)
                    .cloned()
                    .unwrap_or_default();
                Music {
                    name: r.name,
                    id: r.hash,
                    singer: r.singer,
                    singer_id,
                    album: r.album,
                    album_id,
                    time: r.duration,
                    cover: r.cover,
                }
            })
            .collect())
    }

    /// 获取歌词（对应 `getLyric(musicId)`）
    ///
    /// `fmt` 传 `"lrc"` 得纯文本，传 `"krc"` 得逐字歌词（自动转 LRC）。
    pub async fn get_lyric(&self, hash: &str) -> Result<String> {
        api::song::lyric(&self.transport, hash, "lrc").await
    }

    /// 获取逐字歌词
    pub async fn get_lyric_krc(&self, hash: &str) -> Result<String> {
        api::song::lyric(&self.transport, hash, "krc").await
    }

    // ========================================================
    //  搜索
    // ========================================================

    /// 综合搜索（对应 `search(keyword)`）
    pub async fn search(&self, keyword: &str) -> Result<SearchResult> {
        api::search::search_complex(&self.transport, keyword, 1, 30).await
    }

    /// 搜索并补全歌曲详情
    ///
    /// 对应 Dart 的 `search()` 完整行为（会额外调一次 `getMusicsDetails`）。
    pub async fn search_with_details(&self, keyword: &str) -> Result<SearchResult> {
        let mut r = self.search(keyword).await?;
        let hashes: Vec<String> = r.music.iter().map(|m| m.id.clone()).collect();
        if !hashes.is_empty() {
            if let Ok(details) = self.get_musics_details(&hashes).await {
                r.music = details;
            }
        }
        Ok(r)
    }

    // ========================================================
    //  歌手
    // ========================================================

    /// 歌手单曲（对应 `getSingerMusic(singerId)`）
    pub async fn get_singer_music(&self, singer_id: &str) -> Result<Vec<Music>> {
        let hashes = api::artist::artist_audios(&self.transport, singer_id, 200, "hot").await?;
        self.get_musics_details(&hashes).await
    }

    /// 歌手专辑（对应 `getSingerAlbum(singerId)`）
    pub async fn get_singer_albums(&self, singer_id: &str) -> Result<Vec<Album>> {
        api::artist::artist_albums(&self.transport, singer_id, 300, "hot").await
    }

    /// 歌手详情（对应 `getSingerDetails(singerId)`）
    pub async fn get_singer_detail(&self, singer_id: &str) -> Result<Singer> {
        api::artist::artist_detail(&self.transport, singer_id).await
    }

    /// 推荐歌手（对应 `getRecommendSingers(num)`）
    pub async fn get_recommend_singers(&self, num: u32) -> Result<Vec<Singer>> {
        let mut list = api::artist::hot_singers(&self.transport, 100).await?;
        shuffle(&mut list);
        list.truncate(num as usize);
        Ok(list)
    }

    // ========================================================
    //  专辑
    // ========================================================

    /// 专辑歌曲（对应 `getAlbumMusic(albumId)`）
    pub async fn get_album_music(&self, album_id: &str) -> Result<Vec<Music>> {
        let hashes = api::album::album_songs(&self.transport, album_id).await?;
        self.get_musics_details(&hashes).await
    }

    /// 专辑详情（对应 `getAlbumDetails(albumId)`）
    pub async fn get_album_detail(&self, album_id: &str) -> Result<Album> {
        let v = api::album::album(&self.transport, &[album_id.to_string()], "").await?;
        v.into_iter()
            .next()
            .ok_or_else(|| Error::Invalid("专辑不存在".into()))
    }

    // ========================================================
    //  推荐
    // ========================================================

    /// 每日推荐（对应 `getRecommendMusics(num)`）
    pub async fn get_recommend_musics(&self, num: u32) -> Result<Vec<Music>> {
        let mut hashes = api::recommend::everyday_recommend_hashes(&self.transport).await?;
        shuffle(&mut hashes);
        hashes.truncate(num as usize);
        self.get_musics_details(&hashes).await
    }

    /// 推荐歌单（对应 `getRecommendPlaylists(num)`）
    pub async fn get_recommend_playlists(&self, num: u32) -> Result<Vec<Playlist>> {
        let mut list = api::recommend::top_ip(&self.transport).await?;
        shuffle(&mut list);
        list.truncate(num as usize);
        Ok(list)
    }

    // ========================================================
    //  VIP
    // ========================================================

    /// 领取每日 VIP（对应 `getVip()` 的第一步）
    pub async fn claim_daily_vip(&self) -> Result<()> {
        api::user_vip::youth_day_vip(&self.transport, &api::user_vip::beijing_date()).await
    }

    /// 升级 VIP（对应 `getVip()` 的第二步）
    pub async fn upgrade_vip(&self) -> Result<()> {
        api::user_vip::youth_day_vip_upgrade(&self.transport).await
    }

    /// 广告换 VIP，连调 8 次（对应 `getVip8()`）
    pub async fn claim_ad_vip(&self) -> Result<u32> {
        api::user_vip::youth_vip_batch(&self.transport, 8, 15).await
    }

    /// 完整的 VIP 领取流程（对应 `getVip()`）
    pub async fn claim_vip_all(&self) -> Result<()> {
        let _ = self.claim_ad_vip().await;
        let _ = self.claim_daily_vip().await;
        let _ = self.upgrade_vip().await;
        Ok(())
    }
}

/// Fisher–Yates 洗牌（对应 Dart 的 `shuffleArray` / `List.shuffle`）
pub fn shuffle<T>(v: &mut [T]) {
    use rand::seq::SliceRandom;
    let mut rng = rand::thread_rng();
    v.shuffle(&mut rng);
}
