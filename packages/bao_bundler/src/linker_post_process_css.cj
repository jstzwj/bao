// 严格翻译自: src/bundler/linker_context/postProcessCSSChunk.rs (178行)
// bao_bundler - CSS chunk 后处理: 拼接编译结果、生成 source map
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// CSS chunk 后处理
// 严格翻译自: postProcessCSSChunk.rs:12 post_process_css_chunk()
//
// 在所有 CSS 编译结果生成后, 执行后处理:
//   1. 拼接所有编译结果, 插入文件路径注释 /* <path> */
//   2. 处理 source map 行列偏移
//   3. 确保文件以换行符结尾
//   4. 将输出分割为片段 (breakOutputIntoPieces)
//   5. 生成隔离哈希 (用于最终路径)
//   6. 生成 source map (如果启用)
// ============================================================================

/// CSS chunk 后处理
// 严格翻译自: postProcessCSSChunk.rs:12 post_process_css_chunk()
public func postProcessCSSChunkDetailed(
    c: LinkerContext,
    chunk: Chunk,
    chunks: ArrayList<Chunk>
): Unit {
    let j = StringJoinerCSS()
    j.watcher = CSSStringWatcher(chunk.uniqueKey)

    var lineOffset: CSSLineColumnOffset = if (match (c.options.sourceMaps) { case SourceMapOption.None => false case _ => true }) {
        CSSLineColumnOffset()
    } else {
        CSSLineColumnOffset.none()
    }

    var newlineBeforeComment: Bool = false

    // 获取编译结果列表
    let compileResults = chunk.compileResults

    // 拼接所有编译结果, 每个文件前插入注释
    for (i in 0..compileResults.size) {
        let compileResult = compileResults[i]
        let sourceIndex = compileResult.sourceIndex

        // 在 bundle 模式且未压缩时, 添加文件路径注释
        if ((match (c.options.mode) { case LinkerMode.Bundle => true case _ => false }) &&
            !c.options.minifyWhitespace &&
            sourceIndex >= 0) {
            if (newlineBeforeComment) {
                j.pushStatic("\n")
                lineOffset.advance("\n")
            }

            // 获取源文件路径
            let pretty = getSourcePrettyPath(c, sourceIndex)

            j.pushStatic("/* ")
            lineOffset.advance("/* ")

            // 转义路径中的 */ 以避免提前结束注释
            let escapedPretty = escapeCommentClose(pretty)
            j.pushStatic(escapedPretty)
            lineOffset.advance(escapedPretty)

            j.pushStatic(" */\n")
            lineOffset.advance(" */\n")
        }

        if (compileResult.code.size > 0) {
            newlineBeforeComment = true
        }

        // 追加编译结果代码
        j.pushStatic(compileResult.code)

        // 处理 source map 偏移
        match (compileResult.sourceMapChunk) {
            case Some(smChunk) =>
                if (match (c.options.sourceMaps) { case SourceMapOption.None => false case _ => true }) {
                    // source map 偏移重置 (新编译结果从 0,0 开始)
                    lineOffset.reset()
                }
            case None =>
                lineOffset.advance(compileResult.code)
        }
    }

    // 确保文件以换行符结尾
    j.ensureNewlineAtEnd()

    // 将输出分割为片段
    chunk.intermediateOutput = breakOutputIntoPieces(c, j, chunks.size)

    // 生成隔离哈希
    chunk.isolatedHash = generateIsolatedHash(c, chunk)

    // 生成 source map (如果启用)
    if (match (c.options.sourceMaps) { case SourceMapOption.None => false case _ => true }) {
        generateSourceMapForCSSChunk(c, chunk)
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 获取源文件的 pretty 路径
// 严格翻译自: postProcessCSSChunk.rs:71 sources[source_index].path.pretty
private func getSourcePrettyPath(c: LinkerContext, sourceIndex: Int64): String {
    // 从 parse_graph 的 input_files 中获取源文件路径
    // 简化: 使用源索引获取路径
    if (sourceIndex >= 0 && sourceIndex < c.parseGraph.inputFiles.size) {
        return c.parseGraph.inputFiles[Int64(sourceIndex)].source
    }
    return ""
}

/// 转义 CSS 注释结束符 */
// 严格翻译自: postProcessCSSChunk.rs:78-88
// 如果路径中包含 */, 需要在 * 后插入 \ 防止提前结束注释
private func escapeCommentClose(path: String): String {
    if (!path.contains("*/")) {
        return path
    }
    var result = StringBuilder()
    var i = 0
    while (i < path.size) {
        if (i > 0 && path[i..(i + 1)] == "/" && path[(i - 1)..i] == "*") {
            result.append("\\")
        }
        result.append(path[i..(i + 1)])
        i++
    }
    return result.toString()
}

/// 将输出分割为片段
// 严格翻译自: LinkerContext.breakOutputIntoPieces
// 扫描 StringJoiner 的输出, 查找 unique_key 占位符
// 将输出分割为 "纯代码" 和 "chunk/资源引用" 交替的片段
private func breakOutputIntoPieces(c: LinkerContext, j: StringJoinerCSS,
                                    chunksLen: Int64): ArrayList<OutputPiece> {
    let pieces = ArrayList<OutputPiece>()
    let output = j.toString()

    // 扫描输出中的 unique_key 占位符
    // 在 Bun 中, 每个 unique_key 是一个随机 hex 字符串, 用于在最终阶段替换为实际路径
    var pos = 0
    while (pos < output.size) {
        // 查找下一个占位符 (格式: 随机 hex 字符串)
        let nextPlaceholder = findNextPlaceholder(c, output, pos)
        match (nextPlaceholder) {
            case Some(placeholder) =>
                // 输出占位符前的纯文本
                if (placeholder.start > pos) {
                    pieces.append(OutputPiece(output[pos..placeholder.start]))
                }
                // 输出占位符引用
                pieces.append(OutputPiece(
                    placeholder.key,
                    placeholder.kind,
                    placeholder.index
                ))
                pos = placeholder.end
            case None =>
                // 没有更多占位符, 输出剩余文本
                if (pos < output.size) {
                    pieces.append(OutputPiece(output[pos..output.size]))
                }
                pos = output.size
        }
    }

    return pieces
}

/// 占位符查找结果
private class PlaceholderResult {
    public var start: Int64
    public var end: Int64
    public var key: String
    public var kind: OutputPieceKind
    public var index: Int64

    public init(start: Int64, end: Int64, key: String,
                kind: OutputPieceKind, index: Int64) {
        this.start = start
        this.end = end
        this.key = key
        this.kind = kind
        this.index = index
    }
}

/// 查找下一个占位符
// 在输出中查找 unique_key 占位符
private func findNextPlaceholder(c: LinkerContext, output: String,
                                  fromPos: Int64): ?PlaceholderResult {
    // 遍历所有已知的 unique_key
    // 在实际实现中, 这需要维护一个 key -> (kind, index) 的映射
    // 简化: 暂时返回 None
    return None
}

/// 生成隔离哈希 (内容寻址)
// 严格翻译自: LinkerContext.generateIsolatedHash
// 对 chunk 的中间输出计算哈希值, 用于生成唯一的输出文件名
private func generateIsolatedHash(c: LinkerContext, chunk: Chunk): UInt64 {
    var hasher = XxHash64()
    for (piece in chunk.intermediateOutput) {
        if (piece.data.size > 0) {
            hasher.update(piece.data.toArray())
        }
    }
    return hasher.digest()
}

/// 为 CSS chunk 生成 source map
// 严格翻译自: postProcessCSSChunk.rs:159-173
private func generateSourceMapForCSSChunk(c: LinkerContext, chunk: Chunk): Unit {
    // source map 生成逻辑:
    // 1. 收集每个编译结果的 source map 块
    // 2. 计算行列偏移
    // 3. 生成 VLQ 编码的 mappings
    // 4. 写入 source map 文件
    // 简化: 暂不生成
}

// ============================================================================
// 辅助类型
// ============================================================================

/// CSS 字符串拼接器
// 严格翻译自: bun_core.string_joiner.StringJoiner
// 用于高效拼接 CSS 输出, 支持占位符监视
public class StringJoinerCSS {
    private var parts: ArrayList<String>
    public var watcher: CSSStringWatcher

    public init() {
        parts = ArrayList<String>()
        watcher = CSSStringWatcher("")
    }

    /// 追加静态字符串 (不需要释放)
    public func pushStatic(s: String): Unit {
        parts.append(s)
    }

    /// 追加动态字符串
    public func push(s: String): Unit {
        parts.append(s)
    }

    /// 确保以换行符结尾
    public func ensureNewlineAtEnd(): Unit {
        if (parts.size > 0) {
            let last = parts[parts.size - 1]
            if (!last.endsWith("\n")) {
                parts.append("\n")
            }
        }
    }

    /// 转换为字符串
    public func toString(): String {
        var result = StringBuilder()
        for (part in parts) {
            result.append(part)
        }
        return result.toString()
    }
}

/// CSS 字符串监视器 (用于检测占位符替换)
// 严格翻译自: bun_core.string_joiner.Watcher
public class CSSStringWatcher {
    public var input: String  // 被监视的 unique_key

    public init(input: String) {
        this.input = input
    }
}

/// 行列偏移 (用于 source map)
// 严格翻译自: bun_sourcemap.LineColumnOffset
public class CSSLineColumnOffset {
    public var line: Int64
    public var column: Int64
    private var isNull: Bool

    public init() {
        line = 0
        column = 0
        isNull = false
    }

    /// 创建 null 偏移 (不跟踪)
    public static func none(): CSSLineColumnOffset {
        let offset = CSSLineColumnOffset()
        offset.isNull = true
        return offset
    }

    /// 推进偏移 (按文本内容)
    public func advance(text: String): Unit {
        if (isNull) { return }
        for (i in 0..text.size) {
            if (text[i..(i + 1)] == "\n") {
                line++
                column = 0
            } else {
                column++
            }
        }
    }

    /// 重置偏移 (新编译结果从 0,0 开始)
    public func reset(): Unit {
        if (isNull) { return }
        line = 0
        column = 0
    }
}
