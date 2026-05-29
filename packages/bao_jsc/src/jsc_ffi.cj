// 严格翻译自: JavaScriptCore C API (JavaScriptCore.h / JSBase.h / JSObjectRef.h / JSStringRef.h)
// 集中管理所有 JSC C API 的 FFI 声明
//
// 使用 CPointer<UInt8> 表示不透明指针 (void*)，
// 遵循项目现有的 FFI 惯例（与 jni_ffi.cj 保持一致）。
// 所有 foreign 函数需要在 unsafe 块中调用。

package bao_jsc

// ============================================================================
// JSStringRef 操作
// ============================================================================

/// 创建 JSStringRef from a UTF-8 C string
/// C API: JSStringCreateWithUTF8CString(const char* string) -> JSStringRef
foreign func JSStringCreateWithUTF8CString(
    string: CString
): CPointer<UInt8>

/// 释放 JSStringRef
/// C API: JSStringRelease(JSStringRef string)
foreign func JSStringRelease(
    string: CPointer<UInt8>
): Unit

/// 获取 JSStringRef 的 UTF-8 编码最大缓冲区大小
/// C API: JSStringGetMaximumUTF8CStringSize(JSStringRef string) -> size_t
foreign func JSStringGetMaximumUTF8CStringSize(
    string: CPointer<UInt8>
): UInt64

/// 将 JSStringRef 复制到 UTF-8 C 字符串缓冲区
/// C API: JSStringGetUTF8CString(JSStringRef string, char* buffer, size_t bufferSize) -> size_t
/// 返回实际写入的字节数（不含 null 终止符）
foreign func JSStringGetUTF8CString(
    string: CPointer<UInt8>,
    buffer: CPointer<UInt8>,
    bufferSize: UInt64
): UInt64

/// 比较 JSStringRef 与 UTF-8 C 字符串是否相等
/// C API: JSStringIsEqualToUTF8CString(JSStringRef a, const char* b) -> bool
foreign func JSStringIsEqualToUTF8CString(
    a: CPointer<UInt8>,
    b: CString
): Bool

/// 获取 JSStringRef 的字符长度
/// C API: JSStringGetLength(JSStringRef string) -> size_t
foreign func JSStringGetLength(
    string: CPointer<UInt8>
): UInt64

// ============================================================================
// Context 操作
// ============================================================================

/// 获取全局上下文中的全局对象
/// C API: JSContextGetGlobalObject(JSContextRef ctx) -> JSObjectRef
foreign func JSContextGetGlobalObject(
    ctx: CPointer<UInt8>
): CPointer<UInt8>

/// 创建全局上下文
/// C API: JSGlobalContextCreate(JSClassRef globalObjectClass) -> JSGlobalContextRef
foreign func JSGlobalContextCreate(
    globalObjectClass: CPointer<UInt8>
): CPointer<UInt8>

/// 释放全局上下文
/// C API: JSGlobalContextRelease(JSGlobalContextRef ctx)
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
foreign func JSValueMakeUndefined(
    ctx: CPointer<UInt8>
): CPointer<UInt8>

/// 创建 null 值
/// C API: JSValueMakeNull(JSContextRef ctx) -> JSValueRef
foreign func JSValueMakeNull(
    ctx: CPointer<UInt8>
): CPointer<UInt8>

/// 创建 boolean 值
/// C API: JSValueMakeBoolean(JSContextRef ctx, bool value) -> JSValueRef
foreign func JSValueMakeBoolean(
    ctx: CPointer<UInt8>,
    value: Bool
): CPointer<UInt8>

/// 创建 number 值
/// C API: JSValueMakeNumber(JSContextRef ctx, double value) -> JSValueRef
foreign func JSValueMakeNumber(
    ctx: CPointer<UInt8>,
    value: Float64
): CPointer<UInt8>

/// 创建 string 值
/// C API: JSValueMakeString(JSContextRef ctx, JSStringRef string) -> JSValueRef
foreign func JSValueMakeString(
    ctx: CPointer<UInt8>,
    str: CPointer<UInt8>
): CPointer<UInt8>

// ============================================================================
// JSValue 类型检查
// ============================================================================

/// C API: JSValueGetType(JSContextRef ctx, JSValueRef value) -> JSType
foreign func JSValueGetType(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>
): Int32

/// C API: JSValueIsUndefined(JSContextRef ctx, JSValueRef value) -> bool
foreign func JSValueIsUndefined(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>
): Bool

/// C API: JSValueIsNull(JSContextRef ctx, JSValueRef value) -> bool
foreign func JSValueIsNull(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>
): Bool

/// C API: JSValueIsBoolean(JSContextRef ctx, JSValueRef value) -> bool
foreign func JSValueIsBoolean(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>
): Bool

/// C API: JSValueIsNumber(JSContextRef ctx, JSValueRef value) -> bool
foreign func JSValueIsNumber(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>
): Bool

/// C API: JSValueIsString(JSContextRef ctx, JSValueRef value) -> bool
foreign func JSValueIsString(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>
): Bool

/// C API: JSValueIsObject(JSContextRef ctx, JSValueRef value) -> bool
foreign func JSValueIsObject(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>
): Bool

/// C API: JSValueIsSymbol(JSContextRef ctx, JSValueRef value) -> bool
foreign func JSValueIsSymbol(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>
): Bool

// ============================================================================
// JSValue 转换
// ============================================================================

/// C API: JSValueToBoolean(JSContextRef ctx, JSValueRef value) -> bool
foreign func JSValueToBoolean(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>
): Bool

/// C API: JSValueToNumber(JSContextRef ctx, JSValueRef value, JSValueRef* exception) -> double
foreign func JSValueToNumber(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): Float64

/// C API: JSValueToStringCopy(JSContextRef ctx, JSValueRef value, JSValueRef* exception) -> JSStringRef
/// 返回的 JSStringRef 需要调用者用 JSStringRelease 释放
foreign func JSValueToStringCopy(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): CPointer<UInt8>

/// C API: JSValueToObject(JSContextRef ctx, JSValueRef value, JSValueRef* exception) -> JSObjectRef
foreign func JSValueToObject(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): CPointer<UInt8>

// ============================================================================
// JSValue 比较
// ============================================================================

/// C API: JSValueIsEqual(JSContextRef ctx, JSValueRef a, JSValueRef b, JSValueRef* exception) -> bool
foreign func JSValueIsEqual(
    ctx: CPointer<UInt8>,
    a: CPointer<UInt8>,
    b: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): Bool

/// C API: JSValueIsStrictEqual(JSContextRef ctx, JSValueRef a, JSValueRef b) -> bool
foreign func JSValueIsStrictEqual(
    ctx: CPointer<UInt8>,
    a: CPointer<UInt8>,
    b: CPointer<UInt8>
): Bool

/// C API: JSValueIsInstanceOfConstructor(JSContextRef ctx, JSValueRef value,
///           JSObjectRef constructor, JSValueRef* exception) -> bool
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
foreign func JSValueProtect(
    ctx: CPointer<UInt8>,
    value: CPointer<UInt8>
): Unit

/// 取消保护 JSValue（与 JSValueProtect 配对使用）
/// C API: JSValueUnprotect(JSContextRef ctx, JSValueRef value)
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
foreign func JSObjectIsFunction(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>
): Bool

/// 检查对象是否为构造函数
/// C API: JSObjectIsConstructor(JSContextRef ctx, JSObjectRef object) -> bool
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
foreign func JSObjectMakeError(
    ctx: CPointer<UInt8>,
    argumentCount: UInt64,
    arguments: CPointer<CPointer<UInt8>>,
    exception: CPointer<CPointer<UInt8>>
): CPointer<UInt8>

/// 创建普通对象
/// C API: JSObjectMake(JSContextRef ctx, JSClassRef jsClass, void* data) -> JSObjectRef
foreign func JSObjectMake(
    ctx: CPointer<UInt8>,
    jsClass: CPointer<UInt8>,
    data: CPointer<UInt8>
): CPointer<UInt8>

/// 创建数组
/// C API: JSObjectMakeArray(JSContextRef ctx, size_t argumentCount,
///           const JSValueRef arguments[], JSValueRef* exception) -> JSObjectRef
foreign func JSObjectMakeArray(
    ctx: CPointer<UInt8>,
    argumentCount: UInt64,
    arguments: CPointer<CPointer<UInt8>>,
    exception: CPointer<CPointer<UInt8>>
): CPointer<UInt8>

// ============================================================================
// JSObject 属性操作
// ============================================================================

/// C API: JSObjectGetProperty(JSContextRef ctx, JSObjectRef object,
///           JSStringRef propertyName, JSValueRef* exception) -> JSValueRef
foreign func JSObjectGetProperty(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>,
    propertyName: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): CPointer<UInt8>

/// C API: JSObjectSetProperty(JSContextRef ctx, JSObjectRef object,
///           JSStringRef propertyName, JSValueRef value,
///           JSPropertyAttributes attributes, JSValueRef* exception)
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
foreign func JSObjectDeleteProperty(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>,
    propertyName: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): Bool

/// C API: JSObjectHasProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName) -> bool
foreign func JSObjectHasProperty(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>,
    propertyName: CPointer<UInt8>
): Bool

/// C API: JSObjectGetPrototype(JSContextRef ctx, JSObjectRef object) -> JSValueRef
foreign func JSObjectGetPrototype(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>
): CPointer<UInt8>

/// C API: JSObjectSetPrototype(JSContextRef ctx, JSObjectRef object, JSValueRef value)
foreign func JSObjectSetPrototype(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>,
    value: CPointer<UInt8>
): Unit

/// C API: JSObjectCopyPropertyNames(JSContextRef ctx, JSObjectRef object) -> JSPropertyNameArrayRef
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
foreign func JSObjectMakeTypedArray(
    ctx: CPointer<UInt8>,
    arrayType: Int32,
    length: UInt64,
    exception: CPointer<CPointer<UInt8>>
): CPointer<UInt8>

/// 获取 TypedArray 的字节长度
/// C API: JSObjectGetTypedArrayByteLength(JSContextRef ctx, JSObjectRef object,
///           JSValueRef* exception) -> size_t
foreign func JSObjectGetTypedArrayByteLength(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): UInt64

/// 获取 TypedArray 的长度
/// C API: JSObjectGetTypedArrayLength(JSContextRef ctx, JSObjectRef object,
///           JSValueRef* exception) -> size_t
foreign func JSObjectGetTypedArrayLength(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): UInt64

/// 获取 TypedArray 的字节偏移
/// C API: JSObjectGetTypedArrayByteOffset(JSContextRef ctx, JSObjectRef object,
///           JSValueRef* exception) -> size_t
foreign func JSObjectGetTypedArrayByteOffset(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): UInt64

/// 获取 TypedArray 底层的 ArrayBuffer
/// C API: JSObjectGetTypedArrayBuffer(JSContextRef ctx, JSObjectRef object,
///           JSValueRef* exception) -> JSObjectRef
foreign func JSObjectGetTypedArrayBuffer(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): CPointer<UInt8>

/// 获取 ArrayBuffer 的字节指针
/// C API: JSObjectGetArrayBufferBytesPtr(JSContextRef ctx, JSObjectRef object,
///           JSValueRef* exception) -> void*
foreign func JSObjectGetArrayBufferBytesPtr(
    ctx: CPointer<UInt8>,
    object: CPointer<UInt8>,
    exception: CPointer<CPointer<UInt8>>
): CPointer<UInt8>

/// 获取 ArrayBuffer 的字节长度
/// C API: JSObjectGetArrayBufferByteLength(JSContextRef ctx, JSObjectRef object,
///           JSValueRef* exception) -> size_t
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
foreign func JSGarbageCollect(
    ctx: CPointer<UInt8>
): Unit
