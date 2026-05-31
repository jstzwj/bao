// MySQL Column Definition 41 协议包
// 严格翻译自: src/sql/mysql/protocol/ColumnDefinition41.zig
package bao_runtime.sql.mysql

import bao_core.*
import bao_runtime.sql.shared.*

/// MySQL 列标志 (16 位)
/// 对应 Bun: ColumnDefinition41.ColumnFlags (packed struct)
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

    /// 转为 UInt16
    /// 对应 Bun: ColumnFlags.toInt
    public func toInt(): UInt16 {
        var value: UInt16 = 0
        if (NOT_NULL) { value = value | 1 }
        if (PRI_KEY) { value = value | 2 }
        if (UNIQUE_KEY) { value = value | 4 }
        if (MULTIPLE_KEY) { value = value | 8 }
        if (BLOB) { value = value | 16 }
        if (UNSIGNED) { value = value | 32 }
        if (ZEROFILL) { value = value | 64 }
        if (BINARY) { value = value | 128 }
        if (ENUM) { value = value | 256 }
        if (AUTO_INCREMENT) { value = value | 512 }
        if (TIMESTAMP) { value = value | 1024 }
        if (SET) { value = value | 2048 }
        if (NO_DEFAULT_VALUE) { value = value | 4096 }
        if (ON_UPDATE_NOW) { value = value | 8192 }
        return value
    }

    /// 从 UInt16 解码
    /// 对应 Bun: ColumnFlags.fromInt
    public static func fromInt(flags: UInt16): ColumnFlags {
        let f = ColumnFlags()
        f.NOT_NULL = (flags & 1) != 0
        f.PRI_KEY = (flags & 2) != 0
        f.UNIQUE_KEY = (flags & 4) != 0
        f.MULTIPLE_KEY = (flags & 8) != 0
        f.BLOB = (flags & 16) != 0
        f.UNSIGNED = (flags & 32) != 0
        f.ZEROFILL = (flags & 64) != 0
        f.BINARY = (flags & 128) != 0
        f.ENUM = (flags & 256) != 0
        f.AUTO_INCREMENT = (flags & 512) != 0
        f.TIMESTAMP = (flags & 1024) != 0
        f.SET = (flags & 2048) != 0
        f.NO_DEFAULT_VALUE = (flags & 4096) != 0
        f.ON_UPDATE_NOW = (flags & 8192) != 0
        return f
    }
}

/// MySQL Column Definition 4.1 协议包
/// 对应 Bun: ColumnDefinition41
/// 描述结果集中一列的元数据
public class ColumnDefinition41 {
    /// 目录名
    public var catalog: SQLData
    /// 数据库名
    public var schema: SQLData
    /// 表别名
    public var table: SQLData
    /// 原始表名
    public var orgTable: SQLData
    /// 列别名
    public var name: SQLData
    /// 原始列名
    public var orgName: SQLData
    /// 固定长度字段长度
    public var fixedLengthFieldsLength: UInt64
    /// 字符集
    public var characterSet: UInt16
    /// 列长度
    public var columnLength: UInt32
    /// 列类型
    public var columnType: FieldType
    /// 列标志
    public var flags: ColumnFlags
    /// 小数位数
    public var decimals: UInt8
    /// 列标识符 (名称或索引)
    public var nameOrIndex: ColumnIdentifier

    public init() {
        catalog = SQLData.empty()
        schema = SQLData.empty()
        table = SQLData.empty()
        orgTable = SQLData.empty()
        name = SQLData.empty()
        orgName = SQLData.empty()
        fixedLengthFieldsLength = 0
        characterSet = 0
        columnLength = 0
        columnType = FieldType.MYSQL_TYPE_NULL
        flags = ColumnFlags()
        decimals = 0
        nameOrIndex = ColumnIdentifier()
    }

    /// 释放资源
    /// 对应 Bun: ColumnDefinition41.deinit
    public func deinit(): Unit {
        catalog.deinit()
        schema.deinit()
        table.deinit()
        orgTable.deinit()
        name.deinit()
        orgName.deinit()
        nameOrIndex.deinit()
    }

    /// 从 Reader 解码
    /// 对应 Bun: ColumnDefinition41.decodeInternal
    public func decode(reader: MySQLPacketReader): Unit {
        // 长度编码字符串
        catalog = reader.readEncodedString()
        schema = reader.readEncodedString()
        table = reader.readEncodedString()
        orgTable = reader.readEncodedString()
        name = reader.readEncodedString()
        orgName = reader.readEncodedString()

        fixedLengthFieldsLength = reader.readEncodedLenInt()
        characterSet = reader.readInt16()
        columnLength = reader.readInt32()
        columnType = FieldType.valueOf(reader.readInt8())
        flags = ColumnFlags.fromInt(reader.readInt16())
        decimals = reader.readInt8()

        // 更新列标识符
        nameOrIndex.deinit()
        nameOrIndex = ColumnIdentifier.init(name)

        // 跳过末尾 2 字节保留字段
        // 参考: https://mariadb.com/kb/en/result-set-packets/#column-definition-packet
        reader.skip(2)
    }
}
