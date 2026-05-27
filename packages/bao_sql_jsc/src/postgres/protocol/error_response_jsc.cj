// 严格翻译自: src/sql_jsc/postgres/protocol/error_response_jsc.zig
// Postgres 错误响应 JS 转换

package bao_sql_jsc.postgres.protocol

import bao_core.*
import bao_jsc.*
import bao_sql_jsc.postgres.JscErrorResponse
import bao_sql_jsc.postgres.ErrorField

/// 错误响应 JS 转换
/// 对应 Bun: protocol/error_response_jsc.zig
/// 将 PostgreSQL JscErrorResponse 转换为 JS 错误对象

/// JscErrorResponse 转 JS 错误对象
/// 对应 Bun: JscErrorResponse.toJS
public func errorResponseToJS(errorResponse: JscErrorResponse,
                                globalObject: JscJSGlobalObject): JscValue {
    var message = ""
    var code = ""
    var severity = ""
    var detail = ""
    var hint = ""
    var position = ""
    var internalPosition = ""
    var internalQuery = ""
    var where_ = ""
    var schema = ""
    var table = ""
    var column = ""
    var dataType = ""
    var constraint = ""
    var file = ""
    var line = ""
    var routine = ""

    // 解析错误字段
    for (field in errorResponse.messages) {
        match (field) {
            case ErrorField.Severity(s) => severity = s
            case ErrorField.Code(c) => code = c
            case ErrorField.Message(m) => message = m
            case ErrorField.Detail(d) => detail = d
            case ErrorField.Hint(h) => hint = h
            case ErrorField.Position(p) => position = p
            case ErrorField.InternalPosition(p) => internalPosition = p
            case ErrorField.Internal(q) => internalQuery = q
            case ErrorField.Where(w) => where_ = w
            case ErrorField.Schema(s) => schema = s
            case ErrorField.Table(t) => table = t
            case ErrorField.Column(c) => column = c
            case ErrorField.DataType(d) => dataType = d
            case ErrorField.Constraint(c) => constraint = c
            case ErrorField.File(f) => file = f
            case ErrorField.Line(l) => line = l
            case ErrorField.Routine(r) => routine = r
            case _ => ()
        }
    }

    // 构建错误消息
    var errorMessage = message
    if (detail.size > 0) {
        errorMessage = errorMessage + "\n" + detail
    }
    if (hint.size > 0) {
        errorMessage = errorMessage + "\n" + hint
    }

    let errorCodes = if (code == "42601") { "ERR_POSTGRES_SYNTAX_ERROR" } else { "ERR_POSTGRES_SERVER_ERROR" }

    // 创建 JS 错误对象
    let optsObj = JsValue.createEmptyObject(globalObject.globalThis)
    optsObj.put(globalObject.globalThis, "code", JscValue(errorCodes))
    if (code.size > 0) {
        optsObj.put(globalObject.globalThis, "errno", JscValue(code))
    }
    optsObj.put(globalObject.globalThis, "message", JscValue(errorMessage))

    // 可选字段
    if (detail.size > 0) {
        optsObj.put(globalObject.globalThis, "detail", JscValue(detail))
    }
    if (hint.size > 0) {
        optsObj.put(globalObject.globalThis, "hint", JscValue(hint))
    }
    if (severity.size > 0) {
        optsObj.put(globalObject.globalThis, "severity", JscValue(severity))
    }
    if (position.size > 0) {
        optsObj.put(globalObject.globalThis, "position", JscValue(position))
    }
    if (schema.size > 0) {
        optsObj.put(globalObject.globalThis, "schema", JscValue(schema))
    }
    if (table.size > 0) {
        optsObj.put(globalObject.globalThis, "table", JscValue(table))
    }
    if (column.size > 0) {
        optsObj.put(globalObject.globalThis, "column", JscValue(column))
    }

    return optsObj
}
