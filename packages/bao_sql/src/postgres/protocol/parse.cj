// 严格翻译自: src/sql/postgres/protocol/Parse.zig
// PostgreSQL Parse 消息
package bao_sql.postgres.protocol

import bao_sql.postgres.types.IntTypes

/// PostgreSQL Parse 消息
/// 对应 Bun: Parse
public class Parse {
    public var name: String
    public var query: String
    public var params: Array<UInt32>

    public init(name: String, query: String, params: Array<UInt32>) {
        this.name = name
        this.query = query
        this.params = params
    }

    /// 释放资源
    /// 对应 Bun: Parse.deinit
    public func deinit(): Unit {
        // 无需释放
    }

    /// 写入 Parse 消息
    /// 对应 Bun: Parse.writeInternal
    public func writeTo(writer: ArrayListWriter): ?AnyPostgresError {
        let parameters = params
        if (parameters.size > 65535) {
            return AnyPostgresError.TooManyParameters
        }

        let nameZCount = ZHelpers.zCount(name)
        let queryZCount = ZHelpers.zCount(query)
        let nameSize: UInt32 = if (nameZCount > 0) { UInt32(nameZCount) } else { UInt32(1) }
        let querySize: UInt32 = if (queryZCount > 0) { UInt32(queryZCount) } else { UInt32(1) }
        let count: UInt32 = 4 + 2 + UInt32(parameters.size) * 4 + nameSize + querySize

        writer.write([UInt8(80)])
        writer.int4(count)
        writer.string(name)
        writer.string(query)
        writer.short(UInt16(parameters.size))
        for (i in 0..parameters.size) {
            writer.int4(parameters[Int64(i)])
        }

        return None
    }
}
