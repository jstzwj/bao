// bao_bundler - JavaScript 打包器
// 对应 Bun: src/bundler/
package bao_bundler

import bao_core.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// 模块解析器
// 对应 Bun: src/resolver/
// ============================================================================

/// 模块类型
public enum ModuleType {
    | JavaScript
    | TypeScript
    | JSX
    | TSX
    | CSS
    | JSON
    | Wasm
    | Unknown
}

/// 模块信息
public class Module {
    public let path: String
    public let moduleType: ModuleType
    public var dependencies: ArrayList<String>
    public var ast: ?Program
    public var source: String

    public init(path: String, moduleType: ModuleType) {
        this.path = path
        this.moduleType = moduleType
        this.dependencies = ArrayList<String>()
        this.ast = None
        this.source = ""
    }
}

/// 模块解析器
/// 对应 Bun: src/resolver/lib.rs (~10000行)
public class Resolver {
    private var extensions: Array<String>
    private var mainFields: Array<String>
    private var conditions: Array<String>

    public init() {
        extensions = [".js", ".ts", ".jsx", ".tsx", ".mjs", ".cjs", ".json"]
        mainFields = ["module", "main"]
        conditions = ["import", "default"]
    }

    /// 解析模块路径
    public func resolve(importer: String, specifier: String): ?String {
        // 绝对路径
        if (Path.isAbsolute(specifier)) {
            return tryResolve(specifier)
        }

        // 相对路径
        if (specifier.startsWith("./") || specifier.startsWith("../")) {
            let dir = Path.dirname(importer)
            let fullPath = Path.join([dir, specifier])
            return tryResolve(fullPath)
        }

        // node_modules 查找
        return resolveNodeModules(importer, specifier)
    }

    /// 尝试解析 (添加扩展名)
    private func tryResolve(path: String): ?String {
        // 精确匹配
        if (fileExists(path)) {
            return Some(path)
        }
        // 添加扩展名
        for (ext in extensions) {
            let withExt = path + ext
            if (fileExists(withExt)) {
                return Some(withExt)
            }
        }
        // index 文件
        for (ext in extensions) {
            let indexPath = Path.join([path, "index${ext}"])
            if (fileExists(indexPath)) {
                return Some(indexPath)
            }
        }
        return None
    }

    /// 在 node_modules 中查找
    private func resolveNodeModules(importer: String, specifier: String): ?String {
        var dir = Path.dirname(importer)
        while (true) {
            let nmPath = Path.join([dir, "node_modules", specifier])
            let resolved = tryResolve(nmPath)
            match (resolved) {
                case Some(p) => return Some(p)
                case None => {}
            }
            // 尝试 package.json
            let pkgPath = Path.join([nmPath, "package.json"])
            if (fileExists(pkgPath)) {
                return Some(nmPath)
            }
            let parent = Path.dirname(dir)
            if (parent == dir) {
                break
            }
            dir = parent
        }
        return None
    }

    private func fileExists(path: String): Bool {
        try {
            std.fs.exists(path)
        } catch (_: Exception) {
            false
        }
    }
}

// ============================================================================
// 打包器
// 对应 Bun: src/bundler/bundle_v2.rs
// ============================================================================

/// 打包选项
public class BundleOptions {
    public var entryPoints: Array<String>
    public var outdir: String
    public var minify: Bool
    public var sourcemap: Bool
    public var target: String
    public var format: BundleFormat

    public init() {
        entryPoints = []
        outdir = "./dist"
        minify = false
        sourcemap = false
        target = "browser"
        format = BundleFormat.ESM
    }
}

/// 输出格式
public enum BundleFormat {
    | ESM
    | CJS
    | IIFE
}

/// 打包结果
public class BundleResult {
    public var outputFiles: ArrayList<OutputFile>
    public var errors: ArrayList<String>
    public var warnings: ArrayList<String>

    public init() {
        outputFiles = ArrayList<OutputFile>()
        errors = ArrayList<String>()
        warnings = ArrayList<String>()
    }

    public func hasErrors(): Bool {
        return errors.size > 0
    }
}

/// 输出文件
public class OutputFile {
    public let path: String
    public let content: Array<UInt8>

    public init(path: String, content: Array<UInt8>) {
        this.path = path
        this.content = content
    }
}

/// JavaScript 打包器
public class Bundler {
    private var resolver: Resolver
    private var parser: JsParser

    public init() {
        resolver = Resolver()
        parser = JsParser()
    }

    /// 执行打包
    public func bundle(options: BundleOptions): BundleResult {
        let result = BundleResult()

        for (entry in options.entryPoints) {
            if (!fileExists(entry)) {
                result.errors.append("Entry point not found: ${entry}")
                continue
            }

            // 1. 构建模块图
            let graph = buildModuleGraph(entry, result)
            if (result.hasErrors()) {
                continue
            }

            // 2. 生成输出
            let output = generateBundle(graph, options)
            result.outputFiles.append(output)
        }

        return result
    }

    /// 构建模块依赖图
    private func buildModuleGraph(entry: String, result: BundleResult): ArrayList<Module> {
        var graph = ArrayList<Module>()
        var visited = StringSet()
        var queue = ArrayList<String>()
        queue.append(entry)

        while (queue.size > 0) {
            let path = queue.removeAt(0)
            if (visited.contains(path)) {
                continue
            }
            visited.insert(path)

            let module = loadModule(path)
            match (module) {
                case Some(m) => {
                    graph.append(m)
                    // 将依赖加入队列
                    for (dep in m.dependencies) {
                        let resolved = resolver.resolve(path, dep)
                        match (resolved) {
                            case Some(p) => queue.append(p)
                            case None => result.warnings.append("Cannot resolve: ${dep} from ${path}")
                        }
                    }
                }
                case None => {
                    result.errors.append("Cannot load module: ${path}")
                }
            }
        }

        return graph
    }

    /// 加载模块
    private func loadModule(path: String): ?Module {
        let source = try {
            BaoFile.readAllText(path)
        } catch (_: Exception) {
            return None
        }

        let moduleType = detectModuleType(path)
        let module = Module(path, moduleType)
        module.source = source

        // 解析 AST
        let options = ParserOptions()
        options.sourceFile = path
        if (moduleType == ModuleType.TypeScript || moduleType == ModuleType.TSX) {
            options.ts = true
        }
        if (moduleType == ModuleType.JSX || moduleType == ModuleType.TSX) {
            options.jsx = true
        }

        let parseResult = parser.parse(source, options)
        module.ast = Some(parseResult.program)

        // 提取依赖
        module.dependencies = extractDependencies(parseResult.program)

        return Some(module)
    }

    /// 检测模块类型
    private func detectModuleType(path: String): ModuleType {
        let ext = Path.extname(path)
        match (ext) {
            case ".js" | ".mjs" | ".cjs" => ModuleType.JavaScript
            case ".ts" => ModuleType.TypeScript
            case ".jsx" => ModuleType.JSX
            case ".tsx" => ModuleType.TSX
            case ".css" => ModuleType.CSS
            case ".json" => ModuleType.JSON
            case ".wasm" => ModuleType.Wasm
            case _ => ModuleType.Unknown
        }
    }

    /// 从 AST 提取依赖
    private func extractDependencies(program: Program): ArrayList<String> {
        var deps = ArrayList<String>()
        // TODO: 遍历 AST 查找 import/require 声明
        return deps
    }

    /// 生成打包输出
    private func generateBundle(graph: ArrayList<Module>, options: BundleOptions): OutputFile {
        var sb = BaoStringBuilder()

        for (module in graph) {
            // TODO: 代码转换和优化
            sb.append("// ${module.path}\n")
            sb.append(BaoString(module.source))
            sb.append("\n\n")
        }

        let bytes = sb.build().utf8()
        let outputPath = Path.join([options.outdir, "bundle.js"])
        return OutputFile(outputPath, bytes)
    }
}
