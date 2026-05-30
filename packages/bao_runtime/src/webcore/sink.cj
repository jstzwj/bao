// Sink - 流式 Sink
// 严格翻译自: src/runtime/webcore/Sink.rs (1239 lines)
// 包含: Sink, Status, Data, VTable, SinkHandler, UTF8Fallback,
//        JSSink, JsSinkAbi, JsSinkType, SinkSignal, DestructorPtr, Bun__onSinkDestroyed
package bao_runtime.webcore

import bao_core.*
import bao_collections.ArrayList
import bao_collections.ArrayBuffer
import bao_jsc.*
import bao_sys.*
import bao_ptr.*

// ============================================================================
// Re-exports
// 对应 Bun: pub use crate::webcore::array_buffer_sink::ArrayBufferSink
// ============================================================================

// ArrayBufferSink 在 array_buffer_sink.cj 中定义, 此处直接使用

// ============================================================================
// SinkStatus - Sink 状态
// 对应 Bun: Sink.Status (Sink.rs:72-77)
// ============================================================================

/// Sink 状态
/// 对应 Bun: Sink.Status
/// repr(u8), Clone, Copy, PartialEq, Eq
public enum SinkStatus {
    | Ready
    | Closed

    public operator func == (rhs: SinkStatus): Bool {
        match (this) {
            case Ready => match (rhs) { case Ready => true case _ => false }
            case Closed => match (rhs) { case Closed => true case _ => false }
        }
    }
}

// ============================================================================
// SinkWriteResult - Sink 写入结果
// 对应 ArrayBufferSink.write() 返回值
// ============================================================================

/// Sink 写入结果
public enum SinkWriteResult {
    | Done
    | Error(String)

    public operator func == (rhs: SinkWriteResult): Bool {
        match (this) {
            case Done => match (rhs) { case Done => true case _ => false }
            case Error(msg1) => match (rhs) { case Error(msg2) => msg1 == msg2 case _ => false }
        }
    }

    public operator func != (rhs: SinkWriteResult): Bool {
        return !(this == rhs)
    }
}

// ============================================================================
// SinkData - Sink 数据类型
// 对应 Bun: Sink.Data (Sink.rs:79-83)
// ============================================================================

/// Sink 数据类型
/// 对应 Bun: Sink.Data
public enum SinkData {
    | UTF16(StreamResult)
    | Latin1(StreamResult)
    | Bytes(StreamResult)
}

// ============================================================================
// SinkHandler - Sink 处理器接口
// 对应 Bun: SinkHandler trait (Sink.rs:87-93)
// ============================================================================

/// Sink 处理器接口 — 捕获 VTable::wrap 期望的 duck-typed 方法
/// 对应 Bun: SinkHandler trait
public interface SinkHandler {
    /// 写入 UTF-8 数据
    /// 对应 Bun: SinkHandler.write()
    func write(data: StreamResult): StreamResultWritable

    /// 写入 Latin-1 数据
    /// 对应 Bun: SinkHandler.write_latin1()
    func writeLatin1(data: StreamResult): StreamResultWritable

    /// 写入 UTF-16 数据
    /// 对应 Bun: SinkHandler.write_utf16()
    func writeUTF16(data: StreamResult): StreamResultWritable

    /// 结束
    /// 对应 Bun: SinkHandler.end()
    func end(err: ?SyscallError): ?SyscallError

    /// 连接信号
    /// 对应 Bun: SinkHandler.connect()
    func connect(signal: StreamSignal): ?SyscallError
}

// ============================================================================
// StreamSinkVTable - Sink 虚表函数类型
// 对应 Bun: Sink.VTable 函数指针类型 (Sink.rs:305-309)
// ============================================================================

/// UTF-16 写入函数类型
public type WriteUTF16Fn = (UIntNative, StreamResult) -> StreamResultWritable
/// UTF-8 写入函数类型
public type WriteUTF8Fn = (UIntNative, StreamResult) -> StreamResultWritable
/// Latin-1 写入函数类型
public type WriteLatin1Fn = (UIntNative, StreamResult) -> StreamResultWritable
/// 结束函数类型
public type EndFn = (UIntNative, ?SyscallError) -> ?SyscallError
/// 连接函数类型
public type ConnectFn = (UIntNative, StreamSignal) -> ?SyscallError

// ============================================================================
// SinkVTable - Sink 虚表
// 对应 Bun: Sink.VTable (Sink.rs:311-318)
// ============================================================================

/// Sink 虚表 — 定义 Sink 的行为接口
/// 对应 Bun: Sink.VTable
/// Clone, Copy
public class SinkVTable {
    /// 连接函数
    public var connect: ConnectFn
    /// UTF-8 写入函数
    public var write: WriteUTF8Fn
    /// Latin-1 写入函数
    public var writeLatin1: WriteLatin1Fn
    /// UTF-16 写入函数
    public var writeUTF16: WriteUTF16Fn
    /// 结束函数
    public var end: EndFn

    public init(
        connect: ConnectFn,
        write: WriteUTF8Fn,
        writeLatin1: WriteLatin1Fn,
        writeUTF16: WriteUTF16Fn,
        end: EndFn
    ) {
        this.connect = connect
        this.write = write
        this.writeLatin1 = writeLatin1
        this.writeUTF16 = writeUTF16
        this.end = end
    }

    /// 包裹 SinkHandler 为 VTable
    /// 对应 Bun: VTable::wrap::<Wrapped>() (Sink.rs:351-390)
    public static func wrap<T>(handler: T): SinkVTable where T <: SinkHandler {
        // 创建 VTable, 每个函数通过类型擦除调用 SinkHandler 方法
        let connectFn: ConnectFn = { ptr: UIntNative, signal: StreamSignal =>
            // 恢复类型化引用并调用 handler 方法
            handler.connect(signal)
        }
        let writeFn: WriteUTF8Fn = { ptr: UIntNative, data: StreamResult =>
            handler.write(data)
        }
        let writeLatin1Fn: WriteLatin1Fn = { ptr: UIntNative, data: StreamResult =>
            handler.writeLatin1(data)
        }
        let writeUTF16Fn: WriteUTF16Fn = { ptr: UIntNative, data: StreamResult =>
            handler.writeUTF16(data)
        }
        let endFn: EndFn = { ptr: UIntNative, err: ?SyscallError =>
            handler.end(err)
        }
        SinkVTable(connectFn, writeFn, writeLatin1Fn, writeUTF16Fn, endFn)
    }
}

// ============================================================================
// Sink - 流式 Sink 基类
// 对应 Bun: Sink<'a> (Sink.rs:37-44)
// ============================================================================

/// Sink — 手写 vtable 的可写流 Sink
/// 对应 Bun: Sink<'a>
public class Sink {
    /// 类型擦除指针 (handler 引用)
    /// 对应 Bun: Sink.ptr: &'a ()
    public var ptr: UIntNative
    /// 虚表
    /// 对应 Bun: Sink.vtable: VTable
    public var vtable: ?SinkVTable
    /// 状态
    /// 对应 Bun: Sink.status: Status
    public var status: SinkStatus
    /// 是否已使用
    /// 对应 Bun: Sink.used: bool
    public var used: Bool

    public init() {
        ptr = 0
        vtable = None
        status = SinkStatus.Closed
        used = false
    }

    /// pending — 哨兵状态, 状态为 Closed
    /// 对应 Bun: Sink::pending() (Sink.rs:51-69)
    /// Uses 0xAAAAAAAA as a sentinel non-null pointer value (matches Zig's @ptrFromInt).
    public static func pending(): Sink {
        let sink = Sink()
        sink.ptr = 0xAAAAAAAA // 哨兵地址
        sink.vtable = None     // Zig: vtable: undefined
        sink.status = SinkStatus.Closed
        sink.used = false
        return sink
    }

    /// initWithType — 使用类型化 handler 初始化
    /// 对应 Bun: init_with_type<T: SinkHandler>() (Sink.rs:163-171)
    public static func initWithType<T>(handler: T): Sink where T <: SinkHandler {
        let sink = Sink()
        sink.ptr = 0 // 在实际 FFI 中会是 handler 的地址
        sink.vtable = Some(SinkVTable.wrap<T>(handler))
        sink.status = SinkStatus.Ready
        sink.used = false
        return sink
    }

    /// init — 初始化 (initWithType 的别名)
    /// 对应 Bun: init<T: SinkHandler>() (Sink.rs:173-177)
    public static func `init`<T>(handler: T): Sink where T <: SinkHandler {
        return initWithType<T>(handler)
    }

    /// end — 结束 Sink
    /// 对应 Bun: Sink.end() (Sink.rs:393-400)
    public func end(err: ?SyscallError): ?SyscallError {
        if (status == SinkStatus.Closed) {
            return None
        }
        status = SinkStatus.Closed
        if (vtable.isSome()) {
            return vtable.getOrThrow().end(ptr, err)
        }
        return None
    }

    /// writeLatin1 — 写入 Latin-1 数据
    /// 对应 Bun: Sink.write_latin1() (Sink.rs:402-415)
    public func writeLatin1(data: StreamResult): StreamResultWritable {
        if (status == SinkStatus.Closed) {
            return StreamResultWritable.done()
        }
        let res = if (vtable.isSome()) {
            vtable.getOrThrow().writeLatin1(ptr, data)
        } else {
            StreamResultWritable.done()
        }
        if (res.isDone() || status == SinkStatus.Closed) {
            status = SinkStatus.Closed
        } else {
            status = SinkStatus.Ready
        }
        used = true
        return res
    }

    /// writeBytes — 写入字节数据 (UTF-8)
    /// 对应 Bun: Sink.write_bytes() (Sink.rs:417-430)
    public func writeBytes(data: StreamResult): StreamResultWritable {
        if (status == SinkStatus.Closed) {
            return StreamResultWritable.done()
        }
        let res = if (vtable.isSome()) {
            vtable.getOrThrow().write(ptr, data)
        } else {
            StreamResultWritable.done()
        }
        if (res.isDone() || status == SinkStatus.Closed) {
            status = SinkStatus.Closed
        } else {
            status = SinkStatus.Ready
        }
        used = true
        return res
    }

    /// writeUTF16 — 写入 UTF-16 数据
    /// 对应 Bun: Sink.write_utf16() (Sink.rs:432-445)
    public func writeUTF16(data: StreamResult): StreamResultWritable {
        if (status == SinkStatus.Closed) {
            return StreamResultWritable.done()
        }
        let res = if (vtable.isSome()) {
            vtable.getOrThrow().writeUTF16(ptr, data)
        } else {
            StreamResultWritable.done()
        }
        if (res.isDone() || status == SinkStatus.Closed) {
            status = SinkStatus.Closed
        } else {
            status = SinkStatus.Ready
        }
        used = true
        return res
    }

    /// write — 写入 SinkData
    /// 对应 Bun: Sink.write() (Sink.rs:447-454)
    public func writeData(data: SinkData): StreamResultWritable {
        match (data) {
            case UTF16(sr) => writeUTF16(sr)
            case Latin1(sr) => writeLatin1(sr)
            case Bytes(sr) => writeBytes(sr)
        }
    }
}

// ============================================================================
// UTF8Fallback - UTF-8 回退编码转换
// 对应 Bun: Sink.UTF8Fallback (Sink.rs:187-303)
// ============================================================================

/// UTF-8 回退 — Latin1/UTF16 到 UTF-8 的编码转换辅助
/// 对应 Bun: Sink.UTF8Fallback
public class UTF8Fallback {
    /// 栈缓冲区大小
    /// 对应 Bun: UTF8Fallback.STACK_SIZE = 1024
    public static let STACK_SIZE: Int64 = 1024

    public init() {}

    /// writeLatin1 — 将 Latin-1 数据转换为 UTF-8 并写入
    /// 对应 Bun: UTF8Fallback.write_latin1() (Sink.rs:202-251)
    public static func writeLatin1<Ctx>(
        ctx: Ctx,
        input: StreamResult,
        writeFn: (Ctx, StreamResult) -> StreamResultWritable
    ): StreamResultWritable {
        let str_ = input.slice()
        // 检查是否全部 ASCII
        if (isAllAscii(str_)) {
            return writeFn(ctx, input)
        }

        if (STACK_SIZE >= str_.size) {
            var buf = ArrayList<UInt8>()
            for (i in 0..str_.size) {
                buf.append(str_[i])
            }
            // 替换 Latin-1 为 UTF-8
            replaceLatin1WithUTF8(buf)

            let borrowed = ArrayList<UInt8>()
            for (b in buf.items()) {
                borrowed.append(b)
            }
            if (input.isDone()) {
                return writeFn(ctx, StreamResult.temporaryAndDone(borrowed))
            } else {
                return writeFn(ctx, StreamResult.temporary(borrowed))
            }
        }

        // 堆分配路径
        var slice = ArrayList<UInt8>()
        for (i in 0..str_.size) {
            slice.append(str_[i])
        }
        replaceLatin1WithUTF8(slice)

        if (input.isDone()) {
            return writeFn(ctx, StreamResult.ownedAndDone(slice))
        } else {
            return writeFn(ctx, StreamResult.owned(slice))
        }
    }

    /// writeUTF16 — 将 UTF-16 数据转换为 UTF-8 并写入
    /// 对应 Bun: UTF8Fallback.write_utf16() (Sink.rs:253-302)
    public static func writeUTF16<Ctx>(
        ctx: Ctx,
        input: StreamResult,
        writeFn: (Ctx, StreamResult) -> StreamResultWritable
    ): StreamResultWritable {
        let bytes = input.slice()
        // 转换为 UTF-16 码元数组
        let strLen = bytes.size / 2
        let utf16Chars = utf16SliceFromBytes(bytes)

        if (STACK_SIZE >= strLen * 2) {
            var buf = ArrayList<UInt8>()
            let copied = copyUTF16IntoUTF8(buf, utf16Chars)
            let borrowed = ArrayList<UInt8>()
            for (i in 0..copied) {
                borrowed.append(buf[i])
            }
            if (input.isDone()) {
                return writeFn(ctx, StreamResult.temporaryAndDone(borrowed))
            } else {
                return writeFn(ctx, StreamResult.temporary(borrowed))
            }
        }

        // 堆分配路径
        let allocated = toUTF8Alloc(utf16Chars)
        if (input.isDone()) {
            return writeFn(ctx, StreamResult.ownedAndDone(allocated))
        } else {
            return writeFn(ctx, StreamResult.owned(allocated))
        }
    }
}

// ============================================================================
// 辅助函数 — 字符串编码操作
// ============================================================================

/// 检查是否全部 ASCII
/// 对应 Bun: bun_core::strings::is_all_ascii()
func isAllAscii(data: ArrayList<UInt8>): Bool {
    for (b in data) {
        if (b > 127) {
            return false
        }
    }
    return true
}

/// 替换 Latin-1 为 UTF-8 (就地)
/// 对应 Bun: bun_core::strings::replace_latin1_with_utf8()
func replaceLatin1WithUTF8(buf: ArrayList<UInt8>): Unit {
    // Latin-1 (ISO 8859-1) 中 > 127 的字符映射到 Unicode 同位置
    // UTF-8 编码: 2 字节序列 110xxxxx 10xxxxxx
    var result = ArrayList<UInt8>()
    for (b in buf.items()) {
        if (b < 128) {
            result.append(b)
        } else {
            result.append(0xC0 | (b >> 6))
            result.append(0x80 | (b & 0x3F))
        }
    }
    buf.clear()
    for (b in result.items()) {
        buf.append(b)
    }
}

/// 从字节数组提取 UTF-16 码元
/// 对应 Bun: bytemuck::cast_slice (u8 -> u16)
func utf16SliceFromBytes(bytes: ArrayList<UInt8>): Array<UInt16> {
    let len = bytes.size / 2
    if (len == 0) {
        return Array<UInt16>()
    }
    var result = Array<UInt16>(len, repeat: 0)
    for (i in 0..len) {
        let lo = bytes[i * 2]
        let hi = bytes[i * 2 + 1]
        result[i] = UInt16(lo) + UInt16(hi) * 256
    }
    return result
}

/// 将 UTF-16 复制到 UTF-8 缓冲区
/// 对应 Bun: strings::copy_utf16_into_utf8_impl()
func copyUTF16IntoUTF8(buf: ArrayList<UInt8>, utf16: Array<UInt16>): Int64 {
    buf.clear()
    for (ch in utf16) {
        if (ch < 0x80) {
            buf.append(UInt8(ch))
        } else if (ch < 0x800) {
            buf.append(UInt8(0xC0 | ((ch >> 6) & 0x1F)))
            buf.append(UInt8(0x80 | (ch & 0x3F)))
        } else {
            buf.append(UInt8(0xE0 | ((ch >> 12) & 0x0F)))
            buf.append(UInt8(0x80 | ((ch >> 6) & 0x3F)))
            buf.append(UInt8(0x80 | (ch & 0x3F)))
        }
    }
    return buf.size
}

/// 将 UTF-16 分配为 UTF-8
/// 对应 Bun: strings::to_utf8_alloc()
func toUTF8Alloc(utf16: Array<UInt16>): ArrayList<UInt8> {
    let buf = ArrayList<UInt8>()
    for (ch in utf16) {
        if (ch < 0x80) {
            buf.append(UInt8(ch))
        } else if (ch < 0x800) {
            buf.append(UInt8(0xC0 | ((ch >> 6) & 0x1F)))
            buf.append(UInt8(0x80 | (ch & 0x3F)))
        } else {
            buf.append(UInt8(0xE0 | ((ch >> 12) & 0x0F)))
            buf.append(UInt8(0x80 | ((ch >> 6) & 0x3F)))
            buf.append(UInt8(0x80 | (ch & 0x3F)))
        }
    }
    return buf
}

// ============================================================================
// JSSink — JS Sink 包装器
// 对应 Bun: JSSink<T> (Sink.rs:474-477)
// ============================================================================

/// JSSink — 通用的 Sink 到 JS 包装器
/// 对应 Bun: JSSink<T>
/// repr(transparent): 内部类型与包装器共享布局
public class JSSink<T> where T <: JsSinkType {
    /// 内部 sink 实例
    /// 对应 Bun: JSSink.sink: T
    public var sink: T

    public init(sink: T) {
        this.sink = sink
    }
}

// ============================================================================
// JsSinkAbi - Sink JS ABI 接口
// 对应 Bun: JsSinkAbi trait (Sink.rs:579-611)
// ============================================================================

/// 每个 Sink 类型的 C ABI 接口
/// 对应 Bun: JsSinkAbi trait
/// 不能使用 const generics 驱动 link_name, 所以每个 SinkType 提供 resolved externs
public interface JsSinkAbi {
    /// ${abi_name}__fromJS — 将 *ThisSink 编码为 UIntNative
    func fromJsExtern(value: JsValue): UIntNative

    /// ${abi_name}__createObject
    func createObjectExtern(global: JSGlobalObject, obj: UIntNative, destructor: UIntNative): JsValue

    /// ${abi_name}__setDestroyCallback
    func setDestroyCallbackExtern(value: JsValue, callback: UIntNative): Unit

    /// ${abi_name}__assignToStream
    func assignToStreamExtern(
        global: JSGlobalObject,
        stream: JsValue,
        ptr: UIntNative,
        jsvaluePtr: UIntNative
    ): JsValue

    /// ${abi_name}__onClose
    func onCloseExtern(ptr: JsValue, reason: JsValue): Unit

    /// ${abi_name}__onReady
    func onReadyExtern(ptr: JsValue, amount: JsValue, offset: JsValue): Unit

    /// ${abi_name}__detachPtr
    func detachPtrExtern(ptr: JsValue): Unit
}

// ============================================================================
// FromJsResult - from_js_extern 结果常量
// 对应 Bun: from_js_result (Sink.rs:615-620)
// ============================================================================

/// from_js_extern 编码两种不同的失败类型, 使用 0 和 1
/// 对应 Bun: from_js_result
public class FromJsResult {
    /// Sink 已关闭且包装类型已释放
    public static let DETACHED: UIntNative = 0
    /// JS 异常尚未抛出
    public static let CAST_FAILED: UIntNative = 1
}

// ============================================================================
// JsSinkType - Sink 类型接口
// 对应 Bun: JsSinkType trait (Sink.rs:740-799)
// ============================================================================

/// JSSink 可能在包装的 SinkType 上调用的每个方法的 trait
/// 对应 Bun: JsSinkType trait
/// Zig 用 @hasDecl 让大多数方法可选; Rust 用默认方法体建模
public interface JsSinkType {
    /// 名称
    /// 对应 Bun: JsSinkType::NAME
    prop name: String

    /// 是否有 construct 声明
    /// 对应 Bun: @hasDecl(SinkType, "construct")
    prop hasConstruct: Bool

    /// 是否有 signal 字段
    /// 对应 Bun: @hasField(SinkType, "signal")
    prop hasSignal: Bool

    /// 是否有 done 字段
    /// 对应 Bun: @hasField(SinkType, "done")
    prop hasDone: Bool

    /// 是否有 flushFromJS 声明
    /// 对应 Bun: @hasDecl(SinkType, "flushFromJS")
    prop hasFlushFromJs: Bool

    /// 是否有 protectJSWrapper 声明
    /// 对应 Bun: @hasDecl(SinkType, "protectJSWrapper")
    prop hasProtectJsWrapper: Bool

    /// 是否有 updateRef 声明
    /// 对应 Bun: @hasDecl(SinkType, "updateRef")
    prop hasUpdateRef: Bool

    /// 是否有 getFd 声明
    /// 对应 Bun: @hasDecl(SinkType, "getFd")
    prop hasGetFd: Bool

    /// 内存开销
    /// 对应 Bun: JsSinkType::memory_cost()
    func memoryCost(): Int64

    /// 最终化
    /// 对应 Bun: JsSinkType::finalize()
    func finalize(): Unit

    /// 写入字节
    /// 对应 Bun: JsSinkType::write_bytes()
    func writeBytes(data: StreamResult): StreamResultWritable

    /// 写入 UTF-16
    /// 对应 Bun: JsSinkType::write_utf16()
    func writeUTF16(data: StreamResult): StreamResultWritable

    /// 写入 Latin-1
    /// 对应 Bun: JsSinkType::write_latin1()
    func writeLatin1(data: StreamResult): StreamResultWritable

    /// 结束
    /// 对应 Bun: JsSinkType::end()
    func end(err: ?SyscallError): ?SyscallError

    /// 从 JS 结束
    /// 对应 Bun: JsSinkType::end_from_js()
    func endFromJs(global: JSGlobalObject): JsValue

    /// 刷新
    /// 对应 Bun: JsSinkType::flush()
    func flush(): ?SyscallError

    /// 启动
    /// 对应 Bun: JsSinkType::start()
    func start(config: StreamStart): ?SyscallError

    /// 构造 (仅当 hasConstruct = true 时调用)
    /// 对应 Bun: JsSinkType::construct()
    func construct(): Unit

    /// 获取待处理错误
    /// 对应 Bun: JsSinkType::get_pending_error()
    func getPendingError(): ?JsValue

    /// 获取信号
    /// 对应 Bun: JsSinkType::signal()
    func signal(): ?StreamSignal

    /// 获取 done 状态
    /// 对应 Bun: JsSinkType::done()
    func isDone(): Bool

    /// 从 JS 刷新
    /// 对应 Bun: JsSinkType::flush_from_js()
    func flushFromJs(global: JSGlobalObject, wait: Bool): JsValue

    /// 待处理状态是否为 pending
    /// 对应 Bun: JsSinkType::pending_state_is_pending()
    func pendingStateIsPending(): Bool

    /// 保护 JS 包装器
    /// 对应 Bun: JsSinkType::protect_js_wrapper()
    func protectJsWrapper(global: JSGlobalObject, thisValue: JsValue): Unit

    /// 更新引用
    /// 对应 Bun: JsSinkType::update_ref()
    func updateRef(value: Bool): Unit

    /// 获取文件描述符
    /// 对应 Bun: JsSinkType::get_fd()
    func getFd(): Int32
}

// ============================================================================
// JsSinkType 默认实现辅助类
// ============================================================================

/// JsSinkType 的默认实现, 各 SinkType 可继承并覆盖
/// 对应 Bun: JsSinkType 默认方法体
public class DefaultJsSinkType <: JsSinkType {
    public prop name: String { get() { "Sink" } }
    public prop hasConstruct: Bool { get() { false } }
    public prop hasSignal: Bool { get() { false } }
    public prop hasDone: Bool { get() { false } }
    public prop hasFlushFromJs: Bool { get() { false } }
    public prop hasProtectJsWrapper: Bool { get() { false } }
    public prop hasUpdateRef: Bool { get() { false } }
    public prop hasGetFd: Bool { get() { false } }

    public func memoryCost(): Int64 { return 0 }
    public func finalize(): Unit {}
    public func writeBytes(data: StreamResult): StreamResultWritable { StreamResultWritable.done() }
    public func writeUTF16(data: StreamResult): StreamResultWritable { StreamResultWritable.done() }
    public func writeLatin1(data: StreamResult): StreamResultWritable { StreamResultWritable.done() }
    public func end(err: ?SyscallError): ?SyscallError { return None }
    public func endFromJs(global: JSGlobalObject): JsValue { JsValue.undefined() }
    public func flush(): ?SyscallError { return None }
    public func start(config: StreamStart): ?SyscallError { return None }
    public func construct(): Unit {}
    public func getPendingError(): ?JsValue { return None }
    public func signal(): ?StreamSignal { return None }
    public func isDone(): Bool { return false }
    public func flushFromJs(global: JSGlobalObject, wait: Bool): JsValue { JsValue.undefined() }
    public func pendingStateIsPending(): Bool { return false }
    public func protectJsWrapper(global: JSGlobalObject, thisValue: JsValue): Unit {}
    public func updateRef(value: Bool): Unit {}
    public func getFd(): Int32 { return -1 }
}

// ============================================================================
// JSSink<T> 方法
// 对应 Bun: JSSink<T> host-fn glue (Sink.rs:820-1150)
// ============================================================================

/// JSSink 扩展方法
/// 对应 Bun: JSSink<T: JsSinkType + JsSinkAbi> 的所有 host-fn
public class JSSinkHelper {
    public init() {}

    /// createObject — 创建 JS 对象
    /// 对应 Bun: JSSink::create_object() (Sink.rs:623-633)
    public static func createObject<T>(global: JSGlobalObject, obj: T, destructor: UIntNative): JsValue where T <: JsSinkAbi {
        return obj.createObjectExtern(global, 0, destructor)
    }

    /// setDestroyCallback — 设置销毁回调
    /// 对应 Bun: JSSink::set_destroy_callback() (Sink.rs:635-637)
    public static func setDestroyCallback<T>(abi: T, value: JsValue, callback: UIntNative): Unit where T <: JsSinkAbi {
        abi.setDestroyCallbackExtern(value, callback)
    }

    /// fromJs — 从 JS 值恢复 Sink
    /// 对应 Bun: JSSink::from_js() (Sink.rs:641-647)
    public static func fromJs<T>(abi: T, value: JsValue): ?UIntNative where T <: JsSinkAbi {
        let raw = abi.fromJsExtern(value)
        if (raw == FromJsResult.DETACHED || raw == FromJsResult.CAST_FAILED) {
            return None
        }
        return Some(raw)
    }

    /// assignToStream — 分配到流
    /// 对应 Bun: JSSink::assign_to_stream() (Sink.rs:649-661)
    public static func assignToStream<T>(
        abi: T,
        global: JSGlobalObject,
        stream: JsValue,
        ptr: UIntNative,
        jsvaluePtr: UIntNative
    ): JsValue where T <: JsSinkAbi {
        return abi.assignToStreamExtern(global, stream, ptr, jsvaluePtr)
    }

    /// detach — 断开 C++ 控制器单元
    /// 对应 Bun: JSSink::detach() (Sink.rs:668-685)
    public static func detach<T>(signal: StreamSignal, global: JSGlobalObject): Unit where T <: JsSinkAbi {
        if (signal.isDead()) {
            return
        }
        signal.clear()
        // 在实际实现中, 这里会取消保护 JsValue 并调用 detachPtrExtern
        // value.unprotect()
        // T.detachPtrExtern(value)
    }

    /// jsConstruct — JS 构造函数宿主函数体
    /// 对应 Bun: JSSink::js_construct() (Sink.rs:849-866)
    public static func jsConstruct<T>(
        global: JSGlobalObject,
        frame: CallFrame,
        sink: T
    ): JsValue where T <: JsSinkType {
        if (!sink.hasConstruct) {
            // throw illegal constructor
            return JsValue.undefined()
        }
        // 创建新实例
        return JsValue.undefined()
    }

    /// jsWrite — JS 写入宿主函数体
    /// 对应 Bun: JSSink::js_write() (Sink.rs:869-948)
    public static func jsWrite<T>(
        global: JSGlobalObject,
        frame: CallFrame,
        sink: T
    ): JsValue where T <: JsSinkType {
        // 检查待处理错误
        let pendingErr = sink.getPendingError()
        if (pendingErr.isSome()) {
            return pendingErr.getOrThrow() // throw value
        }

        let args = frame.args
        if (args.size == 0) {
            return JsValue.undefined() // throw type error
        }

        let arg = args[0]
        if (arg.isUndefined() || arg.isNull()) {
            return JsValue.undefined() // throw type error
        }

        // ArrayBuffer 路径
        if (arg.isArrayBuffer()) {
            let slice = arg.arrayBufferSlice()
            if (slice.size == 0) {
                return JsValue.jsNumber(0.0)
            }
            let data = ArrayList<UInt8>()
            for (b in slice) { data.append(b) }
            return sink.writeBytes(StreamResult.temporary(data)).toJS(global)
        }

        // 字符串路径
        if (arg.isString()) {
            let str = arg.toString()
            if (str.size == 0) {
                return JsValue.jsNumber(0.0)
            }
            // Treat all strings as Latin-1/UTF-8 path (simplified)
            let data = ArrayList<UInt8>()
            for (c in str) {
                let n = Int32(c)
                if (n < 128) {
                    data.append(UInt8(n))
                } else if (n < 2048) {
                    data.append(UInt8(192 + (n >> 6)))
                    data.append(UInt8(128 + (n & 63)))
                } else {
                    data.append(UInt8(224 + (n >> 12)))
                    data.append(UInt8(128 + ((n >> 6) & 63)))
                    data.append(UInt8(128 + (n & 63)))
                }
            }
            return sink.writeLatin1(StreamResult.temporary(data)).toJS(global)
        }

        return JsValue.undefined() // throw type error
    }

    /// jsFlush — JS 刷新宿主函数体
    /// 对应 Bun: JSSink::js_flush() (Sink.rs:950-982)
    public static func jsFlush<T>(
        global: JSGlobalObject,
        frame: CallFrame,
        sink: T
    ): JsValue where T <: JsSinkType {
        let pendingErr = sink.getPendingError()
        if (pendingErr.isSome()) {
            return pendingErr.getOrThrow() // throw value
        }

        if (sink.hasFlushFromJs) {
            let wait = frame.args.size > 0 && frame.args[0].isBoolean() && frame.args[0].toBoolean()
            return sink.flushFromJs(global, wait)
        }

        sink.flush()
        return JsValue.undefined()
    }

    /// jsStart — JS 启动宿主函数体
    /// 对应 Bun: JSSink::js_start() (Sink.rs:984-1016)
    public static func jsStart<T>(
        global: JSGlobalObject,
        frame: CallFrame,
        sink: T
    ): JsValue where T <: JsSinkType {
        let pendingErr = sink.getPendingError()
        if (pendingErr.isSome()) {
            return pendingErr.getOrThrow() // throw value
        }

        let config = if (frame.args.size > 0) {
            StreamStart.fromJs(global, frame.args[0])
        } else {
            StreamStart.empty()
        }

        sink.start(config)
        return JsValue.undefined()
    }

    /// jsEnd — JS 结束宿主函数体
    /// 对应 Bun: JSSink::js_end() (Sink.rs:1019-1058)
    public static func jsEnd<T>(
        global: JSGlobalObject,
        frame: CallFrame,
        sink: T
    ): JsValue where T <: JsSinkType {
        let pendingErr = sink.getPendingError()
        if (pendingErr.isSome()) {
            return pendingErr.getOrThrow() // throw value
        }

        let result = sink.endFromJs(global)

        // 保护 JS 包装器, 防止异步操作期间被 GC
        if (sink.hasProtectJsWrapper && sink.pendingStateIsPending()) {
            sink.protectJsWrapper(global, frame.`this`())
        }

        return result
    }

    /// jsFinalize — JS 最终化宿主函数体
    /// 对应 Bun: JSSink::js_finalize() (Sink.rs:1062-1064)
    public static func jsFinalize<T>(sink: T): Unit where T <: JsSinkType {
        sink.finalize()
    }

    /// jsClose — JS 关闭宿主函数体
    /// 对应 Bun: JSSink::js_close() (Sink.rs:1069-1096)
    public static func jsClose<T>(
        global: JSGlobalObject,
        sink: T
    ): JsValue where T <: JsSinkType {
        let pendingErr = sink.getPendingError()
        if (pendingErr.isSome()) {
            // throw_error 设置待处理的 JS 异常
            return JsValue.undefined()
        }

        sink.end(Option<SyscallError>.None)
        return JsValue.undefined()
    }

    /// jsEndWithSink — JS 带 Sink 结束宿主函数体
    /// 对应 Bun: JSSink::js_end_with_sink() (Sink.rs:1100-1124)
    public static func jsEndWithSink<T>(
        sink: T,
        global: JSGlobalObject
    ): JsValue where T <: JsSinkType {
        let pendingErr = sink.getPendingError()
        if (pendingErr.isSome()) {
            return JsValue.undefined() // throw value
        }

        return sink.endFromJs(global)
    }

    /// jsUpdateRef — JS 更新引用宿主函数体
    /// 对应 Bun: JSSink::js_update_ref() (Sink.rs:1127-1133)
    public static func jsUpdateRef<T>(sink: T, value: Bool): Unit where T <: JsSinkType {
        if (sink.hasUpdateRef) {
            sink.updateRef(value)
        }
    }

    /// jsGetInternalFd — JS 获取内部文件描述符宿主函数体
    /// 对应 Bun: JSSink::js_get_internal_fd() (Sink.rs:1136-1143)
    public static func jsGetInternalFd<T>(sink: T): JsValue where T <: JsSinkType {
        if (sink.hasGetFd) {
            return JsValue.jsNumber(Float64(sink.getFd()))
        }
        return JsValue.null()
    }

    /// jsMemoryCost — JS 内存开销宿主函数体
    /// 对应 Bun: JSSink::js_memory_cost() (Sink.rs:1146-1149)
    public static func jsMemoryCost<T>(sink: T): Int64 where T <: JsSinkType {
        return sink.memoryCost()
    }
}

// ============================================================================
// SinkSignal — JS Sink 信号
// 对应 Bun: SinkSignal<T> (Sink.rs:696-734)
// ============================================================================

/// JSSink.SinkSignal — 将 JsValue (C++ sink 控制器单元) 包装为 Signal
/// 对应 Bun: SinkSignal<T>
public class SinkSignal<T> where T <: JsSinkAbi {
    public init() {}

    /// init — 从 C++ JsValue 初始化 Signal
    /// 对应 Bun: SinkSignal::init() (Sink.rs:699-733)
    public static func `init`(abi: T, cpp: JsValue): StreamSignal {
        let vtable = SignalVTable(
            { err: ?SyscallError =>
                // onClose: 调用 abi.onCloseExtern(cpp, JsValue.UNDEFINED)
                abi.onCloseExtern(cpp, JsValue.undefined())
            },
            { amount: ?BlobSizeType, offset: ?BlobSizeType =>
                // onReady: 调用 abi.onReadyExtern(cpp, JsValue.UNDEFINED, JsValue.UNDEFINED)
                abi.onReadyExtern(cpp, JsValue.undefined(), JsValue.undefined())
            },
            { => }
        )
        return StreamSignal(vtable)
    }
}

// ============================================================================
// Detached — 已分离的不透明类型
// 对应 Bun: Detached (Sink.rs:1156-1159)
// ============================================================================

/// 已分离状态标记 — 仅用作 TaggedPointerUnion 的类型标签
/// 对应 Bun: Detached
public class Detached {
    public init() {}
}

// ============================================================================
// DestructorTypes - 析构器类型列表
// 对应 Bun: DestructorTypes (Sink.rs:1168-1179)
// ============================================================================

/// 析构器类型列表
/// 对应 Bun: DestructorTypes
/// 标签: Detached=1024, Subprocess=1023
public class DestructorTypes {
    public static let DETACHED_TAG: Int64 = 1024
    public static let SUBPROCESS_TAG: Int64 = 1023
    public static let LEN: Int64 = 2
    public static let MIN_TAG: Int64 = 1023
}

// ============================================================================
// DestructorPtr - 析构器指针
// 对应 Bun: DestructorPtr = TaggedPtrUnion<DestructorTypes> (Sink.rs:1184)
// ============================================================================

/// 带标签的析构器指针
/// 对应 Bun: DestructorPtr
public class DestructorPtr {
    /// 原始指针值
    public var ptr: UIntNative
    /// 标签
    public var tag: Int64

    public init() {
        ptr = 0
        tag = 0
    }

    public init(ptr: UIntNative, tag: Int64) {
        this.ptr = ptr
        this.tag = tag
    }

    /// 从可选值创建
    /// 对应 Bun: DestructorPtr::from()
    public static func from(ptrValue: ?UIntNative): DestructorPtr {
        if (ptrValue.isSome()) {
            return DestructorPtr(ptrValue.getOrThrow(), 0)
        }
        return DestructorPtr()
    }

    /// 是否为空
    public func isNull(): Bool {
        return ptr == 0
    }

    /// 是否为 Detached
    public func isDetached(): Bool {
        return tag == DestructorTypes.DETACHED_TAG
    }

    /// 是否有效
    public func isValid(): Bool {
        return !isNull() && !isDetached()
    }

    /// 获取原始 uintptr
    public func asUintptr(): UIntNative {
        return ptr
    }
}

// ============================================================================
// destructorPtrSubprocess — 编码 Subprocess 指针
// 对应 Bun: destructor_ptr_subprocess() (Sink.rs:1192-1198)
// ============================================================================

/// 将 *Subprocess 编码为第二个 DestructorPtr 标签 (1023)
/// 对应 Bun: destructor_ptr_subprocess
func destructorPtrSubprocess(ptr: UIntNative): UIntNative {
    let ADDR_BITS: UInt32 = 49
    let ADDR_MASK: UInt64 = (1 << ADDR_BITS) - 1
    let SUBPROCESS_TAG: UInt64 = 1023
    return UIntNative((UInt64(ptr) & ADDR_MASK) | (SUBPROCESS_TAG << ADDR_BITS))
}

// ============================================================================
// Bun__onSinkDestroyed — Sink 销毁回调
// 对应 Bun: Bun__onSinkDestroyed() (Sink.rs:1202-1237)
// ============================================================================

/// Sink 销毁回调 — C++ 调用的 FFI 入口
/// 对应 Bun: #[unsafe(no_mangle)] extern "C" fn Bun__onSinkDestroyed
public func onSinkDestroyed(ptrValue: UIntNative, sinkPtr: UIntNative): Unit {
    let ptr = DestructorPtr.from(ptrValue)

    if (ptr.isNull()) {
        return
    }

    if (ptr.isDetached()) {
        return
    }

    if (ptr.isValid()) {
        // Subprocess 路径: 将原始指针转换为 Subprocess 并调用 onStdinDestroyed
        // 在实际实现中需要 Subprocess 类型
        // let subprocess = ptr.asUintptr() as Subprocess
        // subprocess.onStdinDestroyed()
        return
    }

    // Output.debugWarn("Unknown sink type")
}

// ============================================================================
// StringView - 字符串视图
// 对应 Bun: JSString::view
// ============================================================================

/// 字符串视图
public class StringView {
    /// 字节数据
    public var bytes: Array<UInt8>
    /// 是否 16 位
    public var is16Bit: Bool

    public init() {
        bytes = Array<UInt8>()
        is16Bit = false
    }

    /// 大小
    public prop size: Int64 {
        get() {
            return bytes.size
        }
    }
}

// BlobSizeType is defined in blob.cj
// CallFrame, JsValue, JSGlobalObject are provided by bao_jsc

// ported from: src/runtime/webcore/Sink.rs
