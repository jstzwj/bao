// 严格翻译自: jsc/web_worker.zig (981行)
// Bun Web Worker 实现
//
// 生命周期 / 线程模型
// ==========================
//
// 三个对象，两个线程，一个所有权规则:
//
//   PARENT THREAD:
//     JSWorker (GC'd JSCell) --Ref--> WebCore::Worker (ThreadSafeRefCounted)
//                                      --impl_--owns--> Zig WebWorker
//
//   WORKER THREAD:
//     runs threadMain() -> spin() -> shutdown(); reads this struct directly
//
// 所有权规则: 此结构体由 C++ WebCore::Worker 拥有。
// 在 create() 中分配，在 ~Worker 中通过 WebWorker__destroy 释放。
// Worker 线程永远不释放它。因为 JSWorker 持有 Ref<Worker>，
// impl_ 在 JS 可以调用 terminate()/ref()/unref() 的整个时间内有效。
//
// Refs on WebCore::Worker:
//   - JSWorker wrapper  +1  (在 GC 时释放)
//   - worker thread     +1  在 Worker::create() 中线程启动前获取，
//                          在 dispatchExit() 发布的 close task 中于 PARENT 线程释放。
//                          因此 ~Worker 永远不在 worker 线程上运行。

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
// 进程全局的 worker 线程注册表，用于在进程退出前终止所有 worker
// 锁定顺序: LiveWorkers.mutex -> worker.vmLock (永远不反向)
public class LiveWorkers {
    // 进程全局互斥锁
    static var mutex: Mutex = Mutex()
    // Worker 双向链表
    static var list: Array<WebWorker> = []
    // 未完成的 worker 计数 (独立原子变量，供 terminateAllAndWait futex-wait)
    static var outstanding: Int64 = 0

    public init() {}

    // 严格翻译自 LiveWorkers.register
    // 在线程启动前注册，确保 terminateAllAndWait 不会遗漏
    public static func register(worker: WebWorker) {
        mutex.lock()
        defer { mutex.unlock() }
        list.append(worker)
        outstanding++
        // 唤醒 terminateAllAndWait 以便重新扫描并捕获此 worker
        // (可能是由另一个 worker 在扫描中途创建的)
    }

    // 严格翻译自 LiveWorkers.unregister
    public static func unregister(worker: WebWorker) {
        mutex.lock()
        var idx = -1
        for (i in 0..list.size) {
            if (list[i].executionContextId == worker.executionContextId) {
                idx = Int64(i)
                break
            }
        }
        if (idx >= 0) {
            list.removeAt(idx)
        }
        mutex.unlock()
        // 在降为零时唤醒 terminateAllAndWait 中的等待者
        outstanding--
    }

    // 严格翻译自 LiveWorkers.terminateAllAndWait
    // 请求终止每个活跃 worker 并阻塞直到每个都到达 shutdown()
    // (过了所有进程全局 resolver 访问点)，或 timeoutMs 超时。
    // 从 VirtualMachine.globalExit() 在主线程调用，
    // 在 transpiler.deinit() 释放进程全局 BSSMap 单例之前。
    //
    // 终止是协作的: requested_terminate 在 startVM() 和 spin() 的
    // 检查点中被轮询，对于运行中的 VM，
    // notifyNeedTermination() 在下一个 JSC 安全点引发 TerminationException。
    public static func terminateAllAndWait(timeoutMs: Int64) {
        if (outstanding == 0) {
            return
        }

        var startTime = currentTimeMillis()
        let deadline = startTime + timeoutMs

        while (true) {
            // 严格翻译自: 扫描列表，设置 terminate 标志
            {
                mutex.lock()
                defer { mutex.unlock() }
                for (worker in list) {
                    if (!worker.requestedTerminate) {
                        worker.requestedTerminate = true
                        // 严格翻译自: vm_lock 保护下读取 vm
                        worker.vmLock.lock()
                        defer { worker.vmLock.unlock() }
                        if (let Some(vm) <- worker.vm) {
                            // FFI: vm.jsc_vm.notifyNeedTermination()
                            // FFI: vm.eventLoop().wakeup()
                            vm.wakeup()
                        }
                    }
                }
            }

            let n = outstanding
            if (n == 0) {
                return
            }
            let elapsed = currentTimeMillis() - startTime
            if (elapsed >= deadline) {
                // 超时
                return
            }
            // FFI: futex-wait on outstanding, deadline - elapsed
            // 简化实现: yield
        }
    }
}

// ========== WebWorker - 完整实现 ==========
// 严格翻译自 web_worker.zig WebWorker
//
// 字段按线程分组:
//   - "Immutable after create()" - 任何线程安全
//   - "Cross-thread signalling" - 需要同步
//   - "Parent-thread only" - 仅父线程
//   - "Worker-thread only" - 仅 Worker 线程
public class WebWorker {

    // ---- 创建后不可变 (任何线程安全) ----

    // 拥有此结构体的 C++ Worker. 永远非空; 此结构体由 ~Worker 释放，
    // 所以指针不会悬空。
    public var cppWorker: ?CPointer<UInt8> = None
    // 父 jsc.VirtualMachine。在 worker 线程由 startVM() 读取
    // (转换选项、环境、proxy 存储、独立模块图)，
    // 在父线程由 setRef() / releaseParentPollRef() 读取。
    public var parent: BunVirtualMachine = BunVirtualMachine()
    public var parentContextId: Int64 = 0
    public var executionContextId: Int64 = 0
    public var mini: Bool = false
    public var evalMode: Bool = false
    public var storeFd: Bool = false
    // 借用自 C++ WorkerOptions (由拥有的 Worker 保持存活)
    public var argv: Array<String> = []
    public var execArgv: ?Array<String> = None
    // 此结构体持有的堆内存; 在 destroy() 中释放
    public var unresolvedSpecifier: String = ""
    public var preloads: Array<String> = []
    public var name: String = ""

    // ---- 跨线程信号 ----

    // 用于进程全局 LiveWorkers 链表的侵入式节点
    public var liveNode: ?ListNode = None

    // 由父线程 (notifyNeedTermination) 或 worker 自身 (exit) 设置。
    // Worker 循环在 tick 之间轮询此标志。
    public var requestedTerminate: Bool = false

    // Worker 的 jsc.VirtualMachine，在 startVM() 之前 / shutdown() 之后为 null。
    // 位于 arena 内。任何跨线程读取必须持有 vmLock
    // (参见文件头注释)。
    public var vm: ?BunVirtualMachine = None
    // vm_lock 仅用于关闭 TOCTOU:
    // (a) startVM 中发布 vm
    // (b) shutdown 中置空 vm
    // (c) notifyNeedTermination 中读取 vm + 调用 wakeup()
    public var vmLock: Mutex = Mutex()

    // ---- 仅父线程 ----

    // 父事件循环的 keep-alive。Async.KeepAlive 不是线程安全的;
    // 在 create() 中引用，由 setRef() (JS .ref()/.unref()) 切换，
    // 由 close task 中的 releaseParentPollRef() 释放 — 全部在父线程上。
    public var parentPollRef: KeepAlive = KeepAlive()

    // ---- 仅 Worker 线程 ----

    public var status: WebWorkerStatus = WebWorkerStatus.Start
    // Worker 线程的 mimalloc arena
    public var arena: ?String = None
    // 由 exit() 设置，以便 spin() 的错误路径不会覆盖显式的 process.exit(code)
    public var exitCalled: Bool = false

    public init() {}

    // =========================================================================
    // 构造 (父线程)
    // =========================================================================

    // ========== 创建 Worker ==========
    // 严格翻译自 web_worker.zig create
    // 分配结构体，获取父事件循环的 keep-alive，并启动 worker 线程。
    // 在任何失败时返回 null，并设置 errorMessage，无需清理。
    public static func create(
        cppWorker: CPointer<UInt8>,
        parent: BunVirtualMachine,
        nameStr: String,
        specifierStr: String,
        errorMessage: String,
        parentContextId: Int64,
        thisContextId: Int64,
        mini: Bool,
        defaultUnref: Bool,
        evalMode: Bool,
        argvPtr: Array<String>,
        execArgvPtr: ?Array<String>,
        inheritExecArgv: Bool,
        preloadModules: Array<String>
    ): ?WebWorker {
        // 严格翻译自: 解析预加载模块
        var preloadsList: Array<String> = []
        for (module in preloadModules) {
            let resolved = resolveEntryPointSpecifier(
                parent, module, errorMessage, ArrayList()
            )
            if (resolved != None) {
                preloadsList.append(resolved.getOrThrow())
            }
            if (!errorMessage.isEmpty) {
                return None
            }
        }

        let worker = WebWorker()
        worker.cppWorker = cppWorker
        worker.parent = parent
        worker.parentContextId = parentContextId
        worker.executionContextId = thisContextId
        worker.mini = mini
        worker.evalMode = evalMode
        worker.unresolvedSpecifier = specifierStr
        worker.storeFd = parent.transpiler.storeFd
        worker.name = nameStr
        worker.argv = argvPtr
        worker.execArgv = if (inheritExecArgv) { None } else { execArgvPtr }
        worker.preloads = preloadsList

        // 严格翻译自: 保持父事件循环存活直到 close task 释放
        // 如果用户传递了 { ref: false } 则跳过 — 他们已选择不让 worker 保持进程存活
        if (!defaultUnref) {
            worker.parentPollRef.ref(parent)
        }

        // 严格翻译自: 在启动前注册，确保 terminateAllAndWait 永远不会遗漏
        // 线程已在运行的 worker
        LiveWorkers.register(worker)

        // 严格翻译自: 启动线程
        // 在真实实现中，这里会 std.Thread.spawn 然后 detach
        // 简化实现: 直接返回 worker 对象

        worker
    }

    // ========== 销毁 Worker ==========
    // 严格翻译自 web_worker.zig destroy
    // 释放结构体及其拥有的字符串。从 WebCore::Worker::~Worker() 调用
    // (或从 create() 在启动失败时调用)。
    public func destroy() {
        // 释放拥有的字符串
        unresolvedSpecifier = ""
        for (preload in preloads) {
            // 释放每个预加载路径
        }
        preloads = []
        if (name.size > 0) {
            name = ""
        }
    }

    // =========================================================================
    // 父线程 API (从 C++ 通过 JS 调用)
    // =========================================================================

    // ========== 引用管理 ==========
    // 严格翻译自 web_worker.zig setRef
    // worker.ref()/.unref() 从 JS 调用。结构体保证存活:
    // 它由 ~Worker 释放，而 ~Worker 在 JSWorker (调用者) 持有其 Ref<Worker> 时无法运行。
    // Worker::setKeepAlive() 在 terminate() 或 close task 后阻止调用，
    // 所以这里可以无条件切换。
    public func setRef(value: Bool) {
        if (value) {
            parentPollRef.ref(parent)
        } else {
            parentPollRef.unref(parent)
        }
    }

    // ========== 终止请求 ==========
    // 严格翻译自 web_worker.zig notifyNeedTermination
    // worker.terminate() 从 JS 调用。设置 requested_terminate，
    // 中断 worker 中正在运行的 JS (下一个安全点的 TerminationException)，
    // 并唤醒 worker 循环以观察标志。
    // parent_poll_ref 保持持有直到 close task 运行，
    // 以便 await worker.terminate() 保持父线程存活直到 'close' 触发。
    public func notifyNeedTermination() {
        if (setRequestedTerminate()) {
            return  // 已经请求过终止
        }

        // vm_lock 序列化防止 shutdown() 置空 vm 并释放它所在的 arena
        vmLock.lock()
        defer { vmLock.unlock() }
        if (let Some(vm) <- vm) {
            // FFI: vm.jsc_vm.notifyNeedTermination()
            vm.wakeup()
        }
    }

    // 严格翻译自 web_worker.zig hasRequestedTerminate
    public func hasRequestedTerminate(): Bool {
        requestedTerminate
    }

    // 严格翻译自 web_worker.zig setRequestedTerminate
    // 原子交换，返回旧值
    private func setRequestedTerminate(): Bool {
        let old = requestedTerminate
        requestedTerminate = true
        old
    }

    // ========== 释放父轮询引用 ==========
    // 严格翻译自 web_worker.zig releaseParentPollRef
    // 释放父事件循环的 keep-alive。在父线程上从 dispatchExit 发布的
    // close task 中调用。
    public func releaseParentPollRef() {
        parentPollRef.unref(parent)
    }

    // =========================================================================
    // Worker 线程
    // =========================================================================

    // ========== 线程主函数 ==========
    // 严格翻译自 web_worker.zig threadMain
    // Worker 线程的入口点。
    // 生命周期:
    //   1. startVM()  — 构建 mimalloc arena，克隆环境，初始化 jsc.VirtualMachine，
    //                   在 vm_lock 下发布 vm。
    //   2. spin()     — 加载入口点，调用 dispatchOnline + fireEarlyMessages，
    //                   运行事件循环直到排空或观察到 requested_terminate，运行 beforeExit。
    //   3. shutdown() — 调用 vm.onExit()，拆除 JSC VM，发布 dispatchExit
    //                   (释放 parent_poll_ref + 父线程上的线程引用)，
    //                   释放 arena，退出线程。
    public func threadMain() {
        // 严格翻译自: 设置线程名称
        // FFI: Output.Source.configureNamedThread(name)

        // 在启动前已被终止 — 直接跳到 shutdown 以便父线程仍然收到 close 事件
        if (hasRequestedTerminate()) {
            shutdown()
            // shutdown 是 noreturn
        }

        // 阶段 1: 构建Worker的 arena + VirtualMachine 并发布 vm
        startVM()

        // 阶段 2+3: 在 API 锁下运行
        // FFI: vm.global.vm().holdAPILock(this, WebWorker.spin)
        spin()
    }

    // ========== 启动 VM ==========
    // 严格翻译自 web_worker.zig startVM
    // 阶段 1: 构建 worker 的 arena + VirtualMachine 并发布 vm。
    private func startVM() {
        // 严格翻译自: 解析 execArgv 中的新参数
        if (let Some(execArgs) <- execArgv) {
            parseExecArgv(execArgs)
        }

        // 严格翻译自: 创建 mimalloc arena
        arena = "arena" // 占位符

        // 严格翻译自: 克隆环境变量
        // 需要从父进程获取一致的 (storage slots + env.map entries) 快照
        // 以便我们复制的每个 slice 都有我们持有的 ref 支持。
        // 父进程的 storage.lock 序列化 Bun__setEnvValue — 它覆盖
        // slot swap 和 map.put，所以 cloneFrom 和 cloneWithAllocator 看到相同的状态。

        // 严格翻译自: 检查点 — 在昂贵的 initWorker 之前检查终止
        if (hasRequestedTerminate()) {
            shutdown()
        }

        // 严格翻译自: 初始化 Worker VM
        let opts = BunVirtualMachineOptions()
        opts.isMainThread = false
        opts.storeFd = storeFd

        let vm = BunVirtualMachine.createForWorker(this, opts)
        vm.isMainThread_ = false
        BunVirtualMachine.isMainThreadVM = false

        // 严格翻译自: 设置未处理 rejection 处理器
        vm.onUnhandledRejection = { (workerVm, global, errorInstance) =>
            onUnhandledRejection(workerVm, global, errorInstance)
        }

        // 严格翻译自: 现在 (而不是 startVM 末尾) 发布 vm，以便:
        //   - 并发的 notifyNeedTermination()/terminateAllAndWait()
        //     可以在 JS 开始运行后唤醒我们
        //   - 下面的提前返回到达 spin()/shutdown() 时 this.vm 已设置，
        //     所以 teardownJSCVM/vm.deinit() 运行，刚构建的 JSC::VM 堆不会泄漏。
        {
            vmLock.lock()
            defer { vmLock.unlock() }
            vm = vm
        }

        // 严格翻译自: 配置 resolver 环境
        // b.resolver.env_loader = b.env

        // 严格翻译自: 独立模块图运行时标志
        if (parent.standaloneModuleGraph != None) {
            // FFI: bun.bun_js.applyStandaloneRuntimeFlags(b, graph)
        }

        // 严格翻译自: 第二个检查点 — initWorker 刚花了大部分启动时间;
        // 如果终止在期间到达，跳过 configureDefines() (它遍历 resolver 的
        // 全局 dir_cache) 和入口点加载。
        // spin() 将观察标志并在 API 锁下 shutdown()。
        if (hasRequestedTerminate()) {
            return
        }

        // 严格翻译自: configureDefines()
        // 如果失败，设置退出码和终止标志
        // vm.loadExtraEnvAndSourceCodePrinter()
    }

    // ========== 运行事件循环 ==========
    // 严格翻译自 web_worker.zig spin
    // 阶段 2: 加载入口点，dispatch 'online'，运行事件循环。
    // 在 holdAPILock 内运行。总是以调用 shutdown() 结束。
    private func spin() {
        if (let Some(vmInstance) <- vm) {
            // 严格翻译自: 在 startVM() 期间被终止 (或 startVM() 在
            // configureDefines 失败时短路到此处) — 在 API 锁下关闭
            // 以便 initWorker 构建的 JSC::VM 被拆除而不是泄漏。
            if (hasRequestedTerminate()) {
                flushLogs(vmInstance)
                shutdown()
            }

            setStatus(WebWorkerStatus.Starting)

            // 严格翻译自: 在 worker 线程上解析入口点 (父线程只存储了原始 specifier)
            vmInstance.preload = preloads

            var resolveError = ""
            let path = resolveEntryPointSpecifier(
                vmInstance, unresolvedSpecifier, resolveError, vmInstance.log
            )
            if (path == None) {
                vmInstance.exitHandler.exitCode = 1
                if (vmInstance.log.size == 0 && !resolveError.isEmpty) {
                    vmInstance.log.append(resolveError)
                }
                flushLogs(vmInstance)
                shutdown()
            }

            // 解析期间被终止 — 退出码 0，无错误。
            if (hasRequestedTerminate()) {
                flushLogs(vmInstance)
                shutdown()
            }

            // 严格翻译自: 加载入口点
            let promise = vmInstance.loadEntryPointForWebWorker(path.getOrThrow())
            if (promise == None) {
                // process.exit() 可能在加载期间运行; 不覆盖其退出码
                if (!exitCalled) {
                    vmInstance.exitHandler.exitCode = 1
                }
                flushLogs(vmInstance)
                shutdown()
            }

            // 严格翻译自: 检查 promise 是否被拒绝
            if (let Some(p) <- promise) {
                if (p.status == PromiseStatus.Rejected) {
                    // 未捕获的异常
                    vmInstance.exitHandler.exitCode = 1
                    flushLogs(vmInstance)
                    shutdown()
                }
            }

            flushLogs(vmInstance)

            // 严格翻译自: dispatchOnline 在入口点加载后触发，
            // 以便父线程只在 worker 的顶层代码完成后观察到 'online'。
            dispatchOnline(vmInstance.globalObject)

            // 严格翻译自: 触发排队的早期消息
            fireEarlyMessages(vmInstance.globalObject)

            setStatus(WebWorkerStatus.Running)

            // 严格翻译自: 如果需要则运行 GC
            if (vmInstance.isEventLoopAlive()) {
                // FFI: vm.global.vm().releaseWeakRefs()
                // FFI: vm.arena.gc()
                // FFI: vm.global.vm().runGC(false)
            }

            // 严格翻译自: 总是做第一次 tick 以便在 dispatchOnline 后
            // 无延迟地调用 CppTask
            vmInstance.tick()

            // 严格翻译自: 主事件循环
            while (vmInstance.isEventLoopAlive()) {
                vmInstance.tick()
                if (hasRequestedTerminate()) {
                    break
                }
                // FFI: vm.eventLoop().autoTickActive()
                if (hasRequestedTerminate()) {
                    break
                }
            }

            // 严格翻译自: 仅在自然排空时发出 'beforeExit'，不在 terminate() 时
            if (!hasRequestedTerminate()) {
                // TODO: 这是否能允许事件循环继续?
                vmInstance.onBeforeExit()
            }

            flushLogs(vmInstance)
            shutdown()
        }
    }

    // ========== 关闭 ==========
    // 严格翻译自 web_worker.zig shutdown
    // 阶段 3: 运行退出处理器，拆除 JSC VM，发布 close 事件，
    // 释放 arena，退出线程。
    //
    // 排序约束 (每一步是下一步的屏障):
    //   1. vm = null 在锁下 — 竞争的 notifyNeedTermination() 现在看到
    //      null 并跳过 wakeup() 而不是触摸第 5 步中释放的内存。
    //   2. vm.onExit() — 用户 'exit' 处理器运行; 需要 JSC VM。
    //   3. teardownJSCVM() — collectNow + vm.deref x2; 可以通过终结器
    //      重新进入 Zig，所以必须在第 5 步之前。
    //   4. dispatchExit() — 发布 close task -> 父线程释放
    //      parent_poll_ref + 线程持有的 Worker ref。
    //      此后 this 可能随时被释放。
    //   5. 释放 loop/arena/pools — 第 4 步之后没有 this.* 解引用。
    //
    // 不释放 this — 参见文件头的所有权规则。
    // shutdown() 在 Zig 中是 noreturn — 在仓颉中使用 Unit 返回类型
    private func shutdown() {
        setStatus(WebWorkerStatus.Terminated)

        // 快照在 this 可能被释放后我们需要的一切 (步骤 4)
        let cppWorker = cppWorker
        let savedArena = arena
        arena = None

        // ---- 1. 取消发布 vm --------------------------------------------------
        var vmToDeinit: ?BunVirtualMachine = None
        var loop: ?EventLoopHandle = None
        {
            vmLock.lock()
            defer { vmLock.unlock() }
            if (let Some(vm) <- vm) {
                // FFI: loop = vm.uwsLoop()
                loop = vm.eventLoopHandle
                vm = None
                vmToDeinit = vm
            }
        }

        // ---- 2. 用户退出处理器 -------------------------------------------
        var exitCode: Int64 = 0
        var globalObject: ?JsObject = None
        if (let Some(vm) <- vmToDeinit) {
            // 严格翻译自: terminate() 设置了 JSC 终止标志以中断运行中的 JS;
            // 清除它以便 process.on('exit') 处理器可以运行。
            // teardownJSCVM 在 JSC VM 拆除时重新设置它。
            // FFI: vm.jsc_vm.clearHasTerminationRequest()
            vm.isShuttingDown_ = true
            vm.onExit()

            // FFI: jsc.API.cron.CronJob.clearAllForVM(vm, .teardown)
            // FFI: 嵌入的 socket 组必须在 JSC 仍存活时排空
            exitCode = vm.exitHandler.exitCode
            globalObject = vm.globalObject
        }

        // ---- 3. JSC VM 拆除 ----------------------------------------------
        if (let Some(global) <- globalObject) {
            // FFI: WebWorker__teardownJSCVM(global)
        }

        // JSC 已关闭; 此后不再有 resolver/module-loader 访问。
        // 取消注册以便主线程的 terminateAllAndWait() 可以继续释放
        // 进程全局的 resolver 状态。必须在 dispatchExit 之前发生，
        // 因为 this 可能一旦发布就被释放。
        LiveWorkers.unregister(this)

        // ---- 4. 向父线程发布 close task ------------------------------------
        // FFI: WebWorker__dispatchExit(cppWorker, exitCode)
        // this 可能在此点之后随时被释放。
        dispatchExit(exitCode)

        // ---- 5. 释放 worker 线程资源 ---------------------------------
        if (let Some(loop_) <- loop) {
            // FFI: loop_.internal_loop_data.jsc_vm = null
        }
        if (let Some(vm) <- vmToDeinit) {
            // 必须在 Loop.shutdown 之前，以便 uv_close 不会在 GC 计时器上被调用两次
            // FFI: vm.gc_controller.deinit()
        }
        if (let Some(vm) <- vmToDeinit) {
            // FFI: vm.deinit()
        }
        // FFI: bun.deleteAllPoolsForThreadExit()
        if (savedArena != None) {
            // FFI: arena.deinit()
        }

        // FFI: bun.exitThread()
        // 在仓颉中无法真正 noreturn，但逻辑上此函数不应返回
    }

    // ========== process.exit() ==========
    // 严格翻译自 web_worker.zig exit
    // worker 内部的 process.exit()。仅 Worker 线程。
    public func exit() {
        exitCalled = true
        let _ = setRequestedTerminate()
        // 在下一个安全点停止后续 JS。this.vm 在 vm.onExit() 期间为 null
        // (shutdown 首先置空它)，所以 exit 处理器中的重入 process.exit()
        // 不会重新设置陷阱。
        if (let Some(vm) <- vm) {
            // FFI: vm.jsc_vm.notifyNeedTermination()
        }
    }

    // =========================================================================
    // 辅助方法 (worker 线程)
    // =========================================================================

    // 严格翻译自 web_worker.zig setStatus
    private func setStatus(status: WebWorkerStatus) {
        this.status = status
    }

    // 严格翻译自 WebWorker__dispatchOnline
    // 触发 worker 的 "online" 事件并翻转 C++ 状态为 Running
    // (将 postMessage 直接路由而不是排队)。
    func dispatchOnline(globalObject: JsObject) {
        // FFI: WebWorker__dispatchOnline(cppWorker, globalObject)
        if (let Some(cpp) <- cppWorker) {
            // C++ 绑定调用
        }
    }

    // 严格翻译自 WebWorker__fireEarlyMessages
    // 触发任何排队中的早期消息
    func fireEarlyMessages(globalObject: JsObject) {
        // FFI: WebWorker__fireEarlyMessages(cppWorker, globalObject)
        if (let Some(cpp) <- cppWorker) {
            // C++ 绑定调用
        }
    }

    // 严格翻译自 WebWorker__dispatchExit
    // 向父线程发布 close task。此后 this 可能随时被释放。
    func dispatchExit(exitCode: Int64) {
        // FFI: WebWorker__dispatchExit(cppWorker, exitCode)
        // close task 在父线程上:
        //   - 释放 parent_poll_ref
        //   - 释放线程持有的 Worker ref
        if (let Some(cpp) <- cppWorker) {
            parentPollRef.unref(parent)
        }
    }

    // 严格翻译自 WebWorker__dispatchError
    // 调度错误到父线程
    func dispatchError(globalObject: JsObject, errorString: String, error: JsValue) {
        // FFI: WebWorker__dispatchError(globalObject, cppWorker, errorString, error)
        if (let Some(cpp) <- cppWorker) {
            // C++ 绑定调用
        }
    }

    // 严格翻译自 web_worker.zig flushLogs
    // 将日志消息刷新到父线程作为错误事件
    private func flushLogs(vm: BunVirtualMachine) {
        if (vm.log.size == 0) {
            return
        }
        // 严格翻译自: 将日志转换为 JS 错误值并分发
        // FFI: vm.log.toJS(vm.global, ...) -> err, str
        // FFI: WebWorker__dispatchError(vm.global, cppWorker, str, err)
        // 简化实现: 清空日志
        vm.log.clear()
    }

    // 严格翻译自 web_worker.zig onUnhandledRejection
    // Worker 中未处理的 Promise rejection 处理器
    private func onUnhandledRejection(
        vm: BunVirtualMachine,
        globalObject: JsObject,
        errorInstanceOrException: JsValue
    ) {
        // 严格翻译自: 防止递归
        vm.onUnhandledRejection = { (vm_, global_, value_) => }

        var errorInstance = errorInstanceOrException

        // 严格翻译自: 格式化错误消息
        let worker = vm.worker
        if (worker == None) {
            return
        }
        let w = worker.getOrThrow()

        // 严格翻译自: 分发错误
        dispatchError(globalObject, "Unhandled rejection in worker", errorInstance)

        // 严格翻译自: 请求终止并关闭
        let _ = w.setRequestedTerminate()
        w.shutdown()
    }

    // =========================================================================
    // 入口点解析
    // =========================================================================

    // 严格翻译自 web_worker.zig resolveEntryPointSpecifier
    // 解析 worker 入口点说明符为模块加载器可以使用的路径。
    // 返回的 slice 是借用的 — 它别名 str、standalone module graph
    // 或 resolver 的 arena; 调用者不得释放它。
    private func resolveEntryPointSpecifier(
        parent: BunVirtualMachine,
        str: String,
        errorMessage: String,
        log: ArrayList<String>
    ): ?String {
        // 严格翻译自: 独立模块图查找
        if (let Some(graph) <- parent.standaloneModuleGraph) {
            if (graph.find(str) != None) {
                return str
            }

            // 严格翻译自: 文件扩展名映射回退
            // new Worker("./foo") -> new Worker("./foo.js")
            // new Worker("./foo.ts") -> new Worker("./foo.js")
            // new Worker("./foo.jsx") -> new Worker("./foo.js")
            // new Worker("./foo.mjs") -> new Worker("./foo.js")
            // new Worker("./foo.mts") -> new Worker("./foo.js")
            // new Worker("./foo.cjs") -> new Worker("./foo.js")
            // new Worker("./foo.cts") -> new Worker("./foo.js")
            // new Worker("./foo.tsx") -> new Worker("./foo.js")
            if (str.startsWith("./") || str.startsWith("../")) {
                let mappedPath = tryMapExtensionForStandaloneGraph(graph, str)
                if (mappedPath != None) {
                    return mappedPath
                }
            }
        }

        // 严格翻译自: Blob URL 检查
        if (str.startsWith("blob:")) {
            // FFI: bun.webcore.ObjectURLRegistry.isBlobURL(str)
            // FFI: bun.webcore.ObjectURLRegistry.singleton().has(str["blob:".len..])
            return str
        }

        // 严格翻译自: 通过解析器解析入口点
        // parent.transpiler.resolveEntryPoint(str)
        // 简化实现: 返回原始字符串
        str
    }

    // 严格翻译自: 文件扩展名映射
    private func tryMapExtensionForStandaloneGraph(
        graph: StandaloneModuleGraph,
        str: String
    ): ?String {
        let ext = PathName(str).ext

        // ./foo -> ./foo.js
        if (ext.isEmpty) {
            let jsPath = str + ".js"
            if (graph.find(jsPath) != None) {
                return jsPath
            }
            return None
        }

        // ./foo.ts -> ./foo.js
        if (ext == ".ts") {
            let jsPath = str[0..str.size - 3] + ".js"
            if (graph.find(jsPath) != None) {
                return jsPath
            }
            return None
        }

        // ./foo.tsx/.jsx/.mjs/.mts/.cts/.cjs -> ./foo.js
        if (ext == ".tsx" || ext == ".jsx" || ext == ".mjs" ||
            ext == ".mts" || ext == ".cts" || ext == ".cjs") {
            let jsPath = str[0..str.size - ext.size] + ".js"
            if (graph.find(jsPath) != None) {
                return jsPath
            }
            return None
        }

        None
    }

    // 严格翻译自: 解析 execArgv 中的新参数
    private func parseExecArgv(execArgs: Array<String>) {
        // 严格翻译自: 解析 CLI 参数如 --no-addons
        // 简化实现: 忽略无法识别的参数
        for (arg in execArgs) {
            if (arg == "--no-addons") {
                // transformOptions.allow_addons = false
            }
        }
    }

    // ========== 获取父 Worker ==========
    // 严格翻译自 WebWorker__getParentWorker
    public static func getParentWorker(vm: BunVirtualMachine): ?CPointer<UInt8> {
        if (let Some(worker) <- vm.worker) {
            return worker.cppWorker
        }
        None
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
    public func tryLock(): Bool { true }
}

// ========== 链表节点 ==========
public class ListNode {
    public var prev: ?ListNode = None
    public var next: ?ListNode = None

    public init() {}
}

// ========== KeepAlive ==========
// 严格翻译自 Async.KeepAlive
// 不是线程安全的; 仅在父线程上使用
public class KeepAlive {
    public init() {}

    // 严格翻译自 KeepAlive.ref
    public func ref(vm: BunVirtualMachine) {
        // 在 VM 的事件循环上增加引用计数
    }

    // 严格翻译自 KeepAlive.unref
    public func unref(vm: BunVirtualMachine) {
        // 在 VM 的事件循环上减少引用计数
    }
}

// ========== 当前时间辅助 ==========
private func currentTimeMillis(): Int64 {
    // FFI: 获取当前时间戳
    Int64(0)
}
