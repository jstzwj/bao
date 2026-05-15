// 严格翻译自: src/bundler/PathToSourceIndexMap.zig (~47行)
// bao_bundler - 路径到源索引映射: 文件路径 -> Index.Int 的哈希映射
package bao_bundler

import bao_core.*
import bao_collections.*

// ============================================================================
// PathToSourceIndexMap - 路径到源索引的映射
// 严格翻译自: src/bundler/PathToSourceIndexMap.zig:1-47
// Bun: const PathToSourceIndexMap = @This();
//
// 将文件路径字符串映射到源文件索引 (Index.Int = UInt32)
// 用于在打包过程中查找路径对应的源文件索引
//
// 注意: 键的生命周期不由本 map 管理 (假设是 arena 分配的)
// ============================================================================

/// 路径到源索引映射 - 对应 Bun PathToSourceIndexMap
/// Bun: const PathToSourceIndexMap = @This(); { map: Map = .{} }
/// Bun: const Map = bun.StringHashMapUnmanaged(Index.Int)
/// 将文件路径映射到源文件索引 (UInt32)
public class PathToSourceIndexMap {
    /// 底层映射: String -> UInt32
    /// Bun: map: Map = .{}
    /// Bun: const Map = bun.StringHashMapUnmanaged(Index.Int)
    /// 注意: 键的生命周期不由本 map 管理 (假设是 arena 分配的)
    private var map: HashMap<String, UInt32>

    public init() {
        map = HashMap<String, UInt32>()
    }

    /// 通过 Path 对象获取索引 - 对应 Bun PathToSourceIndexMap.getPath()
    /// Bun: pub fn getPath(this: *const PathToSourceIndexMap, path: *const Fs.Path) ?Index.Int
    /// 接受一个 Fs.Path 对象, 使用其 text 属性查找
    public func getPath(path: FsPath): ?UInt32 {
        return get(path.text)
    }

    /// 通过字符串获取索引 - 对应 Bun PathToSourceIndexMap.get()
    /// Bun: pub fn get(this: *const PathToSourceIndexMap, text: []const u8) ?Index.Int
    /// 返回路径对应的源索引, 如果不存在返回 None
    public func get(text: String): ?UInt32 {
        return map.get(text)
    }

    /// 通过 Path 对象存入索引 - 对应 Bun PathToSourceIndexMap.putPath()
    /// Bun: pub fn putPath(this: *PathToSourceIndexMap, allocator: std.mem.Allocator, path: *const Fs.Path, value: Index.Int) bun.OOM!void
    /// 接受一个 Fs.Path 对象, 使用其 text 属性存储
    public func putPath(path: FsPath, value: UInt32): Unit {
        put(path.text, value)
    }

    /// 通过字符串存入索引 - 对应 Bun PathToSourceIndexMap.put()
    /// Bun: pub fn put(this: *PathToSourceIndexMap, allocator: std.mem.Allocator, text: []const u8, value: Index.Int) bun.OOM!void
    public func put(text: String, value: UInt32): Unit {
        map.put(text, value)
    }

    /// 通过 Path 对象获取或插入 - 对应 Bun PathToSourceIndexMap.getOrPutPath()
    /// Bun: pub fn getOrPutPath(this: *PathToSourceIndexMap, allocator: std.mem.Allocator, path: *const Fs.Path) bun.OOM!Map.GetOrPutResult
    /// 接受一个 Fs.Path 对象, 使用其 text 属性查找或插入
    public func getOrPutPath(path: FsPath, defaultValue: UInt32): UInt32 {
        return getOrPut(path.text, defaultValue)
    }

    /// 通过字符串获取或插入 - 对应 Bun PathToSourceIndexMap.getOrPut()
    /// Bun: pub fn getOrPut(this: *PathToSourceIndexMap, allocator: std.mem.Allocator, text: []const u8) bun.OOM!Map.GetOrPutResult
    public func getOrPut(text: String, defaultValue: UInt32): UInt32 {
        match (map.get(text)) {
            case Some(v) => return v
            case None => {
                map.put(text, defaultValue)
                return defaultValue
            }
        }
    }

    /// 通过字符串删除 - 对应 Bun PathToSourceIndexMap.remove()
    /// Bun: pub fn remove(this: *PathToSourceIndexMap, text: []const u8) bool
    /// 返回是否成功删除
    public func remove(text: String): Bool {
        return map.remove(text)
    }

    /// 通过 Path 对象删除 - 对应 Bun PathToSourceIndexMap.removePath()
    /// Bun: pub fn removePath(this: *PathToSourceIndexMap, path: *const Fs.Path) bool
    public func removePath(path: FsPath): Bool {
        return remove(path.text)
    }

    /// 是否包含键
    public func contains(text: String): Bool {
        return map.containsKey(text)
    }

    /// 获取条目数量
    public func count(): Int64 {
        return map.size
    }

    /// 清空映射
    public func clear(): Unit {
        map.clear()
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 文件系统路径 - 对应 Bun Fs.Path
/// Bun: const Fs = bun.fs;
/// 简化的路径表示
public class FsPath {
    /// 路径文本
    public var text: String

    public init(text: String) {
        this.text = text
    }

    public init() {
        this.text = ""
    }

    /// 从字符串创建 - 对应 Bun Fs.Path.init()
    public static func initFunc(text: String): FsPath {
        return FsPath(text: text)
    }

    /// 获取漂亮路径
    public func pretty(): String {
        return text
    }
}
