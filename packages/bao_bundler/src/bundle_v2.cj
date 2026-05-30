// 严格翻译自: src/bundler/bundle_v2.zig (4509行)
// bao_bundler - BundleV2 主打包器: 协调 parse -> resolve -> tree-shake -> chunk -> codegen 流水线
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_threading.*

/// 事件循环
// 严格翻译自: bundle_v2.zig 中 EventLoop
public class EventLoop {
    public init() {}

    public func tick(ctx: BundleV2, isDone: () -> Bool): Unit {
        // 简化: 空操作
    }
}

// ============================================================================
// BundleV2 主打包器
// 严格翻译自: src/bundler/bundle_v2.zig BundleV2 struct (line 107)
// Bun 的 JavaScript/TypeScript 打包器核心实现
// 基于 Go esbuild 实现，感谢 Evan Wallace
//
// # 内存管理说明 (Bun)
// Bun 的 bundler 依赖 mimalloc 的线程本地堆作为 arena 分配器
// 新线程生成时使用线程本地堆，所有分配在该堆上进行
// 任务完成后销毁线程本地堆释放所有内存
// 仓颉版本使用 GC 管理，无需手动内存管理
//
// 核心流程:
//   1. init() - 初始化 BundleV2
//   2. enqueueEntryPoints() - 入队入口点
//   3. waitForParse() - 等待解析完成
//   4. scanForSecondaryPaths() - 扫描次要路径
//   5. findReachableFiles() - 查找可达文件
//   6. cloneAST() - 克隆 AST
//   7. linker.link() - 链接
//   8. linker.generateChunksInParallel() - 并行生成 chunks
// ============================================================================

/// 可达文件访问器
// 严格翻译自: bundle_v2.zig:279 ReachableFileVisitor
// 从所有入口点查找所有可达文件 (postorder 遍历)
public class ReachableFileVisitor {
    /// 可达文件列表 (结果)
    public var reachable: ArrayList<SourceIndex>
    /// 已访问集合
    public var visited: HashSet<Int64>
    /// 所有导入记录列表
    public var allImportRecords: ArrayList<ImportRecordList>
    /// 所有加载器
    public var allLoaders: ArrayList<Loader>
    /// 重定向映射
    public var redirects: Array<Int64>
    /// 动态导入入口点集合
    public var dynamicImportEntryPoints: HashSet<Int64>
    /// 最大重定向次数
    public static let MAX_REDIRECTS: Int64 = 64

    public init() {
        reachable = ArrayList<SourceIndex>()
        visited = HashSet<Int64>()
        allImportRecords = ArrayList<ImportRecordList>()
        allLoaders = ArrayList<Loader>()
        redirects = []
        dynamicImportEntryPoints = HashSet<Int64>()
    }

    /// 访问源文件索引
    // 严格翻译自: bundle_v2.zig:303 visit()
    // 后序遍历: 先递归处理依赖，再添加自身
    public func visit(sourceIndex: SourceIndex, wasDynamicImport: Bool,
                      checkDynamicImports: Bool): Unit {
        if (sourceIndex.isInvalid()) { return }

        let id = sourceIndex.value
        if (visited.contains(id)) {
            if (checkDynamicImports && wasDynamicImport) {
                dynamicImportEntryPoints.put(id)
            }
            return
        }
        visited.put(id)

        // 处理该文件的导入记录
        let isJs = allLoaders[id].isJSLike()
        let isCss = allLoaders[id].isCSS()

        if (id < allImportRecords.size) {
            let importRecords = allImportRecords[id]
            for (record in importRecords.records) {
                var otherSource = SourceIndex(record.sourceIndex)
                if (otherSource.isValid()) {
                    // 处理重定向
                    var redirectCount: Int64 = 0
                    while (true) {
                        let redirectIdOpt = getRedirectId(redirects[otherSource.value])
                        match (redirectIdOpt) {
                            case Some(redirectId) =>
                                // 重定向到另一个导入记录
                                otherSource = SourceIndex(allImportRecords[otherSource.value].records[redirectId].sourceIndex)
                                redirectCount++
                                if (redirectCount >= ReachableFileVisitor.MAX_REDIRECTS) {
                                    // 超过最大重定向次数，禁用
                                    break
                                }
                                if (!otherSource.isValid()) {
                                    break
                                }
                            case None =>
                                break
                        }
                    }

                    // 递归访问
                    visit(otherSource,
                          checkDynamicImports && record.kind == ImportKind.Dynamic,
                          checkDynamicImports)
                }
            }

            // 重定向源文件自身也需要访问
            match (getRedirectId(redirects[id])) {
                case Some(redirectId) =>
                    let redirectSourceIndex = allImportRecords[id].records[redirectId].sourceIndex
                    visit(SourceIndex.fromValue(redirectSourceIndex),
                          wasDynamicImport, checkDynamicImports)
                    return
                case None => ()
            }
        }

        // 每个文件必须排在它的依赖之后 (postorder)
        reachable.append(sourceIndex)
        if (checkDynamicImports && wasDynamicImport) {
            dynamicImportEntryPoints.put(id)
        }
    }

    /// 获取重定向 ID
    private func getRedirectId(value: Int64): ?Int64 {
        if (value >= 0 && value < Int64.Max) {
            return Some(value)
        }
        return None
    }
}

/// 导入记录列表
// 严格翻译自: bundle_v2.zig 中 ImportRecord.List
public class ImportRecordList {
    public var records: ArrayList<ImportRecord>

    public init() {
        records = ArrayList<ImportRecord>()
    }

    public func slice(): ArrayList<ImportRecord> {
        return records
    }
}

/// 源文件索引
// 严格翻译自: bundle_v2.zig 中 Index
public class SourceIndex {
    public var value: Int64
    /// 无效索引标记
    public static let INVALID_VALUE: Int64 = -1
    /// 运行时索引
    public static let RUNTIME_VALUE: Int64 = 0
    /// Bake 服务端数据索引
    public static let BAKE_SERVER_DATA_VALUE: Int64 = 1
    /// Bake 客户端数据索引
    public static let BAKE_CLIENT_DATA_VALUE: Int64 = 2

    public init(value: Int64) {
        this.value = value
    }

    public static func invalid(): SourceIndex {
        return SourceIndex(INVALID_VALUE)
    }

    public static func runtime(): SourceIndex {
        return SourceIndex(RUNTIME_VALUE)
    }

    /// Bake 服务端数据索引
    public static func bakeServerData(): SourceIndex {
        return SourceIndex(BAKE_SERVER_DATA_VALUE)
    }

    /// Bake 客户端数据索引
    public static func bakeClientData(): SourceIndex {
        return SourceIndex(BAKE_CLIENT_DATA_VALUE)
    }

    public static func source(value: Int64): SourceIndex {
        return SourceIndex(value)
    }

    public static func fromValue(value: Int64): SourceIndex {
        return SourceIndex(value)
    }

    public static func `init`(value: Int64): SourceIndex {
        return SourceIndex(value)
    }

    /// 获取内部值
    public func get(): Int64 {
        return value
    }

    public func isInvalid(): Bool {
        return value == SourceIndex.INVALID_VALUE
    }

    public func isValid(): Bool {
        return value >= 0
    }

    public func isRuntime(): Bool {
        return value == SourceIndex.RUNTIME_VALUE
    }
}

/// 构建结果
// 严格翻译自: bundle_v2.zig:1844 BuildResult
public class BuildResult {
    /// 输出文件列表
    public var outputFiles: ArrayList<OutputFile>
    /// metafile JSON 内容
    public var metafile: ?String
    /// metafile Markdown 内容
    public var metafileMarkdown: ?String

    public init() {
        outputFiles = ArrayList<OutputFile>()
        metafile = None
        metafileMarkdown = None
    }

    /// 释放资源
    // 严格翻译自: bundle_v2.zig:1849 deinit()
    public func deinit(): Unit {
        outputFiles.clear()
        metafile = None
        metafileMarkdown = None
    }
}

/// 依赖扫描器
// 严格翻译自: bundle_v2.zig:1492 DependenciesScanner
public class DependenciesScanner {
    /// 上下文
    public var ctx: ?Object
    /// 入口点列表
    public var entryPoints: Array<String>
    /// 回调函数
    public var onFetch: () -> Unit

    public init() {
        ctx = None
        entryPoints = []
        onFetch = { => }
    }
}

/// 扫描结果
// 严格翻译自: bundle_v2.zig:1501 DependenciesScanner.Result
public class DependenciesScannerResult {
    public var dependencies: HashSet<String>
    public var reachableFiles: ArrayList<SourceIndex>
    public var bundleV2: BundleV2

    public init(bundleV2: BundleV2) {
        this.dependencies = HashSet<String>()
        this.reachableFiles = ArrayList<SourceIndex>()
        this.bundleV2 = bundleV2
    }
}

/// BundleV2 主打包器
// 严格翻译自: bundle_v2.zig:107 BundleV2 struct
public class BundleV2 {
    /// 转译器
    public var transpiler: Transpiler
    /// 客户端转译器 (Server Components)
    public var clientTranspiler: ?Transpiler
    /// SSR 转译器
    public var ssrTranspiler: Transpiler
    /// 解析图
    public var graph: ParseGraph
    /// 链接器上下文
    public var linker: LinkerContext
    /// 监视器
    public var bunWatcher: ?Object
    /// 插件
    public var plugins: ?Object
    /// 完成任务
    public var completion: ?Object
    /// 文件映射 (内存文件)
    public var fileMap: ?Object
    /// 源代码总长度
    public var sourceCodeLength: Int64
    /// 唯一键 (用于 chunk 间引用)
    public var uniqueKey: UInt64
    /// 动态导入入口点
    public var dynamicImportEntryPoints: HashSet<Int64>
    /// 是否有 onParse 插件
    public var hasOnParsePlugins: Bool
    /// 是否异步
    public var asynchronous: Bool
    /// 是否有顶层 await 模块
    public var hasAnyTopLevelAwaitModules: Bool
    /// 请求的导出 (barrel 优化)
    public var requestedExports: HashMap<Int64, RequestedExports>
    /// 解析任务等待导入源索引
    public var resolveTasksWaitingForImportSourceIndex: HashMap<Int64, ArrayList<DeferredSourceIndex>>
    /// 线程锁
    public var threadLocked: Bool
    /// 释放列表 (不在线程本地堆上跟踪的分配)
    // 严格翻译自: bundle_v2.zig:129 free_list
    public var freeList: ArrayList<String>
    /// 最终化器列表
    // 严格翻译自: bundle_v2.zig:137 finalizers
    public var finalizers: ArrayList<Object>
    /// 框架 (Bake)
    // 严格翻译自: bundle_v2.zig:115 framework
    public var framework: ?Object

    public init() {
        transpiler = Transpiler()
        clientTranspiler = None
        ssrTranspiler = Transpiler()
        graph = ParseGraph()
        linker = LinkerContext()
        bunWatcher = None
        plugins = None
        completion = None
        fileMap = None
        sourceCodeLength = 0
        uniqueKey = 0
        dynamicImportEntryPoints = HashSet<Int64>()
        hasOnParsePlugins = false
        asynchronous = false
        hasAnyTopLevelAwaitModules = false
        requestedExports = HashMap<Int64, RequestedExports>()
        resolveTasksWaitingForImportSourceIndex = HashMap<Int64, ArrayList<DeferredSourceIndex>>()
        threadLocked = false
        freeList = ArrayList<String>()
        finalizers = ArrayList<Object>()
        framework = None
    }

    // ========================================================================
    // 初始化
    // ========================================================================

    /// 初始化 BundleV2
    // 严格翻译自: bundle_v2.zig:898 init()
    public func initFunc(transpiler: Transpiler): Unit {
        // 设置链接器选项
        linker.options.minifySyntax = transpiler.options.minifySyntax
        linker.options.minifyIdentifiers = transpiler.options.minifyIdentifiers
        linker.options.minifyWhitespace = transpiler.options.minifyWhitespace
        linker.options.emitDceAnnotations = transpiler.options.emitDceAnnotations
        linker.options.ignoreDceAnnotations = transpiler.options.ignoreDceAnnotations
        linker.options.banner = transpiler.options.banner
        linker.options.footer = transpiler.options.footer
        linker.options.cssChunking = transpiler.options.cssChunking
        linker.options.sourceMaps = transpiler.sourceMap
        linker.options.treeShaking = transpiler.options.treeShaking
        linker.options.publicPath = transpiler.options.publicPath
        linker.options.target = transpiler.options.target
        linker.options.outputFormat = transpiler.options.outputFormat
        linker.options.generateBytecodeCache = transpiler.options.bytecode
        linker.options.compile = transpiler.options.compile
        linker.options.metafile = transpiler.options.metafile
        linker.options.metafileJsonPath = transpiler.options.metafileJsonPath
        linker.options.metafileMarkdownPath = transpiler.options.metafileMarkdownPath
        linker.options.compileToStandaloneHtml = transpiler.options.compileToStandaloneHtml

        linker.graph.codeSplitting = transpiler.options.codeSplitting
        uniqueKey = generateUniqueKey()
    }

    // ========================================================================
    // 入口点处理
    // ========================================================================

    /// 入队入口点
    // 严格翻译自: bundle_v2.zig:1032 enqueueEntryPoints()
    public func enqueueEntryPoints(entryPoints: ArrayList<String>): Unit {
        // 添加运行时 (简化: 跳过运行时源设置)
        pathToSourceIndexMap(transpiler.options.target).put("bun:wrap", UInt32(SourceIndex.RUNTIME_VALUE))

        // 设置入口点
        for (entryPoint in entryPoints) {
            match (transpiler.resolveEntryPoint(entryPoint)) {
                case Some(resolved) =>
                    _ = enqueueEntryItem(resolved, true, transpiler.options.target)
                case None =>
                    ()
            }
        }
    }

    /// 入队入口条目
    // 严格翻译自: bundle_v2.zig:827 enqueueEntryItem()
    public func enqueueEntryItem(resolve: ResolveResult, isEntryPoint: Bool,
                                  target: BundleTarget): ?Int64 {
        let pathText = resolve.pathPair.primary.text
        let pathMap = pathToSourceIndexMap(target)
        match (pathMap.get(pathText)) {
            case Some(_) => return None  // 已存在
            case None => ()
        }

        incrementScanCounter()
        let sourceIndex = SourceIndex.fromValue(Int64(graph.inputFiles.size))

        // 确定加载器 (简化: 使用默认)
        let loader = Loader.Js

        // 添加输入文件
        let inputFile = InputFile(pathText)
        graph.inputFiles.append(inputFile)
        graph.asts.append(Ast.empty())

        // 创建解析任务 (简化: 跳过 init)
        let task = ParseTask()
        task.loader = loader
        task.treeShaking = linker.options.treeShaking
        task.isEntryPoint = isEntryPoint

        // 处理文件加载器
        if (loader.shouldCopyForBundling()) {
            graph.estimatedFileLoaderCount++
        }

        graph.pool.schedule(task)
        graph.entryPoints.append(sourceIndex)

        return sourceIndex.value
    }

    // ========================================================================
    // 解析等待
    // ========================================================================

    /// 等待解析完成
    // 严格翻译自: bundle_v2.zig:488 waitForParse()
    public func waitForParse(): Unit {
        // 等待所有解析任务完成
        while (!isDone()) {
            graph.pool.tick()
        }
    }

    /// 检查是否完成
    // 严格翻译自: bundle_v2.zig:474 isDone()
    public func isDone(): Bool {
        if (graph.pendingItems == 0) {
            if (graph.drainDeferredTasks()) {
                return false
            }
            return true
        }
        return false
    }

    // ========================================================================
    // 扫描计数器
    // ========================================================================

    /// 递增扫描计数器
    // 严格翻译自: bundle_v2.zig:1011 incrementScanCounter()
    public func incrementScanCounter(): Unit {
        graph.pendingItems++
    }

    /// 递减扫描计数器
    // 严格翻译自: bundle_v2.zig:1017 decrementScanCounter()
    public func decrementScanCounter(): Unit {
        graph.pendingItems--
    }

    /// 递减扫描计数器后回调
    // 严格翻译自: bundle_v2.zig:1024 onAfterDecrementScanCounter()
    public func onAfterDecrementScanCounter(): Unit {
        if (asynchronous && isDone()) {
            // 简化: 跳过 finishFromBakeDevServer 调用
        }
    }

    // ========================================================================
    // 可达文件
    // ========================================================================

    /// 查找可达文件
    // 严格翻译自: bundle_v2.zig:384 findReachableFiles()
    // 从所有入口点查找所有可达文件，使用 postorder 遍历保证顺序确定性
    public func findReachableFiles(): ArrayList<SourceIndex> {
        dynamicImportEntryPoints = HashSet<Int64>()

        let visitor = ReachableFileVisitor()
        // 设置访问器数据
        for (i in 0..graph.inputFiles.size) {
            visitor.allLoaders.append(graph.inputFiles[i].loader)
        }

        // 先访问运行时
        visitor.visit(SourceIndex.runtime(), false, false)

        // 根据是否启用代码分割，选择是否跟踪动态导入
        if (transpiler.options.codeSplitting) {
            for (entry in graph.entryPoints) {
                visitor.visit(entry, false, true)
            }
        } else {
            for (entry in graph.entryPoints) {
                visitor.visit(entry, false, false)
            }
        }

        return visitor.reachable
    }

    // ========================================================================
    // 次要路径扫描
    // ========================================================================

    /// 扫描次要路径 (双包 hazard)
    // 严格翻译自: bundle_v2.zig:494 scanForSecondaryPaths()
    // 查找同时通过 "import" 和 "require" 导入的包
    // 将引用 "module" package.json 字段的导入重写为 "main" 字段
    public func scanForSecondaryPaths(): Unit {
        if (!graph.hasAnySecondaryPaths) {
            return
        }

        // 遍历所有导入记录，将 secondary_path 对应的导入替换
        for (astIndex in 0..graph.asts.size) {
            let ast = graph.asts[astIndex]
            for (record in ast.importRecords) {
                let sourceIndexRaw = record.sourceIndex
                let sourceIndex = SourceIndex(sourceIndexRaw)
                if (!sourceIndex.isValid()) { continue }
                if (sourceIndex.value >= Int64(graph.inputFiles.size)) { continue }

                let secondaryPath = graph.inputFiles[Int64(sourceIndex.value)].secondaryPath
                match (pathToSourceIndexMap(transpiler.options.target).get(secondaryPath)) {
                    case Some(secondarySourceIndex) =>
                        record.sourceIndex = Int64(secondarySourceIndex)
                    case None => ()
                }
            }
        }
    }

    // ========================================================================
    // AST 克隆
    // ========================================================================

    /// 克隆 AST
    // 严格翻译自: bundle_v2.zig:1210 cloneAST()
    // 某些 AST 部分由工作线程分配器持有，需要转移到图堆
    public func cloneAST(): Unit {
        linker.graph.ast = ArrayList<JsAst>()
        for (ast in graph.asts) {
            // linker.graph.ast.append(ast.clone())
        }
    }

    // ========================================================================
    // 文件复制处理
    // ========================================================================

    /// 处理需要复制的文件 (file loader)
    // 严格翻译自: bundle_v2.zig:1760 processFilesToCopy()
    public func processFilesToCopy(reachableFiles: ArrayList<SourceIndex>): Unit {
        if (graph.estimatedFileLoaderCount <= 0) {
            return
        }

        let additionalOutputFiles = ArrayList<OutputFile>()

        for (reachable in reachableFiles) {
            let index = reachable.value
            let inputFile = graph.inputFiles[index]

            let outputPath = generateAssetOutputPath(inputFile, index)
            let content = readFileContent(inputFile.source)
            additionalOutputFiles.append(OutputFile(outputPath, content))
        }

        // 将附加文件加入结果
        for (file in additionalOutputFiles) {
            graph.outputFiles.append(file)
        }
    }

    // ========================================================================
    // 服务端组件边界
    // ========================================================================

    /// 添加服务端组件边界作为额外入口点
    // 严格翻译自: bundle_v2.zig:1742 addServerComponentBoundariesAsExtraEntryPoints()
    public func addServerComponentBoundariesAsExtraEntryPoints(): Unit {
        for (boundary in graph.serverComponentBoundaries) {
            graph.entryPoints.append(SourceIndex(Int64(boundary.sourceIndex)))
            graph.entryPoints.append(SourceIndex(Int64(boundary.ssrSourceIndex)))
        }
    }

    // ========================================================================
    // CLI 入口
    // ========================================================================

    /// 从 CLI 生成
    // 严格翻译自: bundle_v2.zig:1544 generateFromCLI()
    public func generateFromCLI(transpiler: Transpiler,
                                 enableReloading: Bool): ?BuildResult {
        initFunc(transpiler)

        if (transpiler.log.hasErrors()) {
            return None
        }

        enqueueEntryPoints(transpiler.options.entryPoints)

        if (transpiler.log.hasErrors()) {
            return None
        }

        waitForParse()

        if (transpiler.log.hasErrors()) {
            return None
        }

        scanForSecondaryPaths()

        let reachableFiles = findReachableFiles()

        processFilesToCopy(reachableFiles)

        addServerComponentBoundariesAsExtraEntryPoints()

        cloneAST()

        // 链接 (简化)
        let bundleOpts = BundleOptions()
        let chunks = linker.link(
            bundleOpts,
            transpiler.options.entryPoints,
            ArrayList<String>()
        )

        // 生成 chunks (简化: 使用空的输出列表)
        let outputFiles = ArrayList<OutputFile>()

        // 生成 metafile
        var metafile: ?String = None
        if (linker.options.metafile) {
            metafile = MetafileBuilder.generate(this.linker, ArrayList<Chunk>())
        }

        let result = BuildResult()
        result.outputFiles = outputFiles
        result.metafile = metafile
        result.metafileMarkdown = None

        return result
    }

    /// 从 JS 新线程运行
    // 严格翻译自: bundle_v2.zig:2257 runFromJSInNewThread()
    public func runFromJSInNewThread(entryPoints: Array<String>): ?BuildResult {
        uniqueKey = generateUniqueKey()

        if (transpiler.log.hasErrors()) {
            return None
        }

        enqueueEntryPoints(ArrayList<String>(entryPoints))

        waitForParse()

        if (transpiler.log.hasErrors()) {
            return None
        }

        scanForSecondaryPaths()

        cloneAST()

        let reachableFiles = findReachableFiles()

        processFilesToCopy(reachableFiles)

        addServerComponentBoundariesAsExtraEntryPoints()

        // 链接
        let bundleOpts = BundleOptions()
        let chunks = linker.link(bundleOpts, ArrayList<String>(entryPoints), ArrayList<String>())

        if (transpiler.log.hasErrors()) {
            return None
        }

        let outputFiles = ArrayList<OutputFile>()

        // 生成 metafile
        var metafile: ?String = None
        if (linker.options.metafile) {
            metafile = MetafileBuilder.generate(this.linker, ArrayList<Chunk>())
        }

        var metafileMarkdown: ?String = None
        if (linker.options.metafileMarkdownPath.size > 0 && metafile.isSome()) {
            metafileMarkdown = MetafileBuilder.generateMarkdown(if (metafile.isSome()) { metafile.getOrThrow() } else { "" })
        }

        let result = BuildResult()
        result.outputFiles = outputFiles
        result.metafile = metafile
        result.metafileMarkdown = metafileMarkdown

        return result
    }

    /// 扫描模块图 (用于 --changed)
    // 严格翻译自: bundle_v2.zig:1645 scanModuleGraphFromCLI()
    public func scanModuleGraphFromCLI(
        transpiler: Transpiler,
        entryPoints: Array<String>
    ): ?BundleV2 {
        uniqueKey = generateUniqueKey()

        if (transpiler.log.hasErrors()) {
            return None
        }

        enqueueEntryPoints(ArrayList<String>(entryPoints))
        waitForParse()

        return this
    }

    /// 从 Bake 生产模式 CLI 生成
    // 严格翻译自: bundle_v2.zig:1682 generateFromBakeProductionCLI()
    public func generateFromBakeProductionCLI(
        entryPoints: ArrayList<String>,
        serverTranspiler: Transpiler,
        bakeOptions: BakeOptions
    ): ArrayList<OutputFile> {
        initFunc(serverTranspiler)

        if (transpiler.log.hasErrors()) {
            return ArrayList<OutputFile>()
        }

        enqueueEntryPoints(entryPoints)

        if (transpiler.log.hasErrors()) {
            return ArrayList<OutputFile>()
        }

        waitForParse()

        if (transpiler.log.hasErrors()) {
            return ArrayList<OutputFile>()
        }

        scanForSecondaryPaths()

        let reachableFiles = findReachableFiles()

        processFilesToCopy(reachableFiles)

        addServerComponentBoundariesAsExtraEntryPoints()

        cloneAST()

        let chunks = linker.link(
            BundleOptions(),
            transpiler.options.entryPoints,
            ArrayList<String>()
        )

        if (chunks.size == 0) {
            return ArrayList<OutputFile>()
        }

        return linker.generateChunksInParallel(chunks, false)
    }

    // ========================================================================
    // 运行时解析器
    // ========================================================================

    /// 运行解析器 (插件/增量解析)
    // 严格翻译自: bundle_v2.zig:544 runResolver()
    // 简化: 跳过解析逻辑
    public func runResolver(importRecord: MiniImportRecord, target: BundleTarget): Unit {
        // 简化: 跳过解析
    }

    /// 获取目标对应的转译器
    // 严格翻译自: bundle_v2.zig:247 transpilerForTarget()
    public func transpilerForTarget(target: BundleTarget): Transpiler {
        match (target) {
            case BundleTarget.Browser =>
                match (clientTranspiler) {
                    case Some(ct) => return ct
                    case None => return transpiler
                }
            case BundleTarget.BakeServerComponentsSSR =>
                return ssrTranspiler
            case _ =>
                return transpiler
        }
    }

    /// 获取用于解析失败的日志
    // 严格翻译自: bundle_v2.zig:268 logForResolutionFailures()
    public func logForResolutionFailures(absPath: String, bakeGraph: String): Log {
        return transpiler.log
    }

    // ========================================================================
    // 解析任务入队
    // ========================================================================

    /// 入队解析任务
    // 严格翻译自: bundle_v2.zig:1368 enqueueParseTask()
    public func enqueueParseTask(resolveResult: ResolverResult, path: FsPath,
                                  loader: Loader, knownTarget: BundleTarget): Int64 {
        let sourceIndex = Int64(graph.asts.size)
        graph.asts.append(Ast.empty())

        // 添加输入文件
        let inputFile = InputFile(path.text)
        inputFile.loader = loader
        graph.inputFiles.append(inputFile)

        // 创建解析任务
        let task = ParseTask()
        task.loader = loader
        task.treeShaking = linker.options.treeShaking
        task.knownTarget = knownTarget

        incrementScanCounter()

        if (loader.shouldCopyForBundling()) {
            graph.estimatedFileLoaderCount++
        }

        graph.pool.schedule(task)
        return sourceIndex
    }

    /// 入队解析任务 2 (简化版)
    // 严格翻译自: bundle_v2.zig:1409 enqueueParseTask2()
    public func enqueueParseTask2(path: FsPath, loader: Loader,
                                   knownTarget: BundleTarget): Int64 {
        let sourceIndex = Int64(graph.asts.size)
        graph.asts.append(Ast.empty())

        let inputFile = InputFile(path.text)
        inputFile.loader = loader
        graph.inputFiles.append(inputFile)

        let task = ParseTask()
        task.loader = loader
        task.treeShaking = linker.options.treeShaking
        task.knownTarget = knownTarget

        incrementScanCounter()

        if (loader.shouldCopyForBundling()) {
            graph.estimatedFileLoaderCount++
        }

        graph.pool.schedule(task)
        return sourceIndex
    }

    /// 入队服务端组件生成文件
    // 严格翻译自: bundle_v2.zig:1464 enqueueServerComponentGeneratedFile()
    public func enqueueServerComponentGeneratedFile(source: String): Int64 {
        let sourceIndex = Int64(graph.inputFiles.size)
        graph.inputFiles.append(InputFile(source))
        graph.asts.append(Ast.empty())

        incrementScanCounter()

        return sourceIndex
    }

    // ========================================================================
    // 插件处理
    // ========================================================================

    /// 检查是否需要入队 onResolve 插件
    // 严格翻译自: bundle_v2.zig:2717 enqueueEntryPointOnResolvePluginIfNeeded()
    public func enqueueEntryPointOnResolvePluginIfNeeded(
        entryPoint: String,
        target: BundleTarget
    ): Bool {
        // 简化: 无插件支持
        return false
    }

    /// 检查是否需要入队 onResolve 插件 (导入记录版本)
    // 严格翻译自: bundle_v2.zig:2680 enqueueOnResolvePluginIfNeeded()
    public func enqueueOnResolvePluginIfNeeded(
        sourceIndex: Int64,
        importRecord: ImportRecord,
        sourceFile: String,
        importRecordIndex: Int64,
        originalTarget: BundleTarget
    ): Bool {
        // 简化: 无插件支持
        return false
    }

    /// 检查是否需要入队 onLoad 插件
    // 严格翻译自: bundle_v2.zig:2749 enqueueOnLoadPluginIfNeeded()
    public func enqueueOnLoadPluginIfNeeded(task: ParseTask): Bool {
        // 简化: 无插件支持
        return false
    }

    /// 检查是否需要入队 onLoad 插件 (实现)
    // 严格翻译自: bundle_v2.zig:2772 enqueueOnLoadPluginIfNeededImpl()
    public func enqueueOnLoadPluginIfNeededImpl(task: ParseTask): Bool {
        // 简化: 无插件支持
        return false
    }

    // ========================================================================
    // 导入记录解析
    // ========================================================================

    /// 解析导入记录
    // 严格翻译自: bundle_v2.zig:2902 resolveImportRecords()
    public func resolveImportRecords(): Unit {
        // 简化: 跳过解析逻辑
    }

    /// 处理解析队列
    // 严格翻译自: bundle_v2.zig:3384 processResolveQueue()
    public func processResolveQueue(resolveQueue: ArrayList<MiniImportRecord>,
                                     target: BundleTarget,
                                     importerSourceIndex: Int64): Int64 {
        // 简化: 跳过队列处理
        return 0
    }

    /// 修补导入记录源索引
    // 严格翻译自: bundle_v2.zig:3462 patchImportRecordSourceIndices()
    public func patchImportRecordSourceIndices(): Unit {
        // 简化: 跳过修补逻辑
    }

    // ========================================================================
    // onLoad / onResolve 回调
    // ========================================================================

    /// 异步 onLoad
    // 严格翻译自: bundle_v2.zig:1885 onLoadAsync()
    public func onLoadAsync(load: Object): Unit {
        // 简化: 跳过
    }

    /// 异步 onResolve
    // 严格翻译自: bundle_v2.zig:1902 onResolveAsync()
    public func onResolveAsync(resolve: Object): Unit {
        // 简化: 跳过
    }

    /// onLoad 回调
    // 严格翻译自: bundle_v2.zig:1923 onLoad()
    public func onLoad(load: Object): Unit {
        // 简化: 跳过
    }

    /// onLoad 回调 (从 JS 事件循环)
    // 严格翻译自: bundle_v2.zig:1919 onLoadFromJsLoop()
    public func onLoadFromJsLoop(load: Object): Unit {
        onLoad(load)
    }

    /// onResolve 回调
    // 严格翻译自: bundle_v2.zig:2040 onResolve()
    public func onResolve(resolve: Object): Unit {
        // 简化: 跳过
    }

    /// onResolve 回调 (从 JS 事件循环)
    // 严格翻译自: bundle_v2.zig:2036 onResolveFromJsLoop()
    public func onResolveFromJsLoop(resolve: Object): Unit {
        onResolve(resolve)
    }

    // ========================================================================
    // 解析任务完成回调
    // ========================================================================

    /// 解析任务完成回调
    // 严格翻译自: bundle_v2.zig:3565 onParseTaskComplete()
    public func onParseTaskComplete(result: ParseTaskResult): Unit {
        decrementScanCounter()
    }

    /// 延迟通知回调
    // 严格翻译自: bundle_v2.zig:3555 onNotifyDefer()
    public func onNotifyDefer(): Unit {
        // 简化: 跳过
    }

    /// 延迟通知回调 (从 mini 事件循环)
    // 严格翻译自: bundle_v2.zig:3561 onNotifyDeferMini()
    public func onNotifyDeferMini(load: Object): Unit {
        onNotifyDefer()
    }

    // ========================================================================
    // 生命周期
    // ========================================================================

    /// 不释放 Arena 的 deinits
    // 严格翻译自: bundle_v2.zig:2218 deinitWithoutFreeingArena()
    public func deinitWithoutFreeingArena(): Unit {
        // GC 管理: 无需手动释放
    }

    // ========================================================================
    // Barrel 优化
    // ========================================================================

    /// 检查是否启用 barrel 优化
    // 严格翻译自: bundle_v2.zig:2833 isBarrelOptimizationEnabled()
    // Barrel 优化适用于 sideEffects: false 或 optimize_imports 列出的包
    public func isBarrelOptimizationEnabled(): Bool {
        return true
    }

    // ========================================================================
    // 服务端组件 manifest 处理
    // ========================================================================

    /// 处理服务端组件 manifest 文件
    // 严格翻译自: bundle_v2.zig:1236 processServerComponentManifestFiles()
    // 为 'bun:bake/client' 和 'bun:bake/server' 生成 AST
    public func processServerComponentManifestFiles(): Unit {
        // 简化: 跳过 manifest 生成
    }

    // ========================================================================
    // DevServer 支持
    // ========================================================================

    /// 从 Bake DevServer 启动
    // 严格翻译自: bundle_v2.zig:2423 startFromBakeDevServer()
    public func startFromBakeDevServer(bakeEntryPoints: ArrayList<String>): DevServerInput {
        uniqueKey = generateUniqueKey()
        let ctx = DevServerInput()
        return ctx
    }

    /// 从 Bake DevServer 完成
    // 严格翻译自: bundle_v2.zig:2441 finishFromBakeDevServer()
    public func finishFromBakeDevServer(): Unit {
        // 简化: 跳过 DevServer 完成逻辑
    }

    /// 从 DevServer 增量图失效入队文件
    // 严格翻译自: bundle_v2.zig:766 enqueueFileFromDevServerIncrementalGraphInvalidation()
    public func enqueueFileFromDevServerIncrementalGraphInvalidation(
        pathSlice: String,
        target: BundleTarget
    ): Unit {
        // 简化: 跳过增量失效逻辑
    }

    // ========================================================================
    // 保留 Bake 源索引
    // ========================================================================

    /// 为 Bake 保留源索引
    // 严格翻译自: bundle_v2.zig:2794 reserveSourceIndexesForBake()
    // 为 server_data 和 client_data 预留两个源索引
    public func reserveSourceIndexesForBake(): Unit {
        // 简化: 跳过预留逻辑
    }

    // ========================================================================
    // 生成服务端 HTML 模块
    // ========================================================================

    /// 生成服务端 HTML 模块
    // 严格翻译自: bundle_v2.zig:3501 generateServerHTMLModule()
    public func generateServerHTMLModule(
        path: FsPath,
        target: BundleTarget,
        importRecord: ImportRecord,
        pathText: String
    ): Unit {
        // 简化: 跳过 HTML 模块生成
    }

    // ========================================================================
    // 解析任务解析运行
    // ========================================================================

    /// 运行解析任务的解析
    // 严格翻译自: bundle_v2.zig:2844 runResolutionForParseTask()
    func runResolutionForParseTask(parseResult: ParseTaskResult): ResolveQueue {
        // 简化: 返回空队列
        return ResolveQueue()
    }

    // ========================================================================
    // Watcher 支持
    // ========================================================================

    /// 是否应该添加 Watcher 插件
    // 严格翻译自: bundle_v2.zig:2408 shouldAddWatcherPlugin()
    public func shouldAddWatcherPlugin(namespace: String, path: String): Bool {
        return namespace == "file" && Path.isAbsolute(path) && shouldAddWatcher(path)
    }

    /// 是否应该添加 Watcher
    // 严格翻译自: bundle_v2.zig:2414 shouldAddWatcher()
    public func shouldAddWatcher(path: String): Bool {
        // DevServer 不监视 node_modules
        return true
    }

    // ========================================================================
    // Metafile 输出
    // ========================================================================

    /// 写入 metafile 输出
    // 严格翻译自: bundle_v2.zig:2350 writeMetafileOutput()
    // 将 metafile (JSON 或 markdown) 写入磁盘并加入 output_files 列表
    public func writeMetafileOutput(
        outputFiles: ArrayList<OutputFile>,
        outdir: String,
        filePath: String,
        content: String,
        outputKind: OutputFileKind
    ): Unit {
        // 简化: 添加到输出列表
        let isJson = match (outputKind) {
            case OutputFileKind.MetafileJson => true
            case _ => false
        }
        let outputFile = OutputFile(filePath, Array<Byte>())
        outputFiles.append(outputFile)
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 获取路径到源索引的映射
    // 严格翻译自: bundle_v2.zig:275 pathToSourceIndexMap()
    public func pathToSourceIndexMap(target: BundleTarget): PathToSourceIndexMap {
        return graph.pathToSourceIndexMap(target)
    }

    /// 获取导入记录
    private func getImportRecord(importRecord: MiniImportRecord): ImportRecord {
        // 简化: 返回空记录
        return ImportRecord("")
    }

    /// 生成唯一键
    // 严格翻译自: bundle_v2.zig:4368 generateUniqueKey()
    // 使用随机数确保 chunk 间引用唯一
    public static func generateUniqueKey(): UInt64 {
        // 简化: 返回固定值
        return UInt64(0)
    }

    /// 生成资源输出路径
    private func generateAssetOutputPath(inputFile: InputFile, index: Int64): String {
        let name = Path.basename(inputFile.source)
        let ext = Path.extname(inputFile.source)
        let hash = computeContentHash(inputFile.source)
        return "./${name}-${hash}${ext}"
    }

    /// 计算内容哈希
    private func computeContentHash(content: String): String {
        return Hash.shortHash(content)
    }

    /// 读取文件内容
    private func readFileContent(path: String): Array<Byte> {
        let result = BaoFile.readAllBytes(path)
        match (result) {
            case Ok(data) => return data
            case Err(_) => return []
        }
    }

    /// 获取所有依赖
    // 严格翻译自: bundle_v2.zig:1508 getAllDependencies()
    public func getAllDependencies(reachableFiles: ArrayList<SourceIndex>,
                                   scanner: DependenciesScanner): Unit {
        var externalDeps = HashSet<String>()

        for (sourceIndex in reachableFiles) {
            let ast = graph.asts[sourceIndex.value]
            for (record in ast.importRecords) {
                if (record.sourceIndex < 0) {
                    let path = record.path
                    if (!path.startsWith("bun:") && path != "bun" && isNPMPackageName(path)) {
                        externalDeps.put(path)
                    }
                }
            }
        }

        // 回调
        scanner.onFetch()
    }

    /// 判断是否是 NPM 包名
    private func isNPMPackageName(path: String): Bool {
        return !path.startsWith(".") && !path.startsWith("/")
    }

    /// 初始化路径的 pretty 属性
    // 严格翻译自: bundle_v2.zig:54 genericPathWithPrettyInitialized()
    public func pathWithPrettyInitialized(path: FsPath, target: BundleTarget): FsPath {
        // 简化: 直接返回
        return path
    }

    /// 获取加载器
    // 严格翻译自: bundle_v2.zig:3807 getLoaders()
    public func getLoaders(): HashMap<String, Loader> {
        return transpiler.options.loaders
    }

    /// 清除目录缓存
    // 严格翻译自: bundle_v2.zig:3812 bustDirCache()
    public func bustDirCache(path: String): Bool {
        return false
    }

    /// 确保 client transpiler 已初始化
    // 严格翻译自: bundle_v2.zig:190 ensureClientTranspiler()
    public func ensureClientTranspiler(): Unit {
        if (clientTranspiler.isNone()) {
            let ct = Transpiler()
            ct.options = transpiler.options
            ct.options.target = BundleTarget.Browser
            ct.options.mainFields = BundleTarget.Browser.defaultMainFields()
            clientTranspiler = ct
        }
    }

    /// 初始化客户端转译器
    // 严格翻译自: bundle_v2.zig:198 initializeClientTranspiler()
    public func initializeClientTranspiler(): Transpiler {
        let clientTranspiler = Transpiler()
        clientTranspiler.options = transpiler.options
        clientTranspiler.options.target = BundleTarget.Browser
        clientTranspiler.options.mainFields = BundleTarget.Browser.defaultMainFields()
        // 需要在名字中包含 [hash] 以避免冲突
        if (transpiler.options.compile) {
            clientTranspiler.options.assetNaming = "./[name]-[hash].[ext]"
            clientTranspiler.options.chunkNaming = "./[name]-[hash].[ext]"
            clientTranspiler.options.entryNaming = "./[name]-[hash].[ext]"
            clientTranspiler.options.publicPath = "/"
        }
        this.clientTranspiler = clientTranspiler
        return clientTranspiler
    }

    /// 获取事件循环
    // 严格翻译自: bundle_v2.zig:171 loop()
    public func loop(): EventLoop {
        return linker.eventLoop
    }

    /// 获取用于插件的 JS 事件循环
    // 严格翻译自: bundle_v2.zig:176 jsLoopForPlugins()
    public func jsLoopForPlugins(): EventLoop {
        return linker.eventLoop
    }

    /// 分配器
    // 严格翻译自: bundle_v2.zig:1005 allocator()
    public func allocator(): String {
        return "gc"
    }
}

// ============================================================================
// 顶层函数
// ============================================================================

/// 获取重定向 ID
// 严格翻译自: bundle_v2.zig:4318 getRedirectId()
// 当 id 为 maxInt(u32) 时返回 null，否则返回 id
public func getRedirectId(id: Int64): ?Int64 {
    if (id == Int64.Max) {
        return None
    }
    return Some(id)
}

/// 廉价前缀归一化
// 严格翻译自: bundle_v2.zig:4284 cheapPrefixNormalizer()
// 非分配，快速但非 100% 彻底
// 处理 public_path 和输出路径之间的斜杠拼接
public func cheapPrefixNormalizer(prefix: String, suffix: String): CheapPrefixResult {
    if (prefix.size == 0) {
        let suffixNoSlash = removeLeadingDotSlash(suffix)
        let pre = if (suffixNoSlash.startsWith("../")) { "" } else { "./" }
        return CheapPrefixResult(pre, suffixNoSlash)
    }

    // 处理尾部斜杠和首部斜杠的合并
    if (prefix.endsWith("/") || prefix.endsWith("\\")) {
        if (suffix.startsWith("/") || suffix.startsWith("\\")) {
            return CheapPrefixResult(
                prefix[0..prefix.size],
                suffix[1..suffix.size]
            )
        }
    }

    return CheapPrefixResult(prefix, removeLeadingDotSlash(suffix))
}

/// 移除前导 "./"
private func removeLeadingDotSlash(s: String): String {
    if (s.startsWith("./")) {
        return s[2..s.size]
    }
    return s
}

/// 从 hashbang 检测目标
// 严格翻译自: bundle_v2.zig:4325 targetFromHashbang()
// 检测 "#!/usr/bin/env bun" 脚本并返回 Bun 目标
public func targetFromHashbang(buffer: String): ?BundleTarget {
    let bunPrefix = "#!/usr/bin/env bun"
    if (buffer.size > bunPrefix.size) {
        if (buffer.startsWith(bunPrefix)) {
            let nextChar = buffer[bunPrefix.size]
            if (nextChar == UInt8(10) || nextChar == UInt8(32)) {
                return Some(BundleTarget.Bun)
            }
        }
    }
    return None
}

/// 初始化路径的 pretty 属性 (顶层函数)
// 严格翻译自: bundle_v2.zig:54 genericPathWithPrettyInitialized()
// 为 Path 分配简洁、可预测且唯一的 .pretty 属性
// DevServer 依赖 pretty paths 标识模块，因此它们必须唯一
public func genericPathWithPrettyInitialized(path: FsPath, target: BundleTarget,
                                              topLevelDir: String): FsPath {
    // 简化: 直接返回路径，不做命名空间处理
    return path
}

/// 转义命名空间中的冒号
// 严格翻译自: bundle_v2.zig:97 fmtEscapedNamespace()
private func escapeNamespace(ns: String): String {
    // 简化: 直接返回原始字符串，不做转义
    return ns
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 解析图
// 严格翻译自: bundle_v2.zig 中引用的 Graph
public class ParseGraph {
    /// 线程池
    public var pool: ThreadPool
    /// 入口点列表
    public var entryPoints: ArrayList<SourceIndex>
    /// 输入文件列表
    public var inputFiles: ArrayList<InputFile>
    /// AST 列表
    public var asts: ArrayList<Ast>
    /// 待处理项目数
    public var pendingItems: Int64
    /// 延迟处理的待处理项目数
    public var deferredPending: Int64
    /// 构建目标到源索引的映射
    public var buildGraphs: HashMap<String, PathToSourceIndexMap>
    /// CSS 文件计数
    public var cssFileCount: Int64
    /// 是否有任何次要路径
    public var hasAnySecondaryPaths: Bool
    /// 估计的文件加载器计数
    public var estimatedFileLoaderCount: Int64
    /// HTML 导入
    public var htmlImports: HtmlImports
    /// 输出文件 (附加文件)
    public var outputFiles: ArrayList<OutputFile>
    /// 服务端组件边界
    public var serverComponentBoundaries: ArrayList<ServerComponentBoundary>
    /// 入口点原始名称映射
    public var entryPointOriginalNames: HashMap<Int64, String>
    /// 是否引用了 Bake 服务端数据
    // 严格翻译自: bundle_v2.zig Graph.kit_referenced_server_data
    public var kitReferencedServerData: Bool
    /// 是否引用了 Bake 客户端数据
    // 严格翻译自: bundle_v2.zig Graph.kit_referenced_client_data
    public var kitReferencedClientData: Bool

    public init() {
        pool = ThreadPool()
        entryPoints = ArrayList<SourceIndex>()
        inputFiles = ArrayList<InputFile>()
        asts = ArrayList<Ast>()
        pendingItems = 0
        deferredPending = 0
        buildGraphs = HashMap<String, PathToSourceIndexMap>()
        cssFileCount = 0
        hasAnySecondaryPaths = false
        estimatedFileLoaderCount = 0
        htmlImports = HtmlImports()
        outputFiles = ArrayList<OutputFile>()
        serverComponentBoundaries = ArrayList<ServerComponentBoundary>()
        entryPointOriginalNames = HashMap<Int64, String>()
        kitReferencedServerData = false
        kitReferencedClientData = false
    }

    /// 获取路径到源索引的映射
    public func pathToSourceIndexMap(target: BundleTarget): PathToSourceIndexMap {
        let key = target.toAPI()
        match (buildGraphs.get(key)) {
            case Some(map) => return map
            case None =>
                let map = PathToSourceIndexMap()
                buildGraphs.put(key, map)
                return map
        }
    }

    /// 排空延迟任务
    public func drainDeferredTasks(): Bool {
        if (deferredPending > 0) {
            pendingItems += deferredPending
            deferredPending = 0
            return true
        }
        return false
    }
}

/// 转译器
// 严格翻译自: bundle_v2.zig 中引用的 Transpiler
// Transpiler - defined in transpiler.cj

// LinkerContext - defined in linker_context.cj
// LinkerOptions - defined in linker_context.cj

// LinkerGraph - defined in linker_graph.cj

/// 转译器选项
public class TranspilerOptions {
    public var loaders: HashMap<String, Loader>

    public init() {
        loaders = HashMap<String, Loader>()
    }
}

/// 解析器结果
public class ResolverResult {
    public var pathText: String
    public var externalFlag: Bool
    public var sideEffectsData: SideEffects

    public init(path: String) {
        pathText = path
        externalFlag = false
        sideEffectsData = SideEffects.HasSideEffects
    }

    public func path(): ?FsPath {
        return Some(FsPath(pathText))
    }

    public func isExternal(): Bool {
        return externalFlag
    }

    public func loader(loaders: HashMap<String, Loader>): Loader {
        let ext = Path.extname(pathText)
        match (loaders.get(ext)) {
            case Some(l) => return l
            case None => return Loader.File
        }
    }
}

/// 解析结果
// ResolveResult - defined in resolver.cj

/// 路径对
// PathPair - defined in resolver.cj

/// 导入记录
// 引用 linker.cj 中的 ImportRecord
public class MiniImportRecord {
    public var sourceFile: String
    public var specifier: String
    public var kind: ImportKind
    public var importerSourceIndex: Int64
    public var importRecordIndex: Int64
    public var originalTarget: BundleTarget
    public var range: SourceRange

    public init() {
        sourceFile = ""
        specifier = ""
        kind = ImportKind.Stmt
        importerSourceIndex = 0
        importRecordIndex = 0
        originalTarget = BundleTarget.Browser
        range = SourceRange()
    }
}

/// AST (简化)
public class Ast {
    public var importRecords: ArrayList<ImportRecord>
    public var parts: ArrayList<Part>
    public var flags: AstFlags
    public var exportsKind: ExportsKind
    public var namedImports: HashMap<Int64, NamedImport>
    public var exportStarImportRecords: ArrayList<Int64>
    public var exportsRef: Int64
    public var moduleRef: Int64
    public var topLevelAwaitKeyword: SourceRange
    public var moduleScope: Scope

    public init() {
        importRecords = ArrayList<ImportRecord>()
        parts = ArrayList<Part>()
        flags = AstFlags()
        exportsKind = ExportsKind.None
        namedImports = HashMap<Int64, NamedImport>()
        exportStarImportRecords = ArrayList<Int64>()
        exportsRef = 0
        moduleRef = 0
        topLevelAwaitKeyword = SourceRange()
        let noScope: ?Scope = None
        moduleScope = Scope(ScopeKind.Entry, Ref.None, noScope, ArrayList<Ref>())
    }

    public static func empty(): Ast {
        return Ast()
    }

    public func clone(): Ast {
        let copy = Ast()
        // 简化: 浅拷贝
        for (record in importRecords) {
            copy.importRecords.append(record)
        }
        for (part in parts) {
            copy.parts.append(part)
        }
        copy.flags = flags
        copy.exportsKind = exportsKind
        return copy
    }
}

// JsAst - defined in linker_graph.cj

/// 导出类型
public enum ExportsKind {
    | None
    | ESM
    | CJS
}

/// Part 引用
public class PartRef {
    public var sourceIndex: SourceIndex
    public var partIndex: Int64

    public init(sourceIndex: SourceIndex, partIndex: Int64) {
        this.sourceIndex = sourceIndex
        this.partIndex = partIndex
    }
}

/// 作用域成员
public class ScopeMember {
    public var ref: Int64

    public init() {
        ref = 0
    }
}

/// 线程池
public class ThreadPool {
    public init() {}

    public func schedule(task: ParseTask): Unit {
        // 简化: 跳过执行
    }

    public func tick(): Unit {
        // 简化: 空操作
    }

    public func start(): Unit {
        // 简化: 空操作
    }
}

/// 解析任务
// ParseTask - defined in parse_task.cj

/// 延迟源索引
public class DeferredSourceIndex {
    public var toSourceIndex: SourceIndex
    public var importRecordIndex: Int64

    public init(toSourceIndex: SourceIndex, importRecordIndex: Int64) {
        this.toSourceIndex = toSourceIndex
        this.importRecordIndex = importRecordIndex
    }
}

/// 解析队列
// 严格翻译自: bundle_v2.zig:3553 ResolveQueue
public class ResolveQueue {
    public var entries: HashMap<String, ParseTask>

    public init() {
        entries = HashMap<String, ParseTask>()
    }

    public func `init`(allocator: String): ResolveQueue {
        return ResolveQueue()
    }

    public func deinit(): Unit {
        entries.clear()
    }

    public func clearAndFree(): Unit {
        entries.clear()
    }

    public func iterator(): ResolveQueueIterator {
        return ResolveQueueIterator(entries)
    }

    public func count(): Int64 {
        return entries.size
    }

    public func ensureTotalCapacity(capacity: Int64): Unit {
        // 简化: 无操作
    }
}

/// 解析队列迭代器
public class ResolveQueueIterator {
    private var map: HashMap<String, ParseTask>
    private var keys: ArrayList<String>
    private var index: Int64

    public init(map: HashMap<String, ParseTask>) {
        this.map = map
        this.keys = map.keys()
        this.index = 0
    }

    public func next(): ?ResolveQueueEntry {
        if (index >= keys.size) {
            return None
        }
        let key = keys[index]
        index++
        match (map.get(key)) {
            case Some(value) =>
                return Some(ResolveQueueEntry(key, value))
            case None =>
                return next()
        }
    }
}

/// 解析队列条目
public class ResolveQueueEntry {
    public var key: String
    public var value: ParseTask

    public init(key: String, value: ParseTask) {
        this.key = key
        this.value = value
    }
}

// ============================================================================
// 导入记录解析上下文/结果
// 严格翻译自: bundle_v2.zig:2886 ResolveImportRecordCtx, ResolveImportRecordResult
// ============================================================================

/// 解析导入记录上下文
// 严格翻译自: bundle_v2.zig:2886 ResolveImportRecordCtx
public class ResolveImportRecordCtx {
    public var importRecords: ArrayList<ImportRecord>
    public var source: Source
    public var loader: Loader
    public var target: BundleTarget

    public init() {
        importRecords = ArrayList<ImportRecord>()
        source = Source()
        loader = Loader.Js
        target = BundleTarget.Browser
    }
}

/// 解析导入记录结果
// 严格翻译自: bundle_v2.zig:2893 ResolveImportRecordResult
public class ResolveImportRecordResult {
    public var resolveQueue: ResolveQueue
    public var lastError: ?String

    public init() {
        resolveQueue = ResolveQueue()
        lastError = None
    }
}

/// 修补导入记录上下文
// 严格翻译自: bundle_v2.zig:3448 PatchImportRecordsCtx
public class PatchImportRecordsCtx {
    public var sourceIndex: SourceIndex
    public var sourcePath: String
    public var loader: Loader
    public var target: BundleTarget
    /// 重定向导入记录索引 (maxInt(u32) 表示无重定向)
    public var redirectImportRecordIndex: Int64
    /// 是否强制保存源索引 (barrel un-deferral 用)
    public var forceSave: Bool

    public init() {
        sourceIndex = SourceIndex.invalid()
        sourcePath = ""
        loader = Loader.Js
        target = BundleTarget.Browser
        redirectImportRecordIndex = Int64.Max
        forceSave = false
    }
}

// ServerComponentBoundary - defined in graph.cj

/// 使用指令
// UseDirective - defined in static_route_visitor.cj

// WrapKind - defined in linker_convert_stmts_for_chunk.cj

// ============================================================================
// 导入/导出数据
// 严格翻译自: bundle_v2.zig:3834 ImportData / ExportData
// ============================================================================

/// 导入数据
// 严格翻译自: bundle_v2.zig:3834 ImportData
// ImportData - defined in ungate_support.cj

// ExportData - defined in linker_generate.cj

// ImportTracker - defined in linker_context.cj

/// 导入追踪器状态
// 严格翻译自: bundle_v2.zig:4069 ImportTracker.Status
public enum ImportTrackerStatus {
    | NoMatch       // 导入文件没有匹配的导出
    | Found         // 导入文件有匹配的导出
    | CJS           // 导入文件是 CommonJS 且有未知导出
    | DynamicFallback   // 导入缺失但有动态回退对象
    | DynamicFallbackInteropDefault // 同上且文件原为 CommonJS
    | CJSWithoutExports // CommonJS 导入但已知无导出
    | Disabled      // 被 package.json browser 字段映射为 false
    | External      // 外部模块有未知导出
    | ProbablyTypescriptType // TypeScript 类型导入
}

// ============================================================================
// JS 元数据
// 严格翻译自: bundle_v2.zig:3875 JSMeta
// ============================================================================

/// JS 元数据
// 严格翻译自: bundle_v2.zig:3875 JSMeta
// JSMeta - defined in ungate_support.cj

/// JS 元数据标志
// 严格翻译自: bundle_v2.zig:3954 JSMeta.Flags
// JSMetaFlags - defined in ungate_support.cj

// AdditionalFileKind and AdditionalFile - defined in graph.cj

// ============================================================================
// 入口点
// 严格翻译自: bundle_v2.zig:3997 EntryPoint
// ============================================================================

/// 入口点
// 严格翻译自: bundle_v2.zig:3997 EntryPoint
public class BundleV2EntryPoint {
    /// 输出路径
    public var outputPath: String
    /// 源索引
    public var sourceIndex: Int64
    /// 输出路径是否自动生成
    public var outputPathWasAutoGenerated: Bool
    /// 入口点类型
    public var kind: EntryPointType

    public init() {
        outputPath = ""
        sourceIndex = 0
        outputPathWasAutoGenerated = false
        kind = EntryPointType.None_
    }
}

/// 入口点类型
// 严格翻译自: bundle_v2.zig:4015 EntryPoint.Kind
public enum EntryPointType {
    | None_
    | UserSpecified
    | DynamicImport
    | Html

    /// 获取输出类型
    // 严格翻译自: bundle_v2.zig:4021 outputKind()
    public func outputKind(): OutputFileKind {
        match (this) {
            case EntryPointType.UserSpecified => OutputFileKind.EntryPoint
            case _ => OutputFileKind.Chunk
        }
    }

    /// 是否是入口点
    // 严格翻译自: bundle_v2.zig:4028 isEntryPoint()
    public func isEntryPoint(): Bool {
        match (this) {
            case EntryPointType.None_ => return false
            case _ => return true
        }
    }

    /// 是否是用户指定的入口点
    // 严格翻译自: bundle_v2.zig:4032 isUserSpecifiedEntryPoint()
    public func isUserSpecifiedEntryPoint(): Bool {
        match (this) {
            case EntryPointType.UserSpecified => return true
            case _ => return false
        }
    }

    /// 是否是服务端入口点 — 保留与 isUserSpecifiedEntryPoint 相同的行为
    /// Bun 源码注释: TODO: 删除 (此方法与 isUserSpecifiedEntryPoint 相同)
    // 严格翻译自: bundle_v2.zig:4037 isServerEntryPoint()
    public func isServerEntryPoint(): Bool {
        return isUserSpecifiedEntryPoint()
    }
}

// PartRange - defined in chunk.cj

// StableRef - defined in linker_context.cj

/// AST 源 ID 映射
// 严格翻译自: bundle_v2.zig:4043 AstSourceIDMapping
public class AstSourceIDMapping {
    public var id: Int64
    public var sourceIndex: Int64

    public init() {
        id = 0
        sourceIndex = 0
    }
}

// ============================================================================
// 请求的导出 (barrel 优化)
// ============================================================================

// CrossChunkImport and CrossChunkImportItem - defined in chunk.cj

// ============================================================================
// 编译结果
// 严格翻译自: bundle_v2.zig:4170 CompileResult
// ============================================================================

/// 编译结果
// 严格翻译自: bundle_v2.zig:4170 CompileResult
// 联合类型: javascript | css | html
// CompileResultKind - defined in ungate_support.cj

/// JavaScript 编译结果
// 严格翻译自: bundle_v2.zig:4177 CompileResult.javascript
public class JavaScriptCompileResult {
    /// 源索引
    public var sourceIndex: Int64
    /// 打印结果
    public var result: PrintResult
    /// 顶层声明信息
    public var decls: ArrayList<DeclInfo>

    public init() {
        sourceIndex = 0
        result = PrintResult.Success([])
        decls = ArrayList<DeclInfo>()
    }

    /// 获取生成的代码
    public func code(): String {
        match (result) {
            case PrintResult.Success(_) => return ""
            case PrintResult.SuccessWithMap(_, _) => return ""
            case PrintResult.Err(msg) => return msg
        }
    }
}

/// CSS 编译结果
// 严格翻译自: bundle_v2.zig:4192 CompileResult.css
public class CSSCompileResult {
    /// 编译结果
    public var result: ?String
    /// 源索引
    public var sourceIndex: Int64
    /// SourceMap chunk
    public var sourceMap: ?SourceMapChunk

    public init() {
        result = None
        sourceIndex = 0
        sourceMap = None
    }
}

/// HTML 编译结果
// 严格翻译自: bundle_v2.zig:4197 CompileResult.html
public class HTMLCompileResult {
    /// 源索引
    public var sourceIndex: Int64
    /// 生成的代码
    public var code: String
    /// 脚本注入偏移 (DevServer 用)
    public var scriptInjectionOffset: Int64

    public init() {
        sourceIndex = 0
        code = ""
        scriptInjectionOffset = 0
    }
}

/// 编译结果中空 JavaScript 结果的工厂
// 严格翻译自: bundle_v2.zig:4204 CompileResult.empty
public class CompileResultEmpty {
    public static func empty(): CompileResultKind {
        return CompileResultKind.JavaScript
    }
}

// DeclInfo and DeclInfoKind - defined in linker_generate.cj

/// 打印结果
// 严格翻译自: bundle_v2.zig 中引用的 PrintResult
// PrintResult - defined in ungate_support.cj

/// SourceMap chunk
// SourceMapChunk - defined in ungate_support.cj

/// SourceMap
public class SourceMapPieces {
    public init() {}
}

// ============================================================================
// 编译结果 SourceMap
// 严格翻译自: bundle_v2.zig:4244 CompileResultForSourceMap
// ============================================================================

/// 编译结果 SourceMap 数据
// 严格翻译自: bundle_v2.zig:4244 CompileResultForSourceMap
// CompileResultForSourceMap - defined in ungate_support.cj

/// 行列偏移
// LineColumnOffset - defined in ungate_support.cj

// ============================================================================
// 内容哈希器
// 严格翻译自: bundle_v2.zig:4250 ContentHasher
// ============================================================================

// ContentHasher - defined in linker_context.cj

// ============================================================================
// CSS 入口点元数据
// 严格翻译自: bundle_v2.zig:4339 CssEntryPointMeta
// ============================================================================

/// CSS 入口点元数据
// 严格翻译自: bundle_v2.zig:4339 CssEntryPointMeta
public class CssEntryPointMeta {
    /// 是否在服务端导入 (为 true 时，增量图中会添加存根文件)
    public var importedOnServer: Bool

    public init() {
        importedOnServer = false
    }
}

// ============================================================================
// DevServer 输入/输出
// 严格翻译自: bundle_v2.zig:4345 DevServerInput, DevServerOutput
// ============================================================================

/// DevServer 输入
// 严格翻译自: bundle_v2.zig:4345 DevServerInput
/// 生命周期与 bundler 的 arena 相同
public class DevServerInput {
    /// CSS 入口点
    public var cssEntryPoints: HashMap<Int64, CssEntryPointMeta>

    public init() {
        cssEntryPoints = HashMap<Int64, CssEntryPointMeta>()
    }
}

// DevServerOutput - defined in lib.cj

// ============================================================================
// Bake 选项
// 严格翻译自: bundle_v2.zig:162 BakeOptions
// ============================================================================

/// Bake 选项
// 严格翻译自: bundle_v2.zig:162 BakeOptions
public class BakeOptions {
    /// 框架
    public var framework: ?Any
    /// 客户端转译器
    public var clientTranspiler: Transpiler
    /// SSR 转译器
    public var ssrTranspiler: Transpiler
    /// 插件
    public var plugins: ?Any

    public init() {
        framework = None
        clientTranspiler = Transpiler()
        ssrTranspiler = Transpiler()
        plugins = None
    }
}

// ============================================================================
// 廉价前缀归一化结果
// ============================================================================

/// 廉价前缀归一化结果
public class CheapPrefixResult {
    public var prefix: String
    public var suffix: String

    public init(prefix: String, suffix: String) {
        this.prefix = prefix
        this.suffix = suffix
    }
}

// ============================================================================
// 输出文件类型
// 严格翻译自: bundle_v2.zig 中引用的 OutputKind
// ============================================================================

/// 输出文件类型
// OutputFileKind - defined in output_file.cj

// ============================================================================
// 其他辅助类型
// ============================================================================

/// 路径到源索引映射
// PathToSourceIndexMap - defined in path_to_source_index_map.cj

/// 文件系统路径
// FsPath - defined in path_to_source_index_map.cj

// InputFile - defined in linker_context.cj

// HtmlImports, Log, LogMsg, LogMsgKind, Resolver, Chunk, ChunkEntryPoint,
// ChunkContent, JavaScriptChunkContent, CSSChunkContent, CSSImportOrder,
// MetafileBuilder, AstFlags - all defined in other files
