// 严格翻译自: src/sql/postgres/protocol/FieldMessage.zig
// PostgreSQL 错误/通知字段消息
package bao_sql.postgres.protocol

import std.collection.ArrayList as StdArrayList
import bao_sql.shared.Data

/// PostgreSQL 错误/通知响应中的字段消息
/// 对应 Bun: FieldMessage (union FieldType)
public class FieldMessage {
    public var fieldType: FieldType
    public var value: String

    public init(_fieldType: FieldType, _value: String) {
        this.fieldType = _fieldType
        this.value = _value
    }

    /// 释放资源
    /// 对应 Bun: FieldMessage.deinit
    public func deinit(): Unit {
        // String 在仓颉中是值类型，无需手动释放
    }

    /// 初始化字段消息
    /// 对应 Bun: FieldMessage.init
    public static func `init`(tag: FieldType, message: String): ?FieldMessage {
        match (tag) {
            case FieldType.severity => Some(FieldMessage(tag, message))
            case FieldType.code => Some(FieldMessage(tag, message))
            case FieldType.message => Some(FieldMessage(tag, message))
            case FieldType.detail => Some(FieldMessage(tag, message))
            case FieldType.hint => Some(FieldMessage(tag, message))
            case FieldType.position => Some(FieldMessage(tag, message))
            case FieldType.internal_position => Some(FieldMessage(tag, message))
            case FieldType.internal => Some(FieldMessage(tag, message))
            case FieldType.whereClause => Some(FieldMessage(tag, message))
            case FieldType.schema => Some(FieldMessage(tag, message))
            case FieldType.table => Some(FieldMessage(tag, message))
            case FieldType.column => Some(FieldMessage(tag, message))
            case FieldType.datatype => Some(FieldMessage(tag, message))
            case FieldType.constraint => Some(FieldMessage(tag, message))
            case FieldType.file => Some(FieldMessage(tag, message))
            case FieldType.line => Some(FieldMessage(tag, message))
            case FieldType.routine => Some(FieldMessage(tag, message))
            case _ => None
        }
    }

    /// 从读取器解码字段消息列表
    /// 对应 Bun: FieldMessage.decodeList
    public static func decodeList(reader: StackReaderImpl): ?StdArrayList<FieldMessage> {
        var messages = StdArrayList<FieldMessage>()

        while (true) {
            let fieldInt = reader.byte()
            if (fieldInt.isNone()) { break }
            if (fieldInt.getOrThrow() == 0) { break }

            let field = FieldType.fromByte(fieldInt.getOrThrow())
            let message = reader.readZ()
            if (message.isNone()) { break }
            let msgSlice = message.getOrThrow().slice()
            if (msgSlice.size == 0) { break }

            let msgStr = String.fromUtf8(msgSlice)
            let fieldMsg = FieldMessage.`init`(field, msgStr)
            if (fieldMsg.isSome()) {
                messages.add(fieldMsg.getOrThrow())
            }
        }

        return messages
    }
}
