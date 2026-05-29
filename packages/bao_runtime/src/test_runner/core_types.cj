// bun_test.cj - 测试框架主入口 (types only)
package bao_runtime.test_runner

import bao_collections.ArrayList
import bao_core.{Allocator, defaultAllocator}
import bao_event_loop.Timespec
import bao_jsc.{CallFrame, ExceptionList, JSGlobalObject, JsObject, JsValue, JSPromiseStatus, JsCallback}
import bao_core.Output

// ========== ScopeMode ==========
public enum ScopeMode {
    | normal | skip | todo | failing | filteredOut

    public operator func ==(other: ScopeMode): Bool {
        match (this) {
            case normal => match (other) { case normal => true; case _ => false }
            case skip => match (other) { case skip => true; case _ => false }
            case todo => match (other) { case todo => true; case _ => false }
            case failing => match (other) { case failing => true; case _ => false }
            case filteredOut => match (other) { case filteredOut => true; case _ => false }
        }
    }

    public operator func !=(other: ScopeMode): Bool {
        !(this == other)
    }

    public func toString(): String {
        match (this) {
            case normal => "normal"
            case skip => "skip"
            case todo => "todo"
            case failing => "failing"
            case filteredOut => "filteredOut"
        }
    }
}

// ========== OnlyMode ==========
public enum OnlyMode {
    | no | contains | yes

    public operator func ==(other: OnlyMode): Bool {
        match (this) {
            case no => match (other) { case no => true; case _ => false }
            case contains => match (other) { case contains => true; case _ => false }
            case yes => match (other) { case yes => true; case _ => false }
        }
    }

    public operator func !=(other: OnlyMode): Bool {
        !(this == other)
    }
}

// ========== ConcurrentMode ==========
public enum ConcurrentMode {
    | inherit | no | yes

    public operator func ==(other: ConcurrentMode): Bool {
        match (this) {
            case inherit => match (other) { case inherit => true; case _ => false }
            case no => match (other) { case no => true; case _ => false }
            case yes => match (other) { case yes => true; case _ => false }
        }
    }

    public operator func !=(other: ConcurrentMode): Bool {
        !(this == other)
    }
}

// ========== TestPhase ==========
public enum TestPhase {
    | collection | execution | done

    public operator func ==(other: TestPhase): Bool {
        match (this) {
            case collection => match (other) { case collection => true; case _ => false }
            case execution => match (other) { case execution => true; case _ => false }
            case done => match (other) { case done => true; case _ => false }
        }
    }

    public operator func !=(other: TestPhase): Bool {
        !(this == other)
    }
}

// ========== AddedInPhase ==========
public enum AddedInPhase {
    | preload | collection | execution

    public operator func ==(other: AddedInPhase): Bool {
        match (this) {
            case preload => match (other) { case preload => true; case _ => false }
            case collection => match (other) { case collection => true; case _ => false }
            case execution => match (other) { case execution => true; case _ => false }
        }
    }

    public operator func !=(other: AddedInPhase): Bool {
        !(this == other)
    }
}

// ========== BaseScope ==========
public class BaseScope {
    public var parent: ?DescribeScope = None
    public var name: ?String = None
    public var concurrent: Bool = false
    public var mode: ScopeMode = ScopeMode.normal
    public var only: OnlyMode = OnlyMode.no
    public var hasCallback: Bool = false
    public var testIdForDebugger: Int32 = 0
    public var lineNo: UInt32 = 0
    public init() {}
    public init(cfg: BaseScopeCfg, gpa: Allocator, name: ?String, parent: ?DescribeScope, hasCallback: Bool) {
        this.parent = parent
        this.name = name
        this.hasCallback = hasCallback
    }
    public func propagate(hasCallback: Bool) {
        this.hasCallback = hasCallback
        if (let Some(p) <- parent) {
            if (this.only != OnlyMode.no) { p.markContainsOnly() }
            if (this.hasCallback) { p.markHasCallback() }
        }
    }
    public func deinit(gpa: Allocator) { this.name = None }
}

// ========== BaseScopeCfg ==========
public class BaseScopeCfg {
    public var selfConcurrent: ConcurrentMode = ConcurrentMode.inherit
    public var selfMode: ScopeMode = ScopeMode.normal
    public var selfOnly: Bool = false
    public var testIdForDebugger: Int32 = 0
    public var lineNo: UInt32 = 0
    public init() {}
}

// ========== DescribeScope ==========
public class DescribeScope {
    public var base: BaseScope
    public var entries: ArrayList<TestScheduleEntry>
    public var beforeAll: ArrayList<ExecutionEntry>
    public var beforeEach: ArrayList<ExecutionEntry>
    public var afterEach: ArrayList<ExecutionEntry>
    public var afterAll: ArrayList<ExecutionEntry>
    public var failed: Bool = false

    public init() {
        this.base = BaseScope()
        this.entries = ArrayList<TestScheduleEntry>()
        this.beforeAll = ArrayList<ExecutionEntry>()
        this.beforeEach = ArrayList<ExecutionEntry>()
        this.afterEach = ArrayList<ExecutionEntry>()
        this.afterAll = ArrayList<ExecutionEntry>()
    }

    public static func create(gpa: Allocator, base: BaseScope): DescribeScope {
        let scope = DescribeScope()
        scope.base = base
        return scope
    }

    public func destroy(gpa: Allocator) {
        entries.clear(); beforeAll.clear(); beforeEach.clear()
        afterEach.clear(); afterAll.clear(); base.deinit(gpa)
    }

    public func markContainsOnly() {
        var target: ?DescribeScope = this
        while (let Some(scope) <- target) {
            if (scope.base.only == OnlyMode.contains) { return }
            scope.base.only = OnlyMode.contains
            target = scope.base.parent
        }
    }

    public func markHasCallback() {
        var target: ?DescribeScope = this
        while (let Some(scope) <- target) {
            if (scope.base.hasCallback) { return }
            scope.base.hasCallback = true
            target = scope.base.parent
        }
    }

    /// 追加子 describe 作用域
    /// 对应 Bun: DescribeScope.appendDescribe
    public func appendDescribe(name: String, baseCfg: BaseScopeCfg): DescribeScope {
        let bscope = BaseScope()
        let child = DescribeScope.create(defaultAllocator, bscope)
        entries.append(TestScheduleEntry.describe(child))
        return child
    }

    /// 追加测试条目
    /// 对应 Bun: DescribeScope.appendTest
    public func appendTest(name: String, callback: ?JsValue, cfg: ExecutionEntryCfg, baseCfg: BaseScopeCfg, phase: AddedInPhase): ExecutionEntry {
        let entry = ExecutionEntry()
        let bscope = BaseScope()
        entry.base = bscope
        entries.append(TestScheduleEntry.testCallback(entry))
        return entry
    }
}

// ========== DescribeScopeHookTag ==========
// (Moved from nested enum in DescribeScope - Cangjie does not allow nested enums)
public enum DescribeScopeHookTag {
    | beforeAll | beforeEach | afterEach | afterAll
}

// ========== ExecutionEntryCfg ==========
public class ExecutionEntryCfg {
    public var timeout: UInt32 = 0
    public var hasDoneParameter: Bool = false
    public var retryCount: UInt32 = 0
    public var repeatCount: UInt32 = 0
    public init() {}
}

// ========== ExecutionEntry ==========
public class ExecutionEntry {
    public var base: BaseScope
    public var callback: ?Any = None
    public var timeout: UInt32 = 0
    public var hasDoneParameter: Bool = false
    public var timespec: Timespec = Timespec()
    public var addedInPhase: AddedInPhase = AddedInPhase.preload
    public var retryCount: UInt32 = 0
    public var repeatCount: UInt32 = 0
    public var next: ?ExecutionEntry = None
    public var failureSkipPast: ?ExecutionEntry = None

    public init() { this.base = BaseScope() }

    public operator func == (other: ExecutionEntry): Bool {
        this.base.name == other.base.name
    }
    public operator func != (other: ExecutionEntry): Bool {
        !(this == other)
    }

    public static func create(gpa: Allocator, name: ?String, cb: ?Any, cfg: ExecutionEntryCfg,
                              parent: ?DescribeScope, base: BaseScopeCfg, phase: AddedInPhase): ExecutionEntry {
        let entry = ExecutionEntry()
        entry.base = BaseScope(base, gpa, name, parent, cb.isSome())
        entry.timeout = cfg.timeout
        entry.hasDoneParameter = cfg.hasDoneParameter
        entry.addedInPhase = phase
        entry.retryCount = cfg.retryCount
        entry.repeatCount = cfg.repeatCount
        entry.callback = cb
        return entry
    }

    public func destroy(gpa: Allocator) { base.deinit(gpa) }

    /// 评估超时
    /// 对应 Bun: ExecutionEntry.evaluateTimeout
    public func evaluateTimeout(sequence: ExecutionSequence, now: Timespec): Bool {
        // 没有设置超时（epoch = 0,0）的条目永远不会超时
        if (timespec.isZero()) {
            return false
        }

        // 检查是否已超时
        if (!timespec.lessThan(now)) {
            return false
        }

        // 已超时 — 区分测试超时和钩子超时
        let isTestEntry = sequence.testEntry.isSome() &&
            sequence.testEntry.getOrThrow() == this

        if (isTestEntry) {
            if (hasDoneParameter) {
                sequence.result = Result.failBecauseTimeoutWithDoneCallback
            } else {
                sequence.result = Result.failBecauseTimeout
            }
        } else {
            if (hasDoneParameter) {
                sequence.result = Result.failBecauseHookTimeoutWithDoneCallback
            } else {
                sequence.result = Result.failBecauseHookTimeout
            }
        }

        sequence.maybeSkip = true
        return true
    }
}

// ========== TestScheduleEntry ==========
public enum TestScheduleEntry {
    | describe(DescribeScope)
    | testCallback(ExecutionEntry)
    public func deinit(gpa: Allocator) {
        match (this) {
            case describe(scope) => scope.destroy(gpa)
            case testCallback(entry) => entry.destroy(gpa)
        }
    }
    public func base(): BaseScope {
        match (this) {
            case describe(scope) => return scope.base
            case testCallback(entry) => return entry.base
        }
    }
}

// ========== BunTestPtr ==========
public class BunTestPtr {
    var ptr: ?BunTest = None
    public var refCount: Int64 = 1
    public init() {}
    public init(ptr: BunTest) { this.ptr = ptr }
    public func get(): ?BunTest { return ptr }
    public func deinit() { ptr = None }
    public func downgrade(): BunTestPtrWeak { return BunTestPtrWeak(this) }
    public func dupe(): BunTestPtr { refCount += 1; return this }
    public func deref() { refCount -= 1; if (refCount == 0) { ptr = None } }
    public func hasOneRef(): Bool { return refCount == 1 }

    /// 委托: 将结果添加到内部 BunTest
    public func addResult(result: RefDataValue): Unit {
        match (ptr) {
            case Some(buntest) => buntest.addResult(result)
            case None => ()
        }
    }
}

public class BunTestPtrWeak {
    var strong: ?BunTestPtr = None
    public init(strong: BunTestPtr) { this.strong = strong }
    public func upgrade(): ?BunTestPtr { return strong }
}

// ========== BunTestRoot ==========
public class BunTestRoot {
    public var gpa: Allocator
    public var activeFile: ?BunTestPtr = None
    public var hookScope: DescribeScope

    public init(gpa: Allocator) {
        this.gpa = gpa
        this.hookScope = DescribeScope()
    }

    public func deinit() { activeFile = None }
    public func resetHookScopeForTestIsolation() { hookScope = DescribeScope() }
    public func cloneActiveFile(): ?BunTestPtr { return activeFile }
}

// ========== BunTest ==========
public class BunTest {
    public var bunTestRoot: BunTestRoot
    public var inRunLoop: Bool = false
    public var gpa: Allocator
    public var fileId: UInt32 = 0
    public var phase: TestPhase = TestPhase.collection
    public var extraExecutionEntries: ArrayList<ExecutionEntry> = ArrayList<ExecutionEntry>()
    public var resultQueue: ResultQueue = ResultQueue()
    public var defaultConcurrent: Bool = false
    public var collection_: Collection   // use collection_ to avoid name clash with type
    public var reporter: ?CommandLineReporter = None
    public var snapshots: Snapshots
    public var execution_: Execution   // execution state
    public var timer: EventLoopTimer = EventLoopTimer()

    public init(gpa: Allocator, bunTest: BunTestRoot, fileId: UInt32) {
        this.bunTestRoot = bunTest
        this.gpa = gpa
        this.fileId = fileId
        this.collection_ = Collection(gpa, bunTest)
        this.snapshots = Snapshots(gpa)
        this.execution_ = Execution()
    }

    public func addResult(result: RefDataValue) {
        resultQueue.writeItem(result)
    }

    public func getCurrentStateData(): RefDataValue {
        return RefDataValue.start
    }

    /// 处理未捕获异常
    /// 对应 Bun: bun_test.zig onUncaughtException
    public func onUncaughtException(globalThis: JSGlobalObject, exception: JsValue, isRejection: Bool, userData: RefDataValue) {
        // 根据当前阶段决定处理策略
        let handlingResult: HandleUncaughtExceptionResult = match (phase) {
            case TestPhase.collection =>
                collection_.handleUncaughtException(userData)
            case TestPhase.execution =>
                execution_.handleUncaughtException(userData)
            case TestPhase.done =>
                HandleUncaughtExceptionResult.showUnhandledErrorBetweenTests
        }

        // 根据处理结果显示错误
        match (handlingResult) {
            case HandleUncaughtExceptionResult.hideError =>
                // 不显示错误（如 failing 模式的测试）
                ()
            case HandleUncaughtExceptionResult.showHandledError =>
                // 显示错误但不增加未处理错误计数
                // 对应 Bun: globalThis.bunVM().runErrorHandler(exception.?, null)
                let vm = globalThis.bunVM()
                vm.runErrorHandler(exception, Option<ExceptionList>.None)
            case HandleUncaughtExceptionResult.showUnhandledErrorBetweenTests =>
                // 测试之间的未处理错误
                // 对应 Bun: reporter.jest.unhandled_errors_between_tests += 1
                if (reporter.isSome()) {
                    reporter.getOrThrow().jest.unhandledErrorsBetweenTests += 1
                }
                // 对应 Bun: 打印 "Unhandled error between tests" 横幅
                Output.prettyError("\n<b><d>#<r> <red><b>Unhandled error<r><d> between tests<r>\n<d>-------------------------------<r>\n")
                Output.flush()
                // 对应 Bun: globalThis.bunVM().runErrorHandler(exception.?, null)
                let vm = globalThis.bunVM()
                vm.runErrorHandler(exception, Option<ExceptionList>.None)
                Output.prettyError("<r><d>-------------------------------<r>\n\n")
                Output.flush()
            case HandleUncaughtExceptionResult.showUnhandledErrorInDescribe =>
                // describe 块中的未处理错误
                // 对应 Bun: reporter.jest.unhandled_errors_between_tests += 1
                if (reporter.isSome()) {
                    reporter.getOrThrow().jest.unhandledErrorsBetweenTests += 1
                }
                // 对应 Bun: 打印 "Unhandled error" 横幅
                Output.prettyError("\n<b><d>#<r> <red><b>Unhandled error<r><d> between tests<r>\n<d>-------------------------------<r>\n")
                Output.flush()
                // 对应 Bun: globalThis.bunVM().runErrorHandler(exception.?, null)
                let vm = globalThis.bunVM()
                vm.runErrorHandler(exception, Option<ExceptionList>.None)
                Output.prettyError("<r><d>-------------------------------<r>\n\n")
                Output.flush()
        }
    }

    /// 运行测试回调
    /// 对应 Bun: bun_test.zig runTestCallback (line 1132)
    public static func runTestCallback(strong: BunTestPtr, globalThis: JSGlobalObject, callback: Any, doneParameter: Bool, data: RefDataValue, timeout: Timespec): ?RefDataValue {
        let buntestOpt = strong.get()
        if (buntestOpt.isNone()) { return Some(data) }
        let buntest = buntestOpt.getOrThrow()

        if (doneParameter) {
            // 异步模式：创建 DoneCallback 并绑定为 done 参数
            // 对应 Bun: done_callback = DoneCallback.createUnbound(globalThis)
            let doneCallback = DoneCallback.createUnbound(globalThis)
            // 对应 Bun: done_arg = DoneCallback.bind(done_callback, globalThis)
            let doneArg = DoneCallback.bind(doneCallback, globalThis)
            if (doneArg.isNone()) {
                // 绑定失败，处理异常
                buntest.onUncaughtException(globalThis, JsValue.undefined(), false, data)
                return Some(data)
            }

            // 对应 Bun: this.updateMinTimeout(globalThis, timeout)
            buntest.updateMinTimeout(timeout)

            // 对应 Bun: vm.eventLoop().runCallbackWithResultAndForcefullyDrainMicrotasks()
            // 对应 Bun: vm.eventLoop().runCallbackWithResult — Bao 返回 Unit
            let vm = globalThis.bunVM()
            let args = ArrayList<JsValue>()
            args.append(doneArg.getOrThrow())
            let el = vm.eventLoop
            let jsCallbackOpt = callback as JsCallback
            if (jsCallbackOpt.isNone()) { return Some(data) }
            el.runCallback(jsCallbackOpt.getOrThrow(), globalThis.globalThis, JsValue.jsUndefined(), args)

            // 对应 Bun: done_callback.ensureStillAlive()
            doneCallback.ensureStillAlive()

            // 返回 None 表示异步等待
            return None
        }

        // 同步模式：直接调用回调
        // 对应 Bun: this.updateMinTimeout(globalThis, timeout)
        buntest.updateMinTimeout(timeout)

        // 对应 Bun: vm.eventLoop().runCallbackWithResultAndForcefullyDrainMicrotasks()
        // 简化实现: EventLoop.runCallback 返回 Unit, 无法获取回调结果
        let vm = globalThis.bunVM()
        let args = ArrayList<JsValue>()
        let el = vm.eventLoop
        let jsCallbackOpt = callback as JsCallback
        if (jsCallbackOpt.isNone()) { return Some(data) }
        el.runCallback(jsCallbackOpt.getOrThrow(), globalThis.globalThis, JsValue.jsUndefined(), args)

        return Some(data)
    }

    /// 获取活跃的 BunTestPtr
    /// 对应 Bun: bun_test.zig cloneActiveStrong (module-level)
    public static func cloneActiveStrong(): ?BunTestPtr {
        let runner = Jest.runner
        if (runner.isNone()) {
            return None
        }
        return runner.getOrThrow().bunTestRoot.cloneActiveFile()
    }

    /// 运行测试主循环
    /// 对应 Bun: bun_test.zig run (line 541)
    public static func run(strong: BunTestPtr, globalThis: JSGlobalObject): Bool {
        let buntestOpt = strong.get()
        if (buntestOpt.isNone()) { return false }
        let buntest = buntestOpt.getOrThrow()

        // 重入保护
        if (buntest.inRunLoop) {
            return false
        }
        buntest.inRunLoop = true

        var minTimeout: Timespec = Timespec.EPOCH

        // 排空结果队列
        while (true) {
            let item = buntest.resultQueue.readItem()
            if (item.isNone()) { break }
            let data = item.getOrThrow()

            // 根据阶段分发
            let stepResult: StepResult = match (buntest.phase) {
                case TestPhase.collection =>
                    buntest.collection_.step(strong, globalThis, data)
                case TestPhase.execution =>
                    buntest.execution_.step(strong, globalThis, data)
                case TestPhase.done =>
                    StepResult.complete
            }

            match (stepResult) {
                case StepResult.waiting(timeout) =>
                    // 跟踪最小超时（忽略 epoch = 0,0）
                    if (timeout.isZero()) {
                        // epoch 表示无超时，跳过
                    } else if (minTimeout.isZero()) {
                        minTimeout = timeout
                    } else if (timeout.lessThan(minTimeout)) {
                        minTimeout = timeout
                    }
                case StepResult.complete =>
                    // 阶段完成，推进到下一阶段
                    let advanceResult = buntest.advancePhase(strong, globalThis)
                    match (advanceResult) {
                        case AdvanceResult.exit =>
                            buntest.inRunLoop = false
                            return true
                        case AdvanceResult.cont =>
                            // 入队 start 以继续循环
                            buntest.addResult(RefDataValue.start)
                    }
            }
        }

        buntest.inRunLoop = false

        // 更新定时器
        buntest.updateMinTimeout(minTimeout)

        return true
    }

    /// 推进阶段
    /// 对应 Bun: bun_test.zig _advance (line 597)
    private func advancePhase(strong: BunTestPtr, globalThis: JSGlobalObject): AdvanceResult {
        match (phase) {
            case TestPhase.collection =>
                // Collection -> Execution
                // 对应 Bun: 生成测试执行顺序并加载到执行引擎
                phase = TestPhase.execution

                // 对应 Bun: debug.dumpDescribe(this.collection.root_scope)
                Debug.dumpDescribe(collection_.rootScope)

                // 对应 Bun: 检查是否有过滤器
                let hasFilter = if (reporter.isSome()) {
                    reporter.getOrThrow().jest.filterRegex.isSome()
                } else {
                    false
                }

                // 对应 Bun: Order.init(...)
                let orderCfg = Config(alwaysUseHooks: collection_.rootScope.base.only == OnlyMode.no && !hasFilter, randomize: false)
                let order = Order(gpa: gpa, arena: gpa, cfg: orderCfg)

                // 对应 Bun: order.generateOrderDescribe(root_scope)
                // 注意: generateOrderDescribe 内部已处理 beforeAll/afterAll hooks
                order.generateOrderDescribe(current: collection_.rootScope)

                // 对应 Bun: this.execution.loadFromOrder(&order)
                execution_.loadFromOrder(order)

                // 对应 Bun: debug.dumpOrder(&this.execution)
                Debug.dumpOrder(execution_)

                return AdvanceResult.cont
            case TestPhase.execution =>
                // Execution -> Done
                inRunLoop = false
                phase = TestPhase.done
                return AdvanceResult.exit
            case TestPhase.done =>
                return AdvanceResult.exit
        }
    }

    /// 更新最小超时
    /// 对应 Bun: bun_test.zig updateMinTimeout
    private func updateMinTimeout(minTimeout: Timespec): Unit {
        // 对应 Bun: 只有当新超时比当前超时更早时才设置定时器
        // 这意味着我们无法取消一个不必要的定时器
        if (minTimeout.orderIgnoreEpoch(timer.next)) {
            // 对应 Bun: 如果当前定时器不是 epoch，先移除
            if (!timer.next.isEpoch()) {
                let vm = VirtualMachine.get()
                vm.timer.remove(timer)
            }

            // 对应 Bun: 设置新的定时器
            timer.next = minTimeout

            // 对应 Bun: 如果新定时器不是 epoch，插入到事件循环
            if (!timer.next.isEpoch()) {
                let vm = VirtualMachine.get()
                vm.timer.insert(timer)
            }
        }
    }

    public static func ref(strong: BunTestPtr, data: RefDataValue): ?RefData {
        return RefData(data, strong.downgrade())
    }

    /// Done 回调处理器
    /// 对应 Bun: bun_test.zig bunTestDoneCallback (line 450)
    public static func bunTestDoneCallback(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        // 对应 Bun: const this = DoneCallback.fromJS(callframe.this())
        let thisValue = callFrame.`this`()
        let doneCallback = DoneCallback.fromJS(thisValue)
        if (doneCallback.isNone()) {
            globalThis.throwError("Expected callee to be DoneCallback")
            return JsValue.jsUndefined()
        }
        let this_ = doneCallback.getOrThrow()

        // 对应 Bun: const value = callframe.argumentsAsArray(1)[0]
        let args = callFrame.arguments()
        let value = if (args.size > 0) { args[0] } else { JsValue.jsUndefined() }

        // 对应 Bun: const was_error = !value.isEmptyOrUndefinedOrNull()
        let wasError = !value.isEmptyOrUndefinedOrNull()

        // 对应 Bun: 多次调用保护
        if (this_.called) {
            // 在 Bun 1.2.20 中，这是 no-op
            // 在 Jest 中，这是 "Expected done to be called once, but it was called multiple times."
        } else {
            // 对应 Bun: error is only reported for the first done() call
            if (wasError) {
                let vm = globalThis.bunVM()
                vm.uncaughtException(globalThis.globalThis, value, false)
            }
        }

        // 对应 Bun: this.called = true
        this_.called = true

        // 对应 Bun: const ref_in = this.ref orelse return .js_undefined
        let refIn = this_.ref
        if (refIn.isNone()) {
            return JsValue.jsUndefined()
        }
        let ref = refIn.getOrThrow()

        // 对应 Bun: defer this.ref = null; defer ref_in.deref()
        this_.ref = None
        ref.deref()

        // 对应 Bun: const has_one_ref = ref_in.ref_count.hasOneRef()
        let hasOneRef = ref.hasOneRef()

        // 对应 Bun: const should_run = has_one_ref or was_error
        let shouldRun = hasOneRef || wasError

        // 对应 Bun: if (!should_run) return .js_undefined
        if (!shouldRun) {
            return JsValue.jsUndefined()
        }

        // 对应 Bun: var strong = ref_in.buntest_weak.upgrade()
        let strong = ref.buntestWeak.upgrade()
        if (strong.isNone()) {
            return JsValue.jsUndefined()
        }
        let buntest = strong.getOrThrow()

        // 对应 Bun: buntest.addResult(ref_in.phase)
        buntest.addResult(ref.phase)

        // 对应 Bun: runNextTick(ref_in.buntest_weak, globalThis, ref_in.phase)
        runNextTick(ref.buntestWeak, globalThis, ref.phase)

        return JsValue.jsUndefined()
    }
}

/// 调度下一个 tick 执行测试结果处理
/// 对应 Bun: runNextTick - 在事件循环下一个 tick 中运行回调
/// 通过将结果入队到 resultQueue 并触发 BunTest.run 来推进测试执行
private func runNextTick(buntestWeak: BunTestPtrWeak, globalThis: JSGlobalObject, phase: RefDataValue): Unit {
    // 尝试升级弱引用获取 BunTestPtr
    let strongOpt = buntestWeak.upgrade()
    if (strongOpt.isNone()) { return }
    let strong = strongOpt.getOrThrow()
    // 入队结果并运行
    let buntestOpt = strong.get()
    if (buntestOpt.isSome()) {
        let buntest = buntestOpt.getOrThrow()
        buntest.addResult(phase)
        BunTest.run(strong, globalThis)
    }
    strong.deref()
}

// ========== RefDataValue ==========
public enum RefDataValue {
    | start
    | collection(RefDataCollection)
    | execution(RefDataExecution)
    | done

    public func isStart(): Bool {
        match (this) {
            case start => return true
            case _ => return false
        }
    }
}

public class RefDataCollection {
    public var activeScope: DescribeScope
    public init(activeScope: DescribeScope) { this.activeScope = activeScope }
}

public class RefDataExecution {
    public var groupIndex: UInt64 = 0
    public var entryData: ?RefDataEntry = None

    public init() {}
    public init(groupIndex: UInt64, entryData: ?RefDataEntry) {
        this.groupIndex = groupIndex
        this.entryData = entryData
    }
}

public class RefDataEntry {
    public var sequenceIndex: UInt64 = 0
    public var entry: ExecutionEntry
    public var remainingRepeatCount: Int64 = 0
    public init(sequenceIndex: UInt64, entry: ExecutionEntry, remainingRepeatCount: Int64) {
        this.sequenceIndex = sequenceIndex
        this.entry = entry
        this.remainingRepeatCount = remainingRepeatCount
    }
}

// ========== StepResult ==========
public enum StepResult {
    | waiting(Timespec)
    | complete
}

// ========== AdvanceResult ==========
public enum AdvanceResult {
    | cont | exit
}

// ========== HandleUncaughtExceptionResult ==========
public enum HandleUncaughtExceptionResult {
    | hideError | showHandledError | showUnhandledErrorBetweenTests | showUnhandledErrorInDescribe
}

// ========== ResultQueue ==========
public class ResultQueue {
    private var items: ArrayList<RefDataValue> = ArrayList<RefDataValue>()
    public init() {}
    public func writeItem(item: RefDataValue) { items.append(item) }
    public func readItem(): ?RefDataValue {
        if (items.size > 0) { return Some(items.removeAt(0)) }
        return None
    }
}

// ========== RefData ==========
public class RefData {
    public var phase: RefDataValue
    public var refCount: Int64 = 1
    public var buntestWeak: BunTestPtrWeak
    public init(phase: RefDataValue, buntestWeak: BunTestPtrWeak) {
        this.phase = phase
        this.buntestWeak = buntestWeak
    }
    public func dupe(): RefData { refCount += 1; return this }
    public func deref() { refCount -= 1 }
    public func hasOneRef(): Bool { return refCount == 1 }
    public func bunTest(): ?BunTestPtr { return None }
    public func sequence(buntest: Any): ?ExecutionSequence { return None }
    public func entry(buntest: Any): ?ExecutionEntry { return None }
}

// ========== Signature ==========
public enum Signature {
    | scopeFunctions(ScopeFunctions)
    | str(String)
    public func format(): String {
        match (this) {
            case scopeFunctions(sf) => return sf.format()
            case str(s) => return s
        }
    }
}

// ========== Counter ==========
// (defined elsewhere in the package - removed to avoid redefinition)

// ========== GetActiveCfg ==========
public class GetActiveCfg {
    public var signature: Signature
    public var allowInPreload: Bool
    public init(signature: Signature, allowInPreload: Bool) {
        this.signature = signature
        this.allowInPreload = allowInPreload
    }
}

// ========== GenericHookTag ==========
public enum GenericHookTag {
    | beforeAll | beforeEach | afterEach | afterAll | onTestFinished
    public func asHookTag(): ?DescribeScopeHookTag {
        match (this) {
            case beforeAll => return DescribeScopeHookTag.beforeAll
            case beforeEach => return DescribeScopeHookTag.beforeEach
            case afterEach => return DescribeScopeHookTag.afterEach
            case afterAll => return DescribeScopeHookTag.afterAll
            case onTestFinished => return None
        }
    }
    public func sig(): String {
        match (this) {
            case beforeAll => "beforeAll()"
            case beforeEach => "beforeEach()"
            case afterEach => "afterEach()"
            case afterAll => "afterAll()"
            case onTestFinished => "onTestFinished()"
        }
    }
    public func tagName(): String {
        match (this) {
            case beforeAll => "beforeAll"
            case beforeEach => "beforeEach"
            case afterEach => "afterEach"
            case afterAll => "afterAll"
            case onTestFinished => "onTestFinished"
        }
    }
}

// ========== CommandLineReporter ==========
public class CommandLineReporter {
    public var jest: TestRunner
    public var lastPrintedDot: Bool = false
    public var workerIpcFileIdx: ?UInt32 = None
    public var reporters: ReporterFlags = ReporterFlags()
    public init() {
        this.jest = TestRunner()
    }

    public func summary(): Summary {
        return jest.summary
    }
}

// ========== Jest (defined in jest.cj) ==========

// ========== JestFile ==========
/// 测试文件信息 — 对应 Bun: JestFile
public class JestFile {
    public var source: JestFileSource = JestFileSource()
    public var logErrors: Bool = true
    public var only: Bool = false
    public var skip: Bool = false
    public var todo: Bool = false
    public init() {}
    /// 如果需要，打印测试结果
    public func printIfNeeded() {
        // 在实际 Bun 中, 这里会在测试文件执行完毕后输出结果
    }
}

/// 测试文件源信息 — 对应 Bun: JestFileSource
public class JestFileSource {
    public var path: JestFilePath = JestFilePath()
    public init() {}
}

/// 测试文件路径 — 对应 Bun: JestFilePath
public class JestFilePath {
    public var text: String = ""
    public init() {}
}

// ========== CounterNode ==========
/// 测试计数器节点 — 对应 Bun: CounterNode
/// 用于在测试执行期间跟踪每个 describe/test 块的断言计数
public class CounterNode {
    public var parent: ?CounterNode = None
    public var expectCount: UInt32 = 0
    public var assertCount: UInt32 = 0
    public init() {}
    public init(parent: CounterNode) {
        this.parent = Some(parent)
    }
    /// 递增 expect 调用计数
    public func incrementExpect(): Unit {
        expectCount += 1
        if (let Some(p) <- parent) {
            p.incrementExpect()
        }
    }
    /// 递增 assert 调用计数
    public func incrementAssert(): Unit {
        assertCount += 1
        if (let Some(p) <- parent) {
            p.incrementAssert()
        }
    }
}

// ========== EventLoopTimer (stub) ==========
public class EventLoopTimer {
    public var next: Timespec = Timespec()
    public var state: EventLoopTimerState = EventLoopTimerState.Pending
    public init() {}
}

// ========== EventLoopTimerState ==========
public enum EventLoopTimerState {
    | Pending | Active | Cancelled | Fired

    public operator func ==(other: EventLoopTimerState): Bool {
        match (this) {
            case Pending => match (other) { case Pending => true; case _ => false }
            case Active => match (other) { case Active => true; case _ => false }
            case Cancelled => match (other) { case Cancelled => true; case _ => false }
            case Fired => match (other) { case Fired => true; case _ => false }
        }
    }

    public operator func !=(other: EventLoopTimerState): Bool {
        !(this == other)
    }
}

// ========== ReporterFlags ==========
public class ReporterFlags {
    public var dots: Bool = false
    public var onlyFailures: Bool = false
    public init() {}
}

// ========== GenericHookFns (stubs) ==========
public class GenericHookFns {
    public init() {}
}

// ========== DefaultPrng ==========
public class DefaultPrng {
    public var seed: UInt64 = 0
    public init() {}
    public init(seed: UInt64) { this.seed = seed }
}

// ========== HookFn ==========
public class HookFn {
    public var tag: String
    public init(tag: String) { this.tag = tag }
}

// ========== RunOneResult ==========
public enum RunOneResult {
    | done
    | execute(Timespec)
}

// ========== RefData alias for ScopeFunctions ==========
// ScopeFunctions is defined in scope_functions.cj

// ========== ParseOptions (helper) ==========
public class ParseOptions {
    public var timeout: UInt32 = 0
    public init() {}
}

// ========== Mode alias ==========
// scope_functions.cj defines ScopeFunctionsMode; some files use 'Mode'
public type Mode = ScopeFunctionsMode

// ========== VirtualMachine stub ==========
public class VirtualMachine {
    public var timer: VMTimer = VMTimer()
    public var isInPreload: Bool = false
    public var onUnhandledRejectionExceptionList: ?ExceptionList = None
    public var debugger: ?DebuggerStub = None
    public init() {}
    /// 运行错误处理器 - 委托给 BunVirtualMachine 的实现
    /// 对应 Bun: VirtualMachine.runErrorHandler
    public func runErrorHandler(exception: JsValue, exceptionList: ?ExceptionList): Unit {
        // 对应 Bun: 输出错误到 stderr
        let str = exception.toString()
        println("[ERROR] " + str)
        // Note: ExceptionList is Array<JsValue> which doesn't support append
        // In a real implementation, this would use ArrayList or other mutable collection
    }
    /// 获取全局 VM 实例 — 对应 Bun: VirtualMachine.get()
    public static func get(): VirtualMachine {
        VirtualMachine()
    }
}

/// Debugger stub
public class DebuggerStub {
    public var testReporterAgent: TestReporterAgentStub = TestReporterAgentStub()
    public init() {}
}

public class TestReporterAgentStub {
    public func isEnabled(): Bool { return false }
    public init() {}
}

// ========== VMTimer stub ==========
public class VMTimer {
    public init() {}
    public func remove(ref: EventLoopTimer): Unit {}
    public func insert(ref: EventLoopTimer): Unit {}
}

// ========== FileHandle stub ==========
public class FileHandle {
    public init() {}
}

// ========== FirstLast ==========
public class FirstLast {
    public var first: Bool = false
    public var last: Bool = false
    public init(first: Bool, last: Bool) {
        this.first = first
        this.last = last
    }
}

// ========== GlobMatchResult ==========
public enum GlobMatchResult {
    | match_
    | noMatch

    public operator func ==(other: GlobMatchResult): Bool {
        match (this) {
            case match_ => match (other) { case match_ => true; case _ => false }
            case noMatch => match (other) { case noMatch => true; case _ => false }
        }
    }

    public operator func !=(other: GlobMatchResult): Bool {
        !(this == other)
    }
}

// ========== GlobMatcher ==========
/// 简单的通配符匹配器 — 对应 Bun: GlobMatcher
/// 支持基本的通配符匹配 (* 和 ** 模式)
public class GlobMatcher {
    /// 匹配通配符模式
    /// 对应 Bun: GlobMatcher.match
    public static func `match`(pattern!: String, path!: String): GlobMatchResult {
        // 对应 Bun: GlobMatcher — 基本通配符匹配
        if (pattern == "*" || pattern == "**" || pattern == "*/*") {
            return GlobMatchResult.match_
        }
        if (pattern == path) {
            return GlobMatchResult.match_
        }
        // 处理 *.ext 模式
        if (pattern.startsWith("*.")) {
            let suffix = pattern[1..pattern.size]
            if (path.endsWith(suffix)) {
                return GlobMatchResult.match_
            }
        }
        return GlobMatchResult.noMatch
    }
}

// ========== WyHash ==========
/// 快速哈希 — 对应 Bun: WyHash
/// 使用简单的 FNV-1a 哈希作为 WyHash 的替代
public class WyHash {
    /// 计算字符串的哈希值
    public static func hash(data: String): UInt64 {
        // FNV-1a 64-bit 哈希
        var hash: UInt64 = 0xCBF29CE484222325
        for (i in 0..data.size) {
            let c = data[Int64(i)]
            hash = hash ^ UInt64(c)
            hash = hash * UInt64(1099511628211)
        }
        return hash
    }
}
