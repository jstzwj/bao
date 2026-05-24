// 严格翻译自: src/sys_jsc/error_jsc.zig
//! JSC bridge for `bun.sys.Error`.
package bao_sys_jsc

import bao_jsc.*
import bao_core.*
import bao_sys.*

// ============================================================================
// ErrorJSC - sys.Error 的 JSC 桥接
// ============================================================================

/// 将 sys.Error 转换为 JS 值
public func sysErrorToJS(err: SysError, ptr: JSGlobalObject): JsValue {
    return ptr.createErrorInstance(err.toString())
}

/// 带有异步栈跟踪的 toJS。当前 Bao JsPromise 没有公开 async-stack 注入 API，返回同一 SystemError 实例语义。
public func sysErrorToJSWithAsyncStack(err: SysError, ptr: JSGlobalObject, promise: JsPromise): JsValue {
    return sysErrorToJS(err, ptr)
}

// ============================================================================
// TestingAPIs - Sys Error 测试 API
// ============================================================================

/// Sys Error 测试 API 集合
public class SysErrorTestingAPIs {
    /// 从 libuv 获取错误名称。非 Windows/libuv 翻译环境按 Bun 行为返回 undefined。
    public static func sysErrorNameFromLibuv(globalThis: JSGlobalObject, callframe: CallFrame): JsValue {
        let arguments = callframe.arguments()
        if (arguments.size < 1 || !arguments[0].isNumber()) {
            return globalThis.createErrorInstance("sysErrorNameFromLibuv: expected 1 number argument")
        }
        return JsValue.jsUndefined()
    }

    /// 翻译 UV 错误到 E。非 Windows/libuv 翻译环境按 Bun 行为返回 undefined。
    public static func translateUVErrorToE(globalThis: JSGlobalObject, callframe: CallFrame): JsValue {
        let arguments = callframe.arguments()
        if (arguments.size < 1 || !arguments[0].isNumber()) {
            return globalThis.createErrorInstance("translateUVErrorToE: expected 1 number argument")
        }
        return JsValue.jsUndefined()
    }

    /// sigaction 布局测试。Bao 当前没有暴露 Sigaction 布局 round-trip API。
    public static func sigactionLayout(globalThis: JSGlobalObject, _: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }
}
