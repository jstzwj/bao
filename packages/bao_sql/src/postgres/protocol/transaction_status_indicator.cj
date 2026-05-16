// 严格翻译自: src/sql/postgres/protocol/TransactionStatusIndicator.zig
// PostgreSQL 事务状态指示器
package bao_sql.postgres.protocol

/// PostgreSQL 事务状态指示器
/// 对应 Bun: TransactionStatusIndicator (enum u8)
public enum TransactionStatusIndicator {
    | I    // 空闲 (不在事务块中)
    | T    // 在事务块中
    | E    // 在失败的事务块中
    | unknown(UInt8)

    /// 从字节值创建
    public static func fromByte(value: UInt8): TransactionStatusIndicator {
        match (value) {
            case 73 => TransactionStatusIndicator.I  // 'I'
            case 84 => TransactionStatusIndicator.T  // 'T'
            case 69 => TransactionStatusIndicator.E  // 'E'
            case _ => TransactionStatusIndicator.unknown(value)
        }
    }

    /// 转为字节值
    public func toByte(): UInt8 {
        match (this) {
            case I => UInt8(73)  // 'I'
            case T => UInt8(84)  // 'T'
            case E => UInt8(69)  // 'E'
            case unknown(v) => v
        }
    }
}
