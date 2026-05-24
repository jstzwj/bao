// 严格翻译自: src/sys_jsc/signal_code_jsc.zig
//! JSC bridge for `bun.SignalCode`. Keeps `bao_sys/` free of JSC types.
package bao_sys_jsc

import bao_jsc.*
import bao_core.*
import bao_sys.*

// ============================================================================
// SignalCodeJSC - SignalCode 的 JSC 桥接
// ============================================================================

/// 从 JS 值创建 SignalCode
public func signalCodeFromJS(arg: JsValue, globalThis: JSGlobalObject): SignalCode {
    let numOpt = arg.getNumber()
    if (numOpt.isSome()) {
        let sig64 = numOpt.getOrThrow()
        if (sig64 != sig64) {
            return SignalCode.defaultSignal()
        }
        if (sig64 != Float64(Int64(sig64))) {
            globalThis.throwInvalidArguments("Unknown signal")
            return SignalCode.defaultSignal()
        }
        if (sig64 < 0.0) {
            globalThis.throwInvalidArguments("Invalid signal: must be >= 0")
            return SignalCode.defaultSignal()
        }
        if (sig64 > 31.0) {
            globalThis.throwInvalidArguments("Invalid signal: must be < 32")
            return SignalCode.defaultSignal()
        }
        let parsed = SignalCode.fromInt(Int32(sig64))
        match (parsed) {
            case Some(code) => return code
            case None => return SignalCode.defaultSignal()
        }
    } else if (arg.isString()) {
        let signalName = arg.toString()
        if (signalName.size == 0) {
            return SignalCode.defaultSignal()
        }
        let parsed = signalCodeFromName(signalName)
        match (parsed) {
            case Some(code) => return code
            case None =>
                globalThis.throwInvalidArguments("Unknown signal")
                return SignalCode.defaultSignal()
        }
    } else if (!arg.isEmptyOrUndefinedOrNull()) {
        globalThis.throwInvalidArguments("Invalid signal: must be a string or an integer")
        return SignalCode.defaultSignal()
    }
    return SignalCode.defaultSignal()
}

private func signalCodeFromName(name: String): ?SignalCode {
    match (name) {
        case "SIGHUP" => return Some(SignalCode.SIGHUP)
        case "SIGINT" => return Some(SignalCode.SIGINT)
        case "SIGQUIT" => return Some(SignalCode.SIGQUIT)
        case "SIGILL" => return Some(SignalCode.SIGILL)
        case "SIGTRAP" => return Some(SignalCode.SIGTRAP)
        case "SIGABRT" => return Some(SignalCode.SIGABRT)
        case "SIGBUS" => return Some(SignalCode.SIGBUS)
        case "SIGFPE" => return Some(SignalCode.SIGFPE)
        case "SIGKILL" => return Some(SignalCode.SIGKILL)
        case "SIGUSR1" => return Some(SignalCode.SIGUSR1)
        case "SIGSEGV" => return Some(SignalCode.SIGSEGV)
        case "SIGUSR2" => return Some(SignalCode.SIGUSR2)
        case "SIGPIPE" => return Some(SignalCode.SIGPIPE)
        case "SIGALRM" => return Some(SignalCode.SIGALRM)
        case "SIGTERM" => return Some(SignalCode.SIGTERM)
        case "SIGCHLD" => return Some(SignalCode.SIGCHLD)
        case "SIGCONT" => return Some(SignalCode.SIGCONT)
        case "SIGSTOP" => return Some(SignalCode.SIGSTOP)
        case "SIGTSTP" => return Some(SignalCode.SIGTSTP)
        case "SIGTTIN" => return Some(SignalCode.SIGTTIN)
        case "SIGTTOU" => return Some(SignalCode.SIGTTOU)
        case "SIGURG" => return Some(SignalCode.SIGURG)
        case "SIGXCPU" => return Some(SignalCode.SIGXCPU)
        case "SIGXFSZ" => return Some(SignalCode.SIGXFSZ)
        case "SIGVTALRM" => return Some(SignalCode.SIGVTALRM)
        case "SIGPROF" => return Some(SignalCode.SIGPROF)
        case "SIGWINCH" => return Some(SignalCode.SIGWINCH)
        case "SIGIO" => return Some(SignalCode.SIGIO)
        case "SIGPWR" => return Some(SignalCode.SIGPWR)
        case "SIGSYS" => return Some(SignalCode.SIGSYS)
        case _ => return None
    }
}
