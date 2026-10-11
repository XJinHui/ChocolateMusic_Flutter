//! `NetEaseClient` —— 门面
//!
//! 持有设备身份与传输层，对外提供两类接口：
//!
//! | 类别 | 用途 |
//! | --- | --- |
//! | [`NetEaseClient::raw_request`] | 按原服务器路由透传，供 `Neteasecloud.dart` 无改动迁移 |
//! | 下面的强类型方法 | 新代码直接调用，返回 [`ServerResponse`] |
//!
//! ## 凭据模型
//!
//! 网易云的凭据是 **Cookie**，由调用方每个请求带上（对应 Dart 侧的
//! `Options(headers: {'Cookie': this.cookies})`）。所以所有方法都收 `cookie` 参数。
//! 未登录传空串即可（部分接口仍可用）。

use std::collections::HashMap;
use std::path::{Path, PathBuf};

use serde_json::Value;

use crate::api::{self, ServerRequest, ServerResponse};
use crate::device::DeviceIdentity;
use crate::raw;
use crate::request::Transport;
use crate::Result;

/// 默认的身份文件名
pub const DEFAULT_IDENTITY_FILE: &str = "netease_identity.json";

/// 网易云客户端
///
/// `#[frb(opaque)]`：对 flutter_rust_bridge 而言这是个**不透明句柄**，
/// Dart 侧拿到的是 `RustOpaque<NetEaseClient>`，只能通过方法交互（不镜像字段）。
/// 这样 `reqwest::Client` 之类的字段就不会进入 FFI 转换。
#[flutter_rust_bridge::frb(opaque)]
pub struct NetEaseClient {
    /// 传输层（含设备身份）
    ///
    /// ⚠️ 故意**不是** `pub` —— FRB 会为 opaque 类型的 `pub` 字段生成 getter，
    /// 而 `Transport` 内含 `reqwest::Client`，转换不了。
    pub(crate) transport: Transport,

    /// 身份文件路径；`None` 表示不持久化
    identity_path: Option<PathBuf>,
}

impl Default for NetEaseClient {
    fn default() -> Self {
        Self::new()
    }
}

impl NetEaseClient {
    // ========================================================
    //  构造
    // ========================================================

    /// 创建客户端（不读写磁盘）
    pub fn new() -> Self {
        Self {
            transport: Transport::new(DeviceIdentity::generate()),
            identity_path: None,
        }
    }

    /// 从身份文件加载；文件不存在则生成并写入
    ///
    /// ⚠️ 设备身份**必须持久化** —— 原 Node 实现每次启动都换 `deviceId`，
    /// 这是最明显的风控特征。
    pub fn with_identity_file(path: impl AsRef<Path>) -> Self {
        let path = path.as_ref();
        let device = DeviceIdentity::load_or_create(path);

        Self {
            // ⚠️ 路径也要给 Transport —— 探测到的 NMTID 由它负责落盘
            transport: Transport::with_identity_path(device, Some(path.to_path_buf())),
            identity_path: Some(path.to_path_buf()),
        }
    }

    /// 写入身份文件
    pub fn save(&self) -> Result<()> {
        match &self.identity_path {
            Some(p) => self.transport.device.save(p),
            None => Ok(()),
        }
    }

    // ========================================================
    //  设备身份
    // ========================================================

    /// 52 个**大写** hex 字符
    pub fn device_id(&self) -> String {
        self.transport.device.device_id.clone()
    }

    /// `<6 个小写字母>.<毫秒>.01.0`
    pub fn wnmcid(&self) -> String {
        self.transport.device.wnmcid.clone()
    }

    /// 是否已拿到匿名 token
    pub fn has_music_a(&self) -> bool {
        self.transport.device.has_music_a()
    }

    /// 是否已拿到服务端下发的 `NMTID`
    pub fn has_nmtid(&self) -> bool {
        self.transport.nmtid_state().value.is_some()
    }

    /// 记下匿名 token（由 [`Self::register_anonymous`] 或调用方写入）
    pub fn set_music_a(&mut self, token: impl Into<String>) {
        self.transport.device.music_a = token.into();
    }

    // ========================================================
    //  启动流程
    // ========================================================

    /// 补齐两个**服务端下发**的身份令牌
    ///
    /// 对应原 Node 服务的启动段（`app.js` → `generateConfig`）加第一次 eapi 请求。
    ///
    /// | 令牌 | 从哪来 | 缺了会怎样 |
    /// | --- | --- | --- |
    /// | `MUSIC_A` | `/register/anonimous`（xeapi） | `/login/qr/check` → `-462` |
    /// | `NMTID` | **eapi 响应的 `Set-Cookie`** | `/login/cellphone` → `-462` |
    ///
    /// `-462` 是网易云的风控拦截（`请完成验证操作`），客户端拿它没有任何办法 ——
    /// 必须让请求本身带上这两个令牌。
    ///
    /// 两者都已持久化在身份文件里时**一次网络请求都不发**。
    /// 任一步失败都**不算致命**：照常返回，只是后续请求风控更严。
    ///
    /// 返回若干条人类可读的说明，供调用方打日志。
    pub async fn bootstrap(&mut self) -> Vec<String> {
        let mut notes = Vec::new();

        // ① 匿名注册 → MUSIC_A
        if self.has_music_a() {
            notes.push("MUSIC_A: 已有，跳过注册".into());
        } else {
            match self.register_anonymous("").await {
                Ok(t) if !t.is_empty() => notes.push("MUSIC_A: 注册成功".into()),
                Ok(_) => notes.push("MUSIC_A: 上游未返回 anonymousToken".into()),
                Err(e) => notes.push(format!("MUSIC_A: 注册失败（{e}）")),
            }
        }

        // ② NMTID 探测
        //
        // ⚠️ **只有 eapi 响应才会下发 NMTID**，所以这里主动打一次 eapi 路由。
        //    选 `/login/qr/key`：它本来就要在扫码登录时调，且无副作用
        //    （只是服务端建一个待扫码的 key）。
        if self.has_nmtid() {
            notes.push("NMTID: 已有，跳过探测".into());
        } else {
            let r = self
                .raw_request(
                    "/login/qr/key".into(),
                    std::collections::HashMap::new(),
                    String::new(),
                )
                .await;
            match r {
                Ok(_) if self.has_nmtid() => notes.push("NMTID: 探测成功".into()),
                Ok(_) => notes.push("NMTID: 上游未下发，本次只能用伪造值".into()),
                Err(e) => notes.push(format!("NMTID: 探测失败（{e}）")),
            }
        }

        notes
    }

    // ========================================================
    //  原始响应透传
    // ========================================================

    /// 按原服务器的路由发一次请求，返回**原服务器会返回的响应体**（JSON 文本）
    ///
    /// `path` 是原服务器的路由（如 `/song/url`），`query` 是查询参数，
    /// `cookie` 是账号 Cookie 串。
    ///
    /// ```no_run
    /// # async fn run() -> Result<(), netease::Error> {
    /// # let client = netease::NetEaseClient::new();
    /// let mut q = std::collections::HashMap::new();
    /// q.insert("id".to_string(), "347230".to_string());
    /// let json = client.raw_request("/song/url".into(), q, String::new()).await?;
    /// # Ok(()) }
    /// ```
    ///
    /// ⚠️ `/login/qr/create` **不发任何网易请求**（本地生成二维码）。
    pub async fn raw_request(
        &self,
        path: String,
        query: HashMap<String, String>,
        cookie: String,
    ) -> Result<String> {
        let body = raw::dispatch(&self.transport, &path, &query, &cookie).await?;
        Ok(body.to_string())
    }

    /// 支持的路由清单
    ///
    /// ⚠️ 返回 `Vec<String>` 而不是 `&'static [&'static str]` ——
    /// 后者在 FRB 里会被当成引用类型，退化成 unit。
    pub fn supported_routes() -> Vec<String> {
        raw::ROUTES.iter().map(|s| s.to_string()).collect()
    }

    /// 尚未实现的路由（当前为空）
    pub fn unsupported_routes() -> Vec<String> {
        raw::UNIMPLEMENTED.iter().map(|s| s.to_string()).collect()
    }

    // ========================================================
    //  强类型接口
    // ========================================================

    fn req<'a>(&'a self, cookie: &str) -> ServerRequest<'a> {
        ServerRequest::new(&self.transport, cookie)
    }

    /// 匿名注册，拿到 `MUSIC_A` 并写回设备身份
    ///
    /// **这是启动流程的关键依赖** —— 没有它，未登录状态下部分接口返回 301。
    /// 登录后 `MUSIC_U` 会覆盖它，所以登录用户不需要调。
    ///
    /// ⚠️ 需要 xeapi 公钥，首次调用会自动拉取（多一次网络往返）。
    pub async fn register_anonymous(&mut self, cookie: &str) -> Result<String> {
        let device_id = self.transport.device.device_id.clone();
        let r = api::login::register_anonimous(&self.req(cookie), &device_id).await?;

        let token = api::login::extract_music_a(&r.body).unwrap_or_default();
        if !token.is_empty() {
            self.transport.device.music_a = token.clone();
            let _ = self.save();
        }
        Ok(token)
    }

    /// 登录状态（响应被包一层 `data`）
    pub async fn login_status(&self, cookie: &str) -> Result<ServerResponse> {
        api::login::login_status(&self.req(cookie)).await
    }

    /// 用户账号信息
    pub async fn user_account(&self, cookie: &str) -> Result<ServerResponse> {
        api::login::user_account(&self.req(cookie)).await
    }

    /// 手机验证码登录
    pub async fn login_cellphone(
        &self,
        cookie: &str,
        phone: &str,
        captcha: &str,
    ) -> Result<ServerResponse> {
        api::login::login_cellphone(&self.req(cookie), phone, captcha, "", "").await
    }

    /// 发送手机验证码
    pub async fn captcha_sent(&self, cookie: &str, phone: &str) -> Result<ServerResponse> {
        api::login::captcha_sent(&self.req(cookie), phone, "").await
    }

    /// 刷新登录令牌
    pub async fn login_refresh(&self, cookie: &str) -> Result<ServerResponse> {
        api::login::login_refresh(&self.req(cookie)).await
    }

    /// 生成二维码 key
    pub async fn qr_key(&self, cookie: &str) -> Result<ServerResponse> {
        api::login::qr_key(&self.req(cookie)).await
    }

    /// 生成二维码图片（**不发网络请求**）
    pub fn qr_create(&self, key: &str, platform: &str, want_image: bool) -> ServerResponse {
        api::login::qr_create(key, platform, want_image, &self.device_id())
    }

    /// 检测扫码状态
    pub async fn qr_check(&self, cookie: &str, key: &str) -> Result<ServerResponse> {
        api::login::qr_check(&self.req(cookie), key).await
    }

    /// VIP 信息
    pub async fn vip_info(&self, cookie: &str, uid: &str) -> Result<ServerResponse> {
        api::login::vip_info(&self.req(cookie), uid).await
    }

    /// 用户歌单
    pub async fn user_playlist(
        &self,
        cookie: &str,
        uid: &str,
        limit: u32,
    ) -> Result<ServerResponse> {
        api::playlist::user_playlist(&self.req(cookie), uid, limit, 0).await
    }

    /// 歌单详情
    pub async fn playlist_detail(&self, cookie: &str, id: &str) -> Result<ServerResponse> {
        api::playlist::playlist_detail(&self.req(cookie), id, 8).await
    }

    /// 歌单全部歌曲（两条请求串联）
    pub async fn playlist_track_all(&self, cookie: &str, id: &str) -> Result<ServerResponse> {
        api::playlist::playlist_track_all(&self.req(cookie), id, 1000, 0).await
    }

    /// 新建歌单
    pub async fn playlist_create(&self, cookie: &str, name: &str) -> Result<ServerResponse> {
        api::playlist::playlist_create(&self.req(cookie), name, "", "").await
    }

    /// 删除歌单
    pub async fn playlist_delete(&self, cookie: &str, id: &str) -> Result<ServerResponse> {
        api::playlist::playlist_delete(&self.req(cookie), id).await
    }

    /// 歌单加 / 删歌
    pub async fn playlist_tracks(
        &self,
        cookie: &str,
        op: &str,
        pid: &str,
        tracks: &[String],
    ) -> Result<ServerResponse> {
        api::playlist::playlist_tracks(&self.req(cookie), op, pid, tracks).await
    }

    /// 歌曲详情
    pub async fn song_detail(&self, cookie: &str, ids: &[String]) -> Result<ServerResponse> {
        api::song::song_detail(&self.req(cookie), ids).await
    }

    /// 播放地址
    pub async fn song_url(&self, cookie: &str, ids: &[String], br: u32) -> Result<ServerResponse> {
        api::song::song_url(&self.req(cookie), ids, br).await
    }

    /// 歌词
    pub async fn lyric(&self, cookie: &str, id: &str) -> Result<ServerResponse> {
        api::song::lyric(&self.req(cookie), id).await
    }

    /// 搜索
    pub async fn search(
        &self,
        cookie: &str,
        keywords: &str,
        ty: u32,
        limit: u32,
    ) -> Result<ServerResponse> {
        api::search::search(&self.req(cookie), keywords, ty, limit, 0).await
    }

    /// 歌手单曲
    pub async fn artist_songs(
        &self,
        cookie: &str,
        id: &str,
        limit: u32,
        offset: u32,
    ) -> Result<ServerResponse> {
        api::artist::artist_songs(&self.req(cookie), id, "", offset, limit).await
    }

    /// 歌手专辑
    pub async fn artist_album(&self, cookie: &str, id: &str) -> Result<ServerResponse> {
        api::artist::artist_album(&self.req(cookie), id, 300, 0).await
    }

    /// 歌手详情
    pub async fn artist_detail(&self, cookie: &str, id: &str) -> Result<ServerResponse> {
        api::artist::artist_detail(&self.req(cookie), id).await
    }

    /// 专辑信息
    pub async fn album(&self, cookie: &str, id: &str) -> Result<ServerResponse> {
        api::album::album(&self.req(cookie), id).await
    }

    /// 每日推荐歌曲
    pub async fn recommend_songs(&self, cookie: &str) -> Result<ServerResponse> {
        api::recommend::recommend_songs(&self.req(cookie), "").await
    }

    /// 每日推荐歌单
    pub async fn recommend_resource(&self, cookie: &str) -> Result<ServerResponse> {
        api::recommend::recommend_resource(&self.req(cookie)).await
    }

    /// 热门歌手
    pub async fn top_artists(&self, cookie: &str, limit: u32) -> Result<ServerResponse> {
        api::recommend::top_artists(&self.req(cookie), limit, 0).await
    }

    // ========================================================
    //  便捷解析
    // ========================================================

    /// 取播放地址（`data[0].url`）
    pub async fn song_url_str(&self, cookie: &str, id: &str) -> Result<String> {
        let r = self.song_url(cookie, &[id.to_string()], 999_000).await?;
        Ok(r.body
            .pointer("/data/0/url")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn client_constructs_without_disk() {
        let c = NetEaseClient::new();
        assert_eq!(c.device_id().len(), 52);
        assert!(!c.has_music_a());
        // 不持久化时 save 是空操作
        assert!(c.save().is_ok());
    }

    #[test]
    fn route_tables_cover_client_and_startup() {
        // 29 条客户端路由 + 1 条启动流程路由（匿名注册）
        assert_eq!(
            NetEaseClient::supported_routes().len() + NetEaseClient::unsupported_routes().len(),
            30
        );
    }

    #[test]
    fn qr_create_needs_no_network() {
        let c = NetEaseClient::new();
        let r = c.qr_create("K", "pc", false);
        assert_eq!(r.body["code"], 200);
        assert!(r.body["data"]["qrurl"]
            .as_str()
            .unwrap()
            .contains("codekey=K"));
    }
}
