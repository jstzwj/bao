// 严格翻译自: src/bundler/IndexStringMap.zig (~26行)
// bao_bundler - 索引字符串映射: Index(Int) -> String 的哈希映射
package bao_bundler

import bao_core.*
import bao_collections.*

// ============================================================================
// IndexStringMap - 索引到字符串的映射
// 严格翻译自: src/bundler/IndexStringMap.zig:1-26
// Bun: const IndexStringMap = @This();
//
// 将 Index.Int (UInt32) 映射到字符串值
// 用于在打包过程中跟踪索引到路径/名称的映射
// ============================================================================

/// 索引字符串映射 - 对应 Bun IndexStringMap
/// Bun: const IndexStringMap = @This(); { map: std.AutoArrayHashMapUnmanaged(Index.Int, []const u8) }
/// 将 UInt32 索引映射到字符串
public class IndexStringMap {
    /// 底层映射
    /// Bun: map: std.AutoArrayHashMapUnmanaged(Index.Int, []const u8) = .{}
    private var map: HashMap<UInt32, String>

    public init() {
        map = HashMap<UInt32, String>()
    }

    /// 释放 - 对应 Bun IndexStringMap.deinit()
    /// Bun: pub fn deinit(self: *IndexStringMap, allocator: std.mem.Allocator) void
    /// 在 Bun 中, 这里会释放所有值的内存并释放 map
    /// 仓颉中使用 GC, 只需清空 map
    public func deinit(): Unit {
        map.clear()
    }

    /// 获取值 - 对应 Bun IndexStringMap.get()
    /// Bun: pub fn get(self: *const IndexStringMap, index: Index.Int) ?[]const u8
    /// 返回索引对应的字符串, 如果不存在返回 None
    public func get(index: UInt32): ?String {
        return map.get(index)
    }

    /// 存入值 - 对应 Bun IndexStringMap.put()
    /// Bun: pub fn put(self: *IndexStringMap, allocator: std.mem.Allocator, index: Index.Int, value: []const u8) !void
    /// 在 Bun 中, 这里会复制字符串值
    /// 仓颉中使用 GC, 不需要手动复制
    public func put(index: UInt32, value: String): Unit {
        map.put(index, value)
    }

    /// 是否包含键
    public func contains(index: UInt32): Bool {
        return map.containsKey(index)
    }

    /// 删除键
    public func remove(index: UInt32): Bool {
        return map.remove(index)
    }

    /// 获取或插入 - 对应 Bun getOrPut 语义
    /// 返回已存在的值, 或插入新值并返回
    public func getOrPut(index: UInt32, defaultValue: String): String {
        match (map.get(index)) {
            case Some(v) => return v
            case None => {
                map.put(index, defaultValue)
                return defaultValue
            }
        }
    }

    /// 获取条目数量
    public func count(): Int64 {
        return map.size
    }

    /// 获取所有键
    public func keys(): ArrayList<UInt32> {
        return map.keys()
    }

    /// 获取所有值
    public func values(): ArrayList<String> {
        return map.values()
    }

    /// 清空映射
    public func clear(): Unit {
        map.clear()
    }
}
