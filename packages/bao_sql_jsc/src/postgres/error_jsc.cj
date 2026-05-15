// 严格翻译自: src/sql_jsc/postgres/error_jsc.zig
// Postgres 错误到 JS 错误的转换

package bao_sql_jsc.postgres

import bao_core.*
import bao_jsc.*

/// Postgres 错误类型
/// 对应 Bun: AnyPostgresError
public enum AnyPostgresError {
    | ConnectionClosed
    | ExpectedRequest
    | ExpectedStatement
    | InvalidBackendKeyData
    | InvalidBinaryData
    | InvalidByteSequence
    | InvalidByteSequenceForEncoding
    | InvalidCharacter
    | InvalidMessage
    | InvalidMessageLength
    | InvalidQueryBinding
    | InvalidServerKey
    | InvalidServerSignature
    | InvalidTimeFormat
    | MultidimensionalArrayNotSupportedYet
    | NullsInArrayNotSupportedYet
    | Overflow
    | PBKDFD2
    | SASLSignatureMismatch
    | SASLSignatureInvalidBase64
    | TLSNotAvailable
    | TLSUpgradeFailed
    | TooManyParameters
    | UnexpectedMessage
    | UnknownAuthenticationMethod
    | UnsupportedAuthenticationMethod
    | UnsupportedByteaFormat
    | UnsupportedArrayFormat
    | UnsupportedIntegerSize
    | UnsupportedNumericFormat
    | UnknownFormatCode
    | JSError
    | OutOfMemory
    | ShortRead
}

/// Postgres 错误转 JS 错误
/// 对应 Bun: postgresErrorToJS
public func postgresErrorToJS(globalObject: JscJSGlobalObject, message: ?String,
                                err: AnyPostgresError): JscValue {
    let code = match (err) {
        case ConnectionClosed => "ERR_POSTGRES_CONNECTION_CLOSED"
        case ExpectedRequest => "ERR_POSTGRES_EXPECTED_REQUEST"
        case ExpectedStatement => "ERR_POSTGRES_EXPECTED_STATEMENT"
        case InvalidBackendKeyData => "ERR_POSTGRES_INVALID_BACKEND_KEY_DATA"
        case InvalidBinaryData => "ERR_POSTGRES_INVALID_BINARY_DATA"
        case InvalidQueryBinding => "ERR_POSTGRES_INVALID_QUERY_BINDING"
        case Overflow => "ERR_POSTGRES_OVERFLOW"
        case PBKDFD2 => "ERR_POSTGRES_AUTHENTICATION_FAILED_PBKDF2"
        case SASLSignatureMismatch => "ERR_POSTGRES_SASL_SIGNATURE_MISMATCH"
        case TLSNotAvailable => "ERR_POSTGRES_TLS_NOT_AVAILABLE"
        case TLSUpgradeFailed => "ERR_POSTGRES_TLS_UPGRADE_FAILED"
        case TooManyParameters => "ERR_POSTGRES_TOO_MANY_PARAMETERS"
        case UnexpectedMessage => "ERR_POSTGRES_UNEXPECTED_MESSAGE"
        case UnknownAuthenticationMethod => "ERR_POSTGRES_UNKNOWN_AUTHENTICATION_METHOD"
        case UnsupportedAuthenticationMethod => "ERR_POSTGRES_UNSUPPORTED_AUTHENTICATION_METHOD"
        case UnsupportedByteaFormat => "ERR_POSTGRES_UNSUPPORTED_BYTEA_FORMAT"
        case UnsupportedArrayFormat => "ERR_POSTGRES_UNSUPPORTED_ARRAY_FORMAT"
        case UnsupportedNumericFormat => "ERR_POSTGRES_UNSUPPORTED_NUMERIC_FORMAT"
        case UnsupportedIntegerSize => "ERR_POSTGRES_UNSUPPORTED_INTEGER_SIZE"
        case InvalidMessage => "ERR_POSTGRES_INVALID_MESSAGE"
        case InvalidServerKey => "ERR_POSTGRES_INVALID_SERVER_KEY"
        case InvalidServerSignature => "ERR_POSTGRES_INVALID_SERVER_SIGNATURE"
        case _ => "ERR_POSTGRES_UNKNOWN_ERROR"
    }

    var msg = message.getOrThrow()
    if (msg == None) {
        msg = "Failed to bind query: ${err.name()"
    }

    return createPostgresError(globalObject, msg, code, None, None, None, None)
}

/// Postgres 错误选项
/// 对应 Bun: PostgresErrorOptions
public class PostgresErrorOptions {
    public var code: String = ""
    public var errno: ?String = None
    public var detail: ?String = None
    public var hint: ?String = None
    public var severity: ?String = None
    public var position: ?String = None
    public var internalPosition: ?String = None
    public var internalQuery: ?String = None
    public var where_: ?String = None
    public var schema: ?String = None
    public var table: ?String = None
    public var column: ?String = None
    public var dataType: ?String = None
    public var constraint: ?String = None
    public var file: ?String = None
    public var line: ?String = None
    public var routine: ?String = None

    public init() {}
}
