// 严格翻译自: src/sql_jsc/mysql/protocol/error_packet_jsc.zig
// MySQL 错误包到 JS 错误的转换

package bao_sql_jsc.mysql.protocol

import bao_core.*
import bao_jsc.*
import bao_sql_jsc.mysql.*

/// MySQL 错误选项
/// 对应 Bun: ErrorPacket.MySQLErrorOptions
public class MySQLErrorOptions {
    public var code: String = ""
    public var errno: ?UInt16 = None
    public var sqlState: ?String = None

    public init() {}
}

/// 创建 MySQL 错误 JS 对象
/// 对应 Bun: createMySQLError
public func createMySQLErrorFromPacket(globalObject: JscJSGlobalObject,
                                        message: String,
                                        options: MySQLErrorOptions): JscValue {
    let optsObj = JscValue.createEmptyObject(globalObject.globalThis)
    optsObj.put(globalObject.globalThis, "code", JscValue(options.code))
    if (options.errno.isSome()) {
        optsObj.put(globalObject.globalThis, "errno", JscValue(Int64(options.errno.getOrThrow())))
    }
    if (options.sqlState.isSome()) {
        optsObj.put(globalObject.globalThis, "sqlState", JscValue(options.sqlState.getOrThrow()))
    }
    optsObj.put(globalObject.globalThis, "message", JscValue(message))
    return optsObj
}

/// ErrorPacket 转 JS 错误对象
/// 对应 Bun: ErrorPacket.toJS
public func errorPacketToJS(errorPacket: ErrorPacket,
                              globalObject: JscJSGlobalObject): JscValue {
    var msg = errorPacket.errorMessage
    if (msg.size == 0) {
        msg = "MySQL error occurred"
    }

    let code = if (errorPacket.errorCode == 1064) { "ERR_MYSQL_SYNTAX_ERROR" }
               else { "ERR_MYSQL_SERVER_ERROR" }

    let options = MySQLErrorOptions()
    options.code = code
    options.errno = errorPacket.errorCode
    options.sqlState = if (errorPacket.sqlState.size > 0) { errorPacket.sqlState } else { None }

    return createMySQLErrorFromPacket(globalObject, msg, options)
}
