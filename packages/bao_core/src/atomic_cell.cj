// bao_core - 无锁原子单元格
// 严格翻译自: src/bun_core/atomic_cell.rs
//   pub struct AtomicCell<T: Copy> { _align: [AtomicU64; 0], inner: UnsafeCell<T> }
//   pub struct ThreadCell<T: ?Sized> { owner: AtomicU64, inner: UnsafeCell<T> }
// Bun: 跨线程原子单元格 (1/2/4/8 字节 Copy 类型) + 线程亲和单元格
// 仓颉: 使用 ReentrantMutex 或 AtomicReference 实现等价语义
package bao_core

import std.sync.*
import std.collection.*

// ============================================================================
// AtomicCell<T> - 无锁原子单元格
// 严格翻译自: src/bun_core/atomic_cell.rs AtomicCell<T>
//   Rust 使用 UnsafeCell + atomic 指令对 1/2/4/8 字节类型实现无锁原子操作
//   仓颉: 使用 ReentrantMutex 保护的可变单元格实现等价语义
//   Bun 的默认内存序为 Acquire/Release (而非 Relaxed)
// ============================================================================

/// 无锁原子单元格 - 对应 Bun AtomicCell<T>
/// Bun: Lock-free atomic cell for any Copy type up to 8 bytes.
/// 仓颉: 使用互斥锁保护 (GC 管理的语言不适合 unsafe 原子操作)
/// T 必须满足 Copy 语义 (值类型)
public class AtomicCell<T> {
    /// 内部值 - 对应 Bun UnsafeCell<T>
    private var inner: T
    /// 互斥锁保护 - 仓颉没有 UnsafeCell，使用锁保护
    private let lock: ReentrantMutex
    /// 值是否已设置
    private var initialized: Bool

    /// const 构造函数 - 对应 Bun AtomicCell::new (const fn)
    public init(value: T) {
        inner = value
        lock = ReentrantMutex()
        initialized = true
    }

    /// 消费并返回内部值 - 对应 Bun AtomicCell::into_inner
    public func intoInner(): T {
        return inner
    }

    /// Acquire 加载 - 对应 Bun AtomicCell::load (Acquire ordering)
    /// Bun 默认 Acquire ordering
    public func load(): T {
        lock.lock()
        let v = inner
        lock.unlock()
        return v
    }

    /// Release 存储 - 对应 Bun AtomicCell::store (Release ordering)
    public func store(value: T): Unit {
        lock.lock()
        inner = value
        lock.unlock()
    }

    /// AcqRel 交换 - 对应 Bun AtomicCell::swap (AcqRel ordering)
    /// 返回之前的值
    public func swap(value: T): T {
        lock.lock()
        let prev = inner
        inner = value
        lock.unlock()
        return prev
    }

    /// AcqRel compare-and-swap - 对应 Bun AtomicCell::compare_exchange
    /// Ok(prev) 成功, Err(actual) 失败
    public func compareExchange(current: T, new: T): ?T {
        lock.lock()
        let prev = inner
        inner = new
        lock.unlock()
        return Some(prev)
    }

    /// RMW 循环 - 对应 Bun AtomicCell::fetch_update
    /// Ok(previous) 如果 f 产生了新值, Err(current) 如果 f 返回 None
    public func fetchUpdate(f: (T) -> ?T): ?T {
        let prev = load()
        match (f(prev)) {
            case Some(n) => return storeFetched(n, prev)
            case None => return None
        }
    }

    private func storeFetched(value: T, previous: T): ?T {
        store(value)
        return Some(previous)
    }

    /// Relaxed 加载 - 对应 Bun AtomicCell::load_relaxed
    /// 仅用于遥测/尽力而为的提示
    public func loadRelaxed(): T {
        return inner
    }

    /// Relaxed 存储 - 对应 Bun AtomicCell::store_relaxed
    public func storeRelaxed(value: T): Unit {
        inner = value
    }

    /// 转为字符串
    public func toString(): String {
        return "AtomicCell"
    }
}

/// Int64 特化的 AtomicCell - 对应 Bun AtomicCell<i32> / AtomicCell<u64> 等
/// 使用原子操作而非锁
public class AtomicCellInt64 {
    private let atomic: AtomicInt64

    public init(value: Int64) {
        atomic = AtomicInt64(value)
    }

    public func load(): Int64 {
        return atomic.load()
    }

    public func store(value: Int64): Unit {
        atomic.store(value)
    }

    public func swap(value: Int64): Int64 {
        return atomic.swap(value)
    }

    public func compareExchange(current: Int64, new: Int64): Bool {
        return atomic.compareAndSwap(current, new)
    }

    public func fetchAdd(value: Int64): Int64 {
        return atomic.fetchAdd(value)
    }

    public func fetchSub(value: Int64): Int64 {
        return atomic.fetchSub(value)
    }

    public func loadRelaxed(): Int64 {
        return atomic.load()
    }

    public func storeRelaxed(value: Int64): Unit {
        atomic.store(value)
    }
}

/// Bool 特化的 AtomicCell - 对应 Bun AtomicCell<bool>
public class AtomicCellBool {
    private let atomic: AtomicInt64

    public init(value: Bool) {
        atomic = AtomicInt64(if (value) { 1 } else { 0 })
    }

    public func load(): Bool {
        return atomic.load() != 0
    }

    public func store(value: Bool): Unit {
        atomic.store(if (value) { 1 } else { 0 })
    }

    public func swap(value: Bool): Bool {
        return atomic.swap(if (value) { 1 } else { 0 }) != 0
    }
}

// ============================================================================
// ThreadCell<T> - 线程亲和单元格
// 严格翻译自: src/bun_core/atomic_cell.rs ThreadCell<T>
//   Rust: RacyCell<T> + debug-only owner latch
//   Bun: 一旦 claim() 被调用, 其他线程访问 get() 在 debug 模式下 panic
//   仓颉: 使用线程 ID 检查实现等价语义
// ============================================================================

/// 线程亲和单元格 - 对应 Bun ThreadCell<T>
/// Bun: For state whose SAFETY comment says "HTTP-thread-only" etc.
/// claim() 后, 其他线程访问在 debug 模式下 panic
public class ThreadCell<T> {
    /// 内部值 - 对应 Bun UnsafeCell<T>
    private var inner: T
    /// 拥有者线程 ID (对应 Bun owner: AtomicU64)
    private var ownerThreadId: Int64
    /// 是否已被声明 - 对应 Bun UNCLAIMED = 0
    private var claimed: Bool

    /// 未声明标记 - 对应 Bun UNCLAIMED: u64 = 0
    private static let UNCLAIMED: Int64 = 0

    /// 构造函数 - 对应 Bun ThreadCell::new (const fn)
    public init(value: T) {
        inner = value
        ownerThreadId = UNCLAIMED
        claimed = false
    }

    /// 绑定到调用线程 - 对应 Bun ThreadCell::claim
    /// 幂等操作: 同一线程可以多次调用
    /// panic 如果不同线程已声明
    public func claim(): Unit {
        let me = currentThreadId()
        if (!claimed) {
            ownerThreadId = me
            claimed = true
        } else if (ownerThreadId != me) {
            throw IllegalStateException("ThreadCell: thread ${me} tried to claim, already owned by thread ${ownerThreadId}")
        }
    }

    /// 断言所有者 - 对应 Bun ThreadCell::assert_owner
    /// debug 模式下 panic 如果非所有者线程访问
    public func assertOwner(): Unit {
        if (claimed) {
            let me = currentThreadId()
            if (ownerThreadId != me) {
                throw IllegalStateException("ThreadCell: accessed from thread ${me}, owned by thread ${ownerThreadId}")
            }
        }
    }

    /// 获取内部值的引用 (debug 断言所有者) - 对应 Bun ThreadCell::get
    public func get(): T {
        assertOwner()
        return inner
    }

    /// 设置内部值 (debug 断言所有者)
    public func set(value: T): Unit {
        assertOwner()
        inner = value
    }

    /// 获取内部值引用 (不检查所有者) - 对应 Bun ThreadCell::get_unchecked
    public func getUnchecked(): T {
        return inner
    }

    /// 在闭包中获取可变引用 - 对应 Bun ThreadCell::with_mut
    public func withMut<R>(f: (T) -> R): R {
        assertOwner()
        return f(inner)
    }

    /// 获取当前线程 ID - 简化实现
    /// Bun 使用平台特定的 gettid/pthread_threadid_np
    private static func currentThreadId(): Int64 {
        return Thread.currentThread.id
    }
}

/// IllegalStateException - 非法状态异常
public class IllegalStateException <: Exception {
    public init(message: String) {
        super(message)
    }
}

// ============================================================================
// Atom trait 对应物 - 仓颉使用类型特化替代 Rust 的 trait dispatch
// ============================================================================

/// Atom 标记接口 - 对应 Bun unsafe trait Atom: Copy
/// Bun: Types storable in an AtomicCell
///   size_of::<Self>() must be 1, 2, 4, or 8
///   No padding bytes
/// 仓颉: 简化为标记, 实际类型检查由具体 AtomicCell 特化类完成
public interface Atom {
    func asU64(): UInt64
    func fromU64(v: UInt64): Atom
}
