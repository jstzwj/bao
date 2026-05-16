// MySQL 本地文件加载请求
// 对应 Bun: src/sql/mysql/protocol/LocalInfileRequest.zig
package bao_sql.mysql.protocol

/// MySQL 本地文件加载请求包
/// 对应 Bun: LocalInfileRequest (struct)
///
/// 服务器发送此包请求客户端发送本地文件内容
public class LocalInfileRequest {
    /// 文件名
    /// 对应 Bun: filename Data
    public var filename: Array<UInt8>

    /// 包大小
    /// 对应 Bun: packet_size u24
    public var packetSize: UInt32

    public init() {
        filename = Array<UInt8>()
        packetSize = 0
    }

    public init(packetSize: UInt32) {
        filename = Array<UInt8>()
        this.packetSize = packetSize
    }

    /// 释放资源
    /// 对应 Bun: LocalInfileRequest.deinit
    public func deinit(): Unit {
        filename = Array<UInt8>()
    }

    /// 从读取器解码本地文件请求
    /// 对应 Bun: LocalInfileRequest.decodeInternal
    public func decode(reader: MySQLPacketReader): Unit {
        let header = reader.int8()
        if (header != 0xfb) {
            throw MySQLProtocolException("InvalidLocalInfileRequest")
        }

        filename = reader.read(Int64(packetSize) - 1)
    }
}
