// FFI 对象 — 指针操作、内存读写、Reader、Buffer 转换、DOM Call 描述
// 对应 Bun: src/runtime/ffi/FFIObject.zig + FFIObject.rs
// 提供 ptr(), read(), toArrayBuffer(), toBuffer(), CString() 等指针操作
// 包含 Reader 慢路径/快路径读取器、DOM Call 描述符、字段宿主函数入口
package bao_runtime.ffi

import bao_core.*
import bao_collections.*

// ============================================================================
// 最大可寻址内存
// 对应 Bun: FFIObject.rs — MAX_ADDRESSABLE_MEMORY = (1 << 56) - 1
// ============================================================================

/// 最大可寻址内存 (u56 max = 2^56 - 1 = 72057594037927935)
/// 对应 Rust: const MAX_ADDRESSABLE_MEMORY: usize = u56_max()
private let MAX_ADDRESSABLE_MEMORY: Int64 = 72057594037927935

// ============================================================================
// ValueOrError — 指针操作结果
// 对应 Bun: FFIObject.rs — enum ValueOrError
// ============================================================================

/// 指针操作结果: 错误值或原始指针切片
/// 对应 Rust: enum ValueOrError { Err(JSValue), Slice(*mut u8, usize) }
private enum ValueOrError {
    | Err(JsValue)
    | Slice(ptr: Int64, length: Int64)
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
        match (value.valueType) {
            case JsValueType.Undefined | JsValueType.Null => return JsValue.NULL
            case _ => ()
        }

        // 从 ArrayBuffer 提取指针
        let arrayBuffer = value.asArrayBuffer(globalObject)
        match (arrayBuffer) {
            case Some(buf) => {
                if (buf.size == 0) {
                    return JsValue("ArrayBufferView must have a length > 0. A pointer to empty memory doesn't work")
                }

                var addr: Int64 = buf.ptrAddress

                // 处理偏移
                match (byteOffset) {
                    case Some(off) => {
                        if (off.valueType == JsValueType.Number) {
                            let offset = off.toNumber().toInt64()
                            if (offset < 0) {
                                addr = addr - (-offset)
                            } else {
                                addr = addr + offset
                            }

                            if (addr > buf.ptrAddress + buf.byteLength) {
                                return JsValue("byteOffset out of bounds")
                            }
                        }
                    }
                    case None => ()
                }

                // 安全检查
                if (addr > MAX_ADDRESSABLE_MEMORY) {
                    return JsValue("Pointer is outside max addressible memory, which usually means a bug in your program.")
                }
                if (addr == 0) {
                    return JsValue("Pointer must not be 0")
                }
                if (addr == 0xDEADBEEF || addr == 0xaaaaaaaa || addr == 0xAAAAAAAA) {
                    return JsValue("ptr to invalid memory, that would segfault Bun :(")
                }

                // Debug 断言: 验证地址可往返
                // 对应 Rust: debug_assert!(JSValue::from_ptr_address(addr).as_ptr_address() == addr)

                return JsValue(Float64(addr.toFloat64()))
            }
            case None => {
                return JsValue("Expected ArrayBufferView but received ${value.valueType}")
            }
        }
    }

    /// ptr 宿主函数入口 (从 CallFrame 调用)
    /// 对应 Rust: pub fn ptr(global_this, _: JSValue, arguments: &[JSValue]) -> JSValue
    public static func ptrFromCallframe(globalObject: JsObject, callframe: JsCallFrame): JsValue {
        let args = callframe.arguments(2)
        match (args.size) {
            case 0 => ptrInternal(globalObject, JsValue.ZERO, None)
            case 1 => ptrInternal(globalObject, args[0], None)
            case _ => ptrInternal(globalObject, args[0], Some(args[1]))
        }
    }

    /// ptr 内部实现
    /// 对应 Rust: fn ptr_(global_this, value, byte_offset) -> JSValue
    private static func ptrInternal(globalObject: JsObject, value: JsValue, byteOffset: ?JsValue): JsValue {
        if (value.valueType == JsValueType.Undefined || value.valueType == JsValueType.Null) {
            return JsValue.NULL
        }

        let arrayBuffer = value.asArrayBuffer(globalObject)
        match (arrayBuffer) {
            case Some(buf) => {
                if (buf.size == 0) {
                    return JsValue("ArrayBufferView must have a length > 0. A pointer to empty memory doesn't work")
                }

                var addr: Int64 = buf.ptrAddress

                match (byteOffset) {
                    case Some(off) => {
                        if (off.valueType != JsValueType.Undefined && off.valueType != JsValueType.Null) {
                            if (off.valueType != JsValueType.Number) {
                                return JsValue("Expected number for byteOffset")
                            }
                            let bytei64 = off.toNumber().toInt64()
                            if (bytei64 < 0) {
                                addr = addr - (-bytei64)
                            } else {
                                addr = addr + bytei64
                            }
                            if (addr > buf.ptrAddress + buf.byteLength) {
                                return JsValue("byteOffset out of bounds")
                            }
                        }
                    }
                    case None => ()
                }

                if (addr > MAX_ADDRESSABLE_MEMORY) {
                    return JsValue("Pointer is outside max addressible memory")
                }
                if (addr == 0) {
                    return JsValue("Pointer must not be 0")
                }
                if (addr == 0xDEADBEEF || addr == 0xaaaaaaaa || addr == 0xAAAAAAAA) {
                    return JsValue("ptr to invalid memory, that would segfault Bun :(")
                }

                return JsValue(Float64(addr.toFloat64()))
            }
            case None => {
                return JsValue("Expected ArrayBufferView")
            }
        }
    }

    // ========================================================================
    // C 字符串
    // 对应 Bun: FFIObject.rs:new_cstring / FFIObject.zig:newCString
    // ========================================================================

    /// 从指针创建 C 字符串 (JS String)
    /// 对应 Rust: pub fn new_cstring(global_this, value, byte_offset, length_value)
    public static func newCString(globalObject: JsObject, value: JsValue, byteOffset: ?JsValue, lengthValue: ?JsValue): JsValue {
        match (getPtrSlice(globalObject, value, byteOffset, lengthValue)) {
            case ValueOrError.Slice(ptr, len) => {
                // 从内存读取字节并创建 UTF-8 字符串
                let bytes = readMemory(ptr, len)
                return JsValue(String.fromUtf8(bytes))
            }
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
            case ValueOrError.Slice(ptr, len) => {
                // 处理 finalization callback
                var callback: ?Int64 = None  // deallocator 函数指针
                var ctx: ?Int64 = None        // finalization context

                match (finalizationCallback) {
                    case Some(cbValue) => {
                        let cbPtr = getCPtr(cbValue)
                        match (cbPtr) {
                            case Some(addr) => {
                                callback = Some(addr)
                                // 检查 ctx
                                match (finalizationCtx) {
                                    case Some(ctxValue) => {
                                        let ctxPtr = getCPtr(ctxValue)
                                        match (ctxPtr) {
                                            case Some(p) => ctx = Some(p)
                                            case None => {
                                                if (ctxValue.valueType != JsValueType.Undefined && ctxValue.valueType != JsValueType.Null) {
                                                    return JsValue("Expected user data to be a C pointer (number or BigInt)")
                                                }
                                            }
                                        }
                                    }
                                    case None => ()
                                }
                            }
                            case None => {
                                if (cbValue.valueType != JsValueType.Undefined && cbValue.valueType != JsValueType.Null) {
                                    return JsValue("Expected callback to be a C pointer (number or BigInt)")
                                }
                            }
                        }
                    }
                    case None => {
                        // 检查 finalizationCtx 是否作为 callback 传入
                        match (finalizationCtx) {
                            case Some(ctxValue) => {
                                let ctxPtr = getCPtr(ctxValue)
                                match (ctxPtr) {
                                    case Some(addr) => callback = Some(addr)
                                    case None => {
                                        if (ctxValue.valueType != JsValueType.Undefined && ctxValue.valueType != JsValueType.Null) {
                                            return JsValue("Expected callback to be a C pointer (number or BigInt)")
                                        }
                                    }
                                }
                            }
                            case None => ()
                        }
                    }
                }

                // 创建 ArrayBuffer 包装切片
                let slice = readMemory(ptr, len)
                // 实际实现: ArrayBuffer::from_bytes(slice, JSType::ArrayBuffer)
                //   .to_js_with_context(global, ctx, callback)
                return JsValue("ArrayBuffer(${len} bytes)")
            }
            case ValueOrError.Err(err) => err
        }
    }

    /// 从指针创建 Buffer
    /// 对应 Rust: pub fn to_buffer(global_this, value, byte_offset,
    ///   value_length, finalization_ctx_or_ptr, finalization_callback)
    public static func toBuffer(globalObject: JsObject, value: JsValue, byteOffset: ?JsValue, lengthValue: ?JsValue, finalizationCtx: ?JsValue, finalizationCallback: ?JsValue): JsValue {
        match (getPtrSlice(globalObject, value, byteOffset, lengthValue)) {
            case ValueOrError.Err(err) => err
            case ValueOrError.Slice(ptr, len) => {
                // 处理 finalization callback (同 toArrayBuffer 逻辑)
                var callback: ?Int64 = None
                var ctx: ?Int64 = None

                match (finalizationCallback) {
                    case Some(cbValue) => {
                        let cbPtr = getCPtr(cbValue)
                        match (cbPtr) {
                            case Some(addr) => {
                                callback = Some(addr)
                                match (finalizationCtx) {
                                    case Some(ctxValue) => {
                                        let ctxPtr = getCPtr(ctxValue)
                                        match (ctxPtr) {
                                            case Some(p) => ctx = Some(p)
                                            case None => {
                                                if (ctxValue.valueType != JsValueType.Undefined && ctxValue.valueType != JsValueType.Null) {
                                                    return JsValue("Expected user data to be a C pointer (number or BigInt)")
                                                }
                                            }
                                        }
                                    }
                                    case None => ()
                                }
                            }
                            case None => {
                                if (cbValue.valueType != JsValueType.Undefined && cbValue.valueType != JsValueType.Null) {
                                    return JsValue("Expected callback to be a C pointer (number or BigInt)")
                                }
                            }
                        }
                    }
                    case None => {
                        match (finalizationCtx) {
                            case Some(ctxValue) => {
                                let ctxPtr = getCPtr(ctxValue)
                                match (ctxPtr) {
                                    case Some(addr) => callback = Some(addr)
                                    case None => {
                                        if (ctxValue.valueType != JsValueType.Undefined && ctxValue.valueType != JsValueType.Null) {
                                            return JsValue("Expected callback to be a C pointer (number or BigInt)")
                                        }
                                    }
                                }
                            }
                            case None => ()
                        }
                    }
                }

                let slice = readMemory(ptr, len)

                // 有 finalization callback 时使用 create_buffer_with_ctx
                // 对应 Rust: if callback.is_some() || ctx.is_some() {
                //   create_buffer_with_ctx(global, slice, ctx, callback) }
                match (callback) {
                    case Some(_) | None => {
                        match (ctx) {
                            case Some(_) => {
                                // create_buffer_with_ctx(global, slice, ctx.unwrap_or_null, callback)
                                return JsValue("Buffer(${len} bytes)")
                            }
                            case None => {
                                // JSValue::create_buffer(global, slice)
                                return JsValue("Buffer(${len} bytes)")
                            }
                        }
                    }
                }
            }
        }
    }

    /// 从指针创建 CString Buffer (不带 finalization)
    /// 对应 Rust: pub fn to_cstring_buffer(global_this, value, byte_offset, value_length)
    public static func toCStringBuffer(globalObject: JsObject, value: JsValue, byteOffset: ?JsValue, lengthValue: ?JsValue): JsValue {
        match (getPtrSlice(globalObject, value, byteOffset, lengthValue)) {
            case ValueOrError.Err(err) => err
            case ValueOrError.Slice(ptr, len) => {
                let slice = readMemory(ptr, len)
                // create_buffer_with_ctx(global, slice, null, None)
                return JsValue("Buffer(${len} bytes)")
            }
        }
    }

    // ========================================================================
    // getPtrSlice — 从指针获取字节切片
    // 对应 Bun: FFIObject.rs:get_ptr_slice / FFIObject.zig:getPtrSlice
    // ========================================================================

    /// 从指针参数获取原始字节切片
    /// 对应 Rust: fn get_ptr_slice(global_this, value, byte_offset, byte_length) -> ValueOrError
    private static func getPtrSlice(globalObject: JsObject, value: JsValue, byteOffset: ?JsValue, byteLength: ?JsValue): ValueOrError {
        // 验证 ptr 值为正数
        if (value.valueType != JsValueType.Number || value.toNumber() < 0.0 || value.toNumber() > Float64(MAX_ADDRESSABLE_MEMORY)) {
            return ValueOrError.Err(JsValue("ptr must be a number."))
        }

        var addr = value.toNumber().toInt64()
        if (addr == 0) {
            return ValueOrError.Err(JsValue("ptr cannot be zero, that would segfault Bun :("))
        }

        // 处理偏移
        match (byteOffset) {
            case Some(byteOff) => {
                if (byteOff.valueType == JsValueType.Number) {
                    let off = byteOff.toNumber().toInt64()
                    if (off < 0) {
                        addr = addr - (-off)
                    } else {
                        addr = addr + off
                    }
                    if (addr == 0) {
                        return ValueOrError.Err(JsValue("ptr cannot be zero, that would segfault Bun :("))
                    }
                    if (!byteOff.toNumber().isFinite()) {
                        return ValueOrError.Err(JsValue("ptr must be a finite number."))
                    }
                } else if (byteOff.valueType != JsValueType.Undefined && byteOff.valueType != JsValueType.Null) {
                    return ValueOrError.Err(JsValue("Expected number for byteOffset"))
                }
            }
            case None => ()
        }

        // 安全检查
        if (addr == 0xDEADBEEF || addr == 0xaaaaaaaa || addr == 0xAAAAAAAA) {
            return ValueOrError.Err(JsValue("ptr to invalid memory, that would segfault Bun :("))
        }

        // 处理长度
        match (byteLength) {
            case Some(valueLength) => {
                if (valueLength.valueType != JsValueType.Undefined && valueLength.valueType != JsValueType.Null) {
                    if (valueLength.valueType != JsValueType.Number) {
                        return ValueOrError.Err(JsValue("length must be a number."))
                    }
                    if (valueLength.toNumber() == 0.0) {
                        return ValueOrError.Err(JsValue("length must be > 0. This usually means a bug in your code."))
                    }
                    let lengthI = valueLength.toNumber().toInt64()
                    if (lengthI < 0) {
                        return ValueOrError.Err(JsValue("length must be > 0. This usually means a bug in your code."))
                    }
                    if (lengthI > MAX_ADDRESSABLE_MEMORY) {
                        return ValueOrError.Err(JsValue("length exceeds max addressable memory. This usually means a bug in your code."))
                    }
                    return ValueOrError.Slice(addr, lengthI)
                }
            }
            case None => ()
        }

        // 无长度: 读取到 NUL 终止符 (C 字符串)
        // 对应 Rust: let len = unsafe { bun_core::ffi::cstr(addr as *const c_char) }.to_bytes().len()
        let len = strlenAtAddr(addr)
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
            let addr = value.toNumber().toInt64()
            if (addr > 0) {
                return Some(addr)
            }
        } else if (value.isBigInt()) {
            let addr = value.toUInt64NoTruncate()
            if (addr > 0) {
                return Some(Int64(addr))
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
    public class Reader {
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
                arguments[1].toNumber().toInt64()
            } else {
                0
            }
            return Some(arguments[0].toNumber().toInt64() + off)
        }

        /// 读取 u8
        /// 对应 Rust: pub fn u8(global_object, _, arguments)
        public static func readU8(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) => {
                    let value = readU8FromMemory(addr)
                    return JsValue(Float64(value.toFloat64()))
                }
                case None => return JsValue("Expected a pointer")
            }
        }

        /// 读取 u16
        public static func readU16(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) => {
                    let value = readU16FromMemory(addr)
                    return JsValue(Float64(value.toFloat64()))
                }
                case None => return JsValue("Expected a pointer")
            }
        }

        /// 读取 u32
        public static func readU32(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) => {
                    let value = readU32FromMemory(addr)
                    return JsValue(Float64(value.toFloat64()))
                }
                case None => return JsValue("Expected a pointer")
            }
        }

        /// 读取 ptr (u64)
        public static func readPtr(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) => {
                    let value = readU64FromMemory(addr)
                    return JsValue(Float64(value.toFloat64()))
                }
                case None => return JsValue("Expected a pointer")
            }
        }

        /// 读取 i8
        public static func readI8(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) => {
                    let value = readI8FromMemory(addr)
                    return JsValue(Float64(value.toFloat64()))
                }
                case None => return JsValue("Expected a pointer")
            }
        }

        /// 读取 i16
        public static func readI16(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) => {
                    let value = readI16FromMemory(addr)
                    return JsValue(Float64(value.toFloat64()))
                }
                case None => return JsValue("Expected a pointer")
            }
        }

        /// 读取 i32
        public static func readI32(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) => {
                    let value = readI32FromMemory(addr)
                    return JsValue(Float64(value.toFloat64()))
                }
                case None => return JsValue("Expected a pointer")
            }
        }

        /// 读取 i64 (返回 BigInt)
        public static func readI64(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) => {
                    let value = readI64FromMemory(addr)
                    // 对应 Rust: JSValue::from_int64_no_truncate(global_object, value)
                    return JsValue(Float64(value.toFloat64()))
                }
                case None => return JsValue("Expected a pointer")
            }
        }

        /// 读取 u64 (返回 BigInt)
        public static func readU64(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) => {
                    let value = readU64FromMemory(addr)
                    // 对应 Rust: JSValue::from_uint64_no_truncate(global_object, value)
                    return JsValue(Float64(value.toFloat64()))
                }
                case None => return JsValue("Expected a pointer")
            }
        }

        /// 读取 intptr
        public static func readIntPtr(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) => {
                    let value = readI64FromMemory(addr)
                    return JsValue(Float64(value.toFloat64()))
                }
                case None => return JsValue("Expected a pointer")
            }
        }

        /// 读取 f32
        public static func readF32(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) => {
                    let value = readF32FromMemory(addr)
                    return JsValue(Float64(value.toFloat64()))
                }
                case None => return JsValue("Expected a pointer")
            }
        }

        /// 读取 f64
        public static func readF64(globalObject: JsObject, arguments: ArrayList<JsValue>): JsValue {
            match (addrFromArgs(globalObject, arguments)) {
                case Some(addr) => {
                    let value = readF64FromMemory(addr)
                    return JsValue(value)
                }
                case None => return JsValue("Expected a pointer")
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
            return JsValue(Float64(value.toFloat64()))
        }

        /// 快路径读取 u16
        public static func readU16Fast(rawAddr: Int64, offset: Int32): JsValue {
            let addr = rawAddr + Int64(offset)
            let value = readU16FromMemory(addr)
            return JsValue(Float64(value.toFloat64()))
        }

        /// 快路径读取 u32
        public static func readU32Fast(rawAddr: Int64, offset: Int32): JsValue {
            let addr = rawAddr + Int64(offset)
            let value = readU32FromMemory(addr)
            return JsValue(Float64(value.toFloat64()))
        }

        /// 快路径读取 ptr
        public static func readPtrFast(rawAddr: Int64, offset: Int32): JsValue {
            let addr = rawAddr + Int64(offset)
            let value = readU64FromMemory(addr)
            return JsValue(Float64(value.toFloat64()))
        }

        /// 快路径读取 i8
        public static func readI8Fast(rawAddr: Int64, offset: Int32): JsValue {
            let addr = rawAddr + Int64(offset)
            let value = readI8FromMemory(addr)
            return JsValue(Float64(value.toFloat64()))
        }

        /// 快路径读取 i16
        public static func readI16Fast(rawAddr: Int64, offset: Int32): JsValue {
            let addr = rawAddr + Int64(offset)
            let value = readI16FromMemory(addr)
            return JsValue(Float64(value.toFloat64()))
        }

        /// 快路径读取 i32
        public static func readI32Fast(rawAddr: Int64, offset: Int32): JsValue {
            let addr = rawAddr + Int64(offset)
            let value = readI32FromMemory(addr)
            return JsValue(Float64(value.toFloat64()))
        }

        /// 快路径读取 i64
        public static func readI64Fast(rawAddr: Int64, offset: Int32): JsValue {
            let addr = rawAddr + Int64(offset)
            let value = readI64FromMemory(addr)
            return JsValue(Float64(value.toFloat64()))
        }

        /// 快路径读取 u64
        public static func readU64Fast(rawAddr: Int64, offset: Int32): JsValue {
            let addr = rawAddr + Int64(offset)
            let value = readU64FromMemory(addr)
            return JsValue(Float64(value.toFloat64()))
        }

        /// 快路径读取 intptr
        public static func readIntPtrFast(rawAddr: Int64, offset: Int32): JsValue {
            let addr = rawAddr + Int64(offset)
            let value = readI64FromMemory(addr)
            return JsValue(Float64(value.toFloat64()))
        }

        /// 快路径读取 f32
        public static func readF32Fast(rawAddr: Int64, offset: Int32): JsValue {
            let addr = rawAddr + Int64(offset)
            let value = readF32FromMemory(addr)
            return JsValue(Float64(value.toFloat64()))
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
        public static let DOM_CALLS: ArrayList<(String, String)> = {
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
        }()

        /// 将 Reader 对象暴露给 JS
        /// 对应 Rust: pub fn to_js(global_this) -> JSValue
        public static func toJS(globalObject: JsObject): JsValue {
            let obj = JsObject()
            // 注册各 Reader 方法
            obj.set("u8", JsValue("function u8() { [bao native] }"))
            obj.set("u16", JsValue("function u16() { [bao native] }"))
            obj.set("u32", JsValue("function u32() { [bao native] }"))
            obj.set("ptr", JsValue("function ptr() { [bao native] }"))
            obj.set("i8", JsValue("function i8() { [bao native] }"))
            obj.set("i16", JsValue("function i16() { [bao native] }"))
            obj.set("i32", JsValue("function i32() { [bao native] }"))
            obj.set("i64", JsValue("function i64() { [bao native] }"))
            obj.set("u64", JsValue("function u64() { [bao native] }"))
            obj.set("intptr", JsValue("function intptr() { [bao native] }"))
            obj.set("f32", JsValue("function f32() { [bao native] }"))
            obj.set("f64", JsValue("function f64() { [bao native] }"))
            return JsValue(obj)
        }
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
                obj.set(entry.name, JsValue("function CString() { [bao native constructor] }"))
            } else {
                obj.set(entry.name, JsValue("function ${entry.name}() { [bao native] }"))
            }
        }

        // 注册 FFI.ptr DOM Call put helper
        // 对应 Rust: unsafe { (DOM_CALL.put)(global_object, object) }
        // 实际由 C++ 侧 FFI__ptr__put 辅助函数完成

        // 注册 Reader 子对象
        obj.set("read", Reader.toJS(globalObject))

        return JsValue(obj)
    }

    // ========================================================================
    // 内存操作 — 通过 foreign 关键字对接 C 内存接口
    // ========================================================================

    /// 从内存地址读取字节
    // @C foreign func memcpy(dest: CPointer<UInt8>, src: CPointer<Unit>, n: UInt64): CPointer<UInt8>
    private static func readMemory(addr: Int64, length: Int64): Array<UInt8> {
        var bytes = ArrayList<UInt8>()
        // 占位: 实际通过仓颉 FFI 读取内存
        return bytes.toArray()
    }

    /// 读取内存直到 NUL
    private static func readMemoryUntilNull(addr: Int64): Array<UInt8> {
        var bytes = ArrayList<UInt8>()
        // 占位: 实际通过仓颉 FFI 读取内存直到遇到 NUL
        return bytes.toArray()
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

/// JsValue 扩展 — ArrayBuffer 操作
public extension JsValue {
    /// 尝试转为 ArrayBuffer 视图
    func asArrayBuffer(globalObject: JsObject): ?ArrayBufferView {
        match (valueType) {
            case Object => {
                match (objectData) {
                    case Some(obj) => {
                        let buffer = obj.get("_buffer")
                        match (buffer.valueType) {
                            case _ => return None
                        }
                    }
                    case None => return None
                }
            }
            case _ => return None
        }
    }

    /// 检查是否为 BigInt 类型
    func isBigInt(): Bool {
        // 简化: 检查是否为大整数
        return false
    }

    /// 获取 UInt64 不截断
    func toUInt64NoTruncate(): UInt64 {
        // 简化: 从 BigInt 或 Number 获取
        return UInt64(toNumber().toInt64())
    }
}

/// FfiSliceResult — 指针切片结果 (公共 API)
public enum FfiSliceResult {
    | Slice(Array<UInt8>)
    | Error(JsValue)
}
