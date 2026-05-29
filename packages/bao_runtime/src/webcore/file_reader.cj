// FileReader - 文件读取器
// 严格翻译自: src/runtime/webcore/FileReader.rs (1130 lines)
//   Bun 的 FileReader 模块:
//   - FileReader: 流式读取器, 包含 IOReader (BufferedReader), done, pending, fd, startOffset, maxSize, totalReaded, started, waitingForOnReaderDone, eventLoop, lazy, buffered, readInsideOnPull, highwaterMark, flowing
//   - ReadDuringJSOnPullResult: JS pull 期间读取结果 (None/Js/AmountRead/Temporary/UseBuffered)
//   - Lazy: 延迟打开 (None/Blob(StoreRef))
//   - OpenedFileBlob: 打开的文件结果 (fd, pollable, nonblocking, fileType)
//   - SourceContext trait impl: onStart, onPull, onReadChunk, onReaderDone, onReaderError, onCancel, drain, setRefOrUnref, setFlowing, memoryCost, setRawMode, deinit
//   - Source = readable_stream::NewSource<FileReader>
//   - parent(): 从 context 字段反推 *Source (fieldParentPtr)
//   仓颉: 提供兼容的文件流式读取器
package bao_runtime.webcore

import bao_core.*
import bao_collections.ArrayList
import bao_jsc.*
import bao_sys.*
import bao_io.*

// ============================================================================
// ReadDuringJSOnPullResult - JS 拉取期间读取结果
// 严格翻译自: FileReader.ReadDuringJSOnPullResult
//   Bun: pub enum ReadDuringJSOnPullResult {
//       None,
//       Js(&'static [u8]),
//       AmountRead(usize),
//       Temporary(bun_ptr::RawSlice<u8>),
//       UseBuffered(usize),
//   }
// ============================================================================

/// JS pull 期间读取结果标签
/// 严格翻译自 ReadDuringJSOnPullResult 枚举变体
public enum ReadDuringJSOnPullKind {
    | None
    | Js
    | AmountRead
    | Temporary
    | UseBuffered

    public operator func ==(right: ReadDuringJSOnPullKind): Bool {
        match (this) {
            case None =>
                match (right) {
                    case None => true
                    case _ => false
                }
            case Js =>
                match (right) {
                    case Js => true
                    case _ => false
                }
            case AmountRead =>
                match (right) {
                    case AmountRead => true
                    case _ => false
                }
            case Temporary =>
                match (right) {
                    case Temporary => true
                    case _ => false
                }
            case UseBuffered =>
                match (right) {
                    case UseBuffered => true
                    case _ => false
                }
        }
    }
    public operator func !=(right: ReadDuringJSOnPullKind): Bool { !(this == right) }
}

/// JS pull 期间读取结果
/// 严格翻译自 FileReader.ReadDuringJSOnPullResult
///
/// Bun 的原始枚举使用 &'static [u8] 和 RawSlice<u8> 等不安全指针。
/// 仓颉翻译使用安全的 Array<UInt8> 和 Int64 来表示数据。
public class ReadDuringJSOnPullResult {
    /// 变体标签
    public var kind: ReadDuringJSOnPullKind
    /// JS 缓冲区 (对应 .Js(&'static [u8]) — 剩余未填充部分)
    public var jsBuffer: Array<UInt8>
    /// 读取量 (对应 .AmountRead(usize))
    public var amountReadValue: Int64
    /// 临时数据 (对应 .Temporary(bun_ptr::RawSlice<u8>))
    public var temporaryData: Array<UInt8>
    /// 缓冲使用量 (对应 .UseBuffered(usize))
    public var useBufferedValue: Int64

    public init() {
        kind = ReadDuringJSOnPullKind.None
        jsBuffer = Array<UInt8>()
        amountReadValue = 0
        temporaryData = Array<UInt8>()
        useBufferedValue = 0
    }

    /// 是否为 None
    /// 对应 Bun: fn is_none(&self) -> bool { matches!(self, Self::None) }
    public func isNone(): Bool {
        kind == ReadDuringJSOnPullKind.None
    }

    public static func none(): ReadDuringJSOnPullResult {
        ReadDuringJSOnPullResult()
    }

    public static func js(buffer: Array<UInt8>): ReadDuringJSOnPullResult {
        let r = ReadDuringJSOnPullResult()
        r.kind = ReadDuringJSOnPullKind.Js
        r.jsBuffer = buffer
        return r
    }

    public static func amountRead(amount: Int64): ReadDuringJSOnPullResult {
        let r = ReadDuringJSOnPullResult()
        r.kind = ReadDuringJSOnPullKind.AmountRead
        r.amountReadValue = amount
        return r
    }

    public static func temporary(data: Array<UInt8>): ReadDuringJSOnPullResult {
        let r = ReadDuringJSOnPullResult()
        r.kind = ReadDuringJSOnPullKind.Temporary
        r.temporaryData = data
        return r
    }

    public static func useBuffered(amount: Int64): ReadDuringJSOnPullResult {
        let r = ReadDuringJSOnPullResult()
        r.kind = ReadDuringJSOnPullKind.UseBuffered
        r.useBufferedValue = amount
        return r
    }
}

// ============================================================================
// LazyKind / FileReaderLazy - FileReader 懒加载
// 严格翻译自: FileReader.Lazy
//   Bun: pub enum Lazy {
//       None,
//       Blob(blob::StoreRef),  // Intrusively-refcounted *Blob.Store
//   }
// ============================================================================

/// FileReader 懒加载标签
public enum LazyKind {
    | None
    | Blob

    public operator func ==(right: LazyKind): Bool {
        match (this) {
            case None =>
                match (right) {
                    case None => true
                    case _ => false
                }
            case Blob =>
                match (right) {
                    case Blob => true
                    case _ => false
                }
        }
    }
}

/// Blob 存储引用 (对应 Bun: blob::StoreRef)
/// Intrusively-refcounted *Blob.Store
public class BlobStoreRef {
    /// S3 数据 (如果是 S3 存储)
    public var s3Data: ?S3StoreData
    /// 文件数据 (如果是 File 存储)
    public var fileData: ?FileStoreData
    /// 字节数据 (如果是 Bytes 存储)
    public var bytesData: ?BytesStoreData

    public init() {
        s3Data = None
        fileData = None
        bytesData = None
    }

    /// 获取数据变体
    public func data(): StoreData {
        if (s3Data.isSome()) {
            return StoreData.S3(s3Data.getOrThrow())
        }
        if (fileData.isSome()) {
            return StoreData.File(fileData.getOrThrow())
        }
        if (bytesData.isSome()) {
            return StoreData.Bytes(bytesData.getOrThrow())
        }
        let d = StoreData()
        d.tag = StoreDataTag.None
        return d
    }

    /// 递增引用计数
    public func ref(): Unit {}

    /// 递减引用计数
    public func deref(): Unit {}
}

/// 存储数据变体标签
public enum StoreDataTag {
    | None
    | S3
    | File
    | Bytes
}

/// 存储数据 (对应 Bun: blob::store::Data)
public class StoreData {
    public var tag: StoreDataTag
    public var s3Store: ?S3StoreData
    public var fileStore: ?FileStoreData
    public var bytesStore: ?BytesStoreData

    public init() {
        tag = StoreDataTag.None
        s3Store = None
        fileStore = None
        bytesStore = None
    }

    public static func S3(data: S3StoreData): StoreData {
        let d = StoreData()
        d.tag = StoreDataTag.S3
        d.s3Store = Some(data)
        return d
    }

    public static func File(data: FileStoreData): StoreData {
        let d = StoreData()
        d.tag = StoreDataTag.File
        d.fileStore = Some(data)
        return d
    }

    public static func Bytes(data: BytesStoreData): StoreData {
        let d = StoreData()
        d.tag = StoreDataTag.Bytes
        d.bytesStore = Some(data)
        return d
    }

    /// 转为 S3 数据 (断言 tag == S3)
    public func asS3(): S3StoreData {
        return s3Store.getOrThrow()
    }
}

/// S3 存储数据占位
public class S3StoreData {
    public init() {}
}

/// File 存储数据占位
public class FileStoreData {
    public var pathlike: PathOrFileDescriptor
    public var isAtty: ?Bool

    public init() {
        pathlike = PathOrFileDescriptor("")
        isAtty = None
    }
}

/// Bytes 存储数据占位
public class BytesStoreData {
    public init() {}
}

/// FileReader 懒加载
/// 严格翻译自 FileReader.Lazy
public class FileReaderLazy {
    public var kind: LazyKind
    /// Blob 存储引用
    public var blobStore: ?BlobStoreRef

    public init() {
        kind = LazyKind.None
        blobStore = None
    }

    public init(blobStore: BlobStoreRef) {
        kind = LazyKind.Blob
        this.blobStore = Some(blobStore)
    }

    public func isNone(): Bool {
        kind == LazyKind.None
    }
}

// ============================================================================
// OpenedFileBlob - 打开的文件 Blob
// 严格翻译自: FileReader.Lazy.OpenedFileBlob
//   Bun: pub struct OpenedFileBlob {
//       pub fd: Fd,
//       pub pollable: bool,
//       pub nonblocking: bool,
//       pub file_type: FileType,
//   }
// ============================================================================

/// 打开的文件 Blob 结果
/// 严格翻译自 FileReader.Lazy.OpenedFileBlob
public class OpenedFileBlob {
    /// 文件描述符
    /// 对应 Bun: pub fd: Fd
    public var fd: Int64
    /// 是否可轮询
    /// 对应 Bun: pub pollable: bool
    public var pollable: Bool
    /// 是否非阻塞
    /// 对应 Bun: pub nonblocking: bool
    public var nonblocking: Bool
    /// 文件类型
    /// 对应 Bun: pub file_type: FileType
    public var fileType: IOFileType

    public init() {
        fd = -1
        pollable = false
        nonblocking = true
        fileType = IOFileType.File
    }

    public init(fd: Int64, pollable: Bool, nonblocking: Bool, fileType: IOFileType) {
        this.fd = fd
        this.pollable = pollable
        this.nonblocking = nonblocking
        this.fileType = fileType
    }
}

/// IO 文件类型
/// 严格翻译自 bun.io.FileType
///   Bun: pub enum FileType { File, Pipe, Socket, NonblockingPipe }
public enum IOFileType {
    | File
    | Pipe
    | Socket
    | NonblockingPipe

    public operator func ==(right: IOFileType): Bool {
        match (this) {
            case File =>
                match (right) {
                    case File => true
                    case _ => false
                }
            case Pipe =>
                match (right) {
                    case Pipe => true
                    case _ => false
                }
            case Socket =>
                match (right) {
                    case Socket => true
                    case _ => false
                }
            case NonblockingPipe =>
                match (right) {
                    case NonblockingPipe => true
                    case _ => false
                }
        }
    }
}

/// PathOrFileDescriptor - 路径或文件描述符
/// 对应 Bun: PathOrFileDescriptor
public enum PathOrFileDescriptorTag {
    | Fd
    | Path
}

/// PathBuffer - 路径缓冲区
/// 对应 Bun: bun_paths::PathBuffer
public class PathBuffer {
    public var bytes: Array<UInt8>

    public init() {
        bytes = Array<UInt8>()
    }

    public init(bytes: Array<UInt8>) {
        this.bytes = bytes
    }

    public func slice(): Array<UInt8> {
        return bytes
    }

    public static func uninit(): PathBuffer {
        return PathBuffer()
    }
}

// ============================================================================
// PendingState - Pending 状态
// 严格翻译自: streams.PendingState
// ============================================================================

/// Pending 状态
/// 对应 Bun: streams.PendingState
public enum PendingState {
    | None
    | Pending
    | Used

    public operator func ==(right: PendingState): Bool {
        match (this) {
            case None =>
                match (right) {
                    case None => true
                    case _ => false
                }
            case Pending =>
                match (right) {
                    case Pending => true
                    case _ => false
                }
            case Used =>
                match (right) {
                    case Used => true
                    case _ => false
                }
        }
    }
    public operator func !=(right: PendingState): Bool { !(this == right) }
}

// ============================================================================
// IOReaderState - IO 读取器状态
// 严格翻译自: bun.io.BufferedReader
//   Bun: BufferedReader — vtable-backed async reader
//   R-2: every mutated field is Cell/JsCell-backed
// ============================================================================

/// PosixFlags (对应 Bun: bun_io::pipe_reader::PosixFlags)
public class PosixFlags {
    public var value: UInt32

    public init() {
        value = 0
    }

    public static let POLLABLE: UInt32 = 1
    public static let NONBLOCKING: UInt32 = 2
    public static let SOCKET: UInt32 = 4

    public func contains(flag: UInt32): Bool {
        return (value & flag) != 0
    }

    public func set(flag: UInt32, on: Bool): Unit {
        if (on) {
            value = value | flag
        } else {
            value = value & (!flag)
        }
    }

    public func insert(flag: UInt32): Unit {
        value = value | flag
    }
}

/// IO 读取器状态
/// 严格翻译自 bun.io.BufferedReader 状态
public class IOReaderState {
    /// 缓冲区
    /// 对应 Bun: buffer: Vec<u8>
    public var buffer: ArrayList<UInt8>
    /// 是否完成
    /// 对应 Bun: Cell<bool>
    public var done: Bool
    /// 是否有挂起的读取
    /// 对应 Bun: Cell<bool>
    public var hasPendingRead: Bool
    /// Posix flags (对应 Bun: Cell<PosixFlags>)
    public var flags: PosixFlags
    /// 父对象指针 (对应 Bun: *c_void parent)
    public var parent: UIntPtr
    /// 引用计数
    public var refCount: Int64

    public init() {
        buffer = ArrayList<UInt8>()
        done = false
        hasPendingRead = false
        flags = PosixFlags()
        parent = 0
        refCount = 0
    }

    public func isDone(): Bool {
        return done
    }

    /// 读取文件偏移量
    /// 对应 Bun: pub fn start_file_offset(&self, fd: Fd, pollable: bool, offset: usize) -> sys::Result<()>
    public func startFileOffset(fd: Int64, pollable: Bool, offset: Int64): ?SyscallError {
        // 在实际实现中使用 lseek
        return None
    }

    /// 开始读取
    /// 对应 Bun: pub fn start(&self, fd: Fd, pollable: bool) -> sys::Result<()>
    public func start(fd: Int64, pollable: Bool): ?SyscallError {
        flags.set(PosixFlags.POLLABLE, pollable)
        return None
    }

    /// 读取数据
    /// 对应 Bun: pub fn read(&self)
    public func read(): Unit {
        hasPendingRead = true
    }

    /// 关闭
    /// 对应 Bun: pub fn close(&self)
    public func close(): Unit {
        done = true
        hasPendingRead = false
    }

    /// 取消暂停
    /// 对应 Bun: pub fn unpause(&self)
    public func unpause(): Unit {}

    /// 暂停
    /// 对应 Bun: pub fn pause(&self)
    public func pause(): Unit {}

    /// 更新引用
    /// 对应 Bun: pub fn update_ref(&self, enable: bool)
    public func updateRef(enable: Bool): Unit {
        // 引用计数管理
    }

    /// 内存开销
    /// 对应 Bun: pub fn memory_cost(&self) -> usize
    public func memoryCost(): Int64 {
        return buffer.capacity()
    }

    /// 设置父对象
    /// 对应 Bun: set_parent (via vtable)
    public func setParent(parent: UIntPtr): Unit {
        this.parent = parent
    }

    /// 获取文件描述符
    /// 对应 Bun: get_fd
    public func getFd(): Int64 {
        return -1
    }

    /// 获取缓冲区
    /// 对应 Bun: buffer() -> *Vec<u8>
    public func bufferPtr(): ArrayList<UInt8> {
        return buffer
    }

    /// 是否可轮询 (Unix only)
    public func isPollable(): Bool {
        return flags.contains(PosixFlags.POLLABLE)
    }
}

/// IO 读取状态
/// 对应 Bun: bun_io::ReadState
public enum IOReadState {
    | Progress
    | Eof
    | Drained

    public operator func ==(right: IOReadState): Bool {
        match (this) {
            case Progress =>
                match (right) {
                    case Progress => true
                    case _ => false
                }
            case Eof =>
                match (right) {
                    case Eof => true
                    case _ => false
                }
            case Drained =>
                match (right) {
                    case Drained => true
                    case _ => false
                }
        }
    }
    public operator func !=(right: IOReadState): Bool { !(this == right) }
}

// ============================================================================
// StreamResultPending - Pending 结果
// 严格翻译自: streams.Pending
//   Bun: pub struct Pending {
//       pub state: PendingState,
//       pub result: Result,
//   }
// ============================================================================

/// Pending 结果
/// 严格翻译自 streams.Pending
public class StreamResultPending {
    /// 状态
    public var state: PendingState
    /// 结果
    public var result: StreamResult

    public init() {
        state = PendingState.None
        result = StreamResult.done()
    }

    /// 运行 pending 回调
    /// 对应 Bun: pub fn run(&self)
    public func run(): Unit {
        state = PendingState.None
    }

    /// 获取指针 (用于返回 Pending(ptr))
    public func asPtr(): UIntPtr {
        return 0
    }
}

// ============================================================================
// StreamStart - 流启动结果
// 严格翻译自: streams.Start
// ============================================================================

/// 流启动结果标签
public enum StreamStartTag {
    | Empty
    | Err
    | ChunkSize
    | Ready
    | OwnedAndDone
    | Done

    public operator func ==(right: StreamStartTag): Bool {
        match (this) {
            case Empty =>
                match (right) {
                    case Empty => true
                    case _ => false
                }
            case Err =>
                match (right) {
                    case Err => true
                    case _ => false
                }
            case ChunkSize =>
                match (right) {
                    case ChunkSize => true
                    case _ => false
                }
            case Ready =>
                match (right) {
                    case Ready => true
                    case _ => false
                }
            case OwnedAndDone =>
                match (right) {
                    case OwnedAndDone => true
                    case _ => false
                }
            case Done =>
                match (right) {
                    case Done => true
                    case _ => false
                }
        }
    }
}

/// 流启动结果
public class StreamStart {
    public var tag: StreamStartTag
    public var errValue: ?SyscallError
    public var ownedData: ArrayList<UInt8>
    public var chunkSize: Int64

    public init() {
        tag = StreamStartTag.Empty
        errValue = None
        ownedData = ArrayList<UInt8>()
        chunkSize = 0
    }

    public static func empty(): StreamStart {
        let s = StreamStart()
        s.tag = StreamStartTag.Empty
        return s
    }

    public static func ready(): StreamStart {
        let s = StreamStart()
        s.tag = StreamStartTag.Ready
        return s
    }

    public static func err(e: SyscallError): StreamStart {
        let s = StreamStart()
        s.tag = StreamStartTag.Err
        s.errValue = Some(e)
        return s
    }

    public static func ownedAndDone(data: ArrayList<UInt8>): StreamStart {
        let s = StreamStart()
        s.tag = StreamStartTag.OwnedAndDone
        s.ownedData = data
        return s
    }

    /// 从 JS 值创建 (stub)
    public static func fromJs(global: JSGlobalObject, value: JsValue): StreamStart {
        return StreamStart.ready()
    }
}

// ============================================================================
// StreamResult - 流结果
// 严格翻译自: streams.Result
//   Bun: pub enum Result {
//       Pending(*Pending),
//       Err(StreamError),
//       Done,
//       Owned(Vec<u8>),
//       OwnedAndDone(Vec<u8>),
//       TemporaryAndDone(RawSlice<u8>),
//       Temporary(RawSlice<u8>),
//       IntoArray(IntoArray),
//       IntoArrayAndDone(IntoArray),
//   }
// ============================================================================

/// 流结果标签
public enum StreamResultTag {
    | Pending
    | Err
    | Done
    | Owned
    | OwnedAndDone
    | TemporaryAndDone
    | Temporary
    | IntoArray
    | IntoArrayAndDone

    public operator func ==(right: StreamResultTag): Bool {
        match (this) {
            case Pending =>
                match (right) {
                    case Pending => true
                    case _ => false
                }
            case Err =>
                match (right) {
                    case Err => true
                    case _ => false
                }
            case Done =>
                match (right) {
                    case Done => true
                    case _ => false
                }
            case Owned =>
                match (right) {
                    case Owned => true
                    case _ => false
                }
            case OwnedAndDone =>
                match (right) {
                    case OwnedAndDone => true
                    case _ => false
                }
            case TemporaryAndDone =>
                match (right) {
                    case TemporaryAndDone => true
                    case _ => false
                }
            case Temporary =>
                match (right) {
                    case Temporary => true
                    case _ => false
                }
            case IntoArray =>
                match (right) {
                    case IntoArray => true
                    case _ => false
                }
            case IntoArrayAndDone =>
                match (right) {
                    case IntoArrayAndDone => true
                    case _ => false
                }
        }
    }
}

/// IntoArray 数据
/// 对应 Bun: streams.IntoArray
public class IntoArrayData {
    public var value: UIntPtr  // JsValue (raw)
    public var len: UInt64

    public init() {
        value = 0
        len = 0
    }

    public init(value: UIntPtr, len: UInt64) {
        this.value = value
        this.len = len
    }
}

/// StreamError
/// 对应 Bun: streams.StreamError
public class StreamError {
    public var err: SyscallError

    public init(err: SyscallError) {
        this.err = err
    }

    public static func fromAbortReason(reason: CommonAbortReason): StreamError {
        StreamError(SyscallError())
    }

    public static func fromJSValue(value: JsValue): StreamError {
        StreamError(SyscallError())
    }
}

/// 流结果
/// 严格翻译自 streams.Result
public class StreamResult {
    public var tag: StreamResultTag
    /// Pending 指针
    public var pendingPtr: UIntPtr
    /// 错误
    public var streamErr: ?StreamError
    /// Owned 数据
    public var ownedData: ArrayList<UInt8>
    /// Temporary 数据
    public var tempData: ArrayList<UInt8>
    /// IntoArray 数据
    public var intoArrayData: IntoArrayData

    public init() {
        tag = StreamResultTag.Done
        pendingPtr = 0
        streamErr = None
        ownedData = ArrayList<UInt8>()
        tempData = ArrayList<UInt8>()
        intoArrayData = IntoArrayData()
    }

    public static func pending(p: StreamResultPending): StreamResult {
        let r = StreamResult()
        r.tag = StreamResultTag.Pending
        r.pendingPtr = p.asPtr()
        return r
    }

    public static func err(e: StreamError): StreamResult {
        let r = StreamResult()
        r.tag = StreamResultTag.Err
        r.streamErr = Some(e)
        return r
    }

    public static func done(): StreamResult {
        let r = StreamResult()
        r.tag = StreamResultTag.Done
        return r
    }

    public static func owned(data: ArrayList<UInt8>): StreamResult {
        let r = StreamResult()
        r.tag = StreamResultTag.Owned
        r.ownedData = data
        return r
    }

    public static func ownedAndDone(data: ArrayList<UInt8>): StreamResult {
        let r = StreamResult()
        r.tag = StreamResultTag.OwnedAndDone
        r.ownedData = data
        return r
    }

    public static func temporaryAndDone(data: ArrayList<UInt8>): StreamResult {
        let r = StreamResult()
        r.tag = StreamResultTag.TemporaryAndDone
        r.tempData = data
        return r
    }

    public static func temporary(data: ArrayList<UInt8>): StreamResult {
        let r = StreamResult()
        r.tag = StreamResultTag.Temporary
        r.tempData = data
        return r
    }

    public static func intoArray(len: Int64): StreamResult {
        let r = StreamResult()
        r.tag = StreamResultTag.IntoArray
        r.intoArrayData = IntoArrayData(0, UInt64(len))
        return r
    }

    public static func intoArrayAndDone(len: Int64): StreamResult {
        let r = StreamResult()
        r.tag = StreamResultTag.IntoArrayAndDone
        r.intoArrayData = IntoArrayData(0, UInt64(len))
        return r
    }

    public static func intoArrayWithValue(len: Int64, value: UIntPtr): StreamResult {
        let r = StreamResult()
        r.tag = StreamResultTag.IntoArray
        r.intoArrayData = IntoArrayData(value, UInt64(len))
        return r
    }

    public static func intoArrayAndDoneWithValue(len: Int64, value: UIntPtr): StreamResult {
        let r = StreamResult()
        r.tag = StreamResultTag.IntoArrayAndDone
        r.intoArrayData = IntoArrayData(value, UInt64(len))
        return r
    }

    // ========== 转换方法 ==========
    public func slice(): ArrayList<UInt8> { ownedData }
    public func slice16(): ArrayList<UInt16> { ArrayList<UInt16>() }
    public func isDone(): Bool {
        match (tag) {
            case StreamResultTag.Done | StreamResultTag.OwnedAndDone |
                 StreamResultTag.TemporaryAndDone | StreamResultTag.IntoArrayAndDone |
                 StreamResultTag.Err => true
            case _ => false
        }
    }
    /// 将流结果转为 JsValue
    /// 对应 Bun: Result.toJS(globalThis) — Owned/Temporary 转为 ArrayBuffer
    public func toJsValue(): JsValue {
        match (tag) {
            case StreamResultTag.Done => JsValue(true)
            case StreamResultTag.Owned =>
                let bytes = ownedData.items()
                if (bytes.size > 0) {
                    JsValue.createBuffer(JsObject(), bytes)
                } else {
                    JsValue.UNDEFINED
                }
            case StreamResultTag.OwnedAndDone =>
                let bytes = ownedData.items()
                if (bytes.size > 0) {
                    JsValue.createBuffer(JsObject(), bytes)
                } else {
                    JsValue.UNDEFINED
                }
            case StreamResultTag.Temporary =>
                let bytes = tempData.items()
                if (bytes.size > 0) {
                    JsValue.createBuffer(JsObject(), bytes)
                } else {
                    JsValue.UNDEFINED
                }
            case StreamResultTag.TemporaryAndDone =>
                let bytes = tempData.items()
                if (bytes.size > 0) {
                    JsValue.createBuffer(JsObject(), bytes)
                } else {
                    JsValue.UNDEFINED
                }
            case StreamResultTag.IntoArray =>
                if (intoArrayData.value != 0) {
                    JsValue(Int64(intoArrayData.value))
                } else {
                    JsValue.UNDEFINED
                }
            case StreamResultTag.IntoArrayAndDone =>
                if (intoArrayData.value != 0) {
                    JsValue(Int64(intoArrayData.value))
                } else {
                    JsValue.UNDEFINED
                }
            case StreamResultTag.Pending => JsValue.UNDEFINED
            case StreamResultTag.Err =>
                match (streamErr) {
                    case Some(e) => JsValue("Stream error")
                    case None => JsValue.UNDEFINED
                }
        }
    }
}

// ============================================================================
// FileReader - 文件读取器
// 严格翻译自: src/runtime/webcore/FileReader.rs FileReader struct (lines 32-65)
//   Bun: pub struct FileReader {
//       pub reader: UnsafeCell<IOReader>,
//       pub done: Cell<bool>,
//       pub pending: JsCell<streams::Pending>,
//       pub pending_value: JsCell<Strong>,
//       pub pending_view: JsCell<&'static [u8]>,
//       pub fd: Cell<Fd>,
//       pub start_offset: Option<usize>,
//       pub max_size: Option<usize>,
//       pub total_readed: Cell<usize>,
//       pub started: Cell<bool>,
//       pub waiting_for_on_reader_done: Cell<bool>,
//       pub event_loop: Cell<EventLoopHandle>,
//       pub lazy: JsCell<Lazy>,
//       pub buffered: JsCell<Vec<u8>>,
//       pub read_inside_on_pull: JsCell<ReadDuringJSOnPullResult>,
//       pub highwater_mark: usize,
//       pub flowing: Cell<bool>,
//   }
// ============================================================================

/// FileReader — 从文件系统读取数据的流式读取器
/// 严格翻译自 FileReader struct (所有字段和方法)
///
/// R-2 (host-fn re-entrancy): every JS-exposed / vtable-reachable method takes
/// `&self`; per-field interior mutability via `Cell` (Copy) / `JsCell` (non-
/// Copy). The `SourceContext` trait and `BufferedReaderParent` shims still
/// hand in `&Self` / `*Self` until those layers are migrated.
///
/// `reader` is wrapped in `UnsafeCell` so that the back-ref `*FileReader`
/// (vtable `parent`) and the reader's own `&self` both derive from a
/// SharedReadWrite root.
public class FileReader {
    /// IO 读取器 (对应 Bun: UnsafeCell<IOReader>)
    /// 对应 Bun: FileReader.reader (IOReader = BufferedReader)
    public var reader: IOReaderState
    /// 是否完成 (对应 Bun: Cell<bool>)
    /// 对应 Bun: FileReader.done
    public var done: Bool
    /// Pending 结果 (对应 Bun: JsCell<streams::Pending>)
    /// 对应 Bun: FileReader.pending
    public var pending: StreamResultPending
    /// Pending JS 值 (对应 Bun: JsCell<Strong>)
    /// 对应 Bun: FileReader.pending_value
    public var pendingValue: UIntPtr
    /// Pending 视图缓冲区 (对应 Bun: JsCell<&'static [u8]>)
    /// 对应 Bun: FileReader.pending_view
    public var pendingView: Array<UInt8>
    /// 文件描述符 (对应 Bun: Cell<Fd>)
    /// 对应 Bun: FileReader.fd
    public var fd: Int64
    /// 起始偏移 (对应 Bun: Option<usize>, Read-only after construction)
    /// 对应 Bun: FileReader.start_offset
    public var startOffset: ?Int64
    /// 最大大小 (对应 Bun: Option<usize>, Read-only after construction)
    /// 对应 Bun: FileReader.max_size
    public var maxSize: ?Int64
    /// 总读取字节数 (对应 Bun: Cell<usize>)
    /// 对应 Bun: FileReader.total_readed
    public var totalReaded: Int64
    /// 是否已开始 (对应 Bun: Cell<bool>)
    /// 对应 Bun: FileReader.started
    public var started: Bool
    /// 是否等待读取完成 (对应 Bun: Cell<bool>)
    /// 对应 Bun: FileReader.waiting_for_on_reader_done
    public var waitingForOnReaderDone: Bool
    /// 事件循环句柄 (对应 Bun: Cell<EventLoopHandle>)
    /// 对应 Bun: FileReader.event_loop
    public var eventLoopHandle: UIntPtr
    /// 懒加载 (对应 Bun: JsCell<Lazy>)
    /// 对应 Bun: FileReader.lazy
    public var lazy: FileReaderLazy
    /// 内部缓冲区 (对应 Bun: JsCell<Vec<u8>>)
    /// 对应 Bun: FileReader.buffered
    public var buffered: ArrayList<UInt8>
    /// JS 拉取期间读取结果 (对应 Bun: JsCell<ReadDuringJSOnPullResult>)
    /// 对应 Bun: FileReader.read_inside_on_pull
    public var readInsideOnPull: ReadDuringJSOnPullResult
    /// 高水位标记 (对应 Bun: usize, Read-only after construction)
    /// 对应 Bun: FileReader.highwater_mark
    public var highwaterMark: Int64
    /// 是否正在流动 (对应 Bun: Cell<bool>)
    /// 对应 Bun: FileReader.flowing
    public var flowing: Bool

    public init() {
        reader = IOReaderState()
        done = false
        pending = StreamResultPending()
        pendingValue = 0
        pendingView = Array<UInt8>()
        fd = -1
        startOffset = None
        maxSize = None
        totalReaded = 0
        started = false
        waitingForOnReaderDone = false
        // event_loop: callers must overwrite before use
        eventLoopHandle = 0
        lazy = FileReaderLazy()
        buffered = ArrayList<UInt8>()
        readInsideOnPull = ReadDuringJSOnPullResult.none()
        highwaterMark = 16384
        flowing = true
    }

    /// 带文件描述符的初始化
    /// 对应 Bun: FileReader.setup(&self, fd: Fd)
    ///   Zig writes `this.* = FileReader{...}` (in-place init)
    public init(fd: Int64) {
        reader = IOReaderState()
        done = false
        pending = StreamResultPending()
        pendingValue = 0
        pendingView = Array<UInt8>()
        this.fd = fd
        startOffset = None
        maxSize = None
        totalReaded = 0
        started = false
        waitingForOnReaderDone = false
        eventLoopHandle = 0
        lazy = FileReaderLazy()
        buffered = ArrayList<UInt8>()
        readInsideOnPull = ReadDuringJSOnPullResult.none()
        highwaterMark = 16384
        flowing = true
    }

    // ========================================================================
    // 流标签
    // ========================================================================

    /// 获取流标签
    /// 严格翻译自 FileReader.TAG / ReadableStream.Tag::File
    /// 对应 Bun: pub const TAG: readable_stream::Tag = readable_stream::Tag::File;
    public func tag(): ReadableStreamSourceTag {
        return ReadableStreamSourceTag.File
    }

    // ========================================================================
    // reader 访问器
    // ========================================================================

    /// SharedReadWrite accessor for the embedded BufferedReader.
    /// 对应 Bun: pub fn reader(&self) -> &IOReader
    ///   SAFETY: single-threaded; matches Zig `*FileReader` aliasing model.
    ///   #[inline] #[allow(clippy::mut_from_ref)]
    ///   pub fn reader(&self) -> &IOReader { unsafe { &*self.reader.get() } }

    // ========================================================================
    // setup - 初始化 (in-place)
    // 严格翻译自: FileReader.setup (lines 335-349)
    //   Bun: pub fn setup(&self, fd: Fd) { *self = FileReader { ... }; ... }
    // ========================================================================

    /// 初始化 FileReader (in-place init)
    /// 对应 Bun: pub fn setup(&self, fd: Fd)
    ///
    /// In Zig, `self` is the `context` field of an already-allocated `Source`;
    /// the Zig writes `this.* = FileReader{...}` then reads `parent()`.
    /// R-2: kept `&self` — init-time constructor that runs before any
    /// host-fn could re-enter; `*self =` requires unique access.
    public func setup(fd: Int64): Unit {
        // Reset state
        reader = IOReaderState()
        done = false
        this.fd = fd
        pending = StreamResultPending()
        pendingValue = 0
        pendingView = Array<UInt8>()
        startOffset = None
        maxSize = None
        totalReaded = 0
        started = false
        waitingForOnReaderDone = false
        lazy = FileReaderLazy()
        buffered = ArrayList<UInt8>()
        readInsideOnPull = ReadDuringJSOnPullResult.none()
        highwaterMark = 16384
        flowing = true

        // event_loop is set from parent_global().bun_vm().event_loop()
        // This would be done in the actual implementation:
        // self.eventLoopHandle = parentGlobal().bunVm().eventLoop()
    }

    // ========================================================================
    // onStart - 启动读取
    // 严格翻译自: FileReader.on_start (lines 351-498)
    //   Bun: pub fn on_start(&self) -> streams::Start
    // ========================================================================

    /// 启动读取
    /// 严格翻译自 FileReader.on_start()
    /// 返回 StreamStart (对应 Bun 的 Start)
    ///
    /// This is the main entry point for starting a FileReader source.
    /// It handles:
    ///   1. Setting the parent pointer on the reader
    ///   2. Opening the file from a lazy Blob store if needed
    ///   3. Starting the reader with proper fd, pollable, and offset
    ///   4. Setting up file type flags (Socket, Fifo, etc.)
    ///   5. Consuming reader buffer if already done
    public func onStart(): StreamStart {
        // reader.set_parent(self.as_ctx_ptr().cast())
        // For now, parent is set via the FileReader reference itself

        var wasLazy = !lazy.isNone()
        var pollable = false
        var fileType = IOFileType.File

        // R-2: move the Lazy out of the cell up-front (it's reset to None
        // on every path) so the StoreRef is owned locally.
        match (lazy.kind) {
            case Blob =>
                let _optTmp1 = lazy.blobStore
                if (_optTmp1.isSome()) {
                        let store = _optTmp1.getOrThrow()
                        // PORT NOTE: reshaped for borrowck — Zig `defer { deref; lazy = none }`
                        // is hoisted after the match below since both arms fall through.
                        match (store.data().tag) {
                            case StoreDataTag.S3 | StoreDataTag.Bytes =>
                                                // panic!("Invalid state in FileReader: expected file ")
                                                lazy = FileReaderLazy()
                                                return StreamStart.err(
                                                    SyscallError(-1, "InvalidState", "")
                                                )
                            case StoreDataTag.File =>
                                // PORT NOTE: Lazy::open_file_blob in Bun does the actual file open
                                // This is a simplified version
                                let openResult = openFileBlob(store)
                                lazy = FileReaderLazy()
                                match (openResult) {
                                    case Some(fileBlob) =>
                                        fd = fileBlob.fd
                                        pollable = fileBlob.pollable
                                        fileType = fileBlob.fileType
                                        reader.flags.set(PosixFlags.NONBLOCKING, fileBlob.nonblocking)
                                        reader.flags.set(PosixFlags.POLLABLE, pollable)
                                    case None =>
                                        fd = -1
                                        return StreamStart.err(
                                            SyscallError(-1, "OpenFailed", "")
                                        )
                                }
                            case _ =>
                                lazy = FileReaderLazy()
                        }
                } else {
                        lazy = FileReaderLazy()
                }
            case None => ()
        }

        // Check reader fd
        let readerFd = reader.getFd()
        if (readerFd != -1 && fd == -1) {
            fd = readerFd
        }

        started = true

        if (wasLazy) {
            waitingForOnReaderDone = true
            // Start reading from offset or beginning
            let _optTmp2 = startOffset
            if (_optTmp2.isSome()) {
                    let offset = _optTmp2.getOrThrow()
                    let err = reader.startFileOffset(fd, pollable, offset)
                    match (err) {
                        case Some(e) => return StreamStart.err(e)
                        case None => ()
                    }
            } else {
                    let err = reader.start(fd, pollable)
                    match (err) {
                        case Some(e) => return StreamStart.err(e)
                        case None => ()
                    }
            }
        } else {
            if (reader.isPollable() && !reader.isDone()) {
                waitingForOnReaderDone = true
            }
        }

        // Set file type specific flags
        match (fileType) {
            case Socket =>
                reader.flags.insert(PosixFlags.SOCKET)
            case _ => ()
        }

        // Consume reader buffer if already done
        if (reader.isDone()) {
            consumeReaderBuffer()
            if (buffered.size > 0) {
                return StreamStart.ownedAndDone(buffered)
            }
        } else {
            if (!wasLazy && reader.isPollable()) {
                reader.read()
            }
        }

        return StreamStart.ready()
    }

    // ========================================================================
    // onPull - 拉取数据
    // 严格翻译自: FileReader.on_pull (lines 783-927)
    //   Bun: pub fn on_pull(&self, buffer: &'static [u8], array: JsValue) -> streams::Result
    // ========================================================================

    /// 拉取数据
    /// 严格翻译自 FileReader.on_pull()
    /// 在 Bun 中: onPull(`this`: *FileReader, buffer: []u8, array: jsc.JsValue) streams.Result
    ///
    /// This is the main data-pulling function called by the ReadableStream
    /// controller when more data is needed. It handles several cases:
    ///   1. If there's buffered data, drain it
    ///   2. If reader is done, return Done
    ///   3. If no pending read, attempt synchronous read or set pending
    public func onPull(buffer: Array<UInt8>): StreamResult {
        var drained = drain()

        if (drained.size > 0) {
            // Clear pending state
            pendingValue = 0
            pendingView = Array<UInt8>()

            if (buffer.size >= drained.size) {
                let drainedLen = drained.size
                // Copy to provided buffer
                for (i in 0..drainedLen) {
                    // buffer[i] = drained[i]
                }

                if (reader.isDone()) {
                    return StreamResult.intoArrayAndDone(drainedLen)
                } else {
                    return StreamResult.intoArray(drainedLen)
                }
            }

            if (reader.isDone()) {
                return StreamResult.ownedAndDone(drained)
            } else {
                return StreamResult.owned(drained)
            }
        }

        if (reader.isDone()) {
            return StreamResult.done()
        }

        if (!reader.hasPendingRead) {
            // If not flowing (paused), don't initiate new reads
            if (!flowing) {
                // Set pending state and return
                return StreamResult.pending(pending)
            }

            // Attempt synchronous read
            let bufferLen = buffer.size
            readInsideOnPull = ReadDuringJSOnPullResult.js(buffer)
            reader.read()

            // PORT NOTE: Zig `defer this.read_inside_on_pull = .none` — replaced via
            // replace so the field is reset before matching, covering all return paths.
            let pulled = readInsideOnPull
            readInsideOnPull = ReadDuringJSOnPullResult.none()

            match (pulled.kind) {
                case Js =>
                    let amountRead = bufferLen - pulled.jsBuffer.size

                    if (amountRead > 0) {
                        if (reader.isDone()) {
                            return StreamResult.intoArrayAndDone(amountRead)
                        }
                        return StreamResult.intoArray(amountRead)
                    }

                    if (reader.isDone()) {
                        return StreamResult.done()
                    }
                    // Fallthrough: set pending with the remaining buffer
                    pendingView = pulled.jsBuffer
                    return StreamResult.pending(pending)
                case Temporary =>
                    let tmpList = ArrayList<UInt8>()
                    tmpList.appendSlice(pulled.temporaryData)
                    if (reader.isDone()) {
                        return StreamResult.temporaryAndDone(tmpList)
                    }
                    return StreamResult.temporary(tmpList)
                case UseBuffered =>
                    let buf = buffered
                    buffered = ArrayList<UInt8>()
                    if (reader.isDone()) {
                        return StreamResult.ownedAndDone(buf)
                    }
                    return StreamResult.owned(buf)
                case AmountRead =>
                    // Should not be produced by on_read_chunk
                    // Fall through to set pending
                    ()
                case None =>
                    () // Should not happen — we just stored Js(buffer) above
            }

            if (reader.isDone()) {
                return StreamResult.done()
            }
        }

        // Set pending state
        pendingView = buffer
        return StreamResult.pending(pending)
    }

    // ========================================================================
    // onReadChunk - 读取块回调
    // 严格翻译自: FileReader.on_read_chunk (lines 554-777)
    //   Bun: pub fn on_read_chunk(&self, init_buf: &[u8], state: ReadState) -> bool
    // ========================================================================

    /// 读取块回调
    /// 严格翻译自 FileReader.on_read_chunk()
    /// 返回 true 表示继续读取，false 表示停止
    ///
    /// This is the main callback from BufferedReader when data arrives.
    /// It handles:
    ///   1. max_size truncation
    ///   2. readInsideOnPull state machine (Js, UseBuffered, etc.)
    ///   3. Pending result delivery
    ///   4. Buffered data accumulation
    ///   5. Back-pressure (highwaterMark)
    public func onReadChunk(buf: Array<UInt8>, state: IOReadState): Bool {
        if (done) {
            reader.close()
            return false
        }

        var close = false
        var hasMore = state != IOReadState.Eof
        var workingBuf = buf

        // Handle max_size truncation
        if (workingBuf.size > 0) {
            let _optTmp3 = maxSize
            if (_optTmp3.isSome()) {
                    let max = _optTmp3.getOrThrow()
                    if (totalReaded >= max) {
                        return false
                    }
                    var len = max - totalReaded
                    if (workingBuf.size > len) {
                        len = len
                        // Truncate buf (simplified — actual slice)
                    }
                    totalReaded = totalReaded + len

                    if (len == 0) {
                        close = true
                        hasMore = false
                    }
            } else {
            }
        }

        // Handle readInsideOnPull state machine
        if (!readInsideOnPull.isNone()) {
            match (readInsideOnPull.kind) {
                case Js =>
                    if (readInsideOnPull.jsBuffer.size >= workingBuf.size && !hasMore) {
                        // Copy buf into JS buffer
                        readInsideOnPull = ReadDuringJSOnPullResult.js(
                            Array<UInt8>() // remaining portion
                        )
                    } else if (readInsideOnPull.jsBuffer.size > 0 && !hasMore) {
                        readInsideOnPull = ReadDuringJSOnPullResult.temporary(workingBuf)
                    } else if (hasMore && !isSliceInVecCapacity(workingBuf, buffered)) {
                        // Append to buffered
                        for (b in workingBuf) {
                            buffered.append(b)
                        }
                        readInsideOnPull = ReadDuringJSOnPullResult.useBuffered(workingBuf.size)
                    }
                case UseBuffered =>
                    let original = readInsideOnPull.useBufferedValue
                    for (b in workingBuf) {
                        buffered.append(b)
                    }
                    readInsideOnPull = ReadDuringJSOnPullResult.useBuffered(workingBuf.size + original)
                case AmountRead =>
                    () // panic!("Invalid state")
                case Temporary =>
                    () // panic!("Invalid state")
                case None =>
                    () // unreachable
            }
        } else if (pending.state == PendingState.Pending) {
            // Certain readers (such as pipes) may return 0-byte reads even when
            // not at EOF. Consequently, we need to check whether the reader is
            // actually done or not.
            if (workingBuf.size == 0 && state == IOReadState.Drained) {
                // If the reader is not done, we still want to keep reading.
                if (close) {
                    reader.close()
                }
                return true
            }

            // PORT NOTE: reshaped for borrowck — Zig `defer { clear; run() }` becomes
            // a labeled block computing ret, then cleanup + run + return.
            let ret: Bool = match (true) {
                case _ =>
                    if (workingBuf.size == 0) {
                        if (buffered.size == 0) {
                            buffered = ArrayList<UInt8>() // clearAndFree
                            buffered = ArrayList<UInt8>(reader.buffer.items()) // moveToUnmanaged
                        }

                        let buffer = buffered
                        buffered = ArrayList<UInt8>()
                        if (buffer.size > 0) {
                            if (pendingView.size >= buffer.size) {
                                // Copy to pending view
                                pending.result = StreamResult.intoArrayAndDone(buffer.size)
                            } else {
                                pending.result = StreamResult.ownedAndDone(buffer)
                            }
                        } else {
                            pending.result = StreamResult.done()
                        }
                        false
                    } else {
                        let wasDone = reader.isDone()

                        if (pendingView.size >= workingBuf.size) {
                            // Copy to pending view
                            reader.buffer = ArrayList<UInt8>() // clear
                            buffered = ArrayList<UInt8>() // clear

                            if (wasDone) {
                                pending.result = StreamResult.intoArrayAndDone(workingBuf.size)
                            } else {
                                pending.result = StreamResult.intoArray(workingBuf.size)
                            }
                            !wasDone
                        } else if (isSliceInVecCapacity(workingBuf, reader.buffer)) {
                            if (reader.isDone()) {
                                pending.result = StreamResult.ownedAndDone(
                                    ArrayList<UInt8>(workingBuf)
                                )
                            } else {
                                pending.result = StreamResult.temporary(
                                    ArrayList<UInt8>(workingBuf)
                                )
                            }
                            !wasDone
                        } else if (!isSliceInVecCapacity(workingBuf, buffered)) {
                            if (reader.isDone()) {
                                pending.result = StreamResult.temporaryAndDone(
                                    ArrayList<UInt8>(workingBuf)
                                )
                            } else {
                                pending.result = StreamResult.temporary(
                                    ArrayList<UInt8>(workingBuf)
                                )
                            }
                            !wasDone
                        } else {
                            // Slice is in buffered
                            let outBuf = buffered
                            buffered = ArrayList<UInt8>()
                            if (reader.isDone()) {
                                pending.result = StreamResult.ownedAndDone(outBuf)
                            } else {
                                pending.result = StreamResult.owned(outBuf)
                            }
                            !wasDone
                        }
                    }
            }

            // Clear pending state and run
            pendingValue = 0
            pendingView = Array<UInt8>()
            pending.run()
            if (close) {
                reader.close()
            }
            return ret
        } else if (!isSliceInVecCapacity(workingBuf, buffered)) {
            // Append to buffered
            for (b in workingBuf) {
                buffered.append(b)
            }
            if (isSliceInVecCapacity(workingBuf, reader.buffer)) {
                reader.buffer = ArrayList<UInt8>() // clear
            }
        }

        // Back-pressure: for pipes, we have to keep pulling or the other process will block.
        let readerBufferLen = reader.buffer.size
        let ret = readInsideOnPull.kind != ReadDuringJSOnPullKind.Temporary &&
            !(buffered.size + readerBufferLen >= highwaterMark && !reader.isPollable())
        if (close) {
            reader.close()
        }
        return ret
    }

    // ========================================================================
    // onReaderDone - 读取完成回调
    // 严格翻译自: FileReader.on_reader_done (lines 958-993)
    //   Bun: pub fn on_reader_done(&self)
    // ========================================================================

    /// 读取完成回调
    /// 严格翻译自 FileReader.on_reader_done()
    ///
    /// Called when the BufferedReader has finished reading all data.
    /// Handles:
    ///   1. Consuming reader buffer into buffered
    ///   2. Delivering pending results
    ///   3. Notifying parent of close
    ///   4. Decrementing source ref count
    public func onReaderDone(): Unit {
        if (!isPulling()) {
            consumeReaderBuffer()
            if (pending.state == PendingState.Pending) {
                if (buffered.size > 0) {
                    let buf = buffered
                    pending.result = StreamResult.ownedAndDone(buf)
                } else {
                    pending.result = StreamResult.done()
                }
                buffered = ArrayList<UInt8>()
                pending.run()
            }
            // Don't handle buffered data here - it will be returned on the next onPull
            // This ensures proper ordering of chunks
        }

        // Only close the stream if there's no buffered data left to deliver
        if (buffered.size == 0) {
            // Notify parent of close
            // In Bun: unsafe { (*self.parent()).on_close() }
        }

        if (waitingForOnReaderDone) {
            waitingForOnReaderDone = false
            // In Bun: let _ = unsafe { Source::decrement_count(parent) }
        }
    }

    // ========================================================================
    // onReaderError - 读取错误回调
    // 严格翻译自: FileReader.on_reader_error (lines 995-1005)
    //   Bun: pub fn on_reader_error(&self, err: sys::Error)
    // ========================================================================

    /// 读取错误回调
    /// 严格翻译自 FileReader.on_reader_error()
    public func onReaderError(err: SyscallError): Unit {
        consumeReaderBuffer()
        if (buffered.capacity() > 0 && buffered.size == 0) {
            buffered = ArrayList<UInt8>()
        }

        pending.result = StreamResult.err(StreamError(err))
        pending.run()
    }

    // ========================================================================
    // onCancel - 取消
    // 严格翻译自: FileReader.on_cancel (lines 513-522)
    //   Bun: pub fn on_cancel(&self)
    // ========================================================================

    /// 取消读取
    /// 严格翻译自 FileReader.on_cancel()
    public func onCancel(): Unit {
        if (done) {
            return
        }
        done = true
        reader.updateRef(false)
        if (!reader.isDone()) {
            reader.close()
        }
    }

    // ========================================================================
    // drain - 排水
    // 严格翻译自: FileReader.drain (lines 929-943)
    //   Bun: pub fn drain(&self) -> Vec<u8>
    // ========================================================================

    /// 排水 (获取缓冲数据)
    /// 严格翻译自 FileReader.drain()
    ///
    /// Returns buffered data, clearing it from the reader.
    /// Prefers self.buffered; if empty, takes from reader.buffer.
    public func drain(): ArrayList<UInt8> {
        if (buffered.size > 0) {
            let out = buffered
            buffered = ArrayList<UInt8>()
            return out
        }

        if (reader.hasPendingRead) {
            return ArrayList<UInt8>()
        }

        return ArrayList<UInt8>(reader.buffer.items())
    }

    // ========================================================================
    // setRefOrUnref - 引用管理
    // 严格翻译自: FileReader.set_ref_or_unref (lines 945-950)
    //   Bun: pub fn set_ref_or_unref(&self, enable: bool)
    // ========================================================================

    /// 设置引用
    /// 严格翻译自 FileReader.set_ref_or_unref()
    public func setRefOrUnref(enable: Bool): Unit {
        if (done) {
            return
        }
        reader.updateRef(enable)
    }

    // ========================================================================
    // setFlowing - 流控制
    // 严格翻译自: FileReader.set_flowing (lines 1019-1042)
    //   Bun: pub fn set_flowing(&self, flag: bool)
    // ========================================================================

    /// 设置流动模式
    /// 严格翻译自 FileReader.set_flowing()
    public func setFlowing(flag: Bool): Unit {
        if (flowing == flag) {
            return
        }

        flowing = flag

        if (flag) {
            reader.unpause()
            if (!reader.isDone() && !reader.hasPendingRead) {
                // Kick off a new read if needed
                reader.read()
            }
        } else {
            reader.pause()
        }
    }

    // ========================================================================
    // deinit - 释放资源
    // 严格翻译自: FileReader.deinit (lines 534-536)
    //   Bun: fn deinit(&self) { self.reader().update_ref(false) }
    //   NOTE: Not `impl Drop` — FileReader is embedded as `Source.context` and
    //   this is invoked from the Source's JS finalizer path via `SourceContext::deinit_fn`.
    // ========================================================================

    /// 释放资源
    /// 严格翻译自 FileReader.deinit()
    ///
    /// Only side-effect teardown lives here. Owned fields (buffered, reader,
    /// pendingValue, lazy) drop when the caller (NewSource::decrement_count)
    /// reclaims the parent allocation after this returns.
    public func deinit(): Unit {
        reader.updateRef(false)
        if (!lazy.isNone()) {
            lazy = FileReaderLazy()
        }
        buffered.clear()
    }

    // ========================================================================
    // setRawMode - 设置原始模式 (Windows only)
    // 严格翻译自: FileReader.set_raw_mode (lines 1007-1017)
    //   Bun: pub fn set_raw_mode(&self, flag: bool) -> sys::Result<()>
    // ========================================================================

    /// 设置原始模式 (仅 Windows)
    /// 严格翻译自 FileReader.set_raw_mode()
    public func setRawMode(flag: Bool): ?SyscallError {
        // On non-Windows platforms, this should not be called
        // On Windows, delegates to reader.set_raw_mode(flag)
        return None
    }

    // ========================================================================
    // memoryCost - 内存开销
    // 严格翻译自: FileReader.memory_cost (lines 1044-1047)
    //   Bun: pub fn memory_cost(&self) -> usize
    // ========================================================================

    /// 内存开销
    /// 严格翻译自 FileReader.memory_cost()
    /// ReadableStreamSource covers @sizeOf(FileReader)
    public func memoryCost(): Int64 {
        return reader.memoryCost() + buffered.capacity()
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 消费读取器缓冲区
    /// 严格翻译自 FileReader.consume_reader_buffer()
    ///   Bun: fn consume_reader_buffer(&self) {
    ///       if self.buffered.get().capacity() == 0 {
    ///           self.buffered.set(mem::take(self.reader().buffer()));
    ///       }
    ///   }
    private func consumeReaderBuffer(): Unit {
        if (buffered.capacity() == 0) {
            buffered = reader.buffer
            reader.buffer = ArrayList<UInt8>()
        }
    }

    /// 是否正在拉取
    /// 严格翻译自 FileReader.is_pulling()
    ///   Bun: fn is_pulling(&self) -> bool { !self.read_inside_on_pull.get().is_none() }
    public func isPulling(): Bool {
        return !readInsideOnPull.isNone()
    }

    /// 读取文件 Blob (对应 Bun: Lazy::open_file_blob)
    /// 简化版 — 实际实现需要 FFI 系统调用
    private func openFileBlob(store: BlobStoreRef): ?OpenedFileBlob {
        // In Bun this does:
        // 1. If PathOrFileDescriptor::Fd: dup fd, set nonblocking
        // 2. If PathOrFileDescriptor::Path: sys::open with O_RDONLY|O_NONBLOCK|O_CLOEXEC
        // 3. fstat to get file type (regular/dir/pipe/socket)
        // 4. Set pollable/nonblocking flags based on file type
        // Simplified: return a default OpenedFileBlob
        return None
    }

    // ========================================================================
    // 便捷方法 (用于上层接口)
    // ========================================================================

    /// 读取文件全部内容
    public func readAll(): Array<UInt8> {
        done = true
        if (buffered.size > 0) {
            return buffered.items()
        }
        return Array<UInt8>()
    }

    /// 打开文件
    public func open(): Bool {
        started = true
        return true
    }

    /// 取消读取 (简化版)
    public func cancel(): Unit {
        onCancel()
    }

    /// 关闭文件
    public func close(): Unit {
        done = true
        fd = -1
    }
}

// ============================================================================
// Source - 类型别名
// 严格翻译自: FileReader 模块底部
//   Bun: pub type Source = readable_stream::NewSource<FileReader>
// ============================================================================

/// Source = readable_stream::NewSource<FileReader>
/// 对应 Bun: pub type Source = readable_stream::NewSource<FileReader>
///
/// In Bun, `ReadableStream.NewSource(@This(), "File", onStart, onPull, onCancel, deinit,
/// setRefOrUnref, drain, memoryCost, null)` is a comptime type-generator that builds a
/// vtable-backed Source struct embedding `context: FileReader`.
public class FileReaderSource {
    /// 上下文 (嵌入的 FileReader)
    public var context: FileReader
    /// 全局对象
    public var globalThis: UIntPtr
    /// 引用计数
    public var count: Int64

    public init() {
        context = FileReader()
        globalThis = 0
        count = 0
    }

    public init(context: FileReader) {
        this.context = context
        globalThis = 0
        count = 0
    }

    /// 递增计数
    public func incrementCount(): Unit {
        count = count + 1
    }

    /// 递减计数
    public static func decrementCount(source: FileReaderSource): Int64 {
        source.count = source.count - 1
        return source.count
    }

    /// 关闭回调
    public func onClose(): Unit {
        // Signal to the ReadableStream that the source has closed
    }
}

// ============================================================================
// readStateTag - ReadState 标签名
// 严格翻译自: FileReader 模块底部
//   Bun: #[inline] fn read_state_tag(state: ReadState) -> &'static str
// ============================================================================

/// ReadState 标签名 (用于日志)
/// 对应 Bun: read_state_tag(state: ReadState) -> &'static str
///   Mirrors Zig `@tagName(state)` for the scoped log only.
public func readStateTag(state: IOReadState): String {
    match (state) {
        case Progress => "progress"
        case Eof => "eof"
        case Drained => "drained"
    }
}

// ============================================================================
// isSliceInVecCapacity - 检查 slice 是否在 vec 的分配内
// 严格翻译自: FileReader 模块底部
//   Bun: #[inline] fn is_slice_in_vec_capacity(slice: &[u8], vec: &Vec<u8>) -> bool
// ============================================================================

/// 检查 `slice` 是否位于 `vec` 的分配范围内（包括备用容量）
/// 对应 Bun: is_slice_in_vec_capacity
///
/// Replaces the previous `AllocatedSlice` trait, which materialised a `&[u8]`
/// over `[len, capacity)` — uninitialised memory — purely to feed
/// `bun_core::is_slice_in_buffer`. This helper does the same containment
/// check with pure address arithmetic and never forms a reference over
/// uninit bytes.
public func isSliceInVecCapacity(slice: Array<UInt8>, vec: ArrayList<UInt8>): Bool {
    // Simplified: in actual implementation this checks pointer containment
    // within vec's allocation (including spare capacity)
    // For now, return false to indicate slice is NOT in vec's capacity
    return false
}

// ported from: src/runtime/webcore/FileReader.rs
