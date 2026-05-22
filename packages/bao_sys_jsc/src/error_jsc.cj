// 严格翻译自: src/sys_jsc/error_jsc.zig
//! JSC bridge for `bun.sys.Error`. Stub implementation.
package bao_sys_jsc

import bao_jsc.*
import bao_core.*
import bao_sys.*

// ============================================================================
// ErrorJSC - sys.Error 的 JSC 桥接 (stub)
// ============================================================================

/// 将 sys.Error 转换为 JS 值 - stub
public func sysErrorToJS(err: SysError, ptr: JSGlobalObject): JsValue {
    return ptr.createErrorInstance("SysError")
}

/// 带有异步栈跟踪的 toJS - stub
public func sysErrorToJSWithAsyncStack(err: SysError, ptr: JSGlobalObject, promise: JsPromise): JsValue {
    return ptr.createErrorInstance("SysError")
}

// ============================================================================
// TestingAPIs - Sys Error 测试 API (stub)
// ============================================================================

/// Sys Error 测试 API 集合 - stub
public class SysErrorTestingAPIs {
    /// 从 libuv 获取错误名称 - stub
    public static func sysErrorNameFromLibuv(globalThis: JSGlobalObject, callframe: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 翻译 UV 错误到 E - stub
    public static func translateUVErrorToE(globalThis: JSGlobalObject, callframe: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// sigaction 布局测试 - stub
    public static func sigactionLayout(globalThis: JSGlobalObject, _: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }
}
