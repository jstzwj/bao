// 翻译自 Bun: src/runtime/bake/DevServer/Assets.zig
// 用于 /_bun/asset/{hash}.ext 上的哈希资产存储

package bao_runtime

/// 哈希资产存储。通过 /_bun/asset/{hash}.ext 提供。
/// 键是绝对路径，与 IncrementalGraph(.client) 中的键共享内存。
/// 值是文件的索引。
public class Assets {
    /// 键是绝对路径，与 IncrementalGraph(.client) 中的键共享内存
    public var path_map: StringArrayHashMapUnmanaged<EntryIndex>
    /// 内容寻址存储。多个路径可以指向相同的内容哈希
    public var files: AutoArrayHashMapUnmanaged<UInt64, StaticRoute>
    /// 与 files 索引相同。值永远不为 0。
    public var refs: ArrayListUnmanaged<UInt32>
    /// 当 files 的键被修改时，map 必须重新索引
    public var needs_reindex: Bool = false

    /// EntryIndex
    public struct EntryIndex <: UInt30 {}

    /// 获取路径对应的哈希值
    public func getHash(path: String): ?UInt64 {
        if (let Some(idx) = path_map.get(path)) {
            return files.keys()[idx.get()]
        }
        return None
    }

    /// 当资产被覆盖时，它会获得新的 URL 以绕过浏览器缓存。
    /// 旧的 URL 立即被撤销。
    public func replacePath(
        abs_path: String,
        contents: AnyBlob,
        mime_type: MimeType,
        content_hash: UInt64,
    ): EntryIndex {
        let alloc = owner().allocator()

        let gop = path_map.getOrPut(alloc, abs_path)
        if (!gop.found_existing) {
            let stable_abs_path = owner().client_graph.insertEmpty(abs_path, FileKind.unknown).key
            gop.key_ptr = stable_abs_path
        } else {
            let entry_index = gop.value_ptr
            // 当资产只有一个引用时，可以原地替换
            if (refs.items[entry_index.get()] == 1) {
                let prev = files.values()[entry_index.get()]
                prev.deref()
                files.keys()[entry_index.get()] = content_hash
                files.values()[entry_index.get()] = StaticRoute.initFromAnyBlob(contents, StaticRouteOptions(
                    mime_type: mime_type,
                    server: owner().server!,
                ))
                needs_reindex = true
                return entry_index
            } else {
                refs.items[entry_index.get()] -= 1
            }
        }

        reindexIfNeeded(alloc)
        let file_index_gop = files.getOrPut(alloc, content_hash)
        if (!file_index_gop.found_existing) {
            refs.append(alloc, 1)
            file_index_gop.value_ptr = StaticRoute.initFromAnyBlob(contents, StaticRouteOptions(
                mime_type: mime_type,
                server: owner().server!,
            ))
        } else {
            refs.items[file_index_gop.index] += 1
            var contents_mut = contents
            contents_mut.detach()
        }
        gop.value_ptr = EntryIndex.init(file_index_gop.index)
        return gop.value_ptr
    }

    /// 放入或增加引用计数
    public func putOrIncrementRefCount(content_hash: UInt64, ref_count: UInt32): ?StaticRouteRef {
        let file_index_gop = files.getOrPut(owner().allocator(), content_hash)
        if (!file_index_gop.found_existing) {
            refs.append(owner().allocator(), ref_count)
            return file_index_gop.value_ptr
        } else {
            refs.items[file_index_gop.index] += ref_count
            return None
        }
    }

    /// 按哈希取消引用
    public func unrefByHash(content_hash: UInt64, dec_count: UInt32): Unit {
        let index = files.getIndex(content_hash) ?? panic("Asset double unref")
        unrefByIndex(EntryIndex.init(index), dec_count)
    }

    /// 按索引取消引用
    public func unrefByIndex(index: EntryIndex, dec_count: UInt32): Unit {
        assert(dec_count > 0)
        refs.items[index.get()] -= dec_count
        if (refs.items[index.get()] == 0) {
            files.values()[index.get()].deref()
            files.swapRemoveAt(index.get())
            refs.swapRemove(index.get())
            // swapRemove 将旧的最后索引处的条目移到了 index 的位置
            let moved_from: UInt32 = UInt32(files.count())
            if (moved_from != index.get()) {
                for (entry_index in path_map.values()) {
                    if (entry_index.get() == moved_from) {
                        entry_index = index
                    }
                }
            }
        }
    }

    /// 按路径取消引用
    public func unrefByPath(path: String): Unit {
        let entry = path_map.fetchSwapRemove(path) ?? return
        unrefByIndex(entry.value, 1)
    }

    /// 按需重新索引
    public func reindexIfNeeded(alloc: Allocator): Unit {
        if (needs_reindex) {
            files.reIndex(alloc)
            needs_reindex = false
        }
    }

    /// 获取资产
    public func get(content_hash: UInt64): ?StaticRoute {
        return files.get(content_hash)
    }

    /// 析构
    public func deinit(alloc: Allocator): Unit {
        path_map.deinit(alloc)
        for (blob in files.values()) {
            blob.deref()
        }
        files.deinit(alloc)
        refs.deinit(alloc)
    }

    /// 内存成本
    public func memoryCost(): UInt64 {
        var cost: UInt64 = 0
        cost += DevServer.memoryCostArrayHashMap(path_map)
        for (blob in files.values()) {
            cost += blob.memoryCost()
        }
        cost += DevServer.memoryCostArrayHashMap(files)
        cost += DevServer.memoryCostArrayList(refs)
        return cost
    }

    func owner(): DevServer {
        // 通过字段指针获取父 DevServer
    }
}

// 类型别名
public type StaticRoute = bun.api.server.StaticRoute
public type AnyBlob = jsc.WebCore.Blob.Any
public type MimeType = bun.http.MimeType
public type StaticRouteRef = StaticRoute
public type StaticRouteOptions = bun.api.server.StaticRoute.Options
public type StringArrayHashMapUnmanaged<V> = std.StringArrayHashMapUnmanaged<V>
public type AutoArrayHashMapUnmanaged<K, V> = std.AutoArrayHashMapUnmanaged<K, V>
public type ArrayListUnmanaged<T> = std.ArrayListUnmanaged<T>
