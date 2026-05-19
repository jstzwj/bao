// AST 符号扫描器
// 严格翻译自: src/js_parser/scan/scan_symbols.zig (134 lines)
//   Bun 的符号扫描器负责在 AST 中查找符号声明
//   findSymbol 是核心方法，沿作用域链向上查找符号
//   findSymbolWithRecordUsage 控制是否记录使用计数
//   处理: with 语句作用域、arguments 禁止、TypeScript 命名空间、
//         未绑定符号分配、must_not_be_renamed 标记
//   对应 Bun: Symbols() 模块
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// FindSymbolResult - 符号查找结果
// 严格翻译自: scan_symbols.zig:9-115 (通过返回值推断)
//   pub const FindSymbolResult = struct {
//       ref: Ref,
//       declare_loc: logger.Loc,
//       is_inside_with_scope: bool,
//   }
// ============================================================================

/// 符号查找结果 - 对应 Bun FindSymbolResult
public class FindSymbolResult {
    /// 找到的符号引用 - 对应 ref: Ref
    public var ref: Ref
    /// 声明位置 - 对应 declare_loc: logger.Loc
    public var declareLoc: Loc
    /// 是否在 with 语句作用域内 - 对应 is_inside_with_scope: bool
    public var isInsideWithScope: Bool

    public init(ref: Ref, declareLoc: Loc, isInsideWithScope: Bool) {
        this.ref = ref
        this.declareLoc = declareLoc
        this.isInsideWithScope = isInsideWithScope
    }

    /// 便利构造器: 未找到
    public static func notFound(loc: Loc, isInsideWithScope: Bool): FindSymbolResult {
        return FindSymbolResult(Ref.NONE, loc, isInsideWithScope)
    }
}

// ============================================================================
// SymbolScanVisitor - 符号扫描访问器
// 严格翻译自: scan_symbols.zig:6-117
//   pub fn Symbols(comptime ...) type { return struct { ... } }
//   核心方法: findSymbol, findSymbolWithRecordUsage
//
//   算法:
//     1. 预计算 name 的哈希 (只计算一次)
//     2. 沿作用域链向上搜索:
//        a. 追踪是否在 with 语句体内
//        b. 检查是否在类体内禁止使用 arguments
//        c. 在当前作用域中查找成员
//        d. 检查 TypeScript 命名空间的导出成员
//     3. 如果未找到且 record_usage, 创建未绑定符号
//     4. 如果经过 with 语句体, 标记 must_not_be_renamed
//     5. 记录使用计数
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
    //   return findSymbolWithRecordUsage(p, loc, name, true);
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
    //
    //   核心算法:
    //     var declare_loc: logger.Loc = logger.Loc.Empty;
    //     var is_inside_with_scope = false;
    //     const hash = Scope.getMemberHash(name);
    //     const ref = brk: {
    //         var current: ?*Scope = p.current_scope;
    //         var did_forbid_arguments = false;
    //         while (current) |scope| : (current = current.?.parent) {
    //             // Track "with" scope
    //             // Forbid "arguments" in class bodies
    //             // Look up member in scope
    //             // Check TypeScript namespace
    //         }
    //         // Allocate unbound symbol
    //     };
    //     if (is_inside_with_scope) must_not_be_renamed = true
    //     if (record_usage) recordUsage(ref)
    //     return FindSymbolResult{ ... }
    // ========================================================================

    /// 带使用记录的符号查找 - 对应 Bun findSymbolWithRecordUsage
    /// 沿作用域链向上搜索符号，支持 with 语句作用域追踪
    public func findSymbolWithRecordUsage(loc: Loc, name: String, recordUsage: Bool): FindSymbolResult {
        var declareLoc = Loc.EMPTY
        var isInsideWithScope = false

        // 预计算哈希 - 对应 Bun:
        //   const hash = Scope.getMemberHash(name);
        //   This function can show up in profiling.
        //   That's part of why we do this.
        //   Instead of rehashing `name` for every scope, we do it just once.
        let hash = Scope.getMemberHash(name)

        // 沿作用域链搜索
        // 对应 Bun: const ref: Ref = brk: { var current = p.current_scope; ... }
        var current = p.currentScope
        var didForbidArguments = false
        var foundRef: Ref = Ref.NONE

        while (current != None) {
            let scope = current
            let scopeInfo = scope.info

            // 追踪是否在 with 语句体内
            // 对应 Bun: if (scope.kind == .with) { is_inside_with_scope = true; }
            if (scopeInfo.kind == ScopeKind.With) {
                isInsideWithScope = true
            }

            // 在类体内禁止使用 arguments
            // 对应 Bun:
            //   if (scope.forbid_arguments and !did_forbid_arguments and
            //       strings.eqlComptime(name, "arguments")) {
            //       p.log.addRangeErrorFmt(...)
            //       did_forbid_arguments = true;
            //   }
            if (scopeInfo.forbidArguments && !didForbidArguments && name == "arguments") {
                let r = RangeOfIdentifier(p.source, loc)
                p.log.addRangeError(p.source, r, "Cannot access \"${name}\" here")
                didForbidArguments = true
            }

            // 在当前作用域中查找成员
            // 对应 Bun:
            //   if (scope.getMemberWithHash(name, hash)) |member| {
            //       declare_loc = member.loc;
            //       break :brk member.ref;
            //   }
            if (let Some(member) <- scopeInfo.getMemberWithHash(name, hash)) {
                declareLoc = member.loc
                foundRef = member.ref
                current = None // break
                continue
            }

            // 检查 TypeScript 命名空间
            // 对应 Bun:
            //   if (scope.ts_namespace) |ts_namespace| {
            //       if (ts_namespace.exported_members.get(name)) |member| {
            //           if (member.data.isEnum() == ts_namespace.is_enum_scope) {
            //               // 惰性生成标识符表示属性访问
            //               ...
            //           }
            //       }
            //   }
            if (let Some(tsNamespace) <- scopeInfo.tsNamespace) {
                if (let Some(member) <- tsNamespace.exportedMembers.get(name)) {
                    if (member.isEnum == tsNamespace.isEnumScope) {
                        declareLoc = member.loc
                        // 惰性生成属性访问标识符
                        // 对应 Bun:
                        //   const gop = try ts_namespace.property_accesses.getOrPut(...)
                        //   if (!gop.found_existing) {
                        //       const ref = try p.newSymbol(.other, name);
                        //       gop.value_ptr.* = ref;
                        //       p.symbols.items[ref.inner_index].namespace_alias = .{ ... };
                        //       break :brk ref;
                        //   }
                        //   break :brk gop.value_ptr.*;
                        if (!tsNamespace.propertyAccesses.contains(name)) {
                            let newRef = p.newSymbol(SymbolKind.Other, name)
                            tsNamespace.propertyAccesses.put(name, newRef)
                            let symbol = p.symbols.get(newRef.innerIndex())
                            symbol.namespaceAliasRef = tsNamespace.argRef
                            symbol.namespaceAliasAlias = name
                            foundRef = newRef
                            current = None // break
                            continue
                        } else {
                            foundRef = tsNamespace.propertyAccesses.get(name).getOrElse(Ref.NONE)
                            current = None // break
                            continue
                        }
                    }
                }
            }

            // 移到父作用域
            current = scopeInfo.parent
        }

        // 如果未找到, 分配未绑定符号
        // 对应 Bun:
        //   p.checkForNonBMPCodePoint(loc, name);
        //   if (!record_usage) return FindSymbolResult{ .ref = Ref.None, ... };
        //   const gpe = p.module_scope.getOrPutMemberWithHash(...);
        //   if (gpe.found_existing) { ... }
        //   const _ref = p.newSymbol(.unbound, name);
        //   gpe.key_ptr.* = name;
        //   gpe.value_ptr.* = Scope.Member{ .ref = _ref, .loc = loc };
        if (!foundRef.isValid()) {
            p.checkForNonBMPCodePoint(loc, name)

            if (!recordUsage) {
                return FindSymbolResult(Ref.NONE, loc, isInsideWithScope)
            }

            // 检查模块作用域中是否已有此名称
            let moduleMember = p.moduleScope.getMemberWithHash(name, hash)
            if (let Some(existing) <- moduleMember) {
                declareLoc = existing.loc
                foundRef = existing.ref
            } else {
                // 创建新的未绑定符号
                foundRef = p.newSymbol(SymbolKind.Unbound, name)
                p.moduleScope.addMemberWithHash(name, hash, ScopeMember(foundRef, loc))
                declareLoc = loc
            }
        }

        // 如果经过 with 语句体, 标记不可重命名
        // 对应 Bun:
        //   if (is_inside_with_scope) {
        //       p.symbols.items[ref.innerIndex()].must_not_be_renamed = true;
        //   }
        if (isInsideWithScope) {
            let symbol = p.symbols.get(foundRef.innerIndex())
            symbol.mustNotBeRenamed = true
        }

        // 记录使用计数
        // 对应 Bun: if (record_usage) p.recordUsage(ref);
        if (recordUsage) {
            p.recordUsage(foundRef)
        }

        return FindSymbolResult(foundRef, declareLoc, isInsideWithScope)
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 获取标识符的范围 - 对应 Bun js_lexer.rangeOfIdentifier
    private func RangeOfIdentifier(source: Source, loc: Loc): Range {
        return Range(loc, 1)
    }
}

// ============================================================================
// ScopeInfo - 作用域信息 (用于符号查找)
// 严格翻译自: src/js_parser/ast/Scope.zig
//   pub const Scope = struct {
//       kind: Kind,
//       parent: ?*Scope,
//       members: Members,
//       forbid_arguments: bool,
//       ts_namespace: ?TsNamespace,
//       generated: ArrayList(Ref),
//       ...
//   }
// ============================================================================

/// 作用域信息 - 用于符号查找的作用域对象
/// 对应 Bun Scope 在符号查找过程中需要暴露的接口
public class ScopeInfo {
    /// 作用域类型 - 对应 kind: Kind
    public var kind: ScopeKind
    /// 父作用域 - 对应 parent: ?*Scope
    public var parent: ?ScopeInfo
    /// 成员映射 - 对应 members: Members
    public var members: HashMap<String, ScopeMember>
    /// 带哈希的成员查找表 - 对应 members 的哈希索引
    private var membersByHash: HashMap<UInt64, ScopeMember>
    /// 是否禁止 arguments - 对应 forbid_arguments: bool
    public var forbidArguments: Bool
    /// TypeScript 命名空间 - 对应 ts_namespace: ?TsNamespace
    public var tsNamespace: ?TsNamespaceInfo
    /// 生成的符号列表 - 对应 generated: ArrayList(Ref)
    public var generated: ArrayList<Ref>

    public init() {
        kind = ScopeKind.Block
        parent = None
        members = HashMap<String, ScopeMember>()
        membersByHash = HashMap<UInt64, ScopeMember>()
        forbidArguments = false
        tsNamespace = None
        generated = ArrayList<Ref>()
    }

    public init(kind: ScopeKind) {
        this.kind = kind
        parent = None
        members = HashMap<String, ScopeMember>()
        membersByHash = HashMap<UInt64, ScopeMember>()
        forbidArguments = false
        tsNamespace = None
        generated = ArrayList<Ref>()
    }

    /// 获取成员 - 对应 scope.getMember(name)
    public func getMember(name: String): ?ScopeMember {
        return members.get(name)
    }

    /// 通过哈希获取成员 - 对应 scope.getMemberWithHash(name, hash)
    public func getMemberWithHash(name: String, hash: UInt64): ?ScopeMember {
        // 先按名称查找 (简化实现, 实际应使用哈希)
        return members.get(name)
    }

    /// 添加成员 - 对应 scope.addMember
    public func addMember(name: String, member: ScopeMember): Unit {
        members.put(name, member)
    }

    /// 添加带哈希的成员 - 对应 scope.putMemberWithHash
    public func addMemberWithHash(name: String, hash: UInt64, member: ScopeMember): Unit {
        members.put(name, member)
    }
}

// ============================================================================
// TsNamespaceInfo - TypeScript 命名空间信息
// 严格翻译自: scan_symbols.zig 中对 ts_namespace 的使用
//   const TsNamespace = struct {
//       arg_ref: Ref,
//       is_enum_scope: bool,
//       exported_members: ...
//       property_accesses: ...
//   }
// ============================================================================

/// TypeScript 命名空间信息 - 对应 Bun TsNamespace
public class TsNamespaceInfo {
    /// 命名空间参数引用 - 对应 arg_ref: Ref
    public var argRef: Ref
    /// 是否为枚举作用域 - 对应 is_enum_scope: bool
    public var isEnumScope: Bool
    /// 导出成员映射 - 对应 exported_members
    public var exportedMembers: HashMap<String, TsNamespaceMember>
    /// 属性访问引用映射 (惰性生成) - 对应 property_accesses
    public var propertyAccesses: HashMap<String, Ref>

    public init() {
        argRef = Ref.NONE
        isEnumScope = false
        exportedMembers = HashMap<String, TsNamespaceMember>()
        propertyAccesses = HashMap<String, Ref>()
    }

    public init(argRef: Ref, isEnumScope: Bool) {
        this.argRef = argRef
        this.isEnumScope = isEnumScope
        exportedMembers = HashMap<String, TsNamespaceMember>()
        propertyAccesses = HashMap<String, Ref>()
    }

    /// 获取导出成员
    public func getExportedMember(name: String): ?TsNamespaceMember {
        return exportedMembers.get(name)
    }
}

/// TypeScript 命名空间成员 - 对应 Bun TsNamespace 导出成员
public class TsNamespaceMember {
    /// 声明位置
    public var loc: Loc
    /// 是否为枚举成员
    public var isEnum: Bool
    /// 数据
    public var data: ?Expr

    public init(loc: Loc) {
        this.loc = loc
        isEnum = false
        data = None
    }

    public init(loc: Loc, isEnum: Bool) {
        this.loc = loc
        this.isEnum = isEnum
        data = None
    }
}

