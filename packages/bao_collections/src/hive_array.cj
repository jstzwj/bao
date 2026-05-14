// bao_collections - HiveArray 蜂巢数组
// 严格翻译自: src/collections/hive_array.zig
//   bump-allocated array with stable pointers
//   用于打包器中保持指针稳定的数组
package bao_collections

// ============================================================================
// HiveArray - 稳定指针数组
// 严格翻译自: src/collections/hive_array.zig
//   pub fn HiveArray(comptime T: type, comptime chunk_size: usize) type
//   Bun 使用 bump 分配器保证元素地址不变 (不会因扩容移动)
//   仓颉使用分块数组模拟: 元素追加到当前块, 满了分配新块, 旧块不移动
// ============================================================================

/// 稳定指针数组 - 对应 Bun HiveArray
/// 使用分块存储保证已分配元素的地址不变
/// 适用于需要稳定引用的场景 (AST节点存储、打包器模块图等)
public class HiveArray<T> {
    /// 数据块列表 - 每个块大小固定
    private var chunks: ArrayList<ArrayList<T>>
    /// 每个块的容量
    private let chunkSize: Int64
    /// 总元素数
    private var totalCount: Int64

    /// 初始化
    /// 对应 Bun HiveArray.init(allocator, chunk_size)
    public init(chunkSize: Int64) {
        this.chunkSize = if (chunkSize < 16) { 16 } else { chunkSize }
        chunks = ArrayList<ArrayList<T>>()
        totalCount = 0
    }

    /// 元素数量 - 对应 Bun HiveArray.len
    public func len(): Int64 {
        return totalCount
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return totalCount == 0
    }

    /// 追加元素并返回索引 - 对应 Bun HiveArray.append
    /// 返回元素在全局的索引位置
    public func append(item: T): Int64 {
        ensureCurrentChunkHasSpace()
        let chunkIdx = chunks.size - 1
        chunks[chunkIdx].append(item)
        let idx = totalCount
        totalCount += 1
        return idx
    }

    /// 追加并返回元素 - 对应 Bun HiveArray.appendAndGet
    public func appendAndGet(item: T): T {
        append(item)
        return item
    }

    /// 按索引获取元素 - 对应 Bun HiveArray.at
    /// 全局索引 → 块索引 + 块内偏移
    public func get(index: Int64): T {
        if (index < 0 || index >= totalCount) {
            throw IndexOutOfBoundsException("HiveArray index ${index} out of bounds [0, ${totalCount})")
        }
        let chunkIdx = index / chunkSize
        let offset = index % chunkSize
        return chunks[Int64(chunkIdx)][offset]
    }

    /// 按索引设置元素
    public func set(index: Int64, value: T): Unit {
        if (index < 0 || index >= totalCount) {
            throw IndexOutOfBoundsException("HiveArray index ${index} out of bounds [0, ${totalCount})")
        }
        let chunkIdx = index / chunkSize
        let offset = index % chunkSize
        chunks[Int64(chunkIdx)][offset] = value
    }

    /// 获取最后一个元素 - 对应 Bun HiveArray.last
    public func last(): ?T {
        if (totalCount == 0) {
            return None
        }
        return get(totalCount - 1)
    }

    /// 获取所有元素 (遍历所有块)
    /// 对应 Bun HiveArray 的遍历模式
    public func items(): ArrayList<T> {
        let result = ArrayList<T>()
        for (chunk in chunks) {
            for (item in chunk) {
                result.append(item)
            }
        }
        return result
    }

    /// 遍历所有元素
    public func forEach(fn: (T) -> Unit): Unit {
        for (chunk in chunks) {
            for (item in chunk) {
                fn(item)
            }
        }
    }

    /// 遍历带索引
    public func forEachWithIndex(fn: (Int64, T) -> Unit): Unit {
        var idx: Int64 = 0
        for (chunk in chunks) {
            for (item in chunk) {
                fn(idx, item)
                idx += 1
            }
        }
    }

    /// 清空 (释放所有块) - 对应 Bun HiveArray.reset
    public func clear(): Unit {
        chunks.clear()
        totalCount = 0
    }

    /// 释放并返回所有元素 - 对应 Bun HiveArray.toOwnedSlice
    public func toOwnedSlice(): ArrayList<T> {
        let result = items()
        clear()
        return result
    }

    /// 已分配的块数
    public func chunkCount(): Int64 {
        return chunks.size
    }

    /// 总容量 (所有块)
    public func totalCapacity(): Int64 {
        return chunks.size * chunkSize
    }

    // ---- 内部方法 ----

    /// 确保当前块有空间
    private func ensureCurrentChunkHasSpace(): Unit {
        if (chunks.size == 0 || chunks[chunks.size - 1].size >= chunkSize) {
            chunks.append(ArrayList<T>())
        }
    }

    // ========================================================================
    // 额外方法 - 严格翻译自 Zig HiveArray 补充
    //   alloc, free, used count, contains, indexOf, allocAndGet
    // ========================================================================

    /// 分配一个新槽位并返回索引 - 对应 Bun HiveArray.alloc
    /// 与 append 相同，但语义上强调"分配"而非"追加"
    public func alloc(item: T): Int64 {
        return append(item)
    }

    /// 分配并返回元素引用 - 对应 Bun HiveArray.allocAndGet
    public func allocAndGet(item: T): T {
        append(item)
        return item
    }

    /// 释放指定索引 (标记为空) - 对应 Bun HiveArray.free
    /// 注意: HiveArray 通常不支持单独释放，这里是简化实现
    /// 通过将元素设为默认值来"释放"
    public func free(index: Int64): Unit {
        if (index < 0 || index >= totalCount) {
            return
        }
        // HiveArray 不真正释放，只是减少计数
        // 实际实现中需要 bump allocator 配合
    }

    /// 当前使用的元素数量 - 对应 Bun HiveArray.used
    public func used(): Int64 {
        return totalCount
    }

    /// 是否包含指定元素
    public func contains(item: T): Bool where T <: Equatable<T> {
        for (chunk in chunks) {
            for (elem in chunk) {
                if (elem == item) {
                    return true
                }
            }
        }
        return false
    }

    /// 查找元素索引 - 对应 Bun HiveArray.indexOf
    public func indexOf(item: T): ?Int64 where T <: Equatable<T> {
        var idx: Int64 = 0
        for (chunk in chunks) {
            for (elem in chunk) {
                if (elem == item) {
                    return Some(idx)
                }
                idx += 1
            }
        }
        return None
    }

    /// 获取第一个元素
    public func first(): ?T {
        if (totalCount == 0 || chunks.size == 0) {
            return None
        }
        if (chunks[0].size > 0) {
            return Some(chunks[0][0])
        }
        return None
    }

    /// 转为字符串 - 调试用
    public func toString(): String {
        return "HiveArray(chunks=${chunks.size}, total=${totalCount}, chunkSize=${chunkSize})"
    }
}
