// 严格翻译自: src/sourcemap_jsc/internal_jsc.zig
//! JS testing bindings for `InternalSourceMap`.
package bao_sourcemap_jsc

import bao_jsc.*
import bao_sourcemap.VLQ
import bao_sourcemap.ParseOptions
import bao_sourcemap.MappingParser

// ============================================================================
// InternalSourceMapTestingAPIs - InternalSourceMap 测试 API (stub)
// ============================================================================

/// InternalSourceMap 测试 API 集合 - stub
public class InternalSourceMapTestingAPIs {
    /// 从 VLQ 字符串解码为一组整数。
    /// Bao 目前没有 InternalSourceMap 二进制 blob 类型，因此暴露可验证的 VLQ 解码结果。
    public static func fromVLQ(globalThis: JSGlobalObject, callframe: CallFrame): JsValue {
        let vlqString = callframe.argument(0).toString()
        var values = Array<JsValue>(0, { _ => JsValue.jsUndefined() })
        var offset: Int64 = 0
        while (offset < vlqString.size) {
            let ch = vlqString[offset]
            if (ch == UInt8(0x2C) || ch == UInt8(0x3B)) {
                offset += 1
                continue
            }
            let decoded = VLQ.decode(vlqString, offset)
            if (decoded.start <= offset) {
                return JsValue.jsNull()
            }
            let oldSize = values.size
            var next = Array<JsValue>(oldSize + 1, { _ => JsValue.jsUndefined() })
            for (i in 0..oldSize) {
                next[i] = values[i]
            }
            next[oldSize] = JsValue.jsNumber(decoded.value)
            values = next
            offset = decoded.start
        }
        let obj = JsValue.createEmptyArray(globalThis.globalThis, values.size)
        for (i in 0..values.size) {
            obj.putIndex(globalThis.globalThis, UInt32(i), values[i])
        }
        return obj
    }

    /// 将数字数组编码为 VLQ 字符串。
    public static func toVLQ(globalThis: JSGlobalObject, callframe: CallFrame): JsValue {
        let input = callframe.argument(0)
        var out = ""
        if (input.valueType == JsValueType.Array && input.arrayData.isSome()) {
            let values = input.arrayData.getOrThrow()
            for (i in 0..values.size) {
                out += VLQ.encode(values[i].toInt64())
            }
            return JsValue(out)
        }
        return JsValue.jsNull()
    }

    /// 查找映射。
    /// InternalSourceMap blob support is not present in Bao yet, but this supports a ParsedSourceMap-like JS payload.
    public static func find(globalThis: JSGlobalObject, callframe: CallFrame): JsValue {
        let payload = callframe.argument(0)
        let mappingsOpt = payload.get(globalThis.globalThis, "mappings")
        if (mappingsOpt.isNone()) {
            return JsValue.jsNull()
        }

        let mappingsValue = mappingsOpt.getOrThrow()
        if (!mappingsValue.isString()) {
            return JsValue.jsNull()
        }

        var sourceCount: Int64 = 1
        let sourcesOpt = payload.get(globalThis.globalThis, "sources")
        if (sourcesOpt.isSome()) {
            let sources = sourcesOpt.getOrThrow()
            if (sources.valueType == JsValueType.Array && sources.arrayData.isSome()) {
                sourceCount = sources.arrayData.getOrThrow().size
            }
        }

        let line = Int64(callframe.argument(1).toInt32())
        let col = Int64(callframe.argument(2).toInt32())
        if (line < 0 || col < 0) {
            return JsValue.jsNull()
        }

        let parsed = MappingParser.parse(mappingsValue.toString(), sourceCount, 0, ParseOptions(true, true))
        let mapping = parsed.mappings.find(line, col)
        if (mapping.isNone()) {
            return JsValue.jsNull()
        }

        let found = mapping.getOrThrow()
        let obj = JsValue.createEmptyObject(globalThis.globalThis, 5)
        obj.put(globalThis.globalThis, "generatedLine", JsValue.jsNumber(found.generatedLine()))
        obj.put(globalThis.globalThis, "generatedColumn", JsValue.jsNumber(found.generatedColumn()))
        obj.put(globalThis.globalThis, "originalLine", JsValue.jsNumber(found.originalLine()))
        obj.put(globalThis.globalThis, "originalColumn", JsValue.jsNumber(found.originalColumn()))
        obj.put(globalThis.globalThis, "sourceIndex", JsValue.jsNumber(found.sourceIndex))
        return obj
    }
}
