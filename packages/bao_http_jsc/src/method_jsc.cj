// 严格翻译自: src/http_jsc/method_jsc.zig
//! JSC bridge for `bun.http.Method`. Keeps `src/http_types/` free of JSC types.
package bao_http_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// MethodJSC - Method 的 JSC 桥接
// 严格翻译自: src/http_jsc/method_jsc.zig:3-9
//   extern "c" fn Bun__HTTPMethod__toJS(method: Method, globalObject) jsc.JSValue
//   pub const toJS = Bun__HTTPMethod__toJS
// ============================================================================

// 外部 C 函数声明 - 严格对应 Bun extern "c" 声明
@Foreign("c")
public func Bun__HTTPMethod__toJS(method: Method, globalObject: JSGlobalObject): JSValue

/// 将 HTTP Method 转换为 JS - 严格对应 Bun toJS
/// Zig: pub const toJS = Bun__HTTPMethod__toJS
public func methodToJS(method: Method, globalObject: JSGlobalObject): JSValue {
    return Bun__HTTPMethod__toJS(method, globalObject)
}
