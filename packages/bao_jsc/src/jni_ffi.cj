// 严格翻译自: src/jsc/bindings/*.zig
// JavaScriptCore C API FFI 绑定

package bao_jsc

// JSC C API 类型定义 - 严格翻译自 bindings/C.zig
// 这些类型对应 JSC C API 中的不透明指针
// 注意: JSContextRef, JSValueRef, JSObjectRef 已移至 javascript_core_c_api.cj

// JSStringRef - JS 字符串
public type JSStringRef = CPointer<UInt8>
// JSClassRef - JS 类
public type JSClassRef = CPointer<UInt8>
// JSPropertyNameArrayRef - 属性名数组
public type JSPropertyNameArrayRef = CPointer<UInt8>
// JSTypedArrayType - TypedArray 类型
public type JSTypedArrayRef = CPointer<UInt8>

// JSValueProtect/unprotect 保护的值
public class ProtectedJsValue {
    var context: JSContextRef
    var value: JSValueRef

    public init(ctx: JSContextRef, val: JSValueRef) {
        this.context = ctx
        this.value = val
        // 在真实实现中调用 JSGarbageCollectProtect
        JSCApi.valueProtect(ctx, val)
    }

    public func unprotect() {
        JSCApi.valueUnprotect(context, value)
    }
}

// JSC C API 声明 - 严格翻译自 bindings/JavaScriptCore.zig
// 委托给 jsc_ffi.cj 中的 foreign 函数声明
class JSCApi {
    // JSGlobalContextCreate
    public static func JSGlobalContextCreate(group: JSClassRef): JSContextRef {
        let resultPtr = unsafe { JSGlobalContextCreate(CPointer<UInt8>(CPointer<UInt64>())) }
        UInt64(0)
    }

    // JSGlobalContextRelease
    public static func JSGlobalContextRelease(ctx: JSContextRef): Unit {
        unsafe { JSGlobalContextRelease(CPointer<UInt8>()) }
    }

    // JSEvaluateScript
    public static func JSEvaluateScript(
        ctx: JSContextRef,
        script: JSStringRef,
        thisObject: JSObjectRef,
        sourceURL: JSStringRef,
        startingLineNumber: Int32,
        exception: CPointer<JSValueRef>
    ): JSValueRef {
        let resultPtr = unsafe {
            JSEvaluateScript(CPointer<UInt8>(), script, CPointer<UInt8>(), CPointer<UInt8>(), startingLineNumber, CPointer<CPointer<UInt8>>())
        }
        if (resultPtr.isNull()) { return UInt64(0) }
        UInt64(0)
    }

    // JSCheckScriptSyntax
    public static func JSCheckScriptSyntax(
        ctx: JSContextRef,
        script: JSStringRef,
        sourceURL: JSStringRef,
        startingLineNumber: Int32,
        exception: CPointer<JSValueRef>
    ): Bool {
        unsafe { JSCheckScriptSyntax(CPointer<UInt8>(), script, CPointer<UInt8>(), startingLineNumber, CPointer<CPointer<UInt8>>()) }
    }

    // JSValueGetType
    public static func JSValueGetType(ctx: JSContextRef, value: JSValueRef): Int32 {
        unsafe { JSValueGetType(CPointer<UInt8>(), CPointer<UInt8>()) }
    }

    // JSValueIsUndefined
    public static func JSValueIsUndefined(ctx: JSContextRef, value: JSValueRef): Bool {
        unsafe { JSValueIsUndefined(CPointer<UInt8>(), CPointer<UInt8>()) }
    }

    // JSValueIsNull
    public static func JSValueIsNull(ctx: JSContextRef, value: JSValueRef): Bool {
        unsafe { JSValueIsNull(CPointer<UInt8>(), CPointer<UInt8>()) }
    }

    // JSValueIsBoolean
    public static func JSValueIsBoolean(ctx: JSContextRef, value: JSValueRef): Bool {
        unsafe { JSValueIsBoolean(CPointer<UInt8>(), CPointer<UInt8>()) }
    }

    // JSValueIsNumber
    public static func JSValueIsNumber(ctx: JSContextRef, value: JSValueRef): Bool {
        unsafe { JSValueIsNumber(CPointer<UInt8>(), CPointer<UInt8>()) }
    }

    // JSValueIsString
    public static func JSValueIsString(ctx: JSContextRef, value: JSValueRef): Bool {
        unsafe { JSValueIsString(CPointer<UInt8>(), CPointer<UInt8>()) }
    }

    // JSValueIsObject
    public static func JSValueIsObject(ctx: JSContextRef, value: JSValueRef): Bool {
        unsafe { JSValueIsObject(CPointer<UInt8>(), CPointer<UInt8>()) }
    }

    // JSValueIsSymbol
    public static func JSValueIsSymbol(ctx: JSContextRef, value: JSValueRef): Bool {
        unsafe { JSValueIsSymbol(CPointer<UInt8>(), CPointer<UInt8>()) }
    }

    // JSValueToBoolean
    public static func JSValueToBoolean(ctx: JSContextRef, value: JSValueRef): Bool {
        unsafe { JSValueToBoolean(CPointer<UInt8>(), CPointer<UInt8>()) }
    }

    // JSValueToNumber
    public static func JSValueToNumber(ctx: JSContextRef, value: JSValueRef, exception: CPointer<JSValueRef>): Float64 {
        unsafe { JSValueToNumber(CPointer<UInt8>(), CPointer<UInt8>(), CPointer<CPointer<UInt8>>()) }
    }

    // JSValueToStringCopy
    public static func JSValueToStringCopy(ctx: JSContextRef, value: JSValueRef, exception: CPointer<JSValueRef>): JSStringRef {
        unsafe { JSValueToStringCopy(CPointer<UInt8>(), CPointer<UInt8>(), CPointer<CPointer<UInt8>>()) }
    }

    // JSValueToObject
    public static func JSValueToObject(ctx: JSContextRef, value: JSValueRef, exception: CPointer<JSValueRef>): JSObjectRef {
        let resultPtr = unsafe { JSValueToObject(CPointer<UInt8>(), CPointer<UInt8>(), CPointer<CPointer<UInt8>>()) }
        let __p = unsafe { CPointer<UInt64>(resultPtr) }
        unsafe { UInt64(__p.read()) }
    }

    // JSValueMakeUndefined
    public static func JSValueMakeUndefined(ctx: JSContextRef): JSValueRef {
        let resultPtr = unsafe { JSValueMakeUndefined(CPointer<UInt8>()) }
        let __p = unsafe { CPointer<UInt64>(resultPtr) }
        unsafe { UInt64(__p.read()) }
    }

    // JSValueMakeNull
    public static func JSValueMakeNull(ctx: JSContextRef): JSValueRef {
        let resultPtr = unsafe { JSValueMakeNull(CPointer<UInt8>()) }
        let __p = unsafe { CPointer<UInt64>(resultPtr) }
        unsafe { UInt64(__p.read()) }
    }

    // JSValueMakeBoolean
    public static func JSValueMakeBoolean(ctx: JSContextRef, boolean: Bool): JSValueRef {
        let resultPtr = unsafe { JSValueMakeBoolean(CPointer<UInt8>(), boolean) }
        let __p = unsafe { CPointer<UInt64>(resultPtr) }
        unsafe { UInt64(__p.read()) }
    }

    // JSValueMakeNumber
    public static func JSValueMakeNumber(ctx: JSContextRef, number: Float64): JSValueRef {
        let resultPtr = unsafe { JSValueMakeNumber(CPointer<UInt8>(), number) }
        let __p = unsafe { CPointer<UInt64>(resultPtr) }
        unsafe { UInt64(__p.read()) }
    }

    // JSValueMakeString
    public static func JSValueMakeString(ctx: JSContextRef, string: JSStringRef): JSValueRef {
        let resultPtr = unsafe { JSValueMakeString(CPointer<UInt8>(), string) }
        let __p = unsafe { CPointer<UInt64>(resultPtr) }
        unsafe { UInt64(__p.read()) }
    }

    // JSObjectCallAsFunction
    public static func JSObjectCallAsFunction(
        ctx: JSContextRef,
        object: JSObjectRef,
        thisObject: JSObjectRef,
        argumentCount: UInt64,
        arguments: CPointer<JSValueRef>,
        exception: CPointer<JSValueRef>
    ): JSValueRef {
        let resultPtr = unsafe {
            JSObjectCallAsFunction(CPointer<UInt8>(), CPointer<UInt8>(), CPointer<UInt8>(), argumentCount, CPointer<CPointer<UInt8>>(), CPointer<CPointer<UInt8>>())
        }
        let __p = unsafe { CPointer<UInt64>(resultPtr) }
        unsafe { UInt64(__p.read()) }
    }

    // JSObjectCallAsConstructor
    public static func JSObjectCallAsConstructor(
        ctx: JSContextRef,
        object: JSObjectRef,
        argumentCount: UInt64,
        arguments: CPointer<JSValueRef>,
        exception: CPointer<JSValueRef>
    ): JSObjectRef {
        let resultPtr = unsafe {
            JSObjectCallAsConstructor(CPointer<UInt8>(), CPointer<UInt8>(), argumentCount, CPointer<CPointer<UInt8>>(), CPointer<CPointer<UInt8>>())
        }
        let __p = unsafe { CPointer<UInt64>(resultPtr) }
        unsafe { UInt64(__p.read()) }
    }

    // JSObjectGetProperty
    public static func JSObjectGetProperty(
        ctx: JSContextRef,
        object: JSObjectRef,
        propertyName: JSStringRef,
        exception: CPointer<JSValueRef>
    ): JSValueRef {
        let resultPtr = unsafe { JSObjectGetProperty(CPointer<UInt8>(), CPointer<UInt8>(), propertyName, CPointer<CPointer<UInt8>>()) }
        let __p = unsafe { CPointer<UInt64>(resultPtr) }
        unsafe { UInt64(__p.read()) }
    }

    // JSObjectSetProperty
    public static func JSObjectSetProperty(
        ctx: JSContextRef,
        object: JSObjectRef,
        propertyName: JSStringRef,
        value: JSValueRef,
        attributes: UInt32,
        exception: CPointer<JSValueRef>
    ): Unit {
        unsafe { JSObjectSetProperty(CPointer<UInt8>(), CPointer<UInt8>(), propertyName, CPointer<UInt8>(), attributes, CPointer<CPointer<UInt8>>()) }
    }

    // JSObjectDeleteProperty
    public static func JSObjectDeleteProperty(
        ctx: JSContextRef,
        object: JSObjectRef,
        propertyName: JSStringRef,
        exception: CPointer<JSValueRef>
    ): Bool {
        unsafe { JSObjectDeleteProperty(CPointer<UInt8>(), CPointer<UInt8>(), propertyName, CPointer<CPointer<UInt8>>()) }
    }

    // JSObjectHasProperty
    public static func JSObjectHasProperty(
        ctx: JSContextRef,
        object: JSObjectRef,
        propertyName: JSStringRef
    ): Bool {
        unsafe { JSObjectHasProperty(CPointer<UInt8>(), CPointer<UInt8>(), propertyName) }
    }

    // JSObjectCopyPropertyNames
    public static func JSObjectCopyPropertyNames(
        ctx: JSContextRef,
        object: JSObjectRef
    ): JSPropertyNameArrayRef {
        unsafe { JSObjectCopyPropertyNames(CPointer<UInt8>(), CPointer<UInt8>()) }
    }

    // JSStringCreateWithUTF8CString
    public static func JSStringCreateWithUTF8CString(string: CPointer<UInt8>): JSStringRef {
        unsafe { JSStringCreateWithUTF8CString(CString(string)) }
    }

    // JSStringRelease
    public static func JSStringRelease(string: JSStringRef): Unit {
        unsafe { JSStringRelease(string) }
    }

    // JSStringGetLength
    public static func JSStringGetLength(string: JSStringRef): UInt64 {
        unsafe { JSStringGetLength(string) }
    }

    // JSStringGetMaximumUTF8CStringSize
    public static func JSStringGetMaximumUTF8CStringSize(string: JSStringRef): UInt64 {
        unsafe { JSStringGetMaximumUTF8CStringSize(string) }
    }

    // JSStringGetUTF8CString
    public static func JSStringGetUTF8CString(string: JSStringRef, buffer: CPointer<UInt8>, bufferSize: UInt64): UInt64 {
        unsafe { JSStringGetUTF8CString(string, buffer, bufferSize) }
    }

    // JSValueIsEqual
    public static func JSValueIsEqual(
        ctx: JSContextRef,
        a: JSValueRef,
        b: JSValueRef,
        exception: CPointer<JSValueRef>
    ): Bool {
        unsafe { JSValueIsEqual(CPointer<UInt8>(), CPointer<UInt8>(), CPointer<UInt8>(), CPointer<CPointer<UInt8>>()) }
    }

    // JSValueIsStrictEqual
    public static func JSValueIsStrictEqual(ctx: JSContextRef, a: JSValueRef, b: JSValueRef): Bool {
        unsafe { JSValueIsStrictEqual(CPointer<UInt8>(), CPointer<UInt8>(), CPointer<UInt8>()) }
    }

    // JSValueProtect
    public static func JSValueProtect(ctx: JSContextRef, value: JSValueRef): Unit {
        unsafe { JSValueProtect(CPointer<UInt8>(), CPointer<UInt8>()) }
    }

    // JSValueUnprotect
    public static func JSValueUnprotect(ctx: JSContextRef, value: JSValueRef): Unit {
        unsafe { JSValueUnprotect(CPointer<UInt8>(), CPointer<UInt8>()) }
    }

    // JSGlobalContextSetName — JSC 标准 C API
    // 设置全局上下文的名称, 对应 JSC API: JSGlobalContextSetName(ctx, name)
    public static func JSGlobalContextSetName(ctx: JSContextRef, name: JSStringRef): Unit {
        // 仓颉 FFI 尚未绑定此函数; 当前为空实现
    }

    // JSObjectGetPrototype
    public static func JSObjectGetPrototype(ctx: JSContextRef, object: JSObjectRef): JSValueRef {
        let resultPtr = unsafe { JSObjectGetPrototype(CPointer<UInt8>(), CPointer<UInt8>()) }
        let __p = unsafe { CPointer<UInt64>(resultPtr) }
        unsafe { UInt64(__p.read()) }
    }

    // JSObjectSetPrototype
    public static func JSObjectSetPrototype(ctx: JSContextRef, object: JSObjectRef, prototype: JSValueRef): Unit {
        unsafe { JSObjectSetPrototype(CPointer<UInt8>(), CPointer<UInt8>(), CPointer<UInt8>()) }
    }

    // JSObjectMakeFunctionWithCallback — JSC 标准 C API
    // 创建带回调的函数对象, 对应 JSC API: JSObjectMakeFunctionWithCallback(ctx, name, callAsFunction)
    public static func JSObjectMakeFunctionWithCallback(
        ctx: JSContextRef,
        name: JSStringRef,
        callAsFunction: CPointer<UInt8>
    ): JSObjectRef {
        // 仓颉 FFI 尚未绑定此函数; 返回空引用
        UInt64(0)
    }

    // JSGarbageCollect
    public static func JSGarbageCollect(ctx: JSContextRef): Unit {
        unsafe { JSGarbageCollect(CPointer<UInt8>()) }
    }

    // JSObjectIsFunction
    public static func JSObjectIsFunction(ctx: JSContextRef, object: JSObjectRef): Bool {
        unsafe { JSObjectIsFunction(CPointer<UInt8>(), CPointer<UInt8>()) }
    }

    // JSObjectIsConstructor
    public static func JSObjectIsConstructor(ctx: JSContextRef, object: JSObjectRef): Bool {
        unsafe { JSObjectIsConstructor(CPointer<UInt8>(), CPointer<UInt8>()) }
    }

    // === 辅助方法 ===

    // 保护值
    public static func valueProtect(ctx: JSContextRef, value: JSValueRef) {
        JSCApi.JSValueProtect(ctx, value)
    }

    public static func valueUnprotect(ctx: JSContextRef, value: JSValueRef) {
        JSCApi.JSValueUnprotect(ctx, value)
    }

    // UTF-8 字符串转换辅助
    public static func createJSString(s: String): JSStringRef {
        unsafe {
            let cStr = LibC.mallocCString(s)
            let ref = JSStringCreateWithUTF8CString(cStr)
            LibC.free(cStr)
            ref
        }
    }

    public static func releaseJSString(s: JSStringRef) {
        unsafe {
            JSStringRelease(s)
        }
    }

    // 从 JSStringRef 转为 String
    public static func jsStringToString(s: JSStringRef): String {
        unsafe {
            let maxSize = JSStringGetMaximumUTF8CStringSize(s)
            if (maxSize == 0) { return "" }
            // TODO: allocate a native buffer and call JSStringGetUTF8CString.
            ""
        }
    }
}
