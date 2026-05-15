// MySQL 认证切换响应
// 对应 Bun: src/sql/mysql/protocol/AuthSwitchResponse.zig
package bao_sql.mysql.protocol

/// MySQL 认证切换响应包
/// 对应 Bun: AuthSwitchResponse (struct)
///
/// 客户端在收到服务器的认证切换请求后，发送此包
/// 包含使用新认证方法计算的认证响应数据
public class AuthSwitchResponse {
    /// 认证响应数据
    /// 对应 Bun: auth_response Data
    public var authResponse: Array<UInt8>

    public init() {
        authResponse = Array<UInt8>()
    }

    public init(authResponse: Array<UInt8>) {
        this.authResponse = authResponse
    }

    /// 释放资源
    /// 对应 Bun: AuthSwitchResponse.deinit
    public func deinit(): Unit {
        authResponse = Array<UInt8>()
    }

    /// 将认证切换响应写入到写入器
    /// 对应 Bun: AuthSwitchResponse.writeInternal
    public func write(writer: MySQLPacketWriter): Unit {
        writer.write(authResponse)
    }
}
