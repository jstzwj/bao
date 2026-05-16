// 严格翻译自: src/sql/postgres/protocol/StackReader.zig
// PostgreSQL 协议栈式读取器
package bao_sql.postgres.protocol

import bao_sql.shared.Data

/// 栈式读取器 - 从缓冲区中读取数据
/// 对应 Bun: StackReader
public class StackReader {
    public var buffer: Array<UInt8>
    public var offset: Int64
    public var messageStart: Int64

    public init(buffer: Array<UInt8>, offset: Int64, messageStart: Int64) {
        this.buffer = buffer
        this.offset = offset
        this.messageStart = messageStart
    }

    /// 标记消息开始位置
    /// 对应 Bun: StackReader.markMessageStart
    public func markMessageStart(): Unit {
        messageStart = offset
    }

    /// 确保有足够长度
    /// 对应 Bun: StackReader.ensureLength
    public func ensureLength(length: Int64): Bool {
        return buffer.size >= (offset + length)
    }

    /// 查看剩余未读数据
    /// 对应 Bun: StackReader.peek
    public func peek(): Array<UInt8> {
        if (offset >= buffer.size) {
            return Array<UInt8>()
        }
        return buffer.slice(offset, buffer.size - offset)
    }

    /// 跳过指定字节数
    /// 对应 Bun: StackReader.skip
    public func skip(count: Int64): Unit {
        if (offset + count > buffer.size) {
            offset = buffer.size
            return
        }
        offset += count
    }

    /// 确保有足够容量
    /// 对应 Bun: StackReader.ensureCapacity
    public func ensureCapacity(count: Int64): Bool {
        return buffer.size >= (offset + count)
    }

    /// 读取指定字节数
    /// 对应 Bun: StackReader.read
    public func read(count: Int64): Data {
        let startPos = offset
        if (!ensureCapacity(count)) {
            return Data.emptyData()
        }
        skip(count)
        return Data.create(buffer.slice(startPos, count))
    }

    /// 读取以 null 结尾的字符串
    /// 对应 Bun: StackReader.readZ
    public func readZ(): Data {
        let remaining = peek()
        for (i in 0..remaining.size) {
            if (remaining[Int64(i)] == 0) {
                skip(Int64(i) + 1)
                return Data.create(remaining.slice(0, Int64(i)))
            }
        }
        return Data.emptyData()
    }
}
