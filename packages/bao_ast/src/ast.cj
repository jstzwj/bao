// 严格翻译自: src/ast/ast.zig
// Ast 顶层结构: parts, symbols, scopes, import_records, named_imports/exports
package bao_ast

import bao_core.*
import bao_collections.*
import bao_parser.*

// ============================================================================
// Ast - AST 根结构
// 严格翻译自: src/ast/ast.zig:1-144
// Bun: pub const Ast = struct {
//   approximate_newline_count, has_lazy_export, runtime_imports,
//   nested_scope_slot_counts, import_records, parts, symbols,
//   module_scope, named_imports, named_exports, ...
// }
// ============================================================================

/// CommonJS 命名导出项 - 对应 Bun Ast.CommonJSNamedExport
/// Bun: pub const CommonJSNamedExport = struct { loc_ref: LocRef, needs_decl: bool = true }
public class CommonJSNamedExport {
    public var locRef: LocRef
    public var needsDecl: Bool

    public init(locRef: LocRef, needsDecl: Bool) {
        this.locRef = locRef
        this.needsDecl = needsDecl
    }

    public init(locRef: LocRef) {
        this.locRef = locRef
        this.needsDecl = true
    }
}

/// 内联枚举值 - 对应 Bun InlinedEnumValue
/// Bun 中用于 TS const enum 的内联值
public class InlinedEnumValue {
    public var value: ASTNode
    public var comment: String

    public init(value: ASTNode, comment: String) {
        this.value = value
        this.comment = comment
    }
}

/// 命名导入项 - 对应 Bun NamedImport
/// Bun: pub const NamedImport = struct { alias: string, alias_loc: LocRef, ... }
public class NamedImport {
    public var alias: String
    public var aliasLoc: LocRef
    public var importRecordIndex: UInt32
    public var nameLoc: LocRef
    public var namespaceRef: Ref

    public init(alias: String, aliasLoc: LocRef, importRecordIndex: UInt32,
                nameLoc: LocRef, namespaceRef: Ref) {
        this.alias = alias
        this.aliasLoc = aliasLoc
        this.importRecordIndex = importRecordIndex
        this.nameLoc = nameLoc
        this.namespaceRef = namespaceRef
    }
}

/// 命名导出项 - 对应 Bun NamedExport
/// Bun: pub const NamedExport = struct { alias: string, alias_loc: LocRef, name: string, ... }
public class NamedExport {
    public var alias: String
    public var aliasLoc: LocRef
    public var name: String
    public var nameLoc: LocRef
    public var ref: Ref

    public init(alias: String, aliasLoc: LocRef, name: String,
                nameLoc: LocRef, ref: Ref) {
        this.alias = alias
        this.aliasLoc = aliasLoc
        this.name = name
        this.nameLoc = nameLoc
        this.ref = ref
    }
}

/// 导出类型 - 对应 Bun ExportsKind
/// Bun: pub const ExportsKind = enum { none, cjs, esm }
public enum ExportsKind {
    | None  // 无导出
    | CJS   // CommonJS (module.exports / exports)
    | ESM   // ES Module (export / import)

    public func name(): String {
        match (this) {
            case None => "none"
            case CJS => "cjs"
            case ESM => "esm"
        }
    }
}

/// 运行时导入集合 - 对应 Bun Runtime.Imports
/// 记录文件运行时需要的特殊导入
public class RuntimeImports {
    public var hasPromise: Bool
    public var hasWrap: Bool
    public var hasESM: Bool
    public var hasRequire: Bool

    public init() {
        this.hasPromise = false
        this.hasWrap = false
        this.hasESM = false
        this.hasRequire = false
    }
}

/// Slot 计数 - 对应 Bun SlotCounts
/// Bun: pub const SlotCounts = struct { log: u32 = 0, ... }
public class SlotCounts {
    public var log: UInt32
    public var numeric: UInt32

    public init() {
        this.log = UInt32(0)
        this.numeric = UInt32(0)
    }
}

/// Part 列表 - 对应 Bun Part.List
/// Bun: 每个文件被分割为多个 Part, 每个 Part 是一组语句和它需要的依赖
public class PartList {
    public var items: ArrayList<Part>

    public init() {
        items = ArrayList<Part>()
    }

    public func append(part: Part): Unit {
        items.append(part)
    }
}

/// Part - AST 部分 - 对应 Bun Part
/// Bun: 每个 Part 包含一组语句, 以及该部分的导入/导出/符号引用
public class Part {
    public var stmts: ArrayList<StmtNode>
    public var scope: Scope
    public var isStrict: Bool
    public var localScopeSlotCounts: SlotCounts

    public init() {
        this.stmts = ArrayList<StmtNode>()
        this.scope = Scope()
        this.isStrict = false
        this.localScopeSlotCounts = SlotCounts()
    }
}

/// Symbol 列表 - 对应 Bun Symbol.List
public class SymbolList {
    public var items: ArrayList<Symbol>

    public init() {
        items = ArrayList<Symbol>()
    }

    public func append(sym: Symbol): Unit {
        items.append(sym)
    }
}

/// 导入记录列表 - 对应 Bun ImportRecord.List
public class ImportRecordList {
    public var items: ArrayList<ASTImportRecord>

    public init() {
        items = ArrayList<ASTImportRecord>()
    }

    public func append(record: ASTImportRecord): Unit {
        items.append(record)
    }
}

/// Ast - AST 根结构
/// 严格翻译自 Bun js_ast.Ast
/// Bun: pub const Ast = struct { ... 所有顶层 AST 数据 ... }
public class Ast {
    /// 近似换行数 - 用于预估输出大小
    public var approximateNewlineCount: Int64
    /// 是否有懒导出 (export { ... } from '...')
    public var hasLazyExport: Bool
    /// 运行时导入
    public var runtimeImports: RuntimeImports
    /// 嵌套作用域 slot 计数
    public var nestedScopeSlotCounts: SlotCounts
    /// 运行时导入记录 ID
    public var runtimeImportRecordId: ?UInt32
    /// 是否需要运行时
    public var needsRuntime: Bool

    // CommonJS 相关标志
    /// 是否有顶层 return
    public var hasTopLevelReturn: Bool
    /// 是否使用 exports 引用
    public var usesExportsRef: Bool
    /// 是否使用 module 引用
    public var usesModuleRef: Bool
    /// 是否使用 require 引用
    public var usesRequireRef: Bool
    /// CommonJS module.exports 是否被去优化
    public var commonjsModuleExportsAssignedDeoptimized: Bool
    /// 是否强制 CJS 转 ESM
    public var forceCjsToEsm: Bool
    /// 导出类型
    public var exportsKind: ExportsKind

    // ES6 特征范围 (用于日志)
    /// import 关键字范围
    public var importKeyword: Range
    /// export 关键字范围
    public var exportKeyword: Range
    /// 顶层 await 关键字范围
    public var topLevelAwaitKeyword: Range

    /// 导入记录
    public var importRecords: ImportRecordList
    /// hashbang 行 (#!/usr/bin/env node)
    public var hashbang: String
    /// 指令 ("use strict")
    public var directive: ?String
    /// AST 部分
    public var parts: PartList
    /// 符号表
    public var symbols: SymbolList
    /// 模块作用域
    public var moduleScope: Scope
    /// 字符频率 (用于名称压缩)
    public var charFreq: ?CharFreq

    /// exports 引用
    public var exportsRef: Ref
    /// module 引用
    public var moduleRef: Ref
    /// wrapper 引用
    public var wrapperRef: Ref
    /// require 引用
    public var requireRef: Ref

    /// 命名导入映射
    public var namedImports: HashMap<Ref, NamedImport>
    /// 命名导出映射
    public var namedExports: HashMap<String, NamedExport>
    /// export star 导入记录索引
    public var exportStarImportRecords: ArrayList<UInt32>

    /// 顶层符号到部分的映射
    public var topLevelSymbolsToParts: HashMap<Ref, ArrayList<UInt32>>

    /// CommonJS 命名导出
    public var commonjsNamedExports: HashMap<String, CommonJSNamedExport>
    /// 重定向导入记录索引
    public var redirectImportRecordIndex: ?UInt32

    /// 目标平台
    public var target: TargetKind

    /// TS 枚举映射
    public var tsEnums: HashMap<Ref, HashMap<String, InlinedEnumValue>>

    /// 是否有 CommonJS 导出名称
    public var hasCommonjsExportNames: Bool
    /// 是否有 import.meta
    public var hasImportMeta: Bool
    /// import.meta 引用
    public var importMetaRef: Ref

    public init() {
        approximateNewlineCount = Int64(0)
        hasLazyExport = false
        runtimeImports = RuntimeImports()
        nestedScopeSlotCounts = SlotCounts()
        runtimeImportRecordId = None
        needsRuntime = false
        hasTopLevelReturn = false
        usesExportsRef = false
        usesModuleRef = false
        usesRequireRef = false
        commonjsModuleExportsAssignedDeoptimized = false
        forceCjsToEsm = false
        exportsKind = ExportsKind.None
        importKeyword = Range.None
        exportKeyword = Range.None
        topLevelAwaitKeyword = Range.None
        importRecords = ImportRecordList()
        hashbang = ""
        directive = None
        parts = PartList()
        symbols = SymbolList()
        moduleScope = Scope()
        charFreq = None
        exportsRef = Ref.NONE
        moduleRef = Ref.NONE
        wrapperRef = Ref.NONE
        requireRef = Ref.NONE
        namedImports = HashMap<Ref, NamedImport>()
        namedExports = HashMap<String, NamedExport>()
        exportStarImportRecords = ArrayList<UInt32>()
        topLevelSymbolsToParts = HashMap<Ref, ArrayList<UInt32>>()
        commonjsNamedExports = HashMap<String, CommonJSNamedExport>()
        redirectImportRecordIndex = None
        target = TargetKind.Browser
        tsEnums = HashMap<Ref, HashMap<String, InlinedEnumValue>>()
        hasCommonjsExportNames = false
        hasImportMeta = false
        importMetaRef = Ref.NONE
    }

    /// 从 parts 创建 - 对应 Bun Ast.fromParts()
    public static func fromParts(parts: ArrayList<Part>): Ast {
        let ast = Ast()
        for (part in parts) {
            ast.parts.append(part)
        }
        return ast
    }

    /// 空 Ast - 对应 Bun Ast.empty
    public static let EMPTY: Ast = Ast()

    /// 清理 - 对应 Bun Ast.deinit()
    public func deinit(): Unit {
        parts.items.clear()
        symbols.items.clear()
        importRecords.items.clear()
    }
}

/// 目标平台 - 对应 Bun bun.options.Target
public enum TargetKind {
    | Browser
    | Node
    | Bun
    | BakeInternalDev
    | BakeInternalProd

    public func name(): String {
        match (this) {
            case Browser => "browser"
            case Node => "node"
            case Bun => "bun"
            case BakeInternalDev => "bake_internal_dev"
            case BakeInternalProd => "bake_internal_prod"
        }
    }
}
