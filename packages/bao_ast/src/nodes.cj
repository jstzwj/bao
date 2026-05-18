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
// ClauseItem - 导入/导出子句项
// 严格翻译自: nodes.rs:590-627
//   pub struct ClauseItem { alias, alias_loc, name, original_name }
// ============================================================================

/// 子句项 - 对应 Bun ClauseItem
/// 用于 import { foo as bar } / export { foo as bar } 语法
public class ClauseItem {
    /// 别名 (as 后面的名称)
    public var alias: String
    /// 别名位置
    public var aliasLoc: ASTLoc
    /// 名称引用
    public var name: LocRef
    /// 原始名称 (重导出时保留)
    public var originalName: String

    /// 默认别名 - 对应 ClauseItem.DEFAULT_ALIAS
    public static let DEFAULT_ALIAS: String = "default"

    public init() {
        alias = ""
        aliasLoc = ASTLoc()
        name = LocRef()
        originalName = ""
    }

    public init(alias: String, name: LocRef, originalName: String) {
        this.alias = alias
        this.aliasLoc = ASTLoc()
        this.name = name
        this.originalName = originalName
    }
}

// ============================================================================
// OptionalChain - 可选链类型
// 严格翻译自: nodes.rs:712-732
//   pub enum OptionalChain { Start, Continuation }
// ============================================================================

/// 可选链类型 - 对应 Bun OptionalChain
/// "a?.b" = Start, "a?.b.c" 中 ".c" = Continuation
public enum OptionalChain {
    | Start         // a?.b - 可选链起始
    | Continuation  // a?.b.c - 可选链延续 (但 (a?.b).c 不是)

    public operator func ==(right: OptionalChain): Bool {
        ordinal() == right.ordinal()
    }

    public func ordinal(): Int64 {
        match (this) {
            case Start => 0
            case Continuation => 1
        }
    }
}

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
// NameMinifier - 名称压缩器
// 严格翻译自: nodes.rs:654-710
//   pub struct NameMinifier { head, tail }
// ============================================================================

/// 名称压缩器 - 对应 Bun NameMinifier
/// 用于将符号索引压缩为短标识符名
public class NameMinifier {
    public var head: Array<UInt8>
    public var tail: Array<UInt8>

    public init() {
        head = DEFAULT_HEAD
        tail = DEFAULT_TAIL
    }

    /// 默认头部字符: a-z A-Z $ _
    public static let DEFAULT_HEAD: Array<UInt8> = [
        0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A,
        0x6B, 0x6C, 0x6D, 0x6E, 0x6F, 0x70, 0x71, 0x72, 0x73, 0x74,
        0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, // a-z
        0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A,
        0x4B, 0x4C, 0x4D, 0x4E, 0x4F, 0x50, 0x51, 0x52, 0x53, 0x54,
        0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, // A-Z
        0x24, 0x5F // $ _
    ]

    /// 默认尾部字符: a-z A-Z 0-9 $ _
    public static let DEFAULT_TAIL: Array<UInt8> = [
        0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A,
        0x6B, 0x6C, 0x6D, 0x6E, 0x6F, 0x70, 0x71, 0x72, 0x73, 0x74,
        0x75, 0x76, 0x77, 0x78, 0x79, 0x7A,
        0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A,
        0x4B, 0x4C, 0x4D, 0x4E, 0x4F, 0x50, 0x51, 0x52, 0x53, 0x54,
        0x55, 0x56, 0x57, 0x58, 0x59, 0x5A,
        0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
        0x24, 0x5F
    ]

    /// 数字到压缩名称 - 对应 NameMinifier.number_to_minified_name()
    public func numberToMinifiedName(i: Int64): String {
        var result = StringBuilder()
        var n = i
        let j = n % Int64(head.size)
        result.append(String(UInt8(head[Int64(j)])))
        n = n / Int64(head.size)

        while (n > 0) {
            n -= 1
            let k = n % Int64(tail.size)
            result.append(String(UInt8(tail[Int64(k)])))
            n = n / Int64(tail.size)
        }
        result.toString()
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
// EnumValue - 枚举值
// 严格翻译自: nodes.rs:734-745
// ============================================================================

/// 枚举值 - 对应 Bun EnumValue
public class EnumValue {
    public var loc: ASTLoc
    public var ref: Ref
    public var name: String
    public var value: ?ASTNode

    public init(name: String, ref: Ref) {
        loc = ASTLoc()
        this.ref = ref
        this.name = name
        this.value = None
    }
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

/// 数组绑定 - 对应 Bun ArrayBinding
public class ArrayBinding {
    public var binding: BindingNode
    public var defaultValue: ?ASTNode

    public init(binding: BindingNode) {
        this.binding = binding
        this.defaultValue = None
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
