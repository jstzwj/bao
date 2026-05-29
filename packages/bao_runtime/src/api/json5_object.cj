// 严格翻译自: src/runtime/api/JSON5Object.zig
// Compile-gating stub for Bun.JSON5.
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue}

public class JSON5Object {
    public static func create(globalThis!: JsGlobalObject): JsValue {
        JsValue.jsUndefined()
    }

    public static func stringify(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        JsValue.jsUndefined()
    }

    public static func parse(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        JsValue.jsUndefined()
    }

    public static func exprToJS(expr!: Expr, global!: JsGlobalObject): JsValue {
        JsValue.jsUndefined()
    }
}

public class Stringifier {
    public var builder: ApiStringBuilder = ApiStringBuilder()

    public init() {}
    public init(global!: JsGlobalObject, spaceValue!: JsValue) {}

    public static func initFunc(global!: JsGlobalObject, spaceValue!: JsValue): Stringifier {
        Stringifier(global: global, spaceValue: spaceValue)
    }

    public func deinit(): Unit {}
    public func stringifyValue(global!: JsGlobalObject, value!: JsValue): Unit {}
    public func stringifyArray(global!: JsGlobalObject, value!: JsValue): Unit {}
    public func stringifyObject(global!: JsGlobalObject, value!: JsValue): Unit {}
    public func appendKey(name!: BunString): Unit {}
    public func appendQuotedString(str!: BunString): Unit {}
    public func newline(): Unit {}
}
