// MySQL 错误类型定义
// 对应 Bun: src/sql/mysql/protocol/AnyMySQLError.zig
package bao_sql.mysql.protocol

/// MySQL 错误枚举
/// 对应 Bun: AnyMySQLError.Error (error set)
///
/// 定义了 MySQL 协议层所有可能的错误类型
public enum MySQLError {
    // 连接错误
    | ConnectionClosed                    // 连接已关闭
    | ConnectionTimedOut                  // 连接超时
    | LifetimeTimeout                     // 生命周期超时
    | IdleTimeout                         // 空闲超时

    // 认证错误
    | PasswordRequired                   // 需要密码
    | MissingAuthData                    // 缺少认证数据
    | AuthenticationFailed               // 认证失败
    | FailedToEncryptPassword            // 加密密码失败
    | InvalidPublicKey                   // 无效公钥
    | UnsupportedAuthPlugin              // 不支持的认证插件
    | UnsupportedProtocolVersion         // 不支持的协议版本

    // 功能错误
    | LocalInfileNotSupported            // 不支持本地文件加载
    | JSError                            // JS 错误
    | JSTerminated                       // JS 已终止
    | OutOfMemory                        // 内存不足
    | Overflow                           // 溢出

    // 参数错误
    | WrongNumberOfParametersProvided    // 参数数量错误
    | UnsupportedColumnType              // 不支持的列类型

    // 协议解析错误
    | InvalidLocalInfileRequest          // 无效的本地文件请求
    | InvalidAuthSwitchRequest           // 无效的认证切换请求
    | InvalidQueryBinding                // 无效的查询绑定
    | InvalidResultRow                   // 无效的结果行
    | InvalidBinaryValue                 // 无效的二进制值
    | InvalidEncodedInteger              // 无效的编码整数
    | InvalidEncodedLength               // 无效的编码长度

    // 包解析错误
    | InvalidPrepareOKPacket             // 无效的 PrepareOK 包
    | InvalidOKPacket                    // 无效的 OK 包
    | InvalidEOFPacket                   // 无效的 EOF 包
    | InvalidErrorPacket                 // 无效的错误包
    | UnexpectedPacket                   // 意外的包
    | ShortRead                          // 读取不足
    | UnknownError                       // 未知错误
    | InvalidState                       // 无效状态
}
