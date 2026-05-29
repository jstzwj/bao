// 严格翻译自: src/sourcemap_jsc/JSSourceMap.zig
//! Implements the JavaScript SourceMap class from Node.js.
package bao_sourcemap_jsc

import bao_jsc.*
import bao_core.*
import bao_sourcemap.ParsedSourceMap as SMParsedSourceMap
import bao_sourcemap.ParseOptions
import bao_sourcemap.MappingParser
import bao_sourcemap.SourceMapping

// ============================================================================
// JSSourceMap - JavaScript SourceMap 对象
// 严格翻译自: src/sourcemap_jsc/JSSourceMap.zig
// ============================================================================

/// JavaScript SourceMap 对象 - 实现 Node.js SourceMap API
public class JSSourceMap {
    public var sourcemap: SMParsedSourceMap
    public var sources: Array<BaoString>
    public var names: Array<BaoString>

    public static var enableSourceMaps: Bool = false

    public init(sourcemap: SMParsedSourceMap, sources: Array<BaoString>, names: Array<BaoString>) {
        this.sourcemap = sourcemap
        this.sources = sources
        this.names = names
    }

    public init() {
        sourcemap = SMParsedSourceMap()
        sources = []
        names = []
    }

    /// 查找 SourceMap
    /// Node.js 默认不启用 source maps；Bao 当前也没有可用的 VM source map store 接口。
    public static func findSourceMap(globalObject: JSGlobalObject, callFrame: CallFrame): JsValue {
        if (!enableSourceMaps) {
            return JsValue.jsUndefined()
        }

        let sourceUrlValue = callFrame.argument(0)
        if (!sourceUrlValue.isString()) {
            return JsValue.jsUndefined()
        }

        let sourceUrl = sourceUrlValue.toString()
        if (sourceUrl.startsWith("node:") || sourceUrl.startsWith("bun:") || sourceUrl.startsWith("data:")) {
            return JsValue.jsUndefined()
        }

        // 需要通过 VM 的 source_mappings 接口查找已注册的 SourceMap
        // 对应 Bun: SavedSourceMap.get(globalObject, sourceUrl)
        // 当前 VM source_mappings 接口尚未暴露, 暂时返回 undefined
        return JsValue.jsUndefined()
    }

    /// 构造函数
    public static func constructor(globalObject: JSGlobalObject, callFrame: CallFrame, thisValue: JsValue): JSSourceMap {
        let payloadArg = callFrame.argument(0)
        let mappingsValue = payloadArg.get(globalObject.globalThis, "mappings").getOrThrow()
        let mappingsString = if (mappingsValue.isString()) { mappingsValue.toString() } else { "" }

        var sourceCount: Int64 = 0
        let sourcesValue = payloadArg.get(globalObject.globalThis, "sources").getOrThrow()
        if (sourcesValue.valueType == JsValueType.Array && sourcesValue.arrayData.isSome()) {
            sourceCount = sourcesValue.arrayData.getOrThrow().size
        }

        let parseOptions = ParseOptions(true, true)
        let parsed = MappingParser.parse(mappingsString, sourceCount, 0, parseOptions)
        let sourceMap = SMParsedSourceMap(parsed.inputLineCount, parsed.mappings)
        let result = JSSourceMap(sourceMap, [], [])

        if (sourcesValue.valueType == JsValueType.Array && sourcesValue.arrayData.isSome()) {
            let sourceArray = sourcesValue.arrayData.getOrThrow()
            var sourcesOut = Array<BaoString>(sourceArray.size, { _ => BaoString() })
            for (i in 0..sourceArray.size) {
                sourcesOut[i] = BaoString(sourceArray[i].toString())
            }
            result.sources = sourcesOut
        }

        let namesValue = payloadArg.get(globalObject.globalThis, "names").getOrThrow()
        if (namesValue.valueType == JsValueType.Array && namesValue.arrayData.isSome()) {
            let nameArray = namesValue.arrayData.getOrThrow()
            var namesOut = Array<BaoString>(nameArray.size, { _ => BaoString() })
            for (i in 0..nameArray.size) {
                let name = nameArray[i].toString()
                namesOut[i] = BaoString(name)
                result.sourcemap.mappings.appendName(name)
            }
            result.names = namesOut
        }

        return result
    }

    /// 内存开销
    public func memoryCost(): Int64 {
        return 64 + Int64(sources.size * 16) + Int64(names.size * 16) + sourcemap.memoryCost()
    }

    /// 估计大小
    public func estimatedSize(): Int64 {
        return memoryCost()
    }

    private func getLineColumn(callFrame: CallFrame): (Int64, Int64) {
        return (Int64(callFrame.argument(0).toInt32()), Int64(callFrame.argument(1).toInt32()))
    }

    private func mappingNameToJS(mapping: SourceMapping): JsValue {
        if (mapping.nameIndex >= 0) {
            let mappedName = sourcemap.mappings.getName(mapping.nameIndex)
            if (mappedName.isSome()) {
                return JsValue(mappedName.getOrThrow())
            }
            if (mapping.nameIndex < Int64(names.size)) {
                return JsValue(names[mapping.nameIndex].toString())
            }
        }
        return JsValue.jsUndefined()
    }

    private func sourceNameToJS(mapping: SourceMapping): JsValue {
        if (mapping.sourceIndex >= 0 && mapping.sourceIndex < Int64(sources.size)) {
            return JsValue(sources[mapping.sourceIndex].toString())
        }
        return JsValue.jsUndefined()
    }

    /// 查找原始位置
    public func findOrigin(globalObject: JSGlobalObject, callFrame: CallFrame): JsValue {
        let (lineNumber, columnNumber) = getLineColumn(callFrame)
        let mapping = sourcemap.findMapping(lineNumber, columnNumber)
        if (mapping.isNone()) {
            return JsValue.createEmptyObject(globalObject.globalThis, 0)
        }

        let found = mapping.getOrThrow()
        return Bun__createNodeModuleSourceMapOriginObject(
            globalObject,
            mappingNameToJS(found),
            JsValue.jsNumber(found.originalLine()),
            JsValue.jsNumber(found.originalColumn()),
            sourceNameToJS(found)
        )
    }

    /// 查找映射条目
    public func findEntry(globalObject: JSGlobalObject, callFrame: CallFrame): JsValue {
        let (lineNumber, columnNumber) = getLineColumn(callFrame)
        let mapping = sourcemap.findMapping(lineNumber, columnNumber)
        if (mapping.isNone()) {
            return JsValue.createEmptyObject(globalObject.globalThis, 0)
        }

        let found = mapping.getOrThrow()
        return Bun__createNodeModuleSourceMapEntryObject(
            globalObject,
            JsValue.jsNumber(found.generatedLine()),
            JsValue.jsNumber(found.generatedColumn()),
            JsValue.jsNumber(found.originalLine()),
            JsValue.jsNumber(found.originalColumn()),
            sourceNameToJS(found),
            mappingNameToJS(found)
        )
    }

    /// 释放资源
    public func deinit(): Unit {
        sources = []
        names = []
    }
}

public func Bun__createNodeModuleSourceMapOriginObject(globalObject: JSGlobalObject, name: JsValue, line: JsValue, column: JsValue, source: JsValue): JsValue {
    let obj = JsValue.createEmptyObject(globalObject.globalThis, 4)
    obj.put(globalObject.globalThis, "name", name)
    obj.put(globalObject.globalThis, "line", line)
    obj.put(globalObject.globalThis, "column", column)
    obj.put(globalObject.globalThis, "source", source)
    return obj
}

public func Bun__createNodeModuleSourceMapEntryObject(globalObject: JSGlobalObject, generatedLine: JsValue, generatedColumn: JsValue, originalLine: JsValue, originalColumn: JsValue, source: JsValue, name: JsValue): JsValue {
    let obj = JsValue.createEmptyObject(globalObject.globalThis, 6)
    obj.put(globalObject.globalThis, "generatedLine", generatedLine)
    obj.put(globalObject.globalThis, "generatedColumn", generatedColumn)
    obj.put(globalObject.globalThis, "originalLine", originalLine)
    obj.put(globalObject.globalThis, "originalColumn", originalColumn)
    obj.put(globalObject.globalThis, "source", source)
    obj.put(globalObject.globalThis, "name", name)
    return obj
}
