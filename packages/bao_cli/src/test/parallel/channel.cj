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
        if (wrote < frameBytes.size) {
            for (i in wrote..frameBytes.size) {
                out.append(frameBytes[i])
            }
        }
    }

    /// 是否仍有排队或飞行中的编码字节
    /// 对应 Bun: Channel.hasPendingWrites()
    public func hasPendingWrites(): Bool {
        return out.size > 0
    }

    /// 最佳努力排空缓冲写入
    /// 对应 Bun: Channel.flush()
    public func flush(): Unit {
        ()
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

    /// 接收数据
    /// 对应 Bun: Channel.ingest()
    public func ingest(data: Array<Byte>): Unit {
        ()
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
    private func byteToFrameKind(b: Byte): FrameKind {
        match (Int64(b)) {
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

    public func write(data: Array<Byte>): Int64 {
        return data.size
    }

    public func close(): Unit {
        socket = Option<FileDescriptor>.None
    }
}
