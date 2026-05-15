// WebSocketServerContext - WebSocket 服务器上下文
// 严格翻译自: Bun src/runtime/server/WebSocketServerContext.zig
// 对应: Bun.serve() 的 WebSocket 配置
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// WebSocketServerContext - WebSocket 服务器上下文
// 严格翻译自: src/runtime/server/WebSocketServerContext.zig
// Bun: const WebSocketServerContext = @This()
// 管理 WebSocket 服务器配置和生命周期回调
// ============================================================================

/// WebSocket 行为配置
/// 对应 Bun: uws.WebSocketBehavior
public class WebSocketBehavior {
    /// 最大载荷长度 - 对应 Bun: maxPayloadLength: u32 = 1024 * 1024 * 16
    public var maxPayloadLength: Int64
    /// 最大生存时间 - 对应 Bun: maxLifetime: u16 = 0
    public var maxLifetime: Int64
    /// 空闲超时 (秒) - 对应 Bun: idleTimeout: u16 = 120
    public var idleTimeout: Int64
    /// 压缩级别 - 对应 Bun: compression: i32 = 0
    public var compression: Int64
    /// 背压限制 - 对应 Bun: backpressureLimit: u32 = 1024 * 1024 * 16
    public var backpressureLimit: Int64
    /// 自动发送 Ping - 对应 Bun: sendPingsAutomatically: bool = true
    public var sendPingsAutomatically: Bool
    /// 发送时重置空闲超时 - 对应 Bun: resetIdleTimeoutOnSend: bool = true
    public var resetIdleTimeoutOnSend: Bool
    /// 背压限制时关闭 - 对应 Bun: closeOnBackpressureLimit: bool = false
    public var closeOnBackpressureLimit: Bool

    public init() {
        maxPayloadLength = 1024 * 1024 * 16  // 16MB
        maxLifetime = 0
        idleTimeout = 120  // 2 minutes
        compression = 0
        backpressureLimit = 1024 * 1024 * 16  // 16MB
        sendPingsAutomatically = true
        resetIdleTimeoutOnSend = true
        closeOnBackpressureLimit = false
    }
}

/// WebSocket 处理器标志
/// 对应 Bun: Handler.flags: packed struct(u8) { ssl, publish_to_self }
public class WebSocketHandlerFlags {
    /// 是否 SSL
    public var ssl: Bool
    /// 是否发布给自己
    public var publishToSelf: Bool

    public init() {
        ssl = false
        publishToSelf = false
    }
}

/// WebSocket 处理器
/// 严格翻译自: WebSocketServerContext.Handler
/// 对应 Bun: pub const Handler = struct { onOpen, onMessage, onClose, ... }
public class WebSocketHandler {
    /// 打开回调 - 对应 Bun: onOpen: jsc.JSValue = .zero
    public var onOpen: ?WebSocketCallback
    /// 消息回调 - 对应 Bun: onMessage: jsc.JSValue = .zero
    public var onMessage: ?WebSocketMessageCallback
    /// 关闭回调 - 对应 Bun: onClose: jsc.JSValue = .zero
    public var onClose: ?WebSocketCloseCallback
    /// 排水回调 - 对应 Bun: onDrain: jsc.JSValue = .zero
    public var onDrain: ?WebSocketCallback
    /// 错误回调 - 对应 Bun: onError: jsc.JSValue = .zero
    public var onError: ?WebSocketErrorCallback
    /// Ping 回调 - 对应 Bun: onPing: jsc.JSValue = .zero
    public var onPing: ?WebSocketMessageCallback
    /// Pong 回调 - 对应 Bun: onPong: jsc.JSValue = .zero
    public var onPong: ?WebSocketMessageCallback

    /// 应用引用 - 对应 Bun: app: ?*anyopaque = null
    public var app: ?WebSocketApp

    /// 虚拟机引用 - 对应 Bun: vm: *jsc.VirtualMachine
    public var vm: ?VirtualMachineRef

    /// 全局对象 - 对应 Bun: globalObject: *jsc.JSGlobalObject
    public var globalObject: ?JsGlobalObject

    /// 活跃连接数 - 对应 Bun: active_connections: usize = 0
    public var activeConnections: Int64

    /// 标志 - 对应 Bun: flags: packed struct(u8)
    public var flags: WebSocketHandlerFlags

    public init() {
        onOpen = None
        onMessage = None
        onClose = None
        onDrain = None
        onError = None
        onPing = None
        onPong = None
        app = None
        vm = None
        globalObject = None
        activeConnections = 0
        flags = WebSocketHandlerFlags()
    }

    /// 运行错误回调
    /// 对应 Bun: pub fn runErrorCallback(this, vm, globalObject, error_value) void
    public func runErrorCallback(errorValue: BaoError): Unit {
        match (onError) {
            case Some(cb) => {
                cb(errorValue)
                return
            }
            case None => ()
        }
        // 对应 Bun: vm.uncaughtException(globalObject, error_value, false)
    }
}

/// WebSocket 服务器上下文
/// 严格翻译自: src/runtime/server/WebSocketServerContext.zig
/// 对应 Bun: const WebSocketServerContext = @This()
public class WebSocketServerContext {
    /// 全局对象 - 对应 Bun: globalObject: *jsc.JSGlobalObject
    public var globalObject: ?JsGlobalObject

    /// 处理器 - 对应 Bun: handler: Handler = .{}
    public var handler: WebSocketHandler

    /// 最大载荷长度 - 对应 Bun: maxPayloadLength: u32 = 1024 * 1024 * 16
    public var maxPayloadLength: Int64

    /// 最大生存时间 - 对应 Bun: maxLifetime: u16 = 0
    public var maxLifetime: Int64

    /// 空闲超时 - 对应 Bun: idleTimeout: u16 = 120
    public var idleTimeout: Int64

    /// 压缩 - 对应 Bun: compression: i32 = 0
    public var compression: Int64

    /// 背压限制 - 对应 Bun: backpressureLimit: u32 = 1024 * 1024 * 16
    public var backpressureLimit: Int64

    /// 自动发送 Ping - 对应 Bun: sendPingsAutomatically: bool = true
    public var sendPingsAutomatically: Bool

    /// 发送时重置空闲超时 - 对应 Bun: resetIdleTimeoutOnSend: bool = true
    public var resetIdleTimeoutOnSend: Bool

    /// 背压限制时关闭 - 对应 Bun: closeOnBackpressureLimit: bool = false
    public var closeOnBackpressureLimit: Bool

    public init() {
        globalObject = None
        handler = WebSocketHandler()
        maxPayloadLength = 1024 * 1024 * 16  // 16MB
        maxLifetime = 0
        idleTimeout = 120
        compression = 0
        backpressureLimit = 1024 * 1024 * 16
        sendPingsAutomatically = true
        resetIdleTimeoutOnSend = true
        closeOnBackpressureLimit = false
    }

    /// 转为 WebSocketBehavior
    /// 对应 Bun: pub fn toBehavior(this) uws.WebSocketBehavior
    public func toBehavior(): WebSocketBehavior {
        let behavior = WebSocketBehavior()
        behavior.maxPayloadLength = maxPayloadLength
        behavior.idleTimeout = idleTimeout
        behavior.compression = compression
        behavior.backpressureLimit = backpressureLimit
        behavior.sendPingsAutomatically = sendPingsAutomatically
        behavior.maxLifetime = maxLifetime
        behavior.resetIdleTimeoutOnSend = resetIdleTimeoutOnSend
        behavior.closeOnBackpressureLimit = closeOnBackpressureLimit
        return behavior
    }

    /// 保护引用
    /// 对应 Bun: pub fn protect(this) void
    public func protect(): Unit {
        // 在仓颉中不需要手动内存管理
    }

    /// 取消保护引用
    /// 对应 Bun: pub fn unprotect(this) void
    public func unprotect(): Unit {
        // 在仓颉中不需要手动内存管理
    }

    /// 从配置创建 WebSocket 服务器上下文
    /// 对应 Bun: pub fn onCreate(globalObject, object) bun.JSError!WebSocketServerContext
    public static func onCreate(config: WebSocketConfig): WebSocketServerContext {
        let server = WebSocketServerContext()

        // 对应 Bun: 解析 perMessageDeflate
        server.compression = config.compression

        // 对应 Bun: maxPayloadLength
        server.maxPayloadLength = config.maxPayloadLength

        // 对应 Bun: idleTimeout - uws 不允许 (0, 8) 之间
        var idleTimeout = config.idleTimeout
        if (idleTimeout > 960) {
            idleTimeout = 960
        } else if (idleTimeout > 0 && idleTimeout < 8) {
            idleTimeout = 8  // 向上取整
        }
        server.idleTimeout = idleTimeout

        // 对应 Bun: backpressureLimit
        server.backpressureLimit = config.backpressureLimit

        // 对应 Bun: closeOnBackpressureLimit
        server.closeOnBackpressureLimit = config.closeOnBackpressureLimit

        // 对应 Bun: sendPings
        server.sendPingsAutomatically = config.sendPings

        // 对应 Bun: publishToSelf
        server.handler.flags.publishToSelf = config.publishToSelf

        server.protect()
        return server
    }
}

// ============================================================================
// WebSocket 配置 (从 JS 参数解析)
// ============================================================================

/// WebSocket 配置参数
/// 对应 Bun: WebSocketServerContext.onCreate 解析的 JS 对象字段
public class WebSocketConfig {
    public var compression: Int64
    public var maxPayloadLength: Int64
    public var idleTimeout: Int64
    public var backpressureLimit: Int64
    public var closeOnBackpressureLimit: Bool
    public var sendPings: Bool
    public var publishToSelf: Bool

    public init() {
        compression = 0
        maxPayloadLength = 1024 * 1024 * 16
        idleTimeout = 120
        backpressureLimit = 1024 * 1024 * 16
        closeOnBackpressureLimit = false
        sendPings = true
        publishToSelf = false
    }
}

// ============================================================================
// WebSocket 回调类型
// ============================================================================

/// WebSocket 基础回调
public type WebSocketCallback = (ws: ServerWebSocket) -> Unit

/// WebSocket 消息回调
public type WebSocketMessageCallback = (ws: ServerWebSocket, message: String, isBinary: Bool) -> Unit

/// WebSocket 关闭回调
public type WebSocketCloseCallback = (ws: ServerWebSocket, code: Int64, reason: String) -> Unit

/// WebSocket 错误回调
public type WebSocketErrorCallback = (error: BaoError) -> Unit

/// WebSocket 应用引用
public class WebSocketApp {
    public init() {}
}

/// 虚拟机引用
public class VirtualMachineRef {
    public init() {}
}

/// JS 全局对象引用
public class JsGlobalObject {
    public init() {}
}
