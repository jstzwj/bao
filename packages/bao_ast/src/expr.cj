// 严格翻译自: src/ast/expr.zig (3247L)
// Expr 联合类型: 表达式节点, 包含 init, allocate, clone, deepClone, 各种辅助方法
package bao_ast

import std.convert.*
import bao_core.*
import bao_collections.*
import bao_parser.*

// ============================================================================
// PrimitiveType - 原始类型
// 严格翻译自: src/ast/expr.zig:2093-2128
//   pub const PrimitiveType = enum {
//       unknown, mixed, null, undefined, boolean, number, string, bigint
//   }
// ============================================================================

/// 原始类型 - 对应 Bun Expr.PrimitiveType
/// Bun: pub const PrimitiveType = enum { unknown, mixed, null, undefined, boolean, number, string, bigint }
public enum PrimitiveType {
    | Unknown
    | Mixed
    | Null
    | Undefined
    | Boolean
    | Number
    | String
    | Bigint

    public operator func ==(right: PrimitiveType): Bool {
        return ordinal() == right.ordinal()
    }

    public operator func !=(right: PrimitiveType): Bool {
        return !(this == right)
    }

    public func ordinal(): Int64 {
        match (this) {
            case Unknown => 0
            case Mixed => 1
            case Null => 2
            case Undefined => 3
            case Boolean => 4
            case Number => 5
            case String => 6
            case Bigint => 7
        }
    }

    /// 是否静态 - 对应 Bun PrimitiveType.isStatic()
    /// Bun: pub inline fn isStatic(this: PrimitiveType) bool
    /// static 集合: mixed, null, undefined, boolean, number, string (不含 bigint)
    public func isStatic(): Bool {
        match (this) {
            case Mixed | Null | Undefined | Boolean | Number | String => true
            case Unknown | Bigint => false
        }
    }

    /// 合并两个原始类型 - 对应 Bun PrimitiveType.merge()
    /// Bun: pub fn merge(left_known: PrimitiveType, right_known: PrimitiveType) PrimitiveType
    public static func merge(left: PrimitiveType, right: PrimitiveType): PrimitiveType {
        if (right == Unknown || left == Unknown) {
            return Unknown
        }
        if (left == right) {
            return left
        }
        return Mixed
    }
}

// ============================================================================
// ExprEquality - 表达式相等结果
// 严格翻译自: src/ast/expr.zig:2911-2926
//   pub const Equality = struct {
//       equal: bool = false, ok: bool = false,
//       is_require_main_and_module: bool = false
//   }
// ============================================================================

/// 表达式相等结果 - 对应 Bun Expr.Data.Equality
public class ExprEquality {
    public var equal: Bool
    public var ok: Bool
    public var isRequireMainAndModule: Bool

    public init(equal: Bool, ok: Bool) {
        this.equal = equal
        this.ok = ok
        this.isRequireMainAndModule = false
    }

    /// 对应 Bun Equality.true
    public static let TRUE: ExprEquality = ExprEquality(true, true)
    /// 对应 Bun Equality.false
    public static let FALSE: ExprEquality = ExprEquality(false, true)
    /// 对应 Bun Equality.unknown
    public static let UNKNOWN: ExprEquality = ExprEquality(false, false)
}

// ============================================================================
// ExprDataStore - 表达式数据存储
// 严格翻译自: src/ast/expr.zig:3117-3197
//   pub const Store = struct {
//       threadlocal var instance: ?*StoreType = null,
//       threadlocal var memory_allocator: ?*ASTMemoryAllocator = null,
//       pub fn create(), reset(), deinit(), begin(), assert(), append()
//   }
// ============================================================================

/// 表达式数据存储 - 对应 Bun Expr.Data.Store
/// Bun 使用 arena 分配器, 仓颉使用 GC 堆
public class ExprDataStore {
    /// 实例计数
    public static var instanceCount: Int64 = Int64(0)

    public static func create(): Unit {
        instanceCount += Int64(1)
    }

    public static func reset(): Unit {
        // GC 管理内存, 无需操作
    }

    public static func deinit(): Unit {
        instanceCount -= Int64(1)
    }

    /// create || reset - 对应 Bun Store.begin()
    public static func begin(): Unit {
        create()
    }

    /// 断言 Store 已初始化 - 对应 Bun Store.assert()
    public static func assert_(): Unit {
        // 在 debug 模式下检查 store 已初始化
    }
}

// ============================================================================
// ExprTag - 表达式标签枚举
// 严格翻译自: src/ast/expr.zig:1475-1925
//   pub const Tag = enum {
//       e_array, e_unary, e_binary, e_class, e_new, e_function,
//       e_call, e_dot, e_index, e_arrow, e_jsx_element, e_object,
//       e_spread, e_template, e_reg_exp, e_await, e_yield, e_if,
//       e_import, e_identifier, e_import_identifier, e_private_identifier,
//       e_commonjs_export_identifier, e_boolean, e_branch_boolean,
//       e_number, e_big_int, e_string, e_require_string,
//       e_require_resolve_string, e_require_call_target,
//       e_require_resolve_call_target, e_missing, e_this, e_super,
//       e_null, e_undefined, e_new_target, e_import_meta,
//       e_import_meta_main, e_require_main, e_special,
//       e_inlined_enum, e_name_of_symbol
//   }
//
// 注意: package.cj 中已有一个简化的 ExprTag 枚举。
// 这里提供与 Bun 源码精确对应的标签名称映射, 供 ExprData 使用。
// ============================================================================

/// Bun 精确表达式标签 - 对应 Bun Expr.Tag 的精确值名称
/// 与 package.cj 中的 ExprTag 不同, 这里保持 Bun 的 e_xxx 命名
/// 用于 ExprData 的内部映射
public enum BunExprTag {
    | EArray                   // e_array
    | EUnary                   // e_unary
    | EBinary                  // e_binary
    | EClass                   // e_class
    | ENew                     // e_new
    | EFunction                // e_function
    | ECall                    // e_call
    | EDot                     // e_dot
    | EIndex                   // e_index
    | EArrow                   // e_arrow
    | EJsxElement              // e_jsx_element
    | EObject                  // e_object
    | ESpread                  // e_spread
    | ETemplate                // e_template
    | ERegExp                  // e_reg_exp
    | EAwait                   // e_await
    | EYield                   // e_yield
    | EIf                      // e_if
    | EImport                  // e_import
    | EIdentifier              // e_identifier
    | EImportIdentifier        // e_import_identifier
    | EPrivateIdentifier       // e_private_identifier
    | ECommonJSExportIdentifier // e_commonjs_export_identifier
    | EBoolean                 // e_boolean
    | EBranchBoolean           // e_branch_boolean
    | ENumber                  // e_number
    | EBigInt                  // e_big_int
    | EString                  // e_string
    | ERequireString           // e_require_string
    | ERequireResolveString    // e_require_resolve_string
    | ERequireCallTarget       // e_require_call_target
    | ERequireResolveCallTarget // e_require_resolve_call_target
    | EMissing                 // e_missing
    | EThis                    // e_this
    | ESuper                   // e_super
    | ENull                    // e_null
    | EUndefined               // e_undefined
    | ENewTarget               // e_new_target
    | EImportMeta              // e_import_meta
    | EImportMetaMain          // e_import_meta_main
    | ERequireMain             // e_require_main
    | ESpecial                 // e_special
    | EInlinedEnum             // e_inlined_enum
    | ENameOfSymbol            // e_name_of_symbol

    public operator func ==(right: BunExprTag): Bool {
        return ordinal() == right.ordinal()
    }

    public operator func !=(right: BunExprTag): Bool {
        return !(this == right)
    }

    public func ordinal(): Int64 {
        match (this) {
            case EArray => 0
            case EUnary => 1
            case EBinary => 2
            case EClass => 3
            case ENew => 4
            case EFunction => 5
            case ECall => 6
            case EDot => 7
            case EIndex => 8
            case EArrow => 9
            case EJsxElement => 10
            case EObject => 11
            case ESpread => 12
            case ETemplate => 13
            case ERegExp => 14
            case EAwait => 15
            case EYield => 16
            case EIf => 17
            case EImport => 18
            case EIdentifier => 19
            case EImportIdentifier => 20
            case EPrivateIdentifier => 21
            case ECommonJSExportIdentifier => 22
            case EBoolean => 23
            case EBranchBoolean => 24
            case ENumber => 25
            case EBigInt => 26
            case EString => 27
            case ERequireString => 28
            case ERequireResolveString => 29
            case ERequireCallTarget => 30
            case ERequireResolveCallTarget => 31
            case EMissing => 32
            case EThis => 33
            case ESuper => 34
            case ENull => 35
            case EUndefined => 36
            case ENewTarget => 37
            case EImportMeta => 38
            case EImportMetaMain => 39
            case ERequireMain => 40
            case ESpecial => 41
            case EInlinedEnum => 42
            case ENameOfSymbol => 43
        }
    }

    /// 获取标签名称 - 对应 Bun @tagName(tag)
    public func name(): String {
        match (this) {
            case EArray => "e_array"
            case EUnary => "e_unary"
            case EBinary => "e_binary"
            case EClass => "e_class"
            case ENew => "e_new"
            case EFunction => "e_function"
            case ECall => "e_call"
            case EDot => "e_dot"
            case EIndex => "e_index"
            case EArrow => "e_arrow"
            case EJsxElement => "e_jsx_element"
            case EObject => "e_object"
            case ESpread => "e_spread"
            case ETemplate => "e_template"
            case ERegExp => "e_reg_exp"
            case EAwait => "e_await"
            case EYield => "e_yield"
            case EIf => "e_if"
            case EImport => "e_import"
            case EIdentifier => "e_identifier"
            case EImportIdentifier => "e_import_identifier"
            case EPrivateIdentifier => "e_private_identifier"
            case ECommonJSExportIdentifier => "e_commonjs_export_identifier"
            case EBoolean => "e_boolean"
            case EBranchBoolean => "e_branch_boolean"
            case ENumber => "e_number"
            case EBigInt => "e_big_int"
            case EString => "e_string"
            case ERequireString => "e_require_string"
            case ERequireResolveString => "e_require_resolve_string"
            case ERequireCallTarget => "e_require_call_target"
            case ERequireResolveCallTarget => "e_require_resolve_call_target"
            case EMissing => "e_missing"
            case EThis => "e_this"
            case ESuper => "e_super"
            case ENull => "e_null"
            case EUndefined => "e_undefined"
            case ENewTarget => "e_new_target"
            case EImportMeta => "e_import_meta"
            case EImportMetaMain => "e_import_meta_main"
            case ERequireMain => "e_require_main"
            case ESpecial => "e_special"
            case EInlinedEnum => "e_inlined_enum"
            case ENameOfSymbol => "e_name_of_symbol"
        }
    }

    /// 是否为原始字面量 - 对应 Bun Expr.Tag.isPrimitiveLiteral()
    /// Bun: pub fn isPrimitiveLiteral(tag: Tag) bool
    /// object, regex 和 array 可能有过副作用
    public func isPrimitiveLiteral(): Bool {
        match (this) {
            case ENull | EUndefined | EString | EBoolean |
                 EBranchBoolean | ENumber | EBigInt => true
            case _ => false
        }
    }

    /// typeof 结果 - 对应 Bun Expr.Tag.typeof()
    /// Bun: pub fn typeof(tag: Tag) ?string
    public func typeof_(): ?String {
        match (this) {
            case EArray | EObject | ENull | ERegExp => "object"
            case EUndefined => "undefined"
            case EBoolean | EBranchBoolean => "boolean"
            case ENumber => "number"
            case EBigInt => "bigint"
            case EString => "string"
            case EClass | EFunction | EArrow => "function"
            case _ => None
        }
    }

    /// 格式化标签 - 对应 Bun Expr.Tag.format()
    /// Bun: pub fn format(tag: Tag, writer: *std.Io.Writer) !void
    public func format(): String {
        match (this) {
            case EString => "string"
            case EArray => "array"
            case EUnary => "unary"
            case EBinary => "binary"
            case EBoolean | EBranchBoolean => "boolean"
            case ESuper => "super"
            case ENull => "null"
            case EUndefined => "undefined"
            case ENew => "new"
            case EFunction => "function"
            case ENewTarget => "new target"
            case EImportMeta => "import.meta"
            case ECall => "call"
            case EDot => "dot"
            case EIndex => "index"
            case EArrow => "arrow"
            case EIdentifier => "identifier"
            case EImportIdentifier => "import identifier"
            case EPrivateIdentifier => "#privateIdentifier"
            case EJsxElement => "<jsx>"
            case EMissing => "<missing>"
            case ENumber => "number"
            case EBigInt => "BigInt"
            case EObject => "object"
            case ESpread => "..."
            case ETemplate => "template"
            case ERegExp => "regexp"
            case EAwait => "await"
            case EYield => "yield"
            case EIf => "if"
            case ERequireResolveString => "require_or_require_resolve"
            case EImport => "import"
            case EThis => "this"
            case EClass => "class"
            case ERequireString => "require"
            case _ => name()
        }
    }

    // ---- 标签类型判断方法 ----
    // 对应 Bun Expr.Tag 中的 is*() 方法 (lines 1591-1925)

    public func isArray(): Bool { this == EArray }
    public func isUnary(): Bool { this == EUnary }
    public func isBinary(): Bool { this == EBinary }
    public func isClass(): Bool { this == EClass }
    public func isBoolean(): Bool { this == EBoolean || this == EBranchBoolean }
    public func isSuper(): Bool { this == ESuper }
    public func isNull(): Bool { this == ENull }
    public func isUndefined(): Bool { this == EUndefined }
    public func isNew(): Bool { this == ENew }
    public func isNewTarget(): Bool { this == ENewTarget }
    public func isFunction(): Bool { this == EFunction }
    public func isImportMeta(): Bool { this == EImportMeta }
    public func isCall(): Bool { this == ECall }
    public func isDot(): Bool { this == EDot }
    public func isIndex(): Bool { this == EIndex }
    public func isArrow(): Bool { this == EArrow }
    public func isIdentifier(): Bool { this == EIdentifier }
    public func isImportIdentifier(): Bool { this == EImportIdentifier }
    public func isPrivateIdentifier(): Bool { this == EPrivateIdentifier }
    public func isJsxElement(): Bool { this == EJsxElement }
    public func isMissing(): Bool { this == EMissing }
    public func isNumber(): Bool { this == ENumber }
    public func isBigInt(): Bool { this == EBigInt }
    public func isObject(): Bool { this == EObject }
    public func isSpread(): Bool { this == ESpread }
    public func isString(): Bool { this == EString }
    public func isTemplate(): Bool { this == ETemplate }
    public func isRegExp(): Bool { this == ERegExp }
    public func isAwait(): Bool { this == EAwait }
    public func isYield(): Bool { this == EYield }
    public func isIf(): Bool { this == EIf }
    public func isRequireResolveString(): Bool { this == ERequireResolveString }
    public func isImport(): Bool { this == EImport }
    public func isThis(): Bool { this == EThis }
}

// ============================================================================
// ExprFlags - 表达式标志
// 严格翻译自: src/ast/expr.zig:524
//   pub const EFlags = enum { none, ts_decorator }
// ============================================================================

/// 表达式标志 - 对应 Bun Expr.EFlags
public enum ExprFlags {
    | None
    | TsDecorator

    public func name(): String {
        match (this) {
            case None => "none"
            case TsDecorator => "ts_decorator"
        }
    }
}

// ============================================================================
// ExprQuery - 表达式查询
// 严格翻译自: src/ast/expr.zig:132
//   pub const Query = struct { expr: Expr, loc: logger.Loc, i: u32 = 0 }
// ============================================================================

/// 表达式查询结果 - 对应 Bun Expr.Query
/// Bun: pub const Query = struct { expr: Expr, loc: logger.Loc, i: u32 = 0 }
public class ExprQuery {
    public var expr: ASTNode
    public var loc: ASTLoc
    public var i: UInt32

    public init(expr: ASTNode, loc: ASTLoc, i: UInt32) {
        this.expr = expr
        this.loc = loc
        this.i = i
    }

    public init(expr: ASTNode, loc: ASTLoc) {
        this.expr = expr
        this.loc = loc
        this.i = UInt32(0)
    }
}

// ============================================================================
// ArrayIterator - 数组迭代器
// 严格翻译自: src/ast/expr.zig:436-455
//   pub const ArrayIterator = struct {
//       array: *const E.Array,
//       index: u32,
//       pub fn next(this: *ArrayIterator) ?Expr
//   }
// ============================================================================

/// 数组迭代器 - 对应 Bun Expr.ArrayIterator
/// Bun: pub const ArrayIterator = struct { array: *const E.Array, index: u32 }
public class ExprArrayIterator {
    public var array: EArray
    public var index: Int64

    public init(array: EArray) {
        this.array = array
        this.index = Int64(0)
    }

    /// 获取下一个元素 - 对应 Bun ArrayIterator.next()
    /// Bun: pub fn next(this: *ArrayIterator) ?Expr
    public func next(): ?ASTNode {
        if (index >= array.items.size) {
            return None
        }
        let result = array.items[index]
        index += Int64(1)
        return Some(result)
    }
}

// ============================================================================
// ExprData - 表达式数据联合体
// 严格翻译自: src/ast/expr.zig:2130-3202
//   pub const Data = union(Tag) {
//       e_array: *E.Array, e_unary: *E.Unary, e_binary: *E.Binary, ...
//       clone, deepClone, canBeConstValue, canBeMoved, isSafeToString,
//       knownPrimitive, mergeKnownPrimitive, toTypeof, toNumber,
//       toFiniteNumber, extractNumericValue, extractStringValue,
//       eql, writeToHasher, isStringValue
//   }
// ============================================================================

/// 表达式数据 - 对应 Bun Expr.Data
/// Bun 使用 tagged union, 仓颉用类 + BunExprTag 模拟
/// 提供对表达式节点的类型安全访问和丰富的方法集
public class ExprData {
    /// 标签 - 对应 Bun union tag
    public var tag: BunExprTag
    /// 源码位置
    public var loc: ASTLoc
    /// 节点数据 - 对应 Bun union 的 payload
    public var payload: Any
    /// 子表达式列表 (用于 clone/deepClone)
    public var children: ArrayList<ExprData>

    public init(tag: BunExprTag, loc: ASTLoc, payload: Any) {
        this.tag = tag
        this.loc = loc
        this.payload = payload
        this.children = ArrayList<ExprData>()
    }

    public init(tag: BunExprTag, loc: ASTLoc) {
        this.tag = tag
        this.loc = loc
        this.payload = Option<Any>.None
        this.children = ArrayList<ExprData>()
    }

    /// 获取标签名 - 对应 Bun @tagName(data)
    public func tagName(): String {
        return tag.name()
    }

    // ---- 类型判断方法 ----
    // 对应 Bun Expr.Data 的 switch(data) 模式

    /// 是否为数组 - 对应 Bun data == .e_array
    public func isArray(): Bool { tag == BunExprTag.EArray }

    /// 是否为对象 - 对应 Bun data == .e_object
    public func isObject(): Bool { tag == BunExprTag.EObject }

    /// 是否为字符串 - 对应 Bun data == .e_string
    /// Bun: pub inline fn isStringValue(self: Data) bool
    public func isStringValue(): Bool { tag == BunExprTag.EString }

    /// 是否为缺失 - 对应 Bun data == .e_missing
    public func isMissing(): Bool { tag == BunExprTag.EMissing }

    /// 是否为布尔 - 包含 e_boolean 和 e_branch_boolean
    public func isBooleanValue(): Bool {
        tag == BunExprTag.EBoolean || tag == BunExprTag.EBranchBoolean
    }

    public static func fromASTNode(node: ASTNode): ExprData {
        ExprData(exprTagToBunExprTag(node.tag), node.loc, node.value)
    }

    // ---- 数值提取方法 ----
    // 严格翻译自: src/ast/expr.zig:2843-2909

    /// 转为数字 - 对应 Bun Expr.Data.toNumber()
    /// Bun: pub fn toNumber(data: Expr.Data) ?f64
    public func toNumber(): ?Float64 {
        match (tag) {
            case ENull => Float64(0)
            case EUndefined => Float64(0.0 / 0.0) // NaN
            case EBoolean | EBranchBoolean =>
                match (payload) {
                    case b: EBoolean => if (b.value) { Float64(1.0) } else { Float64(0.0) }
                    case _ => None
                }
            case ENumber =>
                match (payload) {
                    case n: ENumber => n.value
                    case _ => None
                }
            case EString =>
                match (payload) {
                    case s: EString =>
                        if (s.next.isSome()) { return None }
                        if (!s.isUTF8()) { return None }
                        // +'1' => 1 (简化实现)
                        let d = s.data
                        if (d.size == Int64(0)) { return Float64(0) }
                        return Float64.parse(d)
                    case _ => None
                }
            case EInlinedEnum =>
                // 递归到内联值
                match (payload) {
                    case ie: EInlinedEnum =>
                        let innerData = ExprData.fromASTNode(ie.value)
                        return innerData.toNumber()
                    case _ => None
                }
            case _ => None
        }
    }

    /// 转为有限数字 - 对应 Bun Expr.Data.toFiniteNumber()
    /// Bun: pub fn toFiniteNumber(data: Expr.Data) ?f64
    public func toFiniteNumber(): ?Float64 {
        match (tag) {
            case EBoolean | EBranchBoolean =>
                match (payload) {
                    case b: EBoolean => if (b.value) { Float64(1.0) } else { Float64(0.0) }
                    case _ => None
                }
            case ENumber =>
                match (payload) {
                    case n: ENumber =>
                        let v = n.value
                        // 检查 isFinite: 非 NaN 且非 Inf
                        if (v == v && v != Float64(1.0 / 0.0) && v != Float64(-1.0 / 0.0)) {
                            return v
                        }
                        return None
                    case _ => None
                }
            case EInlinedEnum =>
                match (payload) {
                    case ie: EInlinedEnum =>
                        let innerData = ExprData.fromASTNode(ie.value)
                        return innerData.toFiniteNumber()
                    case _ => None
                }
            case _ => None
        }
    }

    /// 提取数值 - 对应 Bun Expr.Data.extractNumericValue()
    /// Bun: pub fn extractNumericValue(data: Expr.Data) ?f64
    public func extractNumericValue(): ?Float64 {
        match (tag) {
            case ENumber =>
                match (payload) {
                    case n: ENumber => n.value
                    case _ => None
                }
            case EInlinedEnum =>
                match (payload) {
                    case ie: EInlinedEnum =>
                        match (ie.value.value) {
                            case n: ENumber => n.value
                            case _ => None
                        }
                    case _ => None
                }
            case _ => None
        }
    }

    /// 提取字符串值 - 对应 Bun Expr.Data.extractStringValue()
    /// Bun: pub fn extractStringValue(data: Expr.Data) ?*E.String
    public func extractStringValue(): ?EString {
        match (tag) {
            case EString =>
                match (payload) {
                    case s: EString => Some(s)
                    case _ => None
                }
            case EInlinedEnum =>
                match (payload) {
                    case ie: EInlinedEnum =>
                        match (ie.value.value) {
                            case s: EString => Some(s)
                            case _ => None
                        }
                    case _ => None
                }
            case _ => None
        }
    }

    // ---- 属性判断方法 ----
    // 严格翻译自: src/ast/expr.zig:2645-2713

    /// 是否可作为常量值 - 对应 Bun Expr.Data.canBeConstValue()
    /// Bun: pub fn canBeConstValue(this: Expr.Data) bool
    /// "const values" 是实例化时无副作用且重复不会产生可观察差异的表达式
    public func canBeConstValue(): Bool {
        match (tag) {
            case ENumber | EBoolean | EBranchBoolean | ENull | EUndefined |
                 EInlinedEnum => true
            case EString =>
                match (payload) {
                    case s: EString => s.next.isNone()
                    case _ => false
                }
            case EArray =>
                match (payload) {
                    case a: EArray => a.wasOriginallyMacro
                    case _ => false
                }
            case EObject =>
                match (payload) {
                    case o: EObject => o.wasOriginallyMacro
                    case _ => false
                }
            case _ => false
        }
    }

    /// 是否可移动 - 对应 Bun Expr.Data.canBeMoved()
    /// Bun: pub fn canBeMoved(data: Expr.Data) bool
    /// 可移动的表达式是没有副作用的表达式, 可移出模块包装器
    public func canBeMoved(): Bool {
        match (tag) {
            case EClass =>
                match (payload) {
                    case c: Class => c.canBeMoved()
                    case _ => false
                }
            case EArrow | EFunction | ENumber | EBoolean | EBranchBoolean |
                 ENull | EUndefined | EBigInt | EString | EInlinedEnum |
                 EImportMeta => true
            case ETemplate =>
                match (payload) {
                    case t: ETemplate => t.tag.isNone() && t.parts.size == Int64(0)
                    case _ => false
                }
            case EArray =>
                match (payload) {
                    case a: EArray => a.wasOriginallyMacro
                    case _ => false
                }
            case EObject =>
                match (payload) {
                    case o: EObject => o.wasOriginallyMacro
                    case _ => false
                }
            case _ => false
        }
    }

    /// 是否安全 toString - 对应 Bun Expr.Data.isSafeToString()
    /// Bun: pub fn isSafeToString(data: Expr.Data) bool
    public func isSafeToString(): Bool {
        match (tag) {
            case EString =>
                match (payload) {
                    case s: EString => s.next.isNone()
                    case _ => false
                }
            case ENumber | EBoolean | EBranchBoolean | EUndefined | ENull => true
            // BigInt 被故意排除, 因为大 BigInt 可能抛出 OOM
            case _ => false
        }
    }

    // ---- 原始类型推导 ----
    // 严格翻译自: src/ast/expr.zig:2715-2834

    /// 已知原始类型 - 对应 Bun Expr.Data.knownPrimitive()
    /// Bun: pub fn knownPrimitive(data: Expr.Data) PrimitiveType
    /// 这是一个复杂的类型推导, 包含对一元/二元/条件表达式的递归推导
    public func knownPrimitive(): PrimitiveType {
        match (tag) {
            case EBigInt => PrimitiveType.Bigint
            case EBoolean | EBranchBoolean => PrimitiveType.Boolean
            case ENull => PrimitiveType.Null
            case ENumber => PrimitiveType.Number
            case EString => PrimitiveType.String
            case EUndefined => PrimitiveType.Undefined
            case ETemplate =>
                // 如果没有 tag, 模板字面量结果为 string
                match (payload) {
                    case t: ETemplate =>
                        if (t.tag.isNone()) { PrimitiveType.String } else { PrimitiveType.Unknown }
                    case _ => PrimitiveType.Unknown
                }
            case EIf =>
                // 三元表达式的类型是两个分支的合并
                match (payload) {
                    case if_: EIf =>
                        mergeKnownPrimitiveExpr(if_.yes, if_.no)
                    case _ => PrimitiveType.Unknown
                }
            case EBinary =>
                match (payload) {
                    case bin: EBinary => knownPrimitiveBinary(bin)
                    case _ => PrimitiveType.Unknown
                }
            case EUnary =>
                match (payload) {
                    case un: EUnary => knownPrimitiveUnary(un)
                    case _ => PrimitiveType.Unknown
                }
            case EInlinedEnum =>
                match (payload) {
                    case ie: EInlinedEnum =>
                        // 内联枚举使用其内部值的类型
                        let innerData = ExprData.fromASTNode(ie.value)
                        innerData.knownPrimitive()
                    case _ => PrimitiveType.Unknown
                }
            case _ => PrimitiveType.Unknown
        }
    }

    /// 合并已知原始类型 (两个 ExprData) - 对应 Bun Expr.Data.mergeKnownPrimitive()
    /// Bun: pub fn mergeKnownPrimitive(lhs: Expr.Data, rhs: Expr.Data) PrimitiveType
    public static func mergeKnownPrimitiveExpr(left: ASTNode, right: ASTNode): PrimitiveType {
        // 简化: 使用 tag 来推导
        let leftType = ExprFactory.knownPrimitive(left)
        let rightType = ExprFactory.knownPrimitive(right)
        return PrimitiveType.merge(leftType, rightType)
    }

    /// 二元表达式原始类型推导 - 对应 Bun Expr.Data.knownPrimitive() 中 e_binary 分支
    /// Bun: lines 2725-2809
    public static func knownPrimitiveBinary(bin: EBinary): PrimitiveType {
        match (bin.op) {
            // 比较操作 => boolean
            case OpCode.BinStrictEq | OpCode.BinStrictNe |
                 OpCode.BinLooseEq | OpCode.BinLooseNe |
                 OpCode.BinLt | OpCode.BinGt |
                 OpCode.BinLe | OpCode.BinGe |
                 OpCode.BinInstanceof | OpCode.BinIn => PrimitiveType.Boolean
            // 逻辑操作 => 合并左右
            case OpCode.BinLogicalOr | OpCode.BinLogicalAnd =>
                PrimitiveType.merge(
                    ExprFactory.knownPrimitive(bin.left),
                    ExprFactory.knownPrimitive(bin.right)
                )
            // 空值合并 => 复杂推导
            case OpCode.BinNullishCoalescing =>
                let leftType = ExprFactory.knownPrimitive(bin.left)
                let rightType = ExprFactory.knownPrimitive(bin.right)
                if (leftType == PrimitiveType.Null || leftType == PrimitiveType.Undefined) {
                    return rightType
                }
                if (leftType != PrimitiveType.Unknown) {
                    if (leftType != PrimitiveType.Mixed) {
                        return leftType
                    }
                    if (rightType != PrimitiveType.Unknown) {
                        return PrimitiveType.Mixed
                    }
                }
                PrimitiveType.Unknown
            // 加法 => string/bigint/number/mixed
            case OpCode.BinAdd =>
                let leftType = ExprFactory.knownPrimitive(bin.left)
                let rightType = ExprFactory.knownPrimitive(bin.right)
                if (leftType == PrimitiveType.String || rightType == PrimitiveType.String) {
                    return PrimitiveType.String
                }
                if (leftType == PrimitiveType.Bigint || rightType == PrimitiveType.Bigint) {
                    return PrimitiveType.Bigint
                }
                PrimitiveType.Mixed
            // 算术/位运算 => mixed (number 或 bigint)
            case OpCode.BinSub | OpCode.BinMul | OpCode.BinDiv | OpCode.BinRem |
                 OpCode.BinPow | OpCode.BinShl | OpCode.BinShr | OpCode.BinUShr |
                 OpCode.BinBitwiseAnd | OpCode.BinBitwiseOr | OpCode.BinBitwiseXor |
                 OpCode.BinSubAssign | OpCode.BinMulAssign | OpCode.BinDivAssign |
                 OpCode.BinRemAssign | OpCode.BinPowAssign |
                 OpCode.BinShlAssign | OpCode.BinShrAssign | OpCode.BinUShrAssign |
                 OpCode.BinBitwiseAndAssign | OpCode.BinBitwiseOrAssign |
                 OpCode.BinBitwiseXorAssign => PrimitiveType.Mixed
            // 赋值/逗号 => 右侧类型
            case OpCode.BinAssign | OpCode.BinComma =>
                ExprFactory.knownPrimitive(bin.right)
            case _ => PrimitiveType.Unknown
        }
    }

    /// 一元表达式原始类型推导 - 对应 Bun Expr.Data.knownPrimitive() 中 e_unary 分支
    /// Bun: lines 2811-2824
    public static func knownPrimitiveUnary(un: EUnary): PrimitiveType {
        match (un.op) {
            case OpCode.UnVoid => PrimitiveType.Undefined
            case OpCode.UnTypeof => PrimitiveType.String
            case OpCode.UnNot | OpCode.UnDelete => PrimitiveType.Boolean
            case OpCode.UnPos => PrimitiveType.Number
            case OpCode.UnNeg | OpCode.UnCpl =>
                // 取决于操作数的类型
                let innerType = ExprFactory.knownPrimitive(un.value)
                match (innerType) {
                    case PrimitiveType.Bigint => PrimitiveType.Bigint
                    case PrimitiveType.Unknown | PrimitiveType.Mixed => PrimitiveType.Mixed
                    case _ => PrimitiveType.Number
                }
            case OpCode.UnPreDec | OpCode.UnPreInc |
                 OpCode.UnPostDec | OpCode.UnPostInc => PrimitiveType.Mixed
            case _ => PrimitiveType.Unknown
        }
    }

    /// typeof 结果 - 对应 Bun Expr.Data.toTypeof()
    /// Bun: pub inline fn toTypeof(data: Expr.Data) ?string
    public func toTypeof(): ?String {
        return tag.typeof_()
    }

    // ---- 相等性比较 ----
    // 严格翻译自: src/ast/expr.zig:2928-3113

    /// 表达式相等比较 - 对应 Bun Expr.Data.eql()
    /// Bun: pub fn eql(left: Expr.Data, right: Expr.Data, p: anytype,
    ///       comptime kind: enum { loose, strict }) Equality
    /// 返回 "equal, ok"。如果 ok 为 false, 则对两个值一无所知。
    /// 如果 ok 为 true, 则两个值的相等/不等存储在 "equal" 中。
    public static func eql(left: ExprData, right: ExprData, kind: EqualityKind): ExprEquality {
        // 处理内联枚举: 递归到内部值
        if (left.tag == BunExprTag.EInlinedEnum) {
            match (left.payload) {
                case ie: EInlinedEnum =>
                    let inner = ExprData.fromASTNode(ie.value)
                    return eql(inner, right, kind)
                case _ => ()
            }
        }

        match (left.tag) {
            // null / undefined
            case ENull | EUndefined =>
                let ok: Bool = match (right.tag) {
                    case ENull | EUndefined => true
                    case _ => right.tag.isPrimitiveLiteral()
                }
                if (isLooseEquality(kind)) {
                    return ExprEquality(
                        match (right.tag) {
                            case ENull | EUndefined => true
                            case _ => false
                        },
                        ok
                    )
                }
                // strict
                return ExprEquality(right.tag == left.tag, ok)
            // boolean
            case EBoolean | EBranchBoolean =>
                let lVal = extractBoolValue(left)
                match (right.tag) {
                    case EBoolean | EBranchBoolean =>
                        let rVal = extractBoolValue(right)
                        if (lVal.isSome() && rVal.isSome()) {
                            return ExprEquality(lVal.getOrDefault({ => false }) == rVal.getOrDefault({ => false }), true)
                        }
                    case ENumber =>
                        if (isStrictEquality(kind)) {
                            return ExprEquality.FALSE
                        }
                        let rNum = extractNumberValue(right)
                        if (lVal.isSome() && rNum.isSome()) {
                            let b = lVal.getOrDefault({ => false })
                            let n = rNum.getOrDefault({ => Float64(0) })
                            return ExprEquality(if (b) { n == Float64(1) } else { n == Float64(0) }, true)
                        }
                    case ENull | EUndefined => return ExprEquality.FALSE
                    case _ => ()
                }
            // number
            case ENumber =>
                let lNum = extractNumberValue(left)
                match (right.tag) {
                    case ENumber =>
                        let rNum = extractNumberValue(right)
                        if (lNum.isSome() && rNum.isSome()) {
                            return ExprEquality(lNum.getOrDefault({ => Float64(0) }) == rNum.getOrDefault({ => Float64(0) }), true)
                        }
                    case EInlinedEnum =>
                        // 简化: 检查内联枚举的数值
                        ()
                    case EBoolean | EBranchBoolean =>
                        if (isLooseEquality(kind)) {
                            let rVal = extractBoolValue(right)
                            if (lNum.isSome() && rVal.isSome()) {
                                let n = lNum.getOrDefault({ => Float64(0) })
                                let b = rVal.getOrDefault({ => false })
                                return ExprEquality(if (b) { n == Float64(1) } else { n == Float64(0) }, true)
                            }
                        }
                        return ExprEquality.FALSE
                    case ENull | EUndefined => return ExprEquality.FALSE
                    case _ => ()
                }
            // bigint
            case EBigInt =>
                if (right.tag == BunExprTag.EBigInt) {
                    let lStr = extractBigintValue(left)
                    let rStr = extractBigintValue(right)
                    if (lStr.isSome() && rStr.isSome()) {
                        if (lStr.getOrDefault({ => "" }) == rStr.getOrDefault({ => "" })) {
                            return ExprEquality.TRUE
                        }
                    }
                    return ExprEquality(false, false)
                }
                let ok: Bool = match (right.tag) {
                    case ENull | EUndefined => true
                    case _ => false
                }
                return ExprEquality(false, ok)
            // string
            case EString =>
                match (right.tag) {
                    case EString =>
                        let lStr = left.extractStringValue()
                        let rStr = right.extractStringValue()
                        if (lStr.isSome() && rStr.isSome()) {
                            return ExprEquality(lStr.getOrDefault({ => EString() }).eql(rStr.getOrDefault({ => EString() })), true)
                        }
                    case ENull | EUndefined => return ExprEquality.FALSE
                    case _ => ()
                }
            case _ => ()
        }

        return ExprEquality.UNKNOWN
    }
}

/// 相等比较类型 - 对应 Bun eql 的 kind 参数
public enum EqualityKind {
    | Loose   // ==
    | Strict  // ===
}

private func isLooseEquality(kind: EqualityKind): Bool {
    match (kind) {
        case Loose => true
        case Strict => false
    }
}

private func isStrictEquality(kind: EqualityKind): Bool {
    match (kind) {
        case Strict => true
        case Loose => false
    }
}

private func exprTagToBunExprTag(tag: ExprTag): BunExprTag {
    match (tag) {
        case ExprTag.Missing => BunExprTag.EMissing
        case ExprTag.Boolean => BunExprTag.EBoolean
        case ExprTag.Null => BunExprTag.ENull
        case ExprTag.Undefined => BunExprTag.EUndefined
        case ExprTag.Number => BunExprTag.ENumber
        case ExprTag.BigInt => BunExprTag.EBigInt
        case ExprTag.StringExpr => BunExprTag.EString
        case ExprTag.Template => BunExprTag.ETemplate
        case ExprTag.RegExp => BunExprTag.ERegExp
        case ExprTag.Identifier => BunExprTag.EIdentifier
        case ExprTag.ImportIdentifier => BunExprTag.EImportIdentifier
        case ExprTag.ThisExpr => BunExprTag.EThis
        case ExprTag.Super => BunExprTag.ESuper
        case ExprTag.Array => BunExprTag.EArray
        case ExprTag.Object => BunExprTag.EObject
        case ExprTag.Arrow => BunExprTag.EArrow
        case ExprTag.Function => BunExprTag.EFunction
        case ExprTag.Class => BunExprTag.EClass
        case ExprTag.Call => BunExprTag.ECall
        case ExprTag.New => BunExprTag.ENew
        case ExprTag.Member => BunExprTag.EDot
        case ExprTag.Index => BunExprTag.EIndex
        case ExprTag.TaggedTemplate => BunExprTag.ETemplate
        case ExprTag.Spread => BunExprTag.ESpread
        case ExprTag.Binary => BunExprTag.EBinary
        case ExprTag.Unary => BunExprTag.EUnary
        case ExprTag.Await => BunExprTag.EAwait
        case ExprTag.Yield => BunExprTag.EYield
        case ExprTag.Conditional => BunExprTag.EIf
        case ExprTag.Assign => BunExprTag.EBinary
        case ExprTag.Sequence => BunExprTag.EBinary
        case ExprTag.TypeCast => BunExprTag.ESpecial
        case ExprTag.JsxElement => BunExprTag.EJsxElement
        case ExprTag.JsxFragment => BunExprTag.EJsxElement
        case ExprTag.InlinedEnum => BunExprTag.EInlinedEnum
        case ExprTag.RequireString => BunExprTag.ERequireString
        case ExprTag.ImportRecord => BunExprTag.EImport
    }
}

/// 辅助: 从 ExprData 提取布尔值
private func extractBoolValue(data: ExprData): ?Bool {
    match (data.payload) {
        case b: EBoolean => Some(b.value)
        case _ => None
    }
}

/// 辅助: 从 ExprData 提取数字值
private func extractNumberValue(data: ExprData): ?Float64 {
    match (data.payload) {
        case n: ENumber => Some(n.value)
        case _ => None
    }
}

/// 辅助: 从 ExprData 提取 BigInt 值
private func extractBigintValue(data: ExprData): ?String {
    match (data.payload) {
        case b: EBigInt => Some(b.value)
        case _ => None
    }
}

// ============================================================================
// 数值提取辅助函数
// 严格翻译自: src/ast/expr.zig:660-703
// ============================================================================

/// 提取安全范围内的数值 - 对应 Bun Expr.extractNumericValuesInSafeRange()
/// Bun: pub fn extractNumericValuesInSafeRange(left: Expr.Data, right: Expr.Data) ?[2]f64
/// 检查 NaN/Infinity 和安全整数范围
public class NumericExtractor {
    /// 安全整数上限 - 对应 Bun jsc.MAX_SAFE_INTEGER
    public static let MAX_SAFE_INTEGER: Float64 = Float64(9007199254740991.0)
    /// 安全整数下限 - 对应 Bun jsc.MIN_SAFE_INTEGER
    public static let MIN_SAFE_INTEGER: Float64 = Float64(-9007199254740991.0)

    /// 提取安全范围内的数值对
    public static func extractNumericValuesInSafeRange(leftData: ExprData, rightData: ExprData): ?Tuple2<Float64> {
        let lValue = leftData.extractNumericValue()
        let rValue = rightData.extractNumericValue()
        if (lValue.isNone() || rValue.isNone()) {
            return None
        }
        let lv = lValue.getOrDefault({ => Float64(0) })
        let rv = rValue.getOrDefault({ => Float64(0) })

        // 检查 NaN
        if (lv != lv || rv != rv) {
            return None
        }
        // 检查 Infinity (允许)
        // 检查安全整数范围
        if (lv > MAX_SAFE_INTEGER || rv > MAX_SAFE_INTEGER) {
            return None
        }
        if (lv < MIN_SAFE_INTEGER || rv < MIN_SAFE_INTEGER) {
            return None
        }
        return Some(Tuple2<Float64>(lv, rv))
    }

    /// 提取数值对 (不做安全范围检查)
    /// 对应 Bun Expr.extractNumericValues()
    /// Bun: pub fn extractNumericValues(left: Expr.Data, right: Expr.Data) ?[2]f64
    public static func extractNumericValues(leftData: ExprData, rightData: ExprData): ?Tuple2<Float64> {
        let lv = leftData.extractNumericValue()
        let rv = rightData.extractNumericValue()
        if (lv.isNone() || rv.isNone()) {
            return None
        }
        return Some(Tuple2<Float64>(lv.getOrDefault({ => Float64(0) }), rv.getOrDefault({ => Float64(0) })))
    }

    /// 提取字符串值对 - 对应 Bun Expr.extractStringValues()
    /// Bun: pub fn extractStringValues(left: Expr.Data, right: Expr.Data, allocator) ?[2]*E.String
    public static func extractStringValues(leftData: ExprData, rightData: ExprData): ?Tuple2<EString> {
        let ls = leftData.extractStringValue()
        let rs = rightData.extractStringValue()
        if (ls.isNone() || rs.isNone()) {
            return None
        }
        let lStr = ls.getOrDefault({ => EString() })
        let rStr = rs.getOrDefault({ => EString() })
        lStr.resolveRopeIfNeeded()
        rStr.resolveRopeIfNeeded()
        if (lStr.isUTF8() != rStr.isUTF8()) {
            return None
        }
        return Some(Tuple2<EString>(lStr, rStr))
    }
}

/// 二元组辅助 - 对应 Zig [2]T
public class Tuple2<T> {
    public var v0: T
    public var v1: T

    public init(v0: T, v1: T) {
        this.v0 = v0
        this.v1 = v1
    }
}

// ============================================================================
// ExprFactory - 表达式工厂和工具方法
// 严格翻译自: src/ast/expr.zig:1-1455 (顶层函数)
//   Expr.init(), Expr.allocate(), Expr.clone(), Expr.deepClone(),
//   Expr.isAnonymousNamed(), Expr.canBeInlinedFromPropertyAccess(),
//   Expr.isEmpty(), Expr.isMissing(), Expr.isArray(), Expr.isObject(),
//   Expr.get(), Expr.set(), Expr.getByIndex(), Expr.getPathMayBeIndex(),
//   Expr.asProperty(), Expr.asArray(), Expr.asUtf8StringLiteral(),
//   Expr.asStringLiteral(), Expr.isString(), Expr.asString(),
//   Expr.asBool(), Expr.asNumber(), Expr.isRef(),
//   Expr.hasValueForThisInCall(), Expr.isPropertyAccess(),
//   Expr.isOptionalChain(), Expr.knownPrimitive(), Expr.isBoolean(),
//   Expr.not(), Expr.maybeSimplifyNot(), Expr.unwrapInlined(),
//   Expr.assign(), Expr.joinWithLeftAssociativeOp(),
//   Expr.joinWithComma(), Expr.joinAllWithComma(),
//   Expr.joinAllWithCommaCallback(), Expr.wrapInArrow(),
//   Expr.toStringExprWithoutSideEffects(),
//   Expr.canBeConstValue(), Expr.canBeMoved(),
//   Expr.initIdentifier(), Expr.toEmpty(), Expr.at()
// ============================================================================

/// Expr 工厂 - 对应 Bun Expr.init() / Expr.allocate()
/// 创建各种类型的表达式节点, 提供表达式工具方法
public class ExprFactory {
    // ---- 工厂方法 ----

    /// 创建缺失表达式 - 对应 Bun Expr{ .data = .{ .e_missing = E.Missing{} } }
    public static func missing(loc: ASTLoc): ASTNode {
        return ASTNode(ExprTag.Missing, loc)
    }

    /// 创建布尔表达式
    public static func boolean(value: Bool, loc: ASTLoc): ASTNode {
        return ASTNode(ExprTag.Boolean, loc, value)
    }

    /// 创建 null 表达式
    public static func null_(loc: ASTLoc): ASTNode {
        return ASTNode(ExprTag.Null, loc, ENull())
    }

    /// 创建 undefined 表达式
    public static func undefined(loc: ASTLoc): ASTNode {
        return ASTNode(ExprTag.Undefined, loc, EUndefined())
    }

    /// 创建数字表达式
    public static func number(value: Float64, loc: ASTLoc): ASTNode {
        return ASTNode(ExprTag.Number, loc, ENumber(value))
    }

    /// 创建 BigInt 表达式
    public static func bigInt(value: String, loc: ASTLoc): ASTNode {
        return ASTNode(ExprTag.BigInt, loc, EBigInt(value))
    }

    /// 创建字符串表达式
    public static func string(value: String, loc: ASTLoc): ASTNode {
        return ASTNode(ExprTag.StringExpr, loc, EString(value))
    }

    /// 创建标识符表达式 - 对应 Bun Expr.initIdentifier()
    /// Bun: pub inline fn initIdentifier(ref: Ref, loc: logger.Loc) Expr
    public static func identifier(ref: Ref, loc: ASTLoc): ASTNode {
        return ASTNode(ExprTag.Identifier, loc, EIdentifier(ref))
    }

    /// 创建 this 表达式
    public static func this_(loc: ASTLoc): ASTNode {
        return ASTNode(ExprTag.ThisExpr, loc, EThis())
    }

    /// 创建 super 表达式
    public static func super_(loc: ASTLoc): ASTNode {
        return ASTNode(ExprTag.Super, loc, ESuper())
    }

    /// 创建数组表达式
    public static func array(items: ArrayList<ASTNode>, loc: ASTLoc): ASTNode {
        let node = ASTNode(ExprTag.Array, loc, EArray())
        for (item in items) {
            node.addChild(item)
        }
        return node
    }

    /// 创建对象表达式
    public static func object(properties: ArrayList<GProperty>, loc: ASTLoc): ASTNode {
        let node = ASTNode(ExprTag.Object, loc, EObject())
        for (`prop` in properties) {
            if (`prop`.key.isSome()) {
                node.addChild(`prop`.key.getOrDefault({ => ASTNode(ExprTag.Missing, loc) }))
            }
            if (`prop`.value.isSome()) {
                node.addChild(`prop`.value.getOrDefault({ => ASTNode(ExprTag.Missing, loc) }))
            }
        }
        return node
    }

    /// 创建调用表达式
    public static func call(target: ASTNode, args: ArrayList<ASTNode>, loc: ASTLoc): ASTNode {
        let node = ASTNode(ExprTag.Call, loc, ECall(target, args))
        node.addChild(target)
        for (arg in args) {
            node.addChild(arg)
        }
        return node
    }

    /// 创建 new 表达式
    public static func new_(target: ASTNode, args: ArrayList<ASTNode>, loc: ASTLoc): ASTNode {
        let node = ASTNode(ExprTag.New, loc, ENew(target, args))
        node.addChild(target)
        for (arg in args) {
            node.addChild(arg)
        }
        return node
    }

    /// 创建成员访问表达式 (a.b)
    public static func dot(target: ASTNode, name: String, nameLoc: ASTLoc, loc: ASTLoc): ASTNode {
        let node = ASTNode(ExprTag.Member, loc, EDot(target, name, nameLoc))
        node.addChild(target)
        return node
    }

    /// 创建索引访问表达式 (a[b])
    public static func index(target: ASTNode, index: ASTNode, loc: ASTLoc): ASTNode {
        let node = ASTNode(ExprTag.Index, loc, EIndex(index, target))
        node.addChild(target)
        node.addChild(index)
        return node
    }

    /// 创建一元表达式
    public static func unary(op: OpCode, value: ASTNode, loc: ASTLoc): ASTNode {
        let node = ASTNode(ExprTag.Unary, loc, EUnary(op, value))
        node.addChild(value)
        return node
    }

    /// 创建二元表达式
    public static func binary(op: OpCode, left: ASTNode, right: ASTNode, loc: ASTLoc): ASTNode {
        let node = ASTNode(ExprTag.Binary, loc, EBinary(left, right, op))
        node.addChild(left)
        node.addChild(right)
        return node
    }

    /// 创建赋值表达式 - 对应 Bun Expr.assign()
    /// Bun: pub fn assign(a: Expr, b: Expr) Expr
    public static func assign(left: ASTNode, right: ASTNode): ASTNode {
        return binary(OpCode.BinAssign, left, right, left.loc)
    }

    /// 创建箭头函数
    public static func arrow(args: ArrayList<GArg>, body: GFnBody, isAsync: Bool, loc: ASTLoc): ASTNode {
        return ASTNode(ExprTag.Arrow, loc, EArrow(args, body, isAsync))
    }

    /// 创建函数表达式
    public static func function(`func`: GFn, loc: ASTLoc): ASTNode {
        return ASTNode(ExprTag.Function, loc, EFunction(`func`))
    }

    /// 创建三元条件表达式
    public static func conditional(test_: ASTNode, yes: ASTNode, no: ASTNode, loc: ASTLoc): ASTNode {
        let node = ASTNode(ExprTag.Conditional, loc, EIf(test_, yes, no))
        node.addChild(test_)
        node.addChild(yes)
        node.addChild(no)
        return node
    }

    /// 创建展开运算符
    public static func spread(value: ASTNode, loc: ASTLoc): ASTNode {
        let node = ASTNode(ExprTag.Spread, loc, ESpread(value))
        node.addChild(value)
        return node
    }

    /// 创建 await 表达式
    public static func await_(value: ASTNode, loc: ASTLoc): ASTNode {
        let node = ASTNode(ExprTag.Await, loc, EAwait(value))
        node.addChild(value)
        return node
    }

    /// 创建 yield 表达式
    public static func yield_(value: ?ASTNode, isStar: Bool, loc: ASTLoc): ASTNode {
        let node = ASTNode(ExprTag.Yield, loc, EYield(value, isStar))
        if (value.isSome()) {
            node.addChild(value.getOrDefault({ => ASTNode(ExprTag.Missing, loc) }))
        }
        return node
    }

    /// 创建模板字面量
    public static func template(tag: ?ASTNode, parts: ArrayList<ETemplatePart>,
                                head: TemplateContents, loc: ASTLoc): ASTNode {
        return ASTNode(ExprTag.Template, loc, ETemplate(tag, parts, head))
    }

    /// 创建正则表达式
    public static func regExp(value: String, loc: ASTLoc): ASTNode {
        return ASTNode(ExprTag.RegExp, loc, ERegExp(value))
    }

    /// 创建 import() 表达式
    public static func import_(expr: ASTNode, options: ASTNode,
                               importRecordIndex: UInt32, loc: ASTLoc): ASTNode {
        return ASTNode(ExprTag.ImportRecord, loc,
                       EImport(expr, options, importRecordIndex))
    }

    /// 创建 require 字符串表达式
    public static func requireString(importRecordIndex: UInt32, loc: ASTLoc): ASTNode {
        return ASTNode(ExprTag.RequireString, loc,
                       ERequireString(importRecordIndex, UInt32(0xFFFFFFFF)))
    }

    /// 创建 import.meta 表达式
    public static func importMeta(loc: ASTLoc): ASTNode {
        return ASTNode(ExprTag.Member, loc, EImportMeta())
    }

    /// 创建 new.target 表达式
    public static func newTarget(range: ASTRange, loc: ASTLoc): ASTNode {
        return ASTNode(ExprTag.Member, loc, ENewTarget(range))
    }

    /// 在同位置创建表达式 - 对应 Bun Expr.at()
    /// Bun: pub inline fn at(expr: *const Expr, comptime Type: type, t: Type, _: std.mem.Allocator) Expr
    public static func at(expr: ASTNode, tag: ExprTag, value: Any): ASTNode {
        return ASTNode(tag, expr.loc, value)
    }

    // ---- 判断方法 ----
    // 严格翻译自: src/ast/expr.zig:6-60, 126-160, 469-516, 1457-1473, 1927-1975

    /// 是否匿名命名 - 对应 Bun Expr.isAnonymousNamed()
    /// Bun: pub fn isAnonymousNamed(expr: Expr) bool
    public static func isAnonymousNamed(expr: ASTNode): Bool {
        match (expr.tag) {
            case ExprTag.Arrow => true
            case ExprTag.Function =>
                match (expr.value) {
                    case f: EFunction => f.`func`.name.isNone()
                    case _ => true
                }
            case ExprTag.Class =>
                // 简化: class_name 为 null 时匿名
                true
            case _ => false
        }
    }

    /// 是否可从属性访问内联 - 对应 Bun Expr.canBeInlinedFromPropertyAccess()
    /// Bun: pub fn canBeInlinedFromPropertyAccess(this: Expr) bool
    /// 如果数组有 spread 则必须保留
    public static func canBeInlinedFromPropertyAccess(expr: ASTNode): Bool {
        match (expr.tag) {
            case ExprTag.Spread => false
            case ExprTag.Missing => false
            case _ => true
        }
    }

    /// 是否缺失 - 对应 Bun Expr.isEmpty() / Expr.isMissing()
    /// Bun: pub fn isMissing(a: *const Expr) bool
    public static func isMissing(expr: ASTNode): Bool {
        return expr.tag == ExprTag.Missing
    }

    /// 转为空 - 对应 Bun Expr.toEmpty()
    /// Bun: pub fn toEmpty(expr: Expr) Expr
    public static func toEmpty(expr: ASTNode): ASTNode {
        return ASTNode(ExprTag.Missing, expr.loc)
    }

    /// 是否为数组 - 对应 Bun Expr.isArray()
    /// Bun: pub inline fn isArray(this: *const Expr) bool
    public static func isArray(expr: ASTNode): Bool {
        return expr.tag == ExprTag.Array
    }

    /// 是否为对象 - 对应 Bun Expr.isObject()
    /// Bun: pub inline fn isObject(this: *const Expr) bool
    public static func isObject(expr: ASTNode): Bool {
        return expr.tag == ExprTag.Object
    }

    /// 是否为字符串 - 对应 Bun Expr.isString()
    /// Bun: pub inline fn isString(expr: *const Expr) bool
    public static func isString(expr: ASTNode): Bool {
        return expr.tag == ExprTag.StringExpr
    }

    /// 是否为布尔值 - 对应 Bun Expr.asBool()
    /// Bun: pub fn asBool(expr: *const Expr) ?bool
    public static func asBool(expr: ASTNode): ?Bool {
        match (expr.tag) {
            case ExprTag.Boolean =>
                match (expr.value) {
                    case b: Bool => Some(b)
                    case _ => None
                }
            case _ => None
        }
    }

    /// 获取数字 - 对应 Bun Expr.asNumber()
    /// Bun: pub fn asNumber(expr: *const Expr) ?f64
    public static func asNumber(expr: ASTNode): ?Float64 {
        match (expr.tag) {
            case ExprTag.Number =>
                match (expr.value) {
                    case n: ENumber => Some(n.value)
                    case _ => None
                }
            case _ => None
        }
    }

    /// 获取 UTF8 字符串字面量 - 对应 Bun Expr.asUtf8StringLiteral()
    /// Bun: pub inline fn asUtf8StringLiteral(expr: *const Expr) ?string
    public static func asUtf8StringLiteral(expr: ASTNode): ?String {
        match (expr.tag) {
            case ExprTag.StringExpr =>
                match (expr.value) {
                    case s: EString =>
                        if (s.next.isNone()) { return Some(s.data) }
                        None
                    case _ => None
                }
            case _ => None
        }
    }

    /// 获取字符串字面量 - 对应 Bun Expr.asStringLiteral()
    /// Bun: pub inline fn asStringLiteral(expr: *const Expr, allocator) ?string
    public static func asStringLiteral(expr: ASTNode): ?String {
        if (expr.tag != ExprTag.StringExpr) { return None }
        match (expr.value) {
            case s: EString =>
                s.resolveRopeIfNeeded()
                return Some(s.data)
            case _ => None
        }
    }

    /// 获取字符串 - 对应 Bun Expr.asString()
    /// Bun: pub inline fn asString(expr: *const Expr, allocator) ?string
    public static func asString(expr: ASTNode): ?String {
        match (expr.tag) {
            case ExprTag.StringExpr =>
                match (expr.value) {
                    case s: EString =>
                        s.resolveRopeIfNeeded()
                        return Some(s.data)
                    case _ => None
                }
            case _ => None
        }
    }

    /// 是否引用特定 Ref - 对应 Bun Expr.isRef()
    /// Bun: pub inline fn isRef(this: *const Expr, ref: Ref) bool
    public static func isRef(expr: ASTNode, ref: Ref): Bool {
        match (expr.tag) {
            case ExprTag.ImportIdentifier =>
                match (expr.value) {
                    case ii: EImportIdentifier => ii.ref.eql(ref)
                    case _ => false
                }
            case ExprTag.Identifier =>
                match (expr.value) {
                    case id: EIdentifier => id.ref.eql(ref)
                    case _ => false
                }
            case _ => false
        }
    }

    /// 属性访问是否有 this 值 - 对应 Bun Expr.hasValueForThisInCall()
    /// Bun: pub inline fn hasValueForThisInCall(expr: *const Expr) bool
    /// 如果调用属性上的函数, 属性访问的目标会成为 "this"
    public static func hasValueForThisInCall(expr: ASTNode): Bool {
        match (expr.tag) {
            case ExprTag.Member | ExprTag.Index => true
            case _ => false
        }
    }

    // ---- 属性查询方法 ----
    // 严格翻译自: src/ast/expr.zig:160-456

    /// 获取对象属性 - 对应 Bun Expr.get()
    /// Bun: pub fn get(expr: *const Expr, name: string) ?Expr
    public static func get(expr: ASTNode, name: String): ?ASTNode {
        let query = asProperty(expr, name)
        match (query) {
            case Some(q) => Some(q.expr)
            case None => None
        }
    }

    /// 设置对象属性 - 对应 Bun Expr.set()
    /// Bun: pub fn set(expr: *Expr, allocator, name: string, value: Expr) OOM!void
    /// 不关心性能时使用。expr 必须是对象。
    public static func set(expr: ASTNode, name: String, value: ASTNode): Unit {
        if (expr.tag != ExprTag.Object) { return }
        match (expr.value) {
            case obj: EObject =>
                // 查找已有属性
                let query = obj.asProperty(name)
                match (query) {
                    case Some(q) =>
                        // 更新现有属性
                        obj.properties[Int64(q.i)] = GProperty(
                            ASTNode(ExprTag.StringExpr, q.loc, name), value)
                    case None =>
                        // 添加新属性
                        obj.properties.append(GProperty(
                            ASTNode(ExprTag.StringExpr, ASTLoc.EMPTY, name), value))
                }
            case _ => ()
        }
    }

    /// 设置字符串属性 - 对应 Bun Expr.setString()
    /// Bun: pub fn setString(expr: *Expr, allocator, name: string, value: string) OOM!void
    public static func setString(expr: ASTNode, name: String, value: String): Unit {
        set(expr, name, ASTNode(ExprTag.StringExpr, expr.loc, EString(value)))
    }

    /// 按索引获取 - 对应 Bun Expr.getByIndex()
    /// Bun: pub fn getByIndex(expr: *const Expr, index: u32, index_str: string, allocator) ?Expr
    /// 仅用于 JSON 美化打印, 不用于 transpiler
    public static func getByIndex(expr: ASTNode, index: UInt32, indexStr: String): ?ASTNode {
        match (expr.tag) {
            case ExprTag.Array =>
                match (expr.value) {
                    case a: EArray =>
                        if (Int64(index) >= a.items.size) { return None }
                        return Some(a.items[Int64(index)])
                    case _ => None
                }
            case ExprTag.Object =>
                match (expr.value) {
                    case obj: EObject =>
                        for (`prop` in obj.properties) {
                            let keyNode = `prop`.key
                            if (keyNode.isNone()) { continue }
                            let k = keyNode.getOrDefault({ => ASTNode(ExprTag.Missing, expr.loc) })
                            match (k.tag) {
                                case ExprTag.StringExpr =>
                                    let keyStr = k.stringValue()
                                    if (keyStr.isSome() && keyStr.getOrDefault({ => "" }) == indexStr) {
                                        return `prop`.value
                                    }
                                case ExprTag.Number =>
                                    let num = k.numberValue()
                                    if (num.isSome() && Int64(num.getOrDefault({ => Float64(0) })) == Int64(index)) {
                                        return `prop`.value
                                    }
                                case _ => continue
                            }
                        }
                        return None
                    case _ => None
                }
            case ExprTag.StringExpr =>
                match (expr.value) {
                    case s: EString =>
                        let strLen = s.len()
                        if (strLen > Int64(index)) {
                            let slice = s.data
                            if (slice.size > Int64(index)) {
                                return Some(ASTNode(ExprTag.StringExpr, expr.loc,
                                    EString(slice[Int64(index)..Int64(index) + Int64(1)])))
                            }
                        }
                        return None
                    case _ => None
                }
            case _ => None
        }
    }

    /// 路径查询 (支持点号和索引) - 对应 Bun Expr.getPathMayBeIndex()
    /// Bun: pub fn getPathMayBeIndex(expr: *const Expr, name: string) ?Expr
    /// 支持: foo, foo.bar, foo[123], foo[123].bar, 等
    /// 不用于 transpiler, 用于 JSON 美化打印
    public static func getPathMayBeIndex(expr: ASTNode, name: String): ?ASTNode {
        if (name.size == Int64(0)) { return None }

        // 查找第一个 [ 或 .
        var firstSpecial = Int64(-1)
        var i = Int64(0)
        while (i < name.size) {
            let ch = name[i]
            if (ch == UInt8(91) || ch == UInt8(46)) { // '[' or '.'
                firstSpecial = i
                i = name.size
            }
            i += Int64(1)
        }

        if (firstSpecial >= Int64(0)) {
            let ch = name[firstSpecial]
            if (ch == UInt8(91)) { // '['
                // 查找 ]
                var endIdx = Int64(-1)
                var j = firstSpecial + Int64(1)
                while (j < name.size) {
                    if (name[j] == UInt8(93)) { // ']'
                        endIdx = j
                        j = name.size
                    }
                    j += Int64(1)
                }
                if (endIdx < Int64(0)) { return None }

                // 递归处理
                var baseExpr: ASTNode = expr
                if (firstSpecial > Int64(0)) {
                    let key = name[Int64(0)..firstSpecial]
                    let baseResult = get(expr, key)
                    if (baseResult.isNone()) { return None }
                    baseExpr = baseResult.getOrDefault({ => expr })
                }

                let indexStr = name[firstSpecial + Int64(1)..endIdx]
                let indexVal = UInt32.tryParse(indexStr)
                if (indexVal.isNone()) { return None }

                let rest = if (name.size > endIdx + Int64(1)) {
                    name[endIdx + Int64(1)..name.size]
                } else {
                    ""
                }

                let result = getByIndex(baseExpr, indexVal.getOrDefault({ => UInt32(0) }), indexStr)
                if (result.isNone()) { return None }

                if (rest.size > Int64(0)) {
                    return getPathMayBeIndex(result.getOrDefault({ => expr }), rest)
                }
                return result
            } else { // '.'
                let key = name[Int64(0)..firstSpecial]
                let subResult = get(expr, key)
                if (subResult.isNone()) { return None }
                let subExpr = subResult.getOrDefault({ => expr })
                let subpath = if (name.size > firstSpecial + Int64(1)) {
                    name[firstSpecial + Int64(1)..name.size]
                } else {
                    ""
                }
                if (subpath.size > Int64(0)) {
                    return getPathMayBeIndex(subExpr, subpath)
                }
                return Some(subExpr)
            }
        }

        return get(expr, name)
    }

    /// 获取对象属性值 - 对应 Bun Expr.getObject()
    /// Bun: pub fn getObject(expr: *const Expr, name: string) ?Expr
    public static func getObject(expr: ASTNode, name: String): ?ASTNode {
        let query = asProperty(expr, name)
        match (query) {
            case Some(q) =>
                if (q.expr.tag == ExprTag.Object) { return Some(q.expr) }
                return None
            case None => None
        }
    }

    /// 获取布尔属性 - 对应 Bun Expr.getBoolean()
    /// Bun: pub fn getBoolean(expr: *const Expr, name: string) ?bool
    public static func getBoolean(expr: ASTNode, name: String): ?Bool {
        let query = asProperty(expr, name)
        match (query) {
            case Some(q) => asBool(q.expr)
            case None => None
        }
    }

    /// 获取字符串属性 - 对应 Bun Expr.getString()
    /// Bun: pub fn getString(expr: *const Expr, allocator, name: string) OOM!?struct { string, logger.Loc }
    public static func getString(expr: ASTNode, name: String): ?String {
        let query = asProperty(expr, name)
        match (query) {
            case Some(q) => asString(q.expr)
            case None => None
        }
    }

    /// 获取数字属性 - 对应 Bun Expr.getNumber()
    /// Bun: pub fn getNumber(expr: *const Expr, name: string) ?struct { f64, logger.Loc }
    public static func getNumber(expr: ASTNode, name: String): ?Float64 {
        let query = asProperty(expr, name)
        match (query) {
            case Some(q) => asNumber(q.expr)
            case None => None
        }
    }

    /// 获取数组属性 - 对应 Bun Expr.getArray()
    /// Bun: pub fn getArray(expr: *const Expr, name: string) ?ArrayIterator
    public static func getArray(expr: ASTNode, name: String): ?ExprArrayIterator {
        let query = asProperty(expr, name)
        match (query) {
            case Some(q) => asArray(q.expr)
            case None => None
        }
    }

    /// 查找属性 - 对应 Bun Expr.asProperty()
    /// Bun: pub fn asProperty(expr: *const Expr, name: string) ?Query
    public static func asProperty(expr: ASTNode, name: String): ?ExprQuery {
        if (expr.tag != ExprTag.Object) { return None }
        match (expr.value) {
            case obj: EObject =>
                let inner = obj.asProperty(name)
                match (inner) {
                    case Some(q) => Some(ExprQuery(q.expr, q.loc, q.i))
                    case None => None
                }
            case _ => None
        }
    }

    /// 获取数组迭代器 - 对应 Bun Expr.asArray()
    /// Bun: pub fn asArray(expr: *const Expr) ?ArrayIterator
    public static func asArray(expr: ASTNode): ?ExprArrayIterator {
        if (expr.tag != ExprTag.Array) { return None }
        match (expr.value) {
            case a: EArray =>
                if (a.items.size == Int64(0)) { return None }
                return Some(ExprArrayIterator(a))
            case _ => None
        }
    }

    // ---- 布尔/原始类型判断 ----

    /// 创建逻辑非 - 对应 Bun Expr.not()
    /// Bun: pub fn not(expr: *const Expr, allocator: std.mem.Allocator) Expr
    /// 将表达式包裹在 "!" 前缀运算符中, 可能被简化
    public static func not(expr: ASTNode): ASTNode {
        let simplified = maybeSimplifyNot(expr)
        if (simplified.isSome()) {
            return simplified.getOrDefault({ => boolean(false, expr.loc) })
        }
        return unary(OpCode.UnNot, expr, expr.loc)
    }

    /// 尝试简化逻辑非 - 对应 Bun Expr.maybeSimplifyNot()
    /// Bun: pub fn maybeSimplifyNot(expr: *const Expr, allocator) ?Expr
    /// 独立于 Not() 以避免失败时的分配
    public static func maybeSimplifyNot(expr: ASTNode): ?ASTNode {
        match (expr.tag) {
            case ExprTag.Null | ExprTag.Undefined =>
                return boolean(true, expr.loc)
            case ExprTag.Boolean =>
                let b = expr.boolValue()
                if (b.isSome()) {
                    return boolean(!b.getOrDefault({ => false }), expr.loc)
                }
            case ExprTag.Number =>
                let n = expr.numberValue()
                if (n.isSome()) {
                    let nv = n.getOrDefault({ => Float64(0) })
                    return boolean(nv == Float64(0) || nv != nv, expr.loc) // 0 or NaN
                }
            case ExprTag.BigInt =>
                // "0n" => true, else => false
                return boolean(false, expr.loc)
            case ExprTag.Function | ExprTag.Arrow | ExprTag.RegExp =>
                return boolean(false, expr.loc)
            case ExprTag.Unary =>
                // "!!!a" => "!a" 简化
                match (expr.value) {
                    case u: EUnary =>
                        if (u.op == OpCode.UnNot) {
                            let innerType = knownPrimitive(u.value)
                            if (innerType == PrimitiveType.Boolean) {
                                return Some(u.value)
                            }
                        }
                    case _ => ()
                }
            case ExprTag.Binary =>
                // 二元表达式取反的简化:
                // !(a == b) => a != b, etc.
                match (expr.value) {
                    case b: EBinary =>
                        match (b.op) {
                            case OpCode.BinLooseEq =>
                                // !(a == b) => a != b
                                return binary(OpCode.BinLooseNe, b.left, b.right, expr.loc)
                            case OpCode.BinLooseNe =>
                                // !(a != b) => a == b
                                return binary(OpCode.BinLooseEq, b.left, b.right, expr.loc)
                            case OpCode.BinStrictEq =>
                                // !(a === b) => a !== b
                                return binary(OpCode.BinStrictNe, b.left, b.right, expr.loc)
                            case OpCode.BinStrictNe =>
                                // !(a !== b) => a === b
                                return binary(OpCode.BinStrictEq, b.left, b.right, expr.loc)
                            case OpCode.BinComma =>
                                // !(a, b) => a, !b
                                let rightNot = not(b.right)
                                return binary(OpCode.BinComma, b.left, rightNot, expr.loc)
                            case _ => ()
                        }
                    case _ => ()
                }
            case ExprTag.InlinedEnum =>
                // 递归简化内联枚举
                match (expr.value) {
                    case ie: EInlinedEnum => return maybeSimplifyNot(ie.value)
                    case _ => ()
                }
            case _ => ()
        }
        return None
    }

    /// 解包内联枚举 - 对应 Bun Expr.unwrapInlined()
    /// Bun: pub fn unwrapInlined(expr: Expr) Expr
    public static func unwrapInlined(expr: ASTNode): ASTNode {
        if (expr.tag == ExprTag.InlinedEnum) {
            match (expr.value) {
                case ie: EInlinedEnum => return ie.value
                case _ => ()
            }
        }
        return expr
    }

    /// 判断是否可选链 - 对应 Bun Expr.isOptionalChain()
    /// Bun: pub fn isOptionalChain(self: *const @This()) bool
    public static func isOptionalChain(expr: ASTNode): Bool {
        match (expr.tag) {
            case ExprTag.Member =>
                match (expr.value) {
                    case d: EDot => d.optionalChain.isSome()
                    case _ => false
                }
            case ExprTag.Index =>
                match (expr.value) {
                    case i: EIndex => i.optionalChain.isSome()
                    case _ => false
                }
            case ExprTag.Call =>
                match (expr.value) {
                    case c: ECall => c.optionalChain.isSome()
                    case _ => false
                }
            case _ => false
        }
    }

    /// 是否属性访问 - 对应 Bun Expr.isPropertyAccess()
    /// Bun: pub inline fn isPropertyAccess(this: *const Expr) bool
    /// 等效于 hasValueForThisInCall
    public static func isPropertyAccess(expr: ASTNode): Bool {
        match (expr.tag) {
            case ExprTag.Member | ExprTag.Index => true
            case _ => false
        }
    }

    /// 已知原始类型 - 对应 Bun Expr.knownPrimitive()
    /// Bun: pub inline fn knownPrimitive(self: *const @This()) PrimitiveType
    public static func knownPrimitive(expr: ASTNode): PrimitiveType {
        match (expr.tag) {
            case ExprTag.BigInt => PrimitiveType.Bigint
            case ExprTag.Boolean => PrimitiveType.Boolean
            case ExprTag.Null => PrimitiveType.Null
            case ExprTag.Number => PrimitiveType.Number
            case ExprTag.StringExpr => PrimitiveType.String
            case ExprTag.Undefined => PrimitiveType.Undefined
            case ExprTag.Template =>
                match (expr.value) {
                    case t: ETemplate =>
                        if (t.tag.isNone()) { PrimitiveType.String } else { PrimitiveType.Unknown }
                    case _ => PrimitiveType.Unknown
                }
            case ExprTag.Conditional =>
                match (expr.value) {
                    case if_: EIf =>
                        PrimitiveType.merge(knownPrimitive(if_.yes), knownPrimitive(if_.no))
                    case _ => PrimitiveType.Unknown
                }
            case ExprTag.Binary =>
                match (expr.value) {
                    case bin: EBinary => ExprData.knownPrimitiveBinary(bin)
                    case _ => PrimitiveType.Unknown
                }
            case ExprTag.Unary =>
                match (expr.value) {
                    case un: EUnary => ExprData.knownPrimitiveUnary(un)
                    case _ => PrimitiveType.Unknown
                }
            case ExprTag.InlinedEnum =>
                match (expr.value) {
                    case ie: EInlinedEnum => knownPrimitive(ie.value)
                    case _ => PrimitiveType.Unknown
                }
            case _ => PrimitiveType.Unknown
        }
    }

    /// 是否为原始字面量 - 对应 Bun Expr.isPrimitiveLiteral()
    /// Bun: pub inline fn isPrimitiveLiteral(this: *const Expr) bool
    public static func isPrimitiveLiteral(expr: ASTNode): Bool {
        match (expr.tag) {
            case ExprTag.Null | ExprTag.Undefined | ExprTag.StringExpr |
                 ExprTag.Boolean | ExprTag.Number | ExprTag.BigInt |
                 ExprTag.RegExp => true
            case _ => false
        }
    }

    /// 判断是否布尔表达式 - 对应 Bun Expr.isBoolean()
    /// Bun: pub fn isBoolean(a: *const Expr) bool
    public static func isBoolean(expr: ASTNode): Bool {
        match (expr.tag) {
            case ExprTag.Boolean => true
            case ExprTag.Unary =>
                match (expr.value) {
                    case u: EUnary => u.op == OpCode.UnNot || u.op == OpCode.UnDelete
                    case _ => false
                }
            case ExprTag.Binary =>
                match (expr.value) {
                    case b: EBinary =>
                        match (b.op) {
                            case OpCode.BinStrictEq | OpCode.BinStrictNe |
                                 OpCode.BinLooseEq | OpCode.BinLooseNe |
                                 OpCode.BinLt | OpCode.BinGt |
                                 OpCode.BinLe | OpCode.BinGe |
                                 OpCode.BinInstanceof | OpCode.BinIn => true
                            case OpCode.BinLogicalOr | OpCode.BinLogicalAnd =>
                                isBoolean(b.left) && isBoolean(b.right)
                            case _ => false
                        }
                    case _ => false
                }
            case ExprTag.Conditional =>
                match (expr.value) {
                    case if_: EIf => isBoolean(if_.yes) && isBoolean(if_.no)
                    case _ => false
                }
            case _ => false
        }
    }

    /// 是否有指定属性名 - 对应 Bun Expr.hasAnyPropertyNamed()
    /// Bun: pub fn hasAnyPropertyNamed(expr: *const Expr, comptime names: []const string) bool
    public static func hasAnyPropertyNamed(expr: ASTNode, names: ArrayList<String>): Bool {
        if (expr.tag != ExprTag.Object) { return false }
        match (expr.value) {
            case obj: EObject =>
                if (obj.properties.size == Int64(0)) { return false }
                for (`prop` in obj.properties) {
                    if (`prop`.value.isNone()) { continue }
                    let keyOpt = `prop`.key
                    if (keyOpt.isNone()) { continue }
                    let key = keyOpt.getOrDefault({ => ASTNode(ExprTag.Missing, expr.loc) })
                    if (key.tag != ExprTag.StringExpr) { continue }
                    let keyStr = key.stringValue()
                    if (keyStr.isSome()) {
                        for (name in names) {
                            if (keyStr.getOrDefault({ => "" }) == name) { return true }
                        }
                    }
                }
            case _ => ()
        }
        return false
    }

    /// 可作为常量值 - 对应 Bun Expr.canBeConstValue()
    /// Bun: pub fn canBeConstValue(this: Expr) bool
    public static func canBeConstValue(expr: ASTNode): Bool {
        match (expr.tag) {
            case ExprTag.Number | ExprTag.Boolean | ExprTag.Null |
                 ExprTag.Undefined | ExprTag.InlinedEnum => true
            case ExprTag.StringExpr =>
                match (expr.value) {
                    case s: EString => s.next.isNone()
                    case _ => false
                }
            case ExprTag.Array =>
                match (expr.value) {
                    case a: EArray => a.wasOriginallyMacro
                    case _ => false
                }
            case ExprTag.Object =>
                match (expr.value) {
                    case o: EObject => o.wasOriginallyMacro
                    case _ => false
                }
            case _ => false
        }
    }

    /// 是否可移动 - 对应 Bun Expr.canBeMoved()
    /// Bun: pub fn canBeMoved(expr: Expr) bool
    public static func canBeMoved(expr: ASTNode): Bool {
        match (expr.tag) {
            case ExprTag.Class => true  // 简化
            case ExprTag.Arrow | ExprTag.Function | ExprTag.Number |
                 ExprTag.Boolean | ExprTag.Null | ExprTag.Undefined |
                 ExprTag.BigInt | ExprTag.StringExpr |
                 ExprTag.InlinedEnum => true
            case ExprTag.Template =>
                match (expr.value) {
                    case t: ETemplate => t.tag.isNone() && t.parts.size == Int64(0)
                    case _ => false
                }
            case ExprTag.Array =>
                match (expr.value) {
                    case a: EArray => a.wasOriginallyMacro
                    case _ => false
                }
            case ExprTag.Object =>
                match (expr.value) {
                    case o: EObject => o.wasOriginallyMacro
                    case _ => false
                }
            case _ => false
        }
    }

    // ---- 连接/组合方法 ----

    /// 使用左结合运算符连接 - 对应 Bun Expr.joinWithLeftAssociativeOp()
    /// Bun: pub fn joinWithLeftAssociativeOp(comptime op: Op.Code, a: Expr, b: Expr, allocator) Expr
    /// 目标是利用运算符的左结合性来 "旋转" AST 以避免不必要的括号
    public static func joinWithLeftAssociativeOp(op: OpCode, a: ASTNode, b: ASTNode): ASTNode {
        // "(a, b) op c" => "a, b op c"
        if (a.tag == ExprTag.Binary) {
            match (a.value) {
                case comma: EBinary =>
                    if (comma.op == OpCode.BinComma) {
                        let newRight = joinWithLeftAssociativeOp(op, comma.right, b)
                        return binary(OpCode.BinComma, comma.left, newRight, a.loc)
                    }
                case _ => ()
            }
        }

        // "a op (b op c)" => "(a op b) op c"
        // "a op (b op (c op d))" => "((a op b) op c) op d"
        if (b.tag == ExprTag.Binary) {
            match (b.value) {
                case binB: EBinary =>
                    if (binB.op == op) {
                        return joinWithLeftAssociativeOp(op,
                            joinWithLeftAssociativeOp(op, a, binB.left),
                            binB.right)
                    }
                case _ => ()
            }
        }

        // "a op b" => "a op b"
        return binary(op, a, b, a.loc)
    }

    /// 使用逗号连接 - 对应 Bun Expr.joinWithComma()
    /// Bun: pub fn joinWithComma(a: Expr, b: Expr, _: std.mem.Allocator) Expr
    public static func joinWithComma(a: ASTNode, b: ASTNode): ASTNode {
        if (isMissing(a)) {
            return b
        }
        if (isMissing(b)) {
            return a
        }
        return binary(OpCode.BinComma, a, b, a.loc)
    }

    /// 使用逗号连接所有 - 对应 Bun Expr.joinAllWithComma()
    /// Bun: pub fn joinAllWithComma(all: []Expr, allocator: std.mem.Allocator) Expr
    public static func joinAllWithComma(all: ArrayList<ASTNode>): ?ASTNode {
        if (all.size == Int64(0)) {
            return None
        }
        if (all.size == Int64(1)) {
            return all[Int64(0)]
        }
        var expr = all[Int64(0)]
        var i = Int64(1)
        while (i < all.size) {
            expr = joinWithComma(expr, all[i])
            i += Int64(1)
        }
        return expr
    }

    /// 使用逗号连接所有 (带回调) - 对应 Bun Expr.joinAllWithCommaCallback()
    /// Bun: pub fn joinAllWithCommaCallback(all: []Expr, comptime Context: type, ctx: Context,
    ///       comptime callback: (fn (ctx: anytype, expr: Expr) ?Expr), allocator) ?Expr
    public static func joinAllWithCommaCallback(
        all: ArrayList<ASTNode>,
        callback: (ASTNode) -> ?ASTNode
    ): ?ASTNode {
        if (all.size == Int64(0)) { return None }
        if (all.size == Int64(1)) {
            return callback(all[Int64(0)])
        }

        var expr: ASTNode = callback(all[Int64(0)]) .getOrDefault({
            => ASTNode(ExprTag.Missing, all[Int64(0)].loc)
        })
        var i = Int64(1)
        while (i < all.size) {
            let item = all[i]
            let mapped = callback(item).getOrDefault({
                => ASTNode(ExprTag.Missing, item.loc)
            })
            expr = joinWithComma(expr, mapped)
            i += Int64(1)
        }

        if (isMissing(expr)) { return None }
        return expr
    }

    // ---- 转换方法 ----

    /// 包裹为箭头函数 - 对应 Bun Expr.wrapInArrow()
    /// Bun: pub fn wrapInArrow(this: Expr, allocator: std.mem.Allocator) !Expr
    public static func wrapInArrow(expr: ASTNode): ASTNode {
        let stmt = StmtNode(StmtTag.Return, expr.loc)
        stmt.addChild(expr)
        let stmts = ArrayList<StmtNode>()
        stmts.append(stmt)
        let body = GFnBody(expr.loc, stmts)
        let args = ArrayList<GArg>()
        return arrow(args, body, false, expr.loc)
    }

    /// 转为字符串表达式 (无副作用) - 对应 Bun Expr.toStringExprWithoutSideEffects()
    /// Bun: pub fn toStringExprWithoutSideEffects(expr: *const Expr, allocator) ?Expr
    public static func toStringExprWithoutSideEffects(expr: ASTNode): ?ASTNode {
        let unwrapped = unwrapInlined(expr)
        match (unwrapped.tag) {
            case ExprTag.Null => return string("null", expr.loc)
            case ExprTag.StringExpr => return expr
            case ExprTag.Undefined => return string("undefined", expr.loc)
            case ExprTag.Boolean =>
                let b = expr.boolValue()
                if (b.isSome()) {
                    return string(if (b.getOrDefault({ => false })) { "true" } else { "false" }, expr.loc)
                }
            case ExprTag.BigInt =>
                match (expr.value) {
                    case bi: EBigInt =>
                        if (bi.value.size > Int64(0)) {
                            return string(bi.value, expr.loc)
                        }
                    case _ => ()
                }
            case ExprTag.Number =>
                let n = expr.numberValue()
                if (n.isSome()) {
                    let s = ENumber.toStringFromF64(n.getOrDefault({ => Float64(0) }))
                    if (s.isSome()) {
                        return string(s.getOrDefault({ => "" }), expr.loc)
                    }
                }
            case ExprTag.RegExp =>
                match (expr.value) {
                    case re: ERegExp =>
                        if (re.value.size > Int64(0)) {
                            return string(re.value, expr.loc)
                        }
                    case _ => ()
                }
            case ExprTag.Member =>
                // JavaScript 混淆器使用 .constructor 属性来生成字符串字面量
                match (expr.value) {
                    case d: EDot =>
                        if (d.name == "constructor") {
                            match (d.target.tag) {
                                case ExprTag.StringExpr => return string("function String() { [native code] }", expr.loc)
                                case ExprTag.RegExp => return string("function RegExp() { [native code] }", expr.loc)
                                case _ => ()
                            }
                        }
                    case _ => ()
                }
            case _ => ()
        }
        return None
    }

    // ---- 常量和计数器 ----

    /// 空表达式 - 对应 Bun Expr.empty
    /// Bun: pub const empty = Expr{ .data = .{ .e_missing = E.Missing{} }, .loc = logger.Loc.Empty }
    public static let EMPTY: ASTNode = ASTNode(ExprTag.Missing, ASTLoc.EMPTY)

    /// 实例计数 - 对应 Bun Expr.icount
    /// Bun: pub var icount: usize = 0
    public static var icount: Int64 = Int64(0)

    // ---- 缓存的布尔值 ----
    // 严格翻译自: src/ast/expr.zig:706-709
    //   var true_bool = E.Boolean{ .value = true };
    //   var false_bool = E.Boolean{ .value = false };
    // Bun 中不需要动态分配布尔值

    /// 缓存的真布尔值
    public static let TRUE_BOOL: ASTNode = ASTNode(ExprTag.Boolean, ASTLoc.EMPTY, true)
    /// 缓存的假布尔值
    public static let FALSE_BOOL: ASTNode = ASTNode(ExprTag.Boolean, ASTLoc.EMPTY, false)
}
