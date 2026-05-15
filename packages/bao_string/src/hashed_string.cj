// 严格翻译自: src/string/HashedString.zig
// 哈希字符串
//   将字符串指针、长度和哈希值打包在一起的轻量级结构
//   用于快速字符串比较(先比哈希,再比长度,最后比内容)
package bao_string

import bao_core.*

// ============================================================================
// HashedString
// 严格翻译自: src/string/HashedString.zig
// ============================================================================

/// 哈希字符串: 将字节切片的指针、长度和哈希值打包
/// 严格翻译自 HashedString.zig HashedString
public class HashedString {
    // 底层字节数据
    private var data: Array<Byte>
    // 字符串长度
    public var len: UInt32
    // 哈希值
    public var hash: UInt32

    public init(data: Array<Byte>, len: UInt32, hash: UInt32) {
        this.data = data
        this.len = len
        this.hash = hash
    }

    /// 空 HashedString
    /// 严格翻译自 HashedString.empty
    public static func empty(): HashedString {
        return HashedString(data: [], len: 0, hash: 0)
    }

    /// 从字节数组初始化,同时计算哈希
    /// 严格翻译自 HashedString.init
    public static func initFunc(buf: Array<Byte>): HashedString {
        return HashedString(
            data: buf,
            len: UInt32(buf.size),
            hash: UInt32(truncate32(hashBytes(buf)))
        )
    }

    /// 从字符串初始化,同时计算哈希
    public static func initFunc(str: String): HashedString {
        let buf = str.toArray()
        return HashedString(
            data: buf,
            len: UInt32(buf.size),
            hash: UInt32(truncate32(hashBytes(buf)))
        )
    }

    /// 从字节数组初始化,不计算哈希
    /// 严格翻译自 HashedString.initNoHash
    public static func initNoHash(buf: Array<Byte>): HashedString {
        return HashedString(
            data: buf,
            len: UInt32(buf.size),
            hash: 0
        )
    }

    /// 判断两个 HashedString 是否相等
    /// 严格翻译自 HashedString.eql
    /// 先比较哈希值(>0时),再比较指针,最后比较长度
    public func eql(other: HashedString): Bool {
        // 如果哈希值都大于0,则比较哈希;否则比较指针
        let hashMatch = (max(this.hash, other.hash) > 0 && this.hash == other.hash)
        if (hashMatch && this.len == other.len) {
            return true
        }
        // 回退:逐字节比较
        if (this.len != other.len) {
            return false
        }
        for (i in 0..Int64(this.len)) {
            if (this.data[i] != other.data[i]) {
                return false
            }
        }
        return true
    }

    /// 判断 HashedString 是否与字节数组相等
    /// 严格翻译自 HashedString.eql (非 HashedString 分支)
    public func eqlBytes(other: Array<Byte>): Bool {
        if (Int64(this.len) != other.size) {
            return false
        }
        let otherHash = UInt32(truncate32(hashBytes(other)))
        return otherHash == this.hash
    }

    /// 获取底层字节数组切片
    /// 严格翻译自 HashedString.str
    public func str(): Array<Byte> {
        if (Int64(this.len) > data.size) {
            return data
        }
        return data[0..Int64(this.len)]
    }

    /// 获取字符串表示
    public func toString(): String {
        return String.fromUtf8(str())
    }
}

// ============================================================================
// 内部辅助函数
// ============================================================================

/// 简单的 FNV-1a 哈希 (模拟 bun.hash)
/// 严格对应 Bun 的哈希行为
private func hashBytes(bytes: Array<Byte>): UInt64 {
    var hash: UInt64 = 14695981039346656037
    for (b in bytes) {
        hash = hash ^ UInt64(b)
        hash = hash * 1099511628211
    }
    return hash
}

/// 截断到 32 位
private func truncate32(value: UInt64): UInt32 {
    return UInt32(value & 0xFFFFFFFF)
}

/// 取两个 UInt32 的最大值
private func max(a: UInt32, b: UInt32): UInt32 {
    if (a > b) { return a }
    return b
}
