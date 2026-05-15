// 严格翻译自: src/semver_jsc/SemverString_jsc.zig
//! JSC bridge for `bun.Semver.String`. Keeps `src/semver/` free of JSC types.
package bao_semver_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// SemverStringJSC - Semver String 的 JSC 桥接
// 严格翻译自: src/semver_jsc/SemverString_jsc.zig:3-9
//   pub fn toJS(this: *const String, buffer: []const u8, globalThis: *jsc.JSGlobalObject) bun.JSError!jsc.JSValue
// ============================================================================

/// 将 Semver String 转换为 JS 值 - 严格对应 Bun toJS
/// Zig: pub fn toJS(this: *const String, buffer: []const u8, globalThis) bun.JSError!jsc.JSValue
/// Zig: return bun.String.createUTF8ForJS(globalThis, this.slice(buffer))
public func semverStringToJS(`this`: SemverString, buffer: Array<Byte>, globalThis: JSGlobalObject): JSValue {
    return BaoString.createUTF8ForJS(globalThis, this.slice(buffer))
}
