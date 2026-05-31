// PostgreSQL 错误 JSC 绑定
// 严格翻译自: bun/src/sql_jsc/postgres/error_jsc.zig
//   pub fn createPostgresError(globalObject, message, options) bun.JSError!JSValue
//   pub fn postgresErrorToJS(globalObject, message, err) JSValue
package bao_runtime.sql.postgresql


/// PostgreSQL 错误 JSC 转换器
/// 对应 Bun error_jsc (文件级函数)
/// 将 PostgreSQL 错误转为 JS Error 对象
public class PostgresErrorJSC {

    /// 创建 PostgreSQL 错误 JS 对象
    /// 对应 Bun createPostgresError()
    ///
    /// 参数:
    ///   message - 错误消息
    ///   options - 错误选项
    public static func createPostgresError(
        message: String,
        options: PostgresErrorOptions
    ): JSPGError {
        JSPGError(
            message: message,
            code: options.code,
            errno: options.errno,
            detail: options.detail,
            hint: options.hint,
            severity: options.severity,
            position: options.position,
            internalPosition: options.internalPosition,
            internalQuery: options.internalQuery,
            whereClause: options.whereClause,
            schema: options.schema,
            table: options.table,
            column: options.column,
            dataType: options.dataType,
            constraint: options.constraint,
            file: options.file,
            line: options.line,
            routine: options.routine
        )
    }

    /// 将 PostgreSQL 错误枚举转为 JS 错误对象
    /// 对应 Bun postgresErrorToJS()
    public static func postgresErrorToJS(err: PostgresError, message: ?String): JSPGError {
        let code = errorToCode(err)
        let msg = match (message) {
            case Some(m) => m
            case None => "Failed to bind query: ${err.message()}"
        }
        createPostgresError(msg, PostgresErrorOptions(code))
    }

    /// 将错误枚举映射到错误代码字符串
    /// 对应 Bun postgresErrorToJS 中的 switch
    private static func errorToCode(err: PostgresError): String {
        match (err) {
            case PostgresError.ConnectionClosed => "ERR_POSTGRES_CONNECTION_CLOSED"
            case PostgresError.ExpectedRequest => "ERR_POSTGRES_EXPECTED_REQUEST"
            case PostgresError.ExpectedStatement => "ERR_POSTGRES_EXPECTED_STATEMENT"
            case PostgresError.InvalidBackendKeyData => "ERR_POSTGRES_INVALID_BACKEND_KEY_DATA"
            case PostgresError.InvalidBinaryData => "ERR_POSTGRES_INVALID_BINARY_DATA"
            case PostgresError.InvalidByteSequence => "ERR_POSTGRES_INVALID_BYTE_SEQUENCE"
            case PostgresError.InvalidByteSequenceForEncoding => "ERR_POSTGRES_INVALID_BYTE_SEQUENCE_FOR_ENCODING"
            case PostgresError.InvalidCharacter => "ERR_POSTGRES_INVALID_CHARACTER"
            case PostgresError.InvalidMessage => "ERR_POSTGRES_INVALID_MESSAGE"
            case PostgresError.InvalidMessageLength => "ERR_POSTGRES_INVALID_MESSAGE_LENGTH"
            case PostgresError.InvalidQueryBinding => "ERR_POSTGRES_INVALID_QUERY_BINDING"
            case PostgresError.InvalidServerKey => "ERR_POSTGRES_INVALID_SERVER_KEY"
            case PostgresError.InvalidServerSignature => "ERR_POSTGRES_INVALID_SERVER_SIGNATURE"
            case PostgresError.InvalidTimeFormat => "ERR_POSTGRES_INVALID_TIME_FORMAT"
            case PostgresError.MultidimensionalArrayNotSupportedYet => "ERR_POSTGRES_MULTIDIMENSIONAL_ARRAY_NOT_SUPPORTED_YET"
            case PostgresError.NullsInArrayNotSupportedYet => "ERR_POSTGRES_NULLS_IN_ARRAY_NOT_SUPPORTED_YET"
            case PostgresError.Overflow => "ERR_POSTGRES_OVERFLOW"
            case PostgresError.PBKDF2Error => "ERR_POSTGRES_AUTHENTICATION_FAILED_PBKDF2"
            case PostgresError.SASLSignatureMismatch => "ERR_POSTGRES_SASL_SIGNATURE_MISMATCH"
            case PostgresError.SASLSignatureInvalidBase64 => "ERR_POSTGRES_SASL_SIGNATURE_INVALID_BASE64"
            case PostgresError.TLSNotAvailable => "ERR_POSTGRES_TLS_NOT_AVAILABLE"
            case PostgresError.TLSUpgradeFailed => "ERR_POSTGRES_TLS_UPGRADE_FAILED"
            case PostgresError.TooManyParameters => "ERR_POSTGRES_TOO_MANY_PARAMETERS"
            case PostgresError.UnexpectedMessage => "ERR_POSTGRES_UNEXPECTED_MESSAGE"
            case PostgresError.UnknownAuthenticationMethod => "ERR_POSTGRES_UNKNOWN_AUTHENTICATION_METHOD"
            case PostgresError.UnsupportedAuthenticationMethod => "ERR_POSTGRES_UNSUPPORTED_AUTHENTICATION_METHOD"
            case PostgresError.UnsupportedByteaFormat => "ERR_POSTGRES_UNSUPPORTED_BYTEA_FORMAT"
            case PostgresError.UnsupportedArrayFormat => "ERR_POSTGRES_UNSUPPORTED_ARRAY_FORMAT"
            case PostgresError.UnsupportedIntegerSize => "ERR_POSTGRES_UNSUPPORTED_INTEGER_SIZE"
            case PostgresError.UnsupportedNumericFormat => "ERR_POSTGRES_UNSUPPORTED_NUMERIC_FORMAT"
            case PostgresError.UnknownFormatCode => "ERR_POSTGRES_UNKNOWN_FORMAT_CODE"
            case PostgresError.JSError => "ERR_POSTGRES_JS_ERROR"
            case PostgresError.JSTerminated => "ERR_POSTGRES_JS_TERMINATED"
            case PostgresError.OutOfMemory => "ERR_POSTGRES_OUT_OF_MEMORY"
            case PostgresError.ShortRead => "ERR_POSTGRES_SHORT_READ"
            case PostgresError.IoError(_) => "ERR_POSTGRES_IO_ERROR"
        }
    }

    /// 获取 TooManyParameters 的详细消息
    public static func tooManyParametersMessage(): String {
        "query has too many parameters - the PostgreSQL wire protocol supports a maximum of 65535 parameters per query. Try reducing your batch size."
    }

    /// 获取 TooManyParameters 的提示
    public static func tooManyParametersHint(): String {
        "Reduce the number of rows in your batch insert so that total_rows * columns_per_row does not exceed 65535."
    }
}

/// JS PostgreSQL 错误对象
/// 对应 Bun 中通过 JSValue 创建的错误对象
public class JSPGError {
    public var message: String
    public var code: String
    public var errno: ?String
    public var detail: ?String
    public var hint: ?String
    public var severity: ?String
    public var position: ?String
    public var internalPosition: ?String
    public var internalQuery: ?String
    public var whereClause: ?String
    public var schema: ?String
    public var table: ?String
    public var column: ?String
    public var dataType: ?String
    public var constraint: ?String
    public var file: ?String
    public var line: ?String
    public var routine: ?String

    public init(
        message: String,
        code: String,
        errno: ?String = None,
        detail: ?String = None,
        hint: ?String = None,
        severity: ?String = None,
        position: ?String = None,
        internalPosition: ?String = None,
        internalQuery: ?String = None,
        whereClause: ?String = None,
        schema: ?String = None,
        table: ?String = None,
        column: ?String = None,
        dataType: ?String = None,
        constraint: ?String = None,
        file: ?String = None,
        line: ?String = None,
        routine: ?String = None
    ) {
        this.message = message
        this.code = code
        this.errno = errno
        this.detail = detail
        this.hint = hint
        this.severity = severity
        this.position = position
        this.internalPosition = internalPosition
        this.internalQuery = internalQuery
        this.whereClause = whereClause
        this.schema = schema
        this.table = table
        this.column = column
        this.dataType = dataType
        this.constraint = constraint
        this.file = file
        this.line = line
        this.routine = routine
    }

    /// 转为可读字符串
    public func toString(): String {
        var result = "[PostgresError: ${message}]"
        match (code) {
            case "" => {}
            case c => result = result + " (code: ${c})"
        }
        match (errno) {
            case Some(e) => result = result + " (errno: ${e})"
            case None => {}
        }
        result
    }
}
