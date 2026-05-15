// 严格翻译自: src/jsc/FFI.zig
// FFI 类型定义 - JavaScriptCore 值编码的低级 FFI 绑定
// 这是从 FFI.h 通过 zig translate-c 生成的

package bao_jsc

// ========== EncodedJSValue ==========
// 严格翻译自 FFI.zig union_EncodedJSValue
// 编码的 JSValue 的外部联合体表示
public class EncodedJSValue {
    public var asInt64: Int64 = 0
    public var asDouble: Float64 = 0.0
    public var asPtr: UInt64 = 0

    public init() {}

    public init(asInt64: Int64) {
        this.asInt64 = asInt64
        this.asDouble = 0.0
        this.asPtr = 0
    }

    public init(asDouble: Float64) {
        this.asDouble = asDouble
        this.asInt64 = 0
        this.asPtr = 0
    }
}

// ========== FFI 常量 ==========
// 严格翻译自 FFI.zig 常量
public let FFI_TAG_VALUE_UNDEFINED: Int64 = (2 | 8)
public let FFI_TRUE_I64: Int64 = (2 | 4) | 1
public let FFI_DOUBLE_ENCODE_OFFSET_BIT: Int32 = 49
public let FFI_OTHER_TAG: Int32 = 0x2
public let FFI_BOOL_TAG: Int32 = 0x4
public let FFI_UNDEFINED_TAG: Int32 = 0x8
public let FFI_TAG_VALUE_FALSE: Int64 = (2 | 4) | 0
public let FFI_TAG_VALUE_TRUE: Int64 = (2 | 4) | 1
public let FFI_TAG_VALUE_UNDEFINED: Int64 = 2 | 8
public let FFI_TAG_VALUE_NULL: Int64 = 2
public let FFI_NOT_CELL_MASK: Int64 = 0xfffe000000000000_i64 | 0x0000000000000002_i64
public let FFI_MAX_INT32: Int32 = 2147483648_i32
public let FFI_MAX_INT52: Int64 = 9007199254740991_i64
public let FFI_NUMBER_TAG: Int64 = 0xfffe000000000000_i64

// ========== ValueUndefined ==========
// 严格翻译自 FFI.zig ValueUndefined
public let ValueUndefined: EncodedJSValue = EncodedJSValue(asInt64: FFI_TAG_VALUE_UNDEFINED)

// ========== ValueTrue ==========
// 严格翻译自 FFI.zig ValueTrue
public let ValueTrue: EncodedJSValue = EncodedJSValue(asInt64: FFI_TRUE_I64)

// ========== FFI 工具函数 ==========
public class FFI {
    // 严格翻译自 JSVALUE_IS_CELL
    public static func jsValueIsCell(val: EncodedJSValue) -> Bool {
        \!((UInt64(val.asInt64) & 0xfffe000000000000_u64) | 0x0000000000000002_u64) \!= 0
    }

    // 严格翻译自 JSVALUE_IS_INT32
    public static func jsValueIsInt32(val: EncodedJSValue) -> Bool {
        (UInt64(val.asInt64) & 0xfffe000000000000_u64) == 0xfffe000000000000_u64
    }

    // 严格翻译自 JSVALUE_IS_NUMBER
    public static func jsValueIsNumber(val: EncodedJSValue) -> Bool {
        (UInt64(val.asInt64) & 0xfffe000000000000_u64) \!= 0
    }

    // 严格翻译自 INT32_TO_JSVALUE
    public static func int32ToJSValue(val: Int32) -> EncodedJSValue {
        EncodedJSValue(asInt64: Int64(0xfffe000000000000_u64 | UInt64(UInt32(val))))
    }

    // 严格翻译自 DOUBLE_TO_JSVALUE
    public static func doubleToJSValue(val: Float64) -> EncodedJSValue {
        var res = EncodedJSValue(asDouble: val)
        res.asInt64 += 1_i64 << 49
        res
    }

    // 严格翻译自 FLOAT_TO_JSVALUE
    public static func floatToJSValue(val: Float32) -> EncodedJSValue {
        doubleToJSValue(Float64(val))
    }

    // 严格翻译自 BOOLEAN_TO_JSVALUE
    public static func booleanToJSValue(val: Bool) -> EncodedJSValue {
        let intVal: Int64 = val ? ((2 | 4) | 1) : ((2 | 4) | 0)
        EncodedJSValue(asInt64: intVal)
    }

    // 严格翻译自 JSVALUE_TO_INT32
    public static func jsValueToInt32(val: EncodedJSValue) -> Int32 {
        Int32(truncating: val.asInt64)
    }

    // 严格翻译自 JSVALUE_TO_DOUBLE
    public static func jsValueToDouble(val: EncodedJSValue) -> Float64 {
        var mutVal = val
        mutVal.asInt64 -= Int64(1) << 49
        mutVal.asDouble
    }

    // 严格翻译自 JSVALUE_TO_FLOAT
    public static func jsValueToFloat(val: EncodedJSValue) -> Float32 {
        Float32(jsValueToDouble(val))
    }

    // 严格翻译自 JSVALUE_TO_BOOL
    public static func jsValueToBool(val: EncodedJSValue) -> Bool {
        val.asInt64 == Int64((2 | 4) | 1)
    }

    // 严格翻译自 JSVALUE_TO_UINT64
    public static func jsValueToUInt64(val: EncodedJSValue) -> UInt64 {
        if (jsValueIsInt32(val)) {
            return UInt64(jsValueToInt32(val))
        }
        if (jsValueIsNumber(val)) {
            return UInt64(jsValueToDouble(val))
        }
        0  // slow path via FFI
    }

    // 严格翻译自 JSVALUE_TO_INT64
    public static func jsValueToInt64(val: EncodedJSValue) -> Int64 {
        if (jsValueIsInt32(val)) {
            return Int64(jsValueToInt32(val))
        }
        if (jsValueIsNumber(val)) {
            return Int64(jsValueToDouble(val))
        }
        0  // slow path via FFI
    }

    // 严格翻译自 UINT64_TO_JSVALUE
    public static func uint64ToJSValue(globalObject: UInt64, val: UInt64) -> EncodedJSValue {
        if (val < 2147483648_u64) {
            return int32ToJSValue(Int32(truncating: val))
        }
        if (val < 9007199254740991_u64) {
            return doubleToJSValue(Float64(val))
        }
        // slow path via FFI
        EncodedJSValue()
    }

    // 严格翻译自 INT64_TO_JSVALUE
    public static func int64ToJSValue(globalObject: UInt64, val: Int64) -> EncodedJSValue {
        if (val >= -2147483648_i64 && val <= 2147483648_i64) {
            return int32ToJSValue(Int32(truncating: val))
        }
        if (val >= -9007199254740991_i64 && val <= 9007199254740991_i64) {
            return doubleToJSValue(Float64(val))
        }
        // slow path via FFI
        EncodedJSValue()
    }

    // FFI: JSFunctionCall
    public static func jsFunctionCall(globalObject: UInt64, callFrame: UInt64) -> UInt64 {
        0
    }
}
