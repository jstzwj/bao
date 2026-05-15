// 严格翻译自: src/sys_jsc/signal_code_jsc.zig
//! JSC bridge for `bun.SignalCode`. Keeps `src/sys/` free of JSC types.
package bao_sys_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// SignalCodeJSC - SignalCode 的 JSC 桥接
// 严格翻译自: src/sys_jsc/signal_code_jsc.zig:3-43
//   pub fn fromJS(arg: jsc.JSValue, globalThis) !SignalCode
// ============================================================================

/// 从 JS 值创建 SignalCode - 严格对应 Bun fromJS
/// Zig: pub fn fromJS(arg: jsc.JSValue, globalThis: *jsc.JSGlobalObject) !SignalCode
public func signalCodeFromJS(arg: JSValue, globalThis: JSGlobalObject): SignalCode {
    if (let sig64 = arg.getNumber()) {
        // Node does this:
        if (isNaN(sig64)) {
            return SignalCode.default
        }

        // This matches node behavior
        if (isInf(sig64) || Float64(Int64(sig64)) != sig64) {
            globalThis.throwInvalidArguments("Unknown signal")
            return SignalCode.default
        }

        if (sig64 < 0) {
            globalThis.throwInvalidArguments("Invalid signal: must be >= 0")
            return SignalCode.default
        }

        if (sig64 > 31) {
            globalThis.throwInvalidArguments("Invalid signal: must be < 32")
            return SignalCode.default
        }

        let code: SignalCode = SignalCode(UInt8(sig64))
        return code
    } else if (arg.isString) {
        if (arg.asString().length() == 0) {
            return SignalCode.default
        }
        let signalCode = arg.toEnum(globalThis, "signal", SignalCode)
        return signalCode
    } else if (!arg.isEmptyOrUndefinedOrNull) {
        globalThis.throwInvalidArguments("Invalid signal: must be a string or an integer")
        return SignalCode.default
    }

    return SignalCode.default
}
