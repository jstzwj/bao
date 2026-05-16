// 严格翻译自: src/sql/postgres/protocol/NewWriter.zig
// PostgreSQL 协议写入器
package bao_sql.postgres.protocol

import std.collection.ArrayList as StdArrayList
import bao_sql.postgres.types.IntTypes

/// PostgreSQL 协议写入器接口
/// 对应 Bun: NewWriter (generic type)
public interface NewWriter<C> {
    /// 获取当前偏移量
    func offset(): Int64

    /// 写入字节
    func write(bytes: Array<UInt8>): Unit

    /// 在指定位置写入字节
    func pwrite(bytes: Array<UInt8>, pos: Int64): Unit

    /// 写入 int4
    func int4(value: UInt32): Unit

    /// 写入 int8
    func int8(value: Int64): Unit

    /// 写入 short
    func short(value: UInt16): Unit

    /// 写入字符串 (null 结尾)
    func string(value: String): Unit

    /// 写入 bool ('t' 或 'f')
    func writeBool(value: Bool): Unit

    /// 写入 null 标记
    func writeNull(): Unit
}

/// 基于 ArrayList 的默认写入器实现
/// 对应 Bun: ArrayList (writer)
public class ArrayListWriter {
    public var buffer: StdArrayList<UInt8>

    public init() {
        buffer = StdArrayList<UInt8>()
    }

    /// 获取当前偏移量
    /// 对应 Bun: ArrayList.offset
    public func offset(): Int64 {
        return buffer.size
    }

    /// 写入字节
    /// 对应 Bun: ArrayList.write
    public func write(bytes: Array<UInt8>): Unit {
        for (i in 0..bytes.size) {
            buffer.add(bytes[Int64(i)])
        }
    }

    /// 在指定位置写入字节
    /// 对应 Bun: ArrayList.pwrite
    public func pwrite(bytes: Array<UInt8>, pos: Int64): Unit {
        for (i in 0..bytes.size) {
            buffer[Int64(pos + Int64(i))] = bytes[Int64(i)]
        }
    }

    /// 写入 int4 (大端)
    public func int4(value: UInt32): Unit {
        let bytes = IntTypes.int32(value)
        write(bytes)
    }

    /// 写入 int8 (大端)
    public func int8(value: Int64): Unit {
        let arr = Array<UInt8>(8, repeat: UInt8(0))
        arr[0] = UInt8((value >> 56) & 0xFF)
        arr[1] = UInt8((value >> 48) & 0xFF)
        arr[2] = UInt8((value >> 40) & 0xFF)
        arr[3] = UInt8((value >> 32) & 0xFF)
        arr[4] = UInt8((value >> 24) & 0xFF)
        arr[5] = UInt8((value >> 16) & 0xFF)
        arr[6] = UInt8((value >> 8) & 0xFF)
        arr[7] = UInt8(value & 0xFF)
        write(arr)
    }

    /// 写入 short (大端)
    public func short(value: UInt16): Unit {
        let arr = Array<UInt8>(2, repeat: UInt8(0))
        arr[0] = UInt8((value >> 8) & 0xFF)
        arr[1] = UInt8(value & 0xFF)
        write(arr)
    }

    /// 写入字符串 (null 结尾)
    /// 对应 Bun: NewWriter.string
    public func string(value: String): Unit {
        for (i in 0..value.size) {
            buffer.add(UInt8(value[Int64(i)]))
        }
        buffer.add(UInt8(0))
    }

    /// 写入 bool ('t' 或 'f')
    /// 对应 Bun: NewWriter.bool
    public func writeBool(value: Bool): Unit {
        if (value) {
            buffer.add(UInt8(116))
        } else {
            buffer.add(UInt8(102))
        }
    }

    /// 写入 null 标记 (max int4)
    /// 对应 Bun: NewWriter.null
    public func writeNull(): Unit {
        int4(4294967295)
    }

    /// 创建长度写入器
    /// 对应 Bun: NewWriter.LengthWriter
    public func length(): LengthWriter {
        let index = offset()
        int4(0)
        return LengthWriter(this, index)
    }

    /// 获取写入缓冲区的副本
    public func bytes(): Array<UInt8> {
        let result = Array<UInt8>(buffer.size, repeat: UInt8(0))
        for (i in 0..buffer.size) {
            result[Int64(i)] = buffer[Int64(i)]
        }
        return result
    }
}

/// 长度写入器 - 记录写入位置并在完成后回填长度
/// 对应 Bun: NewWriter.LengthWriter
public class LengthWriter {
    public let index: Int64
    public let writer: ArrayListWriter

    public init(writer: ArrayListWriter, index: Int64) {
        this.writer = writer
        this.index = index
    }

    /// 写入长度到之前记录的位置
    /// 对应 Bun: LengthWriter.write
    public func write(): Unit {
        let len = IntTypes.int32(UInt32(writer.offset() - index))
        writer.pwrite(len, index)
    }

    /// 写入长度 (不包括自身 4 字节)
    /// 对应 Bun: LengthWriter.writeExcludingSelf
    public func writeExcludingSelf(): Unit {
        let len = IntTypes.int32(UInt32(writer.offset() - (index + 4)))
        writer.pwrite(len, index)
    }
}
