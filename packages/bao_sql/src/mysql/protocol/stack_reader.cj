// MySQL 栈读取器
// 对应 Bun: src/sql/mysql/protocol/StackReader.zig
package bao_sql.mysql.protocol

/// MySQL 栈上包读取器
/// 对应 Bun: StackReader (struct)
///
/// 直接在现有的字节缓冲区上操作的读取器，
/// 无需分配额外的内存。适用于已接收的完整包数据解析。
public class StackReader {
    /// 底层缓冲区
    /// 对应 Bun: buffer []const u8
    public var buffer: Array<UInt8>

    /// 当前偏移量 (引用外部)
    /// 对应 Bun: offset *usize
    public var offsetRef: Int64

    /// 消息起始位置 (引用外部)
    /// 对应 Bun: message_start *usize
    public var messageStartRef: Int64

    public init(buffer: Array<UInt8>, offsetRef: Int64, messageStartRef: Int64) {
        this.buffer = buffer
        this.offsetRef = offsetRef
        this.messageStartRef = messageStartRef
    }

    /// 标记消息起始位置
    /// 对应 Bun: StackReader.markMessageStart
    public func markMessageStart(): Unit {
        messageStartRef = offsetRef
    }

    /// 从消息起始位置设置偏移
    /// 对应 Bun: StackReader.setOffsetFromStart
    public func setOffsetFromStart(newOffset: Int64): Unit {
        offsetRef = messageStartRef + newOffset
    }

    /// 检查是否有足够的数据
    /// 对应 Bun: StackReader.ensureCapacity
    public func ensureCapacity(length: Int64): Bool {
        return Int64(buffer.size) >= (offsetRef + length)
    }

    /// 查看当前剩余数据 (不移动偏移)
    /// 对应 Bun: StackReader.peek
    public func peek(): Array<UInt8> {
        if (offsetRef >= Int64(buffer.size)) {
            return Array<UInt8>()
        }
        return buffer[offsetRef..Int64(buffer.size)]
    }

    /// 跳过指定字节数
    /// 对应 Bun: StackReader.skip
    public func skip(count: Int64): Unit {
        if (count < 0) {
            let absCount = -count
            if (absCount > offsetRef) {
                offsetRef = 0
                return
            }
            offsetRef -= absCount
            return
        }

        if (offsetRef + count > Int64(buffer.size)) {
            offsetRef = Int64(buffer.size)
            return
        }

        offsetRef += count
    }

    /// 读取指定数量的字节
    /// 对应 Bun: StackReader.read
    public func read(count: Int64): Array<UInt8> {
        let currentOffset = offsetRef
        if (!ensureCapacity(count)) {
            throw MySQLError.ShortRead
        }

        skip(count)
        return buffer[currentOffset..offsetRef]
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
}
