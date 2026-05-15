// MySQL TLS 状态
// 对应 Bun: src/sql/mysql/TLSStatus.zig
package bao_sql.mysql

/// MySQL TLS 连接状态
/// 对应 Bun: TLSStatus (union enum)
public enum TLSStatus {
    | none                    // 无 TLS
    | pending                 // TLS 握手挂起
    | message_sent            // SSL 请求消息部分发送
    | ssl_not_available       // SSL 不可用
    | ssl_failed              // SSL 失败
    | ssl_ok                  // SSL 成功
}
