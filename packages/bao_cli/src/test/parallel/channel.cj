// 严格翻译自: src/cli/test/parallel/Channel.zig
package bao_cli.test.parallel

import bao_core.*
import bao_runtime.*
import bao_cli.test.*
import bao_collections.*

public type FileDescriptor = Int64

// ============================================================================
// Channel — 双向 IPC 通道
// 严格翻译自: src/cli/test/parallel/Channel.zig
//
// 用于 bao test --parallel 的双向 IPC 通道
// 读取通过循环的数据回调进行帧解码; 写入通过平台 socket/pipe
// 进行背压缓冲和通过循环排空
//
// 帧格式: [u32 LE payload_len][u8 kind][payload]
// 载荷内的字符串: [u32 LE len][bytes]
// ============================================================================

/// IPC 通道
/// 对应 Bun: Channel(Owner, owner_field)
public class Channel {
    /// 输入缓冲区 (尚未形成完整帧的入站字节)
    public var in_: ArrayList<Byte>

    /// 输出缓冲区 (内核尚未接受的字节)
    public var out: ArrayList<Byte>

    /// 是否完成
    public var done: Bool

    /// 后端
    public var backend: ChannelBackend

    /// 所有者回调: 帧到达
    public var onFrame: ?((FrameKind, FrameReader) -> Unit)

    /// 所有者回调: 通道关闭
    public var onDone: ?(() -> Unit)

    public init() {
        in_ = ArrayList<Byte>()
        out = ArrayList<Byte>()
        done = false
        backend = ChannelBackend()
        onFrame = None
        onDone = None
    }

    /// 采用 duplex fd 到通道并开始读取
    /// 对应 Bun: Channel.adopt()
    public func adopt(vm: VirtualMachine, fd: FileDescriptor): Bool {
        backend.socket = fd
        return true
    }

    /// 排队并写入一个完整的编码帧
    /// 对应 Bun: Channel.send()
    ///
    /// 如果内核只接受部分数据, 剩余部分缓冲到 out
    public func send(frameBytes: Array<Byte>): Unit {
        if (done) {
            return
        }

        if (out.size > 0) {
            // 已有待发送数据, 排入队尾
            for (b in frameBytes) {
                out.append(b)
            }
            return
        }

        // 尝试直接写入
        let wrote = backend.write(frameBytes)
        if (wrote < Int64(frameBytes.size)) {
            for (i in wrote..Int64(frameBytes.size)) {
                out.append(frameBytes[Int64(i)])
            }
        }
    }

    /// 是否仍有排队或飞行中的编码字节
    /// 对应 Bun: Channel.hasPendingWrites()
    public func hasPendingWrites(): Bool {
        return out.size > 0
    }

    /// 是否仍附加 (socket/pipe 仍打开)
    /// 对应 Bun: Channel.isAttached()
    public func isAttached(): Bool {
        return backend.socket != None
    }

    /// 最佳努力排空缓冲写入
    /// 对应 Bun: Channel.flush()
    public func flush(): Unit {
        while (out.size > 0 && !done) {
            let arr = Array<Byte>(out.size, { i => out[i] })
            let wrote = backend.write(arr)
            if (wrote <= 0) {
                return
            }
            // 移除已写入的字节
            let remaining = ArrayList<Byte>()
            for (i in wrote..Int64(out.size)) {
                remaining.append(out[Int64(i)])
            }
            out = remaining
        }
    }

    /// 关闭通道
    /// 对应 Bun: Channel.close()
    public func close(): Unit {
        if (done) {
            return
        }
        flush()
        backend.close()
        markDone()
    }

    /// 释放资源
    /// 对应 Bun: Channel.deinit()
    public func deinit(): Unit {
        done = true
        backend.close()
        in_.clear()
        out.clear()
    }

    /// 接收数据并解码帧
    /// 对应 Bun: Channel.ingest()
    ///
    /// 帧格式: [4字节 payload_len (LE)][1字节 kind][payload 字节]
    /// 完整帧 = 5 + payload_len 字节
    public func ingest(data: Array<Byte>): Unit {
        if (done) {
            return
        }

        // 追加到输入缓冲区
        for (b in data) {
            in_.append(b)
        }

        // 尝试解码完整帧
        var head: Int64 = 0
        while (in_.size - head >= 5) {
            // 读取 payload_len (小端 u32)
            let len = Int64(in_[head]) |
                      (Int64(in_[head + 1]) << 8) |
                      (Int64(in_[head + 2]) << 16) |
                      (Int64(in_[head + 3]) << 24)

            // 帧过大, 视为损坏
            if (len > MAX_PAYLOAD) {
                markDone()
                return
            }

            // 不完整帧, 等待更多数据
            if (in_.size - head < 5 + len) {
                break
            }

            // 解码 kind 字节
            let kindByte = Int64(in_[head + 4])
            let kind = byteToFrameKind(kindByte)

            // 提取载荷
            let payloadData = Array<Byte>(len, { i => in_[head + 5 + i] })
            let rd = FrameReader(payloadData)

            // 分发给所有者
            match (onFrame) {
                case Some(cb) => cb(kind, rd)
                case None => ()
            }

            head += 5 + len
        }

        // 移除已处理的字节
        if (head > 0) {
            let rest = ArrayList<Byte>()
            for (i in head..Int64(in_.size)) {
                rest.append(in_[i])
            }
            in_ = rest
        }
    }

    /// 标记完成
    private func markDone(): Unit {
        if (done) {
            return
        }
        done = true
        match (onDone) {
            case Some(cb) => cb()
            case None => ()
        }
    }

    /// 字节转 FrameKind
    private func byteToFrameKind(b: Int64): FrameKind {
        match (b) {
            case 0 => FrameKind.ready
            case 1 => FrameKind.fileStart
            case 2 => FrameKind.testDone
            case 3 => FrameKind.fileDone
            case 4 => FrameKind.repeatBufs
            case 5 => FrameKind.junitFile
            case 6 => FrameKind.coverageFile
            case 7 => FrameKind.run
            case 8 => FrameKind.shutdown
            case _ => FrameKind.ready
        }
    }
}

/// 通道后端
public class ChannelBackend {
    public var socket: ?FileDescriptor

    public init() {
        socket = None
    }

    /// 写入数据到 fd
    public func write(data: Array<Byte>): Int64 {
        match (socket) {
            case Some(fd) =>
                // 将 Byte 数组转为 UInt8 数组
                let u8data = Array<UInt8>(data.size, { i => UInt8(data[i]) })
                match (Sys.write(fd, u8data)) {
                    case SysMaybe.Ok(n) => n
                    case SysMaybe.Err(_) => Int64(0) - 1 // write error
                }
            case None =>
                Int64(data.size) // 丢弃 (非附加状态)
        }
    }

    /// 关闭 fd
    public func close(): Unit {
        match (socket) {
            case Some(fd) =>
                Sys.close(fd)
                socket = None
            case None => ()
        }
    }
}
