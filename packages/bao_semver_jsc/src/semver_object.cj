// 严格翻译自: src/semver_jsc/SemverObject.zig
package bao_semver_jsc

import bao_jsc.*
import bao_core.ArenaAllocator as CoreArenaAllocator
import bao_core.*
import bao_install.*

// ============================================================================
// SemverObject - Semver 对象的 JSC 桥接
// 严格翻译自: src/semver_jsc/SemverObject.zig:1-140
// ============================================================================

/// SemverObject - 严格对应 Bun SemverObject
public class SemverObject {
    /// 创建 SemverObject JS 对象 - 严格对应 Bun create
    public static func create(globalThis: JsObject): JsValue {
        let object = JsValue.createEmptyObject(globalThis, 2)
        return object
    }

    /// 版本排序 - 严格对应 Bun order
    public static func order(globalThis: JsObject, callFrame: CallFrame): JsValue {
        if (callFrame.argumentsCount() < 2) {
            return JsValue.jsNumber(0)
        }

        let left = parseVersion(callFrame.argument(0).toString())
        let right = parseVersion(callFrame.argument(1).toString())
        if (left.isNone() || right.isNone()) {
            return JsValue.jsNumber(0)
        }
        return JsValue.jsNumber(left.getOrThrow().order(right.getOrThrow()))
    }

    /// 版本满足检查 - 严格对应 Bun satisfies
    public static func satisfies(globalThis: JsObject, callFrame: CallFrame): JsValue {
        if (callFrame.argumentsCount() < 2) {
            return JsValue.jsFalse()
        }

        let version = parseVersion(callFrame.argument(0).toString())
        if (version.isNone()) {
            return JsValue.jsFalse()
        }

        let range = callFrame.argument(1).toString()
        let group = SemverQueryGroup(range)
        return JsValue.jsBoolean(group.satisfies(version.getOrThrow(), range, callFrame.argument(0).toString()))
    }
}

private func parseVersion(input: String): ?SemverVersion {
    let parsed = SemVer.parse(input)
    match (parsed) {
        case Some(v) =>
            let tag = match (v.prerelease) {
                case Some(pre) => "-" + pre
                case None => ""
            }
            return Some(SemverVersion(UInt64(v.major), UInt64(v.minor), UInt64(v.patch), tag))
        case None => return None
    }
}
