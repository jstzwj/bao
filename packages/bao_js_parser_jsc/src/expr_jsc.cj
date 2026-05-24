// 严格翻译自: src/js_parser_jsc/expr_jsc.zig
//! `Expr.toJS` / `E.*.toJS` — converts parsed AST literals into JSC values.
package bao_js_parser_jsc

import bao_ast.*
import bao_jsc.JsValue
import bao_jsc.JSGlobalObject
import bao_core.Result

public type ToJSResult = Result<JsValue, ToJSError>

public func exprToJS(this: ASTNode, globalObject: JSGlobalObject): ToJSResult {
    return dataToJS(ExprData.fromASTNode(this), globalObject)
}

public func dataToJS(this: ExprData, globalObject: JSGlobalObject): ToJSResult {
    match (this.tag) {
        case EArray =>
            match (this.payload) {
                case arr: EArray => return arrayToJS(arr, globalObject)
                case _ => return ToJSResult.Err(ToJSError.CannotConvertArgumentTypeToJS)
            }
        case EObject =>
            match (this.payload) {
                case obj: EObject => return objectToJS(obj, globalObject)
                case _ => return ToJSResult.Err(ToJSError.CannotConvertArgumentTypeToJS)
            }
        case EString =>
            match (this.payload) {
                case str: EString => return stringToJS(str, globalObject)
                case s: String => return ToJSResult.Ok(JsValue(s))
                case _ => return ToJSResult.Err(ToJSError.CannotConvertArgumentTypeToJS)
            }
        case ENull => return ToJSResult.Ok(JsValue.jsNull())
        case EUndefined => return ToJSResult.Ok(JsValue.jsUndefined())
        case EBoolean | EBranchBoolean =>
            match (this.payload) {
                case boolean: EBoolean => return ToJSResult.Ok(boolToJS(boolean, globalObject))
                case b: Bool => return ToJSResult.Ok(JsValue.jsBoolean(b))
                case _ => return ToJSResult.Err(ToJSError.CannotConvertArgumentTypeToJS)
            }
        case ENumber =>
            match (this.payload) {
                case number: ENumber => return ToJSResult.Ok(numberToJS(number))
                case n: Float64 => return ToJSResult.Ok(JsValue.jsNumber(n))
                case _ => return ToJSResult.Err(ToJSError.CannotConvertArgumentTypeToJS)
            }
        case EInlinedEnum =>
            match (this.payload) {
                case inlined: EInlinedEnum => return exprToJS(inlined.value, globalObject)
                case _ => return ToJSResult.Err(ToJSError.CannotConvertArgumentTypeToJS)
            }
        case EIdentifier | EImportIdentifier | EPrivateIdentifier | ECommonJSExportIdentifier =>
            return ToJSResult.Err(ToJSError.CannotConvertIdentifierToJS)
        case _ => return ToJSResult.Err(ToJSError.CannotConvertArgumentTypeToJS)
    }
}

public func arrayToJS(this: EArray, globalObject: JSGlobalObject): ToJSResult {
    let array = JsValue.createEmptyArray(globalObject.globalThis, this.items.size)
    var index: Int64 = 0
    for (expr in this.items) {
        match (exprToJS(expr, globalObject)) {
            case Ok(value) => array.putIndex(globalObject.globalThis, UInt32(index), value)
            case Err(err) => return ToJSResult.Err(err)
        }
        index += 1
    }
    return ToJSResult.Ok(array)
}

public func boolToJS(this: EBoolean, globalObject: JSGlobalObject): JsValue {
    return JsValue.jsBoolean(this.value)
}

public func numberToJS(this: ENumber): JsValue {
    return JsValue.jsNumber(this.value)
}

public func bigIntToJS(this: EBigInt): ToJSResult {
    return ToJSResult.Err(ToJSError.CannotConvertArgumentTypeToJS)
}

public func objectToJS(this: EObject, globalObject: JSGlobalObject): ToJSResult {
    let object = JsValue.createEmptyObject(globalObject.globalThis, this.properties.size)
    for (prop in this.properties) {
        if (prop.kind != PropertyKind.Normal || prop.classStaticBlock.isSome() ||
            prop.key.isNone() || prop.value.isNone()) {
            return ToJSResult.Err(ToJSError.CannotConvertArgumentTypeToJS)
        }

        let keyExpr = prop.key.getOrThrow()
        let valueExpr = prop.value.getOrThrow()
        let keyResult = exprToJS(keyExpr, globalObject)
        let valueResult = exprToJS(valueExpr, globalObject)

        let key = match (keyResult) {
            case Ok(value) => value
            case Err(err) => return ToJSResult.Err(err)
        }
        let value = match (valueResult) {
            case Ok(value) => value
            case Err(err) => return ToJSResult.Err(err)
        }

        object.put(globalObject.globalThis, key.toString(), value)
    }
    return ToJSResult.Ok(object)
}

public func stringToJS(this: EString, globalObject: JSGlobalObject): ToJSResult {
    this.resolveRopeIfNeeded()
    return ToJSResult.Ok(JsValue(this.data))
}
