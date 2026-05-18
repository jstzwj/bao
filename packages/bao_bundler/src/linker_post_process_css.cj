// 严格翻译自: src/bundler/linker_context/postProcessCSSChunk.zig (128行)
// bao_bundler - CSS chunk 后处理: 拼接编译结果、生成 source map
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// CSS chunk 后处理
// 严格翻译自: postProcessCSSChunk.zig
//
// 在所有 CSS 编译结果生成后, 执行后处理:
//   1. 拼接所有编译结果, 插入文件路径注释
//   2. 处理 source map 偏移
//   3. 确保文件以换行符结尾
//   4. 将输出分割为片段 (breakOutputIntoPieces)
//   5. 生成隔离哈希 (用于最终路径)
//   6. 生成 source map (如果启用)
// ============================================================================

/// CSS chunk 后处理
// 严格翻译自: postProcessCSSChunk.zig:2 postProcessCSSChunk()
public func postProcessCSSChunk(
    c: LinkerContext,
    chunk: Chunk,
    chunks: ArrayList<Chunk>
): Unit {
    var j = StringJoiner()
    var lineOffset = LineColumnOffset()
    if (c.options.sourceMaps != SourceMaps.None) {
        lineOffset = LineColumnOffset()
    }

    var newlineBeforeComment = false

    // Concatenate the generated CSS chunks together
    let compileResults = chunk.compileResultsForChunk

    var compileResultsForSourceMap = ArrayList<CompileResultForSourceMap>()

    let sources = c.parseGraph.inputFiles.sources
    for (compileResult in compileResults) {
        let sourceIndex = compileResult.sourceIndex

        // Add file path comment (non-minified bundle mode)
        if (c.options.mode == BundleMode.Bundle &&
            !c.options.minifyWhitespace &&
            sourceIndex >= 0) {
            if (newlineBeforeComment) {
                j.pushStatic("\n")
                lineOffset.advance("\n")
            }

            let pretty = getSourcePrettyPath(c, sourceIndex)
            j.pushStatic("/* ")
            lineOffset.advance("/* ")
            j.pushStatic(pretty)
            lineOffset.advance(pretty)
            j.pushStatic(" */\n")
            lineOffset.advance(" */\n")
        }

        if (compileResult.code.size > 0) {
            newlineBeforeComment = true
        }

        // Append the generated code
        j.push(compileResult.code)

        if (compileResult.sourceMapChunk != None) {
            if (c.options.sourceMaps != SourceMaps.None) {
                compileResultsForSourceMap.append(CompileResultForSourceMap(
                    compileResult.sourceMapChunk,
                    lineOffset,
                    compileResult.sourceIndex
                ))
            }
            lineOffset.reset()
        } else {
            lineOffset.advance(compileResult.code)
        }
    }

    // Ensure file ends with a newline
    j.ensureNewlineAtEnd()

    // Break output into pieces for chunk reference resolution
    chunk.intermediateOutput = breakOutputIntoPieces(c, j, chunks.size)
    chunk.isolatedHash = generateIsolatedHash(c, chunk)

    // Generate source map if enabled
    if (c.options.sourceMaps != SourceMaps.None) {
        let canHaveShifts = chunk.intermediateOutput.isPieces
        chunk.outputSourceMap = generateSourceMapForChunk(
            c, chunk.isolatedHash, compileResultsForSourceMap,
            c.resolver.opts.outputDir, canHaveShifts
        )
    }
}

// ============================================================================
// 辅助类型和函数
// ============================================================================

/// 编译结果的 source map 信息
public class CompileResultForSourceMap {
    public var sourceMapChunk: SourceMapChunk
    public var generatedOffset: LineColumnOffset
    public var sourceIndex: Int64

    public init(sourceMapChunk: SourceMapChunk, generatedOffset: LineColumnOffset,
                sourceIndex: Int64) {
        this.sourceMapChunk = sourceMapChunk
        this.generatedOffset = generatedOffset
        this.sourceIndex = sourceIndex
    }
}

/// 行列偏移
public class LineColumnOffset {
    public var line: Int64
    public var column: Int64

    public init() {
        line = 0
        column = 0
    }

    public func advance(text: String): Unit {
        for (c in text) {
            if (c == '\n') {
                line++
                column = 0
            } else {
                column++
            }
        }
    }

    public func reset(): Unit {
        line = 0
        column = 0
    }
}

/// Source map 块 (简化)
public class SourceMapChunk {
    public init() {}
}

/// 字符串拼接器 (简化)
public class StringJoiner {
    private var parts: ArrayList<String>

    public init() {
        parts = ArrayList<String>()
    }

    public func pushStatic(s: String): Unit {
        parts.append(s)
    }

    public func push(s: String): Unit {
        parts.append(s)
    }

    public func ensureNewlineAtEnd(): Unit {
        if (parts.size > 0) {
            let last = parts[parts.size - 1]
            if (!last.endsWith("\n")) {
                parts.append("\n")
            }
        }
    }
}

/// 打包模式
public enum BundleMode {
    | Bundle
    | Passthrough
}

/// Source maps 选项
public enum SourceMaps {
    | None
    | Inline
    | External
    | Linked
}

// 简化辅助函数
private func getSourcePrettyPath(c: LinkerContext, sourceIndex: Int64): String {
    return ""
}

private func breakOutputIntoPieces(c: LinkerContext, j: StringJoiner, chunksLen: Int64): IntermediateOutput {
    return IntermediateOutput()
}

private func generateIsolatedHash(c: LinkerContext, chunk: Chunk): String {
    return ""
}

private func generateSourceMapForChunk(c: LinkerContext, hash: String,
                                         results: ArrayList<CompileResultForSourceMap>,
                                         outputDir: String, canHaveShifts: Bool): SourceMap {
    return SourceMap()
}

/// 中间输出 (简化)
public class IntermediateOutput {
    public var isPieces: Bool

    public init() {
        isPieces = false
    }
}

/// Source map (简化)
public class SourceMap {
    public init() {}
}
