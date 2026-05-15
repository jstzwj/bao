// napi.cj - Node-API (N-API) 兼容层
// 对应 Bun 源文件: src/runtime/napi/napi.zig
// 实现 Node.js 的 N-API 接口，使原生模块可以在 Bao 运行时中加载

package bao_runtime.napi

// ============================================================================
// N-API 状态码
// 对应 Bun: napi.zig - NapiStatus
// ============================================================================

/// N-API 状态码枚举
/// 对应 Bun: NapiStatus
public enum NapiStatus {
    | ok                     // 0
    | invalidArg             // 1
    | objectExpected         // 2
    | stringExpected         // 3
    | nameExpected           // 4
    | functionExpected       // 5
    | numberExpected         // 6
    | booleanExpected        // 7
    | arrayExpected          // 8
    | genericFailure         // 9
    | pendingException       // 10
    | cancelled              // 11
    | escapeCalledTwice      // 12
    | handleScopeMismatch    // 13
    | callbackScopeMismatch  // 14
    | queueFull              // 15
    | closing                // 16
    | bigintExpected         // 17
    | dateExpected           // 18
    | arraybufferExpected    // 19
    | detachableArraybufferExpected // 20
    | wouldDeadlock          // 21

    public func toInt(): UInt32 {
        match (this) {
            case ok => 0
            case invalidArg => 1
            case objectExpected => 2
            case stringExpected => 3
            case nameExpected => 4
            case functionExpected => 5
            case numberExpected => 6
            case booleanExpected => 7
            case arrayExpected => 8
            case genericFailure => 9
            case pendingException => 10
            case cancelled => 11
            case escapeCalledTwice => 12
            case handleScopeMismatch => 13
            case callbackScopeMismatch => 14
            case queueFull => 15
            case closing => 16
            case bigintExpected => 17
            case dateExpected => 18
            case arraybufferExpected => 19
            case detachableArraybufferExpected => 20
            case wouldDeadlock => 21
        }
    }
}

// ============================================================================
// N-API 值类型
// 对应 Bun: napi.zig - napi_valuetype
// ============================================================================

/// N-API 值类型
/// 对应 Bun: napi_valuetype
public enum NapiValueType {
    | undefined  // 0
    | nNull      // 1
    | boolean    // 2
    | number     // 3
    | string     // 4
    | symbol     // 5
    | object     // 6
    | function   // 7
    | external   // 8
    | bigint     // 9

    public func toInt(): UInt32 {
        match (this) {
            case undefined => 0
            case nNull => 1
            case boolean => 2
            case number => 3
            case string => 4
            case symbol => 5
            case object => 6
            case function => 7
            case external => 8
            case bigint => 9
        }
    }
}

// ============================================================================
// N-API TypedArray 类型
// 对应 Bun: napi.zig - napi_typedarray_type
// ============================================================================

/// N-API TypedArray 类型
/// 对应 Bun: napi_typedarray_type
public enum NapiTypedArrayType {
    | int8Array           // 0
    | uint8Array          // 1
    | uint8ClampedArray   // 2
    | int16Array          // 3
    | uint16Array         // 4
    | int32Array          // 5
    | uint32Array         // 6
    | float32Array        // 7
    | float64Array        // 8
    | bigint64Array       // 9
    | biguint64Array      // 10

    public func toJsType(): String {
        match (this) {
            case int8Array => "Int8Array"
            case uint8Array => "Uint8Array"
            case uint8ClampedArray => "Uint8ClampedArray"
            case int16Array => "Int16Array"
            case uint16Array => "Uint16Array"
            case int32Array => "Int32Array"
            case uint32Array => "Uint32Array"
            case float32Array => "Float32Array"
            case float64Array => "Float64Array"
            case bigint64Array => "BigInt64Array"
            case biguint64Array => "BigUint64Array"
        }
    }
}

// ============================================================================
// NapiEnv - N-API 环境
// 对应 Bun: napi.zig - NapiEnv
// ============================================================================

/// N-API 环境（对应 struct napi_env__）
/// 对应 Bun: NapiEnv
public class NapiEnv {
    public var globalObject: JsObject

    public init(globalObject: JsObject) {
        this.globalObject = globalObject
    }

    /// 转为 JS 全局对象
    /// 对应 Bun: NapiEnv.toJS
    public func toJS(): JsObject {
        return globalObject
    }

    /// 设置最后的错误码
    /// 对应 Bun: NapiEnv.setLastError
    public func setLastError(err: NapiStatus): UInt32 {
        return err.toInt()
    }

    /// 便捷方法：返回 ok
    /// 对应 Bun: NapiEnv.ok
    public func ok(): UInt32 {
        return setLastError(NapiStatus.ok)
    }

    /// 返回 invalid_arg 错误
    /// 对应 Bun: NapiEnv.invalidArg
    public func invalidArg(): UInt32 {
        return setLastError(NapiStatus.invalidArg)
    }

    /// 返回 generic_failure 错误
    /// 对应 Bun: NapiEnv.genericFailure
    public func genericFailure(): UInt32 {
        return setLastError(NapiStatus.genericFailure)
    }

    /// 检查是否正在进行垃圾回收
    /// 对应 Bun: NapiEnv.checkGC
    public func checkGC(): Unit {
        // 简化实现
    }

    /// 获取版本号
    /// 对应 Bun: NapiEnv.getVersion
    public func getVersion(): UInt32 {
        return 9 // N-API 版本 9
    }

    /// 获取并清除待处理的异常
    /// 对应 Bun: NapiEnv.getAndClearPendingException
    public func getAndClearPendingException(): ?JsValue {
        // 简化实现
        return None
    }
}

// ============================================================================
// NapiHandleScope - 句柄作用域
// 对应 Bun: napi.zig - NapiHandleScope
// ============================================================================

/// N-API 句柄作用域
/// 对应 Bun: NapiHandleScope
public class NapiHandleScope {
    public var escapable: Bool = false
    public var values: ArrayList<JsValue> = ArrayList<JsValue>()
    public var escaped: Bool = false

    public init() {}

    public init(escapable: Bool) {
        this.escapable = escapable
    }

    /// 打开新的句柄作用域
    /// 对应 Bun: NapiHandleScope.open
    public static func open(env: NapiEnv, escapable: Bool): ?NapiHandleScope {
        return NapiHandleScope(escapable: escapable)
    }

    /// 关闭句柄作用域
    /// 对应 Bun: NapiHandleScope.close
    public func close(env: NapiEnv): Unit {
        values.clear()
    }

    /// 将值添加到句柄作用域
    /// 对应 Bun: NapiHandleScope.append
    public static func append(env: NapiEnv, value: JsValue): Unit {
        // 简化实现：保持值存活
    }

    /// 转义值到父作用域
    /// 对应 Bun: NapiHandleScope.escape
    public func escape(value: JsValue): Unit {
        if (escaped) {
            return // escape_called_twice
        }
        escaped = true
    }
}

// ============================================================================
// napi_value - N-API 值封装
// 对应 Bun: napi.zig - napi_value
// ============================================================================

/// N-API 值
/// 对应 Bun: napi_value
public class NapiValue {
    public var jsValue: JsValue

    public init(value: JsValue) {
        this.jsValue = value
    }

    /// 设置 napi_value（添加到句柄作用域）
    /// 对应 Bun: napi_value.set
    public func set(env: NapiEnv, val: JsValue): Unit {
        NapiHandleScope.append(env, val)
        jsValue = val
    }

    /// 获取底层的 JSValue
    /// 对应 Bun: napi_value.get
    public func get(): JsValue {
        return jsValue
    }

    /// 创建新的 napi_value
    /// 对应 Bun: napi_value.create
    public static func create(env: NapiEnv, val: JsValue): NapiValue {
        NapiHandleScope.append(env, val)
        return NapiValue(val)
    }
}

// ============================================================================
// 属性描述符
// 对应 Bun: napi.zig - napi_property_descriptor
// ============================================================================

/// N-API 属性描述符
/// 对应 Bun: napi_property_descriptor
public class NapiPropertyDescriptor {
    public var utf8name: ?String = None
    public var name: ?NapiValue = None
    public var method: ?NapiCallback = None
    public var getter: ?NapiCallback = None
    public var setter: ?NapiCallback = None
    public var value: ?NapiValue = None
    public var attributes: UInt32 = 0
    public var data: ?Any = None

    public init() {}
}

/// N-API 回调类型
public type NapiCallback = (NapiEnv, NapiCallbackInfo) -> NapiValue

// ============================================================================
// 扩展错误信息
// 对应 Bun: napi.zig - napi_extended_error_info
// ============================================================================

/// N-API 扩展错误信息
/// 对应 Bun: napi_extended_error_info
public class NapiExtendedErrorInfo {
    public var errorMessage: ?String = None
    public var engineReserved: ?Any = None
    public var engineErrorCode: UInt32 = 0
    public var errorCode: UInt32 = 0

    public init() {}
}

// ============================================================================
// 类型标签
// 对应 Bun: napi.zig - napi_type_tag
// ============================================================================

/// N-API 类型标签
/// 对应 Bun: napi_type_tag
public class NapiTypeTag {
    public var lower: UInt64
    public var upper: UInt64

    public init(lower: UInt64, upper: UInt64) {
        this.lower = lower
        this.upper = upper
    }
}

// ============================================================================
// 回调信息
// 对应 Bun: napi.zig - napi_callback_info
// ============================================================================

/// N-API 回调信息
/// 对应 Bun: napi_callback_info = *jsc.CallFrame
public class NapiCallbackInfo {
    public var arguments: ArrayList<JsValue>
    public var thisArg: JsValue
    public var data: ?Any = None

    public init(args: ArrayList<JsValue>, thisArg: JsValue) {
        this.arguments = args
        this.thisArg = thisArg
    }
}

/// N-API 引用
/// 对应 Bun: napi_ref
public class NapiRef {
    public var value: ?JsValue = None
    public var refCount: UInt32 = 0

    public init() {}
}

// ============================================================================
// N-API 导出函数实现
// 对应 Bun: napi.zig 中的 export fn
// ============================================================================

/// N-API 函数实现
/// 封装所有 napi_* 函数
public class NapiFunctions {
    /// NAPI_AUTO_LENGTH 常量
    public static let NAPI_AUTO_LENGTH: Int64 = Int64(-1)

    // ========================================================================
    // 基本值创建
    // ========================================================================

    /// napi_get_undefined
    /// 对应 Bun: napi_get_undefined
    public static func getUndefined(env: NapiEnv): NapiValue {
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    /// napi_get_null
    /// 对应 Bun: napi_get_null
    public static func getNull(env: NapiEnv): NapiValue {
        return NapiValue.create(env, JsValue.NULL)
    }

    /// napi_get_global
    /// 对应 Bun: napi_get_global
    public static func getGlobal(env: NapiEnv): NapiValue {
        return NapiValue.create(env, JsValue(env.toJS()))
    }

    /// napi_get_boolean
    /// 对应 Bun: napi_get_boolean
    public static func getBoolean(env: NapiEnv, value: Bool): NapiValue {
        return NapiValue.create(env, JsValue(value))
    }

    /// napi_create_array
    /// 对应 Bun: napi_create_array
    public static func createArray(env: NapiEnv): NapiValue {
        return NapiValue.create(env, JsValue.array(ArrayList<JsValue>()))
    }

    /// napi_create_array_with_length
    /// 对应 Bun: napi_create_array_with_length
    public static func createArrayWithLength(env: NapiEnv, length: Int64): NapiValue {
        val len = if (length > 0) { UInt32(length) } else { 0 }
        return NapiValue.create(env, JsValue.array(ArrayList<JsValue>()))
    }

    /// napi_create_double
    /// 对应 Bun: napi_create_double (extern)
    public static func createDouble(env: NapiEnv, value: Float64): NapiValue {
        return NapiValue.create(env, JsValue(value))
    }

    /// napi_create_int32
    /// 对应 Bun: napi_create_int32
    public static func createInt32(env: NapiEnv, value: Int32): NapiValue {
        return NapiValue.create(env, JsValue(Float64(value)))
    }

    /// napi_create_uint32
    /// 对应 Bun: napi_create_uint32
    public static func createUint32(env: NapiEnv, value: UInt32): NapiValue {
        return NapiValue.create(env, JsValue(Float64(value)))
    }

    /// napi_create_int64
    /// 对应 Bun: napi_create_int64
    public static func createInt64(env: NapiEnv, value: Int64): NapiValue {
        return NapiValue.create(env, JsValue(Float64(value)))
    }

    // ========================================================================
    // 字符串创建
    // ========================================================================

    /// napi_create_string_latin1
    /// 对应 Bun: napi_create_string_latin1
    public static func createStringLatin1(env: NapiEnv, str: ?String, length: Int64): NapiValue {
        if (str == None) {
            return NapiValue.create(env, JsValue(""))
        }
        return NapiValue.create(env, JsValue(str!))
    }

    /// napi_create_string_utf8
    /// 对应 Bun: napi_create_string_utf8
    public static func createStringUtf8(env: NapiEnv, str: ?String, length: Int64): NapiValue {
        if (str == None) {
            return NapiValue.create(env, JsValue(""))
        }
        return NapiValue.create(env, JsValue(str!))
    }

    /// napi_create_string_utf16
    /// 对应 Bun: napi_create_string_utf16
    public static func createStringUtf16(env: NapiEnv, str: ?String, length: Int64): NapiValue {
        if (str == None) {
            return NapiValue.create(env, JsValue(""))
        }
        return NapiValue.create(env, JsValue(str!))
    }

    /// napi_create_object
    /// 对应 Bun: napi_create_object (extern)
    public static func createObject(env: NapiEnv): NapiValue {
        return NapiValue.create(env, JsValue(JsObject()))
    }

    /// napi_create_symbol
    /// 对应 Bun: napi_create_symbol (extern)
    public static func createSymbol(env: NapiEnv, description: NapiValue): NapiValue {
        // 简化实现
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    // ========================================================================
    // 错误创建
    // ========================================================================

    /// napi_create_error
    /// 对应 Bun: napi_create_error (extern)
    public static func createError(env: NapiEnv, code: NapiValue, msg: NapiValue): NapiValue {
        val errorObj = JsObject()
        errorObj.set("message", msg.get())
        if (!code.get().isUndefinedOrNull()) {
            errorObj.set("code", code.get())
        }
        return NapiValue.create(env, JsValue(errorObj))
    }

    /// napi_create_type_error
    /// 对应 Bun: napi_create_type_error (extern)
    public static func createTypeError(env: NapiEnv, code: NapiValue, msg: NapiValue): NapiValue {
        val errorObj = JsObject()
        errorObj.set("message", msg.get())
        if (!code.get().isUndefinedOrNull()) {
            errorObj.set("code", code.get())
        }
        errorObj.set("name", JsValue("TypeError"))
        return NapiValue.create(env, JsValue(errorObj))
    }

    /// napi_create_range_error
    /// 对应 Bun: napi_create_range_error (extern)
    public static func createRangeError(env: NapiEnv, code: NapiValue, msg: NapiValue): NapiValue {
        val errorObj = JsObject()
        errorObj.set("message", msg.get())
        if (!code.get().isUndefinedOrNull()) {
            errorObj.set("code", code.get())
        }
        errorObj.set("name", JsValue("RangeError"))
        return NapiValue.create(env, JsValue(errorObj))
    }

    // ========================================================================
    // 值类型检查
    // ========================================================================

    /// napi_typeof
    /// 对应 Bun: napi_typeof (extern)
    public static func typeOf(env: NapiEnv, value: NapiValue): NapiValueType {
        val v = value.get()
        match (v.valueType) {
            case JsValueType.Undefined => return NapiValueType.undefined
            case JsValueType.Null => return NapiValueType.nNull
            case JsValueType.Boolean => return NapiValueType.boolean
            case JsValueType.Number => return NapiValueType.number
            case JsValueType.String => return NapiValueType.string
            case JsValueType.Symbol => return NapiValueType.symbol
            case JsValueType.Function => return NapiValueType.function
            case JsValueType.Object => return NapiValueType.object
            case JsValueType.BigInt => return NapiValueType.bigint
            case _ => return NapiValueType.undefined
        }
    }

    /// napi_is_array
    /// 对应 Bun: napi_is_array
    public static func isArray(env: NapiEnv, value: NapiValue): Bool {
        return value.get().valueType == JsValueType.Array
    }

    /// napi_is_arraybuffer
    /// 对应 Bun: napi_is_arraybuffer
    public static func isArrayBuffer(env: NapiEnv, value: NapiValue): Bool {
        return value.get().valueType == JsValueType.ArrayBuffer
    }

    /// napi_is_typedarray
    /// 对应 Bun: napi_is_typedarray (extern)
    public static func isTypedArray(env: NapiEnv, value: NapiValue): Bool {
        return value.get().valueType == JsValueType.TypedArray
    }

    /// napi_is_dataview
    /// 对应 Bun: napi_is_dataview
    public static func isDataView(env: NapiEnv, value: NapiValue): Bool {
        return value.get().valueType == JsValueType.DataView
    }

    /// napi_is_error
    /// 对应 Bun: napi_is_error
    public static func isError(env: NapiEnv, value: NapiValue): Bool {
        return value.get().valueType == JsValueType.Error
    }

    /// napi_is_promise
    /// 对应 Bun: napi_is_promise
    public static func isPromise(env: NapiEnv, value: NapiValue): Bool {
        return value.get().valueType == JsValueType.Promise
    }

    // ========================================================================
    // 值提取
    // ========================================================================

    /// napi_get_value_double
    /// 对应 Bun: napi_get_value_double (extern)
    public static func getValueDouble(env: NapiEnv, value: NapiValue): Float64 {
        return value.get().toNumber()
    }

    /// napi_get_value_int32
    /// 对应 Bun: napi_get_value_int32 (extern)
    public static func getValueInt32(env: NapiEnv, value: NapiValue): Int32 {
        return Int32(value.get().toNumber())
    }

    /// napi_get_value_uint32
    /// 对应 Bun: napi_get_value_uint32 (extern)
    public static func getValueUint32(env: NapiEnv, value: NapiValue): UInt32 {
        return UInt32(value.get().toNumber())
    }

    /// napi_get_value_int64
    /// 对应 Bun: napi_get_value_int64 (extern)
    public static func getValueInt64(env: NapiEnv, value: NapiValue): Int64 {
        return Int64(value.get().toNumber())
    }

    /// napi_get_value_bool
    /// 对应 Bun: napi_get_value_bool (extern)
    public static func getValueBool(env: NapiEnv, value: NapiValue): Bool {
        return value.get().toBoolean()
    }

    /// napi_get_value_string_utf8
    /// 对应 Bun: napi_get_value_string_utf8 (extern)
    public static func getValueStringUtf8(env: NapiEnv, value: NapiValue): String {
        return value.get().toString()
    }

    /// napi_get_array_length
    /// 对应 Bun: napi_get_array_length
    public static func getArrayLength(env: NapiEnv, value: NapiValue): UInt32 {
        val v = value.get()
        match (v.arrayData) {
            case Some(arr) => return UInt32(arr.size)
            case None => return 0
        }
    }

    // ========================================================================
    // 强制转换
    // ========================================================================

    /// napi_coerce_to_bool
    /// 对应 Bun: napi_coerce_to_bool (extern)
    public static func coerceToBool(env: NapiEnv, value: NapiValue): NapiValue {
        return NapiValue.create(env, JsValue(value.get().toBoolean()))
    }

    /// napi_coerce_to_number
    /// 对应 Bun: napi_coerce_to_number (extern)
    public static func coerceToNumber(env: NapiEnv, value: NapiValue): NapiValue {
        return NapiValue.create(env, JsValue(value.get().toNumber()))
    }

    /// napi_coerce_to_object
    /// 对应 Bun: napi_coerce_to_object (extern)
    public static func coerceToObject(env: NapiEnv, value: NapiValue): NapiValue {
        return NapiValue.create(env, value.get())
    }

    // ========================================================================
    // 比较操作
    // ========================================================================

    /// napi_strict_equals
    /// 对应 Bun: napi_strict_equals
    public static func strictEquals(env: NapiEnv, lhs: NapiValue, rhs: NapiValue): Bool {
        // 简化实现
        return lhs.get().toString() == rhs.get().toString()
    }

    // ========================================================================
    // 属性操作
    // ========================================================================

    /// napi_get_prototype
    /// 对应 Bun: napi_get_prototype
    public static func getPrototype(env: NapiEnv, object: NapiValue): NapiValue {
        val v = object.get()
        if (!v.isObject()) {
            return NapiValue.create(env, JsValue.NULL)
        }
        // 简化实现
        return NapiValue.create(env, JsValue.NULL)
    }

    // ========================================================================
    // 句柄作用域
    // ========================================================================

    /// napi_open_handle_scope
    /// 对应 Bun: napi_open_handle_scope
    public static func openHandleScope(env: NapiEnv): ?NapiHandleScope {
        return NapiHandleScope.open(env, false)
    }

    /// napi_close_handle_scope
    /// 对应 Bun: napi_close_handle_scope
    public static func closeHandleScope(env: NapiEnv, scope: NapiHandleScope): Unit {
        scope.close(env)
    }

    /// napi_open_escapable_handle_scope
    /// 对应 Bun: napi_open_escapable_handle_scope
    public static func openEscapableHandleScope(env: NapiEnv): ?NapiHandleScope {
        return NapiHandleScope.open(env, true)
    }

    /// napi_close_escapable_handle_scope
    /// 对应 Bun: napi_close_escapable_handle_scope
    public static func closeEscapableHandleScope(env: NapiEnv, scope: NapiHandleScope): Unit {
        scope.close(env)
    }

    /// napi_escape_handle
    /// 对应 Bun: napi_escape_handle
    public static func escapeHandle(env: NapiEnv, scope: NapiHandleScope, escapee: NapiValue): NapiValue {
        scope.escape(escapee.get())
        return escapee
    }

    // ========================================================================
    // 引用管理
    // ========================================================================

    /// napi_create_reference
    /// 对应 Bun: napi_create_reference (extern)
    public static func createReference(env: NapiEnv, value: NapiValue, initialRefCount: UInt32): NapiRef {
        val ref = NapiRef()
        ref.value = value.get()
        ref.refCount = initialRefCount
        return ref
    }

    /// napi_delete_reference
    /// 对应 Bun: napi_delete_reference (extern)
    public static func deleteReference(env: NapiEnv, ref: NapiRef): Unit {
        ref.value = None
    }

    /// napi_reference_ref
    /// 对应 Bun: napi_reference_ref (extern)
    public static func referenceRef(env: NapiEnv, ref: NapiRef): UInt32 {
        ref.refCount += 1
        return ref.refCount
    }

    /// napi_reference_unref
    /// 对应 Bun: napi_reference_unref (extern)
    public static func referenceUnref(env: NapiEnv, ref: NapiRef): UInt32 {
        if (ref.refCount > 0) {
            ref.refCount -= 1
        }
        return ref.refCount
    }

    /// napi_get_reference_value
    /// 对应 Bun: napi_get_reference_value (extern)
    public static func getReferenceValue(env: NapiEnv, ref: NapiRef): NapiValue {
        if (ref.value != None) {
            return NapiValue.create(env, ref.value!)
        }
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    // ========================================================================
    // Promise 操作
    // ========================================================================

    /// napi_create_promise
    /// 对应 Bun: napi_create_promise
    public static func createPromise(env: NapiEnv): NapiDeferred {
        val deferred = NapiDeferred()
        deferred.promise = JsPromise()
        return deferred
    }

    /// napi_resolve_deferred
    /// 对应 Bun: napi_resolve_deferred
    public static func resolveDeferred(env: NapiEnv, deferred: NapiDeferred, resolution: NapiValue): Unit {
        deferred.promise.resolve(resolution.get())
    }

    /// napi_reject_deferred
    /// 对应 Bun: napi_reject_deferred
    public static func rejectDeferred(env: NapiEnv, deferred: NapiDeferred, rejection: NapiValue): Unit {
        deferred.promise.reject(rejection.get())
    }

    // ========================================================================
    // 版本信息
    // ========================================================================

    /// napi_get_version
    /// 对应 Bun: napi_get_version
    public static func getVersion(env: NapiEnv): UInt32 {
        return 9 // 最高 N-API 版本
    }

    // ========================================================================
    // 异步上下文（简化实现）
    // ========================================================================

    /// napi_async_init
    /// 对应 Bun: napi_async_init
    public static func asyncInit(env: NapiEnv): NapiEnv {
        return env // 不支持异步上下文
    }

    /// napi_async_destroy
    /// 对应 Bun: napi_async_destroy
    public static func asyncDestroy(env: NapiEnv): Unit {
        // 不支持异步上下文
    }

    // ========================================================================
    // 回调作用域（空实现）
    // ========================================================================

    /// napi_open_callback_scope
    /// 对应 Bun: napi_open_callback_scope
    public static func openCallbackScope(): UInt32 {
        return NapiStatus.ok.toInt()
    }

    /// napi_close_callback_scope
    /// 对应 Bun: napi_close_callback_scope
    public static func closeCallbackScope(): UInt32 {
        return NapiStatus.ok.toInt()
    }

    // ========================================================================
    // 日期
    // ========================================================================

    /// napi_create_date
    /// 对应 Bun: napi_create_date
    public static func createDate(env: NapiEnv, time: Float64): NapiValue {
        // 简化实现
        return NapiValue.create(env, JsValue(time))
    }

    // ========================================================================
    // 外部数据
    // ========================================================================

    /// napi_create_external
    /// 对应 Bun: napi_create_external (extern)
    public static func createExternal(env: NapiEnv, data: ?Any): NapiValue {
        // 简化实现
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    /// napi_get_value_external
    /// 对应 Bun: napi_get_value_external (extern)
    public static func getValueExternal(env: NapiEnv, value: NapiValue): ?Any {
        // 简化实现
        return None
    }

    // ========================================================================
    // 包装/解包
    // ========================================================================

    /// napi_wrap
    /// 对应 Bun: napi_wrap (extern)
    public static func wrap(env: NapiEnv, jsObject: NapiValue, nativeObject: ?Any): NapiRef {
        val ref = NapiRef()
        ref.value = jsObject.get()
        ref.refCount = 0
        return ref
    }

    /// napi_unwrap
    /// 对应 Bun: napi_unwrap (extern)
    public static func unwrap(env: NapiEnv, jsObject: NapiValue): ?Any {
        // 简化实现
        return None
    }

    /// napi_remove_wrap
    /// 对应 Bun: napi_remove_wrap (extern)
    public static func removeWrap(env: NapiEnv, jsObject: NapiValue): ?Any {
        // 简化实现
        return None
    }

    // ========================================================================
    // TypedArray 信息
    // ========================================================================

    /// napi_get_typedarray_info
    /// 对应 Bun: napi_get_typedarray_info
    public static func getTypedArrayInfo(env: NapiEnv, typedarray: NapiValue): NapiTypedArrayInfo {
        return NapiTypedArrayInfo()
    }

    /// napi_get_arraybuffer_info
    /// 对应 Bun: napi_get_arraybuffer_info
    public static func getArrayBufferInfo(env: NapiEnv, arraybuffer: NapiValue): NapiArrayBufferInfo {
        return NapiArrayBufferInfo()
    }

    /// napi_get_dataview_info
    /// 对应 Bun: napi_get_dataview_info
    public static func getDataViewInfo(env: NapiEnv, dataview: NapiValue): NapiArrayBufferInfo {
        return NapiArrayBufferInfo()
    }

    // ========================================================================
    // 函数调用
    // ========================================================================

    /// napi_call_function
    /// 对应 Bun: napi_call_function (extern)
    public static func callFunction(env: NapiEnv, recv: NapiValue, func_: NapiValue, args: ArrayList<NapiValue>): NapiValue {
        // 简化实现
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    /// napi_new_instance
    /// 对应 Bun: napi_new_instance (extern)
    public static func newInstance(env: NapiEnv, constructor: NapiValue, args: ArrayList<NapiValue>): NapiValue {
        // 简化实现
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    /// napi_instanceof
    /// 对应 Bun: napi_instanceof (extern)
    public static func instanceof(env: NapiEnv, object: NapiValue, constructor: NapiValue): Bool {
        // 简化实现
        return false
    }

    // ========================================================================
    // 类定义
    // ========================================================================

    /// napi_define_class
    /// 对应 Bun: napi_define_class (extern)
    public static func defineClass(
        env: NapiEnv,
        utf8name: String,
        constructor: NapiCallback,
        properties: ArrayList<NapiPropertyDescriptor>
    ): NapiValue {
        // 简化实现
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    /// napi_define_properties
    /// 对应 Bun: napi_define_properties (extern)
    public static func defineProperties(
        env: NapiEnv,
        object: NapiValue,
        properties: ArrayList<NapiPropertyDescriptor>
    ): Unit {
        // 简化实现
    }

    // ========================================================================
    // 其他
    // ========================================================================

    /// napi_get_last_error_info
    /// 对应 Bun: napi_get_last_error_info (extern)
    public static func getLastErrorInfo(env: NapiEnv): NapiExtendedErrorInfo {
        return NapiExtendedErrorInfo()
    }

    /// napi_throw
    /// 对应 Bun: napi_throw (extern)
    public static func throw_(env: NapiEnv, error: NapiValue): Unit {
        // 简化实现
    }

    /// napi_throw_error
    /// 对应 Bun: napi_throw_error (extern)
    public static func throwError(env: NapiEnv, code: String, msg: String): Unit {
        // 简化实现
    }

    /// napi_run_script
    /// 对应 Bun: napi_run_script (extern)
    public static func runScript(env: NapiEnv, script: NapiValue): NapiValue {
        // 简化实现
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    /// napi_adjust_external_memory
    /// 对应 Bun: napi_adjust_external_memory (extern)
    public static func adjustExternalMemory(env: NapiEnv, changeInBytes: Int64): Int64 {
        return 0
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// N-API Deferred (Promise)
/// 对应 Bun: napi_deferred = *jsc.JSPromise.Strong
public class NapiDeferred {
    public var promise: JsPromise

    public init() {
        promise = JsPromise()
    }
}

/// TypedArray 信息
public class NapiTypedArrayInfo {
    public var typedArrayType: ?NapiTypedArrayType = None
    public var length: Int64 = 0
    public var data: ?Array<Byte> = None
    public var arrayBuffer: ?NapiValue = None
    public var byteOffset: Int64 = 0

    public init() {}
}

/// ArrayBuffer 信息
public class NapiArrayBufferInfo {
    public var data: ?Array<Byte> = None
    public var byteLength: Int64 = 0

    public init() {}
}
