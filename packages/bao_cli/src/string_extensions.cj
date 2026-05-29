package bao_cli

import bao_collections.*

extend String {
    public func substring(startIndex: Int64, endIndex: Int64): String {
        if (startIndex < 0) { return "" }
        if (endIndex > this.size) { return this[Int64(startIndex)..Int64(this.size)] }
        if (startIndex >= endIndex) { return "" }
        return this[Int64(startIndex)..Int64(endIndex)]
    }

    public func substring(startIndex: Int64): String {
        if (startIndex < 0) { return "" }
        if (startIndex >= this.size) { return "" }
        return this[Int64(startIndex)..Int64(this.size)]
    }

    public func indexOfFrom(startIndex: Int64, ch: UInt8): ?Int64 {
        var i = startIndex
        while (i < this.size) {
            if (this[i] == ch) {
                return Some(i)
            }
            i += 1
        }
        return None
    }

    /// 转换为小写 (ASCII)
    public func toLower(): String {
        var result = ""
        for (ch in this) {
            if (ch >= UInt8('A') && ch <= UInt8('Z')) {
                result = result + String(Rune(ch + UInt8(32)))
            } else {
                result = result + String(Rune(ch))
            }
        }
        return result
    }

    /// 重复字符串 n 次
    public func repeat(n: Int64): String {
        var result = ""
        var i: Int64 = 0
        while (i < n) {
            result = result + this
            i += 1
        }
        return result
    }
}

extend ArrayList<String> {
    /// 用分隔符连接字符串列表
    public func join(separator: String): String {
        var result = ""
        var i: Int64 = 0
        while (i < this.size) {
            if (i > 0) { result = result + separator }
            result = result + this[i]
            i += 1
        }
        return result
    }

    /// 获取子列表
    public func slice(start: Int64, end: Int64): ArrayList<String> {
        let result = ArrayList<String>()
        var i = start
        while (i < end && i < this.size) {
            result.append(this[i])
            i += 1
        }
        return result
    }
}
