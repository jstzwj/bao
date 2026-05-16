// js_native_api_types.cj - N-API 基础类型定义
// 翻译自 Bun 源文件: src/runtime/napi/js_native_api_types.h
// 定义 N-API 的核心类型，包括 napi_env, napi_value, napi_ref 等不透明指针，
// 以及 napi_status, napi_valuetype, napi_typedarray_type 等枚举。

package bao_runtime.napi

// ============================================================================
// 不透明指针类型 (Opaque pointer types)
// 对应 Bun: js_native_api_types.h 中的 struct 前向声明
// N-API API 类型均为不透明指针，用于 ABI 稳定性
// ============================================================================

/// N-API 环境
/// 对应 C: typedef struct NapiEnv* napi_env
public class NapiEnvHandle {}

/// N-API 值
/// 对应 C: typedef struct napi_value__* napi_value
public class NapiValueHandle {}

/// N-API 引用
/// 对应 C: typedef struct napi_ref__* napi_ref
public class NapiRefHandle {}

/// N-API 句柄作用域
/// 对应 C: typedef struct napi_handle_scope__* napi_handle_scope
public class NapiHandleScopeHandle {}

/// N-API 可转义句柄作用域
/// 对应 C: typedef struct napi_escapable_handle_scope__* napi_escapable_handle_scope
public class NapiEscapableHandleScopeHandle {}

/// N-API 回调信息
/// 对应 C: typedef struct napi_callback_info__* napi_callback_info
public class NapiCallbackInfoHandle {}

/// N-API Deferred (Promise)
/// 对应 C: typedef struct napi_deferred__* napi_deferred
public class NapiDeferredHandle {}

// ============================================================================
// napi_property_attributes - 属性特性
// 对应 Bun: js_native_api_types.h - napi_property_attributes
// ============================================================================

/// N-API 属性特性
/// 对应 C: napi_property_attributes enum
public enum NapiPropertyAttributes {
    | napiDefault           // 0
    | napiWritable          // 1 << 0
    | napiEnumerable        // 1 << 1
    | napiConfigurable      // 1 << 2
    | napiStatic            // 1 << 10
    | napiDefaultMethod     // napiWritable | napiConfigurable
    | napiDefaultJsproperty // napiWritable | napiEnumerable | napiConfigurable

    public func toInt(): UInt32 {
        match (this) {
            case napiDefault => 0
            case napiWritable => 1
            case napiEnumerable => 2
            case napiConfigurable => 4
            case napiStatic => 1024
            case napiDefaultMethod => 5    // 1 | 4
            case napiDefaultJsproperty => 7 // 1 | 2 | 4
        }
    }

    /// 检查是否包含写入权限
    public func isWritable(): Bool {
        return (this.toInt() & 1) != 0
    }

    /// 检查是否可枚举
    public func isEnumerable(): Bool {
        return (this.toInt() & 2) != 0
    }

    /// 检查是否可配置
    public func isConfigurable(): Bool {
        return (this.toInt() & 4) != 0
    }

    /// 检查是否为静态属性
    public func isStatic(): Bool {
        return (this.toInt() & 1024) != 0
    }
}

// ============================================================================
// napi_valuetype - 值类型
// 对应 Bun: js_native_api_types.h - napi_valuetype
// ============================================================================

/// N-API 值类型 (对应 typeof)
/// 对应 C: napi_valuetype enum
public enum NapiValueTypeEnum {
    | napiUndefined  // 0
    | napiNull       // 1
    | napiBoolean    // 2
    | napiNumber     // 3
    | napiString     // 4
    | napiSymbol     // 5
    | napiObject     // 6
    | napiFunction   // 7
    | napiExternal   // 8
    | napiBigint     // 9

    public func toInt(): UInt32 {
        match (this) {
            case napiUndefined => 0
            case napiNull => 1
            case napiBoolean => 2
            case napiNumber => 3
            case napiString => 4
            case napiSymbol => 5
            case napiObject => 6
            case napiFunction => 7
            case napiExternal => 8
            case napiBigint => 9
        }
    }

    public static func fromInt(value: UInt32): NapiValueTypeEnum {
        match (value) {
            case 0 => napiUndefined
            case 1 => napiNull
            case 2 => napiBoolean
            case 3 => napiNumber
            case 4 => napiString
            case 5 => napiSymbol
            case 6 => napiObject
            case 7 => napiFunction
            case 8 => napiExternal
            case 9 => napiBigint
            case _ => napiUndefined
        }
    }
}

// ============================================================================
// napi_typedarray_type - TypedArray 类型
// 对应 Bun: js_native_api_types.h - napi_typedarray_type
// ============================================================================

/// N-API TypedArray 类型
/// 对应 C: napi_typedarray_type enum
public enum NapiTypedArrayTypeEnum {
    | napiInt8Array           // 0
    | napiUint8Array          // 1
    | napiUint8ClampedArray   // 2
    | napiInt16Array          // 3
    | napiUint16Array         // 4
    | napiInt32Array          // 5
    | napiUint32Array         // 6
    | napiFloat32Array        // 7
    | napiFloat64Array        // 8
    | napiBigint64Array       // 9
    | napiBiguint64Array      // 10

    public func toInt(): UInt32 {
        match (this) {
            case napiInt8Array => 0
            case napiUint8Array => 1
            case napiUint8ClampedArray => 2
            case napiInt16Array => 3
            case napiUint16Array => 4
            case napiInt32Array => 5
            case napiUint32Array => 6
            case napiFloat32Array => 7
            case napiFloat64Array => 8
            case napiBigint64Array => 9
            case napiBiguint64Array => 10
        }
    }

    public static func fromInt(value: UInt32): NapiTypedArrayTypeEnum {
        match (value) {
            case 0 => napiInt8Array
            case 1 => napiUint8Array
            case 2 => napiUint8ClampedArray
            case 3 => napiInt16Array
            case 4 => napiUint16Array
            case 5 => napiInt32Array
            case 6 => napiUint32Array
            case 7 => napiFloat32Array
            case 8 => napiFloat64Array
            case 9 => napiBigint64Array
            case 10 => napiBiguint64Array
            case _ => napiInt8Array
        }
    }

    /// 获取每个元素的字节大小
    public func elementSize(): Int64 {
        match (this) {
            case napiInt8Array => 1
            case napiUint8Array => 1
            case napiUint8ClampedArray => 1
            case napiInt16Array => 2
            case napiUint16Array => 2
            case napiInt32Array => 4
            case napiUint32Array => 4
            case napiFloat32Array => 4
            case napiFloat64Array => 8
            case napiBigint64Array => 8
            case napiBiguint64Array => 8
        }
    }
}

// ============================================================================
// napi_status - 状态码
// 对应 Bun: js_native_api_types.h - napi_status
// ============================================================================

/// N-API 状态码枚举
/// 对应 C: napi_status enum
public enum NapiStatusEnum {
    | napiOk                               // 0
    | napiInvalidArg                       // 1
    | napiObjectExpected                   // 2
    | napiStringExpected                   // 3
    | napiNameExpected                     // 4
    | napiFunctionExpected                 // 5
    | napiNumberExpected                   // 6
    | napiBooleanExpected                  // 7
    | napiArrayExpected                    // 8
    | napiGenericFailure                   // 9
    | napiPendingException                 // 10
    | napiCancelled                        // 11
    | napiEscapeCalledTwice                // 12
    | napiHandleScopeMismatch              // 13
    | napiCallbackScopeMismatch            // 14
    | napiQueueFull                        // 15
    | napiClosing                          // 16
    | napiBigintExpected                   // 17
    | napiDateExpected                     // 18
    | napiArraybufferExpected              // 19
    | napiDetachableArraybufferExpected    // 20
    | napiWouldDeadlock                    // 21 (unused)
    | napiNoExternalBuffersAllowed         // 22
    | napiCannotRunJs                      // 23

    public func toInt(): UInt32 {
        match (this) {
            case napiOk => 0
            case napiInvalidArg => 1
            case napiObjectExpected => 2
            case napiStringExpected => 3
            case napiNameExpected => 4
            case napiFunctionExpected => 5
            case napiNumberExpected => 6
            case napiBooleanExpected => 7
            case napiArrayExpected => 8
            case napiGenericFailure => 9
            case napiPendingException => 10
            case napiCancelled => 11
            case napiEscapeCalledTwice => 12
            case napiHandleScopeMismatch => 13
            case napiCallbackScopeMismatch => 14
            case napiQueueFull => 15
            case napiClosing => 16
            case napiBigintExpected => 17
            case napiDateExpected => 18
            case napiArraybufferExpected => 19
            case napiDetachableArraybufferExpected => 20
            case napiWouldDeadlock => 21
            case napiNoExternalBuffersAllowed => 22
            case napiCannotRunJs => 23
        }
    }

    public static func fromInt(value: UInt32): NapiStatusEnum {
        match (value) {
            case 0 => napiOk
            case 1 => napiInvalidArg
            case 2 => napiObjectExpected
            case 3 => napiStringExpected
            case 4 => napiNameExpected
            case 5 => napiFunctionExpected
            case 6 => napiNumberExpected
            case 7 => napiBooleanExpected
            case 8 => napiArrayExpected
            case 9 => napiGenericFailure
            case 10 => napiPendingException
            case 11 => napiCancelled
            case 12 => napiEscapeCalledTwice
            case 13 => napiHandleScopeMismatch
            case 14 => napiCallbackScopeMismatch
            case 15 => napiQueueFull
            case 16 => napiClosing
            case 17 => napiBigintExpected
            case 18 => napiDateExpected
            case 19 => napiArraybufferExpected
            case 20 => napiDetachableArraybufferExpected
            case 21 => napiWouldDeadlock
            case 22 => napiNoExternalBuffersAllowed
            case 23 => napiCannotRunJs
            case _ => napiGenericFailure
        }
    }
}

// ============================================================================
// 回调函数类型
// 对应 Bun: js_native_api_types.h - napi_callback, napi_finalize
// ============================================================================

/// N-API 回调函数类型
/// 对应 C: typedef napi_value (*napi_callback)(napi_env env, napi_callback_info info)
public type NapiCallbackFn = (NapiEnv, NapiCallbackInfo) -> NapiValue

/// N-API 终结器函数类型
/// 对应 C: typedef void (*napi_finalize)(napi_env env, void* finalize_data, void* finalize_hint)
public type NapiFinalizeFn = (NapiEnv, ?Any, ?Any) -> Unit

// ============================================================================
// napi_property_descriptor - 属性描述符
// 对应 Bun: js_native_api_types.h - napi_property_descriptor
// ============================================================================

/// N-API 属性描述符
/// 对应 C: napi_property_descriptor struct
public class NapiPropertyDescriptorC {
    /// UTF-8 名称 (与 name 二选一)
    public var utf8name: ?String = None
    /// 名称值
    public var name: ?NapiValue = None
    /// 方法回调
    public var method: ?NapiCallbackFn = None
    /// Getter 回调
    public var getter: ?NapiCallbackFn = None
    /// Setter 回调
    public var setter: ?NapiCallbackFn = None
    /// 属性值
    public var value: ?NapiValue = None
    /// 属性特性
    public var attributes: NapiPropertyAttributes = NapiPropertyAttributes.napiDefault
    /// 透传数据
    public var data: ?Any = None

    public init() {}
}

// ============================================================================
// napi_extended_error_info - 扩展错误信息
// 对应 Bun: js_native_api_types.h - napi_extended_error_info
// ============================================================================

/// N-API 扩展错误信息
/// 对应 C: napi_extended_error_info struct
public class NapiExtendedErrorInfoStruct {
    /// 错误消息
    public var errorMessage: ?String = None
    /// 引擎保留字段
    public var engineReserved: ?Any = None
    /// 引擎错误码
    public var engineErrorCode: UInt32 = 0
    /// N-API 错误码
    public var errorCode: NapiStatusEnum = NapiStatusEnum.napiOk

    public init() {}
}

// ============================================================================
// napi_key_collection_mode - 键集合模式
// 对应 Bun: js_native_api_types.h - napi_key_collection_mode (NAPI_VERSION >= 6)
// ============================================================================

/// N-API 键集合模式
/// 对应 C: napi_key_collection_mode enum
public enum NapiKeyCollectionMode {
    | napiKeyIncludePrototypes // 0
    | napiKeyOwnOnly           // 1
}

// ============================================================================
// napi_key_filter - 键过滤器
// 对应 Bun: js_native_api_types.h - napi_key_filter (NAPI_VERSION >= 6)
// ============================================================================

/// N-API 键过滤器
/// 对应 C: napi_key_filter enum (位标志)
public enum NapiKeyFilter {
    | napiKeyAllProperties // 0
    | napiKeyWritable      // 1
    | napiKeyEnumerable    // 1 << 1
    | napiKeyConfigurable  // 1 << 2
    | napiKeySkipStrings   // 1 << 3
    | napiKeySkipSymbols   // 1 << 4

    public func toInt(): UInt32 {
        match (this) {
            case napiKeyAllProperties => 0
            case napiKeyWritable => 1
            case napiKeyEnumerable => 2
            case napiKeyConfigurable => 4
            case napiKeySkipStrings => 8
            case napiKeySkipSymbols => 16
        }
    }
}

// ============================================================================
// napi_key_conversion - 键转换模式
// 对应 Bun: js_native_api_types.h - napi_key_conversion (NAPI_VERSION >= 6)
// ============================================================================

/// N-API 键转换模式
/// 对应 C: napi_key_conversion enum
public enum NapiKeyConversion {
    | napiKeyKeepNumbers      // 0
    | napiKeyNumbersToStrings // 1
}

// ============================================================================
// napi_type_tag - 类型标签
// 对应 Bun: js_native_api_types.h - napi_type_tag (NAPI_VERSION >= 8)
// ============================================================================

/// N-API 类型标签
/// 对应 C: napi_type_tag struct
public class NapiTypeTagStruct {
    public var lower: UInt64
    public var upper: UInt64

    public init(lower: UInt64, upper: UInt64) {
        this.lower = lower
        this.upper = upper
    }

    public init() {
        this.lower = 0
        this.upper = 0
    }
}
