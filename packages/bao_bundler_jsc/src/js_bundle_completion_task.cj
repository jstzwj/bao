// 严格翻译自: src/bundler_jsc/JSBundleCompletionTask.zig
//! `JSBundleCompletionTask` and the JS-facing entrypoints for `Bun.build()`.
package bao_bundler_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// JSBundleCompletionTask - JS Bundle 完成任务
// ============================================================================

public enum JSBundleCompletionState {
    | Pending
    | Running
    | Completed
    | Cancelled
    | Failed(String)
}

/// JS Bundle 完成任务
public class JSBundleCompletionTask {
    public var cancelled: Bool
    public var refCount: Int64
    public var state: JSBundleCompletionState
    public var startedAtNs: Int64
    public var outputFiles: ArrayList<JsValue>
    public var errors: ArrayList<String>

    public init() {
        cancelled = false
        refCount = 1
        state = JSBundleCompletionState.Pending
        startedAtNs = 0
        outputFiles = ArrayList<JsValue>()
        errors = ArrayList<String>()
    }

    public func ref(): Unit {
        refCount++
    }

    public func deref(): Unit {
        if (refCount > 0) { refCount-- }
    }

    public func cancel(): Unit {
        cancelled = true
        state = JSBundleCompletionState.Cancelled
    }

    public func toJS(globalThis: JSGlobalObject): JsValue {
        let obj = JsObject.make()
        obj.set("cancelled", JsValue(cancelled))
        obj.set("refCount", JsValue(refCount))
        obj.set("state", JsValue(stateToString()))
        obj.set("outputCount", JsValue(Int64(outputFiles.size)))
        obj.set("errorCount", JsValue(Int64(errors.size)))
        return JsValue(obj)
    }

    private func stateToString(): String {
        match (state) {
            case JSBundleCompletionState.Pending => "pending"
            case JSBundleCompletionState.Running => "running"
            case JSBundleCompletionState.Completed => "completed"
            case JSBundleCompletionState.Cancelled => "cancelled"
            case JSBundleCompletionState.Failed(_) => "failed"
        }
    }
}

/// 从 JavaScript 生成 bundle
public func generateFromJavaScript(
    globalThis: JSGlobalObject,
    alloc: Allocator
): JsValue {
    let completion = JSBundleCompletionTask()
    completion.state = JSBundleCompletionState.Failed("Bun.build scheduling requires JSBundler.Config and EventLoop integration")
    completion.errors.append("Bun.build scheduling requires JSBundler.Config and EventLoop integration")
    return completion.toJS(globalThis)
}
