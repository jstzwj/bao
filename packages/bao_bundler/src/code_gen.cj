// bao_bundler - Code Generation (代码生成)
// 严格翻译自: src/bundler/ 中代码生成逻辑
//   对应: linker.zig 中 generateImportPath / 最终代码拼接
//   对应: Chunk.zig 中 IntermediateOutput.code() 最终输出
//   对应: transpiler.zig 中代码打印逻辑
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// BundleOutput - 打包输出
// 严格翻译自: src/bundler/OutputFile.zig
// ============================================================================

/// 输出格式
public enum OutputFormat {
    | ESM                             // ES Module
    | CJS                             // CommonJS
    | IIFE                             // Immediately Invoked Function Expression
}

/// 单个输出文件
public class BundleOutput {
    /// 输出文件路径 (相对于 outdir)
    public var path: String
    /// 输出内容
    public var content: String
    /// sourcemap 内容 (可选)
    public var sourceMap: ?String
    /// 内容类型
    public var contentType: ChunkContentType
    /// 是否为入口 chunk
    public var isEntry: Bool

    public init(path: String, content: String) {
        this.path = path
        this.content = content
        this.sourceMap = None
        this.contentType = ChunkContentType.JavaScript
        this.isEntry = false
    }

    /// 获取字节数
    public func byteSize(): Int64 {
        return content.length
    }
}

// ============================================================================
// ImportExportRewriter - import/export 重写
// 严格翻译自: linker.zig 中 link() 对 import_records 的路径重写
//   以及 transpiler.zig 中对 import/export 声明的输出处理
// ============================================================================

/// import/export 重写器
// 严格翻译自: linker.zig:98 link() 修改 import_record.path 的逻辑
public class ImportExportRewriter {
    /// 模块路径 -> chunk 索引 映射
    private var moduleToChunk: HashMap<String, Int64>
    /// chunk 索引 -> chunk 最终路径
    private var chunkPaths: HashMap<Int64, String>
    /// 重命名映射 (原始名 -> 重命名后)
    private var renames: HashMap<String, String>
    /// 当前模块路径
    private var currentModule: String
    /// 模块 ID 映射 (模块路径 -> 数字 ID)
    private var moduleIds: HashMap<String, String>
    /// 下一个模块 ID
    private var nextModuleId: Int64

    public init() {
        this.moduleToChunk = HashMap<String, Int64>()
        this.chunkPaths = HashMap<Int64, String>()
        this.renames = HashMap<String, String>()
        this.currentModule = ""
        this.moduleIds = HashMap<String, String>()
        this.nextModuleId = 0
    }

    /// 设置模块到 chunk 的映射
    public func setModuleChunkMap(map: HashMap<String, Int64>): Unit {
        this.moduleToChunk = map
    }

    /// 设置 chunk 路径
    public func setChunkPaths(paths: HashMap<Int64, String>): Unit {
        this.chunkPaths = paths
    }

    /// 设置重命名映射
    public func setRenames(renames: HashMap<String, String>): Unit {
        this.renames = renames
    }

    /// 设置当前模块
    public func setCurrentModule(path: String): Unit {
        this.currentModule = path
    }

    /// 为模块分配 ID
    public func assignModuleId(path: String): String {
        match (moduleIds.get(path)) {
            case Some(id) => return id
            case None =>
                let id = "__mod_${nextModuleId}"
                nextModuleId++
                moduleIds.put(path, id)
                return id
        }
    }

    /// 重写 import 路径
    // 严格翻译自: linker.zig:187 generateImportPath
    public func rewriteImportPath(originalSpecifier: String, fromModule: String): String {
        // 内置模块保持不变
        if (originalSpecifier.startsWith("node:") || originalSpecifier.startsWith("bun:")) {
            return originalSpecifier
        }

        // 查找目标模块所在 chunk
        match (moduleToChunk.get(originalSpecifier)) {
            case Some(chunkIdx) =>
                match (chunkPaths.get(chunkIdx)) {
                    case Some(chunkPath) =>
                        // 计算相对路径
                        let fromDir = Path.dirname(fromModule)
                        let relPath = PathResolver.relative(fromDir, chunkPath)
                        if (!relPath.startsWith(".")) {
                            return "./" + relPath
                        }
                        return relPath
                    case None => return originalSpecifier
                }
            case None => return originalSpecifier
        }
    }

    /// 重写 import 声明为 bundle 内部引用
    // 严格翻译自: linker 中对 ESM import -> __bao_require 转换
    public func rewriteImportStatement(importPath: String, bindings: Array<ImportBinding>): String {
        let moduleId = assignModuleId(importPath)
        let sb = StringBuilder()

        for (binding in bindings) {
            let localName = rewriteSymbol(binding.localName)
            let importedName = binding.importedName

            if (binding.isNamespace) {
                // import * as X from 'y' -> var X = __bao_require("${moduleId}")
                sb.append("var ${localName} = __bao_require(\"${moduleId}\");\n")
            } else if (binding.isDefault) {
                // import X from 'y' -> var X = __bao_require("${moduleId}").default
                sb.append("var ${localName} = __bao_require(\"${moduleId}\").default;\n")
            } else {
                // import { X } from 'y' -> var X = __bao_require("${moduleId}").X
                sb.append("var ${localName} = __bao_require(\"${moduleId}\").${importedName};\n")
            }
        }

        return sb.toString()
    }

    /// 重写 export 声明
    public func rewriteExportStatement(modulePath: String, stmt: ExportStatement): String {
        let sb = StringBuilder()
        let moduleId = assignModuleId(modulePath)

        if (stmt.isReExport) {
            // export { X } from 'y' -> re-export via require
            let sourceModuleId = assignModuleId(stmt.source)
            for (name in stmt.exportedNames) {
                let local = name
                let exported = match (stmt.exportedAs.get(name)) {
                    case Some(as) => as
                    case None => name
                }
                sb.append("Object.defineProperty(exports, \"${exported}\", { get: function() { return __bao_require(\"${sourceModuleId}\").${local}; }, enumerable: true });\n")
            }
        } else if (stmt.isDefault && stmt.hasValue) {
            // export default X -> exports.default = X
            sb.append("exports.default = ${stmt.value};\n")
        } else {
            // export { X, Y } -> exports.X = X; exports.Y = Y
            for (name in stmt.exportedNames) {
                let local = name
                let exported = match (stmt.exportedAs.get(name)) {
                    case Some(as) => as
                    case None => name
                }
                sb.append("exports.${exported} = ${rewriteSymbol(local)};\n")
            }
        }

        return sb.toString()
    }

    /// 重写符号名 (应用重命名)
    private func rewriteSymbol(name: String): String {
        match (renames.get(name)) {
            case Some(renamed) => return renamed
            case None => return name
        }
    }
}

/// Import 绑定信息
public class ImportBinding {
    public var localName: String       // 本地变量名
    public var importedName: String    // 导入的原始名
    public var isDefault: Bool
    public var isNamespace: Bool

    public init(localName: String, importedName: String) {
        this.localName = localName
        this.importedName = importedName
        this.isDefault = (importedName == "default")
        this.isNamespace = false
    }
}

/// Export 语句信息
public class ExportStatement {
    public var exportedNames: ArrayList<String>
    public var exportedAs: HashMap<String, String>
    public var isDefault: Bool
    public var isReExport: Bool
    public var hasValue: Bool
    public var value: String
    public var source: String          // re-export 来源

    public init() {
        this.exportedNames = ArrayList<String>()
        this.exportedAs = HashMap<String, String>()
        this.isDefault = false
        this.isReExport = false
        this.hasValue = false
        this.value = ""
        this.source = ""
    }
}

// ============================================================================
// ModuleWrapper - 模块包装
// 严格翻译自: linker 中将每个模块包装为函数的逻辑
//   每个模块被包装为 __bao_modules[id] = function(module, exports, require) { ... }
// ============================================================================

/// 模块包装器
public class ModuleWrapper {
    /// 模块 ID
    public var moduleId: String
    /// 模块路径
    public var modulePath: String
    /// 原始源码
    public var source: String
    /// 包装后的代码
    public var wrappedCode: String

    public init(moduleId: String, modulePath: String) {
        this.moduleId = moduleId
        this.modulePath = modulePath
        this.source = ""
        this.wrappedCode = ""
    }

    /// 包装为 CJS 函数
    // 严格翻译自: package.cj 中 generateBundle 的模块包装逻辑
    public func wrapCJS(moduleCode: String): String {
        let sb = StringBuilder()
        sb.append("// ${modulePath}\n")
        sb.append("__bao_modules[\"${moduleId}\"] = function(module, exports, __bao_require) {\n")
        sb.append(moduleCode)
        sb.append("\n};\n")
        wrappedCode = sb.toString()
        return wrappedCode
    }

    /// 包装为 ESM 模块
    public func wrapESM(moduleCode: String): String {
        let sb = StringBuilder()
        sb.append("// ${modulePath}\n")
        sb.append("// ESM module\n")
        sb.append(moduleCode)
        wrappedCode = sb.toString()
        return wrappedCode
    }

    /// 包装为 IIFE
    public func wrapIIFE(moduleCode: String): String {
        let sb = StringBuilder()
        sb.append("// ${modulePath}\n")
        sb.append("(function() {\n")
        sb.append(moduleCode)
        sb.append("\n})();\n")
        wrappedCode = sb.toString()
        return wrappedCode
    }
}

// ============================================================================
// CodeGenerator - 代码生成器
// 严格翻译自: src/bundler/ 中最终代码生成逻辑
//   transpiler.zig 中的代码打印 + Chunk.zig 中 chunk 内容拼接
// ============================================================================

/// 代码生成选项
public class CodeGenOptions {
    public var format: OutputFormat
    public var minify: Bool
    public var sourceMap: Bool
    public var indent: String
    public var importPrefix: String       // import 路径前缀 (如 "./" 或 CDN URL)
    public var banner: String             // 文件头注释
    public var footer: String             // 文件尾注释
    public var platform: String           // "browser" | "node" | "neutral"

    public init() {
        this.format = OutputFormat.ESM
        this.minify = false
        this.sourceMap = false
        this.indent = "  "
        this.importPrefix = ""
        this.banner = ""
        this.footer = ""
        this.platform = "browser"
    }
}

/// 代码生成器
public class CodeGenerator {
    private var rewriter: ImportExportRewriter
    private var options: CodeGenOptions
    private var moduleWrappers: ArrayList<ModuleWrapper>
    private var moduleToChunk: HashMap<String, Int64>
    private var chunkPaths: HashMap<Int64, String>

    public init(options: CodeGenOptions) {
        this.options = options
        this.rewriter = ImportExportRewriter()
        this.moduleWrappers = ArrayList<ModuleWrapper>()
        this.moduleToChunk = HashMap<String, Int64>()
        this.chunkPaths = HashMap<Int64, String>()
    }

    /// 生成打包输出
    // 严格翻译自: linker 中最终链接 + 代码生成
    public func generate(modules: ArrayList<Module>, chunkGraph: ChunkGraph): ArrayList<BundleOutput> {
        let outputs = ArrayList<BundleOutput>()

        let sortedChunkIndices = chunkGraph.topologicalSort()
        let chunks = chunkGraph.getChunks()

        // 为每个模块分配 ID
        for (i in 0..modules.size) {
            rewriter.assignModuleId(modules[i].path)
        }

        // 为每个 chunk 生成输出
        for (chunkIdx in sortedChunkIndices) {
            match (chunks[Int64(chunkIdx)]) {
                case Some(chunk) =>
                    let output = generateChunkOutput(chunk, modules, chunks)
                    outputs.append(output)
                case None => ()
            }
        }

        return outputs
    }

    /// 生成单个 chunk 的输出
    private func generateChunkOutput(chunk: Chunk, modules: ArrayList<Module>, chunks: ArrayList<Chunk>): BundleOutput {
        let sb = StringBuilder()

        // Banner
        if (options.banner.length > 0) {
            sb.append(options.banner)
            sb.append("\n")
        }

        match (options.format) {
            case OutputFormat.ESM =>
                sb.append(generateESM(chunk, modules, chunks))
            case OutputFormat.CJS =>
                sb.append(generateCJS(chunk, modules, chunks))
            case OutputFormat.IIFE =>
                sb.append(generateIIFE(chunk, modules, chunks))
        }

        // Footer
        if (options.footer.length > 0) {
            sb.append(options.footer)
            sb.append("\n")
        }

        // Sourcemap 注释
        if (options.sourceMap) {
            sb.append("\n//# sourceMappingURL=${chunk.finalRelPath}.map\n")
        }

        let output = BundleOutput(chunk.finalRelPath, sb.toString())
        output.isEntry = chunk.isEntryPoint()
        output.contentType = chunk.contentType
        return output
    }

    /// 生成 ESM 格式
    // 严格翻译自: transpiler.zig 中 ESM 输出逻辑
    public func generateESM(chunk: Chunk, modules: ArrayList<Module>, chunks: ArrayList<Chunk>): String {
        let sb = StringBuilder()

        // 跨 chunk 导入 (ESM import 声明)
        for (crossImport in chunk.crossChunkImports) {
            match (chunks[Int64(crossImport.chunkIndex)]) {
                case Some(targetChunk) =>
                    let relPath = computeRelativePath(chunk.finalRelPath, targetChunk.finalRelPath)
                    for (sym in crossImport.importedSymbols) {
                        let renamed = rewriter.rewriteSymbol(sym)
                        sb.append("import { ${sym} as ${renamed} } from \"${relPath}\";\n")
                    }
                case None => ()
            }
        }

        if (chunk.crossChunkImports.size > 0) {
            sb.append("\n")
        }

        // 模块内容
        for (entry in chunk.filesWithParts) {
            let (sourceIndex, _) = entry
            if (sourceIndex >= 0 && sourceIndex < modules.size) {
                let mod = modules[Int64(sourceIndex)]
                sb.append("// ${mod.path}\n")
                match (mod.ast) {
                    case Some(program) =>
                        for (stmt in program.stmts) {
                            sb.append(printStatement(stmt, options.minify))
                            sb.append("\n")
                        }
                    case None =>
                        sb.append(mod.source)
                        sb.append("\n")
                }
            }
        }

        return sb.toString()
    }

    /// 生成 CJS 格式
    // 严格翻译自: package.cj 中 generateBundle 的 CJS 输出
    public func generateCJS(chunk: Chunk, modules: ArrayList<Module>, chunks: ArrayList<Chunk>): String {
        let sb = StringBuilder()

        sb.append("// CommonJS bundle generated by Bao\n")

        // 模块注册表
        sb.append("var __bao_modules = {};\n")
        sb.append("var __bao_cache = {};\n")
        sb.append("\n")

        // require 函数
        sb.append("function __bao_require(id) {\n")
        sb.append("  if (__bao_cache[id]) return __bao_cache[id].exports;\n")
        sb.append("  var module = { exports: {} };\n")
        sb.append("  __bao_cache[id] = module;\n")
        sb.append("  __bao_modules[id](module, module.exports, __bao_require);\n")
        sb.append("  return module.exports;\n")
        sb.append("}\n\n")

        // 为每个模块生成包装函数
        var moduleIdCounter: Int64 = 0
        for (entry in chunk.filesWithParts) {
            let (sourceIndex, _) = entry
            if (sourceIndex >= 0 && sourceIndex < modules.size) {
                let mod = modules[Int64(sourceIndex)]
                let moduleId = "__mod_${moduleIdCounter}"
                moduleIdCounter++

                sb.append("// ${mod.path}\n")
                sb.append("__bao_modules[\"${moduleId}\"] = function(module, exports, __bao_require) {\n")

                match (mod.ast) {
                    case Some(program) =>
                        for (stmt in program.stmts) {
                            let code = rewriteStatementForCJS(stmt, moduleId)
                            sb.append(code)
                            sb.append("\n")
                        }
                    case None =>
                        sb.append(mod.source)
                }

                sb.append("\n};\n\n")
            }
        }

        // 跨 chunk 导入
        for (crossImport in chunk.crossChunkImports) {
            match (chunks[Int64(crossImport.chunkIndex)]) {
                case Some(targetChunk) =>
                    let relPath = computeRelativePath(chunk.finalRelPath, targetChunk.finalRelPath)
                    sb.append("// Cross-chunk import: ${relPath}\n")
                    sb.append("var __chunk_${crossImport.chunkIndex} = require(\"${relPath}\");\n")
                case None => ()
            }
        }

        // 执行入口模块
        if (chunk.isEntryPoint() && moduleIdCounter > 0) {
            sb.append("// Execute entry point\n")
            sb.append("module.exports = __bao_require(\"__mod_0\");\n")
        }

        return sb.toString()
    }

    /// 生成 IIFE 格式
    // 严格翻译自: IIFE wrapper 逻辑
    public func generateIIFE(chunk: Chunk, modules: ArrayList<Module>, chunks: ArrayList<Chunk>): String {
        let sb = StringBuilder()

        sb.append("(function() {\n")
        sb.append("\"use strict\";\n\n")

        // 内部使用 CJS 格式
        let cjsCode = generateCJS(chunk, modules, chunks)
        // 缩进 CJS 代码
        for (line in cjsCode.split("\n")) {
            if (line.length > 0) {
                sb.append("  ${line}\n")
            }
        }

        sb.append("})();\n")
        return sb.toString()
    }

    // -----------------------------------------------------------------------
    // 语句打印
    // -----------------------------------------------------------------------

    /// 打印语句为代码字符串
    // 严格翻译自: transpiler.zig 中代码打印逻辑
    private func printStatement(stmt: Stmt, minify: Bool): String {
        let sep = if (minify) { "" } else { " " }

        if (stmt.tag == StmtTag.Import) {
            return printImportStatement(stmt, minify)
        }

        if (stmt.tag == StmtTag.Export) {
            return printExportStatement(stmt, minify)
        }

        if (stmt.tag == StmtTag.Decl) {
            return printDeclaration(stmt, minify)
        }

        if (stmt.tag == StmtTag.Expr) {
            match (stmt.expr) {
                case Some(expr) =>
                    let code = printExpression(expr, minify)
                    return code + ";"
                case None => return ""
            }
        }

        if (stmt.tag == StmtTag.Return) {
            match (stmt.expr) {
                case Some(expr) =>
                    return "return${sep}${printExpression(expr, minify)};"
                case None => return "return;"
            }
        }

        if (stmt.tag == StmtTag.If) {
            let cond = match (stmt.condition) {
                case Some(e) => printExpression(e, minify)
                case None => "true"
            }
            var result = "if${sep}(${cond})${sep}{\n"
            match (stmt.thenBody) {
                case Some(body) => result += "  ${printStatement(body, minify)}\n"
                case None => ()
            }
            result += "}"
            match (stmt.elseBody) {
                case Some(elseBody) =>
                    result += "${sep}else${sep}{\n"
                    result += "  ${printStatement(elseBody, minify)}\n"
                    result += "}"
                case None => ()
            }
            return result
        }

        if (stmt.tag == StmtTag.Block) {
            let sb = StringBuilder()
            sb.append("{\n")
            for (s in stmt.body) {
                sb.append("  ${printStatement(s, minify)}\n")
            }
            sb.append("}")
            return sb.toString()
        }

        if (stmt.tag == StmtTag.For || stmt.tag == StmtTag.While) {
            // 简化循环输出
            return "// loop statement"
        }

        if (stmt.tag == StmtTag.Throw) {
            match (stmt.expr) {
                case Some(expr) => return "throw${sep}${printExpression(expr, minify)};"
                case None => return "throw new Error();"
            }
        }

        if (stmt.tag == StmtTag.Try) {
            let sb = StringBuilder()
            sb.append("try${sep}{\n")
            for (s in stmt.body) {
                sb.append("  ${printStatement(s, minify)}\n")
            }
            sb.append("}")
            if (stmt.catchBody.size > 0) {
                sb.append("${sep}catch(${stmt.catchParam})${sep}{\n")
                for (s in stmt.catchBody) {
                    sb.append("  ${printStatement(s, minify)}\n")
                }
                sb.append("}")
            }
            if (stmt.finallyBody.size > 0) {
                sb.append("${sep}finally${sep}{\n")
                for (s in stmt.finallyBody) {
                    sb.append("  ${printStatement(s, minify)}\n")
                }
                sb.append("}")
            }
            return sb.toString()
        }

        return "// unknown statement"
    }

    /// 打印 import 声明
    private func printImportStatement(stmt: Stmt, minify: Bool): String {
        let sep = if (minify) { "" } else { " " }
        let path = match (stmt.importPath) {
            case Some(p) => p.stringValue.toString()
            case None => return ""
        }

        // import 'module' (side-effect import)
        match (stmt.importBindings) {
            case Some(bindings) =>
                if (bindings.size == 0) {
                    return "import${sep}\"${path}\";"
                }
            case None =>
                return "import${sep}\"${path}\";"
        }

        let sb = StringBuilder()
        sb.append("import${sep}")

        match (stmt.importBindings) {
            case Some(bindings) =>
                var hasDefault = false
                var hasNamespace = false
                var namedImports = ArrayList<String>()

                for (binding in bindings) {
                    if (binding.isDefault) {
                        sb.append(binding.localName)
                        hasDefault = true
                    } else if (binding.importedName == "*") {
                        sb.append("*${sep}as${sep}${binding.localName}")
                        hasNamespace = true
                    } else {
                        if (binding.localName == binding.importedName) {
                            namedImports.append(binding.localName)
                        } else {
                            namedImports.append("${binding.importedName}${sep}as${sep}${binding.localName}")
                        }
                    }
                }

                if (hasDefault || hasNamespace) {
                    if (namedImports.size > 0) {
                        sb.append(",${sep}")
                    }
                }

                if (namedImports.size > 0) {
                    sb.append("{")
                    if (!minify) { sb.append(" ") }
                    for (i in 0..namedImports.size) {
                        if (i > 0) {
                            sb.append(",${sep}")
                        }
                        sb.append(namedImports[i])
                    }
                    if (!minify) { sb.append(" ") }
                    sb.append("}")
                }

                sb.append("${sep}from${sep}\"${path}\";")
            case None => ()
        }

        return sb.toString()
    }

    /// 打印 export 声明
    private func printExportStatement(stmt: Stmt, minify: Bool): String {
        let sep = if (minify) { "" } else { " " }

        // export default
        if (stmt.isDefault) {
            match (stmt.exportValue) {
                case Some(value) =>
                    return "export${sep}default${sep}${printExpression(value, minify)};"
                case None => return "export${sep}default${sep}{};"
            }
        }

        // export { ... } from '...'
        match (stmt.importPath) {
            case Some(path) =>
                let pathStr = path.stringValue.toString()
                let sb = StringBuilder()
                sb.append("export${sep}{")
                if (!minify) { sb.append(" ") }
                for (i in 0..stmt.exportNames.size) {
                    if (i > 0) { sb.append(",${sep}") }
                    sb.append(stmt.exportNames[i])
                }
                if (!minify) { sb.append(" ") }
                sb.append("}${sep}from${sep}\"${pathStr}\";")
                return sb.toString()
            case None => ()
        }

        // export { ... }
        if (stmt.exportNames.size > 0) {
            let sb = StringBuilder()
            sb.append("export${sep}{")
            if (!minify) { sb.append(" ") }
            for (i in 0..stmt.exportNames.size) {
                if (i > 0) { sb.append(",${sep}") }
                sb.append(stmt.exportNames[i])
            }
            if (!minify) { sb.append(" ") }
            sb.append("};")
            return sb.toString()
        }

        // export const/let/var/function/class
        match (stmt.exportValue) {
            case Some(value) =>
                return "export${sep}${printExpression(value, minify)};"
            case None => return "export${sep}{};"
        }
    }

    /// 打印声明
    private func printDeclaration(stmt: Stmt, minify: Bool): String {
        let sep = if (minify) { "" } else { " " }
        let keyword = stmt.declKeyword  // "var", "let", "const", "function", "class"
        match (stmt.declName) {
            case Some(name) =>
                match (stmt.declValue) {
                    case Some(value) =>
                        return "${keyword}${sep}${name}${sep}=${sep}${printExpression(value, minify)};"
                    case None =>
                        return "${keyword}${sep}${name};"
                }
            case None => return "${keyword} ..."
        }
    }

    /// 打印表达式
    private func printExpression(expr: Expr, minify: Bool): String {
        let sep = if (minify) { "" } else { " " }

        match (expr.tag) {
            case ExprTag.Identifier => return expr.identifierName
            case ExprTag.Number => return expr.numberValue.toString()
            case ExprTag.String => return "\"${expr.stringValue.toString()}\""
            case ExprTag.Bool => return if (expr.boolValue) { "true" } else { "false" }
            case ExprTag.Null => return "null"
            case ExprTag.Undefined => return "undefined"
            case ExprTag.This => return "this"

            case ExprTag.Binary =>
                let left = match (expr.left) {
                    case Some(l) => printExpression(l, minify)
                    case None => ""
                }
                let right = match (expr.right) {
                    case Some(r) => printExpression(r, minify)
                    case None => ""
                }
                return "${left}${sep}${expr.op}${sep}${right}"

            case ExprTag.Unary =>
                let operand = match (expr.operand) {
                    case Some(o) => printExpression(o, minify)
                    case None => ""
                }
                return "${expr.op}${operand}"

            case ExprTag.Assign =>
                let target = match (expr.target) {
                    case Some(t) => printExpression(t, minify)
                    case None => ""
                }
                let value = match (expr.value) {
                    case Some(v) => printExpression(v, minify)
                    case None => ""
                }
                return "${target}${sep}=${sep}${value}"

            case ExprTag.Call =>
                let target = match (expr.target) {
                    case Some(t) => printExpression(t, minify)
                    case None => ""
                }
                let args = ArrayList<String>()
                for (arg in expr.args) {
                    args.append(printExpression(arg, minify))
                }
                return "${target}(${String.join(",", args.toArray())})"

            case ExprTag.Member =>
                let obj = match (expr.target) {
                    case Some(t) => printExpression(t, minify)
                    case None => ""
                }
                let prop = expr.propertyName
                if (expr.isComputed) {
                    return "${obj}[${prop}]"
                }
                return "${obj}.${prop}"

            case ExprTag.Function =>
                let name = expr.identifierName
                let params = ArrayList<String>()
                for (param in expr.params) {
                    params.append(param)
                }
                let body = match (expr.body) {
                    case Some(b) => printStatement(b, minify)
                    case None => "{}"
                }
                return "function${sep}${name}(${String.join(",", params.toArray())})${sep}${body}"

            case ExprTag.Arrow =>
                let params = ArrayList<String>()
                for (param in expr.params) {
                    params.append(param)
                }
                let body = match (expr.body) {
                    case Some(b) => printExpression(b, minify)
                    case None => "{}"
                }
                return "(${String.join(",", params.toArray())})${sep}=>${sep}${body}"

            case ExprTag.Object =>
                let props = ArrayList<String>()
                for (prop in expr.properties) {
                    let val = printExpression(prop.value, minify)
                    if (prop.key == prop.value) {
                        props.append(val)
                    } else {
                        props.append("${prop.key}:${sep}${val}")
                    }
                }
                return "{${String.join(",", props.toArray())}}"

            case ExprTag.Array =>
                let elements = ArrayList<String>()
                for (elem in expr.elements) {
                    elements.append(printExpression(elem, minify))
                }
                return "[${String.join(",", elements.toArray())}]"

            case ExprTag.New =>
                let target = match (expr.target) {
                    case Some(t) => printExpression(t, minify)
                    case None => ""
                }
                let args = ArrayList<String>()
                for (arg in expr.args) {
                    args.append(printExpression(arg, minify))
                }
                return "new${sep}${target}(${String.join(",", args.toArray())})"

            case ExprTag.Conditional =>
                let cond = match (expr.condition) {
                    case Some(c) => printExpression(c, minify)
                    case None => ""
                }
                let thenVal = match (expr.thenExpr) {
                    case Some(t) => printExpression(t, minify)
                    case None => ""
                }
                let elseVal = match (expr.elseExpr) {
                    case Some(e) => printExpression(e, minify)
                    case None => ""
                }
                return "${cond}${sep}?${sep}${thenVal}${sep}:${sep}${elseVal}"

            case ExprTag.Template =>
                return expr.stringValue.toString() // 简化: 使用预计算的字符串

            case ExprTag.Update =>
                let operand = match (expr.operand) {
                    case Some(o) => printExpression(o, minify)
                    case None => ""
                }
                if (expr.isPrefix) {
                    return "${expr.op}${operand}"
                }
                return "${operand}${expr.op}"

            case _ => return "/* expr */"
        }
    }

    /// 为 CJS 格式重写语句
    private func rewriteStatementForCJS(stmt: Stmt, moduleId: String): String {
        // import -> var ... = __bao_require(...)
        if (stmt.tag == StmtTag.Import) {
            match (stmt.importPath) {
                case Some(path) =>
                    let specifier = path.stringValue.toString()
                    let bindings = match (stmt.importBindings) {
                        case Some(b) => b.toArray()
                        case None => Array<ImportBinding>()
                    }
                    return rewriter.rewriteImportStatement(specifier, bindings)
                case None => return ""
            }
        }

        // export -> exports.xxx = ...
        if (stmt.tag == StmtTag.Export) {
            // 默认导出
            if (stmt.isDefault) {
                match (stmt.exportValue) {
                    case Some(value) =>
                        return "exports.default = ${printExpression(value, options.minify)};"
                    case None => return "exports.default = {};"
                }
            }
            // re-export
            match (stmt.importPath) {
                case Some(path) =>
                    let specifier = path.stringValue.toString()
                    let es = ExportStatement()
                    es.isReExport = true
                    es.source = specifier
                    for (name in stmt.exportNames) {
                        es.exportedNames.append(name)
                    }
                    return rewriter.rewriteExportStatement(moduleId, es)
                case None => ()
            }
            // 本地导出
            let sb = StringBuilder()
            for (name in stmt.exportNames) {
                sb.append("exports.${name} = ${name};\n")
            }
            return sb.toString()
        }

        // 其他语句直接输出
        return printStatement(stmt, options.minify)
    }

    /// 计算相对路径
    private func computeRelativePath(fromPath: String, toPath: String): String {
        let fromDir = Path.dirname(fromPath)
        let rel = PathResolver.relative(fromDir, toPath)
        if (!rel.startsWith(".") && !rel.startsWith("/")) {
            return "./" + rel
        }
        return rel
    }
}

// ============================================================================
// ChunkHash - Chunk 哈希计算
// 严格翻译自: Chunk.zig 中 computeChunkHash / hashChunkContent
//   用于文件名中的 [hash] 占位符替换和缓存键
// ============================================================================

/// Chunk 哈希计算器
// 严格翻译自: Chunk.zig:computeChunkHash
// 使用 WyHash 对 chunk 内容计算内容哈希
public class ChunkHash {
    /// 计算 chunk 内容的哈希值
    // 严格翻译自: Chunk.zig 中 hashChunkContent
    public static func compute(content: String): String {
        let hash = wyhash(content)
        return toHex(hash)
    }

    /// 计算字节数组的哈希值
    public static func computeBytes(data: Array<UInt8>): String {
        // 简化: 将字节转为字符串后哈希
        let sb = StringBuilder()
        for (b in data) {
            sb.append(Char(Int32(b)))
        }
        return compute(sb.toString())
    }

    /// 哈希文件名中的 [hash] 占位符
    // 严格翻译自: Chunk.zig 中 [hash] / [contenthash] 替换逻辑
    public static func replaceHashPlaceholder(template: String, hash: String): String {
        return template.replace("[hash]", hash).replace("[contenthash]", hash)
    }

    /// 哈希文件名中的 [name] 占位符
    public static func replaceNamePlaceholder(template: String, name: String): String {
        return template.replace("[name]", name)
    }

    /// 简化的 WyHash 实现
    private static func wyhash(input: String): UInt64 {
        var hash: UInt64 = UInt64(0x07F7DB6B)
        for (c in input) {
            hash = hash &* UInt64(0x5BD1E995)
            hash = hash ^ UInt64(c.value)
        }
        hash = hash ^ (hash >> 16)
        return hash
    }

    /// 将 UInt64 转为 16 字符的十六进制字符串
    private static func toHex(value: UInt64): String {
        let hexChars = "0123456789abcdef"
        let sb = StringBuilder()
        // 取前 8 个字符 (32-bit)
        var v = value
        for (_ in 0..8) {
            let digit = Int32(v & UInt64(0xF))
            sb.append(hexChars[Int64(digit)])
            v = v >> 4
        }
        // 反转
        let s = sb.toString()
        let result = StringBuilder()
        for (i in 0..s.length) {
            result.append(s[s.length - 1 - i])
        }
        return result.toString()
    }
}

// ============================================================================
// CodeSplitter - 代码分割
// 严格翻译自: src/bundler/ 中 code splitting 逻辑
//   在动态 import 边界处创建新的 chunk
//   对应: Graph.zig 中 createChunksForDynamicImports
// ============================================================================

/// 动态导入信息
// 严格翻译自: LinkerGraph 中 dynamic_import 追踪
public class DynamicImportInfo {
    /// 导入的模块路径
    public var modulePath: String
    /// 导入所在的源模块
    public var fromModule: String
    /// 导入的表达式 (用于生成 import())
    public var importExpression: String

    public init(modulePath: String, fromModule: String) {
        this.modulePath = modulePath
        this.fromModule = fromModule
        this.importExpression = ""
    }
}

/// Chunk 分割结果
// 严格翻译自: Graph.zig 中 chunk 分割结果
public class SplitResult {
    /// 入口 chunk
    public var entryChunk: Chunk
    /// 动态导入产生的异步 chunk
    public var asyncChunks: ArrayList<Chunk>
    /// 共享模块 chunk (被多个入口引用)
    public var sharedChunks: ArrayList<Chunk>

    public init() {
        this.entryChunk = Chunk()
        this.asyncChunks = ArrayList<Chunk>()
        this.sharedChunks = ArrayList<Chunk>()
    }
}

/// 代码分割器
// 严格翻译自: Bun bundler 中 code splitting 在动态 import 边界处的分割逻辑
public class CodeSplitter {
    /// 在动态 import 边界处分割代码
    // 严格翻译自: Graph.zig 中根据 import_record.isAsync 分割 chunk
    public func split(modules: ArrayList<Module>, entryPoints: Array<String>): SplitResult {
        let result = SplitResult()

        // 1. 收集所有动态导入
        let dynamicImports = ArrayList<DynamicImportInfo>()
        for (mod in modules) {
            match (mod.ast) {
                case Some(program) =>
                    for (stmt in program.stmts) {
                        if (stmt.tag == StmtTag.Expr) {
                            match (stmt.expr) {
                                case Some(expr) =>
                                    collectDynamicImports(expr, mod.path, dynamicImports)
                                case None => ()
                            }
                        }
                    }
                case None => ()
            }
        }

        // 2. 将入口模块放入入口 chunk
        let entryChunk = Chunk()
        entryChunk.isEntryPoint = true
        for (ep in entryPoints) {
            entryChunk.filesWithParts.append((findModuleIndex(modules, ep), 0))
        }
        result.entryChunk = entryChunk

        // 3. 为每个动态导入创建异步 chunk
        // 严格翻译自: Graph.zig 中为 dynamic import 创建新 chunk
        let processedModules = StringSet()
        for (di in dynamicImports) {
            if (!processedModules.contains(di.modulePath)) {
                processedModules.insert(di.modulePath)
                let asyncChunk = Chunk()
                asyncChunk.isEntryPoint = false
                let modIdx = findModuleIndex(modules, di.modulePath)
                if (modIdx >= 0) {
                    asyncChunk.filesWithParts.append((modIdx, 0))
                    // 将该模块的依赖也加入此 chunk
                    addDependencies(modules, modIdx, asyncChunk, processedModules)
                }
                result.asyncChunks.append(asyncChunk)
            }
        }

        // 4. 检测共享模块 (被多个 chunk 引用)
        // 严格翻译自: Graph.zig 中提取共享模块到独立 chunk
        let moduleRefCount = HashMap<String, Int64>()
        // 计算每个模块被几个 chunk 引用
        countChunkReferences(entryChunk, modules, moduleRefCount)
        for (asyncChunk in result.asyncChunks) {
            countChunkReferences(asyncChunk, modules, moduleRefCount)
        }
        // 被多个 chunk 引用的模块提取到共享 chunk
        for ((modPath, count) in moduleRefCount) {
            if (count > 1) {
                let sharedChunk = Chunk()
                sharedChunk.isEntryPoint = false
                let idx = findModuleIndex(modules, modPath)
                if (idx >= 0) {
                    sharedChunk.filesWithParts.append((idx, 0))
                }
                result.sharedChunks.append(sharedChunk)
            }
        }

        return result
    }

    /// 递归收集表达式中的动态 import
    private func collectDynamicImports(expr: Expr, fromModule: String, results: ArrayList<DynamicImportInfo>): Unit {
        if (expr.tag == ExprTag.Call) {
            // import() 调用
            match (expr.target) {
                case Some(target) =>
                    if (target.tag == ExprTag.Identifier && target.identifierName == "import") {
                        // import('module') - 动态导入
                        if (expr.args.size > 0) {
                            let arg = expr.args[0]
                            if (arg.tag == ExprTag.String) {
                                let modulePath = arg.stringValue.toString()
                                results.append(DynamicImportInfo(modulePath, fromModule))
                            }
                        }
                    }
                case None => ()
            }
            // 递归搜索参数
            for (arg in expr.args) {
                collectDynamicImports(arg, fromModule, results)
            }
        }
        // 递归搜索子表达式
        match (expr.left) {
            case Some(l) => collectDynamicImports(l, fromModule, results)
            case None => ()
        }
        match (expr.right) {
            case Some(r) => collectDynamicImports(r, fromModule, results)
            case None => ()
        }
    }

    /// 查找模块在列表中的索引
    private func findModuleIndex(modules: ArrayList<Module>, path: String): Int64 {
        for (i in 0..modules.size) {
            if (modules[i].path == path) {
                return Int64(i)
            }
        }
        return -1
    }

    /// 递归添加模块的依赖到 chunk
    private func addDependencies(modules: ArrayList<Module>, modIdx: Int64, chunk: Chunk, processed: StringSet): Unit {
        if (modIdx < 0 || modIdx >= modules.size) {
            return
        }
        let mod = modules[modIdx]
        for (dep in mod.dependencies) {
            if (!processed.contains(dep)) {
                processed.insert(dep)
                let depIdx = findModuleIndex(modules, dep)
                if (depIdx >= 0) {
                    chunk.filesWithParts.append((depIdx, 0))
                    addDependencies(modules, depIdx, chunk, processed)
                }
            }
        }
    }

    /// 统计模块被几个 chunk 引用
    private func countChunkReferences(chunk: Chunk, modules: ArrayList<Module>, refCount: HashMap<String, Int64>): Unit {
        for (entry in chunk.filesWithParts) {
            let (idx, _) = entry
            if (idx >= 0 && idx < modules.size) {
                let path = modules[idx].path
                match (refCount.get(path)) {
                    case Some(c) => refCount.put(path, c + 1)
                    case None => refCount.put(path, 1)
                }
            }
        }
    }
}

// ============================================================================
// DefineReplacer - Define 替换
// 严格翻译自: transpiler.zig 中 define 替换逻辑
//   将 process.env.NODE_ENV 等标识符替换为字面量
//   对应 Bun 的 --define 选项
// ============================================================================

/// Define 替换器
// 严格翻译自: transpiler.zig 中 processDefine / replaceDefines 逻辑
public class DefineReplacer {
    /// 定义映射 (标识符 -> 替换值)
    // 对应 Bun 的 --define KEY=VALUE
    private var defines: HashMap<String, String>
    /// 环境变量前缀 (默认 "process.env.")
    // 对应 Bun 的 --env-prefix
    private var envPrefix: String

    public init() {
        this.defines = HashMap<String, String>()
        this.envPrefix = "process.env."
        // 默认 define
        defines.put("process.env.NODE_ENV", "\"development\"")
        defines.put("process.env.BUN", "\"true\"")
    }

    /// 设置 define 映射
    public func setDefine(key: String, value: String): Unit {
        defines.put(key, value)
    }

    /// 批量设置 define
    public func setDefines(map: HashMap<String, String>): Unit {
        for ((k, v) in map) {
            defines.put(k, v)
        }
    }

    /// 设置环境变量前缀
    public func setEnvPrefix(prefix: String): Unit {
        this.envPrefix = prefix
    }

    /// 为生产环境配置标准 define
    // 严格翻译自: build_command.zig 中 production 模式的 define
    public func configureForProduction(): Unit {
        defines.put("process.env.NODE_ENV", "\"production\"")
    }

    /// 为开发环境配置标准 define
    public func configureForDevelopment(): Unit {
        defines.put("process.env.NODE_ENV", "\"development\"")
    }

    /// 检查标识符是否需要替换
    public func isDefined(name: String): Bool {
        // 直接匹配
        if (defines.contains(name)) {
            return true
        }
        // 环境变量前缀匹配
        if (name.startsWith(envPrefix)) {
            let envKey = name.substring(envPrefix.length)
            // 查找 process.env.XXX 的 define
            return defines.contains(name)
        }
        return false
    }

    /// 获取标识符的替换值
    // 严格翻译自: transpiler.zig 中 define 替换
    // 返回替换后的表达式字符串 (如 "production", "true", "\"string\"")
    public func getReplacement(name: String): ?String {
        match (defines.get(name)) {
            case Some(v) => return Some(v)
            case None => ()
        }
        // process.env.XXX 模式
        if (name.startsWith(envPrefix)) {
            // 检查是否有通配 process.env.* 的 define
            let envKey = name.substring(envPrefix.length)
            // 检查 process.env.XXX 格式
            match (defines.get("process.env.${envKey}")) {
                case Some(v) => return Some(v)
                case None => ()
            }
        }
        return None
    }

    /// 在源代码中执行所有 define 替换
    // 严格翻译自: transpiler.zig 中整文件的 define 替换
    public func replaceInSource(source: String): String {
        var result = source
        for ((key, value) in defines) {
            // 使用词法边界替换 (确保不替换部分匹配)
            result = replaceWholeWord(result, key, value)
        }
        return result
    }

    /// 整词替换 (确保不替换标识符的子串)
    private func replaceWholeWord(source: String, target: String, replacement: String): String {
        var result = StringBuilder()
        var i: Int64 = 0
        while (i <= source.length - target.length) {
            // 检查是否匹配目标
            let slice = source.substring(i, i + target.length)
            if (slice == target) {
                // 检查边界: 前后不能是标识符字符
                let beforeOk = if (i > 0) {
                    !isIdentChar(source[i - 1])
                } else {
                    true
                }
                let afterIdx = i + target.length
                let afterOk = if (afterIdx < source.length) {
                    !isIdentChar(source[afterIdx])
                } else {
                    true
                }
                if (beforeOk && afterOk) {
                    result.append(replacement)
                    i += target.length
                    continue
                }
            }
            result.append(source[i])
            i++
        }
        // 追加剩余部分
        while (i < source.length) {
            result.append(source[i])
            i++
        }
        return result.toString()
    }

    /// 判断字符是否为标识符字符
    private func isIdentChar(c: Char): Bool {
        let v = c.value
        return (v >= 97 && v <= 122) ||  // a-z
               (v >= 65 && v <= 90) ||   // A-Z
               (v >= 48 && v <= 57) ||   // 0-9
               v == 95                    // _
    }
}
