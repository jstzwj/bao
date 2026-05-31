// 严格翻译自: src/bundler/linker_context/postProcessHTMLChunk.rs (53行)
// bao_bundler - HTML chunk 后处理: 拼接编译结果、生成分片输出
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// HTML chunk 后处理
// 严格翻译自: postProcessHTMLChunk.rs:7 post_process_html_chunk()
//
// HTML 后处理比较简单:
//   1. 拼接所有编译结果 (每个 HTML chunk 通常只有一个编译结果)
//   2. 确保以换行符结尾
//   3. 将输出分割为片段 (breakOutputIntoPieces)
//      - 查找 unique_key 占位符并替换为 chunk/资源引用
//   4. 生成隔离哈希 (用于内容寻址文件名)
//
// 注意: HTML chunk 不需要 source map
// ============================================================================

/// HTML chunk 后处理
// 严格翻译自: postProcessHTMLChunk.rs:7 post_process_html_chunk()
public func postProcessHTMLChunkDetailed(
    c: LinkerContext,
    chunk: Chunk,
    chunks: ArrayList<Chunk>
): Unit {
    let j = StringJoinerCSS()
    j.watcher = CSSStringWatcher(input: chunk.uniqueKey)

    // 拼接所有编译结果
    // HTML chunk 通常只有一个编译结果 (整个 HTML 文件)
    let compileResults = chunk.compileResults
    for (i in 0..compileResults.size) {
        let compileResult = compileResults[i]
        j.pushStatic(compileResult.code)
    }

    // 确保文件以换行符结尾
    j.ensureNewlineAtEnd()

    // 将输出分割为片段
    // 在 HTML 中, 占位符包括 JS chunk unique_key 和 CSS chunk unique_key
    chunk.intermediateOutput = breakHTMLOutputIntoPieces(c, j, chunks)

    // 生成隔离哈希
    chunk.isolatedHash = generateHTMLIsolatedHash(c, chunk)
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 将 HTML 输出分割为片段
// 严格翻译自: LinkerContext.breakOutputIntoPieces (HTML 版本)
// HTML 的占位符包括:
//   - JS chunk unique_key (从 <script src="..."> 标签)
//   - CSS chunk unique_key (从 <link href="..."> 标签)
//   - 额外资源文件的 unique_key (从 <img>, <video> 等标签)
private func breakHTMLOutputIntoPieces(c: LinkerContext, j: StringJoinerCSS,
                                        chunks: ArrayList<Chunk>): ArrayList<OutputPiece> {
    let pieces = ArrayList<OutputPiece>()
    let output = j.toString()

    // 构建所有 chunk 的 unique_key -> (kind, index) 映射
    let keyMap = HashMap<String, OutputPieceRef>()
    for (i in 0..chunks.size) {
        let ch = chunks[i]
        if (ch.uniqueKey.size > 0) {
            match (ch.contentType) {
                case ChunkContentType.JavaScript =>
                    keyMap.put(ch.uniqueKey, OutputPieceRef(
                        kind: OutputPieceKind.Chunk,
                        index: i
                    ))
                case ChunkContentType.CSS =>
                    keyMap.put(ch.uniqueKey, OutputPieceRef(
                        kind: OutputPieceKind.Chunk,
                        index: i
                    ))
                case ChunkContentType.HTML => ()
            }
        }
    }

    // 扫描输出中的占位符
    var pos = 0
    while (pos < output.size) {
        var foundKey = ""
        var foundPos = -1
        var foundRef: ?OutputPieceRef = None

        // 查找最近的 unique_key 占位符
        for (key in keyMap.keys()) {
            let idx = output.indexOf(key, pos)
            if (idx >= 0 && (foundPos < 0 || idx < foundPos)) {
                foundPos = idx
                foundKey = key
                foundRef = keyMap.get(key)
            }
        }

        match (foundRef) {
            case Some(ref) =>
                // 输出占位符前的纯文本
                if (foundPos > pos) {
                    pieces.append(OutputPiece(output[pos..foundPos]))
                }
                // 输出占位符引用
                pieces.append(OutputPiece(
                    foundKey,
                    ref.kind,
                    ref.index
                ))
                pos = foundPos + foundKey.size
            case None =>
                // 没有更多占位符, 输出剩余文本
                if (pos < output.size) {
                    pieces.append(OutputPiece(output[pos..output.size]))
                }
                pos = output.size
        }
    }

    // 如果没有任何片段, 添加空片段
    if (pieces.size == 0) {
        pieces.append(OutputPiece(output))
    }

    return pieces
}

/// 生成 HTML chunk 的隔离哈希
// 严格翻译自: postProcessHTMLChunk.rs:47 generateIsolatedHash
// 对中间输出计算哈希, 用于生成唯一输出文件名
// 注意: HTML 的 isolated_hash 需要包含 JS/CSS chunk 的哈希,
// 因为 HTML 内容引用了这些 chunk 的最终路径
private func generateHTMLIsolatedHash(c: LinkerContext, chunk: Chunk): UInt64 {
    var hasher = XxHash64()
    for (piece in chunk.intermediateOutput) {
        if (piece.data.size > 0) {
            hasher.update(piece.data.toArray())
        }
        // 如果是 chunk 引用, 包含目标 chunk 的哈希
        if (piece.kind == OutputPieceKind.Chunk) {
            hasher.update(UInt32(piece.index))
        }
    }
    return hasher.digest()
}

/// 输出片段引用信息
private class OutputPieceRef {
    public var kind: OutputPieceKind
    public var index: Int64

    public init(kind: OutputPieceKind, index: Int64) {
        this.kind = kind
        this.index = index
    }
}
