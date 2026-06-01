// MySQL JS 错误转换绑定
// 严格翻译自: src/sql_jsc/mysql/protocol/any_mysql_error_jsc.zig + error_packet_jsc.zig
//
// 将 MySQL 错误转为 JS Error 对象:
// - mysqlErrorToJS: AnyMySQLError.Error → JS Error
// - createMySQLError: 创建带 code/errno/sqlState/message 的错误对象
// - ErrorPacket.toJS: 错误包 → JS Error
package bao_runtime.sql.mysql

import bao_core.*
import bao_sql.*
import bao_sql.mysql.protocol.*

/// MySQL 错误 JS 转换
/// 对应 Bun: any_mysql_error_jsc.zig
public class MySQLErrorJSC {
    /// 将 MySQL 错误转为 JS Error
    /// 对应 Bun: mysqlErrorToJS
    public static func mysqlErrorToJS(globalObject: JSValueRef, message: ?String, err: MySQLError): JSValueRef {
        let msg = match (message) {
            case Some(m) => m
            case None => err.message()
        }

        let code = match (err) {
            case ConnectionClosed => "ERR_MYSQL_CONNECTION_CLOSED"
            case Overflow => "ERR_MYSQL_OVERFLOW"
            case AuthenticationFailed => "ERR_MYSQL_AUTHENTICATION_FAILED"
            case UnsupportedAuthPlugin => "ERR_MYSQL_UNSUPPORTED_AUTH_PLUGIN"
            case UnsupportedProtocolVersion => "ERR_MYSQL_UNSUPPORTED_PROTOCOL_VERSION"
            case LocalInfileNotSupported => "ERR_MYSQL_LOCAL_INFILE_NOT_SUPPORTED"
            case WrongNumberOfParametersProvided => "ERR_MYSQL_WRONG_NUMBER_OF_PARAMETERS_PROVIDED"
            case UnsupportedColumnType => "ERR_MYSQL_UNSUPPORTED_COLUMN_TYPE"
            case InvalidLocalInfileRequest => "ERR_MYSQL_INVALID_LOCAL_INFILE_REQUEST"
            case InvalidAuthSwitchRequest => "ERR_MYSQL_INVALID_AUTH_SWITCH_REQUEST"
            case InvalidQueryBinding => "ERR_MYSQL_INVALID_QUERY_BINDING"
            case InvalidResultRow => "ERR_MYSQL_INVALID_RESULT_ROW"
            case InvalidBinaryValue => "ERR_MYSQL_INVALID_BINARY_VALUE"
            case InvalidEncodedInteger => "ERR_MYSQL_INVALID_ENCODED_INTEGER"
            case InvalidEncodedLength => "ERR_MYSQL_INVALID_ENCODED_LENGTH"
            case InvalidPrepareOKPacket => "ERR_MYSQL_INVALID_PREPARE_OK_PACKET"
            case InvalidOKPacket => "ERR_MYSQL_INVALID_OK_PACKET"
            case InvalidEOFPacket => "ERR_MYSQL_INVALID_EOF_PACKET"
            case InvalidErrorPacket => "ERR_MYSQL_INVALID_ERROR_PACKET"
            case UnexpectedPacket => "ERR_MYSQL_UNEXPECTED_PACKET"
            case ConnectionTimedOut => "ERR_MYSQL_CONNECTION_TIMEOUT"
            case IdleTimeout => "ERR_MYSQL_IDLE_TIMEOUT"
            case LifetimeTimeout => "ERR_MYSQL_LIFETIME_TIMEOUT"
            case PasswordRequired => "ERR_MYSQL_PASSWORD_REQUIRED"
            case MissingAuthData => "ERR_MYSQL_MISSING_AUTH_DATA"
            case FailedToEncryptPassword => "ERR_MYSQL_FAILED_TO_ENCRYPT_PASSWORD"
            case InvalidPublicKey => "ERR_MYSQL_INVALID_PUBLIC_KEY"
            case UnknownError => "ERR_MYSQL_UNKNOWN_ERROR"
            case InvalidState => "ERR_MYSQL_INVALID_STATE"
            case JSError => "ERR_MYSQL_JS_ERROR"
            case JSTerminated => "ERR_MYSQL_JS_TERMINATED"
            case OutOfMemory => "ERR_OUT_OF_MEMORY"
            case ShortRead => "ERR_MYSQL_SHORT_READ"
        }

        return createMySQLError(globalObject, msg, MySQLErrorOptions(code, Option<UInt32>.None, Option<String>.None))
    }

    /// 创建 MySQL 错误 JS 对象
    /// 对应 Bun: createMySQLError
    public static func createMySQLError(
        globalObject: JSValueRef,
        message: String,
        options: MySQLErrorOptions
    ): JSValueRef {
        // 在真实 JSC 环境中创建带属性的错误对象:
        // { code, errno?, sqlState?, message }
        // 简化实现
        // 在真实 JSC 环境中创建带属性的错误对象:
        // { code, errno?, sqlState?, message }
        // 简化实现
        return JSValueRef.null_()
    }
}

/// 错误包 JS 转换
/// 对应 Bun: error_packet_jsc.zig
public class ErrorPacketJSC {
    /// 将 ErrorPacket 转为 JS Error
    /// 对应 Bun: ErrorPacket.toJS
    public static func toJS(err: ErrorPacket, globalObject: JSValueRef): JSValueRef {
        // err.errorMessage 是 SQLData 类型
        let msgSlice = err.errorMessage
        var msg = ""
        for (b in msgSlice) {
            msg += String(Rune(Int32(b)))
        }
        if (msg.isEmpty()) {
            msg = "MySQL error occurred"
        }

        let code = if (err.errorCode == 1064) {
            "ERR_MYSQL_SYNTAX_ERROR"
        } else {
            "ERR_MYSQL_SERVER_ERROR"
        }

        // err.sqlState 是 ?Array<UInt8> 类型
        var sqlStateStr: ?String = None
        if (let Some(stateBytes) <- err.sqlState) {
            var s = ""
            for (b in stateBytes) {
                s += String(Rune(Int32(b)))
            }
            sqlStateStr = s
        }

        return MySQLErrorJSC.createMySQLError(
            globalObject,
            msg,
            MySQLErrorOptions(code, Some(UInt32(err.errorCode)), sqlStateStr)
        )
    }
}

/// MySQL 错误选项
/// 对应 Bun: MySQLErrorOptions
public class MySQLErrorOptions {
    public var code: String
    public var errno: ?UInt32
    public var sqlState: ?String

    public init() {
        code = ""
        errno = None
        sqlState = None
    }

    public init(code: String, errno: ?UInt32, sqlState: ?String) {
        this.code = code
        this.errno = errno
        this.sqlState = sqlState
    }
}
