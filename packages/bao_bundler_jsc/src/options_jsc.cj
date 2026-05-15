// 严格翻译自: src/bundler_jsc/options_jsc.zig
//! `fromJS` bridges for `bun.options.{Target,Format,Loader}` and `CompileTarget`.
package bao_bundler_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// OptionsJSC - Bundler 选项的 JSC 桥接
// 严格翻译自: src/bundler_jsc/options_jsc.zig:4-71
// ============================================================================

/// 从 JS 获取 Target - 严格对应 Bun targetFromJS
/// Zig: pub fn targetFromJS(global, value) bun.JSError!?options.Target
public func targetFromJS(global: JSGlobalObject, value: JSValue): ?Target {
    if (!value.isString) {
        global.throwInvalidArguments("target must be a string")
        return None
    }
    return Target.Map.fromJS(global, value)
}

/// 从 JS 获取 Format - 严格对应 Bun formatFromJS
/// Zig: pub fn formatFromJS(global, format) bun.JSError!?options.Format
public func formatFromJS(global: JSGlobalObject, format: JSValue): ?Format {
    if (format.isUndefinedOrNull) {
        return None
    }
    if (!format.isString) {
        global.throwInvalidArguments("format must be a string")
        return None
    }

    let result = Format.Map.fromJS(global, format)
    if (result == None) {
        global.throwInvalidArguments("Invalid format - must be esm, cjs, or iife")
    }
    return result
}

/// 从 JS 获取 Loader - 严格对应 Bun loaderFromJS
/// Zig: pub fn loaderFromJS(global, loader) bun.JSError!?options.Loader
public func loaderFromJS(global: JSGlobalObject, loader: JSValue): ?Loader {
    if (loader.isUndefinedOrNull) {
        return None
    }
    if (!loader.isString) {
        global.throwInvalidArguments("loader must be a string")
        return None
    }

    var zigStr = ZigString.init("")
    loader.toZigString(zigStr, global)
    if (zigStr.size == 0) {
        return None
    }

    let slice = zigStr.toSlice(Allocator.default)
    let result = Loader.fromString(slice.slice())
    if (result == None) {
        global.throwInvalidArguments("invalid loader - must be js, jsx, tsx, ts, css, file, toml, yaml, wasm, bunsh, json, or md")
    }
    return result
}

/// 从 JS 获取 CompileTarget - 严格对应 Bun compileTargetFromJS
/// Zig: pub fn compileTargetFromJS(global, value) bun.JSError!CompileTarget
public func compileTargetFromJS(global: JSGlobalObject, value: JSValue): CompileTarget {
    let slice = value.toSlice(global, Allocator.default)
    if (!strings.hasPrefixComptime(slice.slice(), "bun-")) {
        global.throwInvalidArguments("Expected compile target to start with 'bun-', got ${slice.slice()}")
        return CompileTarget.default
    }

    return compileTargetFromSlice(global, slice.slice())
}

/// 从字符串获取 CompileTarget - 严格对应 Bun compileTargetFromSlice
/// Zig: pub fn compileTargetFromSlice(global, slice_with_bun_prefix) bun.JSError!CompileTarget
public func compileTargetFromSlice(global: JSGlobalObject, sliceWithBunPrefix: String): CompileTarget {
    let slice = sliceWithBunPrefix["bun-".size..]
    let targetParsed = CompileTarget.tryFrom(slice)
    if (targetParsed.isErr) {
        global.throwInvalidArguments("Unknown compile target: ${sliceWithBunPrefix}")
        return CompileTarget.default
    }
    if (!targetParsed.resultValue.isSupported) {
        global.throwInvalidArguments("Unsupported compile target: ${sliceWithBunPrefix}")
        return CompileTarget.default
    }

    return targetParsed.resultValue
}
