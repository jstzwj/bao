// 翻译自 Bun: src/runtime/bake/shared.ts
// 共享的文本编解码器工具

package bao_runtime.bake

/// 共享的 TextDecoder 实例
/// 对应 Bun: shared.ts export const td = new TextDecoder()
public class TextDecoder {
    private var decoder: std.text.TextDecoder

    public init() {
        decoder = std.text.TextDecoder()
    }

    /// 将字节数组解码为字符串
    public func decode(buffer: Array<Byte>): String {
        return decoder.decode(buffer)
    }

    /// 将缓冲区的子范围解码为字符串
    public func decode(buffer: Array<Byte>, start: Int64, length: Int64): String {
        return decoder.decode(buffer.slice(start, start + length))
    }
}

/// 共享的 TextEncoder 实例
/// 对应 Bun: shared.ts export const te = new TextEncoder()
public class TextEncoder {
    private var encoder: std.text.TextEncoder

    public init() {
        encoder = std.text.TextEncoder()
    }

    /// 将字符串编码为字节数组
    public func encode(str: String): Array<Byte> {
        return encoder.encode(str)
    }

    /// 将字符串编码到指定的目标缓冲区
    /// 返回实际写入的字节数和读取的字符数
    public func encodeInto(str: String, dest: Array<Byte>): EncodeResult {
        return encoder.encodeInto(str, dest)
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
