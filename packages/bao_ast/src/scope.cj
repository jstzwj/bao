// bao_ast - 作用域管理
// 严格翻译自: src/ast/scope.zig (220L)
//   Scope - 作用域结构 (id, kind, parent, children, members, ...)
//   Scope.Kind - 作用域类型 (block, with, label, entry, ...)
//   Scope.Member - 作用域成员 (ref + loc)
//   Scope.MemberHashMap - 成员哈希映射
//   Scope.recursiveSetStrictMode - 递归设置严格模式
//   Scope.canMergeSymbols - 判断符号是否可合并
package bao_ast

import bao_core.*
import bao_collections.*

// ============================================================================
// ScopeKind - 作用域类型
// 严格翻译自: src/ast/scope.zig:176-193
//   pub const Kind = enum(u8) {
//       block, with, label, class_name, class_body, catch_binding,
//       entry, function_args, function_body, class_static_init
//   }
// 注意: 以下作用域类型阻止提升变量扩展到父作用域:
//   entry, function_args, function_body, class_static_init
// ============================================================================

/// 作用域类型 - 对应 Bun Scope.Kind
/// Bun: pub const Kind = enum(u8) { block, with, label, ... }
public enum ScopeKind {
    | Block            // block - 块级作用域 {}
    | With             // with - with 语句作用域
    | Label            // label - 标签作用域 (break/continue)
    | ClassName        // class_name - 类名绑定
    | ClassBody        // class_body - 类体
    | CatchBinding     // catch_binding - catch 绑定

    // 以下作用域类型阻止提升变量扩展到父作用域
    | Entry            // entry - 模块入口/TypeScript 枚举/TypeScript 命名空间
    | FunctionArgs     // function_args - 函数参数
    | FunctionBody     // function_body - 函数体
    | ClassStaticInit  // class_static_init - class static {}

    /// 序数值 - 对应 Bun enum(u8) 的整数值
    /// 用于 kindStopsHoisting() 判断
    public func ordinal(): Int64 {
        match (this) {
            case Block => 0
            case With => 1
            case Label => 2
            case ClassName => 3
            case ClassBody => 4
            case CatchBinding => 5
            case Entry => 6
            case FunctionArgs => 7
            case FunctionBody => 8
            case ClassStaticInit => 9
        }
    }

    /// 是否为函数级作用域
    public func isFunctionScope(): Bool {
        match (this) {
            case FunctionBody | FunctionArgs | Entry => true
            case _ => false
        }
    }

    /// 是否为块级作用域
    public func isBlockScope(): Bool {
        match (this) {
            case Block | CatchBinding => true
            case _ => false
        }
    }

    /// 是否为类作用域
    public func isClassScope(): Bool {
        match (this) {
            case ClassName | ClassBody | ClassStaticInit => true
            case _ => false
        }
    }

    /// 是否阻止提升 - 对应 Bun Scope.kindStopsHoisting()
    /// Bun: pub inline fn kindStopsHoisting(s: *const Scope) bool
    /// Entry 及之后的作用域类型阻止提升
    public func stopsHoisting(): Bool {
        return ordinal() >= ScopeKind.Entry.ordinal()
    }

    /// 获取类型名称 - 对应 Bun @tagName(self)
    public func name(): String {
        match (this) {
            case Block => "block"
            case With => "with"
            case Label => "label"
            case ClassName => "class_name"
            case ClassBody => "class_body"
            case CatchBinding => "catch_binding"
            case Entry => "entry"
            case FunctionArgs => "function_args"
            case FunctionBody => "function_body"
            case ClassStaticInit => "class_static_init"
        }
    }
}

// ============================================================================
// ScopeMember - 作用域成员
// 严格翻译自: src/ast/scope.zig:72-79
//   pub const Member = struct { ref: Ref, loc: logger.Loc }
// 注意: 不要使用 packed struct (Bun 源码中明确注释，packed 会导致未定义内存崩溃)
// ============================================================================

/// 作用域成员 - 对应 Bun Scope.Member
/// Bun: pub const Member = struct { ref: Ref, loc: logger.Loc }
/// 不要使用 packed struct.getOrThrow()
public class ScopeMember {
    /// 符号引用 - 对应 Bun Member.ref: Ref
    public var ref: Ref
    /// 声明位置 - 对应 Bun Member.loc: logger.Loc
    public var loc: ASTLoc

    public init(ref: Ref, loc: ASTLoc) {
        this.ref = ref
        this.loc = loc
    }

    public init() {
        this.ref = Ref.NONE
        this.loc = ASTLoc.EMPTY
    }

    /// 相等比较 - 对应 Bun Member.eql()
    /// Bun: pub fn eql(a: Member, b: Member) bool
    public func eql(other: ScopeMember): Bool {
        return ref.eql(other.ref) && loc.start == other.loc.start
    }
}

// ============================================================================
// TSNamespaceScope - TypeScript 命名空间作用域
// 严格翻译自: src/ast/ts.zig:1-101
//   pub const TSNamespaceScope = struct {
//       arg_ref: Ref,
//       exported_members: *TSNamespaceMemberMap,
//       property_accesses: bun.StringArrayHashMapUnmanaged(Ref) = .{},
//       is_enum_scope: bool,
//   }
// ============================================================================

/// TypeScript 命名空间成员数据 - 对应 Bun TSNamespaceMember.Data
/// Bun: pub const Data = union(enum) { property, namespace, enum_number, enum_string, enum_property }
public enum TSNamespaceMemberDataKind {
    | Property     // "namespace ns { export let it }"
    | Namespace    // "namespace ns { export namespace it {} }"
    | EnumNumber   // "enum ns { it }"
    | EnumString   // "enum ns { it = 'it' }"
    | EnumProperty // "enum ns { it = something() }"

    /// 是否为枚举类型 - 对应 Bun Data.isEnum()
    public func isEnum(): Bool {
        match (this) {
            case EnumNumber | EnumString | EnumProperty => true
            case _ => false
        }
    }
}

/// TypeScript 命名空间成员数据
public class TSNamespaceMemberData {
    /// 数据类型
    public var kind: TSNamespaceMemberDataKind
    /// 枚举数值 (如果为 EnumNumber)
    public var enumNumber: Float64
    /// 枚举字符串 (如果为 EnumString)
    public var enumString: ?String
    /// 嵌套命名空间映射 (如果为 Namespace)
    public var namespaceMembers: ?TSNamespaceMemberMap

    public init(kind: TSNamespaceMemberDataKind) {
        this.kind = kind
        this.enumNumber = 0.0
        this.enumString = None
        this.namespaceMembers = None
    }

    public static func property(): TSNamespaceMemberData {
        return TSNamespaceMemberData(TSNamespaceMemberDataKind.Property)
    }

    public static func enumNumber(value: Float64): TSNamespaceMemberData {
        let d = TSNamespaceMemberData(TSNamespaceMemberDataKind.EnumNumber)
        d.enumNumber = value
        return d
    }

    public static func enumString(value: String): TSNamespaceMemberData {
        let d = TSNamespaceMemberData(TSNamespaceMemberDataKind.EnumString)
        d.enumString = Some(value)
        return d
    }

    public static func enumProperty(): TSNamespaceMemberData {
        return TSNamespaceMemberData(TSNamespaceMemberDataKind.EnumProperty)
    }
}

/// TypeScript 命名空间成员 - 对应 Bun TSNamespaceMember
/// Bun: pub const TSNamespaceMember = struct { loc: logger.Loc, data: Data }
public class TSNamespaceMember {
    /// 声明位置
    public var loc: ASTLoc
    /// 成员数据
    public var data: TSNamespaceMemberData

    public init(loc: ASTLoc, data: TSNamespaceMemberData) {
        this.loc = loc
        this.data = data
    }
}

/// TypeScript 命名空间成员映射 - 对应 Bun TSNamespaceMemberMap
/// Bun: pub const TSNamespaceMemberMap = bun.StringArrayHashMapUnmanaged(TSNamespaceMember)
public class TSNamespaceMemberMap {
    /// 成员映射 (名称 -> 成员)
    public var members: HashMap<String, TSNamespaceMember>

    public init() {
        members = HashMap<String, TSNamespaceMember>()
    }

    /// 添加成员
    public func put(name: String, member: TSNamespaceMember): Unit {
        members.put(name, member)
    }

    /// 获取成员
    public func get(name: String): ?TSNamespaceMember {
        return members.get(name)
    }

    /// 是否包含成员
    public func contains(name: String): Bool {
        return members.contains(name)
    }
}

/// TypeScript 命名空间作用域 - 对应 Bun TSNamespaceScope
/// Bun: pub const TSNamespaceScope = struct { arg_ref, exported_members, property_accesses, is_enum_scope }
///
/// 用于 TypeScript "enum" 和 "namespace" 块。每个块可能被实例化多次。
/// 导出成员被合并到单个命名空间，而非导出代码仍限于块内。
///
/// 这是一种不同于 JavaScript 分层基于作用域的标识符查找的标识符查找形式。
/// 查找现在需要搜索兄弟作用域以及父作用域。
/// 通过在所有匹配的兄弟作用域之间共享导出成员映射来实现。
public class TSNamespaceScope {
    /// 参数引用 - 对应 Bun TSNamespaceScope.arg_ref: Ref
    /// 特定于此命名空间块。是命名空间块编译成的立即调用函数表达式的参数符号
    ///
    /// var ns;
    /// (function (ns2) {   <-- ns2 就是这个变量
    ///   ns2.x = 123;
    /// })(ns || (ns = {}));
    public var argRef: Ref

    /// 导出成员 - 对应 Bun TSNamespaceScope.exported_members: *TSNamespaceMemberMap
    /// 所有兄弟命名空间块之间共享
    public var exportedMembers: TSNamespaceMemberMap

    /// 属性访问 - 对应 Bun TSNamespaceScope.property_accesses
    /// 惰性生成的标识符映射，表示对此命名空间属性的属性访问
    public var propertyAccesses: HashMap<String, Ref>

    /// 是否为枚举作用域 - 对应 Bun TSNamespaceScope.is_enum_scope: bool
    /// 枚举和命名空间行为分离: 隐式引用仅在 枚举-枚举 和 命名空间-命名空间 之间工作
    public var isEnumScope: Bool

    public init(argRef: Ref, exportedMembers: TSNamespaceMemberMap, isEnumScope: Bool) {
        this.argRef = argRef
        this.exportedMembers = exportedMembers
        this.propertyAccesses = HashMap<String, Ref>()
        this.isEnumScope = isEnumScope
    }

    public init(isEnumScope: Bool) {
        this.argRef = Ref.NONE
        this.exportedMembers = TSNamespaceMemberMap()
        this.propertyAccesses = HashMap<String, Ref>()
        this.isEnumScope = isEnumScope
    }
}

// ============================================================================
// Scope - 作用域结构体
// 严格翻译自: src/ast/scope.zig:1-67
//   pub const Scope = struct {
//       id: usize = 0,
//       kind: Kind = Kind.block,
//       parent: ?*Scope = null,
//       children: BabyList(*Scope) = .{},
//       members: MemberHashMap = .{},
//       generated: BabyList(Ref) = .{},
//       label_ref: ?Ref = null,
//       label_stmt_is_loop: bool = false,
//       contains_direct_eval: bool = false,
//       forbid_arguments: bool = false,
//       strict_mode: StrictModeKind = StrictModeKind.sloppy_mode,
//       is_after_const_local_prefix: bool = false,
//       ts_namespace: ?*TSNamespaceScope = null,
//   }
// ============================================================================

/// 作用域 - 对应 Bun Scope
/// Bun: pub const Scope = struct { id, kind, parent, children, members, ... }
/// 表示 JavaScript 中的作用域，包含变量声明、嵌套作用域等
public class Scope {
    /// 作用域 ID - 对应 Bun Scope.id: usize
    public var id: Int64

    /// 作用域类型 - 对应 Bun Scope.kind: Kind
    public var kind: ScopeKind

    /// 父作用域 - 对应 Bun Scope.parent: ?*Scope
    public var parent: ?Scope

    /// 子作用域 - 对应 Bun Scope.children: BabyList(*Scope)
    public var children: ArrayList<Scope>

    /// 成员变量声明 - 对应 Bun Scope.members: MemberHashMap
    /// 名称到成员 (Ref + Loc) 的映射
    public var members: HashMap<String, ScopeMember>

    /// 生成的引用列表 - 对应 Bun Scope.generated: BabyList(Ref)
    public var generated: ArrayList<Ref>

    /// 标签引用 - 对应 Bun Scope.label_ref: ?Ref
    /// 用于存储 ScopeLabel 作用域的标签符号引用
    public var labelRef: ?Ref

    /// 标签语句是否为循环 - 对应 Bun Scope.label_stmt_is_loop: bool
    public var labelStmtIsLoop: Bool

    /// 是否包含直接 eval - 对应 Bun Scope.contains_direct_eval: bool
    /// 如果作用域包含直接 eval() 表达式，则该作用域内的所有符号都不能重命名
    public var containsDirectEval: Bool

    /// 是否禁止 arguments - 对应 Bun Scope.forbid_arguments: bool
    /// 用于帮助禁止 class 体作用域中的 "arguments"
    public var forbidArguments: Bool

    /// 严格模式 - 对应 Bun Scope.strict_mode: StrictModeKind
    public var strictMode: StrictModeKind

    /// 是否在 const 本地前缀之后 - 对应 Bun Scope.is_after_const_local_prefix: bool
    public var isAfterConstLocalPrefix: Bool

    /// TypeScript 命名空间作用域 - 对应 Bun Scope.ts_namespace: ?*TSNamespaceScope
    /// 非 null 时表示这是一个 TypeScript "namespace" 或 "enum"
    public var tsNamespace: ?TSNamespaceScope

    public init() {
        this.id = 0
        this.kind = ScopeKind.Block
        this.parent = None
        this.children = ArrayList<Scope>()
        this.members = HashMap<String, ScopeMember>()
        this.generated = ArrayList<Ref>()
        this.labelRef = None
        this.labelStmtIsLoop = false
        this.containsDirectEval = false
        this.forbidArguments = false
        this.strictMode = StrictModeKind.SloppyMode
        this.isAfterConstLocalPrefix = false
        this.tsNamespace = None
    }

    public init(id: Int64, kind: ScopeKind) {
        this.id = id
        this.kind = kind
        this.parent = None
        this.children = ArrayList<Scope>()
        this.members = HashMap<String, ScopeMember>()
        this.generated = ArrayList<Ref>()
        this.labelRef = None
        this.labelStmtIsLoop = false
        this.containsDirectEval = false
        this.forbidArguments = false
        this.strictMode = StrictModeKind.SloppyMode
        this.isAfterConstLocalPrefix = false
        this.tsNamespace = None
    }

    /// 重置 - 对应 Bun Scope.reset()
    /// Bun: pub fn reset(this: *Scope) void
    public func reset(): Unit {
        children.clear()
        generated.clear()
        members.clear()
        parent = None
        id = 0
        labelRef = None
        labelStmtIsLoop = false
        containsDirectEval = false
        strictMode = StrictModeKind.SloppyMode
        kind = ScopeKind.Block
    }

    /// 获取成员 - 对应 Bun Scope.getMemberWithHash()
    /// Bun: pub fn getMemberWithHash(this: *const Scope, name: []const u8, hash_value: u64) ?Member
    public func getMember(name: String): ?ScopeMember {
        return members.get(name)
    }

    /// 添加或获取成员 - 对应 Bun Scope.getOrPutMemberWithHash()
    /// Bun: pub fn getOrPutMemberWithHash(this, allocator, name, hash_value) !GetOrPutResult
    public func getOrPutMember(name: String, member: ScopeMember): Unit {
        members.put(name, member)
    }

    /// 添加子作用域
    public func addChild(child: Scope): Unit {
        child.parent = Some(this)
        children.append(child)
    }

    /// 沿作用域链查找名称 - 对应 Bun 解析器的 resolveBinding 逻辑
    public func resolve(name: String): ?ScopeMember {
        let member = members.get(name)
        match (member) {
            case Some(m) => return Some(m)
            case None => match (parent) {
                case Some(p) => return p.resolve(name)
                case None => return None
            }
        }
    }

    /// 递归设置严格模式 - 对应 Bun Scope.recursiveSetStrictMode()
    /// Bun: pub fn recursiveSetStrictMode(s: *Scope, kind: StrictModeKind) void
    /// 只在当前为 sloppy_mode 时设置，递归到子作用域
    public func recursiveSetStrictMode(strictKind: StrictModeKind): Unit {
        if (strictMode == StrictModeKind.SloppyMode) {
            strictMode = strictKind
            for (child in children) {
                child.recursiveSetStrictMode(strictKind)
            }
        }
    }

    /// 是否在严格模式下
    public func isStrictMode(): Bool {
        if (strictMode.isStrict()) {
            return true
        }
        match (parent) {
            case Some(p) => p.isStrictMode()
            case None => false
        }
    }

    /// 作用域深度
    public func depth(): Int64 {
        var d = Int64(0)
        var current = parent
        while (true) {
            match (current) {
                case Some(p) =>
                    d += 1
                    current = p.parent
                case None => break
            }
        }
        return d
    }

    /// 是否阻止提升 - 对应 Bun Scope.kindStopsHoisting()
    /// Bun: pub inline fn kindStopsHoisting(s: *const Scope) bool
    public func stopsHoisting(): Bool {
        return kind.stopsHoisting()
    }
}

// ============================================================================
// canMergeSymbols - 判断符号是否可合并
// 严格翻译自: src/ast/scope.zig:90-174
//   pub fn canMergeSymbols(
//       scope: *Scope,
//       existing: Symbol.Kind,
//       new: Symbol.Kind,
//       comptime is_typescript_enabled: bool,
//   ) SymbolMergeResult
// ============================================================================

/// 判断符号是否可合并 - 对应 Bun Scope.canMergeSymbols()
/// Bun: pub fn canMergeSymbols(scope, existing, new, is_typescript_enabled) SymbolMergeResult
///
/// 处理各种 JavaScript/TypeScript 中符号声明的合并规则:
/// - var 重复声明
/// - 函数重复声明
/// - TypeScript 枚举/命名空间合并
/// - 私有字段 get/set 配对
/// - catch 变量特殊处理
/// - arguments 特殊处理
public func canMergeSymbols(
    scope: Scope,
    existing: SymbolKind,
    newKind: SymbolKind,
    isTypescriptEnabled: Bool
): SymbolMergeResult {
    // 未绑定的现有符号总是被替换
    if (existing == SymbolKind.Unbound) {
        return SymbolMergeResult.ReplaceWithNew
    }

    if (isTypescriptEnabled) {
        // TypeScript: 导入符号允许与模块内符号静默冲突
        // import {Foo} from 'bar'; class Foo {}
        if (existing == SymbolKind.Import) {
            return SymbolMergeResult.ReplaceWithNew
        }

        // "enum Foo {} enum Foo {}"
        // "namespace Foo { ... } enum Foo {}"
        if (newKind == SymbolKind.TsEnum &&
            (existing == SymbolKind.TsEnum || existing == SymbolKind.TsNamespace)) {
            return SymbolMergeResult.ReplaceWithNew
        }

        // "namespace Foo { ... } namespace Foo { ... }"
        // "function Foo() {} namespace Foo { ... }"
        // "enum Foo {} namespace Foo { ... }"
        if (newKind == SymbolKind.TsNamespace) {
            match (existing) {
                case SymbolKind.TsNamespace | SymbolKind.TsEnum |
                     SymbolKind.HoistedFunction |
                     SymbolKind.GeneratorOrAsyncFunction | SymbolKind.Class =>
                    return SymbolMergeResult.KeepExisting
                case _ => ()
            }
        }
    }

    // "var foo; var foo;"
    // "var foo; function foo() {}"
    // "function foo() {} var foo;"
    // "function *foo() {} function *foo() {}" 但不是 "{ function *foo() {} function *foo() {} }"
    if (newKind.isHoistedOrFunction() && existing.isHoistedOrFunction() &&
        (scope.kind == ScopeKind.Entry ||
         scope.kind == ScopeKind.FunctionBody ||
         scope.kind == ScopeKind.FunctionArgs ||
         (newKind == existing && existing.isHoisted()))) {
        return SymbolMergeResult.ReplaceWithNew
    }

    // "get #foo() {} set #foo() {}"
    // "set #foo() {} get #foo() {}"
    if ((existing == SymbolKind.PrivateGet && newKind == SymbolKind.PrivateSet) ||
        (existing == SymbolKind.PrivateSet && newKind == SymbolKind.PrivateGet)) {
        return SymbolMergeResult.BecomePrivateGetSetPair
    }
    if ((existing == SymbolKind.PrivateStaticGet && newKind == SymbolKind.PrivateStaticSet) ||
        (existing == SymbolKind.PrivateStaticSet && newKind == SymbolKind.PrivateStaticGet)) {
        return SymbolMergeResult.BecomePrivateStaticGetSetPair
    }

    // "try {} catch (e) { var e }"
    if (existing == SymbolKind.CatchIdentifier && newKind == SymbolKind.Hoisted) {
        return SymbolMergeResult.ReplaceWithNew
    }

    // "function() { var arguments }"
    if (existing == SymbolKind.Arguments && newKind == SymbolKind.Hoisted) {
        return SymbolMergeResult.KeepExisting
    }

    // "function() { let arguments }"
    if (existing == SymbolKind.Arguments && newKind != SymbolKind.Hoisted) {
        return SymbolMergeResult.OverwriteWithNew
    }

    return SymbolMergeResult.Forbidden
}

/// 判断符号是否可合并 (简化版，不含 TypeScript)
public func canMergeSymbolsSimple(
    scope: Scope,
    existing: SymbolKind,
    newKind: SymbolKind
): SymbolMergeResult {
    return canMergeSymbols(scope, existing, newKind, false)
}

// ============================================================================
// NestedScopeMap - 嵌套作用域映射
// 严格翻译自: src/ast/scope.zig:29
//   pub const NestedScopeMap = std.AutoArrayHashMap(u32, bun.BabyList(*Scope))
// ============================================================================

/// 嵌套作用域映射 - 对应 Bun Scope.NestedScopeMap
/// Bun: pub const NestedScopeMap = std.AutoArrayHashMap(u32, bun.BabyList(*Scope))
/// 按声明索引组织的作用域映射
public class NestedScopeMap {
    /// 映射 (声明索引 -> 子作用域列表)
    public var map: HashMap<UInt32, ArrayList<Scope>>

    public init() {
        map = HashMap<UInt32, ArrayList<Scope>>()
    }

    /// 添加作用域
    public func put(index: UInt32, scopes: ArrayList<Scope>): Unit {
        map.put(index, scopes)
    }

    /// 获取作用域列表
    public func get(index: UInt32): ?ArrayList<Scope> {
        return map.get(index)
    }
}
