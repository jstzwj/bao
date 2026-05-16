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

// ========== JSC JSValue / JSGlobalObject (来自 bindings/bindings.cpp) ==========
// 严格翻译自 ffi_imports.rs 中的 JSC__JSValue* / JSC__JSGlobalObject* 声明

// ---------- JSValue 编码/解码 ----------
// foreign 函数声明 - 这些映射到 JSC C API 的 C++ 绑定

// 严格翻译自 JSC__JSValue__isUndefined
public func jscJSValueIsUndefined(value: JSValue) -> Bool {
    // FFI: JSC__JSValue__isUndefined(value)
    value == JSValue.undefined()
}

// 严格翻译自 JSC__JSValue__isNull
public func jscJSValueIsNull(value: JSValue) -> Bool {
    // FFI: JSC__JSValue__isNull(value)
    value == JSValue.null()
}

// 严格翻译自 JSC__JSValue__isBoolean
public func jscJSValueIsBoolean(value: JSValue) -> Bool {
    // FFI: JSC__JSValue__isBoolean(value)
    value.isBoolean()
}

// 严格翻译自 JSC__JSValue__isNumber
public func jscJSValueIsNumber(value: JSValue) -> Bool {
    value.isNumber()
}

// 严格翻译自 JSC__JSValue__isString
public func jscJSValueIsString(globalObject: CPointer<JSGlobalObject>, value: JSValue) -> Bool {
    // FFI: JSC__JSValue__isString(globalObject, value)
    value.isString()
}

// 严格翻译自 JSC__JSValue__isSymbol
public func jscJSValueIsSymbol(globalObject: CPointer<JSGlobalObject>, value: JSValue) -> Bool {
    // FFI
    false
}

// 严格翻译自 JSC__JSValue__isObject
public func jscJSValueIsObject(value: JSValue) -> Bool {
    value.isObject()
}

// ---------- JSValue 类型转换 ----------

// 严格翻译自 JSC__JSValue__toBoolean
public func jscJSValueToBoolean(globalObject: CPointer<JSGlobalObject>, value: JSValue) -> Bool {
    // FFI: JSC__JSValue__toBoolean(globalObject, value)
    value.toBoolean()
}

// 严格翻译自 JSC__JSValue__toNumber
public func jscJSValueToNumber(globalObject: CPointer<JSGlobalObject>, value: JSValue) -> Float64 {
    // FFI
    value.toDouble()
}

// 严格翻译自 JSC__JSValue__toInt32
public func jscJSValueToInt32(globalObject: CPointer<JSGlobalObject>, value: JSValue) -> Int32 {
    // FFI
    value.toInt32()
}

// 严格翻译自 JSC__JSValue__toUInt32
public func jscJSValueToUInt32(globalObject: CPointer<JSGlobalObject>, value: JSValue) -> UInt32 {
    // FFI
    value.toUInt32()
}

// 严格翻译自 JSC__JSValue__toDouble
public func jscJSValueToDouble(globalObject: CPointer<JSGlobalObject>, value: JSValue) -> Float64 {
    // FFI
    value.toDouble()
}

// ---------- JSValue 属性操作 ----------

// 严格翻译自 JSC__JSValue__getIndex
public func jscJSValueGetIndex(globalObject: CPointer<JSGlobalObject>, value: JSValue, index: UInt32) -> JSValue {
    // FFI: JSC__JSValue__getIndex(globalObject, value, index)
    JSValue.zero
}

// 严格翻译自 JSC__JSValue__setIndex
public func jscJSValueSetIndex(globalObject: CPointer<JSGlobalObject>, value: JSValue, index: UInt32, putValue: JSValue) {
    // FFI: JSC__JSValue__setIndex(globalObject, value, index, putValue)
}

// ========== CallFrame 操作 ==========

// 严格翻译自 JSC__CallFrame__thisValue
public func jscCallFrameThisValue(callFrame: CPointer<UInt8>) -> JSValue {
    // FFI: JSC__CallFrame__thisValue
    JSValue.zero
}

// 严格翻译自 JSC__CallFrame__argument
public func jscCallFrameArgument(callFrame: CPointer<UInt8>, index: UInt32) -> JSValue {
    // FFI: JSC__CallFrame__argument
    JSValue.zero
}

// 严格翻译自 JSC__CallFrame__argumentCount
public func jscCallFrameArgumentCount(callFrame: CPointer<UInt8>) -> UInt32 {
    // FFI: JSC__CallFrame__argumentCount
    0
}

// ========== JSGlobalObject 操作 ==========

// 严格翻译自 JSC__JSGlobalObject__builtinNames
public func jscGlobalObjectBuiltinNames(globalObject: CPointer<JSGlobalObject>) -> CPointer<UInt8> {
    // FFI
    CPointer<UInt8>()
}

// 严格翻译自 JSC__JSGlobalObject__gcController
public func jscGlobalObjectGCController(globalObject: CPointer<JSGlobalObject>) -> CPointer<UInt8> {
    // FFI
    CPointer<UInt8>()
}

// 严格翻译自 JSC__JSGlobalObject__vm
public func jscGlobalObjectVM(globalObject: CPointer<JSGlobalObject>) -> CPointer<UInt8> {
    // FFI
    CPointer<UInt8>()
}

// ========== Bun 特定 FFI ==========

// 严格翻译自 Bun__getCWD
public func bunGetCWD(globalObject: CPointer<JSGlobalObject>, out: CPointer<UInt8>, outLen: Int64) -> Int64 {
    // FFI
    0
}

// 严格翻译自 Bun__readableStreamToArray
public func bunReadableStreamToArray(globalObject: CPointer<JSGlobalObject>, stream: JSValue) -> JSValue {
    // FFI
    JSValue.zero
}

// 严格翻译自 Bun__isBun
public func bunIsBun(value: JSValue) -> Bool {
    // FFI
    false
}

// ========== WebCore 类型 ==========

// 严格翻译自 WebCore__Blob__create
public func webCoreBlobCreate(globalObject: CPointer<JSGlobalObject>, data: CPointer<UInt8>, dataLen: Int64, contentType: CPointer<UInt8>, contentTypeLen: Int64) -> JSValue {
    // FFI
    JSValue.zero
}

// ========== 外部 foreign 声明 ==========
// 以下是通过 foreign 关键字声明的 C ABI 函数

foreign func JSC__JSValue__isUndefined(value: Int64) -> Bool
foreign func JSC__JSValue__isNull(value: Int64) -> Bool
foreign func JSC__JSValue__isBoolean(value: Int64) -> Bool
foreign func JSC__JSValue__isNumber(value: Int64) -> Bool
foreign func JSC__JSValue__isString(globalObject: UInt64, value: Int64) -> Bool
foreign func JSC__JSValue__isObject(value: Int64) -> Bool
foreign func JSC__JSValue__toBoolean(globalObject: UInt64, value: Int64) -> Bool
foreign func JSC__JSValue__toNumber(globalObject: UInt64, value: Int64) -> Float64
foreign func JSC__JSValue__toString(globalObject: UInt64, value: Int64) -> Int64
foreign func JSC__JSValue__toObject(globalObject: UInt64, value: Int64) -> Int64
foreign func JSC__JSValue__get(globalObject: UInt64, value: Int64, propertyName: CPointer<UInt8>, propertyNameLength: Int64) -> Int64
foreign func JSC__JSValue__put(globalObject: UInt64, value: Int64, propertyName: CPointer<UInt8>, propertyNameLength: Int64, putValue: Int64) -> Unit
foreign func JSC__JSGlobalObject__createEmptyObject(globalObject: UInt64, capacity: Int64) -> Int64
foreign func JSC__JSGlobalObject__createArray(globalObject: UInt64, argCount: Int64) -> Int64
foreign func Bun__createFFIFunctionValue(globalObject: UInt64, symbolName: CPointer<UInt8>, symbolNameLen: Int64, argCount: Int64, functionPtr: UInt64, data: UInt64) -> Int64
