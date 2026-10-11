//! 用户相关
//!
//! 对应 `KuGou.dart` 的 `getPlaylist` / `getCollectionList` 的第一步。

use crate::models::Playlist;
use crate::request::{RequestOptions, Transport};
use crate::Result;
use serde_json::{json, Value};

/// 获取用户歌单列表
///
/// 对应 Dart 的 `getPlaylist()`。
///
/// ```text
/// POST https://gateway.kugou.com/v7/get_all_list
/// x-router: cloudlist.service.kugou.com
/// ```
///
/// 返回的每个 [`Playlist`] 同时带 `list_id`（`global_collection_id`，读操作用）
/// 与 `numeric_id`（`listid`，写操作用），无需额外维护映射表。
///
/// ⚠️ 原项目 Dart 客户端用 `name == '我喜欢'` 判断收藏歌单，但实际名称是
/// **`我喜欢的音乐`**，导致判断永不成立。用 [`find_favorite_playlist`] 代替。
/// 构造「获取用户歌单列表」请求
pub(crate) fn build_user_playlist(t: &Transport, page: u32, pagesize: u32) -> RequestOptions {
    let body = json!({
        "userid": t.account.userid,
        "token": t.account.token,
        "total_ver": 979,
        "type": 2,
        "page": if page == 0 { 1 } else { page },
        "pagesize": if pagesize == 0 { 30 } else { pagesize }
    });

    let userid_num: i64 = t.account.userid.parse().unwrap_or(0);

    RequestOptions::post("/v7/get_all_list")
        .router("cloudlist.service.kugou.com")
        .param("plat", 1)
        .param("userid", userid_num)
        .param("token", t.account.token.clone())
        .json_body(&body)
}

pub async fn user_playlist(t: &Transport, page: u32, pagesize: u32) -> Result<Vec<Playlist>> {
    let resp = t.send(build_user_playlist(t, page, pagesize)).await?;

    Ok(resp
        .arr_at(&["data", "info"])
        .iter()
        .map(|i| Playlist {
            name: str_of(i, "name"),
            list_id: str_of(i, "global_collection_id"),
            audio_count: i
                .get("m_count")
                .or_else(|| i.get("count"))
                .and_then(|v| v.as_i64())
                .unwrap_or(0),
            cover: crate::models::get_cover(&str_of(i, "pic"), "500"),
            numeric_id: num_of(i, "listid"),
        })
        .collect())
}

/// 找出「我喜欢的音乐」歌单
///
/// 判断依据（按优先级）：
/// 1. 名称以 `我喜欢` 开头（实际名称是 `我喜欢的音乐`）
/// 2. 列表首项（酷狗通常把它排在首位）
///
/// 原项目用 `== '我喜欢'` 精确匹配，永远匹配不上。
pub fn find_favorite_playlist(list: &[Playlist]) -> Option<&Playlist> {
    list.iter()
        .find(|p| p.name.starts_with("我喜欢"))
        .or_else(|| list.first())
}

fn str_of(v: &Value, k: &str) -> String {
    match v.get(k) {
        Some(Value::String(x)) => x.clone(),
        Some(Value::Number(x)) => x.to_string(),
        _ => String::new(),
    }
}

fn num_of(v: &Value, k: &str) -> String {
    str_of(v, k)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn pl(name: &str) -> Playlist {
        Playlist {
            name: name.to_string(),
            list_id: format!("gid_{name}"),
            numeric_id: "1".into(),
            ..Default::default()
        }
    }

    #[test]
    fn finds_favorite_by_prefix() {
        let list = vec![pl("自建歌单"), pl("我喜欢的音乐"), pl("收藏")];
        assert_eq!(find_favorite_playlist(&list).unwrap().name, "我喜欢的音乐");
    }

    #[test]
    fn falls_back_to_first() {
        let list = vec![pl("歌单一"), pl("歌单二")];
        assert_eq!(find_favorite_playlist(&list).unwrap().name, "歌单一");
    }

    #[test]
    fn handles_empty() {
        assert!(find_favorite_playlist(&[]).is_none());
    }
}
