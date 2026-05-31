// MySQL 字段类型和整数类型定义
// 严格翻译自: src/sql/mysql/MySQLTypes.zig
package bao_runtime.sql.mysql

/// MySQL 字段类型
/// 对应 Bun: FieldType (enum u8)
/// 参考: https://dev.mysql.com/doc/dev/mysql-server/latest/binary__log__types_8h.html
public enum FieldType <: UInt8 {
    | MYSQL_TYPE_DECIMAL(0x00)
    | MYSQL_TYPE_TINY(0x01)
    | MYSQL_TYPE_SHORT(0x02)
    | MYSQL_TYPE_LONG(0x03)
    | MYSQL_TYPE_FLOAT(0x04)
    | MYSQL_TYPE_DOUBLE(0x05)
    | MYSQL_TYPE_NULL(0x06)
    | MYSQL_TYPE_TIMESTAMP(0x07)
    | MYSQL_TYPE_LONGLONG(0x08)
    | MYSQL_TYPE_INT24(0x09)    // MEDIUMINT
    | MYSQL_TYPE_DATE(0x0a)
    | MYSQL_TYPE_TIME(0x0b)
    | MYSQL_TYPE_DATETIME(0x0c)
    | MYSQL_TYPE_YEAR(0x0d)
    | MYSQL_TYPE_NEWDATE(0x0e)
    | MYSQL_TYPE_VARCHAR(0x0f)
    | MYSQL_TYPE_BIT(0x10)
    | MYSQL_TYPE_TIMESTAMP2(0x11)
    | MYSQL_TYPE_DATETIME2(0x12)
    | MYSQL_TYPE_TIME2(0x13)
    | MYSQL_TYPE_JSON(0xf5)
    | MYSQL_TYPE_NEWDECIMAL(0xf6)
    | MYSQL_TYPE_ENUM(0xf7)
    | MYSQL_TYPE_SET(0xf8)
    | MYSQL_TYPE_TINY_BLOB(0xf9)
    | MYSQL_TYPE_MEDIUM_BLOB(0xfa)
    | MYSQL_TYPE_LONG_BLOB(0xfb)
    | MYSQL_TYPE_BLOB(0xfc)
    | MYSQL_TYPE_VAR_STRING(0xfd)
    | MYSQL_TYPE_STRING(0xfe)
    | MYSQL_TYPE_GEOMETRY(0xff)

    /// 是否支持二进制格式 (预编译语句的二进制结果集)
    /// 对应 Bun: FieldType.isBinaryFormatSupported
    public func isBinaryFormatSupported(): Bool {
        match (this) {
            case MYSQL_TYPE_TINY => true
            case MYSQL_TYPE_SHORT => true
            case MYSQL_TYPE_LONG => true
            case MYSQL_TYPE_LONGLONG => true
            case MYSQL_TYPE_FLOAT => true
            case MYSQL_TYPE_DOUBLE => true
            case MYSQL_TYPE_TIME => true
            case MYSQL_TYPE_DATE => true
            case MYSQL_TYPE_DATETIME => true
            case MYSQL_TYPE_TIMESTAMP => true
            case _ => false
        }
    }
}

// ============================================================================
// MySQL 整数类型别名
// 对应 Bun: MySQLTypes.zig 中的类型别名
// ============================================================================

/// MySQL Int8 (1 字节无符号)
public typealias MySQLInt8 = UInt8
/// MySQL Int16 (2 字节无符号)
public typealias MySQLInt16 = UInt16
/// MySQL Int24 (3 字节) - 仓颉无 UInt24，用 UInt32
public typealias MySQLInt24 = UInt32
/// MySQL Int32 (4 字节无符号)
public typealias MySQLInt32 = UInt32
/// MySQL Int64 (8 字节无符号)
public typealias MySQLInt64 = UInt64
