// PostgreSQL 协议读取器
// 严格翻译自: bun/src/sql/postgres/protocol/NewReader.zig + StackReader.zig
// 提供从字节缓冲区读取 PostgreSQL 协议消息的工具方法
package bao_runtime.sql.postgresql


/// PostgreSQL 协议字节读取器
/// 从字节数组中读取协议消息，支持偏移量跟踪
/// 对应 Bun NewReader + StackReader 的功能
public class ProtocolReader {
    private var buffer: Array<UInt8>
    private var pos: Int64  // 当前读取位置

    public init(buffer: Array<UInt8>) {
        this.buffer = buffer
        this.pos = 0
    }

    public init(buffer: Array<UInt8>, offset: Int64) {
        this.buffer = buffer
        this.pos = offset
    }

    /// 剩余可读字节数
    public func remaining(): Int64 {
        buffer.size - pos
    }

    /// 当前位置
    public func position(): Int64 {
        pos
    }

    /// 设置位置
    public func setPosition(p: Int64) {
        pos = p
    }

    /// 获取底层缓冲区
    public func getBuffer(): Array<UInt8> {
        buffer
    }

    /// 标记消息开始位置（用于错误恢复）
    public func markMessageStart(): Int64 {
        pos
    }

    /// 检查是否有足够字节可读
    public func ensureCapacity(count: Int64): Bool {
        pos + count <= buffer.size
    }

    /// 跳过指定字节数
    public func skip(count: Int64) {
        pos += count
        if (pos > buffer.size) {
            pos = buffer.size
        }
    }

    /// 查看当前位置的字节（不移动位置）
    public func peek(): ?UInt8 {
        if (pos < buffer.size) {
            buffer[pos]
        } else {
            None
        }
    }

    /// 查看当前位置开始的多个字节
    public func peekBytes(count: Int64): ?Array<UInt8> {
        if (pos + count <= buffer.size) {
            buffer[pos..(pos + count)].toArray()
        } else {
            None
        }
    }

    /// 读取单个字节
    public func readByte(): ?UInt8 {
        if (pos < buffer.size) {
            let b = buffer[pos]
            pos += 1
            b
        } else {
            None
        }
    }

    /// 读取指定长度的字节
    public func readBytes(count: Int64): ?Array<UInt8> {
        if (pos + count > buffer.size) {
            return None
        }
        let result = buffer[pos..(pos + count)].toArray()
        pos += count
        result
    }

    /// 读取以 null 结尾的字符串
    /// 返回字符串内容和消耗的字节数（包括 null 终止符）
    public func readNullTerminatedString(): ?String {
        var i = pos
        while (i < buffer.size) {
            if (buffer[i] == 0) {
                let bytes = buffer[pos..i].toArray()
                pos = i + 1  // 跳过 null 终止符
                // 将字节转为 UTF-8 字符串
                return bytes.toArray().map({ b => Char.fromUInt8(b) }).toString()
            }
            i += 1
        }
        return None
    }

    /// 读取以 null 结尾的字节数组
    public func readNullTerminatedBytes(): ?Array<UInt8> {
        var i = pos
        while (i < buffer.size) {
            if (buffer[i] == 0) {
                let result = buffer[pos..i].toArray()
                pos = i + 1
                return result
            }
            i += 1
        }
        return None
    }

    /// 读取 UInt16（大端字节序）
    public func readUInt16(): ?UInt16 {
        if (pos + 2 > buffer.size) {
            return None
        }
        let result = readUInt16BE(buffer, pos)
        pos += 2
        result
    }

    /// 读取 UInt32（大端字节序）
    public func readUInt32(): ?UInt32 {
        if (pos + 4 > buffer.size) {
            return None
        }
        let result = readUInt32BE(buffer, pos)
        pos += 4
        result
    }

    /// 读取 Int64（大端字节序）
    public func readInt64(): ?Int64 {
        if (pos + 8 > buffer.size) {
            return None
        }
        let result = readInt64BE(buffer, pos)
        pos += 8
        result
    }

    /// 读取消息长度（UInt32）并验证剩余数据足够
    /// 返回消息长度（包含自身的 4 字节）
    /// 对应 Bun NewReader.length()
    public func readLength(): ?UInt32 {
        let len = readUInt32()
        match (len) {
            case Some(l) => {
                if (l > 0 && !ensureCapacity(l - 4)) {
                    None
                } else {
                    Some(l)
                }
            }
            case None => None
        }
    }

    /// 检查并匹配固定消息（用于 BindComplete, ParseComplete 等）
    /// 对应 Bun NewReader.eatMessage()
    public func eatMessage(expected: Array<UInt8>): Bool {
        if (pos + expected.size > buffer.size) {
            return false
        }
        for (i in 0..expected.size) {
            if (buffer[pos + i] != expected[i]) {
                return false
            }
        }
        pos += expected.size
        return true
    }

    /// 读取指定数量的字节并返回 SQLData
    public func readData(count: Int64): ?SQLData {
        match (readBytes(count)) {
            case Some(bytes) => Some(SQLData(temporary: bytes))
            case None => None
        }
    }
}
