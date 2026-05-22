// 严格翻译自: src/runtime/api/h2.classes.ts
package bao_runtime.api

import bao_jsc.*

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
    public static func request(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// setNativeSocket fn
    /// 严格翻译自: proto.setNativeSocket { fn: "setNativeSocketFromJS", length: 1 }
    public static func setNativeSocketFromJS(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// ping fn
    /// 严格翻译自: proto.ping { fn: "ping", length: 0 }
    public static func ping(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// altsvc fn
    /// 严格翻译自: proto.altsvc { fn: "altsvc", length: 3 }
    public static func altsvc(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// origin fn
    /// 严格翻译自: proto.origin { fn: "origin", length: 1 }
    public static func origin(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// goaway fn
    /// 严格翻译自: proto.goaway { fn: "goaway", length: 3 }
    public static func goaway(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// getCurrentState fn
    /// 严格翻译自: proto.getCurrentState { fn: "getCurrentState", length: 0 }
    public static func getCurrentState(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// settings fn
    /// 严格翻译自: proto.settings { fn: "updateSettings", length: 1 }
    public static func updateSettings(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// setLocalWindowSize fn
    /// 严格翻译自: proto.setLocalWindowSize { fn: "setLocalWindowSize", length: 1 }
    public static func setLocalWindowSize(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// read fn
    /// 严格翻译自: proto.read { fn: "read", length: 1 }
    public static func read(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// flush fn
    /// 严格翻译自: proto.flush { fn: "flushFromJS", length: 0 }
    public static func flushFromJS(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// detach fn
    /// 严格翻译自: proto.detach { fn: "detachFromJS", length: 0 }
    public static func detachFromJS(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// rstStream fn
    /// 严格翻译自: proto.rstStream { fn: "rstStream", length: 1 }
    public static func rstStream(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// writeStream fn
    /// 严格翻译自: proto.writeStream { fn: "writeStream", length: 3 }
    public static func writeStream(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// sendTrailers fn
    /// 严格翻译自: proto.sendTrailers { fn: "sendTrailers", length: 2 }
    public static func sendTrailers(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// noTrailers fn
    /// 严格翻译自: proto.noTrailers { fn: "noTrailers", length: 1 }
    public static func noTrailers(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// setStreamPriority fn
    /// 严格翻译自: proto.setStreamPriority { fn: "setStreamPriority", length: 2 }
    public static func setStreamPriority(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// getStreamContext fn
    /// 严格翻译自: proto.getStreamContext { fn: "getStreamContext", length: 1 }
    public static func getStreamContext(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// setStreamContext fn
    /// 严格翻译自: proto.setStreamContext { fn: "setStreamContext", length: 2 }
    public static func setStreamContext(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// getEndAfterHeaders fn
    /// 严格翻译自: proto.getEndAfterHeaders { fn: "getEndAfterHeaders", length: 1 }
    public static func getEndAfterHeaders(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// isStreamAborted fn
    /// 严格翻译自: proto.isStreamAborted { fn: "isStreamAborted", length: 1 }
    public static func isStreamAborted(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsBoolean(false)
    }

    /// getStreamState fn
    /// 严格翻译自: proto.getStreamState { fn: "getStreamState", length: 1 }
    public static func getStreamState(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// bufferSize fn
    /// 严格翻译自: proto.bufferSize { fn: "getBufferSize", length: 0 }
    public static func getBufferSize(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsNumber(0)
    }

    /// hasNativeRead fn
    /// 严格翻译自: proto.hasNativeRead { fn: "hasNativeRead", length: 1 }
    public static func hasNativeRead(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsBoolean(false)
    }

    /// setNextStreamID fn
    /// 严格翻译自: proto.setNextStreamID { fn: "setNextStreamID", length: 1 }
    public static func setNextStreamID(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// forEachStream fn
    /// 严格翻译自: proto.forEachStream { fn: "forEachStream", length: 2 }
    public static func forEachStream(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// emitErrorToAllStreams fn
    /// 严格翻译自: proto.emitErrorToAllStreams { fn: "emitErrorToAllStreams", length: 1 }
    public static func emitErrorToAllStreams(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// emitAbortToAllStreams fn
    /// 严格翻译自: proto.emitAbortToAllStreams { fn: "emitAbortToAllStreams", length: 0 }
    public static func emitAbortToAllStreams(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// getNextStream fn
    /// 严格翻译自: proto.getNextStream { fn: "getNextStream", length: 0 }
    public static func getNextStream(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }
}
