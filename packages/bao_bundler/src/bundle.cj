// 严格翻译自: src/bundler/bundle_v2.zig, src/bundler/BundleThread.zig, src/bundler/Chunk.zig
// bao_bundler - Bundle 编排器: 协调 parse -> resolve -> tree-shake -> chunk -> codegen 流水线
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*

// ============================================================================
// Bundle 编排器
// 严格翻译自: src/bundler/bundle_v2.zig (BundleV2)
// 核心流程:
//   1. 解析入口点
//   2. 链接模块 (构建依赖图)
//   3. Tree-shaking (标记已使用/未使用)
//   4. 分块 (Chunk splitting)
//   5. 代码生成 (Codegen)
//   6. 输出文件
// ============================================================================

/// Bundle 阶段
/// 严格翻译自: src/bundler/bundle_v2.zig BundleStep
public enum BundlePhase {
    | Parse        // 解析源文件为 AST
    | Resolve      // 解析模块路径
    | Link         // 构建依赖图
    | TreeShake    // 标记已使用/未使用
    | Chunk        // 分块
    | CodeGen      // 代码生成
    | Output       // 写入文件
    | Done         // 完成
}

/// Bundle 选项
/// 严格翻译自: src/bundler/options.zig BundleOptions
public class BundleOptions {
    /// 入口点列表
    public var entryPoints: ArrayList<String>
    /// 输出目录
    public var outdir: String
    /// 输出文件名模式 (例: "[name].[hash].js")
    public var naming: String
    /// 目标平台
    public var target: BundleTarget
    /// 输出格式
    public var format: OutputFormat
    /// 是否 minify
    public var minify: Bool
    /// 是否生成 sourcemap
    public var sourcemap: SourcemapOption
    /// 外部依赖列表
    public var externals: ArrayList<String>
    /// define 替换
    public var defines: HashMap<String, String>
    /// 是否分割 chunk
    public var splitting: Bool
    /// 是否打包所有依赖 (不分包)
    public var packages: PackageMode
    /// 入口点命名 (用于 library 模式)
    public var entryNaming: ArrayList<String>
    /// 全局名称 (用于 IIFE/UMD)
    public var globalName: ?String
    /// 是否是 watch 模式
    public var watch: Bool
    /// 插件列表
    public var plugins: ArrayList<Plugin>
    /// 加载器映射
    public var loaders: HashMap<String, Loader>
    /// 条件 (resolve conditions)
    public var conditions: ArrayList<String>
    /// 是否 banner/footer
    public var banner: ?String
    public var footer: ?String
    /// 是否 emit CSS (而不是嵌入 JS)
    public var emitCSS: Bool
    /// 是否 public path
    public var publicPath: ?String
    /// 目标环境
    public var env: BundleEnv

    public init() {
        entryPoints = ArrayList<String>()
        outdir = "./dist"
        naming = "[name].js"
        target = BundleTarget.Browser
        format = OutputFormat.ESM
        minify = false
        sourcemap = SourcemapOption.None
        externals = ArrayList<String>()
        defines = HashMap<String, String>()
        splitting = false
        packages = PackageMode.Bundle
        entryNaming = ArrayList<String>()
        globalName = None
        watch = false
        plugins = ArrayList<Plugin>()
        loaders = HashMap<String, String>()
        conditions = ArrayList<String>()
        banner = None
        footer = None
        emitCSS = false
        publicPath = None
        env = BundleEnv()
    }
}

/// Bundle 目标
/// 严格翻译自: src/bundler/options.zig Target
public enum BundleTarget {
    | Browser
    | Node
    | Bun
}

/// 输出格式
/// 严格翻译自: src/bundler/options.zig Format
public enum OutputFormat {
    | ESM        // ES Module
    | CJS        // CommonJS
    | IIFE       // Immediately Invoked Function Expression
}

/// Sourcemap 选项
/// 严格翻译自: src/bundler/options.zig SourceMap
public enum SourcemapOption {
    | None
    | Inline
    | External
    | Linked
}

/// 包处理模式
public enum PackageMode {
    | Bundle      // 打包所有依赖
    | External    // 不打包 node_modules
    | Auto        // 自动决定
}

/// Bundle 环境配置
public class BundleEnv {
    public var nodeEnv: String

    public init() {
        nodeEnv = "production"
    }
}

/// 插件 (简化)
public class Plugin {}

/// 加载器 (简化)
public type Loader = String

/// Bundle 结果
/// 严格翻译自: src/bundler/bundle_v2.zig BundleResult
public class BundleResult {
    /// 输出文件列表
    public var outputFiles: ArrayList<OutputFile>
    /// 错误列表
    public var errors: ArrayList<BundleError>
    /// 警告列表
    public var warnings: ArrayList<BundleWarning>
    /// 总耗时 (毫秒)
    public var elapsed: Int64
    /// 各阶段耗时
    public var phaseTimings: HashMap<String, Int64>
    /// 入口点数量
    public var entryPointCount: Int64
    /// 模块总数
    public var moduleCount: Int64
    /// chunk 总数
    public var chunkCount: Int64
    /// 总输出大小
    public var totalSize: Int64

    public init() {
        outputFiles = ArrayList<OutputFile>()
        errors = ArrayList<BundleError>()
        warnings = ArrayList<BundleWarning>()
        elapsed = 0
        phaseTimings = HashMap<String, Int64>()
        entryPointCount = 0
        moduleCount = 0
        chunkCount = 0
        totalSize = 0
    }

    public func hasErrors(): Bool {
        return errors.size > 0
    }

    /// 添加输出文件
    public func addOutputFile(file: OutputFile): Unit {
        outputFiles.append(file)
        totalSize += file.content.size
    }
}

/// 输出文件
/// 严格翻译自: src/bundler/OutputFile.zig
public class OutputFile {
    /// 输出路径 (相对 outdir)
    public var path: String
    /// 输出内容
    public var content: Array<Byte>
    /// 是否是 source map
    public var isSourceMap: Bool
    /// 对应的源文件 (用于 source map)
    public var sourcePath: ?String
    /// 内容哈希
    public var hash: String

    public init(path: String, content: Array<Byte>) {
        this.path = path
        this.content = content
        this.isSourceMap = false
        this.sourcePath = None
        this.hash = ""
    }

    /// 内容大小 (字节)
    public func size(): Int64 {
        return content.size
    }
}

/// Bundle 错误
public class BundleError {
    public var message: String
    public var path: ?String
    public var phase: BundlePhase
    public var line: Int64
    public var column: Int64

    public init(message: String) {
        this.message = message
        this.path = None
        this.phase = BundlePhase.Parse
        this.line = 0
        this.column = 0
    }
}

/// Bundle 警告
public class BundleWarning {
    public var message: String
    public var path: ?String

    public init(message: String) {
        this.message = message
        this.path = None
    }
}

/// Chunk 信息
/// 严格翻译自: src/bundler/Chunk.zig (Chunk)
public class Chunk {
    /// chunk ID
    public var id: Int64
    /// chunk 中的模块列表
    public var modules: ArrayList<String>
    /// 入口模块 (如果是入口 chunk)
    public var entryModule: ?String
    /// chunk 文件名
    public var filename: String
    /// 输出内容
    public var content: String
    /// 是否是入口 chunk
    public var isEntry: Bool
    /// 该 chunk 导入的其他 chunk
    public var imports: ArrayList<Int64>
    /// 该 chunk 的动态导入
    public var dynamicImports: ArrayList<Int64>
    /// CSS 内容 (如果有)
    public var cssContent: ?String
    /// source map 内容
    public var sourceMap: ?String

    public init(id: Int64) {
        this.id = id
        this.modules = ArrayList<String>()
        this.entryModule = None
        this.filename = ""
        this.content = ""
        this.isEntry = false
        this.imports = ArrayList<Int64>()
        this.dynamicImports = ArrayList<Int64>()
        this.cssContent = None
        this.sourceMap = None
    }
}

/// Bundle 编排器
/// 严格翻译自: src/bundler/bundle_v2.zig (BundleV2)
/// 协调整个打包流水线
public class Bundler {
    /// 选项
    private var options: BundleOptions
    /// 解析器
    private var resolver: Resolver
    /// 链接器
    private var linker: Linker
    /// Tree-shaker
    private var treeShaker: TreeShaker
    /// 代码生成器
    private var codeGen: CodeGenerator
    /// 解析缓存
    private var parseCache: HashMap<String, ParsedModule>
    /// 模块数量计数
    private var moduleCount: Int64

    public init() {
        options = BundleOptions()
        resolver = Resolver()
        linker = Linker(resolver)
        treeShaker = TreeShaker()
        codeGen = CodeGenerator()
        parseCache = HashMap<String, ParsedModule>()
        moduleCount = 0
    }

    /// 执行打包
    // 严格翻译自: src/bundler/bundle_v2.zig BundleV2.run
    public func bundle(opts: BundleOptions): BundleResult {
        let result = BundleResult()
        let startTime = Sys.currentTimeMillis()
        this.options = opts

        // 验证入口点
        if (opts.entryPoints.size == 0) {
            result.errors.append(BundleError("No entry points specified"))
            return result
        }

        // 阶段 1: 解析入口点
        let parseStart = Sys.currentTimeMillis()
        let parsedEntries = parseEntryPoints(opts.entryPoints, result)
        result.phaseTimings.put("parse", Sys.currentTimeMillis() - parseStart)

        if (result.hasErrors()) { return result }

        // 阶段 2: 链接模块
        let linkStart = Sys.currentTimeMillis()
        linker.setExternals(opts.externals)
        let linkOpts = LinkerOptions()
        linkOpts.target = match (opts.target) {
            case BundleTarget.Browser => "browser"
            case BundleTarget.Node => "node"
            case BundleTarget.Bun => "bun"
        }
        linker.setOptions(linkOpts)
        let linkResult = linker.link(opts.entryPoints)
        result.phaseTimings.put("link", Sys.currentTimeMillis() - linkStart)

        if (linkResult.hasErrors()) {
            for (err in linkResult.errors) {
                result.errors.append(BundleError(err.message))
            }
            return result
        }

        // 传播链接警告
        for (warn in linkResult.warnings) {
            result.warnings.append(BundleWarning(warn.message))
        }

        // 阶段 3: Tree-shaking
        let shakeStart = Sys.currentTimeMillis()
        let shakeResult = treeShaker.shake(linkResult.graph, opts)
        result.phaseTimings.put("tree-shake", Sys.currentTimeMillis() - shakeStart)

        // 阶段 4: 分块
        let chunkStart = Sys.currentTimeMillis()
        let chunks = createChunks(linkResult.graph, shakeResult, opts)
        result.phaseTimings.put("chunk", Sys.currentTimeMillis() - chunkStart)

        // 阶段 5: 代码生成
        let codegenStart = Sys.currentTimeMillis()
        let outputFiles = generateCode(chunks, opts, linkResult.graph)
        result.phaseTimings.put("codegen", Sys.currentTimeMillis() - codegenStart)

        // 阶段 6: 写入输出
        let outputStart = Sys.currentTimeMillis()
        for (file in outputFiles) {
            result.addOutputFile(file)
        }
        result.phaseTimings.put("output", Sys.currentTimeMillis() - outputStart)

        // 完成
        result.elapsed = Sys.currentTimeMillis() - startTime
        result.entryPointCount = opts.entryPoints.size
        result.moduleCount = linkResult.graph.size()
        result.chunkCount = chunks.size

        return result
    }

    /// 解析入口点
    // 严格翻译自: src/bundler/ParseTask.zig
    private func parseEntryPoints(entries: ArrayList<String>, result: BundleResult): ArrayList<ParsedModule> {
        let parsed = ArrayList<ParsedModule>()

        for (entry in entries) {
            let absPath = Path.resolve(entry)
            if (!BaoFile.exists(absPath)) {
                result.errors.append(BundleError("Entry point not found: ${absPath}"))
                continue
            }

            let module = parseModule(absPath)
            match (module) {
                case Some(m) => {
                    parseCache.put(absPath, m)
                    parsed.append(m)
                    moduleCount++
                }
                case None => {
                    result.errors.append(BundleError("Could not parse entry point: ${absPath}"))
                }
            }
        }

        return parsed
    }

    /// 解析单个模块
    private func parseModule(absPath: String): ?ParsedModule {
        // 检查缓存
        match (parseCache.get(absPath)) {
            case Some(m) => return Some(m)
            case None => {}
        }

        let source = BaoFile.readAllText(absPath)
        match (source) {
            case Some(src) => {
                let module = ParsedModule(absPath, src)
                return Some(module)
            }
            case None => return None
        }
    }

    /// 创建 Chunks
    // 严格翻译自: src/bundler/Chunk.zig Chunk creation
    private func createChunks(graph: DependencyGraph, shakeResult: ShakeResult, opts: BundleOptions): ArrayList<Chunk> {
        let chunks = ArrayList<Chunk>()
        let entries = graph.getEntryPoints()

        // 简单策略: 每个入口点一个 chunk
        var chunkId: Int64 = 0
        for (entryPath in entries) {
            let chunk = Chunk(chunkId)
            chunk.isEntry = true
            chunk.entryModule = Some(entryPath)

            // 收集该入口可达的所有模块 (排除外部依赖)
            let reachable = collectReachableModules(graph, entryPath, shakeResult.usedModules)
            for (mod in reachable) {
                chunk.modules.append(mod)
            }

            // 生成文件名
            let baseName = Path.basenameWithoutExt(entryPath)
            chunk.filename = opts.naming
                .replace("[name]", baseName)
                .replace("[hash]", computeChunkHash(chunk))

            // 解析 chunk 间的导入关系
            resolveChunkImports(chunk, graph, chunks, opts)

            chunks.append(chunk)
            chunkId++
        }

        // 如果启用 splitting, 拆分共享模块到单独的 chunk
        if (opts.splitting && chunks.size > 1) {
            let sharedChunks = extractSharedModules(chunks, graph, chunkId)
            for (sharedChunk in sharedChunks) {
                chunks.append(sharedChunk)
            }
        }

        return chunks
    }

    /// 收集从入口可达的所有模块
    // 严格翻译自: src/bundler/bundle_v2.zig 中 module graph traversal
    private func collectReachableModules(graph: DependencyGraph, entryPath: String, usedModules: HashSet<String>): ArrayList<String> {
        let result = ArrayList<String>()
        let visited = HashSet<String>()
        let queue = ArrayList<String>()
        queue.append(entryPath)

        while (queue.size > 0) {
            let path = queue.removeAt(0)
            if (visited.contains(path)) { continue }
            visited.add(path)

            // 跳过未使用的模块 (tree-shaking)
            if (usedModules.size > 0 && !usedModules.contains(path)) { continue }

            result.append(path)

            match (graph.getNode(path)) {
                case Some(node) => {
                    for (dep in node.dependencies) {
                        if (!visited.contains(dep)) {
                            queue.append(dep)
                        }
                    }
                }
                case None => {}
            }
        }

        return result
    }

    /// 解析 chunk 间的导入关系
    private func resolveChunkImports(chunk: Chunk, graph: DependencyGraph, existingChunks: ArrayList<Chunk>, opts: BundleOptions): Unit {
        // 检查 chunk 中的模块是否引用了其他 chunk 中的模块
        for (modPath in chunk.modules) {
            match (graph.getNode(modPath)) {
                case Some(node) => {
                    for (dep in node.dependencies) {
                        // 查找 dep 在哪个 chunk 中
                        for (otherChunk in existingChunks) {
                            if (otherChunk.modules.contains(dep) && otherChunk.id != chunk.id) {
                                if (!chunk.imports.contains(otherChunk.id)) {
                                    chunk.imports.append(otherChunk.id)
                                }
                            }
                        }
                    }
                }
                case None => {}
            }
        }
    }

    /// 提取共享模块到单独的 chunk
    // 严格翻译自: src/bundler/bundle_v2.zig chunk splitting
    private func extractSharedModules(chunks: ArrayList<Chunk>, graph: DependencyGraph, startId: Int64): ArrayList<Chunk> {
        let sharedChunks = ArrayList<Chunk>()

        // 计算每个模块出现在多少个 chunk 中
        let moduleChunkCount = HashMap<String, Int64>()
        for (chunk in chunks) {
            for (mod in chunk.modules) {
                let count = moduleChunkCount.get(mod) ?? 0
                moduleChunkCount.put(mod, count + 1)
            }
        }

        // 找出被多个 chunk 共享的模块
        let sharedModules = ArrayList<String>()
        for (entry in moduleChunkCount.entries()) {
            if (entry.value > 1) {
                sharedModules.append(entry.key)
            }
        }

        if (sharedModules.size > 0) {
            let sharedChunk = Chunk(startId)
            sharedChunk.isEntry = false
            sharedChunk.filename = "shared.[hash].js".replace("[hash]", computeModuleListHash(sharedModules))
            for (mod in sharedModules) {
                sharedChunk.modules.append(mod)
            }
            sharedChunks.append(sharedChunk)

            // 从各个 entry chunk 中移除共享模块
            for (chunk in chunks) {
                chunk.modules.removeAllWhere({ m => sharedModules.contains(m) })
                if (!chunk.imports.contains(startId)) {
                    chunk.imports.append(startId)
                }
            }
        }

        return sharedChunks
    }

    /// 生成代码
    // 严格翻译自: src/bundler/Chunk.zig Chunk.render
    private func generateCode(chunks: ArrayList<Chunk>, opts: BundleOptions, graph: DependencyGraph): ArrayList<OutputFile> {
        let outputFiles = ArrayList<OutputFile>()

        for (chunk in chunks) {
            let content = codeGen.generate(chunk, opts, graph)

            // JS/CSS 文件
            let jsBytes = content.toByteArray()
            let jsFile = OutputFile(chunk.filename, jsBytes)
            outputFiles.append(jsFile)

            // CSS (如果有)
            match (chunk.cssContent) {
                case Some(css) => {
                    if (opts.emitCSS) {
                        let cssFilename = chunk.filename.replace(".js", ".css")
                        let cssFile = OutputFile(cssFilename, css.toByteArray())
                        cssFile.isSourceMap = false
                        outputFiles.append(cssFile)
                    }
                }
                case None => {}
            }

            // Source map
            if (opts.sourcemap != SourcemapOption.None) {
                match (chunk.sourceMap) {
                    case Some(map) => {
                        let mapFilename = chunk.filename + ".map"
                        let mapFile = OutputFile(mapFilename, map.toByteArray())
                        mapFile.isSourceMap = true
                        outputFiles.append(mapFile)
                    }
                    case None => {}
                }
            }
        }

        return outputFiles
    }

    /// 计算 chunk 哈希
    private func computeChunkHash(chunk: Chunk): String {
        var input = ""
        for (mod in chunk.modules) {
            input = input + mod + ","
        }
        return Hash.shortHash(input)
    }

    /// 计算模块列表哈希
    private func computeModuleListHash(modules: ArrayList<String>): String {
        var input = ""
        for (mod in modules) {
            input = input + mod + ","
        }
        return Hash.shortHash(input)
    }
}

/// 已解析的模块
public class ParsedModule {
    public var path: String
    public var source: String

    public init(path: String, source: String) {
        this.path = path
        this.source = source
    }
}

/// Tree-shaking 结果
public class ShakeResult {
    /// 被标记为已使用的模块路径集合
    public var usedModules: HashSet<String>
    /// 被移除的模块数量
    public var removedCount: Int64

    public init() {
        usedModules = HashSet<String>()
        removedCount = 0
    }
}

/// Tree-shaker (简化接口)
public class TreeShaker {
    /// 执行 tree-shaking
    public func shake(graph: DependencyGraph, opts: BundleOptions): ShakeResult {
        let result = ShakeResult()
        // 从入口点开始标记所有可达模块
        let entries = graph.getEntryPoints()
        let visited = HashSet<String>()
        let queue = ArrayList<String>()

        for (ep in entries) {
            queue.append(ep)
        }

        while (queue.size > 0) {
            let path = queue.removeAt(0)
            if (visited.contains(path)) { continue }
            visited.add(path)
            result.usedModules.add(path)

            match (graph.getNode(path)) {
                case Some(node) => {
                    for (dep in node.dependencies) {
                        if (!visited.contains(dep)) {
                            queue.append(dep)
                        }
                    }
                }
                case None => {}
            }
        }

        result.removedCount = graph.size() - result.usedModules.size
        return result
    }
}

/// 代码生成器 (简化接口)
public class CodeGenerator {
    /// 为 chunk 生成代码
    public func generate(chunk: Chunk, opts: BundleOptions, graph: DependencyGraph): String {
        var output = ""

        // Banner
        match (opts.banner) {
            case Some(b) => output = output + b + "\n"
            case None => {}
        }

        // 模块导入声明 (ESM)
        if (opts.format == OutputFormat.ESM) {
            for (importChunkId in chunk.imports) {
                // 查找目标 chunk 的文件名
                let importPath = "./chunk-${importChunkId}.js"
                output = output + "import \"${importPath}\";\n"
            }
        }

        // 模块内容
        for (modPath in chunk.modules) {
            match (graph.getNode(modPath)) {
                case Some(node) => {
                    // 包装模块
                    let moduleContent = wrapModule(node, opts)
                    output = output + moduleContent + "\n"
                }
                case None => {}
            }
        }

        // 入口模块的导出
        if (chunk.isEntry) {
            match (chunk.entryModule) {
                case Some(entryPath) => {
                    match (graph.getNode(entryPath)) {
                        case Some(node) => {
                            output = output + generateExports(node, opts)
                        }
                        case None => {}
                    }
                }
                case None => {}
            }
        }

        // Footer
        match (opts.footer) {
            case Some(f) => output = output + f + "\n"
            case None => {}
        }

        return output
    }

    /// 包装模块
    private func wrapModule(node: ModuleNode, opts: BundleOptions): String {
        match (opts.format) {
            case OutputFormat.ESM => {
                return "// ${Path.basename(node.path)}\n${node.source}"
            }
            case OutputFormat.CJS => {
                return "// ${Path.basename(node.path)}\n${node.source}"
            }
            case OutputFormat.IIFE => {
                return "${node.source}"
            }
        }
    }

    /// 生成导出语句
    private func generateExports(node: ModuleNode, opts: BundleOptions): String {
        if (node.exports.size == 0) { return "" }

        var output = "\n"
        match (opts.format) {
            case OutputFormat.ESM => {
                let names = ArrayList<String>()
                for (exp in node.exports) {
                    if (exp.kind == ExportKind.Default) {
                        output = output + "export default __default__;\n"
                    } else {
                        names.append(exp.name)
                    }
                }
                if (names.size > 0) {
                    output = output + "export { ${names.join(", ")} };\n"
                }
            }
            case OutputFormat.CJS => {
                output = output + "module.exports = __exports__;\n"
            }
            case OutputFormat.IIFE => {
                output = output + "return __exports__;\n"
            }
        }
        return output
    }
}

/// Linker 引用 (避免循环)
public class Linker {
    private var resolver: Resolver
    private var externals: HashSet<String>
    private var options: LinkerOptions

    public init(resolver: Resolver) {
        this.resolver = resolver
        this.externals = HashSet<String>()
        this.options = LinkerOptions()
    }

    public func setExternals(exts: ArrayList<String>): Unit {
        for (ext in exts) {
            externals.add(ext)
        }
    }

    public func setOptions(opts: LinkerOptions): Unit {
        options = opts
    }

    public func link(entries: ArrayList<String>): LinkResult {
        // 简化: 返回空结果
        // 实际使用 bao_bundler.linker 中的完整实现
        let result = LinkResult()
        return result
    }
}

/// Linker 选项
public class LinkerOptions {
    public var target: String

    public init() {
        target = "browser"
    }
}

/// Linker 结果
public class LinkResult {
    public var graph: DependencyGraph
    public var errors: ArrayList<LinkError>
    public var warnings: ArrayList<LinkWarning>
    public var externals: ArrayList<String>

    public init() {
        graph = DependencyGraph()
        errors = ArrayList<LinkError>()
        warnings = ArrayList<LinkWarning>()
        externals = ArrayList<String>()
    }

    public func hasErrors(): Bool {
        return errors.size > 0
    }
}

/// Linker 错误
public class LinkError {
    public var message: String

    public init(message: String) {
        this.message = message
    }
}

/// Linker 警告
public class LinkWarning {
    public var message: String

    public init(message: String) {
        this.message = message
    }
}

/// 依赖图 (简化)
public class DependencyGraph {
    private var nodes: HashMap<String, ModuleNode>
    private var entryPoints: ArrayList<String>

    public init() {
        nodes = HashMap<String, ModuleNode>()
        entryPoints = ArrayList<String>()
    }

    public func addEntryPoint(path: String): Unit {
        entryPoints.append(path)
    }

    public func getOrAddNode(path: String): ModuleNode {
        match (nodes.get(path)) {
            case Some(n) => return n
            case None => {
                let n = ModuleNode(path)
                nodes.put(path, n)
                return n
            }
        }
    }

    public func addDependency(from: String, to: String): Unit {
        let fromNode = getOrAddNode(from)
        let toNode = getOrAddNode(to)
        if (!fromNode.dependencies.contains(to)) {
            fromNode.dependencies.append(to)
        }
    }

    public func getNode(path: String): ?ModuleNode {
        nodes.get(path)
    }

    public func getEntryPoints(): ArrayList<String> {
        return entryPoints
    }

    public func size(): Int64 {
        return nodes.size
    }
}

/// 模块节点 (简化)
public class ModuleNode {
    public var path: String
    public var dependencies: ArrayList<String>
    public var exports: ArrayList<ExportRecord>
    public var source: String

    public init(path: String) {
        this.path = path
        this.dependencies = ArrayList<String>()
        this.exports = ArrayList<ExportRecord>()
        this.source = ""
    }
}

/// 导出记录 (简化)
public class ExportRecord {
    public var kind: ExportKind
    public var name: String

    public init(kind: ExportKind, name: String) {
        this.kind = kind
        this.name = name
    }
}

/// 导出类型
public enum ExportKind {
    | Named
    | Default
    | ReexportAll
}

/// Hash 辅助
public class Hash {
    public static func shortHash(input: String): String {
        var h: Int64 = 5381
        for (i in 0..input.length) {
            h = ((h << 5) + h) + Int64(input[i])
        }
        return h.toHex().substring(0, 8)
    }
}

/// Resolver 引用
public class Resolver {}

/// LinkerOptions 引用
public class LinkerOptions {}

/// HashSet 引用
public class HashSet<T> {
    private var items: ArrayList<T>

    public init() {
        items = ArrayList<T>()
    }

    public func add(item: T): Unit {
        if (!contains(item)) {
            items.append(item)
        }
    }

    public func contains(item: T): Bool {
        return items.contains(item)
    }

    public func remove(item: T): Unit {
        items.remove(item)
    }

    public func clear(): Unit {
        items.clear()
    }

    public func size(): Int64 {
        return items.size
    }
}
