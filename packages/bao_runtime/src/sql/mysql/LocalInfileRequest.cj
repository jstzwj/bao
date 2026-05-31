// MySQL LocalInfileRequest 协议包
// 严格翻译自: src/sql/mysql/protocol/LocalInfileRequest.zig
package bao_runtime.sql.mysql

import bao_core.*
import bao_runtime.sql.shared.*

/// MySQL LOCAL INFILE 请求包
/// 对应 Bun: LocalInfileRequest
/// 服务器请求客户端发送本地文件
public class LocalInfileRequest {
    /// 文件名
    public var filename: SQLData
    /// 包大小
    public var packetSize: UInt32

    public init() {
        filename = SQLData.empty()
        packetSize = 0
    }

    /// 释放资源
    /// 对应 Bun: LocalInfileRequest.deinit
    public func deinit(): Unit {
        filename.deinit()
    }

    /// 从 Reader 解码
    /// 对应 Bun: LocalInfileRequest.decodeInternal
    public func decode(reader: MySQLPacketReader): Unit {
        let header = reader.readInt8()
        if (header != 0xFB) {
            return  // InvalidLocalInfileRequest
        }

        filename = reader.readBytes(Int64(packetSize) - 1)
    }
}
