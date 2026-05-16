// MySQL 包写入器
// 对应 Bun: src/sql/mysql/protocol/NewWriter.zig
package bao_sql.mysql.protocol

import std.collection.*

/// MySQL 包写入器中的活动包
/// 对应 Bun: NewWriterWrap.Packet (struct)
///
/// 表示正在构建的 MySQL 协议包，结束时写入包头
public class MySQLPacket {
    /// 包头
    public var header: PacketHeader

    /// 包起始偏移
    public var startOffset: Int64

    /// 所属写入器
    private var writer: MySQLPacketWriter

    public init(writer: MySQLPacketWriter, sequenceId: UInt8, startOffset: Int64) {
        this.writer = writer
        header = PacketHeader(0, sequenceId)
        this.startOffset = startOffset
    }

    /// 结束包，计算并写入包头
    /// 对应 Bun: Packet.end
    public func end(): Unit {
        let newOffset = writer.offset()
        // 计算有效载荷长度
        let length = newOffset - startOffset - Int64(PacketHeader.size)
        header.length = UInt32(length)
        // 写入包头到起始位置
        writer.pwrite(header.encode(), startOffset)
    }
}

/// MySQL 包写入器
/// 对应 Bun: NewWriterWrap (struct)
///
/// 提供向字节流写入 MySQL 协议数据的高级接口。
/// 支持写入整数、长度编码整数、null 终止字符串等。
public class MySQLPacketWriter {
    /// 输出缓冲区
    private var buffer: ArrayList<UInt8>

    public init() {
        buffer = ArrayList<UInt8>()
    }

    /// 获取当前写入偏移
    /// 对应 Bun: NewWriterWrap.offset
    public func offset(): Int64 {
        return Int64(buffer.size)
    }

    /// 写入原始字节
    /// 对应 Bun: NewWriterWrap.write
    public func write(data: Array<UInt8>): Unit {
        for (i in 0..data.size) {
            buffer.add(data[i])
        }
    }

    /// 在指定位置写入字节 (用于写包头)
    /// 对应 Bun: NewWriterWrap.pwrite
    public func pwrite(data: Array<UInt8>, position: Int64): Unit {
        for (i in 0..data.size) {
            buffer[Int64(position) + Int64(i)] = data[i]
        }
    }

    /// 开始一个新包
    /// 对应 Bun: NewWriterWrap.start
    public func start(sequenceId: UInt8): MySQLPacket {
        let o = offset()
        // 写入 4 字节占位包头
        write(Array<UInt8>(4, repeat: UInt8(0)))
        return MySQLPacket(this, sequenceId, o)
    }

    /// 写入 1 字节整数
    /// 对应 Bun: NewWriterWrap.int1
    public func int1(value: UInt8): Unit {
        buffer.add(value)
    }

    /// 写入 4 字节小端整数
    /// 对应 Bun: NewWriterWrap.int4
    public func int4(value: UInt32): Unit {
        buffer.add(UInt8(value & 0xff))
        buffer.add(UInt8((value >> 8) & 0xff))
        buffer.add(UInt8((value >> 16) & 0xff))
        buffer.add(UInt8((value >> 24) & 0xff))
    }

    /// 写入 8 字节小端整数
    /// 对应 Bun: NewWriterWrap.int8
    public func int8(value: UInt64): Unit {
        buffer.add(UInt8(value & 0xff))
        buffer.add(UInt8((value >> 8) & 0xff))
        buffer.add(UInt8((value >> 16) & 0xff))
        buffer.add(UInt8((value >> 24) & 0xff))
        buffer.add(UInt8((value >> 32) & 0xff))
        buffer.add(UInt8((value >> 40) & 0xff))
        buffer.add(UInt8((value >> 48) & 0xff))
        buffer.add(UInt8((value >> 56) & 0xff))
    }

    /// 写入 null 终止字符串
    /// 对应 Bun: NewWriterWrap.writeZ
    public func writeZ(value: Array<UInt8>): Unit {
        write(value)
        if (value.size == 0 || value[value.size - 1] != 0) {
            buffer.add(0)
        }
    }

    /// 写入长度编码整数
    /// 对应 Bun: NewWriterWrap.writeLengthEncodedInt
    public func writeLengthEncodedInt(data: UInt64): Unit {
        write(EncodeInt.encodeLengthInt(data))
    }

    /// 写入长度编码字符串
    /// 对应 Bun: NewWriterWrap.writeLengthEncodedString
    public func writeLengthEncodedString(data: Array<UInt8>): Unit {
        writeLengthEncodedInt(UInt64(data.size))
        write(data)
    }

    /// 获取输出缓冲区的副本
    public func toBytes(): Array<UInt8> {
        return buffer.toArray()
    }

    /// 重置写入器
    public func reset(): Unit {
        buffer.clear()
    }
}
