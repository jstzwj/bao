// 严格翻译自: src/sql_jsc/postgres/protocol/error_response_jsc.zig
// Postgres 错误响应 JS 转换

package bao_sql_jsc.postgres.protocol

import bao_core.*
import bao_jsc.*

/// 错误响应 JS 转换
/// 对应 Bun: protocol/error_response_jsc.zig
/// 将 PostgreSQL ErrorResponse 转换为 JS 错误对象

/// ErrorResponse 转 JS 错误对象
/// 对应 Bun: ErrorResponse.toJS
public func errorResponseToJS(errorResponse: ErrorResponse,
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
            case Severity(s) => severity = s
            case Code(c) => code = c
            case Message(m) => message = m
            case Detail(d) => detail = d
            case Hint(h) => hint = h
            case Position(p) => position = p
            case InternalPosition(p) => internalPosition = p
            case Internal(q) => internalQuery = q
            case Where(w) => where_ = w
            case Schema(s) => schema = s
            case Table(t) => table = t
            case Column(c) => column = c
            case DataType(d) => dataType = d
            case Constraint(c) => constraint = c
            case File(f) => file = f
            case Line(l) => line = l
            case Routine(r) => routine = r
            case _ => ()
        }
    }

    // 构建错误消息
    var errorBuilder = StringBuilder()
    if (message.size > 0) {
        errorBuilder.append(message)
    }
    if (detail.size > 0) {
        errorBuilder.append("\n")
        errorBuilder.append(detail)
    }
    if (hint.size > 0) {
        errorBuilder.append("\n")
        errorBuilder.append(hint)
    }

    let errorCodes = if (code == "42601") "ERR_POSTGRES_SYNTAX_ERROR" else "ERR_POSTGRES_SERVER_ERROR"

    // 创建 JS 错误对象
    let optsObj = JscObject.createEmptyObject(globalObject)
    optsObj.put(globalObject, "code", JscValue(errorCodes))
    if (code.size > 0) {
        optsObj.put(globalObject, "errno", JscValue(code))
    }
    optsObj.put(globalObject, "message", JscValue(errorBuilder.toString()))

    // 可选字段
    if (detail.size > 0) {
        optsObj.put(globalObject, "detail", JscValue(detail))
    }
    if (hint.size > 0) {
        optsObj.put(globalObject, "hint", JscValue(hint))
    }
    if (severity.size > 0) {
        optsObj.put(globalObject, "severity", JscValue(severity))
    }
    if (position.size > 0) {
        optsObj.put(globalObject, "position", JscValue(position))
    }
    if (schema.size > 0) {
        optsObj.put(globalObject, "schema", JscValue(schema))
    }
    if (table.size > 0) {
        optsObj.put(globalObject, "table", JscValue(table))
    }
    if (column.size > 0) {
        optsObj.put(globalObject, "column", JscValue(column))
    }

    return optsObj.toValue()
}
