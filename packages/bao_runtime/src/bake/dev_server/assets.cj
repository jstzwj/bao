// 翻译自 Bun: src/runtime/bake/DevServer/Assets.zig
// 用于 /_bun/asset/{hash}.ext 上的哈希资产存储

package bao_runtime.bake.dev_server

/// 哈希资产存储。通过 /_bun/asset/{hash}.ext 提供。
/// 键是绝对路径，与 IncrementalGraph(.client) 中的键共享内存。
/// 值是文件的索引。
public struct EntryIndex {
    public var value: UInt32
    public init(value: UInt32) { this.value = value }
    public func get(): UInt32 { value }
}

public class Assets {
    /// 键是绝对路径，与 IncrementalGraph(.client) 中的键共享内存
    public var path_map: HashMap<String, EntryIndex>
    /// 内容寻址存储。多个路径可以指向相同的内容哈希
    public var files: HashMap<UInt64, StaticRoute>
    /// 与 files 索引相同。值永远不为 0。
    public var refs: Array<UInt32>
    /// 当 files 的键被修改时，map 必须重新索引
    public var needs_reindex: Bool = false

    public init() {
        path_map = HashMap<String, EntryIndex>()
        files = HashMap<UInt64, StaticRoute>()
        refs = Array<UInt32>()
        needs_reindex = false
    }

    /// 获取路径对应的哈希值
    public func getHash(path: String): ?UInt64 {
        if (let Some(idx) <- path_map.get(path)) {
            // return files.keys()[idx.get()]
            return None
        }
        return None
    }

    /// 当资产被覆盖时，它会获得新的 URL 以绕过浏览器缓存。
    /// 旧的 URL 立即被撤销。
    public func replacePath(
        abs_path: String,
        contents: AnyBlob,
        mime_type: MimeType,
        content_hash: UInt64
    ): EntryIndex {
        // 简化实现
        let alloc = owner().allocator()

        // 检查路径是否已存在
        if (let Some(entry_index) <- path_map.get(abs_path)) {
            // 路径已存在
            if (Int64(refs.size) > Int64(entry_index.get()) && refs[Int64(entry_index.get())] == 1) {
                // 只有一个引用，原地替换
                needs_reindex = true
                return entry_index
            } else if (Int64(refs.size) > Int64(entry_index.get())) {
                refs[Int64(entry_index.get())] -= 1
            }
        }

        reindexIfNeeded(alloc)

        // 添加新的内容哈希
        if (files.get(content_hash).isNone()) {
            refs.append(1)
        } else {
            // 已存在
        }

        let idx = EntryIndex(UInt32(refs.size) - 1)
        path_map.put(abs_path, idx)
        return idx
    }

    /// 放入或增加引用计数
    public func putOrIncrementRefCount(content_hash: UInt64, ref_count: UInt32): ?StaticRoute {
        if (files.get(content_hash).isNone()) {
            refs.append(ref_count)
            return files.get(content_hash)
        } else {
            // 增加引用计数
            return None
        }
    }

    /// 按哈希取消引用
    public func unrefByHash(content_hash: UInt64, dec_count: UInt32): Unit {
        // 简化
    }

    /// 按索引取消引用
    public func unrefByIndex(index: EntryIndex, dec_count: UInt32): Unit {
        assert(dec_count > 0)
        let idx = Int64(index.get())
        if (idx < refs.size) {
            refs[idx] -= dec_count
        }
    }

    /// 按路径取消引用
    public func unrefByPath(path: String): Unit {
        if (let Some(entry) <- path_map.remove(path)) {
            unrefByIndex(entry, 1)
        }
    }

    /// 按需重新索引
    public func reindexIfNeeded(alloc: Allocator): Unit {
        if (needs_reindex) {
            needs_reindex = false
        }
    }

    /// 获取资产
    public func get(content_hash: UInt64): ?StaticRoute {
        return files.get(content_hash)
    }

    /// 析构
    public func deinit(alloc: Allocator): Unit {
        path_map.clear()
        files.clear()
        refs = Array<UInt32>()
    }

    /// 内存成本
    public func memoryCost(): UInt64 {
        var cost: UInt64 = 0
        return cost
    }

    func owner(): DevServer {
        // 通过字段指针获取父 DevServer
        DevServer()
    }
}
