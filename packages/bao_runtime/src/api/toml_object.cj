// BAO_STUB: compile gate for src/runtime/api/TOMLObject.zig.
// TODO(bao-runtime-api): restore TOML parser, Logger diagnostics, and JSON printer bridge.
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame}

public func create(globalThis!: JsGlobalObject): JsValue {
    JsValue.jsUndefined()
}

public func parse(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
    JsValue.jsUndefined()
}
