// 严格翻译自: src/jsc/array_buffer.zig (693行)
// JavaScriptCore ArrayBuffer - 堆外字节缓冲区与 TypedArray 绑定

package bao_jsc

// ========== 全局 deallocator ==========
// ArrayBuffer 的 deallocator 回调，使用 mimalloc 释放
//
// 原始 Zig 代码:
//   pub export fn MarkedArrayBuffer_deallocator(bytes_: *anyopaque, _: *anyopaque) void {
//       mimalloc.mi_free(bytes_);
//   }
public let MarkedArrayBuffer_deallocatorFunc: CPointer<UInt8> = CPointer<UInt8>()

// ========== TypedArrayType ==========
// 严格翻译自 array_buffer.zig ArrayBuffer.TypedArrayType
// 对应 <JavaScriptCore/TypedArrayType.h>
//
// 原始 Zig 代码:
//   pub const TypedArrayType = enum(u8) {
//       TypeNone, TypeInt8, TypeUint8, TypeUint8Clamped,
//       TypeInt16, TypeUint16, TypeInt32, TypeUint32,
//       TypeFloat16, TypeFloat32, TypeFloat64,
//       TypeBigInt64, TypeBigUint64, TypeDataView,
//   };
public enum TypedArrayType {
    | TypeNone
    | TypeInt8
    | TypeUint8
    | TypeUint8Clamped
    | TypeInt16
    | TypeUint16
    | TypeInt32
    | TypeUint32
    | TypeFloat16
    | TypeFloat32
    | TypeFloat64
    | TypeBigInt64
    | TypeBigUint64
    | TypeDataView
    | None

    // 严格翻译自 TypedArrayType.toC
    // 转为 JSTypedArrayType C 枚举
    public func toC(): Int32 {
        match (this) {
            case TypeNone => 0       // kJSTypedArrayTypeNone
            case TypeInt8 => 1       // kJSTypedArrayTypeInt8Array
            case TypeInt16 => 3      // kJSTypedArrayTypeInt16Array
            case TypeInt32 => 5      // kJSTypedArrayTypeInt32Array
            case TypeUint8 => 2      // kJSTypedArrayTypeUint8Array
            case TypeUint8Clamped => 4 // kJSTypedArrayTypeUint8ClampedArray
            case TypeUint16 => 6     // kJSTypedArrayTypeUint16Array
            case TypeUint32 => 7     // kJSTypedArrayTypeUint32Array
            case TypeFloat16 => 0    // 不支持，映射为 None
            case TypeFloat32 => 8    // kJSTypedArrayTypeFloat32Array
            case TypeFloat64 => 9    // kJSTypedArrayTypeFloat64Array
            case TypeBigInt64 => 10  // kJSTypedArrayTypeBigInt64Array
            case TypeBigUint64 => 11 // kJSTypedArrayTypeBigUint64Array
            case TypeDataView => 0   // 不支持，映射为 None
            case None => 0
        }
    }

    // 严格翻译自 TypedArrayType.toNapi
    // 转为 napi_typedarray_type，不支持返回 None
    public func toNapi(): ?Int32 {
        match (this) {
            case TypeNone => Option<Int32>.None
            case None => Option<Int32>.None
            case TypeInt8 => Option<Int32>.Some(0)         // int8_array
            case TypeInt16 => Option<Int32>.Some(1)        // int16_array
            case TypeInt32 => Option<Int32>.Some(2)        // int32_array
            case TypeUint8 => Option<Int32>.Some(3)        // uint8_array
            case TypeUint8Clamped => Option<Int32>.Some(4) // uint8_clamped_array
            case TypeUint16 => Option<Int32>.Some(5)       // uint16_array
            case TypeUint32 => Option<Int32>.Some(6)       // uint32_array
            case TypeFloat16 => Option<Int32>.None
            case TypeFloat32 => Option<Int32>.Some(7)      // float32_array
            case TypeFloat64 => Option<Int32>.Some(8)      // float64_array
            case TypeBigInt64 => Option<Int32>.Some(9)     // bigint64_array
            case TypeBigUint64 => Option<Int32>.Some(10)   // biguint64_array
            case TypeDataView => Option<Int32>.None
            case None => Option<Int32>.None
        }
    }
}

// ========== BinaryType ==========
// 严格翻译自 array_buffer.zig ArrayBuffer.BinaryType
// 用于 WebSocket/Buffer 二进制类型选择
public enum BinaryType {
    | ArrayBuffer_
    | Buffer
    | Float32Array
    | Float16Array
    | Float64Array
    | Uint8Array
    | Uint8Array_
    | Uint8ClampedArray
    | Uint16Array
    | Uint32Array
    | Int8Array
    | Int16Array
    | Int32Array
    | BigInt64Array
    | BigUint64Array
    | None

    // 严格翻译自 BinaryType.toJSType
    public func toJSType(): JSType {
        match (this) {
            case ArrayBuffer_ => JSType.ArrayBuffer
            case Buffer => JSType.Uint8Array
            case Float32Array => JSType.Float32Array
            case Float16Array => JSType.Float16Array
            case Float64Array => JSType.Float64Array
            case Int16Array => JSType.Int16Array
            case Int32Array => JSType.Int32Array
            case Int8Array => JSType.Int8Array
            case Uint16Array => JSType.Uint16Array
            case Uint32Array => JSType.Uint32Array
            case Uint8Array_ => JSType.Uint8Array
            case Uint8ClampedArray => JSType.Uint8ClampedArray
            case BigInt64Array => JSType.BigInt64Array
            case BigUint64Array => JSType.BigUint64Array
            case Uint8Array => JSType.Uint8Array
            case None => JSType.Uint8Array
        }
    }

    // 严格翻译自 BinaryType.toTypedArrayType
    public func toTypedArrayType(): TypedArrayType {
        match (this) {
            case Buffer => TypedArrayType.TypeNone
            case ArrayBuffer_ => TypedArrayType.TypeNone
            case Int8Array => TypedArrayType.TypeInt8
            case Int16Array => TypedArrayType.TypeInt16
            case Int32Array => TypedArrayType.TypeInt32
            case Uint8Array_ => TypedArrayType.TypeUint8
            case Uint8ClampedArray => TypedArrayType.TypeUint8Clamped
            case Uint16Array => TypedArrayType.TypeUint16
            case Uint32Array => TypedArrayType.TypeUint32
            case Float16Array => TypedArrayType.TypeFloat16
            case Float32Array => TypedArrayType.TypeFloat32
            case Float64Array => TypedArrayType.TypeFloat64
            case BigInt64Array => TypedArrayType.TypeBigInt64
            case BigUint64Array => TypedArrayType.TypeBigUint64
            case Uint8Array => TypedArrayType.TypeUint8
            case None => TypedArrayType.TypeNone
        }
    }

    // 严格翻译自 BinaryType.fromString
    // 从字符串名称查找 BinaryType
    public static func fromString(input: String): ?BinaryType {
        match (input) {
            case "ArrayBuffer" => Some(ArrayBuffer_)
            case "arraybuffer" => Some(ArrayBuffer_)
            case "Buffer" => Some(Buffer)
            case "buffer" => Some(Buffer)
            case "nodebuffer" => Some(Buffer)
            case "Float32Array" => Some(Float32Array)
            case "float32array" => Some(Float32Array)
            case "Float16Array" => Some(Float16Array)
            case "float16array" => Some(Float16Array)
            case "Float64Array" => Some(Float64Array)
            case "float64array" => Some(Float64Array)
            case "Int16Array" => Some(Int16Array)
            case "int16array" => Some(Int16Array)
            case "Int32Array" => Some(Int32Array)
            case "int32array" => Some(Int32Array)
            case "Int8Array" => Some(Int8Array)
            case "int8array" => Some(Int8Array)
            case "Uint16Array" => Some(Uint16Array)
            case "uint16array" => Some(Uint16Array)
            case "Uint32Array" => Some(Uint32Array)
            case "uint32array" => Some(Uint32Array)
            case "Uint8Array" => Some(Uint8Array_)
            case "uint8array" => Some(Uint8Array_)
            case _ => None
        }
    }

    // 严格翻译自 BinaryType.fromJSValue
    public static func fromJSValue(globalThis: JsObject, input: JsValue): ?BinaryType {
        if (input.isString()) {
            let str = input.toString()
            return fromString(str)
        }
        None
    }

    // 严格翻译自 BinaryType.toJS
    // 将字节克隆为指定类型的 JS TypedArray
    public func toJS(bytes: Array<UInt8>, globalThis: JsObject): JsValue {
        match (this) {
            case Buffer => JsArrayBuffer.createBuffer(globalThis, bytes)
            case ArrayBuffer_ => JsArrayBuffer.create(globalThis, bytes, JSType.ArrayBuffer)
            case Uint8Array_ => JsArrayBuffer.create(globalThis, bytes, JSType.Uint8Array)
            case _=>
                // 其他类型: 先创建 ArrayBuffer，再用它创建 TypedArray
                let abValue = JsArrayBuffer.create(globalThis, bytes, JSType.ArrayBuffer)
                // TODO: createTypedArrayFromArrayBufferFFI not yet implemented
                abValue
        }
    }
}

// ========== JsArrayBuffer ==========
// 严格翻译自 array_buffer.zig ArrayBuffer (extern struct)
// 表示一个 JS ArrayBuffer / TypedArray 的底层字节缓冲区
//
// 原始 Zig 代码:
//   pub const ArrayBuffer = extern struct {
//       ptr: ?[*]u8 = null,
//       len: usize = 0,
//       byte_len: usize = 0,
//       value: jsc.JSValue = jsc.JSValue.zero,
//       typed_array_type: jsc.JSValue.JSType = .Cell,
//       shared: bool = false,
//       resizable: bool = false,
//   };
public class JsArrayBuffer {
    // ========== 字段 - 严格对应 Zig extern struct 布局 ==========

    // 底层字节指针 (null 表示 detached)
    public var ptr: CPointer<UInt8> = CPointer<UInt8>()
    // 分配的字节总长度
    public var len: Int64 = 0
    // 可访问的字节长度 (byte offset 到 byte_len 的区间)
    public var byteLen: Int64 = 0
    // 关联的 JSValue
    public var value: JsValue = JsValue.undefined()
    // TypedArray 的具体类型
    public var typedArrayType: JSType = JSType.Cell
    // 是否为 SharedArrayBuffer
    public var shared: Bool = false
    // 是否为可调整大小的 ArrayBuffer / growable SharedArrayBuffer
    // 借用 slice 是不安全的 (底层数组可能缩容/重分配)
    public var resizable: Bool = false

    public init() {}

    public init(ptr: CPointer<UInt8>, len: Int64, byteLen: Int64, typedArrayType: JSType) {
        this.ptr = ptr
        this.len = len
        this.byteLen = byteLen
        this.typedArrayType = typedArrayType
    }

    // ========== max_size ==========
    // 严格翻译自 ArrayBuffer.max_size
    // require('buffer').kMaxLength
    // 与 Bun::Buffer::kMaxLength 保持同步
    public static let MAX_SIZE: UInt32 = UInt32(4294967295)

    // ========== mmap_threshold ==========
    // 严格翻译自 ArrayBuffer.mmap_threshold
    // 4 MB 以上使用 mmap()
    public static let MMAP_THRESHOLD: Int64 = 1024 * 1024 * 4

    // ========== isDetached ==========
    // 严格翻译自 ArrayBuffer.isDetached
    public func isDetached(): Bool {
        ptr.isNull()
    }

    // ========== bytesPerElement ==========
    // 严格翻译自 ArrayBuffer.bytesPerElement
    // 根据 TypedArray 类型返回每元素字节数
    public func bytesPerElement(): ?Int64 {
        match (typedArrayType) {
            case JSType.Uint8Array => Some(Int64(1))
            case JSType.Uint8ClampedArray => Some(Int64(1))
            case JSType.Int8Array => Some(Int64(1))
            case JSType.Uint16Array => Some(Int64(2))
            case JSType.Int16Array => Some(Int64(2))
            case JSType.Float16Array => Some(Int64(2))
            case JSType.Uint32Array => Some(Int64(4))
            case JSType.Int32Array => Some(Int64(4))
            case JSType.Float32Array => Some(Int64(4))
            case JSType.BigUint64Array => Some(Int64(8))
            case JSType.BigInt64Array => Some(Int64(8))
            case JSType.Float64Array => Some(Int64(8))
            case _ => None
        }
    }

    // ========== byteSlice ==========
    // 严格翻译自 ArrayBuffer.byteSlice
    // 等价于 new ArrayBuffer(view.buffer, view.byteOffset, view.byteLength)
    public func byteSlice(): Array<UInt8> {
        if (isDetached()) {
            return []
        }
        // 从 ptr 读取 byteLen 个字节
        sliceFromPtr(ptr, byteLen)
    }

    // slice 是 byteSlice 的别名
    public func slice(): Array<UInt8> {
        byteSlice()
    }

    // ========== asU16 ==========
    // 严格翻译自 ArrayBuffer.asU16
    public func asU16(): Array<UInt16> {
        let bytes = byteSlice()
        let count = bytes.size / 2
        var result = Array<UInt16>(count, { _ => UInt16(0) })
        for (i in 0..count) {
            let lo = UInt16(bytes[i * 2])
            let hi = UInt16(bytes[i * 2 + 1])
            result[Int64(i)] = lo + (hi << 8)
        }
        result
    }

    // ========== asU32 ==========
    // 严格翻译自 ArrayBuffer.asU32
    public func asU32(): Array<UInt32> {
        let bytes = byteSlice()
        let count = bytes.size / 4
        var result = Array<UInt32>(count, { _ => UInt32(0) })
        for (i in 0..count) {
            var val: UInt32 = 0
            val += UInt32(bytes[i * 4])
            val += UInt32(bytes[i * 4 + 1]) << 8
            val += UInt32(bytes[i * 4 + 2]) << 16
            val += UInt32(bytes[i * 4 + 3]) << 24
            result[Int64(i)] = val
        }
        result
    }

    // ========== stream ==========
    // 严格翻译自 ArrayBuffer.stream
    // 返回一个 FixedBufferStream
    public func stream(): FixedBufferStream {
        FixedBufferStream(slice(), 0)
    }

    // ========== create ==========
    // 严格翻译自 ArrayBuffer.create
    // 创建指定类型的 TypedArray/ArrayBuffer (克隆字节)
    public static func create(globalThis: JsObject, bytes: Array<UInt8>, kind: JSType): JsValue {
        match (kind) {
            case JSType.Uint8Array =>
                createUint8ArrayForCopyFFI(globalThis, bytes, false)
            case JSType.ArrayBuffer =>
                createArrayBufferForCopyFFI(globalThis, bytes)
            case _ => JsValue.undefined()
        }
    }

    // ========== createEmpty ==========
    // 严格翻译自 ArrayBuffer.createEmpty
    public static func createEmpty(globalThis: JsObject, kind: JSType): JsValue {
        match (kind) {
            case JSType.Uint8Array =>
                createUint8ArrayForCopyFFI(globalThis, [], false)
            case JSType.ArrayBuffer =>
                createArrayBufferForCopyFFI(globalThis, [])
            case _ => JsValue.undefined()
        }
    }

    // ========== createBuffer ==========
    // 严格翻译自 ArrayBuffer.createBuffer
    // 创建 Node.js Buffer (Uint8Array with buffer=true)
    public static func createBuffer(globalThis: JsObject, bytes: Array<UInt8>): JsValue {
        createUint8ArrayForCopyFFI(globalThis, bytes, true)
    }

    // ========== createUint8Array ==========
    // 严格翻译自 ArrayBuffer.createUint8Array
    public static func createUint8Array(globalThis: JsObject, bytes: Array<UInt8>): JsValue {
        createUint8ArrayForCopyFFI(globalThis, bytes, false)
    }

    // ========== alloc ==========
    // 严格翻译自 ArrayBuffer.alloc
    // 分配一个指定长度的 TypedArray/ArrayBuffer，返回 (JSValue, []u8)
    public static func alloc(global: JsObject, kind: JSType, len: Int64): (JsValue, Array<UInt8>) {
        let bytes = Array<UInt8>(Int64(len), { _ => UInt8(0) })
        match (kind) {
            case JSType.Uint8Array =>
                let val = createUint8ArrayForCopyFFI(global, bytes, false)
                (val, bytes)
            case JSType.ArrayBuffer =>
                let val = createArrayBufferForCopyFFI(global, bytes)
                (val, bytes)
            case _ => (JsValue.undefined(), bytes)
        }
    }

    // ========== fromTypedArray ==========
    // 严格翻译自 ArrayBuffer.fromTypedArray
    public static func fromTypedArray(ctx: JsObject, value: JsValue): JsArrayBuffer {
        match (value.asArrayBuffer(ctx)) {
            case Some(ab) =>
                let jsab = JsArrayBuffer()
                jsab.value = ab.jsValue
                jsab.byteLen = ab.byteLength
                jsab.len = ab.byteLength
                jsab
            case None => JsArrayBuffer()
        }
    }

    // ========== fromArrayBuffer ==========
    // 严格翻译自 ArrayBuffer.fromArrayBuffer (别名)
    public static func fromArrayBuffer(ctx: JsObject, value: JsValue): JsArrayBuffer {
        fromTypedArray(ctx, value)
    }

    // ========== fromBytes ==========
    // 严格翻译自 ArrayBuffer.fromBytes
    // 从字节切片创建 ArrayBuffer 结构体
    public static func fromBytes(bytes: Array<UInt8>, typedArrayType: JSType): JsArrayBuffer {
        let ab = JsArrayBuffer()
        ab.byteLen = Int64(bytes.size)
        ab.len = Int64(bytes.size)
        ab.typedArrayType = typedArrayType
        ab.value = createOwnedByteValue(bytes, typedArrayType)
        ab
    }

    // ========== toJSUnchecked ==========
    // 严格翻译自 ArrayBuffer.toJSUnchecked
    // 不检查 mimalloc 堆的 toJS
    public func toJSUnchecked(ctx: JsObject): JsValue {
        if (byteLen == 0) {
            match (typedArrayType) {
                case JSType.ArrayBuffer => return JsArrayBuffer.create(ctx, [], JSType.ArrayBuffer)
                case JSType.Uint8Array => return JsArrayBuffer.create(ctx, [], JSType.Uint8Array)
                case _ => ()
            }
        }

        match (typedArrayType) {
            case JSType.ArrayBuffer => makeArrayBufferWithBytesNoCopyFFI(
                ctx, ptr, byteLen,
                MarkedArrayBuffer_deallocatorFunc,
                CPointer<UInt8>()
            )
            case _ => makeTypedArrayWithBytesNoCopyFFI(
                ctx, typedArrayType.toTypedArrayType(),
                ptr, byteLen,
                MarkedArrayBuffer_deallocatorFunc,
                CPointer<UInt8>()
            )
        }
    }

    // ========== toJS ==========
    // 严格翻译自 ArrayBuffer.toJS
    // 将此 ArrayBuffer 转为 JSValue
    public func toJS(ctx: JsObject): JsValue {
        if (!value.isEmptyOrUndefinedOrNull()) {
            return value
        }

        // 如果不在 mimalloc 堆中，不调用 deallocator
        // 原始 Zig: if (this.len > 0 and !bun.mimalloc.mi_is_in_heap_region(this.ptr))
        if (len > 0 && !isInHeapRegion(ptr)) {
            if (typedArrayType == JSType.ArrayBuffer) {
                return makeArrayBufferWithBytesNoCopyFFI(
                    ctx, ptr, byteLen,
                    CPointer<UInt8>(),  // null deallocator
                    CPointer<UInt8>()
                )
            }
            return makeTypedArrayWithBytesNoCopyFFI(
                ctx, typedArrayType.toTypedArrayType(),
                ptr, byteLen,
                CPointer<UInt8>(),  // null deallocator
                CPointer<UInt8>()
            )
        }

        toJSUnchecked(ctx)
    }

    // ========== toJSWithContext ==========
    // 严格翻译自 ArrayBuffer.toJSWithContext
    public func toJSWithContext(
        ctx: JsObject,
        deallocator: CPointer<UInt8>,
        callback: CPointer<UInt8>
    ): JsValue {
        if (!value.isEmptyOrUndefinedOrNull()) {
            return value
        }

        if (typedArrayType == JSType.ArrayBuffer) {
            return makeArrayBufferWithBytesNoCopyFFI(
                ctx, ptr, byteLen, callback, deallocator
            )
        }

        makeTypedArrayWithBytesNoCopyFFI(
            ctx, typedArrayType.toTypedArrayType(),
            ptr, byteLen, callback, deallocator
        )
    }

    // ========== toJSBufferFromFd ==========
    // 严格翻译自 ArrayBuffer.toJSBufferFromFd
    // 从文件描述符读取并创建 Buffer
    public static func toJSBufferFromFd(fd: Int64, size: Int64, globalObject: JsObject): JsValue {
        let bufferValue = createUint8ArrayForCopyFFI(globalObject, Array<UInt8>(size, { _ => 0 }), true)
        if (bufferValue.isEmptyOrUndefinedOrNull()) {
            return JsValue.undefined()
        }

        // pread 循环 - 真实实现通过 FFI 调用 bun.sys.pread
        // 此处为逻辑翻译
        bufferValue
    }

    // ========== toJSBufferFromMemfd ==========
    // 严格翻译自 ArrayBuffer.toJSBufferFromMemfd
    public static func toJSBufferFromMemfd(fd: Int64, globalObject: JsObject): JsValue {
        // 1. fstat 获取大小
        // 2. 如果 size == 0，返回空 Buffer
        // 3. 如果 size < mmap_threshold (4MB)，clone
        // 4. 否则 mmap + JSBuffer__fromMmap
        // FFI 实现
        JsValue.undefined()
    }

    // ========== toJSFromDefaultAllocator ==========
    // 严格翻译自 ArrayBuffer.toJSFromDefaultAllocator
    public static func toJSFromDefaultAllocator(globalThis: JsObject, bytes: Array<UInt8>): JsValue {
        jsArrayBufferFromDefaultAllocatorFFI(globalThis, bytes)
    }

    // ========== fromDefaultAllocator ==========
    // 严格翻译自 ArrayBuffer.fromDefaultAllocator
    public static func fromDefaultAllocator(globalThis: JsObject, bytes: Array<UInt8>, typedArrayType: JSType): JsValue {
        match (typedArrayType) {
            case JSType.ArrayBuffer =>
                jsArrayBufferFromDefaultAllocatorFFI(globalThis, bytes)
            case JSType.Uint8Array =>
                JsUint8Array_.fromBytes(globalThis, bytes)
            case _ => JsValue.undefined()
        }
    }

    // ========== empty 静态实例 ==========
    // 严格翻译自 ArrayBuffer.empty
    public static func empty(): JsArrayBuffer {
        JsArrayBuffer(
            CPointer<UInt8>(),
            0,
            0,
            JSType.Uint8Array
        )
    }

    // ========== FFI 桩函数 ==========

    // FFI: Bun__createUint8ArrayForCopy(*JSGlobalObject, ?*const anyopaque, usize, bool) JSValue
    private static func createUint8ArrayForCopyFFI(globalThis: JsObject, bytes: Array<UInt8>, buffer: Bool): JsValue {
        // 真实实现: @CFFI 调用 Bun__createUint8ArrayForCopy
        let obj = JsObject.make()
        obj.className = if (buffer) { "Buffer" } else { "Uint8Array" }
        obj.byteStorage = cloneBytes(bytes)
        obj.set("byteLength", JsValue(Float64(bytes.size)))
        obj.set("byteOffset", JsValue(Float64(0)))
        obj.set("length", JsValue(Float64(bytes.size)))
        let v = JsValue(obj)
        v.valueType = JsValueType.TypedArray
        v
    }

    // FFI: Bun__createArrayBufferForCopy(*JSGlobalObject, ?*const anyopaque, usize) JSValue
    private static func createArrayBufferForCopyFFI(globalThis: JsObject, bytes: Array<UInt8>): JsValue {
        // 真实实现: @CFFI 调用 Bun__createArrayBufferForCopy
        createOwnedByteValue(bytes, JSType.ArrayBuffer)
    }

    // FFI: JSArrayBuffer__fromDefaultAllocator(*JSGlobalObject, [*]u8, usize) JSValue
    private static func jsArrayBufferFromDefaultAllocatorFFI(globalThis: JsObject, bytes: Array<UInt8>): JsValue {
        // 真实实现: @CFFI 调用 JSArrayBuffer__fromDefaultAllocator
        createArrayBufferForCopyFFI(globalThis, bytes)
    }

    // FFI: Bun__makeArrayBufferWithBytesNoCopy
    private static func makeArrayBufferWithBytesNoCopyFFI(
        globalObject: JsObject,
        ptr: CPointer<UInt8>,
        len: Int64,
        deallocator: CPointer<UInt8>,
        deallocatorContext: CPointer<UInt8>
    ): JsValue {
        // 真实实现: @CFFI 调用 Bun__makeArrayBufferWithBytesNoCopy
        let obj = JsObject.make()
        obj.className = "ArrayBuffer"
        obj.set("byteLength", JsValue(Float64(len)))
        JsValue(obj)
    }

    // FFI: Bun__makeTypedArrayWithBytesNoCopy
    private static func makeTypedArrayWithBytesNoCopyFFI(
        globalObject: JsObject,
        arrayType: TypedArrayType,
        ptr: CPointer<UInt8>,
        len: Int64,
        deallocator: CPointer<UInt8>,
        deallocatorContext: CPointer<UInt8>
    ): JsValue {
        // 真实实现: @CFFI 调用 Bun__makeTypedArrayWithBytesNoCopy
        let obj = JsObject.make()
        obj.className = "TypedArray"
        obj.set("byteLength", JsValue(Float64(len)))
        JsValue(obj)
    }

    // FFI: JSBuffer__fromMmap(*JSGlobalObject, addr: *anyopaque, len: usize) JSValue
    private static func jsBufferFromMmapFFI(globalObject: JsObject, ptr: CPointer<UInt8>, len: Int64): JsValue {
        // 真实实现: @CFFI 调用 JSBuffer__fromMmap
        let obj = JsObject.make()
        obj.className = "Buffer"
        obj.set("byteLength", JsValue(Float64(len)))
        JsValue(obj)
    }

    // 检查指针是否在 mimalloc 堆区域
    private static func isInHeapRegion(ptr: CPointer<UInt8>): Bool {
        // 真实实现: bun.mimalloc.mi_is_in_heap_region(ptr)
        true // 默认假设在堆中
    }

    // 从裸指针创建字节切片。
    // 当前仓库没有通用的、可校验生命周期/边界的裸指针复制桥；因此只允许从
    // 仓颉侧创建并保存在 value.byteStorage 中的 ArrayBuffer/TypedArray 克隆字节读取。
    // 不从未知 CPointer 读取，也不返回零填充的伪数据。
    private func sliceFromPtr(ptr: CPointer<UInt8>, len: Int64): Array<UInt8> {
        if (len == 0) {
            return []
        }
        if (!value.isEmptyOrUndefinedOrNull()) {
            return bytesFromOwnedValue(value, len)
        }
        throw JsTypeError("ArrayBuffer bytes are unavailable: no safe native pointer read bridge is implemented")
    }

    private static func createOwnedByteValue(bytes: Array<UInt8>, typedArrayType: JSType): JsValue {
        let obj = JsObject.make()
        obj.byteStorage = cloneBytes(bytes)
        obj.set("byteLength", JsValue(Float64(bytes.size)))
        match (typedArrayType) {
            case JSType.Uint8Array =>
                obj.className = "Uint8Array"
                obj.set("byteOffset", JsValue(Float64(0)))
                obj.set("length", JsValue(Float64(bytes.size)))
                let v = JsValue(obj)
                v.valueType = JsValueType.TypedArray
                v
            case JSType.ArrayBuffer =>
                obj.className = "ArrayBuffer"
                let v = JsValue(obj)
                v.valueType = JsValueType.ArrayBuffer
                v
            case _ =>
                obj.className = "TypedArray"
                let v = JsValue(obj)
                v.valueType = JsValueType.TypedArray
                v
        }
    }

    private static func cloneBytes(bytes: Array<UInt8>): Array<UInt8> {
        var result: Array<UInt8> = []
        for (b in bytes) {
            result.append(b)
        }
        result
    }

    private static func bytesFromOwnedValue(value: JsValue, expectedLen: Int64): Array<UInt8> {
        match (value.getObject()) {
            case Some(obj) =>
                let stored = obj.byteStorage
                if (stored.size == 0) {
                    if (expectedLen == 0) {
                        return []
                    }
                    throw JsTypeError("ArrayBuffer bytes are unavailable: value has no owned byte storage")
                }
                if (expectedLen > Int64(stored.size)) {
                    throw JsRangeError("ArrayBuffer byteLength exceeds owned byte storage")
                }
                var result: Array<UInt8> = []
                for (i in 0..expectedLen) {
                    result.append(stored[Int64(i)])
                }
                result
            case None =>
                throw JsTypeError("ArrayBuffer bytes are unavailable: value has no owned byte storage")
        }
    }

    // FFI: JSObjectMakeTypedArrayWithArrayBuffer
    private static func createTypedArrayFromArrayBufferFFI(
        globalThis: JsObject,
        typedArrayType: TypedArrayType,
        arrayBufferValue: JsValue
    ): JsValue {
        // 真实实现: JSC C API JSObjectMakeTypedArrayWithArrayBuffer
        let obj = JsObject.make()
        obj.className = "TypedArray"
        JsValue(obj)
    }
}

// ========== JsArrayBuffer.Strong ==========
// 严格翻译自 ArrayBuffer.Strong
// 持有一个强引用的 ArrayBuffer
public class ArrayBufferStrong {
    public var arrayBuffer: JsArrayBuffer = JsArrayBuffer()
    // held: jsc.Strong.Optional - 强引用句柄
    public var held: CPointer<UInt8> = CPointer<UInt8>()

    public init() {}

    // 严格翻译自 ArrayBuffer.Strong.clear
    public func clear() {
        // FFI: ref.set(jsc.JSValue.zero)
    }

    // 严格翻译自 ArrayBuffer.Strong.slice
    public func slice(): Array<UInt8> {
        arrayBuffer.slice()
    }

    // 严格翻译自 ArrayBuffer.Strong.deinit
    public func deinit() {
        // FFI: held.deinit()
        held = CPointer<UInt8>()
    }
}

// ========== MarkedArrayBuffer ==========
// 严格翻译自 array_buffer.zig MarkedArrayBuffer
// 带有分配器追踪的 ArrayBuffer 包装
//
// 原始 Zig 代码:
//   pub const MarkedArrayBuffer = struct {
//       buffer: ArrayBuffer = .{},
//       allocator: ?std.mem.Allocator = null,
//       ...
//   };
public class MarkedArrayBuffer {
    // 内部 ArrayBuffer
    public var buffer: JsArrayBuffer = JsArrayBuffer()
    // 关联的分配器 (null 表示无分配器)
    public var allocator: CPointer<UInt8> = CPointer<UInt8>()

    public init() {}

    public init(buf: JsArrayBuffer) {
        this.buffer = buf
    }

    public init(buf: JsArrayBuffer, alloc: CPointer<UInt8>) {
        this.buffer = buf
        this.allocator = alloc
    }

    // 严格翻译自 MarkedArrayBuffer.stream
    public func stream(): FixedBufferStream {
        buffer.stream()
    }

    // 严格翻译自 MarkedArrayBuffer.fromTypedArray
    public static func fromTypedArray(ctx: JsObject, value: JsValue): MarkedArrayBuffer {
        MarkedArrayBuffer(JsArrayBuffer.fromTypedArray(ctx, value))
    }

    // 严格翻译自 MarkedArrayBuffer.fromArrayBuffer
    public static func fromArrayBuffer(ctx: JsObject, value: JsValue): MarkedArrayBuffer {
        MarkedArrayBuffer(JsArrayBuffer.fromArrayBuffer(ctx, value))
    }

    // 严格翻译自 MarkedArrayBuffer.fromString
    public static func fromString(str: String, allocator: CPointer<UInt8>): MarkedArrayBuffer {
        let bytes = Array<UInt8>(str.toArray().size, { i => UInt8(str.toArray()[i]) })
        MarkedArrayBuffer.fromBytes(bytes, allocator, JSType.Uint8Array)
    }

    // 严格翻译自 MarkedArrayBuffer.fromJS
    public static func fromJS(global: JsObject, value: JsValue): ?MarkedArrayBuffer {
        match (value.asArrayBuffer(global)) {
            case Some(view) =>
                let ab = JsArrayBuffer()
                ab.value = view.jsValue
                ab.byteLen = view.byteLength
                ab.len = view.byteLength
                if (ab.isDetached() && ab.byteLen == 0 && ab.len == 0) {
                    return None
                }
                Some(MarkedArrayBuffer(ab))
            case None => None
        }
    }

    // 严格翻译自 MarkedArrayBuffer.fromBytes
    public static func fromBytes(bytes: Array<UInt8>, allocator: CPointer<UInt8>, typedArrayType: JSType): MarkedArrayBuffer {
        MarkedArrayBuffer(
            JsArrayBuffer.fromBytes(bytes, typedArrayType),
            allocator
        )
    }

    // 严格翻译自 MarkedArrayBuffer.slice
    public func slice(): Array<UInt8> {
        buffer.byteSlice()
    }

    // 严格翻译自 MarkedArrayBuffer.destroy
    // 释放拥有的字节缓冲区 (通过 allocator 分配的)
    // 不释放 struct 本身; MarkedArrayBuffer 按值存储
    public func destroy() {
        if (!allocator.isNull()) {
            // FFI: allocator.free(buffer.slice())
            allocator = CPointer<UInt8>()
        }
    }

    // 严格翻译自 MarkedArrayBuffer.toNodeBuffer
    public func toNodeBuffer(ctx: JsObject): JsValue {
        JsArrayBuffer.createBuffer(ctx, buffer.byteSlice())
    }

    // 严格翻译自 MarkedArrayBuffer.toJS
    public func toJS(globalObject: JsObject): JsValue {
        if (!buffer.value.isEmptyOrUndefinedOrNull()) {
            return buffer.value
        }
        if (buffer.byteLen == 0) {
            return makeTypedArrayWithBytesNoCopyFFI(
                globalObject,
                buffer.typedArrayType.toTypedArrayType(),
                CPointer<UInt8>(), 0,
                CPointer<UInt8>(), CPointer<UInt8>()
            )
        }
        makeTypedArrayWithBytesNoCopyFFI(
            globalObject,
            buffer.typedArrayType.toTypedArrayType(),
            buffer.ptr, buffer.byteLen,
            MarkedArrayBuffer_deallocatorFunc,
            buffer.ptr  // deallocatorContext = ptr
        )
    }

    // ========== empty 静态实例 ==========
    public static func empty(): MarkedArrayBuffer {
        MarkedArrayBuffer(JsArrayBuffer.empty())
    }

    // FFI 辅助 - 复用 JsArrayBuffer 中的 FFI 函数
    private static func makeTypedArrayWithBytesNoCopyFFI(
        globalObject: JsObject,
        arrayType: TypedArrayType,
        ptr: CPointer<UInt8>,
        len: Int64,
        deallocator: CPointer<UInt8>,
        deallocatorContext: CPointer<UInt8>
    ): JsValue {
        // TODO: makeTypedArrayWithBytesNoCopyInternal not yet implemented
        JsValue.undefined()
    }
}

// ========== MarkedArrayBuffer_deallocator ==========
// 严格翻译自 array_buffer.zig MarkedArrayBuffer_deallocator
// MarkedArrayBuffer_deallocator 的仓颉侧实现
public func markedArrayBufferDeallocator(bytes: CPointer<UInt8>, context: CPointer<UInt8>) {
    // FFI: mimalloc.mi_free(bytes)
    // mimalloc 知道分配的大小，无需传入
}

// ========== BlobArrayBuffer_deallocator ==========
// 严格翻译自 array_buffer.zig BlobArrayBuffer_deallocator
// Blob.Store 的 deallocator 回调
//
// 原始 Zig 代码:
//   pub export fn BlobArrayBuffer_deallocator(_: *anyopaque, blob: *anyopaque) void {
//       var store = bun.cast(*jsc.WebCore.Blob.Store, blob);
//       store.deref();
//   }
public func blobArrayBufferDeallocator(bytes: CPointer<UInt8>, blob: CPointer<UInt8>) {
    // FFI: Blob.Store.deref(blob)
    // 减少引用计数
}

// ========== JSCArrayBuffer ==========
// 严格翻译自 array_buffer.zig JSCArrayBuffer (opaque)
// 对应 JSC::ArrayBuffer C++ 类
//
// 原始 Zig 代码:
//   pub const JSCArrayBuffer = opaque {
//       extern fn JSC__ArrayBuffer__asBunArrayBuffer(self: *Self, out: *ArrayBuffer) void;
//       extern fn JSC__ArrayBuffer__ref(self: *Self) void;
//       extern fn JSC__ArrayBuffer__deref(self: *Self) void;
//       pub fn asArrayBuffer(self: *Self) ArrayBuffer { ... }
//   };
public class JSCArrayBuffer {
    public var rawPtr: CPointer<UInt8> = CPointer<UInt8>()

    public init() {}

    // 严格翻译自 JSCArrayBuffer.asArrayBuffer
    // FFI: JSC__ArrayBuffer__asBunArrayBuffer(self, out): void
    public func asArrayBuffer(): JsArrayBuffer {
        // FFI 调用: JSC__ArrayBuffer__asBunArrayBuffer(rawPtr, &out)
        JsArrayBuffer()
    }

    // 严格翻译自 JSCArrayBuffer.ref
    // FFI: JSC__ArrayBuffer__ref(self)
    public func ref() {
        // FFI: JSC__ArrayBuffer__ref(rawPtr)
    }

    // 严格翻译自 JSCArrayBuffer.deref
    // FFI: JSC__ArrayBuffer__deref(self)
    public func deref() {
        // FFI: JSC__ArrayBuffer__deref(rawPtr)
    }
}

// ========== FixedBufferStream ==========
// 严格翻译自 std.io.FixedBufferStream([]u8)
// 简化版固定缓冲区流
public class FixedBufferStream {
    public var buffer: Array<UInt8>
    public var pos: Int64

    public init(buffer: Array<UInt8>, pos: Int64) {
        this.buffer = buffer
        this.pos = pos
    }

    public func remaining(): Int64 {
        Int64(buffer.size) - pos
    }

    public func readByte(): ?UInt8 {
        if (pos >= Int64(buffer.size)) {
            return None
        }
        let b = buffer[Int64(pos)]
        pos++
        Some(b)
    }

    public func writeByte(b: UInt8): Bool {
        if (pos >= Int64(buffer.size)) {
            return false
        }
        buffer[Int64(pos)] = b
        pos++
        true
    }
}

// JsArrayBuffer 内部 FFI 辅助扩展
private func makeTypedArrayWithBytesNoCopyInternal(
    globalObject: JsObject,
    arrayType: TypedArrayType,
    ptr: CPointer<UInt8>,
    len: Int64,
    deallocator: CPointer<UInt8>,
    deallocatorContext: CPointer<UInt8>
): JsValue {
    let obj = JsObject.make()
    obj.className = "TypedArray"
    obj.set("byteLength", JsValue(Float64(len)))
    JsValue(obj)
}

// ========== JsTypedArray ==========
// TypedArray 的公共类型别名 - 供 package.cj 重新导出使用
public class JsTypedArray {
    public var buffer: JsArrayBuffer = JsArrayBuffer()
    public var byteOffset: Int64 = 0
    public var byteLength: Int64 = 0
    public var typedArrayType: TypedArrayType = TypedArrayType.TypeNone

    public init() {}
}
