// js_native_api.cj - JS Native API 函数声明
// 翻译自 Bun 源文件: src/runtime/napi/js_native_api.h
// 声明 JS Native API 中的所有函数接口，包括值创建、类型检查、属性操作、
// 引用管理、句柄作用域、异常处理、Promise 等。
// 对应 Bun napi.zig 中的 export/extern fn 实现。

package bao_runtime.napi

// ============================================================================
// NAPI 常量
// 对应 Bun: napi.zig - NAPI_AUTO_LENGTH, napi.zig 中的常量
// ============================================================================

/// NAPI_AUTO_LENGTH - 自动长度常量
/// 对应 C: #define NAPI_AUTO_LENGTH SIZE_MAX
/// 对应 Bun: napi.zig - const NAPI_AUTO_LENGTH
public let NAPI_AUTO_LENGTH: Int64 = Int64(-1)

/// NAPI 版本号（最高支持的版本）
/// 对应 Bun: napi_get_version 返回 9
public let NAPI_VERSION: UInt32 = 9

// ============================================================================
// JsNativeApi - JS Native API 函数封装
// 对应 Bun: napi.zig 中所有的 export fn / extern fn napi_*
// ============================================================================

/// JS Native API 函数集合
/// 封装所有 js_native_api.h 中声明的 napi_* 函数
/// 对应 Bun: napi.zig 的所有导出函数
public class JsNativeApi {

    // ========================================================================
    // 获取最后错误信息
    // ========================================================================

    /// napi_get_last_error_info
    /// 对应 Bun: napi.zig - pub extern fn napi_get_last_error_info
    /// 获取最后错误信息
    public static func getLastErrorInfo(env: NapiEnv): NapiExtendedErrorInfo {
        return NapiExtendedErrorInfo()
    }

    // ========================================================================
    // 获取单例值 (Singleton getters)
    // ========================================================================

    /// napi_get_undefined
    /// 对应 Bun: napi.zig - pub export fn napi_get_undefined
    public static func getUndefined(env: NapiEnv): NapiValue {
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    /// napi_get_null
    /// 对应 Bun: napi.zig - pub export fn napi_get_null
    public static func getNull(env: NapiEnv): NapiValue {
        return NapiValue.create(env, JsValue.NULL)
    }

    /// napi_get_global
    /// 对应 Bun: napi.zig - pub extern fn napi_get_global
    public static func getGlobal(env: NapiEnv): NapiValue {
        return NapiValue.create(env, JsValue(env.toJS()))
    }

    /// napi_get_boolean
    /// 对应 Bun: napi.zig - pub export fn napi_get_boolean
    public static func getBoolean(env: NapiEnv, value: Bool): NapiValue {
        return NapiValue.create(env, JsValue(value))
    }

    // ========================================================================
    // 创建基本类型 / 对象
    // ========================================================================

    /// napi_create_object
    /// 对应 Bun: napi.zig - pub extern fn napi_create_object
    public static func createObject(env: NapiEnv): NapiValue {
        return NapiValue.create(env, JsValue(JsObject()))
    }

    /// napi_create_array
    /// 对应 Bun: napi.zig - pub export fn napi_create_array
    public static func createArray(env: NapiEnv): NapiValue {
        return NapiValue.create(env, JsValue.array(ArrayList<JsValue>()))
    }

    /// napi_create_array_with_length
    /// 对应 Bun: napi.zig - pub export fn napi_create_array_with_length
    public static func createArrayWithLength(env: NapiEnv, length: Int64): NapiValue {
        // 对应 Bun: 长度处理逻辑 —— i64 -> i32 -> u32, 最小为 0
        let lenI64 = length
        let lenI32 = Int32(lenI64)
        let len: UInt32 = if (lenI32 > 0) { UInt32(lenI32) } else { 0 }
        return NapiValue.create(env, JsValue.array(ArrayList<JsValue>()))
    }

    /// napi_create_double
    /// 对应 Bun: napi.zig - pub extern fn napi_create_double
    public static func createDouble(env: NapiEnv, value: Float64): NapiValue {
        return NapiValue.create(env, JsValue(value))
    }

    /// napi_create_int32
    /// 对应 Bun: napi.zig - pub export fn napi_create_int32
    public static func createInt32(env: NapiEnv, value: Int32): NapiValue {
        return NapiValue.create(env, JsValue(value))
    }

    /// napi_create_uint32
    /// 对应 Bun: napi.zig - pub export fn napi_create_uint32
    public static func createUint32(env: NapiEnv, value: UInt32): NapiValue {
        return NapiValue.create(env, JsValue(value))
    }

    /// napi_create_int64
    /// 对应 Bun: napi.zig - pub export fn napi_create_int64
    public static func createInt64(env: NapiEnv, value: Int64): NapiValue {
        return NapiValue.create(env, JsValue(value))
    }

    // ========================================================================
    // 字符串创建
    // ========================================================================

    /// napi_create_string_latin1
    /// 对应 Bun: napi.zig - pub export fn napi_create_string_latin1
    public static func createStringLatin1(env: NapiEnv, str: ?String, length: Int64): NapiValue {
        if (str == None) {
            return NapiValue.create(env, JsValue(""))
        }
        let s = str.getOrThrow()
        if (length == NAPI_AUTO_LENGTH) {
            return NapiValue.create(env, JsValue(s))
        }
        let len = if (length > 0 && length <= s.size) { Int64(length) } else { s.size }
        return NapiValue.create(env, JsValue(s.substring(0, len)))
    }

    /// napi_create_string_utf8
    /// 对应 Bun: napi.zig - pub export fn napi_create_string_utf8
    public static func createStringUtf8(env: NapiEnv, str: ?String, length: Int64): NapiValue {
        if (str == None) {
            return NapiValue.create(env, JsValue(""))
        }
        let s = str.getOrThrow()
        if (length == NAPI_AUTO_LENGTH) {
            return NapiValue.create(env, JsValue(s))
        }
        let len = if (length > 0 && length <= s.size) { Int64(length) } else { s.size }
        return NapiValue.create(env, JsValue(s.substring(0, len)))
    }

    /// napi_create_string_utf16
    /// 对应 Bun: napi.zig - pub export fn napi_create_string_utf16
    public static func createStringUtf16(env: NapiEnv, str: ?String, length: Int64): NapiValue {
        if (str == None) {
            return NapiValue.create(env, JsValue(""))
        }
        let s = str.getOrThrow()
        if (length == NAPI_AUTO_LENGTH) {
            return NapiValue.create(env, JsValue(s))
        }
        let len = if (length > 0 && length <= s.size) { Int64(length) } else { s.size }
        return NapiValue.create(env, JsValue(s.substring(0, len)))
    }

    /// napi_create_symbol
    /// 对应 Bun: napi.zig - pub extern fn napi_create_symbol
    public static func createSymbol(env: NapiEnv, description: NapiValue): NapiValue {
        // 简化实现
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    /// node_api_symbol_for
    /// 对应 Bun: napi.zig - extern fn node_api_symbol_for
    public static func symbolFor(env: NapiEnv, utf8description: String, length: Int64): NapiValue {
        // 简化实现
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    /// napi_create_function
    /// 对应 Bun: napi.zig - (extern fn 通过 C++ 实现)
    public static func createFunction(env: NapiEnv, utf8name: String, length: Int64,
        cb: NapiCallbackFn, data: ?Any): NapiValue {
        // 简化实现
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    // ========================================================================
    // 创建错误对象
    // ========================================================================

    /// napi_create_error
    /// 对应 Bun: napi.zig - pub extern fn napi_create_error
    public static func createError(env: NapiEnv, code: NapiValue, msg: NapiValue): NapiValue {
        let errorObj = JsObject()
        errorObj.set("message", msg.get())
        if (!code.get().isUndefinedOrNull()) {
            errorObj.set("code", code.get())
        }
        return NapiValue.create(env, JsValue(errorObj))
    }

    /// napi_create_type_error
    /// 对应 Bun: napi.zig - pub extern fn napi_create_type_error
    public static func createTypeError(env: NapiEnv, code: NapiValue, msg: NapiValue): NapiValue {
        let errorObj = JsObject()
        errorObj.set("message", msg.get())
        if (!code.get().isUndefinedOrNull()) {
            errorObj.set("code", code.get())
        }
        errorObj.set("name", JsValue("TypeError"))
        return NapiValue.create(env, JsValue(errorObj))
    }

    /// napi_create_range_error
    /// 对应 Bun: napi.zig - pub extern fn napi_create_range_error
    public static func createRangeError(env: NapiEnv, code: NapiValue, msg: NapiValue): NapiValue {
        let errorObj = JsObject()
        errorObj.set("message", msg.get())
        if (!code.get().isUndefinedOrNull()) {
            errorObj.set("code", code.get())
        }
        errorObj.set("name", JsValue("RangeError"))
        return NapiValue.create(env, JsValue(errorObj))
    }

    /// node_api_create_syntax_error
    /// 对应 Bun: napi.zig - extern fn node_api_create_syntax_error
    public static func createSyntaxError(env: NapiEnv, code: NapiValue, msg: NapiValue): NapiValue {
        let errorObj = JsObject()
        errorObj.set("message", msg.get())
        if (!code.get().isUndefinedOrNull()) {
            errorObj.set("code", code.get())
        }
        errorObj.set("name", JsValue("SyntaxError"))
        return NapiValue.create(env, JsValue(errorObj))
    }

    // ========================================================================
    // 获取原生值 (Getters for native values from napi_value)
    // ========================================================================

    /// napi_typeof
    /// 对应 Bun: napi.zig - pub extern fn napi_typeof
    public static func typeOf(env: NapiEnv, value: NapiValue): NapiValueType {
        let v = value.get()
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

    /// napi_get_value_double
    /// 对应 Bun: napi.zig - pub extern fn napi_get_value_double
    public static func getValueDouble(env: NapiEnv, value: NapiValue): Float64 {
        return value.get().toNumber()
    }

    /// napi_get_value_int32
    /// 对应 Bun: napi.zig - pub extern fn napi_get_value_int32
    public static func getValueInt32(env: NapiEnv, value: NapiValue): Int32 {
        return Int32(value.get().toNumber())
    }

    /// napi_get_value_uint32
    /// 对应 Bun: napi.zig - pub extern fn napi_get_value_uint32
    public static func getValueUint32(env: NapiEnv, value: NapiValue): UInt32 {
        return UInt32(value.get().toNumber())
    }

    /// napi_get_value_int64
    /// 对应 Bun: napi.zig - pub extern fn napi_get_value_int64
    public static func getValueInt64(env: NapiEnv, value: NapiValue): Int64 {
        return Int64(value.get().toNumber())
    }

    /// napi_get_value_bool
    /// 对应 Bun: napi.zig - pub extern fn napi_get_value_bool
    public static func getValueBool(env: NapiEnv, value: NapiValue): Bool {
        return value.get().toBoolean()
    }

    /// napi_get_value_string_latin1
    /// 对应 Bun: napi.zig - pub extern fn napi_get_value_string_latin1
    public static func getValueStringLatin1(env: NapiEnv, value: NapiValue, buf: ?Array<Byte>,
        bufSize: Int64): Int64 {
        let str = value.get().toString()
        if (buf == None) {
            return str.size
        }
        let b = buf.getOrThrow()
        let copyLen = if (bufSize < str.size) { bufSize } else { str.size }
        // 简化实现：返回字节数
        return copyLen
    }

    /// napi_get_value_string_utf8
    /// 对应 Bun: napi.zig - pub extern fn napi_get_value_string_utf8
    public static func getValueStringUtf8(env: NapiEnv, value: NapiValue, buf: ?Array<Byte>,
        bufSize: Int64): Int64 {
        let str = value.get().toString()
        if (buf == None) {
            return str.size
        }
        let b = buf.getOrThrow()
        let copyLen = if (bufSize < str.size) { bufSize } else { str.size }
        return copyLen
    }

    /// napi_get_value_string_utf16
    /// 对应 Bun: napi.zig - pub extern fn napi_get_value_string_utf16
    public static func getValueStringUtf16(env: NapiEnv, value: NapiValue, buf: ?Array<UInt16>,
        bufSize: Int64): Int64 {
        let str = value.get().toString()
        if (buf == None) {
            return str.size
        }
        return str.size
    }

    // ========================================================================
    // 值强制转换 (Coercion)
    // ========================================================================

    /// napi_coerce_to_bool
    /// 对应 Bun: napi.zig - pub extern fn napi_coerce_to_bool
    public static func coerceToBool(env: NapiEnv, value: NapiValue): NapiValue {
        return NapiValue.create(env, JsValue(value.get().toBoolean()))
    }

    /// napi_coerce_to_number
    /// 对应 Bun: napi.zig - pub extern fn napi_coerce_to_number
    public static func coerceToNumber(env: NapiEnv, value: NapiValue): NapiValue {
        return NapiValue.create(env, JsValue(value.get().toNumber()))
    }

    /// napi_coerce_to_object
    /// 对应 Bun: napi.zig - pub extern fn napi_coerce_to_object
    public static func coerceToObject(env: NapiEnv, value: NapiValue): NapiValue {
        return NapiValue.create(env, value.get())
    }

    /// napi_coerce_to_string
    /// 对应 Bun: napi.zig - pub extern fn napi_coerce_to_string
    public static func coerceToString(env: NapiEnv, value: NapiValue): NapiValue {
        return NapiValue.create(env, JsValue(value.get().toString()))
    }

    // ========================================================================
    // 对象属性操作
    // ========================================================================

    /// napi_get_prototype
    /// 对应 Bun: napi.zig - pub export fn napi_get_prototype
    public static func getPrototype(env: NapiEnv, object: NapiValue): NapiValue {
        let v = object.get()
        if (!v.isObject()) {
            return NapiValue.create(env, JsValue.NULL)
        }
        // 简化实现
        return NapiValue.create(env, JsValue.NULL)
    }

    /// napi_get_property_names
    /// 对应 Bun: napi.zig - (注释掉未实现)
    public static func getPropertyNames(env: NapiEnv, object: NapiValue): NapiValue {
        return NapiValue.create(env, JsValue.array(ArrayList<JsValue>()))
    }

    /// napi_set_property
    /// 对应 Bun: napi.zig - pub extern fn napi_set_property
    public static func setProperty(env: NapiEnv, object: NapiValue, key: NapiValue,
        value: NapiValue): UInt32 {
        let obj = object.get()
        if (!obj.isObject()) {
            return NapiStatus.invalidArg.toInt()
        }
        // 简化实现
        return NapiStatus.ok.toInt()
    }

    /// napi_has_property
    /// 对应 Bun: napi.zig - pub extern fn napi_has_property
    public static func hasProperty(env: NapiEnv, object: NapiValue, key: NapiValue): Bool {
        return false
    }

    /// napi_get_property
    /// 对应 Bun: napi.zig - pub extern fn napi_get_property
    public static func getProperty(env: NapiEnv, object: NapiValue, key: NapiValue): NapiValue {
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    /// napi_delete_property
    /// 对应 Bun: napi.zig - pub extern fn napi_delete_property
    public static func deleteProperty(env: NapiEnv, object: NapiValue, key: NapiValue): Bool {
        return false
    }

    /// napi_has_own_property
    /// 对应 Bun: napi.zig - pub extern fn napi_has_own_property
    public static func hasOwnProperty(env: NapiEnv, object: NapiValue, key: NapiValue): Bool {
        return false
    }

    /// napi_set_named_property
    /// 对应 Bun: napi.zig - pub extern fn napi_set_named_property
    public static func setNamedProperty(env: NapiEnv, object: NapiValue, utf8name: String,
        value: NapiValue): UInt32 {
        let obj = object.get()
        if (!obj.isObject()) {
            return NapiStatus.invalidArg.toInt()
        }
        return NapiStatus.ok.toInt()
    }

    /// napi_has_named_property
    /// 对应 Bun: napi.zig - pub extern fn napi_has_named_property
    public static func hasNamedProperty(env: NapiEnv, object: NapiValue, utf8name: String): Bool {
        return false
    }

    /// napi_get_named_property
    /// 对应 Bun: napi.zig - pub extern fn napi_get_named_property
    public static func getNamedProperty(env: NapiEnv, object: NapiValue, utf8name: String): NapiValue {
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    /// napi_set_element
    /// 对应 Bun: napi.zig - pub extern fn napi_set_element
    public static func setElement(env: NapiEnv, object: NapiValue, index: UInt32,
        value: NapiValue): UInt32 {
        return NapiStatus.ok.toInt()
    }

    /// napi_has_element
    /// 对应 Bun: napi.zig - pub extern fn napi_has_element
    public static func hasElement(env: NapiEnv, object: NapiValue, index: UInt32): Bool {
        return false
    }

    /// napi_get_element
    /// 对应 Bun: napi.zig - pub extern fn napi_get_element
    public static func getElement(env: NapiEnv, object: NapiValue, index: UInt32): NapiValue {
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    /// napi_delete_element
    /// 对应 Bun: napi.zig - pub extern fn napi_delete_element
    public static func deleteElement(env: NapiEnv, object: NapiValue, index: UInt32): Bool {
        return false
    }

    /// napi_define_properties
    /// 对应 Bun: napi.zig - pub extern fn napi_define_properties
    public static func defineProperties(env: NapiEnv, object: NapiValue,
        properties: ArrayList<NapiPropertyDescriptor>): UInt32 {
        return NapiStatus.ok.toInt()
    }

    // ========================================================================
    // 数组操作
    // ========================================================================

    /// napi_is_array
    /// 对应 Bun: napi.zig - pub export fn napi_is_array
    public static func isArray(env: NapiEnv, value: NapiValue): Bool {
        return value.get().valueType == JsValueType.Array
    }

    /// napi_get_array_length
    /// 对应 Bun: napi.zig - pub export fn napi_get_array_length
    public static func getArrayLength(env: NapiEnv, value: NapiValue): UInt32 {
        let v = value.get()
        if (v.valueType != JsValueType.Array) {
            return 0
        }
        match (v.arrayData) {
            case Some(arr) => return UInt32(arr.size)
            case None => return 0
        }
    }

    // ========================================================================
    // 值比较
    // ========================================================================

    /// napi_strict_equals
    /// 对应 Bun: napi.zig - pub export fn napi_strict_equals
    public static func strictEquals(env: NapiEnv, lhs: NapiValue, rhs: NapiValue): Bool {
        return lhs.get().toString() == rhs.get().toString()
    }

    // ========================================================================
    // 函数调用
    // ========================================================================

    /// napi_call_function
    /// 对应 Bun: napi.zig - pub extern fn napi_call_function
    public static func callFunction(env: NapiEnv, recv: NapiValue, func_: NapiValue,
        args: ArrayList<NapiValue>): NapiValue {
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    /// napi_new_instance
    /// 对应 Bun: napi.zig - pub extern fn napi_new_instance
    public static func newInstance(env: NapiEnv, constructor: NapiValue,
        args: ArrayList<NapiValue>): NapiValue {
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    /// napi_instanceof
    /// 对应 Bun: napi.zig - pub extern fn napi_instanceof
    public static func instanceof(env: NapiEnv, object: NapiValue, constructor: NapiValue): Bool {
        return false
    }

    // ========================================================================
    // 回调信息
    // ========================================================================

    /// napi_get_cb_info
    /// 对应 Bun: napi.zig - pub extern fn napi_get_cb_info
    public static func getCbInfo(env: NapiEnv, cbinfo: NapiCallbackInfo): NapiCallbackInfo {
        return cbinfo
    }

    /// napi_get_new_target
    /// 对应 Bun: napi.zig - pub extern fn napi_get_new_target
    public static func getNewTarget(env: NapiEnv, cbinfo: NapiCallbackInfo): NapiValue {
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    /// napi_define_class
    /// 对应 Bun: napi.zig - pub extern fn napi_define_class
    public static func defineClass(env: NapiEnv, utf8name: String, length: Int64,
        constructor: NapiCallbackFn, data: ?Any,
        properties: ArrayList<NapiPropertyDescriptor>): NapiValue {
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    // ========================================================================
    // 外部数据 / Wrap
    // ========================================================================

    /// napi_wrap
    /// 对应 Bun: napi.zig - pub extern fn napi_wrap
    public static func wrap(env: NapiEnv, jsObject: NapiValue, nativeObject: ?Any,
        finalizeCb: ?NapiFinalizeFn, finalizeHint: ?Any): NapiRef {
        let ref = NapiRef()
        ref.value = jsObject.get()
        ref.refCount = 0
        return ref
    }

    /// napi_unwrap
    /// 对应 Bun: napi.zig - pub extern fn napi_unwrap
    public static func unwrap(env: NapiEnv, jsObject: NapiValue): ?Any {
        return None
    }

    /// napi_remove_wrap
    /// 对应 Bun: napi.zig - pub extern fn napi_remove_wrap
    public static func removeWrap(env: NapiEnv, jsObject: NapiValue): ?Any {
        return None
    }

    /// napi_create_external
    /// 对应 Bun: napi.zig - pub extern fn napi_create_external
    public static func createExternal(env: NapiEnv, data: ?Any,
        finalizeCb: ?NapiFinalizeFn, finalizeHint: ?Any): NapiValue {
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    /// napi_get_value_external
    /// 对应 Bun: napi.zig - pub extern fn napi_get_value_external
    public static func getValueExternal(env: NapiEnv, value: NapiValue): ?Any {
        return None
    }

    // ========================================================================
    // 引用管理
    // ========================================================================

    /// napi_create_reference
    /// 对应 Bun: napi.zig - pub extern fn napi_create_reference
    public static func createReference(env: NapiEnv, value: NapiValue,
        initialRefCount: UInt32): NapiRef {
        let ref = NapiRef()
        ref.value = value.get()
        ref.refCount = initialRefCount
        return ref
    }

    /// napi_delete_reference
    /// 对应 Bun: napi.zig - pub extern fn napi_delete_reference
    public static func deleteReference(env: NapiEnv, ref: NapiRef): UInt32 {
        ref.value = None
        return NapiStatus.ok.toInt()
    }

    /// napi_reference_ref
    /// 对应 Bun: napi.zig - pub extern fn napi_reference_ref
    public static func referenceRef(env: NapiEnv, ref: NapiRef): UInt32 {
        ref.refCount += 1
        return ref.refCount
    }

    /// napi_reference_unref
    /// 对应 Bun: napi.zig - pub extern fn napi_reference_unref
    public static func referenceUnref(env: NapiEnv, ref: NapiRef): UInt32 {
        if (ref.refCount > 0) {
            ref.refCount -= 1
        }
        return ref.refCount
    }

    /// napi_get_reference_value
    /// 对应 Bun: napi.zig - pub extern fn napi_get_reference_value
    public static func getReferenceValue(env: NapiEnv, ref: NapiRef): NapiValue {
        if (ref.value != None) {
            return NapiValue.create(env, ref.value.getOrThrow())
        }
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    // ========================================================================
    // 句柄作用域
    // ========================================================================

    /// napi_open_handle_scope
    /// 对应 Bun: napi.zig - pub export fn napi_open_handle_scope
    public static func openHandleScope(env: NapiEnv): ?NapiHandleScope {
        return NapiHandleScope.open(env, false)
    }

    /// napi_close_handle_scope
    /// 对应 Bun: napi.zig - pub export fn napi_close_handle_scope
    public static func closeHandleScope(env: NapiEnv, scope: NapiHandleScope): UInt32 {
        scope.close(env)
        return NapiStatus.ok.toInt()
    }

    /// napi_open_escapable_handle_scope
    /// 对应 Bun: napi.zig - pub export fn napi_open_escapable_handle_scope
    public static func openEscapableHandleScope(env: NapiEnv): ?NapiHandleScope {
        return NapiHandleScope.open(env, true)
    }

    /// napi_close_escapable_handle_scope
    /// 对应 Bun: napi.zig - pub export fn napi_close_escapable_handle_scope
    public static func closeEscapableHandleScope(env: NapiEnv, scope: NapiHandleScope): UInt32 {
        scope.close(env)
        return NapiStatus.ok.toInt()
    }

    /// napi_escape_handle
    /// 对应 Bun: napi.zig - pub export fn napi_escape_handle
    public static func escapeHandle(env: NapiEnv, scope: NapiHandleScope,
        escapee: NapiValue): NapiValue {
        scope.escape(escapee.get())
        return escapee
    }

    // ========================================================================
    // 异常处理
    // ========================================================================

    /// napi_throw
    /// 对应 Bun: napi.zig - pub extern fn napi_throw
    public static func throw_(env: NapiEnv, error: NapiValue): UInt32 {
        // 简化实现
        return NapiStatus.ok.toInt()
    }

    /// napi_throw_error
    /// 对应 Bun: napi.zig - pub extern fn napi_throw_error
    public static func throwError(env: NapiEnv, code: String, msg: String): UInt32 {
        return NapiStatus.ok.toInt()
    }

    /// napi_throw_type_error
    /// 对应 Bun: napi.zig - pub extern fn napi_throw_type_error
    public static func throwTypeError(env: NapiEnv, code: String, msg: String): UInt32 {
        return NapiStatus.ok.toInt()
    }

    /// napi_throw_range_error
    /// 对应 Bun: napi.zig - pub extern fn napi_throw_range_error
    public static func throwRangeError(env: NapiEnv, code: String, msg: String): UInt32 {
        return NapiStatus.ok.toInt()
    }

    /// node_api_throw_syntax_error
    /// 对应 Bun: napi.zig - extern fn node_api_throw_syntax_error
    public static func throwSyntaxError(env: NapiEnv, code: String, msg: String): UInt32 {
        return NapiStatus.ok.toInt()
    }

    /// napi_is_error
    /// 对应 Bun: napi.zig - pub export fn napi_is_error
    public static func isError(env: NapiEnv, value: NapiValue): Bool {
        return value.get().valueType == JsValueType.Error
    }

    /// napi_is_exception_pending
    /// 对应 Bun: napi.zig - pub extern fn napi_is_exception_pending
    public static func isExceptionPending(env: NapiEnv): Bool {
        return false
    }

    /// napi_get_and_clear_last_exception
    /// 对应 Bun: napi.zig - pub extern fn napi_get_and_clear_last_exception
    public static func getAndClearLastException(env: NapiEnv): NapiValue {
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    // ========================================================================
    // ArrayBuffer / TypedArray
    // ========================================================================

    /// napi_is_arraybuffer
    /// 对应 Bun: napi.zig - pub export fn napi_is_arraybuffer
    public static func isArrayBuffer(env: NapiEnv, value: NapiValue): Bool {
        return value.get().valueType == JsValueType.ArrayBuffer
    }

    /// napi_create_arraybuffer
    /// 对应 Bun: napi.zig - pub extern fn napi_create_arraybuffer
    public static func createArrayBuffer(env: NapiEnv, byteLength: Int64): NapiArrayBufferInfo {
        return NapiArrayBufferInfo()
    }

    /// napi_create_external_arraybuffer
    /// 对应 Bun: napi.zig - pub extern fn napi_create_external_arraybuffer
    public static func createExternalArrayBuffer(env: NapiEnv, externalData: ?Any,
        byteLength: Int64, finalizeCb: ?NapiFinalizeFn,
        finalizeHint: ?Any): NapiValue {
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    /// napi_get_arraybuffer_info
    /// 对应 Bun: napi.zig - pub export fn napi_get_arraybuffer_info
    public static func getArrayBufferInfo(env: NapiEnv, arraybuffer: NapiValue): NapiArrayBufferInfo {
        return NapiArrayBufferInfo()
    }

    /// napi_is_typedarray
    /// 对应 Bun: napi.zig - pub extern fn napi_is_typedarray
    public static func isTypedArray(env: NapiEnv, value: NapiValue): Bool {
        return value.get().valueType == JsValueType.TypedArray
    }

    /// napi_create_typedarray
    /// 对应 Bun: napi.zig - pub extern fn napi_create_typedarray
    public static func createTypedArray(env: NapiEnv, type_: NapiTypedArrayType,
        length: Int64, arraybuffer: NapiValue,
        byteOffset: Int64): NapiValue {
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    /// napi_get_typedarray_info
    /// 对应 Bun: napi.zig - pub export fn napi_get_typedarray_info
    public static func getTypedArrayInfo(env: NapiEnv, typedarray: NapiValue): NapiTypedArrayInfo {
        return NapiTypedArrayInfo()
    }

    /// napi_create_dataview
    /// 对应 Bun: napi.zig - pub extern fn napi_create_dataview
    public static func createDataView(env: NapiEnv, length: Int64, arraybuffer: NapiValue,
        byteOffset: Int64): NapiValue {
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    /// napi_is_dataview
    /// 对应 Bun: napi.zig - pub export fn napi_is_dataview
    public static func isDataView(env: NapiEnv, value: NapiValue): Bool {
        return value.get().valueType == JsValueType.DataView
    }

    /// napi_get_dataview_info
    /// 对应 Bun: napi.zig - pub export fn napi_get_dataview_info
    public static func getDataViewInfo(env: NapiEnv, dataview: NapiValue): NapiArrayBufferInfo {
        return NapiArrayBufferInfo()
    }

    // ========================================================================
    // 版本管理
    // ========================================================================

    /// napi_get_version
    /// 对应 Bun: napi.zig - pub export fn napi_get_version
    /// 返回 N-API 最高支持版本
    public static func getVersion(env: NapiEnv): UInt32 {
        return NAPI_VERSION
    }

    // ========================================================================
    // Promise
    // ========================================================================

    /// napi_create_promise
    /// 对应 Bun: napi.zig - pub export fn napi_create_promise
    public static func createPromise(env: NapiEnv): NapiDeferred {
        let deferred = NapiDeferred()
        deferred.promise = JsPromise()
        return deferred
    }

    /// napi_resolve_deferred
    /// 对应 Bun: napi.zig - pub export fn napi_resolve_deferred
    public static func resolveDeferred(env: NapiEnv, deferred: NapiDeferred,
        resolution: NapiValue): UInt32 {
        deferred.promise.resolve(resolution.get())
        return NapiStatus.ok.toInt()
    }

    /// napi_reject_deferred
    /// 对应 Bun: napi.zig - pub export fn napi_reject_deferred
    public static func rejectDeferred(env: NapiEnv, deferred: NapiDeferred,
        rejection: NapiValue): UInt32 {
        deferred.promise.reject(rejection.get())
        return NapiStatus.ok.toInt()
    }

    /// napi_is_promise
    /// 对应 Bun: napi.zig - pub export fn napi_is_promise
    public static func isPromise(env: NapiEnv, value: NapiValue): Bool {
        return value.get().valueType == JsValueType.Promise
    }

    // ========================================================================
    // 脚本执行
    // ========================================================================

    /// napi_run_script
    /// 对应 Bun: napi.zig - pub extern fn napi_run_script
    public static func runScript(env: NapiEnv, script: NapiValue): NapiValue {
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    // ========================================================================
    // 内存管理
    // ========================================================================

    /// napi_adjust_external_memory
    /// 对应 Bun: napi.zig - pub extern fn napi_adjust_external_memory
    public static func adjustExternalMemory(env: NapiEnv, changeInBytes: Int64): Int64 {
        return 0
    }

    // ========================================================================
    // 日期 (NAPI_VERSION >= 5)
    // ========================================================================

    /// napi_create_date
    /// 对应 Bun: napi.zig - pub export fn napi_create_date
    public static func createDate(env: NapiEnv, time: Float64): NapiValue {
        return NapiValue.create(env, JsValue(time))
    }

    /// napi_is_date
    /// 对应 Bun: napi.zig - pub export fn napi_is_date
    public static func isDate(env: NapiEnv, value: NapiValue): Bool {
        // 简化实现
        return false
    }

    /// napi_get_date_value
    /// 对应 Bun: napi.zig - pub extern fn napi_get_date_value
    public static func getDateValue(env: NapiEnv, value: NapiValue): Float64 {
        return value.get().toNumber()
    }

    /// napi_add_finalizer
    /// 对应 Bun: napi.zig - pub extern fn napi_add_finalizer
    public static func addFinalizer(env: NapiEnv, jsObject: NapiValue, nativeObject: ?Any,
        finalizeCb: ?NapiFinalizeFn, finalizeHint: ?Any): NapiRef {
        let ref = NapiRef()
        ref.value = jsObject.get()
        ref.refCount = 0
        return ref
    }

    // ========================================================================
    // BigInt (NAPI_VERSION >= 6)
    // ========================================================================

    /// napi_create_bigint_int64
    /// 对应 Bun: napi.zig - pub extern fn napi_create_bigint_int64
    public static func createBigintInt64(env: NapiEnv, value: Int64): NapiValue {
        return NapiValue.create(env, JsValue(value))
    }

    /// napi_create_bigint_uint64
    /// 对应 Bun: napi.zig - pub extern fn napi_create_bigint_uint64
    public static func createBigintUint64(env: NapiEnv, value: UInt64): NapiValue {
        return NapiValue.create(env, JsValue(value))
    }

    /// napi_create_bigint_words
    /// 对应 Bun: napi.zig - pub extern fn napi_create_bigint_words
    public static func createBigintWords(env: NapiEnv, signBit: Int32, wordCount: Int64,
        words: Array<UInt64>): NapiValue {
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    /// napi_get_value_bigint_int64
    /// 对应 Bun: napi.zig - pub extern fn napi_get_value_bigint_int64
    public static func getValueBigintInt64(env: NapiEnv, value: NapiValue): Int64 {
        return Int64(value.get().toNumber())
    }

    /// napi_get_value_bigint_uint64
    /// 对应 Bun: napi.zig - pub extern fn napi_get_value_bigint_uint64
    public static func getValueBigintUint64(env: NapiEnv, value: NapiValue): UInt64 {
        return UInt64(value.get().toNumber())
    }

    /// napi_get_value_bigint_words
    /// 对应 Bun: napi.zig - pub extern fn napi_get_value_bigint_words
    public static func getValueBigintWords(env: NapiEnv, value: NapiValue): NapiBigintWords {
        return NapiBigintWords()
    }

    /// napi_get_all_property_names
    /// 对应 Bun: napi.zig - pub extern fn napi_get_all_property_names
    public static func getAllPropertyNames(env: NapiEnv, object: NapiValue,
        keyMode: NapiKeyCollectionMode, keyFilter: NapiKeyFilter,
        keyConversion: NapiKeyConversion): NapiValue {
        return NapiValue.create(env, JsValue.array(ArrayList<JsValue>()))
    }

    /// napi_set_instance_data
    /// 对应 Bun: napi.zig - pub extern fn napi_set_instance_data
    public static func setInstanceData(env: NapiEnv, data: ?Any,
        finalizeCb: ?NapiFinalizeFn, finalizeHint: ?Any): UInt32 {
        return NapiStatus.ok.toInt()
    }

    /// napi_get_instance_data
    /// 对应 Bun: napi.zig - pub extern fn napi_get_instance_data
    public static func getInstanceData(env: NapiEnv): ?Any {
        return None
    }

    // ========================================================================
    // ArrayBuffer 分离 (NAPI_VERSION >= 7)
    // ========================================================================

    /// napi_detach_arraybuffer
    /// 对应 Bun: napi.zig - pub extern fn napi_detach_arraybuffer
    public static func detachArrayBuffer(env: NapiEnv, arraybuffer: NapiValue): UInt32 {
        return NapiStatus.ok.toInt()
    }

    /// napi_is_detached_arraybuffer
    /// 对应 Bun: napi.zig - pub extern fn napi_is_detached_arraybuffer
    public static func isDetachedArrayBuffer(env: NapiEnv, value: NapiValue): Bool {
        return false
    }

    // ========================================================================
    // 类型标签 (NAPI_VERSION >= 8)
    // ========================================================================

    /// napi_type_tag_object
    /// 对应 Bun: napi.zig - pub extern fn napi_type_tag_object
    public static func typeTagObject(env: NapiEnv, value: NapiValue,
        typeTag: NapiTypeTag): UInt32 {
        return NapiStatus.ok.toInt()
    }

    /// napi_check_object_type_tag
    /// 对应 Bun: napi.zig - pub extern fn napi_check_object_type_tag
    public static func checkObjectTypeTag(env: NapiEnv, value: NapiValue,
        typeTag: NapiTypeTag): Bool {
        return false
    }

    /// napi_object_freeze
    /// 对应 Bun: napi.zig - pub extern fn napi_object_freeze
    public static func objectFreeze(env: NapiEnv, object: NapiValue): UInt32 {
        return NapiStatus.ok.toInt()
    }

    /// napi_object_seal
    /// 对应 Bun: napi.zig - pub extern fn napi_object_seal
    public static func objectSeal(env: NapiEnv, object: NapiValue): UInt32 {
        return NapiStatus.ok.toInt()
    }

    // ========================================================================
    // 外部字符串 (NAPI_VERSION >= 10)
    // ========================================================================

    /// node_api_create_external_string_latin1
    /// 对应 Bun: napi.zig - extern fn node_api_create_external_string_latin1
    public static func createExternalStringLatin1(env: NapiEnv, str: String, length: Int64,
        finalizeCallback: ?NapiFinalizeFn, finalizeHint: ?Any): NapiExternalStringResult {
        return NapiExternalStringResult(NapiValue.create(env, JsValue(str)), false)
    }

    /// node_api_create_external_string_utf16
    /// 对应 Bun: napi.zig - extern fn node_api_create_external_string_utf16
    public static func createExternalStringUtf16(env: NapiEnv, str: String, length: Int64,
        finalizeCallback: ?NapiFinalizeFn, finalizeHint: ?Any): NapiExternalStringResult {
        return NapiExternalStringResult(NapiValue.create(env, JsValue(str)), false)
    }

    /// node_api_create_property_key_latin1
    /// 对应 Bun: napi.zig - (NAPI_VERSION >= 10)
    public static func createPropertyKeyLatin1(env: NapiEnv, str: String, length: Int64): NapiValue {
        return NapiValue.create(env, JsValue(str))
    }

    /// node_api_create_property_key_utf8
    /// 对应 Bun: napi.zig - (NAPI_VERSION >= 10)
    public static func createPropertyKeyUtf8(env: NapiEnv, str: String, length: Int64): NapiValue {
        return NapiValue.create(env, JsValue(str))
    }

    /// node_api_create_property_key_utf16
    /// 对应 Bun: napi.zig - (NAPI_VERSION >= 10)
    public static func createPropertyKeyUtf16(env: NapiEnv, str: String, length: Int64): NapiValue {
        return NapiValue.create(env, JsValue(str))
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 外部字符串创建结果
/// 包含 NapiValue 和 copied 标志
public class NapiExternalStringResult {
    public var value: NapiValue
    public var copied: Bool

    public init(value: NapiValue, copied: Bool) {
        this.value = value
        this.copied = copied
    }
}

/// BigInt 字结果
public class NapiBigintWords {
    public var signBit: Int32 = 0
    public var wordCount: Int64 = 0
    public var words: Array<UInt64> = Array<UInt64>()

    public init() {}
}
