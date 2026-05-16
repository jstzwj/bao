// 严格翻译自: src/sql/postgres/TLSStatus.zig
// PostgreSQL TLS 状态
package bao_sql.postgres

/// PostgreSQL TLS 握手状态
/// 对应 Bun: TLSStatus (union enum)
public enum TLSStatus {
    | none
    | pending
    | message_sent(UInt8)
    | ssl_not_available
    | ssl_ok
}
