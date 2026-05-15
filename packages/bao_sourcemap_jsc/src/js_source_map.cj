// 严格翻译自: src/sourcemap_jsc/JSSourceMap.zig
//! Implements the JavaScript SourceMap class from Node.js.
package bao_sourcemap_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// JSSourceMap - JavaScript SourceMap 对象
// 严格翻译自: src/sourcemap_jsc/JSSourceMap.zig:3-317
//   const JSSourceMap = @This()
//   sourcemap: *bun.SourceMap.ParsedSourceMap
//   sources: []bun.String = &.{}
//   names: []bun.String = &.{}
// ============================================================================

/// JavaScript SourceMap 对象 - 严格对应 Bun JSSourceMap
public class JSSourceMap {
    public var sourcemap: ParsedSourceMap
    public var sources: Array<BaoString>
    public var names: Array<BaoString>

    /// 是否启用 source maps - 严格对应 Bun --enable-source-maps
    public static var enableSourceMaps: Bool = false

    public init(sourcemap: ParsedSourceMap, sources: Array<BaoString>, names: Array<BaoString>) {
        this.sourcemap = sourcemap
        this.sources = sources
        this.names = names
    }

    /// 查找 SourceMap - 严格对应 Bun findSourceMap
    /// Zig: fn findSourceMap(globalObject, callFrame) bun.JSError!JSValue
    public static func findSourceMap(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue {
        if (!enableSourceMaps) {
            return JSValue.jsUndefined
        }

        let sourceUrlValue = callFrame.argument(0)
        if (!sourceUrlValue.isString) {
            return JSValue.jsUndefined
        }

        var sourceUrlString = BaoString.fromJS(sourceUrlValue, globalObject)
        var sourceUrlSlice = sourceUrlString.toUTF8(Allocator.default)
        var sourceUrl = sourceUrlSlice.slice()

        if (strings.hasPrefix(sourceUrl, "node:") || strings.hasPrefix(sourceUrl, "bun:") || strings.hasPrefix(sourceUrl, "data:")) {
            return JSValue.jsUndefined
        }

        let vm = globalObject.bunVM()
        let sourceMap = vm.sourceMappings.get(sourceUrl)
        if (sourceMap == None) {
            return JSValue.jsUndefined
        }

        let fakeSourcesArray = Allocator.default.alloc<BaoString>(1)
        fakeSourcesArray[0] = sourceUrlString.dupeRef()

        let this = JSSourceMap(
            sourcemap: sourceMap,
            sources: fakeSourcesArray,
            names: []
        )

        return this.toJS(globalObject)
    }

    /// 构造函数 - 严格对应 Bun constructor
    /// Zig: pub fn constructor(globalObject, callFrame, thisValue) bun.JSError!*JSSourceMap
    public static func constructor(globalObject: JSGlobalObject, callFrame: CallFrame, thisValue: JSValue): JSSourceMap {
        let payloadArg = callFrame.argument(0)
        let optionsArg = callFrame.argument(1)

        globalObject.validateObject("payload", payloadArg)

        var lineLengths: JSValue = JSValue.zero
        if (optionsArg.isObject) {
            if (let lengths = optionsArg.getIfPropertyExists(globalObject, "lineLengths")) {
                if (lengths.jsType().isArray) {
                    lineLengths = lengths
                }
            }
        }

        let arena = ArenaAllocator(Allocator.default)
        let arenaAllocator = arena.allocator()

        let mappingsValue = payloadArg.getStringish(globalObject, "mappings")
        if (mappingsValue == None) {
            globalObject.throwInvalidArguments("payload 'mappings' must be a string")
            return JSSourceMap(ParsedSourceMap.empty, [], [])
        }

        let mappingsStr = mappingsValue.toUTF8(arenaAllocator)

        var names = ArrayList<BaoString>(Allocator.default)
        var sources = ArrayList<BaoString>(Allocator.default)

        if (let sourcesValue = payloadArg.getArray(globalObject, "sources")) {
            var iter = sourcesValue.arrayIterator(globalObject)
            while (let source = iter.next()) {
                let sourceStr = source.toBunString(globalObject)
                names.append(sourceStr)
            }
        }

        if (let namesValue = payloadArg.getArray(globalObject, "names")) {
            var iter = namesValue.arrayIterator(globalObject)
            while (let name = iter.next()) {
                let nameStr = name.toBunString(globalObject)
                names.append(nameStr)
            }
        }

        // 解析 VLQ 映射
        let parseResult = SourceMapMapping.parse(
            Allocator.default,
            mappingsStr.slice(),
            None,
            sources.size,
            Int32Max,
            MappingParseOptions(allowNames: true, sort: true)
        )

        let mappingList = match (parseResult) {
            case .success => parsed => parsed
            case .fail => fail =>
                if (let loc = fail.loc.toNullable()) {
                    globalObject.throwValue(globalObject.createSyntaxErrorInstance("${fail.msg} at ${loc.start}"))
                } else {
                    globalObject.throwValue(globalObject.createSyntaxErrorInstance("${fail.msg}"))
                }
                return JSSourceMap(ParsedSourceMap.empty, [], [])
        }

        let sourceMap = JSSourceMap(
            sourcemap: ParsedSourceMap(mappingList),
            sources: sources.items,
            names: names.items
        )

        return sourceMap
    }

    /// 内存开销 - 严格对应 Bun memoryCost
    public func memoryCost(): Int64 {
        return Int64(sizeof<JSSourceMap>()) + sources.size * Int64(sizeof<BaoString>()) + sourcemap.memoryCost()
    }

    /// 估计大小 - 严格对应 Bun estimatedSize
    public func estimatedSize(): Int64 {
        return memoryCost()
    }

    /// 查找原始位置 - 严格对应 Bun findOrigin
    /// Zig: pub fn findOrigin(this, globalObject, callFrame) bun.JSError!JSValue
    public func findOrigin(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue {
        let (lineNumber, columnNumber) = getLineColumn(globalObject, callFrame)

        let mapping = sourcemap.findMapping(LineColumn.fromZeroBased(lineNumber), Column.fromZeroBased(columnNumber))
        if (mapping == None) {
            return JSValue.createEmptyObject(globalObject, 0)
        }

        let name = mappingNameToJS(globalObject, mapping)
        let source = sourceNameToJS(globalObject, mapping)
        return Bun__createNodeModuleSourceMapOriginObject(
            globalObject,
            name,
            JSValue.jsNumber(mapping.originalLine()),
            JSValue.jsNumber(mapping.originalColumn()),
            source
        )
    }

    /// 查找映射条目 - 严格对应 Bun findEntry
    /// Zig: pub fn findEntry(this, globalObject, callFrame) bun.JSError!JSValue
    public func findEntry(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue {
        let (lineNumber, columnNumber) = getLineColumn(globalObject, callFrame)

        let mapping = sourcemap.findMapping(LineColumn.fromZeroBased(lineNumber), Column.fromZeroBased(columnNumber))
        if (mapping == None) {
            return JSValue.createEmptyObject(globalObject, 0)
        }

        let name = mappingNameToJS(globalObject, mapping)
        let source = sourceNameToJS(globalObject, mapping)
        return Bun__createNodeModuleSourceMapEntryObject(
            globalObject,
            JSValue.jsNumber(mapping.generatedLine()),
            JSValue.jsNumber(mapping.generatedColumn()),
            JSValue.jsNumber(mapping.originalLine()),
            JSValue.jsNumber(mapping.originalColumn()),
            source,
            name
        )
    }

    /// 获取行列号 - 严格对应 Bun getLineColumn
    private static func getLineColumn(globalObject: JSGlobalObject, callFrame: CallFrame): (Int32, Int32) {
        let lineNumberValue = callFrame.argument(0)
        let columnNumberValue = callFrame.argument(1)
        return (lineNumberValue.coerceInt32(globalObject), columnNumberValue.coerceInt32(globalObject))
    }

    /// 映射名到 JS - 严格对应 Bun mappingNameToJS
    private func mappingNameToJS(globalObject: JSGlobalObject, mapping: SourceMapMapping): JSValue {
        let nameIndex = mapping.nameIndex()
        if (nameIndex >= 0) {
            if (let name = sourcemap.mappings.getName(nameIndex)) {
                return BaoString.createUTF8ForJS(globalObject, name)
            } else {
                let index = Int64(nameIndex)
                if (index < names.size) {
                    return names[index].toJS(globalObject)
                }
            }
        }
        return JSValue.jsUndefined
    }

    /// 源名到 JS - 严格对应 Bun sourceNameToJS
    private func sourceNameToJS(globalObject: JSGlobalObject, mapping: SourceMapMapping): JSValue {
        let sourceIndex = mapping.sourceIndex()
        if (sourceIndex >= 0 && sourceIndex < Int32(sources.size)) {
            return sources[Int64(sourceIndex)].toJS(globalObject)
        }
        return JSValue.jsUndefined
    }

    /// 释放资源 - 严格对应 Bun deinit
    public func deinit(): Unit {
        for (str in sources) {
            str.deref()
        }
        Allocator.default.free(sources)

        for (name in names) {
            name.deref()
        }
        Allocator.default.free(names)

        sourcemap.deref()
    }
}

// 外部 C 函数 - 严格对应 Bun extern 声明
@Foreign("c")
public func Bun__createNodeModuleSourceMapOriginObject(globalObject: JSGlobalObject, name: JSValue, line: JSValue, column: JSValue, source: JSValue): JSValue

@Foreign("c")
public func Bun__createNodeModuleSourceMapEntryObject(globalObject: JSGlobalObject, generatedLine: JSValue, generatedColumn: JSValue, originalLine: JSValue, originalColumn: JSValue, source: JSValue, name: JSValue): JSValue
