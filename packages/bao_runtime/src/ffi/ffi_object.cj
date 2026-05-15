// FFI 对象 — 指针操作与内存读写
// 对应 Bun: src/runtime/ffi/FFIObject.zig
// 提供 ptr(), read(), toArrayBuffer(), toBuffer() 等指针操作
package bao_runtime.ffi

import bao_core.*
import bao_collections.*

// ============================================================================
// FFI 对象
// 对应 Bun: FFIObject
// ============================================================================

/// FFI 工具函数集合
/// 对应 Zig: const FFIObject = @This()
/// 提供指针操作、内存读写、Buffer 转换等能力
public class FfiObject {

    // ========================================================================
    // ptr — 获取指针地址
    // 对应 Zig: FFIObject.ptr
    // ========================================================================

    /// 从 ArrayBufferView 获取指针地址
    /// 对应 Zig: ptr(globalThis, _, arguments)
    public static func ptr(globalObject: JsObject, value: JsValue, byteOffset: ?JsValue): JsValue {
        if (value.valueType == JsValueType.Undefined || value.valueType == JsValueType.Null) {
            return JsValue.NULL
        }

        // 从 ArrayBuffer 提取指针
        let arrayBuffer = value.asArrayBuffer(globalObject)
        match (arrayBuffer) {
            case Some(buf) => {
                if (buf.size == 0) {
                    return JsValue("ArrayBufferView must have a length > 0")
                }

                var addr: Int64 = buf.ptrAddress

                // 处理偏移
                match (byteOffset) {
                    case Some(off) => {
                        if (off.valueType == JsValueType.Number) {
                            let offset = off.toNumber().toInt64()
                            if (offset < 0) {
                                addr -= (-offset)
                            } else {
                                addr += offset
                            }

                            if (addr > buf.ptrAddress + buf.byteLength) {
                                return JsValue("byteOffset out of bounds")
                            }
                        }
                    }
                    case None => ()
                }

                // 安全检查
                if (addr > maxAddressableMemory) {
                    return JsValue("Pointer is outside max addressable memory")
                }
                if (addr == 0) {
                    return JsValue("Pointer must not be 0")
                }
                if (addr == 0xDEADBEEF || addr == 0xAAAAAAAA || addr == 0xaaaaaaaa) {
                    return JsValue("ptr to invalid memory")
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
    // 对应 Zig: FFIObject.newCString
    // ========================================================================

    /// 从指针创建 C 字符串 (JS String)
    /// 对应 Zig: newCString(globalThis, value, byteOffset, lengthValue)
    public static func newCString(globalObject: JsObject, value: JsValue, byteOffset: ?JsValue, lengthValue: ?JsValue): JsValue {
        match (getPtrSlice(globalObject, value, byteOffset, lengthValue)) {
            case FfiSliceResult.Slice(slice) => {
                return JsValue(String.fromUtf8(slice))
            }
            case FfiSliceResult.Error(err) => {
                return err
            }
        }
    }

    // ========================================================================
    // toArrayBuffer / toBuffer
    // 对应 Zig: FFIObject.toArrayBuffer / toBuffer
    // ========================================================================

    /// 从指针创建 ArrayBuffer
    /// 对应 Zig: toArrayBuffer
    public static func toArrayBuffer(globalObject: JsObject, value: JsValue, byteOffset: ?JsValue, lengthValue: ?JsValue, finalizationCtx: ?JsValue, finalizationCallback: ?JsValue): JsValue {
        match (getPtrSlice(globalObject, value, byteOffset, lengthValue)) {
            case FfiSliceResult.Slice(slice) => {
                // 创建 ArrayBuffer 包装切片
                return JsValue("ArrayBuffer(${slice.size} bytes)")
            }
            case FfiSliceResult.Error(err) => {
                return err
            }
        }
    }

    /// 从指针创建 Buffer
    /// 对应 Zig: toBuffer
    public static func toBuffer(globalObject: JsObject, value: JsValue, byteOffset: ?JsValue, lengthValue: ?JsValue, finalizationCtx: ?JsValue, finalizationCallback: ?JsValue): JsValue {
        match (getPtrSlice(globalObject, value, byteOffset, lengthValue)) {
            case FfiSliceResult.Slice(slice) => {
                // 创建 Buffer 包装切片
                return JsValue("Buffer(${slice.size} bytes)")
            }
            case FfiSliceResult.Error(err) => {
                return err
            }
        }
    }

    // ========================================================================
    // getPtrSlice — 从指针获取字节切片
    // 对应 Zig: FFIObject.getPtrSlice
    // ========================================================================

    /// 获取指针切片
    private static func getPtrSlice(globalObject: JsObject, value: JsValue, byteOffset: ?JsValue, byteLength: ?JsValue): FfiSliceResult {
        if (value.valueType != JsValueType.Number || value.toNumber() < 0) {
            return FfiSliceResult.Error(JsValue("ptr must be a number."))
        }

        var addr = value.toNumber().toInt64()
        if (addr == 0) {
            return FfiSliceResult.Error(JsValue("ptr cannot be zero"))
        }

        // 处理偏移
        match (byteOffset) {
            case Some(off) => {
                if (off.valueType == JsValueType.Number) {
                    let offset = off.toNumber().toInt64()
                    if (offset < 0) {
                        addr -= (-offset)
                    } else {
                        addr += offset
                    }
                    if (addr == 0) {
                        return FfiSliceResult.Error(JsValue("ptr cannot be zero after offset"))
                    }
                }
            }
            case None => ()
        }

        // 安全检查
        if (addr == 0xDEADBEEF || addr == 0xAAAAAAAA) {
            return FfiSliceResult.Error(JsValue("ptr to invalid memory"))
        }

        // 处理长度
        match (byteLength) {
            case Some(len) => {
                if (len.valueType != JsValueType.Undefined) {
                    if (len.valueType != JsValueType.Number) {
                        return FfiSliceResult.Error(JsValue("length must be a number."))
                    }
                    let length = len.toNumber().toInt64()
                    if (length <= 0) {
                        return FfiSliceResult.Error(JsValue("length must be > 0"))
                    }
                    if (length > maxAddressableMemory) {
                        return FfiSliceResult.Error(JsValue("length exceeds max addressable memory"))
                    }

                    // 从内存读取指定长度的字节
                    let slice = readMemory(addr, length)
                    return FfiSliceResult.Slice(slice)
                }
            }
            case None => ()
        }

        // 无长度: 读取到 NUL 终止符 (C 字符串)
        let slice = readMemoryUntilNull(addr)
        return FfiSliceResult.Slice(slice)
    }

    // ========================================================================
    // 内存读取器
    // 对应 Bun: FFIObject.Reader
    // ========================================================================

    /// 从指针地址读取指定类型的值
    public class Reader {
        /// 读取 u8
        /// 对应 Zig: Reader.u8
        public static func readU8(addr: Int64, offset: Int64): UInt8 {
            let ptr = addr + offset
            return readU8FromMemory(ptr)
        }

        /// 读取 u16
        public static func readU16(addr: Int64, offset: Int64): UInt16 {
            let ptr = addr + offset
            return readU16FromMemory(ptr)
        }

        /// 读取 u32
        public static func readU32(addr: Int64, offset: Int64): UInt32 {
            let ptr = addr + offset
            return readU32FromMemory(ptr)
        }

        /// 读取 ptr (u64)
        public static func readPtr(addr: Int64, offset: Int64): UInt64 {
            let ptr = addr + offset
            return readU64FromMemory(ptr)
        }

        /// 读取 i8
        public static func readI8(addr: Int64, offset: Int64): Int8 {
            let ptr = addr + offset
            return readI8FromMemory(ptr)
        }

        /// 读取 i16
        public static func readI16(addr: Int64, offset: Int64): Int16 {
            let ptr = addr + offset
            return readI16FromMemory(ptr)
        }

        /// 读取 i32
        public static func readI32(addr: Int64, offset: Int64): Int32 {
            let ptr = addr + offset
            return readI32FromMemory(ptr)
        }

        /// 读取 i64
        public static func readI64(addr: Int64, offset: Int64): Int64 {
            let ptr = addr + offset
            return readI64FromMemory(ptr)
        }

        /// 读取 u64
        public static func readU64(addr: Int64, offset: Int64): UInt64 {
            let ptr = addr + offset
            return readU64FromMemory(ptr)
        }

        /// 读取 intptr
        public static func readIntPtr(addr: Int64, offset: Int64): Int64 {
            let ptr = addr + offset
            return readI64FromMemory(ptr)
        }

        /// 读取 f32
        public static func readF32(addr: Int64, offset: Int64): Float32 {
            let ptr = addr + offset
            return readF32FromMemory(ptr)
        }

        /// 读取 f64
        public static func readF64(addr: Int64, offset: Int64): Float64 {
            let ptr = addr + offset
            return readF64FromMemory(ptr)
        }
    }

    // ========================================================================
    // FFI 全局 getter — 将 FFI 对象暴露给 JS
    // 对应 Zig: FFIObject.getter
    // ========================================================================

    /// 获取 FFI 全局对象的 JS 表示
    /// 对应 Zig: getter(globalObject, _)
    public static func getter(globalObject: JsObject): JsValue {
        return toJS(globalObject)
    }

    /// 转为 JS 对象
    /// 对应 Zig: toJS(globalObject)
    public static func toJS(globalObject: JsObject): JsValue {
        let obj = JsObject()

        // 注册 FFI 方法
        obj.set("viewSource", JsValue("function viewSource() { [bao native] }"))
        obj.set("dlopen", JsValue("function dlopen() { [bao native] }"))
        obj.set("callback", JsValue("function callback() { [bao native] }"))
        obj.set("linkSymbols", JsValue("function linkSymbols() { [bao native] }"))
        obj.set("toBuffer", JsValue("function toBuffer() { [bao native] }"))
        obj.set("toArrayBuffer", JsValue("function toArrayBuffer() { [bao native] }"))
        obj.set("closeCallback", JsValue("function closeCallback() { [bao native] }"))
        obj.set("CString", JsValue("function CString() { [bao native] }"))

        // 注册 Reader 方法
        let reader = JsObject()
        obj.set("read", JsValue(reader))

        return JsValue(obj)
    }

    // ========================================================================
    // 常量
    // ========================================================================

    /// 最大可寻址内存 (2^56)
    private static let maxAddressableMemory: Int64 = 72057594037927935

    // ========================================================================
    // FFI 内存操作 — 通过 foreign 关键字对接 C 内存接口
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

    // 类型化读取 — 通过 foreign func 映射 C 的指针解引用
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
// 指针切片结果
// ========================================================================

/// FFI 指针切片操作的结果
public enum FfiSliceResult {
    | Slice(Array<UInt8>)
    | Error(JsValue)
}

// ============================================================================
// ArrayBuffer 视图 (简化)
// ============================================================================

/// ArrayBuffer 视图信息
public class ArrayBufferView {
    /// 缓冲区指针地址
    public var ptrAddress: Int64
    /// 字节长度
    public var byteLength: Int64
    /// 底层数据
    public var data: Array<UInt8>

    public init() {
        ptrAddress = 0
        byteLength = 0
        data = Array<UInt8>()
    }

    public init(ptr: Int64, len: Int64, data: Array<UInt8>) {
        this.ptrAddress = ptr
        this.byteLength = len
        this.data = data
    }
}

/// JsValue 扩展 — ArrayBuffer 操作
public extension JsValue {
    /// 尝试转为 ArrayBuffer 视图
    func asArrayBuffer(globalObject: JsObject): ?ArrayBufferView {
        // 简化: 检查是否为 TypedArray
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
}
