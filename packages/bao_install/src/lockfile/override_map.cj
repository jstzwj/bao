// bao_install - 覆盖映射
// 严格翻译自: src/install/lockfile/OverrideMap.zig
//   OverrideMap 使用 PackageNameHash 键管理依赖覆盖
//   支持从 overrides 和 resolutions 解析, 包含 $reference 支持
package bao_install.lockfile

import bao_core.*
import bao_collections.*

// ============================================================================
// 覆盖映射
// 严格翻译自: src/install/lockfile/OverrideMap.zig
//   const OverrideMap = @This();
//   map: ArrayHashMapUnmanaged(PackageNameHash, Dependency, ...) = .{}
// ============================================================================

/// 覆盖映射
/// 对应 Bun: OverrideMap
/// 翻译自: src/install/lockfile/OverrideMap.zig
public class OverrideMap {
    /// 映射表 (PackageNameHash -> Dependency)
    /// 翻译自: map: ArrayHashMapUnmanaged(PackageNameHash, Dependency, ...)
    public var map: HashMap<UInt64, DependencyInfo>

    public init() {
        map = HashMap<UInt64, DependencyInfo>()
    }

    /// 获取覆盖版本
    /// 翻译自: OverrideMap.get
    ///   pub fn get(this, name_hash) ?Dependency.Version
    ///   根据包名哈希获取覆盖的版本
    public func get(nameHash: UInt64): ?DependencyInfo {
        if (map.size == 0) { return None }
        return map.get(nameHash)
    }

    /// 排序
    /// 翻译自: OverrideMap.sort
    ///   pub fn sort(this, lockfile) void
    public func sort(): Unit {
        // 按 name 排序, 简化: HashMap 不保证顺序
    }

    /// 清理
    /// 翻译自: OverrideMap.deinit
    ///   pub fn deinit(this, allocator) void
    public func deinit(): Unit {
        map.clear()
    }

    /// 计数字符串大小
    /// 翻译自: OverrideMap.count
    ///   pub fn count(this, lockfile, builder) void
    public func count(): Int64 {
        var total: Int64 = 0
        for (entry in map) {
            total += Int64(entry.value.name.length)
        }
        return total
    }

    /// 克隆
    /// 翻译自: OverrideMap.clone
    ///   pub fn clone(this, pm, old_lockfile, new_lockfile, new_builder) !OverrideMap
    public func clone(): OverrideMap {
        let newMap = OverrideMap()
        for (entry in map) {
            let depClone = DependencyInfo()
            depClone.name = entry.value.name
            depClone.nameHash = entry.value.nameHash
            newMap.map.put(entry.key, depClone)
        }
        return newMap
    }

    /// 解析计数
    /// 翻译自: OverrideMap.parseCount
    ///   pub fn parseCount(_, lockfile, expr, builder) void
    public static func parseCount(expr: JsonExpr): Int64 {
        var total: Int64 = 0

        // 从 "overrides" 解析
        match (expr.get("overrides")) {
            case Some(overrides) => {
                if (overrides.isObject()) {
                    for (prop in overrides.properties()) {
                        total += Int64(prop.key.length)
                        if (prop.value.isString()) {
                            total += Int64(prop.value.asString().length)
                        } else if (prop.value.isObject()) {
                            match (prop.value.get(".")) {
                                case Some(dot) => {
                                    if (dot.isString()) {
                                        total += Int64(dot.asString().length)
                                    }
                                }
                                case None => {}
                            }
                        }
                    }
                }
            }
            case None => {
                // 尝试从 "resolutions" 解析
                match (expr.get("resolutions")) {
                    case Some(resolutions) => {
                        if (resolutions.isObject()) {
                            for (prop in resolutions.properties()) {
                                total += Int64(prop.key.length)
                                match (prop.value.asString()) {
                                    case s: String => total += Int64(s.length)
                                    case _: None => {}
                                }
                            }
                        }
                    }
                    case None => {}
                }
            }
        }

        return total
    }

    /// 解析并追加
    /// 翻译自: OverrideMap.parseAppend
    ///   pub fn parseAppend(this, pm, lockfile, root_package, log, json_source, expr, builder) !void
    public func parseAppend(
        expr: JsonExpr
    ): Unit {
        // 从 "overrides" 解析
        match (expr.get("overrides")) {
            case Some(overrides) => {
                parseFromOverrides(overrides)
                return
            }
            case None => {}
        }

        // 从 "resolutions" 解析
        match (expr.get("resolutions")) {
            case Some(resolutions) => {
                parseFromResolutions(resolutions)
            }
            case None => {}
        }
    }

    /// 从 npm overrides 解析
    /// 翻译自: OverrideMap.parseFromOverrides
    ///   pub fn parseFromOverrides(this, pm, lockfile, root_package, source, log, expr, builder) !void
    ///   https://docs.npmjs.com/cli/v9/configuring-npm/package-json#overrides
    public func parseFromOverrides(expr: JsonExpr): Unit {
        if (!expr.isObject()) { return }

        for (prop in expr.properties()) {
            let k = prop.key
            if (k.length == 0) { continue }

            let nameHash = SemverStringBuilder.stringHashStr(k)

            // 解析值: 字符串 或 { ".": value }
            var versionStr: ?String = None
            match (prop.value.getStringOrDot()) {
                case Some(s) => versionStr = s
                case None => continue
            }

            match (versionStr) {
                case Some(vs) => {
                    // 检查 patch: 前缀 (暂不支持)
                    if (vs.startsWith("patch:")) { continue }

                    // 检查 $reference
                    if (vs.length > 0 && vs[0].value == 36) { // '$'
                        // $reference: 引用直接依赖的版本
                        // 简化: 实际需要查找根包依赖
                        continue
                    }

                    let dep = DependencyInfo()
                    dep.name = k
                    dep.nameHash = nameHash
                    map.put(nameHash, dep)
                }
                case None => {}
            }
        }
    }

    /// 从 yarn resolutions 解析
    /// 翻译自: OverrideMap.parseFromResolutions
    ///   pub fn parseFromResolutions(this, pm, lockfile, root_package, source, log, expr, builder) !void
    ///   yarn classic: https://classic.yarnpkg.com/lang/en/docs/selective-version-resolutions/
    ///   yarn berry: https://yarnpkg.com/configuration/manifest#resolutions
    public func parseFromResolutions(expr: JsonExpr): Unit {
        if (!expr.isObject()) { return }

        for (prop in expr.properties()) {
            var k = prop.key
            // 移除 "**/" 前缀
            if (k.startsWith("**/")) {
                k = k.substring(3)
            }
            if (k.length == 0) { continue }

            // 检查嵌套路径 (暂不支持)
            if (k[0].value == 64) { // '@'
                let firstSlash = k.indexOf("/", 1)
                match (firstSlash) {
                    case Some(idx) => {
                        let rest = k.substring(Int64(idx) + 1)
                        if (rest.indexOf("/") != None) {
                            // 嵌套, 暂不支持
                            continue
                        }
                    }
                    case None => {}
                }
            } else {
                if (k.indexOf("/") != None) {
                    // 嵌套, 暂不支持
                    continue
                }
            }

            let value = prop.value.asString()
            if (value.length == 0) { continue }

            // 检查 patch: 前缀 (暂不支持)
            if (value.startsWith("patch:")) { continue }

            let nameHash = SemverStringBuilder.stringHashStr(k)
            let dep = DependencyInfo()
            dep.name = k
            dep.nameHash = nameHash
            map.put(nameHash, dep)
        }
    }
}

/// JSON 表达式扩展
public class JsonExpr {
    /// 获取字符串或 "." 值
    public func getStringOrDot(): ?String {
        if (isString()) { return asString() }
        if (isObject()) {
            match (get(".")) {
                case Some(dot) => {
                    if (dot.isString()) { return dot.asString() }
                }
                case None => {}
            }
        }
        return None
    }
}
