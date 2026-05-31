// PostgreSQL 协议消息类型 - 响应消息解码
// 严格翻译自多个 Bun 源文件:
//   - BackendKeyData.zig
//   - CommandComplete.zig
//   - ParameterStatus.zig
//   - ReadyForQuery.zig
//   - RowDescription.zig
//   - ErrorResponse.zig
//   - NoticeResponse.zig
//   - NotificationResponse.zig
//   - ParameterDescription.zig
//   - CopyData.zig
//   - CopyFail.zig
package bao_runtime.sql.postgresql

import bao_runtime.sql.shared.*

// ============================================================================
// BackendKeyData - 后端密钥数据
// 严格翻译自: bun/src/sql/postgres/protocol/BackendKeyData.zig
// ============================================================================

/// PostgreSQL 后端密钥数据
/// 在连接建立后由服务器发送，包含进程 ID 和密钥
/// 对应 Bun BackendKeyData
public class BackendKeyData {
    public var processId: UInt32
    public var secretKey: UInt32

    public init() {
        processId = 0
        secretKey = 0
    }

    /// 从读取器解码
    /// 对应 Bun BackendKeyData.decodeInternal()
    public func decode(reader: ProtocolReader): Bool {
        // 验证消息长度 = 12
        let len = reader.readUInt32()
        match (len) {
            case Some(12) => {}
            case _ => return false
        }

        let pid = reader.readUInt32()
        match (pid) {
            case None => return false
            case Some(v) => processId = v
        }

        let key = reader.readUInt32()
        match (key) {
            case None => return false
            case Some(v) => secretKey = v
        }

        return true
    }
}

// ============================================================================
// CommandComplete - 命令完成
// 严格翻译自: bun/src/sql/postgres/protocol/CommandComplete.zig
// ============================================================================

/// PostgreSQL 命令完成消息
/// 包含命令标签（如 "SELECT 5", "INSERT 0 1"）
/// 对应 Bun CommandComplete
public class CommandComplete {
    public var commandTag: SQLData

    public init() {
        commandTag = SQLData()
    }

    /// 从读取器解码
    /// 对应 Bun CommandComplete.decodeInternal()
    public func decode(reader: ProtocolReader): Bool {
        let _len = reader.readLength()
        match (_len) {
            case None => return false
            case Some(_)=> {}
        }

        let tag = reader.readNullTerminatedBytes()
        match (tag) {
            case None => return false
            case Some(bytes) => {
                commandTag = SQLData(temporary: bytes)
            }
        }
        return true
    }

    /// 获取命令标签字符串
    public func tagString(): String {
        let bytes = commandTag.slice()
        bytes.toArray().map({ b => Char.fromUInt8(b) }).toString()
    }

    /// 释放资源
    public func deinit() {
        commandTag.deinit()
    }
}

// ============================================================================
// ReadyForQuery - 准备好接收查询
// 严格翻译自: bun/src/sql/postgres/protocol/ReadyForQuery.zig
// ============================================================================

/// PostgreSQL 准备好接收查询消息
/// 包含事务状态指示器
/// 对应 Bun ReadyForQuery
public class ReadyForQuery {
    public var status: TransactionStatusIndicator

    public init() {
        status = TransactionStatusIndicator.Idle
    }

    /// 从读取器解码
    /// 对应 Bun ReadyForQuery.decodeInternal()
    public func decode(reader: ProtocolReader): Bool {
        let _len = reader.readLength()
        match (_len) {
            case None => return false
            case Some(_)=> {}
        }

        let statusByte = reader.readByte()
        match (statusByte) {
            case None => return false
            case Some(b) => {
                status = TransactionStatusIndicator.fromByte(b)
            }
        }
        return true
    }
}

// ============================================================================
// ParameterStatus - 参数状态
// 严格翻译自: bun/src/sql/postgres/protocol/ParameterStatus.zig
// ============================================================================

/// PostgreSQL 参数状态消息
/// 服务器在连接建立后发送运行时参数
/// 对应 Bun ParameterStatus
public class ParameterStatus {
    public var name: SQLData
    public var value: SQLData

    public init() {
        name = SQLData()
        value = SQLData()
    }

    /// 从读取器解码
    /// 对应 Bun ParameterStatus.decodeInternal()
    public func decode(reader: ProtocolReader): Bool {
        let _len = reader.readLength()
        match (_len) {
            case None => return false
            case Some(_)=> {}
        }

        let n = reader.readNullTerminatedBytes()
        match (n) {
            case None => return false
            case Some(bytes) => name = SQLData(temporary: bytes)
        }

        let v = reader.readNullTerminatedBytes()
        match (v) {
            case None => return false
            case Some(bytes) => value = SQLData(temporary: bytes)
        }
        return true
    }

    /// 获取参数名
    public func nameString(): String {
        let bytes = name.slice()
        bytes.toArray().map({ b => Char.fromUInt8(b) }).toString()
    }

    /// 获取参数值
    public func valueString(): String {
        let bytes = value.slice()
        bytes.toArray().map({ b => Char.fromUInt8(b) }).toString()
    }

    /// 释放资源
    public func deinit() {
        name.deinit()
        value.deinit()
    }
}

// ============================================================================
// RowDescription - 行描述
// 严格翻译自: bun/src/sql/postgres/protocol/RowDescription.zig
// ============================================================================

/// PostgreSQL 行描述消息
/// 描述查询结果的列信息
/// 对应 Bun RowDescription
public class RowDescription {
    public var fields: Array<FieldDescription>

    public init() {
        fields = Array<FieldDescription>()
    }

    /// 从读取器解码
    /// 对应 Bun RowDescription.decodeInternal()
    public func decode(reader: ProtocolReader): Bool {
        let _len = reader.readLength()
        match (_len) {
            case None => return false
            case Some(_)=> {}
        }

        // 读取字段数量 (2 字节)
        let fieldCount = reader.readUInt16()
        match (fieldCount) {
            case None => return false
            case Some(count) => {
                for (_ in 0..Int64(count)) {
                    let field = FieldDescription()
                    if (!field.decode(reader)) {
                        return false
                    }
                    fields.append(field)
                }
            }
        }
        return true
    }

    /// 释放资源
    public func deinit() {
        for (field in fields) {
            field.deinit()
        }
    }
}

// ============================================================================
// ErrorResponse - 错误响应
// 严格翻译自: bun/src/sql/postgres/protocol/ErrorResponse.zig
// ============================================================================

/// PostgreSQL 错误响应消息
/// 包含错误详情字段列表
/// 对应 Bun ErrorResponse
public class ErrorResponse {
    public var messages: Array<FieldMessage>

    public init() {
        messages = Array<FieldMessage>()
    }

    /// 从读取器解码
    /// 对应 Bun ErrorResponse.decodeInternal()
    public func decode(reader: ProtocolReader): Bool {
        let _len = reader.readLength()
        match (_len) {
            case None => return false
            case Some(_)=> {}
        }

        let list = FieldMessageDecoder.decodeList(reader)
        match (list) {
            case None => return false
            case Some(l) => messages = l
        }
        return true
    }

    /// 获取特定字段的值
    public func getField(type: FieldType): ?String {
        for (msg in messages) {
            if (msg.fieldType == type) {  // 简单的枚举比较
                return msg.value
            }
        }
        None
    }

    /// 获取错误代码
    public func code(): ?String {
        getField(FieldType.Code)
    }

    /// 获取错误消息
    public func message(): ?String {
        getField(FieldType.Message)
    }

    /// 获取严重程度
    public func severity(): ?String {
        getField(FieldType.Severity)
    }

    /// 获取详细信息
    public func detail(): ?String {
        getField(FieldType.Detail)
    }

    /// 格式化错误信息
    public func toString(): String {
        let parts = messages.map({ m => m.toString() })
        parts.join("\n")
    }

    /// 释放资源
    public func deinit() {
        for (msg in messages) {
            msg.deinit()
        }
    }
}

// ============================================================================
// NoticeResponse - 通知响应
// 严格翻译自: bun/src/sql/postgres/protocol/NoticeResponse.zig
// ============================================================================

/// PostgreSQL 通知响应消息
/// 结构与 ErrorResponse 相同，但用于警告/通知
/// 对应 Bun NoticeResponse
public class NoticeResponse {
    public var messages: Array<FieldMessage>

    public init() {
        messages = Array<FieldMessage>()
    }

    /// 从读取器解码
    /// 对应 Bun NoticeResponse.decodeInternal()
    public func decode(reader: ProtocolReader): Bool {
        let _len = reader.readLength()
        match (_len) {
            case None => return false
            case Some(_)=> {}
        }

        let list = FieldMessageDecoder.decodeList(reader)
        match (list) {
            case None => return false
            case Some(l) => messages = l
        }
        return true
    }

    /// 释放资源
    public func deinit() {
        for (msg in messages) {
            msg.deinit()
        }
    }
}

// ============================================================================
// NotificationResponse - 通知响应 (LISTEN/NOTIFY)
// 严格翻译自: bun/src/sql/postgres/protocol/NotificationResponse.zig
// ============================================================================

/// PostgreSQL LISTEN/NOTIFY 通知响应
/// 对应 Bun NotificationResponse
public class NotificationResponse {
    public var pid: UInt32
    public var channel: String
    public var payload: String

    public init() {
        pid = 0
        channel = ""
        payload = ""
    }

    /// 从读取器解码
    /// 对应 Bun NotificationResponse.decodeInternal()
    public func decode(reader: ProtocolReader): Bool {
        let _len = reader.readLength()
        match (_len) {
            case None => return false
            case Some(_)=> {}
        }

        let p = reader.readUInt32()
        match (p) {
            case None => return false
            case Some(v) => pid = v
        }

        let ch = reader.readNullTerminatedString()
        match (ch) {
            case None => return false
            case Some(v) => channel = v
        }

        let pl = reader.readNullTerminatedString()
        match (pl) {
            case None => return false
            case Some(v) => payload = v
        }

        return true
    }
}

// ============================================================================
// ParameterDescription - 参数描述
// 严格翻译自: bun/src/sql/postgres/protocol/ParameterDescription.zig
// ============================================================================

/// PostgreSQL 参数描述消息
/// 描述预处理语句的参数类型
/// 对应 Bun ParameterDescription
public class ParameterDescription {
    public var parameters: Array<UInt32>

    public init() {
        parameters = Array<UInt32>()
    }

    /// 从读取器解码
    /// 对应 Bun ParameterDescription.decodeInternal()
    public func decode(reader: ProtocolReader): Bool {
        let _len = reader.readLength()
        match (_len) {
            case None => return false
            case Some(_)=> {}
        }

        let count = reader.readUInt16()
        match (count) {
            case None => return false
            case Some(c) => {
                // 读取参数类型 OID 列表 (每个 4 字节，大端)
                let bytesNeeded = Int64(c) * 4
                match (reader.readBytes(bytesNeeded)) {
                    case None => return false
                    case Some(data) => {
                        for (i in 0..Int64(c)) {
                            let offset = i * 4
                            let oid = readUInt32BE(data, offset)
                            parameters.append(oid)
                        }
                    }
                }
            }
        }
        return true
    }
}

// ============================================================================
// DataRow - 数据行
// 严格翻译自: bun/src/sql/postgres/protocol/DataRow.zig
// ============================================================================

/// PostgreSQL 数据行消息
/// 每行数据包含各列的值（可能是 NULL）
/// 对应 Bun DataRow
public class DataRow {
    /// 列值列表，None 表示 NULL
    public var values: Array<?Array<UInt8>>

    public init(count: Int64) {
        values = Array<?Array<UInt8>>(count)
    }

    /// 从读取器解码
    /// 对应 Bun DataRow.decode()
    /// callback 参数: (index: UInt32, bytes: ?SQLData) -> 是否继续
    public static func decode(reader: ProtocolReader): ?DataRow {
        let _len = reader.readLength()
        match (_len) {
            case None => return None
            case Some(_)=> {}
        }

        // 读取字段数量
        let fieldCount = reader.readUInt16()
        match (fieldCount) {
            case None => return None
            case Some(count) => {
                let row = DataRow(Int64(count))
                for (i in 0..Int64(count)) {
                    // 读取列值长度 (4 字节)
                    let colLen = reader.readUInt32()
                    match (colLen) {
                        case None => return None
                        case Some(len) => {
                            if (len == 0) {
                                // 空值 (长度为 0)
                                row.values.append(Some(Array<UInt8>()))
                            } else if (len == UInt32(NULL_INT4)) {
                                // NULL 标记 (-1)
                                row.values.append(None)
                            } else {
                                // 读取列数据
                                match (reader.readBytes(Int64(len))) {
                                    case None => return None
                                    case Some(bytes) => row.values.append(Some(bytes))
                                }
                            }
                        }
                    }
                }
                return row
            }
        }
    }

    /// 获取指定列的值
    public func get(index: Int64): ?Array<UInt8> {
        if (index >= 0 && index < values.size) {
            values[index]
        } else {
            None
        }
    }

    /// 获取指定列的值作为字符串
    public func getString(index: Int64): ?String {
        match (get(index)) {
            case Some(bytes) => Some(bytes.toArray().map({ b => Char.fromUInt8(b) }).toString())
            case None => None
        }
    }

    /// 列数
    public func columnCount(): Int64 {
        values.size
    }
}

// ============================================================================
// CopyData - COPY 协议数据
// 严格翻译自: bun/src/sql/postgres/protocol/CopyData.zig
// ============================================================================

/// PostgreSQL COPY 协议数据消息
/// 对应 Bun CopyData
public class CopyDataMessage {
    public var data: SQLData

    public init() {
        data = SQLData()
    }

    /// 从读取器解码
    public func decode(reader: ProtocolReader): Bool {
        let len = reader.readLength()
        match (len) {
            case None => return false
            case Some(l) => {
                let dataLen = Int64(l) - 5  // 减去类型字节和长度字节
                if (dataLen > 0) {
                    match (reader.readBytes(dataLen)) {
                        case None => return false
                        case Some(bytes) => data = SQLData(temporary: bytes)
                    }
                }
            }
        }
        return true
    }

    /// 释放资源
    public func deinit() {
        data.deinit()
    }
}
