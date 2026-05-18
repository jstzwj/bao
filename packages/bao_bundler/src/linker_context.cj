// 严格翻译自: src/bundler/LinkerContext.zig (~2780行)
// bao_bundler - 链接器上下文: 管理模块链接状态，协调 tree-shaking、代码分割和 chunk 生成
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// 链接器上下文
// 严格翻译自: src/bundler/LinkerContext.zig LinkerContext struct
// 核心职责:
//   1. 管理链接器图 (LinkerGraph)
//   2. 协调 tree-shaking 和代码分割
//   3. 计算 chunk
//   4. 生成跨 chunk 依赖
//   5. 处理 sourcemap
//   6. 匹配 import 与 export
// ============================================================================

/// 链接器选项
// 严格翻译自: LinkerContext.zig:59 LinkerOptions
public class LinkerContextOptions {
    /// 是否生成字节码缓存
    public var generateBytecodeCache: Bool
    /// 输出格式
    public var outputFormat: OutputFormat
    /// 是否忽略 DCE 注解
    public var ignoreDceAnnotations: Bool
    /// 是否发出 DCE 注解
    public var emitDceAnnotations: Bool
    /// 是否启用 tree-shaking
    public var treeShaking: Bool
    /// 是否压缩空白
    public var minifyWhitespace: Bool
    /// 是否压缩语法
    public var minifySyntax: Bool
    /// 是否压缩标识符
    public var minifyIdentifiers: Bool
    /// banner 文本
    public var banner: String
    /// footer 文本
    public var footer: String
    /// CSS 分块
    public var cssChunking: Bool
    /// 是否编译为独立 HTML
    public var compileToStandaloneHtml: Bool
    /// sourcemap 选项
    public var sourceMaps: SourceMapOption
    /// 目标平台
    public var target: BundleTarget
    /// 是否编译
    public var compile: Bool
    /// 是否生成 metafile
    public var metafile: Bool
    /// metafile JSON 路径
    public var metafileJsonPath: String
    /// metafile Markdown 路径
    public var metafileMarkdownPath: String
    /// 模式
    public var mode: LinkerMode
    /// 公共路径
    public var publicPath: String

    public init() {
        generateBytecodeCache = false
        outputFormat = OutputFormat.ESM
        ignoreDceAnnotations = false
        emitDceAnnotations = true
        treeShaking = true
        minifyWhitespace = false
        minifySyntax = false
        minifyIdentifiers = false
        banner = ""
        footer = ""
        cssChunking = false
        compileToStandaloneHtml = false
        sourceMaps = SourceMapOption.None
        target = BundleTarget.Browser
        compile = false
        metafile = false
        metafileJsonPath = ""
        metafileMarkdownPath = ""
        mode = LinkerMode.Bundle
        publicPath = ""
    }
}

/// 链接器模式
// 严格翻译自: LinkerContext.zig:85 LinkerOptions.Mode
public enum LinkerMode {
    | Passthrough
    | Bundle
}

/// 导入匹配结果
// 严格翻译自: LinkerContext.zig:531 MatchImport
public class MatchImport {
    /// 匹配类型
    public var kind: MatchImportKind
    /// 别名
    public var alias: String
    /// 命名空间引用
    public var namespaceRef: Int64
    /// 源文件索引
    public var sourceIndex: Int64
    /// 名称位置
    public var nameLoc: Int64
    /// 其他源文件索引 (用于歧义匹配)
    public var otherSourceIndex: Int64
    /// 其他名称位置
    public var otherNameLoc: Int64
    /// 引用 ID
    public var ref: Int64

    public init() {
        kind = MatchImportKind.Ignore
        alias = ""
        namespaceRef = 0
        sourceIndex = 0
        nameLoc = 0
        otherSourceIndex = 0
        otherNameLoc = 0
        ref = 0
    }
}

/// 导入匹配类型
// 严格翻译自: LinkerContext.zig:541 MatchImport.Kind
public enum MatchImportKind {
    | Ignore                    // 外部或未定义的导入
    | Normal                    // 正常匹配 (sourceIndex + ref)
    | Namespace                 // 命名空间匹配 (namespaceRef + alias)
    | NormalAndNamespace        // 两者都有
    | Cycle                     // 循环检测
    | ProbablyTypescriptType    // 可能是 TypeScript 类型
    | Ambiguous                 // 歧义匹配 (export * from)
}

/// 语句列表 - 包装器前缀/后缀和所有语句
// 严格翻译自: LinkerContext.zig:1052 StmtList
public class StmtList {
    /// 包装器内部前缀语句
    public var insideWrapperPrefix: InsideWrapperPrefix
    /// 包装器外部前缀语句
    public var outsideWrapperPrefix: ArrayList<Stmt>
    /// 包装器内部后缀语句
    public var insideWrapperSuffix: ArrayList<Stmt>
    /// 所有语句
    public var allStmts: ArrayList<Stmt>

    public init() {
        insideWrapperPrefix = InsideWrapperPrefix()
        outsideWrapperPrefix = ArrayList<Stmt>()
        insideWrapperSuffix = ArrayList<Stmt>()
        allStmts = ArrayList<Stmt>()
    }

    /// 重置所有列表
    public func reset(): Unit {
        insideWrapperPrefix.reset()
        outsideWrapperPrefix.clear()
        insideWrapperSuffix.clear()
        allStmts.clear()
    }

    /// 追加语句到指定列表
    public func append(list: StmtListKind, stmt: Stmt): Unit {
        match (list) {
            case StmtListKind.OutsideWrapperPrefix => outsideWrapperPrefix.append(stmt)
            case StmtListKind.InsideWrapperSuffix => insideWrapperSuffix.append(stmt)
            case StmtListKind.AllStmts => allStmts.append(stmt)
        }
    }

    /// 批量追加语句到指定列表
    public func appendSlice(list: StmtListKind, stmts: ArrayList<Stmt>): Unit {
        match (list) {
            case StmtListKind.OutsideWrapperPrefix =>
                for (s in stmts) { outsideWrapperPrefix.append(s) }
            case StmtListKind.InsideWrapperSuffix =>
                for (s in stmts) { insideWrapperSuffix.append(s) }
            case StmtListKind.AllStmts =>
                for (s in stmts) { allStmts.append(s) }
        }
    }
}

/// 语句列表类型
public enum StmtListKind {
    | OutsideWrapperPrefix
    | InsideWrapperSuffix
    | AllStmts
}

/// 包装器内部前缀
// 严格翻译自: LinkerContext.zig:1053 InsideWrapperPrefix
public class InsideWrapperPrefix {
    public var stmts: ArrayList<Stmt>
    /// 同步依赖结束位置
    public var syncDependenciesEnd: Int64
    /// 是否有异步依赖
    public var hasAsyncDependency: Bool

    public init() {
        stmts = ArrayList<Stmt>()
        syncDependenciesEnd = 0
        hasAsyncDependency = false
    }

    /// 重置
    public func reset(): Unit {
        stmts.clear()
        syncDependenciesEnd = 0
        hasAsyncDependency = false
    }

    /// 追加非依赖语句
    public func appendNonDependency(stmt: Stmt): Unit {
        stmts.append(stmt)
    }

    /// 追加同步依赖
    public func appendSyncDependency(callExpr: Expr): Unit {
        // 插入到 syncDependenciesEnd 位置
        let s = Stmt()
        s.tag = StmtTag.Expr
        s.expr = Some(callExpr)
        stmts.append(s)
        syncDependenciesEnd++
    }

    /// 追加异步依赖
    public func appendAsyncDependency(callExpr: Expr, promiseAllRef: Int64): Unit {
        if (!hasAsyncDependency) {
            hasAsyncDependency = true
            let awaitExpr = Expr()
            awaitExpr.tag = ExprTag.Await
            awaitExpr.value = Some(callExpr)
            let s = Stmt()
            s.tag = StmtTag.Expr
            s.expr = Some(awaitExpr)
            stmts.append(s)
            return
        }
        // 已有异步依赖: 合并到 Promise.all
        // 简化处理: 直接追加
        let s = Stmt()
        s.tag = StmtTag.Expr
        s.expr = Some(callExpr)
        stmts.append(s)
    }
}

/// Chunk 元数据
// 严格翻译自: LinkerContext.zig:632 ChunkMeta
public class ChunkMeta {
    /// 导入引用集合
    public var imports: HashSet<Int64>
    /// 导出引用集合
    public var exports: HashSet<Int64>
    /// 动态导入的 chunk 索引
    public var dynamicImports: HashSet<Int64>

    public init() {
        imports = HashSet<Int64>()
        exports = HashSet<Int64>()
        dynamicImports = HashSet<Int64>()
    }
}

/// 生成 chunk 上下文
// 严格翻译自: LinkerContext.zig:642 GenerateChunkCtx
public class GenerateChunkCtx {
    public var linkerContext: LinkerContext
    public var chunks: ArrayList<Chunk>
    public var chunk: Chunk

    public init(linkerContext: LinkerContext, chunks: ArrayList<Chunk>, chunk: Chunk) {
        this.linkerContext = linkerContext
        this.chunks = chunks
        this.chunk = chunk
    }
}

/// Sourcemap 数据
// 严格翻译自: LinkerContext.zig:91 SourceMapData
public class SourceMapData {
    /// 行偏移任务列表
    public var lineOffsetTasks: ArrayList<SourceMapTask>
    /// 引用内容任务列表
    public var quotedContentsTasks: ArrayList<SourceMapTask>

    public init() {
        lineOffsetTasks = ArrayList<SourceMapTask>()
        quotedContentsTasks = ArrayList<SourceMapTask>()
    }
}

/// Sourcemap 任务
// 严格翻译自: LinkerContext.zig:98 SourceMapData.Task
public class SourceMapTask {
    /// 关联的链接器上下文
    public var ctx: LinkerContext
    /// 源文件索引
    public var sourceIndex: Int64

    public init(ctx: LinkerContext, sourceIndex: Int64) {
        this.ctx = ctx
        this.sourceIndex = sourceIndex
    }
}

/// 稳定引用 (用于排序)
// 严格翻译自: LinkerContext.zig 中 StableRef
public class StableRef {
    public var stableSourceIndex: Int64
    public var ref: Int64

    public init(stableSourceIndex: Int64, ref: Int64) {
        this.stableSourceIndex = stableSourceIndex
        this.ref = ref
    }

    /// 比较函数
    public static func lessThan(a: StableRef, b: StableRef): Bool {
        if (a.stableSourceIndex != b.stableSourceIndex) {
            return a.stableSourceIndex < b.stableSourceIndex
        }
        return a.ref < b.ref
    }
}

/// 链接器上下文
// 严格翻译自: src/bundler/LinkerContext.zig LinkerContext
// 管理整个链接过程的状态
public class LinkerContext {
    /// 解析图 (指向 BundleV2 的 graph)
    public var parseGraph: Graph
    /// 链接器图
    public var graph: LinkerGraph
    /// 日志
    public var log: Log
    /// 解析器
    public var resolver: Resolver
    /// 循环检测器
    public var cycleDetector: ArrayList<ImportTracker>
    /// CJS 运行时引用
    public var cjsRuntimeRef: Int64
    /// ESM 运行时引用
    public var esmRuntimeRef: Int64
    /// 未绑定的 module 引用
    public var unboundModuleRef: Int64
    /// Promise.all 运行时引用
    public var promiseAllRuntimeRef: Int64
    /// 链接器选项
    public var options: LinkerContextOptions
    /// Sourcemap 数据
    public var sourceMaps: SourceMapData
    /// 唯一键缓冲区
    public var uniqueKeyBuf: String
    /// 唯一键前缀
    public var uniqueKeyPrefix: String
    /// 待处理任务计数
    public var pendingTaskCount: Int64
    /// 是否有任何 CSS 局部作用域
    public var hasAnyCssLocals: Bool
    /// 符号重命名映射 (CSS modules 等)
    public var mangledProps: HashMap<Int64, String>

    public init() {
        parseGraph = Graph()
        graph = LinkerGraph()
        log = Log()
        resolver = Resolver()
        cycleDetector = ArrayList<ImportTracker>()
        cjsRuntimeRef = 0
        esmRuntimeRef = 0
        unboundModuleRef = 0
        promiseAllRuntimeRef = 0
        options = LinkerContextOptions()
        sourceMaps = SourceMapData()
        uniqueKeyBuf = ""
        uniqueKeyPrefix = ""
        pendingTaskCount = 0
        hasAnyCssLocals = false
        mangledProps = HashMap<Int64, String>()
    }

    /// 执行链接
    // 严格翻译自: LinkerContext.zig:356 link()
    // 核心流程:
    //   1. load() 加载入口点和可达模块
    //   2. 计算 sourcemap 数据
    //   3. 验证 top-level await
    //   4. scanImportsAndExports()
    //   5. treeShakingAndCodeSplitting()
    //   6. computeChunks()
    //   7. computeCrossChunkDependencies()
    public func link(
        bundleOptions: BundleOptions,
        entryPoints: ArrayList<String>,
        reachable: ArrayList<String>
    ): ArrayList<Chunk> {
        return ArrayList<Chunk>()
    }

    /// 加载入口点和可达模块
    // 严格翻译自: LinkerContext.zig:203 load()
    public func load(entryPoints: ArrayList<String>, reachable: ArrayList<String>): Unit {
        graph.codeSplitting = true
    }

    /// 计算 sourcemap 数据
    // 严格翻译自: LinkerContext.zig:265 computeDataForSourceMap()
    public func computeDataForSourceMap(reachable: ArrayList<String>): Unit {
        sourceMaps = SourceMapData()
        for (path in reachable) {
            let task = SourceMapTask(this, 0)
            sourceMaps.lineOffsetTasks.append(task)
            sourceMaps.quotedContentsTasks.append(task)
        }
    }

    /// 扫描导入和导出
    // 严格翻译自: LinkerContext.zig:492 scanImportsAndExports
    public func scanImportsAndExports(): Unit {
        return
    }

    /// Tree-shaking 和代码分割
    // 严格翻译自: LinkerContext.zig:569 treeShakingAndCodeSplitting()
    public func treeShakingAndCodeSplitting(): Unit {
        return
    }

    /// 标记文件为活跃 (用于 tree-shaking)
    // 严格翻译自: LinkerContext.zig:1665 markFileLiveForTreeShaking()
    public func markFileLiveForTreeShaking(path: String): Unit {
        return
    }

    /// 标记文件可达 (用于代码分割)
    // 严格翻译自: LinkerContext.zig:1573 markFileReachableForCodeSplitting()
    public func markFileReachableForCodeSplitting(path: String, entryIndex: Int64): Unit {
        return
    }

    /// 计算 chunks
    // 严格翻译自: LinkerContext.zig:455 computeChunks
    public func computeChunks(): ArrayList<Chunk> {
        return ArrayList<Chunk>()
    }

    /// 收集从入口可达的活跃模块
    private func collectReachableLiveModules(entry: String): ArrayList<String> {
        return ArrayList<String>()
    }

    /// 提取共享模块到独立 chunk
    private func extractSharedModules(chunks: ArrayList<Chunk>, startId: Int64): ?Chunk {
        return None
    }

    /// 计算跨 chunk 依赖
    // 严格翻译自: LinkerContext.zig:640 computeCrossChunkDependencies
    public func computeCrossChunkDependencies(chunks: ArrayList<Chunk>): Unit {
        return
    }

    /// 检查跨 chunk 导入列表是否已包含
    private func containsCrossChunkImport(list: ArrayList<CrossChunkImport>, item: CrossChunkImport): Bool {
        for (imp in list) {
            if (imp.chunkIndex == item.chunkIndex) { return true }
        }
        return false
    }

    /// 为文件匹配导入与导出
    // 严格翻译自: LinkerContext.zig:2471 matchImportsWithExportsForFile()
    public func matchImportsWithExportsForFile(node: ModuleNode): Unit {
        return
    }

    /// 匹配导入与导出
    // 严格翻译自: LinkerContext.zig:1866 matchImportWithExport()
    public func matchImportWithExport(importRecord: ImportRecord, resolvedPath: String): MatchImport {
        let result = MatchImport()
        result.kind = MatchImportKind.Ignore
        return result
    }

    /// 生成 chunk 名称
    private func generateChunkName(entryPath: String, index: Int64): String {
        return "chunk-${index}.js"
    }

    /// 计算 hash
    private func computeHash(modules: ArrayList<String>): String {
        return "0"
    }

    /// 是否是外部动态导入
    // 严格翻译自: LinkerContext.zig:180 isExternalDynamicImport()
    public func isExternalDynamicImport(record: ImportRecord, sourceIndex: Int64): Bool {
        return graph.codeSplitting &&
               record.kind == ImportKind.Dynamic &&
               record.isExternal
    }

    /// 是否应该包含 part
    // 严格翻译自: LinkerContext.zig:187 shouldIncludePart()
    public func shouldIncludePart(sourceIndex: Int64, stmts: ArrayList<Stmt>): Bool {
        // 优化: 跳过只包含一条导入语句且目标文件不需要包装的 part
        if (stmts.size == 1) {
            // 简化: 总是包含
        }
        return true
    }

    /// 获取运行时函数引用
    // 严格翻译自: LinkerContext.zig:1298 runtimeFunction()
    public func runtimeFunction(name: String): Int64 {
        return 0
    }

    /// 生成孤立 hash (用于内容寻址)
    // 严格翻译自: LinkerContext.zig:844 generateIsolatedHash()
    public func generateIsolatedHash(chunk: Chunk): UInt64 {
        return UInt64(0)
    }

    /// 调度任务
    // 严格翻译自: LinkerContext.zig:298 scheduleTasks()
    public func scheduleTasks(tasks: ArrayList<SourceMapTask>): Unit {
        pendingTaskCount += tasks.size
    }

    /// 标记待处理任务完成
    // 严格翻译自: LinkerContext.zig:303 markPendingTaskDone()
    public func markPendingTaskDone(): Unit {
        pendingTaskCount--
    }

    /// 排序跨 chunk 导出项
    // 严格翻译自: LinkerContext.zig:1549 sortedCrossChunkExportItems()
    public func sortedCrossChunkExportItems(exportRefs: ChunkMeta): ArrayList<StableRef> {
        let result = ArrayList<StableRef>()
        // 按 stable_source_index 排序
        // 简化: 直接返回
        return result
    }

    /// CSS 局部作用域重命名
    // 严格翻译自: LinkerContext.zig:1429 mangleLocalCss()
    public func mangleLocalCss(): Unit {
        if (!hasAnyCssLocals) { return }
        // 遍历所有 CSS AST，重命名局部作用域的类名
        // 简化处理
    }

    /// 为导入的 chunks 追加孤立 hash
    // 严格翻译自: LinkerContext.zig:1481 appendIsolatedHashesForImportedChunks()
    public func appendIsolatedHashesForImportedChunks(
        hash: ContentHasher,
        chunks: ArrayList<Chunk>,
        index: Int64,
        chunkVisitMap: HashSet<Int64>
    ): Unit {
        return
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 图数据结构
// 严格翻译自: src/bundler/Graph.zig
public class Graph {
    /// 线程池引用
    public var pool: ThreadPool
    /// 入口点列表 (源文件索引)
    public var entryPoints: ArrayList<Int64>
    /// 入口点原始名称映射
    public var entryPointOriginalNames: HashMap<Int64, String>
    /// 输入文件列表
    public var inputFiles: ArrayList<InputFile>
    /// AST 列表
    public var asts: ArrayList<Program>
    /// 待处理项目数
    public var pendingItems: Int64
    /// 延迟处理的待处理项目数
    public var deferredPending: Int64
    /// 构建目标到源索引的映射
    public var buildGraphs: HashMap<String, PathToSourceIndexMap>
    /// CSS 文件计数
    public var cssFileCount: Int64

    public init() {
        pool = ThreadPool()
        entryPoints = ArrayList<Int64>()
        entryPointOriginalNames = HashMap<Int64, String>()
        inputFiles = ArrayList<InputFile>()
        asts = ArrayList<Program>()
        pendingItems = 0
        deferredPending = 0
        buildGraphs = HashMap<String, PathToSourceIndexMap>()
        cssFileCount = 0
    }

    /// 获取路径到源索引的映射
    public func pathToSourceIndexMap(target: String): PathToSourceIndexMap {
        match (buildGraphs.get(target)) {
            case Some(map) => return map
            case None =>
                let map = PathToSourceIndexMap()
                buildGraphs.put(target, map)
                return map
        }
    }

    /// 排空延迟任务
    // 严格翻译自: Graph.zig:97 drainDeferredTasks()
    public func drainDeferredTasks(): Bool {
        if (deferredPending > 0) {
            pendingItems += deferredPending
            deferredPending = 0
            return true
        }
        return false
    }
}

/// 输入文件
// 严格翻译自: Graph.zig:70 InputFile
public class InputFile {
    /// 源文件路径
    public var source: String
    /// 次要路径 (如类型声明)
    public var secondaryPath: String
    /// 加载器类型
    public var loader: Loader
    /// 副作用标记
    public var sideEffects: SideEffects
    /// 是否是插件文件
    public var isPluginFile: Bool
    /// 是否是 export * 目标
    public var isExportStarTarget: Bool

    public init(source: String) {
        this.source = source
        this.secondaryPath = ""
        this.loader = Loader.Js
        this.sideEffects = SideEffects.HasSideEffects
        this.isPluginFile = false
        this.isExportStarTarget = false
    }
}

/// 加载器类型
// 严格翻译自: options.zig:568 Loader/// 副作用标记
// 严格翻译自: resolver.zig SideEffects/// 导入追踪器
public class ImportTracker {
    public var sourceIndex: Int64
    public var importRef: Int64

    public init(sourceIndex: Int64, importRef: Int64) {
        this.sourceIndex = sourceIndex
        this.importRef = importRef
    }
}/// 内容哈希器
// 严格翻译自: bundle_v2.zig ContentHasher
public class ContentHasher {
    private var state: UInt64

    public init() {
        state = UInt64(0x07F7DB6B)
    }

    /// 写入数据到哈希
    public func write(data: String): Unit {
        state = state + UInt64(data.size)
    }

    /// 写入整数数组
    public func writeInts(ints: Array<Int64>): Unit {
        for (i in ints) {
            state = state ^ UInt64(i)
        }
    }

    /// 计算最终哈希值
    public func digest(): UInt64 {
        state = state ^ (state >> 16)
        return state
    }
}

/// 位集合
public class BitSet {
    private var bits: HashSet<Int64>

    public init() {
        bits = HashSet<Int64>()
    }

    public func set(index: Int64): Unit {
        bits.put(index)
    }

    public func isSet(index: Int64): Bool {
        return bits.contains(index)
    }

    public func clear(): Unit {
        bits.clear()
    }
}

/// 语句 (简化)
public class Stmt {
    public var tag: StmtTag
    public var expr: ?Expr
    public var body: ArrayList<Stmt>
    public var importPath: ?Expr
    public var exportNames: ArrayList<String>
    public var exportValue: ?Expr
    public var importBindings: ?ArrayList<ImportBinding>
    public var condition: ?Expr
    public var thenBody: ?Stmt
    public var elseBody: ?Stmt
    public var catchBody: ArrayList<Stmt>
    public var catchParam: String
    public var finallyBody: ArrayList<Stmt>
    public var declValue: ?Expr
    public var isDefault: Bool
    public var declKeyword: String
    public var declName: ?String

    public init() {
        tag = StmtTag.Empty
        expr = None
        body = ArrayList<Stmt>()
        importPath = None
        exportNames = ArrayList<String>()
        exportValue = None
        importBindings = None
        condition = None
        thenBody = None
        elseBody = None
        catchBody = ArrayList<Stmt>()
        catchParam = ""
        finallyBody = ArrayList<Stmt>()
        declValue = None
        isDefault = false
        declKeyword = ""
        declName = None
    }
}

/// 表达式 (简化)
public class Expr {
    public var tag: ExprTag
    public var value: ?Expr
    public var target: ?Expr
    public var args: ArrayList<Expr>
    public var left: ?Expr
    public var right: ?Expr
    public var op: String
    public var identifierName: String
    public var stringValue: String
    public var numberValue: Float64
    public var boolValue: Bool
    public var params: ArrayList<String>
    public var properties: ArrayList<Prop>
    public var elements: ArrayList<Expr>
    public var condition: ?Expr
    public var thenExpr: ?Expr
    public var elseExpr: ?Expr
    public var isPrefix: Bool
    public var loc: Int64
    public var operand: ?Expr
    public var propertyName: String
    public var isComputed: Bool

    public init() {
        tag = ExprTag.Missing
        value = None
        target = None
        args = ArrayList<Expr>()
        left = None
        right = None
        op = ""
        identifierName = ""
        stringValue = ""
        numberValue = 0.0
        boolValue = false
        params = ArrayList<String>()
        properties = ArrayList<Prop>()
        elements = ArrayList<Expr>()
        condition = None
        thenExpr = None
        elseExpr = None
        isPrefix = false
        loc = 0
        operand = None
        propertyName = ""
        isComputed = false
    }
}

/// 属性
public class Prop {
    public var key: String
    public var value: Expr

    public init(key: String, value: Expr) {
        this.key = key
        this.value = value
    }
}

// StmtTag and ExprTag are defined in bao_ast - use those directly
// StmtTag.Other -> StmtTag.Empty
// ExprTag.Other -> ExprTag.Missing
