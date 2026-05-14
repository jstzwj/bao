// bao_event_loop - 子进程监视器
// 严格翻译自: src/event_loop/ + src/spawn/spawn.zig
//   Bun 在事件循环中通过 SIGCHLD 和 waitpid 管理子进程
//   当子进程退出时, SIGCHLD 信号触发事件循环回调
//   事件循环调用 waitpid 收集退出状态并通知回调
//   对应 Bun: MiniEventLoop 中的子进程管理和 waitpid 逻辑
package bao_event_loop

import bao_core.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// ChildExitStatus - 子进程退出状态
// 严格翻译自: Bun waitpid 解析逻辑
//   WIFEXITED(status) -> 正常退出, WEXITSTATUS(status) -> 退出码
//   WIFSIGNALED(status) -> 信号终止, WTERMSIG(status) -> 终止信号
//   WIFSTOPPED(status) -> 停止, WSTOPSIG(status) -> 停止信号
// ============================================================================

/// 子进程退出状态 - 对应 Bun 对 waitpid 结果的解析
public class ChildExitStatus {
    /// 进程 ID
    public var pid: Int64
    /// 退出状态枚举
    public var status: ChildStatus
    /// 退出码 (正常退出时有效)
    public var exitCode: Int64
    /// 终止信号 (信号终止时有效)
    public var termSignal: SignalCode
    /// 用户数据 (关联回调上下文)
    public var userData: Int64

    public init(pid: Int64, status: ChildStatus) {
        this.pid = pid
        this.status = status
        this.exitCode = 0
        this.termSignal = SignalCode.SIGTERM
        this.userData = 0
    }

    /// 从 waitpid status 解析
    /// 对应 Bun: waitpid(pid, &status, 0) 后的状态解码
    /// sys.zig: WIFEXITED, WEXITSTATUS, WIFSIGNALED, WTERMSIG
    public static func fromWaitpid(pid: Int64, rawStatus: Int32): ChildExitStatus {
        if ((rawStatus & 0x7F) == 0) {
            // WIFEXITED: 正常退出
            // WEXITSTATUS: (status >> 8) & 0xFF
            let code = Int64((rawStatus >> 8) & 0xFF)
            let result = ChildExitStatus(pid, ChildStatus.Exited)
            result.exitCode = code
            return result
        }
        // WIFSIGNALED: 被信号终止
        // WTERMSIG: status & 0x7F
        let sigNum = Int32(rawStatus & 0x7F)
        let sig = SignalCode.fromInt(sigNum)
        let result = ChildExitStatus(pid, ChildStatus.Signaled)
        result.exitCode = 128 + Int64(sigNum)
        if (let Some(s) = sig) {
            result.termSignal = s
        }
        return result
    }

    /// 是否正常退出
    public func isExited(): Bool {
        return status == ChildStatus.Exited
    }

    /// 是否被信号终止
    public func isSignaled(): Bool {
        return status == ChildStatus.Signaled
    }
}

/// 子进程状态 - 对应 Bun ExitStatus
public enum ChildStatus {
    | Exited      // 正常退出 (WIFEXITED)
    | Signaled    // 被信号终止 (WIFSIGNALED)
    | Stopped     // 被停止 (WIFSTOPPED)
    | Running     // 仍在运行
}

// ============================================================================
// ChildCallback - 子进程回调类型
// ============================================================================

/// 子进程退出回调
public typealias ChildCallback = (ChildExitStatus) -> Unit

// ============================================================================
// ChildWatcher - 子进程监视器
// 严格翻译自: Bun 事件循环中的子进程管理
//   Bun 通过以下机制管理子进程:
//   1. 注册 SIGCHLD 信号处理器
//   2. 收到 SIGCHLD 后, 在事件循环中调用 waitpid
//   3. waitpid 返回子进程退出状态
//   4. 查找并调用对应的退出回调
//   5. 清理子进程资源
//
//   对应 Bun: MiniEventLoop 的子进程等待和通知
//   spawn.zig 中的子进程创建和退出处理
// ============================================================================

/// 子进程监视器 - 对应 Bun 事件循环的子进程管理
/// 在事件循环中注册 SIGCHLD 处理, 收割僵尸进程并通知回调
public class ChildWatcher {
    /// 关联的事件循环
    private var loop: ?MiniEventLoop
    /// 子进程回调映射 (PID -> 回调)
    private var callbacks: HashMap<Int64, ChildCallback>
    /// 活跃的子进程集合
    private var activeChildren: HashSet<Int64>
    /// 信号监视器 (用于注册 SIGCHLD)
    private var signalWatcher: ?SignalWatcher
    /// 待处理的退出事件队列
    private var pendingExits: ConcurrentLinkedQueue<ChildExitStatus>
    /// 是否已安装 SIGCHLD 处理器
    private var sigchldInstalled: Bool

    public init() {
        loop = None
        callbacks = HashMap<Int64, ChildCallback>()
        activeChildren = HashSet<Int64>()
        signalWatcher = None
        pendingExits = ConcurrentLinkedQueue<ChildExitStatus>()
        sigchldInstalled = false
    }

    public init(loop: MiniEventLoop) {
        this.loop = Some(loop)
        callbacks = HashMap<Int64, ChildCallback>()
        activeChildren = HashSet<Int64>()
        signalWatcher = None
        pendingExits = ConcurrentLinkedQueue<ChildExitStatus>()
        sigchldInstalled = false
    }

    /// 绑定事件循环
    public func attach(loop: MiniEventLoop): Unit {
        this.loop = loop
    }

    /// 绑定信号监视器
    public func attachSignal(watcher: SignalWatcher): Unit {
        this.signalWatcher = watcher
    }

    /// 注册子进程退出回调
    /// 对应 Bun: spawn 创建子进程后注册退出回调
    /// 当子进程退出时, SIGCHLD 触发 waitpid, 然后调用此回调
    public func watch(pid: Int64, callback: ChildCallback): SysMaybe<Unit> {
        if (pid <= 0) {
            return SysMaybe<Unit>.Err(SysError(22, SysTag.Waitpid))  // EINVAL
        }

        callbacks.put(pid, callback)
        activeChildren.put(pid)

        // 确保 SIGCHLD 处理器已安装
        installSigchldHandler()

        return SysMaybe<Unit>.Ok(())
    }

    /// 取消子进程监视
    public func unwatch(pid: Int64): Unit {
        callbacks.remove(pid)
        activeChildren.remove(pid)
    }

    /// 安装 SIGCHLD 处理器
    /// 严格对应 Bun: 事件循环启动时注册 SIGCHLD 处理
    /// SIGCHLD 在子进程退出/停止/继续时发送给父进程
    /// 处理器在事件循环线程中调用 reapChildren() 收割僵尸
    private func installSigchldHandler(): Unit {
        if (sigchldInstalled) {
            return
        }
        sigchldInstalled = true

        match (signalWatcher) {
            case Some(watcher) =>
                // 通过 SignalWatcher 注册 SIGCHLD
                watcher.on(SignalCode.SIGCHLD, { (event: SignalWatchEvent) =>
                    // 信号到达, 在事件循环中收割子进程
                    match (loop) {
                        case Some(l) =>
                            l.enqueue({ =>
                                reapChildren()
                            })
                        case None =>
                            reapChildren()
                    }
                })
            case None =>
                // 直接注册到全局信号注册表
                SignalRegistry.register(SignalCode.SIGCHLD, { (sig: SignalCode) =>
                    match (loop) {
                        case Some(l) =>
                            l.enqueue({ =>
                                reapChildren()
                            })
                        case None =>
                            reapChildren()
                    }
                })
        }
    }

    /// 收割已退出的子进程
    /// 严格对应 Bun: 事件循环中的 waitpid 逻辑
    /// 使用 WNOHANG 非阻塞等待所有已退出的子进程
    /// 对应 spawn.zig 中的子进程收割:
    ///   while (true) { waitpid(-1, &status, WNOHANG); if (0) break; }
    public func reapChildren(): Unit {
        let WNOHANG: Int32 = 1

        // 使用 waitpid(-1, ..., WNOHANG) 收割任意子进程
        // -1 表示等待任意子进程
        // WNOHANG 表示非阻塞: 没有子进程退出时立即返回 0
        while (true) {
            var rawStatus: Int32 = 0
            let pid = waitpid(-1, &rawStatus, WNOHANG)

            if (pid <= 0) {
                // 0 = 没有子进程退出, -1 = 错误 (ECHILD = 没有子进程)
                break
            }

            // 解析退出状态
            let exitStatus = ChildExitStatus.fromWaitpid(Int64(pid), rawStatus)
            activeChildren.remove(Int64(pid))

            // 加入待处理队列, 在事件循环中分发回调
            pendingExits.put(exitStatus)
        }

        // 分发所有待处理的退出事件
        dispatchPending()
    }

    /// 分发待处理的退出事件
    /// 在事件循环线程中调用所有注册的退出回调
    public func dispatchPending(): Unit {
        while (true) {
            let event = pendingExits.remove()
            if (event == None) {
                break
            }
            let exitStatus = event.unwrap()
            dispatchOne(exitStatus)
        }
    }

    /// 分发单个退出事件
    private func dispatchOne(status: ChildExitStatus): Unit {
        let callback = callbacks.get(status.pid)
        match (callback) {
            case Some(cb) =>
                cb(status)
                callbacks.remove(status.pid)
            case None => ()
        }
    }

    /// 向子进程发送信号
    /// 对应 Bun: subprocess.kill(signal)
    /// 如果子进程已退出, 什么都不做
    public func kill(pid: Int64, signal: SignalCode): SysMaybe<Unit> {
        if (!activeChildren.contains(pid)) {
            return SysMaybe<Unit>.Err(
                SysError(3, SysTag.Kill)  // ESRCH: 没有此进程
            )
        }
        let rc = kill(Int32(pid), signal.toInt())
        if (rc != 0) {
            return SysMaybe<Unit>.Err(
                SysError(UInt16(Int64(OS.errno())), SysTag.Kill)
            )
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 等待指定子进程退出 (阻塞)
    /// 对应 Bun: subprocess.wait() 的阻塞版本
    public func wait(pid: Int64): ChildExitStatus {
        var rawStatus: Int32 = 0
        let result = waitpid(Int32(pid), &rawStatus, 0)
        if (result < 0) {
            let errStatus = ChildExitStatus(pid, ChildStatus.Exited)
            errStatus.exitCode = -1
            return errStatus
        }
        let status = ChildExitStatus.fromWaitpid(pid, rawStatus)
        activeChildren.remove(pid)
        return status
    }

    /// 获取活跃子进程数量
    public func activeCount(): Int64 {
        return activeChildren.size
    }

    /// 是否有待处理的退出事件
    public func hasPendingExits(): Bool {
        return !pendingExits.isEmpty()
    }

    /// 获取所有活跃子进程 PID
    public func getActivePids(): ArrayList<Int64> {
        var result = ArrayList<Int64>()
        for (pid in activeChildren) {
            result.append(pid)
        }
        return result
    }

    /// 关闭监视器
    public func close(): Unit {
        callbacks.clear()
        activeChildren.clear()
        pendingExits = ConcurrentLinkedQueue<ChildExitStatus>()
        sigchldInstalled = false
    }
}

// ============================================================================
// ChildWatcherBuilder - 子进程监视器构建器
// ============================================================================

/// 子进程监视器构建器
public class ChildWatcherBuilder {
    private var watcher: ChildWatcher

    public init(loop: MiniEventLoop) {
        watcher = ChildWatcher(loop)
    }

    /// 绑定信号监视器
    public func withSignalWatcher(signalWatcher: SignalWatcher): ChildWatcherBuilder {
        watcher.attachSignal(signalWatcher)
        return this
    }

    /// 注册子进程
    public func watch(pid: Int64, callback: ChildCallback): ChildWatcherBuilder {
        watcher.watch(pid, callback)
        return this
    }

    /// 构建
    public func build(): ChildWatcher {
        return watcher
    }
}
