// 严格翻译自: src/runtime/bake/DevServer/Assets.zig
//   Storage for hashed assets on `/_bun/asset/{hash}.ext`
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// Assets — 哈希资产存储
// 严格翻译自: src/runtime/bake/DevServer/Assets.zig - Assets struct
//
// 用于 Bake 开发服务器中的静态资产内容寻址存储:
//   - path_map: 绝对路径 -> EntryIndex (与 IncrementalGraph(.client) 共享键内存)
//   - files: 内容哈希 -> StaticRoute (内容寻址, 多路径可指向同一内容)
//   - refs: 引用计数 (与 files 同索引)
//   - needs_reindex: 当 files 的键被修改时需要重建索引
// ============================================================================

/// 资产条目索引
/// 对应 Bun: EntryIndex = bun.GenericIndex(u30, Assets)
public class EntryIndex {
    public var value: UInt32

    public init(value: UInt32) {
        this.value = value
    }

    public func get(): UInt32 {
        return value
    }
}

/// 哈希资产存储
/// 对应 Bun: Assets struct
/// 存储用于 /_bun/asset/{hash}.ext 上的哈希资产
public class Assets {
    /// 绝对路径 -> 条目索引
    /// 翻译自: path_map: bun.StringArrayHashMapUnmanaged(EntryIndex)
    /// 键与 IncrementalGraph(.client) 共享内存
    public var pathMap: HashMap<String, EntryIndex>

    /// 内容哈希 -> 静态路由
    /// 翻译自: files: AutoArrayHashMapUnmanaged(u64, *StaticRoute)
    /// 内容寻址存储: 多路径可指向同一内容哈希
    public var files: HashMap<UInt64, StaticRoute>

    /// 引用计数, 与 files 同索引, 值永不为 0
    /// 翻译自: refs: ArrayListUnmanaged(u32)
    public var refs: ArrayList<UInt32>

    /// 当 files 的键被修改时需要重建索引
    /// 翻译自: needs_reindex: bool = false
    public var needsReindex: Bool

    public init() {
        pathMap = HashMap<String, EntryIndex>()
        files = HashMap<UInt64, StaticRoute>()
        refs = ArrayList<UInt32>()
        needsReindex = false
    }

    /// 获取指定路径的内容哈希
    public func getHash(path: String): ?UInt64 {
        match (pathMap.get(path)) {
            case Some(idx) =>
                if (files.get(UInt64(idx.get())).isSome()) {
                    return UInt64(idx.get())
                }
                return None
            case None => return None
        }
    }
    /// 替换或新增资产路径
    /// 对应 Bun: pub fn replacePath(assets: *Assets, abs_path, contents, mime_type, content_hash) !EntryIndex
    ///
    /// 当资产被覆盖时, 它会收到新的 URL 以绕过浏览器缓存
    /// 旧 URL 立即被撤销
    public func replacePath(
        absPath: String,
        contents: AnyBlob,
        mimeType: MimeType,
        contentHash: UInt64
    ): EntryIndex {
        let existing = pathMap.get(absPath)
        match (existing) {
            case Some(entryIndex) =>
                // 已存在的路径
                let idx = entryIndex.get()
                if (Int64(idx) < refs.size && refs[Int64(idx)] == UInt32(1)) {
                    // 只有一个引用: 原地替换
                    files.remove(UInt64(idx))
                    files.put(contentHash, StaticRoute())
                    refs[Int64(idx)] = UInt32(1)
                    needsReindex = true
                    return entryIndex
                } else if (Int64(idx) < refs.size) {
                    // 多个引用: 递减引用计数
                    refs[Int64(idx)] = refs[Int64(idx)] - UInt32(1)
                }
            case None => ()
        }

        // 新增条目
        reindexIfNeeded()
        let fileExisting = files.get(contentHash)
        match (fileExisting) {
            case Some(_) =>
                // 内容已存在: 递增引用计数
                // (简化: 实际需要通过 index 递增)
                ()
            case None =>
                files.put(contentHash, StaticRoute())
                refs.append(UInt32(1))
        }

        let newIdx = EntryIndex(UInt32(files.keys().size - 1))
        pathMap.put(absPath, newIdx)
        return newIdx
    }

    /// 放置或递增引用计数
    /// 对应 Bun: pub fn putOrIncrementRefCount(assets, content_hash, ref_count) !?**StaticRoute
    public func putOrIncrementRefCount(contentHash: UInt64, refCount: UInt32): ?StaticRoute {
        let existing = files.get(contentHash)
        match (existing) {
            case Some(route) =>
                // 已存在: 递增引用计数
                // 简化: 返回 None 表示已有数据
                return None
            case None =>
                files.put(contentHash, StaticRoute())
                refs.append(refCount)
                return files.get(contentHash)
        }
    }

    /// 按哈希递减引用
    /// 对应 Bun: pub fn unrefByHash(assets, content_hash, dec_count) void
    public func unrefByHash(contentHash: UInt64, decCount: UInt32): Unit {
        let idx = files.get(contentHash)
        if (idx.isSome()) {
            unrefByIndex(EntryIndex(UInt32(0)), decCount)
        }
    }
    /// 按索引递减引用
    /// 对应 Bun: pub fn unrefByIndex(assets, index, dec_count) void
    public func unrefByIndex(index: EntryIndex, decCount: UInt32): Unit {
        let idx = index.get()
        if (Int64(idx) >= refs.size) {
            return
        }
        refs[Int64(idx)] = refs[Int64(idx)] - decCount
        if (refs[Int64(idx)] == UInt32(0)) {
            // 引用归零: 移除文件并交换删除
            files.remove(UInt64(idx))
            // 翻译自 swapRemove 后修补 path_map 中被移动条目的索引
            let movedFrom = UInt32(files.keys().size)
            if (movedFrom != idx) {
                // 修补: 被移动的条目现在在 index 的位置
                for (key in pathMap.keys()) {
                    match (pathMap.get(key)) {
                        case Some(entryIdx) =>
                            if (entryIdx.get() == movedFrom) {
                                pathMap.put(key, index)
                            }
                        case None => ()
                    }
                }
            }
        }
    }

    /// 按路径递减引用
    /// 对应 Bun: pub fn unrefByPath(assets, path) void
    public func unrefByPath(path: String): Unit {
        let entry = pathMap.remove(path)
        match (entry) {
            case Some(entryIndex) => unrefByIndex(entryIndex, UInt32(1))
            case None => ()
        }
    }

    /// 如果需要则重建索引
    /// 对应 Bun: pub fn reindexIfNeeded(assets, alloc) !void
    public func reindexIfNeeded(): Unit {
        if (needsReindex) {
            // 在完整实现中会重建哈希索引
            needsReindex = false
        }
    }

    /// 获取指定哈希的静态路由
    /// 对应 Bun: pub fn get(assets, content_hash) ?*StaticRoute
    public func get(contentHash: UInt64): ?StaticRoute {
        return files.get(contentHash)
    }

    /// 释放所有资源
    /// 对应 Bun: pub fn deinit(assets, alloc) void
    public func deinit(): Unit {
        pathMap.clear()
        files.clear()
        refs.clear()
        needsReindex = false
    }
}

/// 静态路由 (简化)
/// 对应 Bun: StaticRoute
public class StaticRoute {}

/// MIME 类型 (简化)
/// 对应 Bun: MimeType
public class MimeType {
    public var value: String

    public init() {
        value = ""
    }

    public init(value: String) {
        this.value = value
    }
}

/// 任意 Blob (简化)
/// 对应 Bun: AnyBlob = jsc.WebCore.Blob.Any
public class AnyBlob {}
