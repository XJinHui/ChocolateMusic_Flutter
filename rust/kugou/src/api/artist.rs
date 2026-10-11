//! 歌手相关
//!
//! 对应 `KuGou.dart` 的 `getRecommendSingers` / `getSingerMusic` /
//! `getSingerAlbum` / `getSingerDetails`。

use crate::models::{Album, Singer};
use crate::request::{now_secs, RequestOptions, Transport};
use crate::sign::sign_params_key;
use crate::Result;
use serde_json::{json, Value};

/// 歌手列表（含「热门」分组）
///
/// 对应 Dart 的 `getRecommendSingers(num)`。
///
/// ⚠️ `hotsize` 越大响应体越大。实测 `hotsize=3` 就有 **516 KB**（每位歌手带完整
/// `intro` / `offline_url` / `dycover`）。建议不超过 100。
///
/// 返回 `(分组名, 歌手列表)`，客户端通常只取 `title == "热门"` 那组。
/// 构造「歌手列表」请求
pub(crate) fn build_artist_lists(hotsize: u32) -> RequestOptions {
    RequestOptions::get("/ocean/v6/singer/list")
        .param("musician", 0)
        .param("sextype", 0)
        .param("showtype", 2)
        .param("type", 0)
        .param("hotsize", if hotsize == 0 { 30 } else { hotsize })
}

pub async fn artist_lists(t: &Transport, hotsize: u32) -> Result<Vec<(String, Vec<Singer>)>> {
    let resp = t.send(build_artist_lists(hotsize)).await?;

    let mut groups = Vec::new();
    for group in resp.arr_at(&["data", "info"]) {
        let title = group
            .get("title")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();

        let singers = group
            .get("singer")
            .and_then(|v| v.as_array())
            .map(|arr| {
                arr.iter()
                    .map(|item| Singer {
                        singer: str_of(item, "singername"),
                        // ⚠️ singerid 是数字，需转字符串
                        singer_id: num_of(item, "singerid"),
                        cover: crate::models::get_cover(&str_of(item, "imgurl"), "500"),
                        audio_count: item.get("songcount").and_then(|v| v.as_i64()).unwrap_or(0),
                        album_count: item.get("albumcount").and_then(|v| v.as_i64()).unwrap_or(0),
                    })
                    .collect()
            })
            .unwrap_or_default();

        groups.push((title, singers));
    }
    Ok(groups)
}

/// 只取「热门」分组的歌手
pub async fn hot_singers(t: &Transport, hotsize: u32) -> Result<Vec<Singer>> {
    let groups = artist_lists(t, hotsize).await?;
    Ok(groups
        .into_iter()
        .find(|(title, _)| title == "热门")
        .map(|(_, s)| s)
        .unwrap_or_default())
}

/// 歌手单曲
///
/// 对应 Dart 的 `getSingerMusic(singerId)`。
///
/// `sort` 传 `"hot"` 取最热（上游 `1`），否则取最新（上游 `2`）。
///
/// ⚠️ `pagesize` 无上限校验，建议 ≤ 100。
/// 构造「歌手单曲」请求
pub(crate) fn build_artist_audios(
    t: &Transport,
    singer_id: &str,
    pagesize: u32,
    sort: &str,
) -> RequestOptions {
    let clienttime = now_secs();
    let key = sign_params_key(t.platform, &clienttime.to_string(), None, None);

    let body = json!({
        "appid": t.platform.appid(),
        "clientver": t.platform.clientver(),
        "mid": t.device.mid,
        "clienttime": clienttime,
        "key": key,
        "author_id": singer_id,
        "pagesize": if pagesize == 0 { 30 } else { pagesize },
        "page": 1,
        "sort": if sort == "hot" { 1 } else { 2 },
        "area_code": "all"
    });

    RequestOptions::post("/kmr/v1/audio_group/author")
        .base_url("https://openapi.kugou.com")
        .router("openapi.kugou.com")
        .header("kg-tid", "220")
        .json_body(&body)
}

pub async fn artist_audios(
    t: &Transport,
    singer_id: &str,
    pagesize: u32,
    sort: &str,
) -> Result<Vec<String>> {
    let resp = t
        .send(build_artist_audios(t, singer_id, pagesize, sort))
        .await?;

    // data 直接是数组
    Ok(resp
        .data()
        .as_array()
        .map(|arr| {
            arr.iter()
                .filter_map(|i| i.get("hash").and_then(|v| v.as_str()).map(str::to_string))
                .collect()
        })
        .unwrap_or_default())
}

/// 歌手专辑
///
/// 对应 Dart 的 `getSingerAlbum(singerId)`。
///
/// ⚠️ `sort` 的取值与 [`artist_audios`] **不同**：这里 `"hot"` → 上游 `3`，默认 → `1`。
/// 这是上游 API 的不一致，不要「统一」。
/// 构造「歌手专辑」请求
pub(crate) fn build_artist_albums(singer_id: &str, pagesize: u32, sort: &str) -> RequestOptions {
    let body = json!({
        "author_id": singer_id,
        "pagesize": if pagesize == 0 { 30 } else { pagesize },
        "page": 1,
        "sort": if sort == "hot" { 3 } else { 1 },
        "category": 1,
        "area_code": "all"
    });

    RequestOptions::post("/kmr/v1/author/albums")
        .router("openapi.kugou.com")
        .header("kg-tid", "36")
        .json_body(&body)
}

pub async fn artist_albums(
    t: &Transport,
    singer_id: &str,
    pagesize: u32,
    sort: &str,
) -> Result<Vec<Album>> {
    let resp = t
        .send(build_artist_albums(singer_id, pagesize, sort))
        .await?;

    Ok(resp
        .data()
        .as_array()
        .map(|arr| {
            arr.iter()
                .map(|i| Album {
                    album: str_of(i, "album_name"),
                    album_id: num_of(i, "album_id"),
                    singer: str_of(i, "author_name"),
                    cover: crate::models::get_cover(&str_of(i, "sizable_cover"), "500"),
                    audio_count: i.get("song_count").and_then(|v| v.as_i64()).unwrap_or(0),
                })
                .collect()
        })
        .unwrap_or_default())
}

/// 歌手详情
///
/// 对应 Dart 的 `getSingerDetails(singerId)`。
/// 构造「歌手详情」请求
pub(crate) fn build_artist_detail(singer_id: &str) -> RequestOptions {
    let body = json!({ "author_id": singer_id });

    RequestOptions::post("/kmr/v3/author")
        .router("openapi.kugou.com")
        .header("kg-tid", "36")
        .json_body(&body)
}

pub async fn artist_detail(t: &Transport, singer_id: &str) -> Result<Singer> {
    let resp = t.send(build_artist_detail(singer_id)).await?;

    let d = resp.data();
    Ok(Singer {
        singer: str_of(d, "author_name"),
        // ⚠️ author_id 是数字
        singer_id: num_of(d, "author_id"),
        cover: crate::models::get_cover(&str_of(d, "sizable_avatar"), "500"),
        audio_count: d.get("song_count").and_then(|v| v.as_i64()).unwrap_or(0),
        album_count: d.get("album_count").and_then(|v| v.as_i64()).unwrap_or(0),
    })
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
