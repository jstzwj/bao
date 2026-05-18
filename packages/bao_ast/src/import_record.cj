// 导入记录
// 严格翻译自: src/ast/import_record.rs (159行)
//   ImportRecord and friends — the per-import metadata struct stored on Ast.
//   包含:
//     - ImportRecord: 导入记录 (path, kind, tag, loader, flags)
//     - Tag: 导入标签 (None, Bun, Builtin, Runtime, Macro, ...)
//     - Flags: 导入记录标志位
//     - PrintMode: 打印模式
package bao_ast

import bao_core.*
import bao_collections.*

// ============================================================================
// ImportRecord - 导入记录
// 严格翻译自: import_record.rs:16-44
//   pub struct ImportRecord { range, path, kind, tag, loader, flags, ... }
// ============================================================================

/// 导入记录 - 对应 Bun ImportRecord
/// 存储在 Ast 上的每个导入元数据结构。
/// 包含导入路径、类型、标志等信息。
public class ImportRecord {
    /// 导入范围
    public var range: ASTRange
    /// 导入路径 (解析后为绝对路径)
    public var path: String
    /// 导入类型
    public var kind: ImportKind
    /// 导入标签
    public var tag: ImportTag
    /// 加载器 (可选，用于指定特定文件的加载方式)
    public var loader: ?Loader
    /// 源文件索引
    public var sourceIndex: SourceIndex
    /// 模块 ID (bundler 使用)
    public var moduleId: UInt32
    /// 原始导入路径 (解析前的路径，用于 metafile)
    public var originalPath: String
    /// 标志位
    public var flags: ImportRecordFlags

    public init(path: String, kind: ImportKind) {
        range = ASTRange()
        this.path = path
        this.kind = kind
        tag = ImportTag.None
        loader = None
        sourceIndex = SourceIndex.INVALID
        moduleId = 0
        originalPath = path
        flags = ImportRecordFlags()
    }

    public init(path: String, kind: ImportKind, tag: ImportTag) {
        range = ASTRange()
        this.path = path
        this.kind = kind
        this.tag = tag
        loader = None
        sourceIndex = SourceIndex.INVALID
        moduleId = 0
        originalPath = path
        flags = ImportRecordFlags()
    }
}

// ============================================================================
// ImportTag - 导入标签
// 严格翻译自: import_record.rs:113-133
//   pub enum Tag { None, Bun, Builtin, Runtime, Macro, ... }
// ============================================================================

/// 导入标签 - 对应 Bun Tag
/// 标识导入目标的不同类型
public enum ImportTag {
    | None                 // 普通导入到用户源文件
    | Bun                  // 导入到 'bun'
    | Builtin              // 内建模块 (node:fs, bun:sqlite)
    | Runtime              // 导入到内部运行时
    | Macro                // macro: 导入或 with { type: "macro" }
    | BakeResolveToSsrGraph // Bun Kit: 服务端组件到 SSR 图
    | Tailwind             // Tailwind CSS

    /// 是否为运行时导入 - 对应 Tag.is_runtime()
    public func isRuntime(): Bool {
        match (this) {
            case Runtime => true
            case _ => false
        }
    }

    /// 是否为内部导入 - 对应 Tag.is_internal()
    public func isInternal(): Bool {
        match (this) {
            case Runtime | BakeResolveToSsrGraph | Macro | Bun | Builtin | Tailwind => true
            case None => false
        }
    }

    public operator func ==(right: ImportTag): Bool {
        ordinal() == right.ordinal()
    }

    public func ordinal(): Int64 {
        match (this) {
            case None => 0
            case Bun => 1
            case Builtin => 2
            case Runtime => 3
            case Macro => 4
            case BakeResolveToSsrGraph => 5
            case Tailwind => 6
        }
    }
}

// ============================================================================
// ImportRecordFlags - 导入记录标志位
// 严格翻译自: import_record.rs:46-109
//   bitflags! { pub struct Flags: u16 { ... } }
// ============================================================================

/// 导入记录标志位 - 对应 Bun Flags
/// 将 15 个布尔标志打包为减少内存占用
public class ImportRecordFlags {
    /// 是否处理导入错误 (try/catch 包裹)
    public var handlesImportErrors: Bool
    /// 是否为内部导入
    public var isInternal: Bool
    /// 是否未使用 (TypeScript 类型导入可能被标记)
    public var isUnused: Bool
    /// 是否包含 * as ns 导入
    public var containsImportStar: Bool
    /// 是否包含 default 别名
    public var containsDefaultAlias: Bool
    /// 是否包含 ES 模块别名
    public var containsEsModuleAlias: Bool
    /// 是否调用运行时 __reExport 函数
    public var callsRuntimeReExportFn: Bool
    /// 是否在 try 体内
    public var isInsideTryBody: Bool
    /// 是否原本是 bare import (import 'file')
    public var wasOriginallyBareImport: Bool
    /// 是否原本是 require
    public var wasOriginallyRequire: Bool
    /// 是否被宏注入
    public var wasInjectedByMacro: Bool
    /// 是否为外部且无副作用
    public var isExternalWithoutSideEffects: Bool
    /// 是否在路径中打印命名空间
    public var printNamespaceInPath: Bool
    /// 是否用 toESM 包装
    public var wrapWithToEsm: Bool
    /// 是否用 toCommonJS 包装
    public var wrapWithToCommonJS: Bool

    public init() {
        handlesImportErrors = false
        isInternal = false
        isUnused = false
        containsImportStar = false
        containsDefaultAlias = false
        containsEsModuleAlias = false
        callsRuntimeReExportFn = false
        isInsideTryBody = false
        wasOriginallyBareImport = false
        wasOriginallyRequire = false
        wasInjectedByMacro = false
        isExternalWithoutSideEffects = false
        printNamespaceInPath = false
        wrapWithToEsm = false
        wrapWithToCommonJS = false
    }
}

// ============================================================================
// PrintMode - 打印模式
// 严格翻译自: import_record.rs:147-153
//   pub enum PrintMode { Normal, ImportPath, Css, NapiModule }
// ============================================================================

/// 打印模式 - 对应 Bun PrintMode
public enum PrintMode {
    | Normal       // 正常打印
    | ImportPath   // 作为导入路径打印
    | Css          // CSS 打印
    | NapiModule   // N-API 模块打印

    public operator func ==(right: PrintMode): Bool {
        ordinal() == right.ordinal()
    }

    public func ordinal(): Int64 {
        match (this) {
            case Normal => 0
            case ImportPath => 1
            case Css => 2
            case NapiModule => 3
        }
    }
}

// ============================================================================
// ImportKind - 导入类型
// 严格翻译自: import_record.rs 引用的 bun_ast::ImportKind
// ============================================================================

/// 导入类型 - 对应 Bun ImportKind
public enum ImportKind {
    | Entry            // 入口点
    | EntryPointBuild  // build 入口点
    | EntryPointRun    // run 入口点
    | Stmt             // import 语句
    | Dynamic          // import() 表达式
    | Require          // require() 调用
    | RequireResolve   // require.resolve() 调用
    | At               // CSS @import
    | AtConditional    // CSS 条件 @import
    | Url              // CSS url()

    /// 是否来自 CSS
    public func isFromCSS(): Bool {
        match (this) {
            case At | AtConditional | Url => true
            case _ => false
        }
    }

    public operator func ==(right: ImportKind): Bool {
        ordinal() == right.ordinal()
    }

    public func ordinal(): Int64 {
        match (this) {
            case Entry => 0
            case EntryPointBuild => 1
            case EntryPointRun => 2
            case Stmt => 3
            case Dynamic => 4
            case Require => 5
            case RequireResolve => 6
            case At => 7
            case AtConditional => 8
            case Url => 9
        }
    }
}

/// 导入记录列表 - 对应 Bun ImportRecord.List
public typealias ImportRecordList = ArrayList<ImportRecord>
