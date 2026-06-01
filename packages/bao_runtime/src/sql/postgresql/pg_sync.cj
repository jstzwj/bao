// PostgreSQL 同步写入辅助
// 翻译自: bun/src/sql/postgres/protocol/PostgresProtocol.zig 中的 Sync/Flush
package bao_runtime.sql.postgresql


/// Sync 消息: 'S' (0x53), length=4 (包括自身)
private let SYNC_BYTES: Array<UInt8> = [83, 0, 0, 0, 4]
/// Flush 消息: 'H' (0x48), length=4
private let FLUSH_BYTES: Array<UInt8> = [72, 0, 0, 0, 4]
/// Terminate 消息: 'X' (0x58), length=4
private let TERMINATE_BYTES: Array<UInt8> = [88, 0, 0, 0, 4]
/// SSLRequest 消息: length=8, ssl_request_code=80877103
private let SSL_REQUEST_BYTES: Array<UInt8> = [0, 0, 0, 8, 4, 210, 34, 47]

/// PostgreSQL 同步和刷写消息辅助
public class PGSync {
    /// 写入 Sync 消息
    public static func writeSync(writer: ProtocolWriter): Unit {
        writer.write(SYNC_BYTES)
    }

    /// 写入 Flush 消息
    public static func writeFlush(writer: ProtocolWriter): Unit {
        writer.write(FLUSH_BYTES)
    }

    /// 写入 Terminate 消息
    public static func writeTerminate(writer: ProtocolWriter): Unit {
        writer.write(TERMINATE_BYTES)
    }

    /// 写入 SSLRequest 消息
    public static func writeSSLRequest(writer: ProtocolWriter): Unit {
        writer.write(SSL_REQUEST_BYTES)
    }
}
