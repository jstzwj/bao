// 严格翻译自: src/jsc/StringBuilder.zig
// 字符串构建器 - 高效构建字符串的缓冲区

package bao_jsc

// ========== StringBuilder ==========
// 严格翻译自 StringBuilder (WTF.StringBuilder)
// 高效构建字符串的缓冲区
public class StringBuilder {
    public var buffer: Array<UInt8> = []
    public var length: Int64 = 0

    public init() {}

    // 严格翻译自 StringBuilder.count (string)
    // 计算字符串所需的缓冲区空间
    public func count(str: String) {
        let bytes = str.toArray()
        for (b in bytes) {
            buffer.append(b)
        }
        length += str.size
    }

    // 严格翻译自 StringBuilder.count (with format)
    public func countFormat(format: String, args: Array<Any>) {
        let formatted = String.format(format, args)
        count(str: formatted)
    }

    // 严格翻译自 StringBuilder.allocate
    // 分配缓冲区空间
    public func allocate(capacity: Int64) {
        if (capacity > buffer.size) {
            buffer = Array<UInt8>(capacity, item: 0)
        }
    }

    // 严格翻译自 StringBuilder.append
    // 追加字符串并返回切片
    public func append(str: String) -> String {
        length += str.size
        str
    }

    // 严格翻译自 StringBuilder.allocatedSlice
    // 返回已分配的切片
    public func allocatedSlice() -> Array<UInt8> {
        buffer
    }

    // 严格翻译自 StringBuilder.len
    public func len() -> Int64 {
        length
    }

    // 严格翻译自 StringBuilder.deinit
    public func deinit() {
        buffer = []
        length = 0
    }
}
