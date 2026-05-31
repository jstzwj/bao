// PostgreSQL 连接状态
// 严格翻译自: bun/src/sql/postgres/Status.zig
//   pub const Status = enum {
//       disconnected,
//       connecting,
//       sent_startup_message,
//       connected,
//       failed,
//   };
package bao_runtime.sql.postgresql

/// PostgreSQL 连接状态
/// 对应 Bun Status
public enum PGConnectionStatus {
    | Disconnected          // 已断开
    | Connecting            // 正在连接
    | SentStartupMessage    // 已发送启动消息（等待 TLS/响应）
    | Connected             // 已连接
    | Failed                // 连接失败

    public operator func ==(right: PGConnectionStatus): Bool {
        match (this) {
            case Disconnected => match (right) { case Disconnected => true case _ => false }
            case Connecting => match (right) { case Connecting => true case _ => false }
            case SentStartupMessage => match (right) { case SentStartupMessage => true case _ => false }
            case Connected => match (right) { case Connected => true case _ => false }
            case Failed => match (right) { case Failed => true case _ => false }
        }
    }

    public operator func !=(right: PGConnectionStatus): Bool {
        !(this == right)
    }
}
