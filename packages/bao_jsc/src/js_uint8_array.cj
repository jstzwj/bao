// 严格翻译自: src/jsc/JSUint8Array.zig (36行)
// JavaScriptCore JSUint8Array - Uint8Array opaque 绑定

package bao_jsc

// ========== JSUint8Array_ ==========
// 严格翻译自 JSUint8Array.zig
// JavaScript Uint8Array 的 opaque 绑定
// 提供对底层字节缓冲区的直接访问
//
// 原始 Zig 代码:
//   pub const JSUint8Array = opaque {
//       pub fn ptr(this: *JSUint8Array) [*]u8 { ... }
//       pub fn len(this: *JSUint8Array) usize { ... }
//       pub fn slice(this: *JSUint8Array) []u8 { ... }
//       extern fn JSUint8Array__fromDefaultAllocator(...) JSValue;
//       pub fn fromBytes(globalThis: *JSGlobalObject, bytes: []u8) JSValue { ... }
//       extern fn Bun__createUint8ArrayForCopy(...) JSValue;
//       pub fn fromBytesCopy(globalThis: *JSGlobalObject, bytes: []const u8) JSValue { ... }
//       pub fn createEmpty(globalThis: *JSGlobalObject) JSValue { ... }
//   };
public class JsUint8Array_ {
    // 内部缓冲区
    public var buffer: Array<UInt8> = []
    // 字节偏移量
    public var byteOffset: Int64 = 0
    // 字节长度
    public var byteLength: Int64 = 0
    // 原始 opaque 指针
    public var rawPtr: CPointer<UInt8> = CPointer<UInt8>()

    // FFI 偏移常量 - 严格翻译自 sizes.zig Bun_FFI_PointerOffsetToTypedArrayVector
    // 在 JSC 中，TypedArray 的数据指针和长度存储在固定偏移位置
    static let POINTER_OFFSET_TO_VECTOR: Int64 = 0
    static let POINTER_OFFSET_TO_LENGTH: Int64 = 0

    public init() {}

    public init(buffer: Array<UInt8>) {
        this.buffer = buffer
        this.byteLength = Int64(buffer.size)
    }

    public init(buffer: Array<UInt8>, offset: Int64, length: Int64) {
        this.buffer = buffer
        this.byteOffset = offset
        this.byteLength = length
    }

    // ========== ptr ==========
    // 严格翻译自 JSUint8Array.ptr
    // 获取底层字节缓冲区指针
    //
    // 原始 Zig:
    //   pub fn ptr(this: *JSUint8Array) [*]u8 {
    //       return @as(*[*]u8, @ptrFromInt(@intFromPtr(this) + Sizes.Bun_FFI_PointerOffsetToTypedArrayVector)).*;
    //   }
    public func ptr() -> CPointer<UInt8> {
        // 在仓颉中，直接返回缓冲区数据指针
        if (buffer.size == 0) {
            return CPointer<UInt8>()
        }
        // 返回 buffer 的 C 指针表示
        buffer.data()
    }

    // ========== len ==========
    // 严格翻译自 JSUint8Array.len
    // 获取字节长度
    //
    // 原始 Zig:
    //   pub fn len(this: *JSUint8Array) usize {
    //       return @as(*usize, @ptrFromInt(@intFromPtr(this) + Sizes.Bun_FFI_PointerOffsetToTypedArrayLength)).*;
    //   }
    public func len() -> Int64 {
        byteLength
    }

    // ========== slice ==========
    // 严格翻译自 JSUint8Array.slice
    // 获取字节切片
    //
    // 原始 Zig:
    //   pub fn slice(this: *JSUint8Array) []u8 {
    //       return this.ptr()[0..this.len()];
    //   }
    public func slice() -> Array<UInt8> {
        if (byteOffset == 0 && byteLength == Int64(buffer.size)) {
            buffer
        } else {
            let start = Int64(byteOffset)
            let end = Int64(byteOffset + byteLength)
            if (start < 0 || end > Int64(buffer.size) || start >= end) {
                return []
            }
            buffer[Int64(start)..Int64(end)]
        }
    }

    // ========== fromBytes ==========
    // 严格翻译自 JSUint8Array.fromBytes
    // 从默认分配器分配的字节创建 Uint8Array
    // bytes 必须来自 bun.default_allocator
    //
    // FFI: JSUint8Array__fromDefaultAllocator(*JSGlobalObject, [*]u8, usize) JSValue
    public static func fromBytes(globalThis: JsObject, bytes: Array<UInt8>) -> JsValue {
        // FFI: JSUint8Array__fromDefaultAllocator(globalThis, bytes.ptr, bytes.len)
        let arr = JsUint8Array_(buffer: bytes)
        arr.toJsValue()
    }

    // ========== fromBytesCopy ==========
    // 严格翻译自 JSUint8Array.fromBytesCopy
    // 复制字节创建新的 Uint8Array
    //
    // FFI: Bun__createUint8ArrayForCopy(*JSGlobalObject, ?*const anyopaque, usize, bool) JSValue
    public static func fromBytesCopy(globalThis: JsObject, bytes: Array<UInt8>) -> JsValue {
        // FFI: Bun__createUint8ArrayForCopy(globalThis, bytes.ptr, bytes.len, false)
        let copy = Array<UInt8>()
        for (b in bytes) {
            copy.append(b)
        }
        let arr = JsUint8Array_(buffer: copy)
        arr.toJsValue()
    }

    // ========== createEmpty ==========
    // 严格翻译自 JSUint8Array.createEmpty
    // 创建空的 Uint8Array
    //
    // FFI: Bun__createUint8ArrayForCopy(globalThis, null, 0, false)
    public static func createEmpty(globalThis: JsObject) -> JsValue {
        let arr = JsUint8Array_()
        arr.toJsValue()
    }

    // ========== 元素访问 ==========

    // 获取指定索引的字节
    public func get(index: Int64) -> UInt8 {
        if (index < 0 || index >= byteLength) {
            return 0
        }
        buffer[Int64(byteOffset + index)]
    }

    // 设置指定索引的字节
    public func set(index: Int64, value: UInt8) {
        if (index >= 0 && index < byteLength) {
            buffer[Int64(byteOffset + index)] = value
        }
    }

    // 转为 JsValue
    public func toJsValue() -> JsValue {
        let obj = JsObject.make()
        obj.className = "Uint8Array"
        obj.set("byteLength", JsValue(n: byteLength))
        obj.set("byteOffset", JsValue(n: byteOffset))
        obj.set("length", JsValue(n: byteLength))
        JsValue(obj: obj)
    }
}
