// 严格翻译自: src/sys_jsc/error_jsc.zig
//! JSC bridge for `bun.sys.Error`. Keeps `src/sys/` free of JSC types.
package bao_sys_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// ErrorJSC - sys.Error 的 JSC 桥接
// 严格翻译自: src/sys_jsc/error_jsc.zig:3-13
// ============================================================================

/// 将 sys.Error 转换为 JS 值 - 严格对应 Bun toJS
/// Zig: pub fn toJS(this: Error, ptr: *jsc.JSGlobalObject) bun.JSError!jsc.JSValue
/// Zig: return this.toSystemError().toErrorInstance(ptr)
public func sysErrorToJS(`this`: SysError, ptr: JSGlobalObject): JSValue {
    return this.toSystemError().toErrorInstance(ptr)
}

/// 带有异步栈跟踪的 toJS - 严格对应 Bun toJSWithAsyncStack
/// Zig: pub fn toJSWithAsyncStack(this: Error, ptr, promise) bun.JSError!jsc.JSValue
/// Zig: return this.toSystemError().toErrorInstanceWithAsyncStack(ptr, promise)
public func sysErrorToJSWithAsyncStack(`this`: SysError, ptr: JSGlobalObject, promise: JSPromise): JSValue {
    return this.toSystemError().toErrorInstanceWithAsyncStack(ptr, promise)
}

// ============================================================================
// TestingAPIs - Sys Error 测试 API
// 严格翻译自: src/sys_jsc/error_jsc.zig:15-91
// ============================================================================

/// Sys Error 测试 API 集合 - 严格对应 Bun TestingAPIs
public class SysErrorTestingAPIs {
    /// 从 libuv 获取错误名称 - 严格对应 Bun sysErrorNameFromLibuv
    /// Zig: pub fn sysErrorNameFromLibuv(globalThis, callframe) bun.JSError!jsc.JSValue
    public static func sysErrorNameFromLibuv(globalThis: JSGlobalObject, callframe: CallFrame): JSValue {
        let arguments = callframe.arguments()
        if (arguments.size < 1 || !arguments[0].isNumber) {
            globalThis.throw("sysErrorNameFromLibuv: expected 1 number argument")
            return JSValue.zero
        }

        if (!Environment.isWindows) {
            return JSValue.jsUndefined
        }

        let err = SysError(
            errno: Int32(arguments[0].toInt32()),
            syscall: .open,
            fromLibuv: true
        )
        return BaoString.createUTF8ForJS(globalThis, err.name())
    }

    /// 翻译 UV 错误到 E - 严格对应 Bun translateUVErrorToE
    /// Zig: pub fn translateUVErrorToE(globalThis, callframe) bun.JSError!jsc.JSValue
    public static func translateUVErrorToE(globalThis: JSGlobalObject, callframe: CallFrame): JSValue {
        let arguments = callframe.arguments()
        if (arguments.size < 1 || !arguments[0].isNumber) {
            globalThis.throw("translateUVErrorToE: expected 1 number argument")
            return JSValue.zero
        }

        if (!Environment.isWindows) {
            return JSValue.jsUndefined
        }

        let code: Int32 = arguments[0].toInt32()
        let result = windows.libuv.translateUVErrorToE(code)
        return BaoString.createUTF8ForJS(globalThis, result.toString())
    }

    /// sigaction 布局测试 - 严格对应 Bun sigactionLayout
    /// Zig: pub fn sigactionLayout(globalThis, _) bun.JSError!jsc.JSValue
    public static func sigactionLayout(globalThis: JSGlobalObject, _: CallFrame): JSValue {
        if (!Environment.isPosix) {
            return JSValue.jsUndefined
        }

        let mask = sys.sigemptyset()
        sys.sigaddset(mask, posix.SIG.USR2)
        let act = Sigaction(
            handler: SigactionHandler.handler(sentryHandler),
            mask: mask,
            flags: posix.SA.RESTART
        )
        var prev = Sigaction()
        var readback = Sigaction()
        sys.sigaction(posix.SIG.USR2, act, prev)
        sys.sigaction(posix.SIG.USR2, None, readback)
        sys.sigaction(posix.SIG.USR2, prev, None)

        let installed = JSObject.create(
            JSObjectProps(
                handler: Float64(Int64(sentryHandler)),
                flags: Float64(act.flags & posix.SA.RESTART)
            ),
            globalThis
        ).toJS()
        let rb = JSObject.create(
            JSObjectProps(
                handler: Float64(Int64(readback.handler.handler)),
                flags: Float64(readback.flags & posix.SA.RESTART)
            ),
            globalThis
        ).toJS()
        return JSObject.create(
            JSObjectProps(
                installed: installed,
                readback: rb,
                sizeof: Float64(Int64(sizeof<Sigaction>()))
            ),
            globalThis
        ).toJS()
    }
}
