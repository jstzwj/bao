// AST 解析结果
// 严格翻译自: src/ast/ast_result.rs (234行)
//   js_parser/ast/Ast.zig — the parser-output struct.
//   包含:
//     - Ast: 解析器输出结构体 (parts, symbols, scopes, import_records)
//     - CommonJSNamedExport: CommonJS 命名导出
//     - NamedImport: 命名导入
//     - NamedExport: 命名导出
//     - ExportsKind: 导出类型
//     - Part/PartTag: AST 部分 (用于 tree shaking)
package bao_ast

import bao_core.*
import bao_collections.*

// ============================================================================
// ExportsKind - 导出类型
// 严格翻译自: nodes.rs:871-930
//   pub enum ExportsKind { None, Cjs, Esm, EsmWithDynamicFallback, ... }
// ============================================================================

/// 导出类型 - 对应 Bun ExportsKind
public enum ExportsKind {
    | None                           // 无导出，无法判断文件类型
    | Cjs                            // CommonJS: exports 存储在 module/exports 上
    | Esm                            // ES Module: 所有导出名已知
    | EsmWithDynamicFallback         // ESM + 动态回退 (export * from)
    | EsmWithDynamicFallbackFromCjs  // 同上但原始为 CommonJS

    public func isDynamic(): Bool {
        match (this) {
            case Cjs | EsmWithDynamicFallback | EsmWithDynamicFallbackFromCjs => true
            case _ => false
        }
    }

    public func isEsmWithDynamicFallback(): Bool {
        match (this) {
            case EsmWithDynamicFallback | EsmWithDynamicFallbackFromCjs => true
            case _ => false
        }
    }

    public operator func ==(right: ExportsKind): Bool {
        ordinal() == right.ordinal()
    }

    public func ordinal(): Int64 {
        match (this) {
            case None => 0
            case Cjs => 1
            case Esm => 2
            case EsmWithDynamicFallback => 3
            case EsmWithDynamicFallbackFromCjs => 4
        }
    }
}

// ============================================================================
// Ast - 解析器输出结构体
// 严格翻译自: ast_result.rs:25-148
//   pub struct Ast { approximate_newline_count, import_records, parts, symbols, ... }
// ============================================================================

/// 解析器输出 - 对应 Bun Ast
/// 解析器解析一个文件后产生的完整 AST 结构
public class Ast {
    /// 近似换行数 (用于估计行号)
    public var approximateNewlineCount: Int64
    /// 是否有懒导出
    public var hasLazyExport: Bool
    /// 运行时导入
    public var runtimeImports: RuntimeImports
    /// 嵌套作用域槽数计数
    public var nestedScopeSlotCounts: SlotCounts
    /// 运行时导入记录 ID
    public var runtimeImportRecordId: ?UInt32
    /// 是否需要运行时
    public var needsRuntime: Bool
    /// 是否有顶层 return
    public var hasTopLevelReturn: Bool
    /// 是否使用 exports 引用
    public var usesExportsRef: Bool
    /// 是否使用 module 引用
    public var usesModuleRef: Bool
    /// 是否使用 require 引用
    public var usesRequireRef: Bool
    /// CommonJS module.exports 是否被优化分配
    public var commonjsModuleExportsAssignedDeoptimized: Bool
    /// 是否强制将 CJS 转换为 ESM
    public var forceCjsToEsm: Bool
    /// 导出类型
    public var exportsKind: ExportsKind
    /// import 关键字范围
    public var importKeyword: ASTRange
    /// export 关键字范围
    public var exportKeyword: ASTRange
    /// 顶层 await 关键字范围
    public var topLevelAwaitKeyword: ASTRange
    /// 导入记录列表
    public var importRecords: ArrayList<ASTImportRecord>
    /// hashbang (#!/usr/bin/env node)
    public var hashbang: String
    /// 指令 ("use strict" 等)
    public var directive: ?String
    /// AST 部分列表
    public var parts: ArrayList<Part>
    /// 符号列表
    public var symbols: ArrayList<Symbol>
    /// 模块作用域
    public var moduleScope: Scope
    /// 字符频率 (用于压缩)
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
    public var target: Target
    /// TS 枚举映射
    public var tsEnums: HashMap<Ref, HashMap<String, InlinedEnumValue>>
    /// 是否有 CommonJS 导出名
    public var hasCommonjsExportNames: Bool
    /// 是否有 import.meta
    public var hasImportMeta: Bool
    /// import.meta 引用
    public var importMetaRef: Ref

    public init() {
        approximateNewlineCount = 0
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
        importKeyword = ASTRange()
        exportKeyword = ASTRange()
        topLevelAwaitKeyword = ASTRange()
        importRecords = ArrayList<ASTImportRecord>()
        hashbang = ""
        directive = None
        parts = ArrayList<Part>()
        symbols = ArrayList<Symbol>()
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
        target = Target.Browser
        tsEnums = HashMap<Ref, HashMap<String, InlinedEnumValue>>()
        hasCommonjsExportNames = false
        hasImportMeta = false
        importMetaRef = Ref.NONE
    }

    /// 从 parts 创建 - 对应 Bun Ast.from_parts()
    public static func fromParts(parts: ArrayList<Part>): Ast {
        let ast = Ast()
        ast.parts = parts
        ast
    }

    /// 空 AST - 对应 Bun Ast.empty()
    public static func empty(): Ast {
        Ast()
    }
}

// ============================================================================
// CommonJSNamedExport - CommonJS 命名导出
// 严格翻译自: ast_result.rs:150-162
// ============================================================================

/// CommonJS 命名导出 - 对应 Bun CommonJSNamedExport
public class CommonJSNamedExport {
    public var locRef: LocRef
    public var needsDecl: Bool

    public init() {
        locRef = LocRef()
        needsDecl = true
    }
}

// ============================================================================
// NamedImport - 命名导入
// 严格翻译自: nodes.rs:1229-1254
// ============================================================================

/// 命名导入 - 对应 Bun NamedImport
public class NamedImport {
    /// 使用此导入的部分
    public var localPartsWithUses: ArrayList<UInt32>
    /// 导入的原始导出名
    public var alias: ?String
    /// 别名位置
    public var aliasLoc: ?ASTLoc
    /// 命名空间引用
    public var namespaceRef: ?Ref
    /// 导入记录索引
    public var importRecordIndex: UInt32
    /// 是否为星号导入 (import * as)
    public var aliasIsStar: Bool
    /// 是否被导出
    public var isExported: Bool

    public init() {
        localPartsWithUses = ArrayList<UInt32>()
        alias = None
        aliasLoc = None
        namespaceRef = None
        importRecordIndex = UInt32.MAX
        aliasIsStar = false
        isExported = false
    }
}

// ============================================================================
// NamedExport - 命名导出
// 严格翻译自: nodes.rs:1256-1260
// ============================================================================

/// 命名导出 - 对应 Bun NamedExport
public class NamedExport {
    public var ref: Ref
    public var aliasLoc: ASTLoc

    public init() {
        ref = Ref.NONE
        aliasLoc = ASTLoc()
    }
}

// ============================================================================
// Part - AST 部分
// 严格翻译自: nodes.rs:1099-1181
//   每个文件由多个部分组成，用于 tree shaking 和代码分割
// ============================================================================

/// 部分标签 - 对应 Bun PartTag
public enum PartTag {
    | None
    | JsxImport
    | Runtime
    | CjsImports
    | ReactFastRefresh
    | DirnameFilename
    | BunTest
    | DeadDueToInlining
    | CommonjsNamedExport
    | ImportToConvertFromRequire

    public operator func ==(right: PartTag): Bool {
        ordinal() == right.ordinal()
    }

    public func ordinal(): Int64 {
        match (this) {
            case None => 0
            case JsxImport => 1
            case Runtime => 2
            case CjsImports => 3
            case ReactFastRefresh => 4
            case DirnameFilename => 5
            case BunTest => 6
            case DeadDueToInlining => 7
            case CommonjsNamedExport => 8
            case ImportToConvertFromRequire => 9
        }
    }
}

/// AST 部分 - 对应 Bun Part
/// 每个文件由多个部分组成，各部分可独立进行 tree shaking 和代码分割
public class Part {
    /// 语句列表
    public var stmts: ArrayList<StmtNode>
    /// 作用域列表
    public var scopes: ArrayList<Scope>
    /// 导入记录索引
    public var importRecordIndices: ArrayList<UInt32>
    /// 声明的符号
    public var declaredSymbols: ArrayList<DeclaredSymbol>
    /// 符号使用映射
    public var symbolUses: HashMap<Ref, SymbolUse>
    /// 导入符号属性使用
    public var importSymbolPropertyUses: HashMap<Ref, HashMap<String, SymbolUse>>
    /// 依赖的其他部分
    public var dependencies: ArrayList<Dependency>
    /// 如果未使用可移除
    public var canBeRemovedIfUnused: Bool
    /// 强制 tree shaking
    public var forceTreeShaking: Bool
    /// 是否活跃 (tree shaking 标记)
    public var isLive: Bool
    /// 部分标签
    public var tag: PartTag

    public init() {
        stmts = ArrayList<StmtNode>()
        scopes = ArrayList<Scope>()
        importRecordIndices = ArrayList<UInt32>()
        declaredSymbols = ArrayList<DeclaredSymbol>()
        symbolUses = HashMap<Ref, SymbolUse>()
        importSymbolPropertyUses = HashMap<Ref, HashMap<String, SymbolUse>>()
        dependencies = ArrayList<Dependency>()
        canBeRemovedIfUnused = false
        forceTreeShaking = false
        isLive = false
        tag = PartTag.None
    }
}

// ============================================================================
// Dependency - 依赖
// 严格翻译自: nodes.rs:1071-1086
// ============================================================================

/// 依赖 - 对应 Bun Dependency
public class Dependency {
    public var sourceIndex: SourceIndex
    public var partIndex: UInt32

    public init() {
        sourceIndex = SourceIndex.INVALID
        partIndex = 0
    }
}

// ============================================================================
// InlinedEnumValue - 内联枚举值
// 严格翻译自: nodes.rs:806-869
//   类似 JSValue 的 NaN-boxing 编码
// ============================================================================

/// 内联枚举值解码结果
public enum InlinedEnumValueDecoded {
    | String(String)
    | Number(Float64)
}

/// 内联枚举值 - 对应 Bun InlinedEnumValue
/// 使用 NaN-boxing 编码，64位可同时存储指针或浮点数
public class InlinedEnumValue {
    public var rawData: UInt64

    public init() {
        rawData = 0
    }

    public init(rawData: UInt64) {
        this.rawData = rawData
    }

    /// 解码 - 对应 InlinedEnumValue.decode()
    public func decode(): InlinedEnumValueDecoded {
        if (rawData > 0x0000_FFFF_FFFF_FFFF) {
            InlinedEnumValueDecoded.Number(Float64.fromBits(rawData - DOUBLE_ENCODE_OFFSET))
        } else {
            InlinedEnumValueDecoded.String("tag:${rawData}")
        }
    }

    private static let DOUBLE_ENCODE_OFFSET: UInt64 = UInt64(1) << 49
}

// ============================================================================
// SlotCounts - 槽计数
// 严格翻译自: nodes.rs:629-652
// ============================================================================

/// 槽计数 - 对应 Bun SlotCounts
public class SlotCounts {
    public var slots: ArrayList<UInt32>

    public init() {
        slots = ArrayList<UInt32>()
    }

    /// 取最大值合并 - 对应 SlotCounts.union_max()
    public func unionMax(other: SlotCounts): Unit {
        // 简化: 逐位取最大
        let maxLen = if (slots.size > other.slots.size) { slots.size } else { other.slots.size }
        while (slots.size < maxLen) {
            slots.append(UInt32(0))
        }
        for (i in 0..other.slots.size) {
            if (other.slots[i] > slots[i]) {
                slots[i] = other.slots[i]
            }
        }
    }
}

// ============================================================================
// RuntimeImports - 运行时导入
// 严格翻译自: runtime.rs:153-184
// ============================================================================

/// 运行时导入 - 对应 Bun Runtime.Imports
/// 跟踪从 bun:wrap 导入的运行时函数引用
public class RuntimeImports {
    public var name: ?Ref
    public var require: ?Ref
    public var export: ?Ref
    public var reExport: ?Ref
    public var exportValue: ?Ref
    public var exportDefault: ?Ref
    public var merge: ?Ref
    public var legacyDecorateClassTS: ?Ref
    public var legacyDecorateParamTS: ?Ref
    public var legacyMetadataTS: ?Ref
    public var publicField: ?Ref
    public var privateIn: ?Ref
    public var privateGet: ?Ref
    public var privateAdd: ?Ref
    public var privateSet: ?Ref
    public var privateMethod: ?Ref
    public var decoratorStart: ?Ref
    public var decoratorMetadata: ?Ref
    public var runInitializers: ?Ref
    public var decorateElement: ?Ref
    public var dollarDollarTypeof: ?Ref
    public var using: ?Ref
    public var callDispose: ?Ref
    public var jsonParse: ?Ref
    public var promiseAll: ?Ref

    public init() {
        name = None
        require = None
        export = None
        reExport = None
        exportValue = None
        exportDefault = None
        merge = None
        legacyDecorateClassTS = None
        legacyDecorateParamTS = None
        legacyMetadataTS = None
        publicField = None
        privateIn = None
        privateGet = None
        privateAdd = None
        privateSet = None
        privateMethod = None
        decoratorStart = None
        decoratorMetadata = None
        runInitializers = None
        decorateElement = None
        dollarDollarTypeof = None
        using = None
        callDispose = None
        jsonParse = None
        promiseAll = None
    }

    /// 是否有任何导入
    public func hasAny(): Bool {
        name.isSome() || require.isSome() || export.isSome() ||
        reExport.isSome() || exportValue.isSome() || exportDefault.isSome()
    }
}

// ============================================================================
// 引用辅助类型 (在 base.cj 中定义)
// ============================================================================

/// 引用类型别名 - 与 base.cj 中的 Ref 相同
public typealias Ref = Ref

/// LocRef - 带位置的引用
/// 对应 Bun LocRef { loc: Loc, ref_: Option<Ref> }
public class LocRef {
    public var loc: ASTLoc
    public var ref: ?Ref

    public init() {
        loc = ASTLoc()
        ref = None
    }
}

/// 符号使用信息 - 对应 Bun Symbol.Use
public class SymbolUse {
    public var countEstimate: Int64

    public init() {
        countEstimate = 0
    }
}

/// 字符频率 - 对应 Bun CharFreq
public class CharFreq {
    public init() {}
}

/// 符号 - 对应 Bun Symbol (在 symbol.cj 中定义)
public typealias Symbol = Symbol

/// 作用域 - 对应 Bun Scope (在 scope.cj 中定义)
public typealias Scope = Scope

/// 目标平台 - 对应 Bun Target
public typealias Target = Target

/// 导入记录 - 与 base.cj 中的 ASTImportRecord 相同
public typealias ASTImportRecord = ASTImportRecord

/// 语句节点
public class StmtNode {
    public var tag: StmtTag
    public var loc: ASTLoc

    public init(tag: StmtTag, loc: ASTLoc) {
        this.tag = tag
        this.loc = loc
    }
}

/// AST 位置
public class ASTLoc {
    public var start: Int32

    public init() {
        start = 0
    }

    public init(start: Int32) {
        this.start = start
    }
}

/// AST 范围
public class ASTRange {
    public var loc: ASTLoc
    public var len: Int32

    public init() {
        loc = ASTLoc()
        len = 0
    }
}
