// 严格翻译自: src/sql/shared/ColumnIdentifier.zig
// 列标识符 - 可以是名称、索引或重复
package bao_sql.shared

/// 列标识符种类
public enum ColumnIdentifierKind {
    | nameKind
    | indexKind
    | duplicateKind
}

/// 列标识符
/// JSC 将数字属性名视为索引，因此需要区分名称和索引
/// 对应 Bun: ColumnIdentifier (union enum)
public class ColumnIdentifier {
    /// 标识符种类
    public var kind: ColumnIdentifierKind

    /// 名称数据 (当 kind == nameKind 时有效)
    public var nameData: Data

    /// 索引值 (当 kind == indexKind 时有效)
    public var indexValue: UInt32

    public init() {
        kind = ColumnIdentifierKind.duplicateKind
        nameData = Data.emptyData()
        indexValue = 0
    }

    /// 创建名称类型的标识符
    public static func fromName(name: Data): ColumnIdentifier {
        return ColumnIdentifier(ColumnIdentifierKind.nameKind, name, 0)
    }

    /// 创建索引类型的标识符
    public static func fromIndex(index: UInt32): ColumnIdentifier {
        return ColumnIdentifier(ColumnIdentifierKind.indexKind, Data.emptyData(), index)
    }

    /// 创建重复类型的标识符
    public static func duplicate(): ColumnIdentifier {
        return ColumnIdentifier(ColumnIdentifierKind.duplicateKind, Data.emptyData(), 0)
    }

    public init(kind: ColumnIdentifierKind, nameData: Data, indexValue: UInt32) {
        this.kind = kind
        this.nameData = nameData
        this.indexValue = indexValue
    }

    /// 从名称数据初始化列标识符
    /// 如果名称是纯数字字符串，解析为索引
    /// 对应 Bun: ColumnIdentifier.init
    public static func initIdentifier(name: Data): ColumnIdentifier {
        let slice = name.slice()
        let len = slice.size

        if (len == 0) {
            return ColumnIdentifier.fromName(Data.emptyData())
        }

        // 尝试将名称解析为整数
        var intValue: UInt64 = 0
        var isInteger = true
        for (i in 0..len) {
            let byte = slice[i]
            if (byte >= 0x30 && byte <= 0x39) {
                intValue = intValue * 10 + UInt64(byte - 0x30)
            } else {
                isInteger = false
                break
            }
        }

        // JSC 仅支持到 2^32 的索引属性名
        if (isInteger && intValue < 4294967295) {
            return ColumnIdentifier.fromIndex(UInt32(intValue))
        }

        return ColumnIdentifier.fromName(name.toOwned())
    }

    /// 释放资源
    /// 对应 Bun: ColumnIdentifier.deinit
    public func release(): Unit {
        nameData.release()
    }
}
