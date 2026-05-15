// 严格翻译自: src/sql_jsc/mysql/protocol/any_mysql_error_jsc.zig
// MySQL 错误到 JS 错误的转换

package bao_sql_jsc.mysql.protocol

import bao_core.*
import bao_jsc.*

/// MySQL 错误类型
/// 对应 Bun: AnyMySQLError
public enum AnyMySQLError {
    | ConnectionClosed
    | Overflow
    | AuthenticationFailed
    | UnsupportedAuthPlugin
    | UnsupportedProtocolVersion
    | LocalInfileNotSupported
    | WrongNumberOfParametersProvided
    | UnsupportedColumnType
    | InvalidLocalInfileRequest
    | InvalidAuthSwitchRequest
    | InvalidQueryBinding
    | InvalidResultRow
    | InvalidBinaryValue
    | InvalidEncodedInteger
    | InvalidEncodedLength
    | InvalidPrepareOKPacket
    | InvalidOKPacket
    | InvalidEOFPacket
    | InvalidErrorPacket
    | UnexpectedPacket
    | ConnectionTimedOut
    | IdleTimeout
    | LifetimeTimeout
    | PasswordRequired
    | MissingAuthData
    | FailedToEncryptPassword
    | InvalidPublicKey
    | UnknownError
    | InvalidState
    | JSError
    | OutOfMemory
    | ShortRead
}

/// MySQL 错误转 JS 错误
/// 对应 Bun: mysqlErrorToJS
public func mysqlErrorToJS(globalObject: JscJSGlobalObject, message: ?String,
                             err: AnyMySQLError): JscValue {
    let msg = message.getOrThrow()
    let code = match (err) {
        case ConnectionClosed => "ERR_MYSQL_CONNECTION_CLOSED"
        case Overflow => "ERR_MYSQL_OVERFLOW"
        case AuthenticationFailed => "ERR_MYSQL_AUTHENTICATION_FAILED"
        case UnsupportedAuthPlugin => "ERR_MYSQL_UNSUPPORTED_AUTH_PLUGIN"
        case UnsupportedProtocolVersion => "ERR_MYSQL_UNSUPPORTED_PROTOCOL_VERSION"
        case LocalInfileNotSupported => "ERR_MYSQL_LOCAL_INFILE_NOT_SUPPORTED"
        case WrongNumberOfParametersProvided => "ERR_MYSQL_WRONG_NUMBER_OF_PARAMETERS_PROVIDED"
        case UnsupportedColumnType => "ERR_MYSQL_UNSUPPORTED_COLUMN_TYPE"
        case InvalidQueryBinding => "ERR_MYSQL_INVALID_QUERY_BINDING"
        case UnexpectedPacket => "ERR_MYSQL_UNEXPECTED_PACKET"
        case ConnectionTimedOut => "ERR_MYSQL_CONNECTION_TIMEOUT"
        case IdleTimeout => "ERR_MYSQL_IDLE_TIMEOUT"
        case LifetimeTimeout => "ERR_MYSQL_LIFETIME_TIMEOUT"
        case PasswordRequired => "ERR_MYSQL_PASSWORD_REQUIRED"
        case MissingAuthData => "ERR_MYSQL_MISSING_AUTH_DATA"
        case UnknownError => "ERR_MYSQL_UNKNOWN_ERROR"
        case InvalidState => "ERR_MYSQL_INVALID_STATE"
        case _ => "ERR_MYSQL_UNKNOWN_ERROR"
    }

    return createMySQLError(globalObject, msg, code, 0, "")
}
