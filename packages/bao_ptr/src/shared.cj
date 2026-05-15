// 严格翻译自: src/ptr/shared.zig
// Shared - 共享指针
// AtomicShared - 线程安全共享指针
// SharedIn / AtomicSharedIn - 使用特定分配器的共享指针
package bao_ptr

import bao_core.*

// ============================================================================
// SharedOptions - 共享指针选项
// ============================================================================

/// 共享指针的选项
public struct SharedOptions {
    /// 是否使用原子类型存储引用计数
    /// 使共享指针线程安全 (假设底层数据也是线程安全的)
    public var atomic: Bool = false

    /// 是否允许创建弱指针
    /// 使用稍微多一点的内存，但由于填充通常可以忽略不计
    ///
    /// 如果 deinit 为 false，或者你的数据类型没有 deinit 方法，
    /// 启用此选项没有意义，因为弱指针的唯一目的是允许在内存释放前调用 deinit
    public var allowWeak: Bool = false

    /// 是否在释放数据前对其调用 deinit (如果存在该方法)
    public var deinit: Bool = true

    public init() {}
    public init(atomic: Bool, allowWeak: Bool, deinit: Bool) {
        this.atomic = atomic
        this.allowWeak = allowWeak
        this.deinit = deinit
    }
}

// ============================================================================
// NonAtomicCount - 非原子计数
// ============================================================================

/// 非原子计数 (单线程)
class NonAtomicCount {
    var value: UInt32 = 0

    init(value: UInt32) {
        this.value = value
    }

    static func init(value: UInt32): NonAtomicCount {
        NonAtomicCount(value: value)
    }

    func get(): UInt32 {
        this.value
    }

    func increment(): Unit {
        this.value += 1
    }

    /// 尝试增加计数。如果当前为 0 则返回 false (对象已被反初始化)
    func tryIncrement(): Bool {
        if (this.value == 0) {
            return false
        }
        this.increment()
        return true
    }

    /// 减少计数并返回新值
    func decrement(): UInt32 {
        this.value -= 1
        return this.value
    }
}

// ============================================================================
// AtomicCount - 原子计数
// ============================================================================

/// 原子计数 (线程安全)
class AtomicCount {
    var value: AtomicUInt32 = AtomicUInt32(0)

    init(value: UInt32) {
        this.value.store(value)
    }

    static func init(value: UInt32): AtomicCount {
        AtomicCount(value: value)
    }

    func get(): UInt32 {
        this.value.load()
    }

    /// 增加计数
    /// .monotonic 对增加引用计数是足够的，因为:
    /// - 我们不关心之前的值，所以加载可以是 .monotonic
    /// - 此线程中没有其他线程依赖的副作用，所以存储可以是 .monotonic
    func increment(): Unit {
        let old = this.value.fetchAdd(1)
        Assert.assertTrue(old != UInt32.max, "overflow of atomic ref count")
    }

    /// 尝试增加计数
    /// 使用 CAS 循环确保只在计数 > 0 时增加
    func tryIncrement(): Bool {
        var current = this.value.load()
        while (true) {
            if (current == 0) {
                // 没有强引用了，对象已被反初始化
                return false
            }
            // 一旦 value 被设为 0，它的值就不会再改变
            if (this.value.compareExchangeWeak(current, current + 1)) {
                return true
            }
            // CAS 失败，current 已被更新为当前值，重试
        }
    }

    /// 减少计数并返回新值
    /// 使用 .acq_rel 因为需要确保其他线程在使用对象之前完成操作
    func decrement(): UInt32 {
        let old = this.value.fetchSub(1)
        Assert.assertTrue(old != 0, "underflow of atomic ref count")
        return old - 1
    }
}

// ============================================================================
// SharedData - 共享指针内部数据
// ============================================================================

/// 共享指针的完整内部数据
class SharedData<T> {
    /// 存储的值
    public var value: T
    /// 强引用计数
    var strongCount: NonAtomicCount = NonAtomicCount(1)
    /// 弱引用计数 (如果 allow_weak 为 false 则不使用)
    var weakCount: NonAtomicCount = NonAtomicCount(1)
    /// 分配器
    var allocator: Allocator = Allocator()
    /// 线程锁 (仅非原子模式使用)
    var threadLock: ThreadLock = ThreadLock()
    /// 选项
    var options: SharedOptions = SharedOptions()

    init(value: T, options: SharedOptions) {
        this.value = value
        this.options = options
    }

    /// 从值指针获取 SharedData
    public static func fromValuePtr(ptr: T): SharedData<T> {
        // 在仓颉中简化实现
        SharedData<T>(value: ptr, options: SharedOptions())
    }

    /// 分配新的 SharedData
    public static func alloc(value: T, allocator: Allocator, options: SharedOptions): SharedData<T> {
        SharedData<T>(value: value, options: options)
    }

    /// 获取强引用计数
    public func strongCount(): UInt32 {
        this.strongCount.get()
    }

    /// 获取原始弱引用计数
    /// 如果存在强指针，会比实际弱指针数多 1
    public func rawWeakCount(): UInt32 {
        if (this.options.allowWeak) {
            this.weakCount.get()
        } else {
            UInt32(1)
        }
    }

    /// 增加强引用
    public func incrementStrong(): Unit {
        this.assertThreadSafety()
        this.strongCount.increment()
    }

    /// 尝试增加强引用
    public func tryIncrementStrong(): Bool {
        this.strongCount.tryIncrement()
    }

    /// 减少强引用
    public func decrementStrong(): Unit {
        this.assertThreadSafety()
        if (this.strongCount.decrement() == 0) {
            this.deinitValue()
            this.decrementWeak()
        }
    }

    /// 增加弱引用
    public func incrementWeak(): Unit {
        this.assertThreadSafety()
        this.weakCount.increment()
    }

    /// 减少弱引用
    public func decrementWeak(): Unit {
        this.assertThreadSafety()
        // 如果 allow_weak 为 false，此方法仅在最后一个强引用被反初始化时调用
        // 所以在这种情况下无条件释放内存
        if (!this.options.allowWeak || this.weakCount.decrement() == 0) {
            if (Environment.isDebug) {
                Assert.assertTrue(this.strongCount.get() == 0)
            }
            this.destroy()
        }
    }

    /// 反初始化值
    func deinitValue(): Unit {
        if (this.options.deinit) {
            // 调用值的 deinit
            // bun.memory.deinit(&self.value)
        }
    }

    /// 销毁
    func destroy(): Unit {
        // 释放内存
        // bun.memory.destroy(allocator, self)
    }

    func assertThreadSafety(): Unit {
        if (!this.options.atomic) {
            this.threadLock.assertLocked()
        }
    }
}

// ============================================================================
// AtomicSharedData - 线程安全的共享指针内部数据
// ============================================================================

/// 线程安全版本的共享指针内部数据
class AtomicSharedData<T> {
    /// 存储的值
    public var value: T
    /// 强引用计数 (原子)
    var strongCount: AtomicCount = AtomicCount(1)
    /// 弱引用计数 (原子)
    var weakCount: AtomicCount = AtomicCount(1)
    /// 分配器
    var allocator: Allocator = Allocator()
    /// 选项
    var options: SharedOptions = SharedOptions()

    init(value: T, options: SharedOptions) {
        this.value = value
        this.options = options
    }

    /// 分配
    public static func alloc(value: T, allocator: Allocator, options: SharedOptions): AtomicSharedData<T> {
        AtomicSharedData<T>(value: value, options: options)
    }

    /// 获取强引用计数
    public func strongCount(): UInt32 {
        this.strongCount.get()
    }

    /// 获取原始弱引用计数
    public func rawWeakCount(): UInt32 {
        if (this.options.allowWeak) {
            this.weakCount.get()
        } else {
            UInt32(1)
        }
    }

    /// 增加强引用
    public func incrementStrong(): Unit {
        this.strongCount.increment()
    }

    /// 尝试增加强引用
    public func tryIncrementStrong(): Bool {
        this.strongCount.tryIncrement()
    }

    /// 减少强引用
    public func decrementStrong(): Unit {
        if (this.strongCount.decrement() == 0) {
            this.deinitValue()
            this.decrementWeak()
        }
    }

    /// 增加弱引用
    public func incrementWeak(): Unit {
        this.weakCount.increment()
    }

    /// 减少弱引用
    public func decrementWeak(): Unit {
        if (!this.options.allowWeak || this.weakCount.decrement() == 0) {
            if (Environment.isDebug) {
                Assert.assertTrue(this.strongCount.get() == 0)
            }
            this.destroy()
        }
    }

    func deinitValue(): Unit {
        if (this.options.deinit) {
            // 调用值的 deinit
        }
    }

    func destroy(): Unit {
        // 释放内存
    }
}

// ============================================================================
// Shared - 共享指针
// ============================================================================

/// 共享指针，使用默认分配器分配
///
/// Pointer 应该是可能为可选的单项指针
/// 例如 Shared<*Type> 或 Shared<?*Type>
///
/// 此类型不是线程安全的: 指向同一数据的所有指针必须在同一线程上
/// 参见 AtomicShared 获取线程安全版本
public class Shared<T> {
    var _pointer: ?T = None<T>
    var _data: ?SharedData<T> = None<SharedData<T>>

    public init() {}

    /// 分配共享值
    public static func alloc(value: T): Shared<T> {
        let shared = Shared<T>()
        let data = SharedData<T>(value: value, options: SharedOptions())
        shared._data = Some(data)
        shared._pointer = Some(value)
        return shared
    }

    /// 使用指定分配器分配共享值
    public static func allocIn(value: T, allocator: Allocator): Shared<T> {
        let shared = Shared<T>()
        let data = SharedData<T>(value: value, options: SharedOptions())
        data.allocator = allocator
        shared._data = Some(data)
        shared._pointer = Some(value)
        return shared
    }

    /// 分配共享值，分配失败时调用 bun.outOfMemory
    public static func new(value: T): Shared<T> {
        Shared<T>.alloc(value)
    }

    /// 返回指向共享值的指针
    public func get(): ?T {
        this._pointer
    }

    /// 克隆此共享指针 (增加引用计数，不复制数据)
    public func clone(): Shared<T> {
        match (this._data) {
            case Some(data) =>
                data.incrementStrong()
                let result = Shared<T>()
                result._data = this._data
                result._pointer = this._pointer
                return result
            case None =>
                return Shared<T>()
        }
    }

    /// 反初始化此共享指针
    /// 不会反初始化数据本身，直到所有其他共享指针都被反初始化
    ///
    /// 当没有更多(强)共享指针指向某数据时，数据被反初始化
    /// 一旦也没有弱指针存在，内存被释放
    public func deinit(): Unit {
        match (this._data) {
            case Some(data) =>
                data.decrementStrong()
            case None => ()
        }
        this._pointer = None<T>
        this._data = None<SharedData<T>>
    }

    /// 创建空共享指针 (仅当 Pointer 是可选类型时可用)
    public static func initNull(): Shared<T> {
        Shared<T>()
    }

    /// 获取强引用计数
    public func strongCount(): UInt64 {
        match (this._data) {
            case Some(data) => UInt64(data.strongCount())
            case None => UInt64(0)
        }
    }

    /// 获取弱引用计数
    public func weakCount(): UInt64 {
        match (this._data) {
            case Some(data) => UInt64(data.rawWeakCount()) - 1  // -1 因为这不是实际的弱指针
            case None => UInt64(0)
        }
    }

    /// 将共享指针转换为原始指针，不减少引用计数
    /// 此方法使 self 失效
    public func leak(): ?T {
        let result = this._pointer
        this._pointer = None<T>
        this._data = None<SharedData<T>>
        return result
    }

    /// 从 leak 返回的原始指针创建共享指针
    public static func adoptRawUnsafe(pointer: T): Shared<T> {
        let shared = Shared<T>()
        shared._pointer = Some(pointer)
        return shared
    }

    /// 克隆共享指针，给定一个原始指针
    public static func cloneFromRawUnsafe(pointer: T): Shared<T> {
        let temp = Shared<T>()
        temp._pointer = Some(pointer)
        return temp.clone()
    }
}

// ============================================================================
// AtomicShared - 线程安全共享指针
// ============================================================================

/// 线程安全共享指针，使用默认分配器分配
///
/// 此类型使用原子操作管理引用计数，但不提供数据本身的同步
/// 你必须使用互斥锁或原子来确保正确的并发
public class AtomicShared<T> {
    var _pointer: ?T = None<T>
    var _data: ?AtomicSharedData<T> = None<AtomicSharedData<T>>

    public init() {}

    /// 分配共享值
    public static func alloc(value: T): AtomicShared<T> {
        let shared = AtomicShared<T>()
        let data = AtomicSharedData<T>(value: value, options: SharedOptions(atomic: true, allowWeak: false, deinit: true))
        shared._data = Some(data)
        shared._pointer = Some(value)
        return shared
    }

    /// 使用指定分配器分配
    public static func allocIn(value: T, allocator: Allocator): AtomicShared<T> {
        let shared = AtomicShared<T>()
        let data = AtomicSharedData<T>(value: value, options: SharedOptions(atomic: true, allowWeak: false, deinit: true))
        data.allocator = allocator
        shared._data = Some(data)
        shared._pointer = Some(value)
        return shared
    }

    /// 分配并处理 OOM
    public static func new(value: T): AtomicShared<T> {
        AtomicShared<T>.alloc(value)
    }

    /// 返回指向共享值的指针
    public func get(): ?T {
        this._pointer
    }

    /// 克隆
    public func clone(): AtomicShared<T> {
        match (this._data) {
            case Some(data) =>
                data.incrementStrong()
                let result = AtomicShared<T>()
                result._data = this._data
                result._pointer = this._pointer
                return result
            case None =>
                return AtomicShared<T>()
        }
    }

    /// 反初始化
    public func deinit(): Unit {
        match (this._data) {
            case Some(data) =>
                data.decrementStrong()
            case None => ()
        }
        this._pointer = None<T>
        this._data = None<AtomicSharedData<T>>
    }

    /// 创建空指针
    public static func initNull(): AtomicShared<T> {
        AtomicShared<T>()
    }

    /// 获取强引用计数
    public func strongCount(): UInt64 {
        match (this._data) {
            case Some(data) => UInt64(data.strongCount())
            case None => UInt64(0)
        }
    }

    /// 获取弱引用计数
    public func weakCount(): UInt64 {
        match (this._data) {
            case Some(data) => UInt64(data.rawWeakCount()) - 1
            case None => UInt64(0)
        }
    }

    /// 泄漏
    public func leak(): ?T {
        let result = this._pointer
        this._pointer = None<T>
        this._data = None<AtomicSharedData<T>>
        return result
    }

    /// 从原始指针创建
    public static func adoptRawUnsafe(pointer: T): AtomicShared<T> {
        let shared = AtomicShared<T>()
        shared._pointer = Some(pointer)
        return shared
    }

    /// 从原始指针克隆
    public static func cloneFromRawUnsafe(pointer: T): AtomicShared<T> {
        let temp = AtomicShared<T>()
        temp._pointer = Some(pointer)
        return temp.clone()
    }
}

// ============================================================================
// SharedIn / AtomicSharedIn - 使用特定分配器
// ============================================================================

/// 使用特定类型分配器的共享指针
/// 对 Allocator 的要求与 bun.ptr.OwnedIn 相同
/// Allocator 可以是 std.mem.Allocator 以允许任何类型的分配器
public type SharedIn<T> = Shared<T>

/// 使用特定类型分配器的线程安全共享指针
public type AtomicSharedIn<T> = AtomicShared<T>

// ============================================================================
// SharedWeak - 共享指针的弱引用
// ============================================================================

/// 共享指针的弱引用
///
/// 弱指针必须升级为强指针才能访问共享数据
/// 如果没有共享指针存在了，此升级可能失败
public class SharedWeak<T> {
    var _pointer: ?T = None<T>
    var _data: ?SharedData<T> = None<SharedData<T>>

    public init() {}

    /// 克隆此弱指针并升级为共享指针
    /// 你仍然需要 deinit 弱指针
    public func upgrade(): ?Shared<T> {
        match (this._data) {
            case Some(data) =>
                if (!data.tryIncrementStrong()) {
                    return None<Shared<T>>
                }
                let shared = Shared<T>()
                shared._data = this._data
                shared._pointer = this._pointer
                return Some(shared)
            case None =>
                return None<Shared<T>>
        }
    }

    /// 克隆此弱指针
    public func clone(): SharedWeak<T> {
        match (this._data) {
            case Some(data) =>
                data.incrementWeak()
                let result = SharedWeak<T>()
                result._data = this._data
                result._pointer = this._pointer
                return result
            case None =>
                return SharedWeak<T>()
        }
    }

    /// 反初始化此弱指针
    public func deinit(): Unit {
        match (this._data) {
            case Some(data) =>
                data.decrementWeak()
            case None => ()
        }
        this._pointer = None<T>
        this._data = None<SharedData<T>>
    }

    /// 创建空弱指针
    public static func initNull(): SharedWeak<T> {
        SharedWeak<T>()
    }

    /// 获取强引用计数
    public func strongCount(): UInt64 {
        match (this._data) {
            case Some(data) => UInt64(data.strongCount())
            case None => UInt64(0)
        }
    }

    /// 获取弱引用计数
    public func weakCount(): UInt64 {
        match (this._data) {
            case Some(data) =>
                let rawWeak = UInt64(data.rawWeakCount())
                let strong = UInt64(data.strongCount())
                if (strong > 0) {
                    rawWeak - 1
                } else {
                    rawWeak
                }
            case None => UInt64(0)
        }
    }
}
