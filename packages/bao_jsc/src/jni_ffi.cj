// 严格翻译自: src/jsc/bindings/*.zig
// JavaScriptCore C API FFI 绑定

package bao_jsc

// JSC C API 类型定义 - 严格翻译自 bindings/C.zig
// 这些类型对应 JSC C API 中的不透明指针

// JSContextRef - JSC 执行上下文
public type JSContextRef = CPointer<UInt8>
// JSValueRef - JS 值
public type JSValueRef = CPointer<UInt8>
// JSObjectRef - JS 对象
public type JSObjectRef = CPointer<UInt8>
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
class JSCApi {
    // JSGlobalContextCreate
    @C
    foreign func JSGlobalContextCreate(group: JSClassRef): JSContextRef

    // JSGlobalContextRelease
    @C
    foreign func JSGlobalContextRelease(ctx: JSContextRef): Unit

    // JSEvaluateScript
    @C
    foreign func JSEvaluateScript(
        ctx: JSContextRef,
        script: JSStringRef,
        thisObject: JSObjectRef,
        sourceURL: JSStringRef,
        startingLineNumber: Int32,
        exception: CPointer<JSValueRef>
    ): JSValueRef

    // JSCheckScriptSyntax
    @C
    foreign func JSCheckScriptSyntax(
        ctx: JSContextRef,
        script: JSStringRef,
        sourceURL: JSStringRef,
        startingLineNumber: Int32,
        exception: CPointer<JSValueRef>
    ): Bool

    // JSValueGetType
    @C
    foreign func JSValueGetType(ctx: JSContextRef, value: JSValueRef): Int32

    // JSValueIsUndefined
    @C
    foreign func JSValueIsUndefined(ctx: JSContextRef, value: JSValueRef): Bool

    // JSValueIsNull
    @C
    foreign func JSValueIsNull(ctx: JSContextRef, value: JSValueRef): Bool

    // JSValueIsBoolean
    @C
    foreign func JSValueIsBoolean(ctx: JSContextRef, value: JSValueRef): Bool

    // JSValueIsNumber
    @C
    foreign func JSValueIsNumber(ctx: JSContextRef, value: JSValueRef): Bool

    // JSValueIsString
    @C
    foreign func JSValueIsString(ctx: JSContextRef, value: JSValueRef): Bool

    // JSValueIsObject
    @C
    foreign func JSValueIsObject(ctx: JSContextRef, value: JSValueRef): Bool

    // JSValueIsSymbol
    @C
    foreign func JSValueIsSymbol(ctx: JSContextRef, value: JSValueRef): Bool

    // JSValueToBoolean
    @C
    foreign func JSValueToBoolean(ctx: JSContextRef, value: JSValueRef): Bool

    // JSValueToNumber
    @C
    foreign func JSValueToNumber(ctx: JSContextRef, value: JSValueRef, exception: CPointer<JSValueRef>): Float64

    // JSValueToStringCopy
    @C
    foreign func JSValueToStringCopy(ctx: JSContextRef, value: JSValueRef, exception: CPointer<JSValueRef>): JSStringRef

    // JSValueToObject
    @C
    foreign func JSValueToObject(ctx: JSContextRef, value: JSValueRef, exception: CPointer<JSValueRef>): JSObjectRef

    // JSValueMakeUndefined
    @C
    foreign func JSValueMakeUndefined(ctx: JSContextRef): JSValueRef

    // JSValueMakeNull
    @C
    foreign func JSValueMakeNull(ctx: JSContextRef): JSValueRef

    // JSValueMakeBoolean
    @C
    foreign func JSValueMakeBoolean(ctx: JSContextRef, boolean: Bool): JSValueRef

    // JSValueMakeNumber
    @C
    foreign func JSValueMakeNumber(ctx: JSContextRef, number: Float64): JSValueRef

    // JSValueMakeString
    @C
    foreign func JSValueMakeString(ctx: JSContextRef, string: JSStringRef): JSValueRef

    // JSObjectCallAsFunction
    @C
    foreign func JSObjectCallAsFunction(
        ctx: JSContextRef,
        object: JSObjectRef,
        thisObject: JSObjectRef,
        argumentCount: UInt64,
        arguments: CPointer<JSValueRef>,
        exception: CPointer<JSValueRef>
    ): JSValueRef

    // JSObjectCallAsConstructor
    @C
    foreign func JSObjectCallAsConstructor(
        ctx: JSContextRef,
        object: JSObjectRef,
        argumentCount: UInt64,
        arguments: CPointer<JSValueRef>,
        exception: CPointer<JSValueRef>
    ): JSObjectRef

    // JSObjectGetProperty
    @C
    foreign func JSObjectGetProperty(
        ctx: JSContextRef,
        object: JSObjectRef,
        propertyName: JSStringRef,
        exception: CPointer<JSValueRef>
    ): JSValueRef

    // JSObjectSetProperty
    @C
    foreign func JSObjectSetProperty(
        ctx: JSContextRef,
        object: JSObjectRef,
        propertyName: JSStringRef,
        value: JSValueRef,
        attributes: UInt32,
        exception: CPointer<JSValueRef>
    ): Unit

    // JSObjectDeleteProperty
    @C
    foreign func JSObjectDeleteProperty(
        ctx: JSContextRef,
        object: JSObjectRef,
        propertyName: JSStringRef,
        exception: CPointer<JSValueRef>
    ): Bool

    // JSObjectHasProperty
    @C
    foreign func JSObjectHasProperty(
        ctx: JSContextRef,
        object: JSObjectRef,
        propertyName: JSStringRef
    ): Bool

    // JSObjectCopyPropertyNames
    @C
    foreign func JSObjectCopyPropertyNames(
        ctx: JSContextRef,
        object: JSObjectRef
    ): JSPropertyNameArrayRef

    // JSStringCreateWithUTF8CString
    @C
    foreign func JSStringCreateWithUTF8CString(string: CPointer<UInt8>): JSStringRef

    // JSStringRelease
    @C
    foreign func JSStringRelease(string: JSStringRef): Unit

    // JSStringGetLength
    @C
    foreign func JSStringGetLength(string: JSStringRef): UInt64

    // JSStringGetMaximumUTF8CStringSize
    @C
    foreign func JSStringGetMaximumUTF8CStringSize(string: JSStringRef): UInt64

    // JSStringGetUTF8CString
    @C
    foreign func JSStringGetUTF8CString(string: JSStringRef, buffer: CPointer<UInt8>, bufferSize: UInt64): UInt64

    // JSValueIsEqual
    @C
    foreign func JSValueIsEqual(
        ctx: JSContextRef,
        a: JSValueRef,
        b: JSValueRef,
        exception: CPointer<JSValueRef>
    ): Bool

    // JSValueIsStrictEqual
    @C
    foreign func JSValueIsStrictEqual(ctx: JSContextRef, a: JSValueRef, b: JSValueRef): Bool

    // JSValueProtect
    @C
    foreign func JSValueProtect(ctx: JSContextRef, value: JSValueRef): Unit

    // JSValueUnprotect
    @C
    foreign func JSValueUnprotect(ctx: JSContextRef, value: JSValueRef): Unit

    // JSGlobalContextSetName
    @C
    foreign func JSGlobalContextSetName(ctx: JSContextRef, name: JSStringRef): Unit

    // JSObjectGetPrototype
    @C
    foreign func JSObjectGetPrototype(ctx: JSContextRef, object: JSObjectRef): JSValueRef

    // JSObjectSetPrototype
    @C
    foreign func JSObjectSetPrototype(ctx: JSContextRef, object: JSObjectRef, prototype: JSValueRef): Unit

    // JSObjectMakeFunctionWithCallback
    @C
    foreign func JSObjectMakeFunctionWithCallback(
        ctx: JSContextRef,
        name: JSStringRef,
        callAsFunction: CPointer<UInt8>
    ): JSObjectRef

    // JSGarbageCollect
    @C
    foreign func JSGarbageCollect(ctx: JSContextRef): Unit

    // JSObjectIsFunction
    @C
    foreign func JSObjectIsFunction(ctx: JSContextRef, object: JSObjectRef): Bool

    // JSObjectIsConstructor
    @C
    foreign func JSObjectIsConstructor(ctx: JSContextRef, object: JSObjectRef): Bool

    // === 辅助方法 ===

    // 保护值
    public static func valueProtect(ctx: JSContextRef, value: JSValueRef) {
        unsafe {
            JSCApi().JSValueProtect(ctx, value)
        }
    }

    public static func valueUnprotect(ctx: JSContextRef, value: JSValueRef) {
        unsafe {
            JSCApi().JSValueUnprotect(ctx, value)
        }
    }

    // UTF-8 字符串转换辅助
    public static func createJSString(s: String) -> JSStringRef {
        unsafe {
            // 将 String 转为 C 字符串指针
            let bytes = s.toArray()
            JSStringCreateWithUTF8CString(CPointer<UInt8>.from(bytes))
        }
    }

    public static func releaseJSString(s: JSStringRef) {
        unsafe {
            JSStringRelease(s)
        }
    }

    // 从 JSStringRef 转为 String
    public static func jsStringToString(s: JSStringRef) -> String {
        unsafe {
            let maxSize = JSStringGetMaximumUTF8CStringSize(s)
            if (maxSize == 0) { return "" }
            let buffer = Array<UInt8>(maxSize, item: 0)
            let len = JSStringGetUTF8CString(s, CPointer<UInt8>.from(buffer), maxSize)
            if (len == 0) { return "" }
            String.fromUtf8(buffer[0..Int64(len)])
        }
    }
}
