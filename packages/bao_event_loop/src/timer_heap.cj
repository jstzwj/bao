// bao_event_loop - 定时器最小堆
// 严格翻译自: src/event_loop/ (Bun 的配对堆定时器管理)
//   Bun 使用配对堆 (pairing heap) 管理定时器
//   仓颉使用二叉最小堆实现等价语义
package bao_event_loop

import bao_core.*

// ============================================================================
// TimerHeap - 定时器最小堆
// 严格翻译自: Bun 的定时器堆管理
//   替代 MiniEventLoop 中的线性扫描
//   提供 O(log n) 的插入和删除操作
// ============================================================================

/// 定时器最小堆 - 对应 Bun 的配对堆定时器管理
/// 维护按触发时间排序的定时器集合
public class TimerHeap {
    /// 堆数组
    private var heap: ArrayList<EventLoopTimer>
    /// 定时器 ID 到堆索引的映射
    private var idToIndex: HashMap<Int64, Int64>

    public init() {
        heap = ArrayList<EventLoopTimer>()
        idToIndex = HashMap<Int64, Int64>()
    }

    /// 插入定时器 - 对应 Bun timer insert
    /// O(log n) 操作
    public func insert(timer: EventLoopTimer): Unit {
        timer.inHeap = InHeap.Regular
        heap.append(timer)
        let idx = heap.size - 1
        idToIndex.put(timer.id, idx)
        siftUp(Int64(idx))
    }

    /// 获取最近的定时器 (不移除)
    /// 对应 Bun timer peek
    public func peek(): ?EventLoopTimer {
        if (heap.size == 0) {
            return None
        }
        return Some(heap[0])
    }

    /// 移除并返回最近的定时器
    /// 对应 Bun timer pop
    public func pop(): ?EventLoopTimer {
        if (heap.size == 0) {
            return None
        }
        let top = heap[0]
        idToIndex.remove(top.id)
        let lastIdx = heap.size - 1
        if (lastIdx == 0) {
            heap.removeAt(0)
            return top
        }
        heap[0] = heap[Int64(lastIdx)]
        idToIndex.put(heap[0].id, Int64(0))
        heap.removeAt(Int64(lastIdx))
        siftDown(0)
        top.inHeap = InHeap.None
        return Some(top)
    }

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
            // 需要调整位置
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

    /// 获取最近触发时间 (毫秒)
    /// 对应 Bun timer next deadline
    public func nextDeadline(): ?Timespec {
        if (heap.size == 0) {
            return None
        }
        return Some(heap[0].next)
    }

    /// 触发所有到期的定时器
    /// 对应 Bun timer tick / fire expired
    /// 返回触发的定时器数量
    public func fireExpired(nowMs: Int64): Int64 {
        var count: Int64 = 0
        while (heap.size > 0) {
            let top = heap[0]
            if (!top.isActive()) {
                // 已取消，直接移除
                pop()
                continue
            }
            if (top.next.toMillis() > nowMs) {
                break  // 最近的还没到期
            }
            pop()
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

    /// 清空堆
    public func clear(): Unit {
        for (timer in heap) {
            timer.inHeap = InHeap.None
        }
        heap.clear()
        idToIndex.clear()
    }

    // ===== 内部堆操作 =====

    /// 上浮
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

    /// 下沉
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
