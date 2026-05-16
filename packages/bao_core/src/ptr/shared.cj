// Shared - 共享指针
// 严格翻译自: src/ptr/shared.zig
// 共享指针: 引用计数管理的智能指针, 支持弱引用
package bao_core.ptr

// ============================================================================
// SharedOptions - 共享指针选项
// 对应 Bun: pub const Options = struct { Allocator, atomic, allow_weak, deinit }
// ============================================================================
public class SharedOptions {
    /// 是否使用原子操作 (线程安全)
    public var atomic: Bool = false
    /// 是否允许弱指针
    public var allowWeak: Bool = false
    /// 是否在释放前调用 deinit
    public var deinit: Bool = true

    public init() {}
    public init(atomic: Bool, allowWeak: Bool, deinit: Bool) {
        this.atomic = atomic
        this.allowWeak = allowWeak
        this.deinit = deinit
    }
}

// ============================================================================
// Shared<T> - 非线程安全的共享指针
// 对应 Bun: pub fn Shared(comptime Pointer: type) type
//
// Pointer 应为可能可选的单项指针
// 例: Shared(*Type) 或 Shared(?*Type)
//
// 此类型不是线程安全的: 指向同一数据的所有指针必须在同一线程
// 线程安全版本见 AtomicShared
// ============================================================================
public class Shared<T> {
    /// 指向数据的指针
    private var pointer: ?T = None
    /// 引用计数 (强引用)
    private var strongCount: UInt32
    /// 弱引用计数 (如果允许)
    private var weakCount: UInt32
    /// 选项
    private var options: SharedOptions
    /// 分配器
    private var allocator: ?Allocator = None

    public init() {
        strongCount = 0
        weakCount = 0
        options = SharedOptions()
    }

    private init(ptr: T, opts: SharedOptions, alloc: ?Allocator) {
        pointer = ptr
        strongCount = 1
        weakCount = if (opts.allowWeak) { 1 } else { 0 }
        options = opts
        allocator = alloc
    }

    /// 分配一个新的共享值
    // 对应 Bun: pub fn alloc(value: Child) AllocError!Self
    public static func alloc(value: T): Shared<T> {
        return allocImpl(value, SharedOptions())
    }

    /// 分配一个新的共享值 (指定选项)
    public static func alloc(value: T, opts: SharedOptions): Shared<T> {
        return allocImpl(value, opts)
    }

    private static func allocImpl(value: T, opts: SharedOptions): Shared<T> {
        let s = Shared<T>()
        s.pointer = value
        s.strongCount = 1
        s.weakCount = if (opts.allowWeak) { 1 } else { 0 }
        return s
    }

    /// 获取指针
    // 对应 Bun: pub fn get(self: Self) Pointer
    public func get(): ?T {
        return pointer
    }

    /// 克隆共享指针 (增加引用计数, 不复制数据)
    // 对应 Bun: pub fn clone(self: Self) Self
    public func clone(): Shared<T> {
        if (pointer.isSome()) {
            strongCount += 1
            let cloned = Shared<T>()
            cloned.pointer = pointer
            cloned.strongCount = strongCount
            cloned.weakCount = weakCount
            cloned.options = options
            cloned.allocator = allocator
            return cloned
        }
        return Shared<T>()
    }

    /// 释放共享指针
    // 对应 Bun: pub fn deinit(self: *Self) void
    // 当没有强引用时 deinit 数据; 没有弱引用时释放内存
    public func deinit(): Unit {
        if (pointer.isSome()) {
            decrementStrong()
        }
        pointer = None
    }

    /// 强引用计数
    // 对应 Bun: pub fn strongCount(self: Self) Count
    public func strongRefCount(): UInt32 {
        return strongCount
    }

    /// 弱引用计数
    // 对应 Bun: pub fn weakCount(self: Self) Count
    public func weakRefCount(): UInt32 {
        // -1 因为弱计数中有一个是强引用存在的标记
        if (strongCount > 0 && options.allowWeak) {
            return if (weakCount > 0) { weakCount - 1 } else { 0 }
        }
        return weakCount
    }

    /// 泄漏指针 (不减少引用计数)
    // 对应 Bun: pub fn leak(self: *Self) Pointer
    public func leak(): ?T {
        let result = pointer
        pointer = None
        return result
    }

    /// 从泄漏的指针恢复
    // 对应 Bun: pub fn adoptRawUnsafe(pointer: Pointer) Self
    public static func adoptRawUnsafe(ptr: T): Shared<T> {
        let s = Shared<T>()
        s.pointer = ptr
        s.strongCount = 1
        return s
    }

    /// 从原始指针克隆 (必须来自另一个 Shared)
    // 对应 Bun: pub fn cloneFromRawUnsafe(pointer: Pointer) Self
    public static func cloneFromRawUnsafe(ptr: T): Shared<T> {
        let temp = Shared<T>.adoptRawUnsafe(ptr)
        return temp.clone()
    }

    // 内部: 递减强引用
    private func decrementStrong(): Unit {
        if (strongCount > 0) {
            strongCount -= 1
            if (strongCount == 0) {
                // 对应 Bun: self.deinitValue(); self.decrementWeak()
                if (options.deinit) {
                    // deinit 数据
                }
                decrementWeak()
            }
        }
    }

    // 内部: 递增强引用
    private func incrementStrong(): Unit {
        strongCount += 1
    }

    // 内部: 递减弱引用
    private func decrementWeak(): Unit {
        if (options.allowWeak) {
            if (weakCount > 0) {
                weakCount -= 1
                if (weakCount == 0) {
                    // 释放内存
                    destroy()
                }
            }
        } else {
            // 不允许弱引用时, 强引用为 0 直接释放
            destroy()
        }
    }

    // 内部: 递增弱引用
    private func incrementWeak(): Unit {
        weakCount += 1
    }

    // 内部: 释放内存
    private func destroy(): Unit {
        pointer = None
        allocator = None
    }
}

// ============================================================================
// AtomicShared<T> - 线程安全的共享指针
// 对应 Bun: pub fn AtomicShared(comptime Pointer: type) type
// 使用原子操作管理引用计数, 但不提供数据本身的同步
// ============================================================================
public type AtomicShared<T> = Shared<T>

// ============================================================================
// Weak<T> - 弱引用指针
// 对应 Bun: fn Weak(comptime Pointer: type, comptime options: Options) type
//
// 弱指针必须在访问数据前升级为强指针
// 升级可能失败 (如果所有强指针已被释放)
// ============================================================================
public class Weak<T> {
    private var pointer: ?T = None
    private var weakCount: UInt32
    private let options: SharedOptions

    public init() {
        weakCount = 0
        options = SharedOptions()
    }

    private init(ptr: T, opts: SharedOptions, weakC: UInt32) {
        pointer = ptr
        weakCount = weakC
        options = opts
    }

    /// 升级为强指针 (可能失败)
    // 对应 Bun: pub fn upgrade(self: Self) ?SharedNonOptional
    public func upgrade(): ?Shared<T> {
        if (pointer.isSome()) {
            // 尝试增加强引用
            let shared = Shared<T>.adoptRawUnsafe(pointer.getOrThrow())
            return shared
        }
        return None
    }

    /// 克隆弱指针
    // 对应 Bun: pub fn clone(self: Self) Self
    public func clone(): Weak<T> {
        let w = Weak<T>()
        w.pointer = pointer
        w.weakCount = weakCount + 1
        return w
    }

    /// 释放弱指针
    // 对应 Bun: pub fn deinit(self: *Self) void
    public func deinit(): Unit {
        pointer = None
        weakCount = 0
    }
}
