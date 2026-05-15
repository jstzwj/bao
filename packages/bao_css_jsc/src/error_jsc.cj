// 严格翻译自: src/css_jsc/error_jsc.zig
//! JSC bridge for `bun.css.Err(T)`. Keeps `src/css/` free of JSC types.
package bao_css_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// CssErrorJSC - CSS 错误的 JSC 桥接
// 严格翻译自: src/css_jsc/error_jsc.zig:4-11
//   pub fn toErrorInstance(this: anytype, globalThis) !bun.jsc.JSValue
// ============================================================================

/// 将 CSS 错误转换为 JS Error 实例 - 严格对应 Bun toErrorInstance
/// Zig: pub fn toErrorInstance(this: anytype, globalThis: *bun.jsc.JSGlobalObject) !bun.jsc.JSValue
/// Zig: var str = try bun.String.createFormat("{f}", .{this.kind})
/// Zig: defer str.deref()
/// Zig: return str.toErrorInstance(globalThis)
public func cssErrorToErrorInstance(`this`: CssError, globalThis: JSGlobalObject): JSValue {
    var str = BaoString.createFormat("${this.kind}")
    defer {
        str.deref()
    }
    return str.toErrorInstance(globalThis)
}
