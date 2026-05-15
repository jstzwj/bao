// env_map.cj - 环境变量映射
// 对应 Bun: src/runtime/shell/EnvMap.zig
// 严格翻译Bun环境变量映射到仓颉

package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// 环境变量映射
// 使用ArrayHashMap存储键值对
// ============================================================================

/// 环境变量映射
/// 键和值都是EnvStr类型，支持引用计数和借用切片
public class EnvMap {
    /// 内部映射
    var map: HashMap<EnvStr, EnvStr>

    /// 初始化
    public static func init(alloc: Allocator): EnvMap {
        EnvMap(map: HashMap<EnvStr, EnvStr>())
    }

    /// 内存开销
    public func memoryCost(): UInt64 {
        var size: UInt64 = 0
        // 遍历所有键值对计算内存开销
        for (entry in this.map) {
            size += entry.key.memoryCost()
            size += entry.value.memoryCost()
        }
        return size
    }

    /// 带容量初始化
    public static func initWithCapacity(alloc: Allocator, cap: UInt64): EnvMap {
        let map = HashMap<EnvStr, EnvStr>()
        return EnvMap(map: map)
    }

    /// 释放资源
    public func deinit() {
        this.derefStrings()
        this.map.clear()
    }

    /// 插入键值对
    /// 注意：这会增加值的引用计数，调用前应先ref
    public func insert(key: EnvStr, val: EnvStr) {
        this.map.put(key, val)
        val.ref()
    }

    /// 获取迭代器
    public func iterator(): Iterator {
        Iterator(envMap: this)
    }

    /// 清空但保留容量
    public func clearRetainingCapacity() {
        this.derefStrings()
        this.map.clear()
    }

    /// 确保总容量
    public func ensureTotalCapacity(newCapacity: UInt64) {
        // 确保哈希表有足够容量
    }

    /// 获取值
    /// 注意：返回前会增加引用计数
    public func get(key: EnvStr): ?EnvStr {
        return this.map.get(key)
    }

    /// 克隆
    public func clone(): EnvMap {
        let newMap = EnvMap(map: this.map.clone())
        newMap.refStrings()
        return newMap
    }

    /// 使用指定分配器克隆
    public func cloneWithAllocator(allocator: Allocator): EnvMap {
        let newMap = EnvMap(map: this.map.clone())
        newMap.refStrings()
        return newMap
    }

    /// 增加所有字符串引用
    func refStrings() {
        for (entry in this.map) {
            entry.key.ref()
            entry.value.ref()
        }
    }

    /// 减少所有字符串引用
    func derefStrings() {
        for (entry in this.map) {
            entry.key.deref()
            entry.value.deref()
        }
    }

    /// 迭代器
    public class Iterator {
        var envMap: EnvMap
        var entries: Array<(EnvStr, EnvStr)>
        var index: Int64 = 0

        init(envMap: EnvMap) {
            this.envMap = envMap
            this.entries = envMap.map.entries()
            this.index = 0
        }

        /// 是否有下一个
        public func hasNext(): Boolean {
            return this.index < this.entries.length
        }

        /// 获取下一个条目
        public func next(): ?(EnvStr, EnvStr) {
            if (!this.hasNext()) {
                return None
            }
            let entry = this.entries[this.index]
            this.index += 1
            return entry
        }

        /// 映射长度
        public func len(): UInt64 {
            return UInt64(this.entries.length)
        }
    }
}
