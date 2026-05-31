// MySQL 长度编码整数 (Length-Encoded Integer) 编码/解码
// 严格翻译自: src/sql/mysql/protocol/EncodeInt.zig
package bao_runtime.sql.mysql

import bao_core.*

/// 长度编码整数的编解码工具
/// 对应 Bun: EncodeInt.zig
/// MySQL 协议使用变长编码来节省空间

/// 编码长度整数为字节数组
/// 对应 Bun: encodeLengthInt
/// 返回最多 9 字节的编码结果
public func encodeLengthInt(value: UInt64): Array<UInt8> {
    if (value < 0xfb) {
        let arr = Array<UInt8>(1, item: 0)
        arr[0] = UInt8(value)
        return arr
    } else if (value < 0xffff) {
        let arr = Array<UInt8>(3, item: 0)
        arr[0] = 0xfc
        arr[1] = UInt8(value & 0xff)
        arr[2] = UInt8((value >> 8) & 0xff)
        return arr
    } else if (value < 0xffffff) {
        let arr = Array<UInt8>(4, item: 0)
        arr[0] = 0xfd
        arr[1] = UInt8(value & 0xff)
        arr[2] = UInt8((value >> 8) & 0xff)
        arr[3] = UInt8((value >> 16) & 0xff)
        return arr
    } else {
        let arr = Array<UInt8>(9, item: 0)
        arr[0] = 0xfe
        arr[1] = UInt8(value & 0xff)
        arr[2] = UInt8((value >> 8) & 0xff)
        arr[3] = UInt8((value >> 16) & 0xff)
        arr[4] = UInt8((value >> 24) & 0xff)
        arr[5] = UInt8((value >> 32) & 0xff)
        arr[6] = UInt8((value >> 40) & 0xff)
        arr[7] = UInt8((value >> 48) & 0xff)
        arr[8] = UInt8((value >> 56) & 0xff)
        return arr
    }
}

/// 长度编码整数解码结果
public class LengthIntResult {
    public var value: UInt64
    public var bytesRead: Int64

    public init(value: UInt64, bytesRead: Int64) {
        this.value = value
        this.bytesRead = bytesRead
    }
}

/// 从字节数组解码长度编码整数
/// 对应 Bun: decodeLengthInt
public func decodeLengthInt(bytes: Array<UInt8>): ?LengthIntResult {
    if (bytes.size == 0) {
        return None
    }

    let firstByte = bytes[0]

    if (firstByte == 0xfc) {
        if (bytes.size < 3) {
            return None
        }
        return LengthIntResult(
            UInt64(bytes[1]) | (UInt64(bytes[2]) << 8),
            3
        )
    } else if (firstByte == 0xfd) {
        if (bytes.size < 4) {
            return None
        }
        return LengthIntResult(
            UInt64(bytes[1]) |
                (UInt64(bytes[2]) << 8) |
                (UInt64(bytes[3]) << 16),
            4
        )
    } else if (firstByte == 0xfe) {
        if (bytes.size < 9) {
            return None
        }
        return LengthIntResult(
            UInt64(bytes[1]) |
                (UInt64(bytes[2]) << 8) |
                (UInt64(bytes[3]) << 16) |
                (UInt64(bytes[4]) << 24) |
                (UInt64(bytes[5]) << 32) |
                (UInt64(bytes[6]) << 40) |
                (UInt64(bytes[7]) << 48) |
                (UInt64(bytes[8]) << 56),
            9
        )
    } else {
        return LengthIntResult(UInt64(firstByte), 1)
    }
}

/// 从字节切片(使用起止索引)解码长度编码整数
/// 用于从大 buffer 中的偏移位置解码
public func decodeLengthIntFromSlice(buffer: Array<UInt8>, offset: Int64): ?LengthIntResult {
    if (offset >= buffer.size) {
        return None
    }
    let firstByte = buffer[offset]

    if (firstByte == 0xfc) {
        if (offset + 3 > buffer.size) {
            return None
        }
        return LengthIntResult(
            UInt64(buffer[offset + 1]) | (UInt64(buffer[offset + 2]) << 8),
            3
        )
    } else if (firstByte == 0xfd) {
        if (offset + 4 > buffer.size) {
            return None
        }
        return LengthIntResult(
            UInt64(buffer[offset + 1]) |
                (UInt64(buffer[offset + 2]) << 8) |
                (UInt64(buffer[offset + 3]) << 16),
            4
        )
    } else if (firstByte == 0xfe) {
        if (offset + 9 > buffer.size) {
            return None
        }
        return LengthIntResult(
            UInt64(buffer[offset + 1]) |
                (UInt64(buffer[offset + 2]) << 8) |
                (UInt64(buffer[offset + 3]) << 16) |
                (UInt64(buffer[offset + 4]) << 24) |
                (UInt64(buffer[offset + 5]) << 32) |
                (UInt64(buffer[offset + 6]) << 40) |
                (UInt64(buffer[offset + 7]) << 48) |
                (UInt64(buffer[offset + 8]) << 56),
            9
        )
    } else {
        return LengthIntResult(UInt64(firstByte), 1)
    }
}
