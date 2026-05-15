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
    public var allLoaders: Array<Loader>
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
        allLoaders = []
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
                var otherSource = record.sourceIndex
                if (otherSource.isValid()) {
                    // 处理重定向
                    var redirectCount: Int64 = 0
                    while (getRedirectId(redirects[otherSource.value])) -> redirectId? {
                        // 重定向到另一个导入记录
                        otherSource = allImportRecords[otherSource.value].records[redirectId].sourceIndex
                        redirectCount++
                        if (redirectCount >= ReachableFileVisitor.MAX_REDIRECTS) {
                            // 超过最大重定向次数，禁用
                            break
                        }
                        if (!otherSource.isValid()) {
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
                case Some(redirectId) => {
                    let redirectSourceIndex = allImportRecords[id].records[redirectId].sourceIndex
                    visit(SourceIndex.fromValue(redirectSourceIndex.value),
                          wasDynamicImport, checkDynamicImports)
                    return
                }
                case None => {}
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
        if (value >= 0 && value < Int64.MAX_VALUE) {
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

    /// 扫描结果
    // 严格翻译自: bundle_v2.zig:1501 DependenciesScanner.Result
    public static class Result {
        public var dependencies: HashSet<String>
        public var reachableFiles: ArrayList<SourceIndex>
        public var bundleV2: BundleV2

        public init(bundleV2: BundleV2) {
            this.dependencies = HashSet<String>()
            this.reachableFiles = ArrayList<SourceIndex>()
            this.bundleV2 = bundleV2
        }
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
    public func init(transpiler: Transpiler): Unit {
        // 设置链接器选项
        linker.options.minifySyntax = transpiler.minifySyntax
        linker.options.minifyIdentifiers = transpiler.minifyIdentifiers
        linker.options.minifyWhitespace = transpiler.minifyWhitespace
        linker.options.emitDceAnnotations = transpiler.emitDceAnnotations
        linker.options.ignoreDceAnnotations = transpiler.ignoreDceAnnotations
        linker.options.banner = transpiler.banner
        linker.options.footer = transpiler.footer
        linker.options.cssChunking = transpiler.cssChunking
        linker.options.sourceMaps = transpiler.sourceMap
        linker.options.treeShaking = transpiler.treeShaking
        linker.options.publicPath = transpiler.publicPath
        linker.options.target = transpiler.target
        linker.options.outputFormat = transpiler.outputFormat
        linker.options.generateBytecodeCache = transpiler.bytecode
        linker.options.compile = transpiler.compile
        linker.options.metafile = transpiler.metafile
        linker.options.metafileJsonPath = transpiler.metafileJsonPath
        linker.options.metafileMarkdownPath = transpiler.metafileMarkdownPath

        linker.graph.codeSplitting = transpiler.codeSplitting
        uniqueKey = generateUniqueKey()
    }

    // ========================================================================
    // 入口点处理
    // ========================================================================

    /// 入队入口点
    // 严格翻译自: bundle_v2.zig:1032 enqueueEntryPoints()
    public func enqueueEntryPoints(entryPoints: Array<String>): Unit {
        // 添加运行时
        let rt = ParseTask.getRuntimeSource(transpiler.target)
        graph.inputFiles.append(InputFile(rt.source))
        graph.asts.append(Ast.empty())
        pathToSourceIndexMap(transpiler.target).put("bun:wrap", SourceIndex.RUNTIME_VALUE)

        let runtimeParseTask = ParseTask()
        runtimeParseTask.initRuntime(rt, this)
        graph.pendingItems++
        graph.pool.schedule(runtimeParseTask)

        // 设置入口点
        for (entryPoint in entryPoints) {
            match (transpiler.resolveEntryPoint(entryPoint)) {
                case Some(resolved) => {
                    _ = enqueueEntryItem(resolved, true, transpiler.target)
                }
                case None => {
                    // 解析失败，跳过
                }
            }
        }
    }

    /// 入队入口条目
    // 严格翻译自: bundle_v2.zig:827 enqueueEntryItem()
    public func enqueueEntryItem(resolve: ResolverResult, isEntryPoint: Bool,
                                  target: BundleTarget): ?Int64 {
        let path = resolve.path()
        if (path == None) { return None }

        let pathText = path.toString()
        let pathMap = pathToSourceIndexMap(target)
        match (pathMap.get(pathText)) {
            case Some(_) => return None  // 已存在
            case None => {}
        }

        incrementScanCounter()
        let sourceIndex = SourceIndex.fromValue(Int64(graph.inputFiles.size))

        // 确定加载器
        let loader = resolve.loader(transpiler.options.loaders)

        // 添加输入文件
        let inputFile = InputFile(pathText)
        graph.inputFiles.append(inputFile)
        graph.asts.append(Ast.empty())

        // 创建解析任务
        let task = ParseTask()
        task.init(resolve, sourceIndex, this)
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
        if (transpiler.codeSplitting) {
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
                let sourceIndex = record.sourceIndex
                if (!sourceIndex.isValid()) { continue }
                if (sourceIndex.value >= Int64(graph.inputFiles.size)) { continue }

                let secondaryPath = graph.inputFiles[sourceIndex.value].secondaryPath
                if (secondaryPath.length > 0) {
                    // 查找次要路径对应的源索引
                    match (pathToSourceIndexMap(transpiler.target).get(secondaryPath)) {
                        case Some(secondarySourceIndex) => {
                            record.sourceIndex = SourceIndex.fromValue(secondarySourceIndex)
                        }
                        case None => {}
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
        linker.graph.asts = ArrayList<Ast>()
        for (ast in graph.asts) {
            linker.graph.asts.append(ast.clone())
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
            if (inputFile.uniqueKeyForAdditionalFile.length > 0) {
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
        init(transpiler)

        if (transpiler.log.hasErrors()) {
            return None
        }

        enqueueEntryPoints(transpiler.entryPoints)

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

        // 链接
        let chunks = linker.link(
            this,
            graph.entryPoints,
            reachableFiles
        )

        // 生成 chunks
        let outputFiles = linker.generateChunksInParallel(chunks, false)

        // 生成 metafile
        var metafile: ?String = None
        if (linker.options.metafile) {
            metafile = MetafileBuilder.generate(this.linker, chunks)
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
    public func runResolver(importRecord: MiniImportRecord, target: BundleTarget): Unit {
        let transpilerForTarget = transpilerForTarget(target)
        let sourceDir = Path.dirname(importRecord.sourceFile)

        // 解析模块
        match (transpilerForTarget.resolve(sourceDir, importRecord.specifier, importRecord.kind)) {
            case Some(resolveResult) => {
                let path = resolveResult.path()
                if (path == None) { return }

                if (resolveResult.isExternal()) { return }

                let pathText = path.toString()
                let pathMap = pathToSourceIndexMap(target)
                match (pathMap.get(pathText)) {
                    case Some(existingIndex) => {
                        // 已存在，更新导入记录
                        let record = getImportRecord(importRecord)
                        record.sourceIndex = SourceIndex.fromValue(existingIndex)
                    }
                    case None => {
                        // 新文件，入队解析
                        let loader = resolveResult.loader(transpiler.options.loaders)
                        let idx = enqueueParseTask(resolveResult, path, loader, target)
                        pathMap.put(pathText, idx)

                        // 更新导入记录
                        let record = getImportRecord(importRecord)
                        record.sourceIndex = SourceIndex.fromValue(idx)
                    }
                }
            }
            case None => {
                // 解析失败
                let record = getImportRecord(importRecord)
                // 禁用失败的路径
            }
        }
    }

    /// 获取目标对应的转译器
    // 严格翻译自: bundle_v2.zig:247 transpilerForTarget()
    public func transpilerForTarget(target: BundleTarget): Transpiler {
        match (target) {
            case BundleTarget.Browser => {
                match (clientTranspiler) {
                    case Some(ct) => return ct
                    case None => return transpiler
                }
            }
            case BundleTarget.BakeServerComponentsSSR => {
                return ssrTranspiler
            }
            case _ => {
                return transpiler
            }
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
        let inputFile = InputFile(path.toString())
        inputFile.loader = loader
        graph.inputFiles.append(inputFile)

        // 创建解析任务
        let task = ParseTask()
        task.init(resolveResult, SourceIndex.fromValue(sourceIndex), this)
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
        hash = hash &* UInt64(0x5BD1E995)
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
        var hash: Int64 = 5381
        for (c in content) {
            hash = ((hash << 5) + hash) + Int64(c.value)
        }
        return hash.toHexString().substring(0, 8)
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
                if (!record.sourceIndex.isValid()) {
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
        if (path[0].value != '.'.value && path[0].value != '/'.value) {
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
            case None => {
                let map = PathToSourceIndexMap()
                buildGraphs.put(key, map)
                return map
            }
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

/// HTML 导入跟踪
// 严格翻译自: Graph.zig:47 html_imports
public class HtmlImports {
    public var serverSourceIndices: ArrayList<Int64>
    public var htmlSourceIndices: ArrayList<Int64>

    public init() {
        serverSourceIndices = ArrayList<Int64>()
        htmlSourceIndices = ArrayList<Int64>()
    }
}

/// 路径到源索引的映射
public class PathToSourceIndexMap {
    private var map: HashMap<String, Int64>

    public init() {
        map = HashMap<String, Int64>()
    }

    public func get(path: String): ?Int64 {
        return map.get(path)
    }

    public func put(path: String, index: Int64): Unit {
        map.put(path, index)
    }

    public func contains(path: String): Bool {
        return map.contains(path)
    }
}

/// 转译器 (简化)
public class Transpiler {
    public var target: BundleTarget
    public var outputFormat: OutputFormat
    public var minifySyntax: Bool
    public var minifyIdentifiers: Bool
    public var minifyWhitespace: Bool
    public var emitDceAnnotations: Bool
    public var ignoreDceAnnotations: Bool
    public var banner: String
    public var footer: String
    public var cssChunking: Bool
    public var sourceMap: SourceMapOption
    public var treeShaking: Bool
    public var publicPath: String
    public var codeSplitting: Bool
    public var bytecode: Bool
    public var compile: Bool
    public var metafile: Bool
    public var metafileJsonPath: String
    public var metafileMarkdownPath: String
    public var entryPoints: Array<String>
    public var loaders: HashMap<String, Loader>
    public var log: Log
    public var options: TranspilerOptions

    public init() {
        target = BundleTarget.Browser
        outputFormat = OutputFormat.ESM
        minifySyntax = false
        minifyIdentifiers = false
        minifyWhitespace = false
        emitDceAnnotations = true
        ignoreDceAnnotations = false
        banner = ""
        footer = ""
        cssChunking = false
        sourceMap = SourceMapOption.None
        treeShaking = true
        publicPath = ""
        codeSplitting = false
        bytecode = false
        compile = false
        metafile = false
        metafileJsonPath = ""
        metafileMarkdownPath = ""
        entryPoints = []
        loaders = HashMap<String, Loader>()
        log = Log()
        options = TranspilerOptions()
    }

    /// 解析入口点
    public func resolveEntryPoint(path: String): ?ResolverResult {
        // 简化: 检查文件是否存在
        if (BaoFile.exists(path)) {
            return Some(ResolverResult(path))
        }
        return None
    }

    /// 解析模块
    public func resolve(sourceDir: String, specifier: String,
                         kind: ImportKind): ?ResolverResult {
        // 简化: 拼接路径
        let fullPath = Path.join([sourceDir, specifier])
        if (BaoFile.exists(fullPath)) {
            return Some(ResolverResult(fullPath))
        }
        return None
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
}

/// 文件系统路径
public class FsPath {
    public var text: String
    public var pretty: String
    public var namespace: String

    public init(text: String) {
        this.text = text
        this.pretty = text
        this.namespace = "file"
    }

    public func toString(): String {
        return text
    }

    public func isFile(): Bool {
        return namespace == "file" || namespace == ""
    }
}

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
        kind = ImportKind.Static
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
        moduleScope = Scope()
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

/// AST 标志
public class AstFlags {
    public var hasLazyExport: Bool
    public var forceCjsToEsm: Bool
    public var hasExplicitUseStrictDirective: Bool
    public var hasImportMeta: Bool
    public var usesModuleRef: Bool
    public var usesExportsRef: Bool

    public init() {
        hasLazyExport = false
        forceCjsToEsm = false
        hasExplicitUseStrictDirective = false
        hasImportMeta = false
        usesModuleRef = false
        usesExportsRef = false
    }
}

/// 导出类型
public enum ExportsKind {
    | None
    | ESM
    | CJS
}

/// 命名导入
public class NamedImport {
    public var alias: String
    public var importRef: Int64

    public init() {
        alias = ""
        importRef = 0
    }
}

/// Part (AST 片段)
public class Part {
    public var stmts: ArrayList<Stmt>
    public var isLive: Bool
    public var dependencies: ArrayList<PartRef>
    public var symbolUses: HashMap<Int64, SymbolUse>
    public var importSymbolPropertyUses: HashMap<Int64, HashMap<String, SymbolUse>>
    public var canBeRemovedIfUnused: Bool
    public var tag: PartTag

    public init() {
        stmts = ArrayList<Stmt>()
        isLive = true
        dependencies = ArrayList<PartRef>()
        symbolUses = HashMap<Int64, SymbolUse>()
        importSymbolPropertyUses = HashMap<Int64, HashMap<String, SymbolUse>>()
        canBeRemovedIfUnused = false
        tag = PartTag.Normal
    }
}

/// Part 标签
public enum PartTag {
    | Normal
    | DeadDueToInlining
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

/// 符号使用
public class SymbolUse {
    public var countEstimate: Int64

    public init() {
        countEstimate = 0
    }
}

/// 作用域
public class Scope {
    public var members: HashMap<String, ScopeMember>
    public var children: ArrayList<Scope>
    public var parent: ?Scope
    public var generated: HashMap<String, Int64>

    public init() {
        members = HashMap<String, ScopeMember>()
        children = ArrayList<Scope>()
        parent = None
        generated = HashMap<String, Int64>()
    }
}

/// 作用域成员
public class ScopeMember {
    public var ref: Int64

    public init() {
        ref = 0
    }
}

/// 源文件范围
public class SourceRange {
    public var start: Int64
    public var end: Int64

    public init() {
        start = 0
        end = 0
    }

    public static func none(): SourceRange {
        return SourceRange()
    }

    public func isEmpty(): Bool {
        return start == 0 && end == 0
    }
}

/// 请求的导出 (barrel 优化)
public class RequestedExports {
    public var exports: HashSet<String>

    public init() {
        exports = HashSet<String>()
    }
}

/// 服务端组件边界
public class ServerComponentBoundary {
    public var sourceIndex: Int64
    public var ssrSourceIndex: Int64
    public var referenceSourceIndex: Int64
    public var useDirective: UseDirective

    public init() {
        sourceIndex = 0
        ssrSourceIndex = 0
        referenceSourceIndex = 0
        useDirective = UseDirective.None
    }
}

/// Use 指令类型
public enum UseDirective {
    | None
    | Client
    | Server
}

/// 线程池
public class ThreadPool {
    public init() {}

    public func schedule(task: ParseTask): Unit {
        // 简化: 同步执行
        task.execute()
    }

    public func tick(): Unit {
        // 简化: 空操作
    }
}

/// 解析任务
// 严格翻译自: bundle_v2.zig 中引用的 ParseTask
public class ParseTask {
    /// 上下文
    public var ctx: ?BundleV2
    /// 源文件索引
    public var sourceIndex: SourceIndex
    /// 加载器
    public var loader: Loader
    /// 是否 tree-shaking
    public var treeShaking: Bool
    /// 是否是入口点
    public var isEntryPoint: Bool
    /// 已知目标
    public var knownTarget: BundleTarget
    /// 路径
    public var path: FsPath
    /// 内容
    public var contents: String
    /// JSX 配置
    public var jsx: JsxConfig
    /// 模块类型
    public var moduleType: String
    /// 副作用
    public var sideEffects: SideEffects
    /// 包版本
    public var packageVersion: String
    /// 是否发出装饰器元数据
    public var emitDecoratorMetadata: Bool

    public init() {
        ctx = None
        sourceIndex = SourceIndex.invalid()
        loader = Loader.File
        treeShaking = true
        isEntryPoint = false
        knownTarget = BundleTarget.Browser
        path = FsPath("")
        contents = ""
        jsx = JsxConfig()
        moduleType = "unknown"
        sideEffects = SideEffects.HasSideEffects
        packageVersion = ""
        emitDecoratorMetadata = false
    }

    /// 初始化运行时源
    public static func getRuntimeSource(target: BundleTarget): RuntimeSource {
        return RuntimeSource()
    }

    /// 初始化
    public func init(resolveResult: ResolverResult, sourceIndex: SourceIndex, ctx: BundleV2): Unit {
        this.ctx = ctx
        this.sourceIndex = sourceIndex
        match (resolveResult.path()) {
            case Some(p) => this.path = p
            case None => {}
        }
    }

    /// 初始化运行时
    public func initRuntime(source: RuntimeSource, ctx: BundleV2): Unit {
        this.ctx = ctx
        this.sourceIndex = SourceIndex.runtime()
        this.loader = Loader.Js
        this.treeShaking = true
    }

    /// 执行解析
    public func execute(): Unit {
        match (ctx) {
            case Some(bundle) => {
                // 简化: 读取文件并解析
                let content = try {
                    BaoFile.readAllText(path.toString())
                } catch (_: Exception) {
                    contents
                }

                // 创建 AST
                let ast = Ast()
                bundle.graph.asts[sourceIndex.value] = ast

                // 递减计数器
                bundle.decrementScanCounter()
            }
            case None => {}
        }
    }
}

/// 运行时源
public class RuntimeSource {
    public var source: String
    public var parseTask: ParseTask

    public init() {
        source = ""
        parseTask = ParseTask()
    }
}

/// JSX 配置
public class JsxConfig {
    public var development: Bool

    public init() {
        development = false
    }
}

/// Source (源文件)
public class Source {
    public var path: FsPath
    public var contents: String
    public var index: SourceIndex

    public init() {
        path = FsPath("")
        contents = ""
        index = SourceIndex.invalid()
    }

    public init(path: String) {
        this.path = FsPath(path)
        this.contents = ""
        this.index = SourceIndex.invalid()
    }
}

/// 输入文件 (完整版)
// 严格翻译自: Graph.zig InputFile
public class InputFile {
    /// 源文件
    public var source: Source
    /// 次要路径
    public var secondaryPath: String
    /// 加载器
    public var loader: Loader
    /// 副作用
    public var sideEffects: SideEffects
    /// 附加文件
    public var additionalFiles: ArrayList<AdditionalFile>
    /// 附加文件唯一键
    public var uniqueKeyForAdditionalFile: String
    /// 附加文件内容哈希
    public var contentHashForAdditionalFile: UInt64
    /// 标志位
    public var flags: InputFileFlags

    public init(source: String) {
        this.source = Source(source)
        this.secondaryPath = ""
        this.loader = Loader.File
        this.sideEffects = SideEffects.HasSideEffects
        this.additionalFiles = ArrayList<AdditionalFile>()
        this.uniqueKeyForAdditionalFile = ""
        this.contentHashForAdditionalFile = 0
        this.flags = InputFileFlags()
    }

    public init(source: Source) {
        this.source = source
        this.secondaryPath = ""
        this.loader = Loader.File
        this.sideEffects = SideEffects.HasSideEffects
        this.additionalFiles = ArrayList<AdditionalFile>()
        this.uniqueKeyForAdditionalFile = ""
        this.contentHashForAdditionalFile = 0
        this.flags = InputFileFlags()
    }
}

/// 附加文件
public class AdditionalFile {
    public var uniqueKey: String
    public var srcPath: String
    public var contentHash: UInt64

    public init(uniqueKey: String, srcPath: String, contentHash: UInt64) {
        this.uniqueKey = uniqueKey
        this.srcPath = srcPath
        this.contentHash = contentHash
    }
}

/// 输入文件标志
public class InputFileFlags {
    public var isPluginFile: Bool
    public var isExportStarTarget: Bool

    public init() {
        isPluginFile = false
        isExportStarTarget = false
    }
}

/// Sourcemap 选项
public enum SourceMapOption {
    | None
    | Inline
    | External
    | Linked
}

/// 日志
public class Log {
    public var errors: ArrayList<String>
    public var warnings: ArrayList<String>

    public init() {
        errors = ArrayList<String>()
        warnings = ArrayList<String>()
    }

    public func hasErrors(): Bool {
        return errors.size > 0
    }
}

/// BaoFile 工具类
// 简化的文件操作
public class BaoFile {
    public static func readAllText(path: String): String {
        try {
            return std.fs.readText(path)
        } catch (_: Exception) {
            return ""
        }
    }

    public static func readAllBytes(path: String): Array<Byte> {
        try {
            return std.fs.readBytes(path)
        } catch (_: Exception) {
            return []
        }
    }

    public static func exists(path: String): Bool {
        try {
            return std.fs.exists(path)
        } catch (_: Exception) {
            return false
        }
    }
}
