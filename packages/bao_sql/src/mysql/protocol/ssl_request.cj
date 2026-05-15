// MySQL SSL 请求包
// 对应 Bun: src/sql/mysql/protocol/SSLRequest.zig
package bao_sql.mysql.protocol

/// MySQL SSL 连接请求包
/// 对应 Bun: SSLRequest (struct)
///
/// 参考: https://dev.mysql.com/doc/dev/mysql-server/8.4.6/page_protocol_connection_phase_packets_protocol_ssl_request.html
/// 客户端在握手过程中发送此包请求建立 SSL 加密连接
public class SSLRequest {
    /// 能力标志
    /// 对应 Bun: capability_flags Capabilities
    public var capabilityFlags: Capabilities

    /// 最大包大小 (默认 16MB)
    /// 对应 Bun: max_packet_size u32
    public var maxPacketSize: UInt32

    /// 字符集
    /// 对应 Bun: character_set CharacterSet
    public var characterSet: UInt8

    /// 是否有连接属性
    /// 对应 Bun: has_connection_attributes bool
    public var hasConnectionAttributes: Bool

    public init() {
        capabilityFlags = Capabilities()
        maxPacketSize = 0xFFFFFF // 16MB
        characterSet = 45 // utf8mb4_general_ci
        hasConnectionAttributes = false
    }

    public init(capabilityFlags: Capabilities, maxPacketSize: UInt32, characterSet: UInt8, hasConnectionAttributes: Bool) {
        this.capabilityFlags = capabilityFlags
        this.maxPacketSize = maxPacketSize
        this.characterSet = characterSet
        this.hasConnectionAttributes = hasConnectionAttributes
    }

    /// 释放资源 (无操作)
    /// 对应 Bun: SSLRequest.deinit (no-op)
    public func deinit(): Unit {
        // 无操作
    }

    /// 将 SSL 请求写入到写入器
    /// 对应 Bun: SSLRequest.writeInternal
    public func write(writer: MySQLPacketWriter): Unit {
        var packet = writer.start(1)

        capabilityFlags.CLIENT_CONNECT_ATTRS = hasConnectionAttributes

        // 写入客户端能力标志 (4 字节)
        let caps = capabilityFlags.toInt()
        writer.int4(caps)

        // 写入最大包大小 (4 字节)
        writer.int4(maxPacketSize)

        // 写入字符集 (1 字节)
        writer.int1(characterSet)

        // 写入 23 字节填充
        writer.write(Array<UInt8>(23))

        packet.end()
    }
}
