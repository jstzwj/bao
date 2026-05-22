// 严格翻译自: src/sourcemap_jsc/JSSourceMap.zig
//! Implements the JavaScript SourceMap class from Node.js.
//! Stub implementation - SourceMapMapping and related types not available.
package bao_sourcemap_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// JSSourceMap - JavaScript SourceMap 对象 (stub)
// ============================================================================

/// JavaScript SourceMap 对象 - stub
public class JSSourceMap {
    public var sourcemap: ParsedSourceMap
    public var sources: Array<BaoString>
    public var names: Array<BaoString>

    public static var enableSourceMaps: Bool = false

    public init(sourcemap: ParsedSourceMap, sources: Array<BaoString>, names: Array<BaoString>) {
        this.sourcemap = sourcemap
        this.sources = sources
        this.names = names
    }

    public init() {
        sourcemap = ParsedSourceMap()
        sources = []
        names = []
    }

    /// 查找 SourceMap - stub
    public static func findSourceMap(globalObject: JSGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 构造函数 - stub
    public static func constructor(globalObject: JSGlobalObject, callFrame: CallFrame, thisValue: JsValue): JSSourceMap {
        return JSSourceMap()
    }

    /// 内存开销
    public func memoryCost(): Int64 {
        return Int64(0)
    }

    /// 估计大小
    public func estimatedSize(): Int64 {
        return memoryCost()
    }

    /// 查找原始位置 - stub
    public func findOrigin(globalObject: JSGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 查找映射条目 - stub
    public func findEntry(globalObject: JSGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 释放资源
    public func deinit(): Unit {
        sources = []
        names = []
    }
}

// Stub extern functions
public func Bun__createNodeModuleSourceMapOriginObject(globalObject: JSGlobalObject, name: JsValue, line: JsValue, column: JsValue, source: JsValue): JsValue {
    return JsValue.jsUndefined()
}

public func Bun__createNodeModuleSourceMapEntryObject(globalObject: JSGlobalObject, generatedLine: JsValue, generatedColumn: JsValue, originalLine: JsValue, originalColumn: JsValue, source: JsValue, name: JsValue): JsValue {
    return JsValue.jsUndefined()
}
