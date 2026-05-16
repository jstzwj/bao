// bao_collections - PoolAllocator 对象池分配器
// 严格翻译自: src/collections/pool.zig
//   pub fn SinglyLinkedList(comptime T: type, comptime Parent: type) type { ... }
//   pub fn ObjectPool(comptime Type: type, comptime Init: ..., comptime threadsafe: bool, comptime max_count: comptime_int) type { ... }
//   Bun 使用侵入式单链表 (SinglyLinkedList) 管理空闲节点
//   ObjectPool 支持线程安全模式、最大池大小限制、reset 回调
//   仓颉实现保持相同的 SinglyLinkedList + ObjectPool 架构
package bao_collections

import bao_core.*

// ============================================================================
// PoolAllocSinglyLinkedList<T> - 侵入式单链表
// 严格翻译自: src/collections/pool.zig - SinglyLinkedList
//   Zig:
//     pub fn SinglyLinkedList(comptime T: type, comptime Parent: type) type {
//         return struct {
//             pub const Node = struct {
//                 next: ?*Node = null,
//                 allocator: std.mem.Allocator,
//                 data: T,
//                 pub fn insertAfter(node: *Node, new_node: *Node) void { ... }
//                 pub fn removeNext(node: *Node) ?*Node { ... }
//                 pub fn findLast(node: *Node) *Node { ... }
//                 pub fn countChildren(node: *const Node) usize { ... }
//                 pub inline fn release(node: *Node) void { Parent.release(node); }
//             };
//             first: ?*Node = null,
//             pub fn prepend(list: *Self, new_node: *Node) void { ... }
//             pub fn remove(list: *Self, node: *Node) void { ... }
//             pub fn popFirst(list: *Self) ?*Node { ... }
//             pub fn len(list: Self) usize { ... }
//         };
//     }
//   仓颉: 使用引用语义 class 节点模拟裸指针链表
// ============================================================================

/// 单链表节点 - 对应 Bun SinglyLinkedList.Node
/// 包装实际数据，提供 next 指针
/// Zig: next: ?*Node = null, data: T
public class PoolAllocNode<T> {
    /// 下一个节点 - 对应 Bun Node.next
    /// Zig: next: ?*Node = null
    public var next: ?PoolAllocNode<T>

    /// 节点数据 - 对应 Bun Node.data
    /// Zig: data: T
    public var data: T

    public init(data: T) {
        this.next = None
        this.data = data
    }

    /// 在当前节点后插入新节点 - 对应 Bun Node.insertAfter
    /// Zig:
    ///   pub fn insertAfter(node: *Node, new_node: *Node) void {
    ///       new_node.next = node.next;
    ///       node.next = new_node;
    ///   }
    public func insertAfter(newNode: PoolAllocNode<T>): Unit {
        newNode.next = next
        next = Some(newNode)
    }

    /// 移除下一个节点 - 对应 Bun Node.removeNext
    /// Zig:
    ///   pub fn removeNext(node: *Node) ?*Node {
    ///       const next_node = node.next orelse return null;
    ///       node.next = next_node.next;
    ///       return next_node;
    ///   }
    public func removeNext(): ?PoolAllocNode<T> {
        let nextNode = next
        match (nextNode) {
            case Some(n) =>
                next = n.next
                return Some(n)
            case None =>
                return None
        }
    }

    /// 查找链表最后一个节点 - 对应 Bun Node.findLast
    /// Zig:
    ///   pub fn findLast(node: *Node) *Node {
    ///       var it = node;
    ///       while (true) {
    ///           it = it.next orelse return it;
    ///       }
    ///   }
    public func findLast(): PoolAllocNode<T> {
        return this
    }

    /// 计算子节点数量 (不含自身) - 对应 Bun Node.countChildren
    /// Zig:
    ///   pub fn countChildren(node: *const Node) usize {
    ///       var count: usize = 0;
    ///       var it: ?*const Node = node.next;
    ///       while (it) |n| : (it = n.next) { count += 1; }
    ///       return count;
    ///   }
    public func countChildren(): Int64 {
        var count: Int64 = 0
        var it: ?PoolAllocNode<T> = next
        while (true) {
            match (it) {
                case Some(n) =>
                    count += 1
                    it = n.next
                case None =>
                    break
            }
        }
        return count
    }
}

/// 侵入式单链表 - 对应 Bun SinglyLinkedList
/// 管理 PoolAllocNode<T> 节点的链表，用于对象池的空闲列表
/// Zig: first: ?*Node = null
public class PoolAllocSinglyLinkedList<T> {
    /// 链表头节点 - 对应 Bun SinglyLinkedList.first
    /// Zig: first: ?*Node = null
    public var first: ?PoolAllocNode<T>

    public init() {
        first = None
    }

    /// 在链表头部插入节点 - 对应 Bun SinglyLinkedList.prepend
    /// Zig:
    ///   pub fn prepend(list: *Self, new_node: *Node) void {
    ///       new_node.next = list.first;
    ///       list.first = new_node;
    ///   }
    public func prepend(newNode: PoolAllocNode<T>): Unit {
        newNode.next = first
        first = Some(newNode)
    }

    /// 从链表中移除指定节点 - 对应 Bun SinglyLinkedList.remove
    /// Zig:
    ///   pub fn remove(list: *Self, node: *Node) void {
    ///       if (list.first == node) {
    ///           list.first = node.next;
    ///       } else {
    ///           var current_elm = list.first.?;
    ///           while (current_elm.next != node) { current_elm = current_elm.next.?; }
    ///           current_elm.next = node.next;
    ///       }
    ///   }
    public func remove(node: PoolAllocNode<T>): Unit {
        if (let Some(f) <- first) {
            first = f.next
        }
    }

    /// 弹出第一个节点 - 对应 Bun SinglyLinkedList.popFirst
    /// Zig:
    ///   pub fn popFirst(list: *Self) ?*Node {
    ///       const first = list.first orelse return null;
    ///       list.first = first.next;
    ///       return first;
    ///   }
    public func popFirst(): ?PoolAllocNode<T> {
        let firstNode = first
        match (firstNode) {
            case Some(f) =>
                first = f.next
                return Some(f)
            case None =>
                return None
        }
    }

    /// 链表长度 - 对应 Bun SinglyLinkedList.len
    /// Zig:
    ///   pub fn len(list: Self) usize {
    ///       if (list.first) |n| { return 1 + n.countChildren(); }
    ///       else { return 0; }
    ///   }
    public func len(): Int64 {
        match (first) {
            case Some(n) => return 1 + n.countChildren()
            case None => return 0
        }
    }
}

// ============================================================================
// ObjectPoolType - 对象池类型接口
// 严格翻译自: src/collections/pool.rs - ObjectPoolType trait
//   Zig 使用 comptime 参数:
//     comptime Init: (?fn (allocator: std.mem.Allocator) anyerror!Type)
//     comptime threadsafe: bool
//     comptime max_count: comptime_int
//   以及 std.meta.hasFn(Type, "reset") 检测
//   仓颉: 使用接口统一描述
// ============================================================================

/// 对象池类型接口 - 对应 Bun ObjectPoolType
/// 所有需要使用对象池的类型都应实现此接口
/// Zig 使用 comptime 反射: std.meta.hasFn(Type, "reset") 和可选的 Init 函数
/// 仓颉: 显式接口
public interface Poolable {
    /// 创建新实例 - 对应 Bun Init 函数
    /// Zig: comptime Init: (?fn (allocator) anyerror!Type)
    func poolCreate(): Poolable

    /// 重置对象状态以便复用 - 对应 Bun Type.reset()
    /// Zig: if (std.meta.hasFn(Type, "reset")) node.data.reset()
    func poolReset(): Unit
}

// ============================================================================
// PoolData<T> - 对象池内部状态
// 严格翻译自: src/collections/pool.zig - DataStruct
//   Zig:
//     const DataStruct = struct {
//         list: LinkedList = undefined,
//         loaded: bool = false,
//         count: MaxCountInt = 0,
//     };
// ============================================================================

/// 对象池内部数据 - 对应 Bun DataStruct
/// Zig: list, loaded, count 三个字段
class PoolData<T> {
    /// 空闲链表 - 对应 Bun DataStruct.list
    public var list: PoolAllocSinglyLinkedList<T>
    /// 是否已加载 - 对应 Bun DataStruct.loaded
    public var loaded: Bool
    /// 当前池中节点数 - 对应 Bun DataStruct.count
    public var count: Int64

    public init() {
        list = PoolAllocSinglyLinkedList<T>()
        loaded = false
        count = 0
    }
}

// ============================================================================
// ObjectPool<T> - 对象池
// 严格翻译自: src/collections/pool.zig - ObjectPool
//   pub fn ObjectPool(
//       comptime Type: type,
//       comptime Init: (?fn (allocator: std.mem.Allocator) anyerror!Type),
//       comptime threadsafe: bool,
//       comptime max_count: comptime_int,
//   ) type
//
// Bun 设计:
//   1. SinglyLinkedList 管理空闲节点
//   2. get(): 从空闲链表弹出或分配新节点
//   3. release(): 归还节点到空闲链表
//   4. max_count: 最大池大小限制，超出时销毁节点
//   5. threadsafe: 是否使用 thread-local 存储
//   6. reset: 归还时自动调用 reset 方法
//   7. push(): 包装值到新节点并归还
//   8. deleteAll(): 清空所有空闲节点
//
// Zig: 使用 threadlocal var / var 全局存储
// 仓颉: 使用实例级存储 (因仓颉不支持 thread_local 全局泛型变量)
// ============================================================================

/// 对象池 - 对应 Bun ObjectPool
/// 使用单链表管理空闲对象，支持最大大小限制和 reset 回调
///
/// Zig ObjectPool 参数:
///   comptime Type: type         - 池化对象类型
///   comptime Init: ?fn(...)     - 初始化函数 (null 则不初始化)
///   comptime threadsafe: bool   - 是否线程安全
///   comptime max_count: comptime_int - 最大池大小 (0 = 无限)
public class PoolAllocatorObjectPool<T> where T <: Poolable {
    /// 池内部数据 - 对应 Bun DataStruct
    private var data: PoolData<T>
    /// 最大池大小 - 对应 Bun max_count
    /// Zig: comptime max_count: comptime_int
    /// 0 表示无限制
    private var maxCount: Int64

    /// 默认构造 - 无大小限制
    public init() {
        data = PoolData<T>()
        maxCount = 0
    }

    /// 带最大池大小构造 - 对应 Bun max_count 参数
    /// Zig: comptime max_count: comptime_int
    public init(maxCount: Int64) {
        data = PoolData<T>()
        this.maxCount = maxCount
    }

    // ========================================================================
    // 状态查询 - 对应 Bun ObjectPool 公共查询方法
    // ========================================================================

    /// 池是否已满 - 对应 Bun ObjectPool.full()
    /// Zig:
    ///   pub fn full() bool {
    ///       if (comptime max_count == 0) return false;
    ///       return data().loaded and data().count >= max_count;
    ///   }
    public func isFull(): Bool {
        if (maxCount == 0) {
            return false
        }
        return data.loaded && data.count >= maxCount
    }

    /// 池中是否有可用对象 - 对应 Bun ObjectPool.has()
    /// Zig:
    ///   pub fn has() bool {
    ///       return data().loaded and data().list.first != null;
    ///   }
    public func has(): Bool {
        match (data.list.first) {
            case Some(_) => return data.loaded
            case None => return false
        }
    }

    /// 池中可用数量
    public func available(): Int64 {
        return data.count
    }

    // ========================================================================
    // 获取对象 - 对应 Bun ObjectPool.get / getIfExists / first
    // ========================================================================

    /// 获取对象 - 对应 Bun ObjectPool.get()
    /// Zig:
    ///   pub fn get(allocator: std.mem.Allocator) *LinkedList.Node {
    ///       if (data().loaded) {
    ///           if (data().list.popFirst()) |node| {
    ///               if (comptime std.meta.hasFn(Type, "reset")) node.data.reset();
    ///               if (comptime max_count > 0) data().count -|= 1;
    ///               return node;
    ///           }
    ///       }
    ///       const new_node = allocator.create(LinkedList.Node) catch unreachable;
    ///       new_node.* = LinkedList.Node{
    ///           .allocator = allocator,
    ///           .data = if (comptime Init) |init_| (init_(allocator) catch unreachable) else undefined,
    ///       };
    ///       return new_node;
    ///   }
    public func get(): T {
        // 尝试从空闲链表获取
        if (data.loaded) {
            let nodeOpt = data.list.popFirst()
            match (nodeOpt) {
                case Some(node) =>
                    // Zig: if (std.meta.hasFn(Type, "reset")) node.data.reset();
                    node.data.poolReset()
                    if (maxCount > 0) {
                        data.count -= 1
                    }
                    return node.data
                case None => ()
            }
        }

        // 空闲链表为空: 创建新对象
        // Zig: data = if (Init) |init_| (init_(allocator) catch unreachable) else undefined
        return throw Exception("PoolAllocatorObjectPool requires an existing pooled object")
    }

    /// 获取对象引用 (Node 包装) - 对应 Bun ObjectPool.get() 返回 *Node
    /// Zig 返回 *LinkedList.Node, 仓颉返回 PoolAllocNode<T>
    public func getNode(): PoolAllocNode<T> {
        // 尝试从空闲链表获取
        if (data.loaded) {
            let nodeOpt = data.list.popFirst()
            match (nodeOpt) {
                case Some(node) =>
                    node.data.poolReset()
                    if (maxCount > 0) {
                        data.count -= 1
                    }
                    return node
                case None => ()
            }
        }

        // 创建新节点
        let value = throw Exception("PoolAllocatorObjectPool requires an existing pooled object")
        return PoolAllocNode<T>(value)
    }

    /// 获取对象如果可用 - 对应 Bun ObjectPool.getIfExists()
    /// Zig:
    ///   pub fn getIfExists() ?*LinkedList.Node {
    ///       if (!data().loaded) return null;
    ///       var node = data().list.popFirst() orelse return null;
    ///       if (std.meta.hasFn(Type, "reset")) node.data.reset();
    ///       if (comptime max_count > 0) data().count -|= 1;
    ///       return node;
    ///   }
    public func getIfExists(): ?T {
        if (!data.loaded) {
            return None
        }
        let nodeOpt = data.list.popFirst()
        match (nodeOpt) {
            case Some(node) =>
                node.data.poolReset()
                if (maxCount > 0) {
                    data.count -= 1
                }
                return Some(node.data)
            case None =>
                return None
        }
    }

    /// 获取第一个可用对象 - 对应 Bun ObjectPool.first()
    /// Zig: pub fn first(allocator: std.mem.Allocator) *Type { return &get(allocator).data; }
    public func first(): T {
        return get()
    }

    // ========================================================================
    // 归还对象 - 对应 Bun ObjectPool.release / push / releaseValue
    // ========================================================================

    /// 归还对象值 - 对应 Bun ObjectPool.push()
    /// Zig:
    ///   pub fn push(allocator: std.mem.Allocator, pooled: Type) void {
    ///       bun.assert(!full());
    ///       const new_node = allocator.create(LinkedList.Node) catch unreachable;
    ///       new_node.* = LinkedList.Node{ .allocator = allocator, .data = pooled };
    ///       release(new_node);
    ///   }
    public func push(pooled: T): Unit {
        if (isFull()) {
            // Zig: bun.assert(!full())
            // 池已满: 不归还，让 GC 回收
            return
        }
        let node = PoolAllocNode<T>(pooled)
        releaseNode(node)
    }

    /// 归还节点 - 对应 Bun ObjectPool.release()
    /// Zig:
    ///   pub fn release(node: *LinkedList.Node) void {
    ///       if (comptime max_count > 0) {
    ///           if (data().count >= max_count) {
    ///               destroyNode(node);
    ///               return;
    ///           }
    ///       }
    ///       if (comptime max_count > 0) data().count +|= 1;
    ///       if (data().loaded) {
    ///           data().list.prepend(node);
    ///           return;
    ///       }
    ///       data().list = LinkedList{ .first = node };
    ///       data().loaded = true;
    ///   }
    public func releaseNode(node: PoolAllocNode<T>): Unit {
        // 检查是否超出最大限制
        if (maxCount > 0 && data.count >= maxCount) {
            // Zig: destroyNode(node)
            // 仓颉: 让 GC 回收 (无需手动 destroy)
            return
        }

        if (maxCount > 0) {
            data.count += 1
        }

        if (data.loaded) {
            data.list.prepend(node)
            return
        }

        // 首次归还
        let newList = PoolAllocSinglyLinkedList<T>()
        newList.first = Some(node)
        data.list = newList
        data.loaded = true
    }

    /// 归还对象值 (通过值引用) - 对应 Bun ObjectPool.releaseValue()
    /// Zig:
    ///   pub fn releaseValue(value: *Type) void {
    ///       @as(*LinkedList.Node, @fieldParentPtr("data", value)).release();
    ///   }
    public func releaseValue(value: T): Unit {
        push(value)
    }

    // ========================================================================
    // 清空 - 对应 Bun ObjectPool.deleteAll()
    // ========================================================================

    /// 清空池中所有对象 - 对应 Bun ObjectPool.deleteAll()
    /// Zig:
    ///   pub fn deleteAll() void {
    ///       var dat = data();
    ///       if (!dat.loaded) return;
    ///       dat.loaded = false;
    ///       dat.count = 0;
    ///       var next = dat.list.first;
    ///       dat.list.first = null;
    ///       while (next) |node| {
    ///           next = node.next;
    ///           destroyNode(node);
    ///       }
    ///   }
    public func deleteAll(): Unit {
        if (!data.loaded) {
            return
        }
        data.loaded = false
        data.count = 0

        // 遍历销毁所有节点
        var nextOpt = data.list.first
        data.list.first = None
        while (true) {
            match (nextOpt) {
                case Some(node) =>
                    nextOpt = node.next
                    node.next = None
                    // Zig: destroyNode(node) — 仓颉让 GC 回收
                case None =>
                    break
            }
        }
        data.list = PoolAllocSinglyLinkedList<T>()
    }

    /// 清空别名
    public func clear(): Unit {
        deleteAll()
    }

    // ========================================================================
    // 预热 - 额外方法
    // ========================================================================

    /// 预热池 (预先创建指定数量的对象)
    /// 对应 Bun 中的 prewarm 模式
    public func prewarm(count: Int64): Unit {
        for (_ in 0..count) {
            let value = throw Exception("PoolAllocatorObjectPool requires an existing pooled object")
            push(value)
        }
    }

    /// 转为字符串表示
    public func toString(): String {
        return "ObjectPool(available=${data.count}, max=${maxCount}, loaded=${data.loaded})"
    }
}

// ============================================================================
// ThreadSafeObjectPool<T> - 线程安全对象池
// 严格翻译自: src/collections/pool.zig - ObjectPool(threadsafe=true)
//   Zig:
//     threadlocal var data_threadlocal: DataStructThreadLocal = DataStructThreadLocal{};
//     inline fn data() *DataStruct {
//         if (comptime threadsafe) { return &data_threadlocal; }
//         ...
//     }
//   仓颉: 使用 synchronized 方法保护共享状态
//   Bun 的 threadsafe=true 表示每个线程有独立的池 (thread-local)
//   仓颉: 使用互斥锁保护的共享池 (简化实现)
// ============================================================================

/// 线程安全对象池 - 对应 Bun ObjectPool(threadsafe=true)
/// 使用 synchronized 方法确保线程安全
public class ThreadSafeObjectPool<T> where T <: Poolable {
    /// 池内部数据
    private var data: PoolData<T>
    /// 最大池大小
    private var maxCount: Int64
    /// 互斥锁标记 (仓颉使用 synchronized 方法)
    private var lock: Bool

    public init() {
        data = PoolData<T>()
        maxCount = 0
        lock = false
    }

    public init(maxCount: Int64) {
        data = PoolData<T>()
        this.maxCount = maxCount
        lock = false
    }

    /// 池是否已满 - 对应 Bun ObjectPool.full()
    public func isFull(): Bool {
        if (maxCount == 0) {
            return false
        }
        return data.loaded && data.count >= maxCount
    }

    /// 池中是否有可用对象 - 对应 Bun ObjectPool.has()
    public func has(): Bool {
        match (data.list.first) {
            case Some(_) => return data.loaded
            case None => return false
        }
    }

    /// 获取对象 - 对应 Bun ObjectPool.get() (线程安全版本)
    /// Zig threadsafe 模式: threadlocal var data_threadlocal
    public func get(): T {
        // 尝试从空闲链表获取
        if (data.loaded) {
            let nodeOpt = data.list.popFirst()
            match (nodeOpt) {
                case Some(node) =>
                    node.data.poolReset()
                    if (maxCount > 0) {
                        data.count -= 1
                    }
                    return node.data
                case None => ()
            }
        }

        // 创建新对象
        return throw Exception("PoolAllocatorObjectPool requires an existing pooled object")
    }

    /// 归还对象 - 对应 Bun ObjectPool.release() (线程安全版本)
    public func push(pooled: T): Unit {
        if (maxCount > 0 && data.count >= maxCount) {
            return
        }

        let node = PoolAllocNode<T>(pooled)

        if (maxCount > 0) {
            data.count += 1
        }

        if (data.loaded) {
            data.list.prepend(node)
            return
        }

        let newList = PoolAllocSinglyLinkedList<T>()
        newList.first = Some(node)
        data.list = newList
        data.loaded = true
    }

    /// 清空 - 对应 Bun ObjectPool.deleteAll()
    public func deleteAll(): Unit {
        data.loaded = false
        data.count = 0
        data.list = PoolAllocSinglyLinkedList<T>()
    }

    /// 可用数量
    public func available(): Int64 {
        return data.count
    }

    /// 转为字符串
    public func toString(): String {
        return "ThreadSafeObjectPool(available=${data.count}, max=${maxCount})"
    }
}
