// bao_event_loop - 定时器最小堆
// 严格翻译自: src/event_loop/EventLoopTimer.zig + src/event_loop/timer.zig
//   Bun 使用配对堆 (pairing heap) 管理定时器
//   仓颉使用二叉最小堆实现等价语义
//
// Bun 的定时器管理:
//   EventLoopTimer - 定时器节点
//     next: timespec      - 绝对触发时间
//     state: State        - PENDING/ACTIVE/CANCELLED/FIRED
//     tag: Tag            - TimeoutObject/ImmediateObject/etc
//     heap: IntrusiveField - 侵入式堆字段
//     in_heap: InHeap     - none/regular/fake
//
//   定时器比较: EventLoopTimer.less
//     先比较 sec, 再比较 nsec
//     JS 定时器: 折叠 sub-millisecond 精度到 ms
//     相同 nsec 时: epoch wrapping 处理
//
//   配对堆操作:
//     insert(timer)       - 插入定时器
//     extractMin()        - 提取最近定时器
//     remove(timer)       - 按引用删除
//     peek()              - 查看最近定时器
//     fireExpired(now)    - 触发所有到期定时器
package bao_event_loop

import bao_core.*

// ============================================================================
// TimerHeap - 定时器最小堆
// 严格翻译自: Bun 的配对堆定时器管理
//   替代 MiniEventLoop 中的线性扫描
//   提供 O(log n) 的插入和删除操作
//
// Bun 使用侵入式配对堆 (intrusive pairing heap):
//   heap: IntrusiveField(Self) - 嵌入节点的左右子树指针
//   仓颉使用基于数组的二叉最小堆 (更易于实现)
//
// 关键操作:
//   insert(timer)     - O(log n) 插入并维持堆性质
//   extractMin()      - O(log n) 提取最小 (最近到期) 定时器
//   remove(id)        - O(log n) 按 ID 删除定时器
//   peek()            - O(1) 查看最小定时器
//   fireExpired(now)  - 循环触发所有到期定时器
// ============================================================================

/// 定时器最小堆 - 对应 Bun 的配对堆定时器管理
/// 维护按触发时间排序的定时器集合
/// 使用二叉最小堆 (binary min-heap) 实现
public class TimerHeap {
    /// 堆数组
    private var heap: ArrayList<EventLoopTimer>
    /// 定时器 ID 到堆索引的映射 (用于 O(1) 查找)
    private var idToIndex: HashMap<Int64, Int64>

    public init() {
        heap = ArrayList<EventLoopTimer>()
        idToIndex = HashMap<Int64, Int64>()
    }

    // ========================================================================
    // insert - 插入定时器
    // 对应 Bun timer insert (pairing heap insert)
    //   将 timer 插入堆中，设置 inHeap = Regular
    //   然后上浮到正确位置
    // ========================================================================

    /// 插入定时器 - 对应 Bun timer insert
    /// O(log n) 操作
    public func insert(timer: EventLoopTimer): Unit {
        timer.inHeap = InHeap.Regular
        heap.append(timer)
        let idx = heap.size - 1
        idToIndex.put(timer.id, Int64(idx))
        siftUp(Int64(idx))
    }

    // ========================================================================
    // peek - 获取最近的定时器 (不移除)
    // 对应 Bun timer peek
    //   O(1) 操作
    // ========================================================================

    /// 获取最近的定时器 (不移除)
    /// 对应 Bun timer peek
    public func peek(): ?EventLoopTimer {
        if (heap.size == 0) {
            return None
        }
        return Some(heap[0])
    }

    // ========================================================================
    // extractMin - 移除并返回最近的定时器
    // 对应 Bun timer extractMin (pairing heap delete-min)
    //   1. 保存堆顶
    //   2. 将堆底移到堆顶
    //   3. 下沉恢复堆性质
    // ========================================================================

    /// 移除并返回最近的定时器
    /// 对应 Bun timer pop / extractMin
    public func extractMin(): ?EventLoopTimer {
        if (heap.size == 0) {
            return None
        }
        let top = heap[0]
        idToIndex.remove(top.id)
        let lastIdx = heap.size - 1
        if (lastIdx == 0) {
            heap.removeAt(0)
            top.inHeap = InHeap.None
            return Some(top)
        }
        heap[0] = heap[Int64(lastIdx)]
        idToIndex.put(heap[0].id, Int64(0))
        heap.removeAt(Int64(lastIdx))
        siftDown(0)
        top.inHeap = InHeap.None
        return Some(top)
    }

    // ========================================================================
    // remove - 移除指定 ID 的定时器
    // 对应 Bun timer remove by ID
    //   1. 通过 idToIndex 找到位置
    //   2. 替换为堆底
    //   3. 同时上浮和下沉 (因为替换值可能任意方向)
    // ========================================================================

    /// 移除指定 ID 的定时器
    /// 对应 Bun timer remove by ID
    public func remove(id: Int64): ?EventLoopTimer {
        let idx = idToIndex.get(id)
        if (let Some(index) = idx) {
            let timer = heap[Int64(index)]
            idToIndex.remove(id)
            timer.inHeap = InHeap.None
            let lastIdx = heap.size - 1
            if (Int64(index) == lastIdx) {
                heap.removeAt(Int64(index))
                return Some(timer)
            }
            heap[Int64(index)] = heap[Int64(lastIdx)]
            idToIndex.put(heap[Int64(index)].id, index)
            heap.removeAt(Int64(lastIdx))
            // 替换值可能大于或小于原位置，两个方向都尝试
            siftDown(index)
            siftUp(index)
            return Some(timer)
        }
        return None
    }

    /// 堆大小
    public func size(): Int64 {
        return heap.size
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return heap.size == 0
    }

    // ========================================================================
    // nextDeadline - 获取最近触发时间
    // 对应 Bun timer next deadline
    // ========================================================================

    /// 获取最近触发时间
    /// 对应 Bun timer next deadline
    public func nextDeadline(): ?Timespec {
        if (heap.size == 0) {
            return None
        }
        return Some(heap[0].next)
    }

    // ========================================================================
    // fireExpired - 触发所有到期的定时器
    // 对应 Bun timer tick / fire expired
    //
    // Bun 的定时器触发流程:
    //   1. peek() 获取最近定时器
    //   2. 检查 next <= now
    //   3. extractMin() 取出
    //   4. 调用 timer.fire(now, vm)
    //   5. Interval 定时器: 更新 next 并重新 insert
    //
    // fire 的分派 (EventLoopTimer.fire):
    //   switch (self.tag) {
    //     .TimeoutObject => container.internals.fire(now, vm)
    //     .ImmediateObject => container.internals.fire(now, vm)
    //     .TimerCallback => container.callback(container)
    //     .StatWatcherScheduler => container.timerCallback()
    //     ... 其他 tag
    //   }
    // ========================================================================

    /// 触发所有到期的定时器
    /// 对应 Bun timer tick / fire expired
    /// 返回触发的定时器数量
    public func fireExpired(nowMs: Int64): Int64 {
        var count: Int64 = 0
        while (heap.size > 0) {
            let top = heap[0]
            if (!top.isActive()) {
                // 已取消，直接移除
                extractMin()
                continue
            }
            if (top.next.toMillis() > nowMs) {
                break  // 最近的还没到期
            }
            extractMin()
            top.fire()
            count += 1
            // Interval: 重新插入
            if (top.intervalMs > 0) {
                top.next = Timespec.fromMillis(nowMs + top.intervalMs)
                top.state = TimerState.Active
                insert(top)
            }
        }
        return count
    }

    // ========================================================================
    // fireExpiredWithCallback - 触发定时器并收集回调
    // 对应 Bun 事件循环中的定时器触发 + 回调收集
    // ========================================================================

    /// 触发到期的定时器并返回需要执行的回调列表
    /// 用于将定时器触发和回调执行分离
    public func fireExpiredCollectCallbacks(nowMs: Int64): ArrayList<() -> Unit> {
        let callbacks = ArrayList<() -> Unit>()
        while (heap.size > 0) {
            let top = heap[0]
            if (!top.isActive()) {
                extractMin()
                continue
            }
            if (top.next.toMillis() > nowMs) {
                break
            }
            extractMin()
            if (top.isActive()) {
                callbacks.append(top.callback)
                top.state = TimerState.Fired
                // Interval: 重新插入
                if (top.intervalMs > 0) {
                    top.next = Timespec.fromMillis(nowMs + top.intervalMs)
                    top.state = TimerState.Active
                    insert(top)
                }
            }
        }
        return callbacks
    }

    /// 清空堆
    public func clear(): Unit {
        for (timer in heap) {
            timer.inHeap = InHeap.None
        }
        heap.clear()
        idToIndex.clear()
    }

    // ========================================================================
    // contains - 检查定时器是否在堆中
    // ========================================================================

    /// 检查定时器是否在堆中
    public func contains(id: Int64): Bool {
        idToIndex.get(id) != None
    }

    /// 获取指定 ID 的定时器
    public func get(id: Int64): ?EventLoopTimer {
        let idx = idToIndex.get(id)
        if (let Some(index) = idx) {
            return Some(heap[Int64(index)])
        }
        return None
    }

    // ===== 内部堆操作 =====

    /// 上浮 - 对应 binary heap sift-up
    /// 将 idx 位置的元素上浮直到满足堆性质
    /// 比较: EventLoopTimer.less (先 sec 后 nsec)
    private func siftUp(idx: Int64): Unit {
        var i = idx
        while (i > 0) {
            let parent = (i - 1) / 2
            if (EventLoopTimer.less(heap[Int64(i)], heap[Int64(parent)])) {
                swap(i, parent)
                i = parent
            } else {
                break
            }
        }
    }

    /// 下沉 - 对应 binary heap sift-down
    /// 将 idx 位置的元素下沉直到满足堆性质
    private func siftDown(idx: Int64): Unit {
        var i = idx
        let n = heap.size
        while (true) {
            let left = 2 * i + 1
            let right = 2 * i + 2
            var smallest = i
            if (left < n && EventLoopTimer.less(heap[Int64(left)], heap[Int64(smallest)])) {
                smallest = left
            }
            if (right < n && EventLoopTimer.less(heap[Int64(right)], heap[Int64(smallest)])) {
                smallest = right
            }
            if (smallest != i) {
                swap(i, smallest)
                i = smallest
            } else {
                break
            }
        }
    }

    /// 交换两个元素
    private func swap(i: Int64, j: Int64): Unit {
        let temp = heap[Int64(i)]
        heap[Int64(i)] = heap[Int64(j)]
        heap[Int64(j)] = temp
        idToIndex.put(heap[Int64(i)].id, i)
        idToIndex.put(heap[Int64(j)].id, j)
    }
}

// ============================================================================
// TimersList - 同一 deadline 的定时器链表
// 严格翻译自: Bun 的定时器列表
//   当多个定时器具有相同的触发时间时
//   它们被组织成链表以提高效率
//
//   Bun 通过配对堆的自然结构处理:
//     相同 deadline 的定时器按插入顺序链接
//   仓颉: 使用链表显式组织同一 deadline 的定时器
// ============================================================================

/// 同一 deadline 的定时器链表
/// 当多个定时器具有相同触发时间时使用
public class TimersList {
    /// 链表头
    private var head: ?TimerNode
    /// 链表尾
    private var tail: ?TimerNode
    /// 链表长度
    private var length: Int64

    public init() {
        head = None
        tail = None
        length = 0
    }

    /// 追加定时器到链表末尾
    public func append(timer: EventLoopTimer): Unit {
        let node = TimerNode(timer)
        match (tail) {
            case Some(t) =>
                t.next = node
                tail = node
            case None =>
                head = node
                tail = node
        }
        length += 1
    }

    /// 移除链表头并返回
    public func removeFirst(): ?EventLoopTimer {
        match (head) {
            case Some(h) =>
                let timer = h.timer
                head = h.next
                if (head == None) {
                    tail = None
                }
                length -= 1
                return Some(timer)
            case None => return None
        }
    }

    /// 按 ID 移除定时器
    public func remove(id: Int64): ?EventLoopTimer {
        var prev: ?TimerNode = None
        var current = head
        while (current != None) {
            let node = current.getOrThrow()
            if (node.timer.id == id) {
                // 移除节点
                match (prev) {
                    case Some(p) => p.next = node.next
                    case None => head = node.next
                }
                if (node.next == None) {
                    tail = prev
                }
                length -= 1
                return Some(node.timer)
            }
            prev = current
            current = node.next
        }
        return None
    }

    /// 链表长度
    public func len(): Int64 {
        return length
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return length == 0
    }

    /// 遍历所有定时器
    public func forEach(fn: (EventLoopTimer) -> Unit): Unit {
        var current = head
        while (current != None) {
            let node = current.getOrThrow()
            fn(node.timer)
            current = node.next
        }
    }
}

/// 定时器链表节点
class TimerNode {
    var timer: EventLoopTimer
    var next: ?TimerNode

    init(timer: EventLoopTimer) {
        this.timer = timer
        next = None
    }
}

// ============================================================================
// TimerId - 定时器 ID 生成器
// 严格翻译自: Bun 的定时器 ID 管理
//   Bun 使用递增计数器分配定时器 ID
//   setTimeout/setInterval 返回 ID，clearTimeout/clearInterval 使用 ID
// ============================================================================

/// 定时器 ID 生成器 - 对应 Bun 的定时器 ID 管理
/// 线程安全的递增 ID 分配
public class TimerId {
    /// 下一个 ID (原子递增)
    private var nextId: AtomicInt64

    public init() {
        nextId = AtomicInt64(1)
    }

    /// 分配下一个 ID
    public func next(): Int64 {
        return nextId.incrementAndGet()
    }

    /// 当前 ID (不递增)
    public func current(): Int64 {
        return nextId.get()
    }
}
