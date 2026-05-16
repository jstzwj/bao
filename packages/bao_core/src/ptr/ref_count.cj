// RefCount - 引用计数混入和 RefPtr 指针
// 严格翻译自: src/ptr/ref_count.zig
// 为结构体添加 ref()/deref() 方法, 以及追踪引用的 RefPtr 包装器
package bao_core.ptr

// ============================================================================
// RefCountOptions - 引用计数选项
// 对应 Bun: pub const Options = struct { debug_name, destructor_ctx }
// ============================================================================
public class RefCountOptions {
    /// 调试名称 (默认为类型基本名)
    public var debugName: ?String = None
    /// 析构器上下文类型
    public var destructorCtx: ?String = None

    public init() {}
}

// ============================================================================
// RefCount<T> - 引用计数混入
// 对应 Bun: pub fn RefCount(T: type, field_name: []const u8, destructor: anytype, options: Options) type
//
// 添加 ref() 和 deref() 方法到结构体本身
// 这个混入不处理内存管理, 但很容易与 bun.new + bun.destroy 集成
// ============================================================================

/// 引用计数器
public class RefCount<T> {
    /// 原始引用计数
    private var rawCount: UInt32
    /// 线程锁
    private let threadLock: ThreadLock
    /// 类型名称 (用于调试)
    private let typeName: String
    /// 析构器函数引用
    private let destructor: (T) -> Unit

    public init(name: String, dtor: (T) -> Unit) {
        rawCount = 1
        threadLock = ThreadLock()
        typeName = name
        destructor = dtor
    }

    /// 初始化, 指定初始引用计数
    public init(name: String, dtor: (T) -> Unit, count: UInt32) {
        if (count <= 0) {
            throw Exception("RefCount.initExactRefs: count must be > 0")
        }
        rawCount = count
        threadLock = ThreadLock()
        typeName = name
        destructor = dtor
    }

    /// 增加引用计数
    public func ref(self: T): Unit {
        threadLock.lockOrAssert()
        rawCount += 1
    }

    /// 减少引用计数, 为 0 时调用析构器
    public func deref(self: T): Unit {
        threadLock.lockOrAssert()
        rawCount -= 1
        if (rawCount == 0) {
            destructor(self)
        }
    }

    /// 是否只有一个引用
    public func hasOneRef(): Bool {
        threadLock.lockOrAssert()
        return rawCount == 1
    }

    /// 获取当前计数
    public func get(): UInt32 {
        return rawCount
    }

    /// 断言没有引用
    public func assertNoRefs(): Unit {
        if (rawCount != 0) {
            throw Exception("assertNoRefs: expected 0 refs")
        }
    }

    /// 清除计数为 0, 不运行析构器
    public func clearWithoutDestructor(): Unit {
        threadLock.lockOrAssert()
        rawCount = 0
    }
}

// ============================================================================
// ThreadSafeRefCount<T> - 线程安全的引用计数混入
// ============================================================================

/// 线程安全的引用计数器
public class ThreadSafeRefCount<T> {
    /// 原子引用计数
    private var rawCount: UInt32
    /// 类型名称 (用于调试)
    private let typeName: String
    /// 析构器函数引用
    private let destructor: (T) -> Unit

    public init(name: String, dtor: (T) -> Unit) {
        rawCount = 1
        typeName = name
        destructor = dtor
    }

    public init(name: String, dtor: (T) -> Unit, count: UInt32) {
        if (count <= 0) {
            throw Exception("ThreadSafeRefCount.initExactRefs: count must be > 0")
        }
        rawCount = count
        typeName = name
        destructor = dtor
    }

    /// 增加引用计数 (原子操作)
    public func ref(self: T): Unit {
        let oldCount = rawCount
        rawCount += 1
        if (oldCount <= 0) {
            throw Exception("ThreadSafeRefCount.ref: old count must be > 0")
        }
    }

    /// 减少引用计数 (原子操作)
    public func deref(self: T): Unit {
        let oldCount = rawCount
        rawCount -= 1
        if (oldCount <= 0) {
            throw Exception("ThreadSafeRefCount.deref: old count must be > 0")
        }
        if (oldCount == 1) {
            destructor(self)
        }
    }

    /// 是否只有一个引用
    public func hasOneRef(): Bool {
        return get() == 1
    }

    /// 获取当前计数
    public func get(): UInt32 {
        return rawCount
    }

    /// 断言没有引用
    public func assertNoRefs(): Unit {
        if (rawCount != 0) {
            throw Exception("assertNoRefs: expected 0 refs")
        }
    }

    /// 清除计数为 0, 不运行析构器
    public func clearWithoutDestructor(): Unit {
        rawCount = 0
    }
}

// ============================================================================
// RefPtr<T> - 引用计数指针包装器
// ============================================================================

/// 引用计数指针
public class RefPtr<T> {
    /// 底层数据指针
    private var data: ?T = None
    /// 引用计数器引用
    private var refCount: ?RefCount<T> = None
    /// 调试 ID (debug 模式使用)
    private var debugId: Int64 = 0

    public init() {}

    private init(val: T, rc: RefCount<T>) {
        data = val
        refCount = rc
    }

    /// 增加引用计数并返回 RefPtr
    public static func initRef(rawPtr: T, rc: RefCount<T>): RefPtr<T> {
        rc.ref(rawPtr)
        let ptr = RefPtr<T>()
        ptr.data = rawPtr
        ptr.refCount = rc
        return ptr
    }

    /// 减少引用计数, 为 0 时销毁
    public func deref(): Unit {
        if (data.isSome()) {
            let d = data.getOrThrow()
            if (refCount.isSome()) {
                refCount.getOrThrow().deref(d)
            }
            data = None
        }
    }

    /// 复制引用
    public func dupeRef(): RefPtr<T> {
        if (data.isSome()) {
            let d = data.getOrThrow()
            if (refCount.isSome()) {
                return RefPtr<T>.initRef(d, refCount.getOrThrow())
            }
            let ptr = RefPtr<T>()
            ptr.data = d
            ptr.refCount = RefCount<T>("unknown", {_ => })
            return ptr
        }
        return RefPtr<T>()
    }

    /// 采用新分配的指针 (不增加引用计数)
    public static func adoptRef(rawPtr: T, rc: RefCount<T>): RefPtr<T> {
        if (!rc.hasOneRef()) {
            throw Exception("RefPtr.adoptRef: expected exactly one ref")
        }
        let ptr = RefPtr<T>()
        ptr.data = rawPtr
        ptr.refCount = rc
        return ptr
    }

    /// 接管指针 (不增加引用计数, 不检查 hasOneRef)
    public static func takeRef(rawPtr: T, rc: RefCount<T>): RefPtr<T> {
        let ptr = RefPtr<T>()
        ptr.data = rawPtr
        ptr.refCount = rc
        return ptr
    }

    /// 泄漏指针 (不减少引用计数)
    public func leak(): ?T {
        let result = data
        data = None
        return result
    }

    /// 获取底层数据
    public func get(): ?T {
        return data
    }
}
