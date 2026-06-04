// 严格翻译自: JavaScriptCore C API (JavaScriptCore.h / JSBase.h / JSObjectRef.h / JSStringRef.h)
// 集中管理所有 JSC C API 的 FFI 声明
//
// 使用 CPointer<UInt8> 表示不透明指针 (void*)，
// 遵循项目现有的 FFI 惯例（与 jni_ffi.cj 保持一致）。
// 所有 foreign 函数需要在 unsafe 块中调用。
// @C 修饰符确保使用 C ABI 调用约定。

package bao_jsc

// ============================================================================
// JSStringRef 操作
// ============================================================================

/// 创建 JSStringRef from a UTF-8 C string
/// C API: JSStringCreateWithUTF8CString(const char* string) -> JSStringRef
@C
foreign func JSStringCreateWithUTF8CString(
    string: CString
): CPointer<UInt8>

/// 释放 JSStringRef
/// C API: JSStringRelease(JSStringRef string)
@C
foreign func JSStringRelease(
    string: CPointer<UInt8>
): Unit

/// 获取 JSStringRef 的 UTF-8 编码最大缓冲区大小
/// C API: JSStringGetMaximumUTF8CStringSize(JSStringRef string) -> size_t
@C
foreign func JSStringGetMaximumUTF8CStringSize(
    string: CPointer<UInt8>
): UInt64

/// 将 JSStringRef 复制到 UTF-8 C 字符串缓冲区
/// C API: JSStringGetUTF8CString(JSStringRef string, char* buffer, size_t bufferSize) -> size_t
/// 返回实际写入的字节数（不含 null 终止符）
@C
foreign func JSStringGetUTF8CString(
    string: CPointer<UInt8>,
    buffer: CPointer<UInt8>,
    bufferSize: UInt64
): UInt64

/// 比较 JSStringRef 与 UTF-8 C 字符串是否相等
/// C API: JSStringIsEqualToUTF8CString(JSStringRef a, const char* b) -> bool
@C
foreign func JSStringIsEqualToUTF8CString(
    a: CPointer<UInt8>,
    b: CString
): Bool

/// 获取 JSStringRef 的字符长度
/// C API: JSStringGetLength(JSStringRef string) -> size_t
@C
foreign func JSStringGetLength(
    string: CPointer<UInt8>
): UInt64

// ============================================================================
// Context 操作
// ============================================================================

/// 获取全局上下文中的全局对象
/// C API: JSContextGetGlobalObject(JSContextRef ctx) -> JSObjectRef
@C
foreign func JSContextGetGlobalObject(
    ctx: CPointer<UInt8>
): CPointer<UInt8>

/// 创建全局上下文
/// C API: JSGlobalContextCreate(JSClassRef globalObjectClass) -> JSGlobalContextRef
@C
foreign func JSGlobalContextCreate(
    globalObjectClass: CPointer<UInt8>
): CPointer<UInt8>

/// 释放全局上下文
/// C API: JSGlobalContextRelease(JSGlobalContextRef ctx)
@C
foreign func JSGlobalContextRelease(
    ctx: CPointer<UInt8>
): Unit

// ============================================================================
// Script 执行
// ============================================================================

/// 执行 JavaScript 脚本
/// C API: JSEvaluateScript(JSContextRef ctx, JSStringRef script,
///           JSObjectRef thisObject, JSStringRef sourceURL,
///           int startingLineNumber, JSValueRef* exception) -> JSValueRef
@C
foreign func JSEvaluateScript(
    ctx: CPointer<UInt8>,
    script: CPointer<UInt8>,
    thisObject: CPointer<UInt8>,
    sourceURL: CPointer<UInt8>,
    startingLineNumber: Int32,
    exception: CPointer<CPointer<UInt8>>
): CPointer<UInt8>

/// 检查脚本语法
/// C API: JSCheckScriptSyntax(JSContextRef ctx, JSStringRef script,
///           JSStringRef sourceURL, int startingLineNumber,
///           JSValueRef* exception) -> bool
@C
foreign func JSCheckScriptSyntax(
    ctx: CPointer<UInt8>,
    script: CPointer<UInt8>,
    sourceURL: CPointer<UInt8>,
    startingLineNumber: Int32,
    exception: CPointer<CPointer<UInt8>>
): Bool

// ============================================================================
// JSValue 创建
// ============================================================================

/// 创建 undefined 值
/// C API: JSValueMakeUndefined(JSContextRef ctx) -> JSValueRef
@C
foreign func JSValueMakeUndefined(
    ctx: CPointer<UInt8>
): CPointer<UInt8>

/// 创建 null 值
/// C API: JSValueMakeNull(JSContextRef ctx) -> JSValueRef
@C
foreign func JSValueMakeNull(
    ctx: CPointer<UInt8>
): CPointer<UInt8>

/// 创建 boolean 值
/// C API: JSValueMakeBoolean(JSContextRef ctx, bool value) -> JSValueRef
@C
foreign func JSValueMakeBoolean(
    ctx: CPointer<UInt8>,
    value: Bool
): CPointer<UInt8>

/// 创建 number 值
/// C API: JSValueMakeNumber(JSContextRef ctx, double value) -> JSValueRef
@C
foreign func JSValueMakeNumber(
    ctx: CPointer<UInt8>,
    value: Float64
): CPointer<UInt8>

/// 创建 string 值
/// C API: JSValueMakeString(JSContextRef ctx, JSStringRef string) -> JSValueRef
@C
foreign func JSValueMakeString(
    ctx: CPointer<UInt8>,
    str: CPointer<UInt8>
): CPointer<UInt8>

// ============================================================================
// JSValue 类型检查
// ============================================================================

/// C API: JSValueGetType(JSContextRef ctx, JSValueRef value) -> JSType
@C
foreign func JSValueGetType(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>
): Int32

/// C API: JSValueIsUndefined(JSContextRef ctx, JSValueRef value) -> bool
@C
foreign func JSValueIsUndefined(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>
): Bool

/// C API: JSValueIsNull(JSContextRef ctx, JSValueRef value) -> bool
@C
foreign func JSValueIsNull(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>
): Bool

/// C API: JSValueIsBoolean(JSContextRef ctx, JSValueRef value) -> bool
@C
foreign func JSValueIsBoolean(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>
): Bool

/// C API: JSValueIsNumber(JSContextRef ctx, JSValueRef value) -> bool
@C
foreign func JSValueIsNumber(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>
): Bool

/// C API: JSValueIsString(JSContextRef ctx, JSValueRef value) -> bool
@C
foreign func JSValueIsString(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>
): Bool

/// C API: JSValueIsObject(JSContextRef ctx, JSValueRef value) -> bool
@C
foreign func JSValueIsObject(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>
): Bool

/// C API: JSValueIsSymbol(JSContextRef ctx, JSValueRef value) -> bool
@C
foreign func JSValueIsSymbol(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>
): Bool

// ============================================================================
// JSValue 转换
// ============================================================================

/// C API: JSValueToBoolean(JSContextRef ctx, JSValueRef value) -> bool
@C
foreign func JSValueToBoolean(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>
): Bool

/// C API: JSValueToNumber(JSContextRef ctx, JSValueRef value, JSValueRef* exception) -> double
@C
foreign func JSValueToNumber(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): Float64

/// C API: JSValueToStringCopy(JSContextRef ctx, JSValueRef value, JSValueRef* exception) -> JSStringRef
/// 返回的 JSStringRef 需要调用者用 JSStringRelease 释放
@C
foreign func JSValueToStringCopy(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): CPointer<UInt8>

/// C API: JSValueToObject(JSContextRef ctx, JSValueRef value, JSValueRef* exception) -> JSObjectRef
@C
foreign func JSValueToObject(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): CPointer<UInt8>

// ============================================================================
// JSValue 比较
// ============================================================================

/// C API: JSValueIsEqual(JSContextRef ctx, JSValueRef a, JSValueRef b, JSValueRef* exception) -> bool
@C
foreign func JSValueIsEqual(
    ctx: CPointer<UInt8>,
    a: CPointer<UInt8>,
    b: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): Bool

/// C API: JSValueIsStrictEqual(JSContextRef ctx, JSValueRef a, JSValueRef b) -> bool
@C
foreign func JSValueIsStrictEqual(
    ctx: CPointer<UInt8>,
    a: CPointer<UInt8>,
    b: CPointer<UInt8>
): Bool

/// C API: JSValueIsInstanceOfConstructor(JSContextRef ctx, JSValueRef value,
///           JSObjectRef constructor, JSValueRef* exception) -> bool
@C
foreign func JSValueIsInstanceOfConstructor(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>,
    constructor: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): Bool

// ============================================================================
// JSValue 保护 / 取消保护 (GC)
// ============================================================================

/// 保护 JSValue 不被垃圾回收
/// C API: JSValueProtect(JSContextRef ctx, JSValueRef value)
@C
foreign func JSValueProtect(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>
): Unit

/// 取消保护 JSValue（与 JSValueProtect 配对使用）
/// C API: JSValueUnprotect(JSContextRef ctx, JSValueRef value)
@C
foreign func JSValueUnprotect(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>
): Unit

// ============================================================================
// JSObject 函数调用
// ============================================================================

/// 调用 JS 函数（带 this 绑定）
/// C API: JSObjectCallAsFunction(JSContextRef ctx, JSObjectRef object,
///           JSObjectRef thisObject, size_t argumentCount,
///           const JSValueRef arguments[], JSValueRef* exception) -> JSValueRef
@C
foreign func JSObjectCallAsFunction(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>,
    thisObject: CPointer<UInt8>,
    argumentCount: UInt64,
    arguments: CPointer<CPointer<UInt8>>,
    exception: CPointer<CPointer<UInt8>>
): CPointer<UInt8>

/// 调用 JS 构造函数
/// C API: JSObjectCallAsConstructor(JSContextRef ctx, JSObjectRef object,
///           size_t argumentCount, const JSValueRef arguments[],
///           JSValueRef* exception) -> JSObjectRef
@C
foreign func JSObjectCallAsConstructor(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>,
    argumentCount: UInt64,
    arguments: CPointer<CPointer<UInt8>>,
    exception: CPointer<CPointer<UInt8>>
): CPointer<UInt8>

// ============================================================================
// JSObject 类型检查
// ============================================================================

/// 检查对象是否为函数
/// C API: JSObjectIsFunction(JSContextRef ctx, JSObjectRef object) -> bool
@C
foreign func JSObjectIsFunction(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>
): Bool

/// 检查对象是否为构造函数
/// C API: JSObjectIsConstructor(JSContextRef ctx, JSObjectRef object) -> bool
@C
foreign func JSObjectIsConstructor(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>
): Bool

// ============================================================================
// JSObject 创建
// ============================================================================

/// 创建 Error 对象
/// C API: JSObjectMakeError(JSContextRef ctx, size_t argumentCount,
///           const JSValueRef arguments[], JSValueRef* exception) -> JSObjectRef
@C
foreign func JSObjectMakeError(
    ctx: CPointer<UInt8>,
    argumentCount: UInt64,
    arguments: CPointer<CPointer<UInt8>>,
    exception: CPointer<CPointer<UInt8>>
): CPointer<UInt8>

/// 创建普通对象
/// C API: JSObjectMake(JSContextRef ctx, JSClassRef jsClass, void* data) -> JSObjectRef
@C
foreign func JSObjectMake(
    ctx: CPointer<UInt8>,
    jsClass: CPointer<UInt8>,
    data: CPointer<UInt8>
): CPointer<UInt8>

/// 创建数组
/// C API: JSObjectMakeArray(JSContextRef ctx, size_t argumentCount,
///           const JSValueRef arguments[], JSValueRef* exception) -> JSObjectRef
@C
foreign func JSObjectMakeArray(
    ctx: CPointer<UInt8>,
    argumentCount: UInt64,
    arguments: CPointer<CPointer<UInt8>>,
    exception: CPointer<CPointer<UInt8>>
): CPointer<UInt8>

/// 创建带回调的函数对象 — 用于注册原生函数
/// C API: JSObjectMakeFunctionWithCallback(JSContextRef ctx, JSStringRef name,
///           JSObjectCallAsFunctionCallback callAsFunction) -> JSObjectRef
@C
foreign func JSObjectMakeFunctionWithCallback(
    ctx: CPointer<UInt8>,
    name: CPointer<UInt8>,
    callAsFunction: CPointer<Unit>
): CPointer<UInt8>

// ============================================================================
// JSObject 属性操作
// ============================================================================

/// C API: JSObjectGetProperty(JSContextRef ctx, JSObjectRef object,
///           JSStringRef propertyName, JSValueRef* exception) -> JSValueRef
@C
foreign func JSObjectGetProperty(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>,
    propertyName: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): CPointer<UInt8>

/// C API: JSObjectSetProperty(JSContextRef ctx, JSObjectRef object,
///           JSStringRef propertyName, JSValueRef value,
///           JSPropertyAttributes attributes, JSValueRef* exception)
@C
foreign func JSObjectSetProperty(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>,
    propertyName: CPointer<UInt8>,
    value: CPointer<UInt8>,
    attributes: UInt32,
    exception: CPointer<CPointer<UInt8>>
): Unit

/// C API: JSObjectDeleteProperty(JSContextRef ctx, JSObjectRef object,
///           JSStringRef propertyName, JSValueRef* exception) -> bool
@C
foreign func JSObjectDeleteProperty(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>,
    propertyName: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): Bool

/// C API: JSObjectHasProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName) -> bool
@C
foreign func JSObjectHasProperty(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>,
    propertyName: CPointer<UInt8>
): Bool

/// C API: JSObjectGetPrototype(JSContextRef ctx, JSObjectRef object) -> JSValueRef
@C
foreign func JSObjectGetPrototype(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>
): CPointer<UInt8>

/// C API: JSObjectSetPrototype(JSContextRef ctx, JSObjectRef object, JSValueRef value)
@C
foreign func JSObjectSetPrototype(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>,
    value: CPointer<UInt8>
): Unit

/// C API: JSObjectCopyPropertyNames(JSContextRef ctx, JSObjectRef object) -> JSPropertyNameArrayRef
@C
foreign func JSObjectCopyPropertyNames(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>
): CPointer<UInt8>

// ============================================================================
// TypedArray 操作
// ============================================================================

/// 创建 TypedArray（不带字节拷贝，直接使用给定的内存）
/// C API: JSObjectMakeTypedArrayWithBytesNoCopy(JSContextRef ctx,
///           JSTypedArrayType arrayType, void* bytes, size_t byteLength,
///           JSTypedArrayBytesDeallocator deallocator, void* deallocatorContext,
///           JSValueRef* exception) -> JSObjectRef
@C
foreign func JSObjectMakeTypedArrayWithBytesNoCopy(
    ctx: CPointer<UInt8>,
    arrayType: Int32,
    bytes: CPointer<UInt8>,
    byteLength: UInt64,
    destructor: CPointer<UInt8>,
    destructorContext: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): CPointer<UInt8>

/// 创建 TypedArray（分配新内存）
/// C API: JSObjectMakeTypedArray(JSContextRef ctx, JSTypedArrayType arrayType,
///           size_t length, JSValueRef* exception) -> JSObjectRef
@C
foreign func JSObjectMakeTypedArray(
    ctx: CPointer<UInt8>,
    arrayType: Int32,
    length: UInt64,
    exception: CPointer<CPointer<UInt8>>
): CPointer<UInt8>

/// 获取 TypedArray 的字节长度
/// C API: JSObjectGetTypedArrayByteLength(JSContextRef ctx, JSObjectRef object,
///           JSValueRef* exception) -> size_t
@C
foreign func JSObjectGetTypedArrayByteLength(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): UInt64

/// 获取 TypedArray 的长度
/// C API: JSObjectGetTypedArrayLength(JSContextRef ctx, JSObjectRef object,
///           JSValueRef* exception) -> size_t
@C
foreign func JSObjectGetTypedArrayLength(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): UInt64

/// 获取 TypedArray 的字节偏移
/// C API: JSObjectGetTypedArrayByteOffset(JSContextRef ctx, JSObjectRef object,
///           JSValueRef* exception) -> size_t
@C
foreign func JSObjectGetTypedArrayByteOffset(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): UInt64

/// 获取 TypedArray 底层的 ArrayBuffer
/// C API: JSObjectGetTypedArrayBuffer(JSContextRef ctx, JSObjectRef object,
///           JSValueRef* exception) -> JSObjectRef
@C
foreign func JSObjectGetTypedArrayBuffer(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): CPointer<UInt8>

/// 获取 ArrayBuffer 的字节指针
/// C API: JSObjectGetArrayBufferBytesPtr(JSContextRef ctx, JSObjectRef object,
///           JSValueRef* exception) -> void*
@C
foreign func JSObjectGetArrayBufferBytesPtr(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): CPointer<UInt8>

/// 获取 ArrayBuffer 的字节长度
/// C API: JSObjectGetArrayBufferByteLength(JSContextRef ctx, JSObjectRef object,
///           JSValueRef* exception) -> size_t
@C
foreign func JSObjectGetArrayBufferByteLength(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): UInt64

// ============================================================================
// GC
// ============================================================================

/// 触发垃圾回收
/// C API: JSGarbageCollect(JSContextRef ctx)
@C
foreign func JSGarbageCollect(
    ctx: CPointer<UInt8>
): Unit

// ============================================================================
// Auto-generated FFI declarations (translated from Bun)
// ============================================================================

// ============================================================================
// Auto-generated FFI declarations for Bao JSC
// Translated from Bun's Zig extern fn declarations
// ============================================================================


// ============================================================================
// JSC_C_API (192 functions)
// ============================================================================

@C
foreign func JSArray__constructArray(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: UIntNative
): CPointer<Unit>

@C
foreign func JSArray__constructEmptyArray(
    arg0: CPointer<Unit>, arg1: UIntNative
): CPointer<Unit>

@C
foreign func JSC__AnyPromise__wrap(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>, arg3: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__ArrayBuffer__asBunArrayBuffer(
    out: CPointer<Unit>
): Unit

@C
foreign func JSC__ArrayBuffer__deref(): Unit

@C
foreign func JSC__ArrayBuffer__ref(): Unit

@C
foreign func JSC__createError(
    arg0: CPointer<Unit>, str: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__createRangeError(
    arg0: CPointer<Unit>, str: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__createStructure(
    global: CPointer<Unit>, owner: CPointer<Unit>, length: UInt32, names: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__createTypeError(
    arg0: CPointer<Unit>, str: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__Exception__asJSValue(): CPointer<Unit>

@C
foreign func JSC__Exception__getStackTrace(
    global: CPointer<Unit>, stack: CPointer<Unit>
): Unit

@C
foreign func JSC__GetterSetter__isGetterNull(): Bool

@C
foreign func JSC__GetterSetter__isSetterNull(): Bool

@C
foreign func JSC__JSBigInt__fromJS(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSBigInt__orderDouble(
    arg0: CPointer<Unit>, arg1: Float64
): Int8

@C
foreign func JSC__JSBigInt__orderInt64(
    arg0: CPointer<Unit>, arg1: Int64
): Int8

@C
foreign func JSC__JSBigInt__orderUint64(
    arg0: CPointer<Unit>, arg1: UInt64
): Int8

@C
foreign func JSC__JSBigInt__toInt64(
    arg0: CPointer<Unit>
): Int64

@C
foreign func JSC__JSBigInt__toString(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSCell__getObject(): CPointer<Unit>

@C
foreign func JSC__JSCell__getType(): UInt8

@C
foreign func JSC__JSCell__toObject(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSFunction__getSourceCode(
    value: CPointer<Unit>, out: CPointer<Unit>
): Bool

@C
foreign func JSC__JSFunction__optimizeSoon(
    value: CPointer<Unit>
): Unit

@C
foreign func JSC__JSGlobalObject__bunVM(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSGlobalObject__createAggregateError(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: UIntNative, arg3: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSGlobalObject__createAggregateErrorWithArray(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>, arg3: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSGlobalObject__deleteModuleRegistryEntry(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): Unit

@C
foreign func JSC__JSGlobalObject__drainMicrotasks(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSGlobalObject__generateHeapSnapshot(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSGlobalObject__handleRejectedPromises(
    arg0: CPointer<Unit>
): Unit

@C
foreign func JSC__JSGlobalObject__queueMicrotaskCallback(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, Function: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSGlobalObject__queueMicrotaskJob(
    JSC__JSGlobalObject__ptr: CPointer<Unit>, arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>
): Unit

@C
foreign func JSC__JSGlobalObject__vm(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSModuleLoader__loadAndEvaluateModule(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSObject__create(
    global_object: CPointer<Unit>, length: UIntNative, ctx: CPointer<Unit>, initializer: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSObject__getIndex(
    globalThis: CPointer<Unit>, i: UInt32
): CPointer<Unit>

@C
foreign func JSC__JSPromise__create(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSPromise__rejectedPromise(
    arg0: CPointer<Unit>, JSValue1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSPromise__rejectedPromiseValue(
    arg0: CPointer<Unit>, JSValue1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSPromise__resolvedPromise(
    arg0: CPointer<Unit>, JSValue1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSPromise__resolvedPromiseValue(
    arg0: CPointer<Unit>, JSValue1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSPromise__wrap(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSString__eql(
    global: CPointer<Unit>, other: CPointer<Unit>
): Bool

@C
foreign func JSC__JSString__is8Bit(): Bool

@C
foreign func JSC__JSString__iterator(
    globalObject: CPointer<Unit>, iter: CPointer<Unit>
): Unit

@C
foreign func JSC__JSString__length(): UIntNative

@C
foreign func JSC__JSString__toObject(
    global: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSString__toZigString(
    global: CPointer<Unit>, zig_str: CPointer<Unit>
): Unit

@C
foreign func JSC__jsTypeStringForValue(
    globalObject: CPointer<Unit>, value: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__asArrayBuffer(
    global: CPointer<Unit>, out: CPointer<Unit>
): Bool

@C
foreign func JSC__JSValue__asBigIntCompare(
    global: CPointer<Unit>, other: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__asInternalPromise(
    JSValue0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__asPromise(
    JSValue0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__asString(): CPointer<Unit>

@C
foreign func JSC__JSValue__bigIntSum(
    globalObject: CPointer<Unit>, a: CPointer<Unit>, b: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__createEmptyArray(
    global: CPointer<Unit>, len: UIntNative
): CPointer<Unit>

@C
foreign func JSC__JSValue__createEmptyObject(
    global: CPointer<Unit>, len: UIntNative
): CPointer<Unit>

@C
foreign func JSC__JSValue__createEmptyObjectWithNullPrototype(
    globalObject: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__createInternalPromise(
    globalObject: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__createObject2(
    global: CPointer<Unit>, key1: CPointer<Unit>, key2: CPointer<Unit>, value1: CPointer<Unit>, value2: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__createRangeError(
    message: CPointer<Unit>, code: CPointer<Unit>, global: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__createRopeString(
    rhs: CPointer<Unit>, globalThis: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__createTypeError(
    message: CPointer<Unit>, code: CPointer<Unit>, global: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__createUninitializedUint8Array(
    globalObject: CPointer<Unit>, len: UIntNative
): CPointer<Unit>

@C
foreign func JSC__JSValue__dateInstanceFromNullTerminatedString(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__dateInstanceFromNumber(
    arg0: CPointer<Unit>, arg1: Float64
): CPointer<Unit>

@C
foreign func JSC__JSValue__DateNowISOString(
    arg0: CPointer<Unit>, arg1: Float64
): CPointer<Unit>

@C
foreign func JSC__JSValue__deepEquals(
    other: CPointer<Unit>, global: CPointer<Unit>
): Bool

@C
foreign func JSC__JSValue__deleteProperty(
    target: CPointer<Unit>, global: CPointer<Unit>, key: CPointer<Unit>
): Bool

@C
foreign func JSC__JSValue__eqlCell(
    other: CPointer<Unit>
): Bool

@C
foreign func JSC__JSValue__eqlValue(
    other: CPointer<Unit>
): Bool

@C
foreign func JSC__JSValue__fastGetDirect_(
    global: CPointer<Unit>, builtin_name: UInt8
): CPointer<Unit>

@C
foreign func JSC__JSValue__fastGetOwn(
    value: CPointer<Unit>, globalObject: CPointer<Unit>, property: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__fastGet(
    value: CPointer<Unit>, global: CPointer<Unit>, builtin_id: UInt8
): CPointer<Unit>

@C
foreign func JSC__JSValue__forEachPropertyNonIndexed(
    JSValue0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>, ArgFn3: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__forEach(
    globalObject: CPointer<Unit>, ctx: CPointer<Unit>, callback: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__fromEntries(
    globalThis: CPointer<Unit>, keys_array: CPointer<Unit>, values_array: CPointer<Unit>, strings_count: UIntNative, clone: Bool
): CPointer<Unit>

@C
foreign func JSC__JSValue__fromInt64NoTruncate(
    globalObject: CPointer<Unit>, i: Int64
): CPointer<Unit>

@C
foreign func JSC__JSValue__fromTimevalNoTruncate(
    globalObject: CPointer<Unit>, nsec: Int64, sec: Int64
): CPointer<Unit>

@C
foreign func JSC__JSValue__fromUInt64NoTruncate(
    globalObject: CPointer<Unit>, i: UInt64
): CPointer<Unit>

@C
foreign func JSC__JSValue__getClassInfoName(
    value: CPointer<Unit>, out: CPointer<Unit>, len: CPointer<Unit>
): Bool

@C
foreign func JSC__JSValue__getClassName(
    global: CPointer<Unit>, ret: CPointer<Unit>
): Unit

@C
foreign func JSC__JSValue__getDirectIndex(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: UInt32
): CPointer<Unit>

@C
foreign func JSC__JSValue__getErrorsProperty(
    globalObject: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__getIfPropertyExistsFromPath(
    global: CPointer<Unit>, path: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__getIfPropertyExistsImpl(
    target: CPointer<Unit>, global: CPointer<Unit>, ptr: CPointer<Unit>, len: UInt32
): CPointer<Unit>

@C
foreign func JSC__JSValue__getLengthIfPropertyExistsInternal(
    globalThis: CPointer<Unit>
): Float64

@C
foreign func JSC__JSValue__getName(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>
): Unit

@C
foreign func JSC__JSValue__getNameProperty(
    global: CPointer<Unit>, ret: CPointer<Unit>
): Unit

@C
foreign func JSC__JSValue__getOwnByValue(
    value: CPointer<Unit>, globalObject: CPointer<Unit>, propertyValue: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__getOwn(
    value: CPointer<Unit>, globalObject: CPointer<Unit>, propertyName: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__getPropertyValue(
    target: CPointer<Unit>, global: CPointer<Unit>, ptr: CPointer<Unit>, len: UInt32
): CPointer<Unit>

@C
foreign func JSC__JSValue__getPrototype(
    globalObject: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__getSymbolDescription(
    global: CPointer<Unit>, str: CPointer<Unit>
): Unit

@C
foreign func JSC__JSValue__getUnixTimestamp(): Float64

@C
foreign func JSC__JSValue__getUTCTimestamp(
    globalObject: CPointer<Unit>
): Float64

@C
foreign func JSC__JSValue__isAggregateError(
    globalObject: CPointer<Unit>
): Bool

@C
foreign func JSC__JSValue__isAnyError(): Bool

@C
foreign func JSC__JSValue__isClass(
    global: CPointer<Unit>
): Bool

@C
foreign func JSC__JSValue__isException(
    vm: CPointer<Unit>
): Bool

@C
foreign func JSC__JSValue__isInstanceOf(
    global: CPointer<Unit>, constructor: CPointer<Unit>
): Bool

@C
foreign func JSC__JSValue__isIterable(
    globalObject: CPointer<Unit>
): Bool

@C
foreign func JSC__JSValue__isJSXElement(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): Bool

@C
foreign func JSC__JSValue__isSameValue(
    other: CPointer<Unit>, global: CPointer<Unit>
): Bool

@C
foreign func JSC__JSValue__isStrictEqual(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>
): Bool

@C
foreign func JSC__JSValue__isTerminationException(): Bool

@C
foreign func JSC__JSValue__jestDeepEquals(
    other: CPointer<Unit>, global: CPointer<Unit>
): Bool

@C
foreign func JSC__JSValue__jestDeepMatch(
    subset: CPointer<Unit>, global: CPointer<Unit>, replace_props_with_asymmetric_matchers: Bool
): Bool

@C
foreign func JSC__JSValue__jestStrictDeepEquals(
    other: CPointer<Unit>, global: CPointer<Unit>
): Bool

@C
foreign func JSC__JSValue__jsonStringifyFast(
    globalThis: CPointer<Unit>, out: CPointer<Unit>
): Unit

@C
foreign func JSC__JSValue__jsonStringify(
    globalThis: CPointer<Unit>, indent: UInt32, out: CPointer<Unit>
): Unit

@C
foreign func JSC__JSValue__jsType(): CPointer<Unit>

@C
foreign func JSC__JSValue__keys(
    globalThis: CPointer<Unit>, value: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__push(
    value: CPointer<Unit>, globalObject: CPointer<Unit>, out: CPointer<Unit>
): Unit

@C
foreign func JSC__JSValue__putIndex(
    value: CPointer<Unit>, globalObject: CPointer<Unit>, i: UInt32, out: CPointer<Unit>
): Unit

@C
foreign func JSC__JSValue__putRecord(
    value: CPointer<Unit>, global: CPointer<Unit>, key: CPointer<Unit>, values_array: CPointer<Unit>, values_len: UIntNative
): Unit

@C
foreign func JSC__JSValue__putToPropertyKey(
    target: CPointer<Unit>, globalObject: CPointer<Unit>, key: CPointer<Unit>, value: CPointer<Unit>
): Unit

@C
foreign func JSC__JSValue__put(
    value: CPointer<Unit>, global: CPointer<Unit>, key: CPointer<Unit>, result: CPointer<Unit>
): Unit

@C
foreign func JSC__JSValue__strictDeepEquals(
    other: CPointer<Unit>, global: CPointer<Unit>
): Bool

@C
foreign func JSC__JSValue__stringIncludes(
    globalObject: CPointer<Unit>, other: CPointer<Unit>
): Bool

@C
foreign func JSC__JSValue__symbolFor(
    global: CPointer<Unit>, str: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__symbolKeyFor(
    global: CPointer<Unit>, str: CPointer<Unit>
): Bool

@C
foreign func JSC__JSValue___then(
    global: CPointer<Unit>, ctx: CPointer<Unit>, resolve: CPointer<Unit>, reject: CPointer<Unit>
): Unit

@C
foreign func JSC__JSValue__toBoolean(): Bool

@C
foreign func JSC__JSValue__toError_(): CPointer<Unit>

@C
foreign func JSC__JSValue__toInt32(): Int32

@C
foreign func JSC__JSValue__toISOString(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>
): Int32

@C
foreign func JSC__JSValue__toObject(
    globalThis: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__toUInt64NoTruncate(): UInt64

@C
foreign func JSC__JSValue__toZigString(
    out: CPointer<Unit>, global: CPointer<Unit>
): Unit

@C
foreign func JSC__JSValue__unwrapBoxedPrimitive(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__values(
    globalThis: CPointer<Unit>, value: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSCommonJSExtensions__appendFunction(
    global: CPointer<Unit>, value: CPointer<Unit>
): UInt32

@C
foreign func JSCommonJSExtensions__setFunction(
    global: CPointer<Unit>, index: UInt32, value: CPointer<Unit>
): Unit

@C
foreign func JSCommonJSExtensions__swapRemove(
    global: CPointer<Unit>, index: UInt32
): UInt32

@C
foreign func JSC__VM__blockBytesAllocated(
    vm: CPointer<Unit>
): UIntNative

@C
foreign func JSC__VM__clearExecutionTimeLimit(
    vm: CPointer<Unit>
): Unit

@C
foreign func JSC__VM__clearHasTerminationRequest(
    vm: CPointer<Unit>
): Unit

@C
foreign func JSC__VM__collectAsync(
    vm: CPointer<Unit>
): Unit

@C
foreign func JSC__VM__create(
    heap_type: UInt8
): CPointer<Unit>

@C
foreign func JSC__VM__deferGC(
    ctx: CPointer<Unit>, callback: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__VM__deinit(
    vm: CPointer<Unit>, global_object: CPointer<Unit>
): Unit

@C
foreign func JSC__VM__deleteAllCode(
    vm: CPointer<Unit>, global_object: CPointer<Unit>
): Unit

@C
foreign func JSC__VM__drainMicrotasks(
    vm: CPointer<Unit>
): Unit

@C
foreign func JSC__VM__executionForbidden(
    vm: CPointer<Unit>
): Bool

@C
foreign func JSC__VM__externalMemorySize(
    vm: CPointer<Unit>
): UIntNative

@C
foreign func JSC__VM__getAPILock(
    vm: CPointer<Unit>
): Unit

@C
foreign func JSC__VM__hasExecutionTimeLimit(
    vm: CPointer<Unit>
): Bool

@C
foreign func JSC__VM__hasTerminationRequest(
    vm: CPointer<Unit>
): Bool

@C
foreign func JSC__VM__heapSize(
    vm: CPointer<Unit>
): UIntNative

@C
foreign func JSC__VM__holdAPILock(
    ctx: CPointer<Unit>, callback: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__VM__isEntered(
    vm: CPointer<Unit>
): Bool

@C
foreign func JSC__VM__notifyNeedDebuggerBreak(
    vm: CPointer<Unit>
): Unit

@C
foreign func JSC__VM__notifyNeedShellTimeoutCheck(
    vm: CPointer<Unit>
): Unit

@C
foreign func JSC__VM__notifyNeedTermination(
    vm: CPointer<Unit>
): Unit

@C
foreign func JSC__VM__notifyNeedWatchdogCheck(
    vm: CPointer<Unit>
): Unit

@C
foreign func JSC__VM__performOpportunisticallyScheduledTasks(
    vm: CPointer<Unit>, until: Float64
): Unit

@C
foreign func JSC__VM__releaseAPILock(
    vm: CPointer<Unit>
): Unit

@C
foreign func JSC__VM__releaseWeakRefs(
    vm: CPointer<Unit>
): Unit

@C
foreign func JSC__VM__reportExtraMemory(
    arg0: CPointer<Unit>, arg1: UIntNative
): Unit

@C
foreign func JSC__VM__runGC(
    vm: CPointer<Unit>, sync: Bool
): UIntNative

@C
foreign func JSC__VM__setControlFlowProfiler(
    vm: CPointer<Unit>, enabled: Bool
): Unit

@C
foreign func JSC__VM__setExecutionForbidden(
    vm: CPointer<Unit>, forbidden: Bool
): Unit

@C
foreign func JSC__VM__setExecutionTimeLimit(
    vm: CPointer<Unit>, timeout: Float64
): Unit

@C
foreign func JSC__VM__shrinkFootprint(
    vm: CPointer<Unit>
): Unit

@C
foreign func JSC__VM__throwError(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>
): Unit

@C
foreign func JSC__Wasm__StreamingCompiler__addBytes(
    streaming_compiler: CPointer<Unit>, bytes_ptr: CPointer<Unit>, bytes_len: UIntNative
): Unit

@C
foreign func JSFunctionCall(
    globalObject: CPointer<Unit>, callFrame: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSGlobalObject__clearExceptionExceptTermination(
    arg0: CPointer<Unit>
): Bool

@C
foreign func JSGlobalObject__clearException(
    arg0: CPointer<Unit>
): Unit

@C
foreign func JSGlobalObject__clearTerminationException(): Unit

@C
foreign func JSGlobalObject__createOutOfMemoryError(): CPointer<Unit>

@C
foreign func JSGlobalObject__hasException(
    arg0: CPointer<Unit>
): Bool

@C
foreign func JSGlobalObject__requestTermination(): Unit

@C
foreign func JSGlobalObject__setTimeZone(
    timeZone: CPointer<Unit>
): Bool

@C
foreign func JSGlobalObject__throwOutOfMemoryError(): Unit

@C
foreign func JSGlobalObject__throwStackOverflow(): Unit

@C
foreign func JSGlobalObject__tryTakeException(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSModuleLoader__import(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSObjectGetTypedArrayBytesPtr(
    ctx: CPointer<Unit>, object: CPointer<Unit>, exception: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSObjectMakeTypedArrayWithArrayBufferAndOffset(
    ctx: CPointer<Unit>, arrayType: CPointer<Unit>, buffer: CPointer<Unit>, byteOffset: UIntNative, length: UIntNative, exception: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSObjectMakeTypedArrayWithArrayBuffer(
    ctx: CPointer<Unit>, arrayType: CPointer<Unit>, buffer: CPointer<Unit>, exception: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSRemoteInspectorDisableAutoStart(): Unit

@C
foreign func JSRemoteInspectorGetInspectionEnabledByDefault(): Bool

@C
foreign func JSRemoteInspectorSetInspectionEnabledByDefault(
    enabled: Bool
): Unit

@C
foreign func JSRemoteInspectorSetLogToSystemConsole(
    enabled: Bool
): Unit

@C
foreign func JSRemoteInspectorStart(): Unit

@C
foreign func JSUint8Array__fromDefaultAllocator(
    arg0: CPointer<Unit>, ptr: CPointer<Unit>, len: UIntNative
): CPointer<Unit>

@C
foreign func JSVALUE_TO_INT64_SLOW(
    value: CPointer<Unit>
): Int64

@C
foreign func JSVALUE_TO_UINT64_SLOW(
    value: CPointer<Unit>
): UInt64


// ============================================================================
// Bun_Ext (62 functions)
// ============================================================================

@C
foreign func Bun__attachAsyncStackFromPromise(
    global: CPointer<Unit>, err: CPointer<Unit>, promise: CPointer<Unit>
): Unit

@C
foreign func Bun__CallFrame__describeFrame(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Bun__CallFrame__getCallerSrcLoc(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>, arg3: CPointer<Unit>, arg4: CPointer<Unit>
): Unit

@C
foreign func Bun__CallFrame__isFromBunMain(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): Bool

@C
foreign func Bun__closeAllSQLiteDatabasesForTermination(): Unit

@C
foreign func Bun__createTextCodec(
    encodingName: CPointer<Unit>, encodingNameLen: UIntNative
): CPointer<Unit>

@C
foreign func Bun__createUint8ArrayForCopy(
    arg0: CPointer<Unit>, ptr: CPointer<Unit>, len: UIntNative, buffer: Bool
): CPointer<Unit>

@C
foreign func Bun__decodeWithTextCodec(
    codec: CPointer<Unit>, data: CPointer<Unit>, length: UIntNative, flush: Bool, stopOnError: Bool, outSawError: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Bun__deleteTextCodec(
    codec: CPointer<Unit>
): Unit

@C
foreign func Bun__emitHandledPromiseEvent(
    arg0: CPointer<Unit>, promise: CPointer<Unit>
): Bool

@C
foreign func Bun__EventLoopTaskNoContext__createdInBunVm(
    task: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Bun__EventLoopTaskNoContext__performTask(
    task: CPointer<Unit>
): Unit

@C
foreign func Bun__FFIFunction_getDataPtr(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Bun__FFIFunction_setDataPtr(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): Unit

@C
foreign func Bun__generateHeapProfile(
    vm: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Bun__generateHeapSnapshotV8(
    vm: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Bun__getCanonicalEncodingName(
    encodingName: CPointer<Unit>, encodingNameLen: UIntNative, outLen: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Bun__handleUncaughtException(
    arg0: CPointer<Unit>, err: CPointer<Unit>, is_rejection: Int32
): Int32

@C
foreign func Bun__handleUnhandledRejection(
    arg0: CPointer<Unit>, reason: CPointer<Unit>, promise: CPointer<Unit>
): Int32

@C
foreign func Bun__HTTPServerAgent__notifyBodyChunkReceived(
    agent: CPointer<Unit>, requestId: CPointer<Unit>, serverId: CPointer<Unit>, flags: Int32, chunk: CPointer<Unit>, timestamp: Float64
): Unit

@C
foreign func Bun__HTTPServerAgent__notifyRequestFinished(
    agent: CPointer<Unit>, requestId: CPointer<Unit>, serverId: CPointer<Unit>, timestamp: Float64, duration: Float64
): Unit

@C
foreign func Bun__HTTPServerAgent__notifyRequestHandlerException(
    agent: CPointer<Unit>, requestId: CPointer<Unit>, serverId: CPointer<Unit>, message: CPointer<Unit>, url: CPointer<Unit>, line: Int32, timestamp: Float64
): Unit

@C
foreign func Bun__HTTPServerAgent__notifyRequestWillBeSent(
    agent: CPointer<Unit>, requestId: CPointer<Unit>, serverId: CPointer<Unit>, routeId: CPointer<Unit>, url: CPointer<Unit>, fullUrl: CPointer<Unit>, method: CPointer<Unit>, headersJson: CPointer<Unit>, paramsJson: CPointer<Unit>, hasBody: Bool, timestamp: Float64
): Unit

@C
foreign func Bun__HTTPServerAgent__notifyResponseReceived(
    agent: CPointer<Unit>, requestId: CPointer<Unit>, serverId: CPointer<Unit>, statusCode: Int32, statusText: CPointer<Unit>, headersJson: CPointer<Unit>, hasBody: Bool, timestamp: Float64
): Unit

@C
foreign func Bun__isEncodingSupported(
    encodingName: CPointer<Unit>, encodingNameLen: UIntNative
): Bool

@C
foreign func Bun__JSArray__contiguousVectorIsStillValid(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: UInt32
): Bool

@C
foreign func Bun__JSArray__getContiguousVector(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Bun__JSObject__getCodePropertyVMInquiry(
    global: CPointer<Unit>, obj: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Bun__JSValue__toNumber(
    value: CPointer<Unit>, global: CPointer<Unit>
): Float64

@C
foreign func Bun__loadHTMLEntryPoint(
    global: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Bun__makeArrayBufferWithBytesNoCopy(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: UIntNative, arg3: CPointer<Unit>, arg4: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Bun__makeTypedArrayWithBytesNoCopy(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>, arg3: UIntNative, arg4: CPointer<Unit>, arg5: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Bun__noSideEffectsToString(
    vm: CPointer<Unit>, globalObject: CPointer<Unit>, reason: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Bun__Process__emitWarning(
    globalObject: CPointer<Unit>, warning: CPointer<Unit>, arg_type: CPointer<Unit>, code: CPointer<Unit>, ctor: CPointer<Unit>
): Unit

@C
foreign func Bun__Process__queueNextTick1(
    arg0: CPointer<Unit>, fn_: CPointer<Unit>, arg1: CPointer<Unit>
): Unit

@C
foreign func Bun__Process__queueNextTick2(
    arg0: CPointer<Unit>, fn_: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>
): Unit

@C
foreign func Bun__promises__emitUnhandledRejectionWarning(
    arg0: CPointer<Unit>, reason: CPointer<Unit>, promise: CPointer<Unit>
): Unit

@C
foreign func Bun__promises__isErrorLike(
    arg0: CPointer<Unit>, reason: CPointer<Unit>
): Bool

@C
foreign func Bun__ProxyObject__getInternalField(
    field: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Bun__runDeferredWork(
    task: CPointer<Unit>
): Unit

@C
foreign func Bun__runOnLoadPlugins(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>, arg3: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Bun__runOnResolvePlugins(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>, arg3: CPointer<Unit>, arg4: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Bun__SecretsJobOptions__deinit(
    ctx: CPointer<Unit>
): Unit

@C
foreign func Bun__SecretsJobOptions__runFromJS(
    ctx: CPointer<Unit>, global: CPointer<Unit>, promise: CPointer<Unit>
): Unit

@C
foreign func Bun__SecretsJobOptions__runTask(
    ctx: CPointer<Unit>, global: CPointer<Unit>
): Unit

@C
foreign func Bun__SerializedScriptSlice__free(
    arg0: CPointer<Unit>
): Unit

@C
foreign func Bun__serializeJSValue(
    global: CPointer<Unit>, value: CPointer<Unit>, flags: UInt8
): CPointer<Unit>

@C
foreign func Bun__setSamplingInterval(
    intervalMicroseconds: Int32
): Unit

@C
foreign func Bun__startCPUProfiler(
    vm: CPointer<Unit>
): Unit

@C
foreign func Bun__stopCPUProfiler(
    vm: CPointer<Unit>, outJSON: CPointer<Unit>, outText: CPointer<Unit>
): Unit

@C
foreign func Bun__stripBOMFromTextCodec(
    codec: CPointer<Unit>
): Unit

@C
foreign func Bun__StrongRef__clear(): Unit

@C
foreign func Bun__StrongRef__delete(): Unit

@C
foreign func Bun__StrongRef__new(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Bun__StrongRef__set(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): Unit

@C
foreign func Bun__WeakRef__clear(): Unit

@C
foreign func Bun__WeakRef__delete(): Unit

@C
foreign func Bun__WeakRef__get(): CPointer<Unit>

@C
foreign func Bun__WeakRef__new(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, refType: CPointer<Unit>, ctx: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Bun__WebView__closeAllForTermination(): Unit

@C
foreign func Bun__wrapUnhandledRejectionErrorForUncaughtException(
    arg0: CPointer<Unit>, reason: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Bun__writeHTTPDate(
    buffer: CPointer<Unit>, length: UIntNative, timestampMs: UInt64
): Int32


// ============================================================================
// WebCore (50 functions)
// ============================================================================

@C
foreign func WebCore__AbortSignal__aborted(
    arg0: CPointer<Unit>
): Bool

@C
foreign func WebCore__AbortSignal__abortReason(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__AbortSignal__addListener(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, ArgFn2: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__AbortSignal__cleanNativeBindings(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): Unit

@C
foreign func WebCore__AbortSignal__create(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__AbortSignal__decrementPendingActivity(
    arg0: CPointer<Unit>
): Unit

@C
foreign func WebCore__AbortSignal__fromJS(
    JSValue0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__AbortSignal__getTimeout(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__AbortSignal__incrementPendingActivity(
    arg0: CPointer<Unit>
): Unit

@C
foreign func WebCore__AbortSignal__new(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__AbortSignal__reasonIfAborted(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__AbortSignal__ref(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__AbortSignal__signal(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>
): Unit

@C
foreign func WebCore__AbortSignal__toJS(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__AbortSignal__unref(
    arg0: CPointer<Unit>
): Unit

@C
foreign func WebCore__CommonAbortReason__toJS(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__DOMFormData__append(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>
): Unit

@C
foreign func WebCore__DOMFormData__appendBlob(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>, arg3: CPointer<Unit>, arg4: CPointer<Unit>
): Unit

@C
foreign func WebCore__DOMFormData__cast_(
    JSValue0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__DOMFormData__count(
    arg0: CPointer<Unit>
): UIntNative

@C
foreign func WebCore__DOMFormData__create(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__DOMFormData__createFromURLQuery(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__DOMFormData__fromJS(
    JSValue0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__DOMFormData__toQueryString(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__DOMURL__cast_(
    JSValue0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__DOMURL__fileSystemPath(
    arg0: CPointer<Unit>, error_code: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__FetchHeaders__append(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>, arg3: CPointer<Unit>
): Unit

@C
foreign func WebCore__FetchHeaders__cast_(
    JSValue0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__FetchHeaders__clone(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__FetchHeaders__cloneThis(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__FetchHeaders__copyTo(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>, arg3: CPointer<Unit>
): Unit

@C
foreign func WebCore__FetchHeaders__count(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>
): Unit

@C
foreign func WebCore__FetchHeaders__createEmpty(): CPointer<Unit>

@C
foreign func WebCore__FetchHeaders__createFromH3(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__FetchHeaders__createFromPicoHeaders_(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__FetchHeaders__createFromUWS(
    arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__FetchHeaders__createValue(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>, arg3: CPointer<Unit>, arg4: UInt32
): CPointer<Unit>

@C
foreign func WebCore__FetchHeaders__createValueNotJS(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>, arg3: CPointer<Unit>, arg4: UInt32
): CPointer<Unit>

@C
foreign func WebCore__FetchHeaders__deref(
    arg0: CPointer<Unit>
): Unit

@C
foreign func WebCore__FetchHeaders__fastGet_(
    arg0: CPointer<Unit>, arg1: UInt8, arg2: CPointer<Unit>
): Unit

@C
foreign func WebCore__FetchHeaders__fastHas_(
    arg0: CPointer<Unit>, arg1: UInt8
): Bool

@C
foreign func WebCore__FetchHeaders__fastRemove_(
    arg0: CPointer<Unit>, arg1: UInt8
): Unit

@C
foreign func WebCore__FetchHeaders__get_(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>, arg3: CPointer<Unit>
): Unit

@C
foreign func WebCore__FetchHeaders__has(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>
): Bool

@C
foreign func WebCore__FetchHeaders__isEmpty(
    arg0: CPointer<Unit>
): Bool

@C
foreign func WebCore__FetchHeaders__put_(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>, arg3: CPointer<Unit>
): Unit

@C
foreign func WebCore__FetchHeaders__put(
    name_: CPointer<Unit>, value: CPointer<Unit>, global: CPointer<Unit>
): Unit

@C
foreign func WebCore__FetchHeaders__remove(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>
): Unit

@C
foreign func WebCore__FetchHeaders__toJS(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebCore__FetchHeaders__toUWSResponse(
    arg0: CPointer<Unit>, kind: CPointer<Unit>, arg2: CPointer<Unit>
): Unit


// ============================================================================
// URL (20 functions)
// ============================================================================

@C
foreign func URL__deinit(
    arg0: CPointer<Unit>
): Unit

@C
foreign func URL__fragmentIdentifier(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func URL__fromJS(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func URL__fromString(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func URL__getFileURLString(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func URL__getHrefFromJS(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func URL__getHrefJoin(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func URL__getHref(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func URL__hash(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func URL__hostname(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func URL__host(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func URL__href(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func URL__originLength(
    latin1_slice: CPointer<Unit>, len: UIntNative
): UInt32

@C
foreign func URL__password(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func URL__pathFromFileURL(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func URL__pathname(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func URL__port(
    arg0: CPointer<Unit>
): UInt32

@C
foreign func URL__protocol(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func URL__search(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func URL__username(
    arg0: CPointer<Unit>
): CPointer<Unit>


// ============================================================================
// URLSearchParams (2 functions)
// ============================================================================

@C
foreign func URLSearchParams__create(
    globalObject: CPointer<Unit>, arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func URLSearchParams__fromJS(
    arg0: CPointer<Unit>
): CPointer<Unit>


// ============================================================================
// Yarr (6 functions)
// ============================================================================

@C
foreign func Yarr__RegularExpression__deinit(
    pattern: CPointer<Unit>
): Unit

@C
foreign func Yarr__RegularExpression__init(
    pattern: CPointer<Unit>, flags: UInt16
): CPointer<Unit>

@C
foreign func Yarr__RegularExpression__isValid(): Bool

@C
foreign func Yarr__RegularExpression__matchedLength(): Int32

@C
foreign func Yarr__RegularExpression__matches(
    string: CPointer<Unit>
): Int32

@C
foreign func Yarr__RegularExpression__searchRev(): Int32


// ============================================================================
// StringBuilder (13 functions)
// ============================================================================

@C
foreign func StringBuilder__appendDouble(
    arg0: CPointer<Unit>, num: Float64
): Unit

@C
foreign func StringBuilder__appendInt(
    arg0: CPointer<Unit>, num: Int32
): Unit

@C
foreign func StringBuilder__appendLatin1(
    arg0: CPointer<Unit>, str: CPointer<Unit>, len: UIntNative
): Unit

@C
foreign func StringBuilder__appendLChar(
    arg0: CPointer<Unit>, c: UInt8
): Unit

@C
foreign func StringBuilder__appendQuotedJsonString(
    arg0: CPointer<Unit>, str: CPointer<Unit>
): Unit

@C
foreign func StringBuilder__appendString(
    arg0: CPointer<Unit>, str: CPointer<Unit>
): Unit

@C
foreign func StringBuilder__appendUChar(
    arg0: CPointer<Unit>, c: UInt16
): Unit

@C
foreign func StringBuilder__appendUsize(
    arg0: CPointer<Unit>, num: UIntNative
): Unit

@C
foreign func StringBuilder__appendUtf16(
    arg0: CPointer<Unit>, str: CPointer<Unit>, len: UIntNative
): Unit

@C
foreign func StringBuilder__deinit(
    arg0: CPointer<Unit>
): Unit

@C
foreign func StringBuilder__ensureUnusedCapacity(
    arg0: CPointer<Unit>, arg1: UIntNative
): Unit

@C
foreign func StringBuilder__init(
    arg0: CPointer<Unit>
): Unit

@C
foreign func StringBuilder__toString(
    arg0: CPointer<Unit>, global: CPointer<Unit>
): CPointer<Unit>


// ============================================================================
// Debugger (4 functions)
// ============================================================================

@C
foreign func Debugger__didCancelAsyncCall(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: UInt64
): Unit

@C
foreign func Debugger__didDispatchAsyncCall(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: UInt64
): Unit

@C
foreign func Debugger__didScheduleAsyncCall(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: UInt64, arg3: Bool
): Unit

@C
foreign func Debugger__willDispatchAsyncCall(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: UInt64
): Unit


// ============================================================================
// DOMFormData (1 functions)
// ============================================================================

@C
foreign func DOMFormData__forEach(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>
): Unit


// ============================================================================
// JSBuffer (4 functions)
// ============================================================================

@C
foreign func JSBuffer__bufferFromLength(
    arg0: CPointer<Unit>, arg1: Int64
): CPointer<Unit>

@C
foreign func JSBuffer__bufferFromPointerAndLengthAndDeinit(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: UIntNative, arg3: CPointer<Unit>, arg4: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSBuffer__fromMmap(
    arg0: CPointer<Unit>, addr: CPointer<Unit>, len: UIntNative
): CPointer<Unit>

@C
foreign func JSBuffer__isBuffer(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): Bool


// ============================================================================
// Other (59 functions)
// ============================================================================

@C
foreign func ArrayBuffer__fromSharedMemfd(
    fd: Int64, globalObject: CPointer<Unit>, byte_offset: UIntNative, byte_length: UIntNative, total_size: UIntNative, arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func BakeCreateProdGlobal(
    console_ptr: CPointer<Unit>
): CPointer<Unit>

@C
foreign func BunDebugger__willHotReload(): Unit

@C
foreign func BunString__createArray(
    globalObject: CPointer<Unit>, ptr: CPointer<Unit>, len: UIntNative
): CPointer<Unit>

@C
foreign func BunString__toJSDOMURL(
    globalObject: CPointer<Unit>, in_: CPointer<Unit>
): CPointer<Unit>

@C
foreign func BunString__toJS(
    globalObject: CPointer<Unit>, in_: CPointer<Unit>
): CPointer<Unit>

@C
foreign func BunString__toJSWithLength(
    globalObject: CPointer<Unit>, in_: CPointer<Unit>, arg0: UIntNative
): CPointer<Unit>

@C
foreign func BunString__toURL(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func BunString__transferToJS(
    globalThis: CPointer<Unit>
): CPointer<Unit>

@C
foreign func generateCachedCommonJSProgramByteCodeFromSourceCode(
    sourceProviderURL: CPointer<Unit>, input_code: CPointer<Unit>, inputSourceCodeSize: UIntNative, outputByteCode: CPointer<Unit>, outputByteCodeSize: CPointer<Unit>, cached_bytecode: CPointer<Unit>
): Bool

@C
foreign func generateCachedModuleByteCodeFromSourceCode(
    sourceProviderURL: CPointer<Unit>, input_code: CPointer<Unit>, inputSourceCodeSize: UIntNative, outputByteCode: CPointer<Unit>, outputByteCodeSize: CPointer<Unit>, cached_bytecode: CPointer<Unit>
): Bool

@C
foreign func MarkedArgumentBuffer__append(
    args: CPointer<Unit>, value: CPointer<Unit>
): CPointer<Unit>

@C
foreign func MarkedArgumentBuffer__run(
    ctx: CPointer<Unit>, arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Process__dispatchOnBeforeExit(
    arg0: CPointer<Unit>, code: UInt8
): Unit

@C
foreign func Process__dispatchOnExit(
    arg0: CPointer<Unit>, code: UInt8
): Unit

@C
foreign func Process__emitDisconnectEvent(
    global: CPointer<Unit>
): Unit

@C
foreign func Process__emitErrorEvent(
    global: CPointer<Unit>, value: CPointer<Unit>
): Unit

@C
foreign func Process__emitMessageEvent(
    global: CPointer<Unit>, value: CPointer<Unit>, handle: CPointer<Unit>
): Unit

@C
foreign func ScriptExecutionContextIdentifier__forGlobalObject(
    global: CPointer<Unit>
): UInt32

@C
foreign func SystemError__toErrorInstance(
    global: CPointer<Unit>
): CPointer<Unit>

@C
foreign func SystemError__toErrorInstanceWithInfoObject(
    global: CPointer<Unit>
): CPointer<Unit>

@C
foreign func TopExceptionScope__assertNoException(
    ptr: CPointer<Unit>
): CPointer<Unit>

@C
foreign func TopExceptionScope__clearException(
    ptr: CPointer<Unit>
): CPointer<Unit>

@C
foreign func TopExceptionScope__destruct(
    ptr: CPointer<Unit>
): CPointer<Unit>

@C
foreign func TopExceptionScope__exceptionIncludingTraps(
    ptr: CPointer<Unit>
): CPointer<Unit>

@C
foreign func TopExceptionScope__pureException(
    ptr: CPointer<Unit>
): CPointer<Unit>

@C
foreign func WebWorker__dispatchError(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>, arg3: CPointer<Unit>
): Unit

@C
foreign func WebWorker__dispatchExit(
    arg0: CPointer<Unit>, arg1: Int32
): Unit

@C
foreign func WebWorker__dispatchOnline(
    cpp_worker: CPointer<Unit>, arg0: CPointer<Unit>
): Unit

@C
foreign func WebWorker__fireEarlyMessages(
    cpp_worker: CPointer<Unit>, arg0: CPointer<Unit>
): Unit

@C
foreign func WebWorker__teardownJSCVM(
    arg0: CPointer<Unit>
): Unit

@C
foreign func WTF__numberOfProcessorCores(): Int32

@C
foreign func WTF__parseDouble(
    bytes: CPointer<Unit>, length: UIntNative, counted: CPointer<Unit>
): Float64

@C
foreign func WTF__parseES5Date(
    bytes: CPointer<Unit>, length: UIntNative
): Float64

@C
foreign func WTF__releaseFastMallocFreeMemoryForThisThread(): Unit

@C
foreign func ZigException__collectSourceLines(
    jsValue: CPointer<Unit>, global: CPointer<Unit>, exception: CPointer<Unit>
): Unit

@C
foreign func ZigException__fromException(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Zig__GlobalObject__create(
    arg0: CPointer<Unit>, arg1: Int32, arg2: Bool, arg3: Bool, arg4: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Zig__GlobalObject__createForTestIsolation(
    old_global: CPointer<Unit>, console: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Zig__GlobalObject__destructOnExit(
    arg0: CPointer<Unit>
): Unit

@C
foreign func Zig__GlobalObject__getModuleRegistryMap(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func ZigGlobalObject__makeNapiEnvForFFI(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func ZigGlobalObject__readableStreamToArrayBuffer(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func ZigGlobalObject__readableStreamToBlob(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func ZigGlobalObject__readableStreamToBytes(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func ZigGlobalObject__readableStreamToFormData(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>
): CPointer<Unit>

@C
foreign func ZigGlobalObject__readableStreamToJSON(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func ZigGlobalObject__readableStreamToText(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Zig__GlobalObject__resetModuleRegistryMap(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): Bool

@C
foreign func ZigString__to16BitValue(
    global: CPointer<Unit>
): CPointer<Unit>

@C
foreign func ZigString__toAtomicValue(
    globalThis: CPointer<Unit>
): CPointer<Unit>

@C
foreign func ZigString__toDOMExceptionInstance(
    global: CPointer<Unit>, code: UInt8
): CPointer<Unit>

@C
foreign func ZigString__toErrorInstance(
    global: CPointer<Unit>
): CPointer<Unit>

@C
foreign func ZigString__toExternalU16(
    ptr: CPointer<Unit>, len: UIntNative, global: CPointer<Unit>
): CPointer<Unit>

@C
foreign func ZigString__toJSONObject(
    arg0: CPointer<Unit>
): CPointer<Unit>

@C
foreign func ZigString__toRangeErrorInstance(
    global: CPointer<Unit>
): CPointer<Unit>

@C
foreign func ZigString__toSyntaxErrorInstance(
    global: CPointer<Unit>
): CPointer<Unit>

@C
foreign func ZigString__toTypeErrorInstance(
    global: CPointer<Unit>
): CPointer<Unit>

@C
foreign func ZigString__toValueGC(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>
): CPointer<Unit>


// ============================================================================
// Missing FFI declarations (manually added)
// ============================================================================

@C
foreign func Bun__CreateFFIFunctionValue(
    globalObject: CPointer<Unit>, symbolName: CPointer<Unit>, argCount: UInt32, function: CPointer<Unit>, add_ptr_field: Bool, inputFunctionPtr: CPointer<Unit>
): CPointer<Unit>

@C
foreign func Bun__CreateFFIFunctionWithDataValue(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, argCount: UInt32, function: CPointer<Unit>, data: CPointer<Unit>
): CPointer<Unit>

@C
foreign func DOMFormData__toQueryString(
    arg0: CPointer<Unit>, ctx: CPointer<Unit>, callback: CPointer<Unit>
): Unit

@C
foreign func JSC__JSModuleLoader__evaluate(
    globalObject: CPointer<Unit>, sourceCodePtr: CPointer<Unit>, sourceCodeLen: UIntNative, originUrlPtr: CPointer<Unit>, originUrlLen: UIntNative, referrerUrlPtr: CPointer<Unit>, referrerUrlLen: UIntNative, thisValue: CPointer<Unit>, exception: CPointer<Unit>
): CPointer<Unit>

@C
foreign func JSC__JSValue__callCustomInspectFunction(
    arg0: CPointer<Unit>, arg1: CPointer<Unit>, arg2: CPointer<Unit>, depth: UInt32, max_depth: UInt32, colors: Bool
): CPointer<Unit>

@C
foreign func JSFunction__createFromZig(
    global: CPointer<Unit>, fn_name: CPointer<Unit>, implementation: CPointer<Unit>, arg_count: UInt32, implementation_visibility: UInt32, intrinsic: UInt32, constructor: CPointer<Unit>
): CPointer<Unit>

@C
foreign func ZigString__external(
    arg0: CPointer<Unit>, global: CPointer<Unit>, ctx: CPointer<Unit>, callback: CPointer<Unit>
): CPointer<Unit>

@C
foreign func ZigString__toExternalValueWithCallback(
    arg0: CPointer<Unit>, global: CPointer<Unit>, callback: CPointer<Unit>
): CPointer<Unit>

@C
foreign func URLSearchParams__toString(
    arg0: CPointer<Unit>, ctx: CPointer<Unit>, callback: CPointer<Unit>
): Unit


@C
foreign func TopExceptionScope__construct(
    ptr: CPointer<Unit>, global: CPointer<Unit>, function: CPointer<Unit>, file: CPointer<Unit>, line: UInt32, size: UIntNative, alignment: UIntNative
): Unit

