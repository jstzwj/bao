// 严格翻译自: src/semver_jsc/SemverObject.zig
package bao_semver_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// SemverObject - Semver 对象的 JSC 桥接
// 严格翻译自: src/semver_jsc/SemverObject.zig:1-140
//   pub fn create(globalThis) jsc.JSValue
//   pub fn order(globalThis, callFrame) bun.JSError!jsc.JSValue
//   pub fn satisfies(globalThis, callFrame) bun.JSError!jsc.JSValue
// ============================================================================

/// SemverObject - 严格对应 Bun SemverObject
/// Zig: pub fn create(globalThis: *jsc.JSGlobalObject) jsc.JSValue
public class SemverObject {
    /// 创建 SemverObject JS 对象 - 严格对应 Bun create
    public static func create(globalThis: JSGlobalObject): JSValue {
        let object = JSValue.createEmptyObject(globalThis, 2)

        object.put(
            globalThis,
            ZigString.static("satisfies"),
            JSFunction.create(
                globalThis,
                "satisfies",
                SemverObject.satisfies,
                2
            )
        )

        object.put(
            globalThis,
            ZigString.static("order"),
            JSFunction.create(
                globalThis,
                "order",
                SemverObject.order,
                2
            )
        )

        return object
    }

    /// 版本排序 - 严格对应 Bun order
    /// Zig: pub fn order(globalThis, callFrame) bun.JSError!jsc.JSValue
    public static func order(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        let arena = ArenaAllocator(Allocator.default)
        let allocator = arena.allocator()

        let arguments = callFrame.argumentsOld(2).slice()
        if (arguments.size < 2) {
            globalThis.throw("Expected two arguments")
            return JSValue.zero
        }

        let leftArg = arguments[0]
        let rightArg = arguments[1]

        let leftString = leftArg.toJSString(globalThis)
        let rightString = rightArg.toJSString(globalThis)

        let left = leftString.toSlice(globalThis, allocator)
        let right = rightString.toSlice(globalThis, allocator)

        if (!strings.isAllASCII(left.slice())) {
            return JSValue.jsNumber(0)
        }
        if (!strings.isAllASCII(right.slice())) {
            return JSValue.jsNumber(0)
        }

        let leftResult = Version.parse(SlicedString.init(left.slice(), left.slice()))
        let rightResult = Version.parse(SlicedString.init(right.slice(), right.slice()))

        if (!leftResult.valid) {
            globalThis.throw("Invalid SemVer: ${left.slice()}")
            return JSValue.zero
        }

        if (!rightResult.valid) {
            globalThis.throw("Invalid SemVer: ${right.slice()}")
            return JSValue.zero
        }

        let leftVersion = leftResult.version.max()
        let rightVersion = rightResult.version.max()

        let cmp = leftVersion.orderWithoutBuild(rightVersion, left.slice(), right.slice())
        match (cmp) {
            case .eq => return JSValue.jsNumber(0)
            case .gt => return JSValue.jsNumber(1)
            case .lt => return JSValue.jsNumber(-1)
        }
    }

    /// 版本满足检查 - 严格对应 Bun satisfies
    /// Zig: pub fn satisfies(globalThis, callFrame) bun.JSError!jsc.JSValue
    public static func satisfies(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        let arena = ArenaAllocator(Allocator.default)
        let allocator = arena.allocator()

        let arguments = callFrame.argumentsOld(2).slice()
        if (arguments.size < 2) {
            globalThis.throw("Expected two arguments")
            return JSValue.zero
        }

        let leftArg = arguments[0]
        let rightArg = arguments[1]

        let leftString = leftArg.toJSString(globalThis)
        let rightString = rightArg.toJSString(globalThis)

        let left = leftString.toSlice(globalThis, allocator)
        let right = rightString.toSlice(globalThis, allocator)

        if (!strings.isAllASCII(left.slice())) {
            return JSValue.jsFalse
        }
        if (!strings.isAllASCII(right.slice())) {
            return JSValue.jsFalse
        }

        let leftResult = Version.parse(SlicedString.init(left.slice(), left.slice()))
        if (leftResult.wildcard != Wildcard.none) {
            return JSValue.jsFalse
        }

        let leftVersion = leftResult.version.min()

        let rightGroup = Query.parse(allocator, right.slice(), SlicedString.init(right.slice(), right.slice()))
        defer {
            rightGroup.deinit()
        }

        let rightVersion = rightGroup.getExactVersion()

        if (rightVersion != None) {
            return JSValue.jsBoolean(leftVersion.eql(rightVersion))
        }

        return JSValue.jsBoolean(rightGroup.satisfies(leftVersion, right.slice(), left.slice()))
    }
}
