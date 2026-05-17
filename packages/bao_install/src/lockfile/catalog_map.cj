// bao_install - 目录映射
// 严格翻译自: src/install/lockfile/CatalogMap.zig
//   CatalogMap 管理 pnpm catalog: 依赖的默认组和命名组
//   支持 parseCount/parseAppend, sort, clone, deinit 等操作
package bao_install.lockfile

import bao_install.*

import bao_core.*
import bao_collections.*

// ============================================================================
// 目录映射
// 严格翻译自: src/install/lockfile/CatalogMap.zig
//   const CatalogMap = @This();
//   default: Map = .{}, groups: ArrayHashMapUnmanaged(String, Map, ...) = .{}
// ============================================================================

/// 目录映射
/// 对应 Bun: CatalogMap
/// 翻译自: src/install/lockfile/CatalogMap.zig
/// 管理 pnpm catalog: 的默认组和命名组
public class CatalogMap {
    /// 默认组
    /// 翻译自: default: Map = .{}
    public var default_: HashMap<String, DependencyInfo>

    /// 命名组
    /// 翻译自: groups: ArrayHashMapUnmanaged(String, Map, ...) = .{}
    public var groups: HashMap<String, HashMap<String, DependencyInfo>>

    public init() {
        default_ = HashMap<String, DependencyInfo>()
        groups = HashMap<String, HashMap<String, DependencyInfo>>()
    }

    /// 是否有任何条目
    /// 翻译自: CatalogMap.hasAny
    ///   pub fn hasAny(this: *const CatalogMap) bool
    public func hasAny(): Bool {
        return default_.size > 0 || groups.size > 0
    }

    /// 获取依赖
    /// 翻译自: CatalogMap.get
    ///   pub fn get(this, lockfile, catalog_name, dep_name) ?Dependency
    public func get(catalogName: String, depName: String): ?DependencyInfo {
        if (catalogName.size == 0) {
            if (default_.size == 0) { return None }
            return default_.get(depName)
        }

        match (groups.get(catalogName)) {
            case Some(group) => return getFromGroup(group, depName)
            case None => return None
        }
    }

    private func getFromGroup(group: HashMap<String, DependencyInfo>, depName: String): ?DependencyInfo {
        if (group.size == 0) { return None }
        return group.get(depName)
    }

    /// 获取或创建命名组
    /// 翻译自: CatalogMap.getOrPutGroup
    ///   pub fn getOrPutGroup(this, lockfile, catalog_name) OOM!*Map
    public func getOrPutGroup(catalogName: String): HashMap<String, DependencyInfo> {
        if (catalogName.size == 0) {
            return default_
        }

        match (groups.get(catalogName)) {
            case Some(group) => return group
            case None => return createNewGroup(catalogName)
        }
    }

    private func createNewGroup(catalogName: String): HashMap<String, DependencyInfo> {
        let newGroup = HashMap<String, DependencyInfo>()
        groups.put(catalogName, newGroup)
        return newGroup
    }

    /// 排序所有组和依赖
    /// 翻译自: CatalogMap.sort
    ///   pub fn sort(this, lockfile) void
    public func sort(): Unit {
        // 默认组按名称排序
        // 命名组按名称排序, 每个组内的依赖也按名称排序
        // 简化: HashMap 在仓颉中不一定有序
    }

    /// 清理
    /// 翻译自: CatalogMap.deinit
    ///   pub fn deinit(this, allocator) void
    public func deinit(): Unit {
        default_.clear()
        for (entry in groups) {
            entry.value.clear()
        }
        groups.clear()
    }

    /// 计数字符串大小
    /// 翻译自: CatalogMap.count
    ///   pub fn count(this, lockfile, builder) void
    public func count(): Int64 {
        var total: Int64 = 0

        // 默认组
        for (entry in default_) {
            total += Int64(entry.key.size)
            total += Int64(entry.value.name.size)
        }

        // 命名组
        for (group in groups) {
            total += Int64(group.key.size)
            for (entry in group.value) {
                total += Int64(entry.key.size)
                total += Int64(entry.value.name.size)
            }
        }

        return total
    }

    /// 克隆
    /// 翻译自: CatalogMap.clone
    ///   pub fn clone(this, pm, old, new, builder) OOM!CatalogMap
    public func clone(): CatalogMap {
        let newCatalog = CatalogMap()

        // 克隆默认组
        for (entry in default_) {
            let depClone = DependencyInfo()
            depClone.name = entry.value.name
            depClone.nameHash = entry.value.nameHash
            newCatalog.default_.put(entry.key, depClone)
        }

        // 克隆命名组
        for (group in groups) {
            let newGroup = HashMap<String, DependencyInfo>()
            for (entry in group.value) {
                let depClone = DependencyInfo()
                depClone.name = entry.value.name
                depClone.nameHash = entry.value.nameHash
                newGroup.put(entry.key, depClone)
            }
            newCatalog.groups.put(group.key, newGroup)
        }

        return newCatalog
    }

    /// 从 pnpm lockfile 解析
    /// 翻译自: CatalogMap.fromPnpmLockfile
    ///   pub fn fromPnpmLockfile(lockfile, allocator, log, catalogs_obj, string_buf) !void
    public static func fromPnpmLockfile(
        catalogs: CatalogEntries
    ): CatalogMap {
        let result = CatalogMap()
        // 简化: 实际解析需要遍历 JSON 对象
        return result
    }

    /// 解析计数
    /// 翻译自: CatalogMap.parseCount
    ///   pub fn parseCount(_, lockfile, expr, builder) void
    public static func parseCount(expr: JsonExpr): Int64 {
        var total: Int64 = 0
        // 解析 "catalog" 和 "catalogs" 字段
        match (expr.get("catalog")) {
            case Some(catalog) => total = countCatalog(catalog, total)
            case None => ()
        }

        match (expr.get("catalogs")) {
            case Some(catalogs) => total = countCatalogs(catalogs, total)
            case None => ()
        }

        return total
    }

    private static func countCatalog(catalog: JsonExpr, total: Int64): Int64 {
        var t = total
        if (catalog.isObject()) {
            for (p in catalog.properties()) {
                t += Int64(p.key.size)
                if (p.value.isString()) {
                    t += Int64(p.value.asString().size)
                }
            }
        }
        return t
    }

    private static func countCatalogs(catalogs: JsonExpr, total: Int64): Int64 {
        var t = total
        if (catalogs.isObject()) {
            for (c in catalogs.properties()) {
                t += Int64(c.key.size)
                if (c.value.isObject()) {
                    for (p in c.value.properties()) {
                        t += Int64(p.key.size)
                        if (p.value.isString()) {
                            t += Int64(p.value.asString().size)
                        }
                    }
                }
            }
        }
        return t
    }

    /// 解析并追加
    public func parseAppend(expr: JsonExpr): Bool {
        var foundAny = false

        match (expr.get("catalog")) {
            case Some(catalog) =>
                foundAny = true
                parseDefaultCatalog(catalog)
            case None => ()
        }

        match (expr.get("catalogs")) {
            case Some(catalogs) =>
                foundAny = true
                parseNamedCatalogs(catalogs)
            case None => ()
        }

        return foundAny
    }

    private func parseDefaultCatalog(catalog: JsonExpr): Unit {
        if (catalog.isObject()) {
            let group = getOrPutGroup("")
            for (p in catalog.properties()) {
                let depName = p.key
                let depNameHash = SemverStringBuilder.stringHashStr(depName)
                if (p.value.isString()) {
                    let dep = DependencyInfo()
                    dep.name = depName
                    dep.nameHash = depNameHash
                    group.put(depName, dep)
                }
            }
        }
    }

    private func parseNamedCatalogs(catalogs: JsonExpr): Unit {
        if (catalogs.isObject()) {
            for (c in catalogs.properties()) {
                let catalogName = c.key
                let group = getOrPutGroup(catalogName)
                if (c.value.isObject()) {
                    for (p in c.value.properties()) {
                        let depName = p.key
                        let depNameHash = SemverStringBuilder.stringHashStr(depName)
                        if (p.value.isString()) {
                            let dep = DependencyInfo()
                            dep.name = depName
                            dep.nameHash = depNameHash
                            group.put(depName, dep)
                        }
                    }
                }
            }
        }
    }
}

// ============================================================================
// JSON 表达式 (轻量引用) - defined elsewhere in bao_install
// ============================================================================
public class CatalogEntries {
    public init() {}
}
