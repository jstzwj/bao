// MySQL 长度编码整数编解码
// 对应 Bun: src/sql/mysql/protocol/EncodeInt.zig
package bao_sql.mysql.protocol

/// MySQL 长度编码整数结果
/// 对应 Bun: decodeLengthInt 返回的匿名结构体
public class LengthIntResult {
    public var value: UInt64
    public var bytesRead: Int64

    public init(value: UInt64, bytesRead: Int64) {
        this.value = value
        this.bytesRead = bytesRead
    }
}

/// MySQL 长度编码整数工具
/// 对应 Bun: EncodeInt
///
/// MySQL 协议使用长度编码整数来紧凑地表示整数值:
/// - 值 < 0xfb: 1 字节
/// - 值 < 0xffff: 3 字节 (0xfc 前缀 + 2 字节小端)
/// - 值 < 0xffffff: 4 字节 (0xfd 前缀 + 3 字节小端)
/// - 其他: 9 字节 (0xfe 前缀 + 8 字节小端)
public class EncodeInt {

    /// 编码长度整数
    /// 对应 Bun: encodeLengthInt
    public static func encodeLengthInt(value: UInt64): Array<UInt8> {
        if (value < 0xfb) {
            let result = Array<UInt8>(1, repeat: UInt8(0))
            result[0] = UInt8(value)
            return result
        } else if (value < 0xffff) {
            let result = Array<UInt8>(3, repeat: UInt8(0))
            result[0] = 0xfc
            result[1] = UInt8(value & 0xff)
            result[2] = UInt8((value >> 8) & 0xff)
            return result
        } else if (value < 0xffffff) {
            let result = Array<UInt8>(4, repeat: UInt8(0))
            result[0] = 0xfd
            result[1] = UInt8(value & 0xff)
            result[2] = UInt8((value >> 8) & 0xff)
            result[3] = UInt8((value >> 16) & 0xff)
            return result
        } else {
            let result = Array<UInt8>(9, repeat: UInt8(0))
            result[0] = 0xfe
            result[1] = UInt8(value & 0xff)
            result[2] = UInt8((value >> 8) & 0xff)
            result[3] = UInt8((value >> 16) & 0xff)
            result[4] = UInt8((value >> 24) & 0xff)
            result[5] = UInt8((value >> 32) & 0xff)
            result[6] = UInt8((value >> 40) & 0xff)
            result[7] = UInt8((value >> 48) & 0xff)
            result[8] = UInt8((value >> 56) & 0xff)
            return result
        }
    }

    /// 解码长度编码整数
    /// 对应 Bun: decodeLengthInt
    public static func decodeLengthInt(bytes: Array<UInt8>): ?LengthIntResult {
        if (bytes.size == 0) {
            return None
        }

        let firstByte = bytes[0]

        if (firstByte == UInt8(0xfc)) {
            if (bytes.size < 3) { return None }
            let value = UInt64(bytes[1]) | (UInt64(bytes[2]) << 8)
            return Some(LengthIntResult(value, 3))
        } else if (firstByte == UInt8(0xfd)) {
            if (bytes.size < 4) { return None }
            let value = UInt64(bytes[1]) |
                (UInt64(bytes[2]) << 8) |
                (UInt64(bytes[3]) << 16)
            return Some(LengthIntResult(value, 4))
        } else if (firstByte == UInt8(0xfe)) {
            if (bytes.size < 9) { return None }
            let value = UInt64(bytes[1]) |
                (UInt64(bytes[2]) << 8) |
                (UInt64(bytes[3]) << 16) |
                (UInt64(bytes[4]) << 24) |
                (UInt64(bytes[5]) << 32) |
                (UInt64(bytes[6]) << 40) |
                (UInt64(bytes[7]) << 48) |
                (UInt64(bytes[8]) << 56)
            return Some(LengthIntResult(value, 9))
        } else {
            return Some(LengthIntResult(UInt64(firstByte), 1))
        }
    }
}
