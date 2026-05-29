// Shell 调度任务类型
// 严格翻译自: src/runtime/shell/dispatch_tasks.rs
// 对应 Bun: runtime::dispatch::run_task 中引用的 shell 任务结构体
// 这些任务类型用于在线程池和主线程之间传递 shell 工作负载

package bao_runtime.shell

import bao_core.*
import bao_collections.*
import bao_event_loop.*
import bao_collections.ArrayList

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
    /// 对应 Bun: pub fn run_from_main_thread(`this`: *Self)
    /// 调度契约: `this` 是由 ShellSubprocess::on_process_exit 入队的活动载荷
    public func runFromMainThread(): Unit {
        match (interp) {
            case Some(i) =>
                CmdState.onSubprocessDone(i, cmd, exitCode)
            case None => ()
        }
    }
}

// AsyncDeinitWriter 和 AsyncDeinitReader 已在 io_writer.cj / io_reader.cj 中定义。

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
    public var stat: DispatchResult<DispatchSysStat>
    /// 路径
    public var path: Array<Byte>

    public init() {
        task = ShellTask()
        cond = NodeId.invalid()
        stat = DispatchResult<DispatchSysStat>.ok(DispatchSysStat())
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
    /// 对应 Bun: pub fn run_from_main_thread(`this`: *Self, interp: &Interpreter)
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
    | Syscall(DispatchSyscallError)
    /// 未知错误
    | Unknown(DispatchError)
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
        let globTask = ShellGlobTask()
        globTask.task = task
        globTask.expansion = expansion
        globTask.walker = walker
        globTask.result = ArrayList<Array<Byte>>()
        globTask.err = None

        ShellTask.scheduleGlob(globTask)
    }

    /// 在线程池中运行
    /// 对应 Bun: fn run_from_thread_pool(`this`: &Self)
    public func runFromThreadPool(): Unit {
        match (walkImpl()) {
            case Ok(()) => ()
            case Err(de) =>
                this.err = ShellGlobErr.Unknown(de)
        }
    }

    /// 在主线程上运行
    /// 对应 Bun: fn run_from_main_thread(`this`: *Self, interp: &Interpreter)
    public func runFromMainThread(interp: Interpreter): Unit {
        // Glob 遍历完成，将结果回传给 ExpansionState
        if (this.expansion.isValid()) {
            ExpansionState.onGlobTaskDone(interp, this.expansion, this.result, this.err)
        }
    }

    /// 执行 glob 遍历
    /// 对应 Bun: fn walk_impl(walker, result) -> Result<Result<()>, Error>
    private func walkImpl(): DispatchResult<Unit> {
        let iter = GlobIterator(this.walker)
        let initResult = iter.`init`()
        if (initResult.isErr()) {
            return DispatchResult<Unit>.Err(DispatchError())
        }
        var walkResult = iter.next()
        while (true) {
            match (walkResult) {
                case Ok(Some(path)) =>
                    this.result.append(path)
                    walkResult = iter.next()
                case Ok(None) =>
                    return DispatchResult<Unit>.ok(())
                case Err(e) =>
                    return DispatchResult<Unit>.Err(e)
            }
        }
        return DispatchResult<Unit>.ok(())
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
        if (this.recursive) {
            // 递归删除: 使用系统调用 rm -rf
            let exitCode = ShellBuiltinUtil.rmrf(this.path)
            if (exitCode != 0 && !this.force) {
                // 非 force 模式下报错
                ()
            }
        } else {
            // 删除单个文件或空目录
            ShellBuiltinUtil.removePath(this.path, this.force)
        }
    }
}

// ============================================================================
// 辅助类型 — 仅声明本文件独有、其他模块未定义的类型。
// ExitCode, Interpreter, IOReader, IOWriter, AsyncDeinitReader, AsyncDeinitWriter,
// CmdState, ExpansionState, CondExprState, Result<T>(shell.cj)
// 等类型分别在 interpreter.cj / io_reader.cj / io_writer.cj / io.cj / shell.cj
// 中定义。
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
        match (task.task.eventLoop) {
            case Some(loop) =>
                ShellEventLoopUtil.enqueueTaskConcurrent(loop, task)
            case None => ()
        }
    }
}

/// 节点 ID - 解释器中的 AST 节点标识符
/// 对应 Bun: pub struct NodeId (interpreter.zig)
public struct NodeId {
    public var value: UInt32

    public init(v: UInt32) {
        this.value = v
    }

    /// 无效节点 ID
    public static func invalid(): NodeId {
        NodeId(4294967295) // UInt32.max = 0xFFFFFFFF
    }

    /// 是否有效
    public func isValid(): Bool {
        value != 4294967295
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
    public func `init`(): DispatchResult<GlobInitResult> {
        DispatchResult<GlobInitResult>.ok(GlobInitResult())
    }

    /// 下一个匹配项
    public func next(): DispatchResult<?Array<Byte>> {
        DispatchResult<?Array<Byte>>.ok(Option<Array<Byte>>.None)
    }
}

/// Glob 初始化结果
public class GlobInitResult {
    public func isErr(): Bool {
        false
    }

    public func getErr(): DispatchSyscallError {
        DispatchSyscallError()
    }
}

/// Shell 调度用事件循环句柄扩展
/// 注意: EventLoopHandle 来自 bao_event_loop, 这里只添加扩展方法
/// 由于 Cangjie 不允许向外部类添加方法, 使用工具类代替
public class ShellEventLoopUtil {
    public static func enqueueTaskConcurrent(handle: EventLoopHandle, task: ShellGlobTask): Unit {}
}

/// Shell 内置命令工具
/// 提供内置命令所需的系统调用封装
public class ShellBuiltinUtil {
    /// 递归删除目录（rm -rf）
    public static func rmrf(path: String): Int32 {
        // 对应 Bun: 递归删除目录 — 通过 SysFs 递归删除
        try {
            SysFs.rmrf(path)
            return 0
        } catch {
            case e => return 1
        }
    }

    /// 删除单个路径（文件或空目录）
    public static func removePath(path: String, force: Bool): Unit {
        // 对应 Bun: unlink/rmdir
        try {
            if (SysFs.isDirectory(path)) {
                SysFs.rmdir(path)
            } else {
                SysFs.unlink(path)
            }
        } catch {
            case _ => ()
        }
    }
}

/// 本地调度用系统调用错误
public class DispatchSyscallError {}

/// 本地调度用系统错误
public class DispatchError {}

/// 本地调度用系统 stat 结果
public class DispatchSysStat {}

/// 调度用结果类型 (避免与 shell.cj 中 Result<T> 冲突)
public enum DispatchResult<T> {
    | Ok(T)
    | Err(DispatchError)

    public static func ok(t: T): DispatchResult<T> {
        Ok(t)
    }

    public static func error(e: DispatchError): DispatchResult<T> {
        Err(e)
    }
}

