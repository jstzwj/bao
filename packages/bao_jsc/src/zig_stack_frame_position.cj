// 严格翻译自: src/jsc/ZigStackFramePosition.zig
// Zig 栈帧位置 - 源代码中的行和列信息

package bao_jsc

// ========== ZigStackFramePosition ==========
// 严格翻译自 ZigStackFramePosition
// 表示源代码中带有行和列信息的位置
public class ZigStackFramePosition {
    public var line: Ordinal = Ordinal.invalid
    public var column: Ordinal = Ordinal.invalid
    // -1 如果不存在
    public var lineStartByte: Int32 = -1

    public init() {}

    public init(line: Ordinal, column: Ordinal, lineStartByte: Int32) {
        this.line = line
        this.column = column
        this.lineStartByte = lineStartByte
    }

    // 严格翻译自 ZigStackFramePosition.invalid
    public static func invalid(): ZigStackFramePosition {
        ZigStackFramePosition(
            Ordinal.invalid,
            Ordinal.invalid,
            -1
        )
    }

    // 严格翻译自 ZigStackFramePosition.isInvalid
    public func isInvalid(): Bool {
        line == Ordinal.invalid && column == Ordinal.invalid && lineStartByte == -1
    }

    // 严格翻译自 ZigStackFramePosition.decode
    public static func decode(reader: ByteReader): ZigStackFramePosition {
        ZigStackFramePosition(
            Ordinal.fromZeroBased(reader.readInt32()),
            Ordinal.fromZeroBased(reader.readInt32()),
            -1
        )
    }

    // 严格翻译自 ZigStackFramePosition.encode
    public func encode(writer: ByteWriter) {
        writer.writeInt32(line.zeroBased())
        writer.writeInt32(column.zeroBased())
    }
}

// ========== Ordinal ==========
// 严格翻译自 bun.Ordinal
public class Ordinal {
    public var value: Int32 = 0

    public init() {}
    public init(v: Int32) { value = v }

    public static let invalid: Ordinal = Ordinal(-1)

    public func zeroBased(): Int32 { value }
    public static func fromZeroBased(v: Int32): Ordinal { Ordinal(v) }

    public func equals(other: Ordinal): Bool {
        value == other.value
    }

    public operator func >(right: Int64): Bool {
        Int64(value) > right
    }

    public operator func <(right: Int64): Bool {
        Int64(value) < right
    }

    public operator func ==(right: Ordinal): Bool {
        value == right.value
    }

    public operator func !=(right: Ordinal): Bool {
        value != right.value
    }
}

// 支撑类型
public class ByteReader { public func readInt32(): Int32 { 0 } }
public class ByteWriter { public func writeInt32(v: Int32) {} }
