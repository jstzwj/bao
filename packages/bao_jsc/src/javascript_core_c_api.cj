// 严格翻译自: src/jsc/javascript_core_c_api.zig
// JavaScriptCore C API 绑定

package bao_jsc

// ========== JSC C API 类型 ==========
// 注意: 不要在新代码中使用这些。请使用 jsc.JSValue
// 对于新的 JavaScript 类，请查看 *.classes.ts 文件

// 严格翻译自 JSContextGroupRef
public type JSContextGroupRef = UInt64

// 严格翻译自 JSContextRef
public type JSContextRef = UInt64

// 严格翻译自 JSGlobalContextRef
public type JSGlobalContextRef = JsObject

// 严格翻译自 JSValueRef
public type JSValueRef = UInt64

// 严格翻译自 JSObjectRef
public type JSObjectRef = UInt64

// 严格翻译自 ExceptionRef
public type ExceptionRef = UInt64

// 严格翻译自 JSPropertyNameAccumulatorRef
public type JSPropertyNameAccumulatorRef = UInt64

// 严格翻译自 JSTypedArrayBytesDeallocator
public type JSTypedArrayBytesDeallocator = (UInt64, UInt64) -> Unit

// ========== JSType ==========
// 严格翻译自 JSType
public enum JSTypeC {
    | kJSTypeUndefined
    | kJSTypeNull
    | kJSTypeBoolean
    | kJSTypeNumber
    | kJSTypeString
    | kJSTypeObject
    | kJSTypeSymbol
    | kJSTypeBigInt
}

// ========== JSTypedArrayType ==========
// 严格翻译自 JSTypedArrayType
public enum JSTypedArrayType {
    | kJSTypedArrayTypeInt8Array
    | kJSTypedArrayTypeInt16Array
    | kJSTypedArrayTypeInt32Array
    | kJSTypedArrayTypeUint8Array
    | kJSTypedArrayTypeUint8ClampedArray
    | kJSTypedArrayTypeUint16Array
    | kJSTypedArrayTypeUint32Array
    | kJSTypedArrayTypeFloat32Array
    | kJSTypedArrayTypeFloat64Array
    | kJSTypedArrayTypeArrayBuffer
    | kJSTypedArrayTypeNone
    | kJSTypedArrayTypeBigInt64Array
    | kJSTypedArrayTypeBigUint64Array
}

// ========== JSPropertyAttributes ==========
// 严格翻译自 JSPropertyAttributes
public enum JSPropertyAttributes {
    | kJSPropertyAttributeNone
    | kJSPropertyAttributeReadOnly
    | kJSPropertyAttributeDontEnum
    | kJSPropertyAttributeDontDelete
}

// ========== JSClassAttributes ==========
// 严格翻译自 JSClassAttributes
public enum JSClassAttributes {
    | kJSClassAttributeNone
    | kJSClassAttributeNoAutomaticPrototype
}

// ========== JSCAPI ==========
// 严格翻译自 JSC C API 函数
public class JSCAPI {
    // JSGarbageCollect
    public static func jsGarbageCollect(ctx: JsObject) {
        // FFI: JSGarbageCollect
    }

    // JSValueGetType
    public static func jsValueGetType(ctx: JsObject, value: JSValueRef): JSTypeC {
        // FFI: JSValueGetType
        JSTypeC.kJSTypeUndefined
    }

    // JSValueMakeNull
    public static func jsValueMakeNull(ctx: JsObject): JSValueRef {
        // FFI: JSValueMakeNull
        0
    }

    // JSValueToNumber
    public static func jsValueToNumber(ctx: JsObject, value: JSValueRef, exception: ExceptionRef): Float64 {
        // FFI: JSValueToNumber
        0.0
    }

    // JSValueToObject
    public static func jsValueToObject(ctx: JsObject, value: JSValueRef, exception: ExceptionRef): JSObjectRef {
        // FFI: JSValueToObject
        0
    }

    // JSObjectGetPrototype
    public static func jsObjectGetPrototype(ctx: JsObject, object: JSObjectRef): JSValueRef {
        // FFI: JSObjectGetPrototype
        0
    }

    // JSObjectCallAsFunction
    public static func jsObjectCallAsFunction(ctx: JsObject, object: JSObjectRef, thisObject: JSObjectRef, argumentCount: Int64, arguments: Array<JSValueRef>, exception: ExceptionRef): JSValueRef {
        // FFI: JSObjectCallAsFunction
        0
    }

    // JSObjectCallAsFunctionReturnValueHoldingAPILock
    public static func jsObjectCallAsFunctionReturnValueHoldingAPILock(ctx: JsObject, object: JSObjectRef, thisObject: JSObjectRef, argumentCount: Int64, arguments: Array<JSValueRef>): JsValue {
        // FFI: JSObjectCallAsFunctionReturnValueHoldingAPILock
        JsValue()
    }

    // JSObjectMakeTypedArray
    public static func jsObjectMakeTypedArray(ctx: JsObject, arrayType: JSTypedArrayType, length: Int64, exception: ExceptionRef): JSObjectRef {
        // FFI: JSObjectMakeTypedArray
        0
    }

    // JSObjectGetTypedArrayLength
    public static func jsObjectGetTypedArrayLength(ctx: JsObject, object: JSObjectRef, exception: ExceptionRef): Int64 {
        // FFI: JSObjectGetTypedArrayLength
        0
    }

    // JSObjectGetTypedArrayByteLength
    public static func jsObjectGetTypedArrayByteLength(ctx: JsObject, object: JSObjectRef, exception: ExceptionRef): Int64 {
        // FFI: JSObjectGetTypedArrayByteLength
        0
    }

    // JSObjectGetTypedArrayByteOffset
    public static func jsObjectGetTypedArrayByteOffset(ctx: JsObject, object: JSObjectRef, exception: ExceptionRef): Int64 {
        // FFI: JSObjectGetTypedArrayByteOffset
        0
    }

    // JSObjectGetTypedArrayBuffer
    public static func jsObjectGetTypedArrayBuffer(ctx: JsObject, object: JSObjectRef, exception: ExceptionRef): JSObjectRef {
        // FFI: JSObjectGetTypedArrayBuffer
        0
    }

    // JSRemoteInspector
    public static func jsRemoteInspectorDisableAutoStart() {
        // FFI: JSRemoteInspectorDisableAutoStart
    }

    public static func jsRemoteInspectorStart() {
        // FFI: JSRemoteInspectorStart
    }

    public static func jsRemoteInspectorSetLogToSystemConsole(enabled: Bool) {
        // FFI: JSRemoteInspectorSetLogToSystemConsole
    }

    public static func jsRemoteInspectorGetInspectionEnabledByDefault(): Bool {
        // FFI: JSRemoteInspectorGetInspectionEnabledByDefault
        false
    }

    public static func jsRemoteInspectorSetInspectionEnabledByDefault(enabled: Bool) {
        // FFI: JSRemoteInspectorSetInspectionEnabledByDefault
    }

    // JSObjectGetProxyTarget
    public static func jsObjectGetProxyTarget(object: JSObjectRef): JSObjectRef {
        // FFI: JSObjectGetProxyTarget
        0
    }
}
