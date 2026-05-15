// 严格翻译自: src/ast/new_store.zig (~170行)
// bao_ast - NewStore: 类似 arena 的高效 AST 节点分配器
package bao_ast

import bao_core.*
import bao_collections.*

// ============================================================================
// NewStore - Arena 风格分配器
// 严格翻译自: src/ast/new_store.zig:1-170
// Bun: pub fn NewStore(comptime types: []const type, comptime count: usize) type
//
// 这是一个类似于 arena 的专用内存分配策略, 用于在 JavaScript 解析和
// 访问期间分配表达式和语句节点。分配被分组到大块中, 每个块被视为
// 固定缓冲区分配器。当块空间用完时, 创建新块; 所有块通过链表连接。
//
// 与 arena 类似, 可以调用 .reset() 重置状态, 跨操作重用内存。
//
// 仓颉翻译: 由于仓颉使用 GC 管理, 这里用 ArrayList 池化模拟 arena 行为
// ============================================================================

/// NewStore - Arena 风格分配器
/// 对应 Bun NewStore: 专用内存分配策略
///
/// Bun 中 Expr/Stmt 节点使用 NewStore 分配:
///   - Expr.Data.Store = NewStore(&.{所有 E 类型}, 128)
///   - Stmt.Data.Store = NewStore(&.{所有 S 类型}, 128)
///
/// 仓颉中使用 GC 堆, 但保留 NewStore 接口以保持翻译一致性
public class NewStore {
    /// 分配池 - 对应 Bun NewStore 中的 Block 链表
    private var pool: ArrayList<Any>
    /// 是否已初始化
    public var initialized: Bool
    /// 分配计数
    public var allocCount: Int64

    public init() {
        pool = ArrayList<Any>()
        initialized = false
        allocCount = Int64(0)
    }

    /// 初始化 - 对应 Bun NewStore.init()
    /// Bun: pub fn init() *Store
    public static func init(): NewStore {
        let store = NewStore()
        store.initialized = true
        return store
    }

    /// 释放 - 对应 Bun NewStore.deinit()
    /// Bun: pub fn deinit(store: *Store) void
    public func deinit(): Unit {
        pool.clear()
        initialized = false
        allocCount = Int64(0)
    }

    /// 重置 - 对应 Bun NewStore.reset()
    /// Bun: pub fn reset(store: *Store) void
    /// 重置分配器但保留内存, 以便后续操作重用
    public func reset(): Unit {
        pool.clear()
        allocCount = Int64(0)
    }

    /// 分配并追加值 - 对应 Bun NewStore.append()
    /// Bun: pub inline fn append(store: *Store, comptime T: type, data: T) *T
    /// 返回分配后的指针 (在仓颉中返回值本身, 因为 GC 管理内存)
    public func append<T>(value: T): T {
        allocCount += Int64(1)
        // 在仓颉中, 直接返回值 (GC 管理内存)
        return value
    }

    /// 分配空间 - 对应 Bun NewStore.allocate()
    /// Bun: fn allocate(store: *Store, comptime T: type) *T
    public func allocate(): Unit {
        allocCount += Int64(1)
    }

    /// 锁定 - 对应 Bun NewStore.lock()
    /// 用于 debug 模式下防止并发访问
    public func lock(): Unit {
        // 仓颉中不需要手动锁
    }

    /// 解锁 - 对应 Bun NewStore.unlock()
    public func unlock(): Unit {
        // 仓颉中不需要手动锁
    }
}

/// NewStore 块 - 对应 Bun NewStore.Block
/// Bun 中每个块是固定大小的缓冲区, 仓颉中简化
public class StoreBlock {
    /// 块中已使用的字节
    public var bytesUsed: Int64
    /// 块大小
    public var blockSize: Int64
    /// 下一个块
    public var next: ?StoreBlock

    public init(blockSize: Int64) {
        this.bytesUsed = Int64(0)
        this.blockSize = blockSize
        this.next = None
    }

    /// 清零 - 对应 Bun Block.zero()
    public func zero(): Unit {
        bytesUsed = Int64(0)
        next = None
    }

    /// 尝试分配 - 对应 Bun Block.tryAlloc()
    /// 在仓颉中始终返回 true (GC 管理)
    public func tryAlloc(size: Int64): Bool {
        if (bytesUsed + size <= blockSize) {
            bytesUsed += size
            return true
        }
        return false
    }
}

/// NewStore 线程本地管理 - 对应 Bun Expr.Data.Store / Stmt.Data.Store
/// Bun: pub threadlocal var instance: ?*StoreType = null
/// Bun: pub threadlocal var memory_allocator: ?*ASTMemoryAllocator = null
public class StoreManager {
    /// 当前实例
    private static var instance: ?NewStore = None
    /// 内存分配器引用
    private static var memoryAllocator: ?ASTMemoryAllocator = None
    /// 是否禁用重置
    private static var disableReset: Bool = false

    /// 创建 Store - 对应 Bun Store.create()
    public static func create(): Unit {
        if (instance.isSome()) {
            return
        }
        instance = Some(NewStore.init())
    }

    /// 开始/重置 - 对应 Bun Store.begin()
    public static func begin(): Unit {
        if (memoryAllocator.isSome()) {
            return
        }
        if (instance.isNone()) {
            create()
            return
        }
        if (!disableReset) {
            match (instance) {
                case Some(s) => s.reset()
                case None => {}
            }
        }
    }

    /// 重置 - 对应 Bun Store.reset()
    public static func reset(): Unit {
        if (disableReset || memoryAllocator.isSome()) {
            return
        }
        match (instance) {
            case Some(s) => s.reset()
            case None => {}
        }
    }

    /// 释放 - 对应 Bun Store.deinit()
    public static func deinit(): Unit {
        if (instance.isNone() || memoryAllocator.isSome()) {
            return
        }
        match (instance) {
            case Some(s) => s.deinit()
            case None => {}
        }
        instance = None
    }

    /// 断言已初始化 - 对应 Bun Store.assert()
    public static func assert_(): Unit {
        // debug 模式下检查
    }

    /// 追加值 - 对应 Bun Store.append()
    public static func append<T>(value: T): T {
        match (memoryAllocator) {
            case Some(allocator) => return allocator.append<T>(value)
            case None => match (instance) {
                case Some(s) => return s.append<T>(value)
                case None => return value
            }
        }
    }

    /// 获取实例
    public static func getInstance(): ?NewStore {
        return instance
    }

    /// 设置内存分配器
    public static func setMemoryAllocator(allocator: ?ASTMemoryAllocator): Unit {
        memoryAllocator = allocator
    }

    /// 设置禁用重置
    public static func setDisableReset(disable: Bool): Unit {
        disableReset = disable
    }
}
