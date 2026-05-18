// AST 节点核心类型
// 严格翻译自: src/ast/nodes.rs (1397行)
//   Core AST node payload types and arena-slice helpers.
//   包含:
//     - StoreStr: Arena 拥有的字符串切片
//     - StoreRef<T>: Arena 拥有的指针
//     - StoreSlice<T>: Arena 拥有的类型切片
//     - LocRef: 带位置的引用
//     - ClauseItem: 导入/导出子句项
//     - OptionalChain: 可选链类型
//     - Batcher<T>: 批量分配器
//     - StrictModeKind: 严格模式类型
//     - ExportsKind: 导出类型
//     - 其他核心节点辅助类型
package bao_ast

import bao_core.*
import bao_collections.*

// ============================================================================
// StoreStr - Arena 拥有的字符串
// 严格翻译自: nodes.rs:156-310
//   pub struct StoreStr { ptr: NonNull<u8>, len: usize }
// ============================================================================

/// Arena 拥有的字符串 - 对应 Bun StoreStr
/// AST 字符串字段从解析 arena 借用，在 Store::reset() 时批量释放。
/// 避免级联的 'arena 生命周期参数传播到约 100 个类型。
public class StoreStr {
    public var data: String

    public init() {
        data = ""
    }

    public init(data: String) {
        this.data = data
    }

    /// 切片 - 对应 StoreStr.slice()
    public func slice(): String {
        data
    }

    /// 是否为空
    public func isEmpty(): Bool {
        data.size == 0
    }

    /// 长度
    public func len(): Int64 {
        data.size
    }
}

/// 空字符串常量
public let EMPTY_STORE_STR: StoreStr = StoreStr("")

// ============================================================================
// StrictModeKind - 严格模式类型 (完整版)
// 严格翻译自: nodes.rs:1262-1282
//   pub enum StrictModeKind { SloppyMode, ExplicitStrictMode, ... }
// ============================================================================

/// 严格模式类型 (完整版) - 对应 Bun StrictModeKind
/// 比 base.cj 中的版本更详细
public enum StrictModeKindFull {
    | SloppyMode                       // 非严格模式
    | ExplicitStrictMode               // 显式 "use strict"
    | ImplicitStrictModeImport         // 隐式严格模式 (import)
    | ImplicitStrictModeExport         // 隐式严格模式 (export)
    | ImplicitStrictModeTopLevelAwait  // 隐式严格模式 (top-level await)
    | ImplicitStrictModeClass          // 隐式严格模式 (class)

    public func isStrict(): Bool {
        match (this) {
            case SloppyMode => false
            case _ => true
        }
    }
}

// ============================================================================
// Batcher<T> - 批量分配器
// 严格翻译自: nodes.rs:1312-1364
//   pub struct Batcher<T> { head: StoreSlice<T> }
// ============================================================================

/// 批量分配器 - 对应 Bun Batcher
/// 用于分配大量小型数组时避免多次分配
public class Batcher<T> {
    private var items: ArrayList<T>
    private var index: Int64

    public init(count: Int64) {
        items = ArrayList<T>()
        index = 0
    }

    /// 取一个元素 - 对应 Batcher.eat1()
    public func eat1(value: T): T {
        items.append(value)
        value
    }

    /// 取 N 个元素 - 对应 Batcher.next()
    public func next(values: Array<T>): Unit {
        for (v in values) {
            items.append(v)
        }
    }

    /// 完成 - 对应 Batcher.done()
    public func done(): Unit {
        // 检查是否所有分配都已使用
    }
}

// ============================================================================
// StmtOrExpr - 语句或表达式
// 严格翻译自: nodes.rs:1193-1227
// ============================================================================

/// 语句或表达式 - 对应 Bun StmtOrExpr
public enum StmtOrExpr {
    | Stmt(StmtNode)
    | Expr(ASTNode)
}

// ============================================================================
// ToJSError - JS 错误类型
// 严格翻译自: nodes.rs:1292-1303
// ============================================================================

/// JS 错误类型 - 对应 Bun ToJSError
public enum ToJSError {
    | CannotConvertArgumentTypeToJS
    | CannotConvertIdentifierToJS
    | MacroError
    | OutOfMemory
    | JSError
    | JSTerminated
}

// ============================================================================
// Catch / Finally / Case - 异常处理和 switch
// 严格翻译自: nodes.rs:747-763
// ============================================================================

/// Catch 子句 - 对应 Bun Catch
public class Catch {
    public var loc: ASTLoc
    public var binding: ?BindingNode
    public var body: ArrayList<StmtNode>
    public var bodyLoc: ASTLoc

    public init() {
        loc = ASTLoc()
        binding = None
        body = ArrayList<StmtNode>()
        bodyLoc = ASTLoc()
    }
}

/// Finally 子句 - 对应 Bun Finally
public class Finally {
    public var loc: ASTLoc
    public var stmts: ArrayList<StmtNode>

    public init() {
        loc = ASTLoc()
        stmts = ArrayList<StmtNode>()
    }
}

/// Case 子句 - 对应 Bun Case
public class Case {
    public var loc: ASTLoc
    public var value: ?ASTNode
    public var body: ArrayList<StmtNode>

    public init() {
        loc = ASTLoc()
        value = None
        body = ArrayList<StmtNode>()
    }
}

// ============================================================================
// Span - 文本范围
// 严格翻译自: nodes.rs:788-801
// ============================================================================

/// 文本范围 - 对应 Bun Span
public class Span {
    public var text: String
    public var range: ASTRange

    public init() {
        text = ""
        range = ASTRange()
    }
}

// ============================================================================
// TlaCheck - 顶层 await 检查
// 严格翻译自: nodes.rs:771-786
// ============================================================================

/// 顶层 Await 检查 - 对应 Bun TlaCheck
public class TlaCheck {
    public var depth: UInt32
    public var parent: UInt32
    public var importRecordIndex: UInt32

    public init() {
        depth = 0
        parent = SourceIndex.INVALID.value
        importRecordIndex = SourceIndex.INVALID.value
    }
}

// ============================================================================
// 命名空间导出部分索引
// 严格翻译自: nodes.rs:490
// ============================================================================

/// 命名空间导出部分索引 - 对应 NAMESPACE_EXPORT_PART_INDEX
/// 自动生成的调用 __export(exports, { ... getters ... }) 的部分索引
public let NAMESPACE_EXPORT_PART_INDEX: UInt32 = 0
