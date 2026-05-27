// shell_stubs.cj - Shell 包所需的本地类型定义
// 这些类型在依赖包中不存在或存在冲突，因此在 shell 包内本地定义
package bao_runtime.shell

import bao_core.*
import bao_collections.*
import bao_jsc.{JsValue, JSGlobalObject}

// ============================================================================
// FD - 文件描述符 (本地定义，避免 bao_jsc.FD 和 bao_io.FD 之间的歧义)
// bao_jsc.FD 是精简版本（缺少 close/dup/stdout/stderr/fromUV 等方法）
// bao_io.FD 是 type FD = Int32（不提供方法）
// ============================================================================

/// 文件描述符
/// 对应 Bun: bun.FD (packed struct(backing_int))
public class FD {
    public var value: Int64

    public init() {
        value = -1
    }

    public init(v: Int64) {
        value = v
    }

    /// 无效 FD
    public static func invalid(): FD {
        FD(-1)
    }

    /// 从 UV handle 创建
    public static func fromUV(handle: Int64): FD {
        FD(handle)
    }

    /// 标准输入
    public static func stdin(): FD {
        FD(0)
    }

    /// 标准输出
    public static func stdout(): FD {
        FD(1)
    }

    /// 标准错误
    public static func stderr(): FD {
        FD(2)
    }

    /// 当前工作目录
    public static func cwd(): FD {
        FD(0)
    }

    /// 是否有效
    public func isValid(): Bool {
        value >= 0
    }

    /// 获取原生值
    public func native(): Int32 {
        Int32(value)
    }

    /// 关闭文件描述符
    public func close() {
        // stub
    }

    /// 复制文件描述符
    public func dup(): FD {
        FD(value)
    }
}

// ============================================================================
// InterpreterFlags - 解释器标志
// ============================================================================

/// 解释器标志
/// 对应 Bun: interpreter.zig 中的标志位
public class InterpreterFlags {
    public var quiet: Bool = false
    public var done: Bool = false

    public init() {}
}

// ============================================================================
// CleanupState - 清理状态
// ============================================================================

/// 清理状态
/// 对应 Bun: interpreter.zig CleanupState
public enum CleanupState {
    | needsFullCleanup
    | runtimeCleaned
}

// ============================================================================
// AtomicBool - 原子布尔值
// ============================================================================

/// 原子布尔值
public class AtomicBool {
    private var val: Bool

    public init(v: Bool) {
        val = v
    }

    public func store(v: Bool) {
        val = v
    }

    public func load(): Bool {
        val
    }
}

// ============================================================================
// AtomicUInt32 - 原子无符号32位整数
// ============================================================================

/// 原子无符号32位整数
public class AtomicUInt32 {
    private var val: UInt32

    public init(v: UInt32) {
        val = v
    }

    public func store(v: UInt32) {
        val = v
    }

    public func load(): UInt32 {
        val
    }

    public func fetchAdd(v: UInt32): UInt32 {
        let old = val
        val += v
        return old
    }

    public func fetchSub(v: UInt32): UInt32 {
        let old = val
        val -= v
        return old
    }
}

// ============================================================================
// SyscallError - 系统调用错误
// ============================================================================

/// 系统调用错误
public class SyscallError {
    public var code: Int32
    public var message: String

    public init() {
        code = 0
        message = ""
    }

    public init(code: Int32, message: String) {
        this.code = code
        this.message = message
    }

    public func toSystemError(): SystemError {
        return SystemError(message, "")
    }
}

// ============================================================================
// Syscall - 系统调用封装
// 对应 Bun 中的 bun.sys 系统调用
// ============================================================================

/// 系统调用封装
public class Syscall {
    /// 复制文件描述符
    public static func dup(fd: FD): FD {
        FD(fd.value)
    }

    /// 打开文件（at版本）
    public static func openat(dir: FD, path: String, flags: Int64, perm: Int64): Maybe<FD> {
        Maybe<FD>.success(FD(-1))
    }

    /// 打开文件
    public static func open(filePath: String, flags: Int64, perm: Int64): Maybe<FD> {
        Maybe<FD>.success(FD(-1))
    }

    /// stat（at版本）
    public static func fstatat(dir: FD, path: String): Maybe<Stat> {
        Maybe<Stat>.success(Stat())
    }
}

// ============================================================================
// O - 文件打开标志
// 对应 Bun: sys.O
// ============================================================================

/// 文件打开标志
public class O {
    public static let RDONLY: Int64 = 0x0000
    public static let WRONLY: Int64 = 0x0001
    public static let RDWR: Int64 = 0x0002
    public static let CREAT: Int64 = 0o100
    public static let EXCL: Int64 = 0o200
    public static let NOCTTY: Int64 = 0o400
    public static let TRUNC: Int64 = 0o1000
    public static let APPEND: Int64 = 0o2000
    public static let NONBLOCK: Int64 = 0o4000
    public static let DIRECTORY: Int64 = 0o200000
    public static let NOFOLLOW: Int64 = 0o400000
    public static let CLOEXEC: Int64 = 0o2000000
}

// ============================================================================
// Posix - POSIX 工具函数
// ============================================================================

/// POSIX 工具函数
public class Posix {
    public static func isatty(fd: Int32): Bool {
        false
    }
}

// ============================================================================
// S - 文件模式判断
// ============================================================================

/// 文件模式判断
public class S {
    public static func isFifo(mode: FileMode): Bool {
        false
    }

    public static func isSock(mode: FileMode): Bool {
        false
    }
}

// ============================================================================
// FileMode - 文件模式
// ============================================================================

/// 文件模式
public class FileMode {
    public var value: UInt32

    public init() {
        value = 0
    }

    public init(v: UInt32) {
        value = v
    }
}

// ============================================================================
// Stat - 文件状态
// ============================================================================

/// 文件状态
public class Stat {
    public init() {}
}

// ============================================================================
// Parser - Shell 解析器
// ============================================================================

/// Shell 解析器
public class Parser {
    public init() {}
}

// ============================================================================
// Script - Shell 脚本
// ============================================================================

/// Shell 脚本
public class Script {
    public init() {}
    public func memoryCost(): Int64 { 0 }
}

// ============================================================================
// KeepAlive - 保持活动引用
// ============================================================================

/// 保持活动引用
/// 对应 Bun: bun.jsc.keep_alive
public class KeepAlive {
    public init() {}

    public func disable() {}
}

// ============================================================================
// DefaultAllocator - 默认分配器
// ============================================================================

/// 默认分配器
public class DefaultAllocator {
    public static let instance: Allocator = CAllocator()
}

// ============================================================================
// ChildPtr - IO 读取器/写入器的子节点指针
// ============================================================================

/// IO 子节点指针
public class ChildPtr {
    public var ptr: ?Any

    public init() {
        ptr = Option<Any>.None
    }

    public init(ptr: Any) {
        this.ptr = ptr
    }
}

// ============================================================================
// ReadState - 读取状态
// ============================================================================

/// 读取状态
public enum ReadState {
    | done
    | hasMore
    | error
}

// ============================================================================
// WriterImpl - IO 写入器实现
// ============================================================================

/// IO 写入器实现
public class WriterImpl {
    public init() {}
}

// ============================================================================
// WriteStatus - 写入状态
// ============================================================================

/// 写入状态
public enum WriteStatus {
    | done
    | partial
    | error
}

// ============================================================================
// Process - 进程
// ============================================================================

/// 进程
public class Process {
    public var pid: Int32
    public var exitCode: ?UInt8
    public var exitHandler: ExitHandler

    public init() {
        pid = 0
        exitCode = None
        exitHandler = ExitHandler()
    }

    public init(pid: Int32) {
        this.pid = pid
        exitCode = None
        exitHandler = ExitHandler()
    }

    public func hasExited(): Bool {
        exitCode.isSome()
    }

    public func hasKilled(): Bool {
        false
    }

    public func kill(sig: Int32): Maybe<Unit> {
        Maybe<Unit>.success(())
    }

    public func close() {}

    public func wait(sync: Bool) {}

    public func enableKeepingEventLoopAlive() {}

    public func disableKeepingEventLoopAlive() {}

    /// 终止进程 — 对应 Bun: bun.outOfMemory() / Process.abort()
    public static func abort(): Nothing {
        exit(1)
    }
}

// ============================================================================
// Set<T> - 集合类型
// ============================================================================

/// 集合类型
public class Set<T> {
    private var items: ArrayList<T>

    public init() {
        items = ArrayList<T>()
    }

    public func insert(item: T) {
        items.append(item)
    }

    public func contains(item: T): Bool {
        // stub: 不支持泛型约束
        return false
    }

    public func size(): Int64 {
        items.size
    }
}

// ============================================================================
// StdioKind - 标准 IO 类型
// ============================================================================

/// 标准 IO 类型 — 已在 subproc.cj 中定义 StdioKind

// AsyncState 已在 async.cj 中定义（同包），此处不再重复定义

// ============================================================================
// SpawnStatus - 子进程退出状态
// ============================================================================

/// 子进程退出状态
public enum SpawnStatus {
    | exited(Int32)
    | signaled(Int32)
    | unknown
}

// ============================================================================
// Rusage - 资源使用统计
// ============================================================================

/// 资源使用统计
public class Rusage {
    public init() {}
}

// ============================================================================
// FileSink - 文件接收器
// ============================================================================

/// 文件接收器
public class FileSink {
    public var signal: Signal
    public init() {
        signal = Signal()
    }
    public func deref(): Unit {}
    public func updateRef(add: Bool): Unit {}
    public func end(data: ?ArrayList<Byte>): Unit {}
    public func toJS(globalThis: JSGlobalObject): JsValue { JsValue.jsUndefined() }
}

// ============================================================================
// StaticPipeWriter - 静态管道写入器
// ============================================================================

/// 静态管道写入器
public class StaticPipeWriter {
    public var source: Source
    public init() {
        source = Source()
    }
    public func deref(): Unit {}
    public func updateRef(add: Bool): Unit {}
}

// ============================================================================
// AsyncLoop - 异步循环
// ============================================================================

/// 异步循环
public class AsyncLoop {
    public init() {}
}

// ============================================================================
// StdioResult - 标准 IO 结果
// ============================================================================

/// 标准 IO 结果
public enum StdioResult {
    | fd(FD)
    | pipe(FD, FD)
    | ignore
    | inherit
    | path
}

// ============================================================================
// 状态类型桩 - 完整定义在 states/ 子包
// 由于循环依赖，此处提供最小化的桩类型
// 注意: Cmd, Stmt, Pipeline, CondExpr, Subshell 等名称已在 shell.cj 中定义
// 这里只定义 shell.cj 中不存在的类型
// ============================================================================

// Assigns 已在 assigns.cj 中定义（同包），此处不再重复定义
// Expansion 已在 expansion.cj 中定义（同包），此处不再重复定义

/// If条件状态 — 已在 shell.cj 中定义 If 类

// ============================================================================
// BufferedReader - 缓冲读取器 (本地桩类型)
// ============================================================================

/// 缓冲读取器
/// 对应 Bun: bun.io.BufferedReader
public class BufferedReader {
    public var fd: Int64
    public var closed: Bool
    public var started: Bool
    public var buffer: ArrayList<Byte>
    public var flags: BufferedReaderFlags

    public init() {
        fd = -1
        closed = false
        started = false
        buffer = ArrayList<Byte>()
        flags = BufferedReaderFlags()
    }

    public func setParent(p: Object): Unit {}

    public func start(fd: StdioResult, sync: Bool): Bool {
        this.started = true
        return true
    }

    public func read(): Unit {}

    public func isDone(): Bool { closed }

    public func watch(): Unit {}

    public func updateRef(add: Bool): Unit {}

    public func takeBuffer(): ArrayList<Byte> {
        let result = this.buffer
        this.buffer = ArrayList<Byte>()
        return result
    }

    public func getBuffer(): ArrayList<Byte> { this.buffer }

    public func clearBuffer(): Unit { this.buffer.clear() }

    public func close(): Unit { this.closed = true }

    public func registerPoll(): Unit {}

    public func deinit(): Unit { this.close() }
}

/// 缓冲读取器标志
public class BufferedReaderFlags {
    public var socket: Bool = false

    public init() {}
}

// ============================================================================
// ExitHandler - 退出处理器 (本地桩类型)
// ============================================================================

/// 退出处理器
/// 对应 Bun: bun.jsc.ExitHandler
public class ExitHandler {
    public init() {}
}

// ============================================================================
// Signal - 信号 (本地桩类型)
// ============================================================================

/// 信号
/// 对应 Bun: bun.io.Signal
public class Signal {
    public init() {}
    public func clear(): Unit {}
}

// ============================================================================
// Source - 数据源 (本地桩类型)
// ============================================================================

/// 数据源
/// 对应 Bun: bun.io.Source
public class Source {
    public init() {}
    public func detach(): Unit {}
}
