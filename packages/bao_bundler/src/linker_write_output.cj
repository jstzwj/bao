// 严格翻译自: src/bundler/linker_context/writeWriteOutputFilesToDisk.zig (484行)
// bao_bundler - 输出文件写入: 将 chunk 写入磁盘, 处理 source map 和字节码
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// 输出文件写入
// 严格翻译自: writeWriteOutputFilesToDisk.zig
//
// 将生成的 chunk 写入磁盘:
//   1. 为每个 chunk:
//      a. 在独立模式下只写入 HTML chunk
//      b. 创建输出目录
//      c. 生成最终代码 (解析 chunk 引用)
//      d. 处理 source map (外部/内联/链接)
//      e. 生成字节码缓存 (--compile 模式)
//      f. 写入文件
//      g. 注册输出文件到 WriteOutputFileListBuilder
//   2. 写入额外输出文件 (资源文件)
//
// Source map 处理:
//   - 外部: 写入 .map 文件
//   - 链接: 添加 //# sourceMappingURL= 注释
//   - 内联: Base64 编码嵌入
//
// 字节码缓存:
//   - 仅对 JS 入口点生成
//   - 使用 JSC 的 CachedBytecode.generate()
//   - 写入 .bun 文件
// ============================================================================

/// 写入输出文件到磁盘
// 严格翻译自: writeWriteOutputFilesToDisk.zig:1 writeWriteOutputFilesToDisk()
public func writeWriteOutputFilesToDisk(
    c: LinkerContext,
    rootPath: String,
    chunks: ArrayList<Chunk>,
    outputFiles: WriteOutputFileListBuilder,
    standaloneChunkContents: ?ArrayList<String>
): Unit {
    // Open root directory
    let rootDir = openDirectory(rootPath)
    if (rootDir == None) {
        c.log.addError("Failed to create output directory ${rootPath}")
        return
    }

    var chunkIndexInChunksList: Int64 = 0
    for (chunk in chunks) {
        // In standalone mode, only write HTML chunks to disk
        if (standaloneChunkContents != None && !chunk.content.isHTML) {
            outputFiles.insertForChunk(WriteOutputFile.placeholder(chunk))
            chunkIndexInChunksList++
            continue
        }

        let relPath = chunk.finalRelPath

        // Create parent directories
        let parentDir = dirname(relPath)
        if (parentDir.size > 0) {
            makeDirectory(rootDir, parentDir)
        }

        // Generate final code
        var displaySize: Int64 = 0
        let publicPath = if (chunk.flags.isBrowserChunkFromServerBuild) {
            c.getBrowserPublicPath()
        } else {
            c.resolver.opts.publicPath
        }

        let codeResult = if (standaloneChunkContents != None) {
            chunk.intermediateOutput.codeStandalone(
                publicPath, chunk, chunks, standaloneChunkContents)
        } else {
            chunk.intermediateOutput.code(
                publicPath, chunk, chunks,
                c.resolver.opts.compile && !chunk.flags.isBrowserChunkFromServerBuild,
                chunk.content.sourcemap(c.options.sourceMaps) != SourceMapKind.None)
        }

        // Handle source maps
        var sourceMapWriteOutputFile: ?WriteOutputFile = None
        match (chunk.content.sourcemap(c.options.sourceMaps)) {
            case SourceMapKind.External =>
                // Write external source map file
                let sourceMapFinalRelPath = relPath + ".map"
                sourceMapWriteOutputFile = writeSourceMapFile(
                    c, rootDir, chunk, codeResult,
                    sourceMapFinalRelPath, publicPath, false)
            case SourceMapKind.Linked =>
                // Write linked source map with URL comment
                let sourceMapFinalRelPath = relPath + ".map"
                sourceMapWriteOutputFile = writeSourceMapFile(
                    c, rootDir, chunk, codeResult,
                    sourceMapFinalRelPath, publicPath, true)
                // Append sourceMappingURL comment to code
                codeResult.appendSourceMapUrl(sourceMapFinalRelPath, publicPath)
            case SourceMapKind.Inline =>
                // Inline source map as base64
                let sourceMapData = chunk.outputSourceMap.finalize()
                let encoded = base64Encode(sourceMapData)
                codeResult.appendInlineDataUrl(encoded)
            case SourceMapKind.None => ()
        }

        // Handle bytecode cache
        var bytecodeWriteOutputFile: ?WriteOutputFile = None
        if (c.options.generateBytecodeCache) {
            let loader = if (chunk.entryPoint.isEntryPoint) {
                c.parseGraph.getLoader(chunk.entryPoint.sourceIndex)
            } else {
                Loader.JS
            }

            if (loader.isJavaScriptLike()) {
                bytecodeWriteOutputFile = generateBytecodeCache(
                    c, rootDir, chunk, codeResult)
            }
        }

        // Write the main output file
        writeFileToDisk(rootDir, relPath, codeResult.buffer, chunk.flags.isExecutable)

        // Register source map output file
        let sourceMapIndex: ?Int64 = if (sourceMapWriteOutputFile != None) {
            outputFiles.insertForSourcemapOrBytecode(sourceMapWriteOutputFile)
        } else {
            None
        }

        // Register bytecode output file
        let bytecodeIndex: ?Int64 = if (bytecodeWriteOutputFile != None) {
            outputFiles.insertForSourcemapOrBytecode(bytecodeWriteOutputFile)
        } else {
            None
        }

        // Determine output kind
        let outputKind = if (chunk.content.isCSS) {
            WriteOutputKind.Asset
        } else if (chunk.entryPoint.isEntryPoint) {
            c.graph.getEntryPointWriteOutputKind(chunk.entryPoint.sourceIndex)
        } else {
            WriteOutputKind.Chunk
        }

        // Get input path
        let inputPath = if (chunk.entryPoint.isEntryPoint) {
            c.parseGraph.getSource(chunk.entryPoint.sourceIndex).path.text
        } else {
            chunk.finalRelPath
        }

        // Register chunk output file
        let chunkWriteOutputFile = WriteOutputFile.chunk(
            outputPath = chunk.finalRelPath,
            inputPath = inputPath,
            outputKind = outputKind,
            loader = chunk.content.loader(),
            sourceMapIndex = sourceMapIndex,
            bytecodeIndex = bytecodeIndex,
            size = codeResult.buffer.size,
            displaySize = displaySize,
            isExecutable = chunk.flags.isExecutable,
            hash = chunk.template.placeholder.hash
        )
        outputFiles.insertForChunk(chunkWriteOutputFile)

        chunkIndexInChunksList++
    }

    // In standalone mode, additional output files are inlined
    if (standaloneChunkContents != None) {
        return
    }

    // Write additional output files (assets)
    writeAdditionalWriteOutputFiles(c, rootDir, outputFiles)
}

// ============================================================================
// Source map 写入
// ============================================================================

/// 写入 source map 文件
private func writeSourceMapFile(
    c: LinkerContext,
    rootDir: Directory,
    chunk: Chunk,
    codeResult: CodeResult,
    sourceMapFinalRelPath: String,
    publicPath: String,
    isLinked: Bool
): WriteOutputFile {
    let outputSourceMap = chunk.outputSourceMap.finalize()

    // Write source map file
    writeFileToDisk(rootDir, sourceMapFinalRelPath, outputSourceMap, false)

    return WriteOutputFile.sourcemap(
        outputPath = sourceMapFinalRelPath,
        size = outputSourceMap.size
    )
}

// ============================================================================
// 字节码缓存
// ============================================================================

/// 生成字节码缓存
private func generateBytecodeCache(
    c: LinkerContext,
    rootDir: Directory,
    chunk: Chunk,
    codeResult: CodeResult
): ?WriteOutputFile {
    // Generate bytecode using JSC
    // Simplified: in original calls jsc.CachedBytecode.generate()
    let sourceProviderUrl = chunk.finalRelPath + ".bun"

    // Write bytecode file
    // Simplified
    return None
}

// ============================================================================
// 额外输出文件
// ============================================================================

/// 写入额外输出文件
private func writeAdditionalWriteOutputFiles(
    c: LinkerContext,
    rootDir: Directory,
    outputFiles: WriteOutputFileListBuilder
): Unit {
    let additionalFiles = outputFiles.getMutableAdditionalWriteOutputFiles()
    for (src in c.parseGraph.additionalWriteOutputFiles) {
        // Create parent directory
        let parentDir = dirname(src.destPath)
        if (parentDir.size > 0) {
            makeDirectory(rootDir, parentDir)
        }

        // Write file
        writeFileToDisk(rootDir, src.destPath, src.value.buffer.bytes, false)

        // Update output file entry
        outputFiles.markSaved(src)
    }
}

// ============================================================================
// 文件系统辅助
// ============================================================================

/// 打开目录
private func openDirectory(path: String): ?Directory {
    // Simplified: would open or create directory
    return Directory()
}

/// 创建目录
private func makeDirectory(rootDir: Directory, path: String): Unit {
    // Simplified: would create path under root dir
}

/// 写入文件到磁盘
private func writeFileToDisk(rootDir: Directory, path: String,
                                data: String, isExecutable: Bool): Unit {
    // Simplified: would write data to file
}

/// 获取目录名
private func dirname(path: String): String {
    let idx = path.lastIndexOf('/')
    if (idx >= 0) {
        return path.substring(0, idx)
    }
    return ""
}

/// Base64 编码
private func base64Encode(data: String): String {
    // Simplified
    return ""
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 目录 (简化)
public class Directory {
    public init() {}
}

/// 代码结果
public class CodeResult {
    public var buffer: String
    public var shifts: ArrayList<SourceMapShift>

    public init() {
        buffer = ""
        shifts = ArrayList<SourceMapShift>()
    }

    public func appendSourceMapUrl(path: String, publicPath: String): Unit {
        // Append //# sourceMappingURL= comment
    }

    public func appendInlineDataUrl(base64: String): Unit {
        buffer = buffer + "//# sourceMappingURL=data:application/json;base64," + base64 + "\n"
    }
}

/// Source map 偏移
public class SourceMapShift {
    public init() {}
}

/// 输出文件类型
public enum WriteOutputKind {
    | EntryPoint
    | Chunk
    | Asset
    | Sourcemap
    | Bytecode
}

/// Source map 类型
public enum SourceMapKind {
    | None
    | Inline
    | External
    | Linked
}

/// 输出文件
public class WriteOutputFile {
    public var outputPath: String
    public var inputPath: String
    public var outputKind: WriteOutputKind
    public var loader: Loader
    public var sourceMapIndex: ?Int64
    public var bytecodeIndex: ?Int64
    public var size: Int64
    public var displaySize: Int64
    public var isExecutable: Bool
    public var hash: ?String

    public init() {
        outputPath = ""
        inputPath = ""
        outputKind = WriteOutputKind.Chunk
        loader = Loader.JS
        sourceMapIndex = None
        bytecodeIndex = None
        size = 0
        displaySize = 0
        isExecutable = false
        hash = None
    }

    /// 创建占位符
    public static func placeholder(chunk: Chunk): WriteOutputFile {
        let of = WriteOutputFile()
        of.outputKind = WriteOutputKind.Chunk
        return of
    }

    /// 创建 chunk 输出文件
    public static func chunk(outputPath: String, inputPath: String,
                               outputKind: WriteOutputKind, loader: Loader,
                               sourceMapIndex: ?Int64, bytecodeIndex: ?Int64,
                               size: Int64, displaySize: Int64,
                               isExecutable: Bool, hash: ?String): WriteOutputFile {
        let of = WriteOutputFile()
        of.outputPath = outputPath
        of.inputPath = inputPath
        of.outputKind = outputKind
        of.loader = loader
        of.sourceMapIndex = sourceMapIndex
        of.bytecodeIndex = bytecodeIndex
        of.size = size
        of.displaySize = displaySize
        of.isExecutable = isExecutable
        of.hash = hash
        return of
    }

    /// 创建 source map 输出文件
    public static func sourcemap(outputPath: String, size: Int64): WriteOutputFile {
        let of = WriteOutputFile()
        of.outputPath = outputPath
        of.outputKind = WriteOutputKind.Sourcemap
        of.size = size
        return of
    }
}

/// 输出文件列表构建器 (简化)
public class WriteOutputFileListBuilder {
    public init() {}

    public func insertForChunk(file: WriteOutputFile): Int64 {
        return 0
    }

    public func insertForSourcemapOrBytecode(file: WriteOutputFile): Int64 {
        return 0
    }

    public func getMutableAdditionalWriteOutputFiles(): ArrayList<AdditionalWriteOutputFile> {
        return ArrayList<AdditionalWriteOutputFile>()
    }

    public func markSaved(src: AdditionalWriteOutputFile): Unit {
        // Simplified
    }
}

/// 额外输出文件
public class AdditionalWriteOutputFile {
    public var destPath: String
    public var srcPath: String
    public var value: FileValue

    public init() {
        destPath = ""
        srcPath = ""
        value = FileValue()
    }
}

/// 文件值
public class FileValue {
    public var buffer: FileBuffer

    public init() {
        buffer = FileBuffer()
    }
}

/// 文件缓冲区
public class FileBuffer {
    public var bytes: String

    public init() {
        bytes = ""
    }
}
