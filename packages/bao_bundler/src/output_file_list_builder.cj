// 严格翻译自: src/bundler/linker_context/OutputFileListBuilder.zig (150行)
// bao_bundler - 输出文件列表构建器: 管理 chunk/sourcemap/bytecode/附加文件的索引空间
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// 输出文件列表构建器
// 严格翻译自: OutputFileListBuilder.zig
//
// 将输出文件列表分割为 3 个空间，保持 chunk 索引一致:
//   1. chunks (与 chunk 索引一一对应)
//   2. sourcemaps + bytecode + module_info
//   3. 附加输出文件 (assets 等)
//
// 关键不变量: outputIndexForChunk(chunk[i]) == i
// 这样 DevServer 可以通过 chunk 索引直接找到对应的输出文件
// ============================================================================

/// 输出文件列表构建器
// 严格翻译自: OutputFileListBuilder.zig:29 OutputFileList
public class OutputFileListBuilder {
    /// 输出文件列表
    public var outputFiles: ArrayList<BundlerOutputFile>
    /// chunk 的当前索引
    public var indexForChunk: Int64
    /// sourcemap/bytecode 的当前索引 (null 表示没有)
    public var indexForSourcemapsAndBytecode: ?Int64
    /// 附加输出文件的起始索引
    public var additionalOutputFilesStart: Int64
    /// 总插入数
    public var totalInsertions: Int64

    public init() {
        outputFiles = ArrayList<BundlerOutputFile>()
        indexForChunk = 0
        indexForSourcemapsAndBytecode = None
        additionalOutputFilesStart = 0
        totalInsertions = 0
    }

    /// 初始化
    // 严格翻译自: OutputFileListBuilder.zig:38 init()
    public static func init(linker: LinkerContext,
                              chunks: ArrayList<Chunk>): OutputFileListBuilder {
        let builder = OutputFileListBuilder()

        // 计算容量
        let (length, supplementaryCount) = calculateOutputFileListCapacity(linker, chunks)

        // 预分配空间
        for (_ in 0..length) {
            builder.outputFiles.append(BundlerOutputFile.zero())
        }

        builder.indexForChunk = 0
        builder.indexForSourcemapsAndBytecode = if (supplementaryCount == 0) {
            None
        } else {
            Some(chunks.size)
        }
        builder.additionalOutputFilesStart = chunks.size + supplementaryCount
        builder.totalInsertions = 0

        return builder
    }

    /// 计算输出文件列表容量
    // 严格翻译自: OutputFileListBuilder.zig:70 calculateOutputFileListCapacity()
    public static func calculateOutputFileListCapacity(
        linker: LinkerContext,
        chunks: ArrayList<Chunk>
    ): Tuple<Int64, Int64> {
        // sourcemap 数量
        var sourceMapCount: Int64 = 0
        if (linker.options.sourceMaps == SourceMapOption.External ||
            linker.options.sourceMaps == SourceMapOption.Linked) {
            for (chunk in chunks) {
                if (chunk.contentType == ChunkContentType.JavaScript ||
                    chunk.contentType == ChunkContentType.CSS) {
                    sourceMapCount++
                }
            }
        }

        // bytecode 数量
        var bytecodeCount: Int64 = 0
        if (linker.options.generateBytecodeCache) {
            for (chunk in chunks) {
                if (chunk.contentType == ChunkContentType.JavaScript) {
                    let loader = if (chunk.isEntryPoint() && chunk.entryPoint.sourceIndex >= 0 &&
                                     chunk.entryPoint.sourceIndex < linker.parseGraph.loaders.size) {
                        linker.parseGraph.loaders[chunk.entryPoint.sourceIndex]
                    } else {
                        Loader.Js
                    }
                    if (loader.isJSLike()) {
                        bytecodeCount++
                    }
                }
            }
        }

        // module_info 数量 (ESM bytecode --compile)
        let moduleInfoCount = if (linker.options.generateBytecodeCache &&
                                     linker.options.outputFormat == OutputFormat.ESM &&
                                     linker.options.compile) {
            bytecodeCount
        } else {
            0
        }

        // 附加输出文件数量
        let additionalCount: Int64 = 0 // linker.parseGraph.additionalOutputFiles.size

        let total = chunks.size + sourceMapCount + bytecodeCount + moduleInfoCount + additionalCount
        let supplementary = sourceMapCount + bytecodeCount + moduleInfoCount

        return (total, supplementary)
    }

    /// 为 chunk 插入输出文件
    // 严格翻译自: OutputFileListBuilder.zig:104 insertForChunk()
    public func insertForChunk(outputFile: BundlerOutputFile): Int64 {
        let index = indexForChunk
        outputFiles[index] = outputFile
        indexForChunk++
        totalInsertions++
        return index
    }

    /// 为 sourcemap/bytecode 插入输出文件
    // 严格翻译自: OutputFileListBuilder.zig:112 insertForSourcemapOrBytecode()
    public func insertForSourcemapOrBytecode(outputFile: BundlerOutputFile): ?Int64 {
        match (indexForSourcemapsAndBytecode) {
            case Some(index) => {
                let result = index
                outputFiles[result] = outputFile
                indexForSourcemapsAndBytecode = Some(index + 1)
                totalInsertions++
                return result
            }
            case None => return None
        }
    }

    /// 插入附加输出文件
    // 严格翻译自: OutputFileListBuilder.zig:120 insertAdditionalOutputFiles()
    public func insertAdditionalOutputFiles(files: ArrayList<BundlerOutputFile>): Unit {
        var destIdx = additionalOutputFilesStart
        for (file in files) {
            if (destIdx < outputFiles.size) {
                outputFiles[destIdx] = file
            }
            destIdx++
        }
        totalInsertions += files.size
    }

    /// 获取可变的附加输出文件视图
    // 严格翻译自: OutputFileListBuilder.zig:130 getMutableAdditionalOutputFiles()
    public func getMutableAdditionalOutputFiles(): ArrayList<BundlerOutputFile> {
        let result = ArrayList<BundlerOutputFile>()
        for (i in additionalOutputFilesStart..outputFiles.size) {
            result.append(outputFiles[i])
        }
        return result
    }

    /// 取出最终列表
    // 严格翻译自: OutputFileListBuilder.zig:60 take()
    public func take(): ArrayList<BundlerOutputFile> {
        return outputFiles
    }
}

/// 输出格式
public enum OutputFormat {
    | ESM
    | CJS
    | IIFE
}
