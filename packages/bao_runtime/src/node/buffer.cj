// Buffer 向量化填充操作
// 对应 Bun: src/runtime/node/buffer.zig
// 严格翻译自: src/runtime/node/buffer.zig
package bao_runtime.node

import bao_core.*

// ============================================================================
// BufferVectorized — Buffer 高效填充
// 对应 Bun: src/runtime/node/buffer.zig - BufferVectorized
// ============================================================================
public class BufferVectorized {
    // 使用指定编码的字符串填充 buffer
    // 对应 Bun: src/runtime/node/buffer.zig - BufferVectorized.fill
    public static func fill(data: Array<UInt8>, fillBytes: Array<UInt8>): Bool {
        let fillLength = fillBytes.size
        if (fillLength == 0) {
            return true
        }

        let dataLen = data.size
        if (dataLen == 0) {
            return true
        }

        // 如果填充模式长度为1，使用 memset 优化
        if (fillLength == 1) {
            let byte = fillBytes[0]
            for (i in 0..dataLen) {
                data[i] = byte
            }
            return true
        }

        // 通用模式填充
        var offset: Int64 = 0
        while (offset < dataLen) {
            let remaining = dataLen - offset
            let copyLen = if (remaining < fillLength) { remaining } else { fillLength }
            for (i in 0..copyLen) {
                data[offset + i] = fillBytes[i]
            }
            offset += copyLen
        }

        return true
    }

    // 使用单个字节值填充 buffer
    public static func fillByte(data: Array<UInt8>, value: UInt8): Bool {
        for (i in 0..data.size) {
            data[i] = value
        }
        return true
    }

    // 使用字符串填充 buffer（按指定编码）
    public static func fillString(data: Array<UInt8>, str: String, encoding: Encoding): Bool {
        let bytes = encodeString(str, encoding)
        if (bytes.size == 0) {
            return true
        }
        return fill(data, bytes)
    }

    // 将字符串编码为字节数组
    private static func encodeString(str: String, encoding: Encoding): Array<UInt8> {
        match (encoding) {
            case Encoding.utf8 => BaoString(str).utf8()
            case Encoding.ascii =>
                let arr = Array<UInt8>(str.size, { _ => UInt8(0) })
                for (i in 0..str.size) {
                    arr[i] = UInt8(str[i])
                }
                return arr
            case Encoding.hex =>
                // hex 编码：每两个字符表示一个字节
                let arr = Array<UInt8>(str.size / 2, { _ => UInt8(0) })
                for (i in 0..arr.size) {
                    let high = hexCharToNibble(str[i * 2])
                    let low = hexCharToNibble(str[i * 2 + 1])
                    arr[i] = high * 16 + low
                }
                return arr
            case _ => BaoString(str).utf8()
        }
    }

    // 十六进制字符转换为数值
    private static func hexCharToNibble(c: UInt8): UInt8 {
        if (c >= 0x30 && c <= 0x39) {
            return c - 0x30
        }
        if (c >= 0x61 && c <= 0x66) {
            return c - 0x61 + 10
        }
        if (c >= 0x41 && c <= 0x46) {
            return c - 0x41 + 10
        }
        return 0
    }
}
