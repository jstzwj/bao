// 严格翻译自: src/runtime/api/streams.classes.ts
package bao_runtime.api

import bao_jsc.*

// ============================================================================
// streams.classes.ts 类绑定定义
// Bun: Blob/File/Bytes InternalReadableStreamSource 的 JSC 绑定
// sharedThis: false, construct: false, noConstructor: true, finalize: true
// configurable: false, memoryCost: true
// values: ["pendingPromise", "onCloseCallback", "onDrainCallback"]
// ============================================================================

// ============================================================================
// InternalReadableStreamSource - 可读流内部源 (共享接口)
// BlobInternalReadableStreamSource, FileInternalReadableStreamSource,
// BytesInternalReadableStreamSource 共享相同的原型方法
// ============================================================================

/// InternalReadableStreamSource JSC 绑定 (Blob/File/Bytes 共享)
public class InternalReadableStreamSourceClasses {

    /// drain fn
    /// 严格翻译自: proto.drain { fn: "drainFromJS", length: 1 }
    public static func drainFromJS(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        // 排空流中的数据到消费者
        return JsValue.jsUndefined()
    }

    /// start fn
    /// 严格翻译自: proto.start { fn: "startFromJS", length: 1 }
    public static func startFromJS(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        // 启动流读取
        return JsValue.jsUndefined()
    }

    /// updateRef fn
    /// 严格翻译自: proto.updateRef { fn: "updateRefFromJS", length: 1 }
    public static func updateRefFromJS(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        // 更新引用计数
        return JsValue.jsUndefined()
    }

    /// onClose getter/setter
    /// 严格翻译自: proto.onClose { getter: "getOnCloseFromJS", setter: "setOnCloseFromJS" }
    public static func getOnCloseFromJS(JsGlobalObject, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// setOnCloseFromJS setter
    public static func setOnCloseFromJS(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// onDrain getter/setter
    /// 严格翻译自: proto.onDrain { getter: "getOnDrainFromJS", setter: "setOnDrainFromJS" }
    public static func getOnDrainFromJS(JsGlobalObject, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// setOnDrainFromJS setter
    public static func setOnDrainFromJS(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// cancel fn
    /// 严格翻译自: proto.cancel { fn: "cancelFromJS", length: 1 }
    public static func cancelFromJS(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// pull fn
    /// 严格翻译自: proto.pull { fn: "pullFromJS", length: 1 }
    public static func pullFromJS(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// isClosed getter
    /// 严格翻译自: proto.isClosed { getter: "getIsClosedFromJS" }
    public static func getIsClosedFromJS(JsGlobalObject, thisValue: JsValue): JsValue {
        return JsValue.jsBoolean(false)
    }

    // ========================================================================
    // Blob/Bytes 特有方法 (File 不包含这些)
    // ========================================================================

    /// text fn — Blob/Bytes only, not File
    /// 严格翻译自: proto.text { fn: "textFromJS", length: 0 } (name !== "File")
    public static func textFromJS(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        // 返回 Promise<string>
        return JsValue.jsUndefined()
    }

    /// json fn — Blob/Bytes only, not File
    /// 严格翻译自: proto.json { fn: "jsonFromJS", length: 0 } (name !== "File")
    public static func jsonFromJS(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        // 返回 Promise<any>
        return JsValue.jsUndefined()
    }

    /// arrayBuffer fn — Blob/Bytes only, not File
    /// 严格翻译自: proto.arrayBuffer { fn: "arrayBufferFromJS", length: 0 } (name !== "File")
    public static func arrayBufferFromJS(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        // 返回 Promise<ArrayBuffer>
        return JsValue.jsUndefined()
    }

    /// blob fn — Blob/Bytes only, not File
    /// 严格翻译自: proto.blob { fn: "blobFromJS", length: 0 } (name !== "File")
    public static func blobFromJS(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        // 返回 Promise<Blob>
        return JsValue.jsUndefined()
    }

    /// bytes fn — Blob/Bytes only, not File
    /// 严格翻译自: proto.bytes { fn: "bytesFromJS", length: 0 } (name !== "File")
    public static func bytesFromJS(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        // 返回 Promise<Uint8Array>
        return JsValue.jsUndefined()
    }

    // ========================================================================
    // File 特有方法
    // ========================================================================

    /// setRawMode fn — File only
    /// 严格翻译自: proto.setRawMode { fn: "setRawModeFromJS", length: 1 } (name === "File")
    public static func setRawModeFromJS(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// setFlowing fn — File only
    /// 严格翻译自: proto.setFlowing { fn: "setFlowingFromJS", length: 1 } (name === "File")
    public static func setFlowingFromJS(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }
}
