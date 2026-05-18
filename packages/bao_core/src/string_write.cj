// bao_core - 字符串写入 trait
// 严格翻译自: src/bun_core/string/write.rs
//   pub type Result<T = ()> = core::result::Result<T, crate::Error>;
//   pub use crate::io::{IntLe, Write};
//   pub trait IntBe: Copy { ... }
// Bun: Canonical byte-oriented Write trait — single port of Zig std.Io.Writer
// 仓颉: 提供等价的字节写入接口和大端序编码辅助
package bao_core

// ============================================================================
// Write - 字节写入接口
// 严格翻译自: src/bun_core/string/write.rs Write trait
//   pub use crate::io::{IntLe, Write};
//   对应 Zig 的 std.Io.Writer
// ============================================================================

/// 字节写入接口 - 对应 Bun Write trait / Zig std.Io.Writer
public interface ByteWrite {
    /// 写入字节切片
    func write(bytes: Array<UInt8>): Int64

    /// 写入全部字节
    func writeAll(bytes: Array<UInt8>): Unit

    /// 刷新缓冲区
    func flush(): Unit
}

/// 写入结果类型 - 对应 Bun Result<T = ()>
public type WriteResult<T> = ?T

// ============================================================================
// IntLe - 小端序整数编码辅助
// 严格翻译自: src/bun_core/string/write.rs IntLe
//   pub trait IntLe: Copy { type Bytes; fn to_le_bytes(self) -> Self::Bytes; fn from_le_bytes(bytes) -> Self; }
// ============================================================================

/// 小端序整数编码 - 对应 Bun IntLe
public class IntLe {
    /// Int64 转小端字节数组
    public static func toLeBytes(value: Int64): Array<UInt8> {
        var result = Array<UInt8>(8, { _ => UInt8(0) })
        var v = UInt64(value)
        for (i in 0..8) {
            result[i] = UInt8(v & UInt64(0xFF))
            v = v >> 8
        }
        return result
    }

    /// Int32 转小端字节数组
    public static func toLeBytes32(value: Int32): Array<UInt8> {
        var result = Array<UInt8>(4, { _ => UInt8(0) })
        var v = UInt32(value)
        for (i in 0..4) {
            result[i] = UInt8(v & UInt32(0xFF))
            v = v >> 8
        }
        return result
    }

    /// UInt16 转小端字节数组
    public static func toLeBytes16(value: UInt16): Array<UInt8> {
        var result = Array<UInt8>(2, { _ => UInt8(0) })
        result[0] = UInt8(value & UInt16(0xFF))
        result[1] = UInt8((value >> 8) & UInt16(0xFF))
        return result
    }

    /// 小端字节数组转 Int64
    public static func fromLeBytesI64(bytes: Array<UInt8>): Int64 {
        var result: UInt64 = 0
        for (i in 0..8) {
            if (i < bytes.size) {
                result = result | (UInt64(bytes[i]) << (i * 8))
            }
        }
        return Int64(result)
    }

    /// 小端字节数组转 Int32
    public static func fromLeBytesI32(bytes: Array<UInt8>): Int32 {
        var result: UInt32 = 0
        for (i in 0..4) {
            if (i < bytes.size) {
                result = result | (UInt32(bytes[i]) << (i * 8))
            }
        }
        return Int32(result)
    }
}

// ============================================================================
// IntBe - 大端序 (网络序) 整数编码辅助
// 严格翻译自: src/bun_core/string/write.rs IntBe
//   pub trait IntBe: Copy { type Bytes; fn to_be_bytes(self) -> Self::Bytes; fn from_be_bytes(bytes) -> Self; }
//   用于 HTTP/2 线格式写入器
// ============================================================================

/// 大端序 (网络序) 整数编码 - 对应 Bun IntBe
public class IntBe {
    /// Int64 转大端字节数组
    public static func toBeBytes(value: Int64): Array<UInt8> {
        var result = Array<UInt8>(8, { _ => UInt8(0) })
        var v = UInt64(value)
        var i = 7
        while (i >= 0) {
            result[Int64(i)] = UInt8(v & UInt64(0xFF))
            v = v >> 8
            i -= 1
        }
        return result
    }

    /// Int32 转大端字节数组
    public static func toBeBytes32(value: Int32): Array<UInt8> {
        var result = Array<UInt8>(4, { _ => UInt8(0) })
        var v = UInt32(value)
        var i = 3
        while (i >= 0) {
            result[Int64(i)] = UInt8(v & UInt32(0xFF))
            v = v >> 8
            i -= 1
        }
        return result
    }

    /// UInt16 转大端字节数组
    public static func toBeBytes16(value: UInt16): Array<UInt8> {
        var result = Array<UInt8>(2, { _ => UInt8(0) })
        result[0] = UInt8((value >> 8) & UInt16(0xFF))
        result[1] = UInt8(value & UInt16(0xFF))
        return result
    }

    /// 大端字节数组转 Int64
    public static func fromBeBytesI64(bytes: Array<UInt8>): Int64 {
        var result: UInt64 = 0
        for (i in 0..8) {
            if (i < bytes.size) {
                result = (result << 8) | UInt64(bytes[Int64(i)])
            }
        }
        return Int64(result)
    }

    /// 大端字节数组转 Int32
    public static func fromBeBytesI32(bytes: Array<UInt8>): Int32 {
        var result: UInt32 = 0
        for (i in 0..4) {
            if (i < bytes.size) {
                result = (result << 8) | UInt32(bytes[Int64(i)])
            }
        }
        return Int32(result)
    }

    /// 大端字节数组转 UInt16
    public static func fromBeBytesU16(bytes: Array<UInt8>): UInt16 {
        if (bytes.size < 2) {
            return UInt16(0)
        }
        return (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
    }
}
