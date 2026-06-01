// MySQL 字段类型和整数类型定义
// 严格翻译自: src/sql/mysql/MySQLTypes.zig
package bao_runtime.sql.mysql

/// MySQL 字段类型
/// 对应 Bun: FieldType (enum u8)
/// 参考: https://dev.mysql.com/doc/dev/mysql-server/latest/binary__log__types_8h.html
public enum FieldType {
    | MYSQL_TYPE_DECIMAL  
    | MYSQL_TYPE_TINY  
    | MYSQL_TYPE_SHORT  
    | MYSQL_TYPE_LONG  
    | MYSQL_TYPE_FLOAT  
    | MYSQL_TYPE_DOUBLE  
    | MYSQL_TYPE_NULL  
    | MYSQL_TYPE_TIMESTAMP  
    | MYSQL_TYPE_LONGLONG  
    | MYSQL_TYPE_INT24  // MEDIUMINT
    | MYSQL_TYPE_DATE  
    | MYSQL_TYPE_TIME  
    | MYSQL_TYPE_DATETIME  
    | MYSQL_TYPE_YEAR  
    | MYSQL_TYPE_NEWDATE  
    | MYSQL_TYPE_VARCHAR  
    | MYSQL_TYPE_BIT  
    | MYSQL_TYPE_TIMESTAMP2  
    | MYSQL_TYPE_DATETIME2  
    | MYSQL_TYPE_TIME2  
    | MYSQL_TYPE_JSON  
    | MYSQL_TYPE_NEWDECIMAL  
    | MYSQL_TYPE_ENUM  
    | MYSQL_TYPE_SET  
    | MYSQL_TYPE_TINY_BLOB  
    | MYSQL_TYPE_MEDIUM_BLOB  
    | MYSQL_TYPE_LONG_BLOB  
    | MYSQL_TYPE_BLOB  
    | MYSQL_TYPE_VAR_STRING  
    | MYSQL_TYPE_STRING  
    | MYSQL_TYPE_GEOMETRY  

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
public type MySQLInt8 = UInt8
/// MySQL Int16 (2 字节无符号)
public type MySQLInt16 = UInt16
/// MySQL Int24 (3 字节) - 仓颉无 UInt24，用 UInt32
public type MySQLInt24 = UInt32
/// MySQL Int32 (4 字节无符号)
public type MySQLInt32 = UInt32
/// MySQL Int64 (8 字节无符号)
public type MySQLInt64 = UInt64
