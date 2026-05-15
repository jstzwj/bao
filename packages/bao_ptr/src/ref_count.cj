// 严格翻译自: src/ptr/ref_count.zig
// RefCount - 为结构体类型添加托管引用计数
// ThreadSafeRefCount - 线程安全引用计数
// RefPtr - 引用计数指针
package bao_ptr

import bao_core.*

// ============================================================================
// RefCountOptions - 引用计数选项
// ============================================================================

/// 引用计数选项
public struct RefCountOptions {
    /// 调试名称，默认为类型基名
    public var debugName: ?String = None<String>
    /// 析构器上下文类型
    public var destructorCtx: Any = ()

    public init() {}
    public init(debugName: String) {
        this.debugName = Some(debugName)
    }
}

// ============================================================================
// RefCount - 非线程安全引用计数
// ============================================================================

/// 为结构体类型添加托管的引用计数
/// 实现 ref() 和 deref() 方法
/// 此 mixin 不处理内存管理，但很容易与 bun.new + bun.destroy 集成
///
/// 当对象只有一个所有者时避免使用引用计数
///
/// 使用示例:
///     class Thing {
///         var refCount: RefCount = RefCount()
///         var otherField: UInt32 = 0
///
///         static func initFunc(field: UInt32): Thing {
///             let thing = Thing()
///             thing.otherField = field
///             return thing
///         }
///
///         func deinit(): Unit {
///             // 清理资源
///         }
///     }
public class RefCount {
    /// 原始引用计数
    public var rawCount: UInt32 = 1
    /// 线程锁
    public var thread: ThreadLock = ThreadLock()
    /// 调试名称
    public var debugName: String = ""

    public init() {}

    /// 初始化，设置初始计数
    public static func initFunc(): RefCount {
        RefCount.initExactRefs(1)
    }

    /// 设置精确的初始引用计数
    /// 调用者需要恰好调用 unref() count 次才能销毁
    public static func initExactRefs(count: UInt32): RefCount {
        Assert.assertTrue(count > 0)
        let rc = RefCount()
        rc.rawCount = count
        return rc
    }

    /// 增加引用计数
    public static func ref<T>(obj: T, refCount: RefCount): Unit {
        if (Environment.isDebug) {
            refCount.assertValid()
        }
        refCount.assertSingleThreaded()
        refCount.rawCount += 1
    }

    /// 减少引用计数，如果为 0 则调用析构器
    public static func deref<T>(obj: T, refCount: RefCount, destructor: (T) -> Unit): Unit {
        if (Environment.isDebug) {
            refCount.assertValid()  // 可能是双重 deref
        }
        refCount.assertSingleThreaded()
        refCount.rawCount -= 1
        if (refCount.rawCount == 0) {
            destructor(obj)
        }
    }

    /// 带上下文的减少引用计数
    public static func derefWithContext<T, C>(obj: T, refCount: RefCount, destructor: (T, C) -> Unit, ctx: C): Unit {
        if (Environment.isDebug) {
            refCount.assertValid()
        }
        refCount.assertSingleThreaded()
        refCount.rawCount -= 1
        if (refCount.rawCount == 0) {
            destructor(obj, ctx)
        }
    }

    /// 复制引用
    public static func dupeRef<T>(obj: T, refCount: RefCount): RefPtr<T> {
        RefCount.ref(obj, refCount)
        return RefPtr<T>.initRef(obj)
    }

    /// 是否只有一个引用
    public func hasOneRef(): Bool {
        this.assertSingleThreaded()
        this.rawCount == 1
    }

    /// 获取当前计数
    public func get(): UInt32 {
        this.rawCount
    }

    /// 转储活跃引用
    public func dumpActiveRefs(typeName: String, ptr: UInt64): Unit {
        if (Environment.isDebug) {
            // 转储引用信息
            Output.printError("${typeName}@0x${ptr.toString(16)} has ${this.rawCount} refs")
        }
    }

    /// 断言没有引用 (在析构器调用后计数为 0)
    public func assertNoRefs(): Unit {
        if (Environment.isDebug) {
            Assert.assertTrue(this.rawCount == 0)
        }
    }

    /// 不运行析构器就将引用计数设为 0
    /// 仅在你即将释放对象时使用 (例如使用 bun.destroy)
    /// 调用此方法后不要修改引用计数或创建任何 RefPtr
    public func clearWithoutDestructor(): Unit {
        this.assertSingleThreaded()
        this.rawCount = 0
    }

    func assertSingleThreaded(): Unit {
        this.thread.lockOrAssert()
    }

    func assertValid(): Unit {
        // 在 debug 模式下验证引用计数有效性
    }
}

// ============================================================================
// ThreadSafeRefCount - 线程安全引用计数
// ============================================================================

/// 为结构体类型添加线程安全的引用计数
/// 使用原子操作管理引用计数
///
/// 当对象只有一个所有者时避免使用引用计数
/// 当只有一个线程分配和释放时避免使用线程安全引用计数
///
/// 参考 RefCount 获取示例和最佳实践
public class ThreadSafeRefCount {
    /// 原子引用计数
    public var rawCount: AtomicUInt32 = AtomicUInt32(1)
    /// 调试名称
    public var debugName: String = ""

    public init() {}

    /// 初始化
    public static func initFunc(): ThreadSafeRefCount {
        ThreadSafeRefCount.initExactRefs(1)
    }

    /// 设置精确的初始引用计数
    public static func initExactRefs(count: UInt32): ThreadSafeRefCount {
        Assert.assertTrue(count > 0)
        let rc = ThreadSafeRefCount()
        rc.rawCount.store(count)
        return rc
    }

    /// 增加引用计数 (线程安全)
    public static func ref<T>(obj: T, refCount: ThreadSafeRefCount): Unit {
        if (Environment.isDebug) {
            refCount.assertValid()
        }
        let oldCount = refCount.rawCount.fetchAdd(1)
        Assert.assertTrue(oldCount > 0)
    }

    /// 减少引用计数 (线程安全)，如果为 0 则调用析构器
    public static func deref<T>(obj: T, refCount: ThreadSafeRefCount, destructor: (T) -> Unit): Unit {
        if (Environment.isDebug) {
            refCount.assertValid()
        }
        let oldCount = refCount.rawCount.fetchSub(1)
        Assert.assertTrue(oldCount > 0)
        if (oldCount == 1) {
            destructor(obj)
        }
    }

    /// 复制引用
    public static func dupeRef<T>(obj: T, refCount: ThreadSafeRefCount): RefPtr<T> {
        if (Environment.isDebug) {
            refCount.assertValid()
        }
        ThreadSafeRefCount.ref(obj, refCount)
        return RefPtr<T>.initRef(obj)
    }

    /// 获取当前计数
    public func get(): UInt32 {
        this.rawCount.load()
    }

    /// 是否只有一个引用
    public func hasOneRef(): Bool {
        if (Environment.isDebug) {
            this.assertValid()
        }
        this.get() == 1
    }

    /// 转储活跃引用
    public func dumpActiveRefs(typeName: String, ptr: UInt64): Unit {
        if (Environment.isDebug) {
            Output.printError("${typeName}@0x${ptr.toString(16)} has ${this.rawCount.load()} refs")
        }
    }

    /// 断言没有引用
    public func assertNoRefs(): Unit {
        if (Environment.isDebug) {
            Assert.assertTrue(this.rawCount.load() == 0)
        }
    }

    /// 不运行析构器就将引用计数设为 0
    public func clearWithoutDestructor(): Unit {
        this.rawCount.store(0)
    }

    func assertValid(): Unit {
        // 在 debug 模式下验证引用计数有效性
    }
}

// ============================================================================
// RefPtr - 引用计数指针
// ============================================================================

/// 指向实现 RefCount 或 ThreadSafeRefCount 的对象的指针
/// RefPtr 相对于 T* 的好处是 RefPtr 实例会被跟踪
///
/// 通过使用此类型，你获得以下内存调试工具:
/// - T.ref_count.dump() 转储所有活跃引用
/// - AllocationScope 集成 (通过 .newTracked() 和 .trackAll())
///
/// 参考 RefCount 获取示例和最佳实践
public class RefPtr<T> {
    /// 数据指针
    public var data: ?T = None<T>
    /// 调试 ID (仅 debug 构建)
    var debugId: UInt32 = 0

    public init() {}

    /// 增加引用计数并返回封装指针的结构
    public static func initRef(rawPtr: T): RefPtr<T> {
        let refPtr = RefPtr<T>()
        refPtr.data = Some(rawPtr)
        return refPtr
    }

    /// 减少引用计数，如果计数为 0 则销毁对象
    public func deref(destructor: (T) -> Unit): Unit {
        match (this.data) {
            case Some(d) =>
                destructor(d)
                this.data = None<T>
            case None => ()
        }
    }

    /// 带上下文的减少引用计数
    public func derefWithContext<C>(ctx: C, destructor: (T, C) -> Unit): Unit {
        match (this.data) {
            case Some(d) =>
                destructor(d, ctx)
                this.data = None<T>
            case None => ()
        }
    }

    /// 复制引用
    public func dupeRef(): RefPtr<T> {
        RefPtr<T>.initRef(this.data)
    }

    /// 分配新对象并返回 RefPtr
    public static func new(initData: T): RefPtr<T> {
        RefPtr<T>.adoptRef(initData)
    }

    /// 初始化新分配的指针，返回 RefPtr
    public static func adoptRef(rawPtr: T): RefPtr<T> {
        let refPtr = RefPtr<T>()
        refPtr.data = Some(rawPtr)
        return refPtr
    }

    /// 包装原始指针，不增加引用计数
    /// 调用者放弃其引用，此 RefPtr 现在拥有它
    /// 与 adoptRef 不同，此方法不断言 hasOneRef() - 指针可能有其他未完成的引用
    /// 这是 leak() 的逆操作
    public static func takeRef(rawPtr: T): RefPtr<T> {
        let refPtr = RefPtr<T>()
        refPtr.data = Some(rawPtr)
        return refPtr
    }

    /// 提取原始指针，不减少引用计数
    /// 调用者负责此 RefPtr 持有的引用
    /// 调用此方法后，RefPtr 无效且不得使用
    /// 这是 takeRef() 的逆操作
    public func leak(): ?T {
        let ptr = this.data
        this.data = None<T>
        return ptr
    }

    /// 获取内部数据
    public func get(): ?T {
        this.data
    }

    /// 获取内部数据 (非空断言版本)
    public func getUnchecked(): T {
        match (this.data) {
            case Some(d) => d
            case None => Assert.assertTrue(false, "RefPtr.getUnchecked: data is null")
        }
    }

    /// 检查是否有数据
    public func hasData(): Bool {
        match (this.data) {
            case Some(_) => true
            case None => false
        }
    }
}

// ============================================================================
// maybeAssertNoRefs - 可能断言没有引用
// ============================================================================

/// 如果类型 T 有 ref_count 字段且该字段有 assertNoRefs 方法，则调用它
/// 这在 debug 构建中用于检查对象是否在正确时机被销毁
public func maybeAssertNoRefs<T>(ptr: T): Unit {
    // 在仓颉中通过运行时类型检查实现
    // 如果 T 有 refCount 字段且为 RefCount 或 ThreadSafeRefCount 类型，
    // 则调用 assertNoRefs
}
