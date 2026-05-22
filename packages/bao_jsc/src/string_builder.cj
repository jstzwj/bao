// 严格翻译自: src/jsc/StringBuilder.zig
// 字符串构建器 - 高效构建字符串的缓冲区

package bao_jsc

import bao_collections.*

// ========== StringBuilder ==========
// 严格翻译自 StringBuilder (WTF.StringBuilder)
// 高效构建字符串的缓冲区
public class StringBuilder {
    public var buffer: ArrayList<UInt8> = ArrayList<UInt8>()
    public var length: Int64 = 0

    public init() {}

    // 追加字符串
    public func append(str: String): String {
        let bytes = str.toArray()
        for (b in bytes) {
            buffer.append(b)
        }
        length += str.size
        str
    }

    // 追加单个字符
    public func append(r: Rune): Unit {
        let s = String(r)
        let bytes = s.toArray()
        for (b in bytes) {
            buffer.append(b)
        }
        length += s.size
    }

    // 返回构建的字符串
    public func toString(): String {
        String.fromUtf8(buffer.items())
    }

    // 分配缓冲区空间
    public func allocate(capacity: Int64) {
        if (capacity > buffer.size) {
            buffer = ArrayList<UInt8>()

        }
    }

    // 返回已分配的切片
    public func allocatedSlice(): Array<UInt8> {
        buffer.items()
    }

    // 返回长度
    public func len(): Int64 {
        length
    }

    // 重置
    public func deinit() {
        buffer = ArrayList<UInt8>()
        length = 0
    }
}
