// PostgreSQL 字段描述 (RowDescription 中的列信息)
// 严格翻译自: bun/src/sql/postgres/protocol/FieldDescription.zig
//   const FieldDescription = @This();
//   name_or_index: ColumnIdentifier, table_oid: int4, ...
package bao_runtime.sql.postgresql

import bao_runtime.sql.shared.*

/// PostgreSQL 列描述符
/// 在 RowDescription 消息中描述每一列的元数据
/// 对应 Bun FieldDescription
public class FieldDescription {
    /// 列名或索引
    public var nameOrIndex: ColumnIdentifier
    /// 表 OID
    public var tableOID: UInt32
    /// 列在表中的索引
    public var columnIndex: UInt16
    /// 数据类型 OID
    public var typeOID: UInt32
    /// 是否使用二进制格式
    public var binary: Bool

    public init() {
        nameOrIndex = ColumnIdentifier.Empty
        tableOID = 0
        columnIndex = 0
        typeOID = 0
        binary = false
    }

    /// 获取类型标签
    /// 对应 Bun FieldDescription.typeTag()
    public func typeTag(): PGTag {
        PGTag.fromOID(UInt16(typeOID & 0xFFFF))
    }

    /// 从读取器解码
    /// 对应 Bun FieldDescription.decodeInternal()
    public func decode(reader: ProtocolReader): Bool {
        // 读取字段名 (null 终止字符串)
        let name = reader.readNullTerminatedString()
        match (name) {
            case None => return false
            case Some(n) =>
                nameOrIndex = ColumnIdentifier.fromString(n)
        }

        // 读取表 OID (4 字节)
        let tableOid = reader.readUInt32()
        match (tableOid) {
            case None => return false
            case Some(v) => tableOID = v
        }

        // 读取列索引 (2 字节)
        let colIdx = reader.readUInt16()
        match (colIdx) {
            case None => return false
            case Some(v) => columnIndex = v
        }

        // 读取数据类型 OID (4 字节)
        let typeOid = reader.readUInt32()
        match (typeOid) {
            case None => return false
            case Some(v) => typeOID = v
        }

        // 跳过数据类型大小 (2 字节) + 类型修饰符 (4 字节) = 6 字节
        reader.skip(6)

        // 读取格式代码 (2 字节)
        let formatCode = reader.readUInt16()
        match (formatCode) {
            case None => return false
            case Some(v) =>
                if (v == 0) {
                    binary = false
                } else if (v == 1) {
                    binary = true
                } else {
                    return false  // UnknownFormatCode
                }
        }
        return true
    }

    /// 释放资源
    public func deinit() {
        // ColumnIdentifier 的字符串由 GC 管理
    }
}

/// 列标识符
/// 对应 Bun ColumnIdentifier
public enum ColumnIdentifier {
    | Name(String)         // 命名列
    | Index(UInt32)        // 数字索引列
    | Duplicate            // 重复列
    | Empty                // 空

    /// 从字符串创建 ColumnIdentifier
    /// 对应 Bun ColumnIdentifier.init()
    /// 如果字符串是纯数字，则返回 Index，否则返回 Name
    public static func fromString(s: String): ColumnIdentifier {
        if (s.size == 0) {
            return Empty
        }

        // 检查是否为纯数字
        var intValue: UInt64 = 0
        var isNumeric = true
        for (c in s) {
            if (c >= 48 && c <= 57) {  // '0' to '9'
                intValue = intValue * 10 + UInt64(c - 48)
            } else {
                isNumeric = false
                break
            }
        }

        if (isNumeric && s.size > 0 && s.size < 11 && intValue < 4294967295) {
            return Index(UInt32(intValue))
        }

        return Name(s)
    }

    /// 获取名称（如果是命名列）
    public func name(): ?String {
        match (this) {
            case Name(s) => Some(s)
            case _ => None
        }
    }

    /// 获取索引（如果是数字索引列）
    public func index(): ?UInt32 {
        match (this) {
            case Index(i) => Some(i)
            case _ => None
        }
    }
}
