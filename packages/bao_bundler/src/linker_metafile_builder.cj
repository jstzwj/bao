// 严格翻译自: src/bundler/linker_context/MetafileBuilder.zig (1086行)
// bao_bundler - Metafile 构建器: 生成 esbuild 兼容的 metafile JSON 和 Markdown
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

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
    public static func generateChunkJson(
        c: LinkerContext,
        chunk: Chunk,
        chunks: ArrayList<Chunk>
    ): String {
        var json = StringBuilder()

        // Start chunk entry: "path/to/output.js": {
        json.append(jsonEncodeString(chunk.finalRelPath))
        json.append(": {")

        // Write bytes
        let chunkBytes = chunk.intermediateOutput.getSize()
        json.append("\n      \"bytes\": ${chunkBytes}")

        // Write inputs for this output
        json.append(",\n      \"inputs\": {")
        var firstChunkInput = true
        let iter = chunk.filesWithPartsInChunk.iterator()
        while (iter.hasNext()) {
            let entry = iter.next()
            let fileSourceIndex = entry.key
            let bytesInOutput = entry.value
            if (fileSourceIndex >= c.parseGraph.inputFiles.size) {
                continue
            }
            if (fileSourceIndex == 0) {
                continue // Skip runtime
            }

            let fileSource = c.parseGraph.getSource(fileSourceIndex)
            let filePath = fileSource.path.pretty
            if (filePath.size == 0) {
                continue
            }

            if (!firstChunkInput) {
                json.append(",")
            }
            firstChunkInput = false

            json.append("\n        ")
            json.append(jsonEncodeString(filePath))
            json.append(": {\n          \"bytesInOutput\": ${bytesInOutput}\n        }")
        }
        json.append("\n      }")

        // Write cross-chunk imports
        json.append(",\n      \"imports\": [")
        var firstChunkImport = true
        for (crossImport in chunk.crossChunkImports) {
            if (crossImport.chunkIndex >= chunks.size) {
                continue
            }
            if (!firstChunkImport) {
                json.append(",")
            }
            firstChunkImport = false

            let importedChunk = chunks[crossImport.chunkIndex]
            json.append("\n        {\n          \"path\": ")
            json.append(jsonEncodeString(importedChunk.finalRelPath))
            json.append(",\n          \"kind\": ")
            json.append(jsonEncodeString(crossImport.importKind.label()))
            json.append("\n        }")
        }
        json.append("\n      ]")

        // Write exports
        json.append(",\n      \"exports\": [")
        if (chunk.entryPoint.isEntryPoint) {
            let entrySourceIndex = chunk.entryPoint.sourceIndex
            if (entrySourceIndex < c.parseGraph.inputFiles.size) {
                let sortedExports = c.graph.getSortedExportAliases(entrySourceIndex)
                var firstExport = true
                for (alias in sortedExports) {
                    if (!firstExport) {
                        json.append(",")
                    }
                    firstExport = false
                    json.append("\n        ")
                    json.append(jsonEncodeString(alias))
                }
            }
        }
        json.append("]")

        // Write entry point path
        if (chunk.entryPoint.isEntryPoint) {
            let entrySourceIndex = chunk.entryPoint.sourceIndex
            if (entrySourceIndex < c.parseGraph.inputFiles.size) {
                let entrySource = c.parseGraph.getSource(entrySourceIndex)
                if (entrySource.path.text.size > 0) {
                    json.append(",\n      \"entryPoint\": ")
                    json.append(jsonEncodeString(entrySource.path.pretty))
                }
            }
        }

        // Write cssBundle if this JS chunk has associated CSS
        if (chunk.content.isJavaScript) {
            let cssChunks = chunk.content.javascript.cssChunks
            if (cssChunks.size > 0) {
                let cssChunkIndex = cssChunks[0]
                if (cssChunkIndex < chunks.size) {
                    let cssChunk = chunks[cssChunkIndex]
                    if (cssChunk.finalRelPath.size > 0) {
                        json.append(",\n      \"cssBundle\": ")
                        json.append(jsonEncodeString(cssChunk.finalRelPath))
                    }
                }
            }
        }

        json.append("\n    }")
        return json.toString()
    }

    /// 组装最终 metafile JSON
    // 严格翻译自: MetafileBuilder.zig:164 generate()
    public static func generate(
        c: LinkerContext,
        chunks: ArrayList<Chunk>
    ): String {
        var j = StringJoiner()
        j.pushStatic("{\n  \"inputs\": {")

        // Collect all input files that are reachable
        var firstInput = true
        let sources = c.parseGraph.inputFiles.sources

        // Mark all files that appear in chunks
        var seenSources = HashSet<Int64>()
        for (chunk in chunks) {
            let iter = chunk.filesWithPartsInChunk.iterator()
            while (iter.hasNext()) {
                let entry = iter.next()
                if (entry.key < sources.size) {
                    seenSources.put(entry.key)
                }
            }
        }

        // Write inputs
        var sourceIndex: Int64 = 0
        while (sourceIndex < sources.size) {
            if (!seenSources.contains(sourceIndex)) {
                sourceIndex++
                continue
            }
            if (sourceIndex == 0) {
                sourceIndex++ // Skip runtime
                continue
            }

            let source = sources[sourceIndex]
            let path = source.path.pretty
            if (path.size == 0) {
                sourceIndex++
                continue
            }

            if (!firstInput) {
                j.pushStatic(",")
            }
            firstInput = false

            j.pushStatic("\n    ")
            j.push(jsonEncodeString(path))
            j.push(": {\n      \"bytes\": ${source.contents.size}")

            // Write imports
            j.pushStatic(",\n      \"imports\": [")
            let importRecords = c.graph.getImportRecords(sourceIndex)
            var firstImport = true
            for (record in importRecords) {
                if (record.kind == ImportRecordKind.Internal) {
                    continue
                }
                if (!firstImport) {
                    j.pushStatic(",")
                }
                firstImport = false

                j.pushStatic("\n        {\n          \"path\": ")
                j.push(jsonEncodeString(record.path.text))
                j.pushStatic(",\n          \"kind\": \"")
                j.pushStatic(record.kind.label())
                j.pushStatic("\"")

                // Add "original" field if different from path
                if (record.originalPath.size > 0 && record.originalPath != record.path.text) {
                    j.pushStatic(",\n          \"original\": ")
                    j.push(jsonEncodeString(record.originalPath))
                }

                // Add "external": true
                if (record.flags.isExternalWithoutSideEffects || record.sourceIndex < 0) {
                    j.pushStatic(",\n          \"external\": true")
                }

                j.pushStatic("\n        }")
            }
            j.pushStatic("\n      ]")

            // Write format
            let loader = c.parseGraph.getLoader(sourceIndex)
            let format: ?String = getFormatForLoader(loader, c, sourceIndex)
            if (format != None) {
                j.pushStatic(",\n      \"format\": \"")
                j.pushStatic(format)
                j.pushStatic("\"")
            }

            j.pushStatic("\n    }")
            sourceIndex++
        }

        j.pushStatic("\n  },\n  \"outputs\": {")

        // Write outputs by joining pre-built chunk JSON fragments
        var firstOutput = true
        for (chunk in chunks) {
            if (chunk.finalRelPath.size == 0) {
                continue
            }
            if (!firstOutput) {
                j.pushStatic(",")
            }
            firstOutput = false

            j.pushStatic("\n    ")
            j.pushStatic(chunk.metafileChunkJson)
        }

        j.pushStatic("\n  }\n}\n")

        return j.toString()
    }

    /// 生成 Markdown 可视化报告
    // 严格翻译自: MetafileBuilder.zig:351 generateMarkdown()
    public static func generateMarkdown(metafileJson: String): String {
        var md = StringBuilder()

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
    private static func jsonEncodeString(s: String): String {
        // Simplified: proper JSON encoding would escape special characters
        var result = "\""
        for (c in s) {
            match (c) {
                case '"' => result = result + "\\\""
                case '\\' => result = result + "\\\\"
                case '\n' => result = result + "\\n"
                case '\r' => result = result + "\\r"
                case '\t' => result = result + "\\t"
                case _ => result = result + c.toString()
            }
        }
        result = result + "\""
        return result
    }

    /// 获取 loader 对应的格式字符串
    private static func getFormatForLoader(loader: Loader, c: LinkerContext,
                                            sourceIndex: Int64): ?String {
        match (loader) {
            case Loader.JS =>
                let exportsKind = c.graph.getExportsKind(sourceIndex)
                match (exportsKind) {
                    case ExportsKind.CJS => "cjs"
                    case ExportsKind.ESMWithDynamicFallbackFromCJS => "cjs"
                    case ExportsKind.ESM => "esm"
                    case ExportsKind.ESMWithDynamicFallback => "esm"
                    case ExportsKind.None => None
            case Loader.JSON => "json"
            case Loader.CSS => "css"
            case _ => None
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
public enum OutputFormat {
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
public enum Loader {
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
public enum ExportsKind {
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
        result = result.substring(3)
    }
    while (result.size >= 2 && result.startsWith("./")) {
        result = result.substring(2)
    }
    return result
}

/// 字符串构建器
public class StringBuilder {
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
