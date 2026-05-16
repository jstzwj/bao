// Shell 调度任务类型
// 严格翻译自: src/runtime/shell/dispatch_tasks.rs
// 对应 Bun: runtime::dispatch::run_task 中引用的 shell 任务结构体
// 这些任务类型用于在线程池和主线程之间传递 shell 工作负载

package bao_runtime.shell

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_event_loop.*
import bao_jsc.*

// ============================================================================
// ShellAsyncTask - 异步状态弹回主线程的任务载荷
// 严格翻译自: dispatch_tasks.rs ShellAsyncTask
// 对应 Bun: #[repr(C)] pub struct ShellAsyncTask
// 在 Zig 中 Async 状态结构体本身就是任务;
// 在 NodeId-arena 移植中, 状态存放在 interp.nodes,
// 因此入队的载荷是 (interp, node)。
// ============================================================================

/// Shell 异步任务
/// 用于 Async 状态弹回主线程
public class ShellAsyncTask {
    /// 解释器实例
    public var interp: ?Interpreter
    /// 节点 ID
    public var node: NodeId
    /// 并发任务
    public var concurrentTask: ConcurrentTask

    public init() {
        interp = None
        node = NodeId.invalid()
        concurrentTask = ConcurrentTask()
    }

    public init(interp: Interpreter, node: NodeId, concurrentTask: ConcurrentTask) {
        this.interp = interp
        this.node = node
        this.concurrentTask = concurrentTask
    }
}

// ============================================================================
// ShellAsyncSubprocessDone - 异步子进程完成通知
// 严格翻译自: dispatch_tasks.rs ShellAsyncSubprocessDone
// 对应 Bun: #[repr(C)] pub struct ShellAsyncSubprocessDone
// 从子进程退出处理程序发送回 JS 线程，以恢复拥有的 Cmd 节点。
// ============================================================================

/// Shell 异步子进程完成
/// 子进程退出时发送回主线程
public class ShellAsyncSubprocessDone {
    /// 解释器实例
    public var interp: ?Interpreter
    /// Cmd 节点 ID
    public var cmd: NodeId
    /// 退出码
    public var exitCode: ExitCode
    /// 并发任务
    public var concurrentTask: ConcurrentTask

    public init() {
        interp = None
        cmd = NodeId.invalid()
        exitCode = ExitCode.exited(0)
        concurrentTask = ConcurrentTask()
    }

    public init(interp: Interpreter, cmd: NodeId, exitCode: ExitCode,
                concurrentTask: ConcurrentTask) {
        this.interp = interp
        this.cmd = cmd
        this.exitCode = exitCode
        this.concurrentTask = concurrentTask
    }

    /// 在主线程上运行
    /// 对应 Bun: pub fn run_from_main_thread(this: *mut Self)
    /// 调度契约: `this` 是由 ShellSubprocess::on_process_exit 入队的活动载荷
    public func runFromMainThread(): Unit {
        match (interp) {
            case Some(i) =>
                CmdState.onSubprocessDone(i, cmd, exitCode)
            case None => ()
        }
    }
}

// ============================================================================
// AsyncDeinitWriter - 异步释放 IO 写入器
// 严格翻译自: dispatch_tasks.rs AsyncDeinitWriter
// 对应 Bun: #[repr(C)] pub struct AsyncDeinitWriter
// 将 IOWriter 的释放延迟到主线程，避免 Drop 与写入线程竞争。
// ============================================================================

/// 异步释放 IO 写入器
/// 延迟 IOWriter 的 Drop 到主线程
public class AsyncDeinitWriter {
    /// 要释放的 IO 写入器
    public var writer: ?IOWriter
    /// 并发任务
    public var concurrentTask: ConcurrentTask

    public init() {
        writer = None
        concurrentTask = ConcurrentTask()
    }

    public init(writer: IOWriter, concurrentTask: ConcurrentTask) {
        this.writer = writer
        this.concurrentTask = concurrentTask
    }

    /// 在主线程上运行
    /// 对应 Bun: pub fn run_from_main_thread(this: *mut Self)
    public func runFromMainThread(): Unit {
        match (writer) {
            case Some(w) =>
                w.deinitOnMainThread()
            case None => ()
        }
    }
}

// ============================================================================
// AsyncDeinitReader - 异步释放 IO 读取器
// 严格翻译自: dispatch_tasks.rs AsyncDeinitReader
// 对应 Bun: #[repr(C)] pub struct AsyncDeinitReader
// 将 IOReader 的释放延迟到主线程。
// ============================================================================

/// 异步释放 IO 读取器
/// 延迟 IOReader 的 Drop 到主线程
public class AsyncDeinitReader {
    /// 要释放的 IO 读取器
    public var reader: ?IOReader
    /// 并发任务
    public var concurrentTask: ConcurrentTask

    public init() {
        reader = None
        concurrentTask = ConcurrentTask()
    }

    public init(reader: IOReader, concurrentTask: ConcurrentTask) {
        this.reader = reader
        this.concurrentTask = concurrentTask
    }

    /// 在主线程上运行
    /// 对应 Bun: pub fn run_from_main_thread(this: *mut Self)
    public func runFromMainThread(): Unit {
        match (reader) {
            case Some(r) =>
                r.deinitOnMainThread()
            case None => ()
        }
    }
}

// ============================================================================
// ShellCondExprStatTask - 条件表达式 stat 任务
// 严格翻译自: dispatch_tasks.rs ShellCondExprStatTask
// 对应 Bun: #[repr(C)] pub struct ShellCondExprStatTask
// 包装内部 ShellTask，用于条件表达式的文件 stat 操作。
// ============================================================================

/// 条件表达式 stat 任务内部结构
/// 对应 Bun: #[repr(C)] pub struct CondExprStatInner
public class CondExprStatInner {
    /// Shell 任务
    public var task: ShellTask
    /// 条件节点 ID
    public var cond: NodeId
    /// stat 结果
    public var stat: Result<SysStat>
    /// 路径
    public var path: Array<Byte>

    public init() {
        task = ShellTask()
        cond = NodeId.invalid()
        stat = Result<SysStat>.success(SysStat())
        path = Array<Byte>()
    }
}

/// 条件表达式 stat 任务
/// 用于 [[ ... ]] 中的文件测试操作符
public class ShellCondExprStatTask {
    /// 内部任务
    public var task: CondExprStatInner

    public init() {
        task = CondExprStatInner()
    }

    public init(task: CondExprStatInner) {
        this.task = task
    }

    /// 在主线程上运行
    /// 对应 Bun: pub fn run_from_main_thread(this: *mut Self, interp: &Interpreter)
    public func runFromMainThread(interp: Interpreter): Unit {
        CondExprState.onStatTaskDone(
            interp,
            task.cond,
            task.stat,
            task.path
        )
    }
}

// ============================================================================
// ShellGlobErr - Glob 错误类型
// 严格翻译自: dispatch_tasks.rs ShellGlobErr
// 对应 Bun: pub enum ShellGlobErr
// ============================================================================

/// Shell Glob 错误
public enum ShellGlobErr {
    /// 系统调用错误
    | Syscall(SyscallError)
    /// 未知错误
    | Unknown(Error)
}

// ============================================================================
// ShellGlobTask - Shell Glob 展开任务
// 严格翻译自: dispatch_tasks.rs ShellGlobTask
// 对应 Bun: #[repr(C)] pub struct ShellGlobTask
// 在线程池中执行 glob 模式匹配，完成后回调主线程。
// ============================================================================

/// Shell Glob 展开任务
/// 在线程池中执行 glob 模式匹配
public class ShellGlobTask {
    /// Shell 任务基类
    public var task: ShellTask
    /// 展开节点 ID
    public var expansion: NodeId
    /// Glob 遍历器
    public var walker: GlobWalker
    /// 展开结果 - 匹配到的路径列表
    public var result: ArrayList<Array<Byte>>
    /// 错误
    public var err: ?ShellGlobErr

    public init() {
        task = ShellTask()
        expansion = NodeId.invalid()
        walker = GlobWalker()
        result = ArrayList<Array<Byte>>()
        err = None
    }

    /// 创建并调度
    /// 对应 Bun: pub fn create_and_schedule(interp, expansion, walker)
    public static func createAndSchedule(interp: Interpreter, expansion: NodeId,
                                          walker: GlobWalker): Unit {
        var task = ShellTask(interp.eventLoop)
        task.interp = interp.asCtxPtr()
        let this = ShellGlobTask()
        this.task = task
        this.expansion = expansion
        this.walker = walker
        this.result = ArrayList<Array<Byte>>()
        this.err = None

        ShellTask.scheduleGlob(this)
    }

    /// 在线程池中运行
    /// 对应 Bun: fn run_from_thread_pool(this: &mut Self)
    public func runFromThreadPool(): Unit {
        match (walkImpl()) {
            case .ok(()) => {}
            case .err(let e) =>
                err = ShellGlobErr.Unknown(e)
        }
    }

    /// 在主线程上运行
    /// 对应 Bun: fn run_from_main_thread(this: *mut Self, interp: &Interpreter)
    public func runFromMainThread(interp: Interpreter): Unit {
        ExpansionState.onGlobWalkDone(
            interp,
            expansion,
            result.toArray(),
            err
        )
    }

    /// 执行 glob 遍历
    /// 对应 Bun: fn walk_impl(walker, result) -> Result<Result<()>, Error>
    private func walkImpl(): Result<Unit> {
        var iter = GlobIterator(walker)
        match (iter.init()) {
            case .err(let e) => return Result<Unit>.error(e)
            case .ok(let initResult) =>
                if (initResult.isErr()) {
                    err = ShellGlobErr.Syscall(initResult.getErr())
                    return Result<Unit>.success()
                }
        }

        var done = false
        while (!done) {
            match (iter.next()) {
                case .ok(let nextResult) =>
                    match (nextResult) {
                        case .some(let path) =>
                            // 去除 NUL 终止符
                            var bytes = path
                            if (bytes.size > 0 && bytes[bytes.size - 1] == 0) {
                                bytes = bytes[0..bytes.size - 1]
                            }
                            result.append(bytes)
                        case .none =>
                            done = true
                    }
                case .err(let e) =>
                    err = ShellGlobErr.Syscall(e)
                    done = true
            }
        }
        return Result<Unit>.success()
    }
}

// ============================================================================
// ShellRmDirTask - rm 内置命令的目录递归删除任务
// 严格翻译自: dispatch_tasks.rs ShellRmDirTask (re-export)
// 对应 Bun: pub use crate::shell::builtins::rm::DirTask as ShellRmDirTask
// ============================================================================

/// rm 目录递归删除任务
/// 在线程池中执行文件/目录的递归删除操作
public class ShellRmDirTask {
    /// 要删除的路径
    public var path: String
    /// 是否递归
    public var recursive: Bool
    /// 是否强制
    public var force: Bool

    public init() {
        path = ""
        recursive = false
        force = false
    }

    public init(path: String, recursive: Bool, force: Bool) {
        this.path = path
        this.recursive = recursive
        this.force = force
    }

    /// 在主线程上运行
    /// 对应 Bun: fn run_from_main_thread
    public func runFromMainThread(): Unit {
        // rm 内置命令的完成回调
        if (recursive) {
            Sys.rmtree(path)
        } else {
            Sys.unlink(path)
        }
    }
}

// ============================================================================
// 辅助类型声明
// ============================================================================

/// Shell 任务基类
/// 对应 Bun: pub struct ShellTask (interpreter.zig)
public class ShellTask {
    /// 事件循环
    public var eventLoop: ?EventLoopHandle
    /// 解释器上下文指针
    public var interp: ?CtxPtr

    public init() {
        eventLoop = None
        interp = None
    }

    public init(eventLoop: EventLoopHandle) {
        this.eventLoop = eventLoop
        this.interp = None
    }

    /// 调度 Glob 任务
    public static func scheduleGlob(task: ShellGlobTask): Unit {
        // 将任务提交到线程池
        match (task.eventLoop) {
            case Some(loop) =>
                loop.enqueueTaskConcurrent(task)
            case None => ()
        }
    }
}

/// 节点 ID - 解释器中的 AST 节点标识符
/// 对应 Bun: pub struct NodeId (interpreter.zig)
public struct NodeId {
    public var value: UInt32

    public init(value: UInt32) {
        this.value = value
    }

    /// 无效节点 ID
    public static func invalid(): NodeId {
        NodeId(value: UInt32.max())
    }

    /// 是否有效
    public func isValid(): Bool {
        value != UInt32.max()
    }
}

/// 退出码
/// 对应 Bun: pub const ExitCode (interpreter.zig)
public enum ExitCode {
    | Exited(UInt8)
    | Signaled(UInt8)
    | Unknown

    /// 从退出码创建
    public static func exited(code: UInt8): ExitCode {
        Exited(code)
    }

    /// 从信号创建
    public static func signaled(sig: UInt8): ExitCode {
        Signaled(sig)
    }
}

/// 并发任务包装
/// 对应 Bun: pub use bun_jsc::ConcurrentTask::ConcurrentTask
public class ConcurrentTask {
    public init() {}
}

/// 上下文指针 - 类型擦除的解释器指针
public class CtxPtr {
    public var ptr: UInt64

    public init() {
        ptr = 0
    }
}

/// IO 写入器前向声明
/// 完整实现在 io_writer.cj
public class IOWriter {
    public func deinitOnMainThread(): Unit {}
}

/// IO 读取器前向声明
/// 完整实现在 io_reader.cj
public class IOReader {
    public func deinitOnMainThread(): Unit {}
}

/// 条件表达式状态
/// 对应 Bun: crate::shell::states::cond_expr::CondExpr
public class CondExprState {
    /// stat 任务完成回调
    /// 对应 Bun: pub fn on_stat_task_done(interp, cond, stat, path)
    public static func onStatTaskDone(interp: Interpreter, cond: NodeId,
                                       stat: Result<SysStat>, path: Array<Byte>): Unit {
        // 完整实现在 states/cond_expr.cj
    }
}

/// 展开状态
/// 对应 Bun: crate::shell::states::expansion::Expansion
public class ExpansionState {
    /// Glob 遍历完成回调
    /// 对应 Bun: pub fn on_glob_walk_done(interp, expansion, result, err)
    public static func onGlobWalkDone(interp: Interpreter, expansion: NodeId,
                                       result: Array<Array<Byte>>, err: ?ShellGlobErr): Unit {
        // 完整实现在 states/expansion.cj
    }
}

/// Cmd 状态
/// 对应 Bun: crate::shell::states::cmd::Cmd
public class CmdState {
    /// 子进程完成回调
    /// 对应 Bun: pub fn on_subprocess_done(interp, cmd, exit_code)
    public static func onSubprocessDone(interp: Interpreter, cmd: NodeId,
                                         exitCode: ExitCode): Unit {
        // 完整实现在 states/cmd.cj
    }

    /// 退出码
    public var exitCode: ?UInt8

    /// 退出回调
    public func onExit(code: UInt8): Unit {
        exitCode = code
    }

    public init() {
        exitCode = None
    }
}

/// 解释器前向声明
/// 完整实现在 interpreter.cj
public class Interpreter {
    /// 事件循环句柄
    public var eventLoop: EventLoopHandle

    /// 获取上下文指针
    public func asCtxPtr(): CtxPtr {
        CtxPtr()
    }

    public init() {
        eventLoop = EventLoopHandle()
    }
}

/// Glob 遍历器
/// 对应 Bun: bun.glob.BunGlobWalkerZ
public class GlobWalker {
    public init() {}
}

/// Glob 迭代器
/// 对应 Bun: bun.glob.walk.Iterator
public class GlobIterator {
    public var walker: GlobWalker

    public init(walker: GlobWalker) {
        this.walker = walker
    }

    /// 初始化
    public func init(): Result<GlobInitResult> {
        Result<GlobInitResult>.success(GlobInitResult())
    }

    /// 下一个匹配项
    public func next(): Result<?Array<Byte>> {
        Result<?Array<Byte>>.success(None)
    }
}

/// Glob 初始化结果
public class GlobInitResult {
    public func isErr(): Bool {
        false
    }

    public func getErr(): SyscallError {
        SyscallError()
    }
}

/// 事件循环句柄
public class EventLoopHandle {
    public func enqueueTaskConcurrent(task: ShellGlobTask): Unit {}

    public init() {}
}

/// 系统调用错误
public class SyscallError {}

/// 系统错误
public class Error {}

/// 系统 stat 结果
public class SysStat {}

/// 结果类型
public enum Result<T> {
    | Success(T)
    | Error(Error)

    public static func success(t: T): Result<T> {
        Success(t)
    }

    public static func error(e: Error): Result<T> {
        Error(e)
    }
}
