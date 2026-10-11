//! VIP 相关（概念版 youth 业务）
//!
//! 对应 `KuGou.dart` 的 `getVip` / `getVip8`。

use crate::request::{now_millis, RequestOptions, Transport};
use crate::{Error, Result};
use serde_json::json;

/// 领取每日 VIP
///
/// 对应 Dart 的 `getVip()` 里的 `/youth/day/vip`。
///
/// `receive_day` 必须是**北京时间日期**（`YYYY-MM-DD`）。
/// 用 [`beijing_date`] 生成，避免跨日时段取错日期。
///
/// ⚠️ 原实现声明了 `x-www-form-urlencoded` 但参数在 query，请求体为空。
pub async fn youth_day_vip(t: &Transport, receive_day: &str) -> Result<()> {
    t.send(
        RequestOptions::post("/youth/v1/recharge/receive_vip_listen_song")
            .header("content-type", "application/x-www-form-urlencoded")
            .param("source_id", 90139)
            .param("receive_day", receive_day),
    )
    .await?;
    Ok(())
}

/// 升级 VIP
///
/// 对应 Dart 的 `getVip()` 里的 `/youth/day/vip/upgrade`。无业务参数。
pub async fn youth_day_vip_upgrade(t: &Transport) -> Result<()> {
    let kugouid: i64 = t.account.userid.parse().unwrap_or(0);
    t.send(
        RequestOptions::post("/youth/v1/listen_song/upgrade_vip_reward")
            .param("kugouid", kugouid)
            .param("ad_type", 1),
    )
    .await?;
    Ok(())
}

/// 广告上报换 VIP
///
/// 对应 Dart 的 `getVip8()`（连调 8 次，每次间隔 15 秒）。
///
/// ⚠️ `play_start` 固定为 `play_end - 30 秒` —— 假装播放了 30 秒广告。
/// ⚠️ 次数用光时 `status` **仍是 1**，靠 `error_msg == "今天次数已用光"` 区分。
/// ⚠️ body 里的时间戳是**毫秒**，而 query 里的 `clienttime` 是**秒**。
pub async fn youth_vip(t: &Transport) -> Result<()> {
    let now = now_millis();
    let body = json!({
        "ad_id": 12307537187i64,
        "play_start": now - 30_000,
        "play_end": now
    });

    t.send(
        RequestOptions::post("/youth/v1/ad/play_report")
            .header("Content-Type", "application/json")
            .json_body(&body),
    )
    .await?;
    Ok(())
}

/// 连调 `youth_vip` 直到次数用光或达到上限
///
/// 对应 Dart 的 `getVip8()`：默认 8 次，每次间隔 15 秒（模拟真实观看广告）。
///
/// 返回实际成功次数。
pub async fn youth_vip_batch(t: &Transport, times: u32, interval_secs: u64) -> Result<u32> {
    let times = if times == 0 { 8 } else { times };
    let mut done = 0u32;

    for _ in 0..times {
        match youth_vip(t).await {
            Ok(()) => done += 1,
            Err(e) => {
                // 次数用光：正常终止
                if is_quota_exhausted(&e) {
                    return Ok(done);
                }
                // 其他错误：不中断，继续尝试
            }
        }
        if interval_secs > 0 {
            tokio::time::sleep(std::time::Duration::from_secs(interval_secs)).await;
        }
    }
    Ok(done)
}

/// 判断错误是否为「今天次数已用光」
pub fn is_quota_exhausted(e: &Error) -> bool {
    match e.api_message() {
        Some(msg) => msg.contains("次数已用光") || msg.contains("次数已用完"),
        None => false,
    }
}

/// 取北京时间的 `YYYY-MM-DD`
///
/// 对应 Dart 的 `DateTime.now().toUtc().add(Duration(hours: 8))`。
/// 直接用本地时区会在跨日时段（UTC 16:00 = 北京次日 00:00）取错日期。
pub fn beijing_date() -> String {
    let secs = crate::request::now_secs() + 8 * 3600;
    let (y, m, d) = civil_from_days(secs.div_euclid(86_400));
    format!("{y:04}-{m:02}-{d:02}")
}

/// 把「1970-01-01 起的天数」转成 (年, 月, 日)
///
/// Howard Hinnant 的 `civil_from_days` 算法。
fn civil_from_days(z: i64) -> (i64, u32, u32) {
    let z = z + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = (z - era * 146_097) as u64;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe as i64 + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32;
    (if m <= 2 { y + 1 } else { y }, m, d)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn civil_conversion_known_dates() {
        assert_eq!(civil_from_days(0), (1970, 1, 1));
        // 2000-01-01 是第 10957 天
        assert_eq!(civil_from_days(10957), (2000, 1, 1));
    }

    #[test]
    fn beijing_date_format() {
        let d = beijing_date();
        assert_eq!(d.len(), 10);
        assert_eq!(&d[4..5], "-");
        assert_eq!(&d[7..8], "-");
    }
}
