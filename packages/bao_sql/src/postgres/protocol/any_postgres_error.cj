// 严格翻译自: src/sql/postgres/AnyPostgresError.zig
// PostgreSQL 错误类型
package bao_sql.postgres.protocol

/// PostgreSQL 所有可能的错误
/// 对应 Bun: AnyPostgresError (error enum)
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
    | JSError
    | JSTerminated
    | MultidimensionalArrayNotSupportedYet
    | NullsInArrayNotSupportedYet
    | OutOfMemory
    | Overflow
    | PBKDFD2
    | SASL_SIGNATURE_MISMATCH
    | SASL_SIGNATURE_INVALID_BASE64
    | ShortRead
    | TLSNotAvailable
    | TLSUpgradeFailed
    | TooManyParameters
    | UnexpectedMessage
    | UNKNOWN_AUTHENTICATION_METHOD
    | UNSUPPORTED_AUTHENTICATION_METHOD
    | UnsupportedByteaFormat
    | UnsupportedIntegerSize
    | UnsupportedArrayFormat
    | UnsupportedNumericFormat
    | UnknownFormatCode
}

/// 创建 PostgresError 的选项
/// 对应 Bun: PostgresErrorOptions (struct)
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
        this.errno = None
        this.detail = None
        this.hint = None
        this.severity = None
        this.position = None
        this.internalPosition = None
        this.internalQuery = None
        this.whereClause = None
        this.schema = None
        this.table = None
        this.column = None
        this.dataType = None
        this.constraint = None
        this.file = None
        this.line = None
        this.routine = None
    }
}
