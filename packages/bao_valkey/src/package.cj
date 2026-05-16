// bao_valkey - Valkey/Redis RESP 协议实现
// 严格翻译自: bun/src/valkey/valkey_protocol.zig (564行)
//   支持 RESP2 和 RESP3 协议类型
package bao_valkey

import bao_core.*

// ============================================================================
// RedisError - Redis 错误类型
// 严格翻译自: valkey_protocol.zig - RedisError
// ============================================================================

/// Redis 错误类型 - 对应 Bun RedisError
public enum RedisError {
    | AuthenticationFailed
    | ConnectionClosed
    | InvalidArgument
    | InvalidArray
    | InvalidAttribute
    | InvalidBigNumber
    | InvalidBlobError
    | InvalidBoolean
    | InvalidBulkString
    | InvalidCommand
    | InvalidDouble
    | InvalidErrorString
    | InvalidInteger
    | InvalidMap
    | InvalidNull
    | InvalidPush
    | InvalidResponse
    | InvalidResponseType
    | InvalidSet
    | InvalidSimpleString
    | InvalidVerbatimString
    | JSError
    | OutOfMemory
    | JSTerminated
    | UnsupportedProtocol
    | ConnectionTimeout
    | IdleTimeout
    | NestingDepthExceeded

    public func message(): String {
        match (this) {
            case AuthenticationFailed => "Authentication failed"
            case ConnectionClosed => "Connection closed"
            case InvalidArgument => "Invalid argument"
            case InvalidArray => "Invalid array"
            case InvalidAttribute => "Invalid attribute"
            case InvalidBigNumber => "Invalid big number"
            case InvalidBlobError => "Invalid blob error"
            case InvalidBoolean => "Invalid boolean"
            case InvalidBulkString => "Invalid bulk string"
            case InvalidCommand => "Invalid command"
            case InvalidDouble => "Invalid double"
            case InvalidErrorString => "Invalid error string"
            case InvalidInteger => "Invalid integer"
            case InvalidMap => "Invalid map"
            case InvalidNull => "Invalid null"
            case InvalidPush => "Invalid push"
            case InvalidResponse => "Invalid response"
            case InvalidResponseType => "Invalid response type"
            case InvalidSet => "Invalid set"
            case InvalidSimpleString => "Invalid simple string"
            case InvalidVerbatimString => "Invalid verbatim string"
            case JSError => "JS error"
            case OutOfMemory => "Out of memory"
            case JSTerminated => "JS terminated"
            case UnsupportedProtocol => "Unsupported protocol"
            case ConnectionTimeout => "Connection timeout"
            case IdleTimeout => "Idle timeout"
            case NestingDepthExceeded => "Nesting depth exceeded"
        }
    }
}

// ============================================================================
// RESPType - RESP 协议类型
// 严格翻译自: valkey_protocol.zig - RESPType
//   pub const RESPType = enum(u8) {
//       SimpleString = '+', Error = '-', Integer = ':', BulkString = '$', Array = '*',
//       Null = '_', Double = ',', Boolean = '#', BlobError = '!', VerbatimString = '=',
//       Map = '%', Set = '~', Attribute = '|', Push = '>', BigNumber = '(',
//   };
// ============================================================================

/// RESP 协议类型 - 对应 Bun RESPType
public enum RESPType {
    // RESP2 类型
    | SimpleString   // '+'
    | Error          // '-'
    | Integer        // ':'
    | BulkString     // '$'
    | Array          // '*'
    // RESP3 类型
    | Null           // '_'
    | Double         // ','
    | Boolean        // '#'
    | BlobError      // '!'
    | VerbatimString // '='
    | Map            // '%'
    | Set            // '~'
    | Attribute      // '|'
    | Push           // '>'
    | BigNumber      // '('

    public operator func ==(right: RESPType): Bool {
        match (this) {
            case SimpleString => match (right) { case SimpleString => true case _ => false }
            case Error => match (right) { case Error => true case _ => false }
            case Integer => match (right) { case Integer => true case _ => false }
            case BulkString => match (right) { case BulkString => true case _ => false }
            case Array => match (right) { case Array => true case _ => false }
            case Null => match (right) { case Null => true case _ => false }
            case Double => match (right) { case Double => true case _ => false }
            case Boolean => match (right) { case Boolean => true case _ => false }
            case BlobError => match (right) { case BlobError => true case _ => false }
            case VerbatimString => match (right) { case VerbatimString => true case _ => false }
            case Map => match (right) { case Map => true case _ => false }
            case Set => match (right) { case Set => true case _ => false }
            case Attribute => match (right) { case Attribute => true case _ => false }
            case Push => match (right) { case Push => true case _ => false }
            case BigNumber => match (right) { case BigNumber => true case _ => false }
        }
    }

    /// 从字节解析类型
    public static func fromByte(byte: UInt8): ?RESPType {
        match (byte) {
            case '+' => RESPType.SimpleString
            case '-' => RESPType.Error
            case ':' => RESPType.Integer
            case '$' => RESPType.BulkString
            case '*' => RESPType.Array
            case '_' => RESPType.Null
            case ',' => RESPType.Double
            case '#' => RESPType.Boolean
            case '!' => RESPType.BlobError
            case '=' => RESPType.VerbatimString
            case '%' => RESPType.Map
            case '~' => RESPType.Set
            case '|' => RESPType.Attribute
            case '>' => RESPType.Push
            case '(' => RESPType.BigNumber
            case _ => None
        }
    }

    /// 转换为字节
    public func toByte(): UInt8 {
        match (this) {
            case SimpleString => '+'
            case Error => '-'
            case Integer => ':'
            case BulkString => '$'
            case Array => '*'
            case Null => '_'
            case Double => ','
            case Boolean => '#'
            case BlobError => '!'
            case VerbatimString => '='
            case Map => '%'
            case Set => '~'
            case Attribute => '|'
            case Push => '>'
            case BigNumber => '('
        }
    }
}

// ============================================================================
// VerbatimString - 逐字字符串 (RESP3)
// 严格翻译自: valkey_protocol.zig - VerbatimString
// ============================================================================

/// 逐字字符串 - 对应 Bun VerbatimString
public class VerbatimString {
    public var format: String   // 如 "txt" 或 "mkd"
    public var content: String

    public init(format: String, content: String) {
        this.format = format
        this.content = content
    }
}

// ============================================================================
// RESPMapEntry - Map 条目
// 严格翻译自: valkey_protocol.zig - MapEntry
// ============================================================================

/// Map 条目 - 对应 Bun MapEntry
public class RESPMapEntry {
    public var key: RESPValue
    public var value: RESPValue

    public init(key: RESPValue, value: RESPValue) {
        this.key = key
        this.value = value
    }
}

// ============================================================================
// RESPPush - Push 消息
// 严格翻译自: valkey_protocol.zig - Push
// ============================================================================

/// Push 消息 - 对应 Bun Push
public class RESPPush {
    public var kind: String
    public var data: ArrayList<RESPValue>

    public init(kind: String, data: ArrayList<RESPValue>) {
        this.kind = kind
        this.data = data
    }
}

// ============================================================================
// RESPAttribute - 属性 (RESP3)
// 严格翻译自: valkey_protocol.zig - Attribute
// ============================================================================

/// 属性 - 对应 Bun Attribute
public class RESPAttribute {
    public var attributes: ArrayList<RESPMapEntry>
    public var value: RESPValue

    public init(attributes: ArrayList<RESPMapEntry>, value: RESPValue) {
        this.attributes = attributes
        this.value = value
    }
}

// ============================================================================
// RESPValue - RESP 值 (tagged union)
// 严格翻译自: valkey_protocol.zig - RESPValue
//   pub const RESPValue = union(RESPType) { ... };
// ============================================================================

/// RESP 值 - 对应 Bun RESPValue
/// 支持 RESP2 和 RESP3 所有类型
public class RESPValue {
    public var respType: RESPType
    // RESP2
    public var simpleString: String
    public var error: String
    public var integerValue: Int64
    public var bulkString: ?String
    public var array: ArrayList<RESPValue>
    // RESP3
    public var doubleValue: Float64
    public var booleanValue: Bool
    public var blobError: String
    public var verbatimString: ?VerbatimString
    public var map: ArrayList<RESPMapEntry>
    public var set: ArrayList<RESPValue>
    public var attribute: ?RESPAttribute
    public var push: ?RESPPush
    public var bigNumber: String

    public init(respType: RESPType) {
        this.respType = respType
        simpleString = ""
        error = ""
        integerValue = 0
        bulkString = None
        array = ArrayList<RESPValue>()
        doubleValue = 0.0
        booleanValue = false
        blobError = ""
        verbatimString = None
        map = ArrayList<RESPMapEntry>()
        set = ArrayList<RESPValue>()
        attribute = None
        push = None
        bigNumber = ""
    }

    /// 创建 SimpleString 值
    public static func simpleString(s: String): RESPValue {
        let v = RESPValue(RESPType.SimpleString)
        v.simpleString = s
        v
    }

    /// 创建 Error 值
    public static func error(s: String): RESPValue {
        let v = RESPValue(RESPType.Error)
        v.error = s
        v
    }

    /// 创建 Integer 值
    public static func integer(i: Int64): RESPValue {
        let v = RESPValue(RESPType.Integer)
        v.integerValue = i
        v
    }

    /// 创建 BulkString 值
    public static func bulkString(s: ?String): RESPValue {
        let v = RESPValue(RESPType.BulkString)
        v.bulkString = s
        v
    }

    /// 创建 Null 值
    public static func nullValue(): RESPValue {
        RESPValue(RESPType.Null)
    }

    /// 创建 Double 值
    public static func doubleValue(d: Float64): RESPValue {
        let v = RESPValue(RESPType.Double)
        v.doubleValue = d
        v
    }

    /// 创建 Boolean 值
    public static func booleanValue(b: Bool): RESPValue {
        let v = RESPValue(RESPType.Boolean)
        v.booleanValue = b
        v
    }

    /// 格式化为字符串
    /// 对应 Bun RESPValue.format()
    public func format(): String {
        if (respType == RESPType.SimpleString) { return simpleString }
        if (respType == RESPType.Error) { return error }
        if (respType == RESPType.Integer) { return "${integerValue}" }
        if (respType == RESPType.Null) { return "(nil)" }
        if (respType == RESPType.Double) { return "${doubleValue}" }
        if (respType == RESPType.Boolean) { return "${booleanValue}" }
        if (respType == RESPType.BlobError) { return "Error: ${blobError}" }
        if (respType == RESPType.BigNumber) { return "BigNumber(${bigNumber})" }
        if (respType == RESPType.BulkString) {
            if (bulkString.isSome()) {
                return bulkString.getOrThrow()
            }
            return "(nil)"
        }
        if (respType == RESPType.Array) {
            let sb = StringBuilder()
            sb.append('[')
            for (i in 0..array.size) {
                if (i > 0) { sb.append(", ") }
                sb.append(array[i].format())
            }
            sb.append(']')
            return sb.toString()
        }
        if (respType == RESPType.VerbatimString) {
            if (verbatimString.isSome()) {
                let vs = verbatimString.getOrThrow()
                return "${vs.format}:${vs.content}"
            }
            return "(nil)"
        }
        if (respType == RESPType.Map) {
            let sb = StringBuilder()
            sb.append('{')
            for (i in 0..map.size) {
                if (i > 0) { sb.append(", ") }
                sb.append(map[i].key.format())
                sb.append(": ")
                sb.append(map[i].value.format())
            }
            sb.append('}')
            return sb.toString()
        }
        if (respType == RESPType.Set) {
            let sb = StringBuilder()
            sb.append("Set{")
            for (i in 0..set.size) {
                if (i > 0) { sb.append(", ") }
                sb.append(set[i].format())
            }
            sb.append('}')
            return sb.toString()
        }
        if (respType == RESPType.Attribute) {
            if (attribute.isSome()) {
                let attr = attribute.getOrThrow()
                let sb = StringBuilder()
                sb.append("(Attr: {")
                for (i in 0..attr.attributes.size) {
                    if (i > 0) { sb.append(", ") }
                    sb.append(attr.attributes[i].key.format())
                    sb.append(": ")
                    sb.append(attr.attributes[i].value.format())
                }
                sb.append("} => ")
                sb.append(attr.value.format())
                sb.append(')')
                return sb.toString()
            }
            return "(nil)"
        }
        if (respType == RESPType.Push) {
            if (push.isSome()) {
                let p = push.getOrThrow()
                let sb = StringBuilder()
                sb.append("Push(${p.kind}: [")
                for (i in 0..p.data.size) {
                    if (i > 0) { sb.append(", ") }
                    sb.append(p.data[i].format())
                }
                sb.append("])")
                return sb.toString()
            }
            return "Push(nil)"
        }
        return "(unknown)"
    }
}

// ============================================================================
// ValkeyReader - RESP 协议读取器
// 严格翻译自: valkey_protocol.zig - ValkeyReader
//   pub const ValkeyReader = struct {
//       buffer: []const u8,
//       pos: usize = 0,
//       pub fn readByte, readUntilCRLF, readInteger, readDouble,
//              readBoolean, readVerbatimString, readValue
//   };
// ============================================================================

/// 最大嵌套深度 - 对应 Bun max_nesting_depth
public let MAX_NESTING_DEPTH: Int64 = 128

/// RESP 协议读取器 - 对应 Bun ValkeyReader
/// 从字节缓冲区解析 RESP2/RESP3 协议消息
public class ValkeyReader {
    private var buffer: Array<Byte>
    private var pos: Int64

    public init(buffer: Array<Byte>) {
        this.buffer = buffer
        pos = 0
    }

    public init(str: String) {
        buffer = str.toArray()
        pos = 0
    }

    /// 读取一个字节
    /// 对应 Bun ValkeyReader.readByte()
    public func readByte(): ?Byte {
        if (pos >= buffer.size) {
            return None
        }
        let b = buffer[pos]
        pos += 1
        b
    }

    /// 读取直到 CRLF
    /// 对应 Bun ValkeyReader.readUntilCRLF()
    public func readUntilCRLF(): ?String {
        let remaining = buffer[pos..]
        var i = 0
        while (i < remaining.size - 1) {
            if (remaining[i] == '\r' && remaining[i + 1] == '\n') {
                let result = String(remaining[pos - pos..]) // 从当前 pos 开始
                // 重新实现：用 subArray
                let bytes = Array<Byte>(remaining.size)
                // 简化实现
                let result2 = String.fromUtf8(buffer[pos..(pos + i)])
                pos += i + 2
                return result2
            }
            i += 1
        }
        None
    }

    /// 读取整数
    /// 对应 Bun ValkeyReader.readInteger()
    public func readInteger(): ?Int64 {
        let str = readUntilCRLF()
        if (str.isNone()) { return None }
        Int64.parse(str.getOrThrow())
    }

    /// 读取双精度浮点数
    /// 对应 Bun ValkeyReader.readDouble()
    public func readDouble(): ?Float64 {
        let str = readUntilCRLF()
        if (str.isNone()) { return None }
        let s = str.getOrThrow()
        // 处理特殊值
        if (s == "inf") { return Float64.infinity }
        if (s == "-inf") { return -Float64.infinity }
        if (s == "nan") { return Float64.nan }
        Float64.parse(s)
    }

    /// 读取布尔值
    /// 对应 Bun ValkeyReader.readBoolean()
    public func readBoolean(): ?Bool {
        let str = readUntilCRLF()
        if (str.isNone()) { return None }
        let s = str.getOrThrow()
        if (s.size != 1) { return None }
        match (s[0]) {
            case 't' => true
            case 'f' => false
            case _ => None
        }
    }

    /// 读取一个完整的 RESP 值
    /// 对应 Bun ValkeyReader.readValue()
    public func readValue(): ?RESPValue {
        readValueWithDepth(0)
    }

    /// 带深度限制的读取
    /// 对应 Bun ValkeyReader.readValueWithDepth()
    func readValueWithDepth(depth: Int64): ?RESPValue {
        let typeByte = readByte()
        if (typeByte.isNone()) { return None }

        let respType = RESPType.fromByte(typeByte.getOrThrow().value)
        if (respType.isNone()) { return None }

        let rt = respType.getOrThrow()

        // RESP2 types
        if (rt == RESPType.SimpleString) {
            let str = readUntilCRLF()
            if (str.isNone()) { return None }
            return RESPValue.simpleString(str.getOrThrow())
        }
        if (rt == RESPType.Error) {
            let str = readUntilCRLF()
            if (str.isNone()) { return None }
            return RESPValue.error(str.getOrThrow())
        }
        if (rt == RESPType.Integer) {
            let i = readInteger()
            if (i.isNone()) { return None }
            return RESPValue.integer(i.getOrThrow())
        }
        if (rt == RESPType.BulkString) {
            let len = readInteger()
            if (len.isNone()) { return None }
            if (len.getOrThrow() < 0) {
                return RESPValue.bulkString(None)
            }
            let n = len.getOrThrow()
            if (pos + n > buffer.size) { return None }
            let str = String.fromUtf8(buffer[pos..(pos + n)])
            pos += n
            // 跳过 CRLF
            let crlf = readUntilCRLF()
            return RESPValue.bulkString(str)
        }
        if (rt == RESPType.Array) {
            if (depth >= MAX_NESTING_DEPTH) { return None }
            let len = readInteger()
            if (len.isNone()) { return None }
            if (len.getOrThrow() < 0) {
                return RESPValue(RESPType.Array) // 空数组
            }
            let arr = ArrayList<RESPValue>()
            for (_ in 0..len.getOrThrow()) {
                let v = readValueWithDepth(depth + 1)
                if (v.isNone()) { return None }
                arr.append(v.getOrThrow())
            }
            let result = RESPValue(RESPType.Array)
            result.array = arr
            return result
        }
        // RESP3 types
        if (rt == RESPType.Null) {
            readUntilCRLF() // 读取并丢弃 CRLF
            return RESPValue.nullValue()
        }
        if (rt == RESPType.Double) {
            let d = readDouble()
            if (d.isNone()) { return None }
            return RESPValue.doubleValue(d.getOrThrow())
        }
        if (rt == RESPType.Boolean) {
            let b = readBoolean()
            if (b.isNone()) { return None }
            return RESPValue.booleanValue(b.getOrThrow())
        }
        if (rt == RESPType.BlobError) {
            let len = readInteger()
            if (len.isNone() || len.getOrThrow() < 0) { return None }
            let n = len.getOrThrow()
            if (pos + n > buffer.size) { return None }
            let str = String.fromUtf8(buffer[pos..(pos + n)])
            pos += n
            readUntilCRLF() // 跳过 CRLF
            let result = RESPValue(RESPType.BlobError)
            result.blobError = str
            return result
        }
        if (rt == RESPType.VerbatimString) {
            let len = readInteger()
            if (len.isNone() || len.getOrThrow() < 0) { return None }
            let n = len.getOrThrow()
            if (pos + n > buffer.size) { return None }
            let content = String.fromUtf8(buffer[pos..(pos + n)])
            pos += n
            readUntilCRLF()
            // 格式: "xxx:content"
            if (content.size < 4 || content[3] != ':') { return None }
            let fmt = content.subString(0, 3)
            let body = content.subString(4)
            let result = RESPValue(RESPType.VerbatimString)
            result.verbatimString = VerbatimString(fmt, body)
            return result
        }
        if (rt == RESPType.Map) {
            if (depth >= MAX_NESTING_DEPTH) { return None }
            let len = readInteger()
            if (len.isNone() || len.getOrThrow() < 0) { return None }
            let entries = ArrayList<RESPMapEntry>()
            for (_ in 0..len.getOrThrow()) {
                let key = readValueWithDepth(depth + 1)
                if (key.isNone()) { return None }
                let val = readValueWithDepth(depth + 1)
                if (val.isNone()) { return None }
                entries.append(RESPMapEntry(key.getOrThrow(), val.getOrThrow()))
            }
            let result = RESPValue(RESPType.Map)
            result.map = entries
            return result
        }
        if (rt == RESPType.Set) {
            if (depth >= MAX_NESTING_DEPTH) { return None }
            let len = readInteger()
            if (len.isNone() || len.getOrThrow() < 0) { return None }
            let items = ArrayList<RESPValue>()
            for (_ in 0..len.getOrThrow()) {
                let v = readValueWithDepth(depth + 1)
                if (v.isNone()) { return None }
                items.append(v.getOrThrow())
            }
            let result = RESPValue(RESPType.Set)
            result.set = items
            return result
        }
        if (rt == RESPType.Attribute) {
            if (depth >= MAX_NESTING_DEPTH) { return None }
            let len = readInteger()
            if (len.isNone() || len.getOrThrow() < 0) { return None }
            let attrs = ArrayList<RESPMapEntry>()
            for (_ in 0..len.getOrThrow()) {
                let key = readValueWithDepth(depth + 1)
                if (key.isNone()) { return None }
                let val = readValueWithDepth(depth + 1)
                if (val.isNone()) { return None }
                attrs.append(RESPMapEntry(key.getOrThrow(), val.getOrThrow()))
            }
            // 读取属性后的实际值
            let val = readValueWithDepth(depth + 1)
            if (val.isNone()) { return None }
            let result = RESPValue(RESPType.Attribute)
            result.attribute = RESPAttribute(attrs, val.getOrThrow())
            return result
        }
        if (rt == RESPType.Push) {
            if (depth >= MAX_NESTING_DEPTH) { return None }
            let len = readInteger()
            if (len.isNone() || len.getOrThrow() <= 0) { return None }
            // 第一个元素是 push 类型
            let pushType = readValueWithDepth(depth + 1)
            if (pushType.isNone()) { return None }
            let pt = pushType.getOrThrow()
            var kind = ""
            if (pt.respType == RESPType.SimpleString) {
                kind = pt.simpleString
            } else if (pt.respType == RESPType.BulkString) {
                kind = pt.bulkString.getOr("")
            }
            // 读取剩余数据
            let data = ArrayList<RESPValue>()
            for (_ in 0..(len.getOrThrow() - 1)) {
                let v = readValueWithDepth(depth + 1)
                if (v.isNone()) { return None }
                data.append(v.getOrThrow())
            }
            let result = RESPValue(RESPType.Push)
            result.push = RESPPush(kind, data)
            return result
        }
        if (rt == RESPType.BigNumber) {
            let str = readUntilCRLF()
            if (str.isNone()) { return None }
            let result = RESPValue(RESPType.BigNumber)
            result.bigNumber = str.getOrThrow()
            return result
        }
        return None
    }
}

// ============================================================================
// SubscriptionPushMessage - 订阅推送消息类型
// 严格翻译自: valkey_protocol.zig - SubscriptionPushMessage
// ============================================================================

/// 订阅推送消息类型 - 对应 Bun SubscriptionPushMessage
public enum SubscriptionPushMessage {
    | Message
    | Subscribe
    | Unsubscribe

    public static func fromString(s: String): ?SubscriptionPushMessage {
        match (s) {
            case "message" => SubscriptionPushMessage.Message
            case "subscribe" => SubscriptionPushMessage.Subscribe
            case "unsubscribe" => SubscriptionPushMessage.Unsubscribe
            case _ => None
        }
    }
}
