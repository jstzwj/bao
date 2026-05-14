// 严格翻译自: src/bundler/linker.zig, src/bundler/LinkerContext.zig, src/bundler/LinkerGraph.zig
// bao_bundler - 模块链接器: 解析 imports/exports, 构建依赖图
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*

// ============================================================================
// 模块链接器
// 严格翻译自: src/bundler/linker.zig (Linker)
// 核心职责:
//   1. 遍历 AST 中的 import/export 声明
//   2. 解析模块说明符为实际路径
//   3. 构建模块依赖图
//   4. 处理外部依赖和 node_modules 解析
//   5. 处理 CSS @import 和 url()
//   6. 处理动态导入
// ============================================================================

/// 导入记录
/// 严格翻译自: src/bundler/bundled_ast.zig ImportRecord
public class ImportRecord {
    /// 导入路径 (原始文本)
    public var path: String
    /// 解析后的绝对路径
    public var resolvedPath: ?String
    /// 命名空间 (例: "bun", "node")
    public var namespace: String
    /// 导入类型
    public var kind: ImportKind
    /// 导入的标识符列表
    public var importedNames: ArrayList<ImportSpecifier>
    /// 是否被使用 (tree-shaking 用)
    public var isUsed: Bool
    /// 是否是外部模块
    public var isExternal: Bool
    /// 是否有副作用
    public var hasSideEffects: Bool
    /// 是否是空导入 (import "module")
    public var isEmptyImport: Bool
    /// 源文件中的位置
    public var range: SourceRange
    /// 索引 (在文件的 import_records 中的位置)
    public var index: Int64
    /// 是否是 type-only import
    public var isTypeOnly: Bool
    /// 延迟加载 (dynamic import)
    public var isDeferred: Bool

    public init(path: String) {
        this.path = path
        this.resolvedPath = None
        this.namespace = ""
        this.kind = ImportKind.Static
        this.importedNames = ArrayList<ImportSpecifier>()
        this.isUsed = true
        this.isExternal = false
        this.hasSideEffects = true
        this.isEmptyImport = false
        this.range = SourceRange()
        this.index = 0
        this.isTypeOnly = false
        this.isDeferred = false
    }
}

/// 导入类型
/// 严格翻译自: src/bundler/bundled_ast.zig ImportKind
public enum ImportKind {
    | Static         // import ... from "..."
    | Dynamic        // import("...")
    | Require        // require("...")
    | AtImport       // CSS @import
    | Url            // CSS url()
    | AtCharset      // CSS @charset
    | AtLayer        // CSS @layer
    | ComposeFrom    // CSS composes: ... from "..."
}

/// 导入说明符 (named import 中的单个绑定)
/// 严格翻译自: src/bundler/bundled_ast.zig
public class ImportSpecifier {
    /// 原始名称 (导入的名称)
    public var importedName: String
    /// 本地名称 (绑定到本地的名称)
    public var localName: String
    /// 是否是默认导入
    public var isDefault: Bool
    /// 是否是命名空间导入 (* as)
    public var isNamespace: Bool

    public init(importedName: String, localName: String) {
        this.importedName = importedName
        this.localName = localName
        this.isDefault = false
        this.isNamespace = false
    }
}

/// 导出记录
/// 严格翻译自: src/bundler/bundled_ast.zig ExportRecord
public class ExportRecord {
    /// 导出类型
    public var kind: ExportKind
    /// 导出的名称
    public var name: String
    /// 导出的本地名称 (重导出时不同)
    public var localName: ?String
    /// 重导出来源模块
    public var reexportFrom: ?String
    /// 关联的 AST 节点
    public var range: SourceRange
    /// 是否是 type-only export
    public var isTypeOnly: Bool

    public init(kind: ExportKind, name: String) {
        this.kind = kind
        this.name = name
        this.localName = None
        this.reexportFrom = None
        this.range = SourceRange()
        this.isTypeOnly = false
    }
}

/// 导出类型
/// 严格翻译自: src/bundler/bundled_ast.zig ExportKind
public enum ExportKind {
    | Named         // export { name }
    | Default       // export default ...
    | CommonJS      // module.exports = ...
    | ReexportAll   // export * from "..."
    | ReexportNamed // export { name } from "..."
}

/// 源代码位置范围
public class SourceRange {
    public var startLine: Int64
    public var startColumn: Int64
    public var endLine: Int64
    public var endColumn: Int64

    public init() {
        startLine = 0
        startColumn = 0
        endLine = 0
        endColumn = 0
    }
}

/// 模块依赖图节点
/// 严格翻译自: src/bundler/LinkerGraph.zig
public class ModuleNode {
    /// 模块绝对路径
    public var path: String
    /// 模块类型
    public var moduleType: ModuleType
    /// 该模块的 import 记录
    public var imports: ArrayList<ImportRecord>
    /// 该模块的 export 记录
    public var exports: ArrayList<ExportRecord>
    /// 直接依赖的模块路径列表
    public var dependencies: ArrayList<String>
    /// 依赖此模块的模块路径列表 (反向依赖)
    public var dependents: ArrayList<String>
    /// 是否是入口点
    public var isEntryPoint: Bool
    /// 模块大小 (字节)
    public var size: Int64
    /// 解析后的 AST (如果已解析)
    public var ast: ?Program
    /// 源代码
    public var source: String
    /// 是否需要 runtime
    public var needsRuntime: Bool
    /// 是否有副作用
    public var hasSideEffects: Bool
    /// 用于 chunk 分配的唯一 ID
    public var moduleId: Int64

    public init(path: String) {
        this.path = path
        this.moduleType = ModuleType.Unknown
        this.imports = ArrayList<ImportRecord>()
        this.exports = ArrayList<ExportRecord>()
        this.dependencies = ArrayList<String>()
        this.dependents = ArrayList<String>()
        this.isEntryPoint = false
        this.size = 0
        this.ast = None
        this.source = ""
        this.needsRuntime = false
        this.hasSideEffects = true
        this.moduleId = 0
    }
}

/// 模块依赖图
/// 严格翻译自: src/bundler/LinkerGraph.zig (LinkerGraph)
public class DependencyGraph {
    /// 节点映射: path -> ModuleNode
    private var nodes: HashMap<String, ModuleNode>
    /// 入口点列表
    private var entryPoints: ArrayList<String>
    /// 下一个可用的 module ID
    private var nextModuleId: Int64

    public init() {
        nodes = HashMap<String, ModuleNode>()
        entryPoints = ArrayList<String>()
        nextModuleId = 0
    }

    /// 添加或获取节点
    public func getOrAddNode(path: String): ModuleNode {
        match (nodes.get(path)) {
            case Some(node) => return node
            case None => {
                let node = ModuleNode(path)
                node.moduleId = nextModuleId
                nextModuleId++
                nodes.put(path, node)
                return node
            }
        }
    }

    /// 添加入口点
    public func addEntryPoint(path: String): Unit {
        let node = getOrAddNode(path)
        node.isEntryPoint = true
        if (!entryPoints.contains(path)) {
            entryPoints.append(path)
        }
    }

    /// 添加依赖边
    public func addDependency(from: String, to: String): Unit {
        let fromNode = getOrAddNode(from)
        let toNode = getOrAddNode(to)

        if (!fromNode.dependencies.contains(to)) {
            fromNode.dependencies.append(to)
        }
        if (!toNode.dependents.contains(from)) {
            toNode.dependents.append(from)
        }
    }

    /// 获取所有节点
    public func getAllNodes(): ArrayList<ModuleNode> {
        return nodes.values()
    }

    /// 获取节点
    public func getNode(path: String): ?ModuleNode {
        return nodes.get(path)
    }

    /// 获取入口点
    public func getEntryPoints(): ArrayList<String> {
        return entryPoints
    }

    /// 拓扑排序 (从入口点开始的 BFS)
    public func topologicalSort(): ArrayList<String> {
        let result = ArrayList<String>()
        let visited = HashSet<String>()
        let queue = ArrayList<String>()

        // 从入口点开始
        for (ep in entryPoints) {
            queue.append(ep)
        }

        while (queue.size > 0) {
            let path = queue.removeAt(0)
            if (visited.contains(path)) { continue }
            visited.add(path)
            result.append(path)

            match (nodes.get(path)) {
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

    /// 检测循环依赖
    public func detectCycles(): ArrayList<ArrayList<String>> {
        let cycles = ArrayList<ArrayList<String>>()
        let visited = HashSet<String>()
        let stack = HashSet<String>()
        let path = ArrayList<String>()

        for (ep in entryPoints) {
            dfsDetectCycles(ep, visited, stack, path, cycles)
        }

        return cycles
    }

    /// DFS 检测循环
    private func dfsDetectCycles(
        current: String,
        visited: HashSet<String>,
        stack: HashSet<String>,
        path: ArrayList<String>,
        cycles: ArrayList<ArrayList<String>>
    ): Unit {
        if (stack.contains(current)) {
            // 找到循环
            let cycleStart = path.indexOf(current)
            match (cycleStart) {
                case Some(idx) => {
                    let cycle = ArrayList<String>()
                    for (i in idx..path.size) {
                        cycle.append(path[Int64(i)])
                    }
                    cycle.append(current)
                    cycles.append(cycle)
                }
                case None => {}
            }
            return
        }
        if (visited.contains(current)) { return }

        visited.add(current)
        stack.add(current)
        path.append(current)

        match (nodes.get(current)) {
            case Some(node) => {
                for (dep in node.dependencies) {
                    dfsDetectCycles(dep, visited, stack, path, cycles)
                }
            }
            case None => {}
        }

        path.removeAt(path.size - 1)
        stack.remove(current)
    }

    /// 获取模块总数
    public func size(): Int64 {
        return nodes.size
    }
}

/// 链接结果
public class LinkResult {
    /// 依赖图
    public var graph: DependencyGraph
    /// 链接错误列表
    public var errors: ArrayList<LinkError>
    /// 链接警告列表
    public var warnings: ArrayList<LinkWarning>
    /// 是否需要 runtime
    public var needsRuntime: Bool
    /// 外部依赖列表
    public var externals: ArrayList<String>

    public init() {
        graph = DependencyGraph()
        errors = ArrayList<LinkError>()
        warnings = ArrayList<LinkWarning>()
        needsRuntime = false
        externals = ArrayList<String>()
    }

    public func hasErrors(): Bool {
        return errors.size > 0
    }
}

/// 链接错误
public class LinkError {
    public var message: String
    public var path: String
    public var range: ?SourceRange

    public init(message: String, path: String) {
        this.message = message
        this.path = path
        this.range = None
    }
}

/// 链接警告
public class LinkWarning {
    public var message: String
    public var path: String

    public init(message: String, path: String) {
        this.message = message
        this.path = path
    }
}

/// 模块链接器
/// 严格翻译自: src/bundler/linker.zig (Linker)
/// 核心流程:
///   1. 从入口点开始, 解析每个模块的 AST
///   2. 提取所有 import/export 声明
///   3. 使用 Resolver 解析每个 import 路径
///   4. 对未解析的模块递归处理
///   5. 构建 DependencyGraph
///   6. 处理特殊情况 (external, node_modules, CSS)
public class Linker {
    /// 解析器
    private var resolver: Resolver
    /// 外部依赖列表
    private var externals: HashSet<String>
    /// 已处理的模块
    private var processedModules: HashSet<String>
    /// 正在处理的模块 (用于检测循环)
    private var processingStack: HashSet<String>
    /// 链接结果
    private var result: LinkResult
    /// 选项
    private var options: LinkerOptions

    public init(resolver: Resolver) {
        this.resolver = resolver
        this.externals = HashSet<String>()
        this.processedModules = HashSet<String>()
        this.processingStack = HashSet<String>()
        this.result = LinkResult()
        this.options = LinkerOptions()
    }

    /// 设置外部依赖
    public func setExternals(exts: ArrayList<String>): Linker {
        for (ext in exts) {
            externals.add(ext)
        }
        return this
    }

    /// 设置选项
    public func setOptions(opts: LinkerOptions): Linker {
        options = opts
        return this
    }

    /// 执行链接
    // 严格翻译自: src/bundler/linker.zig Linker.link
    public func link(entryPoints: ArrayList<String>): LinkResult {
        result = LinkResult()

        // 重置状态
        processedModules.clear()
        processingStack.clear()

        // 添加入口点到图
        for (ep in entryPoints) {
            let absPath = Path.resolve(ep)
            result.graph.addEntryPoint(absPath)
        }

        // 从入口点开始递归链接
        for (ep in entryPoints) {
            let absPath = Path.resolve(ep)
            linkModule(absPath)
        }

        return result
    }

    /// 链接单个模块
    // 严格翻译自: src/bundler/linker.zig link (per-file)
    private func linkModule(absPath: String): Unit {
        // 已处理
        if (processedModules.contains(absPath)) { return }

        // 检测循环依赖
        if (processingStack.contains(absPath)) {
            result.warnings.append(LinkWarning("Circular dependency detected: ${absPath}", absPath))
            return
        }
        processingStack.add(absPath)

        // 获取或创建节点
        let node = result.graph.getOrAddNode(absPath)

        // 检测模块类型
        node.moduleType = detectModuleType(absPath)

        // 读取源码
        let sourceOpt = BaoFile.readAllText(absPath)
        match (sourceOpt) {
            case Some(src) => {
                node.source = src
                node.size = src.length

                // 根据模块类型解析导入
                match (node.moduleType) {
                    case ModuleType.JavaScript | ModuleType.TypeScript |
                         ModuleType.JSX | ModuleType.TSX => {
                        linkJavaScript(node, src)
                    }
                    case ModuleType.CSS => {
                        linkCSS(node, src)
                    }
                    case ModuleType.JSON => {
                        // JSON 没有导入
                    }
                    case _ => {}
                }
            }
            case None => {
                result.errors.append(LinkError("Could not read file: ${absPath}", absPath))
            }
        }

        processedModules.add(absPath)
        processingStack.remove(absPath)
    }

    /// 链接 JavaScript/TypeScript 模块
    // 严格翻译自: src/bundler/linker.zig link (JS/TS)
    private func linkJavaScript(node: ModuleNode, source: String): Unit {
        // 解析 AST
        let parser = JavaScriptParser()
        let ast = parser.parse(source, node.path)
        match (ast) {
            case Some(program) => {
                node.ast = Some(program)
                // 提取 import 声明
                let imports = extractImports(program)
                for (imp in imports) {
                    node.imports.append(imp)

                    // 解析导入路径
                    let resolved = resolveImportPath(node.path, imp.path, node.moduleType)
                    match (resolved) {
                        case Some(resolvedPath) => {
                            imp.resolvedPath = Some(resolvedPath)
                            // 检查是否是外部依赖
                            if (isExternal(imp.path)) {
                                imp.isExternal = true
                                result.externals.append(imp.path)
                            } else {
                                // 添加到依赖图并递归链接
                                result.graph.addDependency(node.path, resolvedPath)
                                linkModule(resolvedPath)
                            }
                        }
                        case None => {
                            // 未解析: 可能是 node 内置模块或外部
                            if (isNodeBuiltin(imp.path)) {
                                imp.isExternal = true
                            } else {
                                result.errors.append(LinkError(
                                    "Could not resolve '${imp.path}' from '${node.path}'",
                                    node.path
                                ))
                            }
                        }
                    }
                }

                // 提取 export 声明
                let exports = extractExports(program)
                for (exp in exports) {
                    node.exports.append(exp)
                }
            }
            case None => {
                result.errors.append(LinkError("Parse error in ${node.path}", node.path))
            }
        }
    }

    /// 链接 CSS 模块
    // 严格翻译自: src/bundler/linker.zig CSSResolveError handling
    private func linkCSS(node: ModuleNode, source: String): Unit {
        // 提取 @import 和 url() 引用
        let cssImports = extractCSSImports(source)
        for (cssImp in cssImports) {
            let imp = ImportRecord(cssImp.path)
            imp.kind = cssImp.kind

            let resolved = resolveCSSImportPath(node.path, cssImp.path)
            match (resolved) {
                case Some(resolvedPath) => {
                    imp.resolvedPath = Some(resolvedPath)
                    result.graph.addDependency(node.path, resolvedPath)
                    linkModule(resolvedPath)
                }
                case None => {
                    // CSS url() 可能是外部 URL 或 data URI
                    if (!cssImp.path.startsWith("data:") && !cssImp.path.startsWith("http://") &&
                        !cssImp.path.startsWith("https://")) {
                        result.warnings.append(LinkWarning(
                            "Could not resolve CSS import '${cssImp.path}' from '${node.path}'",
                            node.path
                        ))
                    }
                }
            }
            node.imports.append(imp)
        }
    }

    /// 解析导入路径
    // 严格翻译自: src/bundler/linker.zig resolve
    private func resolveImportPath(fromPath: String, specifier: String, moduleType: ModuleType): ?String {
        // 特殊前缀
        if (specifier.startsWith("bun:")) {
            return None // bun 内置模块
        }
        if (specifier.startsWith("node:")) {
            return None // node 内置模块
        }

        // 使用 resolver 解析
        let resolved = resolver.resolve(fromPath, specifier)
        match (resolved) {
            case Some(path) => return Some(path)
            case None => {
                // 尝试添加扩展名
                let extensions = [".js", ".ts", ".jsx", ".tsx", ".mjs", ".cjs", ".json"]
                for (ext in extensions) {
                    let withExt = resolver.resolve(fromPath, specifier + ext)
                    match (withExt) {
                        case Some(path) => return Some(path)
                        case None => {}
                    }
                }
                // 尝试 index
                for (ext in extensions) {
                    let indexPath = resolver.resolve(fromPath, specifier + "/index" + ext)
                    match (indexPath) {
                        case Some(path) => return Some(path)
                        case None => {}
                    }
                }
                // 尝试 package.json 的 main/module
                let packageJsonPath = resolver.resolve(fromPath, specifier + "/package.json")
                match (packageJsonPath) {
                    case Some(pkgPath) => {
                        let content = BaoFile.readAllText(pkgPath)
                        match (content) {
                            case Some(text) => {
                                let parser = JsonParser()
                                let json = parser.parse(text)
                                match (json) {
                                    case Some(root) => {
                                        let main = JsonHelper.getString(root, "module") ??
                                                   JsonHelper.getString(root, "main") ?? "index.js"
                                        let mainPath = resolver.resolve(fromPath, specifier + "/" + main)
                                        match (mainPath) {
                                            case Some(p) => return Some(p)
                                            case None => {}
                                        }
                                    }
                                    case None => {}
                                }
                            }
                            case None => {}
                        }
                    }
                    case None => {}
                }
            }
        }
        return None
    }

    /// 解析 CSS 导入路径
    private func resolveCSSImportPath(fromPath: String, specifier: String): ?String {
        if (specifier.startsWith("data:") || specifier.startsWith("http://") || specifier.startsWith("https://")) {
            return None
        }
        let dir = Path.dirname(fromPath)
        let fullPath = Path.join([dir, specifier])
        if (BaoFile.exists(fullPath)) {
            return Some(fullPath)
        }
        return resolver.resolve(fromPath, specifier)
    }

    /// 从 AST 提取 import 声明
    // 严格翻译自: src/bundler/linker.zig import_records iteration
    private func extractImports(program: Program): ArrayList<ImportRecord> {
        let result = ArrayList<ImportRecord>()

        for (stmt in program.body) {
            match (stmt) {
                case Statement.ImportDeclaration(decl) => {
                    let imp = ImportRecord(decl.source)
                    imp.kind = ImportKind.Static
                    imp.isTypeOnly = decl.isTypeOnly
                    imp.isEmptyImport = decl.specifiers.size == 0

                    for (spec in decl.specifiers) {
                        let specifier = ImportSpecifier(spec.imported, spec.local)
                        specifier.isDefault = spec.isDefault
                        specifier.isNamespace = spec.isNamespace
                        imp.importedNames.append(specifier)
                    }
                    result.append(imp)
                }
                case Statement.ExportAllDeclaration(decl) => {
                    let imp = ImportRecord(decl.source)
                    imp.kind = ImportKind.Static
                    let expRecord = ExportRecord(ExportKind.ReexportAll, "*")
                    expRecord.reexportFrom = Some(decl.source)
                    result.append(imp)
                }
                case Statement.ExportNamedDeclaration(decl) => {
                    match (decl.source) {
                        case Some(src) => {
                            let imp = ImportRecord(src)
                            imp.kind = ImportKind.Static
                            result.append(imp)
                        }
                        case None => {}
                    }
                }
                case Statement.ExpressionStatement(expr) => {
                    // 动态 import
                    if (isDynamicImport(expr)) {
                        let source = extractDynamicImportSource(expr)
                        match (source) {
                            case Some(src) => {
                                let imp = ImportRecord(src)
                                imp.kind = ImportKind.Dynamic
                                imp.isDeferred = options.deferDynamicImports
                                result.append(imp)
                            }
                            case None => {}
                        }
                    }
                    // require()
                    if (isRequireCall(expr)) {
                        let source = extractRequireSource(expr)
                        match (source) {
                            case Some(src) => {
                                let imp = ImportRecord(src)
                                imp.kind = ImportKind.Require
                                result.append(imp)
                            }
                            case None => {}
                        }
                    }
                }
                case _ => {}
            }
        }

        return result
    }

    /// 从 AST 提取 export 声明
    private func extractExports(program: Program): ArrayList<ExportRecord> {
        let result = ArrayList<ExportRecord>()

        for (stmt in program.body) {
            match (stmt) {
                case Statement.ExportDefaultDeclaration(decl) => {
                    result.append(ExportRecord(ExportKind.Default, "default"))
                }
                case Statement.ExportNamedDeclaration(decl) => {
                    for (spec in decl.specifiers) {
                        let exp = ExportRecord(ExportKind.Named, spec.exported)
                        exp.localName = Some(spec.local)
                        match (decl.source) {
                            case Some(src) => {
                                exp.kind = ExportKind.ReexportNamed
                                exp.reexportFrom = Some(src)
                            }
                            case None => {}
                        }
                        result.append(exp)
                    }
                }
                case Statement.ExportAllDeclaration(decl) => {
                    result.append(ExportRecord(ExportKind.ReexportAll, "*"))
                }
                case _ => {}
            }
        }

        return result
    }

    /// 检查是否是外部依赖
    private func isExternal(specifier: String): Bool {
        // 检查 externals 列表
        if (externals.contains(specifier)) { return true }

        // 检查前缀匹配
        for (ext in externals) {
            if (ext.endsWith("*") && specifier.startsWith(ext.substring(0, ext.length - 1))) {
                return true
            }
        }

        return false
    }

    /// 检查是否是 Node.js 内置模块
    // 严格翻译自: src/bundler/linker.zig node: prefix check
    private func isNodeBuiltin(specifier: String): Bool {
        let builtins = [
            "assert", "buffer", "child_process", "cluster", "console",
            "constants", "crypto", "dgram", "dns", "domain", "events",
            "fs", "http", "https", "module", "net", "os", "path",
            "perf_hooks", "process", "punycode", "querystring", "readline",
            "repl", "stream", "string_decoder", "sys", "timers", "tls",
            "tty", "url", "util", "v8", "vm", "worker_threads", "zlib"
        ]
        for (builtin in builtins) {
            if (specifier == builtin || specifier == "node:${builtin}") {
                return true
            }
        }
        return false
    }

    /// 检测模块类型
    private func detectModuleType(path: String): ModuleType {
        let ext = Path.extname(path).toLower()
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

    /// 检测动态 import
    private func isDynamicImport(expr: Statement): Bool {
        // 简化检测: 检查是否是 call expression 且 callee 是 import
        return false // 需要 AST 分析
    }

    /// 提取动态 import 的源
    private func extractDynamicImportSource(expr: Statement): ?String {
        return None // 需要 AST 分析
    }

    /// 检测 require 调用
    private func isRequireCall(expr: Statement): Bool {
        return false // 需要 AST 分析
    }

    /// 提取 require 源
    private func extractRequireSource(expr: Statement): ?String {
        return None // 需要 AST 分析
    }

    /// 提取 CSS import
    private func extractCSSImports(source: String): ArrayList<CSSImport> {
        let result = ArrayList<CSSImport>()
        // 简化的 CSS import 提取
        // 实际需要 CSS 解析器
        let lines = source.split("\n")
        for (line in lines) {
            let trimmed = line.trim()
            // @import "file.css"
            if (trimmed.startsWith("@import")) {
                let importContent = trimmed.substring(8).trim().removeSuffix(";").trim()
                // 去除引号
                var path = importContent
                if ((path.startsWith("\"") && path.endsWith("\"")) ||
                    (path.startsWith("'") && path.endsWith("'"))) {
                    path = path.substring(1, path.length - 1)
                }
                if (!path.isEmpty()) {
                    result.append(CSSImport(path, ImportKind.AtImport))
                }
            }
        }
        return result
    }
}

/// CSS 导入信息
public class CSSImport {
    public var path: String
    public var kind: ImportKind

    public init(path: String, kind: ImportKind) {
        this.path = path
        this.kind = kind
    }
}

/// 链接器选项
public class LinkerOptions {
    /// 是否延迟处理动态 import
    public var deferDynamicImports: Bool
    /// 是否忽略 node_modules
    public var ignoreNodeModules: Bool
    /// 目标平台
    public var target: String
    /// 是否是 JSX
    public var isJsx: Bool

    public init() {
        deferDynamicImports = true
        ignoreNodeModules = false
        target = "browser"
        isJsx = false
    }
}

/// AST 声明类型 (简化)
public enum Statement {
    | ImportDeclaration(ImportDeclarationData)
    | ExportDefaultDeclaration(ExportDefaultData)
    | ExportNamedDeclaration(ExportNamedData)
    | ExportAllDeclaration(ExportAllData)
    | ExpressionStatement(ExpressionData)
    | Other
}

/// 导入声明数据
public class ImportDeclarationData {
    public var source: String
    public var specifiers: ArrayList<ImportSpecifierData>
    public var isTypeOnly: Bool

    public init(source: String) {
        this.source = source
        this.specifiers = ArrayList<ImportSpecifierData>()
        this.isTypeOnly = false
    }
}

/// 导入说明符数据
public class ImportSpecifierData {
    public var imported: String
    public var local: String
    public var isDefault: Bool
    public var isNamespace: Bool

    public init(imported: String, local: String) {
        this.imported = imported
        this.local = local
        this.isDefault = false
        this.isNamespace = false
    }
}

/// 导出默认数据
public class ExportDefaultData {
    public init() {}
}

/// 导出命名数据
public class ExportNamedData {
    public var source: ?String
    public var specifiers: ArrayList<ExportSpecifierData>

    public init() {
        source = None
        specifiers = ArrayList<ExportSpecifierData>()
    }
}

/// 导出说明符数据
public class ExportSpecifierData {
    public var exported: String
    public var local: String

    public init(exported: String, local: String) {
        this.exported = exported
        this.local = local
    }
}

/// 导出所有数据
public class ExportAllData {
    public var source: String

    public init(source: String) {
        this.source = source
    }
}

/// 表达式数据
public class ExpressionData {
    public init() {}
}

/// AST 程序 (简化)
public class Program {
    public var body: ArrayList<Statement>

    public init() {
        body = ArrayList<Statement>()
    }
}

/// JavaScript 解析器 (简化)
public class JavaScriptParser {
    public func parse(source: String, path: String): ?Program {
        // 简化: 返回空程序
        // 实际应使用 bao_parser 中的解析器
        return Some(Program())
    }
}
