//! 推荐与发现
//!
//! 对应 `KuGou.dart` 的 `getRecommendMusics` / `getRecommendPlaylists`。

use crate::models::Playlist;
use crate::request::{RequestOptions, Transport};
use crate::Result;
use serde_json::{json, Value};

/// 每日推荐
///
/// 对应 Dart 的 `getRecommendMusics(num)`。
///
/// ```text
/// POST https://gateway.kugou.com/everyday_song_recommend
/// x-router: everydayrec.service.kugou.com
/// ```
///
/// ⚠️ `platform` 默认 `"ios"` —— 本项目整体模拟 Android 客户端，但**这个接口上游期望 iOS 标识**。
///
/// 返回 `data.song_list` 原始数组（每首含 80+ 字段）。
/// 若只需 hash 列表，用 [`everyday_recommend_hashes`]。
/// 构造「每日推荐」请求
pub(crate) fn build_everyday_recommend() -> RequestOptions {
    RequestOptions::post("/everyday_song_recommend")
        .router("everydayrec.service.kugou.com")
        .param("platform", "ios")
}

pub async fn everyday_recommend(t: &Transport) -> Result<Vec<Value>> {
    let resp = t.send(build_everyday_recommend()).await?;

    Ok(resp.arr_at(&["data", "song_list"]))
}

/// 每日推荐的 hash 列表
pub async fn everyday_recommend_hashes(t: &Transport) -> Result<Vec<String>> {
    Ok(everyday_recommend(t)
        .await?
        .iter()
        .filter_map(|s| s.get("hash").and_then(|v| v.as_str()).map(str::to_string))
        .collect())
}

/// 推荐歌单（IP 专区日推）
///
/// 对应 Dart 的 `getRecommendPlaylists(num)`。
///
/// ```text
/// POST http://musicadservice.kugou.com/v1/daily_recommend
/// ```
///
/// ⚠️ `clientver` 被覆盖为 **12349**（其他接口用 20489）。
/// ⚠️ `audio_count` 填的是 `extra.play_count`（**播放量**），不是歌曲数。
/// 构造「推荐歌单（IP 专区日推）」请求
pub(crate) fn build_top_ip() -> RequestOptions {
    let body = json!({ "tags": {} });

    RequestOptions::post("/v1/daily_recommend")
        .base_url("http://musicadservice.kugou.com")
        .param("clientver", 12349)
        .param("area_code", 1)
        .json_body(&body)
}

pub async fn top_ip(t: &Transport) -> Result<Vec<Playlist>> {
    let resp = t.send(build_top_ip()).await?;

    let mut out = Vec::new();
    for item in resp.arr_at(&["data", "list"]) {
        let Some(gid) = item
            .pointer("/extra/global_collection_id")
            .and_then(|v| v.as_str())
        else {
            continue;
        };

        out.push(Playlist {
            name: item
                .get("title")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            list_id: gid.to_string(),
            audio_count: item
                .pointer("/extra/play_count")
                .and_then(|v| v.as_i64())
                .unwrap_or(0),
            cover: crate::models::get_cover(
                item.get("image_url").and_then(|v| v.as_str()).unwrap_or(""),
                "500",
            ),
            numeric_id: String::new(),
        });
    }
    Ok(out)
}
