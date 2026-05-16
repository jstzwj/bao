// 严格翻译自: src/sql/postgres/protocol/SASLResponse.zig
// PostgreSQL SASLResponse 消息
package bao_sql.postgres.protocol

import bao_sql.shared.Data
import bao_sql.postgres.types.IntTypes

/// PostgreSQL SASLResponse 消息
/// 对应 Bun: SASLResponse
public class SASLResponse {
    public var data: Data

    public init(data: Data) {
        this.data = data
    }

    /// 释放资源
    /// 对应 Bun: SASLResponse.deinit
    public func deinit(): Unit {
        // Cangjie has GC, no manual deinit needed
    }

    /// 写入 SASLResponse 消息
    /// 对应 Bun: SASLResponse.writeInternal
    public func writeTo(writer: ArrayListWriter): Unit {
        let dataSlice = data.slice()
        let count: UInt32 = 4 + UInt32(dataSlice.size)

        writer.write([UInt8(112)])
        writer.int4(count)
        writer.write(dataSlice)
    }
}
