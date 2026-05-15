// 严格翻译自: src/bundler_jsc/source_map_mode_jsc.zig
//! `fromJS` for `bun.schema.api.SourceMapMode`.
package bao_bundler_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// SourceMapModeJSC - SourceMap 模式的 JSC 桥接
// 严格翻译自: src/bundler_jsc/source_map_mode_jsc.zig:5-28
// ============================================================================

/// 从 JS 获取 SourceMap 模式 - 严格对应 Bun sourceMapModeFromJS
/// Zig: pub fn sourceMapModeFromJS(global, value) bun.JSError!?SourceMapMode
public func sourceMapModeFromJS(global: JSGlobalObject, value: JSValue): ?SourceMapMode {
    if (value.isString) {
        let str = value.toSliceOrNull(global)
        let utf8 = str.slice()
        if (strings.eqlComptime(utf8, "none")) {
            return SourceMapMode.none
        }
        if (strings.eqlComptime(utf8, "inline")) {
            return SourceMapMode.inline
        }
        if (strings.eqlComptime(utf8, "external")) {
            return SourceMapMode.external
        }
        if (strings.eqlComptime(utf8, "linked")) {
            return SourceMapMode.linked
        }
    }
    return None
}
