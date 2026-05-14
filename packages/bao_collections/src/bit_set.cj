// bao_collections - BitSet 位集合
// 严格翻译自: src/collections/bit_set.zig
//   Zig 提供多种 BitSet 变体: IntegerBitSet, ArrayBitSet, DynamicBitSet
//   仓颉使用 Array<UInt64> 统一实现，提供等价 API
package bao_collections

// ============================================================================
// BitSet - 动态位集合
// 严格翻译自: src/collections/bit_set.zig - DynamicBitSet
//   使用 usize 数组存储位掩码
//   对应 Bun: 解析器字符类追踪, bundler tree-shaking 标记
// ============================================================================

/// 动态位集合 - 对应 Bun DynamicBitSet
/// 使用 UInt64 数组存储位，支持动态扩容
public class BitSet {
    /// 底层存储 - 每个 UInt64 存储 64 位
    private var masks: ArrayList<UInt64>
    /// 位数
    private var bitCount: Int64

    /// 每个 mask 的位数
    private static let BITS_PER_MASK: Int64 = 64

    public init() {
        masks = ArrayList<UInt64>()
        bitCount = 0
    }

    public init(capacity: Int64) {
        let numMasks = (capacity + BITS_PER_MASK - 1) / BITS_PER_MASK
        masks = ArrayList<UInt64>()
        for (_ in 0..numMasks) {
            masks.append(UInt64(0))
        }
        bitCount = capacity
    }

    /// 容量 - 对应 Bun BitSet.capacity
    public func capacity(): Int64 {
        return bitCount
    }

    /// 设置位数
    public func setBitCount(count: Int64): Unit {
        let numMasks = (count + BITS_PER_MASK - 1) / BITS_PER_MASK
        while (masks.size < numMasks) {
            masks.append(UInt64(0))
        }
        bitCount = count
    }

    /// 检查指定位是否设置 - 对应 Bun BitSet.isSet
    public func isSet(index: Int64): Bool {
        if (index < 0 || index >= bitCount) {
            return false
        }
        let maskIdx = index / BITS_PER_MASK
        let bitIdx = index % BITS_PER_MASK
        if (maskIdx >= masks.size) {
            return false
        }
        return (masks[maskIdx] & (UInt64(1) << UInt64(bitIdx))) != UInt64(0)
    }

    /// 设置位 - 对应 Bun BitSet.set
    public func set(index: Int64): Unit {
        ensureCapacity(index + 1)
        let maskIdx = index / BITS_PER_MASK
        let bitIdx = index % BITS_PER_MASK
        masks[maskIdx] = masks[maskIdx] | (UInt64(1) << UInt64(bitIdx))
    }

    /// 清除位 - 对应 Bun BitSet.unset
    public func unset(index: Int64): Unit {
        if (index < 0) { return }
        let maskIdx = index / BITS_PER_MASK
        let bitIdx = index % BITS_PER_MASK
        if (maskIdx < masks.size) {
            masks[maskIdx] = masks[maskIdx] & ~(UInt64(1) << UInt64(bitIdx))
        }
    }

    /// 切换位 - 对应 Bun BitSet.toggle
    public func toggle(index: Int64): Unit {
        ensureCapacity(index + 1)
        let maskIdx = index / BITS_PER_MASK
        let bitIdx = index % BITS_PER_MASK
        masks[maskIdx] = masks[maskIdx] ^ (UInt64(1) << UInt64(bitIdx))
    }

    /// 设置范围的值 - 对应 Bun BitSet.setRangeValue
    public func setRangeValue(start: Int64, end: Int64, value: Bool): Unit {
        for (i in start..end) {
            if (i >= 0 && i < bitCount) {
                if (value) {
                    set(i)
                } else {
                    unset(i)
                }
            }
        }
    }

    /// 计算设置的位数 - 对应 Bun BitSet.count
    public func count(): Int64 {
        var total: Int64 = 0
        for (mask in masks) {
            total += popCount(mask)
        }
        return total
    }

    /// 并集操作 - 对应 Bun BitSet.setUnion
    public func setUnion(other: BitSet): Unit {
        let maxMasks = if (masks.size > other.masks.size) { masks.size } else { other.masks.size }
        ensureCapacityByMasks(maxMasks)
        for (i in 0..other.masks.size) {
            if (i < masks.size) {
                masks[i] = masks[i] | other.masks[i]
            }
        }
    }

    /// 交集操作 - 对应 Bun BitSet.setIntersection
    public func setIntersection(other: BitSet): Unit {
        let minMasks = if (masks.size < other.masks.size) { masks.size } else { other.masks.size }
        for (i in 0..minMasks) {
            masks[i] = masks[i] & other.masks[i]
        }
        for (i in minMasks..masks.size) {
            masks[i] = UInt64(0)
        }
    }

    /// 差集操作
    public func setDifference(other: BitSet): Unit {
        let minMasks = if (masks.size < other.masks.size) { masks.size } else { other.masks.size }
        for (i in 0..minMasks) {
            masks[i] = masks[i] & ~other.masks[i]
        }
    }

    /// 查找第一个设置的位 - 对应 Bun BitSet.findFirstSet
    public func findFirstSet(): ?Int64 {
        for (i in 0..masks.size) {
            if (masks[i] != UInt64(0)) {
                return Some(Int64(i) * BITS_PER_MASK + trailingZeros(masks[i]))
            }
        }
        return None
    }

    /// 查找第一个未设置的位 - 对应 Bun BitSet.findFirstUnset
    public func findFirstUnset(): ?Int64 {
        for (i in 0..bitCount) {
            if (!isSet(i)) {
                return Some(i)
            }
        }
        return None
    }

    /// 查找并清除第一个设置的位 - 对应 Bun BitSet.toggleFirstSet
    public func toggleFirstSet(): ?Int64 {
        let idx = findFirstSet()
        match (idx) {
            case Some(i) => {
                unset(i)
                return Some(i)
            }
            case None => return None
        }
    }

    /// 相等比较 - 对应 Bun BitSet.eql
    public func eql(other: BitSet): Bool {
        if (bitCount != other.bitCount) {
            return false
        }
        let maxMasks = if (masks.size > other.masks.size) { masks.size } else { other.masks.size }
        for (i in 0..maxMasks) {
            let a = if (i < masks.size) { masks[i] } else { UInt64(0) }
            let b = if (i < other.masks.size) { other.masks[i] } else { UInt64(0) }
            if (a != b) {
                return false
            }
        }
        return true
    }

    /// 子集检查 - 对应 Bun BitSet.subsetOf
    public func subsetOf(other: BitSet): Bool {
        for (i in 0..masks.size) {
            let a = masks[i]
            let b = if (i < other.masks.size) { other.masks[i] } else { UInt64(0) }
            if ((a & b) != a) {
                return false
            }
        }
        return true
    }

    /// 超集检查 - 对应 Bun BitSet.supersetOf
    public func supersetOf(other: BitSet): Bool {
        return other.subsetOf(this)
    }

    /// 是否为空
    public func isEmpty(): Bool {
        for (mask in masks) {
            if (mask != UInt64(0)) {
                return false
            }
        }
        return true
    }

    /// 清空所有位
    public func clear(): Unit {
        for (i in 0..masks.size) {
            masks[i] = UInt64(0)
        }
    }

    /// 设置所有位
    public func setAll(): Unit {
        for (i in 0..masks.size) {
            masks[i] = ~UInt64(0)
        }
    }

    /// 遍历设置的位 - 对应 Bun BitSet.iterator
    public func forEach(fn: (Int64) -> Unit): Unit {
        for (i in 0..masks.size) {
            var mask = masks[i]
            var bit: Int64 = 0
            while (mask != UInt64(0)) {
                if (mask & UInt64(1) != UInt64(0)) {
                    let idx = i * BITS_PER_MASK + bit
                    if (idx < bitCount) {
                        fn(idx)
                    }
                }
                mask = mask >> UInt64(1)
                bit += 1
            }
        }
    }

    // ---- 内部方法 ----

    /// 确保容量足够
    private func ensureCapacity(needed: Int64): Unit {
        if (needed > bitCount) {
            bitCount = needed
        }
        let numMasks = (needed + BITS_PER_MASK - 1) / BITS_PER_MASK
        while (masks.size < numMasks) {
            masks.append(UInt64(0))
        }
    }

    private func ensureCapacityByMasks(numMasks: Int64): Unit {
        while (masks.size < numMasks) {
            masks.append(UInt64(0))
        }
    }

    /// 计算 UInt64 中 1 的个数 (popcount)
    private static func popCount(v: UInt64): Int64 {
        var x = v
        x = x - ((x >> UInt64(1)) & UInt64(0x5555555555555555))
        x = (x & UInt64(0x3333333333333333)) + ((x >> UInt64(2)) & UInt64(0x3333333333333333))
        x = (x + (x >> UInt64(4))) & UInt64(0x0F0F0F0F0F0F0F0F)
        x = x + (x >> UInt64(8))
        x = x + (x >> UInt64(16))
        x = x + (x >> UInt64(32))
        return Int64(x & UInt64(0x7F))
    }

    /// 计算末尾 0 的个数 (ctz)
    private static func trailingZeros(v: UInt64): Int64 {
        if (v == UInt64(0)) { return 64 }
        var x = v
        var count: Int64 = 0
        while ((x & UInt64(1)) == UInt64(0)) {
            count += 1
            x = x >> UInt64(1)
        }
        return count
    }
}
