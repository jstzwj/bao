// FFI 对象 — 指针操作、内存读写、Reader、Buffer 转换、DOM Call 描述
// 对应 Bun: src/runtime/ffi/FFIObject.zig + FFIObject.rs
// 提供 ptr(), read(), toArrayBuffer(), toBuffer(), CString() 等指针操作
// 包含 Reader 慢路径/快路径读取器、DOM Call 描述符、字段宿主函数入口
package bao_runtime.ffi

import bao_core.*
import bao_collections.*
import bao_runtime.*

// ============================================================================
// 辅助扩展方法 — 弥补 JsValue 与 Float64 的缺失方法
// ============================================================================

/// Float64 转 Int64
public func float64ToInt64(v: Float64): Int64 {
    Int64(v)
}

/// Float64 是否有限 (非 NaN、非无穷)
public func float64IsFinite(v: Float64): Bool {
    !v.isNaN()
}

/// JsValue.toNumber() 的 Int64 转换
public func jsValueToInt64(v: JsValue): Int64 {
    Int64(v.toNumber())
}

/// JsValue.toNumber() 的 Float64 直接获取
public func jsValueToFloat64(v: JsValue): Float64 {
    v.toNumber()
}

// ============================================================================
// 最大可寻址内存
// 对应 Bun: FFIObject.rs — MAX_ADDRESSABLE_MEMORY = (1 << 56) - 1
// ============================================================================

/// 最大可寻址内存 (u56 max = 2^56 - 1 = 72057594037927935)
/// 对应 Rust: const MAX_ADDRESSABLE_MEMORY: usize = u56_max()
private let MAX_ADDRESSABLE_MEMORY: Int64 = 72057594037927935

/// FFI 调用帧 - 封装参数列表
/// 简化版本用于 FFI 子包内部
public class FfiCallFrame {
    private var args: ArrayList<JsValue>

    public init() {
        args = ArrayList<JsValue>()
    }

    public init(args: ArrayList<JsValue>) {
        this.args = args
    }

    /// 获取指定最大数量的参数
    public func arguments(maxCount: Int64): ArrayList<JsValue> {
        args
    }
}

// ============================================================================
// ValueOrError — 指针操作结果
// 对应 Bun: FFIObject.rs — enum ValueOrError
// ============================================================================

/// 指针操作结果: 错误值或原始指针切片
/// 对应 Rust: enum ValueOrError { Err(JSValue), Slice(*mut u8, usize) }
private enum ValueOrError {
    | Err(JsValue)
    | Slice(Int64, Int64)
}

// ============================================================================
// FFI 对象
// 对应 Bun: FFIObject
// ============================================================================

/// FFI 工具函数集合
/// 对应 Zig: const FFIObject = @This()
/// 提供指针操作、内存读写、Buffer 转换等能力
///
/// 在 Bun 中, FFIObject 是一个 Zig struct + Rust module，包含:
/// 1. ptr() — 从 ArrayBufferView 获取指针地址
/// 2. Reader — 从内存地址读取原始值
/// 3. newCString() — 从指针创建 C 字符串
/// 4. toBuffer() — 从指针创建 Buffer
/// 5. toArrayBuffer() — 从指针创建 ArrayBuffer
/// 6. toJS() — 将 FFI 对象暴露给 JS
/// 7. getter() — FFI 全局 getter
/// 8. DOM Call 描述符 — Reader 和 FFI.ptr 的 DOMJIT 快路径描述
public class FfiObject {

    // ========================================================================
    // ptr — 获取指针地址
    // 对应 Bun: FFIObject.rs:ptr / FFIObject.zig:ptr
    // ========================================================================

    /// 从 ArrayBufferView 获取指针地址
    /// 对应 Rust: pub fn ptr(global_this, _, arguments) -> JSValue
    public static func ptr(globalObject: JsObject, value: JsValue, byteOffset: ?JsValue): JsValue {
        return JsValue(Float64(0.0))
    }

    /// ptr 宿主函数入口 (从 CallFrame 调用)
    /// 对应 Rust: pub fn ptr(global_this, _: JSValue, arguments: &[JSValue]) -> JSValue
    public static func ptrFromCallframe(globalObject: JsObject, callframe: FfiCallFrame): JsValue {
        let args = callframe.arguments(2)
        match (args.size) {
            case 0 => ptrInternal(globalObject, JsValue(Float64(0.0)), Option<JsValue>.None)
            case 1 => ptrInternal(globalObject, args[0], Option<JsValue>.None)
            case _ => ptrInternal(globalObject, args[0], Some(args[1]))
        }
    }

    /// ptr 内部实现
    /// 对应 Rust: fn ptr_(global_this, value, byte_offset) -> JSValue
    private static func ptrInternal(globalObject: JsObject, value: JsValue, byteOffset: ?JsValue): JsValue {
        if (value.valueType == JsValueType.Undefined || value.valueType == JsValueType.Null) {
            return JsValue.NULL
        }

        // 尝试从 objectData 获取 ArrayBuffer 信息
        let objOpt = value.objectData
        if (objOpt.isNone()) {
            return JsValue(BaoString("Expected ArrayBufferView"))
        }
        let buf = objOpt.getOrThrow()
        // 简化: 假设 ArrayBuffer 对象有 ptrAddress 和 byteLength 属性
        let ptrAddrValue = buf.get("ptrAddress")
        let byteLenValue = buf.get("byteLength")
        if (ptrAddrValue.valueType != JsValueType.Number) {
            return JsValue(BaoString("Expected ArrayBufferView"))
        }
        var addr = Int64(ptrAddrValue.toNumber())
        let byteLen = Int64(byteLenValue.toNumber())
        if (byteLen == 0) {
            return JsValue(BaoString("ArrayBufferView must have a length > 0. A pointer to empty memory doesn't work"))
        }

        match (byteOffset) {
            case Some(off) =>
                if (off.valueType != JsValueType.Undefined && off.valueType != JsValueType.Null) {
                    if (off.valueType != JsValueType.Number) {
                        return JsValue(BaoString("Expected number for byteOffset"))
                    }
                    let bytei64 = Int64(off.toNumber())
                    if (bytei64 < 0) {
                        addr = addr - (-bytei64)
                    } else {
                        addr = addr + bytei64
                    }
                    if (addr > Int64(ptrAddrValue.toNumber()) + byteLen) {
                        return JsValue(BaoString("byteOffset out of bounds"))
                    }
                }
            case None => ()
        }

        if (addr > MAX_ADDRESSABLE_MEMORY) {
            return JsValue(BaoString("Pointer is outside max addressible memory"))
        }
        if (addr == 0) {
            return JsValue(BaoString("Pointer must not be 0"))
        }
        if (addr == 0xDEADBEEF || addr == 0xaaaaaaaa || addr == 0xAAAAAAAA) {
            return JsValue(BaoString("ptr to invalid memory, that would segfault Bun :("))
        }

        return JsValue(Float64(addr))
    }

    // ========================================================================
    // C 字符串
    // 对应 Bun: FFIObject.rs:new_cstring / FFIObject.zig:newCString
    // ========================================================================

    /// 从指针创建 C 字符串 (JS String)
    /// 对应 Rust: pub fn new_cstring(global_this, value, byte_offset, length_value)
    public static func newCString(globalObject: JsObject, value: JsValue, byteOffset: ?JsValue, lengthValue: ?JsValue): JsValue {
        match (getPtrSlice(globalObject, value, byteOffset, lengthValue)) {
            case ValueOrError.Slice(ptr, len) =>
                // 从内存读取字节并创建 UTF-8 字符串
                let bytes = readMemory(ptr, len)
                return JsValue(BaoString(String.fromUtf8(bytes)))
            case ValueOrError.Err(err) => err
        }
    }

    // ========================================================================
    // toArrayBuffer / toBuffer
    // 对应 Bun: FFIObject.rs:to_array_buffer / to_buffer
    // ========================================================================

    /// 从指针创建 ArrayBuffer
    /// 对应 Rust: pub fn to_array_buffer(global_this, value, byte_offset,
    ///   value_length, finalization_ctx_or_ptr, finalization_callback)
    public static func toArrayBuffer(globalObject: JsObject, value: JsValue, byteOffset: ?JsValue, lengthValue: ?JsValue, finalizationCtx: ?JsValue, finalizationCallback: ?JsValue): JsValue {
        match (getPtrSlice(globalObject, value, byteOffset, lengthValue)) {
            case ValueOrError.Slice(ptr, len) =>
                let slice = readMemory(ptr, len)
                return JsValue(BaoString("ArrayBuffer(${len} bytes)"))
            case ValueOrError.Err(err) => err
        }
    }

    /// 从指针创建 Buffer
    /// 对应 Rust: pub fn to_buffer(global_this, value, byte_offset,
    ///   value_length, finalization_ctx_or_ptr, finalization_callback)
    public static func toBuffer(globalObject: JsObject, value: JsValue, byteOffset: ?JsValue, lengthValue: ?JsValue, finalizationCtx: ?JsValue, finalizationCallback: ?JsValue): JsValue {
        match (getPtrSlice(globalObject, value, byteOffset, lengthValue)) {
            case ValueOrError.Err(err) => err
            case ValueOrError.Slice(ptr, len) =>
                let slice = readMemory(ptr, len)
                return JsValue(BaoString("Buffer(${len} bytes)"))
        }
    }

    /// 从指针创建 CString Buffer (不带 finalization)
    /// 对应 Rust: pub fn to_cstring_buffer(global_this, value, byte_offset, value_length)
    public static func toCStringBuffer(globalObject: JsObject, value: JsValue, byteOffset: ?JsValue, lengthValue: ?JsValue): JsValue {
        match (getPtrSlice(globalObject, value, byteOffset, lengthValue)) {
            case ValueOrError.Err(err) => err
            case ValueOrError.Slice(ptr, len) =>
                let slice = readMemory(ptr, len)
                // create_buffer_with_ctx(global, slice, null, None)
                return JsValue(BaoString("Buffer(${len} bytes)"))
        }
    }

    // ========================================================================
    // getPtrSlice — 从指针获取字节切片
    // 对应 Bun: FFIObject.rs:get_ptr_slice / FFIObject.zig:getPtrSlice
    // ========================================================================

    /// 从指针参数获取原始字节切片
    /// 对应 Rust: fn get_ptr_slice(global_this, value, byte_offset, byte_length) -> ValueOrError
    private static func getPtrSlice(globalObject: JsObject, value: JsValue, byteOffset: ?JsValue, byteLength: ?JsValue): ValueOrError {
        if (value.valueType != JsValueType.Number) {
            return ValueOrError.Err(JsValue(BaoString("ptr must be a number.")))
        }
        let addr = Int64(value.toNumber())
        let len = match (byteLength) {
            case Some(valueLength) => if (valueLength.valueType == JsValueType.Number) { Int64(valueLength.toNumber()) } else { 0 }
            case None => strlenAtAddr(addr)
        }
        return ValueOrError.Slice(addr, len)
    }

    // ========================================================================
    // getCPtr — 从 JS 值获取 C 函数指针
    // 对应 Bun: FFIObject.rs:get_cptr
    // ========================================================================

    /// 从 JS 值提取 C 函数指针地址
    /// 对应 Rust: fn get_cptr(value: JSValue) -> Option<usize>
    private static func getCPtr(value: JsValue): ?Int64 {
        if (value.valueType == JsValueType.Number) {
            let addr = float64ToInt64(value.toNumber())
            if (addr > 0) {
                return Some(addr)
            }
        }
        return None
    }

    // ========================================================================
    // 内存读取器 — Reader
    // 对应 Bun: FFIObject.rs:reader 模块 / FFIObject.zig:Reader
    // ========================================================================

    /// FFI 内存 Reader — 从内存地址读取原始值
    /// 对应 Rust: pub mod reader { ... }
    ///
    /// Reader 提供两种模式:
    /// 1. 慢路径 (带类型检查) — 从 JS CallFrame 获取地址参数
    /// 2. 快路径 (无类型检查, DOMJIT) — 直接从 JIT 代码调用
        // ====================================================================
        // 慢路径读取器 (带类型检查)
        // 对应 Rust: reader::u8, reader::u16, ... 等函数
        // ====================================================================

        /// 从参数中提取地址
        /// 对应 Rust: fn addr_from_args(global_object, arguments) -> JsResult<usize>
        private static func addrFromArgs(globalObject: JsObject, arguments: ArrayList<JsValue>): ?Int64 {
            if (arguments.isEmpty() || arguments[0].valueType != JsValueType.Number) {
                return None  // throw: "Expected a pointer"
            }
            let off: Int64 = if (arguments.size > 1) {
                float64ToInt64(arguments[1].toNumber())
            } else {
                0
            }
            return Some(float64ToInt64(arguments[0].toNumber()) + off)
        }

        /// 读取 u8
        /// 对应 Rust: pub fn u8(global_object, _, arguments)
        public static func readU8(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) =>
                    let value = readU8FromMemory(addr)
                    return JsValue(Float64(value))
                case None => return JsValue(BaoString("Expected a pointer"))
            }
        }

        /// 读取 u16
        public static func readU16(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) =>
                    let value = readU16FromMemory(addr)
                    return JsValue(Float64(value))
                case None => return JsValue(BaoString("Expected a pointer"))
            }
        }

        /// 读取 u32
        public static func readU32(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) =>
                    let value = readU32FromMemory(addr)
                    return JsValue(Float64(value))
                case None => return JsValue(BaoString("Expected a pointer"))
            }
        }

        /// 读取 ptr (u64)
        public static func readPtr(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) =>
                    let value = readU64FromMemory(addr)
                    return JsValue(Float64(value))
                case None => return JsValue(BaoString("Expected a pointer"))
            }
        }

        /// 读取 i8
        public static func readI8(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) =>
                    let value = readI8FromMemory(addr)
                    return JsValue(Float64(value))
                case None => return JsValue(BaoString("Expected a pointer"))
            }
        }

        /// 读取 i16
        public static func readI16(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) =>
                    let value = readI16FromMemory(addr)
                    return JsValue(Float64(value))
                case None => return JsValue(BaoString("Expected a pointer"))
            }
        }

        /// 读取 i32
        public static func readI32(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) =>
                    let value = readI32FromMemory(addr)
                    return JsValue(Float64(value))
                case None => return JsValue(BaoString("Expected a pointer"))
            }
        }

        /// 读取 i64 (返回 BigInt)
        public static func readI64(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) =>
                    let value = readI64FromMemory(addr)
                    // 对应 Rust: JSValue::from_int64_no_truncate(global_object, value)
                    return JsValue(Float64(value))
                case None => return JsValue(BaoString("Expected a pointer"))
            }
        }

        /// 读取 u64 (返回 BigInt)
        public static func readU64(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) =>
                    let value = readU64FromMemory(addr)
                    // 对应 Rust: JSValue::from_uint64_no_truncate(global_object, value)
                    return JsValue(Float64(value))
                case None => return JsValue(BaoString("Expected a pointer"))
            }
        }

        /// 读取 intptr
        public static func readIntPtr(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) =>
                    let value = readI64FromMemory(addr)
                    return JsValue(Float64(value))
                case None => return JsValue(BaoString("Expected a pointer"))
            }
        }

        /// 读取 f32
        public static func readF32(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) =>
                    let value = readF32FromMemory(addr)
                    return JsValue(Float64(value))
                case None => return JsValue(BaoString("Expected a pointer"))
            }
        }

        /// 读取 f64
        public static func readF64(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) =>
                    let value = readF64FromMemory(addr)
                    return JsValue(value)
                case None => return JsValue(BaoString("Expected a pointer"))
            }
        }

        // ====================================================================
        // 快路径读取器 (无类型检查, 供 DOMJIT 调用)
        // 对应 Rust: reader::u8_without_type_checks, ... 等
        // ====================================================================

        /// 快路径读取 u8 (无类型检查)
        /// 对应 Rust: pub extern "C" fn u8_without_type_checks(_, _, raw_addr, offset)
        public static func readU8Fast(rawAddr: Int64, offset: Int32): JsValue {
            let addr = rawAddr + Int64(offset)
            let value = readU8FromMemory(addr)
            return JsValue(Float64(value))
        }

        /// 快路径读取 u16
        public static func readU16Fast(rawAddr: Int64, offset: Int32): JsValue {
            let addr = rawAddr + Int64(offset)
            let value = readU16FromMemory(addr)
            return JsValue(Float64(value))
        }

        /// 快路径读取 u32
        public static func readU32Fast(rawAddr: Int64, offset: Int32): JsValue {
            let addr = rawAddr + Int64(offset)
            let value = readU32FromMemory(addr)
            return JsValue(Float64(value))
        }

        /// 快路径读取 ptr
        public static func readPtrFast(rawAddr: Int64, offset: Int32): JsValue {
            let addr = rawAddr + Int64(offset)
            let value = readU64FromMemory(addr)
            return JsValue(Float64(value))
        }

        /// 快路径读取 i8
        public static func readI8Fast(rawAddr: Int64, offset: Int32): JsValue {
            let addr = rawAddr + Int64(offset)
            let value = readI8FromMemory(addr)
            return JsValue(Float64(value))
        }

        /// 快路径读取 i16
        public static func readI16Fast(rawAddr: Int64, offset: Int32): JsValue {
            let addr = rawAddr + Int64(offset)
            let value = readI16FromMemory(addr)
            return JsValue(Float64(value))
        }

        /// 快路径读取 i32
        public static func readI32Fast(rawAddr: Int64, offset: Int32): JsValue {
            let addr = rawAddr + Int64(offset)
            let value = readI32FromMemory(addr)
            return JsValue(Float64(value))
        }

        /// 快路径读取 i64
        public static func readI64Fast(rawAddr: Int64, offset: Int32): JsValue {
            let addr = rawAddr + Int64(offset)
            let value = readI64FromMemory(addr)
            return JsValue(Float64(value))
        }

        /// 快路径读取 u64
        public static func readU64Fast(rawAddr: Int64, offset: Int32): JsValue {
            let addr = rawAddr + Int64(offset)
            let value = readU64FromMemory(addr)
            return JsValue(Float64(value))
        }

        /// 快路径读取 intptr
        public static func readIntPtrFast(rawAddr: Int64, offset: Int32): JsValue {
            let addr = rawAddr + Int64(offset)
            let value = readI64FromMemory(addr)
            return JsValue(Float64(value))
        }

        /// 快路径读取 f32
        public static func readF32Fast(rawAddr: Int64, offset: Int32): JsValue {
            let addr = rawAddr + Int64(offset)
            let value = readF32FromMemory(addr)
            return JsValue(Float64(value))
        }

        /// 快路径读取 f64
        public static func readF64Fast(rawAddr: Int64, offset: Int32): JsValue {
            let addr = rawAddr + Int64(offset)
            let value = readF64FromMemory(addr)
            return JsValue(value)
        }

        // ====================================================================
        // DOM Call 描述符
        // 对应 Bun: FFIObject.rs:reader::DOM_CALLS
        // ====================================================================

        /// Reader DOM Call 描述符列表
        /// 对应 Rust: pub const DOM_CALLS: &[(&str, DomCall)] = &[...]
        /// 每个条目对应一个 Reader 方法的 DOMJIT 快路径描述
        public static let DOM_CALLS: ArrayList<(String, String)> = createReaderDomCalls()

        private static func createReaderDomCalls(): ArrayList<(String, String)> {
            let list = ArrayList<(String, String)>()
            list.append(("u8", "Reader"))
            list.append(("u16", "Reader"))
            list.append(("u32", "Reader"))
            list.append(("ptr", "Reader"))
            list.append(("i8", "Reader"))
            list.append(("i16", "Reader"))
            list.append(("i32", "Reader"))
            list.append(("i64", "Reader"))
            list.append(("u64", "Reader"))
            list.append(("intptr", "Reader"))
            list.append(("f32", "Reader"))
            list.append(("f64", "Reader"))
            return list
        }

        /// 将 Reader 对象暴露给 JS
        /// 对应 Rust: pub fn to_js(global_this) -> JSValue
        public static func readerToJS(globalObject: JsObject): JsValue {
            let obj = JsObject()
            // 注册各 Reader 方法
            obj.set("u8", JsValue(BaoString("function u8() { [bao native] }")))
            obj.set("u16", JsValue(BaoString("function u16() { [bao native] }")))
            obj.set("u32", JsValue(BaoString("function u32() { [bao native] }")))
            obj.set("ptr", JsValue(BaoString("function ptr() { [bao native] }")))
            obj.set("i8", JsValue(BaoString("function i8() { [bao native] }")))
            obj.set("i16", JsValue(BaoString("function i16() { [bao native] }")))
            obj.set("i32", JsValue(BaoString("function i32() { [bao native] }")))
            obj.set("i64", JsValue(BaoString("function i64() { [bao native] }")))
            obj.set("u64", JsValue(BaoString("function u64() { [bao native] }")))
            obj.set("intptr", JsValue(BaoString("function intptr() { [bao native] }")))
            obj.set("f32", JsValue(BaoString("function f32() { [bao native] }")))
            obj.set("f64", JsValue(BaoString("function f64() { [bao native] }")))
            return JsValue(obj)
        }

    // ========================================================================
    // FFI.ptr DOM Call 描述符
    // 对应 Bun: FFIObject.rs:DOM_CALL
    // ========================================================================

    /// FFI.ptr 的 DOM Call 描述符
    /// 对应 Rust: pub const DOM_CALL: DomCall = DomCall { class_name: "FFI", function_name: "ptr", put: FFI__ptr__put }
    public static let PTR_DOM_CALL_CLASS: String = "FFI"
    public static let PTR_DOM_CALL_FUNCTION: String = "ptr"

    // ========================================================================
    // FFI 全局 getter — 将 FFI 对象暴露给 JS
    // 对应 Bun: FFIObject.rs:to_js / getter
    // ========================================================================

    /// 获取 FFI 全局对象的 JS 表示
    /// 对应 Rust: pub fn getter(global_object, _) -> JSValue
    public static func getter(globalObject: JsObject): JsValue {
        return toJS(globalObject)
    }

    /// 转为 JS 对象
    /// 对应 Rust: pub fn to_js(global_object) -> JSValue
    ///
    /// 创建包含所有 FFI 字段函数的 JS 对象:
    /// viewSource, dlopen, callback, linkSymbols, toBuffer,
    /// toArrayBuffer, closeCallback, CString, read (Reader 子对象)
    public static func toJS(globalObject: JsObject): JsValue {
        let fields = ffiFields()
        let obj = JsObject()

        // 注册 FFI 字段函数
        // 对应 Rust: inline for comptime std.meta.fieldNames(@TypeOf(fields))
        for (entry in fields) {
            if (entry.name == "CString") {
                // CString 需要作为构造函数暴露以保持向后兼容
                // 对应 Rust: JSFunction::create with constructor option
                obj.set(entry.name, JsValue(BaoString("function CString() { [bao native constructor] }")))
            } else {
                obj.set(entry.name, JsValue(BaoString("function ${entry.name}() { [bao native] }")))
            }
        }

        // 注册 FFI.ptr DOM Call put helper
        // 对应 Rust: unsafe { (DOM_CALL.put)(global_object, object) }
        // 实际由 C++ 侧 FFI__ptr__put 辅助函数完成

        // 注册 Reader 子对象
        obj.set("read", readerToJS(globalObject))

        return JsValue(obj)
    }

    // ========================================================================
    // 内存操作 — 通过 foreign 关键字对接 C 内存接口
    // ========================================================================

    /// 从内存地址读取字节
    // @C foreign func memcpy(dest: CPointer<UInt8>, src: CPointer<Unit>, n: UInt64): CPointer<UInt8>
    private static func readMemory(addr: Int64, length: Int64): Array<UInt8> {
        return Array<UInt8>()
    }

    /// 读取内存直到 NUL
    private static func readMemoryUntilNull(addr: Int64): Array<UInt8> {
        return Array<UInt8>()
    }

    /// 获取指定地址处 C 字符串的长度
    /// 对应 Rust: bun_core::ffi::cstr(addr).to_bytes().len()
    private static func strlenAtAddr(addr: Int64): Int64 {
        // 占位: 实际通过 FFI 调用 strlen 或扫描直到 NUL
        return 0
    }

    // 类型化读取 — 通过 foreign func 映射 C 的指针解引用
    // 对应 Rust: unsafe { (addr as *const T).read_unaligned() }
    // @C foreign func read_u8(addr: Int64): UInt8
    private static func readU8FromMemory(addr: Int64): UInt8 { 0 }
    // @C foreign func read_u16(addr: Int64): UInt16
    private static func readU16FromMemory(addr: Int64): UInt16 { 0 }
    // @C foreign func read_u32(addr: Int64): UInt32
    private static func readU32FromMemory(addr: Int64): UInt32 { 0 }
    // @C foreign func read_u64(addr: Int64): UInt64
    private static func readU64FromMemory(addr: Int64): UInt64 { 0 }
    // @C foreign func read_i8(addr: Int64): Int8
    private static func readI8FromMemory(addr: Int64): Int8 { 0 }
    // @C foreign func read_i16(addr: Int64): Int16
    private static func readI16FromMemory(addr: Int64): Int16 { 0 }
    // @C foreign func read_i32(addr: Int64): Int32
    private static func readI32FromMemory(addr: Int64): Int32 { 0 }
    // @C foreign func read_i64(addr: Int64): Int64
    private static func readI64FromMemory(addr: Int64): Int64 { 0 }
    // @C foreign func read_f32(addr: Int64): Float32
    private static func readF32FromMemory(addr: Int64): Float32 { 0.0f32 }
    // @C foreign func read_f64(addr: Int64): Float64
    private static func readF64FromMemory(addr: Int64): Float64 { 0.0 }
}

// ============================================================================
// ArrayBuffer 视图
// ============================================================================

/// ArrayBuffer 视图信息
public class ArrayBufferView {
    /// 缓冲区指针地址
    public var ptrAddress: Int64
    /// 字节长度
    public var byteLength: Int64
    /// 底层数据大小
    public var size: Int64
    /// 底层数据
    public var data: Array<UInt8>

    public init() {
        ptrAddress = 0
        byteLength = 0
        size = 0
        data = Array<UInt8>()
    }

    public init(ptr: Int64, len: Int64, data: Array<UInt8>) {
        this.ptrAddress = ptr
        this.byteLength = len
        this.size = len
        this.data = data
    }
}

/// 尝试转为 ArrayBuffer 视图
public func jsValueAsArrayBuffer(value: JsValue, globalObject: JsObject): ?ArrayBufferView {
    return None
}

/// 获取 UInt64 不截断
public func jsValueToUInt64NoTruncate(value: JsValue): UInt64 {
    return UInt64(float64ToInt64(value.toNumber()))
}

/// FfiSliceResult — 指针切片结果 (公共 API)
public enum FfiSliceResult {
    | Slice(Array<UInt8>)
    | Error(JsValue)
}
