// 严格翻译自: src/bundler/HTMLImportManifest.zig (~200行)
// bao_bundler - HTML 导入清单: 生成 HTML 导入的 JSON 清单
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_ast.*

// ============================================================================
// HTML 导入清单
// 严格翻译自: src/bundler/HTMLImportManifest.zig
// 核心职责:
//   1. 为 HTML 导入生成 JSON 清单
//   2. 包含所有生成文件的元数据 (路径、加载器类型、ETag、MIME 类型)
//   3. 嵌入到 JS 输出中的 __jsonParse() 调用
//
// 清单 JSON 结构:
//   {
//     "index": "./index.html",
//     "files": [
//       {
//         "input": "index.html",
//         "path": "./index-f2me3qnf.js",
//         "loader": "js",
//         "isEntry": true,
//         "headers": { "etag": "...", "content-type": "..." }
//       },
//       ...
//     ]
//   }
// ============================================================================

/// HTML 导入清单
// 严格翻译自: HTMLImportManifest.zig:36 HTMLImportManifest
public class HtmlImportManifest {
    /// 源文件索引
    public var index: UInt32
    /// 解析图引用
    public var graph: BundlerGraphRef
    /// chunk 列表
    public var chunks: ArrayList<ChunkRef>
    /// 链接器图引用
    public var linkerGraph: LinkerGraphRef

    public init(index: UInt32, graph: BundlerGraphRef,
                chunks: ArrayList<ChunkRef>, linkerGraph: LinkerGraphRef) {
        this.index = index
        this.graph = graph
        this.chunks = chunks
        this.linkerGraph = linkerGraph
    }

    /// 格式化为 JSON 字符串
    // 严格翻译自: HTMLImportManifest.zig:43 format
    public func format(): String {
        let sb = StringBuilder()
        sb.append("{")

        // index 字段
        let indexPath = graph.getInputFilePath(index)
        sb.append("\"index\":")
        sb.append(quoteJSON(indexPath))

        // files 数组
        sb.append(",\"files\":[")

        var first = true
        for (chunk in chunks) {
            if (!first) {
                sb.append(",")
            }
            first = false

            let inputPath = graph.getInputFilePath(chunk.getPrimarySourceIndex())
            let outputPath = chunk.getFinalRelPath()
            let loader = chunk.getLoader()
            let hash = chunk.getIsolatedHash()
            let isEntry = chunk.isEntryPoint()

            writeEntryItem(sb, inputPath, outputPath, hash, loader, isEntry)
        }

        sb.append("]}")
        return sb.toString()
    }

    /// 写入单个条目
    // 严格翻译自: HTMLImportManifest.zig:52 writeEntryItem
    private func writeEntryItem(sb: StringBuilder, input: String, path: String,
                                hash: UInt64, loader: String, isEntry: Bool): Unit {
        sb.append("{")
        if (input.length > 0) {
            sb.append("\"input\":")
            sb.append(quoteJSON(input))
            sb.append(",")
        }
        sb.append("\"path\":")
        sb.append(quoteJSON(path))
        sb.append(",\"loader\":\"")
        sb.append(loader)
        sb.append("\",\"isEntry\":")
        sb.append(if (isEntry) "true" else "false")
        sb.append(",\"headers\":{")
        if (hash > 0) {
            let base64Hash = hash.toHexString()
            sb.append("\"etag\":\"")
            sb.append(base64Hash)
            sb.append("\",")
        }
        sb.append("\"content-type\":\"")
        sb.append(getMimeType(loader))
        sb.append("\"")
        sb.append("}}")
    }

    /// 获取 MIME 类型
    private func getMimeType(loader: String): String {
        match (loader) {
            case "js" => "text/javascript;charset=utf-8"
            case "css" => "text/css;charset=utf-8"
            case "html" => "text/html;charset=utf-8"
            case "wasm" => "application/wasm"
            case "json" => "application/json;charset=utf-8"
            case _ => "application/octet-stream"
        }
    }

    /// JSON 转义引号
    private func quoteJSON(s: String): String {
        return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
    }
}

// ============================================================================
// 辅助引用类型
// ============================================================================

/// BundlerGraph 引用
public class BundlerGraphRef {
    public func getInputFilePath(index: UInt32): String {
        return ""
    }
}

/// Chunk 引用
public class ChunkRef {
    public func getPrimarySourceIndex(): UInt32 {
        return 0
    }
    public func getFinalRelPath(): String {
        return ""
    }
    public func getLoader(): String {
        return "js"
    }
    public func getIsolatedHash(): UInt64 {
        return 0
    }
    public func isEntryPoint(): Bool {
        return false
    }
}

/// LinkerGraph 引用
public class LinkerGraphRef {
    public init() {}
}
