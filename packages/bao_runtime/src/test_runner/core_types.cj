// bun_test.cj - 测试框架主入口 (types only)
package bao_runtime.test_runner

import bao_collections.ArrayList
import bao_core.{Allocator, defaultAllocator}
import bao_event_loop.Timespec
import bao_jsc.JSGlobalObject

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
    public func onUncaughtException(globalThis: JSGlobalObject, exception: Any, isRejection: Bool, userData: RefDataValue) {
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
                // TODO: 调用 vm.runErrorHandler(exception)
                ()
            case HandleUncaughtExceptionResult.showUnhandledErrorBetweenTests =>
                // 测试之间的未处理错误
                // TODO: 增加 unhandled_errors_between_tests 计数
                // TODO: 打印 "Unhandled error between tests" 横幅
                // TODO: 调用 vm.runErrorHandler(exception)
                ()
            case HandleUncaughtExceptionResult.showUnhandledErrorInDescribe =>
                // describe 块中的未处理错误
                // TODO: 增加 unhandled_errors_between_tests 计数
                // TODO: 打印 "Unhandled error" 横幅
                // TODO: 调用 vm.runErrorHandler(exception)
                ()
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
            // TODO: 创建 DoneCallback.createUnbound(globalThis)
            // TODO: 绑定为 JS 函数参数
            // TODO: 调用 vm.eventLoop().runCallbackWithResultAndForcefullyDrainMicrotasks()
            // 返回 None 表示异步等待
            return None
        }

        // 同步模式：直接调用回调
        // TODO: 调用 vm.eventLoop().runCallbackWithResultAndForcefullyDrainMicrotasks()
        // 处理 JS 异常和 Promise rejection

        // 临时实现：返回 data 表示同步完成
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
                // 生成测试执行顺序并加载到执行引擎
                // TODO: 使用 Order 生成执行顺序（支持 shuffle）
                phase = TestPhase.execution
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
        // TODO: 与当前定时器比较，如果新超时更早则更新事件循环定时器
    }

    public static func ref(strong: BunTestPtr, data: RefDataValue): ?RefData {
        return RefData(data)
    }

    /// Done 回调处理器
    /// 对应 Bun: bun_test.zig bunTestDoneCallback (line 450)
    public static func bunTestDoneCallback(globalThis: JSGlobalObject, callFrame: Any): Any {
        // TODO: 从 callframe.this() 提取 DoneCallback
        // TODO: 获取参数（传给 done(err) 的错误值）
        // 多次调用保护：如果 called 已为 true，后续调用为 no-op
        // 首次调用且有错误：调用 globalThis.bunVM().uncaughtException()
        // 设置 called = true
        // Ref 管理：获取 this.ref，置空并 deref
        // 只在最后一个 ref 或有错误时继续
        // 升级弱引用为强引用
        // 调用 buntest.addResult(ref_in.phase) 入队阶段结果
        // 调用 runNextTick() 在下一个事件循环 tick 启动下一个测试
        return Object()
    }
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
    public init(phase: RefDataValue) { this.phase = phase }
    public func dupe(): RefData { refCount += 1; return this }
    public func deref() { refCount -= 1 }
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
    public init() {
        this.jest = TestRunner()
    }

    public func summary(): Summary {
        return jest.summary
    }
}

// ========== Jest (defined in jest.cj) ==========

// ========== JestFile (stub) ==========
public class JestFile {
    public var source: JestFileSource = JestFileSource()
    public init() {}
    public func printIfNeeded() {}
}

public class JestFileSource {
    public var path: JestFilePath = JestFilePath()
    public init() {}
}

public class JestFilePath {
    public var text: String = ""
    public init() {}
}

// ========== CounterNode (stub) ==========
public class CounterNode {
    public init() {}
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
}

// ========== ReporterFlags ==========
public class ReporterFlags {
    public var dots: Bool = false
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
    public init() {}
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
