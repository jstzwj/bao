// PostgreSQL 协议字段类型 (错误/通知响应的字段标识)
// 严格翻译自: bun/src/sql/postgres/protocol/FieldType.zig
//   pub const FieldType = enum(u8) { severity = 'S', ... };
package bao_runtime.sql.postgresql

/// PostgreSQL 错误/通知响应字段类型
/// 通过单字节标识不同字段
/// 对应 Bun FieldType
public enum FieldType {
    | Severity              // 'S' - 严重程度 (ERROR/FATAL/PANIC/WARNING/NOTICE/DEBUG/INFO/LOG)
    | LocalizedSeverity     // 'V' - 非本地化的严重程度
    | Code                  // 'C' - SQLSTATE 错误代码
    | Message               // 'M' - 主要错误消息
    | Detail                // 'D' - 详细错误消息
    | Hint                  // 'H' - 修复建议
    | Position              // 'P' - 错误游标位置
    | InternalPosition      // 'p' - 内部命令游标位置
    | Internal              // 'q' - 内部命令文本
    | Where                 // 'W' - 错误上下文
    | Schema                // 's' - 模式名
    | Table                 // 't' - 表名
    | Column                // 'c' - 列名
    | Datatype              // 'd' - 数据类型名
    | Constraint            // 'n' - 约束名
    | File                  // 'F' - 源代码文件名
    | Line                  // 'L' - 源代码行号
    | Routine               // 'R' - 源代码例程名
    | Unknown(UInt8)        // 未知字段类型

    /// 从字节值获取 FieldType
    /// 对应 Bun FieldType 的 @enumFromInt
    public static func fromByte(b: UInt8): FieldType {
        match (b) {
            case 83 => Severity           // 'S'
            case 86 => LocalizedSeverity   // 'V'
            case 67 => Code                // 'C'
            case 77 => Message             // 'M'
            case 68 => Detail              // 'D'
            case 72 => Hint                // 'H'
            case 80 => Position            // 'P'
            case 112 => InternalPosition   // 'p'
            case 113 => Internal           // 'q'
            case 87 => Where               // 'W'
            case 115 => Schema             // 's'
            case 116 => Table              // 't'
            case 99 => Column              // 'c'
            case 100 => Datatype           // 'd'
            case 110 => Constraint         // 'n'
            case 70 => File                // 'F'
            case 76 => Line                // 'L'
            case 82 => Routine             // 'R'
            case _ => Unknown(b)
        }
    }

    /// 转为字节值
    public func toByte(): UInt8 {
        match (this) {
            case Severity => 83            // 'S'
            case LocalizedSeverity => 86   // 'V'
            case Code => 67                // 'C'
            case Message => 77             // 'M'
            case Detail => 68              // 'D'
            case Hint => 72                // 'H'
            case Position => 80            // 'P'
            case InternalPosition => 112   // 'p'
            case Internal => 113           // 'q'
            case Where => 87               // 'W'
            case Schema => 115             // 's'
            case Table => 116              // 't'
            case Column => 99              // 'c'
            case Datatype => 100           // 'd'
            case Constraint => 110         // 'n'
            case File => 70                // 'F'
            case Line => 76                // 'L'
            case Routine => 82             // 'R'
            case Unknown(b) => b
        }
    }
}
