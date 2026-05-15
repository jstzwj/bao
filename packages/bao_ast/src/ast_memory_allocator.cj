// 严格翻译自: src/ast/ast_memory_allocator.zig
// AST 内存分配器: 栈回退分配器 + bump 分配器, 用于 Expr/Stmt 节点分配
package bao_ast

import bao_core.*

// ============================================================================
// ASTMemoryAllocator - AST 内存分配器
// 严格翻译自: src/ast/ast_memory_allocator.zig:1-95
// Bun: pub const ASTMemoryAllocator = struct {
//   stack_allocator, bump_allocator, allocator, previous,
//   enter(), reset(), push(), pop(), append(), initWithoutStack()
// }
// ============================================================================

/// AST 内存分配器 - 对应 Bun ASTMemoryAllocator
/// Bun 使用栈回退分配器 + bump 分配器来高效分配 AST 节点
/// 仓颉中简化为基于 ArrayList 的池化分配
public class ASTMemoryAllocator {
    /// 底层分配器 (在仓颉中直接使用 GC 堆)
    private var pool: ArrayList<Any>
    /// 前一个分配器 (用于嵌套分配)
    public var previous: ?ASTMemoryAllocator
    /// 是否已初始化
    public var initialized: Bool

    public init() {
        pool = ArrayList<Any>()
        previous = None
        initialized = false
    }

    /// 进入分配器作用域 - 对应 Bun ASTMemoryAllocator.enter()
    /// Bun: pub fn enter(this: *ASTMemoryAllocator, allocator: std.mem.Allocator) ASTMemoryAllocator.Scope
    public func enter(): ASTMemoryAllocatorScope {
        initialized = true
        previous = None
        let scope = ASTMemoryAllocatorScope(this, getExprStoreAllocator(), getStmtStoreAllocator())
        scope.enter()
        return scope
    }

    /// 重置分配器 - 对应 Bun ASTMemoryAllocator.reset()
    /// Bun: pub fn reset(this: *ASTMemoryAllocator) void
    public func reset(): Unit {
        pool.clear()
        initialized = false
    }

    /// 推入为当前分配器 - 对应 Bun ASTMemoryAllocator.push()
    /// Bun: pub fn push(this: *ASTMemoryAllocator) void
    public func push(): Unit {
        setExprStoreAllocator(this)
        setStmtStoreAllocator(this)
    }

    /// 弹出当前分配器 - 对应 Bun ASTMemoryAllocator.pop()
    /// Bun: pub fn pop(this: *ASTMemoryAllocator) void
    public func pop(): Unit {
        let prev = this.previous
        if (prev.isSome()) {
            setExprStoreAllocator(prev.orElse(ASTMemoryAllocator()))
            setStmtStoreAllocator(prev.orElse(ASTMemoryAllocator()))
        }
        this.previous = None
    }

    /// 追加值到分配池 - 对应 Bun ASTMemoryAllocator.append()
    /// Bun: pub fn append(this: *ASTMemoryAllocator, comptime ValueType: type, value: anytype) *ValueType
    public func append<T>(value: T): T {
        pool.append(value)
        return value
    }

    /// 不使用栈分配器初始化 - 对应 Bun ASTMemoryAllocator.initWithoutStack()
    public func initWithoutStack(): Unit {
        initialized = true
    }

    // === 以下为静态全局存储引用 (模拟 Bun 的 threadlocal var) ===

    /// 获取当前 Expr 存储
    private static func getExprStoreAllocator(): ?ASTMemoryAllocator {
        return _exprStoreAllocator
    }

    /// 获取当前 Stmt 存储
    private static func getStmtStoreAllocator(): ?ASTMemoryAllocator {
        return _stmtStoreAllocator
    }

    /// 设置 Expr 存储分配器
    private static func setExprStoreAllocator(alloc: ?ASTMemoryAllocator): Unit {
        _exprStoreAllocator = alloc
    }

    /// 设置 Stmt 存储分配器
    private static func setStmtStoreAllocator(alloc: ?ASTMemoryAllocator): Unit {
        _stmtStoreAllocator = alloc
    }

    private static var _exprStoreAllocator: ?ASTMemoryAllocator = None
    private static var _stmtStoreAllocator: ?ASTMemoryAllocator = None
}

/// AST 内存分配器作用域 - 对应 Bun ASTMemoryAllocator.Scope
/// Bun: pub const Scope = struct { current, previous, enter(), exit() }
public class ASTMemoryAllocatorScope {
    /// 当前分配器
    public var current: ?ASTMemoryAllocator
    /// 前一个分配器
    public var previousExpr: ?ASTMemoryAllocator
    public var previousStmt: ?ASTMemoryAllocator

    public init(current: ?ASTMemoryAllocator, previousExpr: ?ASTMemoryAllocator,
                previousStmt: ?ASTMemoryAllocator) {
        this.current = current
        this.previousExpr = previousExpr
        this.previousStmt = previousStmt
    }

    /// 进入作用域 - 对应 Bun Scope.enter()
    /// 设置 Expr/Stmt 存储的内存分配器为当前
    public func enter(): Unit {
        // 在仓颉中模拟 Bun 的全局状态设置
        if (current.isSome()) {
            let allocator = current.orElse(ASTMemoryAllocator())
            allocator.push()
        }
    }

    /// 退出作用域 - 对应 Bun Scope.exit()
    /// 恢复之前的内存分配器
    public func exit(): Unit {
        if (current.isSome()) {
            let allocator = current.orElse(ASTMemoryAllocator())
            allocator.pop()
        }
    }
}
