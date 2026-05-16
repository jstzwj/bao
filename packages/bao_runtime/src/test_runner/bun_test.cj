// bun_test.cj - 测试框架主入口
// 严格翻译自 bun/src/runtime/test_runner/bun_test.zig

package bao_runtime.test_runner

import bao_jsc.*
import std.collection.*

// ========== 公共辅助函数 ==========

/// 克隆当前活跃的强引用
///
/// 从全局Jest.runner获取当前活跃的BunTest文件并返回其强引用。
/// 用于在异步操作中保持对BunTest的引用。
public func cloneActiveStrong(): ?BunTestPtr {
    let runner = Jest.runner ?? return None
    return runner.bunTestRoot.cloneActiveFile()
}

/// 克隆当前活跃的强引用（带配置）
///
/// 验证调用是否合法（不在preload中使用），然后返回活跃BunTest的强引用
public func cloneActiveStrong(globalThis: JSGlobalObject, cfg: GetActiveCfg): ?BunTestPtr {
    let bunTestRoot = getActiveTestRoot(globalThis: globalThis, cfg: cfg) ?? return None
    return bunTestRoot.cloneActiveFile()
}

// ========== 计数器 ==========

/// 期望计数器
public class Counter {
    public var expected: UInt32 = 0
    public var actual: UInt32 = 0

    public init() {}
}

// ========== JS函数签名 ==========

/// 函数签名类型
public enum Signature {
    | scopeFunctions(ScopeFunctions)
    | str(String)

    /// 格式化为字符串
    public func format(): String {
        match (this) {
            case scopeFunctions(sf) => return sf.format()
            case str(s) => return s
        }
    }
}

// ========== 获取活跃测试配置 ==========

/// 获取活跃测试根
///
/// 验证:
/// 1. Jest.runner是否存在（是否在测试运行器中）
/// 2. 根据allowInPreload检查是否在preload阶段
public func getActiveTestRoot(globalThis: JSGlobalObject, cfg: GetActiveCfg): ?BunTestRoot {
    let runner = Jest.runner ?? {
        globalThis.throw(message: "Cannot use " + (cfg.signature.format()) + " outside of the test runner. Run \"bun test\" to run tests.")
        return None
    }()

    let bunTestRoot = runner.bunTestRoot
    let vm = globalThis.bunVM()

    if (vm.isInPreload && !cfg.allowInPreload) {
        globalThis.throw(message: "Cannot use " + (cfg.signature.format()) + " during preload.")
        return None
    }

    return bunTestRoot
}

/// 获取活跃配置
public class GetActiveCfg {
    public var signature: Signature
    public var allowInPreload: Bool

    public init(signature: Signature, allowInPreload: Bool) {
        this.signature = signature
        this.allowInPreload = allowInPreload
    }
}

// ========== 泛型钩子 ==========

/// 钩子标签枚举
///
/// 标识不同类型的生命周期钩子
public enum GenericHookTag {
    | beforeAll
    | beforeEach
    | afterEach
    | afterAll
    | onTestFinished

    /// 转换为DescribeScope的HookTag
    public func asHookTag(): ?DescribeScope.HookTag {
        match (this) {
            case beforeAll => return DescribeScope.HookTag.beforeAll
            case beforeEach => return DescribeScope.HookTag.beforeEach
            case afterEach => return DescribeScope.HookTag.afterEach
            case afterAll => return DescribeScope.HookTag.afterAll
            case onTestFinished => return None
        }
    }

    /// 获取签名字符串
    public func sig(): String {
        match (this) {
            case beforeAll => return "beforeAll()"
            case beforeEach => return "beforeEach()"
            case afterEach => return "afterEach()"
            case afterAll => return "afterAll()"
            case onTestFinished => return "onTestFinished()"
        }
    }

    /// 获取标签名称
    public func tagName(): String {
        match (this) {
            case beforeAll => return "beforeAll"
            case beforeEach => return "beforeEach"
            case afterEach => return "afterEach"
            case afterAll => return "afterAll"
            case onTestFinished => return "onTestFinished"
        }
    }

    /// 获取JS主机函数引用
    public func hostFn(): JSFunction {
        // 返回对应的JS函数入口点
        match (this) {
            case beforeAll => return GenericHookFns.beforeAll
            case beforeEach => return GenericHookFns.beforeEach
            case afterEach => return GenericHookFns.afterEach
            case afterAll => return GenericHookFns.afterAll
            case onTestFinished => return GenericHookFns.onTestFinished
        }
    }
}

/// 泛型钩子函数集合
public class GenericHookFns {
    public static var beforeAll: JSFunction = JSFunction.null
    public static var beforeEach: JSFunction = JSFunction.null
    public static var afterEach: JSFunction = JSFunction.null
    public static var afterAll: JSFunction = JSFunction.null
    public static var onTestFinished: JSFunction = JSFunction.null
}

/// 泛型钩子实现
///
/// 处理beforeEach/afterEach/beforeAll/afterAll/onTestFinished的统一逻辑:
/// 1. 解析参数（获取回调函数和选项）
/// 2. 检查done参数（回调函数的参数个数）
/// 3. 根据当前阶段（Collection/Execution/Done）决定钩子追加位置
/// 4. 在Execution阶段，需要将钩子插入到执行序列的正确位置
public func genericHookImpl(tag: GenericHookTag, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    let tagName = tag.tagName()
    let sigBytes = tag.sig()

    // 解析参数
    let args = ScopeFunctions.parseArguments(
        globalThis: globalThis,
        callFrame: callFrame,
        signature: Signature.str(sigBytes),
        cfg: ParseArgumentsCfg(callback: CallbackMode.require, kind: FunctionKind.hook)
    )

    let hasDoneParameter = if (let Some(callback) <- args.callback) {
        callback.getLength(global: globalThis) > 0
    } else {
        false
    }

    let bunTestRoot = getActiveTestRoot(
        globalThis: globalThis,
        cfg: GetActiveCfg(signature: Signature.str(sigBytes), allowInPreload: true)
    ) ?? return JSValue.jsUndefined

    let cfg = ExecutionEntryCfg(
        timeout: args.options.timeout,
        hasDoneParameter: hasDoneParameter,
        retryCount: 0,
        repeatCount: 0
    )

    let bunTest = bunTestRoot.getActiveFileUnlessInPreload(vm: globalThis.bunVM())
    if (bunTest == None) {
        if (tag == .onTestFinished) {
            globalThis.throw(message: "Cannot call " + (tagName) + "() in preload. It can only be called inside a test.")
            return JSValue.jsUndefined
        }

        // 在preload中，追加到hookScope
        bunTestRoot.hookScope.appendHook(
            tag: tag.asHookTag()!!,
            callback: args.callback,
            cfg: cfg,
            base: BaseScopeCfg(),
            phase: AddedInPhase.preload
        )
        return JSValue.jsUndefined
    }

    match (bunTest.getOrThrow().phase) {
        case collection =>
            if (tag == .onTestFinished) {
                globalThis.throw(message: "Cannot call " + (tagName) + "() outside of a test. It can only be called inside a test.")
                return JSValue.jsUndefined
            }
            bunTest.collection.activeScope.appendHook(
                tag: tag.asHookTag()!!,
                callback: args.callback,
                cfg: cfg,
                base: BaseScopeCfg(),
                phase: AddedInPhase.collection
            )
            return JSValue.jsUndefined

        case execution =>
            let active = bunTest.getCurrentStateData()
            let result = bunTest.execution.getCurrentAndValidExecutionSequence(data: active)
            if (result == None) {
                if (tag == .onTestFinished) {
                    globalThis.throw(message: "Cannot call " + (tagName) + "() here. It cannot be called inside a concurrent test. Use test.serial or remove test.concurrent.")
                } else {
                    globalThis.throw(message: "Cannot call " + (tagName) + "() here. It cannot be called inside a concurrent test. Call it inside describe() instead.")
                }
                return JSValue.jsUndefined
            }

            let (sequence, group) = result.getOrThrow()

            // 确定插入点
            let appendPoint: ExecutionEntry = match (tag) {
                case afterAll | afterEach =>
                    // 在test entry之后插入
                    sequence.testEntry ?? sequence.activeEntry.getOrThrow()
                case onTestFinished =>
                    // 在序列末尾插入
                    var lastEntry = sequence.activeEntry.getOrThrow()
                    while (let Some(next) <- lastEntry.next ){
                        lastEntry = next
                    }
                    lastEntry
                case _ =>
                    globalThis.throw(message: "Cannot call " + (tagName) + "() inside a test. Call it inside describe() instead.")
                    return JSValue.jsUndefined
            }

            // 创建新的执行条目并插入链表
            let newItem = ExecutionEntry.create(
                name: None, cb: args.callback, cfg: cfg,
                parent: None, base: BaseScopeCfg(), phase: AddedInPhase.execution
            )
            newItem.next = appendPoint.next
            appendPoint.next = newItem
            bunTest.extraExecutionEntries.append(newItem)

            return JSValue.jsUndefined

        case done =>
            globalThis.throw(message: "Cannot call " + (tagName) + "() after the test run has completed")
            return JSValue.jsUndefined
    }
}

/// 钩子函数包装
public class HookFn {
    public var tag: String

    public init(tag: String) {
        this.tag = tag
    }

    /// 钩子函数入口
    public func hookFn(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        return genericHookImpl(tag: GenericHookTag.beforeAll, globalThis: globalThis, callFrame: callFrame)
    }
}

// ========== BunTestPtr - BunTest智能指针 ==========

/// BunTest指针，支持共享所有权
///
/// 对应Rust中的Rc<BunTestCell>，提供共享所有权的智能指针。
/// BunTestPtr.get()返回可变的BunTest引用（通过UnsafeCell实现内部可变性）。
///
/// 别名契约: 测试运行器是单线程的，这是Zig中自由别名*T的道德等价物。
/// 调用者不得在可能重新调用.get()的重入点（JS回调、Collection::step等）之间
/// 持有返回的可变引用。
public class BunTestPtr {
    var ptr: ?BunTest = None
    public var refCount: Int64 = 1

    public init() {}

    public init(ptr: BunTest) {
        this.ptr = ptr
    }

    public func get(): ?BunTest {
        return ptr
    }

    public func deinit() {
        ptr = None
    }

    /// 创建弱引用
    public func downgrade(): BunTestPtrWeak {
        return BunTestPtrWeak(strong: this)
    }

    /// 增加引用计数
    public func dupe(): BunTestPtr {
        refCount += 1
        return this
    }

    /// 减少引用计数
    public func deref() {
        refCount -= 1
        if (refCount == 0) {
            ptr = None
        }
    }

    /// 是否只有一个引用
    public func hasOneRef(): Bool {
        return refCount == 1
    }
}

/// 弱引用指针
public class BunTestPtrWeak {
    var strong: ?BunTestPtr = None

    public init(strong: BunTestPtr) {
        this.strong = strong
    }

    /// 尝试升级为强引用
    public func upgrade(): ?BunTestPtr {
        return strong
    }
}

// ========== BunTestRoot - 测试根 ==========

/// BunTest根对象，管理所有测试文件
public class BunTestRoot {
    public var gpa: Allocator
    public var activeFile: ?BunTestPtr = None
    public var hookScope: DescribeScope

    public init(gpa: Allocator) {
        this.gpa = gpa
        this.hookScope = DescribeScope.create(gpa: gpa,
            base: BaseScope(
                parent: None,
                name: None,
                concurrent: false,
                mode: ScopeMode.normal,
                only: OnlyMode.no,
                hasCallback: false,
                testIdForDebugger: 0,
                lineNo: 0
            )
        )
    }

    public func deinit() {
        // hookScope的条目应该为空
        activeFile = None
    }

    /// 为测试隔离重置钩子作用域
    ///
    /// 在加载preload之前调用，重置hookScope为全新的空作用域。
    /// 下一个文件的loadPreloads()将重新注册钩子到新的全局对象。
    public func resetHookScopeForTestIsolation() {
        hookScope = DescribeScope.create(gpa: gpa,
            base: BaseScope(
                parent: None,
                name: None,
                concurrent: false,
                mode: ScopeMode.normal,
                only: OnlyMode.no,
                hasCallback: false,
                testIdForDebugger: 0,
                lineNo: 0
            )
        )
    }

    /// 进入文件
    ///
    /// 创建新的BunTest实例并设置为活跃文件。
    /// 使用稳定的根指针（从全局runner存储中派生）以避免重入时的指针失效。
    public func enterFile(fileId: UInt32, reporter: CommandLineReporter, defaultConcurrent: Bool, firstLast: FirstLast) {
        activeFile = None

        let reporterPtr = reporter
        let bunTest = BunTest(
            bunTestRoot: this,
            gpa: gpa,
            fileId: fileId,
            reporter: reporterPtr,
            defaultConcurrent: defaultConcurrent,
            firstLast: firstLast
        )
        activeFile = BunTestPtr(ptr: bunTest)
    }

    /// 退出文件
    ///
    /// 清除reporter引用并释放活跃文件
    public func exitFile() {
        if (let Some(active) <- activeFile) {
            if (let Some(bt) <- active.get()) {
                bt.reporter = None
            }
        }
        activeFile = None
    }

    /// 获取活跃文件（除非在预加载阶段）
    ///
    /// 如果VM处于preload状态，返回None。
    /// 否则返回当前活跃的BunTest文件的可变引用。
    public func getActiveFileUnlessInPreload(vm: VirtualMachine): ?BunTest {
        if (vm.isInPreload) {
            return None
        }
        return activeFile?.get()
    }

    /// 克隆活跃文件
    public func cloneActiveFile(): ?BunTestPtr {
        return activeFile
    }

    /// 在打印之前调用
    ///
    /// 如果reporter使用dots模式且已经打印了点，先打印换行。
    /// 然后检查是否需要打印当前文件名。
    public func onBeforePrint() {
        if (let Some(activeFile) <- activeFile) {
            if (let Some(bt) <- activeFile.get()) {
                let reporter = bt.reporter
                if (let Some(reporter) <- reporter) {
                    if (reporter.reporters.dots && reporter.lastPrintedDot) {
                        Output.prettyError("<r>\n")
                        Output.flush()
                        reporter.lastPrintedDot = false
                    }
                    // 检查是否需要打印当前文件名
                    if (let Some(runner) <- Jest.runner) {
                        runner.currentFile.printIfNeeded()
                    }
                }
            }
        }
    }

    /// 首尾标记
    public class FirstLast {
        public var first: Bool = false
        public var last: Bool = false

        public init(first: Bool, last: Bool) {
            this.first = first
            this.last = last
        }
    }
}

// ========== BunTest - 单个测试文件的状态 ==========

/// BunTest管理单个测试文件的生命周期
///
/// 每个被测试的文件都会创建一个BunTest实例，它包含:
/// - 文件ID和reporter引用
/// - 当前测试阶段（Collection/Execution/Done）
/// - Collection实例（收集阶段的测试树）
/// - Execution实例（执行阶段的调度器）
/// - 事件循环定时器
/// - 结果队列
public class BunTest {
    public var bunTestRoot: BunTestRoot
    public var inRunLoop: Bool = false
    public var gpa: Allocator
    public var arena: Allocator
    public var fileId: UInt32 = 0
    public var reporter: ?CommandLineReporter = None
    public var timer: EventLoopTimer = EventLoopTimer()
    public var resultQueue: ResultQueue = ResultQueue()
    public var defaultConcurrent: Bool = false
    public var firstLast: BunTestRoot.FirstLast
    public var extraExecutionEntries: ArrayList<ExecutionEntry> = ArrayList<ExecutionEntry>()
    public var wantsWakeup: Bool = false

    public var phase: TestPhase = TestPhase.collection
    public var collection: Collection
    public var execution: Execution

    public init(gpa: Allocator, bunTest: BunTestRoot, fileId: UInt32, reporter: CommandLineReporter, defaultConcurrent: Bool, firstLast: BunTestRoot.FirstLast) {
        this.bunTestRoot = bunTest
        this.gpa = gpa
        this.arena = gpa
        this.fileId = fileId
        this.reporter = reporter
        this.defaultConcurrent = defaultConcurrent
        this.firstLast = firstLast
        this.collection = Collection(gpa: gpa, bunTestRoot: bunTest)
        this.execution = Execution()
    }

    public func deinit() {
        // 如果定时器还在激活状态，需要移除以防止UAF
        if (timer.state == EventLoopTimerState.active) {
            vmTimer().remove(ref: timer)
        }

        // 释放额外的执行条目
        for (entry in extraExecutionEntries ) {
            entry.destroy(gpa: gpa)
        }
    }

    /// 获取当前状态数据
    ///
    /// 根据当前阶段返回不同的RefDataValue:
    /// - Collection: 包含活跃的DescribeScope
    /// - Execution: 包含组索引和条目数据
    ///   - 如果只有一个非并发序列，包含精确的序列位置信息
    ///   - 如果是并发组，只包含组索引
    /// - Done: 返回Done标记
    public func getCurrentStateData(): RefDataValue {
        match (phase) {
            case collection =>
                return RefDataValue.collection(RefDataCollection(activeScope: collection.activeScope))
            case execution =>
                let activeGroup = execution.activeGroupRef()
                if (activeGroup == None) {
                    return RefDataValue.done
                }
                let group = activeGroup.getOrThrow()
                let groupSequences = group.sequences(execution: execution)

                if (groupSequences.size != 1) {
                    return RefDataValue.execution(RefDataExecution(
                        groupIndex: execution.groupIndex,
                        entryData: None // 并发测试，不知道确切的当前条目
                    ))
                }

                let sequence = groupSequences[0]
                let activeEntry = sequence.activeEntry
                if (activeEntry == None) {
                    return RefDataValue.execution(RefDataExecution(
                        groupIndex: execution.groupIndex,
                        entryData: None // 序列已完成
                    ))
                }

                return RefDataValue.execution(RefDataExecution(
                    groupIndex: execution.groupIndex,
                    entryData: RefDataEntry(
                        sequenceIndex: 0,
                        entry: activeEntry.getOrThrow(),
                        remainingRepeatCount: sequence.remainingRepeatCount
                    )
                ))
            case done =>
                return RefDataValue.done
        }
    }

    /// 创建引用
    public func ref(phase: RefDataValue): RefData {
        return RefData(phase: phase)
    }

    /// 添加结果
    public func addResult(result: RefDataValue) {
        resultQueue.writeItem(item: result)
    }

    /// 运行测试循环
    ///
    /// 主运行循环:
    /// 1. 设置inRunLoop标志（防止重入）
    /// 2. 从结果队列中读取结果
    /// 3. 根据阶段调用对应的step函数
    /// 4. 处理步骤结果（等待或完成）
    /// 5. 如果阶段完成，推进到下一阶段
    /// 6. 更新最小超时
    public func run(strong: BunTestPtr, globalThis: JSGlobalObject) {
        if (inRunLoop) { return }
        inRunLoop = true

        var minTimeout = Timespec.epoch

        while (let Some(result) <- resultQueue.readItem() ){
            globalThis.clearTerminationException()

            let stepResult: StepResult = match (phase) {
                case collection => Collection.step(buntestStrong: strong, globalThis: globalThis, data: result)
                case execution => execution.step(buntestStrong: strong, globalThis: globalThis, data: result)
                case done => StepResult.complete
            }

            match (stepResult) {
                case waiting(timeout) =>
                    minTimeout = Timespec.minIgnoreEpoch(a: minTimeout, b: timeout)
                case complete =>
                    if (advance(globalThis: globalThis) == AdvanceResult.exit) {
                        inRunLoop = false
                        return
                    }
                    addResult(result: RefDataValue.start)
            }
        }

        updateMinTimeout(globalThis: globalThis, minTimeout: minTimeout)
        inRunLoop = false
    }

    /// 更新最小超时
    ///
    /// 只在新超时早于当前超时时设置定时器。
    /// 遗憾的是无法取消不必要的定时器。
    public func updateMinTimeout(globalThis: JSGlobalObject, minTimeout: Timespec) {
        // 只在新超时早于当前超时时更新
        if (Timespec.orderIgnoreEpoch(a: minTimeout, b: timer.next) == Ordering.lt) {
            if (timer.next != Timespec.epoch) {
                vmTimer().remove(ref: timer)
            }
            timer.next = minTimeout
            if (timer.next != Timespec.epoch) {
                vmTimer().insert(ref: timer)
            }
        }
    }

    /// 推进到下一阶段
    ///
    /// Collection -> Execution:
    ///   1. 转储describe树（调试）
    ///   2. 检查是否有过滤器
    ///   3. 生成per-file的PRNG用于随机化
    ///   4. 调用Order生成执行顺序
    ///   5. 将顺序加载到Execution中
    ///
    /// Execution -> Done
    public func advance(globalThis: JSGlobalObject): AdvanceResult {
        match (phase) {
            case collection =>
                phase = .execution

                // 调试输出
                Debug.dumpDescribe(scope: collection.rootScope)

                // 检查过滤器
                let hasFilter = if (let Some(reporter) <- reporter) {
                    reporter.jest.filterRegex != None
                } else {
                    false
                }

                // 检查随机化种子
                var perFilePrng: ?DefaultPrng = None
                if (let Some(reporter) <- reporter) {
                    if (let Some(seed) <- reporter.jest.randomizeSeed) {
                        let path = reporter.jest.files[fileId].source.path.text
                        perFilePrng = DefaultPrng.init(
                            seed: WyHash.hash(data: Path.basename(path: path)).wrappingAdd(UInt64(seed))
                        )
                    }
                }

                // 生成执行顺序
                var order = Order.Order.init(cfg: Order.Config(
                    alwaysUseHooks: collection.rootScope.base.only == OnlyMode.no && !hasFilter,
                    randomize: perFilePrng
                ))

                let root = bunTestRoot
                let beforeAllOrder: Order.AllOrderResult = if (firstLast.first) {
                    order.generateAllOrder(hooks: root.hookScope.beforeAll)
                } else {
                    Order.AllOrderResult.empty
                }
                beforeAllOrder.setFailureSkipTo(order: order)
                order.generateOrderDescribe(scope: collection.rootScope)
                let afterAllOrder: Order.AllOrderResult = if (firstLast.last) {
                    order.generateAllOrder(hooks: root.hookScope.afterAll)
                } else {
                    Order.AllOrderResult.empty
                }
                afterAllOrder.setFailureSkipTo(order: order)

                execution.loadFromOrder(order: order)
                Debug.dumpOrder(execution: execution)
                return AdvanceResult.cont

            case execution =>
                inRunLoop = false
                phase = .done
                return AdvanceResult.exit

            case done =>
                return AdvanceResult.exit
        }
    }

    /// 运行测试回调
    ///
    /// 执行测试或钩子的回调函数:
    /// 1. 如果有done参数，创建DoneCallback并绑定
    /// 2. 更新超时
    /// 3. 调用回调函数并drain微任务
    /// 4. 处理未处理的Promise rejection
    /// 5. 根据结果类型（同步/异步Promise/done回调）返回相应结果
    ///
    /// 返回:
    /// - Some(RefDataValue): 同步完成
    /// - None: 异步等待（Promise或done回调）
    public func runTestCallback(strong: BunTestPtr, globalThis: JSGlobalObject, callback: JSValue, doneParameter: Bool, data: RefDataValue, timeout: Timespec): ?RefDataValue {
        var doneArg: JSValue = JSValue.zero
        var doneCallback: JSValue = JSValue.zero

        if (doneParameter) {
            doneCallback = DoneCallback.createUnbound(globalThis: globalThis)
            let bindResult = DoneCallback.bind(value: doneCallback, globalThis: globalThis)
            if (bindResult == None) {
                onUncaughtException(globalThis: globalThis, exception: None, isRejection: false, userData: data)
                doneCallback = JSValue.zero
            } else {
                doneArg = bindResult.getOrThrow()
            }
        }

        updateMinTimeout(globalThis: globalThis, minTimeout: timeout)

        // 执行回调
        let result: JSValue
        let argsSlice: Array<JSValue> = if (!doneArg.isEmpty()) { [doneArg] } else { [] }
        result = globalThis.bunVM().eventLoop.runCallbackWithResultAndDrainMicrotasks(
            callback: callback,
            global: globalThis,
            thisValue: JSValue.jsUndefined,
            args: argsSlice
        )

        doneCallback.ensureStillAlive()

        // Drain未处理的Promise rejection
        while (true) {
            if (!result.isEmpty()) {
                if (let Some(promise) <- result.asPromise()) {
                    if (promise.status() == PromiseStatus.rejected) {
                        promise.setHandled()
                    }
                }
            }

            let prevUnhandledCount = globalThis.bunVM().unhandledErrorCounter
            globalThis.handleRejectedPromises()
            if (globalThis.bunVM().unhandledErrorCounter == prevUnhandledCount) {
                break
            }
        }

        // done回调引用处理
        var dcbRef: ?RefData = None
        if (!doneCallback.isEmpty() && !result.isEmpty()) {
            if (let Some(dcbData) <- DoneCallback.fromJS(value: doneCallback)) {
                if (dcbData.called) {
                    // done回调已经被调用或回调出错
                } else {
                    let r = ref(phase: data)
                    dcbData.ref = r
                    dcbRef = r
                }
            }
        }

        // 处理Promise结果
        if (!result.isEmpty()) {
            if (let Some(promise) <- result.asPromise()) {
                match (promise.status()) {
                    case pending =>
                        // 未立即resolve，注册then回调
                        let thisRef: RefData = if (let Some(dcbRefValue) <- dcbRef) {
                            dcbRefValue.dupe()
                        } else {
                            ref(phase: data)
                        }
                        result.then(
                            global: globalThis,
                            onFulfilled: thisRef,
                            onRejected: thisRef
                        )
                        return None // 异步等待
                    case fulfilled =>
                        return data // 同步完成
                    case rejected =>
                        let value = promise.result(global: globalThis)
                        onUncaughtException(globalThis: globalThis, exception: value, isRejection: true, userData: data)
                        return data
                }
            }
        }

        // 等待done回调
        if (dcbRef != None) {
            return None
        }

        return data // 同步完成
    }

    /// 处理未捕获的异常
    ///
    /// 根据当前阶段和异常类型决定如何处理:
    /// 1. 获取HandleUncaughtExceptionResult
    /// 2. 如果应该隐藏错误，直接返回
    /// 3. 否则打印错误信息
    /// 4. 对于"测试间未处理错误"，增加计数器并显示分隔线
    public func onUncaughtException(globalThis: JSGlobalObject, exception: ?JSValue, isRejection: Bool, userData: RefDataValue) {
        let handleStatus: HandleUncaughtExceptionResult = match (phase) {
            case collection => collection.handleUncaughtException(userData: userData)
            case done => HandleUncaughtExceptionResult.showUnhandledErrorBetweenTests
            case execution => execution.handleUncaughtException(userData: userData)
        }

        if (handleStatus == .hideError) {
            return // 不打印错误
        }

        if (exception == None) {
            return // 异常不应该可见
        }

        bunTestRoot.onBeforePrint()

        if (handleStatus == .showUnhandledErrorBetweenTests || handleStatus == .showUnhandledErrorInDescribe) {
            if (let Some(reporter) <- reporter) {
                reporter.jest.unhandledErrorsBetweenTests += 1
            }
            Output.prettyError("<r>\n<b><d>#<r> <red><b>Unhandled error<r><d> between tests<r>\n<d>-------------------------------<r>\n")
            Output.flush()
        }

        globalThis.bunVM().runErrorHandler(exception: exception.getOrThrow(), exceptionList: None)

        if (handleStatus == .showUnhandledErrorBetweenTests || handleStatus == .showUnhandledErrorInDescribe) {
            Output.prettyError("<r><d>-------------------------------<r>\n\n")
        }

        Output.flush()
    }

    /// 重置序列
    public func resetSequence(sequence: ExecutionSequence) {
        execution.resetSequence(sequence: sequence)
    }
}

// ========== 测试阶段枚举 ==========

/// 测试运行阶段
public enum TestPhase {
    | collection
    | execution
    | done

    public func toString(): String {
        match (this) {
            case collection => return "collection"
            case execution => return "execution"
            case done => return "done"
        }
    }
}

// ========== RefDataValue - 引用数据值 ==========

/// 引用数据值，用于跟踪测试执行状态
public enum RefDataValue {
    | start
    | collection(RefDataCollection)
    | execution(RefDataExecution)
    | done

    /// 是否为Start
    public func isStart(): Bool {
        match (this) {
            case start => return true
            case _ => return false
        }
    }

    /// 获取所属组
    public func group(buntest: BunTest): ?ConcurrentGroup {
        match (this) {
            case execution(entryData) => return buntest.execution.groups[entryData.groupIndex]
            case _ => return None
        }
    }

    /// 获取所属序列
    public func sequence(buntest: BunTest): ?ExecutionSequence {
        match (this) {
            case execution(groupIndex, entryData) =>
                if (entryData == None) { return None }
                let ed = entryData.getOrThrow()
                let group = buntest.execution.groups[groupIndex]
                let absIdx = group.sequenceStart + ed.sequenceIndex
                if (absIdx >= group.sequenceEnd) { return None }
                return buntest.execution.sequences[absIdx]
            case _ => return None
        }
    }

    /// 获取当前条目
    public func entry(buntest: BunTest): ?ExecutionEntry {
        match (this) {
            case execution =>
                if (buntest.phase != .execution) { return None }
                let result = buntest.execution.getCurrentAndValidExecutionSequence(data: this)
                if (result == None) { return None }
                let (sequence, _) = result.getOrThrow()
                return sequence.activeEntry
            case _ => return None
        }
    }

    /// 格式化为字符串
    public func format(): String {
        match (this) {
            case start => return "start"
            case collection(data) =>
                let name = data.activeScope.base.name ?? "(null)"
                return "collection: active_scope=" + (name)
            case execution(groupIndex, entryData) =>
                if (let Some(ed) <- entryData) {
                    return "execution: group_index=" + (groupIndex) + ",sequence_index=" + (ed.sequenceIndex) + ",entry=" + (ed.entry) + ",remaining_repeat_count=" + (ed.remainingRepeatCount)
                } else {
                    return "execution: group_index=" + (groupIndex)
                }
            case done => return "done"
        }
    }
}

/// 集合引用数据
public class RefDataCollection {
    public var activeScope: DescribeScope

    public init(activeScope: DescribeScope) {
        this.activeScope = activeScope
    }
}

/// 执行引用数据
public class RefDataExecution {
    public var groupIndex: UInt64 = 0
    public var entryData: ?RefDataEntry = None
}

/// 引用数据条目
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

// ========== RefData - 引用数据 ==========

/// 引用数据，跟踪测试状态
///
/// 侵入式引用计数，当最后一个引用被释放时调用destroy
public class RefData {
    public var buntestWeak: BunTestPtrWeak
    public var phase: RefDataValue
    public var refCount: Int64 = 1

    public init(phase: RefDataValue) {
        this.buntestWeak = BunTestPtrWeak(strong: None)
        this.phase = phase
    }

    /// 析构 - 最后一个引用释放时调用
    public func destroy() {
    }

    public func deref() {
        refCount -= 1
        if (refCount == 0) {
            destroy()
        }
    }

    public func dupe(): RefData {
        refCount += 1
        return this
    }

    public func hasOneRef(): Bool {
        return refCount == 1
    }

    public func bunTest(): ?BunTestPtr {
        return buntestWeak.upgrade()
    }
}

// ========== HandleUncaughtExceptionResult ==========

/// 未捕获异常处理结果
public enum HandleUncaughtExceptionResult {
    | hideError                      // 隐藏错误（已消费）
    | showHandledError               // 显示已处理的错误
    | showUnhandledErrorBetweenTests // 显示测试间的未处理错误
    | showUnhandledErrorInDescribe   // 显示describe中的未处理错误
}

// ========== ResultQueue - 结果队列 ==========

/// 线性FIFO结果队列
public class ResultQueue {
    private var items: ArrayList<RefDataValue> = ArrayList<RefDataValue>()

    public init() {}

    public func writeItem(item: RefDataValue) {
        items.append(item)
    }

    public func readItem(): ?RefDataValue {
        if (items.size() > 0) {
            return items.removeAt(0)
        }
        return None
    }

    public func deinit() {
        items.clear()
    }
}

// ========== StepResult - 步骤结果 ==========

/// 测试步骤执行结果
public enum StepResult {
    | waiting(Timespec) // 等待，需要等待指定时间
    | complete          // 当前阶段完成

    /// 默认值
    public init() {
        this = .waiting(Timespec.epoch)
    }
}

// ========== AdvanceResult - 推进结果 ==========

/// 阶段推进结果
public enum AdvanceResult {
    | cont  // 继续到下一阶段
    | exit  // 退出运行循环
}

// ========== ConcurrentMode - 并发模式 ==========

/// 测试并发模式
public enum ConcurrentMode {
    | inherit  // 继承父级
    | no       // 串行
    | yes      // 并发
}

// ========== BaseScopeCfg - 基础作用域配置 ==========

/// 基础作用域配置
public class BaseScopeCfg {
    public var selfConcurrent: ConcurrentMode = ConcurrentMode.inherit
    public var selfMode: ScopeMode = ScopeMode.normal
    public var selfOnly: Bool = false
    public var testIdForDebugger: Int32 = 0
    public var lineNo: UInt32 = 0

    public init() {}

    /// 扩展配置
    ///
    /// 合并两个配置。如果other设置了某个值而result还没有设置，则使用other的值。
    /// 如果两者都设置了同一个值，返回None（冲突）。
    public func extend(other: BaseScopeCfg): ?BaseScopeCfg {
        var result = BaseScopeCfg()
        result.selfConcurrent = this.selfConcurrent
        result.selfMode = this.selfMode
        result.selfOnly = this.selfOnly
        result.testIdForDebugger = this.testIdForDebugger
        result.lineNo = this.lineNo

        if (other.selfConcurrent != ConcurrentMode.inherit) {
            if (result.selfConcurrent != ConcurrentMode.inherit) {
                return None
            }
            result.selfConcurrent = other.selfConcurrent
        }
        if (other.selfMode != ScopeMode.normal) {
            if (result.selfMode != ScopeMode.normal) {
                return None
            }
            result.selfMode = other.selfMode
        }
        if (other.selfOnly) {
            if (result.selfOnly) {
                return None
            }
            result.selfOnly = true
        }
        return result
    }
}

// ========== ScopeMode - 作用域模式 ==========

/// 作用域运行模式
public enum ScopeMode {
    | normal
    | skip
    | todo
    | failing
    | filteredOut

    public func toString(): String {
        match (this) {
            case normal => return "normal"
            case skip => return "skip"
            case todo => return "todo"
            case failing => return "failing"
            case filteredOut => return "filtered_out"
        }
    }
}

// ========== OnlyMode - Only模式 ==========

/// Only标记
public enum OnlyMode {
    | no
    | contains
    | yes
}

// ========== BaseScope - 基础作用域 ==========

/// 基础作用域
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
        this.concurrent = false
        this.mode = cfg.selfMode
        this.only = if (cfg.selfOnly) { OnlyMode.yes } else { OnlyMode.no }
        this.hasCallback = hasCallback
        this.testIdForDebugger = cfg.testIdForDebugger
        this.lineNo = cfg.lineNo

        // 从父级继承并发设置
        if (let Some(parentScope) <- parent) {
            if (cfg.selfConcurrent == ConcurrentMode.inherit) {
                this.concurrent = parentScope.base.concurrent
            } else {
                this.concurrent = cfg.selfConcurrent == ConcurrentMode.yes
            }
            // 如果父级模式不是normal，继承父级模式
            if (parentScope.base.mode != ScopeMode.normal && cfg.selfMode == ScopeMode.normal) {
                this.mode = parentScope.base.mode
            }
        }
    }

    /// 传播only和callback标记到父级
    public func propagate(hasCallback: Bool) {
        this.hasCallback = hasCallback
        if (let Some(parent) <- this.parent) {
            if (this.only != OnlyMode.no) {
                parent.markContainsOnly()
            }
            if (this.hasCallback) {
                parent.markHasCallback()
            }
        }
    }

    public func deinit(gpa: Allocator) {
        this.name = None
    }
}

// ========== DescribeScope - describe作用域 ==========

/// describe()作用域，包含子测试和钩子
public class DescribeScope {
    public var base: BaseScope
    public var entries: ArrayList<TestScheduleEntry> = ArrayList<TestScheduleEntry>()
    public var beforeAll: ArrayList<ExecutionEntry> = ArrayList<ExecutionEntry>()
    public var beforeEach: ArrayList<ExecutionEntry> = ArrayList<ExecutionEntry>()
    public var afterEach: ArrayList<ExecutionEntry> = ArrayList<ExecutionEntry>()
    public var afterAll: ArrayList<ExecutionEntry> = ArrayList<ExecutionEntry>()
    public var failed: Bool = false

    public init() {
        this.base = BaseScope()
    }

    /// 创建新的DescribeScope
    public static func create(gpa: Allocator, base: BaseScope): DescribeScope {
        let scope = DescribeScope()
        scope.base = base
        return scope
    }

    /// 销毁DescribeScope
    public func destroy(gpa: Allocator) {
        // 释放所有条目和钩子
        entries.clear()
        beforeAll.clear()
        beforeEach.clear()
        afterEach.clear()
        afterAll.clear()
        base.deinit(gpa: gpa)
    }

    /// 标记包含only
    ///
    /// 向上遍历父级链，标记每个父级为contains only
    public func markContainsOnly() {
        var target: ?DescribeScope = this
        while (let Some(scope) <- target ){
            if (scope.base.only == OnlyMode.contains) {
                return
            }
            scope.base.only = OnlyMode.contains
            target = scope.base.parent
        }
    }

    /// 标记有回调
    ///
    /// 向上遍历父级链，标记每个父级有回调
    public func markHasCallback() {
        var target: ?DescribeScope = this
        while (let Some(scope) <- target ){
            if (scope.base.hasCallback) {
                return
            }
            scope.base.hasCallback = true
            target = scope.base.parent
        }
    }

    /// 追加describe
    public func appendDescribe(name: ?String, base: BaseScopeCfg): DescribeScope {
        let child = DescribeScope.create(gpa: Allocator.default, base: BaseScope(
            cfg: base, gpa: Allocator.default, name: name, parent: this, hasCallback: false
        ))
        child.base.propagate(hasCallback: false)
        entries.append(TestScheduleEntry.describe(child))
        return child
    }

    /// 追加测试
    public func appendTest(name: ?String, callback: ?JSValue, cfg: ExecutionEntryCfg, base: BaseScopeCfg, phase: AddedInPhase): ExecutionEntry {
        let entry = ExecutionEntry.create(gpa: Allocator.default, name: name, cb: callback, cfg: cfg, parent: this, base: base, phase: phase)
        entry.base.propagate(hasCallback: callback != None)
        entries.append(TestScheduleEntry.testCallback(entry))
        return entry
    }

    /// 钩子标签
    public enum HookTag {
        | beforeAll
        | beforeEach
        | afterEach
        | afterAll
    }

    /// 获取钩子条目列表
    public func getHookEntries(tag: HookTag): ArrayList<ExecutionEntry> {
        switch tag {
        case beforeAll => return beforeAll
        case beforeEach => return beforeEach
        case afterEach => return afterEach
        case afterAll => return afterAll
        }
    }

    /// 追加钩子
    public func appendHook(tag: HookTag, callback: ?JSValue, cfg: ExecutionEntryCfg, base: BaseScopeCfg, phase: AddedInPhase): ExecutionEntry {
        let entry = ExecutionEntry.create(gpa: Allocator.default, name: None, cb: callback, cfg: cfg, parent: this, base: base, phase: phase)
        getHookEntries(tag: tag).append(entry)
        return entry
    }
}

// ========== ExecutionEntryCfg - 执行条目配置 ==========

/// 执行条目配置
public class ExecutionEntryCfg {
    public var timeout: UInt32 = 0       // 0 = 无限超时
    public var hasDoneParameter: Bool = false
    public var retryCount: UInt32 = 0    // 重试次数
    public var repeatCount: UInt32 = 0   // 重复次数

    public init() {}
}

// ========== ExecutionEntry - 执行条目 ==========

/// 执行条目，表示一个测试或钩子
public class ExecutionEntry {
    public var base: BaseScope
    public var callback: ?JSValue = None
    public var timeout: UInt32 = 0
    public var hasDoneParameter: Bool = false
    public var timespec: Timespec = Timespec.epoch
    public var addedInPhase: AddedInPhase = AddedInPhase.preload
    public var retryCount: UInt32 = 0
    public var repeatCount: UInt32 = 0
    public var next: ?ExecutionEntry = None
    public var failureSkipPast: ?ExecutionEntry = None

    public init() {
        this.base = BaseScope()
    }

    /// 添加阶段
    public enum AddedInPhase {
        | preload
        | collection
        | execution
    }

    /// 创建执行条目
    public static func create(gpa: Allocator, name: ?String, cb: ?JSValue, cfg: ExecutionEntryCfg, parent: ?DescribeScope, base: BaseScopeCfg, phase: AddedInPhase): ExecutionEntry {
        let entry = ExecutionEntry()
        entry.base = BaseScope(cfg: base, gpa: gpa, name: name, parent: parent, hasCallback: cb != None)
        entry.timeout = cfg.timeout
        entry.hasDoneParameter = cfg.hasDoneParameter
        entry.addedInPhase = phase
        entry.retryCount = cfg.retryCount
        entry.repeatCount = cfg.repeatCount
        entry.callback = cb
        return entry
    }

    /// 评估超时
    public func evaluateTimeout(sequence: ExecutionSequence, now: Timespec): Bool {
        if (!timespec.isEpoch() && timespec.order(other: now) == .lt) {
            // 超时
            let isTestEntry = sequence.testEntry?.base == self.base
            if (isTestEntry) {
                sequence.result = hasDoneParameter ? .failBecauseTimeoutWithDoneCallback : .failBecauseTimeout
            } else {
                sequence.result = hasDoneParameter ? .failBecauseHookTimeoutWithDoneCallback : .failBecauseHookTimeout
            }
            sequence.maybeSkip = true
            return true
        }
        return false
    }

    /// 销毁
    public func destroy(gpa: Allocator) {
        base.deinit(gpa: gpa)
    }
}

// ========== TestScheduleEntry - 测试调度条目 ==========

/// 测试调度条目 - describe或test
public enum TestScheduleEntry {
    | describe(DescribeScope)
    | testCallback(ExecutionEntry)

    /// 销毁
    public func deinit(gpa: Allocator) {
        switch this {
        case describe(scope) => scope.destroy(gpa => gpa)
        case testCallback(entry) => entry.destroy(gpa => gpa)
        }
    }

    /// 获取基础作用域
    public func base(): BaseScope {
        switch this {
        case describe(scope) => return scope.base
        case testCallback(entry) => return entry.base
        }
    }
}

// ========== RunOneResult ==========

/// 单次运行结果
public enum RunOneResult {
    | done
    | execute(Timespec)
}

// ========== 引用的子模块声明 ==========

// 这些类型在其他文件中定义
public typealias FakeTimersType = FakeTimers
public typealias ExecutionType = Execution
public typealias CollectionType = Collection
public typealias ScopeFunctionsType = ScopeFunctions
public typealias OrderType = Order
public typealias DebugType = Debug

/// 获取VM定时器
public func vmTimer(): EventLoopTimers {
    return VirtualMachine.get().timer
}
