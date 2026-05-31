// PostgreSQL 事务状态指示器
// 严格翻译自: bun/src/sql/postgres/protocol/TransactionStatusIndicator.zig
//   pub const TransactionStatusIndicator = enum(u8) {
//       I = 'I',
//       T = 'T',
//       E = 'E',
//   };
package bao_runtime.sql.postgresql

/// PostgreSQL 事务状态指示器
/// 在 ReadyForQuery 消息中指示当前事务状态
/// 对应 Bun TransactionStatusIndicator
public enum TransactionStatusIndicator {
    | Idle            // 'I' - 空闲（不在事务块中）
    | InTransaction   // 'T' - 在事务块中
    | Failed          // 'E' - 在失败的事务块中
    | Unknown(UInt8)  // 未知状态

    /// 从字节值解析
    public static func fromByte(b: UInt8): TransactionStatusIndicator {
        match (b) {
            case 73 => Idle           // 'I'
            case 84 => InTransaction  // 'T'
            case 69 => Failed         // 'E'
            case _ => Unknown(b)
        }
    }

    /// 转为字节值
    public func toByte(): UInt8 {
        match (this) {
            case Idle => 73            // 'I'
            case InTransaction => 84   // 'T'
            case Failed => 69          // 'E'
            case Unknown(b) => b
        }
    }
}
