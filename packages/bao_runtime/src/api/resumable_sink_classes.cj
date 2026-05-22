// 严格翻译自: src/runtime/api/ResumableSink.classes.ts
package bao_runtime.api

import bao_jsc.*

// ============================================================================
// ResumableSink.classes.ts 类绑定定义
// Bun: ResumableFetchSink, ResumableS3UploadSink 的 JSC 绑定
// sharedThis: false, construct: true, finalize: true, configurable: false
// values: ["ondrain", "oncancel", "stream"]
// ============================================================================

// ============================================================================
// ResumableFetchSink - 可恢复的 Fetch 上传接收器
// 严格翻译自: generate("ResumableFetchSink")
// ============================================================================

/// ResumableFetchSink JSC 绑定
/// Bun: 用于 fetch 上传的可恢复接收器
public class ResumableFetchSinkClasses {

    /// start fn
    /// 严格翻译自: proto.start { fn: "jsStart", length: 1 }
    public static func jsStart(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// write fn
    /// 严格翻译自: proto.write { fn: "jsWrite", length: 1 }
    public static func jsWrite(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// end fn
    /// 严格翻译自: proto.end { fn: "jsEnd", length: 1 }
    public static func jsEnd(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// setHandlers fn (passThis: true)
    /// 严格翻译自: proto.setHandlers { fn: "jsSetHandlers", length: 2, passThis: true }
    public static func jsSetHandlers(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }
}

// ============================================================================
// ResumableS3UploadSink - 可恢复的 S3 上传接收器
// 严格翻译自: generate("ResumableS3UploadSink")
// ============================================================================

/// ResumableS3UploadSink JSC 绑定
/// Bun: 用于 S3 分片上传的可恢复接收器
public class ResumableS3UploadSinkClasses {

    /// start fn
    /// 严格翻译自: proto.start { fn: "jsStart", length: 1 }
    public static func jsStart(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// write fn
    /// 严格翻译自: proto.write { fn: "jsWrite", length: 1 }
    public static func jsWrite(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// end fn
    /// 严格翻译自: proto.end { fn: "jsEnd", length: 1 }
    public static func jsEnd(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// setHandlers fn (passThis: true)
    /// 严格翻译自: proto.setHandlers { fn: "jsSetHandlers", length: 2, passThis: true }
    public static func jsSetHandlers(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        return JsValue.jsUndefined()
    }
}
