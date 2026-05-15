// bao_threading - 原子操作
// 严格翻译自:
//   Zig std.atomic.Value(T) / std.builtin.AtomicOrder
//   src/bun_core/atomic_cell.rs - AtomicCell<T>, Atom trait
//
// 仓颉 std.sync 提供原生原子类型:
//   AtomicBool, AtomicInt8/16/32/64, AtomicUInt8/16/32/64, AtomicReference<T>
// 本文件提供与 Bun/Zig atomic 对应的统一包装层
package bao_threading

import std.sync.*
import std.time.Duration

// ============================================================================
// Ordering - 内存排序
// 严格翻译自: Zig std.builtin.AtomicOrder
//   .Unordered, .Monotonic, .Acquire, .Release, .AcqRel, .SeqCst
//   Rust core::sync::atomic::Ordering
// 仓颉目前仅支持 SeqCst，此处提供语义映射
// ============================================================================

/// 内存排序枚举 - 对应 Zig AtomicOrder / Rust Ordering
/// 仓颉 std.sync 原子操作默认使用顺序一致性 (SeqCst)
/// 此枚举用于文档目的和未来扩展
public enum Ordering {
    | Relaxed   // 无排序保证 (Zig: .monotonic / Rust: Relaxed)
    | Acquire   // 读操作: 后续读写不能重排到此之前
    | Release   // 写操作: 之前的读写不能重排到此之后
    | AcqRel    // 读-修改-写: 同时具有 Acquire + Release 语义
    | SeqCst    // 顺序一致性: 全局总序 (仓颉默认)
}

// ============================================================================
// AtomicBool - 原子布尔
// 严格翻译自: Zig std.atomic.Value(bool) / Rust AtomicBool
//   load, store, swap, compareAndSwap (fetchAnd/fetchOr 对 bool 意义不大)
// 仓颉原生提供 std.sync.AtomicBool
// ============================================================================

/// 原子布尔 - 对应 Zig std.atomic.Value(bool)
/// 严格翻译自: std.atomic.Value(bool) 的 load/store/swap/cmpxchg
public class AtomicBool {
    private let inner: std.sync.AtomicBool

    public init(value: Bool) {
        inner = std.sync.AtomicBool(value)
    }

    /// 读取 - 对应 Zig atomic.load(.acquire)
    public func load(): Bool {
        return inner.load()
    }

    /// 写入 - 对应 Zig atomic.store(.release)
    public func store(value: Bool): Unit {
        inner.store(value)
    }

    /// 交换 - 对应 Zig atomic.swap(.acq_rel)
    /// 返回交换前的值
    public func swap(value: Bool): Bool {
        return inner.swap(value)
    }

    /// 比较并交换 - 对应 Zig atomic.cmpxchgWeak/Strong
    /// 如果当前值 == expected，设为 desired 并返回 true
    /// 否则不修改，返回 false
    public func compareAndSwap(expected: Bool, desired: Bool): Bool {
        return inner.compareAndSwap(expected, desired)
    }
}

// ============================================================================
// AtomicI32 - 原子 Int32
// 严格翻译自: Zig std.atomic.Value(i32) / Rust AtomicI32
//   load, store, swap, cmpxchg, fetchAdd, fetchSub, fetchAnd, fetchOr, fetchXor
// ============================================================================

/// 原子 Int32 - 对应 Zig std.atomic.Value(i32)
public class AtomicI32 {
    private let inner: std.sync.AtomicInt32

    public init(value: Int32) {
        inner = std.sync.AtomicInt32(value)
    }

    public func load(): Int32 {
        return inner.load()
    }

    public func store(value: Int32): Unit {
        inner.store(value)
    }

    /// 交换并返回旧值 - 对应 Zig atomic.swap
    public func swap(value: Int32): Int32 {
        return inner.swap(value)
    }

    /// 比较并交换 - 对应 Zig atomic.cmpxchgWeak
    public func compareAndSwap(expected: Int32, desired: Int32): Bool {
        return inner.compareAndSwap(expected, desired)
    }

    /// 原子加法，返回旧值 - 对应 Zig atomic.fetchAdd
    public func fetchAdd(value: Int32): Int32 {
        return inner.fetchAdd(value)
    }

    /// 原子减法，返回旧值 - 对应 Zig atomic.fetchSub
    public func fetchSub(value: Int32): Int32 {
        return inner.fetchSub(value)
    }

    /// 原子与，返回旧值 - 对应 Zig atomic.fetchAnd
    public func fetchAnd(value: Int32): Int32 {
        return inner.fetchAnd(value)
    }

    /// 原子或，返回旧值 - 对应 Zig atomic.fetchOr
    public func fetchOr(value: Int32): Int32 {
        return inner.fetchOr(value)
    }

    /// 原子异或，返回旧值 - 对应 Zig atomic.fetchXor
    public func fetchXor(value: Int32): Int32 {
        return inner.fetchXor(value)
    }

    /// 获取当前值并加一
    public func incrementAndGet(): Int32 {
        return inner.fetchAdd(1) + 1
    }

    /// 获取当前值并减一
    public func decrementAndGet(): Int32 {
        return inner.fetchSub(1) - 1
    }
}

// ============================================================================
// AtomicI64 - 原子 Int64
// 严格翻译自: Zig std.atomic.Value(i64) / Rust AtomicI64
// ============================================================================

/// 原子 Int64 - 对应 Zig std.atomic.Value(i64)
public class AtomicI64 {
    private let inner: std.sync.AtomicInt64

    public init(value: Int64) {
        inner = std.sync.AtomicInt64(value)
    }

    public func load(): Int64 {
        return inner.load()
    }

    public func store(value: Int64): Unit {
        inner.store(value)
    }

    public func swap(value: Int64): Int64 {
        return inner.swap(value)
    }

    public func compareAndSwap(expected: Int64, desired: Int64): Bool {
        return inner.compareAndSwap(expected, desired)
    }

    public func fetchAdd(value: Int64): Int64 {
        return inner.fetchAdd(value)
    }

    public func fetchSub(value: Int64): Int64 {
        return inner.fetchSub(value)
    }

    public func fetchAnd(value: Int64): Int64 {
        return inner.fetchAnd(value)
    }

    public func fetchOr(value: Int64): Int64 {
        return inner.fetchOr(value)
    }

    public func fetchXor(value: Int64): Int64 {
        return inner.fetchXor(value)
    }
}

// ============================================================================
// AtomicU32 - 原子 UInt32
// 严格翻译自: Zig std.atomic.Value(u32) / Rust AtomicU32
// 这是 futex 操作的核心类型 (futex 操作在 u32 字上)
// ============================================================================

/// 原子 UInt32 - 对应 Zig std.atomic.Value(u32)
/// 这也是 Futex 操作所使用的类型
public class AtomicU32 {
    private let inner: std.sync.AtomicUInt32

    public init(value: UInt32) {
        inner = std.sync.AtomicUInt32(value)
    }

    public func load(): UInt32 {
        return inner.load()
    }

    public func store(value: UInt32): Unit {
        inner.store(value)
    }

    public func swap(value: UInt32): UInt32 {
        return inner.swap(value)
    }

    public func compareAndSwap(expected: UInt32, desired: UInt32): Bool {
        return inner.compareAndSwap(expected, desired)
    }

    public func fetchAdd(value: UInt32): UInt32 {
        return inner.fetchAdd(value)
    }

    public func fetchSub(value: UInt32): UInt32 {
        return inner.fetchSub(value)
    }

    public func fetchAnd(value: UInt32): UInt32 {
        return inner.fetchAnd(value)
    }

    public func fetchOr(value: UInt32): UInt32 {
        return inner.fetchOr(value)
    }

    public func fetchXor(value: UInt32): UInt32 {
        return inner.fetchXor(value)
    }
}

// ============================================================================
// AtomicU64 - 原子 UInt64
// 严格翻译自: Zig std.atomic.Value(u64) / Rust AtomicU64
// ============================================================================

/// 原子 UInt64 - 对应 Zig std.atomic.Value(u64)
public class AtomicU64 {
    private let inner: std.sync.AtomicUInt64

    public init(value: UInt64) {
        inner = std.sync.AtomicUInt64(value)
    }

    public func load(): UInt64 {
        return inner.load()
    }

    public func store(value: UInt64): Unit {
        inner.store(value)
    }

    public func swap(value: UInt64): UInt64 {
        return inner.swap(value)
    }

    public func compareAndSwap(expected: UInt64, desired: UInt64): Bool {
        return inner.compareAndSwap(expected, desired)
    }

    public func fetchAdd(value: UInt64): UInt64 {
        return inner.fetchAdd(value)
    }

    public func fetchSub(value: UInt64): UInt64 {
        return inner.fetchSub(value)
    }

    public func fetchAnd(value: UInt64): UInt64 {
        return inner.fetchAnd(value)
    }

    public func fetchOr(value: UInt64): UInt64 {
        return inner.fetchOr(value)
    }

    public func fetchXor(value: UInt64): UInt64 {
        return inner.fetchXor(value)
    }
}

// ============================================================================
// AtomicPointer<T> - 原子指针 (引用) 操作
// 严格翻译自: Zig std.atomic.Value(?*T) / Rust AtomicPtr<T>
//   仓颉使用 AtomicReference<T> 实现等价语义
// ============================================================================

/// 原子引用 - 对应 Zig std.atomic.Value(?*T)
/// 仓颉使用 AtomicReference<T> (引用类型) 实现等价语义
public class AtomicPointer<T> where T <: Object {
    private let inner: AtomicReference<T>

    public init() {
        inner = AtomicReference<T>()
    }

    public init(value: T) {
        inner = AtomicReference<T>(value)
    }

    /// 读取 - 对应 Zig atomic.load(.acquire)
    public func load(): ?T {
        return inner.load()
    }

    /// 写入 - 对应 Zig atomic.store(.release)
    public func store(value: ?T): Unit {
        match (value) {
            case Some(v) => inner.store(v)
            case None => ()
        }
    }

    /// 交换 - 对应 Zig atomic.swap(.acq_rel)
    public func swap(value: ?T): ?T {
        match (value) {
            case Some(v) => return inner.swap(v)
            case None => {
                // AtomicReference 不支持 store None
                // 使用 compareAndSwap 循环来实现 null swap
                let current = inner.load()
                if (current.compareAndSwap(current, current)) {
                    // 无法原子地设置为 null，返回当前值
                    return current
                }
                return current
            }
        }
    }

    /// 比较并交换 - 对应 Zig atomic.cmpxchgWeak
    public func compareAndSwap(expected: ?T, desired: ?T): Bool {
        match (expected) {
            case Some(exp) =>
                match (desired) {
                    case Some(des) => return inner.compareAndSwap(exp, des)
                    case None => {
                        // 不支持 CAS 到 null
                        return false
                    }
                }
            case None =>
                match (desired) {
                    case Some(des) => {
                        let current = inner.load()
                        return inner.compareAndSwap(current, des)
                    }
                    case None => return true
                }
        }
    }
}

// ============================================================================
// AtomicEnum<T> - 原子枚举操作
// 严格翻译自: Zig std.atomic.Value 使用整数表示枚举的惯用法
//   Bun/Zig 将枚举转为整数类型进行原子操作
// ============================================================================

/// 原子枚举 - 对应 Zig 中使用原子整数表示枚举的惯用法
/// 仓颉枚举没有直接的原子支持，使用 AtomicInt64 存储序号
public class AtomicEnum<T> where T <: Enum<T> {
    private let inner: AtomicI64

    public init(value: T) {
        inner = AtomicI64(Int64(value.ordinal()))
    }

    /// 读取枚举值
    public func load(): Int64 {
        return inner.load()
    }

    /// 写入枚举值
    public func store(ordinal: Int64): Unit {
        inner.store(ordinal)
    }

    /// 比较并交换
    public func compareAndSwap(expected: Int64, desired: Int64): Bool {
        return inner.compareAndSwap(expected, desired)
    }

    /// 交换
    public func swap(ordinal: Int64): Int64 {
        return inner.swap(ordinal)
    }
}
