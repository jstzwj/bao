// 严格翻译自: src/sql/postgres/Status.zig
// PostgreSQL 连接状态
package bao_sql.postgres

/// PostgreSQL 连接状态
/// 对应 Bun: Status (enum)
public enum PostgresStatus {
    | disconnected
    | connecting
    | sent_startup_message
    | connected
    | failed
}
