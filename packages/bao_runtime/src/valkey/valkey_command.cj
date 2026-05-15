// Valkey 命令 - RESP 协议命令序列化与 Promise 管理
// 严格翻译自: bun/src/runtime/valkey_jsc/ValkeyCommand.zig
package bao_runtime.valkey

import bao_core.*
import bao_collections.*
import bao_valkey.*

// ============================================================================
// ValkeyCommand - Redis 命令
// 严格翻译自: ValkeyCommand.zig - Command
//   pub const Command = struct {
//       command: []const u8,
//       args: Args,
//       meta: Meta = .{},
//   };
// ============================================================================

/// Redis 命令参数
/// 对应 Bun Command.Args (union(enum) { slices, args, raw })
public class CommandArgs {
    public var slices: ?ArrayList<Slice>
    public var args: ?ArrayList<JsArgument>
    public var raw: ?ArrayList<String>
    /// 标记当前使用哪个变体: "slices" | "args" | "raw"
    public var variant: String

    public init() {
        slices = None
        args = None
        raw = None
        variant = "args"
    }

    public init(slices: ArrayList<Slice>) {
        this.slices = slices
        this.args = None
        this.raw = None
        variant = "slices"
    }

    public init(args: ArrayList<JsArgument>) {
        this.slices = None
        this.args = args
        this.raw = None
        variant = "args"
    }

    public init(raw: ArrayList<String>) {
        this.slices = None
        this.args = None
        this.raw = raw
        variant = "raw"
    }

    /// 获取参数长度
    /// 对应 Bun Command.Args.len()
    public func len(): Int64 {
        match (variant) {
            case "slices" => {
                if (slices.isSome()) { slices.getOrThrow().size } else { 0 }
            }
            case "args" => {
                if (args.isSome()) { args.getOrThrow().size } else { 0 }
            }
            case "raw" => {
                if (raw.isSome()) { raw.getOrThrow().size } else { 0 }
            }
            case _ => 0
        }
    }
}

/// Slice 类型 - 用于持有字节切片的引用
public class Slice {
    public var data: Array<Byte>
    public var offset: Int64
    public var length: Int64

    public init(data: Array<Byte>) {
        this.data = data
        offset = 0
        length = data.size
    }

    public init(data: Array<Byte>, offset: Int64, length: Int64) {
        this.data = data
        this.offset = offset
        this.length = length
    }

    /// 获取字节长度
    public func byteLength(): Int64 {
        length
    }

    /// 获取切片内容
    public func slice(): Array<Byte> {
        data[offset..(offset + length)]
    }

    /// 转为字符串
    public func toString(): String {
        String.fromUtf8(slice())
    }
}

/// JS 参数类型 - 对应 Bun node.BlobOrStringOrBuffer
public class JsArgument {
    public var data: Array<Byte>
    public var isBuffer: Bool

    public init(data: Array<Byte>, isBuffer: Bool) {
        this.data = data
        this.isBuffer = isBuffer
    }

    public init(str: String) {
        data = str.toArray()
        isBuffer = false
    }

    /// 获取字节长度
    public func byteLength(): Int64 {
        data.size
    }

    /// 获取切片内容
    public func slice(): Array<Byte> {
        data
    }

    /// 转为字符串
    public func toString(): String {
        String.fromUtf8(data)
    }

    /// 释放资源
    public func deinit(): Unit {
        // 释放资源 - 对应 Bun BlobOrStringOrBuffer.deinit()
    }
}

// ============================================================================
// CommandMeta - 命令元数据
// 严格翻译自: ValkeyCommand.zig - Meta (packed struct(u8))
//   pub const Meta = packed struct(u8) {
//       return_as_bool: bool = false,
//       supports_auto_pipelining: bool = true,
//       return_as_buffer: bool = false,
//       subscription_request: bool = false,
//       _padding: u4 = 0,
//   };
// ============================================================================

/// 不允许自动管道化的命令列表
/// 对应 Bun Meta.not_allowed_autopipeline_commands
public let NOT_ALLOWED_AUTOPIPELINE_COMMANDS: Array<String> = [
    "AUTH", "INFO", "QUIT", "EXEC", "MULTI", "WATCH",
    "SCRIPT", "SELECT", "CLUSTER", "DISCARD", "UNWATCH",
    "PIPELINE", "SUBSCRIBE", "PSUBSCRIBE", "UNSUBSCRIBE", "UNPSUBSCRIBE"
]

/// Redis 命令元数据
/// 对应 Bun Command.Meta
public class CommandMeta {
    /// 返回值转换为布尔值
    public var returnAsBool: Bool
    /// 是否支持自动管道化
    public var supportsAutoPipelining: Bool
    /// 返回值作为 Buffer
    public var returnAsBuffer: Bool
    /// 是否为订阅请求
    public var subscriptionRequest: Bool

    public init() {
        returnAsBool = false
        supportsAutoPipelining = true
        returnAsBuffer = false
        subscriptionRequest = false
    }

    public init(returnAsBool: Bool, supportsAutoPipelining: Bool,
                returnAsBuffer: Bool, subscriptionRequest: Bool) {
        this.returnAsBool = returnAsBool
        this.supportsAutoPipelining = supportsAutoPipelining
        this.returnAsBuffer = returnAsBuffer
        this.subscriptionRequest = subscriptionRequest
    }

    /// 检查命令是否允许自动管道化
    /// 对应 Bun Meta.check()
    public func check(command: ValkeyCommand): CommandMeta {
        let newMeta = CommandMeta(
            returnAsBool,
            supportsAutoPipelining,
            returnAsBuffer,
            subscriptionRequest
        )
        var isNotAllowed = false
        for (cmd in NOT_ALLOWED_AUTOPIPELINE_COMMANDS) {
            if (cmd == command.command) {
                isNotAllowed = true
            }
        }
        newMeta.supportsAutoPipelining = !isNotAllowed
        newMeta
    }
}

// ============================================================================
// ValkeyCommand - Redis 命令
// 严格翻译自: ValkeyCommand.zig - Command
//   pub const Command = struct {
//       command: []const u8,
//       args: Args,
//       meta: Meta = .{},
//   };
// ============================================================================

/// Redis 命令
/// 对应 Bun Command
public class ValkeyCommand {
    /// 命令名称 (如 "GET", "SET")
    public var command: String
    /// 命令参数
    public var args: CommandArgs
    /// 命令元数据
    public var meta: CommandMeta

    public init(command: String, args: CommandArgs) {
        this.command = command
        this.args = args
        meta = CommandMeta()
    }

    public init(command: String, args: CommandArgs, meta: CommandMeta) {
        this.command = command
        this.args = args
        this.meta = meta
    }

    /// 将命令序列化为 RESP 协议格式
    /// 对应 Bun Command.write()
    ///   try writer.print("*{d}\r\n", .{1 + this.args.len()});
    ///   try writer.print("${d}\r\n{s}\r\n", .{ this.command.len, this.command });
    public func writeToBuffer(output: ByteBuffer): Unit {
        // 序列化为 RESP 数组格式
        let argCount = 1 + args.len()
        output.append("*${argCount}\r\n")
        output.append("${command.size}\r\n${command}\r\n")

        // 根据参数变体序列化
        match (args.variant) {
            case "slices" => {
                if (args.slices.isSome()) {
                    for (arg in args.slices.getOrThrow()) {
                        let s = arg.toString()
                        output.append("${arg.byteLength()}\r\n${s}\r\n")
                    }
                }
            }
            case "args" => {
                if (args.args.isSome()) {
                    for (arg in args.args.getOrThrow()) {
                        let s = arg.toString()
                        output.append("${arg.byteLength()}\r\n${s}\r\n")
                    }
                }
            }
            case "raw" => {
                if (args.raw.isSome()) {
                    for (arg in args.raw.getOrThrow()) {
                        output.append("${arg.size}\r\n${arg}\r\n")
                    }
                }
            }
            case _ => ()
        }
    }

    /// 计算序列化后的字节长度
    /// 对应 Bun Command.byteLength()
    public func byteLength(): Int64 {
        let buf = ByteBuffer()
        writeToBuffer(buf)
        buf.size
    }

    /// 序列化命令为字节数组
    /// 对应 Bun Command.serialize()
    public func serialize(): Array<Byte> {
        let buf = ByteBuffer()
        writeToBuffer(buf)
        buf.toByteArray()
    }

    /// 释放资源
    /// 对应 Bun Command.deinit() - no-op
    public func deinit(): Unit {
        // 无操作
    }
}

// ============================================================================
// CommandEntry - 离线队列命令条目
// 严格翻译自: ValkeyCommand.zig - Entry
//   pub const Entry = struct {
//       serialized_data: []u8,
//       meta: Meta = .{},
//       promise: Promise,
//   };
// ============================================================================

/// 离线队列命令条目
/// 对应 Bun Command.Entry
public class CommandEntry {
    /// 预序列化的 RESP 协议字节
    public var serializedData: Array<Byte>
    /// 命令元数据
    public var meta: CommandMeta
    /// 关联的 Promise
    public var promise: ValkeyPromise

    public init(serializedData: Array<Byte>, meta: CommandMeta, promise: ValkeyPromise) {
        this.serializedData = serializedData
        this.meta = meta
        this.promise = promise
    }

    /// 创建离线命令条目
    /// 对应 Bun Command.Entry.create()
    public static func create(command: ValkeyCommand, promise: ValkeyPromise): CommandEntry {
        CommandEntry(command.serialize(), command.meta, promise)
    }

    /// 释放资源
    /// 对应 Bun Command.Entry.deinit()
    public func deinit(): Unit {
        // 释放序列化数据
    }
}

// ============================================================================
// ValkeyPromise - Redis 命令 Promise
// 严格翻译自: ValkeyCommand.zig - Promise
//   pub const Promise = struct {
//       meta: Meta,
//       promise: jsc.JSPromise.Strong,
//   };
// ============================================================================

/// Redis 命令 Promise
/// 对应 Bun Command.Promise
public class ValkeyPromise {
    /// 命令元数据
    public var meta: CommandMeta
    /// 内部 Promise
    public var promise: JsPromise

    public init(meta: CommandMeta) {
        this.meta = meta
        promise = JsPromise()
    }

    public init(meta: CommandMeta, promise: JsPromise) {
        this.meta = meta
        this.promise = promise
    }

    /// 创建 Promise
    /// 对应 Bun Command.Promise.create()
    public static func create(meta: CommandMeta): ValkeyPromise {
        ValkeyPromise(meta)
    }

    /// 完成 Promise
    /// 对应 Bun Command.Promise.resolve()
    public func resolve(globalObject: JsObject, value: RESPValue): Unit {
        let options = ToJSOptions(meta.returnAsBuffer)
        let jsValue = value.toJSWithOptions(globalObject, options)
        promise.resolve(jsValue)
    }

    /// 拒绝 Promise
    /// 对应 Bun Command.Promise.reject()
    public func reject(globalObject: JsObject, jsvalue: JsValue): Unit {
        promise.reject(jsvalue)
    }

    /// 获取 JS Promise 值
    public func get(): JsValue {
        JsValue(JsValueType.Promise)
    }

    /// 释放资源
    /// 对应 Bun Command.Promise.deinit()
    public func deinit(): Unit {
        // 释放 Promise 资源
    }
}

// ============================================================================
// PromisePair - 命令+Promise 对
// 严格翻译自: ValkeyCommand.zig - PromisePair
//   pub const PromisePair = struct {
//       meta: Meta,
//       promise: Promise,
//   };
// ============================================================================

/// 命令+Promise 对 - 用于跟踪哪个命令对应哪个 Promise
/// 对应 Bun Command.PromisePair
public class PromisePair {
    /// 命令元数据
    public var meta: CommandMeta
    /// 关联的 Promise
    public var promise: ValkeyPromise

    public init(meta: CommandMeta, promise: ValkeyPromise) {
        this.meta = meta
        this.promise = promise
    }

    /// 拒绝命令
    /// 对应 Bun Command.PromisePair.rejectCommand()
    public func rejectCommand(globalObject: JsObject, jsvalue: JsValue): Unit {
        promise.reject(globalObject, jsvalue)
    }
}

// ============================================================================
// ToJSOptions - 转换选项
// 严格翻译自: protocol_jsc.zig - ToJSOptions
// ============================================================================

/// RESP 值转 JS 值的选项
public class ToJSOptions {
    public var returnAsBuffer: Bool

    public init() {
        returnAsBuffer = false
    }

    public init(returnAsBuffer: Bool) {
        this.returnAsBuffer = returnAsBuffer
    }
}

// ============================================================================
// ByteBuffer - 字节缓冲区辅助类
// ============================================================================

/// 字节缓冲区 - 用于 RESP 序列化
public class ByteBuffer {
    private var buffer: ArrayList<Byte>

    public init() {
        buffer = ArrayList<Byte>()
    }

    public var size: Int64 {
        buffer.size
    }

    /// 追加字符串
    public func append(s: String): Unit {
        for (b in s.toArray()) {
            buffer.append(b)
        }
    }

    /// 追加字节
    public func append(b: Byte): Unit {
        buffer.append(b)
    }

    /// 转为字节数组
    public func toByteArray(): Array<Byte> {
        buffer.toArray()
    }
}
