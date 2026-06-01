// MySQL 值类型
// 严格翻译自: src/sql_jsc/mysql/MySQLValue.zig
// PORT NOTE: Cangjie enums cannot carry payloads. Simplified to a tagged class.
package bao_runtime.sql.mysql

import bao_core.*
import bao_runtime.sql.shared.*

/// MySQL 值数据 (simplified tagged union as class)
public class MySQLValueData {
    public var tag: Int32 = 0  // 0=null, 1=bool, 2=short, etc.
    public var boolVal: Bool = false
    public var intVal: Int64 = 0
    public var floatVal: Float64 = 0.0
    public var stringVal: Array<UInt8> = Array<UInt8>()

    public init() {}

    public static func nullValue(): MySQLValueData {
        let v = MySQLValueData()
        v.tag = 0
        return v
    }

    public static func fromBool(b: Bool): MySQLValueData {
        let v = MySQLValueData()
        v.tag = 1
        v.boolVal = b
        return v
    }

    public static func fromInt(i: Int64): MySQLValueData {
        let v = MySQLValueData()
        v.tag = 6
        v.intVal = i
        return v
    }

    public static func fromFloat(f: Float64): MySQLValueData {
        let v = MySQLValueData()
        v.tag = 9
        v.floatVal = f
        return v
    }

    public static func fromString(s: Array<UInt8>): MySQLValueData {
        let v = MySQLValueData()
        v.tag = 10
        v.stringVal = s
        return v
    }

    public func isNull(): Bool {
        return tag == 0
    }
}
