// bao_event_loop - Signal Watcher 信号监视器
// 严格翻译自: src/event_loop/MiniEventLoop.rs + src/sys/SignalCode.zig
//   Bun 在事件循环中注册信号处理器用于:
//   1. SIGINT (Ctrl+C) - 优雅关闭
//   2. SIGTERM - 优雅终止
//   3. SIGWINCH - 终端大小变化
//   4. SIGCHLD - 子进程状态变化
//   5. SIGPIPE - 忽略 (防止写入已关闭的管道崩溃)
//   对应 Bun: MiniEventLoop 中的信号注册和分发逻辑
//   以及 src/bun.zig 中 Global 信号的初始化
package bao_event_loop

import bao_core.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// SignalWatchEvent - 信号监视事件
// 严格翻译自: Bun 事件循环中信号到达时的事件
// ============================================================================

/// 信号监视事件 - 信号到达时创建
public class SignalWatchEvent {
    /// 信号码
    public var signal: SignalCode
    /// 信号到达时间 (自启动以来的毫秒数)
    public var timestamp: Int64
    /// 信号到达次数 (用于合并同类信号)
    public var count: Int64
    /// 是否为第一次
    public var isFirst: Bool

    public init(signal: SignalCode) {
        this.signal = signal
        this.timestamp = currentTimeMs()
        this.count = 1
        this.isFirst = true
    }

    public init(signal: SignalCode, timestamp: Int64, count: Int64) {
        this.signal = signal
        this.timestamp = timestamp
        this.count = count
        this.isFirst = false
    }

    /// 增加计数
    public func increment(): Unit {
        count += 1
        isFirst = false
    }

    /// 信号名称
    public func name(): String {
        return signal.name()
    }

    /// 信号描述
    public func description(): ?String {
        return signal.description()
    }

    /// 获取当前时间 (毫秒)
    private static func currentTimeMs(): Int64 {
        // 简化实现
        return 0
    }
}

// ============================================================================
// SignalCallback - 信号回调类型
// ============================================================================

/// 信号回调函数类型
public type SignalCallback = (SignalWatchEvent) -> Unit

// ============================================================================
// SignalWatcher - 信号监视器
// 严格翻译自: Bun 事件循环中的信号注册与分发
//   Bun 在启动时注册以下信号处理器:
//   1. SIGINT  - 在主线程中分发到 JS 事件循环
//   2. SIGTERM - 触发优雅关闭
//   3. SIGPIPE - 忽略 (bun.zig: Environment.ignoreSIGPIPE)
//   4. SIGWINCH - 通知终端大小变化
//   5. SIGCHLD  - 通过 waitpid 收割僵尸子进程
//   对应模式:
//     MiniEventLoop.run() -> 收到信号 -> 分发到注册的回调
//     SignalRegistry.dispatch(sigNum) -> SignalWatcher.handleSignal()
// ============================================================================

/// 信号监视器 - 对应 Bun 事件循环的信号管理
/// 注册 POSIX 信号处理器, 将信号分发到事件循环回调
/// 使用全局 SignalRegistry 接收 C 信号桥接
public class SignalWatcher {
    /// 关联的事件循环
    private var loop: ?MiniEventLoop
    /// 信号回调映射 (信号 -> 回调列表)
    private var handlers: HashMap<SignalCode, ArrayList<SignalCallback>>
    /// 已注册的信号集合
    private var registered: HashSet<SignalCode>
    /// 是否活跃
    private var active: Bool
    /// 信号到达队列 (待分发)
    private var pendingSignals: ConcurrentLinkedQueue<SignalWatchEvent>
    /// 是否已初始化默认信号
    private var defaultsInstalled: Bool

    public init() {
        loop = None
        handlers = HashMap<SignalCode, ArrayList<SignalCallback>>()
        registered = HashSet<SignalCode>()
        active = false
        pendingSignals = ConcurrentLinkedQueue<SignalWatchEvent>()
        defaultsInstalled = false
    }

    public init(loop: MiniEventLoop) {
        this.loop = Some(loop)
        handlers = HashMap<SignalCode, ArrayList<SignalCallback>>()
        registered = HashSet<SignalCode>()
        active = false
        pendingSignals = ConcurrentLinkedQueue<SignalWatchEvent>()
        defaultsInstalled = false
    }

    /// 绑定事件循环
    public func attach(loop: MiniEventLoop): Unit {
        this.loop = Some(loop)
    }

    /// 注册信号回调
    /// 对应 Bun: 事件循环中的 signal handler 注册
    /// 例如: process.on('SIGINT', callback) 注册 SIGINT 处理
    public func on(signal: SignalCode, callback: SignalCallback): SysMaybe<Unit> {
        // 确保信号可捕获
        if (!signal.isCatchable()) {
            return SysMaybe<Unit>.Err(
                SysError(22, SysTag.Kill, "Cannot catch ${signal.name()}")
            )
        }

        // 添加到回调列表
        var callbacks = handlers.get(signal)
        if (let Some(list) = callbacks) {
            list.append(callback)
        } else {
            let newList = ArrayList<SignalCallback>()
            newList.append(callback)
            handlers.put(signal, newList)
        }

        // 如果还没注册到系统, 注册信号处理器
        if (!registered.contains(signal)) {
            // 注册到全局信号注册表
            SignalRegistry.register(signal, { (sig: SignalCode) =>
                handleSignalFromC(sig)
            })
            registered.put(signal)
        }

        return SysMaybe<Unit>.Ok(())
    }

    /// 注册一次性信号回调 (触发一次后自动移除)
    public func once(signal: SignalCode, callback: SignalCallback): SysMaybe<Unit> {
        let wrapper: SignalCallback = { (event: SignalWatchEvent) =>
            // 先调用原始回调
            callback(event)
            // 然后移除自己
            off(signal, wrapper)
        }
        return on(signal, wrapper)
    }

    /// 移除信号回调
    /// 对应 Bun: process.removeListener('SIGINT', callback)
    public func off(signal: SignalCode, callback: SignalCallback): Unit {
        let callbacks = handlers.get(signal)
        if (let Some(list) = callbacks) {
            list.remove(callback)
            if (list.size == 0) {
                handlers.remove(signal)
                // 恢复默认处理
                if (registered.contains(signal)) {
                    SignalHandler.restoreDefault(signal)
                    registered.remove(signal)
                }
            }
        }
    }

    /// 移除指定信号的所有回调
    public func removeAll(signal: SignalCode): Unit {
        handlers.remove(signal)
        if (registered.contains(signal)) {
            SignalHandler.restoreDefault(signal)
            registered.remove(signal)
        }
    }

    /// 安装默认信号处理器
    /// 严格对应 Bun 启动时的信号注册:
    /// 1. SIGPIPE - 忽略 (防止写入已关闭管道崩溃)
    ///   bun.zig: Environment.ignoreSIGPIPE
    /// 2. SIGINT  - 注册默认中断处理
    /// 3. SIGTERM - 注册默认终止处理
    public func installDefaults(): Unit {
        if (defaultsInstalled) {
            return
        }
        defaultsInstalled = true

        // SIGPIPE - 忽略
        // 对应 Bun: Environment.ignoreSIGPIPE
        // 防止写入已关闭的管道/套接字时进程崩溃
        SignalHandler.ignore(SignalCode.SIGPIPE)

        // SIGINT - 注册默认中断处理
        // 对应 Bun: process.on('SIGINT', defaultHandler)
        on(SignalCode.SIGINT, { (event: SignalWatchEvent) =>
            // 默认行为: 优雅关闭
            match (loop) {
                case Some(l) => l.stop()
                case None => ()
            }
        })

        // SIGTERM - 注册默认终止处理
        // 对应 Bun: process.on('SIGTERM', defaultHandler)
        on(SignalCode.SIGTERM, { (event: SignalWatchEvent) =>
            match (loop) {
                case Some(l) => l.stop()
                case None => ()
            }
        })

        active = true
    }

    /// 启动信号监视
    public func start(): Unit {
        if (!defaultsInstalled) {
            installDefaults()
        }
        active = true
    }

    /// 停止信号监视
    /// 恢复所有已注册信号的默认处理
    public func stop(): Unit {
        active = false
        // 恢复所有信号的默认处理
        for (signal in registered) {
            SignalHandler.restoreDefault(signal)
        }
        registered.clear()
        handlers.clear()
        SignalRegistry.clear()
    }

    /// 处理从 C 信号桥接收到的信号
    /// 由全局 SignalRegistry.dispatch 调用
    private func handleSignalFromC(signal: SignalCode): Unit {
        if (!active) {
            return
        }
        let event = SignalWatchEvent(signal)
        pendingSignals.put(event)
        // 通知事件循环有信号待处理
        match (loop) {
            case Some(l) =>
                l.enqueue({ =>
                    dispatchPending()
                })
            case None =>
                dispatchPending()
        }
    }

    /// 分发待处理的信号事件
    /// 在事件循环线程中调用所有注册的回调
    public func dispatchPending(): Unit {
        while (true) {
            let event = pendingSignals.remove()
            if (event == None) {
                break
            }
            let e = event.unwrap()
            dispatchOne(e)
        }
    }

    /// 分发单个信号事件
    private func dispatchOne(event: SignalWatchEvent): Unit {
        let callbacks = handlers.get(event.signal)
        if (let Some(list) = callbacks) {
            for (callback in list) {
                callback(event)
            }
        }
    }

    /// 是否有待处理的信号
    public func hasPending(): Bool {
        return !pendingSignals.isEmpty()
    }

    /// 获取已注册的信号列表
    public func getRegisteredSignals(): ArrayList<SignalCode> {
        var result = ArrayList<SignalCode>()
        for (signal in registered) {
            result.append(signal)
        }
        return result
    }

    /// 是否活跃
    public func isActive(): Bool {
        return active
    }
}

// ============================================================================
// SignalWatcherBuilder - 信号监视器构建器
// ============================================================================

/// 信号监视器构建器 - 便捷创建和配置 SignalWatcher
public class SignalWatcherBuilder {
    private var watcher: SignalWatcher

    public init(loop: MiniEventLoop) {
        watcher = SignalWatcher(loop)
    }

    /// 注册 SIGINT 处理
    public func onInterrupt(callback: SignalCallback): SignalWatcherBuilder {
        watcher.on(SignalCode.SIGINT, callback)
        return this
    }

    /// 注册 SIGTERM 处理
    public func onTerminate(callback: SignalCallback): SignalWatcherBuilder {
        watcher.on(SignalCode.SIGTERM, callback)
        return this
    }

    /// 注册 SIGWINCH 处理 (终端大小变化)
    public func onResize(callback: SignalCallback): SignalWatcherBuilder {
        watcher.on(SignalCode.SIGWINCH, callback)
        return this
    }

    /// 注册 SIGCHLD 处理 (子进程状态变化)
    public func onChild(callback: SignalCallback): SignalWatcherBuilder {
        watcher.on(SignalCode.SIGCHLD, callback)
        return this
    }

    /// 注册自定义信号处理
    public func onSignal(signal: SignalCode, callback: SignalCallback): SignalWatcherBuilder {
        watcher.on(signal, callback)
        return this
    }

    /// 安装默认处理器
    public func withDefaults(): SignalWatcherBuilder {
        watcher.installDefaults()
        return this
    }

    /// 构建
    public func build(): SignalWatcher {
        return watcher
    }
}
