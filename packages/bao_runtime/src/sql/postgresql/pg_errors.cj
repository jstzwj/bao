// PostgreSQL 错误类型
// 严格翻译自: bun/src/sql/postgres/AnyPostgresError.zig
//   pub const AnyPostgresError = error{...};
package bao_runtime.sql.postgresql

/// PostgreSQL 错误类型
/// 对应 Bun AnyPostgresError
public enum PostgresError {
    | ConnectionClosed                              // 连接已关闭
    | ExpectedRequest                               // 预期有请求
    | ExpectedStatement                             // 预期有预处理语句
    | InvalidBackendKeyData                         // 无效的后端密钥数据
    | InvalidBinaryData                             // 无效的二进制数据
    | InvalidByteSequence                           // 无效的字节序列
    | InvalidByteSequenceForEncoding                // 编码无效字节序列
    | InvalidCharacter                              // 无效字符
    | InvalidMessage                                // 无效消息
    | InvalidMessageLength                          // 无效消息长度
    | InvalidQueryBinding                           // 无效查询绑定
    | InvalidServerKey                              // 无效的服务器密钥
    | InvalidServerSignature                        // 无效的服务器签名
    | InvalidTimeFormat                             // 无效的时间格式
    | JSError                                       // JavaScript 错误
    | JSTerminated                                  // JavaScript 终止
    | MultidimensionalArrayNotSupportedYet          // 尚不支持多维数组
    | NullsInArrayNotSupportedYet                   // 尚不支持数组中的 NULL
    | OutOfMemory                                   // 内存不足
    | Overflow                                      // 溢出
    | PBKDF2Error                                   // PBKDF2 错误
    | SASLSignatureMismatch                         // SASL 签名不匹配
    | SASLSignatureInvalidBase64                    // SASL 签名 Base64 无效
    | ShortRead                                     // 读取不足
    | TLSNotAvailable                               // TLS 不可用
    | TLSUpgradeFailed                              // TLS 升级失败
    | TooManyParameters                             // 参数过多
    | UnexpectedMessage                             // 意外消息
    | UnknownAuthenticationMethod                   // 未知认证方法
    | UnsupportedAuthenticationMethod               // 不支持的认证方法
    | UnsupportedByteaFormat                        // 不支持的 bytea 格式
    | UnsupportedIntegerSize                        // 不支持的整数大小
    | UnsupportedArrayFormat                        // 不支持的数组格式
    | UnsupportedNumericFormat                      // 不支持的 numeric 格式
    | UnknownFormatCode                             // 未知格式代码
    | UnknownFieldType                              // 未知字段类型
    | IoError(String)                               // I/O 错误（附带描述）

    public func message(): String {
        match (this) {
            case ConnectionClosed => "Connection closed"
            case ExpectedRequest => "Expected request"
            case ExpectedStatement => "Expected statement"
            case InvalidBackendKeyData => "Invalid backend key data"
            case InvalidBinaryData => "Invalid binary data"
            case InvalidByteSequence => "Invalid byte sequence"
            case InvalidByteSequenceForEncoding => "Invalid byte sequence for encoding"
            case InvalidCharacter => "Invalid character"
            case InvalidMessage => "Invalid message"
            case InvalidMessageLength => "Invalid message length"
            case InvalidQueryBinding => "Invalid query binding"
            case InvalidServerKey => "Invalid server key"
            case InvalidServerSignature => "Invalid server signature"
            case InvalidTimeFormat => "Invalid time format"
            case JSError => "JS error"
            case JSTerminated => "JS terminated"
            case MultidimensionalArrayNotSupportedYet => "Multidimensional arrays not supported yet"
            case NullsInArrayNotSupportedYet => "NULLs in arrays not supported yet"
            case OutOfMemory => "Out of memory"
            case Overflow => "Overflow"
            case PBKDF2Error => "PBKDF2 error"
            case SASLSignatureMismatch => "SASL signature mismatch"
            case SASLSignatureInvalidBase64 => "SASL signature invalid base64"
            case ShortRead => "Short read"
            case TLSNotAvailable => "TLS not available"
            case TLSUpgradeFailed => "TLS upgrade failed"
            case TooManyParameters => "Too many parameters"
            case UnexpectedMessage => "Unexpected message"
            case UnknownAuthenticationMethod => "Unknown authentication method"
            case UnsupportedAuthenticationMethod => "Unsupported authentication method"
            case UnsupportedByteaFormat => "Unsupported bytea format"
            case UnsupportedIntegerSize => "Unsupported integer size"
            case UnsupportedArrayFormat => "Unsupported array format"
            case UnsupportedNumericFormat => "Unsupported numeric format"
            case UnknownFormatCode => "Unknown format code"
            case UnknownFieldType => "Unknown field type"
            case IoError(msg) => "IO error: ${msg}"
        }
    }
}

/// PostgreSQL 错误选项 - 用于构造带详细信息的错误
/// 对应 Bun PostgresErrorOptions
public class PostgresErrorOptions {
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

    public init(code: String) {
        this.code = code
        errno = None
        detail = None
        hint = None
        severity = None
        position = None
        internalPosition = None
        internalQuery = None
        whereClause = None
        schema = None
        table = None
        column = None
        dataType = None
        constraint = None
        file = None
        line = None
        routine = None
    }
}
