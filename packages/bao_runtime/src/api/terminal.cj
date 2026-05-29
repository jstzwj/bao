// BAO_STUB: compile gate for src/runtime/api/bun/Terminal.rs.
// TODO(bao-runtime-api): restore the full PTY, termios, reader/writer, and generated JSTerminal bindings.
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame}

public class Terminal {
    public init() {}
    public static func constructor(globalThis!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        JsValue.jsUndefined()
    }
    public func close(globalThis!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        JsValue.jsUndefined()
    }
    public func finalize(): Unit {}
}
