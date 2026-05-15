// ImportRecord - 导入记录类型
// 严格翻译自: bun/src/options_types/import_record.zig
//   pub const ImportKind = enum(u8) { ... };
//   pub const ImportRecord = struct { ... };
package bao_options

import bao_core.*

// ============================================================================
// ImportKind - 导入类型
// 严格翻译自: import_record.zig - ImportKind
//   pub const ImportKind = enum(u8) {
//       entry_point_run, entry_point_build, stmt, require,
//       dynamic, require_resolve, at, at_conditional,
//       url, composes, html_manifest, internal,
//   };
// ============================================================================

/// 导入类型 - 对应 Bun ImportKind
public enum ImportKind {
    | EntryPointRun        // bun run 入口点
    | EntryPointBuild      // bun build 入口点
    | Stmt                 // ES6 import/re-export 语句
    | Require              // require() 调用
    | Dynamic              // import() 动态导入
    | RequireResolve       // require.resolve() 调用
    | At                   // CSS @import 规则
    | AtConditional        // CSS @import 带条件
    | Url                  // CSS url() token
    | Composes             // CSS composes 属性
    | HtmlManifest         // HTML import manifest
    | Internal             // 内部导入

    /// 获取标签
    /// 对应 Bun ImportKind.label()
    public func label(): String {
        match (this) {
            case EntryPointRun => "entry-point-run"
            case EntryPointBuild => "entry-point-build"
            case Stmt => "import-statement"
            case Require => "require-call"
            case Dynamic => "dynamic-import"
            case RequireResolve => "require-resolve"
            case At => "import-rule"
            case AtConditional => "import-rule-conditional"
            case Url => "url-token"
            case Composes => "composes"
            case HtmlManifest => "html_manifest"
            case Internal => "internal"
        }
    }

    /// 获取错误标签
    /// 对应 Bun ImportKind.errorLabel()
    public func errorLabel(): String {
        match (this) {
            case EntryPointRun => "entry point (run)"
            case EntryPointBuild => "entry point (build)"
            case Stmt => "import"
            case Require => "require()"
            case Dynamic => "import()"
            case RequireResolve => "require.resolve()"
            case At => "@import"
            case AtConditional => "@import"
            case Url => "url()"
            case Composes => "composes"
            case HtmlManifest => "HTML import"
            case Internal => "<bun internal>"
        }
    }

    /// 是否为 CommonJS 导入
    /// 对应 Bun ImportKind.isCommonJS()
    public func isCommonJS(): Bool {
        match (this) {
            case Require => true
            case RequireResolve => true
            case _ => false
        }
    }

    /// 是否来自 CSS
    /// 对应 Bun ImportKind.isFromCSS()
    public func isFromCSS(): Bool {
        match (this) {
            case AtConditional => true
            case At => true
            case Url => true
            case Composes => true
            case _ => false
        }
    }
}

// ============================================================================
// ImportTag - 导入标签
// 严格翻译自: import_record.zig - ImportRecord.Tag
//   pub const Tag = enum { none, bun, builtin, runtime, macro,
//                          bake_resolve_to_ssr_graph, tailwind };
// ============================================================================

/// 导入标签 - 对应 Bun ImportRecord.Tag
public enum ImportTag {
    | None
    | Bun
    | Builtin
    | Runtime
    | Macro
    | BakeResolveToSSRGraph
    | Tailwind
    | this
}

    /// 是否为内部导入
    /// 对应 Bun ImportRecord.Tag.isInternal()
    public func isInternal(): Bool {
        match (this) {
            case Runtime => true
            case Macro => true
            case BakeResolveToSSRGraph => true
            case Tailwind => true
            case _ => false
        }
    }
}

// ============================================================================
// ImportRecordFlags - 导入记录标志
// 严格翻译自: import_record.zig - ImportRecord.Flags
//   pub const Flags = packed struct(u16) {
//       handles_import_errors: bool = false,
//       is_internal: bool = false,
//       is_unused: bool = false,
//       ...
//   };
// ============================================================================

/// 导入记录标志 - 对应 Bun ImportRecord.Flags
public class ImportRecordFlags {
    /// try { require('x') } catch { handle } - 不生成错误
    public var handlesImportErrors: Bool
    /// 是否为内部导入
    public var isInternal: Bool
    /// 是否未使用 (TypeScript 类型导入可能被标记)
    public var isUnused: Bool
    /// 是否包含 * as ns 语法
    public var containsImportStar: Bool
    /// 是否包含 default 别名
    public var containsDefaultAlias: Bool
    /// 是否包含 es_module 别名
    public var containsEsModuleAlias: Bool
    /// 是否调用运行时 reExport 函数
    public var callsRuntimeReExportFn: Bool
    /// 是否在 try 体内
    public var isInsideTryBody: Bool
    /// 是否原本是 bare import
    public var wasOriginallyBareImport: Bool
    /// 是否原本是 require
    public var wasOriginallyRequire: Bool
    /// 是否由 macro 注入
    public var wasInjectedByMacro: Bool
    /// 是否可移除的无副作用外部导入
    public var isExternalWithoutSideEffects: Bool
    /// 是否在路径中打印命名空间
    public var printNamespaceInPath: Bool
    /// 是否包装为 ESM
    public var wrapWithToEsm: Bool
    /// 是否包装为 CommonJS
    public var wrapWithToCommonjs: Bool

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
        wrapWithToCommonjs = false
    }
}

// ============================================================================
// ImportRecord - 导入记录
// 严格翻译自: import_record.zig - ImportRecord
//   pub const ImportRecord = struct {
//       range: logger.Range,
//       path: fs.Path,
//       kind: ImportKind,
//       tag: Tag = .none,
//       ...
//   };
// ============================================================================

/// 导入记录 - 对应 Bun ImportRecord
/// 记录源代码中的每一个 import/require 语句
public class ImportRecord {
    /// 源代码范围
    public var rangeStart: Int64
    public var rangeLen: Int64
    /// 解析后的路径
    public var path: String
    /// 导入类型
    public var kind: ImportKind
    /// 导入标签
    public var tag: ImportTag
    /// 加载器
    public var loader: String
    /// 源索引
    public var sourceIndex: Int64
    /// 原始导入路径 (解析前的)
    public var originalPath: String
    /// 标志位
    public var flags: ImportRecordFlags

    public init() {
        rangeStart = 0
        rangeLen = 0
        path = ""
        kind = ImportKind.Stmt
        tag = ImportTag.None
        loader = ""
        sourceIndex = -1
        originalPath = ""
        flags = ImportRecordFlags()
    }

    public init(path: String, kind: ImportKind) {
        rangeStart = 0
        rangeLen = 0
        this.path = path
        this.kind = kind
        tag = ImportTag.None
        loader = ""
        sourceIndex = -1
        originalPath = path
        flags = ImportRecordFlags()
    }

    /// 打印模式
    /// 对应 Bun ImportRecord.PrintMode
    public enum PrintMode {
        | Normal
        | ImportPath
        | Css
        | NapiModule
    }
}
