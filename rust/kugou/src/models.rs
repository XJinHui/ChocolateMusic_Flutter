//! 数据模型
//!
//! 对应 `chocolate_music` 的 `Type.dart`：`Music` / `Singer` / `Album` / `Playlist` / `KugouData`。

use serde::{Deserialize, Serialize};

/// 歌曲
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
pub struct Music {
    /// 歌名
    pub name: String,
    /// 歌曲 hash（取播放地址用）
    pub id: String,
    /// 歌手名
    pub singer: String,
    /// 歌手 ID（跳转歌手页用）
    pub singer_id: String,
    /// 专辑名
    pub album: String,
    /// 专辑 ID（跳转专辑页用）
    pub album_id: String,
    /// 时长（秒）
    pub time: i64,
    /// 封面 URL（已替换尺寸占位符）
    pub cover: String,
}

/// 歌手
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
pub struct Singer {
    pub singer: String,
    pub singer_id: String,
    pub cover: String,
    /// 歌曲数
    pub audio_count: i64,
    /// 专辑数
    pub album_count: i64,
}

/// 专辑
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
pub struct Album {
    pub album: String,
    pub album_id: String,
    pub singer: String,
    pub cover: String,
    pub audio_count: i64,
}

/// 歌单
///
/// ⚠️ `list_id` 是 **`global_collection_id`**（字符串，用于读操作）；
/// 写操作需要的是数字 `listid`，存在 [`Playlist::numeric_id`]。
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
pub struct Playlist {
    pub name: String,
    /// `global_collection_id` —— 读操作用
    pub list_id: String,
    pub audio_count: i64,
    pub cover: String,
    /// 数字 `listid` —— 写操作用（`/playlist/del`、`/playlist/tracks/add` 等）
    #[serde(default)]
    pub numeric_id: String,
}

/// 登录账号数据
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct KugouData {
    pub token: String,
    pub userid: String,
    /// token 过期时间（秒级时间戳）
    pub t_expire_time: i64,
    pub cover: String,
    pub nickname: String,
    pub dfid: String,
    pub url: String,
}

impl KugouData {
    /// token 是否已过期
    pub fn is_expired(&self) -> bool {
        let now = crate::request::now_secs();
        self.t_expire_time < now
    }

    /// 剩余有效秒数（已过期返回负数）
    pub fn remaining_secs(&self) -> i64 {
        self.t_expire_time - crate::request::now_secs()
    }
}

/// 搜索结果聚合
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct SearchResult {
    pub music: Vec<Music>,
    pub singer: Vec<Singer>,
    pub album: Vec<Album>,
}

/// 云盘上传的曲库匹配结果
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct MatchInfo {
    pub album_audio_id: i64,
    pub audio_id: i64,
    pub hash_std: String,
    pub author_name: String,
    pub audio_name: String,
}

// ============================================================
//  封面 URL 处理
// ============================================================

/// 替换封面 URL 里的尺寸占位符
///
/// 对应 Dart 的 `getCover`：
/// 1. `{size}` → 实际尺寸
/// 2. `/240/` → `/{size}/`
pub fn get_cover(url: &str, size: &str) -> String {
    if url.is_empty() {
        return String::new();
    }
    let s = url.replacen("{size}", size, 1);
    s.replacen("/240/", &format!("/{size}/"), 1)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cover_replaces_size_placeholder() {
        let u = "http://imge.kugou.com/x/{size}/a.jpg";
        assert_eq!(get_cover(u, "500"), "http://imge.kugou.com/x/500/a.jpg");
    }

    #[test]
    fn cover_replaces_240_path() {
        let u = "http://imge.kugou.com/240/a.jpg";
        assert_eq!(get_cover(u, "500"), "http://imge.kugou.com/500/a.jpg");
    }

    #[test]
    fn cover_empty_stays_empty() {
        assert_eq!(get_cover("", "500"), "");
    }
}
