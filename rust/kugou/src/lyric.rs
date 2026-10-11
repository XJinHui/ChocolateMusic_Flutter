//! 歌词处理
//!
//! 对应 Dart 的 `processLyric` / `krcToLrc` / `msToLrcTime`。

/// 清洗 LRC：只保留含时间标签的行，剔除 `[ti:]`、`[ar:]`、`[by:]` 等元数据
///
/// 时间标签格式：`[mm:ss.xx]` 或 `[mm:ss.xxx]`
pub fn process_lyric(lrc: &str) -> String {
    if lrc.is_empty() {
        return String::new();
    }
    lrc.lines()
        .filter(|line| has_time_tag(line.trim()))
        .collect::<Vec<_>>()
        .join("\n")
}

/// 判断一行是否含 `[mm:ss.xx]` 或 `[mm:ss.xxx]` 时间标签
fn has_time_tag(line: &str) -> bool {
    let b = line.as_bytes();
    let mut i = 0;
    while i + 9 < b.len() {
        if b[i] == b'['
            && b[i + 3] == b':'
            && b[i + 6] == b'.'
            && b[i + 1].is_ascii_digit()
            && b[i + 2].is_ascii_digit()
            && b[i + 4].is_ascii_digit()
            && b[i + 5].is_ascii_digit()
        {
            // 小数点后至少 2 位数字
            let d7 = b.get(i + 7).copied().unwrap_or(0);
            let d8 = b.get(i + 8).copied().unwrap_or(0);
            if d7.is_ascii_digit() && d8.is_ascii_digit() {
                return true;
            }
        }
        i += 1;
    }
    false
}

/// 毫秒 → LRC 时间格式 `mm:ss.xx`
///
/// 对应 Dart 的 `msToLrcTime`（取厘秒，即毫秒的百分位）
pub fn ms_to_lrc_time(ms: i64) -> String {
    let minutes = ms / 60_000;
    let seconds = (ms % 60_000) / 1_000;
    let centis = (ms % 1_000) / 10;
    format!("{minutes:02}:{seconds:02}.{centis:02}")
}

/// KRC → LRC 转换
///
/// KRC 格式：
/// - 行级：`[开始毫秒,持续毫秒]句子内容`
/// - 逐字：`<偏移毫秒,持续毫秒,?>字符`
///
/// 转换后每行形如 `[mm:ss.xx]<mm:ss.xx>字<mm:ss.xx>字…`
pub fn krc_to_lrc(krc: &str) -> String {
    let mut out = String::new();

    for line in krc.lines() {
        // 匹配 [数字,数字]
        let Some(open) = line.find('[') else { continue };
        let Some(close_rel) = line[open..].find(']') else {
            continue;
        };
        let close = open + close_rel;
        let header = &line[open + 1..close];

        let Some((start_str, _dur)) = header.split_once(',') else {
            continue;
        };
        let Ok(start_ms) = start_str.trim().parse::<i64>() else {
            continue;
        };

        let sentence = &line[close + 1..];
        let mut chars = String::new();

        // 逐个解析 <偏移,持续,?>字符
        let mut rest = sentence;
        while let Some(lt) = rest.find('<') {
            let Some(gt_rel) = rest[lt..].find('>') else { break };
            let gt = lt + gt_rel;
            let tag = &rest[lt + 1..gt];
            let after = &rest[gt + 1..];

            // 字符直到下一个 '<'
            let next = after.find('<').unwrap_or(after.len());
            let ch = &after[..next];

            if !ch.is_empty() {
                if let Some(off_str) = tag.split(',').next() {
                    if let Ok(offset) = off_str.trim().parse::<i64>() {
                        chars.push_str(&format!(
                            "<{}>{}",
                            ms_to_lrc_time(start_ms + offset),
                            ch
                        ));
                    }
                }
            }
            rest = &after[next..];
        }

        out.push_str(&format!("[{}]{}\n", ms_to_lrc_time(start_ms), chars));
    }

    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn filters_metadata_lines() {
        let input = "[ti:标题]\n[ar:歌手]\n[00:01.23]第一句\n[00:05.678]第二句\n";
        let got = process_lyric(input);
        assert_eq!(got, "[00:01.23]第一句\n[00:05.678]第二句");
    }

    #[test]
    fn keeps_2_and_3_digit_millis() {
        assert!(has_time_tag("[00:01.23]x"));
        assert!(has_time_tag("[00:01.234]x"));
        assert!(!has_time_tag("[ti:x]"));
        assert!(!has_time_tag("[00:01]x"));
    }

    #[test]
    fn ms_conversion() {
        assert_eq!(ms_to_lrc_time(0), "00:00.00");
        assert_eq!(ms_to_lrc_time(1_234), "00:01.23");
        assert_eq!(ms_to_lrc_time(61_990), "01:01.99");
    }

    #[test]
    fn krc_conversion() {
        let krc = "[1000,500]<0,100,0>你<100,100,0>好";
        let lrc = krc_to_lrc(krc);
        assert_eq!(lrc.trim(), "[00:01.00]<00:01.00>你<00:01.10>好");
    }
}
