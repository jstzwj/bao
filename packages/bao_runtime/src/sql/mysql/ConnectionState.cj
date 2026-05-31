// MySQL 连接状态
// 严格翻译自: src/sql/mysql/ConnectionState.zig
package bao_runtime.sql.mysql

/// MySQL 连接状态机
/// 对应 Bun: ConnectionState (enum)
public enum ConnectionState {
    | disconnected              // 已断开
    | connecting                // 正在连接
    | handshaking               // 正在握手
    | authenticating            // 正在认证
    | authentication_awaiting_pk // 等待公钥 (caching_sha2_password)
    | connected                 // 已连接
    | failed                    // 连接失败
}
