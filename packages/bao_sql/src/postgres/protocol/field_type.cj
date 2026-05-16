// 严格翻译自: src/sql/postgres/protocol/FieldType.zig
// PostgreSQL 错误/通知字段类型
package bao_sql.postgres.protocol

/// PostgreSQL 错误/通知响应中的字段类型
/// 对应 Bun: FieldType (enum u8)
public enum FieldType {
    | severity             // 'S' - 严重性
    | localized_severity   // 'V' - 本地化严重性
    | code                 // 'C' - SQLSTATE 错误代码
    | message              // 'M' - 主要错误消息
    | detail               // 'D' - 详细错误消息
    | hint                 // 'H' - 提示
    | position             // 'P' - 错误位置
    | internal_position    // 'p' - 内部位置
    | internal             // 'q' - 内部查询
    | whereClause          // 'W' - 上下文
    | schema               // 's' - 模式名
    | table                // 't' - 表名
    | column               // 'c' - 列名
    | datatype             // 'd' - 数据类型名
    | constraint           // 'n' - 约束名
    | file                 // 'F' - 源文件名
    | line                 // 'L' - 源代码行号
    | routine              // 'R' - 源代码例程名
    | unknown(UInt8)

    /// 从字节值创建
    public static func fromByte(value: UInt8): FieldType {
        if (value == 83) { return FieldType.severity }
        if (value == 86) { return FieldType.localized_severity }
        if (value == 67) { return FieldType.code }
        if (value == 77) { return FieldType.message }
        if (value == 68) { return FieldType.detail }
        if (value == 72) { return FieldType.hint }
        if (value == 80) { return FieldType.position }
        if (value == 112) { return FieldType.internal_position }
        if (value == 113) { return FieldType.internal }
        if (value == 87) { return FieldType.whereClause }
        if (value == 115) { return FieldType.schema }
        if (value == 116) { return FieldType.table }
        if (value == 99) { return FieldType.column }
        if (value == 100) { return FieldType.datatype }
        if (value == 110) { return FieldType.constraint }
        if (value == 70) { return FieldType.file }
        if (value == 76) { return FieldType.line }
        if (value == 82) { return FieldType.routine }
        return FieldType.unknown(value)
    }

    /// 转为字节值
    public func toByte(): UInt8 {
        match (this) {
            case severity => UInt8(83)
            case localized_severity => UInt8(86)
            case code => UInt8(67)
            case message => UInt8(77)
            case detail => UInt8(68)
            case hint => UInt8(72)
            case position => UInt8(80)
            case internal_position => UInt8(112)
            case internal => UInt8(113)
            case whereClause => UInt8(87)
            case schema => UInt8(115)
            case table => UInt8(116)
            case column => UInt8(99)
            case datatype => UInt8(100)
            case constraint => UInt8(110)
            case file => UInt8(70)
            case line => UInt8(76)
            case routine => UInt8(82)
            case unknown(v) => v
        }
    }
}
