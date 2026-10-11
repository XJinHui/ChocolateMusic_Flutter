//! 广告免费听（3 条路由，全部 xeapi）
//!
//! | 路由 | 上游 | checkToken |
//! | --- | --- | :-: |
//! | `/ad/get` | `/api/ad/get` | 🛡 v3 |
//! | `/ad/listening/rights` | `/api/ad/homepage/free/tab/extend/v2` | |
//! | `/ad/listening/rights/gain` | `/api/ad/listening/rights/gain` | 🛡 v3 |
//!
//! 客户端 `getFreeDuration()` 的流程：
//!
//! ```text
//! /ad/get               → 拿广告，取 ads['400002_0'].id
//! /ad/listening/rights/gain?reqUid=<id>   → 领取免费时长
//! /ad/listening/rights  → 读 data.rightsRemainingTime
//! ```
//!
//! ⚠️ **客户端传的 `reqUid` 是广告的 `id`，不是 `req_id`** ——
//! 服务端的自动补齐逻辑本来会去取 `req_id`，但客户端传了非空值就把它**短路**了。
//! 这里保留原行为（传什么用什么）。

use serde_json::{json, Map, Value};

use crate::api::{ServerRequest, ServerResponse};
use crate::{now_ms, Query, Result};

// ============================================================
//  /ad/get
// ============================================================

/// 获取广告
///
/// 响应是**重建**的，不是上游 body：
///
/// ```json
/// { "code": 200, "ads": <上游 ads 或 null>, "message": ..., "extra": { "reqId": ... } }
/// ```
///
/// ⚠️ 客户端读 `response.data['ads']['400002_0']['id']` —— 用的是 `ads`，**不是** `extra.reqId`。
pub async fn ad_get(t: &ServerRequest<'_>, type_ids: &str) -> Result<ServerResponse> {
    let type_ids = if type_ids.is_empty() {
        r#"["400002_0"]"#
    } else {
        type_ids
    };

    let r = t
        .send_xeapi_checked("/api/ad/get", json!({ "type_ids": type_ids }))
        .await?;

    let raw = &r.body;

    Ok(ServerResponse::new(
        json!({
            "code": 200,
            "ads": raw.get("ads").cloned().unwrap_or(Value::Null),
            "message": raw.get("message").cloned().unwrap_or(Value::Null),
            "extra": { "reqId": extract_req_id(raw) },
        }),
        r.cookies,
    ))
}

/// 从广告对象里按四级兜底提取 `req_id`
///
/// 顺序：`extJson.contextInfo.req_id` → `adExtMap.req_id` → `adLogId.requestId`
/// → `ad.reqId` → `extJson.contextInfo.req_id`（字符串形态）
fn extract_req_id(raw: &Value) -> String {
    let Some(ad) = first_ad(raw) else {
        return String::new();
    };

    let ext = obj_of(ad.get("extJson"));
    let ext_map = obj_of(ad.get("adExtMap"));

    // 1. extJson.contextInfo.req_id
    if let Some(v) = ext
        .as_ref()
        .and_then(|e| e.pointer("/contextInfo/req_id"))
        .and_then(Value::as_str)
    {
        if !v.is_empty() {
            return v.to_string();
        }
    }
    // 2. adExtMap.req_id
    if let Some(v) = ext_map
        .as_ref()
        .and_then(|e| e.get("req_id"))
        .and_then(Value::as_str)
    {
        if !v.is_empty() {
            return v.to_string();
        }
    }
    // 3. adLogId.requestId
    if let Some(v) = ad.pointer("/adLogId/requestId").and_then(Value::as_str) {
        if !v.is_empty() {
            return v.to_string();
        }
    }
    // 4. ad.reqId
    if let Some(v) = ad.get("reqId").and_then(Value::as_str) {
        if !v.is_empty() {
            return v.to_string();
        }
    }
    // 5. 兜底：extra.reqId（ad_get 自己算出来的那个）
    raw.pointer("/extra/reqId")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string()
}

/// 取 `ads` 对象的第一个值（对应 `Object.values(ads)[0]`）
fn first_ad(raw: &Value) -> Option<&Value> {
    raw.get("ads")
        .and_then(Value::as_object)
        .and_then(|o| o.values().next())
}

/// 字段可能是 JSON 字符串，也可能是对象 —— 统一成 `Value::Object`
fn obj_of(v: Option<&Value>) -> Option<Value> {
    match v? {
        Value::Object(_) => v.cloned(),
        Value::String(s) => {
            let parsed: Value = serde_json::from_str(s).ok()?;
            parsed.is_object().then_some(parsed)
        }
        _ => None,
    }
}

/// 字段可能是 JSON 字符串，也可能是对象 —— 统一成字符串
fn stringify_of(v: Option<&Value>) -> Option<String> {
    match v? {
        Value::String(s) if !s.is_empty() => Some(s.clone()),
        Value::Null => None,
        other => Some(other.to_string()),
    }
}

// ============================================================
//  /ad/listening/rights
// ============================================================

/// 查询免费听时长状态
///
/// ⚠️ 客户端读 `response.data['data']['rightsRemainingTime']`（毫秒）
/// 与 `['data']['rightsUpperLimit']`（布尔）。
pub async fn ad_listening_rights(t: &ServerRequest<'_>) -> Result<ServerResponse> {
    let r = t
        .send_xeapi(
            "/api/ad/homepage/free/tab/extend/v2",
            json!({ "entrance": "FREE_LISTEN_RN" }),
        )
        .await?;
    Ok(ServerResponse::passthrough(r))
}

// ============================================================
//  /ad/listening/rights/gain
// ============================================================

/// 领取免费听权益
///
/// 上游要的是 `reqParam` = **一个 21 字段对象的 JSON 字符串**。
/// 大部分字段由服务端自动从 [`ad_get`] 补齐。
///
/// 响应被包一层：`{ code: 200, data: <上游 body> }` ——
/// 客户端读 `response.data['data']['data']['gainFlag']`。
pub async fn ad_listening_rights_gain(
    t: &ServerRequest<'_>,
    query: &Query,
) -> Result<ServerResponse> {
    let time = now_ms();

    let mut req_uid = s(query, "reqUid").to_string();
    let mut context_info = query.get("contextInfo").cloned();
    let mut creative_type: Option<Value> = query.get("creativeType").map(|v| json!(v));
    let mut general_rights_info = query.get("generalRightsInfo").cloned();

    // `hint`：广告下发的领取配置，用作兜底
    let mut hint: Map<String, Value> = Map::new();

    // ⚠️ 只有「缺 reqUid / 缺 contextInfo / 缺 creativeType」时才去拉广告。
    //    客户端总会传 reqUid，所以这里通常**不会**触发（与原实现一致）。
    if req_uid.is_empty() || context_info.is_none() || creative_type.is_none() {
        let type_ids = if s(query, "type_ids").is_empty() {
            r#"["400002_0"]"#
        } else {
            s(query, "type_ids")
        };

        if let Ok(ad_res) = ad_get(t, type_ids).await {
            if let Some(ad) = first_ad(&ad_res.body) {
                let ext = obj_of(ad.get("extJson"));
                let ext_map = obj_of(ad.get("adExtMap"));

                if req_uid.is_empty() {
                    req_uid = [
                        ext.as_ref()
                            .and_then(|e| e.pointer("/contextInfo/req_id"))
                            .and_then(Value::as_str),
                        ext_map
                            .as_ref()
                            .and_then(|e| e.get("req_id"))
                            .and_then(Value::as_str),
                        ad.pointer("/adLogId/requestId").and_then(Value::as_str),
                        ad.get("reqId").and_then(Value::as_str),
                        ad_res.body.pointer("/extra/reqId").and_then(Value::as_str),
                    ]
                    .into_iter()
                    .flatten()
                    .find(|v| !v.is_empty())
                    .unwrap_or("")
                    .to_string();
                }

                if context_info.is_none() {
                    context_info = stringify_of(
                        ext.as_ref()
                            .and_then(|e| e.get("contextInfo"))
                            .or_else(|| ad.pointer("/adLogId/contextInfo"))
                            .or_else(|| ad.get("showContext")),
                    );
                }

                if creative_type.is_none() {
                    creative_type = ad.get("creativeType").cloned();
                }

                if general_rights_info.is_none() {
                    general_rights_info = stringify_of(ad.get("generalRightsInfo"));
                }

                // hint = listeningRightHintInfo ⊕ generalRightsInfo
                let hint_cfg = obj_of(ad.get("listeningRightHintInfo"));
                let gri = obj_of(ad.get("generalRightsInfo"));
                for src in [hint_cfg, gri].into_iter().flatten() {
                    if let Some(o) = src.as_object() {
                        hint.extend(o.clone());
                    }
                }
            }
        }
    }

    let rights_gain_method = int_or(query, "rightsGainMethod")
        .or_else(|| hint_int(&hint, "rightsGainMethod"))
        .unwrap_or(2);

    // ⚠️ 字段顺序必须与 `ad_listening_rights_gain.js` 一致 ——
    //    它会被 JSON.stringify 成 reqParam 发给上游。
    let mut p = Map::new();
    p.insert("reqUid".into(), json!(req_uid));
    p.insert(
        "exposureTime".into(),
        json!(int_or(query, "exposureTime").unwrap_or(time)),
    );
    insert_opt(&mut p, "userId", int_or(query, "uid"));
    p.insert(
        "clickTime".into(),
        json!(int_or(query, "clickTime").unwrap_or(time)),
    );
    insert_opt(
        &mut p,
        "extraRightsType",
        int_or(query, "extraRightsType").or_else(|| hint_int(&hint, "extraRightsType")),
    );
    p.insert(
        "playContinuously".into(),
        json!(truthy(s(query, "playContinuously"))),
    );
    insert_opt(
        &mut p,
        "source",
        int_or(query, "source").or_else(|| hint_int(&hint, "source")),
    );
    p.insert(
        "creativeType".into(),
        json!(creative_type
            .as_ref()
            .and_then(|v| js_int(v))
            .unwrap_or(36)),
    );
    p.insert("rightsGainMethod".into(), json!(rights_gain_method));
    insert_opt(
        &mut p,
        "extraRightsGainMethod",
        int_or(query, "extraRightsGainMethod")
            .or_else(|| hint_int(&hint, "extraRightsGainMethod")),
    );
    insert_opt(
        &mut p,
        "extraRightsGainDuration",
        int_or(query, "extraRightsGainDuration")
            .or_else(|| hint_int(&hint, "extraRightsGainDuration")),
    );
    insert_opt(
        &mut p,
        "nextRightsGainDuration",
        int_or(query, "nextRightsGainDuration")
            .or_else(|| hint_int(&hint, "nextRightsGainDuration")),
    );
    insert_opt(
        &mut p,
        "rightsGainType",
        int_or(query, "rightsGainType").or_else(|| hint_int(&hint, "rightsGainType")),
    );
    insert_opt(
        &mut p,
        "rightsGainDuration",
        int_or(query, "rightsGainDuration").or_else(|| hint_int(&hint, "rightsGainDuration")),
    );
    insert_opt(&mut p, "gainMethodStep", int_or(query, "gainMethodStep"));
    insert_opt(&mut p, "generalRightsInfo", general_rights_info);
    insert_opt(
        &mut p,
        "rightsExtJson",
        query
            .get("rightsExtJson")
            .cloned()
            .or_else(|| hint.get("rightsExtJson").map(js_to_string)),
    );
    insert_opt(
        &mut p,
        "appInfo",
        query.get("appInfo").and_then(|v| serde_json::from_str::<Value>(v).ok()),
    );
    insert_opt(&mut p, "contextInfo", context_info);
    insert_opt(&mut p, "installed", int_or(query, "installed"));
    // sniffTime：只有 rightsGainMethod ∈ {3, 6} 才传
    if rights_gain_method == 3 || rights_gain_method == 6 {
        p.insert(
            "sniffTime".into(),
            json!(int_or(query, "sniffTime").unwrap_or(time)),
        );
    }

    let req_param = serde_json::to_string(&Value::Object(p))
        .map_err(|e| crate::Error::Json(e.to_string()))?;

    let r = t
        .send_xeapi_checked(
            "/api/ad/listening/rights/gain",
            json!({ "reqParam": req_param }),
        )
        .await?;

    Ok(ServerResponse::new(
        json!({ "code": 200, "data": r.body }),
        r.cookies,
    ))
}

// ============================================================
//  内部工具
// ============================================================

fn s<'a>(query: &'a Query, key: &str) -> &'a str {
    query.get(key).map(String::as_str).unwrap_or("")
}

/// `parseInt(x)`，失败返回 `None`
fn int_or(query: &Query, key: &str) -> Option<i64> {
    s(query, key).parse().ok()
}

/// 从 `hint` 里取整数
fn hint_int(hint: &Map<String, Value>, key: &str) -> Option<i64> {
    hint.get(key).and_then(|v| js_int(v))
}

/// 模仿 JS 的 `parseInt(v)`：数字直接用，字符串解析，其他失败
fn js_int(v: &Value) -> Option<i64> {
    match v {
        Value::Number(n) => n.as_i64(),
        Value::String(s) => s.parse().ok(),
        _ => None,
    }
}

fn js_to_string(v: &Value) -> String {
    match v {
        Value::String(s) => s.clone(),
        other => other.to_string(),
    }
}

/// ⚠️ JS 里 `undefined` 的字段会被 `delete` 掉 —— 这里就是不插入
fn insert_opt(map: &mut Map<String, Value>, key: &str, v: Option<impl Into<Value>>) {
    if let Some(v) = v {
        map.insert(key.to_string(), v.into());
    }
}

/// 模仿 JS 的 truthy
fn truthy(v: &str) -> bool {
    !matches!(v, "" | "false" | "0" | "null" | "undefined")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extracts_req_id_from_ext_json() {
        let raw = json!({"ads": {"400002_0": {"extJson": "{\"contextInfo\":{\"req_id\":\"R1\"}}"}}});
        assert_eq!(extract_req_id(&raw), "R1");
    }

    #[test]
    fn extracts_req_id_with_fallbacks() {
        // adLogId.requestId
        let raw = json!({"ads": {"k": {"adLogId": {"requestId": "R2"}}}});
        assert_eq!(extract_req_id(&raw), "R2");
        // ad.reqId
        let raw = json!({"ads": {"k": {"reqId": "R3"}}});
        assert_eq!(extract_req_id(&raw), "R3");
        // extra.reqId
        let raw = json!({"ads": {"k": {}}, "extra": {"reqId": "R4"}});
        assert_eq!(extract_req_id(&raw), "R4");
        // 都没有 → 空
        let raw = json!({"ads": {"k": {}}});
        assert_eq!(extract_req_id(&raw), "");
    }

    #[test]
    fn handles_missing_ads() {
        assert_eq!(extract_req_id(&json!({})), "");
        assert!(first_ad(&json!({"ads": null})).is_none());
    }

    #[test]
    fn obj_of_handles_both_shapes() {
        assert!(obj_of(Some(&json!({"a": 1}))).is_some());
        assert!(obj_of(Some(&json!("{\"a\":1}"))).is_some());
        assert!(obj_of(Some(&json!("not json"))).is_none());
        assert!(obj_of(None).is_none());
    }

    #[test]
    fn js_int_matches_parse_int() {
        assert_eq!(js_int(&json!(42)), Some(42));
        assert_eq!(js_int(&json!("42")), Some(42));
        assert_eq!(js_int(&json!("abc")), None);
        assert_eq!(js_int(&json!(true)), None);
    }

    #[test]
    fn truthy_matches_js() {
        assert!(truthy("true"));
        assert!(truthy("1"));
        assert!(!truthy(""));
        assert!(!truthy("false"));
        assert!(!truthy("0"));
    }
}
