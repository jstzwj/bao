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
    public static func JSGlobalContextCreate(group: JSClassRef): JSContextRef { return CPointer<UInt8>() }

    // JSGlobalContextRelease
    public static func JSGlobalContextRelease(ctx: JSContextRef): Unit { return }

    // JSEvaluateScript
    public static func JSEvaluateScript(
        ctx: JSContextRef,
        script: JSStringRef,
        thisObject: JSObjectRef,
        sourceURL: JSStringRef,
        startingLineNumber: Int32,
        exception: CPointer<JSValueRef>
    ): JSValueRef { return CPointer<UInt8>() }

    // JSCheckScriptSyntax
    public static func JSCheckScriptSyntax(
        ctx: JSContextRef,
        script: JSStringRef,
        sourceURL: JSStringRef,
        startingLineNumber: Int32,
        exception: CPointer<JSValueRef>
    ): Bool { return false }

    // JSValueGetType
    public static func JSValueGetType(ctx: JSContextRef, value: JSValueRef): Int32 { return 0 }

    // JSValueIsUndefined
    public static func JSValueIsUndefined(ctx: JSContextRef, value: JSValueRef): Bool { return false }

    // JSValueIsNull
    public static func JSValueIsNull(ctx: JSContextRef, value: JSValueRef): Bool { return false }

    // JSValueIsBoolean
    public static func JSValueIsBoolean(ctx: JSContextRef, value: JSValueRef): Bool { return false }

    // JSValueIsNumber
    public static func JSValueIsNumber(ctx: JSContextRef, value: JSValueRef): Bool { return false }

    // JSValueIsString
    public static func JSValueIsString(ctx: JSContextRef, value: JSValueRef): Bool { return false }

    // JSValueIsObject
    public static func JSValueIsObject(ctx: JSContextRef, value: JSValueRef): Bool { return false }

    // JSValueIsSymbol
    public static func JSValueIsSymbol(ctx: JSContextRef, value: JSValueRef): Bool { return false }

    // JSValueToBoolean
    public static func JSValueToBoolean(ctx: JSContextRef, value: JSValueRef): Bool { return false }

    // JSValueToNumber
    public static func JSValueToNumber(ctx: JSContextRef, value: JSValueRef, exception: CPointer<JSValueRef>): Float64 { return 0.0 }

    // JSValueToStringCopy
    public static func JSValueToStringCopy(ctx: JSContextRef, value: JSValueRef, exception: CPointer<JSValueRef>): JSStringRef { return CPointer<UInt8>() }

    // JSValueToObject
    public static func JSValueToObject(ctx: JSContextRef, value: JSValueRef, exception: CPointer<JSValueRef>): JSObjectRef { return CPointer<UInt8>() }

    // JSValueMakeUndefined
    public static func JSValueMakeUndefined(ctx: JSContextRef): JSValueRef { return CPointer<UInt8>() }

    // JSValueMakeNull
    public static func JSValueMakeNull(ctx: JSContextRef): JSValueRef { return CPointer<UInt8>() }

    // JSValueMakeBoolean
    public static func JSValueMakeBoolean(ctx: JSContextRef, boolean: Bool): JSValueRef { return CPointer<UInt8>() }

    // JSValueMakeNumber
    public static func JSValueMakeNumber(ctx: JSContextRef, number: Float64): JSValueRef { return CPointer<UInt8>() }

    // JSValueMakeString
    public static func JSValueMakeString(ctx: JSContextRef, string: JSStringRef): JSValueRef { return CPointer<UInt8>() }

    // JSObjectCallAsFunction
    public static func JSObjectCallAsFunction(
        ctx: JSContextRef,
        object: JSObjectRef,
        thisObject: JSObjectRef,
        argumentCount: UInt64,
        arguments: CPointer<JSValueRef>,
        exception: CPointer<JSValueRef>
    ): JSValueRef { return CPointer<UInt8>() }

    // JSObjectCallAsConstructor
    public static func JSObjectCallAsConstructor(
        ctx: JSContextRef,
        object: JSObjectRef,
        argumentCount: UInt64,
        arguments: CPointer<JSValueRef>,
        exception: CPointer<JSValueRef>
    ): JSObjectRef { return CPointer<UInt8>() }

    // JSObjectGetProperty
    public static func JSObjectGetProperty(
        ctx: JSContextRef,
        object: JSObjectRef,
        propertyName: JSStringRef,
        exception: CPointer<JSValueRef>
    ): JSValueRef { return CPointer<UInt8>() }

    // JSObjectSetProperty
    public static func JSObjectSetProperty(
        ctx: JSContextRef,
        object: JSObjectRef,
        propertyName: JSStringRef,
        value: JSValueRef,
        attributes: UInt32,
        exception: CPointer<JSValueRef>
    ): Unit { return }

    // JSObjectDeleteProperty
    public static func JSObjectDeleteProperty(
        ctx: JSContextRef,
        object: JSObjectRef,
        propertyName: JSStringRef,
        exception: CPointer<JSValueRef>
    ): Bool { return false }

    // JSObjectHasProperty
    public static func JSObjectHasProperty(
        ctx: JSContextRef,
        object: JSObjectRef,
        propertyName: JSStringRef
    ): Bool { return false }

    // JSObjectCopyPropertyNames
    public static func JSObjectCopyPropertyNames(
        ctx: JSContextRef,
        object: JSObjectRef
    ): JSPropertyNameArrayRef { return CPointer<UInt8>() }

    // JSStringCreateWithUTF8CString
    public static func JSStringCreateWithUTF8CString(string: CPointer<UInt8>): JSStringRef { return CPointer<UInt8>() }

    // JSStringRelease
    public static func JSStringRelease(string: JSStringRef): Unit { return }

    // JSStringGetLength
    public static func JSStringGetLength(string: JSStringRef): UInt64 { return 0 }

    // JSStringGetMaximumUTF8CStringSize
    public static func JSStringGetMaximumUTF8CStringSize(string: JSStringRef): UInt64 { return 0 }

    // JSStringGetUTF8CString
    public static func JSStringGetUTF8CString(string: JSStringRef, buffer: CPointer<UInt8>, bufferSize: UInt64): UInt64 { return 0 }

    // JSValueIsEqual
    public static func JSValueIsEqual(
        ctx: JSContextRef,
        a: JSValueRef,
        b: JSValueRef,
        exception: CPointer<JSValueRef>
    ): Bool { return false }

    // JSValueIsStrictEqual
    public static func JSValueIsStrictEqual(ctx: JSContextRef, a: JSValueRef, b: JSValueRef): Bool { return false }

    // JSValueProtect
    public static func JSValueProtect(ctx: JSContextRef, value: JSValueRef): Unit { return }

    // JSValueUnprotect
    public static func JSValueUnprotect(ctx: JSContextRef, value: JSValueRef): Unit { return }

    // JSGlobalContextSetName
    public static func JSGlobalContextSetName(ctx: JSContextRef, name: JSStringRef): Unit { return }

    // JSObjectGetPrototype
    public static func JSObjectGetPrototype(ctx: JSContextRef, object: JSObjectRef): JSValueRef { return CPointer<UInt8>() }

    // JSObjectSetPrototype
    public static func JSObjectSetPrototype(ctx: JSContextRef, object: JSObjectRef, prototype: JSValueRef): Unit { return }

    // JSObjectMakeFunctionWithCallback
    public static func JSObjectMakeFunctionWithCallback(
        ctx: JSContextRef,
        name: JSStringRef,
        callAsFunction: CPointer<UInt8>
    ): JSObjectRef { return CPointer<UInt8>() }

    // JSGarbageCollect
    public static func JSGarbageCollect(ctx: JSContextRef): Unit { return }

    // JSObjectIsFunction
    public static func JSObjectIsFunction(ctx: JSContextRef, object: JSObjectRef): Bool { return false }

    // JSObjectIsConstructor
    public static func JSObjectIsConstructor(ctx: JSContextRef, object: JSObjectRef): Bool { return false }

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
    public static func createJSString(s: String): JSStringRef {
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
    public static func jsStringToString(s: JSStringRef): String {
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
