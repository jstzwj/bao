// bao_io - 侵入式配对堆 (Intrusive Pairing Heap)
// 严格翻译自: src/io/heap.zig
//   Bun 使用侵入式配对堆实现优先队列，元素自身持有堆元数据
//   仓颉实现提供等价的泛型侵入式配对堆
package bao_io

// ============================================================================
// IntrusiveHeapField - 侵入式堆字段
// 严格翻译自: src/io/heap.zig IntrusiveField(T)
//   元素类型 T 需要包含此类型的 "heap" 字段
// ============================================================================

/// 侵入式堆字段 - 元素类型需要包含此字段
/// 严格翻译自 heap.zig:116-121 IntrusiveField(T)
///   child: ?*T = null, prev: ?*T = null, next: ?*T = null
public class IntrusiveHeapField<T> {
    public var child: ?T = None
    public var prev: ?T = None
    public var next: ?T = None

    public init() {}
}

// ============================================================================
// IntrusiveHeap - 侵入式配对堆
// 严格翻译自: src/io/heap.zig Intrusive(T, Context, less)
//   配对堆是一种简单的堆实现，支持 insert/peek/deleteMin/remove/findMax
//   通过 less 比较函数决定堆性质 (min-heap or max-heap)
// ============================================================================

/// 侵入式配对堆 - 泛型堆实现
/// 严格翻译自 heap.zig:18-114 Intrusive(T, Context, less)
///   root: ?*T = null, context: Context
///   insert: meld into root
///   peek: return root
///   count: O(N) traversal
///   deleteMin: combine-siblings
///   remove: detach + combine-children + meld
public class IntrusiveHeap<T> {
    /// 堆根节点
    public var root: ?T = None
    /// 比较函数: 返回 true 表示 a 的优先级低于 b (less than)
    private var lessFn: (T, T) -> Bool

    public init(lessFn: (T, T) -> Bool) {
        this.lessFn = lessFn
    }

    /// 获取堆字段 (子类需覆写)
    /// 翻译自: current.heap.child, current.heap.next 等
    public func getHeapField(elem: T): IntrusiveHeapField<T> {
        // 需要元素类型提供 heap 字段访问
        // 由具体使用处实现
        fatal("getHeapField must be overridden")
    }

    /// 插入元素到堆中
    /// 严格翻译自 heap.zig:28-29 insert()
    ///   self.root = if (self.root) |root| self.meld(v, root) else v;
    public func insert(v: T): Unit {
        let field = getHeapField(v)
        if (let Some(r) = root) {
            root = meld(v, r)
        } else {
            root = v
        }
    }

    /// 查看堆顶元素但不移除
    /// 严格翻译自 heap.zig:33 peek()
    public func peek(): ?T {
        return root
    }

    /// 计算堆中元素数量 - O(N) 操作
    /// 严格翻译自 heap.zig:37-48 count() + countInternal()
    ///   递归遍历 child 和 next 统计节点数
    public func count(): Int64 {
        return countInternal(root)
    }

    private func countInternal(node: ?T): Int64 {
        if (let Some(current) = node) {
            var result: Int64 = 1
            let field = getHeapField(current)
            // 统计子节点
            result += countInternal(field.child)
            // 统计兄弟节点
            result += countInternal(field.next)
            return result
        }
        return 0
    }

    /// 查找堆中最大值 - O(N) 操作
    /// 严格翻译自 heap.zig:51-66 findMax() + findMaxInternal()
    public func findMax(): ?T {
        if (let Some(r) = root) {
            return findMaxInternal(r, r)
        }
        return None
    }

    private func findMaxInternal(node: T, currentMax: T): T {
        var maxSoFar = currentMax
        let field = getHeapField(node)

        // 更新最大值
        if (lessFn(maxSoFar, node)) {
            maxSoFar = node
        }

        // 遍历子节点
        if (let Some(child) = field.child) {
            maxSoFar = findMaxInternal(child, maxSoFar)
        }

        // 遍历兄弟节点
        if (let Some(next) = field.next) {
            maxSoFar = findMaxInternal(next, maxSoFar)
        }

        return maxSoFar
    }

    /// 删除并返回最小值
    /// 严格翻译自 heap.zig:69-82 deleteMin()
    ///   root = combine_siblings(root.child) else null
    ///   root.heap = .{} (清空指针)
    public func deleteMin(): ?T {
        if (let Some(r) = root) {
            let field = getHeapField(r)
            if (let Some(child) = field.child) {
                root = combineSiblings(child)
            } else {
                root = None
            }
            // 清空指针
            field.child = None
            field.prev = None
            field.next = None
            return r
        }
        return None
    }

    /// 移除指定元素
    /// 严格翻译自 heap.zig:85-109 remove()
    ///   如果没有 prev, 则必须是 root -> deleteMin
    ///   否则从链表中移除, 合并子树后 meld 回 root
    public func remove(v: T): Unit {
        let field = getHeapField(v)

        if (let Some(prev) = field.prev) {
            // 从链表中移除 v
            if (let Some(next) = field.next) {
                getHeapField(next).prev = prev
            }
            let prevField = getHeapField(prev)
            if (prevField.child == Some(v)) {
                prevField.child = field.next
            } else {
                prevField.next = field.next
            }
            field.prev = None
            field.next = None

            // 合并子树并 meld 回 root
            if (let Some(child) = field.child) {
                field.child = None
                if (let Some(r) = root) {
                    let x = combineSiblings(child)
                    root = meld(x, r)
                }
            }
        } else {
            // 必须是 root
            if (let Some(r) = root) {
                if (r == v) {
                    let _ = deleteMin()
                }
            }
        }
    }

    /// 合并两个堆 (meld)
    /// 严格翻译自 heap.zig:119-160 meld()
    ///   较小优先级的成为较大优先级的子节点
    ///   维护双向链表: prev/next 指针
    private func meld(a: T, b: T): T {
        let aField = getHeapField(a)
        let bField = getHeapField(b)

        if (lessFn(a, b)) {
            // B 指回 A
            bField.prev = a

            // A 继承 B 的兄弟
            if (let Some(bNext) = bField.next) {
                aField.next = bNext
                getHeapField(bNext).prev = a
                bField.next = None
            }

            // B 成为 A 的左子节点
            if (let Some(aChild) = aField.child) {
                bField.next = aChild
                getHeapField(aChild).prev = b
            }
            aField.child = b
            return a
        }

        // A 成为 B 的子节点
        bField.prev = aField.prev
        aField.prev = b
        if (let Some(bChild) = bField.child) {
            aField.next = bChild
            getHeapField(bChild).prev = a
        }
        bField.child = a
        return b
    }

    /// 合并兄弟节点
    /// 严格翻译自 heap.zig:163-180 combine_siblings()
    ///   先从左到右两两合并，再从右到左依次 meld
    private func combineSiblings(left: T): T {
        let leftField = getHeapField(left)
        leftField.prev = None

        // 从左到右两两合并
        var rootRes: ?T = None
        var a: T = left
        while (true) {
            let aField = getHeapField(a)
            if (let Some(b) = aField.next) {
                aField.next = None
                var bNode = meld(a, b)
                let bField = getHeapField(bNode)
                if (let Some(nextB) = bField.next) {
                    a = nextB
                } else {
                    rootRes = bNode
                    break
                }
            } else {
                rootRes = a
                break
            }
        }

        // 从右到左合并
        if (let Some(r) = rootRes) {
            var currentRoot = r
            while (true) {
                let rField = getHeapField(currentRoot)
                if (let Some(b) = rField.prev) {
                    getHeapField(b).next = None
                    currentRoot = meld(b, currentRoot)
                } else {
                    return currentRoot
                }
            }
        }
        return left
    }
}
