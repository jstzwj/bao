// 严格翻译自: src/http_jsc/fetch_enums_jsc.zig
//! JSC bridges for the small `http_types/Fetch*` enums.
package bao_http_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// FetchEnumsJSC - Fetch 枚举的 JSC 桥接
// ============================================================================

/// 将 FetchRedirect 转换为 JS
public func fetchRedirectToJS(val: UInt8, global: JsObject): JsValue {
    match (val) {
        case 0 => return JsValue("follow")
        case 1 => return JsValue("error")
        case 2 => return JsValue("manual")
        case _ => return JsValue.jsUndefined()
    }
}

/// 将 FetchRequestMode 转换为 JS
public func fetchRequestModeToJS(val: UInt8, global: JsObject): JsValue {
    match (val) {
        case 0 => return JsValue("navigate")
        case 1 => return JsValue("same-origin")
        case 2 => return JsValue("no-cors")
        case 3 => return JsValue("cors")
        case _ => return JsValue.jsUndefined()
    }
}

/// 将 FetchCacheMode 转换为 JS
public func fetchCacheModeToJS(val: UInt8, global: JsObject): JsValue {
    match (val) {
        case 0 => return JsValue("default")
        case 1 => return JsValue("no-store")
        case 2 => return JsValue("reload")
        case 3 => return JsValue("no-cache")
        case 4 => return JsValue("force-cache")
        case 5 => return JsValue("only-if-cached")
        case _ => return JsValue.jsUndefined()
    }
}
