// PostgreSQL 客户端消息写入器
// 严格翻译自多个 Bun 源文件:
//   - StartupMessage.zig
//   - PasswordMessage.zig
//   - SASLInitialResponse.zig
//   - SASLResponse.zig
//   - Parse.zig
//   - Describe.zig
//   - Execute.zig
//   - Close.zig
//   - PostgresProtocol.zig (writeQuery)
package bao_runtime.sql.postgresql

import bao_runtime.sql.shared.*

/// PostgreSQL 客户端消息写入器
/// 提供构建各种客户端消息的静态方法
/// 对应 Bun 中的各种 writeInternal 方法
public class ClientMessageWriter {

    // ========================================================================
    // StartupMessage - 启动消息
    // 严格翻译自: bun/src/sql/postgres/protocol/StartupMessage.zig
    // 格式: Int32(length) + Int32(196608) + "user\0" + user + "\0" +
    //       "database\0" + database + "\0" + "client_encoding\0UTF8\0" + "\0"
    // ========================================================================

    /// 写入启动消息
    /// 对应 Bun StartupMessage.writeInternal()
    public static func writeStartupMessage(
        writer: ProtocolWriter,
        user: String,
        database: String,
        options: String
    ): Unit {
        // 计算长度
        let userLen = user.size + 1  // string + null
        let dbLen = (if (database.size == 0) user.size else database.size) + 1
        let totalLen = 4 + 4 +  // length + protocol version
            5 + userLen +       // "user\0" + user + "\0"
            9 + dbLen +         // "database\0" + db + "\0"
            16 +                // "client_encoding\0UTF8\0"
            options.size + 1    // options + null terminator

        // 写入长度
        writer.writeInt4(UInt32(totalLen))
        // 写入协议版本号 3.0 (196608)
        writer.writeInt4(196608)

        // 写入 user
        writer.writeString("user")
        if (user.size > 0) {
            writer.writeString(user)
        } else {
            writer.writeByte(0)
        }

        // 写入 database（如果为空则使用 user 名）
        writer.writeString("database")
        if (database.size == 0) {
            writer.writeString(user)
        } else {
            writer.writeString(database)
        }

        // 写入 client_encoding
        writer.writeString("client_encoding")
        writer.writeString("UTF8")

        // 写入 options
        if (options.size > 0) {
            let optBytes = options.toArray().map({ c => UInt8(c) })
            writer.write(optBytes)
        }
        writer.writeByte(0)  // 最终终止符
    }

    // ========================================================================
    // PasswordMessage - 密码消息
    // 严格翻译自: bun/src/sql/postgres/protocol/PasswordMessage.zig
    // 格式: 'p' + Int32(length) + password + "\0"
    // ========================================================================

    /// 写入密码消息
    /// 对应 Bun PasswordMessage.writeInternal()
    public static func writePasswordMessage(
        writer: ProtocolWriter,
        password: String
    ): Unit {
        let pwdBytes = password.toArray().map({ c => UInt8(c) })
        let count = 4 + pwdBytes.size + 1

        // 消息类型 'p'
        writer.writeByte(112)  // 'p'
        // 长度
        writer.writeInt4(UInt32(count))
        // 密码
        writer.writeString(password)
    }

    // ========================================================================
    // SASLInitialResponse - SASL 初始响应
    // 严格翻译自: bun/src/sql/postgres/protocol/SASLInitialResponse.zig
    // 格式: 'p' + Int32(length) + mechanism + "\0" + Int32(dataLen) + data
    // ========================================================================

    /// 写入 SASL 初始响应
    /// 对应 Bun SASLInitialResponse.writeInternal()
    public static func writeSASLInitialResponse(
        writer: ProtocolWriter,
        mechanism: String,
        data: String
    ): Unit {
        let mechBytes = mechanism.toArray().map({ c => UInt8(c) })
        let dataBytes = data.toArray().map({ c => UInt8(c) })
        let count = 4 + mechBytes.size + 1 + dataBytes.size + 4

        writer.writeByte(112)  // 'p'
        writer.writeInt4(UInt32(count))
        writer.writeString(mechanism)
        writer.writeInt4(UInt32(dataBytes.size))
        writer.write(dataBytes)
    }

    // ========================================================================
    // SASLResponse - SASL 响应
    // 严格翻译自: bun/src/sql/postgres/protocol/SASLResponse.zig
    // 格式: 'p' + Int32(length) + data
    // ========================================================================

    /// 写入 SASL 响应
    /// 对应 Bun SASLResponse.writeInternal()
    public static func writeSASLResponse(
        writer: ProtocolWriter,
        data: String
    ): Unit {
        let dataBytes = data.toArray().map({ c => UInt8(c) })
        let count = 4 + dataBytes.size

        writer.writeByte(112)  // 'p'
        writer.writeInt4(UInt32(count))
        writer.write(dataBytes)
    }

    // ========================================================================
    // Query - 简单查询
    // 严格翻译自: bun/src/sql/postgres/PostgresProtocol.zig - writeQuery
    // 格式: 'Q' + Int32(length) + query + "\0"
    // ========================================================================

    /// 写入简单查询消息
    /// 对应 Bun writeQuery()
    public static func writeQuery(
        writer: ProtocolWriter,
        query: String
    ): Unit {
        let queryBytes = query.toArray().map({ c => UInt8(c) })
        let count = 4 + queryBytes.size + 1

        writer.writeByte(81)  // 'Q'
        writer.writeInt4(UInt32(count))
        writer.writeString(query)
    }

    // ========================================================================
    // Parse - 解析消息
    // 严格翻译自: bun/src/sql/postgres/protocol/Parse.zig
    // 格式: 'P' + Int32(length) + name + "\0" + query + "\0" + Int16(paramCount) + [Int32(oid)...]
    // ========================================================================

    /// 写入解析消息
    /// 对应 Bun Parse.writeInternal()
    public static func writeParse(
        writer: ProtocolWriter,
        name: String,
        query: String,
        paramTypes: Array<UInt32>
    ): Unit {
        let nameBytes = name.toArray().map({ c => UInt8(c) })
        let queryBytes = query.toArray().map({ c => UInt8(c) })
        let nameLen = if (name.size > 0) name.size + 1 else 1
        let queryLen = if (query.size > 0) query.size + 1 else 1
        let count = 4 + 2 + nameLen + queryLen + paramTypes.size * 4

        writer.writeByte(80)  // 'P'
        writer.writeInt4(UInt32(count))
        writer.writeString(name)
        writer.writeString(query)
        writer.writeShort(UInt16(paramTypes.size))
        for (oid in paramTypes) {
            writer.writeInt4(oid)
        }
    }

    // ========================================================================
    // Describe - 描述消息
    // 严格翻译自: bun/src/sql/postgres/protocol/Describe.zig
    // 格式: 'D' + Int32(length) + 'S'|'P' + name + "\0"
    // ========================================================================

    /// 写入描述消息
    /// 对应 Bun Describe.writeInternal()
    /// isStatement: true 表示预处理语句，false 表示 Portal
    public static func writeDescribe(
        writer: ProtocolWriter,
        name: String,
        isStatement: Bool
    ): Unit {
        writer.writeByte(68)  // 'D'
        let lengthPlaceholder = writer.writeLengthPlaceholder()
        // 'S' = 预处理语句, 'P' = Portal
        if (isStatement) {
            writer.writeByte(83)  // 'S'
        } else {
            writer.writeByte(80)  // 'P'
        }
        writer.writeString(name)
        lengthPlaceholder.write()
    }

    // ========================================================================
    // Bind - 绑定消息
    // 格式: 'B' + Int32(length) + portalName + "\0" + stmtName + "\0" +
    //        Int16(numFormatCodes) + [Int16(formatCode)...] +
    //        Int16(numParams) + [Int32(paramLen) + paramBytes...] +
    //        Int16(numResultFormatCodes) + [Int16(formatCode)...]
    // ========================================================================

    /// 写入绑定消息
    public static func writeBind(
        writer: ProtocolWriter,
        portalName: String,
        statementName: String,
        params: Array<?Array<UInt8>>,
        paramFormatCodes: Array<UInt16>,
        resultFormatCodes: Array<UInt16>
    ): Unit {
        writer.writeByte(66)  // 'B'
        let lengthPlaceholder = writer.writeLengthPlaceholder()

        // Portal 名称（空字符串使用默认 portal）
        writer.writeString(portalName)
        // 语句名称
        writer.writeString(statementName)

        // 参数格式代码
        writer.writeShort(UInt16(paramFormatCodes.size))
        for (code in paramFormatCodes) {
            writer.writeShort(code)
        }

        // 参数值
        writer.writeShort(UInt16(params.size))
        for (param in params) {
            match (param) {
                case Some(bytes) => {
                    writer.writeInt4(UInt32(bytes.size))
                    writer.write(bytes)
                }
                case None => {
                    writer.writeNull()  // -1 表示 NULL
                }
            }
        }

        // 结果格式代码
        writer.writeShort(UInt16(resultFormatCodes.size))
        for (code in resultFormatCodes) {
            writer.writeShort(code)
        }

        lengthPlaceholder.write()
    }

    // ========================================================================
    // Execute - 执行消息
    // 严格翻译自: bun/src/sql/postgres/protocol/Execute.zig
    // 格式: 'E' + Int32(length) + portalName + "\0" + Int32(maxRows)
    // ========================================================================

    /// 写入执行消息
    /// 对应 Bun Execute.writeInternal()
    public static func writeExecute(
        writer: ProtocolWriter,
        portalName: String,
        maxRows: UInt32
    ): Unit {
        writer.writeByte(69)  // 'E'
        let lengthPlaceholder = writer.writeLengthPlaceholder()
        if (portalName.size > 0) {
            writer.writeString(portalName)
        } else {
            writer.writeByte(0)
        }
        writer.writeInt4(maxRows)
        lengthPlaceholder.write()
    }

    // ========================================================================
    // Close - 关闭消息
    // 严格翻译自: bun/src/sql/postgres/protocol/Close.zig
    // 格式: 'C' + Int32(length) + 'S'|'P' + name + "\0"
    // ========================================================================

    /// 写入关闭消息
    /// 对应 Bun Close.writeInternal()
    public static func writeClose(
        writer: ProtocolWriter,
        name: String,
        isStatement: Bool
    ): Unit {
        let nameBytes = name.toArray().map({ c => UInt8(c) })
        let count = 4 + 1 + nameBytes.size + 1

        writer.writeByte(67)  // 'C'
        writer.writeInt4(UInt32(count))
        if (isStatement) {
            writer.writeByte(83)  // 'S'
        } else {
            writer.writeByte(80)  // 'P'
        }
        writer.write(nameBytes)
        writer.writeByte(0)
    }

    // ========================================================================
    // CopyFail - COPY 失败
    // 严格翻译自: bun/src/sql/postgres/protocol/CopyFail.zig
    // 格式: 'f' + Int32(length) + message + "\0"
    // ========================================================================

    /// 写入 COPY 失败消息
    public static func writeCopyFail(
        writer: ProtocolWriter,
        message: String
    ): Unit {
        let msgBytes = message.toArray().map({ c => UInt8(c) })
        let count = 4 + msgBytes.size + 1

        writer.writeByte(102)  // 'f'
        writer.writeInt4(UInt32(count))
        writer.writeString(message)
    }

    // ========================================================================
    // CopyData - COPY 数据
    // 格式: 'd' + Int32(length) + data
    // ========================================================================

    /// 写入 COPY 数据消息
    public static func writeCopyData(
        writer: ProtocolWriter,
        data: Array<UInt8>
    ): Unit {
        let count = 4 + data.size + 1

        writer.writeByte(100)  // 'd'
        writer.writeInt4(UInt32(count))
        writer.write(data)
        writer.writeByte(0)
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 写入字符串为字节（UTF-8）
    public static func stringToBytes(s: String): Array<UInt8> {
        s.toArray().map({ c => UInt8(c) })
    }

    /// 计算带 null 终止符的字符串长度
    /// 对应 Bun zHelpers.zCount()
    public static func zCount(s: String): Int64 {
        if (s.size > 0) {
            s.size + 1
        } else {
            0
        }
    }

    /// 计算字段对的总长度
    /// 对应 Bun zHelpers.zFieldCount()
    public static func zFieldCount(prefix: String, value: String): Int64 {
        if (value.size > 0) {
            zCount(prefix) + zCount(value)
        } else {
            zCount(prefix)
        }
    }
}
