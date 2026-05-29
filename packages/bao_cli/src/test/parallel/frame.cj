// 严格翻译自: src/cli/test/parallel/Frame.zig
package bao_cli.test.parallel

import bao_core.*
import bao_runtime.*
import bao_collections.*

// ============================================================================
// Frame — fd-3 IPC 通道的线协议
// 严格翻译自: src/cli/test/parallel/Frame.zig
//
// 长度前缀的二进制帧:
//   [u32 LE payload_len][u8 kind][payload]
// 载荷内的字符串: [u32 LE len][bytes]
// ============================================================================

/// 帧类型
/// 对应 Bun: Frame.Kind
public enum FrameKind {
    // worker -> coordinator
    | ready           // (空)
    | fileStart       // u32 file_idx
    | testDone         // u32 file_idx, str formatted_line (包含 ANSI; 原样打印)
    | fileDone         // 9 x u32: file_idx, pass, fail, skip, todo, expectations, skipped_label, files, unhandled
    | repeatBufs       // 3 x str: failures, skips, todos (原样重复缓冲区字节)
    | junitFile        // str path
    | coverageFile     // str path
    // coordinator -> worker
    | run              // u32 file_idx, str path
    | shutdown         // (空)
}

/// 单个 IPC 帧载荷的上限
/// 对应 Bun: Frame.max_payload
public let MAX_PAYLOAD: Int64 = 64 * 1024 * 1024

/// 最小长度前缀二进制编解码器
/// 对应 Bun: Frame
public class Frame {
    /// 缓冲区
    public var buf: ArrayList<Byte>

    public init() {
        buf = ArrayList<Byte>()
    }

    /// 开始构建帧
    /// 对应 Bun: Frame.begin()
    public func begin(kind: FrameKind): Unit {
        buf.clear()
        // 预留头部 (4 字节 payload_len)
        for (_ in 0..4) {
            buf.append(0)
        }
        // kind 字节
        buf.append(frameKindToUInt8(kind))
    }

    /// 写入 u32 值 (小端)
    /// 对应 Bun: Frame.u32_()
    public func u32_(v: Int64): Unit {
        buf.append(UInt8(v & 0xFF))
        buf.append(UInt8((v >> 8) & 0xFF))
        buf.append(UInt8((v >> 16) & 0xFF))
        buf.append(UInt8((v >> 24) & 0xFF))
    }

    /// 写入字符串 (长度前缀)
    /// 对应 Bun: Frame.str()
    /// 严格翻译自: Frame.zig 中 str(s) -- 写入 u32 长度 + 字节
    public func str(s: String): Unit {
        // 截断保护: 单帧不超过 MAX_PAYLOAD
        let trunc = "\n... [output truncated: would exceed --parallel IPC frame limit]\n"
        let headroom: Int64 = 256
        let used: Int64 = (buf.size.toInt64() - 5) + 4
        let room: Int64 = if (MAX_PAYLOAD > used + headroom) { MAX_PAYLOAD - used - headroom } else { 0 }
        if (s.size.toInt64() <= room) {
            u32_(Int64(s.size))
            for (i in 0..s.size) {
                buf.append(UInt8(s[i]))
            }
            return
        }
        let keep: Int64 = if (room > trunc.size.toInt64()) { room - trunc.size.toInt64() } else { 0 }
        u32_(keep + trunc.size.toInt64())
        for (i in 0..Int64(s.size)) {
            if (i >= keep) { break }
            buf.append(UInt8(s[i]))
        }
        for (i in 0..trunc.size) {
            buf.append(UInt8(trunc[i]))
        }
    }

    /// 完成帧并返回编码字节
    /// 对应 Bun: Frame.finish()
    /// 严格翻译自: Frame.zig 中 finish() -- 补全 payload_len 头部并返回缓冲区
    public func finish(): Array<Byte> {
        let payloadLen: Int64 = buf.size.toInt64() - 5
        // 写入 payload_len 到头部 [0..4]
        buf[0] = UInt8(payloadLen & 0xFF)
        buf[1] = UInt8((payloadLen >> 8) & 0xFF)
        buf[2] = UInt8((payloadLen >> 16) & 0xFF)
        buf[3] = UInt8((payloadLen >> 24) & 0xFF)
        return Array<Byte>(buf.size, { i => buf[i] })
    }

    /// 释放资源
    /// 对应 Bun: Frame.deinit()
    public func deinit(): Unit {
        buf.clear()
    }

    /// 将 FrameKind 转换为字节
    private func frameKindToUInt8(kind: FrameKind): Byte {
        match (kind) {
            case FrameKind.ready => 0
            case FrameKind.fileStart => 1
            case FrameKind.testDone => 2
            case FrameKind.fileDone => 3
            case FrameKind.repeatBufs => 4
            case FrameKind.junitFile => 5
            case FrameKind.coverageFile => 6
            case FrameKind.run => 7
            case FrameKind.shutdown => 8
        }
    }
}

/// 载荷读取器
/// 对应 Bun: Frame.Reader
public class FrameReader {
    /// 剩余数据
    public var data: Array<Byte>
    public var pos: Int64

    public init(data: Array<Byte>) {
        this.data = data
        this.pos = 0
    }

    /// 读取 u32 值
    /// 对应 Bun: Reader.u32_()
    /// 严格翻译自: Frame.zig Reader.u32_() -- 小端读取 4 字节
    public func u32_(): Int64 {
        if (pos + 4 > data.size) { return 0 }
        let v = Int64(data[pos].toInt()) |
                (Int64(data[pos + 1].toInt()) << 8) |
                (Int64(data[pos + 2].toInt()) << 16) |
                (Int64(data[pos + 3].toInt()) << 24)
        pos += 4
        return v
    }

    /// 读取字符串
    /// 对应 Bun: Reader.str()
    /// 严格翻译自: Frame.zig Reader.str() -- 先读 u32 长度, 再读字节
    public func str(): String {
        let n = u32_()
        if (n == 0) { return "" }
        if (pos + n > data.size) { return "" }
        let bytes = Array<Byte>(n, { i => data[pos + i] })
        pos += n
        return String.fromUtf8(bytes)
    }
}
