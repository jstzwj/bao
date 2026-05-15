// MySQL 包读取器
// 对应 Bun: src/sql/mysql/protocol/NewReader.zig
package bao_sql

/// MySQL 包读取器
/// 对应 Bun: NewReader (通过 NewReaderWrap 生成)
///
/// 提供从字节流中读取 MySQL 协议数据的高级接口。
/// 支持读取整数、长度编码整数、null 终止字符串等。
public class MySQLPacketReader {
    /// 底层缓冲区
    private var buffer: Array<UInt8>

    /// 当前偏移量
    private var offset: Int64

    /// 消息起始位置
    private var messageStart: Int64

    public init(buffer: Array<UInt8>) {
        this.buffer = buffer
        this.offset = 0
        this.messageStart = 0
    }

    public init(buffer: Array<UInt8>, offset: Int64, messageStart: Int64) {
        this.buffer = buffer
        this.offset = offset
        this.messageStart = messageStart
    }

    /// 标记消息起始位置
    /// 对应 Bun: StackReader.markMessageStart
    public func markMessageStart(): Unit {
        messageStart = offset
    }

    /// 从消息起始位置设置偏移
    /// 对应 Bun: StackReader.setOffsetFromStart
    public func setOffsetFromStart(newOffset: Int64): Unit {
        offset = messageStart + newOffset
    }

    /// 检查是否有足够的数据
    /// 对应 Bun: StackReader.ensureCapacity
    public func ensureCapacity(length: Int64): Bool {
        return Int64(buffer.size) >= (offset + length)
    }

    /// 查看当前剩余数据 (不移动偏移)
    /// 对应 Bun: StackReader.peek
    public func peek(): Array<UInt8> {
        if (offset >= Int64(buffer.size)) {
            return Array<UInt8>()
        }
        return buffer[Int64(offset)..Int64(buffer.size)]
    }

    /// 跳过指定字节数
    /// 对应 Bun: StackReader.skip
    public func skip(count: Int64): Unit {
        if (count < 0) {
            let absCount = -count
            if (absCount > offset) {
                offset = 0
                return
            }
            offset -= absCount
            return
        }

        if (offset + count > Int64(buffer.size)) {
            offset = Int64(buffer.size)
            return
        }

        offset += count
    }

    /// 读取指定数量的字节
    /// 对应 Bun: StackReader.read
    public func read(count: Int64): Array<UInt8> {
        if (!ensureCapacity(count)) {
            throw MySQLError.ShortRead
        }

        let start = offset
        skip(count)
        return buffer[start..offset]
    }

    /// 读取 null 终止字符串
    /// 对应 Bun: StackReader.readZ
    public func readZ(): Array<UInt8> {
        let remaining = peek()
        var zeroIndex = -1
        for (i in 0..remaining.size) {
            if (remaining[i] == 0) {
                zeroIndex = Int64(i)
                break
            }
        }

        if (zeroIndex >= 0) {
            skip(zeroIndex + 1)
            return remaining[0..zeroIndex]
        }

        throw MySQLError.ShortRead
    }

    /// 读取 1 字节无符号整数
    /// 对应 Bun: NewReader.int(u8)
    public func int8(): UInt8 {
        let data = read(1)
        return data[0]
    }

    /// 读取 2 字节小端无符号整数
    /// 对应 Bun: NewReader.int(u16)
    public func int16(): UInt16 {
        let data = read(2)
        return UInt16(data[0]) | (UInt16(data[1]) << 8)
    }

    /// 读取 3 字节小端无符号整数
    /// 对应 Bun: NewReader.int(u24)
    public func int24(): UInt32 {
        let data = read(3)
        return UInt32(data[0]) | (UInt32(data[1]) << 8) | (UInt32(data[2]) << 16)
    }

    /// 读取 4 字节小端无符号整数
    /// 对应 Bun: NewReader.int(u32)
    public func int32(): UInt32 {
        let data = read(4)
        return UInt32(data[0]) |
            (UInt32(data[1]) << 8) |
            (UInt32(data[2]) << 16) |
            (UInt32(data[3]) << 24)
    }

    /// 读取 8 字节小端无符号整数
    /// 对应 Bun: NewReader.int(u64)
    public func int64(): UInt64 {
        let data = read(8)
        return UInt64(data[0]) |
            (UInt64(data[1]) << 8) |
            (UInt64(data[2]) << 16) |
            (UInt64(data[3]) << 24) |
            (UInt64(data[4]) << 32) |
            (UInt64(data[5]) << 40) |
            (UInt64(data[6]) << 48) |
            (UInt64(data[7]) << 56)
    }

    /// 读取长度编码字符串
    /// 对应 Bun: NewReader.encodeLenString
    public func encodeLenString(): Array<UInt8> {
        let result = EncodeInt.decodeLengthInt(peek())
        match (result) {
            case Some(r) => {
                skip(r.bytesRead)
                return read(Int64(r.value))
            }
            case None => throw MySQLError.InvalidEncodedLength
        }
    }

    /// 读取长度编码整数
    /// 对应 Bun: NewReader.encodedLenInt
    public func encodedLenInt(): UInt64 {
        let result = EncodeInt.decodeLengthInt(peek())
        match (result) {
            case Some(r) => {
                skip(r.bytesRead)
                return r.value
            }
            case None => throw MySQLError.InvalidEncodedInteger
        }
    }

    /// 读取长度编码整数，同时累加读取字节数
    /// 对应 Bun: NewReader.encodedLenIntWithSize
    public func encodedLenIntWithSize(size: Int64): UInt64 {
        let result = EncodeInt.decodeLengthInt(peek())
        match (result) {
            case Some(r) => {
                skip(r.bytesRead)
                size += r.bytesRead
                return r.value
            }
            case None => throw MySQLError.InvalidEncodedInteger
        }
    }
}
