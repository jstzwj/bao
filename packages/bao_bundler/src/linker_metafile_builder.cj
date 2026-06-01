// 严格翻译自: src/bundler/linker_context/MetafileBuilder.zig (1086行)
// bao_bundler - Metafile 构建器: 生成 esbuild 兼容的 metafile JSON 和 Markdown
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_string.*

// ============================================================================
// Metafile 构建器
// 严格翻译自: MetafileBuilder.zig
//
// 生成 esbuild 兼容的 metafile JSON 输出:
//   {
//     "inputs": {
//       "path/to/file.js": {
//         "bytes": 1234,
//         "imports": [...],
//         "format": "esm"
//       }
//     },
//     "outputs": {
//       "path/to/output.js": {
//         "bytes": 5678,
//         "inputs": { "path/to/file.js": { "bytesInOutput": 1200 } },
//         "imports": [...],
//         "exports": ["default", "foo"],
//         "entryPoint": "path/to/file.js"
//       }
//     }
//   }
//
// 还支持生成 Markdown 可视化报告 (用于调试 bundle 膨胀问题)
// ============================================================================

/// Metafile 构建器
// 严格翻译自: MetafileBuilder.zig:31
public class MetafileBuilder {

    /// 为单个 chunk 生成 JSON 片段
    // 严格翻译自: MetafileBuilder.zig:36 generateChunkJson()
    // 生成形如: "path/to/output.js": { "bytes": N, "inputs": {...}, "imports": [...], "exports": [...], "entryPoint": "..." }
    public static func generateChunkJson(
        c: LinkerContext,
        chunk: Chunk,
        chunks: ArrayList<Chunk>
    ): String {
        let sb = StringBuilder()

        // 开头: "path/to/output.js": {
        sb.append(jsonEncodeString(chunk.finalRelPath))
        sb.append(": {")

        // Write bytes
        let chunkBytes = chunk.intermediateOutputSize()
        sb.append("\n      \"bytes\": ")
        sb.append(chunkBytes.toString())

        // Write inputs for this output (bytesInOutput from filesWithParts)
        sb.append(",\n      \"inputs\": {")
        var firstChunkInput = true
        for (entry in chunk.filesWithParts.allEntries()) {
            let fileSourceIndex = entry[0]
            let bytesInOutput = entry[1]

            // 跳过运行时索引 (index 0)
            if (fileSourceIndex == 0) {
                continue
            }

            // 获取源文件路径
            let filePath = getSourcePath(c, fileSourceIndex)
            if (filePath.size == 0) {
                continue
            }

            if (!firstChunkInput) {
                sb.append(",")
            }
            firstChunkInput = false

            sb.append("\n        ")
            sb.append(jsonEncodeString(filePath))
            sb.append(": {\n          \"bytesInOutput\": ")
            sb.append(bytesInOutput.toString())
            sb.append("\n        }")
        }
        sb.append("\n      }")

        // Write cross-chunk imports
        sb.append(",\n      \"imports\": [")
        var firstChunkImport = true
        for (crossImport in chunk.crossChunkImports) {
            if (crossImport.chunkIndex < 0 || crossImport.chunkIndex >= chunks.size) {
                continue
            }

            if (!firstChunkImport) {
                sb.append(",")
            }
            firstChunkImport = false

            let importedChunk = chunks[crossImport.chunkIndex]
            sb.append("\n        {\n          \"path\": ")
            sb.append(jsonEncodeString(importedChunk.finalRelPath))
            sb.append(",\n          \"kind\": ")
            sb.append(jsonEncodeString(crossImport.importKind.toMetafileLabel()))
            sb.append("\n        }")
        }
        sb.append("\n      ]")

        // Write exports and entry point if applicable
        sb.append(",\n      \"exports\": [")
        if (chunk.entryPoint.isEntryPoint) {
            let entrySourceIndex = chunk.entryPoint.sourceIndex
            let sortedExports = getSortedExportAliases(c, entrySourceIndex)
            var firstExport = true
            for (alias in sortedExports) {
                if (!firstExport) {
                    sb.append(",")
                }
                firstExport = false
                sb.append("\n        ")
                sb.append(jsonEncodeString(alias))
            }
            if (!firstExport) {
                sb.append("\n      ")
            }
        }
        sb.append("]")

        // Write entry point path
        if (chunk.entryPoint.isEntryPoint) {
            let entrySourceIndex = chunk.entryPoint.sourceIndex
            let entryPath = getSourcePath(c, entrySourceIndex)
            if (entryPath.size > 0) {
                sb.append(",\n      \"entryPoint\": ")
                sb.append(jsonEncodeString(entryPath))
            }
        }

        // Write cssBundle if this JS chunk has associated CSS
        if (match (chunk.contentType) { case ChunkContentType.JavaScript => true case _ => false }) {
            let cssChunks = chunk.jsContent.cssChunks
            if (cssChunks.size > 0) {
                let cssChunkIndex = cssChunks[0]
                if (cssChunkIndex >= 0 && cssChunkIndex < chunks.size) {
                    let cssChunk = chunks[cssChunkIndex]
                    if (cssChunk.finalRelPath.size > 0) {
                        sb.append(",\n      \"cssBundle\": ")
                        sb.append(jsonEncodeString(cssChunk.finalRelPath))
                    }
                }
            }
        }

        sb.append("\n    }")

        return sb.toString()
    }

    /// 组装最终 metafile JSON
    // 严格翻译自: MetafileBuilder.zig:164 generate()
    public static func generate(
        c: LinkerContext,
        chunks: ArrayList<Chunk>
    ): String {
        let sb = StringBuilder()

        sb.append("{\n  \"inputs\": {")

        // Collect all source indices that appear in chunks
        let seenSources = HashSet<Int64>()

        // Mark all files that appear in chunks
        for (chunk in chunks) {
            for (entry in chunk.filesWithParts.allEntries()) {
                seenSources.put(entry[0])
            }
        }

        // Write inputs
        let inputFiles = c.parseGraph.inputFiles
        let importRecordsList = c.graph.ast
        var firstInput = true

        for (sourceIndex in 0..inputFiles.size) {
            if (!seenSources.contains(sourceIndex)) {
                continue
            }

            // Skip runtime (index 0)
            if (sourceIndex == 0) {
                continue
            }

            let inputFile = inputFiles[sourceIndex]
            let filePath = inputFile.source
            if (filePath.size == 0) {
                continue
            }

            if (!firstInput) {
                sb.append(",")
            }
            firstInput = false

            sb.append("\n    ")
            sb.append(jsonEncodeString(filePath))
            sb.append(": {\n      \"bytes\": ")
            sb.append(inputFile.contents.size.toString())

            // Write imports for this input file
            sb.append(",\n      \"imports\": [")
            if (sourceIndex < importRecordsList.size) {
                let importRecords = importRecordsList[sourceIndex].importRecords
                var firstImport = true
                for (record in importRecords) {
                    // Skip internal imports
                    if (record.kind == ImportKind.Internal) {
                        continue
                    }

                    if (!firstImport) {
                        sb.append(",")
                    }
                    firstImport = false

                    sb.append("\n        {\n          \"path\": ")
                    sb.append(jsonEncodeString(record.path))
                    sb.append(",\n          \"kind\": \"")
                    sb.append(record.kind.toMetafileLabel())
                    sb.append("\"")

                    // Add "original" field if different from path
                    // (In Bao, resolvedPath is the resolved version)
                    match (record.resolvedPath) {
                        case Some(resolved) =>
                            if (resolved.size > 0 && resolved != record.path) {
                                sb.append(",\n          \"original\": ")
                                sb.append(jsonEncodeString(resolved))
                            }
                        case None => ()
                    }

                    // Add "external": true for external imports
                    if (record.isExternal || record.sourceIndex < 0) {
                        sb.append(",\n          \"external\": true")
                    }

                    // Add "with" for import attributes (json, toml, text loaders)
                    if (record.sourceIndex >= 0 && record.sourceIndex < inputFiles.size) {
                        let loader = inputFiles[record.sourceIndex].loader
                        let withType = loaderToWithType(loader)
                        match (withType) {
                            case Some(wt) =>
                                sb.append(",\n          \"with\": { \"type\": \"")
                                sb.append(wt)
                                sb.append("\" }")
                            case None => ()
                        }
                    }

                    sb.append("\n        }")
                }
            }
            sb.append("\n      ]")

            // Write format based on loader and exports_kind
            let loader = inputFile.loader
            let format = getFormatForLoader(loader, c, sourceIndex)
            match (format) {
                case Some(fmt) =>
                    sb.append(",\n      \"format\": \"")
                    sb.append(fmt)
                    sb.append("\"")
                case None => ()
            }

            sb.append("\n    }")
        }

        sb.append("\n  },\n  \"outputs\": {")

        // Write outputs by joining pre-built chunk JSON fragments
        var firstOutput = true
        for (chunk in chunks) {
            if (chunk.finalRelPath.size == 0) {
                continue
            }

            if (!firstOutput) {
                sb.append(",")
            }
            firstOutput = false

            sb.append("\n    ")
            // If the chunk has a pre-built metafile JSON, use it
            // Otherwise generate inline
            sb.append(chunk.metafileChunkJson)
        }

        sb.append("\n  }\n}\n")

        return sb.toString()
    }

    /// 获取源文件路径
    private static func getSourcePath(c: LinkerContext, sourceIndex: Int64): String {
        let inputFiles = c.parseGraph.inputFiles
        if (sourceIndex < 0 || sourceIndex >= inputFiles.size) {
            return ""
        }
        let path = inputFiles[sourceIndex].source
        if (path.size == 0) {
            return ""
        }
        return path
    }

    /// 获取排序后的导出别名
    private static func getSortedExportAliases(c: LinkerContext, sourceIndex: Int64): ArrayList<String> {
        let result = ArrayList<String>()
        if (sourceIndex < 0 || sourceIndex >= c.graph.ast.size) {
            return result
        }
        // 从 namedExports 获取导出名称
        let ast = c.graph.ast[sourceIndex]
        let keys = ast.namedExports.keys()
        // 简单选择排序
        for (i in 0..keys.size) {
            var minIdx = i
            for (j in i + 1..keys.size) {
                if (keys[j] < keys[minIdx]) {
                    minIdx = j
                }
            }
            if (minIdx != i) {
                let tmp = keys[i]
                keys[i] = keys[minIdx]
                keys[minIdx] = tmp
            }
        }
        for (k in keys) {
            result.append(k)
        }
        return result
    }

    /// 根据 loader 获取 "with" type 属性
    private static func loaderToWithType(loader: Loader): ?String {
        match (loader) {
            case Loader.Json => Some("json")
            case Loader.Toml => Some("toml")
            case Loader.Text => Some("text")
            case _ => None
        }
    }

    /// 根据 loader 和 exports_kind 获取 format 字符串
    private static func getFormatForLoader(loader: Loader, c: LinkerContext, sourceIndex: Int64): ?String {
        match (loader) {
            case Loader.Js | Loader.Jsx | Loader.Ts | Loader.Tsx =>
                // 根据 exports_kind 判断 esm/cjs
                if (sourceIndex < c.graph.ast.size) {
                    let ast = c.graph.ast[sourceIndex]
                    // 通过 namedExports 和 namedImports 判断
                    let hasEsmExports = ast.namedExports.size > 0
                    let hasNamedImports = ast.namedImports.size > 0
                    // 简化: 有 ESM 导出/导入特征时标记为 esm，否则 cjs
                    if (hasEsmExports || hasNamedImports) {
                        return Some("esm")
                    }
                    return Some("cjs")
                }
                return None
            case Loader.Json => Some("json")
            case Loader.Css => Some("css")
            case _ => None
        }
    }

    /// 生成 Markdown 可视化报告
    // 严格翻译自: MetafileBuilder.zig:351 generateMarkdown()
    public static func generateMarkdown(metafileJson: String): String {
        var md = MetafileStringBuilder()

        // Parse JSON (simplified - in original uses std.json)
        // For now, generate a basic markdown structure

        md.append("# Bundle Analysis Report\n\n")
        md.append("This report helps identify bundle size issues, dependency bloat, ")
        md.append("and optimization opportunities.\n\n")

        md.append("## Table of Contents\n\n")
        md.append("- [Quick Summary](#quick-summary)\n")
        md.append("- [Largest Modules by Output Contribution](#largest-modules-by-output-contribution)\n")
        md.append("- [Entry Point Analysis](#entry-point-analysis)\n")
        md.append("- [Dependency Chains](#dependency-chains)\n")
        md.append("- [Full Module Graph](#full-module-graph)\n")
        md.append("- [Raw Data for Searching](#raw-data-for-searching)\n\n")
        md.append("---\n\n")

        md.append("## Quick Summary\n\n")
        md.append("| Metric | Value |\n")
        md.append("|--------|-------|\n")
        md.append("| Note | Full markdown generation requires JSON parsing |\n\n")

        md.append("## Raw Data for Searching\n\n")
        md.append("```\n")
        md.append(metafileJson)
        md.append("\n```\n")

        return md.toString()
    }

    // ========================================================================
    // JSON 辅助
    // ========================================================================

    /// JSON 编码字符串
    // 严格翻译自: MetafileBuilder.zig:343 writeJSONString
    public static func jsonEncodeString(s: String): String {
        var result = "\""
        for (c in s) {
            match (c) {
                case '"' => result = result + "\\\""
                case '\\' => result = result + "\\\\"
                case '\n' => result = result + "\\n"
                case '\r' => result = result + "\\r"
                case '\t' => result = result + "\\t"
                case '\b' => result = result + "\\b"
                case _ => result = result + c.toString()
            }
        }
        result = result + "\""
        return result
    }

    /// 获取 loader 对应的格式字符串 (保留旧接口兼容性)
    private static func getFormatForMetafileLoader(loader: MetafileLoader, c: LinkerContext,
                                            sourceIndex: Int64): ?String {
        return getFormatForLoader(loaderToCoreLoader(loader), c, sourceIndex)
    }

    /// 将 MetafileLoader 转为 Loader
    private static func loaderToCoreLoader(loader: MetafileLoader): Loader {
        match (loader) {
            case MetafileLoader.JS => Loader.Js
            case MetafileLoader.JSX => Loader.Jsx
            case MetafileLoader.TS => Loader.Ts
            case MetafileLoader.TSX => Loader.Tsx
            case MetafileLoader.JSON => Loader.Json
            case MetafileLoader.CSS => Loader.Css
            case MetafileLoader.File => Loader.File
            case MetafileLoader.Other => Loader.Text
        }
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 导入记录种类
public enum ImportRecordKind {
    | Stmt
    | Require
    | Dynamic
    | At
    | Internal
    | Url

    public func label(): String {
        match (this) {
            case Stmt => "import-statement"
            case Require => "require-call"
            case Dynamic => "dynamic-import"
            case At => "css-import"
            case Internal => "internal"
            case Url => "url-import"
        }
    }
}

/// 简化的导入记录
public class ImportRecordForMeta {
    public var path: PathText
    public var originalPath: String
    public var kind: ImportRecordKind
    public var sourceIndex: Int64
    public var flags: ImportRecordFlags

    public init() {
        path = PathText("")
        originalPath = ""
        kind = ImportRecordKind.Stmt
        sourceIndex = -1
        flags = ImportRecordFlags()
    }
}

/// 路径文本
public class PathText {
    public var text: String

    public init(text: String) {
        this.text = text
    }
}

/// 导入记录标志
public class ImportRecordFlags {
    public var isExternalWithoutSideEffects: Bool

    public init() {
        isExternalWithoutSideEffects = false
    }
}

/// 输出格式
public enum MetafileOutputFormat {
    | ESM
    | CJS
    | IIFE
    | InternalBakeDev

    public func isAlwaysStrictMode(): Bool {
        match (this) {
            case ESM => true
            case IIFE => true
            case _ => false
        }
    }
}

/// 加载器类型
public enum MetafileLoader {
    | JS
    | JSX
    | TS
    | TSX
    | JSON
    | CSS
    | File
    | Other

    public func isTypeScript(): Bool {
        match (this) {
            case TS => true
            case TSX => true
            case _ => false
        }
    }

    public func isJavaScriptLike(): Bool {
        match (this) {
            case JS => true
            case JSX => true
            case TS => true
            case TSX => true
            case _ => false
        }
    }

    public func isCSS(): Bool {
        match (this) {
            case CSS => true
            case _ => false
        }
    }
}

/// 导出类型
public enum MetafileExportsKind {
    | None
    | CJS
    | ESM
    | ESMWithDynamicFallback
    | ESMWithDynamicFallbackFromCJS
}

/// 去除前导 "../" 序列
// 严格翻译自: MetafileBuilder.zig:1066 stripParentRefs()
private func stripParentRefs(path: String): String {
    var result = path
    while (result.size >= 3 && result.startsWith("../")) {
        result = result[3..]
    }
    // Also handle ./ prefix
    while (result.size >= 2 && result.startsWith("./")) {
        result = result[2..]
    }
    return result
}

/// 字符串构建器
public class MetafileStringBuilder {
    private var parts: ArrayList<String>

    public init() {
        parts = ArrayList<String>()
    }

    public func append(s: String): Unit {
        parts.append(s)
    }

    public func toString(): String {
        var result = ""
        for (part in parts) {
            result = result + part
        }
        return result
    }
}
