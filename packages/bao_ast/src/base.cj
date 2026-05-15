// bao_ast - AST 基础类型
// 严格翻译自: src/ast/base.zig (236L)
//   Ref - 符号引用 (packed struct: inner_index + tag + source_index)
//   Index - 源文件/部分索引
//   RefHashCtx / RefCtx - Ref 哈希上下文
//   ImportItemStatus - 导入项状态
//   NamespaceAlias - 命名空间别名
//   DeclaredSymbol - 已声明符号
//   StrictModeKind - 严格模式类型
//   AssignTarget - 赋值目标类型
package bao_ast

import bao_core.*
import bao_collections.*

// ============================================================================
// RefTag - 引用标签
// 严格翻译自: src/ast/base.zig:97-230
//   pub const Ref = packed struct(u64) {
//       inner_index: Int = 0,
//       tag: enum(u2) { invalid, allocated_name, source_contents_slice, symbol },
//       source_index: Int = 0,
//   }
// ============================================================================

/// 引用标签 - 对应 Bun Ref.tag
/// Bun: enum(u2) { invalid, allocated_name, source_contents_slice, symbol }
public enum RefTag {
    | Invalid            // 0 - 无效引用
    | AllocatedName      // 1 - 已分配名称
    | SourceContentsSlice // 2 - 源内容切片
    | Symbol             // 3 - 符号引用

    public func name(): String {
        match (this) {
            case Invalid => "invalid"
            case AllocatedName => "allocated_name"
            case SourceContentsSlice => "source_contents_slice"
            case Symbol => "symbol"
        }
    }
}

/// 符号引用 - 严格对应 Bun Ref
/// Bun: packed struct(u64) { inner_index: u31, tag: enum(u2), source_index: u31 }
///
/// 文件并行解析以获得速度。我们希望每个解析器都能生成不会相互冲突的符号 ID。
/// 我们还希望能够快速地将所有文件的符号表合并为一个巨大的符号表。
///
/// 我们通过给每个符号 ID 两个部分来实现这两个目标：一个是解析器协程独有的源索引，
/// 另一个是随着解析器生成新符号 ID 而递增的内部索引。
/// 符号映射可以是一个数组的数组，首先按源索引索引，然后按内部索引索引。
/// 通过创建一个包含所有已解析文件的所有内部数组的外部数组，可以快速合并映射。
public class Ref {
    /// 内部索引 - 对应 Bun Ref.inner_index: u31
    public var innerIndex: Int32
    /// 标签 - 对应 Bun Ref.tag: enum(u2)
    public var tag: RefTag
    /// 源索引 - 对应 Bun Ref.source_index: u31
    public var sourceIndex: Int32

    /// 空引用 - 对应 Bun Ref.None (inner_index=0, source_index=0, tag=invalid)
    /// 用全零表示空状态，不使用额外比特
    public static let NONE: Ref = Ref(0, RefTag.Invalid, 0)

    public init(innerIndex: Int32, tag: RefTag, sourceIndex: Int32) {
        this.innerIndex = innerIndex
        this.tag = tag
        this.sourceIndex = sourceIndex
    }

    public init() {
        this.innerIndex = 0
        this.tag = RefTag.Invalid
        this.sourceIndex = 0
    }

    /// 是否为空 - 对应 Bun Ref.isEmpty()
    /// Bun: pub inline fn isEmpty(this: Ref) bool { return this.asU64() == 0; }
    public func isEmpty(): Bool {
        return innerIndex == 0 && sourceIndex == 0 && tag == RefTag.Invalid
    }

    /// 是否有效 - 对应 Bun Ref.isValid()
    /// Bun: pub fn isValid(this: Ref) bool { return this.tag != .invalid; }
    public func isValid(): Bool {
        return tag != RefTag.Invalid
    }

    /// 是否为符号引用 - 对应 Bun Ref.isSymbol()
    /// Bun: pub fn isSymbol(this: Ref) bool { return this.tag == .symbol; }
    public func isSymbol(): Bool {
        return tag == RefTag.Symbol
    }

    /// 是否为源内容切片 - 对应 Bun Ref.isSourceContentsSlice()
    /// Bun: pub inline fn isSourceContentsSlice(this: Ref) bool
    public func isSourceContentsSlice(): Bool {
        return tag == RefTag.SourceContentsSlice
    }

    /// 获取源索引 - 对应 Bun Ref.sourceIndex()
    public func getSourceIndex(): Int32 {
        return sourceIndex
    }

    /// 获取内部索引 - 对应 Bun Ref.innerIndex()
    public func getInnerIndex(): Int32 {
        return innerIndex
    }

    /// 判断源索引是否为空 - 对应 Bun Ref.isSourceIndexNull()
    /// Bun: pub fn isSourceIndexNull(this: anytype) bool
    /// 使用 maxInt(u31) = 0x7FFFFFFF 表示空
    public func isSourceIndexNull(): Bool {
        return sourceIndex == Int32.MAX
    }

    /// 相等比较 - 对应 Bun Ref.eql()
    /// Bun: pub fn eql(ref: Ref, other: Ref) bool { return ref.asU64() == other.asU64(); }
    public func eql(other: Ref): Bool {
        return innerIndex == other.innerIndex &&
               sourceIndex == other.sourceIndex &&
               tag == other.tag
    }

    /// 计算哈希值 - 对应 Bun Ref.hash()
    /// Bun: pub fn hash(key: Ref) u32 { return @truncate(key.hash64()); }
    public func hash(): UInt64 {
        // 简单的哈希组合: 将三个字段组合成一个 64 位值
        var h = UInt64(innerIndex)
        h = h * UInt64(31) + UInt64(sourceIndex)
        h = h * UInt64(31) + UInt64(tag.ordinal())
        return h
    }

    /// 初始化 - 对应 Bun Ref.init()
    /// Bun: pub fn init(inner_index: Int, source_index: u32, is_source_contents_slice: bool) Ref
    public static func initFunc(innerIndex: Int32, sourceIndex: Int32, isSourceContentsSlice: Bool): Ref {
        return Ref(
            innerIndex,
            if (isSourceContentsSlice) { RefTag.SourceContentsSlice } else { RefTag.AllocatedName },
            sourceIndex
        )
    }

    /// 初始化源结束位置 - 对应 Bun Ref.initSourceEnd()
    /// Bun: pub fn initSourceEnd(old: Ref) Ref
    public static func initSourceEnd(old: Ref): Ref {
        return init(old.innerIndex, old.sourceIndex, old.tag == RefTag.SourceContentsSlice)
    }

    /// 格式化 - 对应 Bun Ref.format()
    /// Bun: try writer.print("Ref[inner={d}, src={d}, .{s}]", ...)
    public func toString(): String {
        return "Ref[inner=${innerIndex}, src=${sourceIndex}, .${tag.name()}]"
    }
}

// ============================================================================
// SourceIndex - 源文件索引
// 严格翻译自: src/ast/base.zig:25-82
//   pub const Index = packed struct(u32) { value: Int }
// ============================================================================

/// 源文件索引 - 对应 Bun Index
/// Bun: pub const Index = packed struct(u32) { value: Int }
/// 在 Bun 中，许多不同的 ID 指向不同的东西，使用此类型来确保不会混淆
public class SourceIndex {
    public var value: UInt32

    /// 无效索引 - 对应 Bun Index.invalid
    /// Bun: pub const invalid = Index{ .value = std.math.maxInt(Int) }
    public static let INVALID: SourceIndex = SourceIndex(UInt32(0x7FFFFFFF))

    /// 运行时索引 - 对应 Bun Index.runtime
    /// Bun: pub const runtime = Index{ .value = 0 }
    public static let RUNTIME: SourceIndex = SourceIndex(UInt32(0))

    /// Bake server 数据索引
    public static let BAKE_SERVER_DATA: SourceIndex = SourceIndex(UInt32(1))

    /// Bake client 数据索引
    public static let BAKE_CLIENT_DATA: SourceIndex = SourceIndex(UInt32(2))

    public init(value: UInt32) {
        this.value = value
    }

    public init() {
        this.value = UInt32(0x7FFFFFFF)
    }

    /// 设置值 - 对应 Bun Index.set()
    public func set(val: UInt32): Unit {
        this.value = val
    }

    /// 是否为运行时 - 对应 Bun Index.isRuntime()
    /// Bun: pub inline fn isRuntime(this: Index) bool
    public func isRuntime(): Bool {
        return value == SourceIndex.RUNTIME.value
    }

    /// 是否有效 - 对应 Bun Index.isValid()
    public func isValid(): Bool {
        return value != SourceIndex.INVALID.value
    }

    /// 是否无效 - 对应 Bun Index.isInvalid()
    public func isInvalid(): Bool {
        return !isValid()
    }

    /// 获取值 - 对应 Bun Index.get()
    public func get(): UInt32 {
        return value
    }

    /// 从数字创建源索引 - 对应 Bun Index.source()
    public static func source(num: UInt32): SourceIndex {
        return SourceIndex(num)
    }

    /// 从数字创建部分索引 - 对应 Bun Index.part()
    public static func part(num: UInt32): SourceIndex {
        return SourceIndex(num)
    }
}

// ============================================================================
// ImportItemStatus - 导入项状态
// 严格翻译自: src/ast/ 中的 ImportItemStatus
// Bun 中用于自动生成的导入项状态，避免对缺失导入报告编译时错误
// ============================================================================

/// 导入项状态 - 对应 Bun ImportItemStatus
/// Bun: pub const ImportItemStatus = enum { none, generated, missing }
public enum ImportItemStatus {
    | None       // 常规导入项
    | Generated  // 自动生成 (从命名空间属性访问生成)
    | Missing    // 导入缺失

    public func name(): String {
        match (this) {
            case None => "none"
            case Generated => "generated"
            case Missing => "missing"
        }
    }
}

// ============================================================================
// NamespaceAlias - 命名空间别名
// 严格翻译自: src/ast/ 中的 G.NamespaceAlias
// Bun: 用于记录导入标识符的命名空间别名信息
// ============================================================================

/// 命名空间别名 - 对应 Bun G.NamespaceAlias
/// Bun 中用于从 import * as ns from 'path' 中提取属性访问
public class NamespaceAlias {
    /// 命名空间引用 - 对应命名空间符号的 Ref
    public var namespaceRef: Ref
    /// 别名名称
    public var alias: String

    public init(namespaceRef: Ref, alias: String) {
        this.namespaceRef = namespaceRef
        this.alias = alias
    }

    public init() {
        this.namespaceRef = Ref.NONE
        this.alias = ""
    }
}

// ============================================================================
// StrictModeKind - 严格模式类型
// 严格翻译自: src/ast/ 中的 StrictModeKind
// Bun: 用于区分不同严格模式的规则
// ============================================================================

/// 严格模式类型 - 对应 Bun StrictModeKind
/// Bun: 用于跟踪作用域的严格模式状态
public enum StrictModeKind {
    | SloppyMode   // 非严格模式
    | StrictMode   // 严格模式 ("use strict")
    | CJSAutoStrict // CommonJS 自动严格模式

    public func isStrict(): Bool {
        match (this) {
            case StrictMode | CJSAutoStrict => true
            case SloppyMode => false
        }
    }
}

// ============================================================================
// AssignTarget - 赋值目标类型
// 严格翻译自: src/ast/ 中的 AssignTarget
// Bun: pub const AssignTarget = enum { none, replace, update }
// ============================================================================

/// 赋值目标类型 - 对应 Bun AssignTarget
/// Bun: 用于判断操作符是替换赋值还是更新赋值
public enum AssignTarget {
    | None     // 非赋值
    | Replace  // 简单赋值 (=)
    | Update   // 复合赋值 (+=, -=, ...)

    public func name(): String {
        match (this) {
            case None => "none"
            case Replace => "replace"
            case Update => "update"
        }
    }
}

// ============================================================================
// DeclaredSymbol - 已声明符号
// 严格翻译自: src/ast/ 中的 DeclaredSymbol
// Bun: 用于跟踪在特定范围内声明的符号
// ============================================================================

/// 已声明符号 - 对应 Bun DeclaredSymbol
/// Bun: 用于在 bundler 中分配 chunk 索引等操作
public class DeclaredSymbol {
    /// 符号引用
    public var ref: Ref
    /// 是否为顶层声明
    public var isTopLevel: Bool

    public init(ref: Ref, isTopLevel: Bool) {
        this.ref = ref
        this.isTopLevel = isTopLevel
    }

    public init(ref: Ref) {
        this.ref = ref
        this.isTopLevel = false
    }
}

/// 已声明符号列表
public class DeclaredSymbolList {
    public var items: ArrayList<DeclaredSymbol>

    public init() {
        items = ArrayList<DeclaredSymbol>()
    }

    public func append(symbol: DeclaredSymbol): Unit {
        items.append(symbol)
    }
}

// ============================================================================
// ImportRecord - AST 层导入记录
// 严格翻译自: src/ast/ 中的 ImportRecord (AST 层面)
// 与 bao_parser 中的 ImportRecord 不同，这里包含 AST 分析后的额外信息
// ============================================================================

/// 导入记录类型 (AST 层) - 对应 Bun AST ImportRecord.Kind
public enum ASTImportKind {
    | Static       // import ... from '...'
    | Dynamic      // import('...')
    | Require      // require('...')
    | Stmt         // import '...'
    | AtConditional // @if 条件导入
    | URL          // new URL('...', import.meta.url)

    public func name(): String {
        match (this) {
            case Static => "static"
            case Dynamic => "dynamic"
            case Require => "require"
            case Stmt => "stmt"
            case AtConditional => "at_conditional"
            case URL => "url"
        }
    }
}

/// 导入记录 (AST 层) - 对应 Bun AST 中的 ImportRecord
/// 在解析器和 bundler 之间传递的导入信息
public class ASTImportRecord {
    /// 导入路径 - 对应 Bun path: string
    public var path: String
    /// 导入类型 - 对应 Bun kind
    public var kind: ASTImportKind
    /// 路径范围 - 对应 Bun range: Range
    public var range: Range
    /// 是否包含默认导入
    public var hasDefaultImport: Bool
    /// 是否包含命名空间导入 (* as)
    public var hasStarImport: Bool
    /// 是否为类型导入 (TypeScript)
    public var isTypeOnly: Bool
    /// 导入项列表
    public var items: ArrayList<ASTImportItem>

    public init(path: String, kind: ASTImportKind, range: Range) {
        this.path = path
        this.kind = kind
        this.range = range
        this.hasDefaultImport = false
        this.hasStarImport = false
        this.isTypeOnly = false
        this.items = ArrayList<ASTImportItem>()
    }
}

/// 导入项 (AST 层) - 对应 Bun ImportItem
public class ASTImportItem {
    /// 导入名称
    public var name: String
    /// 别名 (as 后面的名称)
    public var alias: String
    /// 源位置
    public var loc: Loc
    /// 引用 - 对应 Bun Ref
    public var ref: Ref
    /// 导入项状态 - 对应 Bun import_item_status
    public var status: ImportItemStatus

    public init(name: String, alias: String, loc: Loc) {
        this.name = name
        this.alias = alias
        this.loc = loc
        this.ref = Ref.NONE
        this.status = ImportItemStatus.None
    }
}

// ============================================================================
// RefHashCtx / RefCtx - Ref 哈希上下文
// 严格翻译自: src/ast/base.zig:1-21
//   pub const RefHashCtx = struct { pub fn hash, pub fn eql }
//   pub const RefCtx = struct { pub fn hash, pub fn eql }
// ============================================================================

/// Ref 哈希上下文 (32位哈希) - 对应 Bun RefHashCtx
/// Bun: pub const RefHashCtx = struct { pub fn hash(_: @This(), key: Ref) u32 }
public class RefHashContext {
    public static func hash(ref: Ref): UInt64 {
        return ref.hash()
    }

    public static func eql(a: Ref, b: Ref): Bool {
        return a.eql(b)
    }
}
