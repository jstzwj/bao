// PostgreSQL 协议写入器
// 严格翻译自: bun/src/sql/postgres/protocol/NewWriter.zig + ArrayList.zig
// 提供向字节缓冲区写入 PostgreSQL 协议消息的工具方法
package bao_runtime.sql.postgresql

import bao_runtime.sql.shared.*

/// PostgreSQL 协议字节写入器
/// 支持向动态缓冲区写入协议消息
/// 对应 Bun NewWriter + ArrayList 的功能
public class ProtocolWriter {
    private var buffer: Array<UInt8>

    public init() {
        buffer = Array<UInt8>()
    }

    public init(capacity: Int64) {
        buffer = Array<UInt8>(capacity)
    }

    /// 当前写入偏移量
    /// 对应 Bun NewWriter.offset()
    public func offset(): Int64 {
        buffer.size
    }

    /// 获取底层缓冲区
    public func getBuffer(): Array<UInt8> {
        buffer
    }

    /// 写入原始字节
    /// 对应 Bun NewWriter.write()
    public func write(data: Array<UInt8>) {
        for (b in data) {
            buffer.append(b)
        }
    }

    /// 在指定位置写入字节（覆盖）
    /// 对应 Bun NewWriter.pwrite()
    public func pwrite(data: Array<UInt8>, index: Int64) {
        for (i in 0..data.size) {
            buffer[index + i] = data[i]
        }
    }

    /// 写入单个字节
    public func writeByte(b: UInt8) {
        buffer.append(b)
    }

    /// 写入 UInt32（大端字节序）
    /// 对应 Bun NewWriter.int4()
    public func writeInt4(value: UInt32) {
        let bytes = int32BigEndian(value)
        write(bytes)
    }

    /// 写入 Int64（大端字节序）
    /// 对应 Bun NewWriter.int8()
    public func writeInt8(value: Int64) {
        let b0 = UInt8((value >> 56) & 0xFF)
        let b1 = UInt8((value >> 48) & 0xFF)
        let b2 = UInt8((value >> 40) & 0xFF)
        let b3 = UInt8((value >> 32) & 0xFF)
        let b4 = UInt8((value >> 24) & 0xFF)
        let b5 = UInt8((value >> 16) & 0xFF)
        let b6 = UInt8((value >> 8) & 0xFF)
        let b7 = UInt8(value & 0xFF)
        write([b0, b1, b2, b3, b4, b5, b6, b7])
    }

    /// 写入有符号 Int32（大端字节序）
    /// 对应 Bun NewWriter.sint4()
    public func writeSInt4(value: Int32) {
        writeInt4(UInt32(value))
    }

    /// 写入 Float64（大端字节序）
    /// 对应 Bun NewWriter.f64()
    public func writeFloat64(value: Float64) {
        // 通过 UInt64 位模式转换
        let bits = UInt64(value)
        writeInt8(Int64(bits))
    }

    /// 写入 Float32（大端字节序）
    /// 对应 Bun NewWriter.f32()
    public func writeFloat32(value: Float32) {
        let bits = UInt32(value)
        writeInt4(bits)
    }

    /// 写入 UInt16（大端字节序）
    /// 对应 Bun NewWriter.short()
    public func writeShort(value: UInt16) {
        write(int16BigEndian(value))
    }

    /// 写入 null 终止的字符串
    /// 对应 Bun NewWriter.string()
    public func writeString(s: String) {
        for (c in s) {
            buffer.append(UInt8(c))
        }
        buffer.append(0)  // null 终止符
    }

    /// 写入字节（带 null 终止符）
    /// 对应 Bun NewWriter.bytes()
    public func writeBytes(data: Array<UInt8>) {
        for (b in data) {
            buffer.append(b)
        }
        if (data.size == 0 || data[data.size - 1] != 0) {
            buffer.append(0)
        }
    }

    /// 写入布尔值
    /// 对应 Bun NewWriter.bool()
    public func writeBool(value: Bool) {
        if (value) {
            buffer.append(116)  // 't'
        } else {
            buffer.append(102)  // 'f'
        }
    }

    /// 写入 NULL 标记
    /// 对应 Bun NewWriter.null()
    public func writeNull() {
        writeInt4(UInt32.MAX)  // -1 的无符号表示
    }

    /// 创建长度写入器
    /// 在当前位置写入占位 0，稍后通过 LengthWriter 填充实际长度
    /// 对应 Bun NewWriter.length()
    public func writeLengthPlaceholder(): LengthWriter {
        let index = offset()
        writeInt4(0)  // 占位
        LengthWriter(writer: this, index: index)
    }

    /// 清空缓冲区
    public func clear() {
        buffer = Array<UInt8>()
    }
}

/// 长度写入器 - 用于在消息写入完成后回填长度
/// 对应 Bun NewWriter.LengthWriter
public class LengthWriter {
    public let writer: ProtocolWriter
    public let index: Int64

    public init(writer: ProtocolWriter, index: Int64) {
        this.writer = writer
        this.index = index
    }

    /// 回填消息长度（包含自身的 4 字节）
    /// 对应 Bun LengthWriter.write()
    public func write() {
        let length = writer.offset() - index
        writer.pwrite(int32BigEndian(UInt32(length)), index)
    }

    /// 回填消息长度（不包含自身的 4 字节）
    /// 对应 Bun LengthWriter.writeExcludingSelf()
    public func writeExcludingSelf() {
        let length = writer.offset() - index - 4
        writer.pwrite(int32BigEndian(UInt32(length)), index)
    }
}
