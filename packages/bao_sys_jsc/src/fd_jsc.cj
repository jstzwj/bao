// 严格翻译自: src/sys_jsc/fd_jsc.zig
//! JSC bridge for `bun.FD`. Keeps `bao_sys/` free of JSC types.
package bao_sys_jsc

import bao_jsc.*
import bao_core.*
import bao_sys.*

// ============================================================================
// FDJSC - FD 的 JSC 桥接
// ============================================================================

/// 从 JS 值创建 FD
public func fdFromJS(value: JsValue): ?Int64 {
    if (!value.isAnyInt()) {
        return None
    }
    let fd64 = value.toInt64()
    if (fd64 < 0 || fd64 > Int64(2147483647)) {
        return None
    }
    return Some(fd64)
}

/// 从 JS 值创建经过验证的 FD
public func fdFromJSValidated(value: JsValue, global: JSGlobalObject): ?Int64 {
    if (!value.isNumber()) {
        return None
    }

    let fd = value.toNumber()
    if (fd != Float64(Int64(fd))) {
        global.throwInvalidArguments("fd must be an integer")
        return None
    }

    let fd64 = Int64(fd)
    if (fd64 < 0 || fd64 > Int64(2147483647)) {
        global.throwInvalidArguments("fd must be an integer between 0 and 2147483647")
        return None
    }

    return Some(fd64)
}

/// 将 FD 转换为 JS 值
public func fdToJS(anyFd: Int64, global: JSGlobalObject): JsValue {
    if (!FdUtils.isValid(anyFd)) {
        return JsValue.jsNumberFromInt32(-1)
    }
    return JsValue.jsNumberFromInt64(anyFd)
}

/// 将 FD 转换为 JS 值（不转移所有权）
public func fdToJSWithoutMakingLibUVOwned(anyFd: Int64): JsValue {
    if (!FdUtils.isValid(anyFd)) {
        return JsValue.jsNumberFromInt32(-1)
    }
    return JsValue.jsNumberFromInt64(anyFd)
}
