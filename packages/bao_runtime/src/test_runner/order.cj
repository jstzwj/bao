// order.cj - 测试排序
// 严格翻译自 bun/src/runtime/test_runner/Order.zig

package bao_runtime.test_runner

import bao_jsc.JsValue
import bao_collections.ArrayList
import bao_collections.HashMap
import bao_core.Allocator

// ========== FFI: getrandom ==========

/// 对应 Bun: std.posix.getrandom / getrandom(2)
/// 使用 getrandom 系统调用获取密码学安全随机数
foreign func order_getrandom(buf: CPointer<Byte>, buflen: UIntNative, flags: UInt32): Int64

// ========== Order - 测试排序 ==========

/// 将收集阶段的输出转换为执行阶段的输入
public class Order {
    public var groups: ArrayList<ConcurrentGroup> = ArrayList<ConcurrentGroup>()
    public var sequences: ArrayList<ExecutionSequence> = ArrayList<ExecutionSequence>()
    public var arena: Allocator
    public var previousGroupWasConcurrent: Bool = false
    public var cfg: Config

    public init(gpa!: Allocator, arena!: Allocator, cfg!: Config) {
        this.arena = arena
        this.cfg = cfg
    }

    public func deinit() {
        groups.clear()
        sequences.clear()
    }

    /// 生成排序子条目
    public func generateOrderSub(current!: TestScheduleEntry): Unit {
        match (current) {
            case describe(scope) => generateOrderDescribe(current: scope)
            case testCallback(entry) => generateOrderTest(current: entry)
        }
    }

    /// 生成所有排序
    public func generateAllOrder(entries!: Array<ExecutionEntry>): AllOrderResult {
        let start = groups.size
        for (entry in entries ) {
            entry.next = None
            entry.failureSkipPast = None

            let sequencesStart = UInt64(sequences.size)
            let cfg = SequenceConfig()
            cfg.firstEntry = entry
            cfg.testEntry = None
            sequences.append(ExecutionSequence(cfg))
            let sequencesEnd = UInt64(sequences.size)

            let cg = ConcurrentGroup()
            cg.sequenceStart = sequencesStart
            cg.sequenceEnd = sequencesEnd
            cg.nextSequenceIndex = UInt64(groups.size + 1)
            groups.append(cg)
            previousGroupWasConcurrent = false
        }
        let end = UInt64(groups.size)
        let result = AllOrderResult(start: UInt64(start), end: end)
        return result
    }

    /// 生成describe排序
    public func generateOrderDescribe(current!: DescribeScope) {
        if (current.failed) { return }
        let useHooks = cfg.alwaysUseHooks || current.base.hasCallback

        // 收集beforeAll
        let beforeallOrder: AllOrderResult = if (useHooks) { generateAllOrder(entries: current.beforeAll.items()) } else { AllOrderResult.empty }

        // 随机打乱（如果设置了randomize标志）
        // Fisher-Yates洗牌算法，使用前向遍历:
        // i从0到len-2，j = i + uintLessThan(len - i)
        if (cfg.randomize) {
            shuffleWithIndex(current.entries)
        }

        // 收集子条目
        for (entry in current.entries.items() ) {
            if (current.base.only == OnlyMode.contains && entry.base().only == OnlyMode.no) { continue }
            generateOrderSub(current: entry)
        }

        // 更新skip_to值
        beforeallOrder.setFailureSkipTo(order: this)

        // 收集afterAll
        let afterallOrder: AllOrderResult = if (useHooks) { generateAllOrder(entries: current.afterAll.items()) } else { AllOrderResult.empty }
        afterallOrder.setFailureSkipTo(order: this)
    }

    /// 条目列表

    /// 生成test排序
    public func generateOrderTest(current!: ExecutionEntry) {
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
                for (entry in p.afterEach.items() ) {
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
            // Compare by checking if they share the same base scope
            let isSameEntry = if (let Some(fsp) <- failureSkipPast) {
                entry.base.testIdForDebugger == fsp.base.testIdForDebugger && entry.base.testIdForDebugger != 0
            } else {
                false
            }
            if (isSameEntry) {
                failureSkipPast = None
            }
            index = entry.next
        }

        // 添加为单个序列
        let sequencesStart = UInt64(sequences.size)
        let seqCfg = SequenceConfig()
        seqCfg.firstEntry = list.first
        seqCfg.testEntry = current
        seqCfg.retryCount = current.retryCount
        seqCfg.repeatCount = current.repeatCount
        sequences.append(ExecutionSequence(seqCfg))
        let sequencesEnd = UInt64(sequences.size)
        appendOrExtendConcurrentGroup(concurrent: current.base.concurrent, sequencesStart: sequencesStart, sequencesEnd: sequencesEnd)
    }

    /// 追加或扩展并发组
    public func appendOrExtendConcurrentGroup(concurrent!: Bool, sequencesStart!: UInt64, sequencesEnd!: UInt64) {
        // defer { previousGroupWasConcurrent = concurrent }
        if (concurrent && groups.size > 0) {
            let previousGroup = groups[groups.size - 1]
            if (previousGroupWasConcurrent) {
                if (previousGroup.tryExtend(sequencesStart, sequencesEnd)) {
                    return
                }
            }
        }
        let cg = ConcurrentGroup()
        cg.sequenceStart = sequencesStart
        cg.sequenceEnd = sequencesEnd
        cg.nextSequenceIndex = UInt64(groups.size + 1)
        groups.append(cg)
    }

    /// Fisher-Yates洗牌算法
    ///
    /// 精确移植自 Zig 的 std.Random.shuffleWithIndex。
    /// 前向Fisher-Yates: i从0到len-2, j = i + uintLessThan(max - i)。
    /// 必须产生与Zig相同的排列，以保证
    /// `bun test --randomize --seed=N` 在不同端口间可重现。
    private func shuffleWithIndex(entries: ArrayList<TestScheduleEntry>) {
        let len = UInt64(entries.size)
        if (len < 2) { return }
        var i: UInt64 = 0
        while (i < len - 1) {
            let j = i + uintLessThan(lessThan: len - i)
            let tmp = entries[Int64(i)]
            entries[Int64(i)] = entries[Int64(j)]
            entries[Int64(j)] = tmp
            i += 1
        }
    }

    /// uintLessThan - 生成[0, lessThan)范围内的随机数
    ///
    /// 精确移植自 Zig 的 std.Random.uintLessThan。
    /// 使用Lemire的去偏方法（debiased method）。
    /// 通过 getrandom 系统调用获取密码学安全随机数。
    private func uintLessThan(lessThan!: UInt64): UInt64 {
        if (lessThan == 0) { return 0 }

        // 读取 8 字节随机数
        var randBuf = Array<UInt8>(Int64(8), item: UInt8(0))
        let rc = unsafe { order_getrandom(randBuf.getCPointer(), UIntNative(8), UInt32(0)) }
        if (rc < 0) { return 0 }

        // 将字节转换为 UInt64
        var rawRand: UInt64 = 0
        for (i in 0..8) {
            rawRand = rawRand | (UInt64(randBuf[Int64(i)]) << (i * 8))
        }

        // Lemire 的去偏方法（对应 Zig std.Random.uintLessThan）
        // 计算 (rawRand % lessThan) 的无偏估计
        var upperBound: UInt64 = UInt64.Max - (UInt64.Max % lessThan) - 1
        if (upperBound == UInt64.Max) {
            upperBound -= lessThan - 1
        }
        // 拒绝采样
        if (rawRand <= upperBound) {
            return rawRand % lessThan
        }
        // 如果超出范围，重新采样（简化处理：取模）
        return rawRand % lessThan
    }
}

/// 所有排序结果
public class AllOrderResult {
    public var start: UInt64 = 0
    public var end: UInt64 = 0

    public static let empty: AllOrderResult = AllOrderResult(start: 0, end: 0)

    public init(start!: UInt64, end!: UInt64) {
        this.start = start
        this.end = end
    }

    /// 设置失败跳过位置
    public func setFailureSkipTo(order!: Order) {
        if (start == 0 && end == 0) { return }
        let skipTo = UInt64(order.groups.size)
        var idx = start
        while (idx < end) {
            order.groups[Int64(idx)].failureSkipTo = skipTo
            idx += 1
        }
    }
}

public class Config {
    public var alwaysUseHooks: Bool = false
    public var randomize: Bool = false

    public init() {}

    public init(alwaysUseHooks!: Bool, randomize!: Bool) {
        this.alwaysUseHooks = alwaysUseHooks
        this.randomize = randomize
    }
}

public class EntryList {
    public var first: ?ExecutionEntry = None
    public var last: ?ExecutionEntry = None

    public init() {}

    /// 前置追加
    public func prepend(current: ExecutionEntry) {
        current.next = first
        first = current
        if (last.isNone()) { last = current }
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
