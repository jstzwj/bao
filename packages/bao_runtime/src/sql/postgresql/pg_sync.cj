// PostgreSQL 同步写入辅助
// 翻译自: bun/src/sql/postgres/protocol/PostgresProtocol.zig 中的 Sync/Flush
package bao_runtime.sql.postgresql


/// PostgreSQL 同步和刷写消息辅助
public class PGSync {
    /// 写入 Sync 消息
    public static func writeSync(writer: ProtocolWriter): Unit {
        writer.write(SYNC)
    }

    /// 写入 Flush 消息
    public static func writeFlush(writer: ProtocolWriter): Unit {
        writer.write(FLUSH)
    }

    /// 写入 Terminate 消息
    public static func writeTerminate(writer: ProtocolWriter): Unit {
        writer.write(TERMINATE)
    }

    /// 写入 SSLRequest 消息
    public static func writeSSLRequest(writer: ProtocolWriter): Unit {
        writer.write(SSL_REQUEST)
    }
}
