// PostgreSQL TLS 状态
// 严格翻译自: bun/src/sql/postgres/TLSStatus.zig
//   pub const TLSStatus = union(enum) {
//       none,
//       pending,
//       message_sent: u8,
//       ssl_not_available,
//       ssl_ok,
//   };
package bao_runtime.sql.postgresql

/// PostgreSQL TLS 握手状态
/// 对应 Bun TLSStatus
public enum TLSStatus {
    | None                          // 不使用 TLS
    | Pending                       // TLS 握手待发起
    | MessageSent(UInt8)            // SSL 请求消息已部分发送（记录已发送字节数）
    | SSLNotAvailable               // 服务器不支持 SSL
    | SSLOk                         // SSL 连接已建立

    /// 是否正在等待 TLS 握手
    public func isPending(): Bool {
        match (this) {
            case Pending => true
            case MessageSent(_) => true
            case _ => false
        }
    }

    /// 是否已完成 TLS（或不使用 TLS）
    public func isComplete(): Bool {
        match (this) {
            case None | SSLOk => true
            case _ => false
        }
    }
}
