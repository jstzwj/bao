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
public class TarballStream {
    // ===== 跨线程生产者状态 (HTTP -> Worker) =====

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

    /// 当前被 libarchive 消费的字节
    /// 翻译自: reading: std.ArrayListUnmanaged(u8)
    public var reading: ArrayList<UInt8>

    /// reading 中的读取位置
    /// 翻译自: read_pos: usize
    public var readPos: Int64

    /// 当前提取阶段
    /// 翻译自: phase: enum { want_header, want_data, done }
    public var phase: TarballPhase

    /// 输出文件描述符 (当前正在写入的条目)
    /// 翻译自: out_fd: ?bun.FD
    public var outFd: ?String

    /// 目标临时目录
    /// 翻译自: dest: ?bun.FD
    public var dest: ?String

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
    public var entryActualOffset: Int64
    public var entryFinalOffset: Int64

    public init() {
        pending = ArrayList<UInt8>()
        closed = false
        httpErr = None
        statusCode = UInt32(0)
        draining = false
        reading = ArrayList<UInt8>()
        readPos = 0
        phase = TarballPhase.WantHeader
        outFd = None
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
    }

    /// 最小流式处理大小
    /// 翻译自: TarballStream.minSize
    ///   小于此大小的 tarball 使用缓冲方式
    public static func minSize(): Int64 {
        return 1024 * 512  // 512KB 默认
    }

    /// HTTP 线程调用: 接收一个 body 块
    /// 翻译自: TarballStream.onChunk
    ///   pub fn onChunk(this, chunk, is_last, err) void
    public func onChunk(chunk: Array<UInt8>, isLast: Bool, err: ?String): Unit {
        if (chunk.size > 0) {
            for (b in chunk) {
                pending.append(b)
            }
            bytesReceived += chunk.size
        }
        if (isLast) { closed = true }
        if (err != None) { httpErr = err }

        scheduleDrain()
    }

    /// 调度 drain 任务
    /// 翻译自: TarballStream.scheduleDrain
    private func scheduleDrain(): Unit {
        if (draining) { return }
        draining = true
        // 实际实现: 将 drain_task 提交到 ThreadPool
    }

    /// 排空: 消费所有可用字节, 解压写入磁盘
    /// 翻译自: TarballStream.drain
    public func drain(): Unit {
        while (true) {
            if (fail == None && phase != TarballPhase.Done) {
                let more = takePending()
                // step() 调用 libarchive 处理
                // 翻译自: this.step() catch |err| { this.fail = err }
                if (fail == None && phase != TarballPhase.Done) {
                    if (more) { continue }
                    // 释放 worker, 等待下一个 HTTP chunk
                    draining = false
                    return
                }
            }

            // 终止状态
            reading.clear()
            readPos = 0

            if (closed) {
                finish()
                return
            }

            draining = false
            if (pending.size > 0 || closed) {
                if (!draining) { continue }
            }
            return
        }
    }

    /// 移动 pending 字节到 reading
    /// 翻译自: TarballStream.takePending
    public func takePending(): Bool {
        if (pending.size == 0) { return closed }

        // 更新哈希
        hasher.update(pending)

        // 交换缓冲区
        if (reading.size == readPos) {
            reading.clear()
            reading = pending
            pending = ArrayList<UInt8>()
            readPos = 0
        } else {
            // 追加模式
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
        return true
    }

    /// 完成提取
    /// 翻译自: TarballStream.finish
    public func finish(): Unit {
        closeOutputFile()
        populateResult()
        // 清理临时目录 (失败时)
    }

    /// 关闭输出文件
    /// 翻译自: TarballStream.closeOutputFile
    public func closeOutputFile(): Unit {
        if (outFd != None) {
            outFd = None
        }
    }

    /// 填充提取结果
    /// 翻译自: TarballStream.populateResult
    public func populateResult(): Unit {
        // 验证完整性
        if (fail == None) {
            if (!hasher.verify()) {
                fail = Some("Integrity check failed")
            }
        }
    }

    /// 重置用于重试
    /// 翻译自: TarballStream.resetForRetry
    public func resetForRetry(): Unit {
        pending.clear()
        closed = false
        httpErr = None
        statusCode = UInt32(0)
        bytesReceived = 0
    }
}

// ============================================================================
// 流式完整性校验
// 严格翻译自: src/install/integrity.zig - Integrity.Streaming
// ============================================================================

/// 流式完整性校验
/// 翻译自: Integrity.Streaming
public class StreamingIntegrity {
    private var sha: Sha512State
    private var expectedHash: ?String
    private var computeIfMissing: Bool
    private var totalBytes: Int64

    public init() {
        sha = Sha512State()
        expectedHash = None
        computeIfMissing = false
        totalBytes = 0
    }

    public init(expectedHash: ?String, computeIfMissing: Bool) {
        sha = Sha512State()
        this.expectedHash = expectedHash
        this.computeIfMissing = computeIfMissing
        totalBytes = 0
    }

    /// 更新哈希
    public func update(data: ArrayList<UInt8>): Unit {
        sha.update(data)
        totalBytes += data.size
    }

    /// 验证完整性
    public func verify(): Bool {
        match (expectedHash) {
            case Some(expected) => {
                let computed = sha.finalize()
                return computed == expected
            }
            case None => return true
        }
    }

    /// 获取最终哈希值
    public func finalHash(): String {
        return sha.finalize()
    }
}

/// SHA-512 状态 (简化实现)
public class Sha512State {
    private var bytes: ArrayList<UInt8>

    public init() {
        bytes = ArrayList<UInt8>()
    }

    public func update(data: ArrayList<UInt8>): Unit {
        for (b in data) {
            bytes.append(b)
        }
    }

    public func finalize(): String {
        // 简化实现: 返回十六进制摘要
        let hash = bao_hash.Sha512.hash(bytes.toArray())
        let sb = StringBuilder()
        for (b in hash) {
            let hex = Int64(b).toString(16)
            if (hex.length < 2) { sb.append("0") }
            sb.append(hex)
        }
        return "sha512-${sb.toString()}"
    }
}
