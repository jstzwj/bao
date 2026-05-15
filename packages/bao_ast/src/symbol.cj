// bao_ast - 符号跟踪
// 严格翻译自: src/ast/symbol.zig (488L)
//   Symbol - 符号结构体 (original_name, kind, link, use_count_estimate, ...)
//   Symbol.Kind - 符号类型枚举 (unbound, hoisted, hoisted_function, ...)
//   Symbol.SlotNamespace - 槽命名空间
//   Symbol.Map - 符号映射表 (二维数组)
//   Symbol.Use - 符号使用信息
//   Symbol.MergeResult - 符号合并结果
package bao_ast

import bao_core.*
import bao_collections.*

// ============================================================================
// SymbolKind - 符号类型
// 严格翻译自: src/ast/symbol.zig:192-304
//   pub const Kind = enum {
//       unbound, hoisted, hoisted_function, catch_identifier,
//       generator_or_async_function, arguments, class,
//       private_field, private_method, private_get, private_set,
//       private_get_set_pair, private_static_field, private_static_method,
//       private_static_get, private_static_set, private_static_get_set_pair,
//       label, ts_enum, ts_namespace, import, constant, local_css, other
//   }
// ============================================================================

/// 符号类型 - 对应 Bun Symbol.Kind
/// Bun: pub const Kind = enum { unbound, hoisted, ... }
/// 符号类型决定了如何打印符号以及如何处理冲突、重命名等
public enum SymbolKind {
    /// 未绑定符号 - 在引用它的文件中未声明
    /// 例如: 在没有声明的情况下使用 "window"
    | Unbound                   // unbound

    /// 提升声明 - var/function 声明
    /// 允许在同一作用域内多次重新声明
    /// 会被提升到最近的函数或模块作用域
    | Hoisted                   // hoisted
    | HoistedFunction           // hoisted_function

    /// catch 标识符 - 处理 catch 块中的变量声明特殊情况
    /// catch(e) { var e = 2 } 中的 e 阻止提升变量扩展
    | CatchIdentifier           // catch_identifier

    /// generator 或 async 函数 - 不提升但有特殊覆盖行为
    | GeneratorOrAsyncFunction  // generator_or_async_function

    /// 函数内特殊的 "arguments" 变量
    | Arguments                 // arguments

    /// 类声明 - 可与 TypeScript 命名空间合并
    | Class                     // class

    /// 私有标识符 (i.e. "#foo")
    | PrivateField              // private_field
    | PrivateMethod             // private_method
    | PrivateGet                // private_get
    | PrivateSet                // private_set
    | PrivateGetSetPair         // private_get_set_pair
    | PrivateStaticField        // private_static_field
    | PrivateStaticMethod       // private_static_method
    | PrivateStaticGet          // private_static_get
    | PrivateStaticSet          // private_static_set
    | PrivateStaticGetSetPair   // private_static_get_set_pair

    /// 标签 - 在自己的命名空间中
    | Label                     // label

    /// TypeScript 枚举 - 可与 TS 命名空间和其他 TS 枚举合并
    | TsEnum                    // ts_enum

    /// TypeScript 命名空间 - 可与类、函数、TS 枚举和其他 TS 命名空间合并
    | TsNamespace               // ts_namespace

    /// 导入 - TypeScript 中允许静默与模块内符号冲突
    | Import                    // import

    /// 常量 - 赋值会在运行时抛出 TypeError
    | Constant                  // constant

    /// 本地 CSS 标识符 - 重命名为文件内唯一
    | LocalCSS                  // local_css

    /// 其他 - 没有特殊行为的符号
    | Other                     // other

    /// 序数值 - 用于依赖枚举顺序的判断 (如 isPrivate)
    public func ordinal(): Int64 {
        match (this) {
            case Unbound => 0
            case Hoisted => 1
            case HoistedFunction => 2
            case CatchIdentifier => 3
            case GeneratorOrAsyncFunction => 4
            case Arguments => 5
            case Class => 6
            case PrivateField => 7
            case PrivateMethod => 8
            case PrivateGet => 9
            case PrivateSet => 10
            case PrivateGetSetPair => 11
            case PrivateStaticField => 12
            case PrivateStaticMethod => 13
            case PrivateStaticGet => 14
            case PrivateStaticSet => 15
            case PrivateStaticGetSetPair => 16
            case Label => 17
            case TsEnum => 18
            case TsNamespace => 19
            case Import => 20
            case Constant => 21
            case LocalCSS => 22
            case Other => 23
        }
    }

    /// 是否为私有标识符 - 对应 Bun Symbol.Kind.isPrivate()
    /// Bun: pub inline fn isPrivate(kind: Symbol.Kind) bool
    /// 从 private_field 到 private_static_get_set_pair 之间
    public func isPrivate(): Bool {
        return ordinal() >= SymbolKind.PrivateField.ordinal() &&
               ordinal() <= SymbolKind.PrivateStaticGetSetPair.ordinal()
    }

    /// 是否为提升类型 - 对应 Bun Symbol.Kind.isHoisted()
    /// Bun: pub inline fn isHoisted(kind: Symbol.Kind) bool
    public func isHoisted(): Bool {
        match (this) {
            case Hoisted | HoistedFunction => true
            case _ => false
        }
    }

    /// 是否为提升或函数类型 - 对应 Bun Symbol.Kind.isHoistedOrFunction()
    /// Bun: pub inline fn isHoistedOrFunction(kind: Symbol.Kind) bool
    public func isHoistedOrFunction(): Bool {
        match (this) {
            case Hoisted | HoistedFunction | GeneratorOrAsyncFunction => true
            case _ => false
        }
    }

    /// 是否为函数类型 - 对应 Bun Symbol.Kind.isFunction()
    /// Bun: pub inline fn isFunction(kind: Symbol.Kind) bool
    public func isFunction(): Bool {
        match (this) {
            case HoistedFunction | GeneratorOrAsyncFunction => true
            case _ => false
        }
    }

    /// 获取类型名称 - 对应 Bun @tagName(self)
    public func name(): String {
        match (this) {
            case Unbound => "unbound"
            case Hoisted => "hoisted"
            case HoistedFunction => "hoisted_function"
            case CatchIdentifier => "catch_identifier"
            case GeneratorOrAsyncFunction => "generator_or_async_function"
            case Arguments => "arguments"
            case Class => "class"
            case PrivateField => "private_field"
            case PrivateMethod => "private_method"
            case PrivateGet => "private_get"
            case PrivateSet => "private_set"
            case PrivateGetSetPair => "private_get_set_pair"
            case PrivateStaticField => "private_static_field"
            case PrivateStaticMethod => "private_static_method"
            case PrivateStaticGet => "private_static_get"
            case PrivateStaticSet => "private_static_set"
            case PrivateStaticGetSetPair => "private_static_get_set_pair"
            case Label => "label"
            case TsEnum => "ts_enum"
            case TsNamespace => "ts_namespace"
            case Import => "import"
            case Constant => "constant"
            case LocalCSS => "local_css"
            case Other => "other"
        }
    }
}

// ============================================================================
// SlotNamespace - 槽命名空间
// 严格翻译自: src/ast/symbol.zig:149-157
//   pub const SlotNamespace = enum {
//       must_not_be_renamed, default, label, private_name, mangled_prop
//   }
// ============================================================================

/// 槽命名空间 - 对应 Bun Symbol.SlotNamespace
/// Bun: 用于混淆时分配名称槽位
public enum SlotNamespace {
    | MustNotBeRenamed  // must_not_be_renamed
    | Default           // default
    | Label             // label
    | PrivateName       // private_name
    | MangledProp       // mangled_prop

    public func name(): String {
        match (this) {
            case MustNotBeRenamed => "must_not_be_renamed"
            case Default => "default"
            case Label => "label"
            case PrivateName => "private_name"
            case MangledProp => "mangled_prop"
        }
    }
}

// ============================================================================
// SymbolUse - 符号使用信息
// 严格翻译自: src/ast/symbol.zig:306-308
//   pub const Use = struct { count_estimate: u32 = 0 }
// ============================================================================

/// 符号使用信息 - 对应 Bun Symbol.Use
/// Bun: pub const Use = struct { count_estimate: u32 = 0 }
public class SymbolUse {
    /// 使用次数估计
    public var countEstimate: Int32

    public init() {
        this.countEstimate = 0
    }
}

// ============================================================================
// Symbol - 符号结构体
// 严格翻译自: src/ast/symbol.zig:1-144
//   pub const Symbol = struct {
//       original_name: []const u8,
//       namespace_alias: ?G.NamespaceAlias = null,
//       link: Ref = Ref.None,
//       use_count_estimate: u32 = 0,
//       chunk_index: u32 = invalid_chunk_index,
//       nested_scope_slot: u32 = invalid_nested_scope_slot,
//       did_keep_name: bool = true,
//       must_start_with_capital_letter_for_jsx: bool = false,
//       kind: Kind = Kind.other,
//       must_not_be_renamed: bool = false,
//       import_item_status: ImportItemStatus = ImportItemStatus.none,
//       private_symbol_must_be_lowered: bool = false,
//       remove_overwritten_function_declaration: bool = false,
//       has_been_assigned_to: bool = false,
//   }
// ============================================================================

/// 无效 chunk 索引 - 对应 Bun invalid_chunk_index
/// Bun: const invalid_chunk_index = std.math.maxInt(u32)
private let INVALID_CHUNK_INDEX: UInt32 = UInt32(0x7FFFFFFF)

/// 无效嵌套作用域槽位 - 对应 Bun Symbol.invalid_nested_scope_slot
/// Bun: pub const invalid_nested_scope_slot = std.math.maxInt(u32)
public let INVALID_NESTED_SCOPE_SLOT: UInt32 = UInt32(0x7FFFFFFF)

/// 符号 - 对应 Bun Symbol
/// Bun: pub const Symbol = struct { original_name, namespace_alias, link, use_count_estimate, ... }
///
/// original_name 是来自解析器的名称。在压缩或避免名称冲突时可能会重命名。
/// 打印期间不要使用原始名称。
public class Symbol {
    /// 原始名称 - 对应 Bun Symbol.original_name: []const u8
    /// 这是来自解析器的名称。压缩或避免冲突时可能重命名
    public var originalName: String

    /// 命名空间别名 - 对应 Bun Symbol.namespace_alias: ?G.NamespaceAlias
    /// 用于 ES6 import 语句的 import 子句中的符号
    /// 这些应该始终通过 EImportIdentifier 引用
    public var namespaceAlias: ?NamespaceAlias

    /// 链接引用 - 对应 Bun Symbol.link: Ref
    /// 用于解析器的单遍解析
    public var link: Ref

    /// 使用次数估计 - 对应 Bun Symbol.use_count_estimate: u32
    /// 用于检测符号是否被使用 (如未使用的 TypeScript 导入)
    public var useCountEstimate: Int32

    /// Chunk 索引 - 对应 Bun Symbol.chunk_index: u32
    /// 用于代码分割的跨 chunk 导入/导出
    private var chunkIndex: UInt32

    /// 嵌套作用域槽位 - 对应 Bun Symbol.nested_scope_slot: u32
    /// 用于压缩，兄弟作用域中的符号可以共享名称
    private var nestedScopeSlotValue: UInt32

    /// 是否保留名称 - 对应 Bun Symbol.did_keep_name: bool
    public var didKeepName: Bool

    /// JSX 是否必须大写开头 - 对应 Bun Symbol.must_start_with_capital_letter_for_jsx
    public var mustStartWithCapitalLetterForJSX: Bool

    /// 符号类型 - 对应 Bun Symbol.kind: Kind
    public var kind: SymbolKind

    /// 是否禁止重命名 - 对应 Bun Symbol.must_not_be_renamed: bool
    /// 如 "arguments" 变量，with 语句中的标识符
    public var mustNotBeRenamed: Bool

    /// 导入项状态 - 对应 Bun Symbol.import_item_status: ImportItemStatus
    /// 自动生成的导入项状态，避免对缺失导入报告编译时错误
    public var importItemStatus: ImportItemStatus

    /// 私有符号是否需要降级 - 对应 Bun Symbol.private_symbol_must_be_lowered
    public var privateSymbolMustBeLowered: Bool

    /// 是否删除被覆盖的函数声明 - 对应 Bun Symbol.remove_overwritten_function_declaration
    public var removeOverwrittenFunctionDeclaration: Bool

    /// 是否已被赋值 - 对应 Bun Symbol.has_been_assigned_to
    /// 用于 HMR 决定何时需要实时绑定代码
    public var hasBeenAssignedTo: Bool

    public init(originalName: String, kind: SymbolKind) {
        this.originalName = originalName
        this.kind = kind
        this.namespaceAlias = None
        this.link = Ref.NONE
        this.useCountEstimate = 0
        this.chunkIndex = INVALID_CHUNK_INDEX
        this.nestedScopeSlotValue = INVALID_NESTED_SCOPE_SLOT
        this.didKeepName = true
        this.mustStartWithCapitalLetterForJSX = false
        this.mustNotBeRenamed = false
        this.importItemStatus = ImportItemStatus.None
        this.privateSymbolMustBeLowered = false
        this.removeOverwrittenFunctionDeclaration = false
        this.hasBeenAssignedTo = false
    }

    public init(originalName: String) {
        this.originalName = originalName
        this.kind = SymbolKind.Other
        this.namespaceAlias = None
        this.link = Ref.NONE
        this.useCountEstimate = 0
        this.chunkIndex = INVALID_CHUNK_INDEX
        this.nestedScopeSlotValue = INVALID_NESTED_SCOPE_SLOT
        this.didKeepName = true
        this.mustStartWithCapitalLetterForJSX = false
        this.mustNotBeRenamed = false
        this.importItemStatus = ImportItemStatus.None
        this.privateSymbolMustBeLowered = false
        this.removeOverwrittenFunctionDeclaration = false
        this.hasBeenAssignedTo = false
    }

    /// 获取 chunk 索引 - 对应 Bun Symbol.chunkIndex()
    /// Bun: pub inline fn chunkIndex(this: *const Symbol) ?u32
    public func getChunkIndex(): ?UInt32 {
        if (chunkIndex == INVALID_CHUNK_INDEX) {
            return None
        }
        return Some(chunkIndex)
    }

    /// 设置 chunk 索引
    public func setChunkIndex(index: UInt32): Unit {
        this.chunkIndex = index
    }

    /// 获取嵌套作用域槽位 - 对应 Bun Symbol.nestedScopeSlot()
    /// Bun: pub inline fn nestedScopeSlot(this: *const Symbol) ?u32
    public func getNestedScopeSlot(): ?UInt32 {
        if (nestedScopeSlotValue == INVALID_NESTED_SCOPE_SLOT) {
            return None
        }
        return Some(nestedScopeSlotValue)
    }

    /// 设置嵌套作用域槽位
    public func setNestedScopeSlot(slot: UInt32): Unit {
        this.nestedScopeSlotValue = slot
    }

    /// 获取槽命名空间 - 对应 Bun Symbol.slotNamespace()
    /// Bun: pub fn slotNamespace(this: *const Symbol) SlotNamespace
    public func slotNamespace(): SlotNamespace {
        if (kind == SymbolKind.Unbound || mustNotBeRenamed) {
            return SlotNamespace.MustNotBeRenamed
        }
        if (kind.isPrivate()) {
            return SlotNamespace.PrivateName
        }
        match (kind) {
            case Label => return SlotNamespace.Label
            case _ => return SlotNamespace.Default
        }
    }

    /// 是否有链接 - 对应 Bun Symbol.hasLink()
    /// Bun: pub inline fn hasLink(this: *const Symbol) bool
    public func hasLink(): Bool {
        return link.isValid()
    }

    /// 是否为提升类型 - 对应 Bun Symbol.isHoisted()
    /// Bun: pub inline fn isHoisted(self: *const Symbol) bool
    public func isHoisted(): Bool {
        return kind.isHoisted()
    }

    /// 合并内容 - 对应 Bun Symbol.mergeContentsWith()
    /// Bun: pub fn mergeContentsWith(this: *Symbol, old: *Symbol) void
    /// 将旧符号的使用计数和名称信息合并到当前符号
    public func mergeContentsWith(old: Symbol): Unit {
        useCountEstimate += old.useCountEstimate
        if (old.mustNotBeRenamed) {
            originalName = old.originalName
            mustNotBeRenamed = true
        }
        // TODO: MustStartWithCapitalLetterForJSX
    }
}

// ============================================================================
// SymbolMap - 符号映射表
// 严格翻译自: src/ast/symbol.zig:323-465
//   pub const Map = struct {
//       symbols_for_source: NestedList = .{},
//       dump, assignChunkIndex, merge, get, getConst, init, ...
//       getWithLink, getWithLinkConst, followAll, follow
//   }
//
// Bun 使用二维数组实现符号映射 (比 HashMap 更高效)
// 因为不涉及哈希计算，且可以快速合并多个文件的符号表
// 每个文件只在一个内部数组中生成符号，合并时只需创建外部数组
// ============================================================================

/// 符号映射表 - 对应 Bun Symbol.Map
/// Bun: pub const Map = struct { symbols_for_source: NestedList }
/// 二维数组: symbols_for_source[source_index][inner_index] -> Symbol
public class SymbolMap {
    /// 符号表 - 对应 Bun symbols_for_source: NestedList
    /// 外层按源文件索引，内层按符号内部索引
    public var symbolsForSource: ArrayList<ArrayList<Symbol>>

    public init() {
        symbolsForSource = ArrayList<ArrayList<Symbol>>()
    }

    public init(sourceCount: Int64) {
        symbolsForSource = ArrayList<ArrayList<Symbol>>()
        var i = Int64(0)
        while (i < sourceCount) {
            symbolsForSource.append(ArrayList<Symbol>())
            i += 1
        }
    }

    /// 使用单个列表初始化 - 对应 Bun Symbol.Map.initWithOneList()
    /// Bun: pub fn initWithOneList(list: List) Map
    public static func initWithOneList(list: ArrayList<Symbol>): SymbolMap {
        let map = SymbolMap()
        map.symbolsForSource.append(list)
        return map
    }

    /// 获取符号 (可变) - 对应 Bun Symbol.Map.get()
    /// Bun: pub fn get(self: *const Map, ref: Ref) ?*Symbol
    public func get(ref: Ref): ?Symbol {
        if (ref.isSourceIndexNull() || ref.isSourceContentsSlice()) {
            return None
        }
        let srcIdx = Int64(ref.getSourceIndex())
        let innerIdx = Int64(ref.getInnerIndex())
        if (srcIdx < 0 || srcIdx >= symbolsForSource.size) {
            return None
        }
        let list = symbolsForSource[srcIdx]
        if (innerIdx < 0 || innerIdx >= list.size) {
            return None
        }
        return list[innerIdx]
    }

    /// 获取符号并跟随链接 - 对应 Bun Symbol.Map.getWithLink()
    /// Bun: pub fn getWithLink(symbols: *const Map, ref: Ref) ?*Symbol
    public func getWithLink(ref: Ref): ?Symbol {
        let symbol = get(ref)
        match (symbol) {
            case Some(s) =>
                if (s.hasLink()) {
                    return get(s.link).orElse(s)
                }
                return Some(s)
            case None => return None
        }
    }

    /// 跟随所有链接 - 对应 Bun Symbol.Map.followAll()
    /// Bun: pub fn followAll(symbols: *Map) void
    /// 等效于 esbuild 的 followSymbols
    public func followAll(): Unit {
        for (list in symbolsForSource) {
            for (symbol in list) {
                if (!symbol.hasLink()) {
                    continue
                }
                symbol.link = follow(symbol.link)
            }
        }
    }

    /// 跟随链接 - 对应 Bun Symbol.Map.follow()
    /// Bun: pub fn follow(symbols: *const Map, ref: Ref) Ref
    /// 等效于 esbuild 的 followSymbols
    public func follow(ref: Ref): Ref {
        let symbol = get(ref)
        match (symbol) {
            case Some(s) =>
                if (!s.hasLink()) {
                    return ref
                }
                let result = follow(s.link)
                if (!s.link.eql(result)) {
                    s.link = result
                }
                return result
            case None => return ref
        }
    }

    /// 合并两个引用 - 对应 Bun Symbol.Map.merge()
    /// Bun: pub fn merge(this: *Map, old: Ref, new: Ref) Ref
    /// 用于符号合并 (flat bundling 模式下重新导出的符号)
    public func merge(old: Ref, newRef: Ref): Ref {
        if (old.eql(newRef)) {
            return newRef
        }

        let oldSymbol = get(old)
        match (oldSymbol) {
            case Some(s) =>
                if (s.hasLink()) {
                    let oldLink = s.link
                    s.link = merge(oldLink, newRef)
                    return s.link
                }
            case None => ()
        }

        let newSymbol = get(newRef)
        match (newSymbol) {
            case Some(s) =>
                if (s.hasLink()) {
                    let newLink = s.link
                    s.link = merge(old, newLink)
                    return s.link
                }
            case None => ()
        }

        match (oldSymbol) {
            case Some(os) =>
                os.link = newRef
                match (newSymbol) {
                    case Some(ns) => ns.mergeContentsWith(os)
                    case None => ()
                }
            case None => ()
        }
        return newRef
    }

    /// 转储符号表 - 对应 Bun Symbol.Map.dump()
    /// Bun: pub fn dump(this: Map) void
    public func dump(): String {
        var sb = StringBuilder()
        var sourceIdx = Int64(0)
        for (list in symbolsForSource) {
            sb.append("\n-- Source ID: ${sourceIdx} (${list.size} symbols) --\n\n")
            var innerIdx = Int64(0)
            for (symbol in list) {
                sb.append(" name: ${symbol.originalName}\n")
                sb.append("  tag: ${symbol.kind.name()}\n")
                if (symbol.hasLink()) {
                    sb.append("       ${symbol.link.toString()}\n")
                } else {
                    sb.append("       Ref[inner=${innerIdx}, src=${sourceIdx}, .symbol]\n")
                }
                innerIdx += 1
            }
            sourceIdx += 1
        }
        return sb.toString()
    }
}

/// 符号合并结果 - 对应 Bun scope.zig 中的 SymbolMergeResult
/// 用于 canMergeSymbols 的返回值
public enum SymbolMergeResult {
    | Forbidden                  // 禁止合并
    | ReplaceWithNew             // 用新符号替换
    | OverwriteWithNew           // 用新符号覆盖
    | KeepExisting               // 保留现有
    | BecomePrivateGetSetPair    // 变为 private get/set 对
    | BecomePrivateStaticGetSetPair // 变为 private static get/set 对
}
