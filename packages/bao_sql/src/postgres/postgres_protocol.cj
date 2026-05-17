// 严格翻译自: src/sql/postgres/PostgresProtocol.zig
// PostgreSQL 协议常量和消息类型汇总
package bao_sql.postgres

import bao_sql.postgres.types.IntTypes
import bao_collections.*

/// PostgreSQL 协议常量和消息类型汇总
/// 对应 Bun: PostgresProtocol
public class PostgresProtocol {
    // 固定消息常量
    // ASCII values: '3'=0x33, 'I'=0x49, 'X'=0x58, '2'=0x32, '1'=0x31
    //               'c'=0x63, 'S'=0x53, 'H'=0x48, 'n'=0x6e, 'Q'=0x51

    /// CloseComplete: '3' + Int32(4)
    public static let CloseComplete: Array<UInt8> = [0x33, 0, 0, 0, 4]

    /// EmptyQueryResponse: 'I' + Int32(4)
    public static let EmptyQueryResponse: Array<UInt8> = [0x49, 0, 0, 0, 4]

    /// Terminate: 'X' + Int32(4)
    public static let Terminate: Array<UInt8> = [0x58, 0, 0, 0, 4]

    /// BindComplete: '2' + Int32(4)
    public static let BindComplete: Array<UInt8> = [0x32, 0, 0, 0, 4]

    /// ParseComplete: '1' + Int32(4)
    public static let ParseComplete: Array<UInt8> = [0x31, 0, 0, 0, 4]

    /// CopyDone: 'c' + Int32(4)
    public static let CopyDone: Array<UInt8> = [0x63, 0, 0, 0, 4]

    /// Sync: 'S' + Int32(4)
    public static let Sync: Array<UInt8> = [0x53, 0, 0, 0, 4]

    /// Flush: 'H' + Int32(4)
    public static let Flush: Array<UInt8> = [0x48, 0, 0, 0, 4]

    /// SSLRequest: Int32(8) + Int32(80877103)
    public static let SSLRequest: Array<UInt8> = [0, 0, 0, 8, 4, 210, 119, 47]

    /// NoData: 'n' + Int32(4)
    public static let NoData: Array<UInt8> = [0x6e, 0, 0, 0, 4]

    /// 构建查询消息字节
    /// 对应 Bun: PostgresProtocol.writeQuery
    public static func buildQueryBytes(query: String): Array<UInt8> {
        let count: UInt32 = 4 + UInt32(query.size) + 1
        let result = ArrayList<UInt8>()
        result.append(0x51) // 'Q'
        let countBytes = IntTypes.int32(count)
        result.append(countBytes[0])
        result.append(countBytes[1])
        result.append(countBytes[2])
        result.append(countBytes[3])
        for (b in query) {
            result.append(b)
        }
        result.append(UInt8(0))
        return result.toOwnedSlice()
    }
}
