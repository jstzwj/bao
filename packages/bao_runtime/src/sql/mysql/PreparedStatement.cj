// MySQL PreparedStatement - simplified stub
package bao_runtime.sql.mysql

import bao_core.*

/// MySQL 预编译语句
public class PreparedStatement {
    public var statementId: Array<UInt8> = Array<UInt8>(4, { _ => UInt8(0) })
    public var columnCount: Int64 = 0
    public var paramCount: Int64 = 0

    public init() {}
}
