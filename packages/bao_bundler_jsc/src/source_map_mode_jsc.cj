// 严格翻译自: src/bundler_jsc/source_map_mode_jsc.zig
//! `fromJS` for SourceMapMode.
package bao_bundler_jsc

import bao_jsc.*
import bao_core.*
import bao_options.*

// ============================================================================
// SourceMapModeJSC
// ============================================================================

/// 从 JS 获取 SourceMap 模式
public func sourceMapModeFromJS(global: JSGlobalObject, value: JsValue): JsValue {
    match (sourceMapModeValueFromJS(global, value)) {
        case Some(mode) => JsValue(sourceMapModeToString(mode))
        case None => JsValue.jsUndefined()
    }
}

public func sourceMapModeValueFromJS(global: JSGlobalObject, value: JsValue): ?SourceMapMode {
    if (!value.isString()) { return Option<SourceMapMode>.None }

    match (value.toString()) {
        case "none" => Some(SourceMapMode.None)
        case "inline" => Some(SourceMapMode.Inline)
        case "external" => Some(SourceMapMode.External)
        case "linked" => Some(SourceMapMode.Linked)
        case _ => Option<SourceMapMode>.None
    }
}

private func sourceMapModeToString(mode: SourceMapMode): String {
    match (mode) {
        case SourceMapMode.None => "none"
        case SourceMapMode.Inline => "inline"
        case SourceMapMode.External => "external"
        case SourceMapMode.Linked => "linked"
    }
}
