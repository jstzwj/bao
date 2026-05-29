// BAO_STUB: compile gate for src/runtime/api/standalone_graph_jsc.zig.
// TODO(bao-runtime-api): restore StandaloneModuleGraph JSC generation and Blob bridge.
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame}

/// StandaloneModuleGraphJSC — 独立模块图的 JS 绑定
public class StandaloneModuleGraphJSC {
    public init() {}
    public static func generateFromGraph(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        JsValue.jsUndefined()
    }
}
