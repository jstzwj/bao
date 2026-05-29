// 严格翻译自: src/runtime/api/cron.rs
// TODO: 完整实现需要进程管理和 cron 调度支持
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame}
import bao_core.{Allocator, Output}

/// SpawnStatus stub
public class SpawnStatus {
    public var exitCode: Int32 = 0
    public var signal: Int32 = 0
    public init() {}
}

/// OutputReader stub
public class OutputReader {
    public init() {}
}

/// CronRegisterJob — cron 注册任务
public class CronRegisterJob {
    public init() {}
    public static func constructor(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): Maybe<CronRegisterJob> {
        Maybe<CronRegisterJob>.Ok(CronRegisterJob())
    }
    public func `spawn`(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue { JsValue.jsUndefined() }
    public func finalize(): Unit {}
}

/// CronRemoveJob — cron 移除任务
public class CronRemoveJob {
    public init() {}
    public static func constructor(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): Maybe<CronRemoveJob> {
        Maybe<CronRemoveJob>.Ok(CronRemoveJob())
    }
    public func `spawn`(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue { JsValue.jsUndefined() }
    public func finalize(): Unit {}
}
