// 翻译自 Bun: src/runtime/bake/client/data-view.ts
// HMR WebSocket 协议使用的 DataView 读写工具。

package bao_runtime.bake.client

import bao_runtime.bake.*

public class DataViewReader {
    public var view: DataView
    public var cursor: Int64

    public init(view: DataView, cursor: Int64 = 0) {
        this.view = view
        this.cursor = cursor
    }

    public func u32(): UInt32 {
        let value = view.getUint32(cursor, true)
        cursor += 4
        return value
    }

    public func i32(): Int32 {
        let value = view.getInt32(cursor, true)
        cursor += 4
        return value
    }

    public func u16(): UInt16 {
        let value = view.getUint16(cursor, true)
        cursor += 2
        return value
    }

    public func u8(): UInt8 {
        let value = view.getUint8(cursor)
        cursor += 1
        return value
    }

    public func stringWithLength(byteLength: Int64): String {
        let str = td.decode(view.buffer.slice(cursor, cursor + byteLength))
        cursor += byteLength
        return str
    }

    public func string32(): String {
        return stringWithLength(Int64(u32()))
    }

    public func hasMoreData(): Bool {
        return cursor < view.byteLength
    }

    public func rest(): Array<Byte> {
        return view.buffer.slice(cursor)
    }
}

public class DataViewWriter {
    public var view: DataView
    public var uint8ArrayView: Array<Byte>
    public var cursor: Int64
    public var capacity: Int64

    public static func initCapacity(capacity: Int64): DataViewWriter {
        let view = DataView(Array<Byte>(capacity, repeat: 0))
        return DataViewWriter(view, 0, capacity)
    }

    public init(view: DataView, cursor: Int64, capacity: Int64) {
        this.view = view
        this.cursor = cursor
        this.capacity = capacity
        this.uint8ArrayView = view.buffer
    }

    public func u8(value: UInt8): Unit {
        view.setUint8(cursor, value)
        cursor += 1
    }

    public func u32(value: UInt32): Unit {
        view.setUint32(cursor, value, true)
        cursor += 4
    }

    public func i32(value: Int32): Unit {
        view.setInt32(cursor, value, true)
        cursor += 4
    }

    public func string(value: String): Unit {
        if (value.length == 0) { return }
        let result = te.encodeInto(value, uint8ArrayView.slice(cursor))
        if (result.read != value.length) {
            throw Error("Failed to encode string")
        }
        cursor += result.written
    }

    public func stringWithLength(value: String): Unit {
        let start = cursor
        u32(0)
        string(value)
        view.setUint32(start, UInt32(cursor - start - 4), true)
    }
}

/// JavaScript DataView 的仓颉侧等价包装。
public class DataView {
    public var buffer: Array<Byte>
    public var byteLength: Int64 { get { buffer.size } }

    public init(buffer: Array<Byte>) {
        this.buffer = buffer
    }

    public func getUint8(offset: Int64): UInt8 { return UInt8(buffer[offset]) }
    public func setUint8(offset: Int64, value: UInt8): Unit { buffer[offset] = Byte(value) }

    public func getUint16(offset: Int64, littleEndian: Bool): UInt16 {
        let b0 = UInt16(buffer[offset])
        let b1 = UInt16(buffer[offset + 1])
        return if (littleEndian) { b0 | (b1 << 8) } else { (b0 << 8) | b1 }
    }

    public func getUint32(offset: Int64, littleEndian: Bool): UInt32 {
        let b0 = UInt32(buffer[offset]); let b1 = UInt32(buffer[offset + 1])
        let b2 = UInt32(buffer[offset + 2]); let b3 = UInt32(buffer[offset + 3])
        return if (littleEndian) { b0 | (b1 << 8) | (b2 << 16) | (b3 << 24) } else { (b0 << 24) | (b1 << 16) | (b2 << 8) | b3 }
    }

    public func getInt32(offset: Int64, littleEndian: Bool): Int32 { return Int32(getUint32(offset, littleEndian)) }

    public func setUint32(offset: Int64, value: UInt32, littleEndian: Bool): Unit {
        if (littleEndian) {
            buffer[offset] = Byte(value & 0xff); buffer[offset + 1] = Byte((value >> 8) & 0xff)
            buffer[offset + 2] = Byte((value >> 16) & 0xff); buffer[offset + 3] = Byte((value >> 24) & 0xff)
        } else {
            buffer[offset] = Byte((value >> 24) & 0xff); buffer[offset + 1] = Byte((value >> 16) & 0xff)
            buffer[offset + 2] = Byte((value >> 8) & 0xff); buffer[offset + 3] = Byte(value & 0xff)
        }
    }

    public func setInt32(offset: Int64, value: Int32, littleEndian: Bool): Unit { setUint32(offset, UInt32(value), littleEndian) }
}
