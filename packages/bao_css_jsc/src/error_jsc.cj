// 严格翻译自: src/css_jsc/error_jsc.zig
//! JSC bridge for `bun.css.Err(T)`. Keeps `src/css/` free of JSC types.
package bao_css_jsc

import bao_jsc.*
import bao_core.ArenaAllocator as CoreArenaAllocator
import bao_core.*

// ============================================================================
// CssErrorJSC - CSS 错误的 JSC 桥接
// 严格翻译自: src/css_jsc/error_jsc.zig:4-11
//   pub fn toErrorInstance(this: anytype, globalThis) !bun.jsc.JsValue
// ============================================================================

/// 将 CSS 错误转换为 JS Error 实例 - 严格对应 Bun toErrorInstance
/// Simplified: creates error instance from error kind string
public func cssErrorToErrorInstance(errKind: String, globalThis: JSGlobalObject): JsValue {
    return globalThis.createErrorInstance(errKind)
}
