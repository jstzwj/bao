// 严格翻译自: src/http_jsc/method_jsc.zig
//! JSC bridge for `bun.http.Method`. Keeps `src/http_types/` free of JSC types.
package bao_http_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// MethodJSC - Method 的 JSC 桥接
// ============================================================================

// 对应 Bun: extern "c" fn Bun__HTTPMethod__toJS(method: Method, globalObject: *jsc.JSGlobalObject) jsc.JSValue
// 仓颉中无 extern "c" 绑定, 使用纯仓颉实现
public func Bun__HTTPMethod__toJS(method: UInt8, globalObject: JsObject): JsValue {
    // 将方法字节映射到方法名字符串, 再转为 JSValue
    let methodName = when (method) {
        0 => "GET"
        1 => "HEAD"
        2 => "POST"
        3 => "PUT"
        4 => "DELETE"
        5 => "PATCH"
        6 => "OPTIONS"
        7 => "TRACE"
        8 => "CONNECT"
        else => "GET"
    }
    return JsValue(methodName)
}

/// 将 HTTP Method 转换为 JS - 严格对应 Bun toJS
public func methodToJS(method: UInt8, globalObject: JsObject): JsValue {
    return Bun__HTTPMethod__toJS(method, globalObject)
}
