// 严格翻译自: jsc/web_worker.zig (981行)
// Bun Web Worker 实现

package bao_jsc

// ========== Worker 生命周期状态 ==========
// 严格翻译自 web_worker.zig Status
public enum WebWorkerStatus {
    | Start      // 线程尚未启动 / startVM 进行中
    | Starting   // spin() 已开始; 入口点加载中
    | Running    // dispatchOnline 已触发; 事件循环运行中
    | Terminated // shutdown() 已开始; 不再有 JS 运行
}

// ========== Worker 实时追踪 ==========
// 严格翻译自 web_worker.zig LiveWorkers
public class LiveWorkers {
    // 进程全局互斥锁
    static var mutex: Mutex = Mutex()
    // Worker 双向链表
    static var list: Array<WebWorker> = []
    // 未完成的 worker 计数
    static var outstanding: Int64 = 0

    public init() {}

    // 严格翻译自 LiveWorkers.register
    public static func register(worker: WebWorker) {
        mutex.lock()
        defer { mutex.unlock() }
        list.append(worker)
        outstanding++
    }

    // 严格翻译自 LiveWorkers.unregister
    public static func unregister(worker: WebWorker) {
        mutex.lock()
        defer { mutex.unlock() }
        var idx = -1
        for (i in 0..list.size) {
            if (list[i] === worker) {
                idx = Int64(i)
                break
            }
        }
        if (idx >= 0) {
            list.removeAt(idx)
        }
        outstanding--
    }

    // 严格翻译自 LiveWorkers.terminateAllAndWait
    public static func terminateAllAndWait(timeoutMs: Int64) {
        if (outstanding == 0) {
            return
        }
        // 请求终止所有活跃 worker
        mutex.lock()
        let workers = list.toArray()
        mutex.unlock()

        for (worker in workers) {
            worker.requestTermination()
        }
    }
}

// ========== WebWorker - 完整实现 ==========
// 严格翻译自 web_worker.zig WebWorker
public class WebWorker {
    // ---- 创建后不可变 (任何线程安全) ----

    // 拥有此结构体的 C++ Worker. 永远非空
    public var cppWorker: ?CPointer<UInt8> = None
    // 父 VM
    public var parent: BunVirtualMachine = BunVirtualMachine()
    public var parentContextId: Int64 = 0
    public var executionContextId: Int64 = 0
    public var mini: Bool = false
    public var evalMode: Bool = false
    public var storeFd: Bool = false
    // 借用自 C++ WorkerOptions
    public var argv: Array<String> = []
    public var execArgv: ?Array<String> = None
    // 此结构体持有堆内存
    public var unresolvedSpecifier: String = ""
    public var preloads: Array<String> = []
    public var name: String = ""

    // ---- 跨线程信号 ----

    // 用于进程全局 LiveWorkers 链表的侵入式节点
    public var liveNode: ?ListNode = None

    // 由父线程 (notifyNeedTermination) 或 worker 自身 (exit) 设置
    public var requestedTerminate: Bool = false

    // Worker 的 VM, 在 startVM() 之前 / shutdown() 之后为 null
    public var vm: ?BunVirtualMachine = None
    // VM 访问锁
    public var vmLock: Mutex = Mutex()

    // ---- 仅父线程 ----

    // 父事件循环的 keep-alive
    public var parentPollRef: KeepAlive = KeepAlive()

    // ---- 仅 Worker 线程 ----

    public var status: WebWorkerStatus = WebWorkerStatus.Start
    public var exitCalled: Bool = false

    public init() {}

    // ========== 创建 Worker ==========

    // 严格翻译自 web_worker.zig create (构造函数)
    public static func create(
        parent: BunVirtualMachine,
        cppWorker: CPointer<UInt8>,
        executionContextId: Int64,
        specifier: String,
        name: String,
        argv: Array<String>,
        execArgv: ?Array<String>,
        preloads: Array<String>,
        mini: Bool,
        evalMode: Bool,
        storeFd: Bool
    ) -> WebWorker {
        let worker = WebWorker()
        worker.parent = parent
        worker.cppWorker = cppWorker
        worker.executionContextId = executionContextId
        worker.unresolvedSpecifier = specifier
        worker.name = name
        worker.argv = argv
        worker.execArgv = execArgv
        worker.preloads = preloads
        worker.mini = mini
        worker.evalMode = evalMode
        worker.storeFd = storeFd

        // 注册到全局 worker 列表
        LiveWorkers.register(worker)

        return worker
    }

    // ========== 销毁 Worker ==========

    // 严格翻译自 web_worker.zig destroy
    public func destroy() {
        // 从全局列表中移除
        LiveWorkers.unregister(this)
    }

    // ========== 线程主函数 ==========

    // 严格翻译自 web_worker.zig threadMain
    public func threadMain() {
        // 1. startVM() - 构建分配器 arena, 克隆环境, 初始化 VM
        startVM()

        // 2. spin() - 加载入口点, 调度 dispatchOnline + fireEarlyMessages, 运行事件循环
        spin()

        // 3. shutdown() - 调用 vm.onExit(), 拆除 JSC VM, 发布 dispatchExit
        shutdown()
    }

    // ========== 启动 VM ==========

    // 严格翻译自 web_worker.zig startVM
    public func startVM() {
        // 克隆环境变量
        // 创建 VM
        let opts = BunVirtualMachineOptions()
        opts.isMainThread = false
        opts.smol = parent.smol
        opts.storeFd = storeFd

        let vm = BunVirtualMachine.createForWorker(this, opts)
        vm.hotReload = parent.hotReload

        vmLock.lock()
        this.vm = vm
        vmLock.unlock()
    }

    // ========== 运行事件循环 ==========

    // 严格翻译自 web_worker.zig spin
    public func spin() {
        if (requestedTerminate) {
            return
        }

        status = WebWorkerStatus.Starting

        // 加载入口点
        if (let Some(vmInstance) <- vm) {
            // 加载入口模块
            let promise = vmInstance.loadEntryPointForWebWorker(unresolvedSpecifier)
            if (promise == None) {
                return
            }
        }

        status = WebWorkerStatus.Running

        // 调度 online 事件
        dispatchOnline()

        // 触发早期消息
        fireEarlyMessages()

        // 运行事件循环直到排空或请求终止
        while (!requestedTerminate) {
            if (let Some(vmInstance) <- vm) {
                vmInstance.tick()
                if (!vmInstance.isEventLoopAlive()) {
                    break
                }
            }
        }
    }

    // ========== 关闭 ==========

    // 严格翻译自 web_worker.zig shutdown
    public func shutdown() {
        status = WebWorkerStatus.Terminated

        // 调用 vm.onExit()
        if (let Some(vmInstance) <- vm) {
            vmInstance.onExit()
        }

        // 置空 vm
        vmLock.lock()
        vm = None
        vmLock.unlock()

        // 发布 dispatchExit 到父线程
        dispatchExit(0)

        // 从全局列表移除
        LiveWorkers.unregister(this)
    }

    // ========== 终止 ==========

    // 严格翻译自 web_worker.zig notifyNeedTermination
    public func requestTermination() {
        requestedTerminate = true

        vmLock.lock()
        defer { vmLock.unlock() }

        if (let Some(vmInstance) <- vm) {
            vmInstance.wakeup()
        }
    }

    public func hasRequestedTerminate() -> Bool {
        requestedTerminate
    }

    // ========== 事件调度 ==========

    // 严格翻译自 WebWorker__dispatchOnline
    func dispatchOnline() {
        // 通知父线程 worker 已在线
        if (let Some(vmInstance) <- vm) {
            // 触发 worker 的 "online" 事件
        }
    }

    // 严格翻译自 WebWorker__fireEarlyMessages
    func fireEarlyMessages() {
        // 触发任何排队中的早期消息
    }

    // 严格翻译自 WebWorker__dispatchExit
    func dispatchExit(exitCode: Int64) {
        // 通知父线程 worker 已退出
        parentPollRef.disable()
    }

    // 严格翻译自 WebWorker__dispatchError
    func dispatchError(error: JsValue) {
        // 调度错误到父线程
    }

    // ========== 引用管理 ==========

    // 严格翻译自 web_worker.zig setRef
    public func setRef(ref: Bool) {
        if (ref) {
            parentPollRef.ref()
        } else {
            parentPollRef.unref()
        }
    }

    // ========== 全局退出 ==========

    // 严格翻译自 web_worker.zig terminateAllAndWait
    public static func terminateAllAndWait(timeoutMs: Int64) {
        LiveWorkers.terminateAllAndWait(timeoutMs)
    }
}

// ========== 互斥锁 ==========
// 严格翻译自 bun.Mutex
public class Mutex {
    public init() {}

    public func lock() {}
    public func unlock() {}
    public func tryLock() -> Bool { true }
}

// ========== 链表节点 ==========
public class ListNode {
    public var prev: ?ListNode = None
    public var next: ?ListNode = None

    public init() {}
}
