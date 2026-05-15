// MySQL 列定义 (Column Definition 41)
// 对应 Bun: src/sql/mysql/protocol/ColumnDefinition41.zig
package bao_sql.mysql.protocol

/// MySQL 列标志位
/// 对应 Bun: ColumnDefinition41.ColumnFlags (packed struct)
///
/// 使用 16 位整数表示列的各种属性标志
public class ColumnFlags {
    public var NOT_NULL: Bool
    public var PRI_KEY: Bool
    public var UNIQUE_KEY: Bool
    public var MULTIPLE_KEY: Bool
    public var BLOB: Bool
    public var UNSIGNED: Bool
    public var ZEROFILL: Bool
    public var BINARY: Bool
    public var ENUM: Bool
    public var AUTO_INCREMENT: Bool
    public var TIMESTAMP: Bool
    public var SET: Bool
    public var NO_DEFAULT_VALUE: Bool
    public var ON_UPDATE_NOW: Bool

    public init() {
        NOT_NULL = false
        PRI_KEY = false
        UNIQUE_KEY = false
        MULTIPLE_KEY = false
        BLOB = false
        UNSIGNED = false
        ZEROFILL = false
        BINARY = false
        ENUM = false
        AUTO_INCREMENT = false
        TIMESTAMP = false
        SET = false
        NO_DEFAULT_VALUE = false
        ON_UPDATE_NOW = false
    }

    /// 将标志位转换为整数
    /// 对应 Bun: ColumnFlags.toInt
    public func toInt(): UInt16 {
        var value: UInt16 = 0
        if (NOT_NULL) { value = value | UInt16(1 << 0) }
        if (PRI_KEY) { value = value | UInt16(1 << 1) }
        if (UNIQUE_KEY) { value = value | UInt16(1 << 2) }
        if (MULTIPLE_KEY) { value = value | UInt16(1 << 3) }
        if (BLOB) { value = value | UInt16(1 << 4) }
        if (UNSIGNED) { value = value | UInt16(1 << 5) }
        if (ZEROFILL) { value = value | UInt16(1 << 6) }
        if (BINARY) { value = value | UInt16(1 << 7) }
        if (ENUM) { value = value | UInt16(1 << 8) }
        if (AUTO_INCREMENT) { value = value | UInt16(1 << 9) }
        if (TIMESTAMP) { value = value | UInt16(1 << 10) }
        if (SET) { value = value | UInt16(1 << 11) }
        if (NO_DEFAULT_VALUE) { value = value | UInt16(1 << 12) }
        if (ON_UPDATE_NOW) { value = value | UInt16(1 << 13) }
        return value
    }

    /// 从整数解析标志位
    /// 对应 Bun: ColumnFlags.fromInt
    public static func fromInt(flags: UInt16): ColumnFlags {
        let cf = ColumnFlags()
        cf.NOT_NULL = (flags & UInt16(1 << 0)) != 0
        cf.PRI_KEY = (flags & UInt16(1 << 1)) != 0
        cf.UNIQUE_KEY = (flags & UInt16(1 << 2)) != 0
        cf.MULTIPLE_KEY = (flags & UInt16(1 << 3)) != 0
        cf.BLOB = (flags & UInt16(1 << 4)) != 0
        cf.UNSIGNED = (flags & UInt16(1 << 5)) != 0
        cf.ZEROFILL = (flags & UInt16(1 << 6)) != 0
        cf.BINARY = (flags & UInt16(1 << 7)) != 0
        cf.ENUM = (flags & UInt16(1 << 8)) != 0
        cf.AUTO_INCREMENT = (flags & UInt16(1 << 9)) != 0
        cf.TIMESTAMP = (flags & UInt16(1 << 10)) != 0
        cf.SET = (flags & UInt16(1 << 11)) != 0
        cf.NO_DEFAULT_VALUE = (flags & UInt16(1 << 12)) != 0
        cf.ON_UPDATE_NOW = (flags & UInt16(1 << 13)) != 0
        return cf
    }
}

/// MySQL 列标识符
/// 对应 Bun: ColumnIdentifier (来自 shared/ColumnIdentifier.zig)
public class ColumnIdentifier {
    /// 列名
    public var name: String

    public init() {
        name = ""
    }

    public init(name: String) {
        this.name = name
    }
}

/// MySQL 协议 4.1 版本列定义包
/// 对应 Bun: ColumnDefinition41 (struct)
///
/// 描述结果集中某一列的元数据信息
public class ColumnDefinition41 {
    /// 目录名 (长度编码字符串)
    /// 对应 Bun: catalog Data
    public var catalog: Array<UInt8>

    /// 模式名 (长度编码字符串)
    /// 对应 Bun: schema Data
    public var schema: Array<UInt8>

    /// 表名 (长度编码字符串)
    /// 对应 Bun: table Data
    public var table: Array<UInt8>

    /// 原始表名 (长度编码字符串)
    /// 对应 Bun: org_table Data
    public var orgTable: Array<UInt8>

    /// 列名 (长度编码字符串)
    /// 对应 Bun: name Data
    public var name: Array<UInt8>

    /// 原始列名 (长度编码字符串)
    /// 对应 Bun: org_name Data
    public var orgName: Array<UInt8>

    /// 固定长度字段长度
    /// 对应 Bun: fixed_length_fields_length u64
    public var fixedLengthFieldsLength: UInt64

    /// 字符集
    /// 对应 Bun: character_set u16
    public var characterSet: UInt16

    /// 列长度
    /// 对应 Bun: column_length u32
    public var columnLength: UInt32

    /// 列类型
    /// 对应 Bun: column_type FieldType
    public var columnType: FieldType

    /// 列标志
    /// 对应 Bun: flags ColumnFlags
    public var flags: ColumnFlags

    /// 小数位数
    /// 对应 Bun: decimals u8
    public var decimals: UInt8

    /// 列名或索引标识
    /// 对应 Bun: name_or_index ColumnIdentifier
    public var nameOrIndex: ColumnIdentifier

    public init() {
        catalog = Array<UInt8>()
        schema = Array<UInt8>()
        table = Array<UInt8>()
        orgTable = Array<UInt8>()
        name = Array<UInt8>()
        orgName = Array<UInt8>()
        fixedLengthFieldsLength = 0
        characterSet = 0
        columnLength = 0
        columnType = FieldType.MYSQL_TYPE_NULL(0x06)
        flags = ColumnFlags()
        decimals = 0
        nameOrIndex = ColumnIdentifier()
    }

    /// 释放资源
    /// 对应 Bun: ColumnDefinition41.deinit
    public func deinit(): Unit {
        catalog = Array<UInt8>()
        schema = Array<UInt8>()
        table = Array<UInt8>()
        orgTable = Array<UInt8>()
        name = Array<UInt8>()
        orgName = Array<UInt8>()
        nameOrIndex = ColumnIdentifier()
    }

    /// 从读取器解码列定义
    /// 对应 Bun: ColumnDefinition41.decodeInternal
    public func decode(reader: MySQLPacketReader): Unit {
        // 读取长度编码字符串
        catalog = reader.encodeLenString()
        schema = reader.encodeLenString()
        table = reader.encodeLenString()
        orgTable = reader.encodeLenString()
        name = reader.encodeLenString()
        orgName = reader.encodeLenString()

        // 读取固定长度字段
        fixedLengthFieldsLength = reader.encodedLenInt()
        characterSet = reader.int16()
        columnLength = reader.int32()
        columnType = FieldType.fromInt(reader.int8())
        flags = ColumnFlags.fromInt(reader.int16())
        decimals = reader.int8()

        nameOrIndex = ColumnIdentifier(String.fromUtf8(name))

        // 跳过末尾 2 字节
        // 参考: https://mariadb.com/kb/en/result-set-packets/#column-definition-packet
        reader.skip(2)
    }
}
