// RESP 协议 JSC 层 - RESP 值到 JS 值的桥接
// 严格翻译自: bun/src/runtime/valkey_jsc/protocol_jsc.zig
//   toJS 桥接 RESP 协议类型 (valkey/valkey_protocol.zig)。
//   协议解析器、RESPValue union 和 ValkeyReader 保持在 valkey/ 中；
//   只有涉及 JSGlobalObject/JSValue 的转换才放在这里，
//   以使 valkey/ 不依赖 JSC。
package bao_runtime

import bao_core.*
import bao_collections.*
import bao.valkey.*

// ============================================================================
// ProtocolJsc - RESP 值与 JS 值的转换桥接
// 严格翻译自: protocol_jsc.zig
// ============================================================================

/// Redis 错误到 JS 错误码的映射
/// 对应 Bun protocol_jsc.valkeyErrorToJS()
public enum RedisErrorCode {
    | ConnectionClosed
    | InvalidResponse
    | AuthenticationFailed
    | InvalidCommand
    | InvalidArgument
    | InvalidResponseType
    | ConnectionTimeout
    | IdleTimeout
    | OutOfMemory

    /// 获取错误消息
    public func message(): String {
        match (this) {
            case ConnectionClosed => "Connection closed"
            case InvalidResponse => "Invalid response"
            case AuthenticationFailed => "Authentication failed"
            case InvalidCommand => "Invalid command"
            case InvalidArgument => "Invalid argument"
            case InvalidResponseType => "Invalid response type"
            case ConnectionTimeout => "Connection timeout"
            case IdleTimeout => "Idle timeout"
            case OutOfMemory => "Out of memory"
        }
    }

    /// 将 RedisError 映射到 RedisErrorCode
    /// 对应 Bun protocol_jsc.valkeyErrorToJS() 中的 switch(err)
    public static func fromRedisError(err: RedisError): RedisErrorCode {
        match (err) {
            case RedisError.ConnectionClosed => RedisErrorCode.ConnectionClosed
            case RedisError.InvalidResponse => RedisErrorCode.InvalidResponse
            case RedisError.InvalidBulkString => RedisErrorCode.InvalidResponse
            case RedisError.InvalidArray => RedisErrorCode.InvalidResponse
            case RedisError.InvalidInteger => RedisErrorCode.InvalidResponse
            case RedisError.InvalidSimpleString => RedisErrorCode.InvalidResponse
            case RedisError.InvalidErrorString => RedisErrorCode.InvalidResponse
            case RedisError.InvalidDouble => RedisErrorCode.InvalidResponse
            case RedisError.InvalidBoolean => RedisErrorCode.InvalidResponse
            case RedisError.InvalidNull => RedisErrorCode.InvalidResponse
            case RedisError.InvalidMap => RedisErrorCode.InvalidResponse
            case RedisError.InvalidSet => RedisErrorCode.InvalidResponse
            case RedisError.InvalidBigNumber => RedisErrorCode.InvalidResponse
            case RedisError.InvalidVerbatimString => RedisErrorCode.InvalidResponse
            case RedisError.InvalidBlobError => RedisErrorCode.InvalidResponse
            case RedisError.InvalidAttribute => RedisErrorCode.InvalidResponse
            case RedisError.InvalidPush => RedisErrorCode.InvalidResponse
            case RedisError.AuthenticationFailed => RedisErrorCode.AuthenticationFailed
            case RedisError.InvalidCommand => RedisErrorCode.InvalidCommand
            case RedisError.InvalidArgument => RedisErrorCode.InvalidArgument
            case RedisError.UnsupportedProtocol => RedisErrorCode.InvalidResponse
            case RedisError.InvalidResponseType => RedisErrorCode.InvalidResponseType
            case RedisError.ConnectionTimeout => RedisErrorCode.ConnectionTimeout
            case RedisError.IdleTimeout => RedisErrorCode.IdleTimeout
            case RedisError.NestingDepthExceeded => RedisErrorCode.InvalidResponse
            case RedisError.JSError => RedisErrorCode.InvalidResponse
            case RedisError.OutOfMemory => RedisErrorCode.OutOfMemory
            case RedisError.JSTerminated => RedisErrorCode.InvalidResponse
        }
    }
}

/// RESP 值到 JS 值的转换工具
/// 对应 Bun protocol_jsc 中的转换函数
public class ProtocolJsc {

    /// 将 Redis 错误转换为 JS 错误值
    /// 对应 Bun protocol_jsc.valkeyErrorToJS()
    ///
    /// pub fn valkeyErrorToJS(globalObject: *jsc.JSGlobalObject, message: ?[]const u8,
    ///     err: protocol.RedisError) jsc.JSValue
    public static func valkeyErrorToJS(message: ?String, err: RedisError): JsValue {
        let errorCode = RedisErrorCode.fromRedisError(err)
        let msg = if (message.isSome()) {
            message.getOrThrow()
        } else {
            "Valkey error: ${err.message()}"
        }
        // 返回一个 JS Error 对象
        let errorObj = JsObject()
        errorObj.set("message", JsValue(msg))
        errorObj.set("code", JsValue(errorCode.message()))
        JsValue(errorObj)
    }

    /// 将 RESP 值转换为 JS 值
    /// 对应 Bun protocol_jsc.respValueToJS()
    ///
    /// pub fn respValueToJS(self: *RESPValue, globalObject: *jsc.JSGlobalObject) bun.JSError!jsc.JSValue
    public static func respValueToJS(value: RESPValue): JsValue {
        respValueToJSWithOptions(value, ToJSOptions())
    }

    /// 将字符串转为 JS 值 (考虑 buffer 选项)
    /// 对应 Bun protocol_jsc.valkeyStrToJSValue()
    ///
    /// fn valkeyStrToJSValue(globalObject: *jsc.JSGlobalObject, str: []const u8,
    ///     options: *const ToJSOptions) bun.JSError!jsc.JSValue
    private static func valkeyStrToJSValue(str: String, options: ToJSOptions): JsValue {
        if (options.returnAsBuffer) {
            // 返回为 ArrayBuffer
            // 对应: try jsc.ArrayBuffer.createBuffer(globalObject, str)
            let arr = ArrayList<JsValue>()
            for (b in str.toArray()) {
                arr.append(JsValue(Int64(b.value)))
            }
            JsValue.array(arr)
        } else {
            // 返回为字符串
            // 对应: bun.String.createUTF8ForJS(globalObject, str)
            JsValue(str)
        }
    }

    /// 将 RESP 值转换为 JS 值 (带选项)
    /// 对应 Bun protocol_jsc.respValueToJSWithOptions()
    ///
    /// pub fn respValueToJSWithOptions(self: *RESPValue, globalObject: *jsc.JSGlobalObject,
    ///     options: ToJSOptions) bun.JSError!jsc.JSValue
    public static func respValueToJSWithOptions(value: RESPValue, options: ToJSOptions): JsValue {
        match (value.respType) {
            // SimpleString -> 字符串
            case RESPType.SimpleString => valkeyStrToJSValue(value.simpleString, options)

            // Error -> JS Error
            case RESPType.Error => valkeyErrorToJS(value.error, RedisError.InvalidResponse)

            // Integer -> 数字
            case RESPType.Integer => JsValue(Float64(value.integerValue))

            // BulkString -> 字符串或 null
            case RESPType.BulkString => {
                if (value.bulkString.isSome()) {
                    valkeyStrToJSValue(value.bulkString.getOrThrow(), options)
                } else {
                    JsValue.NULL
                }
            }

            // Array -> JS Array
            case RESPType.Array => {
                let arr = ArrayList<JsValue>()
                for (item in value.array) {
                    arr.append(respValueToJSWithOptions(item, options))
                }
                JsValue.array(arr)
            }

            // Null -> JS null
            case RESPType.Null => JsValue.NULL

            // Double -> 数字
            case RESPType.Double => JsValue(value.doubleValue)

            // Boolean -> 布尔值
            case RESPType.Boolean => JsValue(value.booleanValue)

            // BlobError -> JS Error
            case RESPType.BlobError => valkeyErrorToJS(value.blobError, RedisError.InvalidBlobError)

            // VerbatimString -> 字符串
            case RESPType.VerbatimString => {
                if (value.verbatimString.isSome()) {
                    valkeyStrToJSValue(value.verbatimString.getOrThrow().content, options)
                } else {
                    JsValue.NULL
                }
            }

            // Map -> JS Object
            case RESPType.Map => {
                let obj = JsObject()
                for (entry in value.map) {
                    let jsKey = respValueToJSWithOptions(entry.key, ToJSOptions())
                    let keyStr = jsKey.toString()
                    let jsValue = respValueToJSWithOptions(entry.value, options)
                    obj.set(keyStr, jsValue)
                }
                JsValue(obj)
            }

            // Set -> JS Array
            case RESPType.Set => {
                let arr = ArrayList<JsValue>()
                for (item in value.set) {
                    arr.append(respValueToJSWithOptions(item, options))
                }
                JsValue.array(arr)
            }

            // Attribute -> 返回内部值 (忽略属性)
            // 对应: return try respValueToJSWithOptions(attribute.value, globalObject, options)
            case RESPType.Attribute => {
                if (value.attribute.isSome()) {
                    respValueToJSWithOptions(value.attribute.getOrThrow().value, options)
                } else {
                    JsValue.NULL
                }
            }

            // Push -> JS Object { type, data }
            // 对应:
            //   var js_obj = jsc.JSValue.createEmptyObjectWithNullPrototype(globalObject);
            //   js_obj.put(globalObject, "type", kind_str);
            //   js_obj.put(globalObject, "data", data_array);
            case RESPType.Push => {
                if (value.push.isSome()) {
                    let push = value.push.getOrThrow()
                    let obj = JsObject()
                    obj.set("type", JsValue(push.kind))
                    let dataArr = ArrayList<JsValue>()
                    for (item in push.data) {
                        dataArr.append(respValueToJSWithOptions(item, options))
                    }
                    obj.set("data", JsValue.array(dataArr))
                    JsValue(obj)
                } else {
                    JsValue.NULL
                }
            }

            // BigNumber -> 数字或字符串
            // 对应:
            //   if (std.fmt.parseInt(i64, str, 10)) |int| {
            //       return jsc.JSValue.jsNumber(int);
            //   } else |_| {
            //       return bun.String.createUTF8ForJS(globalObject, str);
            //   }
            case RESPType.BigNumber => {
                let parsed = Int64.tryParse(value.bigNumber)
                if (parsed.isSome()) {
                    JsValue(Float64(parsed.getOrThrow()))
                } else {
                    JsValue(value.bigNumber)
                }
            }
        }
    }
}
