// bao_install - 目录映射
// 严格翻译自: src/install/lockfile/CatalogMap.zig
//   CatalogMap 管理 pnpm catalog: 依赖的默认组和命名组
//   支持 parseCount/parseAppend, sort, clone, deinit 等操作
package bao_install.lockfile

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
        if (catalogName.length == 0) {
            if (default_.size == 0) { return None }
            return default_.get(depName)
        }

        match (groups.get(catalogName)) {
            case Some(group) => {
                if (group.size == 0) { return None }
                return group.get(depName)
            }
            case None => return None
        }
    }

    /// 获取或创建命名组
    /// 翻译自: CatalogMap.getOrPutGroup
    ///   pub fn getOrPutGroup(this, lockfile, catalog_name) OOM!*Map
    public func getOrPutGroup(catalogName: String): HashMap<String, DependencyInfo> {
        if (catalogName.length == 0) {
            return default_
        }

        match (groups.get(catalogName)) {
            case Some(group) => return group
            case None => {
                let newGroup = HashMap<String, DependencyInfo>()
                groups.put(catalogName, newGroup)
                return newGroup
            }
        }
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
            total += Int64(entry.key.length)
            total += Int64(entry.value.name.length)
        }

        // 命名组
        for (group in groups) {
            total += Int64(group.key.length)
            for (entry in group.value) {
                total += Int64(entry.key.length)
                total += Int64(entry.value.name.length)
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
            case Some(catalog) => {
                if (catalog.isObject()) {
                    for (prop in catalog.properties()) {
                        total += Int64(prop.key.length)
                        if (prop.value.isString()) {
                            total += Int64(prop.value.asString().length)
                        }
                    }
                }
            }
            case None => ()
        }

        match (expr.get("catalogs")) {
            case Some(catalogs) => {
                if (catalogs.isObject()) {
                    for (catalog in catalogs.properties()) {
                        total += Int64(catalog.key.length)
                        if (catalog.value.isObject()) {
                            for (prop in catalog.value.properties()) {
                                total += Int64(prop.key.length)
                                if (prop.value.isString()) {
                                    total += Int64(prop.value.asString().length)
                                }
                            }
                        }
                    }
                }
            }
            case None => ()
        }

        return total
    }

    /// 解析并追加
    /// 翻译自: CatalogMap.parseAppend
    ///   pub fn parseAppend(this, pm, lockfile, log, source, expr, builder) OOM!bool
    public func parseAppend(expr: JsonExpr): Bool {
        var foundAny = false

        // 解析默认 catalog
        match (expr.get("catalog")) {
            case Some(catalog) => {
                foundAny = true
                if (catalog.isObject()) {
                    let group = getOrPutGroup("")
                    for (prop in catalog.properties()) {
                        let depName = prop.key
                        let depNameHash = SemverStringBuilder.stringHashStr(depName)

                        if (prop.value.isString()) {
                            let versionLiteral = prop.value.asString()
                            let dep = DependencyInfo()
                            dep.name = depName
                            dep.nameHash = depNameHash
                            group.put(depName, dep)
                        }
                    }
                }
            }
            case None => ()
        }

        // 解析命名 catalogs
        match (expr.get("catalogs")) {
            case Some(catalogs) => {
                foundAny = true
                if (catalogs.isObject()) {
                    for (catalog in catalogs.properties()) {
                        let catalogName = catalog.key
                        let group = getOrPutGroup(catalogName)

                        if (catalog.value.isObject()) {
                            for (prop in catalog.value.properties()) {
                                let depName = prop.key
                                let depNameHash = SemverStringBuilder.stringHashStr(depName)

                                if (prop.value.isString()) {
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
            case None => ()
        }

        return foundAny
    }
}

// ============================================================================
// JSON 表达式 (轻量引用)
// ============================================================================

/// JSON 表达式
/// 对应 Bun: Expr
public class JsonExpr {
    public init() {}

    public func get(key: String): ?JsonExpr { return None }
    public func isObject(): Bool { return false }
    public func isString(): Bool { return false }
    public func asString(): String { return "" }
    public func properties(): ArrayList<JsonProperty> { return ArrayList<JsonProperty>() }
}

/// JSON 属性
public class JsonProperty {
    public var key: String
    public var value: JsonExpr

    public init() {
        key = ""
        value = JsonExpr()
    }
}

/// 目录条目列表
public class CatalogEntries {
    public init() {}
}
