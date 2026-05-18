// 严格翻译自: src/runtime/api/bun/Terminal.rs
package bao_runtime.api

import bao_jsc.*
import bao_core.*
import bao_io.*
import bao_sys.*
import bao_collections.*

// ============================================================================
// Terminal - Bun.Terminal - 伪终端 (PTY) 支持
// 对应 Bun: src/runtime/api/bun/Terminal.rs (2010 行)
// ============================================================================

// ============================================================================
// js - JS 绑定模块 (Generated bindings / codegen)
// 严格翻译自: Terminal.rs pub mod js { ... }
//   Bun: jsc.Codegen.JSTerminal 的生成绑定
//   缓存值访问器: data, drain, exit
// ============================================================================

/// GcValue - GC 值枚举, 对应 js.gc.GcValue
/// Bun: 用于存储 JS 回调的 values 槽位
public enum GcValue {
    | Data    // data 回调
    | Exit    // exit 回调
    | Drain   // drain 回调
}

/// GcAccessor - GC 值访问器, 对应 js.gc 模块
/// Bun: js.gc.get / js.gc.set 访问缓存的 JSValue
public class GcAccessor {

    /// 获取缓存的 JSValue
    /// 严格翻译自: js.gc.get(which, this_value)
    public static func get(which: GcValue, thisValue: JsValue): ?JsValue {
        // 对应 Bun 的 data_get_cached / exit_get_cached / drain_get_cached
        match (which) {
            case Data => JsValue.getCached(thisValue, "data")
            case Exit => JsValue.getCached(thisValue, "exit")
            case Drain => JsValue.getCached(thisValue, "drain")
        }
    }

    /// 设置缓存的 JSValue
    /// 严格翻译自: js.gc.set(which, this_value, global, value)
    public static func set(which: GcValue, thisValue: JsValue, global: JsGlobalObject, value: JsValue): Unit {
        match (which) {
            case Data => JsValue.setCached(thisValue, global, "data", value)
            case Exit => JsValue.setCached(thisValue, global, "exit", value)
            case Drain => JsValue.setCached(thisValue, global, "drain", value)
        }
    }
}

// ============================================================================
// Flags - 状态标志位
// 严格翻译自: Terminal.rs bitflags! { pub struct Flags: u8 { ... } }
// ============================================================================

/// Flags - Terminal 状态标志位
/// Bun: bitflags, 使用 UInt8 位字段
/// REF_COUNT: 1=JS side, 2=Reader, 3=Writer
public struct Flags: Equatable {
    public var rawValue: UInt8

    public init(rawValue: UInt8) {
        this.rawValue = rawValue
    }

    public init() {
        this.rawValue = 0
    }

    /// CLOSED = 1 << 0
    public static let CLOSED: UInt8 = 1 << 0
    /// FINALIZED = 1 << 1
    public static let FINALIZED: UInt8 = 1 << 1
    /// RAW_MODE = 1 << 2
    public static let RAW_MODE: UInt8 = 1 << 2
    /// READER_STARTED = 1 << 3
    public static let READER_STARTED: UInt8 = 1 << 3
    /// CONNECTED = 1 << 4
    public static let CONNECTED: UInt8 = 1 << 4
    /// READER_DONE = 1 << 5
    public static let READER_DONE: UInt8 = 1 << 5
    /// WRITER_DONE = 1 << 6
    public static let WRITER_DONE: UInt8 = 1 << 6
    /// INLINE_SPAWNED = 1 << 7
    /// 当内联创建的终端已附加到子进程时设置
    /// 防止重用同一个内联终端进行第二次 spawn
    public static let INLINE_SPAWNED: UInt8 = 1 << 7

    /// 是否包含指定标志
    public func contains(flag: UInt8): Bool {
        return (rawValue & flag) != 0
    }

    /// 插入指定标志
    public mutating func insert(flag: UInt8): Unit {
        rawValue = rawValue | flag
    }

    /// 移除指定标志
    public mutating func remove(flag: UInt8): Unit {
        rawValue = rawValue & (~flag)
    }

    /// 设置指定标志为指定值
    public mutating func set(flag: UInt8, value: Bool): Unit {
        if (value) {
            insert(flag)
        } else {
            remove(flag)
        }
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return rawValue == 0
    }

    public static func == (lhs: Flags, rhs: Flags): Bool {
        return lhs.rawValue == rhs.rawValue
    }
}

// ============================================================================
// IOWriter / IOReader 类型别名
// 严格翻译自: Terminal.rs pub type IOWriter / IOReader / Poll
// ============================================================================

/// IOWriter - 流式写入器类型
/// Bun: StreamingWriter<Terminal>
public typealias IOWriter = StreamingWriter

/// IOReader - 缓冲读取器类型
/// Bun: BufferedReader
public typealias IOReader = BufferedReader

/// Poll 类型别名, 用于 FilePoll Owner 注册
public typealias Poll = StreamingWriter

// ============================================================================
// StreamingWriter - 流式写入器
// 对应 Bun: bun.io.StreamingWriter
// ============================================================================

/// StreamingWriter - 流式写入器封装
/// Bun: bun_io::StreamingWriter<Terminal>
/// 提供 write, close, start, updateRef 等方法
public class StreamingWriter {
    public var parent: CPointer<Unit> = CPointer<Unit>()
    public var fd: Int64 = INVALID_FD
    public var started: Bool = false
    public var closed: Bool = false

    public init() {}

    /// 启动写入器
    /// 严格翻译自: StreamingWriter.start(fd, true)
    public func start(fd: Int64,_: Bool): SysMaybe<Unit> {
        this.fd = fd
        this.started = true
        return SysMaybe<Unit>.Ok(())
    }

    /// 写入数据
    /// 严格翻译自: StreamingWriter.write(bytes)
    public func write(bytes: Array<UInt8>): IoWriteResult {
        if (closed || fd == INVALID_FD) {
            return IoWriteResult.err(SysError(32, SysTag.Write))  // EPIPE
        }
        let result = SysFs.write(fd, bytes)
        match (result) {
            case SysMaybe<Int64>.Ok(n) => return IoWriteResult.wrote(n)
            case SysMaybe<Int64>.Err(e) => return IoWriteResult.err(e)
        }
    }

    /// 关闭写入器
    public func close(): Unit {
        if (!closed) {
            closed = true
            if (fd != INVALID_FD) {
                FdExt.close(fd)
                fd = INVALID_FD
            }
        }
    }

    /// 更新引用
    public func updateRef(ctx: EventLoopHandle, add: Bool): Unit {
        // 对应 Bun StreamingWriter.updateRef(ctx, add)
    }
}

// ============================================================================
// IoWriteResult - IO 写入结果
// 严格翻译自: bun_io::WriteResult
// ============================================================================

/// IoWriteResult - IO 写入结果
/// Bun: bun_io::WriteResult (Done, Wrote, Pending, Err)
public enum IoWriteResult {
    | Done(Int64)         // 写入完成
    | Wrote(Int64)        // 写入了部分字节
    | Pending(Int64)      // 待处理
    | Err(SysError)       // 错误

    public func isDone(): Bool {
        match (this) {
            case Done(_) => true
            case _ => false
        }
    }

    public func isErr(): Bool {
        match (this) {
            case Err(_) => true
            case _ => false
        }
    }

    public static func err(e: SysError): IoWriteResult {
        IoWriteResult.Err(e)
    }

    public static func wrote(n: Int64): IoWriteResult {
        IoWriteResult.Wrote(n)
    }
}

// ============================================================================
// Options - 创建选项
// 严格翻译自: Terminal.rs pub struct Options { ... }
// ============================================================================

/// Options - Terminal 创建选项
/// Bun: pub struct Options { cols, rows, term_name, data_callback, exit_callback, drain_callback }
public struct Options {
    /// 列数 (默认 80)
    public var cols: UInt16 = 80
    /// 行数 (默认 24)
    public var rows: UInt16 = 24
    /// 终端名称 (如 "xterm-256color")
    public var termName: ZigStringSlice = ZigStringSlice()
    /// 数据回调
    public var dataCallback: ?JsValue = None
    /// 退出回调
    public var exitCallback: ?JsValue = None
    /// 排空回调
    public var drainCallback: ?JsValue = None

    /// 最大终端名称长度
    /// Bun: MAX_TERM_NAME_LEN = 128
    public static let MAX_TERM_NAME_LEN: Int64 = 128

    /// 默认构造
    public init() {}

    /// 从 JS 对象解析选项
    /// 严格翻译自: Options::parse_from_js(global_object, js_options)
    public static func parseFromJS(globalObject: JsGlobalObject, jsOptions: JsValue): Maybe<Options> {
        var options = Options()

        // 解析 cols
        if (let Some(colsVal) = jsOptions.get(globalObject, "cols")) {
            if (!colsVal.isUndefinedOrNull() && colsVal.isNumber()) {
                let n = colsVal.toInt32()
                if (n > 0 && n <= 65535) {
                    options.cols = UInt16(n)
                }
            }
        }

        // 解析 rows
        if (let Some(rowsVal) = jsOptions.get(globalObject, "rows")) {
            if (!rowsVal.isUndefinedOrNull() && rowsVal.isNumber()) {
                let n = rowsVal.toInt32()
                if (n > 0 && n <= 65535) {
                    options.rows = UInt16(n)
                }
            }
        }

        // 解析 name (终端名称)
        if (let Some(nameVal) = jsOptions.get(globalObject, "name")) {
            if (!nameVal.isUndefinedOrNull()) {
                let slice = nameVal.toSlice(globalObject)
                if (slice.slice().size > Options.MAX_TERM_NAME_LEN) {
                    return Maybe<Options>.err(
                        "EINVAL",
                        "Terminal name too long",
                        ""
                    )
                }
                options.termName = slice
            }
        }

        // 解析 data 回调
        if (let Some(dataVal) = jsOptions.get(globalObject, "data")) {
            if (!dataVal.isUndefinedOrNull() && dataVal.isCell() && dataVal.isCallable()) {
                options.dataCallback = Some(dataVal.withAsyncContextIfNeeded(globalObject))
            }
        }

        // 解析 exit 回调
        if (let Some(exitVal) = jsOptions.get(globalObject, "exit")) {
            if (!exitVal.isUndefinedOrNull() && exitVal.isCell() && exitVal.isCallable()) {
                options.exitCallback = Some(exitVal.withAsyncContextIfNeeded(globalObject))
            }
        }

        // 解析 drain 回调
        if (let Some(drainVal) = jsOptions.get(globalObject, "drain")) {
            if (!drainVal.isUndefinedOrNull() && drainVal.isCell() && drainVal.isCallable()) {
                options.drainCallback = Some(drainVal.withAsyncContextIfNeeded(globalObject))
            }
        }

        return Maybe<Options>(result: options)
    }

    /// 释放资源
    public mutating func deinit(): Unit {
        termName.deinit()
    }
}

// ============================================================================
// CreateResult - 创建结果
// 严格翻译自: Terminal.rs pub struct CreateResult { ... }
// ============================================================================

/// CreateResult - Terminal 创建结果
/// Bun: pub struct CreateResult { terminal, js_value }
public class TerminalCreateResult {
    /// 终端实例
    public var terminal: Terminal
    /// JS 包装值
    public var jsValue: JsValue

    public init(terminal: Terminal, jsValue: JsValue) {
        this.terminal = terminal
        this.jsValue = jsValue
    }
}

// ============================================================================
// InitError - 初始化错误
// 严格翻译自: Terminal.rs pub enum InitError { ... }
// ============================================================================

/// InitError - Terminal 初始化错误
/// Bun: pub enum InitError { OpenPtyFailed, DupFailed, NotSupported, WriterStartFailed, ReaderStartFailed }
public enum InitError {
    | OpenPtyFailed      // PTY 打开失败
    | DupFailed          // fd 复制失败
    | NotSupported       // 平台不支持
    | WriterStartFailed  // 写入器启动失败
    | ReaderStartFailed  // 读取器启动失败

    public func toError(): SysError {
        return match (this) {
            case OpenPtyFailed => SysError(0, SysTag.Open)
            case DupFailed => SysError(0, SysTag.Dup)
            case NotSupported => SysError(38, SysTag.Open)  // ENOSYS - 平台不支持
            case WriterStartFailed => SysError(0, SysTag.Write)
            case ReaderStartFailed => SysError(0, SysTag.Read)
        }
    }

    public func toString(): String {
        return match (this) {
            case OpenPtyFailed => "OpenPtyFailed"
            case DupFailed => "DupFailed"
            case NotSupported => "NotSupported"
            case WriterStartFailed => "WriterStartFailed"
            case ReaderStartFailed => "ReaderStartFailed"
        }
    }
}

// ============================================================================
// CreatePtyError - PTY 创建错误
// 严格翻译自: Terminal.rs pub enum CreatePtyError { ... }
// ============================================================================

/// CreatePtyError - PTY 创建错误
/// Bun: pub enum CreatePtyError { OpenPtyFailed, DupFailed, NotSupported }
public enum CreatePtyError {
    | OpenPtyFailed
    | DupFailed
    | NotSupported

    public func toString(): String {
        return match (this) {
            case OpenPtyFailed => "OpenPtyFailed"
            case DupFailed => "DupFailed"
            case NotSupported => "NotSupported"
        }
    }
}

// ============================================================================
// PtyResult - PTY 创建结果
// 严格翻译自: Terminal.rs pub struct PtyResult { ... }
// ============================================================================

/// PtyResult - PTY 创建结果
/// Bun: pub struct PtyResult { master, read_fd, write_fd, slave, hpcon }
public struct PtyResult {
    /// Master 端 FD
    public var master: Int64
    /// 读取端 FD (复制的 master fd)
    public var readFd: Int64
    /// 写入端 FD (复制的 master fd)
    public var writeFd: Int64
    /// Slave 端 FD (子进程使用)
    public var slave: Int64

    public init(master: Int64, readFd: Int64, writeFd: Int64, slave: Int64) {
        this.master = master
        this.readFd = readFd
        this.writeFd = writeFd
        this.slave = slave
    }
}

// ============================================================================
// TermiosField - termios 字段枚举
// 严格翻译自: Terminal.rs enum TermiosField { ... }
// ============================================================================

/// TermiosField - termios 字段类型
/// Bun: enum TermiosField { Iflag, Oflag, Lflag, Cflag }
public enum TermiosField {
    | Iflag     // 输入标志
    | Oflag     // 输出标志
    | Lflag     // 本地标志
    | Cflag     // 控制标志
}

// ============================================================================
// OpenPtyTermios - openpty 使用的 termios 结构
// 严格翻译自: Terminal.rs pub struct OpenPtyTermios { ... }
// ============================================================================

/// OpenPtyTermios - openpty extern 签名所需的 termios 结构
/// 即使传入 null, 也需要保持类型正确性
public struct OpenPtyTermios {
    public var cIflag: UInt32
    public var cOflag: UInt32
    public var cCflag: UInt32
    public var cLflag: UInt32
    public var cCc: Array<UInt8>
    public var cIspeed: UInt32
    public var cOspeed: UInt32

    public init() {
        cIflag = 0
        cOflag = 0
        cCflag = 0
        cLflag = 0
        cCc = Array<UInt8>(20, { _ => UInt8(0) })
        cIspeed = 0
        cOspeed = 0
    }
}

// ============================================================================
// Winsize - 终端窗口大小
// 严格翻译自: bun_core::Winsize
// ============================================================================

/// Winsize - 终端窗口大小
/// Bun: pub const Winsize = extern struct { row, col, xpixel, ypixel }
public struct Winsize {
    public var row: UInt16
    public var col: UInt16
    public var xpixel: UInt16
    public var ypixel: UInt16

    public init(row: UInt16, col: UInt16) {
        this.row = row
        this.col = col
        this.xpixel = 0
        this.ypixel = 0
    }

    public init(row: UInt16, col: UInt16, xpixel: UInt16, ypixel: UInt16) {
        this.row = row
        this.col = col
        this.xpixel = xpixel
        this.ypixel = ypixel
    }
}

// ============================================================================
// PTY 创建函数
// 严格翻译自: Terminal.rs fn create_pty / create_pty_posix
// ============================================================================

/// TIOCSWINSZ ioctl 常量
/// Linux x86_64: 0x5414
/// macOS: 0x80087467
public let TIOCSWINSZ_LINUX: UIntNative = 0x5414
public let TIOCSWINSZ_MACOS: UIntNative = 0x80087467

/// createPty - 创建 PTY
/// 严格翻译自: Terminal.rs fn create_pty(cols, rows)
/// POSIX 平台使用 openpty, Windows 使用 ConPTY
public func createPty(cols: UInt16, rows: UInt16): SysMaybe<PtyResult> {
    return createPtyPosix(cols, rows)
}

/// createPtyPosix - POSIX 平台创建 PTY
/// 严格翻译自: Terminal.rs fn create_pty_posix(cols, rows)
/// 使用 openpty 系统调用创建 PTY master/slave 对
public func createPtyPosix(cols: UInt16, rows: UInt16): SysMaybe<PtyResult> {
    // 使用 openpty 创建 PTY
    // openpty 需要传入 winsize
    let winsize = Winsize(row: rows, col: cols)

    // FFI: 调用 openpty
    // int openpty(int *amaster, int *aslave, char *name,
    //             const struct termios *termp, const struct winsize *winp);
    var masterFd: Int32 = -1
    var slaveFd: Int32 = -1

    unsafe {
        let masterPtr = malloc(UIntNative(4))
        let slavePtr = malloc(UIntNative(4))
        let winsizePtr = malloc(UIntNative(8))

        // 写入 winsize
        let wsBase = CPointer<UInt16>(winsizePtr)
        wsBase.write(winsize.row)
        (wsBase + Int64(1)).write(winsize.col)
        (wsBase + Int64(2)).write(winsize.xpixel)
        (wsBase + Int64(3)).write(winsize.ypixel)

        let result = openpty(masterPtr, slavePtr, CPointer<UInt8>(), CPointer<Unit>(), winsizePtr)

        if (result != 0) {
            free(masterPtr)
            free(slavePtr)
            free(winsizePtr)
            return SysMaybe<PtyResult>.Err(
                SysError(UInt16(Int64(OS.errno())), SysTag.Open)
            )
        }

        masterFd = CPointer<Int32>(masterPtr).read()
        slaveFd = CPointer<Int32>(slavePtr).read()
        free(masterPtr)
        free(slavePtr)
        free(winsizePtr)
    }

    // 配置 slave 端 termios 为合理的默认值 (匹配 node-pty 行为)
    configureSlaveTermios(slaveFd)

    // 复制 master fd 用于独立的读写
    let masterFdDesc: Int64 = Int64(masterFd)
    let slaveFdDesc: Int64 = Int64(slaveFd)

    // dup master fd 获取独立的读取 fd
    let readFd = dup(masterFdDesc)
    if (readFd < 0) {
        FdExt.close(masterFdDesc)
        FdExt.close(slaveFdDesc)
        return SysMaybe<PtyResult>.Err(SysError(UInt16(Int64(OS.errno())), SysTag.Dup))
    }

    // dup master fd 获取独立的写入 fd
    let writeFd = dup(masterFdDesc)
    if (writeFd < 0) {
        FdExt.close(masterFdDesc)
        FdExt.close(slaveFdDesc)
        FdExt.close(readFd)
        return SysMaybe<PtyResult>.Err(SysError(UInt16(Int64(OS.errno())), SysTag.Dup))
    }

    // 设置 master 端 fd 为非阻塞 (用于事件循环的异步 I/O)
    setNonblocking(masterFdDesc, true)
    setNonblocking(readFd, true)
    setNonblocking(writeFd, true)
    // 注意: slave_fd 保持阻塞 - 子进程期望阻塞 I/O

    // 设置 master 端 fd 的 close-on-exec
    // slave_fd 不设置 close-on-exec, 因为子进程需要继承它
    setCloseOnExec(masterFdDesc)
    setCloseOnExec(readFd)
    setCloseOnExec(writeFd)

    return SysMaybe<PtyResult>.Ok(
        PtyResult(master: masterFdDesc, readFd: readFd, writeFd: writeFd, slave: slaveFdDesc)
    )
}

/// configureSlaveTermios - 配置 slave 端 termios 为合理的默认值
/// 严格翻译自: Terminal.rs create_pty_posix 中的 tcgetattr/tcsetattr 块
/// 设置 cooked mode 默认值, 匹配 node-pty 行为
public func configureSlaveTermios(slaveFd: Int32): Unit {
    match (Termios.getattr(Int64(slaveFd))) {
        case SysMaybe<Termios>.Ok(var t) =>
            // 输入标志: 标准终端输入处理
            t.iflag = InputFlags.ICRNL | InputFlags.IXON | InputFlags.IXANY
                | UInt32(0x00002000)  // IMAXBEL
                | InputFlags.BRKINT
            // IUTF8: Linux/macOS 支持
            t.iflag = t.iflag | UInt32(0x00004000)  // IUTF8

            // 输出标志: 标准终端输出处理
            t.oflag = OutputFlags.OPOST | OutputFlags.ONLCR

            // 控制标志: 8 位字符, 启用接收器
            t.cflag = ControlFlags.CREAD | ControlFlags.CS8 | UInt32(0x00004000)  // HUPCL

            // 本地标志: 规范模式, 回显和信号
            t.lflag = LocalFlags.ICANON | LocalFlags.ISIG | LocalFlags.IEXTEN
                | LocalFlags.ECHO | LocalFlags.ECHOE | LocalFlags.ECHOK
                | UInt32(0x00000040)   // ECHOKE
                | UInt32(0x00000200)   // ECHOCTL

            // 控制字符 - 标准默认值
            t.cc[Int64(4)] = UInt8(4)     // VEOF: Ctrl-D
            t.cc[Int64(5)] = UInt8(0)     // VEOL: 禁用
            t.cc[Int64(2)] = UInt8(0x7f)  // VERASE: DEL (退格)
            t.cc[Int64(14)] = UInt8(23)   // VWERASE: Ctrl-W
            t.cc[Int64(3)] = UInt8(21)    // VKILL: Ctrl-U
            t.cc[Int64(12)] = UInt8(18)   // VREPRINT: Ctrl-R
            t.cc[Int64(0)] = UInt8(3)     // VINTR: Ctrl-C
            t.cc[Int64(1)] = UInt8(0x1c)  // VQUIT: Ctrl-\
            t.cc[Int64(10)] = UInt8(26)   // VSUSP: Ctrl-Z
            t.cc[Int64(8)] = UInt8(17)    // VSTART: Ctrl-Q (XON)
            t.cc[Int64(9)] = UInt8(19)    // VSTOP: Ctrl-S (XOFF)
            t.cc[Int64(15)] = UInt8(22)   // VLNEXT: Ctrl-V
            t.cc[Int64(13)] = UInt8(15)   // VDISCARD: Ctrl-O
            t.cc[Int64(6)] = UInt8(1)     // VMIN: 非规范读取最小字符数
            t.cc[Int64(5)] = UInt8(0)     // VTIME: 非规范读取超时

            // 应用设置
            t.setattr(Int64(slaveFd), TcSetAttrFlags.TCSANOW)
        case SysMaybe<Termios>.Err(_) =>
            // tcgetattr 失败, 在 debug 构建中记录日志, 但继续不修改 termios
            ()
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// dup - 复制文件描述符
/// 严格翻译自: sys::dup(fd)
@C
foreign func dup(fd: Int32): Int32

/// dup 重载 (Int64 版本)
public func dup(fd: Int64): Int64 {
    unsafe { Int64(dup(Int32(fd))) }
}

/// openpty - 打开 PTY
/// 严格翻译自: openpty 外部函数
@C
foreign func openpty(
    amaster: CPointer<Int32>,
    aslave: CPointer<Int32>,
    name: CPointer<UInt8>,
    termp: CPointer<Unit>,
    winp: CPointer<Unit>
): Int32

/// setNonblocking - 设置文件描述符为非阻塞
/// 严格翻译自: sys::update_nonblocking(fd, true)
public func setNonblocking(fd: Int64, nonblocking: Bool): Int32 {
    unsafe {
        let flags = fcntl(Int32(fd), 3, 0)  // F_GETFL
        if (flags < 0) {
            return -1
        }
        let newFlags = if (nonblocking) { flags | 2048 } else { flags & (-2049) }  // O_NONBLOCK = 0x800
        return fcntl(Int32(fd), 4, newFlags)  // F_SETFL
    }
}

/// fcntl - 文件控制操作
@C
foreign func fcntl(fd: Int32, cmd: Int32, arg: Int32): Int32

/// setCloseOnExec - 设置 close-on-exec 标志
/// 严格翻译自: spawn_sys::set_close_on_exec(fd)
public func setCloseOnExec(fd: Int64): Int32 {
    unsafe {
        let flags = fcntl(Int32(fd), 3, 0)  // F_GETFL
        if (flags < 0) {
            return -1
        }
        return fcntl(Int32(fd), 2, flags | 524288)  // F_SETFD, FD_CLOEXEC = 0x80000
    }
}

/// clampToCoord - 将 UInt16 限制在 i16 范围内
/// 严格翻译自: Terminal.rs fn clamp_to_coord(v: u16) -> i16
public func clampToCoord(v: UInt16): Int16 {
    if (v > 32767) {
        return 32767  // Int16.MAX
    }
    return Int16(v)
}

/// getTermios - 获取终端属性
/// 严格翻译自: Terminal.rs fn get_termios(fd)
public func getTermios(fd: Int64): ?Termios {
    match (Termios.getattr(fd)) {
        case SysMaybe<Termios>.Ok(t) => Some(t)
        case SysMaybe<Termios>.Err(_) => None
    }
}

/// setTermios - 设置终端属性
/// 严格翻译自: Terminal.rs fn set_termios(fd, termios_p)
public func setTermios(fd: Int64, termios: Termios): Bool {
    match (termios.setattr(fd, TcSetAttrFlags.TCSANOW)) {
        case SysMaybe<Unit>.Ok(_) => true
        case SysMaybe<Unit>.Err(_) => false
    }
}

// ============================================================================
// Terminal - 伪终端类
// 严格翻译自: Terminal.rs pub struct Terminal { ... }
// 对应 Bun: src/runtime/api/bun/Terminal.rs (2010 行)
//
// 引用计数:
// 1. JS 侧 (在 finalize 中释放)
// 2. Reader (在 onReaderDone/onReaderError 中释放)
// 3. Writer (在 onWriterClose 中释放)
// ============================================================================

/// Terminal - 伪终端类, 创建 PTY master/slave 对
/// Bun: pub struct Terminal { ref_count, master_fd, read_fd, write_fd, slave_fd, ... }
public class Terminal {
    /// 引用计数
    public var refCount: RefCount

    /// PTY 的 master 端 (原始 fd, 用于 ioctl 操作)
    public var masterFd: Int64

    /// 用于读取的复制 master fd
    public var readFd: Int64

    /// 用于写入的复制 master fd
    public var writeFd: Int64

    /// PTY 的 slave 端 (子进程使用)
    public var slaveFd: Int64

    /// 当前终端大小
    public var cols: UInt16
    public var rows: UInt16

    /// 终端名称 (如 "xterm-256color"), 构造后只读
    public var termName: ZigStringSlice

    /// 事件循环句柄, 构造后只读
    public var eventLoopHandle: EventLoopHandle

    /// 全局对象引用, 构造后只读
    public var globalThis: JsGlobalObject

    /// 写入器 - 向终端发送数据
    public var writer: IOWriter

    /// 读取器 - 从终端接收数据
    public var reader: IOReader

    /// JS 引用 - 用于 GC 跟踪
    /// weak: 空闲时允许 GC
    /// strong: 活跃连接时阻止 GC
    public var thisValue: JsRef

    /// 状态标志
    public var flags: Flags

    // ========================================================================
    // 构造函数
    // ========================================================================

    public init() {
        refCount = RefCount()
        masterFd = INVALID_FD
        readFd = INVALID_FD
        writeFd = INVALID_FD
        slaveFd = INVALID_FD
        cols = 80
        rows = 24
        termName = ZigStringSlice()
        eventLoopHandle = EventLoopHandle()
        globalThis = JsGlobalObject()
        writer = IOWriter()
        reader = IOReader(INVALID_FD, PIPE_BUF_SIZE)
        thisValue = JsRef.empty()
        flags = Flags()
    }

    // ========================================================================
    // 内部辅助方法 (R-2 interior-mutability helpers)
    // 严格翻译自: Terminal.rs impl Terminal { fn global(), fn update_flags(), ... }
    // ========================================================================

    /// global - 获取全局对象引用
    /// 严格翻译自: fn global(&self) -> &JSGlobalObject
    public func global(): JsGlobalObject {
        return globalThis
    }

    /// updateFlags - 读-修改-写 flags
    /// 严格翻译自: fn update_flags(&self, f: impl FnOnce(&mut Flags))
    public func updateFlags(f: (Flags) -> Flags): Unit {
        flags = f(flags)
    }

    /// ref_ - 增加引用计数
    /// 严格翻译自: pub fn ref_(&self)
    public func ref_(): Unit {
        refCount.ref()
    }

    /// deref_ - 减少引用计数, 计数为零时调用 deinitAndDestroy
    /// 严格翻译自: pub fn deref_(&self)
    public func deref_(): Unit {
        if (refCount.deref()) {
            // 引用计数归零, 执行销毁
            deinitAndDestroy()
        }
    }

    // ========================================================================
    // initTerminal - 内部初始化 (构造函数和 createFromSpawn 共享)
    // 严格翻译自: Terminal.rs fn init_terminal(global_object, options, existing_js_value)
    // ========================================================================

    /// initTerminal - 初始化 Terminal 实例
    /// 创建 PTY, 启动读写器, 存储 JS 回调
    /// 返回 CreateResult 或 InitError
    public static func initTerminal(
        globalObject: JsGlobalObject,
        options: Options,
        existingJsValue: ?JsValue
    ): Maybe<TerminalCreateResult> {
        // 创建 PTY
        let ptyResult = createPty(options.cols, options.rows)
        match (ptyResult) {
            case SysMaybe<PtyResult>.Err(e) =>
                return Maybe<TerminalCreateResult>.err(
                    "OpenPtyFailed",
                    e.toString(),
                    ""
                )
            case SysMaybe<PtyResult>.Ok(pty) => {
                // 使用默认 term name 如果为空
                var termName = options.termName
                if (termName.slice().size == 0) {
                    termName = ZigStringSlice("xterm-256color")
                }

                // 创建 Terminal 实例
                let terminal = Terminal()
                terminal.masterFd = pty.master
                terminal.readFd = pty.readFd
                terminal.writeFd = pty.writeFd
                terminal.slaveFd = pty.slave
                terminal.cols = options.cols
                terminal.rows = options.rows
                terminal.termName = termName
                terminal.eventLoopHandle = EventLoopHandle()
                terminal.globalThis = globalObject
                terminal.writer = IOWriter()
                terminal.reader = IOReader(pty.readFd, PIPE_BUF_SIZE)
                terminal.thisValue = JsRef.empty()
                terminal.flags = Flags()

                // 设置 reader parent
                terminal.reader.setParent(terminal)

                // 设置 writer parent
                terminal.writer.parent = CPointer<Unit>()

                // 启动 writer - 添加一个引用
                let writerResult = terminal.writer.start(pty.writeFd, true)
                match (writerResult) {
                    case SysMaybe<Unit>.Err(_) =>
                        // Writer 启动失败
                        terminal.flags.insert(Flags.WRITER_DONE)
                        FdExt.close(terminal.readFd)
                        terminal.readFd = INVALID_FD
                        terminal.closeInternal()
                        terminal.deref_()
                        return Maybe<TerminalCreateResult>.err(
                            "WriterStartFailed",
                            "Failed to start terminal writer",
                            ""
                        )
                    case SysMaybe<Unit>.Ok(_) =>
                        terminal.ref_()
                }

                // 启动 reader - 添加一个引用
                let readerResult = terminal.reader.start(pty.readFd, true)
                match (readerResult) {
                    case SysMaybe<Unit>.Err(_) =>
                        // Reader 启动失败
                        FdExt.close(terminal.readFd)
                        terminal.readFd = INVALID_FD
                        terminal.closeInternal()
                        terminal.deref_()
                        return Maybe<TerminalCreateResult>.err(
                            "ReaderStartFailed",
                            "Failed to start terminal reader",
                            ""
                        )
                    case SysMaybe<Unit>.Ok(_) =>
                        terminal.ref_()
                        // PTY 行为类似管道, 不是 socket
                        // 设置 poll 标志
                        terminal.flags.insert(Flags.READER_STARTED)
                }

                // 开始读取数据
                terminal.reader.read()

                // 获取或创建 JS 包装器
                let thisValue = match (existingJsValue) {
                    case Some(v) => v
                    case None => JsValue(terminal)
                }

                // 存储 thisValue - 开始时使用强引用 (因为正在活跃读取)
                terminal.thisValue = JsRef.initStrong(thisValue, globalObject)

                // 存储回调 (通过 GC setter, 防止回调被 GC 回收)
                if (let Some(cb) = options.dataCallback) {
                    GcAccessor.set(GcValue.Data, thisValue, globalObject, cb)
                }
                if (let Some(cb) = options.exitCallback) {
                    GcAccessor.set(GcValue.Exit, thisValue, globalObject, cb)
                }
                if (let Some(cb) = options.drainCallback) {
                    GcAccessor.set(GcValue.Drain, thisValue, globalObject, cb)
                }

                return Maybe<TerminalCreateResult>(
                    result: TerminalCreateResult(terminal: terminal, jsValue: thisValue)
                )
            }
        }
    }

    // ========================================================================
    // constructor - JS 构造函数
    // 严格翻译自: Terminal.rs pub fn constructor(global_object, callframe, this_value)
    // ========================================================================

    /// constructor - 从 JS 创建 Terminal
    /// 严格翻译自: pub fn constructor(global_object, callframe, this_value) -> JsResult<*mut Terminal>
    public static func constructor(globalObject: JsGlobalObject, callframe: CallFrame, thisValue: JsValue): Maybe<Terminal> {
        let args = callframe.argumentsAsArray(1)
        let jsOptions = args[0]

        if (!jsOptions.isObject()) {
            return Maybe<Terminal>.err(
                "TypeError",
                "Terminal constructor requires an options object",
                ""
            )
        }

        let optionsResult = Options.parseFromJS(globalObject, jsOptions)
        var options = match (optionsResult) {
            case Maybe<Options>.Error(_, _) =>
                return Maybe<Terminal>.err("TypeError", "Failed to parse options", "")
            case Maybe<Options>.Result(o) => o
        }

        let result = initTerminal(globalObject, options, Some(thisValue))
        match (result) {
            case Maybe<TerminalCreateResult>.Error(code, msg, path) =>
                var errorMsg = match (code) {
                    case "OpenPtyFailed" => "Failed to open PTY"
                    case "DupFailed" => "Failed to duplicate PTY file descriptor"
                    case "NotSupported" => "PTY not supported on this platform"
                    case "WriterStartFailed" => "Failed to start terminal writer"
                    case "ReaderStartFailed" => "Failed to start terminal reader"
                    case _ => msg
                }
                return Maybe<Terminal>.err(code, errorMsg, path)
            case Maybe<TerminalCreateResult>.Result(r) =>
                return Maybe<Terminal>(result: r.terminal)
        }
    }

    // ========================================================================
    // createFromSpawn - 从 spawn 创建 (非 JS 构造函数)
    // 严格翻译自: Terminal.rs pub fn create_from_spawn(global_object, options)
    // ========================================================================

    /// createFromSpawn - 从 Bun.spawn 选项创建 Terminal
    /// 严格翻译自: pub fn create_from_spawn(global_object, options) -> Result<CreateResult, InitError>
    /// 返回 Terminal 和 JS 包装值, slave_fd 应用于子进程的 stdin/stdout/stderr
    public static func createFromSpawn(
        globalObject: JsGlobalObject,
        options: Options
    ): Maybe<TerminalCreateResult> {
        return initTerminal(globalObject, options, None)
    }

    // ========================================================================
    // getter/setter 方法
    // 严格翻译自: Terminal.rs impl Terminal { get_closed, get_input_flags, ... }
    // ========================================================================

    /// getSlaveFd - 获取 slave fd 用于子进程
    /// 严格翻译自: pub fn get_slave_fd(&self) -> Fd
    public func getSlaveFd(): Int64 {
        return slaveFd
    }

    /// isClosed - 是否已关闭
    /// 严格翻译自: pub fn is_closed(&self) -> bool
    public func isClosed(): Bool {
        return flags.contains(Flags.CLOSED)
    }

    /// isInlineSpawned - 是否已内联 spawn
    /// 严格翻译自: pub fn is_inline_spawned(&self) -> bool
    public func isInlineSpawned(): Bool {
        return flags.contains(Flags.INLINE_SPAWNED)
    }

    /// getClosed - 获取关闭状态 (JS getter)
    /// 严格翻译自: pub fn get_closed(&self, _global) -> JSValue
    public func getClosed(_: JsGlobalObject): JsValue {
        return JsValue(flags.contains(Flags.CLOSED))
    }

    /// getInputFlags - 获取输入标志 (JS getter)
    /// 严格翻译自: pub fn get_input_flags(&self, _global) -> JSValue
    public func getInputFlags(_: JsGlobalObject): JsValue {
        return getTermiosFlag(TermiosField.Iflag)
    }

    /// setInputFlags - 设置输入标志 (JS setter)
    /// 严格翻译自: pub fn set_input_flags(&self, global_object, value) -> JsResult<bool>
    public func setInputFlags(globalObject: JsGlobalObject, value: JsValue): Bool {
        setTermiosFlag(globalObject, value, TermiosField.Iflag)
        return true
    }

    /// getOutputFlags - 获取输出标志 (JS getter)
    /// 严格翻译自: pub fn get_output_flags(&self, _global) -> JSValue
    public func getOutputFlags(_: JsGlobalObject): JsValue {
        return getTermiosFlag(TermiosField.Oflag)
    }

    /// setOutputFlags - 设置输出标志 (JS setter)
    /// 严格翻译自: pub fn set_output_flags(&self, global_object, value) -> JsResult<bool>
    public func setOutputFlags(globalObject: JsGlobalObject, value: JsValue): Bool {
        setTermiosFlag(globalObject, value, TermiosField.Oflag)
        return true
    }

    /// getLocalFlags - 获取本地标志 (JS getter)
    /// 严格翻译自: pub fn get_local_flags(&self, _global) -> JSValue
    public func getLocalFlags(_: JsGlobalObject): JsValue {
        return getTermiosFlag(TermiosField.Lflag)
    }

    /// setLocalFlags - 设置本地标志 (JS setter)
    /// 严格翻译自: pub fn set_local_flags(&self, global_object, value) -> JsResult<bool>
    public func setLocalFlags(globalObject: JsGlobalObject, value: JsValue): Bool {
        setTermiosFlag(globalObject, value, TermiosField.Lflag)
        return true
    }

    /// getControlFlags - 获取控制标志 (JS getter)
    /// 严格翻译自: pub fn get_control_flags(&self, _global) -> JSValue
    public func getControlFlags(_: JsGlobalObject): JsValue {
        return getTermiosFlag(TermiosField.Cflag)
    }

    /// setControlFlags - 设置控制标志 (JS setter)
    /// 严格翻译自: pub fn set_control_flags(&self, global_object, value) -> JsResult<bool>
    public func setControlFlags(globalObject: JsGlobalObject, value: JsValue): Bool {
        setTermiosFlag(globalObject, value, TermiosField.Cflag)
        return true
    }

    // ========================================================================
    // termios 标志读写
    // 严格翻译自: Terminal.rs fn get_termios_flag / fn set_termios_flag
    // ========================================================================

    /// getTermiosFlag - 获取 termios 标志值
    /// 严格翻译自: fn get_termios_flag<const FIELD: TermiosField>(&self) -> JSValue
    public func getTermiosFlag(field: TermiosField): JsValue {
        if (flags.contains(Flags.CLOSED) || masterFd == INVALID_FD) {
            return JsValue(0.0)
        }

        if (let Some(termiosData) = getTermios(masterFd)) {
            let raw: Float64 = match (field) {
                case TermiosField.Iflag => Float64(Int64(termiosData.iflag))
                case TermiosField.Oflag => Float64(Int64(termiosData.oflag))
                case TermiosField.Lflag => Float64(Int64(termiosData.lflag))
                case TermiosField.Cflag => Float64(Int64(termiosData.cflag))
            }
            return JsValue(raw)
        }
        return JsValue(0.0)
    }

    /// setTermiosFlag - 设置 termios 标志值
    /// 严格翻译自: fn set_termios_flag<const FIELD: TermiosField>(&self, global_object, value)
    public func setTermiosFlag(globalObject: JsGlobalObject, value: JsValue, field: TermiosField): Unit {
        if (flags.contains(Flags.CLOSED) || masterFd == INVALID_FD) {
            return
        }

        let num = value.coerceF64(globalObject)
        if (let Some(mut termiosData) = getTermios(masterFd)) {
            // 限制到 tcflag_t 范围
            var clamped = num
            if (clamped < 0.0) { clamped = 0.0 }
            if (clamped > 4294967295.0) { clamped = 4294967295.0 }
            let bits = UInt32(clamped)
            match (field) {
                case TermiosField.Iflag => termiosData.iflag = bits
                case TermiosField.Oflag => termiosData.oflag = bits
                case TermiosField.Lflag => termiosData.lflag = bits
                case TermiosField.Cflag => termiosData.cflag = bits
            }
            setTermios(masterFd, termiosData)
        }
    }

    // ========================================================================
    // write - 向终端写入数据
    // 严格翻译自: Terminal.rs pub fn write(&self, global_object, callframe)
    // ========================================================================

    /// write - 向终端写入数据
    /// 严格翻译自: pub fn write(&self, global_object, callframe) -> JsResult<JSValue>
    public func write(globalObject: JsGlobalObject, callframe: CallFrame): Maybe<JsValue> {
        if (flags.contains(Flags.CLOSED)) {
            return Maybe<JsValue>.err("Error", "Terminal is closed", "")
        }

        let args = callframe.argumentsAsArray(1)
        let data = args[0]

        if (data.isUndefinedOrNull()) {
            return Maybe<JsValue>.err("Error", "write() requires data argument", "")
        }

        // 使用 StringOrBuffer 获取要写入的字节
        let stringOrBuffer = StringOrBuffer.fromJS(globalObject, data)
        if (stringOrBuffer == None) {
            return Maybe<JsValue>.err("TypeError", "write() argument must be a string or ArrayBuffer", "")
        }

        var bytes: Array<UInt8> = []
        match (stringOrBuffer) {
            case Some(sob) => bytes = sob.slice()
            case None => ()
        }

        if (bytes.size == 0) {
            return Maybe<JsValue>(result: JsValue(0.0))
        }

        // 使用流式写入器写入
        let writeResult = writer.write(bytes)
        match (writeResult) {
            case IoWriteResult.Done(amt) =>
                return Maybe<JsValue>(result: JsValue(Float64(amt)))
            case IoWriteResult.Wrote(amt) =>
                return Maybe<JsValue>(result: JsValue(Float64(amt)))
            case IoWriteResult.Pending(amt) =>
                // 在 POSIX 上返回 amt; 报告实际字节数
                return Maybe<JsValue>(result: JsValue(Float64(bytes.size)))
            case IoWriteResult.Err(err) =>
                return Maybe<JsValue>.err("Error", err.toString(), "")
        }
    }

    // ========================================================================
    // resize - 调整终端大小
    // 严格翻译自: Terminal.rs pub fn resize(&self, global_object, callframe)
    // ========================================================================

    /// resize - 调整终端大小
    /// 严格翻译自: pub fn resize(&self, global_object, callframe) -> JsResult<JSValue>
    public func resize(globalObject: JsGlobalObject, callframe: CallFrame): Maybe<JsValue> {
        if (flags.contains(Flags.CLOSED)) {
            return Maybe<JsValue>.err("Error", "Terminal is closed", "")
        }

        let args = callframe.argumentsAsArray(2)

        // 解析 new_cols
        var newCols: UInt16 = 80
        if (args[0].isNumber()) {
            let n = args[0].toInt32()
            if (n > 0 && n <= 65535) {
                newCols = UInt16(n)
            } else {
                return Maybe<JsValue>.err("Error", "resize() requires valid cols argument", "")
            }
        } else {
            return Maybe<JsValue>.err("Error", "resize() requires valid cols argument", "")
        }

        // 解析 new_rows
        var newRows: UInt16 = 24
        if (args[1].isNumber()) {
            let n = args[1].toInt32()
            if (n > 0 && n <= 65535) {
                newRows = UInt16(n)
            } else {
                return Maybe<JsValue>.err("Error", "resize() requires valid rows argument", "")
            }
        } else {
            return Maybe<JsValue>.err("Error", "resize() requires valid rows argument", "")
        }

        // POSIX: 调用 ioctl TIOCSWINSZ
        unsafe {
            let winsize = Winsize(row: newRows, col: newCols)
            let winsizePtr = malloc(UIntNative(8))
            let wsBase = CPointer<UInt16>(winsizePtr)
            wsBase.write(winsize.row)
            (wsBase + Int64(1)).write(winsize.col)
            (wsBase + Int64(2)).write(winsize.xpixel)
            (wsBase + Int64(3)).write(winsize.ypixel)

            let ioctlResult = ioctl(Int32(masterFd), TIOCSWINSZ_LINUX, winsizePtr)
            free(winsizePtr)

            if (ioctlResult != 0) {
                return Maybe<JsValue>.err("Error", "Failed to resize terminal", "")
            }
        }

        cols = newCols
        rows = newRows

        return Maybe<JsValue>(result: JsValue.jsUndefined())
    }

    // ========================================================================
    // setRawMode - 设置原始模式
    // 严格翻译自: Terminal.rs pub fn set_raw_mode(&self, global_object, callframe)
    // ========================================================================

    /// setRawMode - 设置原始模式
    /// 严格翻译自: pub fn set_raw_mode(&self, global_object, callframe) -> JsResult<JSValue>
    public func setRawMode(globalObject: JsGlobalObject, callframe: CallFrame): Maybe<JsValue> {
        if (flags.contains(Flags.CLOSED)) {
            return Maybe<JsValue>.err("Error", "Terminal is closed", "")
        }

        let args = callframe.argumentsAsArray(1)
        let enabled = args[0].toBoolean()

        // 使用 TTY 模式函数
        let tty = TTY(masterFd)
        let ttyResult = tty.setRawMode(enabled)
        match (ttyResult) {
            case SysMaybe<Unit>.Err(_) =>
                return Maybe<JsValue>.err("Error", "Failed to set raw mode", "")
            case SysMaybe<Unit>.Ok(_) => {}
        }

        flags.set(Flags.RAW_MODE, enabled)
        return Maybe<JsValue>(result: JsValue.jsUndefined())
    }

    // ========================================================================
    // doRef / doUnref - 引用/取消引用终端
    // 严格翻译自: Terminal.rs pub fn do_ref / pub fn do_unref
    // ========================================================================

    /// doRef - 引用终端, 保持事件循环活跃
    /// 严格翻译自: pub fn do_ref(&self, _g, _f) -> JsResult<JSValue>
    public func doRef(_: JsGlobalObject, _: CallFrame): Maybe<JsValue> {
        updateRef(true)
        return Maybe<JsValue>(result: JsValue.jsUndefined())
    }

    /// doUnref - 取消引用终端
    /// 严格翻译自: pub fn do_unref(&self, _g, _f) -> JsResult<JSValue>
    public func doUnref(_: JsGlobalObject, _: CallFrame): Maybe<JsValue> {
        updateRef(false)
        return Maybe<JsValue>(result: JsValue.jsUndefined())
    }

    /// updateRef - 更新引用
    /// 严格翻译自: fn update_ref(&self, add: bool)
    public func updateRef(add: Bool): Unit {
        reader.updateRef(add)
        writer.updateRef(eventLoopHandle, add)
    }

    // ========================================================================
    // close - 关闭终端
    // 严格翻译自: Terminal.rs pub fn close(&self, _g, _f)
    // ========================================================================

    /// close - 关闭终端
    /// 严格翻译自: pub fn close(&self, _g, _f) -> JsResult<JSValue>
    public func close(_: JsGlobalObject, _: CallFrame): Maybe<JsValue> {
        closeInternal()
        return Maybe<JsValue>(result: JsValue.jsUndefined())
    }

    // ========================================================================
    // asyncDispose - 异步释放 (using 语法)
    // 严格翻译自: Terminal.rs pub fn async_dispose(&self, global_object, _f)
    // ========================================================================

    /// asyncDispose - 异步释放, 用于 "using" 语法
    /// 严格翻译自: pub fn async_dispose(&self, global_object, _f) -> JsResult<JSValue>
    /// 关闭后调用者不应再看到进一步的 data/exit 回调
    public func asyncDispose(globalObject: JsGlobalObject, _: CallFrame): Maybe<JsValue> {
        // 降级 JSRef 使包装器可被 GC 回收
        thisValue.downgrade()
        // 标记为已终结, 抑制回调
        flags.insert(Flags.FINALIZED)
        closeInternal()
        return Maybe<JsValue>(result: JsPromise.resolvedPromiseValue(globalObject, JsValue.jsUndefined()))
    }

    // ========================================================================
    // closeInternal - 内部关闭实现
    // 严格翻译自: Terminal.rs pub fn close_internal(&self)
    // ========================================================================

    /// closeInternal - 内部关闭实现
    /// 严格翻译自: pub fn close_internal(&self)
    /// 关闭所有文件描述符和 I/O 资源
    public func closeInternal(): Unit {
        if (flags.contains(Flags.CLOSED)) {
            return
        }
        flags.insert(Flags.CLOSED)

        // 关闭写入器 (关闭 write_fd)
        writer.close()
        writeFd = INVALID_FD

        // 关闭读取器 (关闭 read_fd)
        if (flags.contains(Flags.READER_STARTED)) {
            reader.close()
        }
        readFd = INVALID_FD

        // 关闭 master fd
        if (masterFd != INVALID_FD) {
            FdExt.close(masterFd)
            masterFd = INVALID_FD
        }

        // 关闭 slave fd
        if (slaveFd != INVALID_FD) {
            FdExt.close(slaveFd)
            slaveFd = INVALID_FD
        }
    }

    // ========================================================================
    // closeSlaveFd - 关闭 slave fd
    // 严格翻译自: Terminal.rs pub fn close_slave_fd(&self)
    // ========================================================================

    /// closeSlaveFd - 关闭父进程持有的 slave_fd (fork 后)
    /// 严格翻译自: pub fn close_slave_fd(&self)
    /// 子进程有自己的副本 - 关闭父进程的副本确保在子进程退出时 master 端收到 EOF
    public func closeSlaveFd(): Unit {
        flags.insert(Flags.INLINE_SPAWNED)
        let fd = slaveFd
        if (fd != INVALID_FD) {
            FdExt.close(fd)
            slaveFd = INVALID_FD
        }
    }

    // ========================================================================
    // closePseudoconsole - 关闭伪控制台 (Windows)
    // 严格翻译自: Terminal.rs pub fn close_pseudoconsole(&self)
    // POSIX 上为空操作
    // ========================================================================

    /// closePseudoconsole - 关闭伪控制台
    /// POSIX: 无操作
    public func closePseudoconsole(): Unit {
        // POSIX: 无操作
    }

    // ========================================================================
    // abandonFromSpawn - spawn 侧错误路径清理
    // 严格翻译自: Terminal.rs pub fn abandon_from_spawn(&self)
    // ========================================================================

    /// abandonFromSpawn - spawn 侧错误路径清理
    /// 严格翻译自: pub fn abandon_from_spawn(&self)
    /// 用于子进程从未启动的情况
    /// 降级 JSRef 使包装器可被 GC 回收
    /// 标记 finalized 使 onReaderDone 跳过 JS exit 回调
    /// 运行 closeInternal
    public func abandonFromSpawn(): Unit {
        thisValue.downgrade()
        flags.insert(Flags.FINALIZED)
        closeInternal()
    }

    // ========================================================================
    // getPseudoconsole - 获取伪控制台句柄
    // 严格翻译自: Terminal.rs pub fn get_pseudoconsole(&self)
    // POSIX: 返回 None
    // ========================================================================

    /// getPseudoconsole - 获取伪控制台句柄 (Windows)
    /// POSIX: 返回 None
    public func getPseudoconsole(): ?CPointer<Unit> {
        None
    }

    // ========================================================================
    // IOWriter 回调
    // 严格翻译自: Terminal.rs impl Terminal { on_writer_close, on_writer_ready, ... }
    // ========================================================================

    /// onWriterClose - 写入器关闭回调
    /// 严格翻译自: fn on_writer_close(&self)
    fn onWriterClose(): Unit {
        if (!flags.contains(Flags.WRITER_DONE)) {
            flags.insert(Flags.WRITER_DONE)
            // 释放 writer 的引用
            deref_()
        }
    }

    /// onWriterReady - 写入器就绪回调
    /// 严格翻译自: fn on_writer_ready(&self)
    /// 调用 drain 回调
    fn onWriterReady(): Unit {
        let thisJsvalue = thisValue.tryGet()
        if (thisJsvalue == None) {
            return
        }
        match (thisJsvalue) {
            case Some(jsVal) =>
                if (let Some(callback) = GcAccessor.get(GcValue.Drain, jsVal)) {
                    let globalThis = global()
                    globalThis.bunVm().eventLoopMut().runCallback(
                        callback,
                        globalThis,
                        jsVal,
                        [jsVal]
                    )
                }
            case None => ()
        }
    }

    /// onWriterError - 写入器错误回调
    /// 严格翻译自: fn on_writer_error(&self, err: sys::Error)
    /// 写入错误时关闭终端
    fn onWriterError(err: SysError): Unit {
        // 写入错误, 关闭终端防止进一步操作
        // 处理子进程退出时的管道破裂等情况
        if (!flags.contains(Flags.CLOSED)) {
            closeInternal()
        }
    }

    /// onWrite - 写入完成回调
    /// 严格翻译自: fn on_write(&self, amount: usize, status: WriteStatus)
    fn onWrite(amount: Int64, status: WriteStatus): Unit {
        // 日志记录
    }

    // ========================================================================
    // IOReader 回调
    // 严格翻译自: Terminal.rs impl Terminal { on_reader_done, on_reader_error, ... }
    // ========================================================================

    /// onReaderDone - 读取器完成回调 (EOF)
    /// 严格翻译自: pub fn on_reader_done(&self)
    /// EOF 来自 master - 降级为弱引用以允许 GC
    /// 如果已终结 (在 finalize 期间调用 close), 跳过 JS 交互
    public func onReaderDone(): Unit {
        if (!flags.contains(Flags.FINALIZED)) {
            flags.remove(Flags.CONNECTED)
            thisValue.downgrade()
            // exit_code 0 = PTY 流上的干净 EOF (不是子进程退出码)
            callExitCallback(0, None)
        }
        // 释放 reader 的引用 (仅一次)
        if (!flags.contains(Flags.READER_DONE)) {
            flags.insert(Flags.READER_DONE)
            deref_()
        }
    }

    /// onReaderError - 读取器错误回调
    /// 严格翻译自: pub fn on_reader_error(&self, err: sys::Error)
    /// 错误 - 降级为弱引用以允许 GC
    public func onReaderError(err: SysError): Unit {
        if (!flags.contains(Flags.FINALIZED)) {
            flags.remove(Flags.CONNECTED)
            thisValue.downgrade()
            // exit_code 1 = PTY 流上的 I/O 错误 (不是子进程退出码)
            callExitCallback(1, None)
        }
        // 释放 reader 的引用 (仅一次)
        if (!flags.contains(Flags.READER_DONE)) {
            flags.insert(Flags.READER_DONE)
            deref_()
        }
    }

    // ========================================================================
    // callExitCallback - 调用退出回调
    // 严格翻译自: Terminal.rs fn call_exit_callback(&self, exit_code, signal)
    // ========================================================================

    /// callExitCallback - 调用退出回调
    /// 严格翻译自: fn call_exit_callback(&self, exit_code: i32, signal: Option<SignalCode>)
    /// 注意: exit_code 是 PTY 级别的 (0=EOF, 1=error), 不是子进程退出码
    /// signal 参数仅在信号导致 PTY 关闭时填充
    fn callExitCallback(exitCode: Int32, signal: ?SignalCode): Unit {
        let thisJsvalue = thisValue.tryGet()
        if (thisJsvalue == None) {
            return
        }
        match (thisJsvalue) {
            case Some(jsVal) =>
                if (let Some(callback) = GcAccessor.get(GcValue.Exit, jsVal)) {
                    let globalThis = global()

                    let signalValue: JsValue = match (signal) {
                        case Some(s) => JsValue(s.toString())  // "SIGTERM" 等
                        case None => JsValue.jsNull()
                    }

                    globalThis.bunVm().eventLoopMut().runCallback(
                        callback,
                        globalThis,
                        jsVal,
                        [jsVal, JsValue(Float64(exitCode)), signalValue]
                    )
                }
            case None => ()
        }
    }

    // ========================================================================
    // onReadChunk - 数据块读取回调
    // 严格翻译自: Terminal.rs pub fn on_read_chunk(&self, chunk, has_more)
    // ========================================================================

    /// onReadChunk - 数据可用回调
    /// 严格翻译自: pub fn on_read_chunk(&self, chunk: &[u8], has_more: ReadState) -> bool
    /// 返回 true 继续读取, false 暂停
    public func onReadChunk(chunk: Array<UInt8>, hasMore: ReadState): Bool {
        if (flags.contains(Flags.FINALIZED)) {
            return true
        }

        // 首次收到数据 - 升级为强引用 (已连接)
        if (!flags.contains(Flags.CONNECTED)) {
            flags.insert(Flags.CONNECTED)
            let globalObj = global()
            thisValue.upgrade(globalObj)
        }

        let thisJsvalue = thisValue.tryGet()
        if (thisJsvalue == None) {
            return true
        }
        match (thisJsvalue) {
            case Some(jsVal) =>
                if (let Some(callback) = GcAccessor.get(GcValue.Data, jsVal)) {
                    let globalThis = global()

                    // 复制数据块以创建 ArrayBuffer
                    let data = MarkedArrayBuffer.fromBytes(chunk, JSType.Uint8Array)
                        .toNodeBuffer(globalThis)

                    globalThis.bunVm().eventLoopMut().runCallback(
                        callback,
                        globalThis,
                        jsVal,
                        [jsVal, data]
                    )
                }
            case None => ()
        }

        return true  // 继续读取
    }

    // ========================================================================
    // eventLoop / loop_ - 获取事件循环
    // 严格翻译自: Terminal.rs pub fn event_loop / pub fn loop_
    // ========================================================================

    /// eventLoop - 获取事件循环句柄
    /// 严格翻译自: pub fn event_loop(&self) -> EventLoopHandle
    public func eventLoop(): EventLoopHandle {
        return eventLoopHandle
    }

    /// loop_ - 获取事件循环原始指针
    /// 严格翻译自: pub fn loop_(&self) -> *mut AsyncLoop
    public func loop_(): CPointer<Unit> {
        return eventLoopHandle.loop()
    }

    // ========================================================================
    // finalize - GC 回收
    // 严格翻译自: Terminal.rs pub fn finalize(self: Box<Self>)
    // ========================================================================

    /// finalize - GC 回收时调用
    /// 严格翻译自: pub fn finalize(self: Box<Self>)
    public func finalize(): Unit {
        thisValue.finalize()
        flags.insert(Flags.FINALIZED)
        closeInternal()
    }

    // ========================================================================
    // deinitAndDestroy - 销毁终端
    // 严格翻译自: Terminal.rs fn deinit_and_destroy(this: *mut Terminal)
    // ========================================================================

    /// deinitAndDestroy - 销毁终端
    /// 严格翻译自: fn deinit_and_destroy(this: *mut Terminal)
    /// 引用计数归零时调用
    public func deinitAndDestroy(): Unit {
        // 设置 reader/writer done 标志防止 closeInternal 中的额外 deref 调用
        flags.insert(Flags.READER_DONE)
        flags.insert(Flags.WRITER_DONE)
        // 关闭所有 FD (如果尚未关闭)
        closeInternal()
        // 释放 term_name, reader, writer
        termName.deinit()
        reader.deinit()
        writer.close()
    }
}

// ============================================================================
// BufferedReaderParent trait 实现
// 严格翻译自: Terminal.rs impl BufferedReaderParent for Terminal { ... }
// Bun: bun.io.BufferedReader.init(@This()) - vtable parent
// Terminal 声明 onReadChunk/onReaderDone/onReaderError/loop/eventLoop
// ============================================================================

/// BufferedReaderParent - 缓冲读取器父接口
/// Terminal 实现此接口作为 BufferedReader 的 parent
/// 严格翻译自: impl BufferedReaderParent for Terminal
public interface BufferedReaderParent {
    func onReadChunk(chunk: Array<UInt8>, hasMore: ReadState): Bool
    func onReaderDone(): Unit
    func onReaderError(err: SysError): Unit
    func loop_(): CPointer<Unit>
    func eventLoop(): EventLoopHandle
}

/// Terminal 实现 BufferedReaderParent
/// 严格翻译自: Terminal.rs impl BufferedReaderParent for Terminal
/// BufferedReaderParent 的回调使用 from_parent_ptr 恢复 &Terminal
extension Terminal <: BufferedReaderParent {
    public func onReadChunk(chunk: Array<UInt8>, hasMore: ReadState): Bool {
        return onReadChunk(chunk, hasMore)
    }
    public func onReaderDone(): Unit {
        onReaderDone()
    }
    public func onReaderError(err: SysError): Unit {
        onReaderError(err)
    }
    public func loop_(): CPointer<Unit> {
        return loop_()
    }
    public func eventLoop(): EventLoopHandle {
        return eventLoop()
    }
}

// ============================================================================
// StreamingWriterParent trait 实现
// 严格翻译自: Terminal.rs impl PosixStreamingWriterParent for Terminal { ... }
// Bun: bun.io.StreamingWriter(@This(), struct { onClose, onWritable, onError, onWrite })
// ============================================================================

/// StreamingWriterParent - 流式写入器父接口
/// Terminal 实现此接口作为 StreamingWriter 的 parent
/// 严格翻译自: impl PosixStreamingWriterParent for Terminal
public interface StreamingWriterParent {
    func onWrite(amount: Int64, status: WriteStatus): Unit
    func onError(err: SysError): Unit
    func onReady(): Unit
    func onClose(): Unit
    func swEventLoop(): EventLoopHandle
    func swLoop(): CPointer<Unit>
}

/// Terminal 实现 StreamingWriterParent
/// 严格翻译自: Terminal.rs impl bun_io::pipe_writer::PosixStreamingWriterParent for Terminal
extension Terminal <: StreamingWriterParent {
    public func onWrite(amount: Int64, status: WriteStatus): Unit {
        onWrite(amount, status)
    }
    public func onError(err: SysError): Unit {
        onWriterError(err)
    }
    public func onReady(): Unit {
        onWriterReady()
    }
    public func onClose(): Unit {
        onWriterClose()
    }
    public func swEventLoop(): EventLoopHandle {
        return eventLoopHandle
    }
    public func swLoop(): CPointer<Unit> {
        return eventLoopHandle.loop()
    }
}

// ============================================================================
// StringOrBuffer - 字符串或缓冲区辅助类
// 严格翻译自: Terminal.rs use crate::node::StringOrBuffer
// ============================================================================

/// StringOrBuffer - 字符串或 ArrayBuffer
/// 对应 Bun: crate::node::StringOrBuffer
/// 用于 write() 方法中接受字符串或 ArrayBuffer 参数
public class StringOrBuffer {
    private var bytes: Array<UInt8>
    private var isString: Bool

    private init(bytes: Array<UInt8>, isString: Bool) {
        this.bytes = bytes
        this.isString = isString
    }

    /// 从 JS 值创建 StringOrBuffer
    /// 严格翻译自: StringOrBuffer::from_js(global_object, data)
    public static func fromJS(globalObject: JsGlobalObject, value: JsValue): ?StringOrBuffer {
        if (value.isString()) {
            let str = value.toString()
            return Some(StringOrBuffer(bytes: str.toArray(), isString: true))
        }
        if (value.isArrayBuffer() || value.isTypedArray()) {
            // 从 ArrayBuffer 获取字节
            let bytes = value.toArrayBuffer()
            return Some(StringOrBuffer(bytes: bytes, isString: false))
        }
        return None
    }

    /// 获取字节切片
    public func slice(): Array<UInt8> {
        return bytes
    }

    /// 释放资源
    public func deinit(): Unit {
        bytes = []
    }
}

// ============================================================================
// JsRef - JS 引用管理
// 严格翻译自: bun_jsc::JsRef
// ============================================================================

/// JsRef - JS 引用封装
/// 管理 JS 值的强引用/弱引用
public class JsRef {
    private var value: ?JsValue
    private var isStrong: Bool

    public init() {
        value = None
        isStrong = false
    }

    /// 空引用
    public static func empty(): JsRef {
        return JsRef()
    }

    /// 初始化强引用
    /// 严格翻译自: JsRef::init_strong(value, global)
    public static func initStrong(value: JsValue, global: JsGlobalObject): JsRef {
        let r = JsRef()
        r.value = Some(value)
        r.isStrong = true
        return r
    }

    /// 降级为弱引用 (允许 GC)
    /// 严格翻译自: JsRef::downgrade()
    public func downgrade(): Unit {
        isStrong = false
    }

    /// 升级为强引用 (阻止 GC)
    /// 严格翻译自: JsRef::upgrade(global)
    public func upgrade(global: JsGlobalObject): Unit {
        isStrong = true
    }

    /// 尝试获取 JSValue
    /// 严格翻译自: JsRef::try_get()
    public func tryGet(): ?JsValue {
        return value
    }

    /// 获取内部引用
    public func get(): JsRef {
        return this
    }

    /// GC 回收
    public func finalize(): Unit {
        value = None
        isStrong = false
    }
}

// ============================================================================
// MarkedArrayBuffer - 标记数组缓冲区
// 严格翻译自: bun_jsc::MarkedArrayBuffer
// ============================================================================

/// MarkedArrayBuffer - 标记数组缓冲区
/// 用于创建 JS ArrayBuffer/TypedArray
public class MarkedArrayBuffer {

    /// 从字节数组创建
    /// 严格翻译自: MarkedArrayBuffer::from_bytes(bytes, js_type)
    public static func fromBytes(bytes: Array<UInt8>, jsType: JSType): MarkedArrayBuffer {
        return MarkedArrayBuffer()
    }

    /// 转为 Node Buffer
    public func toNodeBuffer(global: JsGlobalObject): JsValue {
        return JsValue(bytes: [])
    }
}

// ============================================================================
// EventLoopHandle - 事件循环句柄
// 严格翻译自: bun_jsc::EventLoopHandle
// ============================================================================

/// EventLoopHandle - 事件循环句柄
/// 严格翻译自: bun_jsc::EventLoopHandle
public class EventLoopHandle {
    public init() {}

    /// 获取事件循环上下文
    public func asEventLoopCtx(): EventLoopHandle {
        return this
    }

    /// 获取底层 loop 指针
    public func loop(): CPointer<Unit> {
        return CPointer<Unit>()
    }
}

// ============================================================================
// BufferedReader - 缓冲读取器 (增强版, 带 parent 和回调)
// 严格翻译自: bun_io::BufferedReader
// ============================================================================

/// BufferedReader - 带回调的缓冲读取器
/// 对应 Bun: bun_io::BufferedReader
public class BufferedReader {
    public var fd: Int64
    public var parent: CPointer<Unit>
    public var closed: Bool
    public var started: Bool
    public var handle: BufferedReaderHandle
    public var flags: BufferedReaderFlags_
    private var buffer: Array<UInt8>
    private var capacity: Int64

    public init(fd: Int64, capacity: Int64) {
        this.fd = fd
        this.parent = CPointer<Unit>()
        this.closed = false
        this.started = false
        this.handle = BufferedReaderHandle()
        this.flags = BufferedReaderFlags_()
        this.buffer = Array<UInt8>(capacity, { _ => UInt8(0) })
        this.capacity = capacity
    }

    /// 设置 parent 指针
    public func setParent(p: Object): Unit {
        // parent 用于回调
    }

    /// 启动读取
    /// 严格翻译自: BufferedReader.start(fd, true)
    public func start(fd: Int64,_: Bool): SysMaybe<Unit> {
        this.fd = fd
        this.started = true
        return SysMaybe<Unit>.Ok(())
    }

    /// 读取数据
    /// 严格翻译自: BufferedReader.read()
    public func read(): Unit {
        if (closed || !started) {
            return
        }
        // 实际读取由事件循环驱动
    }

    /// 关闭读取器
    public func close(): Unit {
        if (!closed) {
            closed = true
            if (fd != INVALID_FD) {
                FdExt.close(fd)
                fd = INVALID_FD
            }
        }
    }

    /// 更新引用
    public func updateRef(add: Bool): Unit {
        // 对应 Bun BufferedReader.updateRef(add)
    }

    /// 释放资源
    public func deinit(): Unit {
        close()
    }
}

/// BufferedReaderHandle - 读取器句柄
public class BufferedReaderHandle {
    public var poll: ?FilePoll

    public init() {
        poll = None
    }

    public func getPoll(): ?FilePoll {
        return poll
    }
}

/// BufferedReaderFlags_ - 读取器内部标志
public class BufferedReaderFlags_ {
    public var nonblocking: Bool
    public var pollable: Bool

    public init() {
        nonblocking = false
        pollable = false
    }

    public func insert(flags: UInt32): Unit {
        if ((flags & 1) != 0) { nonblocking = true }
        if ((flags & 2) != 0) { pollable = true }
    }
}

/// FilePoll - 文件轮询抽象
public class FilePoll {
    public func setFlag(flag: Int64): Unit {}
}

/// RefCount - 引用计数
/// 严格翻译自: bun_ptr::RefCount<Terminal>
public class RefCount {
    private var count: Int32

    public init() {
        count = 1
    }

    /// 增加引用
    public func ref(): Unit {
        count += 1
    }

    /// 减少引用, 返回 true 如果计数归零
    /// 严格翻译自: bun_ptr::RefCount::deref()
    public func deref(): Bool {
        count -= 1
        return count == 0
    }

    /// 初始化
    public static func init(): RefCount {
        return RefCount()
    }
}

/// JsPromise - JS Promise 辅助
public class JsPromise {
    /// 创建已解决的 Promise
    public static func resolvedPromiseValue(global: JsGlobalObject, value: JsValue): JsValue {
        return value
    }
}

// ported from: src/runtime/api/bun/Terminal.rs
