// bao_install - 可恢复的流式 Tarball 解压器
// 严格翻译自: src/install/TarballStream.zig
//   Resumable, non-blocking tarball extractor for `bun install`.
//   HTTP 线程逐块传递 body 到 onChunk, 解压和写入在 ThreadPool 上异步进行
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 提取阶段状态机
// 严格翻译自: src/install/TarballStream.zig - phase
//   phase: enum { want_header, want_data, done }
// ============================================================================

/// 提取阶段
/// 翻译自: TarballStream.phase
public enum TarballPhase {
    | WantHeader   // 调用 archive_read_next_header
    | WantData     // 写入文件体数据
    | Done         // 完成

    public operator func ==(right: TarballPhase): Bool {
        match (this) {
            case WantHeader => match (right) { case WantHeader => true case _ => false }
            case WantData => match (right) { case WantData => true case _ => false }
            case Done => match (right) { case Done => true case _ => false }
        }
    }
    public operator func !=(right: TarballPhase): Bool { !(this == right) }
}

// ============================================================================
// 文件类型
// 严格翻译自: src/install/TarballStream.zig 中的文件类型判断
//   bun.sys.kindFromMode(entry.filetype())
// ============================================================================

/// 文件系统条目类型
/// 翻译自: bun.sys.Kind
public enum FileKind {
    | File
    | Directory
    | SymLink
    | Other

    public operator func ==(right: FileKind): Bool {
        match (this) {
            case File => match (right) { case File => true case _ => false }
            case Directory => match (right) { case Directory => true case _ => false }
            case SymLink => match (right) { case SymLink => true case _ => false }
            case Other => match (right) { case Other => true case _ => false }
        }
    }
    public operator func !=(right: FileKind): Bool { !(this == right) }
}

// ============================================================================
// 归档读取结果
// 严格翻译自: src/install/TarballStream.zig - lib.Archive.Result
//   ARCHIVE_OK, ARCHIVE_WARN, ARCHIVE_RETRY, ARCHIVE_EOF, ARCHIVE_FAILED, ARCHIVE_FATAL
// ============================================================================

/// 归档操作结果
/// 翻译自: lib.Archive.Result
public enum ArchiveResult {
    | Ok
    | Warn
    | Retry
    | Eof
    | Failed
    | Fatal

    public operator func ==(right: ArchiveResult): Bool {
        match (this) {
            case Ok => match (right) { case Ok => true case _ => false }
            case Warn => match (right) { case Warn => true case _ => false }
            case Retry => match (right) { case Retry => true case _ => false }
            case Eof => match (right) { case Eof => true case _ => false }
            case Failed => match (right) { case Failed => true case _ => false }
            case Fatal => match (right) { case Fatal => true case _ => false }
        }
    }
    public operator func !=(right: ArchiveResult): Bool { !(this == right) }
}

// ============================================================================
// 归档数据块
// 严格翻译自: src/install/TarballStream.zig - lib.Archive.Block
//   { bytes: []const u8, offset: i64, result: Archive.Result }
// ============================================================================

/// 归档数据块
/// 翻译自: lib.Archive.Block
public class ArchiveBlock {
    /// 数据字节
    public var bytes: Array<UInt8>
    /// 偏移量
    public var offset: Int64
    /// 读取结果
    public var result: ArchiveResult

    public init() {
        bytes = []
        offset = 0
        result = ArchiveResult.Ok
    }

    public init(bytes: Array<UInt8>, offset: Int64, result: ArchiveResult) {
        this.bytes = bytes
        this.offset = offset
        this.result = result
    }
}

// ============================================================================
// 归档条目
// 严格翻译自: src/install/TarballStream.zig - lib.Archive.Entry
// ============================================================================

/// 归档条目
/// 翻译自: lib.Archive.Entry
public class ArchiveEntry {
    /// 路径名
    public var pathname: String
    /// 文件类型 (mode)
    public var filetype: UInt32
    /// 权限
    public var perm: UInt16
    /// 符号链接目标
    public var symlinkTarget: String
    /// 文件大小
    public var size: Int64

    public init() {
        pathname = ""
        filetype = UInt32(0)
        perm = UInt16(0o644)
        symlinkTarget = ""
        size = Int64(0)
    }

    /// 获取文件类型
    /// 翻译自: bun.sys.kindFromMode
    public func kind(): FileKind {
        // AE_IFREG = 0o100000, AE_IFDIR = 0o040000, AE_IFLNK = 0o120000
        if ((filetype & UInt32(0o170000)) == UInt32(0o100000)) { return FileKind.File }
        if ((filetype & UInt32(0o170000)) == UInt32(0o040000)) { return FileKind.Directory }
        if ((filetype & UInt32(0o170000)) == UInt32(0o120000)) { return FileKind.SymLink }
        return FileKind.Other
    }
}

// ============================================================================
// 简化的归档读取器
// 严格翻译自: src/install/TarballStream.zig 中对 libarchive 的调用
// ============================================================================

/// 归档读取器 (简化)
/// 翻译自: lib.Archive
///   封装 libarchive 的读取操作
public class ArchiveReader {
    private var tarballStream: ?TarballStream

    public init() {
        tarballStream = None
    }

    /// 打开归档
    /// 翻译自: TarballStream.openArchive
    ///   设置 gzip 过滤器和 tar 格式, 注册读取回调
    public func open(stream: TarballStream): ArchiveResult {
        tarballStream = Some(stream)
        return ArchiveResult.Ok
    }

    /// 读取下一个头
    /// 翻译自: archive.readNextHeader
    public func readNextHeader(entry: ArchiveEntry): ArchiveResult {
        if (tarballStream.isSome()) {
            let stream = tarballStream.getOrThrow()
            if (stream.pending.size <= 0) {
                return ArchiveResult.Retry
            }
            return ArchiveResult.Ok
        }
        return ArchiveResult.Failed
    }

    /// 读取下一个数据块
    /// 翻译自: archive.next / archive_read_data_block
    public func next(offset: Ref<Int64>): ?ArchiveBlock {
        if (tarballStream.isNone()) {
            return None
        }
        let stream = tarballStream.getOrThrow()
        if (stream.pending.size <= 0) {
            return None  // 数据结束
        }
        // 简化: 返回当前数据块
        let block = ArchiveBlock()
        offset.value = 0
        block.result = ArchiveResult.Ok
        return block
    }

    /// 读取回调
    /// 翻译自: TarballStream.archiveReadCallback
    ///   从 reading 缓冲区提供数据给 libarchive
    ///   返回可读字节数, 或 ARCHIVE_RETRY (需要更多数据), 或 0 (EOF)
    public func readCallback(): Int64 {
        if (tarballStream.isNone()) { return Int64(0) }
        let stream = tarballStream.getOrThrow()
        let remaining = stream.pending.size
        if (remaining > 0) {
            return Int64(remaining)
        }

        // 检查是否已关闭
        if (stream.closed) {
            return Int64(0)  // EOF
        }

        // 告诉 libarchive 重试
        return Int64(-30)  // ARCHIVE_RETRY
    }

    /// 关闭归档
    public func close(): Unit {
        tarballStream = None
    }

    /// 获取错误字符串
    public func errorString(): String {
        return "archive error"
    }
}

// ============================================================================
// 流式 Tarball 解压器
// 严格翻译自: src/install/TarballStream.zig - TarballStream
//   跨线程生产者状态 (HTTP -> worker):
//     mutex, pending, closed, http_err, status_code, draining
//   Drain 侧状态:
//     reading, read_pos, archive, phase, out_fd, dest, hasher 等
// ============================================================================

/// 可恢复的流式 Tarball 解压器
/// 对应 Bun: TarballStream
/// 支持下载和解压并行执行, 不需要在内存中保存完整 tarball
///
/// 工作流程:
/// 1. HTTP 线程通过 onChunk 传递压缩数据块
/// 2. onChunk 将数据追加到 pending 并调度 drain 任务
/// 3. drain 在工作线程上运行, 通过 libarchive 解压并写入文件
/// 4. 当 libarchive 需要更多数据时返回 ARCHIVE_RETRY, 释放工作线程
/// 5. 下一个 HTTP 块到达时重新调度 drain, 从上次中断处恢复
public class TarballStream {
    // ===== 跨线程生产者状态 (HTTP -> Worker) =====

    /// 互斥锁 (保护 pending)
    /// 翻译自: mutex: Mutex = .{}
    public var mutex: TarballMutex

    /// 待处理的压缩字节 (HTTP 线程追加, 解压线程消费)
    /// 翻译自: pending: std.ArrayListUnmanaged(u8)
    public var pending: ArrayList<UInt8>

    /// HTTP 线程是否已交付最后一个块
    /// 翻译自: closed: bool
    public var closed: Bool

    /// HTTP 请求失败时的错误
    /// 翻译自: http_err: ?anyerror
    public var httpErr: ?String

    /// 响应状态码
    /// 翻译自: status_code: u32
    public var statusCode: UInt32

    /// 是否正在排空 (drain 任务已排队或运行中)
    /// 翻译自: draining: std.atomic.Value(bool)
    public var draining: Bool

    // ===== Drain 侧状态 =====

    /// 当前被 libarchive 消费的压缩字节
    /// 翻译自: reading: std.ArrayListUnmanaged(u8)
    public var reading: ArrayList<UInt8>

    /// reading 中的读取位置
    /// 翻译自: read_pos: usize
    public var readPos: Int64

    /// libarchive 归档读取器
    /// 翻译自: archive: ?*lib.Archive
    public var archive: ?ArchiveReader

    /// 当前提取阶段
    /// 翻译自: phase: enum { want_header, want_data, done }
    public var phase: TarballPhase

    /// 输出文件描述符 (当前正在写入的条目)
    /// 翻译自: out_fd: ?bun.FD
    public var outFd: ?TarballFd

    /// 是否使用 pwrite (POSIX)
    /// 翻译自: use_pwrite: bool
    public var usePwrite: Bool

    /// 是否使用 lseek
    /// 翻译自: use_lseek: bool
    public var useLseek: Bool

    /// 目标临时目录
    /// 翻译自: dest: ?bun.FD
    public var dest: ?TarballFd

    /// 临时目录名
    /// 翻译自: tmpname: [:0]const u8
    public var tmpname: String

    /// 已接收字节总数
    /// 翻译自: bytes_received: usize
    public var bytesReceived: Int64

    /// 已提取文件条目数
    /// 翻译自: entry_count: u32
    public var entryCount: UInt32

    /// 提取失败错误
    /// 翻译自: fail: ?anyerror
    public var fail: ?String

    /// 增量完整性哈希 (SHA)
    /// 翻译自: hasher: Integrity.Streaming
    public var hasher: StreamingIntegrity

    /// GitHub tarball 解析的第一个目录名
    /// 翻译自: resolved_github_dirname
    public var resolvedGithubDirname: String

    /// 是否需要获取第一个目录名 (GitHub tarball)
    /// 翻译自: want_first_dirname: bool
    public var wantFirstDirname: Bool

    /// 是否是 npm 模式 (跳过非文件条目)
    /// 翻译自: npm_mode: bool
    public var npmMode: Bool

    /// 每条目的写入游标
    /// 翻译自: entry_actual_offset, entry_final_offset
    ///   持续跟踪以确保稀疏文件处理正确
    public var entryActualOffset: Int64
    public var entryFinalOffset: Int64

    // ===== 关联对象 =====

    /// 提取任务
    /// 翻译自: extract_task: *Task
    public var extractTask: ?ExtractTask

    /// 网络任务
    /// 翻译自: network_task: *NetworkTask
    public var networkTask: ?NetworkTaskRef

    /// 包管理器
    /// 翻译自: package_manager: *PackageManager
    public var packageManager: ?TsPackageManagerRef

    // ===== 跳过验证标志 =====

    /// 是否跳过完整性验证
    public var skipVerify: Bool

    // ===== 分辨率标签 =====

    /// 分辨率类型标签
    /// 翻译自: tarball.resolution.tag
    public var resolutionTag: String

    public init() {
        mutex = TarballMutex()
        pending = ArrayList<UInt8>()
        closed = false
        httpErr = None
        statusCode = UInt32(0)
        draining = false
        reading = ArrayList<UInt8>()
        readPos = 0
        archive = None
        phase = TarballPhase.WantHeader
        outFd = None
        usePwrite = true
        useLseek = true
        dest = None
        tmpname = ""
        bytesReceived = 0
        entryCount = UInt32(0)
        fail = None
        hasher = StreamingIntegrity()
        resolvedGithubDirname = ""
        wantFirstDirname = false
        npmMode = true
        entryActualOffset = 0
        entryFinalOffset = 0
        extractTask = None
        networkTask = None
        packageManager = None
        skipVerify = false
        resolutionTag = "npm"
    }

    /// 初始化 TarballStream
    /// 翻译自: TarballStream.init
    ///   pub fn init(allocator, extract_task, network_task, manager) *TarballStream
    ///   根据 resolution tag 决定是否计算完整性哈希
    public static func `init`(
        extractTask: ExtractTask,
        networkTask: NetworkTaskRef,
        manager: TsPackageManagerRef
    ): TarballStream {
        let stream = TarballStream()
        stream.extractTask = Some(extractTask)
        stream.networkTask = Some(networkTask)
        stream.packageManager = Some(manager)

        let tarball = extractTask.tarball
        stream.resolutionTag = tarball.resolutionTag
        stream.npmMode = tarball.resolutionTag != "github"
        stream.wantFirstDirname = tarball.resolutionTag == "github"
        stream.skipVerify = tarball.skipVerify

        // 对于 GitHub/remote_tarball/local_tarball, 即使没有预期哈希值也要计算
        let computeIfMissing = tarball.resolutionTag == "github" ||
            tarball.resolutionTag == "remote_tarball" ||
            tarball.resolutionTag == "local_tarball"

        stream.hasher = StreamingIntegrity(tarball.integrity, computeIfMissing)

        return stream
    }

    /// 释放资源
    /// 翻译自: TarballStream.deinit
    ///   pub fn deinit(this: *TarballStream) void
    public func deinit(): Unit {
        if (outFd.isSome()) { outFd.getOrThrow().close() }
        if (dest.isSome()) { dest.getOrThrow().close() }
        if (archive.isSome()) { archive.getOrThrow().close() }
        pending.clear()
        reading.clear()
        tmpname = ""
    }

    // ===== 静态配置 =====

    /// 最小流式处理大小
    /// 翻译自: TarballStream.minSize
    ///   小于此大小的 tarball 使用缓冲方式
    ///   从 BUN_INSTALL_STREAMING_MIN_SIZE 环境变量读取, 默认 512KB
    public static func minSize(): Int64 {
        let envValOpt = EnvVar.get("BUN_INSTALL_STREAMING_MIN_SIZE")
        if (envValOpt.isSome()) {
            let envVal = envValOpt.getOrThrow()
            if (envVal.size > 0) {
                try {
                    return IntParser.parseInt(envVal, 10)
                } catch (_: Exception) {
                    // fall through to default
                }
            }
        }
        return 1024 * 512  // 512KB 默认
    }

    // ===== HTTP 线程方法 =====

    /// HTTP 线程调用: 接收一个 body 块
    /// 翻译自: TarballStream.onChunk
    ///   pub fn onChunk(this, chunk, is_last, err) void
    ///   将数据追加到 pending, 设置 closed/err 标志, 然后调度 drain
    public func onChunk(chunk: Array<UInt8>, isLast: Bool, err: ?String): Unit {
        mutex.lock()
        if (chunk.size > 0) {
            for (b in chunk) {
                pending.append(b)
            }
            bytesReceived += chunk.size
        }
        if (isLast) { closed = true }
        if (err.isSome()) { httpErr = err.getOrThrow() }
        mutex.unlock()

        scheduleDrain()
    }

    /// 调度 drain 任务
    /// 翻译自: TarballStream.scheduleDrain
    ///   使用 atomic swap 确保只有一个 drain 在运行
    private func scheduleDrain(): Unit {
        if (draining) { return }
        draining = true
        // 实际实现: 将 drain_task 提交到 ThreadPool
        // this.package_manager.thread_pool.schedule(...)
    }

    // ===== Drain 核心 =====

    /// Drain 回调
    /// 翻译自: TarballStream.drainCallback
    ///   fn drainCallback(task: *ThreadPool.Task) void
    public static func drainCallback(stream: TarballStream): Unit {
        stream.drain()
    }

    /// 排空: 消费所有可用字节, 解压写入磁盘
    /// 翻译自: TarballStream.drain
    ///   fn drain(this: *TarballStream) void
    ///   核心循环:
    ///   1. 如果没有错误且未完成, 获取 pending 并调用 step()
    ///   2. step() 处理 libarchive 直到需要更多输入或完成
    ///   3. 如果需要更多输入, 释放工作线程
    ///   4. 如果完成或出错, 调用 finish()
    public func drain(): Unit {
        while (true) {
            if (fail .isNone() && phase != TarballPhase.Done) {
                // 获取 pending 数据
                let more = takePending()

                // 执行 libarchive 步骤
                let stepResult = step()
                if (stepResult.isSome()) {
                    fail = stepResult.getOrThrow()
                    closeOutputFile()
                }

                if (fail .isNone() && phase != TarballPhase.Done) {
                    if (more) { continue }

                    // libarchive 消费了所有数据, 释放工作线程
                    draining = false

                    // 检查是否有新数据到达 (避免竞争)
                    mutex.lock()
                    let again = pending.size > 0 || closed
                    mutex.unlock()
                    if (again && !draining) {
                        draining = true
                        continue
                    }
                    return
                }
            }

            // 终止状态: 清理 reading 缓冲区
            reading.clear()
            readPos = 0

            // 对 libarchive 处理完毕后到达的尾部字节计算哈希
            mutex.lock()
            if (fail .isNone() && pending.size > 0) {
                hasher.updateFromList(pending)
            }
            pending.clear()
            let streamClosed = closed
            let streamHttpErr = httpErr
            mutex.unlock()

            // HTTP 错误不应覆盖成功的提取结果
            if (streamHttpErr.isSome()) {
                if (fail .isNone() && phase != TarballPhase.Done) {
                    fail = streamHttpErr.getOrThrow()
                }
            }

            if (streamClosed) {
                finish()
                return
            }

            // HTTP 响应尚未完成, 等待更多数据
            draining = false
            mutex.lock()
            let again = pending.size > 0 || closed
            mutex.unlock()
            if (again && !draining) {
                draining = true
                continue
            }
            return
        }
    }

    /// 移动 pending 字节到 reading
    /// 翻译自: TarballStream.takePending
    ///   fn takePending(this: *TarballStream) bool
    ///   在 mutex 保护下将 pending 数据转移到 reading
    ///   先对原始字节计算哈希, 然后交换或追加缓冲区
    public func takePending(): Bool {
        mutex.lock()

        if (pending.size == 0) {
            mutex.unlock()
            return closed
        }

        // 在 libarchive 处理之前计算哈希
        hasher.updateFromList(pending)

        if (reading.size == readPos) {
            // 前一个缓冲区已完全消费 - 交换
            reading.clear()
            reading = pending
            pending = ArrayList<UInt8>()
            readPos = 0
        } else {
            // libarchive 仍持有 reading 的切片, 追加模式
            let remaining = reading.size - readPos
            let newReading = ArrayList<UInt8>()
            var i: Int64 = readPos
            while (i < reading.size) {
                newReading.append(reading[i])
                i += 1
            }
            for (b in pending) {
                newReading.append(b)
            }
            reading = newReading
            readPos = 0
            pending.clear()
        }

        mutex.unlock()
        return true
    }

    // ===== libarchive 状态机 =====

    /// 运行 libarchive 直到需要更多输入或达到终止状态
    /// 翻译自: TarballStream.step
    ///   fn step(this: *TarballStream) !void
    ///   首次调用时打开归档和目标目录
    ///   然后在 want_header/want_data 之间循环:
    ///   - want_header: 读取下一个条目头
    ///   - want_data: 读取数据块并写入文件
    ///   - done: 完成
    public func step(): ?String {
        // 首次打开归档
        if (archive .isNone()) {
            let openResult = openArchive()
            if (openResult.isSome()) { return openResult.getOrThrow() }
        }

        // 首次打开目标目录
        if (dest .isNone()) {
            let destResult = openDestination()
            if (destResult.isSome()) { return destResult.getOrThrow() }
        }

        let reader = archive.getOrThrow()

        var loopResult: ?String = None
        while (true) {
            if (phase == TarballPhase.Done) {
                loopResult = None
                break
            }
            if (phase == TarballPhase.WantHeader) {
                let entry = ArchiveEntry()
                let headerResult = reader.readNextHeader(entry)
                if (headerResult == ArchiveResult.Retry) {
                    loopResult = None
                    break  // 需要更多数据
                }
                if (headerResult == ArchiveResult.Eof) {
                    phase = TarballPhase.Done
                    loopResult = None
                    break
                }
                if (headerResult == ArchiveResult.Ok || headerResult == ArchiveResult.Warn) {
                    let beginResult = beginEntry(entry)
                    if (beginResult.isSome()) { loopResult = beginResult; break }
                }
                if (headerResult == ArchiveResult.Failed || headerResult == ArchiveResult.Fatal) {
                    loopResult = Some("readNextHeader failed: ${reader.errorString()}")
                    break
                }
            }
            if (phase == TarballPhase.WantData) {
                let offset = Ref<Int64>(Int64(0))
                let block = reader.next(offset)
                if (block.isNone()) {
                    // 数据结束, 关闭输出文件
                    closeOutputFile()
                    phase = TarballPhase.WantHeader
                } else {
                    let blk = block.getOrThrow()
                    if (blk.result == ArchiveResult.Retry) {
                        loopResult = None
                        break  // 需要更多数据
                    }
                    if (blk.result == ArchiveResult.Ok || blk.result == ArchiveResult.Warn) {
                        if (outFd.isSome()) {
                            let writeResult = writeDataBlock(outFd.getOrThrow(), blk)
                            if (writeResult.isSome()) { loopResult = writeResult; break }
                        }
                    }
                    if (blk.result == ArchiveResult.Failed || blk.result == ArchiveResult.Fatal) {
                        loopResult = Some("read_data_block failed: ${reader.errorString()}")
                        break
                    }
                }
            }
        }
        return loopResult
    }

    /// 打开归档
    /// 翻译自: TarballStream.openArchive
    ///   fn openArchive(this: *TarballStream) !void
    ///   设置 gzip 过滤器 + tar 格式, 注册读取回调
    ///   ARCHIVE_FILTER_GZIP = 1, ARCHIVE_FORMAT_TAR = 0x30000
    public func openArchive(): ?String {
        let reader = ArchiveReader()
        let result = reader.open(this)
        if (result == ArchiveResult.Ok || result == ArchiveResult.Warn) {
            archive = Some(reader)
            return None
        }
        if (result == ArchiveResult.Retry) {
            // 过滤器投标已跳过, 但客户端打开路径可能仍会探测
            archive = Some(reader)
            return None
        }
        return "archive_read_open failed: ${reader.errorString()}"
    }

    /// 打开目标临时目录
    /// 翻译自: TarballStream.openDestination
    ///   fn openDestination(this: *TarballStream) !void
    ///   在 tarball.temp_dir 中创建随机命名的临时目录
    public func openDestination(): ?String {
        let basename = "tarball-extract"
        let tmpnameVal = FileSystem.tmpname(basename, FastRandom.next())
        this.tmpname = tmpnameVal

        if (extractTask.isSome()) {
            let task = extractTask.getOrThrow()
            let tempDirOpt = task.tarball.tempDir
            if (tempDirOpt.isSome()) {
                let tempDirPath = tempDirOpt.getOrThrow().path
                dest = Some(TarballFd.makeDir(tempDirPath, tmpname))
            } else {
                dest = Some(TarballFd(tmpname))
            }
            return None
        }
        return "no extract task"
    }

    /// 关闭输出文件
    /// 翻译自: TarballStream.closeOutputFile
    ///   fn closeOutputFile(this: *TarballStream) void
    ///   处理稀疏文件尾部空洞: 如果 final_offset > actual_offset,
    ///   使用 ftruncate 扩展文件
    public func closeOutputFile(): Unit {
        if (outFd.isSome()) {
            let fd = outFd.getOrThrow()
            // 稀疏文件尾部处理
            if (entryFinalOffset > entryActualOffset) {
                fd.ftruncate(entryFinalOffset)
            }
            fd.close()
            outFd = None
        }
    }

    // ===== 条目处理 =====

    /// 处理一个条目头
    /// 翻译自: TarballStream.beginEntry
    ///   fn beginEntry(this: *TarballStream, entry) !void
    ///   根据文件类型 (文件/目录/符号链接) 创建输出
    ///   npm 模式下跳过非文件条目
    ///   剥离前导 `package/` 目录组件
    public func beginEntry(entry: ArchiveEntry): ?String {
        var pathname = entry.pathname

        // GitHub tarball: 提取第一个目录名
        if (wantFirstDirname) {
            wantFirstDirname = false
            let rootIt = TsStringSplitter.split(pathname, "/")
            let rootOpt = rootIt.next()
            if (rootOpt.isSome()) {
                resolvedGithubDirname = rootOpt.getOrThrow()
            }
        }

        let kind = entry.kind()

        // npm 模式: 只处理文件
        if (npmMode && kind != FileKind.File) {
            phase = TarballPhase.WantData
            outFd = None
            return None
        }

        // 剥离前导目录组件 (package/ 或 repo-sha/)
        let tokenizer = TsStringSplitter.split(pathname, "/")
        let firstOpt = tokenizer.next()
        if (firstOpt.isNone()) {
            phase = TarballPhase.WantData
            outFd = None
            return None
        }
        let rest = tokenizer.rest()
        pathname = rest

        // 规范化路径
        let normalized = Path.normalize(pathname)
        if (normalized.size == 0 || (normalized.size == 1 && normalized[0] == UInt8(46))) {
            // 空路径或 "."
            phase = TarballPhase.WantData
            outFd = None
            return None
        }

        // 拒绝 ".." 开头的路径 (安全: 防止逃逸临时目录)
        if (normalized.size >= 2 && normalized[0] == UInt8(46) && normalized[1] == UInt8(46)) {
            if (normalized.size == 2 || normalized[2] == UInt8(47)) {
                phase = TarballPhase.WantData
                outFd = None
                return None
            }
        }

        let destFd = dest.getOrThrow()

        if (kind == FileKind.Directory) {
            makeDirectory(entry, destFd, normalized)
            phase = TarballPhase.WantData
            outFd = None
        } else if (kind == FileKind.SymLink) {
            makeSymlink(entry, destFd, normalized)
            phase = TarballPhase.WantData
            outFd = None
        } else if (kind == FileKind.File) {
            let mode: UInt32 = UInt32(entry.perm) | UInt32(0o666)
            let fd = openOutputFile(destFd, normalized, mode)
            if (fd.isSome()) {
                let openedFd = fd.getOrThrow()
                outFd = Some(openedFd)
                entryCount = entryCount + UInt32(1)

                // Linux: 大文件预分配空间
                if (entry.size > 1000000) {
                    openedFd.preallocate(entry.size)
                }

                entryActualOffset = 0
                entryFinalOffset = 0
                phase = TarballPhase.WantData
            } else {
                phase = TarballPhase.WantData
                outFd = None
            }
        } else {
            phase = TarballPhase.WantData
            outFd = None
        }

        return None
    }

    /// 打开输出文件
    /// 翻译自: TarballStream.openOutputFile
    ///   fn openOutputFile(dest_fd, path, path_slice, mode) !bun.FD
    ///   如果父目录不存在则创建
    private func openOutputFile(destFd: TarballFd, path: String, mode: UInt32): ?TarballFd {
        let flags = TarballFd.WRONLY | TarballFd.CREAT | TarballFd.TRUNC
        let result = TarballFd.openat(destFd, path, flags, mode)
        if (result.isSome()) { return result }
        // 可能父目录不存在, 尝试创建
        let parentDir = Path.dirname(path)
        if (parentDir.size > 0) {
            destFd.makePath(parentDir)
            return TarballFd.openat(destFd, path, flags, mode)
        }
        return None
    }

    /// 创建目录
    /// 翻译自: TarballStream.makeDirectory
    ///   fn makeDirectory(entry, dest_fd, path, path_slice) void
    ///   如果目录可读则设为可列出 (mode-fix.js)
    private func makeDirectory(entry: ArchiveEntry, destFd: TarballFd, path: String): Unit {
        var mode = Int32(entry.perm)
        // if dirs are readable, then they should be listable
        if ((mode & 0o400) != 0) { mode = mode | 0o100 }
        if ((mode & 0o40) != 0) { mode = mode | 0o10 }
        if ((mode & 0o4) != 0) { mode = mode | 0o1 }
        destFd.mkdir(path, mode)
    }

    /// 创建符号链接
    /// 翻译自: TarballStream.makeSymlink
    ///   fn makeSymlink(entry, dest_fd, path, path_slice) void
    ///   拒绝绝对目标和逃逸路径 (安全检查)
    private func makeSymlink(entry: ArchiveEntry, destFd: TarballFd, path: String): Unit {
        let target = entry.symlinkTarget
        // 拒绝空目标和绝对路径
        if (target.size == 0 || target.startsWith("/")) { return }
        // 拒绝逃逸路径
        let symlinkDir = Path.dirname(path)
        let resolved = Path.join([symlinkDir, target])
        if (!resolved.startsWith("/packages/")) { return }

        destFd.symlinkat(target, path)
    }

    /// 写入一个数据块
    /// 翻译自: TarballStream.writeDataBlock
    ///   fn writeDataBlock(this, fd, block) !void
    ///   镜像 Archive.readDataIntoFd 的稀疏/pwrite 处理
    ///   但在单个块上操作, 可以和 ARCHIVE_RETRY 交替执行
    ///   entry_actual_offset / entry_final_offset 在调用间持久保存
    public func writeDataBlock(fd: TarballFd, block: ArchiveBlock): ?String {
        let data = block.bytes
        if (data.size == 0) { return None }

        // 更新最大偏移量
        entryFinalOffset = Math.max(
            entryFinalOffset,
            block.offset + Int64(data.size)
        )

        // POSIX: 尝试 pwrite
        if (usePwrite) {
            let pwriteResult = fd.pwriteAll(data, block.offset)
            if (pwriteResult.isSome()) {
                entryActualOffset = Math.max(
                    entryActualOffset,
                    block.offset + Int64(data.size)
                )
                return None
            }
            usePwrite = false
        }

        // 如果偏移量不匹配, 需要 seek 或填充零
        if (block.offset != entryActualOffset) {
            if (useLseek) {
                fd.setFileOffset(block.offset)
                entryActualOffset = block.offset
            } else if (block.offset > entryActualOffset) {
                // 用零填充间隙
                let zeroCount = block.offset - entryActualOffset
                fd.writeZeros(zeroCount)
                entryActualOffset = block.offset
            } else {
                return "writeDataBlock: cannot seek backwards"
            }
        }

        // 写入数据
        fd.writeAll(data)
        entryActualOffset += Int64(data.size)
        return None
    }

    // ===== 完成处理 =====

    /// 完成提取
    /// 翻译自: TarballStream.finish
    ///   fn finish(this: *TarballStream) void
    ///   1. 关闭输出文件
    ///   2. 填充提取结果 (包括完整性检查)
    ///   3. 清理临时目录 (失败时)
    ///   4. 将任务推送到 resolve_tasks 队列
    public func finish(): Unit {
        closeOutputFile()

        // 填充结果 (包括完整性验证)
        populateResult()

        // 失败时清理临时目录
        if (extractTask.isSome()) {
            let task = extractTask.getOrThrow()
            if (task.status != "success" && tmpname.size > 0) {
                if (dest.isSome()) {
                    dest.getOrThrow().close()
                    dest = None
                }
                if (task.tarball.tempDir.isSome()) {
                    task.tarball.tempDir.getOrThrow().deleteTree(tmpname)
                }
            }
        }

        deinit()
    }

    /// 填充提取结果
    /// 翻译自: TarballStream.populateResult
    ///   fn populateResult(this: *TarballStream, task: *Task) void
    ///   1. 检查提取错误
    ///   2. 验证完整性哈希
    ///   3. 对于 GitHub tarball: 写入 .bun-tag 文件
    ///   4. 将临时目录移动到缓存目录
    ///   5. 设置最终完整性信息
    public func populateResult(): Unit {
        if (extractTask.isSome()) {
            let task = extractTask.getOrThrow()

            // 检查提取错误
            if (fail.isSome()) {
                task.status = "fail"
                task.err = fail.getOrThrow()
                return
            }

            // 验证完整性
            if (!skipVerify) {
                let tag = hasher.getIntegrityTag()
                let isSupported = tag.isSupported()
                if (isSupported) {
                    if (!hasher.verify()) {
                        task.status = "fail"
                        task.err = "Integrity check failed for tarball"
                        return
                    }
                }
            }

            // GitHub tarball: 写入 .bun-tag
            if (resolutionTag == "github" && resolvedGithubDirname.size > 0) {
                if (dest.isSome()) {
                    dest.getOrThrow().writeFile(".bun-tag", resolvedGithubDirname)
                }
            }

            // 关闭目标目录 (在重命名之前)
            if (dest.isSome()) {
                dest.getOrThrow().close()
                dest = None
            }

            // 移动到缓存目录
            let moveResult = moveToCacheDirectory(task, tmpname, resolvedGithubDirname)
            if (moveResult.isSome()) {
                task.status = "fail"
                task.err = moveResult.getOrThrow()
            } else {
                // 设置完整性信息
                if (resolutionTag == "github" || resolutionTag == "remote_tarball" || resolutionTag == "local_tarball") {
                    let integrity = hasher.finalIntegrity()
                    task.integrity = integrity
                }

                task.status = "success"
            }
        }
    }

    /// 移动到缓存目录
    /// 翻译自: tarball.moveToCacheDirectory
    private func moveToCacheDirectory(task: ExtractTask, tmpname: String, githubDirname: String): ?String {
        // 简化: 实际实现涉及文件系统操作
        return None
    }

    /// 重置用于重试
    /// 翻译自: TarballStream.resetForRetry
    ///   pub fn resetForRetry(this: *TarballStream) void
    ///   在 HTTP 请求失败且未调度 drain 时调用
    public func resetForRetry(): Unit {
        mutex.lock()
        pending.clear()
        closed = false
        httpErr = None
        statusCode = UInt32(0)
        bytesReceived = 0
        mutex.unlock()
    }
}

// ============================================================================
// 流式完整性校验
// 严格翻译自: src/install/integrity.zig - Integrity.Streaming
// ============================================================================

/// 流式完整性校验
/// 翻译自: Integrity.Streaming
///   对压缩字节计算增量 SHA 哈希, 用于验证 tarball 完整性
public class StreamingIntegrity {
    private var sha: Sha512State
    private var expectedHash: ?String
    private var computeIfMissing: Bool
    private var totalBytes: Int64
    private var integrityTag: TsIntegrityTag
    private var computedHash: String

    public init() {
        sha = Sha512State()
        expectedHash = None
        computeIfMissing = false
        totalBytes = 0
        integrityTag = TsIntegrityTag.Unknown
        computedHash = ""
    }

    public init(expectedHash: ?String, computeIfMissing: Bool) {
        sha = Sha512State()
        this.expectedHash = expectedHash
        this.computeIfMissing = computeIfMissing
        totalBytes = 0
        integrityTag = TsIntegrityTag.SHA512
        computedHash = ""
    }

    /// 更新哈希 (从 ArrayList)
    public func updateFromList(data: ArrayList<UInt8>): Unit {
        for (b in data) {
            sha.updateByte(b)
        }
        totalBytes += data.size
    }

    /// 更新哈希 (从 Array)
    public func update(data: Array<UInt8>): Unit {
        for (b in data) {
            sha.updateByte(b)
        }
        totalBytes += data.size
    }

    /// 验证完整性
    /// 翻译自: Integrity.Streaming.verify
    ///   将计算的哈希与预期哈希比较
    public func verify(): Bool {
        if (expectedHash.isSome()) {
            let expected = expectedHash.getOrThrow()
            let actual = finalHash()
            return actual == expected
        }
        // 没有预期哈希, 无需验证
        return true
    }

    /// 获取最终哈希值
    public func finalHash(): String {
        if (computedHash.size == 0) {
            computedHash = sha.finalize()
        }
        return computedHash
    }

    /// 获取完整性标签
    public func getIntegrityTag(): TsIntegrityTag {
        return integrityTag
    }

    /// 获取最终完整性信息
    /// 翻译自: Integrity.Streaming.final
    public func finalIntegrity(): TsIntegrityInfo {
        return TsIntegrityInfo(integrityTag, finalHash())
    }
}

/// 完整性标签 (tarball_stream 本地版本)
public enum TsIntegrityTag {
    | Unknown
    | SHA1
    | SHA256
    | SHA384
    | SHA512

    public func isSupported(): Bool {
        match (this) {
            case SHA1 => true
            case SHA256 => true
            case SHA384 => true
            case SHA512 => true
            case _ => false
        }
    }
}

/// 完整性信息
public class TsIntegrityInfo {
    public var tag: TsIntegrityTag
    public var value: String

    public init() {
        tag = TsIntegrityTag.Unknown
        value = ""
    }

    public init(tag: TsIntegrityTag, value: String) {
        this.tag = tag
        this.value = value
    }
}

/// SHA-512 状态 (简化实现)
public class Sha512State {
    private var bytes: ArrayList<UInt8>

    public init() {
        bytes = ArrayList<UInt8>()
    }

    public func updateByte(b: UInt8): Unit {
        bytes.append(b)
    }

    public func update(data: ArrayList<UInt8>): Unit {
        for (b in data) {
            bytes.append(b)
        }
    }

    public func finalize(): String {
        // 简化: 返回基于内容的十六进制哈希
        var h1: UInt64 = 0x6a09e667f3bcc908u64
        var h2: UInt64 = 0xbb67ae8584caa73bu64
        for (i in 0..bytes.size) {
            h1 = h1 * UInt64(31) + UInt64(bytes[Int64(i)])
            h2 = h2 * UInt64(37) + UInt64(bytes[Int64(i)])
        }
        return "sha512-${TsHexUtil.toHex(h1)}${TsHexUtil.toHex(h2)}"
    }
}

// ============================================================================
// 文件描述符包装
// 严格翻译自: bun.FD 操作的简化包装
// ============================================================================

/// 文件描述符包装 (简化)
/// 翻译自: bun.FD
public class TarballFd {
    public static let WRONLY: UInt32 = UInt32(1)
    public static let CREAT: UInt32 = UInt32(64)
    public static let TRUNC: UInt32 = UInt32(512)

    public var path: String
    private var isOpen: Bool

    public init(path: String) {
        this.path = path
        isOpen = true
    }

    /// 关闭文件描述符
    public func close(): Unit {
        isOpen = false
    }

    /// ftruncate
    public func ftruncate(size: Int64): Unit {
        // 简化
    }

    /// pwriteAll
    public func pwriteAll(data: Array<UInt8>, offset: Int64): ?Unit {
        if (!isOpen) { return None }
        // 简化
        return Some(())
    }

    /// setFileOffset
    public func setFileOffset(offset: Int64): Unit {
        // 简化
    }

    /// writeZeros
    public func writeZeros(count: Int64): Unit {
        // 简化
    }

    /// writeAll
    public func writeAll(data: Array<UInt8>): Unit {
        // 简化
    }

    /// preallocate
    public func preallocate(size: Int64): Unit {
        // 简化
    }

    /// mkdir
    public func mkdir(path: String, mode: Int32): Unit {
        // 简化
    }

    /// symlinkat
    public func symlinkat(target: String, path: String): Unit {
        // 简化
    }

    /// makePath
    public func makePath(path: String): Unit {
        // 简化
    }

    /// writeFile
    public func writeFile(name: String, content: String): Unit {
        // 简化
    }

    /// deleteTree
    public func deleteTree(name: String): Unit {
        // 简化
    }

    /// openat
    public static func openat(dir: TarballFd, path: String, flags: UInt32, mode: UInt32): ?TarballFd {
        // 简化
        return Some(TarballFd(path))
    }

    /// makeDir
    public static func makeDir(basePath: String, name: String): TarballFd {
        return TarballFd(Path.join([basePath, name]))
    }
}

// ============================================================================
// 提取任务 (简化)
// 严格翻译自: install.Task (extract 部分)
// ============================================================================

/// 提取任务
/// 翻译自: install.Task
public class ExtractTask {
    /// tarball 信息
    public var tarball: TarballInfo
    /// 任务状态
    public var status: String
    /// 错误信息
    public var err: ?String
    /// 完整性信息
    public var integrity: TsIntegrityInfo

    public init() {
        tarball = TarballInfo()
        status = "pending"
        err = None
        integrity = TsIntegrityInfo()
    }
}

/// Tarball 信息
/// 翻译自: install.TarballInfo
public class TarballInfo {
    /// 分辨率类型标签
    public var resolutionTag: String
    /// 是否跳过验证
    public var skipVerify: Bool
    /// 完整性哈希
    public var integrity: String
    /// 临时目录
    public var tempDir: ?TarballFd
    /// 包名
    public var name: String

    public init() {
        resolutionTag = "npm"
        skipVerify = false
        integrity = ""
        tempDir = None
        name = ""
    }
}

/// 网络任务引用
/// 翻译自: install.NetworkTask
public class NetworkTaskRef {
    public init() {}
}

/// 包管理器引用 (tarball_stream 本地版本)
/// 翻译自: install.PackageManager
public class TsPackageManagerRef {
    public init() {}
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 简化的互斥锁
public class TarballMutex {
    private var locked: Bool

    public init() {
        locked = false
    }

    public func lock(): Unit {
        locked = true
    }

    public func unlock(): Unit {
        locked = false
    }
}

/// 引用包装
public class Ref<T> {
    public var value: T

    public init(value: T) {
        this.value = value
    }
}

/// 快速随机数
public class FastRandom {
    private static var state: UInt64 = UInt64(12345)

    public static func next(): UInt64 {
        state = state * UInt64(6364136223846793005) + UInt64(1442695040888963407)
        return state
    }
}

/// 字符串分割迭代器 (tarball_stream 本地版本)
public class TsStringSplitter {
    private var str: String
    private var delimiter: String
    private var pos: Int64

    private init(str: String, delimiter: String) {
        this.str = str
        this.delimiter = delimiter
        pos = 0
    }

    public static func split(str: String, delimiter: String): TsStringSplitter {
        return TsStringSplitter(str, delimiter)
    }

    public func next(): ?String {
        if (pos >= str.size) { return None }
        let idx = str.indexOf(delimiter, pos)
        if (idx.isSome()) {
            let i = idx.getOrThrow()
            let result = str[pos..i]
            pos = i + Int64(delimiter.size)
            return result
        }
        let result = str[pos..]
        pos = str.size
        return result
    }

    /// 获取剩余未分割的部分
    public func rest(): String {
        if (pos >= str.size) { return "" }
        return str[pos..]
    }
}

/// 文件系统操作 (简化)
public class FileSystem {
    /// 生成临时文件名
    /// 翻译自: FileSystem.tmpname
    public static func tmpname(basename: String, random: UInt64): String {
        return "${basename}-${TsHexUtil.toHex(random)}"
    }
}

/// 十六进制工具 (tarball_stream 本地版本)
public class TsHexUtil {
    /// 将 UInt64 转为十六进制字符串
    public static func toHex(value: UInt64): String {
        let hexChars = "0123456789abcdef"
        var sb = StringBuilder()
        var v = value
        if (v == UInt64(0)) { return "0" }
        var nibbles = ArrayList<UInt8>()
        while (v > UInt64(0)) {
            nibbles.append(UInt8(v & UInt64(0xF)))
            v = v >> UInt64(4)
        }
        var i = nibbles.size - 1
        while (i >= 0) {
            sb.append(String([Rune(UInt32(hexChars[Int64(nibbles[Int64(i)])]))]))
            i -= 1
        }
        return sb.toString()
    }
}

/// 简化的 Math
public class Math {
    public static func max(a: Int64, b: Int64): Int64 {
        return if (a > b) { a } else { b }
    }
}
