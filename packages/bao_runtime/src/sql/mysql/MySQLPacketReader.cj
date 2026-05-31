// MySQL 数据包读取器
// 严格翻译自: src/sql/mysql/protocol/NewReader.zig + StackReader.zig
package bao_runtime.sql.mysql

import bao_core.*
import bao_runtime.sql.shared.*

/// MySQL 数据包读取器
/// 对应 Bun: StackReader + NewReader
/// 从缓冲区中按 MySQL 协议解析数据
public class MySQLPacketReader {
    /// 底层缓冲区
    public var buffer: Array<UInt8>
    /// 当前读取偏移
    public var offset: Int64
    /// 消息起始偏移
    public var messageStart: Int64

    public init() {
        buffer = Array<UInt8>()
        offset = 0
        messageStart = 0
    }

    public init(buffer: Array<UInt8>) {
        this.buffer = buffer
        offset = 0
        messageStart = 0
    }

    public init(buffer: Array<UInt8>, offset: Int64, messageStart: Int64) {
        this.buffer = buffer
        this.offset = offset
        this.messageStart = messageStart
    }

    /// 设置缓冲区
    public func setBuffer(buffer: Array<UInt8>): Unit {
        this.buffer = buffer
        offset = 0
        messageStart = 0
    }

    /// 标记消息起始位置
    /// 对应 Bun: StackReader.markMessageStart
    public func markMessageStart(): Unit {
        messageStart = offset
    }

    /// 从消息起始设置偏移
    /// 对应 Bun: StackReader.setOffsetFromStart
    public func setOffsetFromStart(newOffset: Int64): Unit {
        offset = messageStart + newOffset
    }

    /// 检查是否有足够容量
    /// 对应 Bun: StackReader.ensureCapacity
    public func ensureCapacity(length: Int64): Bool {
        return buffer.size >= (offset + length)
    }

    /// 预览剩余数据 (不移动偏移)
    /// 对应 Bun: StackReader.peek
    public func peek(): Array<UInt8> {
        if (offset >= buffer.size) {
            return Array<UInt8>()
        }
        let result = Array<UInt8>()
        for (i in offset..buffer.size) {
            result.append(buffer[i])
        }
        return result
    }

    /// 跳过字节 (正数向前, 负数向后)
    /// 对应 Bun: StackReader.skip
    public func skip(count: Int64): Unit {
        if (count < 0) {
            let absCount = -count
            if (absCount > offset) {
                offset = 0
            } else {
                offset -= absCount
            }
            return
        }
        if (offset + count > buffer.size) {
            offset = buffer.size
            return
        }
        offset += count
    }

    /// 读取指定数量的字节
    /// 对应 Bun: StackReader.read
    public func readBytes(count: Int64): SQLData {
        if (!ensureCapacity(count)) {
            return SQLData.empty()
        }
        let start = offset
        skip(count)
        let result = Array<UInt8>()
        for (i in start..offset) {
            result.append(buffer[i])
        }
        return SQLData.fromTemporary(result)
    }

    /// 读取 null 终止字符串
    /// 对应 Bun: StackReader.readZ
    public func readNullTerminated(): SQLData {
        let remaining = peek()
        var zeroPos = -1
        for (i in 0..remaining.size) {
            if (remaining[i] == 0) {
                zeroPos = i
                break
            }
        }
        if (zeroPos < 0) {
            return SQLData.empty()  // ShortRead
        }
        skip(zeroPos + 1)
        let result = Array<UInt8>()
        for (i in 0..zeroPos) {
            result.append(remaining[i])
        }
        return SQLData.fromTemporary(result)
    }

    /// 读取 1 字节无符号整数
    public func readInt8(): UInt8 {
        if (offset >= buffer.size) {
            return 0
        }
        let v = buffer[offset]
        offset += 1
        return v
    }

    /// 读取 2 字节小端无符号整数
    public func readInt16(): UInt16 {
        if (offset + 2 > buffer.size) {
            return 0
        }
        let v = UInt16(buffer[offset]) |
            (UInt16(buffer[offset + 1]) << 8)
        offset += 2
        return v
    }

    /// 读取 3 字节小端无符号整数
    public func readInt24(): UInt32 {
        if (offset + 3 > buffer.size) {
            return 0
        }
        let v = UInt32(buffer[offset]) |
            (UInt32(buffer[offset + 1]) << 8) |
            (UInt32(buffer[offset + 2]) << 16)
        offset += 3
        return v
    }

    /// 读取 4 字节小端无符号整数
    public func readInt32(): UInt32 {
        if (offset + 4 > buffer.size) {
            return 0
        }
        let v = UInt32(buffer[offset]) |
            (UInt32(buffer[offset + 1]) << 8) |
            (UInt32(buffer[offset + 2]) << 16) |
            (UInt32(buffer[offset + 3]) << 24)
        offset += 4
        return v
    }

    /// 读取 8 字节小端无符号整数
    public func readInt64(): UInt64 {
        if (offset + 8 > buffer.size) {
            return 0
        }
        let v = UInt64(buffer[offset]) |
            (UInt64(buffer[offset + 1]) << 8) |
            (UInt64(buffer[offset + 2]) << 16) |
            (UInt64(buffer[offset + 3]) << 24) |
            (UInt64(buffer[offset + 4]) << 32) |
            (UInt64(buffer[offset + 5]) << 40) |
            (UInt64(buffer[offset + 6]) << 48) |
            (UInt64(buffer[offset + 7]) << 56)
        offset += 8
        return v
    }

    /// 读取长度编码整数
    /// 对应 Bun: NewReader.encodedLenInt
    public func readEncodedLenInt(): UInt64 {
        let result = decodeLengthIntFromSlice(buffer, offset)
        if (let Some(r) <- result) {
            offset += r.bytesRead
            return r.value
        }
        return 0
    }

    /// 读取长度编码整数 (并累计已读大小)
    /// 对应 Bun: NewReader.encodedLenIntWithSize
    public func readEncodedLenIntWithSize(currentSize: Int64): LengthIntResult {
        let result = decodeLengthIntFromSlice(buffer, offset)
        if (let Some(r) <- result) {
            offset += r.bytesRead
            r.bytesRead += currentSize
            return r
        }
        return LengthIntResult(0, currentSize)
    }

    /// 读取长度编码字符串
    /// 对应 Bun: NewReader.encodeLenString
    public func readEncodedString(): SQLData {
        let result = decodeLengthIntFromSlice(buffer, offset)
        if (let Some(r) <- result) {
            offset += r.bytesRead
            let len = Int64(r.value)
            return readBytes(len)
        }
        return SQLData.empty()
    }
}
