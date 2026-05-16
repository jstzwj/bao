// MySQL 字段类型 (protocol 包本地副本，用于打破循环依赖)
// 对应 Bun: FieldType (enum u8)
package bao_sql.mysql.protocol

/// MySQL 字段类型
/// 对应 Bun: FieldType (enum u8)
/// 参考: https://dev.mysql.com/doc/dev/mysql-server/latest/binary__log__types_8h.html
public enum FieldType {
    | MYSQL_TYPE_DECIMAL(UInt8)
    | MYSQL_TYPE_TINY(UInt8)
    | MYSQL_TYPE_SHORT(UInt8)
    | MYSQL_TYPE_LONG(UInt8)
    | MYSQL_TYPE_FLOAT(UInt8)
    | MYSQL_TYPE_DOUBLE(UInt8)
    | MYSQL_TYPE_NULL(UInt8)
    | MYSQL_TYPE_TIMESTAMP(UInt8)
    | MYSQL_TYPE_LONGLONG(UInt8)
    | MYSQL_TYPE_INT24(UInt8)
    | MYSQL_TYPE_DATE(UInt8)
    | MYSQL_TYPE_TIME(UInt8)
    | MYSQL_TYPE_DATETIME(UInt8)
    | MYSQL_TYPE_YEAR(UInt8)
    | MYSQL_TYPE_NEWDATE(UInt8)
    | MYSQL_TYPE_VARCHAR(UInt8)
    | MYSQL_TYPE_BIT(UInt8)
    | MYSQL_TYPE_TIMESTAMP2(UInt8)
    | MYSQL_TYPE_DATETIME2(UInt8)
    | MYSQL_TYPE_TIME2(UInt8)
    | MYSQL_TYPE_JSON(UInt8)
    | MYSQL_TYPE_NEWDECIMAL(UInt8)
    | MYSQL_TYPE_ENUM(UInt8)
    | MYSQL_TYPE_SET(UInt8)
    | MYSQL_TYPE_TINY_BLOB(UInt8)
    | MYSQL_TYPE_MEDIUM_BLOB(UInt8)
    | MYSQL_TYPE_LONG_BLOB(UInt8)
    | MYSQL_TYPE_BLOB(UInt8)
    | MYSQL_TYPE_VAR_STRING(UInt8)
    | MYSQL_TYPE_STRING(UInt8)
    | MYSQL_TYPE_GEOMETRY(UInt8)

    /// 从整数值创建
    public static func fromInt(value: UInt8): FieldType {
        match (value) {
            case 0x00 => FieldType.MYSQL_TYPE_DECIMAL(0x00)
            case 0x01 => FieldType.MYSQL_TYPE_TINY(0x01)
            case 0x02 => FieldType.MYSQL_TYPE_SHORT(0x02)
            case 0x03 => FieldType.MYSQL_TYPE_LONG(0x03)
            case 0x04 => FieldType.MYSQL_TYPE_FLOAT(0x04)
            case 0x05 => FieldType.MYSQL_TYPE_DOUBLE(0x05)
            case 0x06 => FieldType.MYSQL_TYPE_NULL(0x06)
            case 0x07 => FieldType.MYSQL_TYPE_TIMESTAMP(0x07)
            case 0x08 => FieldType.MYSQL_TYPE_LONGLONG(0x08)
            case 0x09 => FieldType.MYSQL_TYPE_INT24(0x09)
            case 0x0a => FieldType.MYSQL_TYPE_DATE(0x0a)
            case 0x0b => FieldType.MYSQL_TYPE_TIME(0x0b)
            case 0x0c => FieldType.MYSQL_TYPE_DATETIME(0x0c)
            case 0x0d => FieldType.MYSQL_TYPE_YEAR(0x0d)
            case 0x0e => FieldType.MYSQL_TYPE_NEWDATE(0x0e)
            case 0x0f => FieldType.MYSQL_TYPE_VARCHAR(0x0f)
            case 0x10 => FieldType.MYSQL_TYPE_BIT(0x10)
            case 0x11 => FieldType.MYSQL_TYPE_TIMESTAMP2(0x11)
            case 0x12 => FieldType.MYSQL_TYPE_DATETIME2(0x12)
            case 0x13 => FieldType.MYSQL_TYPE_TIME2(0x13)
            case 0xf5 => FieldType.MYSQL_TYPE_JSON(0xf5)
            case 0xf6 => FieldType.MYSQL_TYPE_NEWDECIMAL(0xf6)
            case 0xf7 => FieldType.MYSQL_TYPE_ENUM(0xf7)
            case 0xf8 => FieldType.MYSQL_TYPE_SET(0xf8)
            case 0xf9 => FieldType.MYSQL_TYPE_TINY_BLOB(0xf9)
            case 0xfa => FieldType.MYSQL_TYPE_MEDIUM_BLOB(0xfa)
            case 0xfb => FieldType.MYSQL_TYPE_LONG_BLOB(0xfb)
            case 0xfc => FieldType.MYSQL_TYPE_BLOB(0xfc)
            case 0xfd => FieldType.MYSQL_TYPE_VAR_STRING(0xfd)
            case 0xfe => FieldType.MYSQL_TYPE_STRING(0xfe)
            case 0xff => FieldType.MYSQL_TYPE_GEOMETRY(0xff)
            case _ => FieldType.MYSQL_TYPE_NULL(0x06)
        }
    }

    /// 转为 UInt8
    public func toUInt8(): UInt8 {
        match (this) {
            case MYSQL_TYPE_DECIMAL(v) => v
            case MYSQL_TYPE_TINY(v) => v
            case MYSQL_TYPE_SHORT(v) => v
            case MYSQL_TYPE_LONG(v) => v
            case MYSQL_TYPE_FLOAT(v) => v
            case MYSQL_TYPE_DOUBLE(v) => v
            case MYSQL_TYPE_NULL(v) => v
            case MYSQL_TYPE_TIMESTAMP(v) => v
            case MYSQL_TYPE_LONGLONG(v) => v
            case MYSQL_TYPE_INT24(v) => v
            case MYSQL_TYPE_DATE(v) => v
            case MYSQL_TYPE_TIME(v) => v
            case MYSQL_TYPE_DATETIME(v) => v
            case MYSQL_TYPE_YEAR(v) => v
            case MYSQL_TYPE_NEWDATE(v) => v
            case MYSQL_TYPE_VARCHAR(v) => v
            case MYSQL_TYPE_BIT(v) => v
            case MYSQL_TYPE_TIMESTAMP2(v) => v
            case MYSQL_TYPE_DATETIME2(v) => v
            case MYSQL_TYPE_TIME2(v) => v
            case MYSQL_TYPE_JSON(v) => v
            case MYSQL_TYPE_NEWDECIMAL(v) => v
            case MYSQL_TYPE_ENUM(v) => v
            case MYSQL_TYPE_SET(v) => v
            case MYSQL_TYPE_TINY_BLOB(v) => v
            case MYSQL_TYPE_MEDIUM_BLOB(v) => v
            case MYSQL_TYPE_LONG_BLOB(v) => v
            case MYSQL_TYPE_BLOB(v) => v
            case MYSQL_TYPE_VAR_STRING(v) => v
            case MYSQL_TYPE_STRING(v) => v
            case MYSQL_TYPE_GEOMETRY(v) => v
        }
    }

    /// 是否支持二进制格式
    public func isBinaryFormatSupported(): Bool {
        match (this) {
            case MYSQL_TYPE_BLOB(_) | MYSQL_TYPE_MEDIUM_BLOB(_) |
                 MYSQL_TYPE_LONG_BLOB(_) | MYSQL_TYPE_TINY_BLOB(_) |
                 MYSQL_TYPE_GEOMETRY(_) => true
            case _ => false
        }
    }
}
