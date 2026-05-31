// SQL 共享列标识符
// 严格翻译自: src/sql/shared/ColumnIdentifier.zig
package bao_runtime.sql.shared

import bao_core.*

/// SQL 列标识符类型
/// 对应 Bun: ColumnIdentifier (union enum) 的标签
public enum ColumnIdType {
    | name       // 按名称
    | index      // 按索引
    | duplicate  // 重复列

    public operator func ==(right: ColumnIdType): Bool {
        match (this) {
            case name => match (right) { case name => true case _ => false }
            case index => match (right) { case index => true case _ => false }
            case duplicate => match (right) { case duplicate => true case _ => false }
        }
    }

    public operator func !=(right: ColumnIdType): Bool {
        !(this == right)
    }
}

/// SQL 列标识符
/// 对应 Bun: ColumnIdentifier (union enum)
/// 列可以通过名称引用，也可以通过索引引用
public class ColumnIdentifier {
    /// 标识符类型
    public var idType: ColumnIdType
    /// 列名 (当 idType == name)
    public var name: SQLData
    /// 列索引 (当 idType == index)
    public var index: UInt32

    public init() {
        idType = ColumnIdType.name
        name = SQLData.empty()
        index = 0
    }

    /// 从名称初始化
    /// 对应 Bun: ColumnIdentifier.init
    /// 检测名称是否实际是数字索引
    public static func fromName(name: SQLData): ColumnIdentifier {
        let slice = name.slice()
        let len = slice.size

        if (len == 0) {
            let id = ColumnIdentifier()
            id.idType = ColumnIdType.name
            id.name = SQLData.empty()
            return id
        }

        // 尝试解析为整数索引
        var mightBeInt = true
        var intVal: UInt64 = 0
        for (byte in slice) {
            let digit0: UInt8 = 48  // '0' 的 ASCII 值
            let digit9: UInt8 = 57  // '9' 的 ASCII 值
            if (byte >= digit0 && byte <= digit9) {
                intVal = intVal * 10 + UInt64(Int64(byte) - Int64(digit0))
            } else {
                mightBeInt = false
                break
            }
        }

        if (mightBeInt && len >= 1 && intVal < UInt64(UInt32.Max)) {
            let id = ColumnIdentifier()
            id.idType = ColumnIdType.index
            id.index = UInt32(intVal)
            return id
        }

        let id = ColumnIdentifier()
        id.idType = ColumnIdType.name
        id.name = name.toOwned()
        return id
    }

    /// 从索引初始化
    public static func fromIndex(index: UInt32): ColumnIdentifier {
        let id = ColumnIdentifier()
        id.idType = ColumnIdType.index
        id.index = index
        return id
    }

    /// 释放资源
    /// 对应 Bun: ColumnIdentifier.deinit
    public func deinit(): Unit {
        if (idType == ColumnIdType.name) {
            name.deinit()
        }
    }
}
