// order.cj - 测试排序
// 严格翻译自 bun/src/runtime/test_runner/Order.zig

package bao_runtime

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
        switch current {
        case .describe(let describe): generateOrderDescribe(current: describe)
        case .testCallback(let testCallback): generateOrderTest(current: testCallback)
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
            if start == 0 && end == 0 { return }
            let skipTo = order.groups.size
            for i in start..end {
                order.groups[i].failureSkipTo = skipTo
            }
        }
    }

    /// 排序配置
    public class Config {
        public var alwaysUseHooks: Bool = false
        public var randomize: Bool = false

        public init() {}
    }

    /// 生成所有排序
    public func generateAllOrder(entries: Array<ExecutionEntry>): AllOrderResult {
        let start = groups.size
        for entry in entries {
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
        if current.failed { return }
        let useHooks = cfg.alwaysUseHooks || current.base.hasCallback

        // 收集beforeAll
        let beforeallOrder: AllOrderResult = useHooks ? generateAllOrder(entries: current.beforeAll.toArray()) : AllOrderResult.empty

        // 随机打乱（如果设置了randomize标志）
        // TODO: 实现shuffle

        // 收集子条目
        for entry in current.entries.toArray() {
            if current.base.only == OnlyMode.contains && entry.base().only == OnlyMode.no { continue }
            generateOrderSub(current: entry)
        }

        // 更新skip_to值
        beforeallOrder.setFailureSkipTo(order: this)

        // 收集afterAll
        let afterallOrder: AllOrderResult = useHooks ? generateAllOrder(entries: current.afterAll.toArray()) : AllOrderResult.empty
        afterallOrder.setFailureSkipTo(order: this)
    }

    /// 条目列表
    public class EntryList {
        public var first: ?ExecutionEntry = None
        public var last: ?ExecutionEntry = None

        public init() {}

        /// 前置追加
        public func prepend(current: ExecutionEntry) {
            current.next = first
            first = current
            if last == None { last = current }
        }

        /// 后置追加
        public func append(current: ExecutionEntry) {
            current.next = None
            if let l = last {
                l.next = current
                last = current
            } else {
                first = current
                last = current
            }
        }
    }

    /// 生成test排序
    public func generateOrderTest(current: ExecutionEntry) {
        let useEachHooks = current.base.hasCallback
        var list = EntryList()

        // 收集beforeEach（从父级向上遍历，前置以反转顺序）
        if useEachHooks {
            var parent: ?DescribeScope = current.base.parent
            while let p = parent {
                var i = p.beforeEach.size
                while i > 0 {
                    i -= 1
                    list.prepend(p.beforeEach[i])
                }
                parent = p.base.parent
            }
        }

        // 追加测试
        list.append(current)

        // 收集afterEach
        if useEachHooks {
            var parent: ?DescribeScope = current.base.parent
            while let p = parent {
                for entry in p.afterEach.toArray() {
                    list.append(entry)
                }
                parent = p.base.parent
            }
        }

        // 设置skip_to值
        var index = list.first
        var failureSkipPast: ?ExecutionEntry = current
        while let entry = index {
            entry.failureSkipPast = failureSkipPast
            if entry === failureSkipPast {
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
        if concurrent && groups.size > 0 {
            let previousGroup = groups[groups.size - 1]
            if previousGroupWasConcurrent {
                if previousGroup.tryExtend(nextSequenceStart: sequencesStart, nextSequenceEnd: sequencesEnd) {
                    return
                }
            }
        }
        groups.append(ConcurrentGroup(
            sequenceStart: sequencesStart, sequenceEnd: sequencesEnd, nextIndex: groups.size + 1
        ))
    }
}
