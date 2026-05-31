// PostgreSQL 错误响应 JSC 绑定
// 严格翻译自: bun/src/sql_jsc/postgres/protocol/error_response_jsc.zig
//   pub fn toJS(this: ErrorResponse, globalObject: *jsc.JSGlobalObject) JSValue
package bao_runtime.sql.postgresql


/// 错误响应 JSC 转换器
/// 对应 Bun error_response_jsc
/// 将 ErrorResponse 协议消息转为 JS Error 对象
public class ErrorResponseJSC {

    /// 将 ErrorResponse 转为 JS 错误对象
    /// 对应 Bun ErrorResponse.toJS()
    public static func toJS(errorResponse: ErrorResponse): JSPGError {
        // 收集各字段
        var severity = ""
        var code = ""
        var message = ""
        var detail = ""
        var hint = ""
        var position = ""
        var internalPosition = ""
        var internal = ""
        var whereClause = ""
        var schema = ""
        var table = ""
        var column = ""
        var dataType = ""
        var constraint = ""
        var file = ""
        var line = ""
        var routine = ""

        for (field in errorResponse.messages) {
            match (field.fieldType) {
                case FieldType.Severity => severity = field.value
                case FieldType.Code => code = field.value
                case FieldType.Message => message = field.value
                case FieldType.Detail => detail = field.value
                case FieldType.Hint => hint = field.value
                case FieldType.Position => position = field.value
                case FieldType.InternalPosition => internalPosition = field.value
                case FieldType.Internal => internal = field.value
                case FieldType.Where => whereClause = field.value
                case FieldType.Schema => schema = field.value
                case FieldType.Table => table = field.value
                case FieldType.Column => column = field.value
                case FieldType.Datatype => dataType = field.value
                case FieldType.Constraint => constraint = field.value
                case FieldType.File => file = field.value
                case FieldType.Line => line = field.value
                case FieldType.Routine => routine = field.value
                case _ => {}
            }
        }

        // 构建错误消息
        var errorMessage = ""
        if (!message.isEmpty) {
            errorMessage = message
        }

        // 确定错误代码
        let errno = if (!code.isEmpty) code else ""
        let errorCode = if (code == "42601") {
            // 语法错误
            "ERR_POSTGRES_SYNTAX_ERROR"
        } else {
            "ERR_POSTGRES_SERVER_ERROR"
        }

        return JSPGError(
            message: errorMessage,
            code: errorCode,
            errno: errno,
            detail: if (detail.isEmpty) None else detail,
            hint: if (hint.isEmpty) None else hint,
            severity: if (severity.isEmpty) None else severity,
            position: if (position.isEmpty) None else position,
            internalPosition: if (internalPosition.isEmpty) None else internalPosition,
            internalQuery: if (internal.isEmpty) None else internal,
            whereClause: if (whereClause.isEmpty) None else whereClause,
            schema: if (schema.isEmpty) None else schema,
            table: if (table.isEmpty) None else table,
            column: if (column.isEmpty) None else column,
            dataType: if (dataType.isEmpty) None else dataType,
            constraint: if (constraint.isEmpty) None else constraint,
            file: if (file.isEmpty) None else file,
            line: if (line.isEmpty) None else line,
            routine: if (routine.isEmpty) None else routine
        )
    }
}
