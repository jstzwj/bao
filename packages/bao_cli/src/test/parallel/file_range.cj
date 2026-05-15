// 严格翻译自: src/cli/test/parallel/FileRange.zig
package bao_cli

// ============================================================================
// FileRange — 连续的文件索引范围
// 严格翻译自: src/cli/test/parallel/FileRange.zig
//
// Coordinator.files 的连续切片, 分配给一个 worker
// 调度从前面取 (缓存热区), 偷取从后面取 (远离所有者的热区)
// ============================================================================

/// 文件范围: [lo, hi) 半开区间
public class FileRange {
    /// 下界 (包含)
    public var lo: Int64

    /// 上界 (不包含)
    public var hi: Int64

    public init() {
        lo = 0
        hi = 0
    }

    public init(lo: Int64, hi: Int64) {
        this.lo = lo
        this.hi = hi
    }

    /// 范围长度
    public func len(): Int64 {
        return hi - lo
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return lo >= hi
    }

    /// 从前面弹出一个元素 (缓存热区)
    /// 对应 Bun: FileRange.popFront()
    public func popFront(): ?Int64 {
        if (isEmpty()) {
            return None
        }
        val val_ = lo
        lo += 1
        return Some(val_)
    }

    /// 从后面偷取一半作为新的连续范围, 前半留给所有者
    /// 对应 Bun: FileRange.stealBackHalf()
    ///
    /// 偷取者通过 popFront 向前遍历偷取的块,
    /// 所以两个 worker 都保持目录局部性
    /// 对于 len()==1, 唯一的文件给偷取者
    /// (所有者要么已经在飞行中, 要么从未被启动)
    public func stealBackHalf(): ?FileRange {
        if (isEmpty()) {
            return None
        }
        val mid = lo + len() / 2
        val stolen = FileRange(mid, hi)
        hi = mid
        return Some(stolen)
    }
}
