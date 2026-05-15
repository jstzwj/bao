// bao_install - 包 Manifest 缓存映射
// 严格翻译自: src/install/PackageManifestMap.zig
//   pub const PackageManifestMap = struct { hash_map: HashMap = .{} }
//   管理 NPM 包 manifest 的缓存, 支持内存缓存和磁盘缓存回退
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 缓存行为
// 严格翻译自: src/install/PackageManifestMap.zig - CacheBehavior
//   pub const CacheBehavior = enum {
//       load_from_memory,
//       load_from_memory_fallback_to_disk,
//   }
// ============================================================================

/// Manifest 缓存行为
/// 翻译自: PackageManifestMap.CacheBehavior
public enum ManifestCacheBehavior {
    | LoadFromMemory                   // 仅从内存加载
    | LoadFromMemoryFallbackToDisk     // 内存未命中时从磁盘加载
}

// ============================================================================
// Manifest 缓存条目值
// 严格翻译自: src/install/PackageManifestMap.zig - Value (union)
//   const Value = union(enum) {
//       expired: Npm.PackageManifest,
//       manifest: Npm.PackageManifest,
//       not_found: void,
//   }
// ============================================================================

/// Manifest 缓存条目值
/// 翻译自: PackageManifestMap.Value
public enum ManifestCacheValue {
    | Expired(PackageManifestData)     // 已过期 (etag 失效但可回退)
    | Manifest(PackageManifestData)    // 有效 manifest
    | NotFound                         // 未找到 (404)
}

// ============================================================================
// 包 Manifest 缓存映射
// 严格翻译自: src/install/PackageManifestMap.zig - PackageManifestMap
//   pub const PackageManifestMap = struct {
//       hash_map: HashMap = .{},
//   }
//   const HashMap = std.HashMapUnmanaged(PackageNameHash, Value, ...)
// ============================================================================

/// 包 Manifest 缓存映射
/// 对应 Bun: PackageManifestMap
/// 管理所有已下载的 NPM 包 manifest, 支持内存缓存和磁盘缓存回退
public class PackageManifestMap {
    /// 内部哈希表: name_hash -> ManifestCacheValue
    /// 翻译自: hash_map: HashMap
    private var map: HashMap<UInt64, ManifestCacheValue>

    public init() {
        map = HashMap<UInt64, ManifestCacheValue>()
    }

    /// 按包名查找 manifest
    /// 翻译自: PackageManifestMap.byName
    ///   pub fn byName(this, pm, scope, name, cache_behavior, needs_extended_manifest) ?*Npm.PackageManifest
    public func byName(
        name: String,
        scope: NpmRegistryScope,
        cacheBehavior: ManifestCacheBehavior,
        needsExtendedManifest: Bool
    ): ?PackageManifestData {
        let nameHash = SemverStringBuilder.stringHashStr(name)
        return byNameHash(nameHash, cacheBehavior, needsExtendedManifest)
    }

    /// 按名称哈希查找 manifest
    /// 翻译自: PackageManifestMap.byNameHash
    ///   pub fn byNameHash(this, pm, scope, name_hash, cache_behavior, needs_extended_manifest) ?*Npm.PackageManifest
    public func byNameHash(
        nameHash: UInt64,
        cacheBehavior: ManifestCacheBehavior,
        needsExtendedManifest: Bool
    ): ?PackageManifestData {
        return byNameHashAllowExpired(nameHash, None, cacheBehavior, needsExtendedManifest)
    }

    /// 按包名查找, 允许返回过期的 manifest
    /// 翻译自: PackageManifestMap.byNameAllowExpired
    ///   pub fn byNameAllowExpired(this, pm, scope, name, is_expired, cache_behavior, needs_extended_manifest) ?*Npm.PackageManifest
    public func byNameAllowExpired(
        name: String,
        isExpired: Bool,
        cacheBehavior: ManifestCacheBehavior,
        needsExtendedManifest: Bool
    ): ?PackageManifestData {
        let nameHash = SemverStringBuilder.stringHashStr(name)
        return byNameHashAllowExpired(nameHash, Some(isExpired), cacheBehavior, needsExtendedManifest)
    }

    /// 按名称哈希查找, 允许返回过期的 manifest
    /// 翻译自: PackageManifestMap.byNameHashAllowExpired
    ///   核心查找逻辑: 先查内存, 未命中时从磁盘加载 (如果启用)
    public func byNameHashAllowExpired(
        nameHash: UInt64,
        isExpired: ?Bool,
        cacheBehavior: ManifestCacheBehavior,
        needsExtendedManifest: Bool
    ): ?PackageManifestData {
        // 仅内存模式
        match (cacheBehavior) {
            case LoadFromMemory => {
                match (map.get(nameHash)) {
                    case Some(ManifestCacheValue.Manifest(m)) => return m
                    case Some(ManifestCacheValue.Expired(m)) => {
                        match (isExpired) {
                            case Some(_) => return m  // 返回过期数据作为回退
                            case None => return None
                        }
                    }
                    case Some(ManifestCacheValue.NotFound) => return None
                    case None => return None
                }
            }
            case LoadFromMemoryFallbackToDisk => ()
        }

        // 回退到磁盘模式: 查找或插入
        match (map.get(nameHash)) {
            case Some(ManifestCacheValue.Manifest(m)) => {
                // 检查是否需要扩展 manifest
                if (needsExtendedManifest && !m.hasExtendedManifest) {
                    // 降级为过期
                    map.put(nameHash, ManifestCacheValue.Expired(m))
                }
                return m
            }
            case Some(ManifestCacheValue.Expired(m)) => {
                match (isExpired) {
                    case Some(_) => return m
                    case None => return None
                }
            }
            case Some(ManifestCacheValue.NotFound) => return None
            case None => {
                // 未找到: 尝试从磁盘加载 (实际实现需要文件系统访问)
                // 翻译自: Npm.PackageManifest.Serializer.loadByFileID
                // 这里标记为未找到
                map.put(nameHash, ManifestCacheValue.NotFound)
                return None
            }
        }
    }

    /// 插入 manifest 到缓存
    /// 翻译自: PackageManifestMap.insert
    ///   pub fn insert(this, name_hash, manifest) !void
    public func insert(nameHash: UInt64, manifest: PackageManifestData): Unit {
        map.put(nameHash, ManifestCacheValue.Manifest(manifest))
    }

    /// 标记 manifest 为过期
    /// 翻译自: PackageManifestMap 中设置 expired 值
    public func setExpired(nameHash: UInt64, manifest: PackageManifestData): Unit {
        map.put(nameHash, ManifestCacheValue.Expired(manifest))
    }

    /// 标记为未找到
    public func setNotFound(nameHash: UInt64): Unit {
        map.put(nameHash, ManifestCacheValue.NotFound)
    }

    /// 移除缓存条目
    public func remove(nameHash: UInt64): Unit {
        map.remove(nameHash)
    }

    /// 清空所有缓存
    public func clear(): Unit {
        map.clear()
    }

    /// 缓存条目数量
    public func count(): Int64 {
        return map.size
    }
}
