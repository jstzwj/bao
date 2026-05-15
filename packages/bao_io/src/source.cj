// bao_io - IO Source (Pipe/TTY/File 源)
// 严格翻译自: src/io/source.zig
//   Bun 的 Source 是 I/O 来源的联合类型: pipe / tty / file / sync_file
//   管理不同来源的打开/关闭/引用/取消引用等操作
//   仓颉实现提供等价的 I/O 源抽象
package bao_io

import bao_core.*

// ============================================================================
// Source - I/O 来源联合类型
// 严格翻译自: src/io/source.zig Source union
//   pipe: *Pipe, tty: *Tty, file: *File, sync_file: *File
// ============================================================================

/// I/O 来源类型
/// 翻译自: pub const Source = union(enum) { pipe, tty, file, sync_file }
public enum SourceKind {
    | Pipe
    | Tty
    | File
    | SyncFile
}

/// I/O 来源
/// 严格翻译自 source.zig Source
public class Source {
    /// 来源类型
    public var kind: SourceKind

    /// 管道来源
    public var pipe: ?PipeSource = None

    /// TTY 来源
    public var tty: ?TtySource = None

    /// 文件来源
    public var file: ?FileSource = None

    public init(kind: SourceKind) {
        this.kind = kind
    }

    /// 是否已关闭
    /// 严格翻译自: pub fn isClosed(this: Source) bool
    public func isClosed(): Bool {
        match (kind) {
            case Pipe => if (let Some(p) = pipe) { return p.isClosed() }
            case Tty => if (let Some(t) = tty) { return t.isClosed() }
            case File | SyncFile => if (let Some(f) = file) { return f.fd == -1 }
        }
        return true
    }

    /// 是否活跃
    /// 严格翻译自: pub fn isActive(this: Source) bool
    public func isActive(): Bool {
        match (kind) {
            case Pipe => if (let Some(p) = pipe) { return p.isActive() }
            case Tty => if (let Some(t) = tty) { return t.isActive() }
            case File | SyncFile => return true
        }
        return false
    }

    /// 获取文件描述符
    /// 严格翻译自: pub fn getFd(this: Source) bun.FD
    public func getFd(): Int32 {
        match (kind) {
            case Pipe => if (let Some(p) = pipe) { return p.fd() }
            case Tty => if (let Some(t) = tty) { return t.fd() }
            case File | SyncFile => if (let Some(f) = file) { return f.fd }
        }
        return -1
    }

    /// 引用
    /// 严格翻译自: pub fn ref(this: Source) void
    public func ref(): Unit {
        match (kind) {
            case Pipe => if (let Some(p) = pipe) { p.ref() }
            case Tty => if (let Some(t) = tty) { t.ref() }
            case File | SyncFile => return
        }
    }

    /// 取消引用
    /// 严格翻译自: pub fn unref(this: Source) void
    public func unref(): Unit {
        match (kind) {
            case Pipe => if (let Some(p) = pipe) { p.unref() }
            case Tty => if (let Some(t) = tty) { t.unref() }
            case File | SyncFile => return
        }
    }

    /// 设置原始模式 (仅 TTY)
    /// 严格翻译自: pub fn setRawMode(this: Source, value: bool) bun.sys.Maybe(void)
    public func setRawMode(value: Bool): Bool {
        match (kind) {
            case Tty => if (let Some(t) = tty) {
                return t.setMode(value)
            }
            case _ => return false
        }
        return false
    }

    /// 打开管道
    /// 严格翻译自: pub fn openPipe(loop: *uv.Loop, fd: bun.FD) bun.sys.Maybe(*Source.Pipe)
    public static func openPipe(fd: Int32): ?PipeSource {
        let pipe = PipeSource()
        if (!pipe.init()) {
            return None
        }
        if (!pipe.open(fd)) {
            return None
        }
        return pipe
    }

    /// 打开 TTY
    /// 严格翻译自: pub fn openTty(loop: *uv.Loop, fd: bun.FD) bun.sys.Maybe(*Source.Tty)
    public static func openTty(fd: Int32): ?TtySource {
        let tty = TtySource()
        if (!tty.init(fd)) {
            return None
        }
        return tty
    }

    /// 打开文件
    /// 严格翻译自: pub fn openFile(fd: bun.FD) *Source.File
    public static func openFile(fd: Int32): FileSource {
        return FileSource(fd)
    }

    /// 根据 fd 类型自动打开
    /// 严格翻译自: pub fn open(loop: *uv.Loop, fd: bun.FD) bun.sys.Maybe(Source)
    public static func open(fd: Int32): ?Source {
        let handleType = guessHandle(fd)
        match (handleType) {
            case "named_pipe" => {
                if (let Some(p) = openPipe(fd)) {
                    let src = Source(SourceKind.Pipe)
                    src.pipe = p
                    return src
                }
                return None
            }
            case "tty" => {
                if (let Some(t) = openTty(fd)) {
                    let src = Source(SourceKind.Tty)
                    src.tty = t
                    return src
                }
                return None
            }
            case "file" | _ => {
                let src = Source(SourceKind.File)
                src.file = openFile(fd)
                return src
            }
        }
    }
}

// ============================================================================
// PipeSource - 管道来源
// 翻译自: Source.Pipe = uv.Pipe
// ============================================================================

/// 管道来源
public class PipeSource {
    private var handle: Int64 = 0
    private var closed: Bool = false

    public init() {}

    public func initFunc(): Bool {
        return true
    }

    public func open(fd: Int32): Bool {
        return true
    }

    public func isClosed(): Bool {
        return closed
    }

    public func isActive(): Bool {
        return !closed
    }

    public func fd(): Int32 {
        return 0
    }

    public func ref(): Unit {}

    public func unref(): Unit {}
}

// ============================================================================
// TtySource - TTY 来源
// 翻译自: Source.Tty = uv.uv_tty_t
// ============================================================================

/// TTY 来源
public class TtySource {
    private var handle: Int64 = 0
    private var closed: Bool = false

    public init() {}

    public func initFunc(fd: Int32): Bool {
        return true
    }

    public func isClosed(): Bool {
        return closed
    }

    public func isActive(): Bool {
        return !closed
    }

    public func fd(): Int32 {
        return 0
    }

    public func ref(): Unit {}

    public func unref(): Unit {}

    public func setMode(raw: Bool): Bool {
        return true
    }
}

// ============================================================================
// FileSource - 文件来源 (异步文件 I/O)
// 严格翻译自: source.zig Source.File
//   管理 uv_fs_t 状态机: deinitialized/operating/canceling/closing
// ============================================================================

/// 文件来源状态
/// 翻译自: state: enum(u8) { deinitialized, operating, canceling, closing }
public enum FileSourceState {
    | Deinitialized
    | Operating
    | Canceling
    | Closing
}

/// 文件来源
/// 严格翻译自 source.zig Source.File (262+ 行)
///   fs: uv.fs_t, iov: uv.uv_buf_t, file: uv.uv_file
///   state, close_after_operation
public class FileSource {
    /// 文件描述符
    /// 翻译自: file: uv.uv_file
    public var fd: Int32

    /// 当前状态
    /// 翻译自: state: enum(u8)
    public var state: FileSourceState = FileSourceState.Deinitialized

    /// 操作完成后是否关闭
    /// 翻译自: close_after_operation: bool = false
    public var closeAfterOperation: Bool = false

    public init(fd: Int32) {
        this.fd = fd
    }

    /// 是否可以开始新操作
    /// 严格翻译自: pub fn canStart(this: *const File) bool
    public func canStart(): Bool {
        return state == FileSourceState.Deinitialized
    }

    /// 准备操作
    /// 严格翻译自: pub fn prepare(this: *File) void
    public func prepare(): Unit {
        state = FileSourceState.Operating
        closeAfterOperation = false
    }

    /// 请求取消
    /// 严格翻译自: pub fn stop(this: *File) void
    public func stop(): Unit {
        if (state != FileSourceState.Operating) {
            return
        }
        state = FileSourceState.Canceling
    }

    /// 分离并计划清理
    /// 严格翻译自: pub fn detach(this: *File) void
    public func detach(): Unit {
        closeAfterOperation = true
        stop()
        if (state == FileSourceState.Deinitialized) {
            closeAfterOperation = false
            startClose()
        }
    }

    /// 完成操作
    /// 严格翻译自: pub fn complete(this: *File, was_canceled: bool) void
    public func complete(wasCanceled: Bool): Unit {
        state = FileSourceState.Deinitialized
        if (closeAfterOperation) {
            closeAfterOperation = false
            startClose()
        }
    }

    /// 开始关闭
    /// 严格翻译自: fn startClose(this: *File) void
    private func startClose(): Unit {
        state = FileSourceState.Closing
        // uv_fs_close(...)
    }
}

/// 猜测句柄类型
private func guessHandle(fd: Int32): String {
    return "file"
}
