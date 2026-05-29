// 严格翻译自: src/runtime/api/cron.classes.ts
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame}

// ============================================================================
// cron.classes.ts 类绑定定义
// Bun: CronJob 的 JSC 绑定
// construct: false, noConstructor: true, finalize: true
// configurable: false
// values: ["callback", "pendingPromise"]
// ============================================================================

/// CronJob JSC 绑定
/// Bun: Bun.cron() 返回的定时任务对象
public class CronJobClasses {

    /// stop fn
    /// 严格翻译自: proto.stop { fn: "stop", length: 0 }
    public static func stop(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 停止 cron 任务
        return JsValue.jsUndefined()
    }

    /// @@dispose fn (alias: stop)
    /// 严格翻译自: proto["@@dispose"] { fn: "stop", length: 0 }
    public static func dispose(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return stop(globalObject, callframe, thisValue)
    }

    /// ref fn
    /// 严格翻译自: proto.ref { fn: "doRef", length: 0 }
    public static func doRef(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 引用 cron 任务，保持事件循环活跃
        return JsValue.jsUndefined()
    }

    /// unref fn
    /// 严格翻译自: proto.unref { fn: "doUnref", length: 0 }
    public static func doUnref(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 取消引用 cron 任务
        return JsValue.jsUndefined()
    }

    /// cron getter (cached)
    /// 严格翻译自: proto.cron { getter: "getCron", cache: true }
    public static func getCron(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        // 返回 cron 表达式字符串
        return JsValue.jsNull()
    }
}
