// 严格翻译自: src/runtime/cli/test/parallel/FileRange.zig
//   Contiguous slice of `Coordinator.files` owned by a worker. Dispatching
//   pulls from the front (cache-hot region); stealing takes from the back
//   (furthest from the owner's hot region).
package bao_runtime.test_runner

// ============================================================================
// FileRange — 文件范围 (并行测试调度)
// 严格翻译自: src/runtime/cli/test/parallel/FileRange.zig - FileRange
//
// 用于并行测试中工作窃取 (work-stealing) 调度:
//   - 每个 Worker 持有一段连续的文件索引范围 [lo, hi)
//   - popFront() 从前端取出 (cache-hot 区域)
//   - stealBackHalf() 从后半段窃取任务给其他 Worker
// ============================================================================

/// 文件范围 — 并行测试调度中的连续文件索引区间
/// 对应 Bun: FileRange (pub const FileRange = @This())
///
/// Contiguous slice of Coordinator.files owned by a worker.
/// Dispatching pulls from the front (cache-hot region);
/// stealing takes from the back (furthest from the owner's hot region).
public class FileRange {
    /// 下界 (含)
    /// 翻译自: lo: u32
    public var lo: UInt32

    /// 上界 (不含)
    /// 翻译自: hi: u32
    public var hi: UInt32

    public init(lo: UInt32, hi: UInt32) {
        this.lo = lo
        this.hi = hi
    }

    /// 范围长度
    /// 翻译自: pub fn len(self: @This()) u32 { return self.hi - self.lo }
    public func len(): UInt32 {
        return hi - lo
    }

    /// 范围是否为空
    /// 翻译自: pub fn isEmpty(self: @This()) bool { return self.lo >= self.hi }
    public func isEmpty(): Bool {
        return lo >= hi
    }

    /// 从前端弹出一个元素
    /// 翻译自: pub fn popFront(self: *@This()) ?u32
    /// 从 cache-hot 区域取出下一个文件索引
    public func popFront(): ?UInt32 {
        if (isEmpty()) {
            return None
        }
        let result = lo
        lo = lo + UInt32(1)
        return result
    }

    /// 从后半段窃取任务
    /// 翻译自: pub fn stealBackHalf(self: *@This()) ?FileRange
    /// 将后半段作为新的连续范围分配给窃取者, 前半段留给原 Worker
    /// 对于 len()==1 的情况, 单个文件分配给窃取者
    ///   (因为原 Worker 可能已经在处理中或者从未被启动)
    public func stealBackHalf(): ?FileRange {
        if (isEmpty()) {
            return None
        }
        let mid = lo + len() / UInt32(2)
        let stolen = FileRange(mid, hi)
        hi = mid
        return stolen
    }
}
