// 严格翻译自: src/sql/postgres/protocol/FieldDescription.zig
// PostgreSQL 字段描述
package bao_sql.postgres.protocol

import bao_sql.postgres.types.Tag
import bao_sql.shared.ColumnIdentifier
import bao_sql.shared.Data

/// PostgreSQL 字段描述
/// 对应 Bun: FieldDescription
public class FieldDescription {
    /// 字段名称或索引
    public var nameOrIndex: ColumnIdentifier
    /// 表 OID
    public var tableOid: UInt32
    /// 列索引
    public var columnIndex: UInt16
    /// 类型 OID
    public var typeOid: UInt32
    /// 是否二进制格式
    public var binary: Bool

    public init() {
        nameOrIndex = ColumnIdentifier.fromName(Data.emptyData())
        tableOid = 0
        columnIndex = 0
        typeOid = 0
        binary = false
    }

    /// 获取类型标签
    /// 对应 Bun: FieldDescription.typeTag
    public func typeTag(): Tag {
        return Tag.fromOid(Int16(typeOid & 0xFFFF))
    }

    /// 释放资源
    /// 对应 Bun: FieldDescription.deinit
    public func deinit(): Unit {
        // Cangjie has GC, no manual deinit needed
    }

    /// 从读取器解码
    /// 对应 Bun: FieldDescription.decodeInternal
    public static func decode(reader: StackReaderImpl): ?FieldDescription {
        let result = FieldDescription()

        // 字段名 (null 结尾字符串)
        let name = reader.readZ()
        if (name.isNone()) { return None }
        let fieldName = ColumnIdentifier.initIdentifier(name.getOrThrow())

        // 表 OID (4 字节)
        let tableOid = reader.int4()
        if (tableOid.isNone()) { return None }

        // 列属性号 (2 字节)
        let columnIndex = reader.short()
        if (columnIndex.isNone()) { return None }

        // 数据类型 OID (4 字节)
        let typeOid = reader.int4()
        if (typeOid.isNone()) { return None }

        // 数据类型大小 (2 字节) + 类型修饰符 (4 字节) - 跳过
        reader.skip(6)

        // 格式代码 (2 字节)
        let formatCode = reader.short()
        if (formatCode.isNone()) { return None }

        let binary = match (formatCode.getOrThrow()) {
            case 0 => false
            case 1 => true
            case _ => false
        }

        result.nameOrIndex = fieldName
        result.tableOid = tableOid.getOrThrow()
        result.columnIndex = columnIndex.getOrThrow()
        result.typeOid = typeOid.getOrThrow()
        result.binary = binary

        return result
    }
}
