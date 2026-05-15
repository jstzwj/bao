// 严格翻译自: src/sourcemap_jsc/internal_jsc.zig
//! JS testing bindings for `InternalSourceMap`. Keeps `src/sourcemap/` free of JSC types.
package bao_sourcemap_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// InternalSourceMapTestingAPIs - InternalSourceMap 测试 API
// 严格翻译自: src/sourcemap_jsc/internal_jsc.zig:3-60
//   pub const TestingAPIs = struct {
//       pub fn fromVLQ(...)
//       pub fn toVLQ(...)
//       pub fn find(...)
//   }
// ============================================================================

/// InternalSourceMap 测试 API 集合 - 严格对应 Bun TestingAPIs
public class InternalSourceMapTestingAPIs {
    /// 从 VLQ 字符串解码 - 严格对应 Bun fromVLQ
    /// Zig: pub fn fromVLQ(globalThis, callframe) bun.JSError!jsc.JSValue
    public static func fromVLQ(globalThis: JSGlobalObject, callframe: CallFrame): JSValue {
        let vlqStr = callframe.argument(0).toBunString(globalThis)
        let vlq = vlqStr.toUTF8(Allocator.default)

        let blob = InternalSourceMap.fromVLQ(Allocator.default, vlq.slice(), 0)
        if (blob.isErr) {
            globalThis.throw("InternalSourceMap.fromVLQ: invalid VLQ input")
            return JSValue.zero
        }

        return ArrayBuffer.createUint8Array(globalThis, blob)
    }

    /// 编码为 VLQ 字符串 - 严格对应 Bun toVLQ
    /// Zig: pub fn toVLQ(globalThis, callframe) bun.JSError!jsc.JSValue
    public static func toVLQ(globalThis: JSGlobalObject, callframe: CallFrame): JSValue {
        let ab = callframe.argument(0).asArrayBuffer(globalThis)
        if (ab == None) {
            globalThis.throw("InternalSourceMap.toVLQ: expected Uint8Array")
            return JSValue.zero
        }
        let bytes = ab.byteSlice()
        if (!InternalSourceMap.isValidBlob(bytes)) {
            globalThis.throw("InternalSourceMap.toVLQ: invalid blob")
            return JSValue.zero
        }
        let ism = InternalSourceMap(data: bytes.ptr)
        var out = MutableString.initEmpty(Allocator.default)
        ism.appendVLQTo(out)
        return BaoString.createUTF8ForJS(globalThis, out.list.items)
    }

    /// 查找映射 - 严格对应 Bun find
    /// Zig: pub fn find(globalThis, callframe) bun.JSError!jsc.JSValue
    public static func find(globalThis: JSGlobalObject, callframe: CallFrame): JSValue {
        let ab = callframe.argument(0).asArrayBuffer(globalThis)
        if (ab == None) {
            globalThis.throw("InternalSourceMap.find: expected Uint8Array")
            return JSValue.zero
        }
        let bytes = ab.byteSlice()
        if (!InternalSourceMap.isValidBlob(bytes)) {
            globalThis.throw("InternalSourceMap.find: invalid blob")
            return JSValue.zero
        }
        let line = callframe.argument(1).toInt32()
        let col = callframe.argument(2).toInt32()
        if (line < 0 || col < 0) {
            return JSValue.null
        }
        let ism = InternalSourceMap(data: bytes.ptr)
        let mapping = ism.find(LineColumn.fromZeroBased(line), Column.fromZeroBased(col))
        if (mapping == None) {
            return JSValue.null
        }

        let obj = JSValue.createEmptyObject(globalThis, 5)
        obj.put(globalThis, ZigString.static("generatedLine"), JSValue.jsNumber(mapping.generatedLine))
        obj.put(globalThis, ZigString.static("generatedColumn"), JSValue.jsNumber(mapping.generatedColumn))
        obj.put(globalThis, ZigString.static("originalLine"), JSValue.jsNumber(mapping.originalLine))
        obj.put(globalThis, ZigString.static("originalColumn"), JSValue.jsNumber(mapping.originalColumn))
        obj.put(globalThis, ZigString.static("sourceIndex"), JSValue.jsNumber(mapping.sourceIndex))
        return obj
    }
}
