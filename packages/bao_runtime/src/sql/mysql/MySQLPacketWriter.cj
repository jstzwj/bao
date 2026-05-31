// MySQL 数据包写入器
// 严格翻译自: src/sql/mysql/protocol/NewWriter.zig
package bao_runtime.sql.mysql

import bao_core.*

/// MySQL 数据包写入器
/// 对应 Bun: NewWriter + NewWriterWrap
/// 按照 MySQL 协议将数据编码并写入缓冲区
public class MySQLPacketWriter {
    /// 内部缓冲区
    public var buffer: Array<UInt8>
    /// 当前包起始偏移
    public var packetStartOffset: Int64
    /// 是否有活跃的包
    public var hasActivePacket: Bool

    public init() {
        buffer = Array<UInt8>()
        packetStartOffset = 0
        hasActivePacket = false
    }

    /// 获取当前偏移量
    /// 对应 Bun: NewWriterWrap.offset
    public func currentOffset(): Int64 {
        return buffer.size
    }

    /// 开始一个新包
    /// 对应 Bun: NewWriterWrap.start
    public func start(sequenceId: UInt8): Unit {
        packetStartOffset = buffer.size
        hasActivePacket = true
        // 写入 4 字节包头占位 (length: 3 + sequence_id: 1)
        buffer.append(0)  // length byte 0
        buffer.append(0)  // length byte 1
        buffer.append(0)  // length byte 2
        buffer.append(sequenceId)
    }

    /// 结束当前包 (回填长度)
    /// 对应 Bun: Packet.end
    public func endPacket(): Unit {
        if (!hasActivePacket) {
            return
        }
        let currentPos = buffer.size
        let length = currentPos - packetStartOffset - 4  // 减去包头 4 字节
        // 回填长度 (3 字节小端)
        buffer[packetStartOffset] = UInt8(length & 0xff)
        buffer[packetStartOffset + 1] = UInt8((length >> 8) & 0xff)
        buffer[packetStartOffset + 2] = UInt8((length >> 16) & 0xff)
        hasActivePacket = false
    }

    /// 写入原始字节
    /// 对应 Bun: NewWriterWrap.write
    public func writeBytes(data: Array<UInt8>): Unit {
        for (b in data) {
            buffer.append(b)
        }
    }

    /// 在指定位置写入字节 (pwrite)
    /// 对应 Bun: NewWriterWrap.pwrite
    public func pwrite(data: Array<UInt8>, pos: Int64): Unit {
        for (i in 0..data.size) {
            if (pos + i < buffer.size) {
                buffer[pos + i] = data[i]
            }
        }
    }

    /// 写入 1 字节整数
    /// 对应 Bun: NewWriterWrap.int1
    public func writeInt8(value: UInt8): Unit {
        buffer.append(value)
    }

    /// 写入 4 字节小端整数
    /// 对应 Bun: NewWriterWrap.int4
    public func writeInt32(value: UInt32): Unit {
        buffer.append(UInt8(value & 0xff))
        buffer.append(UInt8((value >> 8) & 0xff))
        buffer.append(UInt8((value >> 16) & 0xff))
        buffer.append(UInt8((value >> 24) & 0xff))
    }

    /// 写入 8 字节小端整数
    /// 对应 Bun: NewWriterWrap.int8
    public func writeInt64(value: UInt64): Unit {
        buffer.append(UInt8(value & 0xff))
        buffer.append(UInt8((value >> 8) & 0xff))
        buffer.append(UInt8((value >> 16) & 0xff))
        buffer.append(UInt8((value >> 24) & 0xff))
        buffer.append(UInt8((value >> 32) & 0xff))
        buffer.append(UInt8((value >> 40) & 0xff))
        buffer.append(UInt8((value >> 48) & 0xff))
        buffer.append(UInt8((value >> 56) & 0xff))
    }

    /// 写入 2 字节小端整数
    public func writeInt16(value: UInt16): Unit {
        buffer.append(UInt8(value & 0xff))
        buffer.append(UInt8((value >> 8) & 0xff))
    }

    /// 写入 null 终止字符串
    /// 对应 Bun: NewWriterWrap.writeZ
    public func writeNullTerminated(data: Array<UInt8>): Unit {
        for (b in data) {
            buffer.append(b)
        }
        if (data.size == 0 || data[data.size - 1] != 0) {
            buffer.append(0)
        }
    }

    /// 写入零填充
    public func writeZeros(count: Int64): Unit {
        for (_ in 0..count) {
            buffer.append(0)
        }
    }

    /// 写入长度编码整数
    /// 对应 Bun: NewWriterWrap.writeLengthEncodedInt
    public func writeLengthEncodedInt(value: UInt64): Unit {
        let encoded = encodeLengthInt(value)
        for (b in encoded) {
            buffer.append(b)
        }
    }

    /// 写入长度编码字符串
    /// 对应 Bun: NewWriterWrap.writeLengthEncodedString
    public func writeLengthEncodedString(data: Array<UInt8>): Unit {
        writeLengthEncodedInt(UInt64(data.size))
        for (b in data) {
            buffer.append(b)
        }
    }

    /// 写入 null bitmap (预编译语句参数)
    /// 对应 Bun: PreparedStatement.Execute.writeNullBitmap
    public func writeNullBitmap(params: Array<MySQLValue>, paramCount: Int64): Unit {
        let bitmapBytes = (paramCount + 7) / 8
        let bitmap = Array<UInt8>(bitmapBytes, item: 0)
        for (i in 0..paramCount) {
            if (params[i].isNull()) {
                bitmap[i >> 3] = bitmap[i >> 3] | UInt8(1 << (i & 7))
            }
        }
        for (b in bitmap) {
            buffer.append(b)
        }
    }

    /// 获取写入缓冲区
    public func getBuffer(): Array<UInt8> {
        return buffer
    }

    /// 清空缓冲区
    public func reset(): Unit {
        buffer = Array<UInt8>()
        packetStartOffset = 0
        hasActivePacket = false
    }
}

/// MySQL 值类型 (简化版，用于 writeNullBitmap)
/// 完整实现在 MySQLValue 中
public class MySQLValue {
    public var isNullValue: Bool

    public init() {
        isNullValue = false
    }

    public func isNull(): Bool {
        return isNullValue
    }
}
