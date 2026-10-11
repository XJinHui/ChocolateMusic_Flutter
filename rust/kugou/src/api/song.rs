//! 歌曲相关：播放地址、详情、歌词
//!
//! 对应 `KuGou.dart` 的 `getMusicUrl` / `getMusicsDetails` / `getAlbumAudioId` /
//! `getLyric` / `chooseMusicQuality`。

use crate::crypto::random_string;
use crate::lyric::process_lyric;
use crate::platform::Platform;
use crate::request::{RequestOptions, Transport};
use crate::{Error, Result};
use serde_json::{json, Value};

/// 需要加 `magic_` 前缀的魔法音效
const MAGIC_QUALITIES: &[&str] = &[
    "piano",
    "acappella",
    "subwoofer",
    "ancient",
    "dj",
    "surnay",
];

/// 归一化音质参数
///
/// 对应 Dart 里传入 `quality` 前的处理：魔法音效会加 `magic_` 前缀。
pub fn normalize_quality(q: &str) -> String {
    if MAGIC_QUALITIES.contains(&q) {
        format!("magic_{q}")
    } else {
        q.to_string()
    }
}

/// 获取音乐播放地址
///
/// 对应 Dart 的 `getMusicUrl(musicId, bitrate:)` 与 `chooseMusicQuality`。
///
/// ```text
/// GET https://gateway.kugou.com/v5/url
/// x-router: trackercdn.kugou.com
/// ```
///
/// ⚠️ 使用前需先调 [`register_dev`](crate::api::login::register_dev) 获取 `dfid`，
/// 否则会提示「本次请求需要验证」。
///
/// 返回播放地址；无版权或需 VIP 时返回空字符串。
/// 构造「获取音乐播放地址」请求
pub(crate) fn build_song_url(t: &Transport, hash: &str, quality: &str) -> RequestOptions {
    let is_lite = t.platform == Platform::Lite;

    let page_id = if is_lite { 967177915 } else { 151369488 };
    let ppage_id = if is_lite {
        "356753938,823673182,967485191"
    } else {
        "463467626,350369493,788954147"
    };
    let pid = if is_lite { 411 } else { 2 };

    let q = if quality.is_empty() { "128" } else { quality };

    RequestOptions::get("/v5/url")
        .router("trackercdn.kugou.com")
        .encrypt_key(true)
        .param("album_id", 0)
        .param("area_code", 1)
        .param("hash", hash.to_lowercase())
        .param("ssa_flag", "is_fromtrack")
        .param("version", 11430)
        .param("page_id", page_id)
        .param("quality", normalize_quality(q))
        .param("album_audio_id", 0)
        .param("behavior", "play")
        .param("pid", pid)
        .param("cmd", 26)
        .param("pidversion", 3001)
        .param("IsFreePart", 0)
        .param("ppage_id", ppage_id)
        .param("cdnBackup", 1)
        .param("module", "")
        // ⚠️ 覆盖默认的 clientver
        .param("clientver", 11430)
}

pub async fn song_url(t: &Transport, hash: &str, quality: &str) -> Result<String> {
    let resp = t.send(build_song_url(t, hash, quality)).await?;

    // ⚠️ 播放地址在**顶层** `url` 数组，不在 `data` 下
    Ok(resp
        .body
        .get("url")
        .and_then(|v| v.as_array())
        .and_then(|a| a.first())
        .and_then(|v| v.as_str())
        .unwrap_or_default()
        .to_string())
}

/// 一次请求批量取多个 hash 的播放地址
///
/// 上游一次只接受一个 hash，这里并发发起。
pub async fn song_urls(
    t: &Transport,
    hashes: &[String],
    quality: &str,
) -> Vec<(String, Result<String>)> {
    let futs = hashes.iter().map(|h| {
        let h = h.clone();
        async move {
            let r = song_url(t, &h, quality).await;
            (h, r)
        }
    });
    futures_join(futs).await
}

/// 歌曲详情（批量）
///
/// 对应 Dart 的 `getMusicsDetails(ids)` 的前半部分（`/privilege/lite`）。
///
/// 返回上游的原始 `data` 数组，字段说明见 `docs/rewrite/api/endpoints/privilege_lite.md`。
/// 构造「歌曲详情（批量）」请求
pub(crate) fn build_privilege_lite(t: &Transport, hashes: &[String]) -> RequestOptions {
    let resource: Vec<Value> = hashes
        .iter()
        .map(|h| json!({ "type": "audio", "page_id": 0, "hash": h, "album_id": 0 }))
        .collect();

    let body = json!({
        "appid": t.platform.appid(),
        "area_code": 1,
        "behavior": "play",
        "clientver": t.platform.clientver(),
        "need_hash_offset": 1,
        "relate": 1,
        "support_verify": 1,
        "resource": resource,
        "qualities": [
            "128", "320", "flac", "high",
            "viper_atmos", "viper_tape", "viper_clear", "super", "multitrack"
        ]
    });

    RequestOptions::post("/v2/get_res_privilege/lite")
        .router("media.store.kugou.com")
        .header("Content-Type", "application/json")
        .json_body(&body)
}

pub async fn privilege_lite(t: &Transport, hashes: &[String]) -> Result<Vec<Value>> {
    if hashes.is_empty() {
        return Ok(Vec::new());
    }

    let resp = t.send(build_privilege_lite(t, hashes)).await?;

    Ok(resp.data().as_array().cloned().unwrap_or_default())
}

/// `album_audio_id` → 专辑 / 歌手 ID
///
/// 对应 Dart 的 `getAlbumAudioId(ids)`。
///
/// 返回 `(album_audio_id, album_id, singer_id)` 三元组列表。
/// 构造「`album_audio_id` → 专辑 / 歌手 ID」请求
pub(crate) fn build_krm_audio(
    album_audio_ids: &[String],
    fields: &str,
) -> RequestOptions {
    let data: Vec<Value> = album_audio_ids
        .iter()
        .filter_map(|s| s.parse::<i64>().ok())
        .map(|id| json!({ "entity_id": id }))
        .collect();

    let body = json!({
        "data": data,
        "fields": if fields.is_empty() { "base" } else { fields }
    });

    RequestOptions::post("/kmr/v2/audio")
        .router("openapi.kugou.com")
        .header("KG-TID", "238")
        .json_body(&body)
}

pub async fn krm_audio(
    t: &Transport,
    album_audio_ids: &[String],
    fields: &str,
) -> Result<Vec<(String, String, String)>> {
    if album_audio_ids.is_empty() {
        return Ok(Vec::new());
    }

    let resp = t.send(build_krm_audio(album_audio_ids, fields)).await?;

    let out = resp
        .data()
        .as_array()
        .map(|arr| {
            arr.iter()
                .filter_map(|item| {
                    let aaid = item.pointer("/base/album_audio_id")?.as_i64()?;
                    let album_id = item
                        .pointer("/base/album_id")
                        .map(value_to_string)
                        .unwrap_or_default();
                    let singer_id = item
                        .pointer("/authors/0/base/author_id")
                        .map(value_to_string)
                        .unwrap_or_default();
                    Some((aaid.to_string(), album_id, singer_id))
                })
                .collect()
        })
        .unwrap_or_default();

    Ok(out)
}

/// 歌词搜索结果
#[derive(Debug, Clone, Default)]
pub struct LyricCandidate {
    pub id: String,
    pub accesskey: String,
    pub song: String,
    pub singer: String,
    pub duration: i64,
}

/// 搜索歌词，拿到 `id` 与 `accesskey`
///
/// 对应 Dart 的 `getLyric(musicId)` 的第一步。
///
/// ⚠️ 本接口成功码是 **200**（其他接口是 1）。
/// 构造「搜索歌词」请求
pub(crate) fn build_search_lyric(t: &Transport, hash: &str) -> RequestOptions {
    RequestOptions::get("/v1/search")
        .base_url("https://lyrics.kugou.com")
        .clear_default_params(true)
        .param("album_audio_id", 0)
        .param("appid", t.platform.appid())
        .param("clientver", t.platform.clientver())
        .param("duration", 0)
        .param("hash", hash)
        .param("keyword", "")
        .param("lrctxt", 1)
        .param("man", "no")
}

pub async fn search_lyric(t: &Transport, hash: &str) -> Result<Vec<LyricCandidate>> {
    let resp = t.send(build_search_lyric(t, hash)).await?;

    let out = resp
        .body
        .get("candidates")
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|c| {
                    Some(LyricCandidate {
                        id: c.get("id").map(value_to_string)?,
                        accesskey: c.get("accesskey").and_then(|v| v.as_str())?.to_string(),
                        song: c.get("song").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                        singer: c
                            .get("singer")
                            .and_then(|v| v.as_str())
                            .unwrap_or("")
                            .to_string(),
                        duration: c.get("duration").and_then(|v| v.as_i64()).unwrap_or(0),
                    })
                })
                .collect()
        })
        .unwrap_or_default();

    Ok(out)
}

/// 获取歌词文本
///
/// 对应 Dart 的 `getLyric(musicId)`：内部先 [`search_lyric`] 再取歌词。
///
/// `fmt` 传 `"lrc"` 得到纯文本，传 `"krc"` 得到逐字歌词（自动转 LRC 格式）。
/// 返回已清洗的 LRC 文本。
pub async fn lyric(t: &Transport, hash: &str, fmt: &str) -> Result<String> {
    let candidates = search_lyric(t, hash).await?;
    let Some(best) = candidates.first() else {
        return Err(Error::Invalid("未找到歌词".into()));
    };

    let text = lyric_by_id(t, &best.id, &best.accesskey, fmt).await?;
    Ok(process_lyric(&text))
}

/// 构造「按 `id` + `accesskey` 取歌词」请求
pub(crate) fn build_lyric_by_id(id: &str, accesskey: &str, fmt: &str) -> RequestOptions {
    let fmt = if fmt.is_empty() { "lrc" } else { fmt };

    RequestOptions::get("/download")
        .base_url("https://lyrics.kugou.com")
        .param("ver", 1)
        .param("client", "android")
        .param("id", id)
        .param("accesskey", accesskey)
        .param("fmt", fmt)
        .param("charset", "utf8")
        .param("decode", "true")
}

/// 按 `id` + `accesskey` 取歌词
///
/// 返回**加了 `decodeContent` 字段的完整响应体** —— 与原服务器的行为一致
/// （服务器在 `?decode=true` 时把解码结果挂在 `decodeContent` 上，`content` 保留）。
pub(crate) async fn lyric_by_id_body(
    t: &Transport,
    id: &str,
    accesskey: &str,
    fmt: &str,
) -> Result<Value> {
    let fmt = if fmt.is_empty() { "lrc" } else { fmt };

    let resp = t.send(build_lyric_by_id(id, accesskey, fmt)).await?;

    let content = resp
        .str_at(&["content"])
        .ok_or_else(|| Error::Invalid(format!("歌词响应无 content: {}", resp.body)))?;

    // contenttype != 0 表示明文；否则是 KRC
    let contenttype = resp.i64_at(&["contenttype"]).unwrap_or(0);
    let decoded = if fmt == "lrc" || contenttype != 0 {
        base64_decode_to_string(&content)
    } else {
        let raw = base64_decode(&content);
        decode_krc(&raw)
    };

    let mut body = resp.body.clone();
    body["decodeContent"] = Value::String(decoded);
    Ok(body)
}

/// 按 `id` + `accesskey` 取歌词原文
///
/// 对应 Dart 里第二次 `dio.get('/lyric?...')`。
pub async fn lyric_by_id(
    t: &Transport,
    id: &str,
    accesskey: &str,
    fmt: &str,
) -> Result<String> {
    let body = lyric_by_id_body(t, id, accesskey, fmt).await?;
    Ok(body
        .get("decodeContent")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string())
}

/// KRC 解码：跳过 4 字节头 → XOR → zlib 解压
///
/// ```text
/// KEY = [64, 71, 97, 119, 94, 50, 116, 71, 81, 54, 49, 45, 206, 210, 110, 105]
/// ```
pub fn decode_krc(bytes: &[u8]) -> String {
    const KEY: [u8; 16] = [64, 71, 97, 119, 94, 50, 116, 71, 81, 54, 49, 45, 206, 210, 110, 105];

    if bytes.len() <= 4 {
        return String::new();
    }

    // ⚠️ 不要原地修改传入的切片
    let mut buf: Vec<u8> = bytes[4..].to_vec();
    for (i, b) in buf.iter_mut().enumerate() {
        *b ^= KEY[i % KEY.len()];
    }

    match inflate_zlib(&buf) {
        Some(text) => text,
        None => String::new(),
    }
}

// ============================================================
//  内部工具
// ============================================================

fn value_to_string(v: &Value) -> String {
    match v {
        Value::String(s) => s.clone(),
        other => other.to_string(),
    }
}

fn base64_decode(s: &str) -> Vec<u8> {
    use base64::Engine;
    base64::engine::general_purpose::STANDARD
        .decode(s)
        .unwrap_or_default()
}

fn base64_decode_to_string(s: &str) -> String {
    String::from_utf8_lossy(&base64_decode(s)).to_string()
}

/// zlib 解压（`flate2` 的 ZlibDecoder 即带 2 字节头 + Adler-32 校验）
fn inflate_zlib(data: &[u8]) -> Option<String> {
    use std::io::Read;
    let mut d = flate2::read::ZlibDecoder::new(data);
    let mut out = Vec::new();
    d.read_to_end(&mut out).ok()?;
    Some(String::from_utf8_lossy(&out).to_string())
}

/// 顺序等待一组 future（无 futures crate 依赖的简易 join）
async fn futures_join<F, T>(futs: impl Iterator<Item = F>) -> Vec<T>
where
    F: std::future::Future<Output = T>,
{
    let mut out = Vec::new();
    for f in futs {
        out.push(f.await);
    }
    out
}

/// 生成随机 `dfid`（24 位），供部分接口使用
pub fn random_dfid() -> String {
    random_string(24).to_lowercase()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn magic_prefix_applied() {
        assert_eq!(normalize_quality("piano"), "magic_piano");
        assert_eq!(normalize_quality("dj"), "magic_dj");
    }

    #[test]
    fn normal_quality_untouched() {
        assert_eq!(normalize_quality("320"), "320");
        assert_eq!(normalize_quality("flac"), "flac");
    }

    #[test]
    fn krc_decode_handles_short_input() {
        assert_eq!(decode_krc(&[1, 2, 3]), "");
    }
}
