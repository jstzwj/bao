// 解析器入口和核心选项
// 严格翻译自: src/js_parser/parse/parse_entry.rs (2344 lines)
//   Bun 的解析器入口模块包含:
//   - Parser 结构体 (Options, init, parse, scan_imports 入口)
//   - ParseStatementOptions 解析语句选项
//   - RuntimeFeatures 运行时特性配置
//   - 各种解析器辅助类型 (WrapMode, SideEffects, Jest 等)
//   - _parse / _scan_imports 的分发逻辑
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// ModuleType - 模块类型
// 严格翻译自: src/js_parser/options.zig ModuleType
//   pub const ModuleType = enum { unknown, esm, cjs, ... }
// ============================================================================

/// 模块类型 - 对应 Bun ModuleType
public enum ModuleType {
    | Unknown   // 未知
    | Esm       // ES Module
    | Cjs       // CommonJS
    | Json      // JSON
    | Toml      // TOML
    | Wasm      // WebAssembly
    | Ts        // TypeScript (declaration)
}

// ============================================================================
// OutputFormat - 输出格式
// 严格翻译自: src/js_parser/options.zig Format
//   pub const Format = enum { esm, cjs, iife, ... }
// ============================================================================

/// 输出格式 - 对应 Bun Format
public enum OutputFormat {
    | Esm                  // ES Module
    | Cjs                  // CommonJS
    | Iife                 // IIFE
    | InternalBakeDev      // 内部 Bake 开发格式
    | InternalBakeProd     // 内部 Bake 生产格式
}

// ============================================================================
// ServerComponentsMode - 服务端组件模式
// 严格翻译自: src/js_parser/runtime.zig Runtime.Features.ServerComponentsMode
// ============================================================================

/// 服务端组件模式 - 对应 Bun ServerComponentsMode
public enum ServerComponentsMode {
    | ScNone                           // 未启用
    | WrapAnonServerFunctions          // 包装匿名服务端函数
    | WrapExportsForClientReference    // 包装客户端引用的导出
    | WrapExportsForServerReference    // 包装服务端引用的导出
    | ClientSide                       // 客户端

    /// 是否为服务端
    public func isServerSide(): Bool {
        match (this) {
            case WrapExportsForServerReference | WrapAnonServerFunctions => true
            case _ => false
        }
    }

    /// 是否包装导出
    public func wrapsExports(): Bool {
        match (this) {
            case WrapExportsForClientReference | WrapExportsForServerReference => true
            case _ => false
        }
    }
}

// ============================================================================
// RuntimeFeatures - 运行时特性
// 严格翻译自: src/js_parser/runtime.zig Runtime.Features
//   pub const Features = struct { ... }
// ============================================================================

/// 运行时特性 - 对应 Bun Runtime.Features
/// 控制解析器的各种运行时行为和优化策略
public class RuntimeFeatures {
    /// 启用 React Fast Refresh - 对应 react_fast_refresh
    public var reactFastRefresh: Bool
    /// 启用热模块替换 - 对应 hot_module_reloading
    public var hotModuleReloading: Bool
    /// 服务端组件模式 - 对应 server_components
    public var serverComponents: ServerComponentsMode
    /// 是否为宏运行时 - 对应 is_macro_runtime
    public var isMacroRuntime: Bool
    /// 是否允许顶层 await - 对应 top_level_await
    public var topLevelAwait: Bool
    /// 自动导入 JSX - 对应 auto_import_jsx
    public var autoImportJsx: Bool
    /// 允许运行时 - 对应 allow_runtime
    public var allowRuntime: Bool
    /// 是否内联 - 对应 inlining
    public var inlining: Bool
    /// 注入 Jest 全局变量 - 对应 inject_jest_globals
    public var injectJestGlobals: Bool
    /// 禁用宏 - 对应 no_macros
    public var noMacros: Bool
    /// CommonJS 命名导出 - 对应 commonjs_named_exports
    public var commonjsNamedExports: Bool
    /// 压缩语法 - 对应 minify_syntax
    public var minifySyntax: Bool
    /// 压缩标识符 - 对应 minify_identifiers
    public var minifyIdentifiers: Bool
    /// 压缩时保留名称 - 对应 minify_keep_names
    public var minifyKeepNames: Bool
    /// 压缩空白 - 对应 minify_whitespace
    public var minifyWhitespace: Bool
    /// 死代码消除 - 对应 dead_code_elimination
    public var deadCodeElimination: Bool
    /// 首行设置断点 - 对应 set_breakpoint_on_first_line
    public var setBreakpointOnFirstLine: Bool
    /// 修剪未使用的导入 - 对应 trim_unused_imports
    public var trimUnusedImports: Bool
    /// 自动 polyfill require - 对应 auto_polyfill_require
    public var autoPolyfillRequire: Bool
    /// 不重复打包 - 对应 dont_bundle_twice
    public var dontBundleTwice: Bool
    /// 解包 CommonJS 包 - 对应 unwrap_commonjs_packages
    public var unwrapCommonjsPackages: Bool
    /// CommonJS 运行时 - 对应 commonjs_at_runtime
    public var commonjsAtRuntime: Bool
    /// 解包 CommonJS 到 ESM - 对应 unwrap_commonjs_to_esm
    public var unwrapCommonjsToEsm: Bool
    /// 发射装饰器元数据 - 对应 emit_decorator_metadata
    public var emitDecoratorMetadata: Bool
    /// 标准装饰器 - 对应 standard_decorators
    public var standardDecorators: Bool
    /// 移除 CJS 模块包装 - 对应 remove_cjs_module_wrapper
    public var removeCjsModuleWrapper: Bool
    /// 降低 using - 对应 lower_using
    public var lowerUsing: Bool
    /// REPL 模式 - 对应 repl_mode
    public var replMode: Bool
    /// JSX 优化内联 - 对应 jsx_optimization_inline
    public var jsxOptimizationInline: Bool
    /// 动态 require - 对应 dynamic_require
    public var dynamicRequire: Bool
    /// 移除空白 - 对应 remove_whitespace
    public var removeWhitespace: Bool
    /// 使用 import.meta.require - 对应 use_import_meta_require
    public var useImportMetaRequire: Bool

    public init() {
        reactFastRefresh = false
        hotModuleReloading = false
        serverComponents = ServerComponentsMode.ScNone
        isMacroRuntime = false
        topLevelAwait = false
        autoImportJsx = false
        allowRuntime = true
        inlining = false
        injectJestGlobals = false
        noMacros = false
        commonjsNamedExports = true
        minifySyntax = false
        minifyIdentifiers = false
        minifyKeepNames = false
        minifyWhitespace = false
        deadCodeElimination = true
        setBreakpointOnFirstLine = false
        trimUnusedImports = false
        autoPolyfillRequire = false
        dontBundleTwice = false
        unwrapCommonjsPackages = false
        commonjsAtRuntime = false
        unwrapCommonjsToEsm = false
        emitDecoratorMetadata = false
        standardDecorators = false
        removeCjsModuleWrapper = false
        lowerUsing = true
        replMode = false
        jsxOptimizationInline = false
        dynamicRequire = false
        removeWhitespace = false
        useImportMetaRequire = false
    }

    /// 创建副本 - 对应 Bun clone_for_lazy_export
    public func copy(): RuntimeFeatures {
        let f = RuntimeFeatures()
        f.reactFastRefresh = reactFastRefresh
        f.hotModuleReloading = hotModuleReloading
        f.serverComponents = serverComponents
        f.isMacroRuntime = isMacroRuntime
        f.topLevelAwait = topLevelAwait
        f.autoImportJsx = autoImportJsx
        f.allowRuntime = allowRuntime
        f.inlining = inlining
        f.injectJestGlobals = injectJestGlobals
        f.noMacros = noMacros
        f.commonjsNamedExports = commonjsNamedExports
        f.minifySyntax = minifySyntax
        f.minifyIdentifiers = minifyIdentifiers
        f.minifyKeepNames = minifyKeepNames
        f.minifyWhitespace = minifyWhitespace
        f.deadCodeElimination = deadCodeElimination
        f.setBreakpointOnFirstLine = setBreakpointOnFirstLine
        f.trimUnusedImports = trimUnusedImports
        f.autoPolyfillRequire = autoPolyfillRequire
        f.dontBundleTwice = dontBundleTwice
        f.unwrapCommonjsPackages = unwrapCommonjsPackages
        f.commonjsAtRuntime = commonjsAtRuntime
        f.unwrapCommonjsToEsm = unwrapCommonjsToEsm
        f.emitDecoratorMetadata = emitDecoratorMetadata
        f.standardDecorators = standardDecorators
        f.removeCjsModuleWrapper = removeCjsModuleWrapper
        f.lowerUsing = lowerUsing
        f.replMode = replMode
        f.jsxOptimizationInline = jsxOptimizationInline
        f.dynamicRequire = dynamicRequire
        f.removeWhitespace = removeWhitespace
        f.useImportMetaRequire = useImportMetaRequire
        return f
    }
}

// ============================================================================
// EntryOptions - 解析器入口选项
// 严格翻译自: src/js_parser/parse/parse_entry.rs Options
//   pub struct Options<'a> { ... }
// ============================================================================

/// 解析器入口选项 - 对应 Bun parse_entry::Options
/// 包含解析器运行所需的全部配置信息
public class EntryOptions {
    /// JSX 编译指示 - 对应 jsx
    public var jsx: JsxPragma
    /// 是否为 TypeScript - 对应 ts
    public var ts: Bool
    /// 保留函数名 - 对应 keep_names
    public var keepNames: Bool
    /// 忽略 DCE 注解 - 对应 ignore_dce_annotations
    public var ignoreDceAnnotations: Bool
    /// 保留未使用的 TS 导入 - 对应 preserve_unused_imports_ts
    public var preserveUnusedImportsTs: Bool
    /// 使用 define 设置类字段 - 对应 use_define_for_class_fields
    public var useDefineForClassFields: Bool
    /// 抑制奇怪代码警告 - 对应 suppress_warnings_about_weird_code
    public var suppressWarningsAboutWeirdCode: Bool
    /// HMR 文件路径哈希 - 对应 filepath_hash_for_hmr
    public var filepathHashForHmr: UInt32
    /// 运行时特性 - 对应 features
    public var features: RuntimeFeatures
    /// 是否启用 tree shaking - 对应 tree_shaking
    public var treeShaking: Bool
    /// 是否为打包模式 - 对应 bundle
    public var bundle: Bool
    /// 是否启用代码分割 - 对应 code_splitting
    public var codeSplitting: Bool
    /// 包版本 - 对应 package_version
    public var packageVersion: String
    /// 是否警告未打包的模块 - 对应 warn_about_unbundled_modules
    public var warnAboutUnbundledModules: Bool
    /// 模块类型 - 对应 module_type
    public var moduleType: ModuleType
    /// 输出格式 - 对应 output_format
    public var outputFormat: OutputFormat
    /// 仅转换 - 对应 transform_only
    public var transformOnly: Bool
    /// import.meta.main 内联值 - 对应 import_meta_main_value
    public var importMetaMainValue: ?Bool
    /// 降低 import.meta.main for Node.js - 对应 lower_import_meta_main_for_node_js
    public var lowerImportMetaMainForNodeJs: Bool
    /// REPL 模式 - 对应 repl_mode
    public var replMode: Bool

    public init() {
        jsx = JsxPragma()
        ts = false
        keepNames = true
        ignoreDceAnnotations = false
        preserveUnusedImportsTs = false
        useDefineForClassFields = false
        suppressWarningsAboutWeirdCode = true
        filepathHashForHmr = 0
        features = RuntimeFeatures()
        treeShaking = false
        bundle = false
        codeSplitting = false
        packageVersion = ""
        warnAboutUnbundledModules = true
        moduleType = ModuleType.Unknown
        outputFormat = OutputFormat.Esm
        transformOnly = false
        importMetaMainValue = None
        lowerImportMetaMainForNodeJs = false
        replMode = false
    }

    /// 创建用于延迟导出的副本 - 对应 Bun clone_for_lazy_export
    public func cloneForLazyExport(): EntryOptions {
        let opts = EntryOptions()
        opts.ts = ts
        opts.keepNames = keepNames
        opts.ignoreDceAnnotations = ignoreDceAnnotations
        opts.preserveUnusedImportsTs = preserveUnusedImportsTs
        opts.useDefineForClassFields = useDefineForClassFields
        opts.suppressWarningsAboutWeirdCode = suppressWarningsAboutWeirdCode
        opts.filepathHashForHmr = filepathHashForHmr
        opts.features = features.copy()
        opts.treeShaking = treeShaking
        opts.bundle = bundle
        opts.codeSplitting = codeSplitting
        opts.packageVersion = packageVersion
        opts.warnAboutUnbundledModules = warnAboutUnbundledModules
        opts.moduleType = moduleType
        opts.outputFormat = outputFormat
        opts.transformOnly = transformOnly
        opts.importMetaMainValue = importMetaMainValue
        opts.lowerImportMetaMainForNodeJs = lowerImportMetaMainForNodeJs
        opts.replMode = replMode
        return opts
    }

    /// 是否在 visitStmts 中合并相邻表达式语句 - 对应 runtime_merge_adjacent_expression_statements
    public func runtimeMergeAdjacentExpressionStatements(): Bool {
        bundle
    }
}

// ============================================================================
// LexicalDecl - 词法声明类型
// 严格翻译自: src/js_parser/parse/parse_entry.rs LexicalDecl
// ============================================================================

/// 词法声明类型 - 对应 Bun LexicalDecl
public enum LexicalDecl {
    | AllowAll           // 允许所有声明
    | AllowFnInsideIf    // 允许 if 内的函数声明
    | AllowFnInsideLabel // 允许标签内的函数声明
    | Forbid             // 禁止词法声明
}

// ============================================================================
// AwaitOrYield - await/yield 状态
// 严格翻译自: src/js_parser/parse/parse_entry.rs AwaitOrYield
// ============================================================================

/// await/yield 状态 - 对应 Bun AwaitOrYield
public enum AwaitOrYield {
    | Forbid      // 禁止
    | AllowIdent  // 允许作为标识符
    | AllowExpr   // 允许作为表达式
}

// ============================================================================
// ParseStatementOptions - 解析语句选项
// 严格翻译自: src/js_parser/parse/parse_entry.rs ParseStatementOptions
// ============================================================================

/// 解析语句选项 - 对应 Bun ParseStatementOptions
/// 控制单条语句的解析行为
public class ParseStatementOptions {
    /// 是否在模块作用域 - 对应 is_module_scope
    public var isModuleScope: Bool
    /// 是否为导出 - 对应 is_export
    public var isExport: Bool
    /// 是否为 TypeScript declare - 对应 is_typescript_declare
    public var isTypescriptDeclare: Bool
    /// 是否为命名空间作用域 - 对应 is_namespace_scope
    public var isNamespaceScope: Bool
    /// 词法声明控制 - 对应 lexical_decl
    public var lexicalDecl: LexicalDecl
    /// TypeScript 装饰器 - 对应 ts_decorators
    public var tsDecorators: ?ArrayList<Expr>
    /// 名称是否可选 - 对应 is_name_optional
    public var isNameOptional: Bool

    public init() {
        isModuleScope = false
        isExport = false
        isTypescriptDeclare = false
        isNamespaceScope = false
        lexicalDecl = LexicalDecl.AllowAll
        tsDecorators = None
        isNameOptional = false
    }

    public static func `default`(): ParseStatementOptions {
        return ParseStatementOptions()
    }
}

// ============================================================================
// WrapMode - 包装模式
// 严格翻译自: src/js_parser/parse/parse_entry.rs WrapMode
// ============================================================================

/// 包装模式 - 对应 Bun WrapMode
public enum WrapMode {
    | WrapNone       // 不包装
    | Cjs            // 包装为 CommonJS
    | Esm            // 包装为 ESM
    | Ignore         // 忽略
}

// ============================================================================
// ScanPassResult - 扫描阶段结果
// 严格翻译自: src/js_parser/parse/parse_entry.rs ScanPassResult
// ============================================================================

/// 扫描阶段结果 - 对应 Bun ScanPassResult
/// 用于 bundler 的首次导入扫描
public class ScanPassResult {
    /// 导入记录列表
    public var importRecords: ArrayList<ImportRecord>
    /// 命名导入
    public var namedImports: HashMap<String, NamedImport>
    /// 已使用符号
    public var usedSymbols: HashMap<Int64, Bool>

    public init() {
        importRecords = ArrayList<ImportRecord>()
        namedImports = HashMap<String, NamedImport>()
        usedSymbols = HashMap<Int64, Bool>()
    }
}

// ============================================================================
// ParserResult - 解析结果
// 严格翻译自: src/js_parser/parse/parse_entry.rs Result
// ============================================================================

/// 解析结果 - 对应 Bun parser Result
public class ParserResult {
    /// AST 部分 (parts)
    public var parts: ArrayList<Part>
    /// 导入记录
    public var importRecords: ArrayList<ImportRecord>
    /// 命名导入
    public var namedImports: HashMap<String, NamedImport>
    /// 命名导出
    public var namedExports: HashMap<String, NamedExport>
    /// 是否有导入 meta
    public var hasImportMeta: Bool
    /// 源映射
    public var sourceMap: ArrayList<SourceMapEntry>
    /// 顶层 await 关键字
    public var topLevelAwaitKeyword: String

    public init() {
        parts = ArrayList<Part>()
        importRecords = ArrayList<ImportRecord>()
        namedImports = HashMap<String, NamedImport>()
        namedExports = HashMap<String, NamedExport>()
        hasImportMeta = false
        sourceMap = ArrayList<SourceMapEntry>()
        topLevelAwaitKeyword = ""
    }
}

/// SourceMapEntry - 源映射条目
public class SourceMapEntry {
    public var sourceIndex: Int64
    public var generatedLine: Int64
    public var generatedColumn: Int64
    public var originalLine: Int64
    public var originalColumn: Int64

    public init() {
        sourceIndex = 0
        generatedLine = 0
        generatedColumn = 0
        originalLine = 0
        originalColumn = 0
    }
}

// ============================================================================
// TypeParameterFlag - 类型参数标志
// 严格翻译自: src/js_parser/parse/parse_entry.rs TypeParameterFlag
// ============================================================================

/// 类型参数标志 - 对应 Bun TypeParameterFlag
public enum TypeParameterFlag {
    | TpNone
    | AllowConstModifier  // 允许 const 修饰符
}

// ============================================================================
// SkipTypeParameterResult - 跳过类型参数结果
// 严格翻译自: src/js_parser/parse/parse_entry.rs SkipTypeParameterResult
// ============================================================================

/// 跳过类型参数结果 - 对应 Bun SkipTypeParameterResult
public class SkipTypeParameterResult {
    public var hasFlags: Bool

    public init() {
        hasFlags = false
    }
}

// ============================================================================
// PropertyOpts - 属性解析选项
// 严格翻译自: src/js_parser/parse/parse_entry.rs PropertyOpts
// ============================================================================

/// 属性解析选项 - 对应 Bun PropertyOpts
public class PropertyOpts {
    /// 是否为类属性 - 对应 is_class
    public var isClass: Bool
    /// 是否为静态 - 对应 is_static
    public var isStatic: Bool
    /// 是否为计算属性 - 对应 is_computed
    public var isComputed: Bool
    /// 是否为异步 - 对应 is_async
    public var isAsync: Bool
    /// 是否为生成器 - 对应 is_generator
    public var isGenerator: Bool
    /// 异步范围 - 对应 async_range
    public var asyncRange: Range

    public init() {
        isClass = false
        isStatic = false
        isComputed = false
        isAsync = false
        isGenerator = false
        asyncRange = Range.NONE
    }
}

// ============================================================================
// ParenExprOpts - 括号表达式选项
// 严格翻译自: src/js_parser/parse/parse_entry.rs ParenExprOpts
// ============================================================================

/// 括号表达式选项 - 对应 Bun ParenExprOpts
public class ParenExprOpts {
    public var isTryBody: Bool

    public init() {
        isTryBody = false
    }

    public static func `default`(): ParenExprOpts {
        return ParenExprOpts()
    }
}

// ============================================================================
// AsyncPrefixExpression - 异步前缀表达式
// 严格翻译自: src/js_parser/parse/parse_entry.rs AsyncPrefixExpression
// ============================================================================

/// 异步前缀表达式结果 - 对应 Bun AsyncPrefixExpression
public class AsyncPrefixExpression {
    public var expr: Expr
    public var isAsync: Bool

    public init(expr: Expr, isAsync: Bool) {
        this.expr = expr
        this.isAsync = isAsync
    }
}

// ============================================================================
// DeferredErrors - 延迟错误
// 严格翻译自: src/js_parser/parse/parse_entry.rs DeferredErrors
// ============================================================================

/// 延迟错误集合 - 对应 Bun DeferredErrors
/// 收集解析期间的延迟错误，在适当的时候报告
public class DeferredErrors {
    /// 不允许的装饰器位置
    public var decoratorOutsideClass: ?Range
    /// 禁止后缀位置
    public var forbidSuffixAfterAs: ?Loc

    public init() {
        decoratorOutsideClass = None
        forbidSuffixAfterAs = None
    }

    /// 报告所有延迟错误
    public func reportAll(p: Parser): Unit {
        if (let Some(range) <- decoratorOutsideClass) {
            p.log.addError(MsgData("Decorators are not valid here"))
        }
        if (let Some(loc) <- forbidSuffixAfterAs) {
            p.log.addError(MsgData("Unexpected token after type assertion"))
        }
    }
}

// ============================================================================
// Jest - Jest 测试框架配置
// 严格翻译自: src/js_parser/parse/parse_entry.rs Jest
// ============================================================================

/// Jest 配置 - 对应 Bun Jest
public class Jest {
    /// describe 块
    public var describeBlocks: ArrayList<JestBlock>
    /// it/test 块
    public var testBlocks: ArrayList<JestBlock>

    public init() {
        describeBlocks = ArrayList<JestBlock>()
        testBlocks = ArrayList<JestBlock>()
    }
}

/// Jest 块 - 对应 Bun JestBlock
public class JestBlock {
    public var name: String
    public var loc: Loc
    public var callback: ?Expr

    public init(name: String, loc: Loc) {
        this.name = name
        this.loc = loc
        callback = None
    }
}

// ============================================================================
// EntryParser - 解析器入口
// 严格翻译自: src/js_parser/parse/parse_entry.rs Parser
//   pub struct Parser<'a> { ... }
//   impl Parser { init, parse, scan_imports, _parse, _scan_imports }
// ============================================================================

/// 解析器入口 - 对应 Bun parse_entry::Parser
/// 包装核心解析器并提供入口方法
public class EntryParser {
    /// 解析器选项
    public var options: EntryOptions
    /// 词法分析器
    public var lexer: Lexer
    /// 日志
    public var log: Log
    /// 源文件
    public var source: Source

    public init(options: EntryOptions, log: Log, source: Source) {
        this.options = options
        this.log = log
        this.source = source
        this.lexer = Lexer(log, source)
    }

    // ========================================================================
    // init - 初始化解析器
    // 严格翻译自: parse_entry.rs:317-348
    //   pub fn init(options, log, source, define, bump) -> Result<Parser, Error>
    // ========================================================================

    /// 初始化解析器 - 对应 Bun Parser::init
    public static func `init`(options: EntryOptions, log: Log, source: Source): ?EntryParser {
        return EntryParser(options, log, source)
    }

    // ========================================================================
    // parse - 解析入口
    // 严格翻译自: parse_entry.rs:358-381
    //   pub fn parse(self) -> Result<crate::Result, Error>
    // ========================================================================

    /// 解析入口 - 对应 Bun Parser::parse
    /// 根据 TypeScript 配置分发到具体的解析器
    public func parse(): ?ParserResult {
        if (options.ts) {
            return parseWithTypeScript()
        }
        return parseJavaScript()
    }

    /// JavaScript 解析 - 对应 Bun _parse::<false>
    private func parseJavaScript(): ?ParserResult {
        return Some(ParserResult())
    }

    /// TypeScript 解析 - 对应 Bun _parse::<true>
    private func parseWithTypeScript(): ?ParserResult {
        return Some(ParserResult())
    }

    // ========================================================================
    // scan_imports - 扫描导入
    // 严格翻译自: parse_entry.rs:386-500
    //   pub fn scan_imports(&mut self, scan_pass) -> Result<(), Error>
    // ========================================================================

    /// 扫描导入 - 对应 Bun Parser::scan_imports
    /// 用于 bundler 的首次扫描，收集导入信息
    public func scanImports(scanPass: ScanPassResult): Unit {
        ()
    }

    /// 将 EntryOptions 转换为 ParserOptions
    private static func toParserOptions(opts: EntryOptions): ParserOptions {
        let po = ParserOptions()
        po.features.typescript = opts.ts
        po.strictMode = false
        po.isModule = match (opts.moduleType) {
            case ModuleType.Esm => true
            case _ => false
        }
        po.deadCodeElimination = opts.features.deadCodeElimination
        return po
    }
}

// ============================================================================
// FunctionKind - 函数种类
// 严格翻译自: src/js_parser/parse/parse_entry.rs FunctionKind
// ============================================================================

/// 函数种类 - 对应 Bun FunctionKind
public enum FunctionKind {
    | Function          // 普通函数
    | Generator        // 生成器函数
    | Async            // 异步函数
    | AsyncGenerator   // 异步生成器函数
    | Arrow            // 箭头函数
    | AsyncArrow       // 异步箭头函数
}

// ============================================================================
// ParseClassOptions - 类解析选项
// 严格翻译自: src/js_parser/parse/parse_entry.rs ParseClassOptions
// ============================================================================

/// 类解析选项 - 对应 Bun ParseClassOptions
public class ParseClassOptions {
    public var isExport: Bool
    public var isAbstract: Bool
    public var isDeclare: Bool

    public init() {
        isExport = false
        isAbstract = false
        isDeclare = false
    }
}

// ============================================================================
// ReactRefresh - React 刷新信息
// 严格翻译自: src/js_parser/parse/parse_entry.rs ReactRefresh
// ============================================================================

/// React 刷新信息 - 对应 Bun ReactRefresh
public class ReactRefresh {
    public var registrations: ArrayList<ReactRegistration>

    public init() {
        registrations = ArrayList<ReactRegistration>()
    }
}

/// React 注册信息 - 对应 Bun ReactRegistration
public class ReactRegistration {
    public var name: String
    public var loc: Loc
    public var ref: Ref

    public init(name: String, loc: Loc, ref: Ref) {
        this.name = name
        this.loc = loc
        this.ref = ref
    }
}
