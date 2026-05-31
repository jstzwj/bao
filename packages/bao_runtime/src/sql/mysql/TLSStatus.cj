// MySQL TLS 连接状态
// 严格翻译自: src/sql/mysql/TLSStatus.zig
package bao_runtime.sql.mysql

/// MySQL TLS 状态
/// 对应 Bun: TLSStatus (union enum)
public enum TLSStatus {
    | none                // 无 TLS
    | pending             // 等待中
    | ssl_not_available   // SSL 不可用
    | ssl_failed          // SSL 握手失败
    | ssl_ok              // SSL 连接成功
}
