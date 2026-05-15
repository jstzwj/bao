// 严格翻译自: src/runtime/api/bun/subprocess.zig
package bao_runtime

import bao_jsc.*
import bao_core.*
import bao_sys.*
import bao_io.*

// ============================================================================
// Subprocess - Bun.spawn / Bun.spawnSync 返回的子进程对象
// 对应 Bun: src/runtime/api/bun/subprocess.zig
// ============================================================================

/// 子进程对象
public class Subprocess {
    var refCount: RefCount
    var process: Process
    var stdin: Writable
    var stdout: Readable
    var stderr: Readable
    var stdioPipes: ArrayListUnmanaged(ExtraPipe) = ArrayListUnmanaged()
    var pidRusage: Rusage = null

    /// 附加到此子进程的终端
    var terminal: Terminal = null

    var globalThis: JsGlobalObject
    var observableGetters: EnumSet<StdioKind> = EnumSet()
    var closed: EnumSet<StdioKind> = EnumSet()
    var thisValue: JsRef = JsRef.empty()

    /// IPC 数据，null 表示未初始化
    var ipcData: IPCSendQueue = null
    var flags: Flags = Flags{}

    var weakFileSinkStdinPtr: FileSink = null
    var abortSignal: AbortSignal = null

    var eventLoopTimerRefd: Bool = false
    var eventLoopTimer: EventLoopTimer = EventLoopTimer{
        tag = .SubprocessTimeout,
        next = .epoch,
    }
    var killSignal: SignalCode

    var stdoutMaxbuf: MaxBuf = null
    var stderrMaxbuf: MaxBuf = null
    var exitedDueToMaxbuf: MaxBufKind = null

    // ========================================================================
    // Flags - 子进程标志位
    // ========================================================================

    public class Flags {
        var isSync: Bool = false
        var killed: Bool = false
        var hasStdinDestructorCalled: Bool = false
        var finalized: Bool = false
        var derefOnStdinDestroyed: Bool = false
        var isStdinAReadableStream: Bool = false
        var ownsTerminal: Bool = false
    }

    // ========================================================================
    // StdioKind - 标准流类型枚举
    // ========================================================================

    public enum StdioKind {
        case stdin
        case stdout
        case stderr

        public func toFd(): FD {
            return switch (this) {
                case .stdin => FD.stdin()
                case .stdout => FD.stdout()
                case .stderr => FD.stderr()
            }
        }

        public func toNum(): Int32 {
            return switch (this) {
                case .stdin => 0
                case .stdout => 1
                case .stderr => 2
            }
        }
    }

    // ========================================================================
    // Source - stdin 数据源
    // ========================================================================

    public enum Source {
        case blob(BlobAny)
        case array_buffer(ArrayBufferStrong)
        case detached

        public func memoryCost(): Int64 {
            return switch (this) {
                case .blob => this.blob.memoryCost()
                case .array_buffer => 0
                case .detached => 0
            }
        }

        public func slice(): Array<UInt8> {
            return switch (this) {
                case .blob => this.blob.slice()
                case .array_buffer => this.array_buffer.slice()
                else => panic("Invalid source")
            }
        }

        public func detach() {
            switch (this) {
                case .blob => this.blob.detach()
                case .array_buffer => this.array_buffer.deinit()
                else => {}
            }
            this = .detached
        }
    }

    // ========================================================================
    // 核心方法
    // ========================================================================

    /// 内存占用
    public func memoryCost(): Int64 {
        return sizeof(Subprocess) +
            this.process.memoryCost() +
            this.stdin.memoryCost() +
            this.stdout.memoryCost() +
            this.stderr.memoryCost()
    }

    /// 是否已退出
    public func hasExited(): Bool {
        return this.process.hasExited()
    }

    /// 计算是否有待处理的活动
    public func computeHasPendingActivity(): Bool {
        // IPC 数据
        if (this.ipcData != null && !this.ipcData.close_event_sent) {
            return true
        }

        if (this.hasPendingActivityStdio()) {
            return true
        }

        if (!this.process.hasExited()) {
            return true
        }

        return false
    }

    /// 更新待处理活动状态
    public func updateHasPendingActivity() {
        if (this.flags.isSync) { return }

        let hasPending = this.computeHasPendingActivity()

        if (hasPending) {
            this.thisValue.upgrade(this.globalThis)
        } else {
            this.thisValue.downgrade()
        }
    }

    /// Stdio 是否有待处理活动
    public func hasPendingActivityStdio(): Bool {
        if (this.stdin.hasPendingActivity()) { return true }

        for (kind in [StdioKind.stdout, StdioKind.stderr]) {
            if (this[kind].hasPendingActivity()) { return true }
        }

        return false
    }

    /// 关闭 IO
    public func onCloseIO(kind: StdioKind) {
        switch (kind) {
            case .stdin => {
                switch (this.stdin) {
                    case .pipe(let pipe) => {
                        pipe.signal.clear()
                        pipe.deref()
                        this.stdin = Writable.ignore()
                    }
                    case .buffer => {
                        this.stdin.buffer.source.detach()
                        this.stdin.buffer.deref()
                        this.stdin = Writable.ignore()
                    }
                    else => {}
                }
            }
            case .stdout, .stderr => {
                let out = this[kind]
                switch (out) {
                    case .pipe(let pipe) => {
                        if (pipe.state == .done) {
                            out = Readable.buffer(CowString.initOwned(pipe.state.done, default_allocator))
                            pipe.state = PipeReaderState.done([])
                        } else {
                            out = Readable.ignore()
                        }
                        pipe.deref()
                    }
                    else => {}
                }
            }
        }

        this.updateHasPendingActivity()
    }

    /// JS ref
    public func jsRef() {
        this.process.enableKeepingEventLoopAlive()

        if (!this.hasCalledGetter(.stdin)) { this.stdin.ref() }
        if (!this.hasCalledGetter(.stdout)) { this.stdout.ref() }
        if (!this.hasCalledGetter(.stderr)) { this.stderr.ref() }

        this.updateHasPendingActivity()
    }

    /// JS unref
    public func jsUnref() {
        this.process.disableKeepingEventLoopAlive()

        if (!this.hasCalledGetter(.stdin)) { this.stdin.unref() }
        if (!this.hasCalledGetter(.stdout)) { this.stdout.unref() }
        if (!this.hasCalledGetter(.stderr)) { this.stderr.unref() }

        this.updateHasPendingActivity()
    }

    /// 构造函数 (禁止直接构造)
    public static func constructor(globalObject: JsGlobalObject, callframe: JsCallFrame): Subprocess {
        return globalObject.throw("Cannot construct Subprocess")
    }

    // ========================================================================
    // Getter 方法
    // ========================================================================

    /// 获取 stderr
    public func getStderr(globalThis: JsGlobalObject): JsValue {
        if (this.terminal != null) { return JsValue.null() }
        this.observableGetters.insert(.stderr)
        return this.stderr.toJS(globalThis, this.hasExited())
    }

    /// 获取 stdin
    public func getStdin(globalThis: JsGlobalObject): JsValue {
        if (this.terminal != null) { return JsValue.null() }
        this.observableGetters.insert(.stdin)
        return this.stdin.toJS(globalThis, this)
    }

    /// 获取 stdout
    public func getStdout(globalThis: JsGlobalObject): JsValue {
        if (this.terminal != null) { return JsValue.null() }
        this.observableGetters.insert(.stdout)
        return this.stdout.toJS(globalThis, this.hasExited())
    }

    /// 获取 terminal
    public func getTerminal(globalThis: JsGlobalObject): JsValue {
        if (let terminal = this.terminal) {
            return terminal.toJS(globalThis)
        }
        return JsValue.jsUndefined()
    }

    /// 获取 PID
    public func getPid(globalThis: JsGlobalObject): JsValue {
        return JsValue.jsNumber(this.pid())
    }

    /// 获取 PID 值
    public func pid(): Int32 {
        return Int32(this.process.pid)
    }

    /// 获取 killed 状态
    public func getKilled(globalThis: JsGlobalObject): JsValue {
        return JsValue.jsBoolean(this.hasKilled())
    }

    /// 是否已被杀死
    public func hasKilled(): Bool {
        return this.process.hasKilled()
    }

    /// 获取 stdio 数组
    public func getStdio(global: JsGlobalObject): JsValue {
        let array = try JsValue.createEmptyArray(global, 0)
        try array.push(global, JsValue.null())
        try array.push(global, JsValue.null())
        try array.push(global, JsValue.null())

        for (item in this.stdioPipes.items) {
            switch (item) {
                case .owned_fd(let fd) => try array.push(global, JsValue.jsNumber(fd.cast()))
                case .unowned_fd(let fd) => try array.push(global, JsValue.jsNumber(fd.cast()))
                case .unavailable => try array.push(global, JsValue.null())
            }
        }
        return array
    }

    /// 获取 resource usage
    public func resourceUsage(globalObject: JsGlobalObject, callframe: JsCallFrame): JsValue {
        return this.createResourceUsageObject(globalObject)
    }

    /// 创建 resource usage JS 对象
    public func createResourceUsageObject(globalObject: JsGlobalObject): JsValue {
        return ResourceUsage.create(
            if (this.pidRusage != null) {
                this.pidRusage
            } else {
                return JsValue.jsUndefined()
            },
            globalObject,
        )
    }

    /// 获取 exited Promise
    public func getExited(thisValue: JsValue, globalThis: JsGlobalObject): JsValue {
        if (let promise = JSSubprocess.exitedPromiseGetCached(thisValue)) {
            return promise
        }

        switch (this.process.status) {
            case .exited(let exit) => {
                return JsPromise.resolvedPromiseValue(globalThis, JsValue.jsNumber(exit.code))
            }
            case .signaled(let signal) => {
                return JsPromise.resolvedPromiseValue(globalThis, JsValue.jsNumber(signal.toExitCode() ?? 254))
            }
            case .err(let err) => {
                let jsErr = err.toJS(globalThis) catch { return JsValue.zero }
                return JsPromise.dangerouslyCreateRejectedPromiseValueWithoutNotifyingVM(globalThis, jsErr)
            }
            else => {
                let promise = JsPromise.create(globalThis).toJS()
                JSSubprocess.exitedPromiseSetCached(thisValue, globalThis, promise)
                return promise
            }
        }
    }

    /// 获取退出码
    public func getExitCode(globalThis: JsGlobalObject): JsValue {
        if (this.process.status == .exited) {
            return JsValue.jsNumber(this.process.status.exited.code)
        }
        return JsValue.jsNull()
    }

    /// 获取信号码
    public func getSignalCode(global: JsGlobalObject): JsValue {
        if (let signal = this.process.signalCode()) {
            if (let name = signal.name()) {
                return ZigString.init(name).toJS(global)
            } else {
                return JsValue.jsNumber(Int32(signal.rawValue))
            }
        }
        return JsValue.jsNull()
    }

    // ========================================================================
    // 操作方法
    // ========================================================================

    /// 杀死子进程
    public func kill(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        this.thisValue.update(globalThis, callframe.this())

        let arguments = callframe.argumentsOld(1)
        let sig = try SignalCode.fromJS(arguments.ptr[0], globalThis)

        if (globalThis.hasException()) { return JsValue.zero }

        switch (this.tryKill(sig)) {
            case .result => {}
            case .err(let err) => {
                return globalThis.throwValue(try err.toJS(globalThis))
            }
        }

        return JsValue.jsUndefined()
    }

    /// 尝试杀死子进程
    public func tryKill(sig: SignalCode): Maybe<Unit> {
        if (this.hasExited()) { return Maybe<Unit>.success }
        return this.process.kill(Int32(sig.rawValue))
    }

    /// doRef
    public func doRef(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        this.jsRef()
        return JsValue.jsUndefined()
    }

    /// doUnref
    public func doUnref(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        this.jsUnref()
        return JsValue.jsUndefined()
    }

    /// asyncDispose (用于 using 语法)
    public func asyncDispose(global: JsGlobalObject, callframe: JsCallFrame): JsValue {
        if (this.process.hasExited()) {
            return JsValue.jsUndefined()
        }

        let thisJsvalue = callframe.this()
        defer thisJsvalue.ensureStillAlive()

        this.stdin.unref()
        this.stdout.unref()
        this.stderr.unref()

        switch (this.tryKill(this.killSignal)) {
            case .result => {}
            case .err(let err) => {
                return global.throwValue(try err.toJS(global))
            }
        }

        return this.getExited(thisJsvalue, global)
    }

    /// IPC 发送
    public func doSend(global: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        return IPC.doSend(
            if (this.ipcData != null) this.ipcData else null,
            global,
            callFrame,
            if (this.hasExited()) .subprocess_exited else .subprocess,
        )
    }

    /// 断开 IPC
    public func disconnectIPC(nextTick: Bool) {
        let ipcData = this.ipc() ?? return
        ipcData.closeSocketNextTick(nextTick)
    }

    /// disconnect 方法
    public func disconnect(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        this.disconnectIPC(true)
        return JsValue.jsUndefined()
    }

    /// 获取 connected 状态
    public func getConnected(globalThis: JsGlobalObject): JsValue {
        let ipcData = this.ipc()
        return JsValue.jsBoolean(ipcData != null && ipcData.isConnected())
    }

    /// 获取 IPC 数据
    public func ipc(): IPCSendQueue {
        return this.ipcData ?? return null
    }

    // ========================================================================
    // 进程退出回调
    // ========================================================================

    /// 进程退出时的回调
    public func onProcessExit(process: Process, status: Status, rusage: Rusage) {
        let thisJsvalue = this.thisValue.tryGet() ?? JsValue.zero
        let globalThis = this.globalThis
        let jscVm = globalThis.bunVM()
        thisJsvalue.ensureStillAlive()
        this.pidRusage = rusage
        let isSync = this.flags.isSync
        this.clearAbortSignal()

        defer this.deref()
        defer this.disconnectIPC(true)

        if (this.eventLoopTimer.state == .ACTIVE) {
            jscVm.timer.remove(this.eventLoopTimer)
        }
        this.setEventLoopTimerRefd(false)

        jscVm.onSubprocessExit(process)

        // 关闭 stdin 数据源
        if (this.stdin == .buffer) {
            this.stdin.buffer.close()
        }

        if (isSync) {
            if (this.stdout == .pipe) { this.stdout.close() }
            if (this.stderr == .pipe) { this.stderr.close() }
        } else {
            if (this.stdout == .pipe && !this.stdout.pipe.reader.isDone()) {
                this.stdout.pipe.reader.read()
            }
            if (this.stderr == .pipe && !this.stderr.pipe.reader.isDone()) {
                this.stderr.pipe.reader.read()
            }
        }

        if (!isSync && thisJsvalue != JsValue.zero) {
            // 处理 exited Promise
            if (let promise = consumeExitedPromise(thisJsvalue, globalThis)) {
                switch (status) {
                    case .exited(let exited) => promise.asAnyPromise().resolve(globalThis, JsValue.jsNumber(exited.code)) catch {}
                    case .err(let err) => {
                        promise.asAnyPromise().rejectWithAsyncStack(globalThis, err.toJS(globalThis) catch { return }) catch {}
                    }
                    case .signaled => {
                        promise.asAnyPromise().resolve(globalThis, JsValue.jsNumber(128 + Int32(status.signaled.rawValue))) catch {}
                    }
                    else => {}
                }
            }

            // 处理 onExit 回调
            if (let callback = consumeOnExitCallback(thisJsvalue, globalThis)) {
                let waitpidValue = if (status == .err) {
                    status.err.toJS(globalThis) catch { return }
                } else {
                    JsValue.jsUndefined()
                }

                let thisValue = if (thisJsvalue.isEmptyOrUndefinedOrNull()) JsValue.jsUndefined() else thisJsvalue
                thisValue.ensureStillAlive()

                let args = [thisValue, this.getExitCode(globalThis), this.getSignalCode(globalThis), waitpidValue]
                globalThis.bunVM().eventLoop().runCallback(callback, globalThis, thisValue, args)
            }
        }
    }

    // ========================================================================
    // 生命周期方法
    // ========================================================================

    /// 设置事件循环定时器引用
    public func setEventLoopTimerRefd(refd: Bool) {
        if (this.eventLoopTimerRefd == refd) { return }
        this.eventLoopTimerRefd = refd
        if (refd) {
            this.globalThis.bunVM().timer.incrementTimerRef(1)
        } else {
            this.globalThis.bunVM().timer.incrementTimerRef(-1)
        }
    }

    /// 超时回调
    public func timeoutCallback() {
        this.setEventLoopTimerRefd(false)
        if (this.eventLoopTimer.state == .CANCELLED) { return }
        if (this.hasExited()) {
            this.eventLoopTimer.state = .CANCELLED
            return
        }
        this.eventLoopTimer.state = .FIRED
        _ = this.tryKill(this.killSignal)
    }

    /// maxbuf 回调
    public func onMaxBuffer(kind: MaxBufKind) {
        this.exitedDueToMaxbuf = kind
        _ = this.tryKill(this.killSignal)
    }

    /// stdin 销毁回调
    public func onStdinDestroyed() {
        let mustDeref = this.flags.derefOnStdinDestroyed
        this.flags.derefOnStdinDestroyed = false
        defer if (mustDeref) { this.deref() }

        this.flags.hasStdinDestructorCalled = true
        this.weakFileSinkStdinPtr = null

        if (!this.flags.finalized) {
            this.updateHasPendingActivity()
        }
    }

    /// IPC 消息处理
    public func handleIPCMessage(message: IPCDecodedIPCMessage, handle: JsValue) {
        switch (message) {
            case .version(let v) => {
                IPC.log("Child IPC version is \{v}")
            }
            case .data(let data) => {
                IPC.log("Received IPC message from child")
                let thisJsvalue = this.thisValue.tryGet() ?? JsValue.zero
                defer thisJsvalue.ensureStillAlive()
                if (thisJsvalue != JsValue.zero) {
                    if (let cb = JSSubprocess.ipcCallbackGetCached(thisJsvalue)) {
                        let globalThis = this.globalThis
                        globalThis.bunVM().eventLoop().runCallback(
                            cb,
                            globalThis,
                            thisJsvalue,
                            [data, thisJsvalue, handle],
                        )
                    }
                }
            }
            case .internal(let data) => {
                IPC.log("Received IPC internal message from child")
                NodeClusterBinding.handleInternalMessagePrimary(this.globalThis, this, data) catch {}
            }
        }
    }

    /// IPC 关闭处理
    public func handleIPCClose() {
        let thisJsvalue = this.thisValue.tryGet() ?? JsValue.zero
        defer thisJsvalue.ensureStillAlive()
        let globalThis = this.globalThis
        this.updateHasPendingActivity()

        if (thisJsvalue != JsValue.zero) {
            JSSubprocess.ipcCallbackSetCached(thisJsvalue, globalThis, JsValue.zero)

            if (let callback = consumeOnDisconnectCallback(thisJsvalue, globalThis)) {
                globalThis.bunVM().eventLoop().runCallback(callback, globalThis, thisJsvalue, [JsValue.jsBoolean(true)])
            }
        }
    }

    /// 终结流
    public func finalizeStreams() {
        this.closeProcess()
        this.closeIO(.stdin)
        this.closeIO(.stdout)
        this.closeIO(.stderr)

        for (item in this.stdioPipes.items) {
            switch (item) {
                case .owned_fd(let fd) => fd.close()
                case .unowned_fd, .unavailable => {}
            }
        }
        this.stdioPipes.clearAndFree(default_allocator)
    }

    /// 关闭 IO
    func closeIO(io: StdioKind) {
        if (this.closed.contains(io)) { return }
        this.closed.insert(io)

        if (!this.hasCalledGetter(io)) {
            this[io].finalize()
        } else {
            this[io].close()
        }
    }

    /// 关闭进程资源
    func closeProcess() {
        if (!Environment.isLinux) { return }
        this.process.close()
    }

    /// 是否已调用 getter
    func hasCalledGetter(getter: StdioKind): Bool {
        return this.observableGetters.contains(getter)
    }

    /// 终结化 (GC finalizer)
    public func finalize() {
        this.thisValue.finalize()
        this.clearAbortSignal()

        assert(!this.computeHasPendingActivity() || VirtualMachine.get().isShuttingDown())
        this.finalizeStreams()

        this.process.detach()
        this.process.deref()

        if (this.eventLoopTimer.state == .ACTIVE) {
            this.globalThis.bunVM().timer.remove(this.eventLoopTimer)
        }
        this.setEventLoopTimerRefd(false)

        MaxBuf.removeFromSubprocess(this.stdoutMaxbuf)
        MaxBuf.removeFromSubprocess(this.stderrMaxbuf)

        if (this.ipcData != null) {
            this.ipcData.deinit()
            this.ipcData = null
        }

        this.flags.finalized = true
        this.deref()
    }

    /// 清除 abort signal
    func clearAbortSignal() {
        if (let signal = this.abortSignal) {
            this.abortSignal = null
            signal.pendingActivityUnref()
            signal.cleanNativeBindings(this)
            signal.unref()
        }
    }

    // ========================================================================
    // 静态 spawn 方法
    // ========================================================================

    /// Bun.spawn - 异步创建子进程
    public static func spawn(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        return JsBunSpawnBindings.spawn(globalThis, callframe)
    }

    /// Bun.spawnSync - 同步创建子进程
    public static func spawnSync(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        return JsBunSpawnBindings.spawnSync(globalThis, callframe)
    }

    // ========================================================================
    // 消费缓存回调
    // ========================================================================

    static func consumeExitedPromise(thisJsvalue: JsValue, globalThis: JsGlobalObject): JsValue {
        if (let promise = JSSubprocess.exitedPromiseGetCached(thisJsvalue)) {
            JSSubprocess.exitedPromiseSetCached(thisJsvalue, globalThis, JsValue.zero)
            return promise
        }
        return null
    }

    static func consumeOnExitCallback(thisJsvalue: JsValue, globalThis: JsGlobalObject): JsValue {
        if (let callback = JSSubprocess.onExitCallbackGetCached(thisJsvalue)) {
            JSSubprocess.onExitCallbackSetCached(thisJsvalue, globalThis, JsValue.zero)
            return callback
        }
        return null
    }

    static func consumeOnDisconnectCallback(thisJsvalue: JsValue, globalThis: JsGlobalObject): JsValue {
        if (let callback = JSSubprocess.onDisconnectCallbackGetCached(thisJsvalue)) {
            JSSubprocess.onDisconnectCallbackSetCached(thisJsvalue, globalThis, JsValue.zero)
            return callback
        }
        return null
    }
}

// ============================================================================
// 类型别名
// ========================================================================

public typealias StdioResult = ExtraPipe   // POSIX 上为 ?FD
public typealias MaxBufKind = MaxBuf.Kind
