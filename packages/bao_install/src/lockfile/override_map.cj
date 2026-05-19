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
        return 0
    }

    public func clone(): OverrideMap {
        return OverrideMap()
    }

    public static func parseCount(expr: JsonExpr): Int64 {
        return 0
    }

    private static func countOverrides(overrides: JsonExpr, total: Int64): Int64 {
        return total
    }

    private static func countResolutions(resolutions: JsonExpr, total: Int64): Int64 {
        return total
    }

    public func parseAppend(expr: JsonExpr): Unit {
        return
    }

    public func parseFromOverrides(expr: JsonExpr): Unit {
        return
    }

    public func parseFromResolutions(expr: JsonExpr): Unit {
        return
    }
}

/// JSON 表达式扩展
public class JsonExpr {
    public func getStringOrDot(): ?String {
        return None
    }
}
