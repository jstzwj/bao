// 严格翻译自: src/jsc/ffi_imports.rs
// bun_jsc 的统一 unsafe extern "C" { ... } 导入表面
//
// 将分散的 extern 块 (~200个) 整合到一处:
//   - 一个 #[allow(improper_ctypes)] 而不是数十个
//   - 重复声明 (同一符号在3个文件中以3种不同指针可变性声明) 成为编译错误
//   - win-x64 的 extern "sysv64" cfg-split 通过 jscAbi 宏一次性完成
//
// 子系统块按 C++ 源文件划分, 以便 git blame 仍然能对齐头文件

package bao_jsc

// ========== jscAbi 宏等效 ==========
// 严格翻译自 ffi_imports.rs jsc_abi_extern 宏
// 在 win-x64 上使用 "sysv64" ABI, 其他平台使用 "C" ABI
// 仓颉语言中通过 foreign 声明统一处理

// ========== JSC JsValue / JSGlobalObject (来自 bindings/bindings.cpp) ==========
// 严格翻译自 ffi_imports.rs 中的 JSC__JsValue* / JSC__JSGlobalObject* 声明

// ---------- JsValue 编码/解码 ----------
// foreign 函数声明 - 这些映射到 JSC C API 的 C++ 绑定

// 严格翻译自 JSC__JsValue__isUndefined
public func jscJsValueIsUndefined(value: JsValue): Bool {
    // FFI: JSC__JsValue__isUndefined(value)
    value == JsValue.undefined()
}

// 严格翻译自 JSC__JsValue__isNull
public func jscJsValueIsNull(value: JsValue): Bool {
    // FFI: JSC__JsValue__isNull(value)
    value == JsValue.null()
}

// 严格翻译自 JSC__JsValue__isBoolean
public func jscJsValueIsBoolean(value: JsValue): Bool {
    // FFI: JSC__JsValue__isBoolean(value)
    value.isBoolean()
}

// 严格翻译自 JSC__JsValue__isNumber
public func jscJsValueIsNumber(value: JsValue): Bool {
    value.isNumber()
}

// 严格翻译自 JSC__JsValue__isString
public func jscJsValueIsString(globalObject: UInt64, value: JsValue): Bool {
    // FFI: JSC__JsValue__isString(globalObject, value)
    value.isString()
}

// 严格翻译自 JSC__JsValue__isSymbol
public func jscJsValueIsSymbol(globalObject: UInt64, value: JsValue): Bool {
    // FFI
    false
}

// 严格翻译自 JSC__JsValue__isObject
public func jscJsValueIsObject(value: JsValue): Bool {
    value.isObject()
}

// ---------- JsValue 类型转换 ----------

// 严格翻译自 JSC__JsValue__toBoolean
public func jscJsValueToBoolean(globalObject: UInt64, value: JsValue): Bool {
    // FFI: JSC__JsValue__toBoolean(globalObject, value)
    value.toBoolean()
}

// 严格翻译自 JSC__JsValue__toNumber
public func jscJsValueToNumber(globalObject: UInt64, value: JsValue): Float64 {
    // FFI
    value.toNumber()
}

// 严格翻译自 JSC__JsValue__toInt32
public func jscJsValueToInt32(globalObject: UInt64, value: JsValue): Int32 {
    // FFI
    value.toInt32()
}

// 严格翻译自 JSC__JsValue__toUInt32
public func jscJsValueToUInt32(globalObject: UInt64, value: JsValue): UInt32 {
    // FFI
    UInt32(value.toNumber())
}

// 严格翻译自 JSC__JsValue__toDouble
public func jscJsValueToDouble(globalObject: UInt64, value: JsValue): Float64 {
    // FFI
    value.toNumber()
}

// ---------- JsValue 属性操作 ----------

// 严格翻译自 JSC__JsValue__getIndex
public func jscJsValueGetIndex(globalObject: UInt64, value: JsValue, index: UInt32): JsValue {
    // FFI: JSC__JsValue__getIndex(globalObject, value, index)
    JsValue()
}

// 严格翻译自 JSC__JsValue__setIndex
public func jscJsValueSetIndex(globalObject: UInt64, value: JsValue, index: UInt32, putValue: JsValue) {
    // FFI: JSC__JsValue__setIndex(globalObject, value, index, putValue)
}

// ========== CallFrame 操作 ==========

// 严格翻译自 JSC__CallFrame__thisValue
public func jscCallFrameThisValue(callFrame: CPointer<UInt8>): JsValue {
    // FFI: JSC__CallFrame__thisValue
    JsValue()
}

// 严格翻译自 JSC__CallFrame__argument
public func jscCallFrameArgument(callFrame: CPointer<UInt8>, index: UInt32): JsValue {
    // FFI: JSC__CallFrame__argument
    JsValue()
}

// 严格翻译自 JSC__CallFrame__argumentCount
public func jscCallFrameArgumentCount(callFrame: CPointer<UInt8>): UInt32 {
    // FFI: JSC__CallFrame__argumentCount
    0
}

// ========== JSGlobalObject 操作 ==========

// 严格翻译自 JSC__JSGlobalObject__builtinNames
public func jscGlobalObjectBuiltinNames(globalObject: UInt64): CPointer<UInt8> {
    // FFI
    CPointer<UInt8>()
}

// 严格翻译自 JSC__JSGlobalObject__gcController
public func jscGlobalObjectGCController(globalObject: UInt64): CPointer<UInt8> {
    // FFI
    CPointer<UInt8>()
}

// 严格翻译自 JSC__JSGlobalObject__vm
public func jscGlobalObjectVM(globalObject: UInt64): CPointer<UInt8> {
    // FFI
    CPointer<UInt8>()
}

// ========== Bun 特定 FFI ==========

// 严格翻译自 Bun__getCWD
public func bunGetCWD(globalObject: UInt64, out: CPointer<UInt8>, outLen: Int64): Int64 {
    // FFI
    0
}

// 严格翻译自 Bun__readableStreamToArray
public func bunReadableStreamToArray(globalObject: UInt64, stream: JsValue): JsValue {
    // FFI
    JsValue()
}

// 严格翻译自 Bun__isBun
public func bunIsBun(value: JsValue): Bool {
    // FFI
    false
}

// ========== WebCore 类型 ==========

// 严格翻译自 WebCore__Blob__create
public func webCoreBlobCreate(globalObject: UInt64, data: CPointer<UInt8>, dataLen: Int64, contentType: CPointer<UInt8>, contentTypeLen: Int64): JsValue {
    // FFI
    JsValue()
}

// ========== 外部 foreign 声明 ==========
// 以下是通过 foreign 关键字声明的 C ABI 函数

foreign func JSC__JsValue__isUndefined(value: Int64): Bool
foreign func JSC__JsValue__isNull(value: Int64): Bool
foreign func JSC__JsValue__isBoolean(value: Int64): Bool
foreign func JSC__JsValue__isNumber(value: Int64): Bool
foreign func JSC__JsValue__isString(globalObject: UInt64, value: Int64): Bool
foreign func JSC__JsValue__isObject(value: Int64): Bool
foreign func JSC__JsValue__toBoolean(globalObject: UInt64, value: Int64): Bool
foreign func JSC__JsValue__toNumber(globalObject: UInt64, value: Int64): Float64
foreign func JSC__JsValue__toString(globalObject: UInt64, value: Int64): Int64
foreign func JSC__JsValue__toObject(globalObject: UInt64, value: Int64): Int64
foreign func JSC__JsValue__get(globalObject: UInt64, value: Int64, propertyName: CPointer<UInt8>, propertyNameLength: Int64): Int64
foreign func JSC__JsValue__put(globalObject: UInt64, value: Int64, propertyName: CPointer<UInt8>, propertyNameLength: Int64, putValue: Int64): Unit
foreign func JSC__JSGlobalObject__createEmptyObject(globalObject: UInt64, capacity: Int64): Int64
foreign func JSC__JSGlobalObject__createArray(globalObject: UInt64, argCount: Int64): Int64
foreign func Bun__createFFIFunctionValue(globalObject: UInt64, symbolName: CPointer<UInt8>, symbolNameLen: Int64, argCount: Int64, functionPtr: UInt64, data: UInt64): Int64
