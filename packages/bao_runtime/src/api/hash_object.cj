// 严格翻译自: src/runtime/api/HashObject.zig
package bao_runtime

import bao_jsc.*
import bao_core.*
import bao_collections.*
import bao_sys.*

// ============================================================================
// HashObject - 多种哈希算法的 JS 绑定
// 对应 Bun: src/runtime/api/HashObject.zig
// ============================================================================

/// HashObject 提供多种哈希算法供 JavaScript 调用
/// 支持的算法: wyhash, adler32, crc32, cityHash32, cityHash64,
/// xxHash32, xxHash64, xxHash3, murmur32v2, murmur32v3, murmur64v2, rapidhash
public class HashObject {

    /// 创建 hash 函数对象并注册所有哈希方法
    public static func create(globalThis: JsGlobalObject): JsValue {
        let function = JsFunction.create(globalThis, "hash", wyhash, 1)

        let fnNames = [
            "wyhash",
            "adler32",
            "crc32",
            "cityHash32",
            "cityHash64",
            "xxHash32",
            "xxHash64",
            "xxHash3",
            "murmur32v2",
            "murmur32v3",
            "murmur64v2",
            "rapidhash",
        ]

        for (name in fnNames) {
            let value = JsFunction.create(globalThis, name, getHashFn(name), 1)
            function.put(globalThis, ZigString.static(name), value)
        }

        return function
    }

    /// 根据名称获取哈希函数
    public static func getHashFn(name: String): (JsGlobalObject, JsCallFrame) -> JsValue {
        return { globalThis, callframe in
            return hashWrap(globalThis, callframe, name)
        }
    }

    // ========================================================================
    // 各哈希算法实现
    // ========================================================================

    /// wyhash 哈希
    public static func wyhash(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        return hashWrap(globalThis, callframe, "wyhash")
    }

    /// adler32 哈希
    public static func adler32(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        return hashWrap(globalThis, callframe, "adler32")
    }

    /// crc32 哈希 (使用 zlib 硬件加速)
    public static func crc32(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        return hashWrap(globalThis, callframe, "crc32")
    }

    /// cityHash32 哈希
    public static func cityHash32(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        return hashWrap(globalThis, callframe, "cityHash32")
    }

    /// cityHash64 哈希
    public static func cityHash64(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        return hashWrap(globalThis, callframe, "cityHash64")
    }

    /// xxHash32 哈希
    public static func xxHash32(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        return hashWrap(globalThis, callframe, "xxHash32")
    }

    /// xxHash64 哈希
    public static func xxHash64(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        return hashWrap(globalThis, callframe, "xxHash64")
    }

    /// xxHash3 哈希
    public static func xxHash3(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        return hashWrap(globalThis, callframe, "xxHash3")
    }

    /// murmur32v2 哈希
    public static func murmur32v2(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        return hashWrap(globalThis, callframe, "murmur32v2")
    }

    /// murmur32v3 哈希
    public static func murmur32v3(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        return hashWrap(globalThis, callframe, "murmur32v3")
    }

    /// murmur64v2 哈希
    public static func murmur64v2(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        return hashWrap(globalThis, callframe, "murmur64v2")
    }

    /// rapidhash 哈希
    public static func rapidhash(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        return hashWrap(globalThis, callframe, "rapidhash")
    }

    // ========================================================================
    // 通用哈希包装器
    // ========================================================================

    /// 通用哈希函数包装器 - 处理输入参数和种子, 调用对应哈希算法
    public static func hashWrap(globalThis: JsGlobalObject, callframe: JsCallFrame, algorithm: String): JsValue {
        let arguments = callframe.argumentsOld(2).slice()
        var args = CallFrame.ArgumentsSlice.init(globalThis.bunVM(), arguments)
        defer args.deinit()

        var input: Array<UInt8> = []
        var inputSlice = ZigString.Slice.empty
        defer inputSlice.deinit()

        if (let arg = args.nextEat()) {
            if (let blob = arg.asBlob()) {
                input = blob.sharedView()
            } else {
                switch (arg.jsTypeLoose()) {
                    case JSType.ArrayBuffer,
                         JSType.Int8Array,
                         JSType.Uint8Array,
                         JSType.Uint8ClampedArray,
                         JSType.Int16Array,
                         JSType.Uint16Array,
                         JSType.Int32Array,
                         JSType.Uint32Array,
                         JSType.Float16Array,
                         JSType.Float32Array,
                         JSType.Float64Array,
                         JSType.BigInt64Array,
                         JSType.BigUint64Array,
                         JSType.DataView:
                        let arrayBuffer = arg.asArrayBuffer(globalThis)
                        if (arrayBuffer != null) {
                            input = arrayBuffer.byteSlice()
                        } else {
                            globalThis.throwInvalidArguments("ArrayBuffer conversion error")
                            return JsValue.zero
                        }
                    default:
                        inputSlice = try arg.toSlice(globalThis, default_allocator)
                        input = inputSlice.slice()
                }
            }
        }

        // 获取可选种子值
        var seed: UInt64 = 0
        if (let arg = args.nextEat()) {
            if (arg.isNumber() || arg.isBigInt()) {
                seed = arg.toUInt64NoTruncate()
            }
        }

        // 调用对应哈希算法
        let result = computeHash(algorithm, input, seed)

        // 根据返回类型决定 JS 值
        if (result.is32Bit) {
            return JsValue.jsNumber(result.value32)
        }
        return JsValue.fromUInt64NoTruncate(globalThis, result.value64)
    }

    /// 计算哈希值 (根据算法名称分派)
    public static func computeHash(algorithm: String, data: Array<UInt8>, seed: UInt64): HashResult {
        switch (algorithm) {
            case "wyhash":
                return HashResult.value64(Wyhash.hash(UInt64(seed), data))
            case "adler32":
                return HashResult.value32(Adler32.hash(UInt32(seed), data))
            case "crc32":
                return HashResult.value32(Crc32.hash(UInt32(seed), data))
            case "cityHash32":
                return HashResult.value32(CityHash32.hash(UInt32(seed), data))
            case "cityHash64":
                return HashResult.value64(CityHash64.hash(UInt64(seed), data))
            case "xxHash32":
                return HashResult.value32(XxHash32.hash(UInt32(seed), data))
            case "xxHash64":
                return HashResult.value64(XxHash64.hash(UInt64(seed), data))
            case "xxHash3":
                return HashResult.value64(XxHash3.hash(UInt32(seed), data))
            case "murmur32v2":
                return HashResult.value32(Murmur2_32.hash(UInt32(seed), data))
            case "murmur32v3":
                return HashResult.value32(Murmur3_32.hash(UInt32(seed), data))
            case "murmur64v2":
                return HashResult.value64(Murmur2_64.hash(UInt64(seed), data))
            case "rapidhash":
                return HashResult.value64(RapidHash.hash(UInt64(seed), data))
            default:
                return HashResult.value64(0)
        }
    }
}

/// 哈希结果
public enum HashResult {
    case value32(UInt32)
    case value64(UInt64)

    public var is32Bit: Bool {
        match (this) {
            case .value32(_) => true
            case .value64(_) => false
        }
    }

    public var value32: UInt32 {
        match (this) {
            case .value32(v) => v
            case .value64(v) => UInt32(v & 0xFFFFFFFF)
        }
    }

    public var value64: UInt64 {
        match (this) {
            case .value32(v) => UInt64(v)
            case .value64(v) => v
        }
    }
}
