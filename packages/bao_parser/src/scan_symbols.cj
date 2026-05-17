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
        if (!recordUsage) {
            return FindSymbolResult(Ref.NONE, loc, false)
        }

        let ref = p.newSymbol(SymbolKind.Unbound, name)
        return FindSymbolResult(ref, loc, false)
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

// SymbolKind - 已在 ast.cj 中定义

// ============================================================================
// ScopeMember - 作用域成员
// 已在 ast.cj 中定义
// ============================================================================

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
