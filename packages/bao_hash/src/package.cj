// bao_hash - 哈希算法
// 对应 Bun: src/hash/, src/wyhash/, src/highway/
package bao_hash

import bao_core.*

// ============================================================================
// WyHash - 快速非加密哈希
// 对应 Bun: src/wyhash/
// ============================================================================

/// WyHash 快速哈希算法实现
public class WyHash {
    private static let WYP0: UInt64 = 0xa0761d6478bd642f
    private static let WYP1: UInt64 = 0xe7037ed1a0b428db
    private static let WYP2: UInt64 = 0x8ebc6af09c88c6e3
    private static let WYP3: UInt64 = 0x589965cc75374cc3
    private static let WYP4: UInt64 = 0x1d8e4e27c47d124f

    /// 计算字节数组的哈希值
    public static func hash(data: Array<UInt8>): UInt64 {
        return hashWithSeed(data, 0)
    }

    /// 带种子的哈希
    public static func hashWithSeed(data: Array<UInt8>, seed: UInt64): UInt64 {
        let len = data.size
        var seedMut = seed

        if (len <= 16) {
            return wyhash16(data, seedMut, len)
        }

        // 使用 wymix 处理数据块
        var i: Int64 = 0
        seedMut = seedMut ^ WYP0

        var a: UInt64 = 0
        var b: UInt64 = 0

        if (len <= 64) {
            // 小数据: 逐块处理
            while (i + 16 <= len) {
                a = readUInt64(data, i)
                b = readUInt64(data, i + 8)
                seedMut = seedMut ^ (wymix(a ^ WYP1, b ^ WYP2))
                i += 16
            }
            // 处理尾部
            if (i < len) {
                a = readUInt64(data, len - 8)
                b = readUInt64(data, len - 16)
                seedMut = seedMut ^ (wymix(a ^ WYP3, b ^ WYP4))
            }
            return wymix(seedMut, UInt64(len) ^ WYP0)
        }

        // 大数据: 使用更大的块
        var see1 = seedMut
        var see2 = seedMut
        while (i + 64 <= len) {
            seedMut = seedMut ^ (wymix(readUInt64(data, i) ^ WYP1, readUInt64(data, i + 8) ^ WYP2))
            see1 = see1 ^ (wymix(readUInt64(data, i + 16) ^ WYP3, readUInt64(data, i + 24) ^ WYP4))
            see2 = see2 ^ (wymix(readUInt64(data, i + 32) ^ WYP2, readUInt64(data, i + 40) ^ WYP1))
            seedMut = seedMut ^ (wymix(readUInt64(data, i + 48) ^ WYP4, readUInt64(data, i + 56) ^ WYP3))
            i += 64
        }

        // 处理剩余
        while (i + 16 <= len) {
            seedMut = seedMut ^ (wymix(readUInt64(data, i) ^ WYP1, readUInt64(data, i + 8) ^ WYP2))
            i += 16
        }
        if (i < len) {
            seedMut = seedMut ^ (wymix(readUInt64(data, len - 16) ^ WYP1, readUInt64(data, len - 8) ^ WYP2))
        }

        return wymix(seedMut ^ see1 ^ see2, UInt64(len) ^ WYP0)
    }

    /// 计算字符串哈希
    public static func hash(s: String): UInt64 {
        var bytes = Array<UInt8>()
        for (c in s) {
            bytes.append(UInt8(c.value))
        }
        return hash(bytes)
    }

    private static func wyhash16(data: Array<UInt8>, seed: UInt64, len: Int64): UInt64 {
        if (len <= 3) {
            var a: UInt64 = if (len > 0) { UInt64(data[0]) } else { 0 }
            var b: UInt64 = if (len > 1) { UInt64(data[len / 2]) } else { 0 }
            return wymix(a ^ (seed ^ WYP0), b ^ (seed ^ WYP1))
        }
        if (len <= 8) {
            let a = readUInt64(data, 0)
            let b = readUInt64(data, len - 4)
            return wymix(a ^ (seed ^ WYP0), b ^ (seed ^ WYP1))
        }
        // 9-16 字节
        let a = readUInt64(data, 0)
        let b = readUInt64(data, len - 8)
        return wymix(a ^ (seed ^ WYP0), b ^ (seed ^ WYP1))
    }

    private static func wymix(a: UInt64, b: UInt64): UInt64 {
        var x = a
        var y = b
        x = x ^ (x >> 32)
        y = y ^ (y >> 32)
        // 简化的乘法混合
        return (x * WYP1) ^ (y * WYP2)
    }

    private static func readUInt64(data: Array<UInt8>, offset: Int64): UInt64 {
        var result: UInt64 = 0
        let end = if (offset + 8 <= data.size) { offset + 8 } else { data.size }
        for (i in offset..end) {
            result = result | (UInt64(data[i]) << UInt64((i - offset) * 8))
        }
        return result
    }
}

// ============================================================================
// CRC32 校验
// ============================================================================

/// CRC32 校验算法
public class Crc32 {
    /// CRC32 查找表
    private static let TABLE: Array<UInt32> = buildTable()

    /// 计算 CRC32
    public static func hash(data: Array<UInt8>): UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for (b in data) {
            let index = Int32((crc ^ UInt32(b)) & 0xFF)
            crc = TABLE[index] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }

    /// 计算字符串的 CRC32
    public static func hash(s: String): UInt32 {
        var bytes = Array<UInt8>()
        for (c in s) {
            bytes.append(UInt8(c.value))
        }
        return hash(bytes)
    }

    private static func buildTable(): Array<UInt32> {
        var table = Array<UInt32>(256, item: UInt32(0))
        for (i in 0..256) {
            var crc = UInt32(i)
            for (_ in 0..8) {
                if ((crc & 1) != 0) {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc = crc >> 1
                }
            }
            table[i] = crc
        }
        return table
    }
}

// ============================================================================
// FNV-1a 哈希
// ============================================================================

/// FNV-1a 哈希算法
public class Fnv1a {
    private static let FNV_OFFSET_BASIS: UInt64 = 14695981039346656037
    private static let FNV_PRIME: UInt64 = 1099511628211

    /// 计算 FNV-1a 哈希
    public static func hash(data: Array<UInt8>): UInt64 {
        var h = FNV_OFFSET_BASIS
        for (b in data) {
            h = h ^ UInt64(b)
            h = h * FNV_PRIME
        }
        return h
    }

    /// 计算字符串的 FNV-1a 哈希
    public static func hash(s: String): UInt64 {
        var h = FNV_OFFSET_BASIS
        for (c in s) {
            h = h ^ UInt64(c.value)
            h = h * FNV_PRIME
        }
        return h
    }
}
