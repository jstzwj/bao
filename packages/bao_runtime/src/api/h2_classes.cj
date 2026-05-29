// 严格翻译自: src/runtime/api/h2.classes.ts
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue}

// ============================================================================
// h2.classes.ts 类绑定定义
// Bun: H2FrameParser 的 JSC 绑定
// construct: true, finalize: true, constructNeedsThis: true, configurable: false
// values: ["context", "onError", "onWrite", "onStreamError", "onStreamStart",
//          "onStreamHeaders", "onStreamEnd", "onStreamData", "onRemoteSettings",
//          "onLocalSettings", "onWantTrailers", "onPing", "onEnd", "onGoAway",
//          "onAborted", "onAltSvc", "onOrigin", "onFrameError"]
// ============================================================================

/// H2FrameParser JSC 绑定
/// Bun: HTTP/2 帧解析器
public class H2FrameParserClasses {

    /// request fn
    /// 严格翻译自: proto.request { fn: "request", length: 2 }
    public static func request(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// setNativeSocket fn
    /// 严格翻译自: proto.setNativeSocket { fn: "setNativeSocketFromJS", length: 1 }
    public static func setNativeSocketFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// ping fn
    /// 严格翻译自: proto.ping { fn: "ping", length: 0 }
    public static func ping(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// altsvc fn
    /// 严格翻译自: proto.altsvc { fn: "altsvc", length: 3 }
    public static func altsvc(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// origin fn
    /// 严格翻译自: proto.origin { fn: "origin", length: 1 }
    public static func origin(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// goaway fn
    /// 严格翻译自: proto.goaway { fn: "goaway", length: 3 }
    public static func goaway(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// getCurrentState fn
    /// 严格翻译自: proto.getCurrentState { fn: "getCurrentState", length: 0 }
    public static func getCurrentState(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// settings fn
    /// 严格翻译自: proto.settings { fn: "updateSettings", length: 1 }
    public static func updateSettings(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// setLocalWindowSize fn
    /// 严格翻译自: proto.setLocalWindowSize { fn: "setLocalWindowSize", length: 1 }
    public static func setLocalWindowSize(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// read fn
    /// 严格翻译自: proto.read { fn: "read", length: 1 }
    public static func read(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// flush fn
    /// 严格翻译自: proto.flush { fn: "flushFromJS", length: 0 }
    public static func flushFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// detach fn
    /// 严格翻译自: proto.detach { fn: "detachFromJS", length: 0 }
    public static func detachFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// rstStream fn
    /// 严格翻译自: proto.rstStream { fn: "rstStream", length: 1 }
    public static func rstStream(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// writeStream fn
    /// 严格翻译自: proto.writeStream { fn: "writeStream", length: 3 }
    public static func writeStream(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// sendTrailers fn
    /// 严格翻译自: proto.sendTrailers { fn: "sendTrailers", length: 2 }
    public static func sendTrailers(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// noTrailers fn
    /// 严格翻译自: proto.noTrailers { fn: "noTrailers", length: 1 }
    public static func noTrailers(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// setStreamPriority fn
    /// 严格翻译自: proto.setStreamPriority { fn: "setStreamPriority", length: 2 }
    public static func setStreamPriority(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// getStreamContext fn
    /// 严格翻译自: proto.getStreamContext { fn: "getStreamContext", length: 1 }
    public static func getStreamContext(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// setStreamContext fn
    /// 严格翻译自: proto.setStreamContext { fn: "setStreamContext", length: 2 }
    public static func setStreamContext(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// getEndAfterHeaders fn
    /// 严格翻译自: proto.getEndAfterHeaders { fn: "getEndAfterHeaders", length: 1 }
    public static func getEndAfterHeaders(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// isStreamAborted fn
    /// 严格翻译自: proto.isStreamAborted { fn: "isStreamAborted", length: 1 }
    public static func isStreamAborted(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsBoolean(false)
    }

    /// getStreamState fn
    /// 严格翻译自: proto.getStreamState { fn: "getStreamState", length: 1 }
    public static func getStreamState(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// bufferSize fn
    /// 严格翻译自: proto.bufferSize { fn: "getBufferSize", length: 0 }
    public static func getBufferSize(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsNumber(0)
    }

    /// hasNativeRead fn
    /// 严格翻译自: proto.hasNativeRead { fn: "hasNativeRead", length: 1 }
    public static func hasNativeRead(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsBoolean(false)
    }

    /// setNextStreamID fn
    /// 严格翻译自: proto.setNextStreamID { fn: "setNextStreamID", length: 1 }
    public static func setNextStreamID(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// forEachStream fn
    /// 严格翻译自: proto.forEachStream { fn: "forEachStream", length: 2 }
    public static func forEachStream(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// emitErrorToAllStreams fn
    /// 严格翻译自: proto.emitErrorToAllStreams { fn: "emitErrorToAllStreams", length: 1 }
    public static func emitErrorToAllStreams(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// emitAbortToAllStreams fn
    /// 严格翻译自: proto.emitAbortToAllStreams { fn: "emitAbortToAllStreams", length: 0 }
    public static func emitAbortToAllStreams(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// getNextStream fn
    /// 严格翻译自: proto.getNextStream { fn: "getNextStream", length: 0 }
    public static func getNextStream(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }
}
