// 严格翻译自: src/runtime/api/JSTranspiler.zig
// Compile-gating stub: keeps the public API shape while the real transpiler is ported.
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame}
import bao_core.Allocator
import bao_collections.ArrayList

public class Config {
    public init() {}
    public static func fromJS(config: Config, globalThis: JsGlobalObject, object: JsValue, allocator: Allocator): Unit {}
}

public class ScanPassResult { public init() {} }
public class JsPrinterBufferWriter { public init() {}; public init(alloc: Any) {} }
public class LoggerLogLevel { public init() {} }
public class MacroJSCtx {
    public static let zero: MacroJSCtx = MacroJSCtx()
    public init() {}
}
public class TransformOptions { public init() {} }
public class ParseResult { public init() {} }

public enum ExprData {
    | eNull
    | eBoolean(Bool)
    | eNumber(Float64)
    | eString(BunString)
    | eArray(Array<Expr>)
    | eObject(Array<Expr>)
    | eUndefined
}

public class Expr {
    public var data: ExprData = ExprData.eUndefined
    public init() {}
    public init(data!: ExprData) {
        this.data = data
    }
}

public class NamedExports {
    public init() {}
    public func count(): Int64 { 0 }
}

public class ImportRecord {
    public init() {}
}

public class Space {
    public init() {}
    public init(global!: JsGlobalObject, spaceValue!: JsValue) {
    }

    public func deinit(): Unit {}
}

public class BunString {
    public var value: String = ""

    public init() {}
    public init(value!: String) {
        this.value = value
    }

    public static let empty: BunString = BunString()
    public static func createStatic(s: String): BunString { BunString(value: s) }
    public static func cloneUTF8(s: String): BunString { BunString(value: s) }
    public static func cloneUtf8(s: String): BunString { BunString(value: s) }
    public static func fromBytes(bytes: Array<UInt8>): BunString { BunString() }
    public static func borrowUTF8(s: String): BunString { BunString(value: s) }
    public static func toJSArray(global: JsGlobalObject, names: Array<BunString>): JsValue { JsValue.jsUndefined() }

    public func toJS(global: JsGlobalObject): JsValue { JsValue.jsString(value) }
    public func toJS(allocator: Allocator, global: JsGlobalObject): JsValue { JsValue.jsString(value) }
    public func toString(): String { value }
    public func slice(): String { value }
    public func size(): Int64 { value.size }
    public func count(): Int64 { value.size }
    public func isEmpty(): Bool { value.size == 0 }
    public func charAt(i!: Int64): Rune {
        if (i < 0 || i >= value.size) { return Rune(0) }
        return Rune(value[i])
    }
    public func substringWithLen(start!: Int64, len!: Int64): BunString {
        if (start < 0 || start >= value.size || len <= 0) { return BunString() }
        let end = if (start + len > value.size) { value.size } else { start + len }
        return BunString(value: value[start..end])
    }
    public func eqlComptime(expected!: String): Bool { value == expected }
    public func deref(): Unit {}
}

public class JSTranspiler {
    public var config: Config = Config()
    public var scanPassResult: ScanPassResult = ScanPassResult()
    public var bufferWriter: ?JsPrinterBufferWriter = None
    public var logLevel: LoggerLogLevel = LoggerLogLevel()
    public static let defaultTransformOptions: TransformOptions = TransformOptions()

    public init() {}

    public static func constructor(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JSTranspiler {
        JSTranspiler()
    }

    public func transform(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        JsValue.jsUndefined()
    }

    public func transformSync(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        JsValue.jsUndefined()
    }

    public func scan(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        JsValue.jsUndefined()
    }

    public func scanImports(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        JsValue.jsUndefined()
    }

    public func ref(): Unit {}
    public func deref(): Unit {}
    public func finalize(): Unit {}
    public func deinit(): Unit {}
}

public func exportReplacementValue(value!: JsValue, globalThis!: JsGlobalObject, allocator!: Allocator): ?Expr {
    None
}

public func namedExportsToJS(global!: JsGlobalObject, namedExports!: NamedExports): JsValue {
    JsValue.jsUndefined()
}

public func namedImportsToJS(global!: JsGlobalObject, importRecords!: Array<ImportRecord>, trimUnusedImports!: Bool): JsValue {
    JsValue.jsUndefined()
}
