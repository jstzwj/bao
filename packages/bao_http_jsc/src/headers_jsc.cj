// 严格翻译自: src/http_jsc/headers_jsc.zig
//! JSC bridges for headers. Keeps `src/http/` free of JSC types.
package bao_http_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// HeadersJSC - Headers 的 JSC 桥接 (stub)
// ============================================================================

/// 将 Headers 转换为 FetchHeaders (stub)
public func headersToFetchHeaders(entries: Array<HTTPHeader>, global: JsObject): JsValue {
    return JsValue.jsUndefined()
}

/// H2 测试 API
public class H2TestingAPIs {
    public static func liveCounts(globalThis: JsObject, _: CallFrame): JsValue {
        let obj = JsValue.createEmptyObject(globalThis, 2)
        obj.put(globalThis, "sessions", JsValue.jsNumber(0))
        obj.put(globalThis, "streams", JsValue.jsNumber(0))
        return obj
    }
}

/// H3 测试 API
public class H3TestingAPIs {
    public static func quicLiveCounts(globalThis: JsObject, _: CallFrame): JsValue {
        let obj = JsValue.createEmptyObject(globalThis, 2)
        obj.put(globalThis, "sessions", JsValue.jsNumber(0))
        obj.put(globalThis, "streams", JsValue.jsNumber(0))
        return obj
    }
}

/// HTTP 头部 (simple data class)
public class HTTPHeader {
    public var name: String
    public var value: String
    public init() { name = ""; value = "" }
    public init(name: String, value: String) { this.name = name; this.value = value }
}
