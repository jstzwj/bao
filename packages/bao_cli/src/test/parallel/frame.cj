// 严格翻译自: src/cli/test/parallel/Frame.zig
package bao_cli.test.parallel

import bao_core.*

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
        buf.append(frameKindToByte(kind))
    }

    /// 写入 u32 值 (小端)
    /// 对应 Bun: Frame.u32_()
    public func u32_(v: Int64): Unit {
        buf.append(Byte(v & 0xFF))
        buf.append(Byte((v >> 8) & 0xFF))
        buf.append(Byte((v >> 16) & 0xFF))
        buf.append(Byte((v >> 24) & 0xFF))
    }

    /// 写入字符串 (长度前缀)
    /// 对应 Bun: Frame.str()
    public func str(s: String): Unit {
        let trunc = "\n... [output truncated: would exceed --parallel IPC frame limit]\n"
        let headroom = 256
        let used = (buf.size - 5) + 4  // 当前载荷 + str-len 前缀
        let room = if (MAX_PAYLOAD > used + headroom) MAX_PAYLOAD - used - headroom else 0

        if (s.length <= room) {
            u32_(s.length)
            for (b in s.toByteArray()) {
                buf.append(b)
            }
            return
        }

        let keep = if (room > trunc.length) room - trunc.length else 0
        u32_(keep + trunc.length)
        for (i in 0..keep) {
            buf.append(s[i].toByte())
        }
        for (b in trunc.toByteArray()) {
            buf.append(b)
        }
    }

    /// 完成帧并返回编码字节
    /// 对应 Bun: Frame.finish()
    public func finish(): Array<Byte> {
        let payloadLen = buf.size - 5
        // 写入 payload_len (小端)
        buf[0] = Byte(payloadLen & 0xFF)
        buf[1] = Byte((payloadLen >> 8) & 0xFF)
        buf[2] = Byte((payloadLen >> 16) & 0xFF)
        buf[3] = Byte((payloadLen >> 24) & 0xFF)
        return buf.toArray()
    }

    /// 释放资源
    /// 对应 Bun: Frame.deinit()
    public func deinit(): Unit {
        buf.clear()
    }

    /// 将 FrameKind 转换为字节
    private func frameKindToByte(kind: FrameKind): Byte {
        when (kind) {
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
    public func u32_(): Int64 {
        if (pos + 4 > data.length) {
            return 0
        }
        let v = (data[pos].toInt() and 0xFF) or
                ((data[pos + 1].toInt() and 0xFF) << 8) or
                ((data[pos + 2].toInt() and 0xFF) << 16) or
                ((data[pos + 3].toInt() and 0xFF) << 24)
        pos += 4
        return v
    }

    /// 读取字符串
    /// 对应 Bun: Reader.str()
    public func str(): String {
        let n = u32_()
        if (pos + n > data.length) {
            return ""
        }
        let bytes = ByteArray(n.toInt())
        for (i in 0..n) {
            bytes[i.toInt()] = data[pos + i]
        }
        pos += n
        return String(bytes)
    }
}
