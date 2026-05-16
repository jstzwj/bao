// order.cj - 测试排序
// 严格翻译自 bun/src/runtime/test_runner/Order.zig

package bao_runtime.test_runner

import bao_jsc.*
import std.collection.*

// ========== Order - 测试排序 ==========

/// 将收集阶段的输出转换为执行阶段的输入
public class Order {
    public var groups: ArrayList<ConcurrentGroup> = ArrayList<ConcurrentGroup>()
    public var sequences: ArrayList<ExecutionSequence> = ArrayList<ExecutionSequence>()
    public var arena: Allocator
    public var previousGroupWasConcurrent: Bool = false
    public var cfg: Config

    public init(gpa: Allocator, arena: Allocator, cfg: Config) {
        this.arena = arena
        this.cfg = cfg
    }

    public func deinit() {
        groups.clear()
        sequences.clear()
    }

    /// 生成排序子条目
    public func generateOrderSub(current: TestScheduleEntry) {
        match (current) {
            case TestScheduleEntry.describe(describe) => generateOrderDescribe(current: describe)
            case TestScheduleEntry.testCallback(testCallback) => generateOrderTest(current: testCallback)
        }
    }

    /// 生成所有排序
    public func generateAllOrder(entries: Array<ExecutionEntry>): AllOrderResult {
        let start = groups.size
        for (entry in entries ) {
            entry.next = None
            entry.failureSkipPast = None

            let sequencesStart = sequences.size
            sequences.append(ExecutionSequence(cfg: ExecutionSequence.SequenceConfig(
                firstEntry: entry, testEntry: None
            )))
            let sequencesEnd = sequences.size

            groups.append(ConcurrentGroup(
                sequenceStart: sequencesStart, sequenceEnd: sequencesEnd, nextIndex: groups.size + 1
            ))
            previousGroupWasConcurrent = false
        }
        let end = groups.size
        return AllOrderResult(start: start, end: end)
    }

    /// 生成describe排序
    public func generateOrderDescribe(current: DescribeScope) {
        if (current.failed) { return }
        let useHooks = cfg.alwaysUseHooks || current.base.hasCallback

        // 收集beforeAll
        let beforeallOrder: AllOrderResult = if (useHooks) { generateAllOrder(entries: current.beforeAll.toArray()) } else { AllOrderResult.empty }

        // 随机打乱（如果设置了randomize标志）
        // Fisher-Yates洗牌算法，使用前向遍历:
        // i从0到len-2，j = i + uintLessThan(len - i)
        if (cfg.randomize) {
            shuffleWithIndex(entries: current.entries)
        }

        // 收集子条目
        for (entry in current.entries.toArray() ) {
            if (current.base.only == OnlyMode.contains && entry.base().only == OnlyMode.no) { continue }
            generateOrderSub(current: entry)
        }

        // 更新skip_to值
        beforeallOrder.setFailureSkipTo(order: this)

        // 收集afterAll
        let afterallOrder: AllOrderResult = if (useHooks) { generateAllOrder(entries: current.afterAll.toArray()) } else { AllOrderResult.empty }
        afterallOrder.setFailureSkipTo(order: this)
    }

    /// 条目列表

    /// 生成test排序
    public func generateOrderTest(current: ExecutionEntry) {
        let useEachHooks = current.base.hasCallback
        var list = EntryList()

        // 收集beforeEach（从父级向上遍历，前置以反转顺序）
        if (useEachHooks) {
            var parent: ?DescribeScope = current.base.parent
            while (let Some(p) <- parent ){
                var i = p.beforeEach.size
                while (i > 0) {
                    i -= 1
                    list.prepend(p.beforeEach[i])
                }
                parent = p.base.parent
            }
        }

        // 追加测试
        list.append(current)

        // 收集afterEach
        if (useEachHooks) {
            var parent: ?DescribeScope = current.base.parent
            while (let Some(p) <- parent ){
                for (entry in p.afterEach.toArray() ) {
                    list.append(entry)
                }
                parent = p.base.parent
            }
        }

        // 设置skip_to值
        var index = list.first
        var failureSkipPast: ?ExecutionEntry = current
        while (let Some(entry) <- index ){
            entry.failureSkipPast = failureSkipPast
            if (entry == failureSkipPast) {
                failureSkipPast = None
            }
            index = entry.next
        }

        // 添加为单个序列
        let sequencesStart = sequences.size
        sequences.append(ExecutionSequence(cfg: ExecutionSequence.SequenceConfig(
            firstEntry: list.first, testEntry: current,
            retryCount: current.retryCount, repeatCount: current.repeatCount
        )))
        let sequencesEnd = sequences.size
        appendOrExtendConcurrentGroup(concurrent: current.base.concurrent, sequencesStart: sequencesStart, sequencesEnd: sequencesEnd)
    }

    /// 追加或扩展并发组
    public func appendOrExtendConcurrentGroup(concurrent: Bool, sequencesStart: UInt64, sequencesEnd: UInt64) {
        defer { previousGroupWasConcurrent = concurrent }
        if (concurrent && groups.size > 0) {
            let previousGroup = groups[groups.size - 1]
            if (previousGroupWasConcurrent) {
                if (previousGroup.tryExtend(nextSequenceStart: sequencesStart, nextSequenceEnd: sequencesEnd)) {
                    return
                }
            }
        }
        groups.append(ConcurrentGroup(
            sequenceStart: sequencesStart, sequenceEnd: sequencesEnd, nextIndex: groups.size + 1
        ))
    }

    /// Fisher-Yates洗牌算法
    ///
    /// 精确移植自 Zig 的 std.Random.shuffleWithIndex。
    /// 前向Fisher-Yates: i从0到len-2, j = i + uintLessThan(max - i)。
    /// 必须产生与Zig相同的排列，以保证
    /// `bun test --randomize --seed=N` 在不同端口间可重现。
    private func shuffleWithIndex(entries: ArrayList<TestScheduleEntry>) {
        let len = entries.size
        if (len < 2) { return }
        var i: UInt64 = 0
        while (i < len - 1) {
            let j = i + uintLessThan(lessThan: len - i)
            let tmp = entries[i]
            entries[i] = entries[j]
            entries[j] = tmp
            i += 1
        }
    }

    /// uintLessThan - 生成[0, lessThan)范围内的随机数
    ///
    /// 精确移植自 Zig 的 std.Random.uintLessThan。
    /// 使用Lemire的去偏方法（debiased method）。
    private func uintLessThan(lessThan: UInt64): UInt64 {
        var x = DefaultPrng.next()
        var m = x * lessThan
        var l = m & UInt64.max
        if (l < lessThan) {
            var t = 0 - lessThan // wrapping_neg
            if (t >= lessThan) {
                t = lessThan
                while (t != 0) {
                    t >>= 1
                }
                // t现在是最高位
                while (l < t) {
                    x = DefaultPrng.next()
                    m = x * lessThan
                    l = m & UInt64.max
                }
            }
        }
        return UInt64(m >> 64) // 高64位
    }
}

/// 所有排序结果
public class AllOrderResult {
    public var start: UInt64 = 0
    public var end: UInt64 = 0

    public static let empty: AllOrderResult = AllOrderResult(start: 0, end: 0)

    public init(start: UInt64, end: UInt64) {
        this.start = start
        this.end = end
    }

    /// 设置失败跳过位置
    public func setFailureSkipTo(order: Order) {
        if (start == 0 && end == 0) { return }
        let skipTo = order.groups.size
        for (i in start..end) {
            order.groups[i].failureSkipTo = skipTo
        }
    }
}

public class Config {
    public var alwaysUseHooks: Bool = false
    public var randomize: Bool = false

    public init() {}
}

public class EntryList {
    public var first: ?ExecutionEntry = None
    public var last: ?ExecutionEntry = None

    public init() {}

    /// 前置追加
    public func prepend(current: ExecutionEntry) {
        current.next = first
        first = current
        if (last == None) { last = current }
    }

    /// 后置追加
    public func append(current: ExecutionEntry) {
        current.next = None
        if (let Some(l) <- last) {
            l.next = current
            last = current
        } else {
            first = current
            last = current
        }
    }
}
