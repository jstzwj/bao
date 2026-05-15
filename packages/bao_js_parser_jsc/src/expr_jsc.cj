// 严格翻译自: src/js_parser_jsc/expr_jsc.zig
//! `Expr.toJS` / `E.*.toJS` — converts a parsed AST literal into a runtime
//! `JSValue`. Used by the macro system. The AST types stay in `js_parser/`;
//! only the JS-materialization lives here.
package bao_js_parser_jsc

import bao_jsc.*
import bao_core.*
import bao_parser.*

// ============================================================================
// ExprJSC - Expr 的 JSC 桥接转换函数
// 严格翻译自: src/js_parser_jsc/expr_jsc.zig:5-101
// ============================================================================

/// Expr 转 JS - 严格对应 Bun exprToJS
/// Zig: pub fn exprToJS(this: Expr, allocator: std.mem.Allocator, globalObject: *jsc.JSGlobalObject) ToJSError!jsc.JSValue
public func exprToJS(`this`: Expr, allocator: Allocator, globalObject: JSGlobalObject): ?JSValue {
    return dataToJS(this.data, allocator, globalObject)
}

/// Expr.Data 转 JS - 严格对应 Bun dataToJS
/// Zig: pub fn dataToJS(this: Expr.Data, allocator: std.mem.Allocator, globalObject: *jsc.JSGlobalObject) ToJSError!jsc.JSValue
public func dataToJS(`this`: ExprData, allocator: Allocator, globalObject: JSGlobalObject): ?JSValue {
    return match (this) {
        case .e_array => e =>
            arrayToJS(e, allocator, globalObject)
        case .e_object => e =>
            objectToJS(e, allocator, globalObject)
        case .e_string => e =>
            stringToJS(e, allocator, globalObject)
        case .e_null =>
            JSValue.null
        case .e_undefined =>
            JSValue.jsUndefined
        case .e_boolean => boolean =>
            if (boolean.value) JSValue.jscTrue else JSValue.jscFalse
        case .e_branch_boolean => boolean =>
            if (boolean.value) JSValue.jscTrue else JSValue.jscFalse
        case .e_number => e =>
            numberToJS(e)
        case .e_inlined_enum => inlined =>
            dataToJS(inlined.value.data, allocator, globalObject)
        case .e_identifier =>
            // Cannot convert identifier to JS. Try a statically-known value
            None
        case .e_import_identifier =>
            None
        case .e_private_identifier =>
            None
        case .e_commonjs_export_identifier =>
            None
        default =>
            // Cannot convert argument type to JS
            None
    }
}

/// Array 转 JS - 严格对应 Bun arrayToJS
/// Zig: pub fn arrayToJS(this: E.Array, allocator: std.mem.Allocator, globalObject: *jsc.JSGlobalObject) ToJSError!jsc.JSValue
public func arrayToJS(`this`: EArray, allocator: Allocator, globalObject: JSGlobalObject): ?JSValue {
    let items = this.items.slice()
    var array = JSValue.createEmptyArray(globalObject, items.length)
    array.protect()

    for (i in 0..items.length) {
        let itemValue = dataToJS(items[i].data, allocator, globalObject)
        if (itemValue == None) {
            array.unprotect()
            return None
        }
        array.putIndex(globalObject, UInt32(i), itemValue)
    }

    array.unprotect()
    return array
}

/// Boolean 转 JS - 严格对应 Bun boolToJS
/// Zig: pub fn boolToJS(this: E.Boolean, ctx: *jsc.C.JSContextRef) jsc.C.JSValueRef
public func boolToJS(`this`: EBoolean, ctx: JSContextRef): JSValueRef {
    return JSValueMakeBoolean(ctx, this.value)
}

/// Number 转 JS - 严格对应 Bun numberToJS
/// Zig: pub fn numberToJS(this: E.Number) jsc.JSValue
public func numberToJS(`this`: ENumber): JSValue {
    return JSValue.jsNumber(this.value)
}

/// BigInt 转 JS - 严格对应 Bun bigIntToJS
/// Zig: pub fn bigIntToJS(_: E.BigInt) jsc.JSValue
public func bigIntToJS(`this`: EBigInt): JSValue {
    // TODO:
    return JSValue.jsNumber(0)
}

/// Object 转 JS - 严格对应 Bun objectToJS
/// Zig: pub fn objectToJS(this: *E.Object, allocator: std.mem.Allocator, globalObject: *jsc.JSGlobalObject) ToJSError!jsc.JSValue
public func objectToJS(`this`: EObject, allocator: Allocator, globalObject: JSGlobalObject): ?JSValue {
    var obj = JSValue.createEmptyObject(globalObject, this.properties.length)
    obj.protect()

    let props: Array<GProperty> = this.properties.slice()
    for (i in 0..props.length) {
        let prop = props[i]
        if (prop.kind != PropertyKind.normal || prop.classStaticBlock != None || prop.key == None || prop.value == None) {
            obj.unprotect()
            return None
        }
        let key = dataToJS(prop.key.data, allocator, globalObject)
        if (key == None) {
            obj.unprotect()
            return None
        }
        let value = exprToJS(prop.value, allocator, globalObject)
        if (value == None) {
            obj.unprotect()
            return None
        }
        obj.putToPropertyKey(globalObject, key, value)
    }

    obj.unprotect()
    return obj
}

/// String 转 JS - 严格对应 Bun stringToJS
/// Zig: pub fn stringToJS(s: *E.String, allocator: std.mem.Allocator, globalObject: *jsc.JSGlobalObject) !jsc.JSValue
public func stringToJS(s: EString, allocator: Allocator, globalObject: JSGlobalObject): ?JSValue {
    s.resolveRopeIfNeeded(allocator)
    if (!s.isPresent()) {
        let emp = BaoString.empty
        return emp.toJS(globalObject)
    }

    if (s.isUTF8()) {
        if (let utf16 = strings.toUTF16Alloc(allocator, s.slice8(), false, false)) {
            let (out, chars) = BaoString.createUninitialized(.utf16, utf16.length)
            memCopy(chars, utf16)
            return out.transferToJS(globalObject)
        } else {
            let (out, chars) = BaoString.createUninitialized(.latin1, s.slice8().length)
            memCopy(chars, s.slice8())
            return out.transferToJS(globalObject)
        }
    } else {
        let (out, chars) = BaoString.createUninitialized(.utf16, s.slice16().length)
        memCopy(chars, s.slice16())
        return out.transferToJS(globalObject)
    }
}
