// MySQL SSLRequest 协议包
// 严格翻译自: src/sql/mysql/protocol/SSLRequest.zig
package bao_runtime.sql.mysql

import bao_core.*
import bao_sql.mysql.protocol.*

/// MySQL SSL 请求包
/// 对应 Bun: SSLRequest
/// 在发送 HandshakeResponse41 之前，如果需要 SSL，客户端先发送此包
/// 参考: https://dev.mysql.com/doc/dev/mysql-server/8.4.6/page_protocol_connection_phase_packets_protocol_ssl_request.html
public class SSLRequest {
    /// 客户端能力标志
    public var capabilityFlags: Capabilities
    /// 最大包大小
    public var maxPacketSize: UInt32
    /// 字符集
    public var characterSet: CharacterSet
    /// 是否有连接属性
    public var hasConnectionAttributes: Bool

    public init() {
        capabilityFlags = Capabilities()
        maxPacketSize = 0xFFFFFF
        characterSet = CharacterSet.Unknown
        hasConnectionAttributes = false
    }

    /// 编码到 Writer
    /// 对应 Bun: SSLRequest.writeInternal
    public func write(writer: MySQLPacketWriter): Unit {
        writer.start(1)  // SSLRequest 序列号固定为 1

        capabilityFlags.CLIENT_CONNECT_ATTRS = hasConnectionAttributes

        // 写入客户端能力标志 (4 字节)
        let caps = capabilityFlags.toInt()
        writer.writeInt32(caps)

        // 写入最大包大小 (4 字节)
        writer.writeInt32(maxPacketSize)

        // 写入字符集 (1 字节)
        writer.writeInt8(0)  // characterSet value placeholder

        // 写入 23 字节填充
        writer.writeZeros(23)

        writer.endPacket()
    }
}
