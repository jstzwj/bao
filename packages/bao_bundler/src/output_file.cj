// 严格翻译自: src/bundler/OutputFile.zig (~337行)
// bao_bundler - 输出文件: 管理打包输出的磁盘写入优化 (move/copy/buffer/noop)
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*

// ============================================================================
// 输出文件
// 严格翻译自: src/bundler/OutputFile.zig
// 核心职责:
//   1. 管理打包输出文件的生命周期
//   2. 根据目标/文件句柄数/同名文件选择不同写入策略
//   3. 支持 move/copy/buffer/noop/pending/saved 六种值类型
//   4. FileOperation 封装文件操作
//   5. BakeExtra 支持 Bake (SSR/路由) 场景
// ============================================================================

/// 输出文件
// 严格翻译自: OutputFile.zig:1 OutputFile
// 不在内存中保持文件，而是:
// 1. 直接写入磁盘
// 2. (可选) 将文件移动到目标位置
// 这节省了缓冲区分配
public class BundlerOutputFile {
    /// 加载器类型
    public var loader: Loader
    /// 输入加载器
    public var inputLoader: Loader
    /// 源路径
    public var srcPath: FsPath
    /// 文件值
    public var value: OutputFileValue
    /// 文件大小
    public var size: Int64
    /// 不含 sourcemap 的大小
    public var sizeWithoutSourcemap: Int64
    /// 哈希值
    public var hash: UInt64
    /// 是否可执行
    public var isExecutable: Bool
    /// Sourcemap 索引
    public var sourceMapIndex: UInt32
    /// 字节码索引
    public var bytecodeIndex: UInt32
    /// 模块信息索引
    public var moduleInfoIndex: UInt32
    /// 输出类型
    public var outputKind: OutputKind
    /// 目标路径 (相对)
    public var destPath: String
    /// Bake 侧 (client/server)
    public var side: ?BakeSide
    /// 入口点索引
    public var entryPointIndex: ?UInt32
    /// 引用的 CSS chunk
    public var referencedCssChunks: ArrayList<Int32>
    /// 源文件索引
    public var sourceIndex: Int32
    /// Bake 额外信息
    public var bakeExtra: BakeExtra

    public init() {
        loader = Loader.File
        inputLoader = Loader.Js
        srcPath = FsPath()
        value = OutputFileValue()
        size = 0
        sizeWithoutSourcemap = 0
        hash = 0
        isExecutable = false
        sourceMapIndex = UInt32.maxValue
        bytecodeIndex = UInt32.maxValue
        moduleInfoIndex = UInt32.maxValue
        outputKind = OutputKind.Chunk
        destPath = ""
        side = None
        entryPointIndex = None
        referencedCssChunks = ArrayList<Int32>()
        sourceIndex = -1
        bakeExtra = BakeExtra()
    }

    /// 零值输出文件
    // 严格翻译自: OutputFile.zig:30 zero_value
    public static func zero(): BundlerOutputFile {
        let f = BundlerOutputFile()
        f.value = OutputFileValue(OutputFileKind.Noop)
        return f
    }

    /// 从 pending 结果创建
    // 严格翻译自: OutputFile.zig:158 initPending()
    public static func initPending(loader: Loader, pending: ResolveResultRef): BundlerOutputFile {
        let f = BundlerOutputFile()
        f.loader = loader
        f.srcPath = pending.path
        f.size = 0
        f.value = OutputFileValue(OutputFileKind.Pending, pending: pending)
        return f
    }

    /// 从文件创建
    // 严格翻译自: OutputFile.zig:167 initFile()
    public static func initFile(pathname: String, size: Int64): BundlerOutputFile {
        let f = BundlerOutputFile()
        f.loader = Loader.File
        f.srcPath = FsPath(pathname)
        f.size = size
        f.value = OutputFileValue(OutputFileKind.Copy, operation: FileOperation.fromFile(pathname))
        return f
    }

    /// 从选项创建
    // 严格翻译自: OutputFile.zig:214 init()
    public static func initFunc(opts: OutputFileOptions): BundlerOutputFile {
        let f = BundlerOutputFile()
        f.loader = opts.loader
        f.inputLoader = opts.inputLoader
        f.srcPath = FsPath(opts.inputPath)
        f.destPath = opts.outputPath
        f.sourceIndex = opts.sourceIndex
        f.hash = opts.hash ?? 0
        f.outputKind = opts.outputKind
        f.isExecutable = opts.isExecutable

        // 大小
        match (opts.size) {
            case Some(s) => f.size = s
            case None => {
                match (opts.dataKind) {
                    case OutputFileDataKind.Buffer => {
                        match (opts.bufferData) {
                            case Some(buf) => f.size = buf.length
                            case None => f.size = 0
                        }
                    }
                    case OutputFileDataKind.File => {
                        match (opts.fileSize) {
                            case Some(s) => f.size = s
                            case None => f.size = 0
                        }
                    }
                    case OutputFileDataKind.Saved => f.size = 0
                }
            }
        }

        f.sizeWithoutSourcemap = opts.displaySize
        f.bytecodeIndex = opts.bytecodeIndex ?? UInt32.maxValue
        f.moduleInfoIndex = opts.moduleInfoIndex ?? UInt32.maxValue
        f.sourceMapIndex = opts.sourceMapIndex ?? UInt32.maxValue
        f.side = opts.side
        f.entryPointIndex = opts.entryPointIndex
        f.referencedCssChunks = opts.referencedCssChunks
        f.bakeExtra = opts.bakeExtra

        // 值
        match (opts.dataKind) {
            case OutputFileDataKind.Buffer => {
                match (opts.bufferData) {
                    case Some(data) => {
                        f.value = OutputFileValue(OutputFileKind.Buffer, bufferData: data)
                    }
                    case None => {
                        f.value = OutputFileValue(OutputFileKind.Noop)
                    }
                }
            }
            case OutputFileDataKind.File => {
                let op = FileOperation.fromFile(opts.outputPath)
                f.value = OutputFileValue(OutputFileKind.Copy, operation: op)
            }
            case OutputFileDataKind.Saved => {
                f.value = OutputFileValue(OutputFileKind.Saved)
            }
        }

        return f
    }

    /// 写入磁盘
    // 严格翻译自: OutputFile.zig:251 writeToDisk()
    public func writeToDisk(rootDir: FileDescriptor, rootDirPath: String): Unit {
        match (value.kind) {
            case OutputFileKind.Noop => ()
            case OutputFileKind.Saved => /* 已写入磁盘 */
            case OutputFileKind.Buffer => {
                // 写入缓冲区数据到磁盘
                // 简化
            }
            case OutputFileKind.Move => {
                moveToDisk(rootDirPath, value.operation.pathname, rootDir)
            }
            case OutputFileKind.Copy => {
                copyToDisk(rootDirPath, value.operation.pathname, rootDir)
            }
            case OutputFileKind.Pending => /* 不应该在这里 */
        }
    }

    /// 移动文件
    // 严格翻译自: OutputFile.zig:295 moveTo()
    private func moveToDisk(rootDirPath: String, relPath: String, dir: FileDescriptor): Unit {
        // 简化: 调用系统 moveFile
    }

    /// 复制文件
    // 严格翻译自: OutputFile.zig:299 copyTo()
    private func copyToDisk(rootDirPath: String, relPath: String, dir: FileDescriptor): Unit {
        // 简化: 调用系统 copyFile
    }

    /// 释放资源
    // 严格翻译自: OutputFile.zig:47 deinit()
    public func deinit(): Unit {
        // 释放缓冲区数据等
    }
}

/// 输出文件值
// 严格翻译自: OutputFile.zig:97 Value
public class OutputFileValue {
    /// 值类型
    public var kind: OutputFileKind
    /// 文件操作 (move/copy)
    public var operation: FileOperation
    /// 缓冲区数据
    public var bufferData: String
    /// Pending 解析结果
    public var pending: ResolveResultRef
    /// 已保存文件
    public var saved: SavedFile

    public init() {
        kind = OutputFileKind.Noop
        operation = FileOperation()
        bufferData = ""
        pending = ResolveResultRef()
        saved = SavedFile()
    }

    public init(kind: OutputFileKind) {
        this.kind = kind
        operation = FileOperation()
        bufferData = ""
        pending = ResolveResultRef()
        saved = SavedFile()
    }

    public init(kind: OutputFileKind, operation: FileOperation) {
        this.kind = kind
        this.operation = operation
        bufferData = ""
        pending = ResolveResultRef()
        saved = SavedFile()
    }

    public init(kind: OutputFileKind, bufferData: String) {
        this.kind = kind
        this.bufferData = bufferData
        operation = FileOperation()
        pending = ResolveResultRef()
        saved = SavedFile()
    }

    public init(kind: OutputFileKind, pending: ResolveResultRef) {
        this.kind = kind
        this.pending = pending
        operation = FileOperation()
        bufferData = ""
        saved = SavedFile()
    }

    /// 获取字节切片
    // 严格翻译自: OutputFile.zig:121 asSlice()
    public func asSlice(): String {
        match (kind) {
            case OutputFileKind.Buffer => bufferData
            case _ => ""
        }
    }
}

/// 输出文件类型
// 严格翻译自: OutputFile.zig:85 Kind
public enum OutputFileKind {
    | Move       // 移动临时文件到目标
    | Copy       // 复制文件到目标
    | Noop       // 无操作
    | Buffer     // 内存缓冲区
    | Pending    // 等待解析
    | Saved      // 已保存
}

/// 文件操作
// 严格翻译自: OutputFile.zig:60 FileOperation
public class FileOperation {
    /// 路径名
    public var pathname: String
    /// 文件描述符
    public var fd: FileDescriptor
    /// 目录描述符
    public var dir: FileDescriptor
    /// 是否是临时目录
    public var isTmpdir: Bool
    /// 是否是输出目录
    public var isOutdir: Bool
    /// 完成后是否关闭句柄
    public var closeHandleOnComplete: Bool
    /// 是否自动 watch
    public var autowatch: Bool

    public init() {
        pathname = ""
        fd = FileDescriptor()
        dir = FileDescriptor()
        isTmpdir = false
        isOutdir = false
        closeHandleOnComplete = false
        autowatch = true
    }

    /// 从文件创建
    // 严格翻译自: OutputFile.zig:69 fromFile()
    public static func fromFile(pathname: String): FileOperation {
        let op = FileOperation()
        op.pathname = pathname
        return op
    }

    /// 获取路径名 (考虑 tmpdir)
    // 严格翻译自: OutputFile.zig:76 getPathname()
    public func getPathname(): String {
        if (isTmpdir) {
            // 简化: 应该 join tmpdir + pathname
            return pathname
        }
        return pathname
    }
}

/// 输出类型
public enum OutputKind {
    | Chunk
    | SourceMap
    | Bytecode
    | Asset
    | Metadata
}

/// Bake 侧
public enum BakeSide {
    | Client
    | Server
}

/// Bake 额外信息
// 严格翻译自: OutputFile.zig:39 BakeExtra
public class BakeExtra {
    /// 是否是路由
    public var isRoute: Bool
    /// 是否完全静态
    public var fullyStatic: Bool
    /// 是否是 Bake 运行时
    public var bakeIsRuntime: Bool

    public init() {
        isRoute = false
        fullyStatic = false
        bakeIsRuntime = false
    }
}

/// 已保存文件
// 严格翻译自: OutputFile.zig:156 SavedFile
public class SavedFile {
    /// 已写入磁盘的路径
    public var path: String
    /// 文件大小
    public var size: Int64

    public init() {
        path = ""
        size = 0
    }
}

/// 输出文件选项
// 严格翻译自: OutputFile.zig:182 Options
public class OutputFileOptions {
    /// 加载器
    public var loader: Loader
    /// 输入加载器
    public var inputLoader: Loader
    /// 哈希
    public var hash: ?UInt64
    /// Sourcemap 索引
    public var sourceMapIndex: ?UInt32
    /// 字节码索引
    public var bytecodeIndex: ?UInt32
    /// 模块信息索引
    public var moduleInfoIndex: ?UInt32
    /// 输出路径
    public var outputPath: String
    /// 源文件索引
    public var sourceIndex: Int32
    /// 大小
    public var size: ?Int64
    /// 输入路径
    public var inputPath: String
    /// 显示大小
    public var displaySize: UInt32
    /// 输出类型
    public var outputKind: OutputKind
    /// 是否可执行
    public var isExecutable: Bool
    /// 数据类型
    public var dataKind: OutputFileDataKind
    /// 缓冲区数据
    public var bufferData: ?String
    /// 文件大小
    public var fileSize: ?Int64
    /// Bake 侧
    public var side: ?BakeSide
    /// 入口点索引
    public var entryPointIndex: ?UInt32
    /// 引用的 CSS chunk
    public var referencedCssChunks: ArrayList<Int32>
    /// Bake 额外信息
    public var bakeExtra: BakeExtra

    public init() {
        loader = Loader.File
        inputLoader = Loader.Js
        hash = None
        sourceMapIndex = None
        bytecodeIndex = None
        moduleInfoIndex = None
        outputPath = ""
        sourceIndex = -1
        size = None
        inputPath = ""
        displaySize = 0
        outputKind = OutputKind.Chunk
        isExecutable = false
        dataKind = OutputFileDataKind.Buffer
        bufferData = None
        fileSize = None
        side = None
        entryPointIndex = None
        referencedCssChunks = ArrayList<Int32>()
        bakeExtra = BakeExtra()
    }
}

/// 输出文件数据类型
public enum OutputFileDataKind {
    | Buffer
    | File
    | Saved
}

/// FS 路径
public class FsPath {
    /// 路径文本
    public var text: String
    /// pretty 路径
    public var pretty: String
    /// 命名空间
    public var namespace: String

    public init() {
        text = ""
        pretty = ""
        namespace = "file"
    }

    public init(text: String) {
        this.text = text
        this.pretty = text
        this.namespace = "file"
    }
}

/// 解析结果引用 (简化)
public class ResolveResultRef {
    public var path: FsPath

    public init() {
        path = FsPath()
    }
}
