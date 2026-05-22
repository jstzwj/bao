// 严格翻译自: src/js_parser_jsc/expr_jsc.zig
//! `Expr.toJS` - stub implementation.
package bao_js_parser_jsc

import bao_jsc.JsValue
import bao_jsc.JSGlobalObject
import bao_core.Allocator

// ============================================================================
// Stubs
// ============================================================================

public func exprToJS(): ?JsValue {
    return None
}

public func dataToJS(): ?JsValue {
    return None
}

public func arrayToJS(): ?JsValue {
    return None
}

public func numberToJS(): JsValue {
    return JsValue.jsNumber(0)
}
