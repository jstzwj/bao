// 翻译自 Bun: src/runtime/bake/shared.ts
// 共享的文本编解码器工具

package bao_runtime.bake

/// 共享的 TextDecoder 实例
/// 对应 Bun: shared.ts export const td = new TextDecoder()
public class TextDecoder {

    public init() {}

    /// 将字节数组解码为字符串
    public func decode(buffer: Array<Byte>): String {
        return String.fromUtf8(buffer)
    }

    /// 将缓冲区的子范围解码为字符串
    public func decode(buffer: Array<Byte>, start: Int64, length: Int64): String {
        var sub = Array<Byte>()
        var i = start
        while (i < start + length && i < buffer.size) {
            sub.append(buffer[Int64(i)])
            i++
        }
        return String.fromUtf8(sub)
    }
}

/// 共享的 TextEncoder 实例
/// 对应 Bun: shared.ts export const te = new TextEncoder()
public class TextEncoder {

    public init() {}

    /// 将字符串编码为字节数组
    public func encode(str: String): Array<Byte> {
        return str.toArray()
    }

    /// 将字符串编码到指定的目标缓冲区
    /// 返回实际写入的字节数和读取的字符数
    public func encodeInto(str: String, dest: Array<Byte>): EncodeResult {
        let bytes = str.toArray()
        var i = 0
        while (i < bytes.size && i < dest.size) {
            dest[i] = bytes[i]
            i++
        }
        return EncodeResult(read: Int64(str.size), written: Int64(i))
    }
}

/// 编码结果
public class EncodeResult {
    /// 读取的字符数
    public var read: Int64
    /// 写入的字节数
    public var written: Int64

    public init(read: Int64, written: Int64) {
        this.read = read
        this.written = written
    }
}

/// 全局共享实例
public let td: TextDecoder = TextDecoder()
public let te: TextEncoder = TextEncoder()
