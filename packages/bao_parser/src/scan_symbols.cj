// AST 符号扫描器
// 严格翻译自: src/js_parser/scan/scan_symbols.zig (133 lines)
//   Bun 的符号扫描器负责在 AST 中查找符号声明
//   findSymbol 是核心方法，沿作用域链向上查找符号
//   findSymbolWithRecordUsage 控制是否记录使用计数
//   对应 Bun: Symbols() 模块
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// SymbolScanVisitor - 符号扫描访问器
// 严格翻译自: scan_symbols.zig:6-117
//   pub fn Symbols(comptime ...) type { return struct { ... } }
//   核心方法: findSymbol, findSymbolWithRecordUsage
// ============================================================================

/// 符号扫描访问器 - 对应 Bun Symbols 模块
/// 提供符号查找功能，沿作用域链向上搜索
public class SymbolScanVisitor {
    /// 关联的解析器
    private var p: Parser

    public init(parser: Parser) {
        p = parser
    }

    // ========================================================================
    // findSymbol - 查找符号
    // 严格翻译自: scan_symbols.zig:9-11
    //   pub fn findSymbol(noalias p: *P, loc: logger.Loc, name: string) !FindSymbolResult
    // ========================================================================

    /// 查找符号 - 对应 Bun findSymbol
    /// 委托给 findSymbolWithRecordUsage 并记录使用
    public func findSymbol(loc: Loc, name: String): FindSymbolResult {
        return findSymbolWithRecordUsage(loc, name, true)
    }

    // ========================================================================
    // findSymbolWithRecordUsage - 带使用记录的符号查找
    // 严格翻译自: scan_symbols.zig:13-116
    //   pub fn findSymbolWithRecordUsage(
    //       noalias p: *P, loc: logger.Loc, name: string,
    //       comptime record_usage: bool
    //   ) !FindSymbolResult
    // ========================================================================

    /// 带使用记录的符号查找 - 对应 Bun findSymbolWithRecordUsage
    /// 沿作用域链向上搜索符号，支持 with 语句作用域追踪
    public func findSymbolWithRecordUsage(loc: Loc, name: String, recordUsage: Bool): FindSymbolResult {
        var declareLoc = Loc.EMPTY
        var isInsideWithScope = false

        // 沿作用域链查找
        // 对应 Bun: var current: ?*Scope = p.current_scope; while (current) |scope| { ... }
        var currentScope = p.currentScope
        var didForbidArguments = false

        while (true) {
            if (currentScope == None) {
                break
            }
            if (let Some(scope) <- currentScope) {
                // 跟踪是否在 with 语句体内
                // 对应 Bun: if (scope.kind == .with) { is_inside_with_scope = true; }
                if (scope.kind == ScopeKind.With) {
                    isInsideWithScope = true
                }

                // 禁止在类体内引用 "arguments"
                // 对应 Bun: if (scope.forbid_arguments and name == "arguments")
                if (scope.forbidArguments && !didForbidArguments && name == "arguments") {
                    p.log.addError(MsgData("Cannot access \"${name}\" here"))
                    didForbidArguments = true
                }

                // 在当前作用域查找符号
                // 对应 Bun: if (scope.getMemberWithHash(name, hash)) |member|
                if (let Some(member) <- scope.getMember(name)) {
                    declareLoc = member.loc
                    let ref = member.ref

                    // 如果经过了 with 语句体，不能重命名
                    // 对应 Bun: if (is_inside_with_scope) { must_not_be_renamed = true; }
                    if (isInsideWithScope) {
                        p.setSymbolMustNotBeRenamed(ref)
                    }

                    // 记录使用次数
                    if (recordUsage) {
                        p.recordUsage(ref)
                    }

                    return FindSymbolResult(
                        ref: ref,
                        declareLoc: declareLoc,
                        isInsideWithScope: isInsideWithScope
                    )
                }

                // 检查 TypeScript 命名空间
                // 对应 Bun: if (scope.ts_namespace) |ts_namespace| { ... }
                if (let Some(tsNamespace) <- scope.tsNamespace) {
                    if (let Some(member) <- tsNamespace.getExportedMember(name)) {
                        declareLoc = member.loc
                        // 懒生成属性访问标识符
                        let ref = p.generateNamespacePropertyAccess(tsNamespace, name)
                        if (recordUsage) {
                            p.recordUsage(ref)
                        }
                        return FindSymbolResult(
                            ref: ref,
                            declareLoc: declareLoc,
                            isInsideWithScope: isInsideWithScope
                        )
                    }
                }

                // 继续向上查找
                currentScope = scope.parent
            } else {
                break
            }
        }

        // 未找到符号 - 分配一个 "unbound" 符号
        // 对应 Bun: p.newSymbol(.unbound, name)
        if (!recordUsage) {
            return FindSymbolResult(
                ref: Ref.NONE,
                declareLoc: loc,
                isInsideWithScope: isInsideWithScope
            )
        }

        // 在模块作用域中查找或创建未绑定符号
        let existingRef = p.getModuleScopeMember(name)
        if (existingRef != None && existingRef.isValid()) {
            if (let Some(ref) <- existingRef) {
                declareLoc = loc
                if (isInsideWithScope) {
                    p.setSymbolMustNotBeRenamed(ref)
                }
                p.recordUsage(ref)
                return FindSymbolResult(
                    ref: ref,
                    declareLoc: declareLoc,
                    isInsideWithScope: isInsideWithScope
                )
            }
        }

        // 创建新的未绑定符号
        let newRef = p.newSymbol(SymbolKind.Unbound, name)
        p.addModuleScopeMember(name, newRef, loc)
        declareLoc = loc

        if (isInsideWithScope) {
            p.setSymbolMustNotBeRenamed(newRef)
        }

        p.recordUsage(newRef)

        return FindSymbolResult(
            ref: newRef,
            declareLoc: declareLoc,
            isInsideWithScope: isInsideWithScope
        )
    }
}

// ============================================================================
// SymbolKind - 符号类型
// 严格翻译自: src/js_parser/ast/Symbol.zig
//   pub const Kind = enum {
//       unbound, import, export, resolved,
//       constant, let, var, hoisted, hoisted_function,
//       class, label, other, ...
//   }
// ============================================================================

/// 符号类型 - 对应 Bun Symbol.Kind
public enum SymbolKind {
    | Unbound            // 未绑定 (全局变量)
    | Import             // 导入符号
    | Export             // 导出符号
    | Resolved           // 已解析
    | Constant           // const 声明
    | Let                // let 声明
    | Var                // var 声明
    | Hoisted            // 提升的声明
    | HoistedFunction    // 提升的函数声明
    | Class              // 类名
    | Label              // 标签
    | Other              // 其他
    | Private            // 私有字段
    | PrivateStatic      // 静态私有字段
    | PrivateMethod      // 私有方法
    | PrivateStaticMethod // 静态私有方法
    | PrivateGet         // 私有 getter
    | PrivateSet         // 私有 setter
    | PrivateStaticGet   // 静态私有 getter
    | PrivateStaticSet   // 静态私有 setter

    /// 是否为私有成员类型
    public func isPrivate(): Bool {
        match (this) {
            case Private | PrivateStatic | PrivateMethod |
                 PrivateStaticMethod | PrivateGet | PrivateSet |
                 PrivateStaticGet | PrivateStaticSet =>
                return true
            case _ =>
                return false
        }
    }
}

// ============================================================================
// ScopeMember - 作用域成员
// 严格翻译自: src/js_parser/ast/Scope.zig
//   pub const Member = struct { ref: Ref, loc: Loc }
// ============================================================================

/// 作用域成员 - 对应 Bun Scope.Member
public class ScopeMember {
    /// 符号引用
    public var ref: Ref
    /// 声明位置
    public var loc: Loc

    public init(ref: Ref, loc: Loc) {
        this.ref = ref
        this.loc = loc
    }
}

// ============================================================================
// ScopeInfo - 作用域信息 (用于符号查找)
// 严格翻译自: src/js_parser/ast/Scope.zig
// ============================================================================

/// 作用域信息 - 用于符号查找的作用域对象
/// 对应 Bun Scope 在符号查找过程中需要暴露的接口
public class ScopeInfo {
    /// 作用域类型
    public var kind: ScopeKind
    /// 父作用域
    public var parent: ?ScopeInfo
    /// 成员映射
    public var members: HashMap<String, ScopeMember>
    /// 是否禁止 arguments
    public var forbidArguments: Bool
    /// TypeScript 命名空间
    public var tsNamespace: ?TsNamespaceInfo

    public init() {
        kind = ScopeKind.Block
        parent = None
        members = HashMap<String, ScopeMember>()
        forbidArguments = false
        tsNamespace = None
    }

    /// 获取成员
    public func getMember(name: String): ?ScopeMember {
        if (members.contains(name)) {
            return members.get(name)
        }
        return None
    }

    /// 添加成员
    public func addMember(name: String, member: ScopeMember): Unit {
        members.put(name, member)
    }
}

// ============================================================================
// TsNamespaceInfo - TypeScript 命名空间信息
// ============================================================================

/// TypeScript 命名空间信息
public class TsNamespaceInfo {
    /// 导出成员映射
    public var exportedMembers: HashMap<String, TsNamespaceMember>

    public init() {
        exportedMembers = HashMap<String, TsNamespaceMember>()
    }

    /// 获取导出成员
    public func getExportedMember(name: String): ?TsNamespaceMember {
        if (exportedMembers.contains(name)) {
            return exportedMembers.get(name)
        }
        return None
    }
}

/// TypeScript 命名空间成员
public class TsNamespaceMember {
    /// 声明位置
    public var loc: Loc

    public init(loc: Loc) {
        this.loc = loc
    }
}
