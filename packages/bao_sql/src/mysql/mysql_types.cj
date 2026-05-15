// MySQL 类型定义
// 对应 Bun: src/sql/mysql/MySQLTypes.zig
package bao_sql.mysql

/// MySQL 整数类型别名
/// 对应 Bun: int1, int2, int3, int4, int8
public type MySQLInt8 = UInt8   // int1 = u8
public type MySQLInt16 = UInt16 // int2 = u16
// int3 = u24 (仓颉没有 u24，使用 UInt32 替代)
public type MySQLInt24 = UInt32 // int3 = u24 -> UInt32
public type MySQLInt32 = UInt32 // int4 = u32
public type MySQLInt64 = UInt64 // int8 = u64

/// MySQL 字符集
/// 对应 Bun: CharacterSet (enum u8)
/// 参考: https://dev.mysql.com/doc/refman/8.0/en/charset-charsets.html
public enum CharacterSet {
}
        return "(unknown)"
    }
}

/// MySQL 字段类型
/// 对应 Bun: FieldType (enum u8)
/// 参考: https://dev.mysql.com/doc/dev/mysql-server/latest/binary__log__types_8h.html
public enum FieldType {
}
    }

    /// 从整数值创建
    public static func fromInt(value: UInt8): FieldType {
        match (value) {
            | 0x00 => FieldType.MYSQL_TYPE_DECIMAL(0x00)
            | 0x01 => FieldType.MYSQL_TYPE_TINY(0x01)
            | 0x02 => FieldType.MYSQL_TYPE_SHORT(0x02)
            | 0x03 => FieldType.MYSQL_TYPE_LONG(0x03)
            | 0x04 => FieldType.MYSQL_TYPE_FLOAT(0x04)
            | 0x05 => FieldType.MYSQL_TYPE_DOUBLE(0x05)
            | 0x06 => FieldType.MYSQL_TYPE_NULL(0x06)
            | 0x07 => FieldType.MYSQL_TYPE_TIMESTAMP(0x07)
            | 0x08 => FieldType.MYSQL_TYPE_LONGLONG(0x08)
            | 0x09 => FieldType.MYSQL_TYPE_INT24(0x09)
            | 0x0a => FieldType.MYSQL_TYPE_DATE(0x0a)
            | 0x0b => FieldType.MYSQL_TYPE_TIME(0x0b)
            | 0x0c => FieldType.MYSQL_TYPE_DATETIME(0x0c)
            | 0x0d => FieldType.MYSQL_TYPE_YEAR(0x0d)
            | 0x0e => FieldType.MYSQL_TYPE_NEWDATE(0x0e)
            | 0x0f => FieldType.MYSQL_TYPE_VARCHAR(0x0f)
            | 0x10 => FieldType.MYSQL_TYPE_BIT(0x10)
            | 0x11 => FieldType.MYSQL_TYPE_TIMESTAMP2(0x11)
            | 0x12 => FieldType.MYSQL_TYPE_DATETIME2(0x12)
            | 0x13 => FieldType.MYSQL_TYPE_TIME2(0x13)
            | 0xf5 => FieldType.MYSQL_TYPE_JSON(0xf5)
            | 0xf6 => FieldType.MYSQL_TYPE_NEWDECIMAL(0xf6)
            | 0xf7 => FieldType.MYSQL_TYPE_ENUM(0xf7)
            | 0xf8 => FieldType.MYSQL_TYPE_SET(0xf8)
            | 0xf9 => FieldType.MYSQL_TYPE_TINY_BLOB(0xf9)
            | 0xfa => FieldType.MYSQL_TYPE_MEDIUM_BLOB(0xfa)
            | 0xfb => FieldType.MYSQL_TYPE_LONG_BLOB(0xfb)
            | 0xfc => FieldType.MYSQL_TYPE_BLOB(0xfc)
            | 0xfd => FieldType.MYSQL_TYPE_VAR_STRING(0xfd)
            | 0xfe => FieldType.MYSQL_TYPE_STRING(0xfe)
            | 0xff => FieldType.MYSQL_TYPE_GEOMETRY(0xff)
            | _ => FieldType.MYSQL_TYPE_NULL(0x06)
        }
    }
}
