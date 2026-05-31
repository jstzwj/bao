// MySQL 错误类型定义
// 严格翻译自: src/sql/mysql/protocol/AnyMySQLError.zig
package bao_runtime.sql.mysql

/// MySQL 协议错误枚举
/// 对应 Bun: AnyMySQLError.Error
public enum MySQLError {
    | ConnectionClosed
    | ConnectionTimedOut
    | LifetimeTimeout
    | IdleTimeout
    | PasswordRequired
    | MissingAuthData
    | AuthenticationFailed
    | FailedToEncryptPassword
    | InvalidPublicKey
    | UnsupportedAuthPlugin
    | UnsupportedProtocolVersion
    | LocalInfileNotSupported
    | JSError
    | JSTerminated
    | OutOfMemory
    | Overflow
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
    | ShortRead
    | UnknownError
    | InvalidState

    /// 获取错误的可读描述
    public func message(): String {
        match (this) {
            case ConnectionClosed => "Connection closed"
            case ConnectionTimedOut => "Connection timed out"
            case LifetimeTimeout => "Lifetime timeout"
            case IdleTimeout => "Idle timeout"
            case PasswordRequired => "Password required"
            case MissingAuthData => "Missing authentication data"
            case AuthenticationFailed => "Authentication failed"
            case FailedToEncryptPassword => "Failed to encrypt password"
            case InvalidPublicKey => "Invalid public key"
            case UnsupportedAuthPlugin => "Unsupported authentication plugin"
            case UnsupportedProtocolVersion => "Unsupported protocol version"
            case LocalInfileNotSupported => "LOCAL INFILE not supported"
            case JSError => "JavaScript error"
            case JSTerminated => "JavaScript terminated"
            case OutOfMemory => "Out of memory"
            case Overflow => "Overflow"
            case WrongNumberOfParametersProvided => "Wrong number of parameters provided"
            case UnsupportedColumnType => "Unsupported column type"
            case InvalidLocalInfileRequest => "Invalid local infile request"
            case InvalidAuthSwitchRequest => "Invalid auth switch request"
            case InvalidQueryBinding => "Invalid query binding"
            case InvalidResultRow => "Invalid result row"
            case InvalidBinaryValue => "Invalid binary value"
            case InvalidEncodedInteger => "Invalid encoded integer"
            case InvalidEncodedLength => "Invalid encoded length"
            case InvalidPrepareOKPacket => "Invalid prepare OK packet"
            case InvalidOKPacket => "Invalid OK packet"
            case InvalidEOFPacket => "Invalid EOF packet"
            case InvalidErrorPacket => "Invalid error packet"
            case UnexpectedPacket => "Unexpected packet"
            case ShortRead => "Short read"
            case UnknownError => "Unknown error"
            case InvalidState => "Invalid state"
        }
    }
}
