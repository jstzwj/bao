// MySQL 连接状态
// 对应 Bun: src/sql/mysql/ConnectionState.zig
package bao_sql.mysql

/// MySQL 连接状态枚举
/// 对应 Bun: ConnectionState (enum)
public enum ConnectionState {
    | disconnected                 // 已断开
    | connecting                   // 正在连接
    | handshaking                  // 握手中
    | authenticating               // 认证中
    | authentication_awaiting_pk   // 等待公钥
    | connected                    // 已连接
    | failed                       // 失败
}
