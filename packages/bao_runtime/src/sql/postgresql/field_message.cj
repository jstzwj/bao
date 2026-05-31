// PostgreSQL 字段消息 (错误/通知响应中的字段)
// 严格翻译自: bun/src/sql/postgres/protocol/FieldMessage.zig
//   pub const FieldMessage = union(FieldType) { severity: String, ... };
package bao_runtime.sql.postgresql

/// PostgreSQL 错误/通知响应中的字段消息
/// 每个字段由类型标识和字符串值组成
/// 对应 Bun FieldMessage
public class FieldMessage {
    public var fieldType: FieldType
    public var value: String

    public init(fieldType: FieldType, value: String) {
        this.fieldType = fieldType
        this.value = value
    }

    /// 释放资源
    public func deinit() {
        // String 由 GC 管理
    }

    /// 格式化输出
    public func toString(): String {
        "${fieldType}: ${value}"
    }
}

/// 字段消息列表解码器
/// 对应 Bun FieldMessage.decodeList()
public class FieldMessageDecoder {

    /// 从读取器解码字段消息列表
    /// 持续读取直到遇到 null 终止符
    public static func decodeList(reader: ProtocolReader): ?Array<FieldMessage> {
        let messages = Array<FieldMessage>()

        while (true) {
            // 读取字段类型字节
            let fieldByte = reader.readByte()
            match (fieldByte) {
                case None => return None
                case Some(b) => {
                    // 0 表示字段列表结束
                    if (b == 0) {
                        return messages
                    }
                    let fieldType = FieldType.fromByte(b)

                    // 读取字段值 (null 终止字符串)
                    let value = reader.readNullTerminatedString()
                    match (value) {
                        case None => return None
                        case Some(v) => {
                            if (v.size == 0) {
                                return messages
                            }
                            // 只有已知的字段类型才添加
                            match (fieldType) {
                                case FieldType.Unknown(_) => {}
                                case _ => {
                                    messages.append(FieldMessage(fieldType: fieldType, value: v))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
