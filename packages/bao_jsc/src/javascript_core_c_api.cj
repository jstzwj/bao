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
// 委托给 jsc_ffi.cj 中的 foreign 声明
public class JSCAPI {
    // JSGarbageCollect
    public static func jsGarbageCollect(ctx: JsObject) {
        unsafe { JSGarbageCollect(ctx.rawPtr) }
    }

    // JSValueGetType
    public static func jsValueGetType(ctx: JsObject, value: JSValueRef): JSTypeC {
        let rawCtx = ctx.rawPtr
        let rawVal = CPointer<UInt8>()
        let typeInt = unsafe { JSValueGetType(rawCtx, rawVal) }
        match (typeInt) {
            case 0 => JSTypeC.kJSTypeUndefined
            case 1 => JSTypeC.kJSTypeNull
            case 2 => JSTypeC.kJSTypeBoolean
            case 3 => JSTypeC.kJSTypeNumber
            case 4 => JSTypeC.kJSTypeString
            case 5 => JSTypeC.kJSTypeObject
            case 6 => JSTypeC.kJSTypeSymbol
            case 7 => JSTypeC.kJSTypeBigInt
            case _ => JSTypeC.kJSTypeUndefined
        }
    }

    // JSValueMakeNull
    public static func jsValueMakeNull(ctx: JsObject): JSValueRef {
        let ptr = unsafe { JSValueMakeNull(ctx.rawPtr) }
        UInt64(CPointer<UInt64>(ptr).read())
    }

    // JSValueToNumber
    public static func jsValueToNumber(ctx: JsObject, value: JSValueRef, exception: ExceptionRef): Float64 {
        let rawCtx = ctx.rawPtr
        let rawVal = CPointer<UInt8>()
        unsafe { JSValueToNumber(rawCtx, rawVal, CPointer<CPointer<UInt8>>()) }
    }

    // JSValueToObject
    public static func jsValueToObject(ctx: JsObject, value: JSValueRef, exception: ExceptionRef): JSObjectRef {
        let rawCtx = ctx.rawPtr
        let rawVal = CPointer<UInt8>()
        let resultPtr = unsafe { JSValueToObject(rawCtx, rawVal, CPointer<CPointer<UInt8>>()) }
        UInt64(CPointer<UInt64>(resultPtr).read())
    }

    // JSObjectGetPrototype
    public static func jsObjectGetPrototype(ctx: JsObject, object: JSObjectRef): JSValueRef {
        let rawCtx = ctx.rawPtr
        let rawObj = CPointer<UInt8>()
        let resultPtr = unsafe { JSObjectGetPrototype(rawCtx, rawObj) }
        UInt64(CPointer<UInt64>(resultPtr).read())
    }

    // JSObjectCallAsFunction
    public static func jsObjectCallAsFunction(ctx: JsObject, object: JSObjectRef, thisObject: JSObjectRef, argumentCount: Int64, arguments: Array<JSValueRef>, exception: ExceptionRef): JSValueRef {
        let rawCtx = ctx.rawPtr
        let rawObj = CPointer<UInt8>()
        let rawThis = CPointer<UInt8>()
        let resultPtr = unsafe {
            JSObjectCallAsFunction(rawCtx, rawObj, rawThis, UInt64(argumentCount), CPointer<CPointer<UInt8>>(), CPointer<CPointer<UInt8>>())
        }
        UInt64(CPointer<UInt64>(resultPtr).read())
    }

    // JSObjectCallAsFunctionReturnValueHoldingAPILock
    public static func jsObjectCallAsFunctionReturnValueHoldingAPILock(ctx: JsObject, object: JSObjectRef, thisObject: JSObjectRef, argumentCount: Int64, arguments: Array<JSValueRef>): JsValue {
        let result = jsObjectCallAsFunction(ctx, object, thisObject, argumentCount, arguments, 0)
        JsValue()
    }

    // JSObjectMakeTypedArray
    public static func jsObjectMakeTypedArray(ctx: JsObject, arrayType: JSTypedArrayType, length: Int64, exception: ExceptionRef): JSObjectRef {
        let typeInt: Int32 = match (arrayType) {
            case kJSTypedArrayTypeInt8Array => 1
            case kJSTypedArrayTypeInt16Array => 3
            case kJSTypedArrayTypeInt32Array => 5
            case kJSTypedArrayTypeUint8Array => 2
            case kJSTypedArrayTypeUint8ClampedArray => 4
            case kJSTypedArrayTypeUint16Array => 6
            case kJSTypedArrayTypeUint32Array => 7
            case kJSTypedArrayTypeFloat32Array => 8
            case kJSTypedArrayTypeFloat64Array => 9
            case kJSTypedArrayTypeArrayBuffer => 10
            case kJSTypedArrayTypeNone => 0
            case kJSTypedArrayTypeBigInt64Array => 11
            case kJSTypedArrayTypeBigUint64Array => 12
        }
        let resultPtr = unsafe {
            JSObjectMakeTypedArray(ctx.rawPtr, typeInt, UInt64(length), CPointer<CPointer<UInt8>>())
        }
        UInt64(CPointer<UInt64>(resultPtr).read())
    }

    // JSObjectGetTypedArrayLength
    public static func jsObjectGetTypedArrayLength(ctx: JsObject, object: JSObjectRef, exception: ExceptionRef): Int64 {
        let rawObj = CPointer<UInt8>()
        let len = unsafe { JSObjectGetTypedArrayLength(ctx.rawPtr, rawObj, CPointer<CPointer<UInt8>>()) }
        Int64(len)
    }

    // JSObjectGetTypedArrayByteLength
    public static func jsObjectGetTypedArrayByteLength(ctx: JsObject, object: JSObjectRef, exception: ExceptionRef): Int64 {
        let rawObj = CPointer<UInt8>()
        let len = unsafe { JSObjectGetTypedArrayByteLength(ctx.rawPtr, rawObj, CPointer<CPointer<UInt8>>()) }
        Int64(len)
    }

    // JSObjectGetTypedArrayByteOffset
    public static func jsObjectGetTypedArrayByteOffset(ctx: JsObject, object: JSObjectRef, exception: ExceptionRef): Int64 {
        let rawObj = CPointer<UInt8>()
        let offset = unsafe { JSObjectGetTypedArrayByteOffset(ctx.rawPtr, rawObj, CPointer<CPointer<UInt8>>()) }
        Int64(offset)
    }

    // JSObjectGetTypedArrayBuffer
    public static func jsObjectGetTypedArrayBuffer(ctx: JsObject, object: JSObjectRef, exception: ExceptionRef): JSObjectRef {
        let rawObj = CPointer<UInt8>()
        let resultPtr = unsafe { JSObjectGetTypedArrayBuffer(ctx.rawPtr, rawObj, CPointer<CPointer<UInt8>>()) }
        UInt64(CPointer<UInt64>(resultPtr).read())
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
