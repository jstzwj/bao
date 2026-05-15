// Valkey JS 函数绑定 - Redis 命令的 JavaScript API
// 严格翻译自: bun/src/runtime/valkey_jsc/js_valkey_functions.zig
//   包含所有 Redis 命令的 JS 函数绑定实现
package bao_runtime.valkey

import bao_core.*
import bao_collections.*
import bao_valkey.*

// ============================================================================
// 辅助函数
// 严格翻译自: js_valkey_functions.zig - requireNotSubscriber / requireSubscriber / fromJS
// ============================================================================

/// 要求客户端不是订阅者模式
/// 对应 Bun requireNotSubscriber()
func requireNotSubscriber(client: JSValkeyClient, functionName: String): Unit {
    if (client.isSubscriber()) {
        throw BaoError("RedisClient.prototype.${functionName} cannot be called while in subscriber mode.")
    }
}

/// 要求客户端是订阅者模式
/// 对应 Bun requireSubscriber()
func requireSubscriber(client: JSValkeyClient, functionName: String): Unit {
    if (!client.isSubscriber()) {
        throw BaoError("RedisClient.prototype.${functionName} can only be called while in subscriber mode.")
    }
}

/// 从 JS 值转换为 JSArgument
/// 对应 Bun fromJS()
func jsArgumentFromJS(globalObject: JsObject, value: JsValue): ?JsArgument {
    if (value.valueType == JsValueType.Undefined || value.valueType == JsValueType.Null) {
        None
    } else if (value.valueType == JsValueType.Number) {
        // 数字转为字符串
        Some(JsArgument(value.toString()))
    } else if (value.valueType == JsValueType.String) {
        Some(JsArgument(value.stringValue.toString()))
    } else {
        None
    }
}

// ============================================================================
// ValkeyFunctions - Redis 命令的 JS 函数绑定
// 严格翻译自: js_valkey_functions.zig 中的所有函数
// ============================================================================

/// Redis 命令 JS 函数绑定
/// 对应 Bun js_valkey_functions 中的所有函数
public class ValkeyFunctions {

    // ========================================================================
    // jsSend - 通用命令发送
    // 严格翻译自: js_valkey_functions.zig - jsSend()
    //   pub fn jsSend(this: *JSValkeyClient, globalObject: *jsc.JSGlobalObject,
    //       callframe: *jsc.CallFrame) bun.JSError!JSValue
    // ========================================================================

    /// 通用命令发送
    /// 对应 Bun jsSend()
    public static func jsSend(client: JSValkeyClient, globalObject: JsObject,
                              commandStr: String, argsArray: ArrayList<JsValue>): JsValue {
        let args = ArrayList<JsArgument>()
        for (arg in argsArray) {
            let jsArg = jsArgumentFromJS(globalObject, arg)
            if (jsArg.isSome()) {
                args.append(jsArg.getOrThrow())
            }
        }

        let command = ValkeyCommand(
            commandStr,
            CommandArgs(args),
            CommandMeta()
        )
        command.meta = command.meta.check(command)

        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    // ========================================================================
    // GET / GETBUFFER
    // 严格翻译自: js_valkey_functions.zig - get() / getBuffer()
    // ========================================================================

    /// GET 命令
    /// 对应 Bun get()
    public static func get(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        requireNotSubscriber(client, "get")

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))

        let command = ValkeyCommand("GET", CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    /// GETBUFFER 命令
    /// 对应 Bun getBuffer()
    public static func getBuffer(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        requireNotSubscriber(client, "getBuffer")

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))

        let meta = CommandMeta()
        meta.returnAsBuffer = true

        let command = ValkeyCommand("GET", CommandArgs(args), meta)
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    // ========================================================================
    // SET
    // 严格翻译自: js_valkey_functions.zig - set()
    // ========================================================================

    /// SET 命令
    /// 对应 Bun set()
    public static func set(client: JSValkeyClient, globalObject: JsObject,
                           key: String, value: String, extraArgs: ArrayList<String>): JsValue {
        requireNotSubscriber(client, "set")

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))
        args.append(JsArgument(value))

        for (extra in extraArgs) {
            args.append(JsArgument(extra))
        }

        let command = ValkeyCommand("SET", CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    // ========================================================================
    // INCR / DECR
    // 严格翻译自: js_valkey_functions.zig - incr() / decr()
    // ========================================================================

    /// INCR 命令
    /// 对应 Bun incr()
    public static func incr(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        requireNotSubscriber(client, "incr")

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))

        let command = ValkeyCommand("INCR", CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    /// DECR 命令
    /// 对应 Bun decr()
    public static func decr(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        requireNotSubscriber(client, "decr")

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))

        let command = ValkeyCommand("DECR", CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    // ========================================================================
    // EXISTS
    // 严格翻译自: js_valkey_functions.zig - exists()
    // ========================================================================

    /// EXISTS 命令
    /// 对应 Bun exists()
    public static func exists(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        requireNotSubscriber(client, "exists")

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))

        let meta = CommandMeta()
        meta.returnAsBool = true

        let command = ValkeyCommand("EXISTS", CommandArgs(args), meta)
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    // ========================================================================
    // EXPIRE
    // 严格翻译自: js_valkey_functions.zig - expire()
    // ========================================================================

    /// EXPIRE 命令
    /// 对应 Bun expire()
    public static func expire(client: JSValkeyClient, globalObject: JsObject,
                               key: String, seconds: Int64): JsValue {
        requireNotSubscriber(client, "expire")

        let rawArgs = ArrayList<String>()
        rawArgs.append(key)
        rawArgs.append("${seconds}")

        let command = ValkeyCommand("EXPIRE", CommandArgs(rawArgs))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    // ========================================================================
    // TTL
    // 严格翻译自: js_valkey_functions.zig - ttl()
    // ========================================================================

    /// TTL 命令
    /// 对应 Bun ttl()
    public static func ttl(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        requireNotSubscriber(client, "ttl")

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))

        let command = ValkeyCommand("TTL", CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    // ========================================================================
    // SADD / SREM / SMEMBERS / SPOP / SRANDMEMBER / SISMEMBER
    // 严格翻译自: js_valkey_functions.zig - sadd/srem/smembers/spop/srandmember/sismember
    // ========================================================================

    /// SADD 命令
    /// 对应 Bun sadd()
    public static func sadd(client: JSValkeyClient, globalObject: JsObject,
                            key: String, members: ArrayList<String>): JsValue {
        requireNotSubscriber(client, "sadd")

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))
        for (member in members) {
            args.append(JsArgument(member))
        }

        let command = ValkeyCommand("SADD", CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    /// SREM 命令
    /// 对应 Bun srem()
    public static func srem(client: JSValkeyClient, globalObject: JsObject,
                            key: String, members: ArrayList<String>): JsValue {
        requireNotSubscriber(client, "srem")

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))
        for (member in members) {
            args.append(JsArgument(member))
        }

        let command = ValkeyCommand("SREM", CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    /// SMEMBERS 命令
    /// 对应 Bun smembers()
    public static func smembers(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        requireNotSubscriber(client, "smembers")

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))

        let command = ValkeyCommand("SMEMBERS", CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    /// SPOP 命令
    /// 对应 Bun spop()
    public static func spop(client: JSValkeyClient, globalObject: JsObject,
                            key: String, count: ?Int64): JsValue {
        requireNotSubscriber(client, "spop")

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))
        if (count.isSome()) {
            args.append(JsArgument("${count.getOrThrow()}"))
        }

        let command = ValkeyCommand("SPOP", CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    /// SRANDMEMBER 命令
    /// 对应 Bun srandmember()
    public static func srandmember(client: JSValkeyClient, globalObject: JsObject,
                                   key: String, count: ?Int64): JsValue {
        requireNotSubscriber(client, "srandmember")

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))
        if (count.isSome()) {
            args.append(JsArgument("${count.getOrThrow()}"))
        }

        let command = ValkeyCommand("SRANDMEMBER", CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    /// SISMEMBER 命令
    /// 对应 Bun sismember()
    public static func sismember(client: JSValkeyClient, globalObject: JsObject,
                                 key: String, member: String): JsValue {
        requireNotSubscriber(client, "sismember")

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))
        args.append(JsArgument(member))

        let meta = CommandMeta()
        meta.returnAsBool = true

        let command = ValkeyCommand("SISMEMBER", CommandArgs(args), meta)
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    // ========================================================================
    // HSET / HMSET / HGET / HDEL / HEXISTS / HSETNX / HMGET
    // 严格翻译自: js_valkey_functions.zig - hset/hmset/hget/hdel/hexists/hsetnx/hmget
    // ========================================================================

    /// HSET 命令
    /// 对应 Bun hset()
    public static func hset(client: JSValkeyClient, globalObject: JsObject,
                            key: String, fieldValuePairs: ArrayList<String>): JsValue {
        requireNotSubscriber(client, "hset")

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))
        for (fv in fieldValuePairs) {
            args.append(JsArgument(fv))
        }

        let command = ValkeyCommand("HSET", CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    /// HMSET 命令
    /// 对应 Bun hmset()
    public static func hmset(client: JSValkeyClient, globalObject: JsObject,
                             key: String, fieldValuePairs: ArrayList<String>): JsValue {
        requireNotSubscriber(client, "hmset")

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))
        for (fv in fieldValuePairs) {
            args.append(JsArgument(fv))
        }

        let command = ValkeyCommand("HMSET", CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    /// HGET 命令 - 对应 compile.@"(key: RedisKey, value: RedisValue)"("hget", "HGET", ...)
    public static func hget(client: JSValkeyClient, globalObject: JsObject,
                            key: String, field: String): JsValue {
        requireNotSubscriber(client, "hget")

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))
        args.append(JsArgument(field))

        let command = ValkeyCommand("HGET", CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    /// HDEL 命令 - 对应 compile.@"(key: RedisKey, ...args: RedisKey[])"
    public static func hdel(client: JSValkeyClient, globalObject: JsObject,
                            key: String, fields: ArrayList<String>): JsValue {
        requireNotSubscriber(client, "hdel")

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))
        for (field in fields) {
            args.append(JsArgument(field))
        }

        let command = ValkeyCommand("HDEL", CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    /// HEXISTS 命令
    /// 对应 Bun hexists()
    public static func hexists(client: JSValkeyClient, globalObject: JsObject,
                               key: String, field: String): JsValue {
        requireNotSubscriber(client, "hexists")

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))
        args.append(JsArgument(field))

        let meta = CommandMeta()
        meta.returnAsBool = true

        let command = ValkeyCommand("HEXISTS", CommandArgs(args), meta)
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    /// HSETNX 命令
    /// 对应 Bun hsetnx()
    public static func hsetnx(client: JSValkeyClient, globalObject: JsObject,
                              key: String, field: String, value: String): JsValue {
        requireNotSubscriber(client, "hsetnx")

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))
        args.append(JsArgument(field))
        args.append(JsArgument(value))

        let meta = CommandMeta()
        meta.returnAsBool = true

        let command = ValkeyCommand("HSETNX", CommandArgs(args), meta)
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    /// HMGET 命令
    /// 对应 Bun hmget()
    public static func hmget(client: JSValkeyClient, globalObject: JsObject,
                             key: String, fields: ArrayList<String>): JsValue {
        requireNotSubscriber(client, "hmget")

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))
        for (field in fields) {
            args.append(JsArgument(field))
        }

        let command = ValkeyCommand("HMGET", CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    /// HINCRBY 命令
    /// 对应 Bun hincrby()
    public static func hincrby(client: JSValkeyClient, globalObject: JsObject,
                               key: String, field: String, increment: String): JsValue {
        requireNotSubscriber(client, "hincrby")

        let rawArgs = ArrayList<String>()
        rawArgs.append(key)
        rawArgs.append(field)
        rawArgs.append(increment)

        let command = ValkeyCommand("HINCRBY", CommandArgs(rawArgs))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    /// HINCRBYFLOAT 命令
    /// 对应 Bun hincrbyfloat()
    public static func hincrbyfloat(client: JSValkeyClient, globalObject: JsObject,
                                    key: String, field: String, increment: String): JsValue {
        requireNotSubscriber(client, "hincrbyfloat")

        let rawArgs = ArrayList<String>()
        rawArgs.append(key)
        rawArgs.append(field)
        rawArgs.append(increment)

        let command = ValkeyCommand("HINCRBYFLOAT", CommandArgs(rawArgs))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    // ========================================================================
    // PING
    // 严格翻译自: js_valkey_functions.zig - ping()
    // ========================================================================

    /// PING 命令
    /// 对应 Bun ping()
    public static func ping(client: JSValkeyClient, globalObject: JsObject,
                            message: ?String): JsValue {
        let args = ArrayList<JsArgument>()
        if (message.isSome()) {
            args.append(JsArgument(message.getOrThrow()))
        }

        let command = ValkeyCommand("PING", CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    // ========================================================================
    // PUBLISH / SUBSCRIBE / UNSUBSCRIBE
    // 严格翻译自: js_valkey_functions.zig - publish/subscribe/unsubscribe
    // ========================================================================

    /// PUBLISH 命令
    /// 对应 Bun publish()
    public static func publish(client: JSValkeyClient, globalObject: JsObject,
                               channel: String, message: String): JsValue {
        requireNotSubscriber(client, "publish")

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(channel))
        args.append(JsArgument(message))

        let command = ValkeyCommand("PUBLISH", CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    /// SUBSCRIBE 命令
    /// 对应 Bun subscribe()
    public static func subscribe(client: JSValkeyClient, globalObject: JsObject,
                                 channels: ArrayList<String>, handler: JsValue): JsValue {
        let args = ArrayList<JsArgument>()
        for (channel in channels) {
            args.append(JsArgument(channel))
            // 添加接收处理器
            client.subscriptionCtx.upsertReceiveHandler(channel, handler)
        }

        let meta = CommandMeta()
        meta.subscriptionRequest = true

        let command = ValkeyCommand("SUBSCRIBE", CommandArgs(args), meta)
        let promise = client.send(globalObject, command)

        // 如果发送失败，清理处理器
        JsValue(JsValueType.Promise)
    }

    /// UNSUBSCRIBE 命令
    /// 对应 Bun unsubscribe()
    public static func unsubscribe(client: JSValkeyClient, globalObject: JsObject,
                                   channels: ArrayList<String>): JsValue {
        requireSubscriber(client, "unsubscribe")

        let args = ArrayList<JsArgument>()
        for (channel in channels) {
            args.append(JsArgument(channel))
            // 清除指定频道的处理器
            client.subscriptionCtx.clearReceiveHandlers(channel)
        }

        if (channels.size == 0) {
            client.subscriptionCtx.clearAllReceiveHandlers()
        }

        let command = ValkeyCommand("UNSUBSCRIBE", CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    // ========================================================================
    // DUPLICATE
    // 严格翻译自: js_valkey_functions.zig - duplicate()
    // ========================================================================

    /// DUPLICATE 命令 - 克隆客户端
    /// 对应 Bun duplicate()
    public static func duplicate(client: JSValkeyClient, globalObject: JsObject): JsValue {
        let newClient = client.cloneWithoutConnecting(globalObject)

        // 如果原始客户端已连接且未手动关闭，开始连接新客户端
        if (client.client.status == ConnectionStatus.Connected &&
            !client.client.flags.isManuallyClosed) {
            newClient.client.flags.connectionPromiseReturnsClient = true
            newClient.doConnect()
        }

        JsValue.UNDEFINED
    }

    // ========================================================================
    // 通用单键命令
    // 严格翻译自: compile 模板函数
    //   pub fn @"(key: RedisKey)"(name, command, arg0_name, client_state_requirement)
    // ========================================================================

    /// 通用单键命令 - 对应 compile.@"(key: RedisKey)"
    public static func singleKeyCommand(client: JSValkeyClient, globalObject: JsObject,
                                         commandName: String, key: String,
                                         requireNotSub: Bool): JsValue {
        if (requireNotSub) { requireNotSubscriber(client, commandName) }

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))

        let command = ValkeyCommand(commandName, CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    // ========================================================================
    // 通用键+值命令
    // 严格翻译自: compile.@"(key: RedisKey, value: RedisValue)"
    // ========================================================================

    /// 通用键+值命令 - 对应 compile.@"(key: RedisKey, value: RedisValue)"
    public static func keyValueCommand(client: JSValkeyClient, globalObject: JsObject,
                                        commandName: String, key: String, value: String,
                                        requireNotSub: Bool): JsValue {
        if (requireNotSub) { requireNotSubscriber(client, commandName) }

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))
        args.append(JsArgument(value))

        let command = ValkeyCommand(commandName, CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    // ========================================================================
    // 通用键+值+值命令
    // 严格翻译自: compile.@"(key: RedisKey, value: RedisValue, value2: RedisValue)"
    // ========================================================================

    /// 通用键+值+值命令 - 对应 compile.@"(key: RedisKey, value: RedisValue, value2: RedisValue)"
    public static func keyValueValueCommand(client: JSValkeyClient, globalObject: JsObject,
                                             commandName: String,
                                             key: String, value1: String, value2: String,
                                             requireNotSub: Bool): JsValue {
        if (requireNotSub) { requireNotSubscriber(client, commandName) }

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))
        args.append(JsArgument(value1))
        args.append(JsArgument(value2))

        let command = ValkeyCommand(commandName, CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    // ========================================================================
    // 通用字符串数组命令
    // 严格翻译自: compile.@"(...strings: string[])"
    // ========================================================================

    /// 通用字符串数组命令 - 对应 compile.@"(...strings: string[])"
    public static func stringArrayCommand(client: JSValkeyClient, globalObject: JsObject,
                                           commandName: String, args: ArrayList<String>,
                                           requireNotSub: Bool): JsValue {
        if (requireNotSub) { requireNotSubscriber(client, commandName) }

        let jsArgs = ArrayList<JsArgument>()
        for (arg in args) {
            jsArgs.append(JsArgument(arg))
        }

        let command = ValkeyCommand(commandName, CommandArgs(jsArgs))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    // ========================================================================
    // 通用键+可变参数命令
    // 严格翻译自: compile.@"(key: RedisKey, ...args: RedisKey[])"
    // ========================================================================

    /// 通用键+可变参数命令 - 对应 compile.@"(key: RedisKey, ...args: RedisKey[])"
    public static func keyVariadicCommand(client: JSValkeyClient, globalObject: JsObject,
                                           commandName: String, key: String,
                                           extraArgs: ArrayList<String>,
                                           requireNotSub: Bool): JsValue {
        if (requireNotSub) { requireNotSubscriber(client, commandName) }

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))
        for (extra in extraArgs) {
            args.append(JsArgument(extra))
        }

        let command = ValkeyCommand(commandName, CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    // ========================================================================
    // 通用键+值+可变参数命令
    // 严格翻译自: compile.@"(key: RedisKey, value: RedisValue, ...args: RedisValue)"
    // ========================================================================

    /// 通用键+值+可变参数命令 - 对应 compile.@"(key: RedisKey, value: RedisValue, ...args: RedisValue)"
    public static func keyValueVariadicCommand(client: JSValkeyClient, globalObject: JsObject,
                                                commandName: String,
                                                key: String, value: String,
                                                extraArgs: ArrayList<String>,
                                                requireNotSub: Bool): JsValue {
        if (requireNotSub) { requireNotSubscriber(client, commandName) }

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(key))
        args.append(JsArgument(value))
        for (extra in extraArgs) {
            args.append(JsArgument(extra))
        }

        let command = ValkeyCommand(commandName, CommandArgs(args))
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    // ========================================================================
    // SMOVE 命令
    // 严格翻译自: js_valkey_functions.zig - smove()
    // ========================================================================

    /// SMOVE 命令
    /// 对应 Bun smove()
    public static func smove(client: JSValkeyClient, globalObject: JsObject,
                             source: String, destination: String, member: String): JsValue {
        requireNotSubscriber(client, "smove")

        let args = ArrayList<JsArgument>()
        args.append(JsArgument(source))
        args.append(JsArgument(destination))
        args.append(JsArgument(member))

        let meta = CommandMeta()
        meta.returnAsBool = true

        let command = ValkeyCommand("SMOVE", CommandArgs(args), meta)
        let promise = client.send(globalObject, command)
        JsValue(JsValueType.Promise)
    }

    // ========================================================================
    // 以下为所有通过 compile 模板生成的命令的包装方法
    // 严格翻译自: js_valkey_functions.zig 中的所有 pub const = compile.xxx
    // ========================================================================

    // -- 单键命令 (compile.@"(key: RedisKey)") --
    // bitcount, dump, expiretime, getdel, hgetall, hkeys, hlen, hvals,
    // keys, llen, persist, pexpiretime, pttl, randomkey, scard, strlen,
    // zcard

    public static func bitcount(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        singleKeyCommand(client, globalObject, "bitcount", key, true)
    }

    public static func dump(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        singleKeyCommand(client, globalObject, "dump", key, true)
    }

    public static func expiretime(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        singleKeyCommand(client, globalObject, "expiretime", key, true)
    }

    public static func getdel(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        singleKeyCommand(client, globalObject, "getdel", key, true)
    }

    public static func hgetall(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        singleKeyCommand(client, globalObject, "hgetall", key, true)
    }

    public static func hkeys(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        singleKeyCommand(client, globalObject, "hkeys", key, true)
    }

    public static func hlen(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        singleKeyCommand(client, globalObject, "hlen", key, true)
    }

    public static func hvals(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        singleKeyCommand(client, globalObject, "hvals", key, true)
    }

    public static func keys(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        singleKeyCommand(client, globalObject, "keys", key, true)
    }

    public static func llen(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        singleKeyCommand(client, globalObject, "llen", key, true)
    }

    public static func persist(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        singleKeyCommand(client, globalObject, "persist", key, true)
    }

    public static func pexpiretime(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        singleKeyCommand(client, globalObject, "pexpiretime", key, true)
    }

    public static func pttl(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        singleKeyCommand(client, globalObject, "pttl", key, true)
    }

    public static func randomkey(client: JSValkeyClient, globalObject: JsObject): JsValue {
        // compile.@"()"("randomkey", "RANDOMKEY", .not_subscriber).call
        stringArrayCommand(client, globalObject, "RANDOMKEY", ArrayList<String>(), true)
    }

    public static func scard(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        singleKeyCommand(client, globalObject, "scard", key, true)
    }

    public static func strlen(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        singleKeyCommand(client, globalObject, "strlen", key, true)
    }

    public static func zcard(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        singleKeyCommand(client, globalObject, "zcard", key, true)
    }

    public static func typeCommand(client: JSValkeyClient, globalObject: JsObject, key: String): JsValue {
        singleKeyCommand(client, globalObject, "type", key, true)
    }

    // -- 键+值命令 (compile.@"(key: RedisKey, value: RedisValue)") --
    // getbit, setbit, expireat, getex, hget, incrby, incrbyfloat, decrby,
    // pfadd, rpoplpush, zscore, hstrlen

    public static func getbit(client: JSValkeyClient, globalObject: JsObject,
                              key: String, offset: String): JsValue {
        keyValueCommand(client, globalObject, "GETBIT", key, offset, true)
    }

    public static func setbit(client: JSValkeyClient, globalObject: JsObject,
                              key: String, offset: String, value: String): JsValue {
        keyValueValueCommand(client, globalObject, "SETBIT", key, offset, value, true)
    }

    public static func expireat(client: JSValkeyClient, globalObject: JsObject,
                                key: String, timestamp: String): JsValue {
        keyValueCommand(client, globalObject, "EXPIREAT", key, timestamp, true)
    }

    public static func hget(client: JSValkeyClient, globalObject: JsObject,
                            key: String, field: String): JsValue {
        keyValueCommand(client, globalObject, "HGET", key, field, true)
    }

    public static func incrby(client: JSValkeyClient, globalObject: JsObject,
                              key: String, increment: String): JsValue {
        keyValueCommand(client, globalObject, "INCRBY", key, increment, true)
    }

    public static func incrbyfloat(client: JSValkeyClient, globalObject: JsObject,
                                   key: String, increment: String): JsValue {
        keyValueCommand(client, globalObject, "INCRBYFLOAT", key, increment, true)
    }

    public static func decrby(client: JSValkeyClient, globalObject: JsObject,
                              key: String, decrement: String): JsValue {
        keyValueCommand(client, globalObject, "DECRBY", key, decrement, true)
    }

    public static func pfadd(client: JSValkeyClient, globalObject: JsObject,
                             key: String, value: String): JsValue {
        keyValueCommand(client, globalObject, "PFADD", key, value, true)
    }

    public static func rpoplpush(client: JSValkeyClient, globalObject: JsObject,
                                 source: String, destination: String): JsValue {
        keyValueCommand(client, globalObject, "RPOPLPUSH", source, destination, true)
    }

    public static func zscore(client: JSValkeyClient, globalObject: JsObject,
                              key: String, member: String): JsValue {
        keyValueCommand(client, globalObject, "ZSCORE", key, member, true)
    }

    public static func hstrlen(client: JSValkeyClient, globalObject: JsObject,
                               key: String, field: String): JsValue {
        keyValueCommand(client, globalObject, "HSTRLEN", key, field, true)
    }

    public static func append(client: JSValkeyClient, globalObject: JsObject,
                              key: String, value: String): JsValue {
        keyValueCommand(client, globalObject, "APPEND", key, value, true)
    }

    public static func getset(client: JSValkeyClient, globalObject: JsObject,
                              key: String, value: String): JsValue {
        keyValueCommand(client, globalObject, "GETSET", key, value, true)
    }

    public static func rename(client: JSValkeyClient, globalObject: JsObject,
                              key: String, newkey: String): JsValue {
        keyValueCommand(client, globalObject, "RENAME", key, newkey, true)
    }

    public static func renamenx(client: JSValkeyClient, globalObject: JsObject,
                                key: String, newkey: String): JsValue {
        keyValueCommand(client, globalObject, "RENAMENX", key, newkey, true)
    }

    public static func pexpire(client: JSValkeyClient, globalObject: JsObject,
                               key: String, ms: String): JsValue {
        keyValueCommand(client, globalObject, "PEXPIRE", key, ms, true)
    }

    public static func pexpireat(client: JSValkeyClient, globalObject: JsObject,
                                 key: String, msTimestamp: String): JsValue {
        keyValueCommand(client, globalObject, "PEXPIREAT", key, msTimestamp, true)
    }

    // -- 键+值+值命令 (compile.@"(key: RedisKey, value: RedisValue, value2: RedisValue)") --
    // getrange, setrange, lindex, lrange, lrem, lset, ltrim,
    // zcount, zlexcount, setex, psetex, zincrby,
    // zremrangebylex, zremrangebyrank, zremrangebyscore

    public static func getrange(client: JSValkeyClient, globalObject: JsObject,
                                key: String, start: String, end: String): JsValue {
        keyValueValueCommand(client, globalObject, "GETRANGE", key, start, end, true)
    }

    public static func setrange(client: JSValkeyClient, globalObject: JsObject,
                                key: String, offset: String, value: String): JsValue {
        keyValueValueCommand(client, globalObject, "SETRANGE", key, offset, value, true)
    }

    public static func lindex(client: JSValkeyClient, globalObject: JsObject,
                              key: String, index: String): JsValue {
        keyValueCommand(client, globalObject, "LINDEX", key, index, true)
    }

    public static func lrange(client: JSValkeyClient, globalObject: JsObject,
                              key: String, start: String, stop: String): JsValue {
        keyValueValueCommand(client, globalObject, "LRANGE", key, start, stop, true)
    }

    public static func lrem(client: JSValkeyClient, globalObject: JsObject,
                            key: String, count: String, element: String): JsValue {
        keyValueValueCommand(client, globalObject, "LREM", key, count, element, true)
    }

    public static func lset(client: JSValkeyClient, globalObject: JsObject,
                            key: String, index: String, element: String): JsValue {
        keyValueValueCommand(client, globalObject, "LSET", key, index, element, true)
    }

    public static func ltrim(client: JSValkeyClient, globalObject: JsObject,
                             key: String, start: String, stop: String): JsValue {
        keyValueValueCommand(client, globalObject, "LTRIM", key, start, stop, true)
    }

    public static func zcount(client: JSValkeyClient, globalObject: JsObject,
                              key: String, min: String, max: String): JsValue {
        keyValueValueCommand(client, globalObject, "ZCOUNT", key, min, max, true)
    }

    public static func zlexcount(client: JSValkeyClient, globalObject: JsObject,
                                 key: String, min: String, max: String): JsValue {
        keyValueValueCommand(client, globalObject, "ZLEXCOUNT", key, min, max, true)
    }

    public static func setex(client: JSValkeyClient, globalObject: JsObject,
                             key: String, seconds: String, value: String): JsValue {
        keyValueValueCommand(client, globalObject, "SETEX", key, seconds, value, true)
    }

    public static func psetex(client: JSValkeyClient, globalObject: JsObject,
                              key: String, ms: String, value: String): JsValue {
        keyValueValueCommand(client, globalObject, "PSETEX", key, ms, value, true)
    }

    public static func zincrby(client: JSValkeyClient, globalObject: JsObject,
                               key: String, increment: String, member: String): JsValue {
        keyValueValueCommand(client, globalObject, "ZINCRBY", key, increment, member, true)
    }

    public static func zremrangebylex(client: JSValkeyClient, globalObject: JsObject,
                                      key: String, min: String, max: String): JsValue {
        keyValueValueCommand(client, globalObject, "ZREMRANGEBYLEX", key, min, max, true)
    }

    public static func zremrangebyrank(client: JSValkeyClient, globalObject: JsObject,
                                       key: String, start: String, stop: String): JsValue {
        keyValueValueCommand(client, globalObject, "ZREMRANGEBYRANK", key, start, stop, true)
    }

    public static func zremrangebyscore(client: JSValkeyClient, globalObject: JsObject,
                                        key: String, min: String, max: String): JsValue {
        keyValueValueCommand(client, globalObject, "ZREMRANGEBYSCORE", key, min, max, true)
    }

    public static func substr(client: JSValkeyClient, globalObject: JsObject,
                              key: String, start: String, end: String): JsValue {
        keyValueValueCommand(client, globalObject, "SUBSTR", key, start, end, true)
    }

    public static func blmove(client: JSValkeyClient, globalObject: JsObject,
                              args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "BLMOVE", args, true)
    }

    public static func brpoplpush(client: JSValkeyClient, globalObject: JsObject,
                                  source: String, destination: String, timeout: String): JsValue {
        keyValueValueCommand(client, globalObject, "BRPOPLPUSH", source, destination, timeout, true)
    }

    // -- 键+可变参数命令 (compile.@"(key: RedisKey, ...args: RedisKey[])") --
    // del, mget, lpop, rpop, zpopmax, zpopmin, zrandmember,
    // zrem, zrank, zrevrank

    public static func del(client: JSValkeyClient, globalObject: JsObject,
                           key: String, extraArgs: ArrayList<String>): JsValue {
        keyVariadicCommand(client, globalObject, "DEL", key, extraArgs, true)
    }

    public static func mget(client: JSValkeyClient, globalObject: JsObject,
                            key: String, extraArgs: ArrayList<String>): JsValue {
        keyVariadicCommand(client, globalObject, "MGET", key, extraArgs, true)
    }

    public static func lpop(client: JSValkeyClient, globalObject: JsObject,
                            key: String, extraArgs: ArrayList<String>): JsValue {
        keyVariadicCommand(client, globalObject, "LPOP", key, extraArgs, true)
    }

    public static func rpop(client: JSValkeyClient, globalObject: JsObject,
                            key: String, extraArgs: ArrayList<String>): JsValue {
        keyVariadicCommand(client, globalObject, "RPOP", key, extraArgs, true)
    }

    public static func zpopmax(client: JSValkeyClient, globalObject: JsObject,
                               key: String, extraArgs: ArrayList<String>): JsValue {
        keyVariadicCommand(client, globalObject, "ZPOPMAX", key, extraArgs, true)
    }

    public static func zpopmin(client: JSValkeyClient, globalObject: JsObject,
                               key: String, extraArgs: ArrayList<String>): JsValue {
        keyVariadicCommand(client, globalObject, "ZPOPMIN", key, extraArgs, true)
    }

    public static func zrandmember(client: JSValkeyClient, globalObject: JsObject,
                                   key: String, extraArgs: ArrayList<String>): JsValue {
        keyVariadicCommand(client, globalObject, "ZRANDMEMBER", key, extraArgs, true)
    }

    public static func zrem(client: JSValkeyClient, globalObject: JsObject,
                            key: String, extraArgs: ArrayList<String>): JsValue {
        keyVariadicCommand(client, globalObject, "ZREM", key, extraArgs, true)
    }

    public static func zrank(client: JSValkeyClient, globalObject: JsObject,
                             key: String, extraArgs: ArrayList<String>): JsValue {
        keyVariadicCommand(client, globalObject, "ZRANK", key, extraArgs, true)
    }

    public static func zrevrank(client: JSValkeyClient, globalObject: JsObject,
                                key: String, extraArgs: ArrayList<String>): JsValue {
        keyVariadicCommand(client, globalObject, "ZREVRANK", key, extraArgs, true)
    }

    public static func unlink(client: JSValkeyClient, globalObject: JsObject,
                              key: String, extraArgs: ArrayList<String>): JsValue {
        keyVariadicCommand(client, globalObject, "UNLINK", key, extraArgs, true)
    }

    public static func touch(client: JSValkeyClient, globalObject: JsObject,
                             key: String, extraArgs: ArrayList<String>): JsValue {
        keyVariadicCommand(client, globalObject, "TOUCH", key, extraArgs, true)
    }

    public static func zrangebylex(client: JSValkeyClient, globalObject: JsObject,
                                   key: String, extraArgs: ArrayList<String>): JsValue {
        keyVariadicCommand(client, globalObject, "ZRANGEBYLEX", key, extraArgs, true)
    }

    public static func zrevrangebylex(client: JSValkeyClient, globalObject: JsObject,
                                      key: String, extraArgs: ArrayList<String>): JsValue {
        keyVariadicCommand(client, globalObject, "ZREVRANGEBYLEX", key, extraArgs, true)
    }

    // -- 键+值+可变参数命令 (compile.@"(key: RedisKey, value: RedisValue, ...args: RedisValue)") --
    // lpush, lpushx, rpush, rpushx, zmscore, setnx

    public static func lpush(client: JSValkeyClient, globalObject: JsObject,
                             key: String, value: String, extraArgs: ArrayList<String>): JsValue {
        keyValueVariadicCommand(client, globalObject, "LPUSH", key, value, extraArgs, true)
    }

    public static func lpushx(client: JSValkeyClient, globalObject: JsObject,
                              key: String, value: String, extraArgs: ArrayList<String>): JsValue {
        keyValueVariadicCommand(client, globalObject, "LPUSHX", key, value, extraArgs, true)
    }

    public static func rpush(client: JSValkeyClient, globalObject: JsObject,
                             key: String, value: String, extraArgs: ArrayList<String>): JsValue {
        keyValueVariadicCommand(client, globalObject, "RPUSH", key, value, extraArgs, true)
    }

    public static func rpushx(client: JSValkeyClient, globalObject: JsObject,
                              key: String, value: String, extraArgs: ArrayList<String>): JsValue {
        keyValueVariadicCommand(client, globalObject, "RPUSHX", key, value, extraArgs, true)
    }

    public static func zmscore(client: JSValkeyClient, globalObject: JsObject,
                               args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "ZMSCORE", args, true)
    }

    public static func setnx(client: JSValkeyClient, globalObject: JsObject,
                             key: String, value: String): JsValue {
        keyValueCommand(client, globalObject, "SETNX", key, value, true)
    }

    // -- 字符串数组命令 (compile.@"(...strings: string[])" --
    // blpop, brpop, zrange, zrevrange, zrangebyscore, zrevrangebyscore,
    // mset, msetnx, script, select, spublish,
    // sdiff, sdiffstore, sinter, sintercard, sinterstore,
    // smismember, sscan, sunion, sunionstore,
    // zadd, zscan, zdiff, zdiffstore, zinter, zintercard,
    // zinterstore, zunion, zunionstore, zmpop, bzmpop,
    // bzpopmin, bzpopmax, blmpop,
    // psubscribe, punsubscribe, pubsub, copy, hrandfield,
    // hscan, hgetdel, hgetex, hsetex, hexpire, hexpireat,
    // hexpiretime, hpersist, hpexpire, hpexpireat, hpexpiretime,
    // hpttl, httl, linsert, lmove, lmpop, lpos, getex, scan,
    // zrangestore, lmpop

    public static func blpop(client: JSValkeyClient, globalObject: JsObject,
                             args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "BLPOP", args, true)
    }

    public static func brpop(client: JSValkeyClient, globalObject: JsObject,
                             args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "BRPOP", args, true)
    }

    public static func zrange(client: JSValkeyClient, globalObject: JsObject,
                              args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "ZRANGE", args, true)
    }

    public static func zrevrange(client: JSValkeyClient, globalObject: JsObject,
                                 args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "ZREVRANGE", args, true)
    }

    public static func zrangebyscore(client: JSValkeyClient, globalObject: JsObject,
                                     args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "ZRANGEBYSCORE", args, true)
    }

    public static func zrevrangebyscore(client: JSValkeyClient, globalObject: JsObject,
                                        args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "ZREVRANGEBYSCORE", args, true)
    }

    public static func mset(client: JSValkeyClient, globalObject: JsObject,
                            args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "MSET", args, true)
    }

    public static func msetnx(client: JSValkeyClient, globalObject: JsObject,
                              args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "MSETNX", args, true)
    }

    public static func script(client: JSValkeyClient, globalObject: JsObject,
                              args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "SCRIPT", args, true)
    }

    public static func select(client: JSValkeyClient, globalObject: JsObject,
                              args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "SELECT", args, true)
    }

    public static func spublish(client: JSValkeyClient, globalObject: JsObject,
                                channel: String, message: String): JsValue {
        keyValueCommand(client, globalObject, "SPUBLISH", channel, message, true)
    }

    public static func sdiff(client: JSValkeyClient, globalObject: JsObject,
                             args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "SDIFF", args, true)
    }

    public static func sdiffstore(client: JSValkeyClient, globalObject: JsObject,
                                  args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "SDIFFSTORE", args, true)
    }

    public static func sinter(client: JSValkeyClient, globalObject: JsObject,
                              args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "SINTER", args, true)
    }

    public static func sintercard(client: JSValkeyClient, globalObject: JsObject,
                                  args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "SINTERCARD", args, true)
    }

    public static func sinterstore(client: JSValkeyClient, globalObject: JsObject,
                                   args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "SINTERSTORE", args, true)
    }

    public static func smismember(client: JSValkeyClient, globalObject: JsObject,
                                  args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "SMISMEMBER", args, true)
    }

    public static func sscan(client: JSValkeyClient, globalObject: JsObject,
                             args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "SSCAN", args, true)
    }

    public static func sunion(client: JSValkeyClient, globalObject: JsObject,
                              args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "SUNION", args, true)
    }

    public static func sunionstore(client: JSValkeyClient, globalObject: JsObject,
                                   args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "SUNIONSTORE", args, true)
    }

    public static func zadd(client: JSValkeyClient, globalObject: JsObject,
                            args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "ZADD", args, true)
    }

    public static func zscan(client: JSValkeyClient, globalObject: JsObject,
                             args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "ZSCAN", args, true)
    }

    public static func zdiff(client: JSValkeyClient, globalObject: JsObject,
                             args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "ZDIFF", args, true)
    }

    public static func zdiffstore(client: JSValkeyClient, globalObject: JsObject,
                                  args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "ZDIFFSTORE", args, true)
    }

    public static func zinter(client: JSValkeyClient, globalObject: JsObject,
                              args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "ZINTER", args, true)
    }

    public static func zintercard(client: JSValkeyClient, globalObject: JsObject,
                                  args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "ZINTERCARD", args, true)
    }

    public static func zinterstore(client: JSValkeyClient, globalObject: JsObject,
                                   args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "ZINTERSTORE", args, true)
    }

    public static func zunion(client: JSValkeyClient, globalObject: JsObject,
                              args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "ZUNION", args, true)
    }

    public static func zunionstore(client: JSValkeyClient, globalObject: JsObject,
                                   args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "ZUNIONSTORE", args, true)
    }

    public static func zmpop(client: JSValkeyClient, globalObject: JsObject,
                             args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "ZMPOP", args, true)
    }

    public static func bzmpop(client: JSValkeyClient, globalObject: JsObject,
                              args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "BZMPOP", args, true)
    }

    public static func bzpopmin(client: JSValkeyClient, globalObject: JsObject,
                                args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "BZPOPMIN", args, true)
    }

    public static func bzpopmax(client: JSValkeyClient, globalObject: JsObject,
                                args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "BZPOPMAX", args, true)
    }

    public static func blmpop(client: JSValkeyClient, globalObject: JsObject,
                              args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "BLMPOP", args, true)
    }

    // 订阅相关命令 (dont_care 状态要求)
    public static func psubscribe(client: JSValkeyClient, globalObject: JsObject,
                                  args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "PSUBSCRIBE", args, false)
    }

    public static func punsubscribe(client: JSValkeyClient, globalObject: JsObject,
                                    args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "PUNSUBSCRIBE", args, false)
    }

    public static func pubsub(client: JSValkeyClient, globalObject: JsObject,
                              args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "PUBSUB", args, false)
    }

    // Hash 相关扩展命令
    public static func hrandfield(client: JSValkeyClient, globalObject: JsObject,
                                  args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "HRANDFIELD", args, true)
    }

    public static func hscan(client: JSValkeyClient, globalObject: JsObject,
                             args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "HSCAN", args, true)
    }

    public static func hgetdel(client: JSValkeyClient, globalObject: JsObject,
                               args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "HGETDEL", args, true)
    }

    public static func hgetex(client: JSValkeyClient, globalObject: JsObject,
                              args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "HGETEX", args, true)
    }

    public static func hsetex(client: JSValkeyClient, globalObject: JsObject,
                              args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "HSETEX", args, true)
    }

    public static func hexpire(client: JSValkeyClient, globalObject: JsObject,
                               args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "HEXPIRE", args, true)
    }

    public static func hexpireat(client: JSValkeyClient, globalObject: JsObject,
                                 args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "HEXPIREAT", args, true)
    }

    public static func hexpiretime(client: JSValkeyClient, globalObject: JsObject,
                                   args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "HEXPIRETIME", args, true)
    }

    public static func hpersist(client: JSValkeyClient, globalObject: JsObject,
                                args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "HPERSIST", args, true)
    }

    public static func hpexpire(client: JSValkeyClient, globalObject: JsObject,
                                args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "HPEXPIRE", args, true)
    }

    public static func hpexpireat(client: JSValkeyClient, globalObject: JsObject,
                                  args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "HPEXPIREAT", args, true)
    }

    public static func hpexpiretime(client: JSValkeyClient, globalObject: JsObject,
                                    args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "HPEXPIRETIME", args, true)
    }

    public static func hpttl(client: JSValkeyClient, globalObject: JsObject,
                             args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "HPTTL", args, true)
    }

    public static func httl(client: JSValkeyClient, globalObject: JsObject,
                            args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "HTTL", args, true)
    }

    // List 相关命令
    public static func linsert(client: JSValkeyClient, globalObject: JsObject,
                               args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "LINSERT", args, true)
    }

    public static func lmove(client: JSValkeyClient, globalObject: JsObject,
                             args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "LMOVE", args, true)
    }

    public static func lmpop(client: JSValkeyClient, globalObject: JsObject,
                             args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "LMPOP", args, true)
    }

    public static func lpos(client: JSValkeyClient, globalObject: JsObject,
                            args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "LPOS", args, true)
    }

    public static func getex(client: JSValkeyClient, globalObject: JsObject,
                             args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "GETEX", args, true)
    }

    public static func scan(client: JSValkeyClient, globalObject: JsObject,
                            args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "SCAN", args, true)
    }

    public static func zrangestore(client: JSValkeyClient, globalObject: JsObject,
                                   args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "ZRANGESTORE", args, true)
    }

    public static func copy(client: JSValkeyClient, globalObject: JsObject,
                            args: ArrayList<String>): JsValue {
        stringArrayCommand(client, globalObject, "COPY", args, true)
    }
}
