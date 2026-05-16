// 严格翻译自: src/sql/postgres/protocol/SASLInitialResponse.zig
// PostgreSQL SASLInitialResponse 消息
package bao_sql.postgres.protocol

import bao_sql.shared.Data
import bao_sql.postgres.types.IntTypes

/// PostgreSQL SASLInitialResponse 消息
/// 对应 Bun: SASLInitialResponse
public class SASLInitialResponse {
    public var mechanism: Data
    public var data: Data

    public init(mechanism: Data, data: Data) {
        this.mechanism = mechanism
        this.data = data
    }

    /// 释放资源
    /// 对应 Bun: SASLInitialResponse.deinit
    public func deinit(): Unit {
        // Cangjie has GC, no manual deinit needed
    }

    /// 写入 SASLInitialResponse 消息
    /// 对应 Bun: SASLInitialResponse.writeInternal
    public func writeTo(writer: ArrayListWriter): Unit {
        let mechanismSlice = mechanism.slice()
        let dataSlice = data.slice()
        let count: UInt32 = 4 + UInt32(mechanismSlice.size) + 1 + UInt32(dataSlice.size) + 4

        writer.write([UInt8(112)])
        writer.int4(count)
        writer.string(String.fromUtf8(mechanismSlice))
        writer.int4(UInt32(dataSlice.size))
        writer.write(dataSlice)
    }
}
