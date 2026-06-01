// 严格翻译自: src/runtime/cli/test/parallel/Frame.zig
//   Wire protocol over the fd-3 IPC channel: length-prefixed binary frames.
//     [u32 LE payload_len][u8 kind][payload]
//   Strings within a payload are [u32 LE len][bytes].
package bao_runtime.test_runner

import bao_core.*
import bao_collections.*

// ============================================================================
// FrameKind — IPC 帧类型
// 严格翻译自: src/runtime/cli/test/parallel/Frame.zig - Kind enum(u8)
// ============================================================================

/// IPC 帧类型
/// 对应 Bun: Frame.Kind enum(u8)
public enum FrameKind {
    // worker -> coordinator
    | ready            // (空) Worker 就绪
    | fileStart        // u32 file_idx — 开始处理文件
    | testDone         // u32 file_idx, str formatted_line — 单个测试完成
    | fileDone         // 9 x u32: file_idx, pass, fail, skip, todo, expectations, skipped_label, files, unhandled
    | repeatBufs       // 3 x str: failures, skips, todos (逐字重复缓冲)
    | junitFile        // str path — JUnit 报告文件
    | coverageFile     // str path — 覆盖率文件
    // coordinator -> worker
    | run              // u32 file_idx, str path — 运行指定文件
    | shutdown         // (空) 关闭 Worker

    public operator func ==(right: FrameKind): Bool {
        return this == right
    }

    public func toUInt8(): UInt8 {
        match (this) {
            case FrameKind.ready => UInt8(0)
            case FrameKind.fileStart => UInt8(1)
            case FrameKind.testDone => UInt8(2)
            case FrameKind.fileDone => UInt8(3)
            case FrameKind.repeatBufs => UInt8(4)
            case FrameKind.junitFile => UInt8(5)
            case FrameKind.coverageFile => UInt8(6)
            case FrameKind.run => UInt8(7)
            case FrameKind.shutdown => UInt8(8)
        }
    }

    public operator func !=(right: FrameKind): Bool {
        return !(this == right)
    }
}

// ============================================================================
// Frame — IPC 帧
// 严格翻译自: src/runtime/cli/test/parallel/Frame.zig - Frame struct
//
/// Upper bound on a single IPC frame payload. The protocol is internal but
/// fd 3 is reachable from test JS via `fs.writeSync(3, ...)`; rejecting
/// nonsensical lengths up-front prevents both a `5 + len` u32 overflow and
/// an unbounded allocation.
// ============================================================================

/// 单帧 payload 上限 (64 MB)
/// 翻译自: pub const max_payload: u32 = 64 * 1024 * 1024
public let FRAME_MAX_PAYLOAD: UInt32 = UInt32(64) * UInt32(1024) * UInt32(1024)

/// IPC 帧 — 长度前缀二进制编解码器
/// 对应 Bun: Frame struct
/// 帧先构建到可复用缓冲区, 然后在单次写入中刷出, 以避免对端看到撕裂的头部
public class Frame {
    /// 帧缓冲区
    /// 翻译自: buf: std.ArrayListUnmanaged(u8) = .empty
    public var buf: ArrayList<UInt8>

    public init() {
        buf = ArrayList<UInt8>()
    }

    /// 开始构建新帧
    /// 翻译自: pub fn begin(self: *Frame, kind: Kind) void
    /// 保留 4 字节头部 (payload_len 在 finish() 中填充)
    public func begin(kind: FrameKind): Unit {
        buf.clear()
        // 保留头部: [u32 LE payload_len] — 在 finish() 中填充
        for (_ in 0..Int64(4)) {
            buf.append(UInt8(0))
        }
        // 写入 kind 字节
        buf.append(kind.toUInt8())
    }

    /// 写入 u32 值 (小端序)
    /// 翻译自: pub fn u32_(self: *Frame, v: u32) void
    public func writeU32(v: UInt32): Unit {
        buf.append(UInt8(v & UInt32(0xFF)))
        buf.append(UInt8((v >> UInt32(8)) & UInt32(0xFF)))
        buf.append(UInt8((v >> UInt32(16)) & UInt32(0xFF)))
        buf.append(UInt8((v >> UInt32(24)) & UInt32(0xFF)))
    }

    /// 写入字符串 (带长度前缀)
    /// 翻译自: pub fn str(self: *Frame, s: []const u8) void
    /// 如果字符串过长会被截断, 附加截断提示
    public func writeStr(s: String): Unit {
        // 截断提示
        let trunc = "\n... [output truncated: would exceed --parallel IPC frame limit]\n"
        let headroom: Int64 = 256
        let used: Int64 = (buf.size - 5) + 4  // 当前 payload + str-len 前缀
        let room: Int64 = if (Int64(FRAME_MAX_PAYLOAD) > used + headroom) {
            Int64(FRAME_MAX_PAYLOAD) - used - headroom
        } else {
            Int64(0)
        }

        if (s.size <= room) {
            writeU32(UInt32(s.size))
            for (i in 0..s.size) {
                buf.append(UInt8(s[Int64(i)]))
            }
            return
        }

        let keep: Int64 = if (room > trunc.size) { room - trunc.size } else { Int64(0) }
        writeU32(UInt32(keep + trunc.size))
        for (i in 0..keep) {
            buf.append(UInt8(s[Int64(i)]))
        }
        for (i in 0..trunc.size) {
            buf.append(UInt8(trunc[Int64(i)]))
        }
    }

    /// 完成帧构建: 填充头部长度并返回编码字节
    /// 翻译自: pub fn finish(self: *Frame) []const u8
    public func finish(): ArrayList<UInt8> {
        let payloadLen: UInt32 = UInt32(buf.size - 4)
        // 写入 payload_len 到头部 (小端序)
        buf[Int64(0)] = UInt8(payloadLen & UInt32(0xFF))
        buf[Int64(1)] = UInt8((payloadLen >> UInt32(8)) & UInt32(0xFF))
        buf[Int64(2)] = UInt8((payloadLen >> UInt32(16)) & UInt32(0xFF))
        buf[Int64(3)] = UInt8((payloadLen >> UInt32(24)) & UInt32(0xFF))
        return buf
    }

    /// 释放缓冲区
    /// 翻译自: pub fn deinit(self: *Frame) void
    public func deinit(): Unit {
        buf.clear()
    }
}

// ============================================================================
// FrameReader — IPC 帧读取器
// 严格翻译自: src/runtime/cli/test/parallel/Frame.zig - Reader struct
//
/// Payload reader; bounds-checked, returns zero/empty on truncation.
// ============================================================================

/// IPC 帧读取器 — 带边界检查的 payload 解析器
/// 对应 Bun: Frame.Reader struct
/// 边界检查, 截断时返回零/空
public class FrameReader {
    /// 剩余 payload 数据
    /// 翻译自: p: []const u8
    public var p: ArrayList<UInt8>
    /// 当前读取位置
    private var pos: Int64

    public init(payload: ArrayList<UInt8>) {
        p = payload
        pos = 0
    }

    /// 读取 u32 (小端序)
    /// 翻译自: pub fn u32_(self: *Reader) u32
    /// 边界检查: 不足 4 字节返回 0
    public func readU32(): UInt32 {
        if (pos + 4 > p.size) {
            return UInt32(0)
        }
        let b0 = UInt32(p[Int64(pos)])
        let b1 = UInt32(p[Int64(pos + 1)])
        let b2 = UInt32(p[Int64(pos + 2)])
        let b3 = UInt32(p[Int64(pos + 3)])
        pos += Int64(4)
        return b0 | (b1 << UInt32(8)) | (b2 << UInt32(16)) | (b3 << UInt32(24))
    }

    /// 读取字符串 (带长度前缀)
    /// 翻译自: pub fn str(self: *Reader) []const u8
    /// 边界检查: 长度不足返回空字符串
    public func readStr(): String {
        let n = readU32()
        if (pos + Int64(n) > p.size) {
            return ""
        }
        let sb = StringBuilder()
        for (i in Int64(0)..Int64(n)) {
            sb.append(Rune(p[Int64(pos + i)]))
        }
        pos += Int64(n)
        return sb.toString()
    }
}
