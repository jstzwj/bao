// 严格翻译自: src/http_jsc/method_jsc.zig
//! JSC bridge for `bun.http.Method`. Keeps `src/http_types/` free of JSC types.
package bao_http_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// MethodJSC - Method 的 JSC 桥接
// ============================================================================

// Stub: 原为 extern "c" 声明，仓颉中替换为 stub 实现
public func Bun__HTTPMethod__toJS(method: UInt8, globalObject: JsObject): JsValue {
    return JsValue.jsUndefined()
}

/// 将 HTTP Method 转换为 JS - 严格对应 Bun toJS
public func methodToJS(method: UInt8, globalObject: JsObject): JsValue {
    return Bun__HTTPMethod__toJS(method, globalObject)
}
