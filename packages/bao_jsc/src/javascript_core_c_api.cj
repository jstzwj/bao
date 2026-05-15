// 严格翻译自: src/jsc/javascript_core_c_api.zig
// JavaScriptCore C API 绑定

package bao_jsc

// ========== JSC C API 类型 ==========
// 注意: 不要在新代码中使用这些。请使用 jsc.JSValue
// 对于新的 JavaScript 类，请查看 *.classes.ts 文件

// 严格翻译自 JSContextGroupRef
public typealias JSContextGroupRef = UInt64

// 严格翻译自 JSGlobalContextRef
public typealias JSGlobalContextRef = JsObject

// 严格翻译自 JSValueRef
public typealias JSValueRef = UInt64

// 严格翻译自 JSObjectRef
public typealias JSObjectRef = UInt64

// 严格翻译自 ExceptionRef
public typealias ExceptionRef = UInt64

// 严格翻译自 JSPropertyNameAccumulatorRef
public typealias JSPropertyNameAccumulatorRef = UInt64

// 严格翻译自 JSTypedArrayBytesDeallocator
public typealias JSTypedArrayBytesDeallocator = (UInt64, UInt64) -> Void

// ========== JSType ==========
// 严格翻译自 JSType
public enum JSTypeC: UInt32 {
    case kJSTypeUndefined = 0
    case kJSTypeNull = 1
    case kJSTypeBoolean = 2
    case kJSTypeNumber = 3
    case kJSTypeString = 4
    case kJSTypeObject = 5
    case kJSTypeSymbol = 6
    case kJSTypeBigInt = 7
}

// ========== JSTypedArrayType ==========
// 严格翻译自 JSTypedArrayType
public enum JSTypedArrayType: UInt32 {
    case kJSTypedArrayTypeInt8Array = 0
    case kJSTypedArrayTypeInt16Array = 1
    case kJSTypedArrayTypeInt32Array = 2
    case kJSTypedArrayTypeUint8Array = 3
    case kJSTypedArrayTypeUint8ClampedArray = 4
    case kJSTypedArrayTypeUint16Array = 5
    case kJSTypedArrayTypeUint32Array = 6
    case kJSTypedArrayTypeFloat32Array = 7
    case kJSTypedArrayTypeFloat64Array = 8
    case kJSTypedArrayTypeArrayBuffer = 9
    case kJSTypedArrayTypeNone = 10
    case kJSTypedArrayTypeBigInt64Array = 11
    case kJSTypedArrayTypeBigUint64Array = 12
}

// ========== JSPropertyAttributes ==========
// 严格翻译自 JSPropertyAttributes
public enum JSPropertyAttributes: UInt32 {
    case kJSPropertyAttributeNone = 0
    case kJSPropertyAttributeReadOnly = 2
    case kJSPropertyAttributeDontEnum = 4
    case kJSPropertyAttributeDontDelete = 8
}

// ========== JSClassAttributes ==========
// 严格翻译自 JSClassAttributes
public enum JSClassAttributes: UInt32 {
    case kJSClassAttributeNone = 0
    case kJSClassAttributeNoAutomaticPrototype = 2
}

// ========== JSCAPI ==========
// 严格翻译自 JSC C API 函数
public class JSCAPI {
    // JSGarbageCollect
    public static func jsGarbageCollect(ctx: JsObject) {
        // FFI: JSGarbageCollect
    }

    // JSValueGetType
    public static func jsValueGetType(ctx: JsObject, value: JSValueRef) -> JSTypeC {
        // FFI: JSValueGetType
        JSTypeC.kJSTypeUndefined
    }

    // JSValueMakeNull
    public static func jsValueMakeNull(ctx: JsObject) -> JSValueRef {
        // FFI: JSValueMakeNull
        0
    }

    // JSValueToNumber
    public static func jsValueToNumber(ctx: JsObject, value: JSValueRef, exception: ExceptionRef) -> Float64 {
        // FFI: JSValueToNumber
        0.0
    }

    // JSValueToObject
    public static func jsValueToObject(ctx: JsObject, value: JSValueRef, exception: ExceptionRef) -> JSObjectRef {
        // FFI: JSValueToObject
        0
    }

    // JSObjectGetPrototype
    public static func jsObjectGetPrototype(ctx: JsObject, object: JSObjectRef) -> JSValueRef {
        // FFI: JSObjectGetPrototype
        0
    }

    // JSObjectCallAsFunction
    public static func jsObjectCallAsFunction(ctx: JsObject, object: JSObjectRef, thisObject: JSObjectRef, argumentCount: Int64, arguments: Array<JSValueRef>, exception: ExceptionRef) -> JSValueRef {
        // FFI: JSObjectCallAsFunction
        0
    }

    // JSObjectCallAsFunctionReturnValueHoldingAPILock
    public static func jsObjectCallAsFunctionReturnValueHoldingAPILock(ctx: JsObject, object: JSObjectRef, thisObject: JSObjectRef, argumentCount: Int64, arguments: Array<JSValueRef>) -> JsValue {
        // FFI: JSObjectCallAsFunctionReturnValueHoldingAPILock
        JsValue.zero
    }

    // JSObjectMakeTypedArray
    public static func jsObjectMakeTypedArray(ctx: JsObject, arrayType: JSTypedArrayType, length: Int64, exception: ExceptionRef) -> JSObjectRef {
        // FFI: JSObjectMakeTypedArray
        0
    }

    // JSObjectGetTypedArrayLength
    public static func jsObjectGetTypedArrayLength(ctx: JsObject, object: JSObjectRef, exception: ExceptionRef) -> Int64 {
        // FFI: JSObjectGetTypedArrayLength
        0
    }

    // JSObjectGetTypedArrayByteLength
    public static func jsObjectGetTypedArrayByteLength(ctx: JsObject, object: JSObjectRef, exception: ExceptionRef) -> Int64 {
        // FFI: JSObjectGetTypedArrayByteLength
        0
    }

    // JSObjectGetTypedArrayByteOffset
    public static func jsObjectGetTypedArrayByteOffset(ctx: JsObject, object: JSObjectRef, exception: ExceptionRef) -> Int64 {
        // FFI: JSObjectGetTypedArrayByteOffset
        0
    }

    // JSObjectGetTypedArrayBuffer
    public static func jsObjectGetTypedArrayBuffer(ctx: JsObject, object: JSObjectRef, exception: ExceptionRef) -> JSObjectRef {
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

    public static func jsRemoteInspectorGetInspectionEnabledByDefault() -> Bool {
        // FFI: JSRemoteInspectorGetInspectionEnabledByDefault
        false
    }

    public static func jsRemoteInspectorSetInspectionEnabledByDefault(enabled: Bool) {
        // FFI: JSRemoteInspectorSetInspectionEnabledByDefault
    }

    // JSObjectGetProxyTarget
    public static func jsObjectGetProxyTarget(object: JSObjectRef) -> JSObjectRef {
        // FFI: JSObjectGetProxyTarget
        0
    }
}
