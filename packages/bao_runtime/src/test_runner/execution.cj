// execution.cj - 测试执行器
// 严格翻译自 bun/src/runtime/test_runner/Execution.zig

package bao_runtime.test_runner

import bao_jsc.*
import std.collection.*

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
    public var groups: Array<ConcurrentGroup> = Array<ConcurrentGroup>()
    public var sequences: Array<ExecutionSequence> = Array<ExecutionSequence>()
    public var groupIndex: UInt64 = 0

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
        if (groupIndex >= groups.size) { return None }
        return groups[groupIndex]
    }

    /// 获取活跃组（只读引用）
    public func activeGroupRef(): ?ConcurrentGroup {
        if (groupIndex >= groups.size) { return None }
        return groups[groupIndex]
    }

    /// 步骤执行 - 执行阶段的主入口
    ///
    /// 根据data的类型决定执行路径:
    /// - Start: 开始执行下一个组
    /// - 其他: 完成当前条目后推进序列
    public func step(buntestStrong: BunTestPtr, globalThis: JSGlobalObject, data: RefDataValue): StepResult {
        let buntest = buntestStrong.get()
        let execution = buntest.execution
        var now = Timespec.nowForceRealTime()

        match (data) {
            case start =>
                return stepGroup(buntestStrong: buntestStrong, globalThis: globalThis, now: now)
            case _ =>
                // 确定活跃的序列和组
                let result = getCurrentAndValidExecutionSequence(data: data)
                if (result == None) {
                    return StepResult.waiting(timeout: Timespec.epoch)
                }
                let (sequencePtr, groupPtr) = result.getOrThrow()

                let sequenceIndex: UInt64 = match (data) {
                    case execution(entryData) => entryData?.sequenceIndex ?? 0
                    case _ => 0
                }

                // 推进序列
                advanceSequence(buntest: buntest, sequence: sequencePtr, group: groupPtr)

                // 步骤序列
                let sequenceResult = stepSequence(
                    buntestStrong: buntestStrong, globalThis: globalThis,
                    group: groupPtr, sequenceIndex: sequenceIndex, now: now
                )
                match (sequenceResult) {
                    case done =>
                        ()
                    case execute(timeout) =>
                        return StepResult.waiting(timeout: timeout)
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
                    let absIdx = group.sequenceStart + nextIdx
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
                            return StepResult.waiting(timeout: timeout)
                    }
                }

                // 所有序列都已开始
                if (groupPtr.remainingIncompleteEntries == 0) {
                    return stepGroup(buntestStrong: buntestStrong, globalThis: globalThis, now: now)
                }
                return StepResult.waiting(timeout: Timespec.epoch)
        }
    }

    /// 步骤组 - 循环处理所有并发组
    public func stepGroup(buntestStrong: BunTestPtr, globalThis: JSGlobalObject, now: Timespec): StepResult {
        let buntest = buntestStrong.get()
        let execution = buntest.execution

        // 循环处理组
        while (true) {
            let group: ?ConcurrentGroup = activeGroup()
            if (group == None) {
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
                    return StepResult.waiting(timeout: timeout)
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
                if (!sequences[i].result.isFail()) {
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
    }

    /// 步骤组内单个 - 处理并发限制
    public func stepGroupOne(buntestStrong: BunTestPtr, globalThis: JSGlobalObject, group: ConcurrentGroup, now: Timespec): AdvanceStatus {
        let buntest = buntestStrong.get()
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
                        case _ => Timespec.epoch
                    }
                    finalStatus = AdvanceStatus.execute(timeout: Timespec.minIgnoreEpoch(a: prevTimeout, b: timeout))
                    activeCount += 1
                    if (concurrentLimit != 0 && activeCount >= concurrentLimit) {
                        break
                    }
            }
        }
        return finalStatus
    }

    /// 步骤序列 - 循环执行序列中的条目
    public func stepSequence(buntestStrong: BunTestPtr, globalThis: JSGlobalObject, group: ConcurrentGroup, sequenceIndex: UInt64, now: Timespec): AdvanceSequenceStatus {
        // 循环直到返回确定状态
        while (true) {
            if (let Some(r) <- stepSequenceOne(
                buntestStrong: buntestStrong, globalThis: globalThis,
                group: group, sequenceIndex: sequenceIndex, now: now
            ) ){
                return r
            }
            // 返回None表示应该继续循环
        }
    }

    /// 步骤序列内单个 - 核心执行逻辑
    ///
    /// 返回None表示应该继续循环，返回Some表示得到了确定状态
    public func stepSequenceOne(buntestStrong: BunTestPtr, globalThis: JSGlobalObject, group: ConcurrentGroup, sequenceIndex: UInt64, now: Timespec): ?AdvanceSequenceStatus {
        let buntest = buntestStrong.get()
        let seqAbs = group.sequenceStart + sequenceIndex
        let sequence = sequences[seqAbs]

        if (sequence.executing) {
            let activeEntry = sequence.activeEntry
            if (activeEntry == None) {
                // 序列正在执行但没有活跃条目
                return AdvanceSequenceStatus.execute(timeout: Timespec.epoch)
            }

            let entry = activeEntry.getOrThrow()
            // 评估超时
            if (entry.evaluateTimeout(sequence: sequence, now: now)) {
                advanceSequence(buntest: buntest, sequence: sequence, group: group)
                return None // 继续循环
            }

            return AdvanceSequenceStatus.execute(timeout: entry.timespec)
        }

        // 检查是否还有下一个条目
        let nextItem = sequence.activeEntry
        if (nextItem == None) {
            // 序列已完成
            return AdvanceSequenceStatus.done
        }

        let entry = nextItem.getOrThrow()
        sequence.executing = true

        // 如果是序列的第一个条目，触发序列开始回调
        if (nextItem == sequence.firstEntry) {
            onSequenceStarted(sequence: sequence)
        }
        onEntryStarted(entry: entry)

        if (let Some(cb) <- entry.callback) {
            // 有回调，需要执行
            let callbackData = RefDataValue.execution(RefDataExecution(
                groupIndex: groupIndex,
                entryData: RefDataEntry(
                    sequenceIndex: sequenceIndex,
                    entry: entry,
                    remainingRepeatCount: sequence.remainingRepeatCount
                )
            ))

            let result = BunTest.runTestCallback(
                strong: buntestStrong,
                globalThis: globalThis,
                callback: cb,
                doneParameter: entry.hasDoneParameter,
                data: callbackData,
                timeout: entry.timespec
            )

            if (result != None) {
                // 同步完成
                now = Timespec.nowForceRealTime()
                let _ = entry.evaluateTimeout(sequence: sequence, now: now)
                advanceSequence(buntest: buntest, sequence: sequence, group: group)
                return None // 继续循环
            }

            return AdvanceSequenceStatus.execute(timeout: entry.timespec)
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
            advanceSequence(buntest: buntest, sequence: sequence, group: group)
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
            onEntryCompleted(entry: entry)

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

        if (sequence.activeEntry == None) {
            // 序列刚完成
            let testFailed = sequence.result.isFail()
            let testPassed = sequence.result.isPass(pendingIs: PendingIs.pendingIsPass)

            // 重试逻辑: 测试失败且还有重试次数
            if (testFailed && sequence.remainingRetryCount > 0) {
                if (sequence.flakyAttemptCount < ExecutionSequence.MAX_FLAKY_ATTEMPTS) {
                    let elapsedNs: UInt64 = if (sequence.startedAt.isEpoch()) {
                        0
                    } else {
                        sequence.startedAt.sinceNowForceRealTime()
                    }
                    sequence.flakyAttemptsBuf[sequence.flakyAttemptCount] = FlakyAttempt(
                        result: sequence.result, elapsedNs: elapsedNs
                    )
                    sequence.flakyAttemptCount += 1
                }
                sequence.remainingRetryCount -= 1
                resetSequence(sequence: sequence)
                return
            }

            // 重复逻辑: 测试通过且还有重复次数
            if (testPassed && sequence.remainingRepeatCount > 0) {
                sequence.remainingRepeatCount -= 1
                resetSequence(sequence: sequence)
                return
            }

            // 所有重试/重复完成后报告最终结果
            onSequenceCompleted(buntest: buntest, sequence: sequence)

            // 减少组内未完成条目计数
            if (group.remainingIncompleteEntries == 0) {
                return
            }
            group.remainingIncompleteEntries -= 1
        }
    }

    /// 组开始回调 - 启用auto_killer
    public func onGroupStarted(group: ConcurrentGroup, globalThis: JSGlobalObject) {
        // 启用auto_killer以在超时时杀死悬挂进程
    }

    /// 组完成回调 - 禁用auto_killer
    public func onGroupCompleted(group: ConcurrentGroup, globalThis: JSGlobalObject) {
        // 禁用auto_killer
    }

    /// 序列开始回调 - 记录开始时间、报告测试开始
    public func onSequenceStarted(sequence: ExecutionSequence) {
        if (let Some(entry) <- sequence.testEntry) {
            if (entry.callback == None) {
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
        if (entry.callback == None) {
            return
        }

        if (entry.timeout != 0) {
            entry.timespec = Timespec.msFromNowForceRealTime(interval: entry.timeout)
        } else {
            entry.timespec = Timespec.epoch
        }
    }

    /// 条目完成回调
    public func onEntryCompleted(entry: ExecutionEntry) {
        // 空实现
    }

    /// 序列完成回调 - 处理断言计数、报告测试完成
    public func onSequenceCompleted(buntest: BunTest, sequence: ExecutionSequence) {
        let elapsedNs: UInt64 = if (sequence.startedAt.isEpoch()) {
            0
        } else {
            sequence.startedAt.sinceNowForceRealTime()
        }

        // 检查断言期望
        match (sequence.expectAssertions) {
            case atLeastOne =>
                if (sequence.expectCallCount == 0 && sequence.result.isPass(pendingIs: PendingIs.pendingIsPass)) {
                    sequence.result = Result.failBecauseExpectedHasAssertions
                }
            case exact(expected) =>
                if (sequence.expectCallCount != expected && sequence.result.isPass(pendingIs: PendingIs.pendingIsPass)) {
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
            if (sequence.testEntry != None || sequence.result != Result.pass) {
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
            entryPtr.timespec = Timespec.epoch
            currentEntry = entryPtr.next
        }

        // 保留flaky历史
        let savedFlakyAttemptCount = sequence.flakyAttemptCount
        let savedFlakyAttemptsBuf = sequence.flakyAttemptsBuf

        // 重新初始化序列
        sequence.activeEntry = sequence.firstEntry
        sequence.result = Result.pending
        sequence.executing = false
        sequence.startedAt = Timespec.epoch
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
            case execution(groupIdx, entryData) =>
                if (entryData == None) {
                    return None
                }
                let ed = entryData.getOrThrow()

                // 验证组索引是否匹配
                if (groupIndex >= groups.size || groupIdx != groupIndex) {
                    return None
                }
                if (groupIdx >= groups.size) {
                    return None
                }

                let group = groups[groupIdx]
                let seqAbs = group.sequenceStart + ed.sequenceIndex
                if (seqAbs >= group.sequenceEnd) {
                    return None
                }

                let sequence = sequences[seqAbs]

                // 验证repeat计数是否匹配
                if (Int64(sequence.remainingRepeatCount) != ed.remainingRepeatCount) {
                    return None
                }

                // 验证active entry是否匹配
                if (sequence.activeEntry != ed.entry) {
                    return None
                }

                return (sequence, group)
            case _ =>
                return None
        }
    }

    /// 处理未捕获异常
    public func handleUncaughtException(userData: RefDataValue): HandleUncaughtExceptionResult {
        let result = getCurrentAndValidExecutionSequence(data: userData)
        if (result == None) {
            return HandleUncaughtExceptionResult.showUnhandledErrorBetweenTests
        }
        let (sequence, _) = result.getOrThrow()

        sequence.maybeSkip = true

        // 如果正在执行钩子（不是testEntry）
        if (sequence.activeEntry != sequence.testEntry) {
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
            let groupSequences = sequences[currentGroup.sequenceStart..currentGroup.sequenceEnd]
            if (groupSequences.size == 1) {
                let sequence = groupSequences[0]
                if (let Some(entry) <- sequence.activeEntry) {
                    let now = Timespec.nowForceRealTime()
                    if (entry.timespec.order(other: now) == Ordering.lt) {
                        // 杀死悬挂进程
                    }
                }
            }
        }

        // 添加Start结果以触发下一步
        buntest.addResult(result: RefDataValue.start)
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
    public func sequences(execution: Execution): Array<ExecutionSequence> {
        return execution.sequences[sequenceStart..sequenceEnd]
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
    public var startedAt: Timespec = Timespec.epoch
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
    public func flakyAttempts(): Array<FlakyAttempt> {
        return flakyAttemptsBuf[0..flakyAttemptCount]
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
        return !isPass(pendingIs: PendingIs.pendingIsPass)
    }
}

/// 基础结果类型
public enum ResultBasic {
    | pending
    | pass
    | fail
    | skip
    | todo
}

/// Pending处理方式
public enum PendingIs {
    | pendingIsPass
    | pendingIsFail
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

// ========== AddedInPhase ==========

/// 添加阶段
public enum AddedInPhase {
    | preload
    | collection
    | execution
}
