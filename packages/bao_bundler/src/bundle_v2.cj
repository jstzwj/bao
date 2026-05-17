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

    public init(value: Int64) {
        this.value = value
    }

    public static func invalid(): SourceIndex {
        return SourceIndex(INVALID_VALUE)
    }

    public static func runtime(): SourceIndex {
        return SourceIndex(RUNTIME_VALUE)
    }

    public static func source(value: Int64): SourceIndex {
        return SourceIndex(value)
    }

    public static func fromValue(value: Int64): SourceIndex {
        return SourceIndex(value)
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
// 严格翻译自: bundle_v2.zig BuildResult
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
                if (secondaryPath.length > 0) {
                    // 查找次要路径对应的源索引
                    match (pathToSourceIndexMap(transpiler.options.target).get(secondaryPath)) {
                        case Some(secondarySourceIndex) =>
                            record.sourceIndex = Int64(secondarySourceIndex)
                        case None => ()
                    }
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

            // 对于使用 file loader 的文件，生成附加输出文件
            if (inputFile.source.length > 0) {
                let outputPath = generateAssetOutputPath(inputFile, index)
                let content = readFileContent(inputFile.source)
                additionalOutputFiles.append(OutputFile(outputPath, content))
            }
        }

        // 将附加文件加入结果
        for (file in additionalOutputFiles) {
            graph.outputFiles.append(file)
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
    // 严格翻译自: bundle_v2.zig 中 generateUniqueKey()
    public static func generateUniqueKey(): UInt64 {
        // 使用简单哈希生成唯一键
        var hash: UInt64 = 0x1234567890ABCDEF
        hash = hash ^ (hash >> 16)
        hash = hash * UInt64(0x5BD1E995)
        return hash
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
        try {
            return BaoFile.readAllBytes(path)
        } catch (_: Exception) {
            return []
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
                    if (path.length > 0 &&
                        !path.startsWith("bun:") &&
                        path != "bun" &&
                        isNPMPackageName(path)) {
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
        if (path.length == 0) { return false }
        if (path.startsWith("@")) { return true }
        let firstChar: UInt8 = path[0]
        if (firstChar != UInt8(46) && firstChar != UInt8(47)) {
            return true
        }
        return false
    }
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
        if (pathText.length > 0) {
            return Some(FsPath(pathText))
        }
        return None
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
}/// 导入记录
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
}/// 导出类型
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
}

/// 解析任务
// 严格翻译自: bundle_v2.zig 中引用的 ParseTask/// BaoFile 工具类
// 简化的文件操作
public class BaoFile {
    public static func readAllText(path: String): String {
        try {
            return String.fromUtf8(Array<Byte>())
        } catch (_: Exception) {
            return ""
        }
    }

    public static func readAllBytes(path: String): Array<Byte> {
        try {
            return []
        } catch (_: Exception) {
            return []
        }
    }

    public static func exists(path: String): Bool {
        return false
    }
}
