// MySQL 能力标志
// 对应 Bun: src/sql/mysql/Capabilities.zig
package bao_sql.mysql

/// MySQL 客户端/服务器能力标志
/// 对应 Bun: Capabilities (struct)
///
/// 每个字段对应 MySQL 协议中的一个能力位
public class Capabilities {
    // ============================================================================
    // 能力标志字段
    // 对应 Bun: Capabilities 中的 bool 字段
    // ============================================================================
    public var CLIENT_LONG_PASSWORD: Bool
    public var CLIENT_FOUND_ROWS: Bool
    public var CLIENT_LONG_FLAG: Bool
    public var CLIENT_CONNECT_WITH_DB: Bool
    public var CLIENT_NO_SCHEMA: Bool
    public var CLIENT_COMPRESS: Bool
    public var CLIENT_ODBC: Bool
    public var CLIENT_LOCAL_FILES: Bool
    public var CLIENT_IGNORE_SPACE: Bool
    public var CLIENT_PROTOCOL_41: Bool
    public var CLIENT_INTERACTIVE: Bool
    public var CLIENT_SSL: Bool
    public var CLIENT_IGNORE_SIGPIPE: Bool
    public var CLIENT_TRANSACTIONS: Bool
    public var CLIENT_RESERVED: Bool
    public var CLIENT_SECURE_CONNECTION: Bool
    public var CLIENT_MULTI_STATEMENTS: Bool
    public var CLIENT_MULTI_RESULTS: Bool
    public var CLIENT_PS_MULTI_RESULTS: Bool
    public var CLIENT_PLUGIN_AUTH: Bool
    public var CLIENT_CONNECT_ATTRS: Bool
    public var CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA: Bool
    public var CLIENT_CAN_HANDLE_EXPIRED_PASSWORDS: Bool
    public var CLIENT_SESSION_TRACK: Bool
    public var CLIENT_DEPRECATE_EOF: Bool
    public var CLIENT_OPTIONAL_RESULTSET_METADATA: Bool
    public var CLIENT_ZSTD_COMPRESSION_ALGORITHM: Bool
    public var CLIENT_QUERY_ATTRIBUTES: Bool
    public var MULTI_FACTOR_AUTHENTICATION: Bool
    public var CLIENT_CAPABILITY_EXTENSION: Bool
    public var CLIENT_SSL_VERIFY_SERVER_CERT: Bool
    public var CLIENT_REMEMBER_OPTIONS: Bool

    // ============================================================================
    // 常量：各能力位的位移值
    // 对应 Bun: Capabilities 中的 const _XXX 常量
    // ============================================================================
    public static let _CLIENT_LONG_PASSWORD: UInt32 = 1                     // 1 << 0
    public static let _CLIENT_FOUND_ROWS: UInt32 = 2                       // 1 << 1
    public static let _CLIENT_LONG_FLAG: UInt32 = 4                        // 1 << 2
    public static let _CLIENT_CONNECT_WITH_DB: UInt32 = 8                  // 1 << 3
    public static let _CLIENT_NO_SCHEMA: UInt32 = 16                       // 1 << 4
    public static let _CLIENT_COMPRESS: UInt32 = 32                        // 1 << 5
    public static let _CLIENT_ODBC: UInt32 = 64                            // 1 << 6
    public static let _CLIENT_LOCAL_FILES: UInt32 = 128                    // 1 << 7
    public static let _CLIENT_IGNORE_SPACE: UInt32 = 256                   // 1 << 8
    public static let _CLIENT_PROTOCOL_41: UInt32 = 512                    // 1 << 9
    public static let _CLIENT_INTERACTIVE: UInt32 = 1024                   // 1 << 10
    public static let _CLIENT_SSL: UInt32 = 2048                           // 1 << 11
    public static let _CLIENT_IGNORE_SIGPIPE: UInt32 = 4096                // 1 << 12
    public static let _CLIENT_TRANSACTIONS: UInt32 = 8192                  // 1 << 13
    public static let _CLIENT_RESERVED: UInt32 = 16384                     // 1 << 14
    public static let _CLIENT_SECURE_CONNECTION: UInt32 = 32768            // 1 << 15
    public static let _CLIENT_MULTI_STATEMENTS: UInt32 = 65536             // 1 << 16
    public static let _CLIENT_MULTI_RESULTS: UInt32 = 131072               // 1 << 17
    public static let _CLIENT_PS_MULTI_RESULTS: UInt32 = 262144            // 1 << 18
    public static let _CLIENT_PLUGIN_AUTH: UInt32 = 524288                 // 1 << 19
    public static let _CLIENT_CONNECT_ATTRS: UInt32 = 1048576              // 1 << 20
    public static let _CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA: UInt32 = 2097152   // 1 << 21
    public static let _CLIENT_CAN_HANDLE_EXPIRED_PASSWORDS: UInt32 = 4194304     // 1 << 22
    public static let _CLIENT_SESSION_TRACK: UInt32 = 8388608              // 1 << 23
    public static let _CLIENT_DEPRECATE_EOF: UInt32 = 16777216             // 1 << 24
    public static let _CLIENT_OPTIONAL_RESULTSET_METADATA: UInt32 = 33554432    // 1 << 25
    public static let _CLIENT_ZSTD_COMPRESSION_ALGORITHM: UInt32 = 67108864     // 1 << 26
    public static let _CLIENT_QUERY_ATTRIBUTES: UInt32 = 134217728          // 1 << 27
    public static let _MULTI_FACTOR_AUTHENTICATION: UInt32 = 268435456      // 1 << 28
    public static let _CLIENT_CAPABILITY_EXTENSION: UInt32 = 536870912      // 1 << 29
    public static let _CLIENT_SSL_VERIFY_SERVER_CERT: UInt32 = 1073741824   // 1 << 30
    public static let _CLIENT_REMEMBER_OPTIONS: UInt32 = 2147483648u32     // 1 << 31 (注意: 需要 UInt32)

    public init() {
        CLIENT_LONG_PASSWORD = false
        CLIENT_FOUND_ROWS = false
        CLIENT_LONG_FLAG = false
        CLIENT_CONNECT_WITH_DB = false
        CLIENT_NO_SCHEMA = false
        CLIENT_COMPRESS = false
        CLIENT_ODBC = false
        CLIENT_LOCAL_FILES = false
        CLIENT_IGNORE_SPACE = false
        CLIENT_PROTOCOL_41 = false
        CLIENT_INTERACTIVE = false
        CLIENT_SSL = false
        CLIENT_IGNORE_SIGPIPE = false
        CLIENT_TRANSACTIONS = false
        CLIENT_RESERVED = false
        CLIENT_SECURE_CONNECTION = false
        CLIENT_MULTI_STATEMENTS = false
        CLIENT_MULTI_RESULTS = false
        CLIENT_PS_MULTI_RESULTS = false
        CLIENT_PLUGIN_AUTH = false
        CLIENT_CONNECT_ATTRS = false
        CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA = false
        CLIENT_CAN_HANDLE_EXPIRED_PASSWORDS = false
        CLIENT_SESSION_TRACK = false
        CLIENT_DEPRECATE_EOF = false
        CLIENT_OPTIONAL_RESULTSET_METADATA = false
        CLIENT_ZSTD_COMPRESSION_ALGORITHM = false
        CLIENT_QUERY_ATTRIBUTES = false
        MULTI_FACTOR_AUTHENTICATION = false
        CLIENT_CAPABILITY_EXTENSION = false
        CLIENT_SSL_VERIFY_SERVER_CERT = false
        CLIENT_REMEMBER_OPTIONS = false
    }

    /// 拒绝不支持的能力标志
    /// 对应 Bun: Capabilities.reject
    public func reject(): Unit {
        CLIENT_ZSTD_COMPRESSION_ALGORITHM = false
        MULTI_FACTOR_AUTHENTICATION = false
        CLIENT_CAPABILITY_EXTENSION = false
        CLIENT_SSL_VERIFY_SERVER_CERT = false
        CLIENT_REMEMBER_OPTIONS = false
        CLIENT_COMPRESS = false
        CLIENT_INTERACTIVE = false
        CLIENT_IGNORE_SIGPIPE = false
        CLIENT_NO_SCHEMA = false
        CLIENT_ODBC = false
        CLIENT_LOCAL_FILES = false
        CLIENT_OPTIONAL_RESULTSET_METADATA = false
        CLIENT_QUERY_ATTRIBUTES = false
    }

    /// 将能力标志转换为整数
    /// 对应 Bun: Capabilities.toInt
    public func toInt(): UInt32 {
        var value: UInt32 = 0

        if (CLIENT_LONG_PASSWORD) { value = value | Capabilities._CLIENT_LONG_PASSWORD }
        if (CLIENT_FOUND_ROWS) { value = value | Capabilities._CLIENT_FOUND_ROWS }
        if (CLIENT_LONG_FLAG) { value = value | Capabilities._CLIENT_LONG_FLAG }
        if (CLIENT_CONNECT_WITH_DB) { value = value | Capabilities._CLIENT_CONNECT_WITH_DB }
        if (CLIENT_NO_SCHEMA) { value = value | Capabilities._CLIENT_NO_SCHEMA }
        if (CLIENT_COMPRESS) { value = value | Capabilities._CLIENT_COMPRESS }
        if (CLIENT_ODBC) { value = value | Capabilities._CLIENT_ODBC }
        if (CLIENT_LOCAL_FILES) { value = value | Capabilities._CLIENT_LOCAL_FILES }
        if (CLIENT_IGNORE_SPACE) { value = value | Capabilities._CLIENT_IGNORE_SPACE }
        if (CLIENT_PROTOCOL_41) { value = value | Capabilities._CLIENT_PROTOCOL_41 }
        if (CLIENT_INTERACTIVE) { value = value | Capabilities._CLIENT_INTERACTIVE }
        if (CLIENT_SSL) { value = value | Capabilities._CLIENT_SSL }
        if (CLIENT_IGNORE_SIGPIPE) { value = value | Capabilities._CLIENT_IGNORE_SIGPIPE }
        if (CLIENT_TRANSACTIONS) { value = value | Capabilities._CLIENT_TRANSACTIONS }
        if (CLIENT_RESERVED) { value = value | Capabilities._CLIENT_RESERVED }
        if (CLIENT_SECURE_CONNECTION) { value = value | Capabilities._CLIENT_SECURE_CONNECTION }
        if (CLIENT_MULTI_STATEMENTS) { value = value | Capabilities._CLIENT_MULTI_STATEMENTS }
        if (CLIENT_MULTI_RESULTS) { value = value | Capabilities._CLIENT_MULTI_RESULTS }
        if (CLIENT_PS_MULTI_RESULTS) { value = value | Capabilities._CLIENT_PS_MULTI_RESULTS }
        if (CLIENT_PLUGIN_AUTH) { value = value | Capabilities._CLIENT_PLUGIN_AUTH }
        if (CLIENT_CONNECT_ATTRS) { value = value | Capabilities._CLIENT_CONNECT_ATTRS }
        if (CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA) { value = value | Capabilities._CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA }
        if (CLIENT_CAN_HANDLE_EXPIRED_PASSWORDS) { value = value | Capabilities._CLIENT_CAN_HANDLE_EXPIRED_PASSWORDS }
        if (CLIENT_SESSION_TRACK) { value = value | Capabilities._CLIENT_SESSION_TRACK }
        if (CLIENT_DEPRECATE_EOF) { value = value | Capabilities._CLIENT_DEPRECATE_EOF }
        if (CLIENT_OPTIONAL_RESULTSET_METADATA) { value = value | Capabilities._CLIENT_OPTIONAL_RESULTSET_METADATA }
        if (CLIENT_ZSTD_COMPRESSION_ALGORITHM) { value = value | Capabilities._CLIENT_ZSTD_COMPRESSION_ALGORITHM }
        if (CLIENT_QUERY_ATTRIBUTES) { value = value | Capabilities._CLIENT_QUERY_ATTRIBUTES }
        if (MULTI_FACTOR_AUTHENTICATION) { value = value | Capabilities._MULTI_FACTOR_AUTHENTICATION }
        if (CLIENT_CAPABILITY_EXTENSION) { value = value | Capabilities._CLIENT_CAPABILITY_EXTENSION }
        if (CLIENT_SSL_VERIFY_SERVER_CERT) { value = value | Capabilities._CLIENT_SSL_VERIFY_SERVER_CERT }
        if (CLIENT_REMEMBER_OPTIONS) { value = value | Capabilities._CLIENT_REMEMBER_OPTIONS }

        return value
    }

    /// 从整数解析能力标志
    /// 对应 Bun: Capabilities.fromInt
    public static func fromInt(flags: UInt32): Capabilities {
        let caps = Capabilities()
        caps.CLIENT_LONG_PASSWORD = (Capabilities._CLIENT_LONG_PASSWORD & flags) != 0
        caps.CLIENT_FOUND_ROWS = (Capabilities._CLIENT_FOUND_ROWS & flags) != 0
        caps.CLIENT_LONG_FLAG = (Capabilities._CLIENT_LONG_FLAG & flags) != 0
        caps.CLIENT_CONNECT_WITH_DB = (Capabilities._CLIENT_CONNECT_WITH_DB & flags) != 0
        caps.CLIENT_NO_SCHEMA = (Capabilities._CLIENT_NO_SCHEMA & flags) != 0
        caps.CLIENT_COMPRESS = (Capabilities._CLIENT_COMPRESS & flags) != 0
        caps.CLIENT_ODBC = (Capabilities._CLIENT_ODBC & flags) != 0
        caps.CLIENT_LOCAL_FILES = (Capabilities._CLIENT_LOCAL_FILES & flags) != 0
        caps.CLIENT_IGNORE_SPACE = (Capabilities._CLIENT_IGNORE_SPACE & flags) != 0
        caps.CLIENT_PROTOCOL_41 = (Capabilities._CLIENT_PROTOCOL_41 & flags) != 0
        caps.CLIENT_INTERACTIVE = (Capabilities._CLIENT_INTERACTIVE & flags) != 0
        caps.CLIENT_SSL = (Capabilities._CLIENT_SSL & flags) != 0
        caps.CLIENT_IGNORE_SIGPIPE = (Capabilities._CLIENT_IGNORE_SIGPIPE & flags) != 0
        caps.CLIENT_TRANSACTIONS = (Capabilities._CLIENT_TRANSACTIONS & flags) != 0
        caps.CLIENT_RESERVED = (Capabilities._CLIENT_RESERVED & flags) != 0
        caps.CLIENT_SECURE_CONNECTION = (Capabilities._CLIENT_SECURE_CONNECTION & flags) != 0
        caps.CLIENT_MULTI_STATEMENTS = (Capabilities._CLIENT_MULTI_STATEMENTS & flags) != 0
        caps.CLIENT_MULTI_RESULTS = (Capabilities._CLIENT_MULTI_RESULTS & flags) != 0
        caps.CLIENT_PS_MULTI_RESULTS = (Capabilities._CLIENT_PS_MULTI_RESULTS & flags) != 0
        caps.CLIENT_PLUGIN_AUTH = (Capabilities._CLIENT_PLUGIN_AUTH & flags) != 0
        caps.CLIENT_CONNECT_ATTRS = (Capabilities._CLIENT_CONNECT_ATTRS & flags) != 0
        caps.CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA = (Capabilities._CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA & flags) != 0
        caps.CLIENT_CAN_HANDLE_EXPIRED_PASSWORDS = (Capabilities._CLIENT_CAN_HANDLE_EXPIRED_PASSWORDS & flags) != 0
        caps.CLIENT_SESSION_TRACK = (Capabilities._CLIENT_SESSION_TRACK & flags) != 0
        caps.CLIENT_DEPRECATE_EOF = (Capabilities._CLIENT_DEPRECATE_EOF & flags) != 0
        caps.CLIENT_OPTIONAL_RESULTSET_METADATA = (Capabilities._CLIENT_OPTIONAL_RESULTSET_METADATA & flags) != 0
        caps.CLIENT_ZSTD_COMPRESSION_ALGORITHM = (Capabilities._CLIENT_ZSTD_COMPRESSION_ALGORITHM & flags) != 0
        caps.CLIENT_QUERY_ATTRIBUTES = (Capabilities._CLIENT_QUERY_ATTRIBUTES & flags) != 0
        caps.MULTI_FACTOR_AUTHENTICATION = (Capabilities._MULTI_FACTOR_AUTHENTICATION & flags) != 0
        caps.CLIENT_CAPABILITY_EXTENSION = (Capabilities._CLIENT_CAPABILITY_EXTENSION & flags) != 0
        caps.CLIENT_SSL_VERIFY_SERVER_CERT = (Capabilities._CLIENT_SSL_VERIFY_SERVER_CERT & flags) != 0
        caps.CLIENT_REMEMBER_OPTIONS = (Capabilities._CLIENT_REMEMBER_OPTIONS & flags) != 0
        return caps
    }

    /// 返回两个能力集合的交集 (AND)
    /// 对应 Bun: Capabilities.intersect
    public func intersect(other: Capabilities): Capabilities {
        return Capabilities.fromInt(this.toInt() & other.toInt())
    }

    /// 获取默认能力标志
    /// 对应 Bun: Capabilities.getDefaultCapabilities
    public static func getDefaultCapabilities(ssl: Bool, hasDbName: Bool): Capabilities {
        let caps = Capabilities()
        caps.CLIENT_PROTOCOL_41 = true
        caps.CLIENT_PLUGIN_AUTH = true
        caps.CLIENT_SECURE_CONNECTION = true
        caps.CLIENT_CONNECT_WITH_DB = hasDbName
        caps.CLIENT_DEPRECATE_EOF = true
        caps.CLIENT_SSL = ssl
        caps.CLIENT_MULTI_STATEMENTS = true
        caps.CLIENT_MULTI_RESULTS = true
        return caps
    }
}
