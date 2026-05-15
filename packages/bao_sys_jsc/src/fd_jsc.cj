// 严格翻译自: src/sys_jsc/fd_jsc.zig
//! JSC bridge for `bun.FD`. Keeps `src/sys/` free of JSC types.
package bao_sys_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// FDJSC - FD 的 JSC 桥接
// 严格翻译自: src/sys_jsc/fd_jsc.zig:4-81
// ============================================================================

/// 从 JS 值创建 FD - 严格对应 Bun fromJS
/// Zig: pub fn fromJS(value: JSValue) ?FD
public func fdFromJS(value: JSValue): ?FD {
    if (!value.isAnyInt) {
        return None
    }
    let fd64 = value.toInt64()
    if (fd64 < 0 || fd64 > Int64(Int32Max)) {
        return None
    }
    let fd: Int32 = Int32(fd64)
    return FD.fromUV(fd)
}

/// 从 JS 值创建经过验证的 FD - 严格对应 Bun fromJSValidated
/// Zig: pub fn fromJSValidated(value: JSValue, global: *jsc.JSGlobalObject) bun.JSError!?FD
public func fdFromJSValidated(value: JSValue, global: JSGlobalObject): ?FD {
    if (!value.isNumber) {
        return None
    }
    let float = value.asNumber()
    if (float % 1 != 0) {
        global.throwRangeError(float, RangeErrorProps(fieldName: "fd", msg: "an integer"))
        return None
    }
    if (float < 0 || float > Float64(Int32Max)) {
        global.throwRangeError(float, RangeErrorProps(fieldName: "fd", min: 0, max: Int32Max))
        return None
    }
    let int: Int64 = Int64(float)
    let fd: Int32 = Int32(int)
    return FD.fromUV(fd)
}

/// 将 FD 转换为 JS 值 - 严格对应 Bun toJS
/// Zig: pub fn toJS(any_fd: FD, global: *jsc.JSGlobalObject) JSValue
public func fdToJS(anyFd: FD, global: JSGlobalObject): JSValue {
    if (!anyFd.isValid) {
        return JSValue.jsNumberFromInt32(-1)
    }
    let uvOwnedFd = anyFd.makeLibUVOwned()
    if (uvOwnedFd.isErr) {
        anyFd.close()
        let errInstance = SystemError(
            message: BaoString.static("EMFILE, too many open files"),
            code: BaoString.static("EMFILE")
        ).toErrorInstance(global)
        return global.vm().throwError(global, errInstance)
    }
    return JSValue.jsNumberFromInt32(uvOwnedFd.resultValue.uv())
}

/// 将 FD 转换为 JS 值（不转移所有权） - 严格对应 Bun toJSWithoutMakingLibUVOwned
/// Zig: pub fn toJSWithoutMakingLibUVOwned(any_fd: FD) JSValue
public func fdToJSWithoutMakingLibUVOwned(anyFd: FD): JSValue {
    if (!anyFd.isValid) {
        return JSValue.jsNumberFromInt32(-1)
    }
    if (Environment.isWindows) {
        return match (anyFd.kind) {
            case .system => JSValue.jsNumberFromUint64(UInt64(anyFd.value.asSystem))
            case .uv => JSValue.jsNumberFromInt32(anyFd.value.asUv)
        }
    }
    return JSValue.jsNumberFromInt32(anyFd.value.asSystem)
}
