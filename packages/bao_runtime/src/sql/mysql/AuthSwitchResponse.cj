// MySQL AuthSwitchResponse 协议包
// 严格翻译自: src/sql/mysql/protocol/AuthSwitchResponse.zig
package bao_runtime.sql.mysql

import bao_core.*
import bao_runtime.sql.shared.*

/// MySQL 认证切换响应包
/// 对应 Bun: AuthSwitchResponse
/// 客户端发送此包以响应 AuthSwitchRequest
public class AuthSwitchResponse {
    /// 认证响应数据 (如 scramble 密码)
    public var authResponse: SQLData

    public init() {
        authResponse = SQLData.empty()
    }

    /// 释放资源
    /// 对应 Bun: AuthSwitchResponse.deinit
    public func deinit(): Unit {
        authResponse.deinit()
    }

    /// 编码到 Writer
    /// 对应 Bun: AuthSwitchResponse.writeInternal
    public func write(writer: MySQLPacketWriter): Unit {
        writer.writeBytes(authResponse.slice())
    }
}
