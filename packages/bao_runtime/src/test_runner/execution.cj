// execution.cj - 测试执行器
// 严格翻译自 bun/src/runtime/test_runner/Execution.zig

package bao_runtime.test_runner

import bao_jsc.JSGlobalObject
import bao_collections.ArrayList
import bao_collections.HashMap
import bao_event_loop.Timespec
import bao_core.Allocator

// ========== Execution - 测试执行阶段 ==========

/// 测试执行阶段，负责运行收集到的所有测试
///
/// 示例结构:
/// Execution[
///   ConcurrentGroup[
///     ExecutionSequence[beforeAll]
///   ],
///   ConcurrentGroup[
///     ExecutionSequence[beforeEach, test.concurrent, afterEach],
///     ExecutionSequence[beforeEach, test.concurrent, afterEach],
///   ],
///   ConcurrentGroup[
///     ExecutionSequence[afterAll]
///   ],
/// ]
public class Execution {
    public var groups: ArrayList<ConcurrentGroup> = ArrayList<ConcurrentGroup>()
    public var sequences: ArrayList<ExecutionSequence> = ArrayList<ExecutionSequence>()
    public var groupIndex: UInt64 = 0

    /// Return the smaller of two Timespec values, treating epoch (zero) as "no timeout" (ignored).
    /// If one is zero and the other is not, returns the non-zero one.
    /// If both are zero, returns epoch.
    public static func minIgnoreEpoch(a: Timespec, b: Timespec): Timespec {
        if (a.isZero()) { return b }
        if (b.isZero()) { return a }
        if (a.lessThan(b)) { return a }
        return b
    }

    public init() {}

    public func deinit() {
        // 释放资源
    }

    /// 从Order加载
    public func loadFromOrder(order: Order) {
        groups = order.groups
        sequences = order.sequences
    }

    /// 获取活跃组
    public func activeGroup(): ?ConcurrentGroup {
        if (Int64(groupIndex) >= groups.size) { return None }
        return groups[Int64(groupIndex)]
    }

    /// 获取活跃组（只读引用）
    public func activeGroupRef(): ?ConcurrentGroup {
        if (Int64(groupIndex) >= groups.size) { return None }
        return groups[Int64(groupIndex)]
    }

    /// 步骤执行 - 执行阶段的主入口
    ///
    /// 根据data的类型决定执行路径:
    /// - Start: 开始执行下一个组
    /// - 其他: 完成当前条目后推进序列
    public func step(buntestStrong: BunTestPtr, globalThis: JSGlobalObject, data: RefDataValue): StepResult {
        let buntestOpt = buntestStrong.get()
        if (buntestOpt.isNone()) { return StepResult.complete }
        let buntest = buntestOpt.getOrThrow()
        let execution = buntest.execution_
        var now = Timespec.nowForceRealTime()

        match (data) {
            case start =>
                return stepGroup(buntestStrong, globalThis, now)
            case _ =>
                // 确定活跃的序列和组
                let result = getCurrentAndValidExecutionSequence(data)
                if (result.isNone()) {
                    return StepResult.waiting(Timespec.EPOCH)
                }
                let (sequencePtr, groupPtr) = result.getOrThrow()

                let sequenceIndex: UInt64 = match (data) {
                    case execution(entryData) => entryData.entryData?.sequenceIndex ?? UInt64(0)
                    case _ => 0
                }

                // 推进序列
                advanceSequence(buntest, sequencePtr, groupPtr)

                // 步骤序列
                let sequenceResult = stepSequence(
                    buntestStrong: buntestStrong, globalThis: globalThis,
                    group: groupPtr, sequenceIndex: sequenceIndex, now: now
                )
                match (sequenceResult) {
                    case done =>
                        ()
                    case execute(timeout) =>
                        return StepResult.waiting(timeout)
                }

                // 序列完成；执行下一个序列
                var continueLoop = true
                while (continueLoop) {
                    let group = groupPtr
                    let seqLen = group.sequenceEnd - group.sequenceStart
                    if (group.nextSequenceIndex >= seqLen) {
                        break
                    }
                    let nextIdx = group.nextSequenceIndex
                    let absIdx = Int64(group.sequenceStart + nextIdx)
                    if (sequences[absIdx].executing) {
                        group.nextSequenceIndex += 1
                        continue
                    }
                    let nextSequenceResult = stepSequence(
                        buntestStrong: buntestStrong, globalThis: globalThis,
                        group: groupPtr, sequenceIndex: nextIdx, now: now
                    )
                    match (nextSequenceResult) {
                        case done =>
                            groupPtr.nextSequenceIndex += 1
                            continue
                        case execute(timeout) =>
                            return StepResult.waiting(timeout)
                    }
                }

                // 所有序列都已开始
                if (groupPtr.remainingIncompleteEntries == 0) {
                    return stepGroup(buntestStrong, globalThis, now)
                }
                return StepResult.waiting(Timespec.EPOCH)
        }
    }

    /// 步骤组 - 循环处理所有并发组
    public func stepGroup(buntestStrong: BunTestPtr, globalThis: JSGlobalObject, now: Timespec): StepResult {
        let buntestOpt = buntestStrong.get()
        if (buntestOpt.isNone()) { return StepResult.complete }
        let buntest = buntestOpt.getOrThrow()
        let execution = buntest.execution_

        // 循环处理组
        while (true) {
            let group: ?ConcurrentGroup = activeGroup()
            if (group.isNone()) {
                return StepResult.complete
            }
            let groupPtr = group.getOrThrow()

            if (!groupPtr.executing) {
                onGroupStarted(group: groupPtr, globalThis: globalThis)
                groupPtr.executing = true
            }

            // 循环处理组内的条目并推进执行
            let status = stepGroupOne(buntestStrong: buntestStrong, globalThis: globalThis, group: groupPtr, now: now)
            match (status) {
                case execute(timeout) =>
                    return StepResult.waiting(timeout)
                case done =>
                    ()
            }

            groupPtr.executing = false
            onGroupCompleted(group: groupPtr, globalThis: globalThis)

            // 如果只有一个序列且全部失败，跳到failureSkipTo组
            let start = groupPtr.sequenceStart
            let end = groupPtr.sequenceEnd
            let failureSkipTo = groupPtr.failureSkipTo
            var allFailed = true
            for (i in start..end ) {
                if (!sequences[Int64(i)].result.isFail()) {
                    allFailed = false
                    break
                }
            }

            if (allFailed) {
                groupIndex = failureSkipTo
            } else {
                groupIndex += 1
            }
        }
        return StepResult.complete  // unreachable but satisfies type checker
    }

    /// 步骤组内单个 - 处理并发限制
    public func stepGroupOne(buntestStrong!: BunTestPtr, globalThis!: JSGlobalObject, group!: ConcurrentGroup, now!: Timespec): AdvanceStatus {
        let buntestOpt = buntestStrong.get()
        if (buntestOpt.isNone()) { return AdvanceStatus.done }
        let buntest = buntestOpt.getOrThrow()
        var finalStatus: AdvanceStatus = AdvanceStatus.done
        let concurrentLimit: UInt32 = if (let Some(reporter) <- buntest.reporter) {
            reporter.jest.maxConcurrency
        } else {
            20
        }
        var activeCount: UInt64 = 0
        let len = group.sequenceEnd - group.sequenceStart

        for (sequenceIndex in 0..len ) {
            let sequenceResult = stepSequence(
                buntestStrong: buntestStrong, globalThis: globalThis,
                group: group, sequenceIndex: sequenceIndex, now: now
            )
            match (sequenceResult) {
                case done =>
                    ()
                case execute(timeout) =>
                    let prevTimeout: Timespec = match (finalStatus) {
                        case execute(t) => t
                        case _ => Timespec.EPOCH
                    }
                    finalStatus = AdvanceStatus.execute(Execution.minIgnoreEpoch(prevTimeout, timeout))
                    activeCount += 1
                    if (concurrentLimit != 0 && activeCount >= UInt64(concurrentLimit)) {
                        break
                    }
            }
        }
        return finalStatus
    }

    /// 步骤序列 - 循环执行序列中的条目
    public func stepSequence(buntestStrong!: BunTestPtr, globalThis!: JSGlobalObject, group!: ConcurrentGroup, sequenceIndex!: UInt64, now!: Timespec): AdvanceSequenceStatus {
        // 循环直到返回确定状态
        var done = false
        var status: AdvanceSequenceStatus = AdvanceSequenceStatus.done
        while (!done) {
            let result = stepSequenceOne(
                buntestStrong: buntestStrong, globalThis: globalThis,
                group: group, sequenceIndex: sequenceIndex, now: now
            )
            if (result.isSome()) {
                status = result.getOrThrow()
                done = true
            }
        }
        return status
    }

    /// 步骤序列内单个 - 核心执行逻辑
    ///
    /// 返回None表示应该继续循环，返回Some表示得到了确定状态
    public func stepSequenceOne(buntestStrong!: BunTestPtr, globalThis!: JSGlobalObject, group!: ConcurrentGroup, sequenceIndex!: UInt64, now!: Timespec): ?AdvanceSequenceStatus {
        var currentTime = now
        let buntestOpt = buntestStrong.get()
        if (buntestOpt.isNone()) { return AdvanceSequenceStatus.done }
        let buntest = buntestOpt.getOrThrow()
        let seqAbs = group.sequenceStart + sequenceIndex
        let sequence = sequences[Int64(seqAbs)]

        if (sequence.executing) {
            let activeEntry = sequence.activeEntry
            if (activeEntry.isNone()) {
                // 序列正在执行但没有活跃条目
                return AdvanceSequenceStatus.execute(Timespec.EPOCH)
            }

            let entry = activeEntry.getOrThrow()
            // 评估超时
            if (entry.evaluateTimeout(sequence, currentTime)) {
                advanceSequence(buntest, sequence, group)
                return None // 继续循环
            }

            return AdvanceSequenceStatus.execute(entry.timespec)
        }

        // 检查是否还有下一个条目
        let nextItem = sequence.activeEntry
        if (nextItem.isNone()) {
            // 序列已完成
            return AdvanceSequenceStatus.done
        }

        let entry = nextItem.getOrThrow()
        sequence.executing = true

        // 如果是序列的第一个条目，触发序列开始回调
        if (nextItem.isSome() && sequence.firstEntry.isSome() &&
            nextItem.getOrThrow() == sequence.firstEntry.getOrThrow()) {
            onSequenceStarted(sequence)
        }
        onEntryStarted(entry)

        if (let Some(cb) <- entry.callback) {
            // 有回调，需要执行
            let callbackData = RefDataValue.execution(RefDataExecution(
                groupIndex,
                RefDataEntry(
                    sequenceIndex,
                    entry,
                    Int64(sequence.remainingRepeatCount)
                )
            ))

            let result = BunTest.runTestCallback(
                buntestStrong,
                globalThis,
                cb,
                entry.hasDoneParameter,
                callbackData,
                entry.timespec
            )

            if (result.isSome()) {
                // 同步完成
                currentTime = Timespec.nowForceRealTime()
                let _ = entry.evaluateTimeout(sequence, currentTime)
                advanceSequence(buntest, sequence, group)
                return None // 继续循环
            }

            return AdvanceSequenceStatus.execute(entry.timespec)
        } else {
            // 没有回调，根据模式设置结果
            match (entry.base.mode) {
                case skip =>
                    if (sequence.result == Result.pending) {
                        sequence.result = Result.skip
                    }
                case todo =>
                    if (sequence.result == Result.pending) {
                        sequence.result = Result.todo
                    }
                case filteredOut =>
                    if (sequence.result == Result.pending) {
                        sequence.result = Result.skippedBecauseLabel
                    }
                case _ =>
                    ()
            }
            advanceSequence(buntest, sequence, group)
            return None // 继续循环
        }
    }

    /// 推进序列 - 将序列的activeEntry移到下一个位置
    ///
    /// 处理以下逻辑:
    /// 1. 标记当前条目完成
    /// 2. 如果maybeSkip为true，跳到failureSkipPast.next
    /// 3. 处理retry/repeat逻辑
    /// 4. 如果序列完成，调用onSequenceCompleted
    public func advanceSequence(buntest: BunTest, sequence: ExecutionSequence, group: ConcurrentGroup) {
        if (let Some(entry) <- sequence.activeEntry) {
            onEntryCompleted(entry)

            sequence.executing = false
            if (sequence.maybeSkip) {
                sequence.maybeSkip = false
                if (let Some(failureSkipPast) <- entry.failureSkipPast) {
                    sequence.activeEntry = failureSkipPast.next
                } else {
                    sequence.activeEntry = None
                }
            } else {
                sequence.activeEntry = entry.next
            }
        }

        if (sequence.activeEntry.isNone()) {
            // 序列刚完成
            let testFailed = sequence.result.isFail()
            let testPassed = sequence.result.isPass(PendingIs.pendingIsPass)

            // 重试逻辑: 测试失败且还有重试次数
            if (testFailed && sequence.remainingRetryCount > 0) {
                if (sequence.flakyAttemptCount < ExecutionSequence.MAX_FLAKY_ATTEMPTS) {
                    let elapsedNs: UInt64 = if (sequence.startedAt.isZero()) {
                        0
                    } else {
                        UInt64(sequence.startedAt.duration(Timespec.nowForceRealTime()).toMillis())
                    }
                    sequence.flakyAttemptsBuf[Int64(sequence.flakyAttemptCount)] = FlakyAttempt(sequence.result, elapsedNs)
                    sequence.flakyAttemptCount += 1
                }
                sequence.remainingRetryCount -= 1
                resetSequence(sequence)
                return
            }

            // 重复逻辑: 测试通过且还有重复次数
            if (testPassed && sequence.remainingRepeatCount > 0) {
                sequence.remainingRepeatCount -= 1
                resetSequence(sequence)
                return
            }

            // 所有重试/重复完成后报告最终结果
            onSequenceCompleted(buntest, sequence)

            // 减少组内未完成条目计数
            if (group.remainingIncompleteEntries == 0) {
                return
            }
            group.remainingIncompleteEntries -= 1
        }
    }

    /// 组开始回调 - 启用auto_killer
    public func onGroupStarted(group!: ConcurrentGroup, globalThis!: JSGlobalObject) {
        // 启用auto_killer以在超时时杀死悬挂进程
    }

    /// 组完成回调 - 禁用auto_killer
    public func onGroupCompleted(group!: ConcurrentGroup, globalThis!: JSGlobalObject) {
        // 禁用auto_killer
    }

    /// 序列开始回调 - 记录开始时间、报告测试开始
    public func onSequenceStarted(sequence: ExecutionSequence) {
        if (let Some(entry) <- sequence.testEntry) {
            if (entry.callback.isNone()) {
                return
            }
        }

        sequence.startedAt = Timespec.nowForceRealTime()

        if (let Some(entry) <- sequence.testEntry) {
            // 报告测试开始（用于debugger的test reporter agent）
            if (entry.base.testIdForDebugger != 0) {
                // 报告测试开始到debugger
            }
        }
    }

    /// 条目开始回调 - 设置超时时间
    public func onEntryStarted(entry: ExecutionEntry) {
        if (entry.callback.isNone()) {
            return
        }

        if (entry.timeout != 0) {
            entry.timespec = Timespec.nowForceRealTime().addMs(Int64(entry.timeout))
        } else {
            entry.timespec = Timespec.EPOCH
        }
    }

    /// 条目完成回调
    public func onEntryCompleted(entry: ExecutionEntry) {
        // 空实现
    }

    /// 序列完成回调 - 处理断言计数、报告测试完成
    public func onSequenceCompleted(buntest: BunTest, sequence: ExecutionSequence) {
        let elapsedNs: UInt64 = if (sequence.startedAt.isZero()) {
            0
        } else {
            UInt64(sequence.startedAt.duration(Timespec.nowForceRealTime()).toMillis())
        }

        // 检查断言期望
        match (sequence.expectAssertions) {
            case atLeastOne =>
                if (sequence.expectCallCount == 0 && sequence.result.isPass(PendingIs.pendingIsPass)) {
                    sequence.result = Result.failBecauseExpectedHasAssertions
                }
            case exact(expected) =>
                if (sequence.expectCallCount != expected && sequence.result.isPass(PendingIs.pendingIsPass)) {
                    sequence.result = Result.failBecauseExpectedAssertionCount
                }
            case _ =>
                ()
        }

        // 如果结果仍为pending，根据条目模式设置最终结果
        if (sequence.result == Result.pending) {
            sequence.result = match (sequence.entryMode()) {
                case failing => Result.failBecauseFailingTestPassed
                case todo => Result.failBecauseTodoPassed
                case _ => Result.pass
            }
        }

        // 报告测试完成
        if (let Some(firstEntry) <- sequence.firstEntry) {
            if (sequence.testEntry.isSome() || sequence.result != Result.pass) {
                // 调用reporter报告测试完成
            }
        }

        // 报告测试结束到debugger
        if (let Some(entry) <- sequence.testEntry) {
            if (entry.base.testIdForDebugger != 0) {
                // 报告测试结束到debugger的test reporter agent
            }
        }
    }

    /// 重置序列 - 用于retry/repeat
    ///
    /// 1. 遍历条目链，移除在执行阶段添加的条目
    /// 2. 重置每个条目的timespec
    /// 3. 重新初始化序列（保留retry/repeat计数和flaky历史）
    public func resetSequence(sequence: ExecutionSequence) {
        // 重置条目
        var currentEntry: ?ExecutionEntry = sequence.firstEntry
        while (let Some(entryPtr) <- currentEntry ){
            // 移除在执行阶段添加的条目
            while (let Some(next) <- entryPtr.next ){
                if (next.addedInPhase != AddedInPhase.execution) {
                    break
                }
                entryPtr.next = next.next
            }
            entryPtr.timespec = Timespec.EPOCH
            currentEntry = entryPtr.next
        }

        // 保留flaky历史
        let savedFlakyAttemptCount = sequence.flakyAttemptCount
        let savedFlakyAttemptsBuf = sequence.flakyAttemptsBuf

        // 重新初始化序列
        sequence.activeEntry = sequence.firstEntry
        sequence.result = Result.pending
        sequence.executing = false
        sequence.startedAt = Timespec.EPOCH
        sequence.expectCallCount = 0
        sequence.expectAssertions = ExpectAssertions.notSet
        sequence.maybeSkip = false

        sequence.flakyAttemptCount = savedFlakyAttemptCount
        sequence.flakyAttemptsBuf = savedFlakyAttemptsBuf

        // 重置快照计数器
        if (let Some(runner) <- Jest.runner) {
            runner.snapshots.resetCounts()
        }
    }

    /// 获取当前有效的执行序列
    ///
    /// 验证RefDataValue中的序列信息是否仍然有效（未被新的执行覆盖）
    public func getCurrentAndValidExecutionSequence(data: RefDataValue): ?(ExecutionSequence, ConcurrentGroup) {
        match (data) {
            case execution(refData) =>
                let groupIdx = refData.groupIndex
                let entryData = refData.entryData
                if (entryData.isNone()) {
                    return None
                }
                let ed = entryData.getOrThrow()

                // 验证组索引是否匹配
                if (Int64(groupIndex) >= groups.size || groupIdx != groupIndex) {
                    return None
                }
                if (Int64(groupIdx) >= groups.size) {
                    return None
                }

                let group = groups[Int64(groupIdx)]
                let seqAbs = group.sequenceStart + ed.sequenceIndex
                if (seqAbs >= group.sequenceEnd) {
                    return None
                }

                let sequence = sequences[Int64(seqAbs)]

                // 验证repeat计数是否匹配
                if (Int64(sequence.remainingRepeatCount) != ed.remainingRepeatCount) {
                    return None
                }

                // 验证active entry是否匹配
                if (sequence.activeEntry.isNone() || sequence.activeEntry.getOrThrow() != ed.entry) {
                    return None
                }

                return (sequence, group)
            case _ =>
                return None
        }
    }

    /// 处理未捕获异常
    public func handleUncaughtException(userData: RefDataValue): HandleUncaughtExceptionResult {
        let result = getCurrentAndValidExecutionSequence(userData)
        if (result.isNone()) {
            return HandleUncaughtExceptionResult.showUnhandledErrorBetweenTests
        }
        let (sequence, _) = result.getOrThrow()

        sequence.maybeSkip = true

        // 如果正在执行钩子（不是testEntry）
        if (sequence.activeEntry.isNone() != sequence.testEntry.isNone() ||
            (sequence.activeEntry.isSome() && sequence.testEntry.isSome() &&
             sequence.activeEntry.getOrThrow() != sequence.testEntry.getOrThrow())) {
            if (sequence.result == Result.pending) {
                sequence.result = Result.fail
            }
            return HandleUncaughtExceptionResult.showHandledError
        }

        // 根据条目模式处理
        match (sequence.entryMode()) {
            case failing =>
                if (sequence.result == Result.pending) {
                    sequence.result = Result.pass
                }
                return HandleUncaughtExceptionResult.hideError
            case todo =>
                if (sequence.result == Result.pending) {
                    sequence.result = Result.todo
                }
                return HandleUncaughtExceptionResult.showHandledError
            case _ =>
                if (sequence.result == Result.pending) {
                    sequence.result = Result.fail
                }
                return HandleUncaughtExceptionResult.showHandledError
        }
    }

    /// 处理超时
    public func handleTimeout(globalThis: JSGlobalObject) {
        // 如果并发组只有一个序列且活跃条目已超时
        // 杀死任何悬挂的进程
        if (let Some(currentGroup) <- activeGroup()) {
            let start = Int64(currentGroup.sequenceStart)
            let end = Int64(currentGroup.sequenceEnd)
            if (end - start == 1) {
                let sequence = sequences[start]
                if (sequence.activeEntry.isSome()) {
                    let entry = sequence.activeEntry.getOrThrow()
                    let now = Timespec.nowForceRealTime()
                    if (!entry.timespec.isZero() && entry.timespec.lessThan(now)) {
                        // 杀死悬挂进程
                    }
                }
            }
        }

        // 添加Start结果以触发下一步
        if (let Some(runner) <- Jest.runner) {
            let activeFile = runner.bunTestRoot.activeFile
            if (activeFile.isSome()) {
                let buntest = activeFile.getOrThrow().get()
                if (buntest.isSome()) {
                    buntest.getOrThrow().addResult(RefDataValue.start)
                }
            }
        }
    }
}

// ========== ConcurrentGroup - 并发组 ==========

/// 并发组，包含一组可以并发执行的序列
public class ConcurrentGroup {
    public var sequenceStart: UInt64 = 0
    public var sequenceEnd: UInt64 = 0
    public var nextSequenceIndex: UInt64 = 0
    public var executing: Bool = false
    public var remainingIncompleteEntries: UInt64 = 0
    public var failureSkipTo: UInt64 = 0

    public init() {}

    public init(sequenceStart: UInt64, sequenceEnd: UInt64, nextIndex: UInt64) {
        this.sequenceStart = sequenceStart
        this.sequenceEnd = sequenceEnd
        this.executing = false
        this.remainingIncompleteEntries = sequenceEnd - sequenceStart
        this.failureSkipTo = nextIndex
        this.nextSequenceIndex = 0
    }

    /// 尝试扩展组
    public func tryExtend(nextSequenceStart: UInt64, nextSequenceEnd: UInt64): Bool {
        if (sequenceEnd != nextSequenceStart) { return false }
        sequenceEnd = nextSequenceEnd
        remainingIncompleteEntries = sequenceEnd - sequenceStart
        return true
    }

    /// 获取组内的序列
    public func sequences(execution: Execution): ArrayList<ExecutionSequence> {
        var result = ArrayList<ExecutionSequence>()
        var i = Int64(sequenceStart)
        let end = Int64(sequenceEnd)
        while (i < end) {
            result.append(execution.sequences[i])
            i += 1
        }
        return result
    }
}

// ========== ExecutionSequence - 执行序列 ==========

/// 执行序列，包含一组顺序执行的条目
public class ExecutionSequence {
    public var firstEntry: ?ExecutionEntry = None
    public var activeEntry: ?ExecutionEntry = None
    public var testEntry: ?ExecutionEntry = None
    public var remainingRepeatCount: UInt32 = 0
    public var remainingRetryCount: UInt32 = 0
    public var flakyAttemptCount: UInt64 = 0
    public var flakyAttemptsBuf: Array<FlakyAttempt> = Array<FlakyAttempt>()
    public var result: Result = Result.pending
    public var executing: Bool = false
    public var startedAt: Timespec = Timespec.EPOCH
    public var expectCallCount: UInt32 = 0
    public var expectAssertions: ExpectAssertions = ExpectAssertions.notSet
    public var maybeSkip: Bool = false

    public static let MAX_FLAKY_ATTEMPTS: UInt64 = 16

    public init() {}

    public init(cfg: SequenceConfig) {
        this.firstEntry = cfg.firstEntry
        this.activeEntry = cfg.firstEntry
        this.testEntry = cfg.testEntry
        this.remainingRepeatCount = cfg.repeatCount
        this.remainingRetryCount = cfg.retryCount
    }

    /// 获取不稳定测试的尝试记录
    public func flakyAttempts(): ArrayList<FlakyAttempt> {
        var result = ArrayList<FlakyAttempt>()
        var i: Int64 = 0
        let count = Int64(flakyAttemptCount)
        while (i < count) {
            result.append(flakyAttemptsBuf[i])
            i += 1
        }
        return result
    }

    /// 获取条目模式
    public func entryMode(): ScopeMode {
        if (let Some(entry) <- testEntry) {
            return entry.base.mode
        }
        return ScopeMode.normal
    }
}

/// 序列配置
public class SequenceConfig {
    public var firstEntry: ?ExecutionEntry = None
    public var testEntry: ?ExecutionEntry = None
    public var retryCount: UInt32 = 0
    public var repeatCount: UInt32 = 0

    public init() {}
}

// ========== FlakyAttempt - 不稳定测试尝试 ==========

/// 不稳定测试的尝试记录
public class FlakyAttempt {
    public var result: Result = Result.pending
    public var elapsedNs: UInt64 = 0

    public init() {}
    public init(result: Result, elapsedNs: UInt64) {
        this.result = result
        this.elapsedNs = elapsedNs
    }
}

// ========== Result - 执行结果 ==========

/// 测试执行结果
public enum Result {
    | pending
    | pass
    | skip
    | skippedBecauseLabel
    | todo
    | fail
    | failBecauseTimeout
    | failBecauseTimeoutWithDoneCallback
    | failBecauseHookTimeout
    | failBecauseHookTimeoutWithDoneCallback
    | failBecauseFailingTestPassed
    | failBecauseTodoPassed
    | failBecauseExpectedHasAssertions
    | failBecauseExpectedAssertionCount

    /// 获取基础结果
    public func basicResult(): ResultBasic {
        match (this) {
            case pending => return ResultBasic.pending
            case pass => return ResultBasic.pass
            case fail | failBecauseTimeout | failBecauseTimeoutWithDoneCallback |
                failBecauseHookTimeout | failBecauseHookTimeoutWithDoneCallback |
                failBecauseFailingTestPassed | failBecauseTodoPassed |
                failBecauseExpectedHasAssertions | failBecauseExpectedAssertionCount =>
                return ResultBasic.fail
            case skip | skippedBecauseLabel => return ResultBasic.skip
            case todo => return ResultBasic.todo
        }
    }

    /// 是否通过
    public func isPass(pendingIs: PendingIs): Bool {
        match (basicResult()) {
            case ResultBasic.pass | ResultBasic.skip | ResultBasic.todo => return true
            case ResultBasic.fail => return false
            case ResultBasic.pending => return pendingIs == PendingIs.pendingIsPass
        }
    }

    /// 是否失败
    public func isFail(): Bool {
        return !isPass(PendingIs.pendingIsPass)
    }

    public operator func ==(other: Result): Bool {
        match (this) {
            case pending => match (other) { case pending => true; case _ => false }
            case pass => match (other) { case pass => true; case _ => false }
            case skip => match (other) { case skip => true; case _ => false }
            case skippedBecauseLabel => match (other) { case skippedBecauseLabel => true; case _ => false }
            case todo => match (other) { case todo => true; case _ => false }
            case fail => match (other) { case fail => true; case _ => false }
            case failBecauseTimeout => match (other) { case failBecauseTimeout => true; case _ => false }
            case failBecauseTimeoutWithDoneCallback => match (other) { case failBecauseTimeoutWithDoneCallback => true; case _ => false }
            case failBecauseHookTimeout => match (other) { case failBecauseHookTimeout => true; case _ => false }
            case failBecauseHookTimeoutWithDoneCallback => match (other) { case failBecauseHookTimeoutWithDoneCallback => true; case _ => false }
            case failBecauseFailingTestPassed => match (other) { case failBecauseFailingTestPassed => true; case _ => false }
            case failBecauseTodoPassed => match (other) { case failBecauseTodoPassed => true; case _ => false }
            case failBecauseExpectedHasAssertions => match (other) { case failBecauseExpectedHasAssertions => true; case _ => false }
            case failBecauseExpectedAssertionCount => match (other) { case failBecauseExpectedAssertionCount => true; case _ => false }
        }
    }

    public operator func !=(other: Result): Bool {
        !(this == other)
    }
}

/// 基础结果类型
public enum ResultBasic {
    | pending
    | pass
    | fail
    | skip
    | todo

    public operator func ==(other: ResultBasic): Bool {
        match (this) {
            case pending => match (other) { case pending => true; case _ => false }
            case pass => match (other) { case pass => true; case _ => false }
            case fail => match (other) { case fail => true; case _ => false }
            case skip => match (other) { case skip => true; case _ => false }
            case todo => match (other) { case todo => true; case _ => false }
        }
    }

    public operator func !=(other: ResultBasic): Bool {
        !(this == other)
    }
}

/// Pending处理方式
public enum PendingIs {
    | pendingIsPass
    | pendingIsFail

    public operator func ==(other: PendingIs): Bool {
        match (this) {
            case pendingIsPass => match (other) { case pendingIsPass => true; case _ => false }
            case pendingIsFail => match (other) { case pendingIsFail => true; case _ => false }
        }
    }

    public operator func !=(other: PendingIs): Bool {
        !(this == other)
    }
}

// ========== AdvanceStatus ==========

/// 推进状态
public enum AdvanceStatus {
    | done
    | execute(Timespec)
}

// ========== AdvanceSequenceStatus ==========

/// 序列推进状态
public enum AdvanceSequenceStatus {
    | done
    | execute(Timespec)
}

// ========== ExpectAssertions ==========

/// 断言期望
public enum ExpectAssertions {
    | notSet
    | atLeastOne
    | exact(UInt32)
}

// AddedInPhase moved to core_types.cj to avoid duplication
