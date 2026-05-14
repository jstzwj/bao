// bao_bundler - JavaScript 打包器
// 对应 Bun: src/bundler/
package bao_bundler

import bao_core.*
import bao_collections.*
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
    /// 对应 Bun: src/bundler/ 中扫描 import/require 声明的逻辑
    /// 遍历顶层语句查找 import 声明和 require() 调用
    private func extractDependencies(program: Program): ArrayList<String> {
        let deps = ArrayList<String>()
        let stmts = program.stmts
        for (stmt in stmts) {
            // import 声明: import ... from 'specifier'
            if (stmt.tag == StmtTag.Import) {
                match (stmt.importPath) {
                    case Some(path) => {
                        let spec = path.stringValue.toString()
                        if (spec.length > 0) {
                            deps.append(spec)
                        }
                    }
                    case None => ()
                }
            }

            // export ... from 'specifier'
            if (stmt.tag == StmtTag.Export) {
                match (stmt.importPath) {
                    case Some(path) => {
                        let spec = path.stringValue.toString()
                        if (spec.length > 0) {
                            deps.append(spec)
                        }
                    }
                    case None => ()
                }
            }

            // require('specifier') — 检查顶层表达式语句
            if (stmt.tag == StmtTag.Expr) {
                match (stmt.expr) {
                    case Some(expr) => {
                        let reqSpec = extractRequireSpecifier(expr)
                        match (reqSpec) {
                            case Some(spec) => deps.append(spec)
                            case None => ()
                        }
                    }
                    case None => ()
                }
            }
        }
        return deps
    }

    /// 从表达式中提取 require() 的参数
    private func extractRequireSpecifier(expr: Expr): ?String {
        // require('path') 或 require("path")
        if (expr.tag == ExprTag.Call) {
            match (expr.target) {
                case Some(target) => {
                    if (target.tag == ExprTag.Identifier && target.identifierName == "require") {
                        if (expr.args.size > 0) {
                            let arg = expr.args[0]
                            if (arg.tag == ExprTag.String) {
                                return Some(arg.stringValue.toString())
                            }
                        }
                    }
                }
                case None => ()
            }
        }
        return None
    }

    /// 生成打包输出
    /// 对应 Bun: src/bundler/ 中代码生成和 chunk 拼接
    private func generateBundle(graph: ArrayList<Module>, options: BundleOptions): OutputFile {
        // 拓扑排序: 确保被依赖的模块在前
        let sorted = topologicalSort(graph)

        let sb = StringBuilder()

        // 输出格式头部
        match (options.format) {
            case BundleFormat.ESM => {
                // ESM 格式: 直接输出 import/export
            }
            case BundleFormat.CJS => {
                sb.append("// CommonJS bundle generated by Bao\n")
            }
            case BundleFormat.IIFE => {
                sb.append("(function() {\n")
            }
        }

        // 为每个模块生成包装函数
        let moduleMap = HashMap<String, Int64>()
        for (i in 0..sorted.size) {
            moduleMap.put(sorted[i].path, i)
        }

        // 模块注册表
        sb.append("// Module registry\n")
        sb.append("var __bao_modules = {};\n")
        sb.append("var __bao_cache = {};\n")
        sb.append("\n")

        // 定义每个模块
        for (i in 0..sorted.size) {
            let mod = sorted[i]
            let moduleId = "__module_${i}"

            // 包装为函数
            sb.append("// ${mod.path}\n")
            sb.append("__bao_modules[\"${moduleId}\"] = function(module, exports, require) {\n")

            // 使用 Printer 生成代码 (如果有 AST)
            match (mod.ast) {
                case Some(program) => {
                    let printerOptions = PrintOptions()
                    printerOptions.minify = options.minify
                    let printer = Printer(printerOptions)
                    let code = printer.printProgram(program.stmts)
                    sb.append(code)
                }
                case None => {
                    // 没有 AST，直接输出源码
                    sb.append(mod.source)
                }
            }

            sb.append("\n};\n\n")
        }

        // 运行入口模块
        if (sorted.size > 0) {
            let entryId = "__module_0"
            sb.append("// Execute entry point\n")
            sb.append("(function() {\n")
            sb.append("  var module = { exports: {} };\n")
            sb.append("  var exports = module.exports;\n")
            sb.append("  var __bao_require = function(id) {\n")
            sb.append("    if (__bao_cache[id]) return __bao_cache[id].exports;\n")
            sb.append("    var m = { exports: {} };\n")
            sb.append("    __bao_cache[id] = m;\n")
            sb.append("    __bao_modules[id](m, m.exports, __bao_require);\n")
            sb.append("    return m.exports;\n")
            sb.append("  };\n")
            sb.append("  __bao_modules[\"${entryId}\"](module, exports, __bao_require);\n")
            sb.append("})();\n")
        }

        // IIFE 闭合
        if (options.format == BundleFormat.IIFE) {
            sb.append("})();\n")
        }

        // sourcemap 注释
        if (options.sourcemap) {
            sb.append("\n//# sourceMappingURL=bundle.js.map\n")
        }

        let content = stringToBytes(sb.toString())
        let outputPath = Path.join([options.outdir, "bundle.js"])
        return OutputFile(outputPath, content)
    }

    /// 拓扑排序 — 确保依赖在前
    private func topologicalSort(modules: ArrayList<Module>): ArrayList<Module> {
        let result = ArrayList<Module>()
        let visited = HashSet<String>()
        let pathMap = HashMap<String, Module>()
        let adjList = HashMap<String, ArrayList<String>>()

        // 建立邻接表
        for (mod in modules) {
            pathMap.put(mod.path, mod)
            let deps = ArrayList<String>()
            for (dep in mod.dependencies) {
                let resolved = resolver.resolve(mod.path, dep)
                match (resolved) {
                    case Some(p) => deps.append(p)
                    case None => ()
                }
            }
            adjList.put(mod.path, deps)
        }

        // DFS 拓扑排序
        let visiting = HashSet<String>()
        func visit(path: String): Unit {
            if (visited.contains(path)) { return }
            if (visiting.contains(path)) { return }  // 循环依赖，跳过
            visiting.put(path)
            match (adjList.get(path)) {
                case Some(deps) => {
                    for (dep in deps) {
                        visit(dep)
                    }
                }
                case None => ()
            }
            visiting.remove(path)
            visited.put(path)
            match (pathMap.get(path)) {
                case Some(mod) => result.append(mod)
                case None => ()
            }
        }

        for (mod in modules) {
            visit(mod.path)
        }

        return result
    }

    /// 便捷方法：打包为字符串
    public func bundleToString(options: BundleOptions): String {
        let result = bundle(options)
        if (result.hasErrors()) {
            var sb = StringBuilder()
            for (err in result.errors) {
                sb.append("Error: ${err}\n")
            }
            return sb.toString()
        }
        if (result.outputFiles.size > 0) {
            let content = result.outputFiles[0].content
            let sb = StringBuilder()
            for (b in content) {
                sb.append(Char(Int32(b)))
            }
            return sb.toString()
        }
        return ""
    }

    private static func stringToBytes(s: String): Array<UInt8> {
        var bytes = Array<UInt8>()
        for (c in s) {
            bytes.append(UInt8(c.value))
        }
        return bytes
    }
}
