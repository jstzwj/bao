// bao_core - 字符串类型
// 对应 Bun: src/bun_core/string/mod.rs, src/string/
package bao_core

// ============================================================================
// BaoString - 核心字符串类型
// 对应 Bun: ZigString / String
// Bun 使用指针标记的 5 变体字符串:
//   - ZigString (借用的 UTF-8 切片)
//   - StaticZigString (静态字符串)
//   - WTFStringImpl (WebKit 堆分配)
//   - Empty
//   - Dead
// 仓颉使用 GC 管理，简化为统一的字符串包装
// ============================================================================

/// 字符串编码类型
public enum StringEncoding {
    | UTF8
    | UTF16
    | Latin1
}

/// 核心字符串类型
/// 对应 Bun 的 ZigString + String 联合体
public class BaoString {
    private var data: Array<UInt8>
    private var encoding: StringEncoding

    public init() {
        data = []
        encoding = StringEncoding.UTF8
    }

    public init(value: String) {
        data = []
        encoding = StringEncoding.UTF8
        for (b in value.toArray()) {
            data.append(UInt8(b))
        }
    }

    public init(bytes: Array<UInt8>) {
        data = bytes
        encoding = StringEncoding.UTF8
    }

    public init(bytes: Array<UInt8>, encoding: StringEncoding) {
        data = bytes
        this.encoding = encoding
    }

    /// 从 UTF-8 字节数组借用 (对应 Bun: ZigString.borrowUTF8)
    public static func borrowUtf8(bytes: Array<UInt8>): BaoString {
        return BaoString(bytes, StringEncoding.UTF8)
    }

    /// 从 UTF-16 数组创建 (对应 Bun: ZigString.borrowUTF16)
    public static func fromUtf16(chars: Array<UInt16>): BaoString {
        // UTF-16 → UTF-8 转码
        var bytes = Array<UInt8>()
        for (ch in chars) {
            if (ch < 0x80) {
                bytes.append(UInt8(ch))
            } else if (ch < 0x800) {
                bytes.append(UInt8(0xC0 | (ch >> 6)))
                bytes.append(UInt8(0x80 | (ch & 0x3F)))
            } else {
                bytes.append(UInt8(0xE0 | (ch >> 12)))
                bytes.append(UInt8(0x80 | ((ch >> 6) & 0x3F)))
                bytes.append(UInt8(0x80 | (ch & 0x3F)))
            }
        }
        return BaoString(bytes, StringEncoding.UTF8)
    }

    /// 获取 UTF-8 字节视图
    public func utf8(): Array<UInt8> {
        return data
    }

    /// 获取字符串长度 (字节数)
    public func byteLength(): Int64 {
        return data.size
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return data.size == 0
    }

    /// 转为仓颉原生字符串
    public func toString(): String {
        var sb = StringBuilder()
        for (b in data) {
            sb.append(Char(b))
        }
        return sb.toString()
    }

    /// 克隆
    public func clone(): BaoString {
        return BaoString(Array<UInt8>(data), encoding)
    }

    /// 比较相等
    public func equals(other: BaoString): Bool {
        if (data.size != other.data.size) {
            return false
        }
        for (i in 0..data.size) {
            if (data[i] != other.data[i]) {
                return false
            }
        }
        return true
    }

    /// 连接
    public func concat(other: BaoString): BaoString {
        var result = Array<UInt8>()
        for (b in data) {
            result.append(b)
        }
        for (b in other.data) {
            result.append(b)
        }
        return BaoString(result)
    }

    /// 子字符串 (字节偏移)
    public func slice(start: Int64, end: Int64): BaoString {
        var result = Array<UInt8>()
        let s = if (start < 0) { 0 } else { start }
        let e = if (end > data.size) { data.size } else { end }
        for (i in s..e) {
            result.append(data[i])
        }
        return BaoString(result)
    }

    /// 获取编码
    public func getEncoding(): StringEncoding {
        return encoding
    }
}

// ============================================================================
// StringBuilder - 高效字符串构建器
// 对应 Bun: src/string/StringBuilder.zig
// ============================================================================

/// 高效字符串构建器
public class BaoStringBuilder {
    private var chunks: ArrayList<BaoString>
    private var totalLength: Int64

    public init() {
        chunks = ArrayList<BaoString>()
        totalLength = 0
    }

    /// 追加字符串
    public func append(s: BaoString): BaoStringBuilder {
        chunks.append(s)
        totalLength += s.byteLength()
        return this
    }

    /// 追加原生字符串
    public func append(s: String): BaoStringBuilder {
        chunks.append(BaoString(s))
        totalLength += s.size
        return this
    }

    /// 追加单字节
    public func appendByte(b: UInt8): BaoStringBuilder {
        chunks.append(BaoString([b]))
        totalLength += 1
        return this
    }

    /// 追加换行
    public func newline(): BaoStringBuilder {
        return append("\n")
    }

    /// 获取总长度
    public func length(): Int64 {
        return totalLength
    }

    /// 构建最终字符串
    public func build(): BaoString {
        var result = Array<UInt8>()
        // 预分配
        // result = Array<UInt8>(totalLength, item: 0) // TODO: 检查初始化方式
        for (chunk in chunks) {
            for (b in chunk.utf8()) {
                result.append(b)
            }
        }
        return BaoString(result)
    }

    /// 清空
    public func clear(): Unit {
        chunks.clear()
        totalLength = 0
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return totalLength == 0
    }
}

// ============================================================================
// HashedString - 预哈希字符串
// 对应 Bun: src/string/HashedString.zig
// ============================================================================

/// 预计算哈希的字符串，用于快速比较
public class HashedString {
    public let value: BaoString
    public let hash: UInt64

    public init(value: BaoString) {
        this.value = value
        this.hash = HashedString.computeHash(value)
    }

    public init(value: String) {
        this.value = BaoString(value)
        this.hash = HashedString.computeHash(this.value)
    }

    /// 计算字符串哈希 (使用 FNV-1a 算法)
    public static func computeHash(s: BaoString): UInt64 {
        var h: UInt64 = 14695981039346656037
        for (b in s.utf8()) {
            h = h ^ UInt64(b)
            h = h * 1099511628211
        }
        return h
    }

    /// 比较相等 (先比哈希再比内容)
    public func equals(other: HashedString): Bool {
        if (this.hash != other.hash) {
            return false
        }
        return this.value.equals(other.value)
    }
}
