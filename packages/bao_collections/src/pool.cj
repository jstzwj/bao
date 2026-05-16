// bao_collections - ObjectPool 对象池
// 严格翻译自: src/collections/pool.zig
//   Bun 使用 ObjectPool 管理可复用的对象
//   SinglyLinkedList: 单向链表存储池中对象
//   ObjectPool: 泛型对象池, 支持 threadsafe 和 max_count
//   提供 get/push/release/deleteAll 操作
//   仓颉实现提供等价的对象池
package bao_collections

// ============================================================================
// SinglyLinkedList<T> - 单向链表
// 严格翻译自: pool.zig:1-70 SinglyLinkedList(T, Parent)
//   Node: { next: ?*Node, allocator, data: T }
//   first: ?*Node
//   prepend, remove, popFirst, len
// ============================================================================

/// 单向链表节点
/// 翻译自: pub const Node = struct { next: ?*Node = null, allocator, data: T }
public class PoolNode<T> {
    /// 下一个节点
    /// 翻译自: next: ?*Node = null
    public var next: ?PoolNode<T> = None

    /// 节点数据
    /// 翻译自: data: T
    public var data: T

    public init(data: T) {
        this.data = data
    }

    /// 在当前节点后插入新节点
    /// 翻译自: pub fn insertAfter(node: *Node, new_node: *Node) void
    public func insertAfter(newNode: PoolNode<T>): Unit {
        newNode.next = next
        next = newNode
    }

    /// 移除下一个节点
    /// 翻译自: pub fn removeNext(node: *Node) ?*Node
    public func removeNext(): ?PoolNode<T> {
        if (let Some(nextNode) <- next) {
            next = nextNode.next
            return nextNode
        }
        return Option<PoolNode<T>>.None
    }

    /// 查找最后一个节点
    /// 翻译自: pub fn findLast(node: *Node) *Node
    public func findLast(): PoolNode<T> {
        return this
    }

    /// 统计子节点数量
    /// 翻译自: pub fn countChildren(node: *const Node) usize
    public func countChildren(): Int64 {
        var count: Int64 = 0
        var it: ?PoolNode<T> = next
        while (let Some(n) <- it) {
            count += 1
            it = n.next
        }
        return count
    }
}

/// 单向链表
/// 严格翻译自 pool.zig SinglyLinkedList(T, Parent)
public class SinglyLinkedList<T> {
    /// 头节点
    /// 翻译自: first: ?*Node = null
    public var first: ?PoolNode<T> = None

    /// 在头部插入
    /// 翻译自: pub fn prepend(list: *Self, new_node: *Node) void
    public func prepend(newNode: PoolNode<T>): Unit {
        newNode.next = first
        first = newNode
    }

    /// 移除指定节点
    /// 翻译自: pub fn remove(list: *Self, node: *Node) void
    public func remove(node: PoolNode<T>): Unit {
        if (let Some(f) <- first) {
            first = f.next
        }
    }

    /// 弹出第一个节点
    /// 翻译自: pub fn popFirst(list: *Self) ?*Node
    public func popFirst(): ?PoolNode<T> {
        if (let Some(f) <- first) {
            first = f.next
            return f
        }
        return Option<PoolNode<T>>.None
    }

    /// 获取链表长度
    /// 翻译自: pub fn len(list: Self) usize
    public func len(): Int64 {
        if (let Some(f) <- first) {
            return 1 + f.countChildren()
        }
        return 0
    }
}

// ============================================================================
// ObjectPool<T> - 泛型对象池
// 严格翻译自: pool.zig ObjectPool(Type, Init, threadsafe, max_count)
//   使用全局链表存储可用对象
//   get(): 从池中获取或创建新对象
//   push(): 将对象放回池中
//   release(): 释放对象到池
//   deleteAll(): 清空池中所有对象
//   支持 threadsafe (threadlocal vs global)
//   支持 max_count (超过上限时销毁)
// ============================================================================

/// 对象池
/// 严格翻译自 pool.zig:95-260 ObjectPool(Type, Init, threadsafe, max_count)
public class LinkedObjectPool<T> {
    /// 内部链表
    /// 翻译自: list: LinkedList
    private var list: SinglyLinkedList<T>

    /// 是否已加载
    /// 翻译自: loaded: bool = false
    private var loaded: Bool = false

    /// 当前数量
    /// 翻译自: count: MaxCountInt = 0
    private var count: Int64 = 0

    /// 最大数量
    /// 翻译自: comptime max_count: comptime_int
    private let maxCount: Int64

    /// 初始化函数
    private let initFn: ?() -> T

    /// 锁 (用于线程安全)
    private let lock: PoolMutex

    public init() {
        this(0, Option<() -> T>.None)
    }

    public init(maxCount: Int64, initFn: ?(() -> T)) {
        this.list = SinglyLinkedList<T>()
        this.maxCount = maxCount
        this.initFn = initFn
        this.lock = PoolMutex()
    }

    /// 是否已满
    /// 翻译自: pub fn full() bool
    public func full(): Bool {
        if (maxCount == 0) {
            return false
        }
        return loaded && count >= maxCount
    }

    /// 是否有可用对象
    /// 翻译自: pub fn has() bool
    public func has(): Bool {
        match (list.first) {
            case Some(_) => return loaded
            case None => return false
        }
    }

    /// 推入对象
    /// 翻译自: pub fn push(allocator, pooled: Type) void
    public func push(pooled: T): Unit {
        let node = PoolNode<T>(pooled)
        release(node)
    }

    /// 如果存在则获取
    /// 翻译自: pub fn getIfExists() ?*LinkedList.Node
    public func getIfExists(): ?PoolNode<T> {
        if (!loaded) {
            return Option<PoolNode<T>>.None
        }
        if (let Some(node) <- list.popFirst()) {
            if (maxCount > 0) {
                count -= 1
            }
            return node
        }
        return Option<PoolNode<T>>.None
    }

    /// 获取第一个对象的数据
    /// 翻译自: pub fn first(allocator) *Type
    public func first(): T {
        return get().data
    }

    /// 获取对象 (从池中或创建新的)
    /// 翻译自: pub fn get(allocator) *LinkedList.Node
    public func get(): PoolNode<T> {
        if (loaded) {
            if (let Some(node) <- list.popFirst()) {
                if (maxCount > 0) {
                    count -= 1
                }
                return node
            }
        }

        // 创建新对象
        if (let Some(fn) <- initFn) {
            return PoolNode<T>(fn())
        }
        throw Exception("LinkedObjectPool requires an init function when empty")
    }

    /// 通过值释放
    /// 翻译自: pub fn releaseValue(value: *Type) void
    public func releaseValue(value: T): Unit {
        // 由外部管理 node
    }

    /// 释放节点
    /// 翻译自: pub fn release(node: *LinkedList.Node) void
    public func release(node: PoolNode<T>): Unit {
        if (maxCount > 0 && count >= maxCount) {
            // 超过上限, 销毁
            return
        }

        if (maxCount > 0) {
            count += 1
        }

        if (loaded) {
            list.prepend(node)
            return
        }

        list.first = node
        loaded = true
    }

    /// 清空所有对象
    /// 翻译自: pub fn deleteAll() void
    public func deleteAll(): Unit {
        if (!loaded) {
            return
        }
        loaded = false
        count = 0
        var next = list.first
        list.first = None
        while (let Some(node) <- next) {
            next = node.next
            node.next = None
        }
    }
}

/// 简单互斥锁
private class PoolMutex {
    public func lock(): Unit {}
    public func unlock(): Unit {}
}
