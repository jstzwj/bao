// 严格翻译自: src/runtime/api/glob.zig
// TODO: 恢复完整 Glob 模式匹配、同步/异步扫描和 pending activity 语义。
package bao_runtime.api

import bao_jsc.{ConcurrentPromiseTaskGeneric, JsGlobalObject, JsValue}

public class Arena {
    public init() {}
    public func deinit(): Unit {}
}

public class GlobWalker {
    public init() {}
}

public class Glob {
    public var pattern: String = ""

    public init() {}
    public init(pattern: String) {
        this.pattern = pattern
    }

    public static func constructor(globalThis!: JsGlobalObject, callframe!: JsCallFrame): Glob {
        return Glob()
    }

    public func finalize(): Unit {}

    public func getHasPendingActivity(): Bool {
        return false
    }

    public func scan(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return JsValue.createEmptyArray(globalThis.globalThis, 0)
    }

    public func scanSync(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return JsValue.createEmptyArray(globalThis.globalThis, 0)
    }

    public func `match`(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return JsValue.jsBoolean(false)
    }
}

func globWalkResultToJS(globWalk!: GlobWalker, globalThis!: JsGlobalObject): JsValue {
    return JsValue.createEmptyArray(globalThis.globalThis, 0)
}

public type AsyncGlobWalkTask = ConcurrentPromiseTaskGeneric
