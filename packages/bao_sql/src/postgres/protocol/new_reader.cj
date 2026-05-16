// 严格翻译自: src/sql/postgres/protocol/NewReader.zig
// PostgreSQL 协议读取器
package bao_sql.postgres.protocol

import bao_sql.shared.Data

/// PostgreSQL 协议读取器接口
/// 对应 Bun: NewReader (generic type)
public interface NewReader<C> {
    /// 标记消息开始位置
    func markMessageStart(): Unit

    /// 查看缓冲区中剩余未读数据
    func peek(): Array<UInt8>

    /// 跳过指定字节数
    func skip(count: Int64): Unit

    /// 确保有足够的容量
    func ensureCapacity(count: Int64): Bool

    /// 读取指定字节数
    func read(count: Int64): Data

    /// 读取以 null 结尾的字符串
    func readZ(): Data

    /// 读取整数
    func int4(): ?UInt32

    /// 读取短整数
    func short(): ?UInt16

    /// 读取消息长度
    func length(): ?UInt32

    /// 读取单字节
    func byte(): ?UInt8
}

/// 基于 StackReader 的默认读取器实现
/// 对应 Bun: NewReader (concrete)
public class StackReaderImpl {
    public var buffer: Array<UInt8>
    public var offset: Int64
    public var messageStart: Int64

    public init(buffer: Array<UInt8>) {
        this.buffer = buffer
        this.offset = 0
        this.messageStart = 0
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
    public func read(count: Int64): ?Data {
        if (!ensureCapacity(count)) {
            return None
        }
        let start = offset
        offset += count
        return Data.create(buffer.slice(start, count))
    }

    /// 读取以 null 结尾的字符串
    /// 对应 Bun: StackReader.readZ
    public func readZ(): ?Data {
        let remaining = peek()
        // 查找 null 字节
        for (i in 0..remaining.size) {
            if (remaining[Int64(i)] == 0) {
                skip(Int64(i) + 1)
                return Data.create(remaining.slice(0, Int64(i)))
            }
        }
        return None
    }

    /// 读取 int4
    public func int4(): ?UInt32 {
        let data = read(4)
        if (data.isNone()) { return None }
        let slice = data.getOrThrow().slice()
        if (slice.size < 4) { return None }
        return UInt32(slice[0]) << 24 | UInt32(slice[1]) << 16 | UInt32(slice[2]) << 8 | UInt32(slice[3])
    }

    /// 读取 short
    public func short(): ?UInt16 {
        let data = read(2)
        if (data.isNone()) { return None }
        let slice = data.getOrThrow().slice()
        if (slice.size < 2) { return None }
        return UInt16(slice[0]) << 8 | UInt16(slice[1])
    }

    /// 读取消息长度
    public func length(): ?UInt32 {
        let expected = int4()
        if (expected.isNone()) { return None }
        let val = expected.getOrThrow()
        if (val > 0) {
            if (!ensureCapacity(Int64(val - 4))) {
                return None
            }
        }
        return val
    }

    /// 读取单字节
    public func byte(): ?UInt8 {
        let data = read(1)
        if (data.isNone()) { return None }
        let slice = data.getOrThrow().slice()
        if (slice.size < 1) { return None }
        return slice[0]
    }
}
