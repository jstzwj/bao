// 严格翻译自:
//   src/bundler/linker_context/MetafileBuilder.zig (1085行)
//   src/bundler/linker_context/postProcessJSChunk.zig (1125行, metafile 部分)
// bao_bundler - Metafile 生成: esbuild 兼容的 metafile JSON 输出
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*

// ============================================================================
// Metafile 构建器
// 严格翻译自: linker_context/MetafileBuilder.zig (1085行)
//
// 生成与 esbuild 格式兼容的 metafile JSON:
// {
//   "inputs": {
//     "path/to/file.js": {
//       "bytes": 1234,
//       "imports": [
//         { "path": "dependency.js", "kind": "import-statement" },
//         { "path": "external", "kind": "require-call", "external": true }
//       ],
//       "format": "esm"
//     }
//   },
//   "outputs": {
//     "path/to/output.js": {
//       "bytes": 5678,
//       "inputs": {
//         "path/to/file.js": { "bytesInOutput": 1200 }
//       },
//       "imports": [
//         { "path": "chunk.js", "kind": "import-statement" }
//       ],
//       "exports": ["default", "foo"],
//       "entryPoint": "path/to/file.js"
//     }
//   }
// }
// ============================================================================

/// Metafile 构建器
// 严格翻译自: MetafileBuilder.zig:31 MetafileBuilder
public class MetafileBuilder {

    /// 生成单个 chunk 的 JSON 片段
    // 严格翻译自: MetafileBuilder.zig:36 generateChunkJson()
    // 在并行 chunk 生成期间调用，结果存储在 chunk.metafile_chunk_json 中
    public static func generateChunkJson(
        linker: LinkerContext,
        chunk: Chunk,
        allChunks: ArrayList<Chunk>
    ): String {
        let sb = StringBuilder()
        let sources = linker.parseGraph.inputFiles

        // 开始 chunk 条目: "path/to/output.js": {
        writeJSONString(sb, chunk.finalRelPath)
        sb.append(": {")

        // 写入 bytes
        let chunkBytes = chunk.intermediateOutputSize
        sb.append("\n      \"bytes\": ${chunkBytes}")

        // 写入 inputs
        sb.append(",\n      \"inputs\": {")
        var firstChunkInput = true
        for (entry in chunk.filesWithParts.entries()) {
            let fileSourceIndex = entry.key
            let bytesInOutput = entry.value
            if (fileSourceIndex >= Int64(sources.size)) { continue }
            if (fileSourceIndex == SourceIndex.RUNTIME_VALUE) { continue }

            let inputFile = sources[fileSourceIndex]
            let filePath = inputFile.source.path.pretty
            if (filePath.length == 0) { continue }

            if (!firstChunkInput) {
                sb.append(",")
            }
            firstChunkInput = false

            sb.append("\n        ")
            writeJSONString(sb, filePath)
            sb.append(": {\n          \"bytesInOutput\": ${bytesInOutput}\n        }")
        }
        sb.append("\n      }")

        // 写入跨 chunk 导入
        sb.append(",\n      \"imports\": [")
        var firstChunkImport = true
        for (crossImport in chunk.crossChunkImports) {
            if (crossImport.chunkIndex >= Int64(allChunks.size)) { continue }

            if (!firstChunkImport) {
                sb.append(",")
            }
            firstChunkImport = false

            let importedChunk = allChunks[crossImport.chunkIndex]
            sb.append("\n        {\n          \"path\": ")
            writeJSONString(sb, importedChunk.finalRelPath)
            sb.append(",\n          \"kind\": ")
            writeJSONString(sb, crossImport.importKind.label())
            sb.append("\n        }")
        }
        sb.append("\n      ]")

        // 写入 exports
        sb.append(",\n      \"exports\": [")
        if (chunk.isEntryPoint) {
            let entrySourceIndex = chunk.entryPoint.sourceIndex
            if (entrySourceIndex < Int64(linker.graph.sortedAndFilteredExportAliases.size)) {
                let sortedExports = linker.graph.sortedAndFilteredExportAliases[entrySourceIndex]
                var firstExport = true
                for (alias in sortedExports) {
                    if (!firstExport) {
                        sb.append(",")
                    }
                    firstExport = false
                    sb.append("\n        ")
                    writeJSONString(sb, alias)
                }
                if (!firstExport) {
                    sb.append("\n      ")
                }
            }
        }
        sb.append("]")

        // 写入 entryPoint
        if (chunk.isEntryPoint) {
            let entrySourceIndex = chunk.entryPoint.sourceIndex
            if (entrySourceIndex < Int64(sources.size)) {
                let entrySource = sources[entrySourceIndex]
                if (entrySource.source.path.text.length > 0 &&
                    entrySource.source.path.pretty.length > 0) {
                    sb.append(",\n      \"entryPoint\": ")
                    writeJSONString(sb, entrySource.source.path.pretty)
                }
            }
        }

        // 写入 cssBundle (如果 JS chunk 有关联的 CSS)
        if (chunk.contentType == ChunkContentType.JavaScript &&
            chunk.cssChunkIndices.size > 0) {
            let cssChunkIndex = chunk.cssChunkIndices[0]
            if (cssChunkIndex < Int64(allChunks.size)) {
                let cssChunk = allChunks[cssChunkIndex]
                if (cssChunk.finalRelPath.length > 0) {
                    sb.append(",\n      \"cssBundle\": ")
                    writeJSONString(sb, cssChunk.finalRelPath)
                }
            }
        }

        sb.append("\n    }")

        return sb.toString()
    }

    /// 组装最终 metafile JSON
    // 严格翻译自: MetafileBuilder.zig:164 generate()
    // 在所有 chunks 并行生成后调用
    // chunk 引用 (unique_keys) 被解析为最终输出路径
    public static func generate(
        linker: LinkerContext,
        chunks: ArrayList<Chunk>
    ): String {
        let sb = StringBuilder()

        sb.append("{\n  \"inputs\": {")

        // 收集所有在 chunks 中的源文件
        let sources = linker.parseGraph.inputFiles
        let loaders = linker.parseGraph.loaders
        let importRecordsList = linker.graph.asts

        // 标记所有出现在 chunks 中的文件
        let seenSources = HashSet<Int64>()
        for (chunk in chunks) {
            for (entry in chunk.filesWithParts.entries()) {
                let sourceIndex = entry.key
                if (sourceIndex < Int64(sources.size)) {
                    seenSources.put(sourceIndex)
                }
            }
        }

        // 写入 inputs
        var firstInput = true
        let sourceIndices = seenSources.toArray()
        sourceIndices.sort()

        for (sourceIndex in sourceIndices) {
            let source = sources[sourceIndex]
            let filePath = source.source.path.pretty
            if (filePath.length == 0) { continue }

            if (!firstInput) {
                sb.append(",")
            }
            firstInput = false

            sb.append("\n    ")
            writeJSONString(sb, filePath)
            sb.append(": {\n")

            // bytes
            let bytes = source.source.contents.length
            sb.append("      \"bytes\": ${bytes},\n")

            // imports
            sb.append("      \"imports\": [")
            if (sourceIndex < Int64(importRecordsList.size)) {
                let ast = importRecordsList[sourceIndex]
                var firstImport = true
                for (record in ast.importRecords) {
                    if (!firstImport) {
                        sb.append(",")
                    }
                    firstImport = false

                    sb.append("\n        {\n          \"path\": ")
                    let importPath = if (record.sourceIndex.isValid() &&
                                          record.sourceIndex.value < Int64(sources.size)) {
                        sources[record.sourceIndex.value].source.path.pretty
                    } else {
                        record.path
                    }
                    writeJSONString(sb, importPath)
                    sb.append(",\n          \"kind\": ")
                    writeJSONString(sb, record.kind.label())
                    if (!record.sourceIndex.isValid()) {
                        sb.append(",\n          \"external\": true")
                    }
                    sb.append("\n        }")
                }
                if (!firstImport) {
                    sb.append("\n      ")
                }
            }
            sb.append("],\n")

            // format
            let format = if (sourceIndex < Int64(linker.graph.exportsKinds.size)) {
                match (linker.graph.exportsKinds[sourceIndex]) {
                    case ExportsKind.ESM => "esm"
                    case ExportsKind.CJS => "cjs"
                    case ExportsKind.None => "esm"
                }
            } else {
                "esm"
            }
            sb.append("      \"format\": \"${format}\"\n")

            sb.append("    }")
        }

        sb.append("\n  },\n")

        // 写入 outputs
        sb.append("  \"outputs\": {")
        var firstOutput = true
        for (chunk in chunks) {
            if (chunk.finalRelPath.length == 0) { continue }

            if (!firstOutput) {
                sb.append(",")
            }
            firstOutput = false

            // 使用预构建的 chunk JSON (如果有)
            match (chunk.metafileChunkJson) {
                case Some(json) => {
                    sb.append("\n    ")
                    sb.append(json)
                }
                case None => {
                    // 实时生成
                    sb.append("\n    ")
                    let json = generateChunkJson(linker, chunk, chunks)
                    sb.append(json)
                }
            }
        }

        sb.append("\n  }\n}")

        return sb.toString()
    }

    // ========================================================================
    // JSON 辅助方法
    // ========================================================================

    /// 写入 JSON 字符串 (转义特殊字符)
    // 严格翻译自: MetafileBuilder.zig 中 writeJSONString
    public static func writeJSONString(sb: StringBuilder, value: String): Unit {
        sb.append("\"")
        for (c in value) {
            match (c) {
                case '"' => sb.append("\\\"")
                case '\\' => sb.append("\\\\")
                case '\n' => sb.append("\\n")
                case '\r' => sb.append("\\r")
                case '\t' => sb.append("\\t")
                case _ => {
                    if (c.value < 0x20) {
                        sb.append("\\u${c.value.toHexString().padLeft(4, '0')}")
                    } else {
                        sb.append(c)
                    }
                }
            }
        }
        sb.append("\"")
    }

    /// 写入 JSON 数字
    public static func writeJSONNumber(sb: StringBuilder, value: Int64): Unit {
        sb.append(value.toString())
    }

    /// 写入 JSON 布尔
    public static func writeJSONBool(sb: StringBuilder, value: Bool): Unit {
        sb.append(if (value) "true" else "false")
    }
}

// ============================================================================
// 辅助类型 (Metafile 相关)
// ============================================================================

/// Metafile 输入信息
// 严格翻译自: MetafileBuilder.zig 中 MetafileInput
public class MetafileInput {
    /// 文件路径
    public var path: String
    /// 文件大小 (字节)
    public var bytes: Int64
    /// 导入列表
    public var imports: ArrayList<MetafileImport>
    /// 模块格式
    public var format: String

    public init(path: String) {
        this.path = path
        bytes = 0
        imports = ArrayList<MetafileImport>()
        format = "esm"
    }
}

/// Metafile 导入信息
// 严格翻译自: MetafileBuilder.zig 中 MetafileImport
public class MetafileImport {
    /// 导入路径
    public var path: String
    /// 导入类型标签
    public var kind: String
    /// 是否是外部导入
    public var external: Bool

    public init(path: String, kind: String) {
        this.path = path
        this.kind = kind
        external = false
    }
}

/// Metafile 输出信息
// 严格翻译自: MetafileBuilder.zig 中 MetafileOutput
public class MetafileOutput {
    /// 输出路径
    public var path: String
    /// 输出大小 (字节)
    public var bytes: Int64
    /// 输入文件及其在输出中的大小
    public var inputs: HashMap<String, Int64>
    /// 导入列表
    public var imports: ArrayList<MetafileImport>
    /// 导出名称列表
    public var exports: ArrayList<String>
    /// 入口点路径 (如果是入口 chunk)
    public var entryPoint: ?String
    /// 关联的 CSS bundle 路径
    public var cssBundle: ?String

    public init(path: String) {
        this.path = path
        bytes = 0
        inputs = HashMap<String, Int64>()
        imports = ArrayList<MetafileImport>()
        exports = ArrayList<String>()
        entryPoint = None
        cssBundle = None
    }

    /// 转换为 JSON
    public func toJson(): String {
        let sb = StringBuilder()
        MetafileBuilder.writeJSONString(sb, path)
        sb.append(": {\n")

        sb.append("      \"bytes\": ${bytes},\n")

        // inputs
        sb.append("      \"inputs\": {")
        var first = true
        for (entry in inputs.entries()) {
            if (!first) { sb.append(",") }
            first = false
            sb.append("\n        ")
            MetafileBuilder.writeJSONString(sb, entry.key)
            sb.append(": {\"bytesInOutput\": ${entry.value}}")
        }
        if (!first) { sb.append("\n      ") }
        sb.append("},\n")

        // imports
        sb.append("      \"imports\": [")
        var firstImport = true
        for (imp in imports) {
            if (!firstImport) { sb.append(",") }
            firstImport = false
            sb.append("\n        {\"path\": ")
            MetafileBuilder.writeJSONString(sb, imp.path)
            sb.append(", \"kind\": ")
            MetafileBuilder.writeJSONString(sb, imp.kind)
            if (imp.external) {
                sb.append(", \"external\": true")
            }
            sb.append("}")
        }
        if (!firstImport) { sb.append("\n      ") }
        sb.append("],\n")

        // exports
        sb.append("      \"exports\": [")
        var firstExport = true
        for (exp in exports) {
            if (!firstExport) { sb.append(",") }
            firstExport = false
            sb.append("\n        ")
            MetafileBuilder.writeJSONString(sb, exp)
        }
        if (!firstExport) { sb.append("\n      ") }
        sb.append("]")

        // entryPoint
        match (entryPoint) {
            case Some(ep) => {
                sb.append(",\n      \"entryPoint\": ")
                MetafileBuilder.writeJSONString(sb, ep)
            }
            case None => {}
        }

        // cssBundle
        match (cssBundle) {
            case Some(css) => {
                sb.append(",\n      \"cssBundle\": ")
                MetafileBuilder.writeJSONString(sb, css)
            }
            case None => {}
        }

        sb.append("\n    }")
        return sb.toString()
    }
}

/// 完整的 Metafile
// 严格翻译自: MetafileBuilder.zig 中完整 metafile 结构
public class Metafile {
    /// 输入文件
    public var inputs: HashMap<String, MetafileInput>
    /// 输出文件
    public var outputs: HashMap<String, MetafileOutput>

    public init() {
        inputs = HashMap<String, MetafileInput>()
        outputs = HashMap<String, MetafileOutput>()
    }

    /// 添加输入文件
    public func addInput(input: MetafileInput): Unit {
        inputs.put(input.path, input)
    }

    /// 添加输出文件
    public func addOutput(output: MetafileOutput): Unit {
        outputs.put(output.path, output)
    }

    /// 生成完整 JSON
    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{\n  \"inputs\": {")

        var first = true
        for (entry in inputs.entries()) {
            if (!first) { sb.append(",") }
            first = false
            sb.append("\n    ")
            sb.append(entry.value.toJson())
        }

        sb.append("\n  },\n  \"outputs\": {")

        first = true
        for (entry in outputs.entries()) {
            if (!first) { sb.append(",") }
            first = false
            sb.append("\n    ")
            sb.append(entry.value.toJson())
        }

        sb.append("\n  }\n}")
        return sb.toString()
    }
}
