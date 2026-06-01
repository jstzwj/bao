// PostgreSQL DataCell - simplified stub
package bao_runtime.sql.postgresql
import bao_core.*
import bao_runtime.sql.shared.*

/// SQL Data Cell
public class SQLDataCell {
    public var tag: Int32 = 0
    public init() {}
    public static func nullCell(): SQLDataCell { SQLDataCell() }
    public static func fromInt32(v: Int32): SQLDataCell { SQLDataCell() }
    public static func fromInt64(v: Int64): SQLDataCell { SQLDataCell() }
    public static func fromFloat64(v: Float64): SQLDataCell { SQLDataCell() }
    public static func fromString(s: String): SQLDataCell { SQLDataCell() }
    public static func fromBool(b: Bool): SQLDataCell { SQLDataCell() }
    public static func fromBytea(b: Array<UInt8>): SQLDataCell { SQLDataCell() }
    public static func fromJson(s: String): SQLDataCell { SQLDataCell() }
    public static func fromDate(v: Int64): SQLDataCell { SQLDataCell() }
    public static func fromDateWithTimeZone(v: Int64): SQLDataCell { SQLDataCell() }
}
