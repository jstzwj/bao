// 严格翻译自: src/bundler/HTMLImportManifest.rs (391行)
// bao_bundler - HTML 导入清单: 生成 HTML 导入的 JSON 清单
//
// 当在 JavaScript 中导入 HTML 文件时:
//   import index from "./index.html";
//   console.log(index);
//
// Bun 将其转换为 __jsonParse() 调用, JSON 清单包含所有生成文件的元数据:
//   {
//     "index": "./index.html",
//     "files": [
//       {
//         "input": "index.html",
//         "path": "./index-f2me3qnf.js",
//         "loader": "js",
//         "isEntry": true,
//         "headers": { "etag": "eet6gn75", "content-type": "text/javascript;charset=utf-8" }
//       },
//       ...
//     ]
//   }
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// HTML 导入清单
// 严格翻译自: HTMLImportManifest.rs:57 HTMLImportManifest
// ============================================================================

/// HTML 导入清单
// 严格翻译自: HTMLImportManifest.rs:57
// 当 JS 代码导入 HTML 文件时, 生成一个 JSON 清单描述所有输出文件
public class HtmlImportManifest {
    /// HTML 文件的源文件索引 (在 graph.html_imports.html_source_indices 中)
    public var index: UInt32
    /// 解析图引用
    public var graph: Graph
    /// 关联的 chunk 列表 (包含由此 HTML 导入生成的所有 chunk)
    public var chunks: ArrayList<Chunk>
    /// 链接器图引用
    public var linkerGraph: LinkerGraph

    public init(index: UInt32, graph: Graph,
                chunks: ArrayList<Chunk>, linkerGraph: LinkerGraph) {
        this.index = index
        this.graph = graph
        this.chunks = chunks
        this.linkerGraph = linkerGraph
    }

    /// 格式化为 JSON 字符串 (未转义)
    // 严格翻译自: HTMLImportManifest.rs:64 fmt::Display
    // 生成完整的清单 JSON (用于内部处理)
    public func format(): String {
        let sb = StringBuilder()
        formatTo(sb)
        return sb.toString()
    }

    /// 将 JSON 写入 StringBuilder
    // 严格翻译自: HTMLImportManifest.rs:178 write()
    public func formatTo(sb: StringBuilder): Unit {
        // 获取浏览器和服务端源文件索引
        let browserSourceIndex = graph.getHTMLSourceIndex(index)
        let serverSourceIndex = graph.getHTMLServerSourceIndex(index)
        let sources = graph.inputFiles
        let options = graph.getBundleOptions()
        let rootDir = graph.getTopLevelDir()

        sb.append("{")

        // 1. 写入 "index" 字段 - 主 HTML 文件的输出路径
        var entryPointBits = BitSet()
        for (ch in chunks) {
            if (ch.entryPoint.sourceIndex == browserSourceIndex &&
                ch.entryPoint.isEntryPoint) {
                entryPointBits.set(ch.entryPoint.entryPointId)

                if (match (ch.contentType) { case ChunkContentType.HTML => true case _ => false }) {
                    sb.append("\"index\":")
                    if (options.compile && options.publicPath.size > 0) {
                        let fullPath = options.publicPath + removeLeadingDotSlash(ch.finalRelPath)
                        sb.append(quoteJSON(fullPath))
                    } else {
                        sb.append(quoteJSON(ch.finalRelPath))
                    }
                    sb.append(",")
                }
            }
        }

        // 2. 写入 "files" 数组
        sb.append("\"files\":[")

        var first = true

        // 遍历所有与该 HTML 导入相关的 chunk
        let hasSingleHTMLImport = graph.getHTMLImportCount() == 1
        for (ch in chunks) {
            // 包含条件:
            // - chunk 的 entry_bits 与此 HTML 导入的入口点位图有交集
            // - 或者只有一个 HTML 导入, 且是来自服务端构建的浏览器 chunk
            if (ch.entryBits.hasIntersection(entryPointBits) ||
                (hasSingleHTMLImport && ch.isBrowserChunkFromServerBuild)) {
                if (!first) {
                    sb.append(",")
                }
                first = false

                // 输入路径 (相对于 root_dir)
                let input: String = if (!ch.entryPoint.isEntryPoint) {
                    ""
                } else {
                    let pathForKey = relativeNormalized(rootDir,
                        sources[Int64(ch.entryPoint.sourceIndex)].source)
                    removeLeadingDotSlash(pathForKey)
                }

                // 输出路径
                let path: String = if (options.compile && options.publicPath.size > 0) {
                    options.publicPath + removeLeadingDotSlash(ch.finalRelPath)
                } else {
                    ch.finalRelPath
                }

                // 哈希值:
                // HTML chunk 的 body 嵌入了 JS/CSS chunk 的哈希路径,
                // 所以 etag 必须在那些哈希变化时也变化
                // isolated_hash 设计上排除了那些替换;
                // placeholder.hash 通过 appendIsolatedHashesForImportedChunks 包含了它们
                let hash = ch.placeholderHash
                let effectiveHash = if (hash > 0) { hash } else { ch.isolatedHash }

                writeEntryItem(sb, input, path, effectiveHash,
                    loaderToString(ch.contentType),
                    ch.entryPoint.isEntryPoint)
            }
        }

        // 额外输出文件 (如资源文件)
        let additionalFiles = graph.getAdditionalOutputFiles()
        let fileEntryBits = linkerGraph.filesEntryBits()
        var alreadyVisited = BitSet()

        for (i in 0..additionalFiles.size) {
            if (alreadyVisited.isSet(Int64(i))) {
                continue
            }

            let outputFile = additionalFiles[Int64(i)]
            if (outputFile.sourceIndex == serverSourceIndex) {
                continue
            }

            match (outputFile.sourceIndex) {
                case Some(srcIdx) =>
                    let bits = fileEntryBits[srcIdx]
                    if (bits.hasIntersection(entryPointBits)) {
                        alreadyVisited.set(Int64(i))
                        if (!first) {
                            sb.append(",")
                        }
                        first = false

                        let pathForKey = relativeNormalized(rootDir,
                            sources[Int64(srcIdx)].source)
                        let input = removeLeadingDotSlash(pathForKey)

                        let path: String = if (options.compile && options.publicPath.size > 0) {
                            options.publicPath + removeLeadingDotSlash(outputFile.destPath)
                        } else {
                            outputFile.destPath
                        }

                        writeEntryItem(sb, input, path, outputFile.hash,
                            outputFile.loader, outputFile.isEntryPoint)
                    }
                case None => ()
            }
        }

        sb.append("]}")
    }

    /// 写入单个条目
    // 严格翻译自: HTMLImportManifest.rs:82 write_entry_item()
    private func writeEntryItem(sb: StringBuilder, input: String, path: String,
                                hash: UInt64, loader: String, isEntry: Bool): Unit {
        sb.append("{")
        if (input.size > 0) {
            sb.append("\"input\":")
            sb.append(quoteJSON(input))
            sb.append(",")
        }
        sb.append("\"path\":")
        sb.append(quoteJSON(path))
        sb.append(",\"loader\":\"")
        sb.append(loader)
        sb.append("\",\"isEntry\":")
        sb.append(if (isEntry) { "true" } else { "false" })
        sb.append(",\"headers\":{")
        if (hash > 0) {
            // Base64 URL-safe 编码哈希
            let base64Hash = encodeBase64UrlSafe(hash)
            sb.append("\"etag\":\"")
            sb.append(base64Hash)
            sb.append("\",")
        }
        sb.append("\"content-type\":\"")
        sb.append(getMimeType(loader))
        sb.append("\"")
        sb.append("}}")
    }

    /// 格式化为转义 JSON (用于嵌入到 JS 字符串中)
    // 严格翻译自: HTMLImportManifest.rs:134 write_escaped_json()
    // 生成 JSON 后进行字符串转义, 以便嵌入到 __jsonParse('...') 中
    public func formatEscapedJSON(): String {
        let raw = format()
        return escapeForJSString(raw)
    }

    /// 获取 MIME 类型
    // 严格翻译自: options.Loader.to_mime_type()
    private func getMimeType(loader: String): String {
        match (loader) {
            case "js" => "text/javascript;charset=utf-8"
            case "css" => "text/css;charset=utf-8"
            case "html" => "text/html;charset=utf-8"
            case "wasm" => "application/wasm"
            case "json" => "application/json;charset=utf-8"
            case "file" => "application/octet-stream"
            case "svg" => "image/svg+xml"
            case "png" => "image/png"
            case "jpg" | "jpeg" => "image/jpeg"
            case "gif" => "image/gif"
            case "webp" => "image/webp"
            case "ico" => "image/x-icon"
            case "ttf" => "font/ttf"
            case "otf" => "font/otf"
            case "woff" => "font/woff"
            case "woff2" => "font/woff2"
            case "txt" => "text/plain;charset=utf-8"
            case _ => "application/octet-stream"
        }
    }

    /// JSON 转义引号
    // 严格翻译自: HTMLImportManifest.rs:94 write_json_string
    private func quoteJSON(s: String): String {
        return "\"" + escapeJSON(s) + "\""
    }

    /// 转义 JSON 特殊字符
    private func escapeJSON(s: String): String {
        return s
            .replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t")
    }

    /// 转义 JS 字符串特殊字符 (用于 __jsonParse() 内嵌)
    // 严格翻译自: HTMLImportManifest.rs:144 write_pre_quoted_string
    private func escapeForJSString(s: String): String {
        return s
            .replace("\\", "\\\\")
            .replace("'", "\\'")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\u{2028}", "\\u2028")
            .replace("\u{2029}", "\\u2029")
    }

    /// 将 chunk 内容类型转换为 loader 字符串
    private func loaderToString(contentType: ChunkContentType): String {
        match (contentType) {
            case ChunkContentType.JavaScript => "js"
            case ChunkContentType.CSS => "css"
            case ChunkContentType.HTML => "html"
        }
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// Base64 URL-safe 编码 64 位哈希
// 严格翻译自: HTMLImportManifest.rs:113-117
// 使用 URL-safe Base64 (无填充) 编码 8 字节哈希
private func encodeBase64UrlSafe(hash: UInt64): String {
    let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
    let bytesInit = ArrayList<UInt8>()
    bytesInit.append(UInt8(hash & 0xFF))
    bytesInit.append(UInt8((hash >> 8) & 0xFF))
    bytesInit.append(UInt8((hash >> 16) & 0xFF))
    bytesInit.append(UInt8((hash >> 24) & 0xFF))
    bytesInit.append(UInt8((hash >> 32) & 0xFF))
    bytesInit.append(UInt8((hash >> 40) & 0xFF))
    bytesInit.append(UInt8((hash >> 48) & 0xFF))
    bytesInit.append(UInt8((hash >> 56) & 0xFF))
    let bytes = Array<UInt8>(bytesInit.size, {i => bytesInit[i]})

    var result = StringBuilder()
    var i = 0
    while (i < 8) {
        let b0 = Int64(bytes[i] & 0xFF)
        let b1 = if (i + 1 < 8) { Int64(bytes[i + 1] & 0xFF) } else { 0 }
        let b2 = if (i + 2 < 8) { Int64(bytes[i + 2] & 0xFF) } else { 0 }

        let idx0 = (b0 >> 2) & 0x3F
        let idx1 = ((b0 & 0x03) << 4) | ((b1 >> 4) & 0x0F)
        let idx2 = ((b1 & 0x0F) << 2) | ((b2 >> 6) & 0x03)
        let idx3 = b2 & 0x3F

        result.append(chars[Int64(idx0)..(Int64(idx0) + 1)])
        result.append(chars[Int64(idx1)..(Int64(idx1) + 1)])
        result.append(chars[Int64(idx2)..(Int64(idx2) + 1)])
        result.append(chars[Int64(idx3)..(Int64(idx3) + 1)])

        i += 3
    }

    return result.toString()
}

/// 移除路径开头的 ./
// 严格翻译自: strings.removeLeadingDotSlash
private func removeLeadingDotSlash(path: String): String {
    if (path.startsWith("./")) {
        return path[2..path.size]
    }
    return path
}

/// 计算相对规范化路径
// 严格翻译自: bun_paths.resolve_path.relative_normalized
private func relativeNormalized(base: String, target: String): String {
    // 简化: 如果 target 已经是相对路径, 直接返回
    if (target.startsWith("./") || target.startsWith("../")) {
        return target
    }
    // 如果 base 和 target 共享前缀目录, 计算相对路径
    if (target.startsWith(base)) {
        return "." + target[base.size..target.size]
    }
    return target
}
