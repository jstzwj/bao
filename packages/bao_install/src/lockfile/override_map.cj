// bao_install - 覆盖映射
// 严格翻译自: src/install/lockfile/OverrideMap.zig
package bao_install.lockfile

import bao_install.*

import bao_core.*
import bao_collections.*

/// 覆盖映射
public class OverrideMap {
    public var map: HashMap<UInt64, DependencyInfo>

    public init() {
        map = HashMap<UInt64, DependencyInfo>()
    }

    public func get(nameHash: UInt64): ?DependencyInfo {
        if (map.size == 0) { return None }
        return map.get(nameHash)
    }

    public func sort(): Unit {
        // 简化: HashMap 不保证顺序
    }

    public func deinit(): Unit {
        map.clear()
    }

    public func count(): Int64 {
        var total: Int64 = 0
        for (entry in map) {
            total += Int64(entry.value.name.size)
        }
        return total
    }

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

    public static func parseCount(expr: JsonExpr): Int64 {
        var total: Int64 = 0
        match (expr.get("overrides")) {
            case Some(overrides) => total = countOverrides(overrides, total)
            case None =>
                match (expr.get("resolutions")) {
                    case Some(resolutions) => total = countResolutions(resolutions, total)
                    case None => ()
                }
        }
        return total
    }

    private static func countOverrides(overrides: JsonExpr, total: Int64): Int64 {
        var t = total
        if (overrides.isObject()) {
            for (p in overrides.properties()) {
                t += Int64(p.key.size)
                if (p.value.isString()) {
                    t += Int64(p.value.asString().size)
                } else if (p.value.isObject()) {
                    match (p.value.get(".")) {
                        case Some(dot) =>
                            if (dot.isString()) { t += Int64(dot.asString().size) }
                        case None => ()
                    }
                }
            }
        }
        return t
    }

    private static func countResolutions(resolutions: JsonExpr, total: Int64): Int64 {
        var t = total
        if (resolutions.isObject()) {
            for (p in resolutions.properties()) {
                t += Int64(p.key.size)
                t += Int64(p.value.asString().size)
            }
        }
        return t
    }

    public func parseAppend(expr: JsonExpr): Unit {
        match (expr.get("overrides")) {
            case Some(overrides) =>
                parseFromOverrides(overrides)
                return
            case None => ()
        }

        match (expr.get("resolutions")) {
            case Some(resolutions) => parseFromResolutions(resolutions)
            case None => ()
        }
    }

    public func parseFromOverrides(expr: JsonExpr): Unit {
        if (!expr.isObject()) { return }

        for (p in expr.properties()) {
            let k = p.key
            if (k.size == 0) { () }

            let nameHash = SemverStringBuilder.stringHashStr(k)

            var versionStr: ?String = None
            match (p.value.getStringOrDot()) {
                case Some(s) => versionStr = s
                case None => ()
            }

            match (versionStr) {
                case Some(vs) =>
                    if (vs.startsWith("patch:")) { () }
                    if (vs.size > 0 && vs[Int64(0)] == UInt8(36)) { () }

                    let dep = DependencyInfo()
                    dep.name = k
                    dep.nameHash = nameHash
                    map.put(nameHash, dep)
                case None => ()
            }
        }
    }

    public func parseFromResolutions(expr: JsonExpr): Unit {
        if (!expr.isObject()) { return }

        for (p in expr.properties()) {
            var k = p.key
            if (k.startsWith("**/")) {
                k = k.slice(3)
            }
            if (k.size == 0) { () }

            let value = p.value.asString()
            if (value.size == 0) { () }

            if (value.startsWith("patch:")) { () }

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
    public func getStringOrDot(): ?String {
        if (isString()) { return asString() }
        if (isObject()) {
            match (get(".")) {
                case Some(dot) =>
                    if (dot.isString()) { return dot.asString() }
                case None => ()
            }
        }
        return None
    }
}
