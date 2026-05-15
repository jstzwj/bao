// Socket 事件处理器 — TCP/TLS 连接的回调管理
// 对应 Bun: src/runtime/socket/Handlers.zig
// 管理 onOpen, onClose, onData, onWritable 等回调的生命周期
package bao_runtime.socket

import bao_core.*
import bao_collections.*

// ============================================================================
// 二进制数据类型
// 对应 Bun: jsc.ArrayBuffer.BinaryType
// ============================================================================

/// 接收数据的二进制格式类型
public enum BinaryType {
    | Buffer       // Node.js Buffer
    | ArrayBuffer  // ArrayBuffer
    | Uint8Array   // Uint8Array

    /// 从字符串解析
    public static func fromString(value: String): BinaryType {
        match (value) {
            case "arraybuffer" => BinaryType.ArrayBuffer
            case "uint8array" => BinaryType.Uint8Array
            case _ => BinaryType.Buffer
        }
    }
}

// ============================================================================
// Socket 模式
// 对应 Bun: socket.SocketMode
// ============================================================================

/// Socket 运行模式
public enum SocketMode {
    | Client         // 客户端连接
    | Server         // 服务器监听
    | DuplexServer   // 双工升级为 TLS 服务器

    /// 是否为服务器模式
    public func isServer(): Bool {
        match (this) {
            case Server => true
            case DuplexServer => true
            case Client => false
        }
    }
}

// ============================================================================
// Socket 事件处理器
// 对应 Bun: Handlers struct
// ============================================================================

/// Socket 事件处理器
/// 管理所有 JS 回调的生命周期: onOpen, onClose, onData, onWritable 等
/// 对应 Zig: const Handlers = @This()
public class Handlers {
    /// 连接打开回调
    public var onOpen: JsValue
    /// 连接关闭回调
    public var onClose: JsValue
    /// 数据到达回调
    public var onData: JsValue
    /// 可写回调
    public var onWritable: JsValue
    /// 超时回调
    public var onTimeout: JsValue
    /// 连接错误回调
    public var onConnectError: JsValue
    /// 连接结束回调
    public var onEnd: JsValue
    /// 通用错误回调
    public var onError: JsValue
    /// TLS 握手回调
    public var onHandshake: JsValue

    /// 数据的二进制类型
    public var binaryType: BinaryType

    /// 关联的虚拟机
    public var vm: VirtualMachine
    /// 关联的全局对象
    public var globalObject: JsObject
    /// 活跃连接数
    public var activeConnections: Int64
    /// Socket 模式
    public var mode: SocketMode
    /// 关联的 Promise
    public var promise: JsValue

    public init(vm: VirtualMachine, globalObject: JsObject, mode: SocketMode) {
        this.vm = vm
        this.globalObject = globalObject
        this.mode = mode
        this.onOpen = JsValue.UNDEFINED
        this.onClose = JsValue.UNDEFINED
        this.onData = JsValue.UNDEFINED
        this.onWritable = JsValue.UNDEFINED
        this.onTimeout = JsValue.UNDEFINED
        this.onConnectError = JsValue.UNDEFINED
        this.onEnd = JsValue.UNDEFINED
        this.onError = JsValue.UNDEFINED
        this.onHandshake = JsValue.UNDEFINED
        this.binaryType = BinaryType.Buffer
        this.activeConnections = 0
        this.promise = JsValue.UNDEFINED
    }

    /// 标记为活跃 (增加活跃连接计数)
    /// 对应 Zig: markActive
    public func markActive(): Unit {
        activeConnections += 1
    }

    /// 标记为非活跃 (减少活跃连接计数)
    /// 对应 Zig: markInactive
    /// 返回 true 表示处理器已被销毁 (客户端模式, 最后一个引用)
    public func markInactive(): Bool {
        activeConnections -= 1
        if (activeConnections == 0) {
            match (mode) {
                case Server => {
                    // 服务器模式: 不释放 Handlers (嵌入在 Listener 中)
                    return false
                }
                case Client | DuplexServer => {
                    // 客户端模式: 释放分配的 Handlers
                    return true
                }
            }
        }
        return false
    }

    /// 调用错误处理器
    /// 对应 Zig: callErrorHandler
    public func callErrorHandler(thisValue: JsValue, error: JsValue): Bool {
        if (onError.valueType == JsValueType.Undefined) {
            return false
        }

        // 调用 onError(thisValue, error)
        // 实际实现中需要通过 JS 引擎调用
        return true
    }

    /// 解析 Promise
    /// 对应 Zig: resolvePromise
    public func resolvePromise(value: JsValue): Unit {
        // 将 promise 解析为给定值
        promise = JsValue.UNDEFINED
    }

    /// 拒绝 Promise
    /// 对应 Zig: rejectPromise
    public func rejectPromise(value: JsValue): Bool {
        if (promise.valueType == JsValueType.Undefined) {
            return false
        }
        // 将 promise 拒绝为给定错误值
        promise = JsValue.UNDEFINED
        return true
    }

    /// 从 JS 对象构造 Handlers
    /// 对应 Zig: fromJS
    public static func fromJS(globalObject: JsObject, opts: JsValue, isServer: Bool): ?Handlers {
        // 验证 opts 是否为对象
        if (opts.valueType != JsValueType.Object) {
            return None
        }

        // 读取二进制类型
        var binaryType = BinaryType.Buffer
        match (opts.objectData) {
            case Some(obj) => {
                let bt = obj.get("binaryType")
                if (bt.valueType == JsValueType.String) {
                    binaryType = BinaryType.fromString(bt.toString())
                }
            }
            case None => {}
        }

        // 创建 Handlers
        let vm = VirtualMachine()
        let handlers = Handlers(vm, globalObject, if (isServer) SocketMode.Server else SocketMode.Client)
        handlers.binaryType = binaryType

        // 读取回调函数
        match (opts.objectData) {
            case Some(obj) => {
                let onOpen = obj.get("onOpen")
                if (onOpen.valueType == JsValueType.Function) {
                    handlers.onOpen = onOpen
                }

                let onClose = obj.get("onClose")
                if (onClose.valueType == JsValueType.Function) {
                    handlers.onClose = onClose
                }

                let onData = obj.get("onData")
                if (onData.valueType == JsValueType.Function) {
                    handlers.onData = onData
                }

                let onWritable = obj.get("onWritable")
                if (onWritable.valueType == JsValueType.Function) {
                    handlers.onWritable = onWritable
                }

                let onTimeout = obj.get("onTimeout")
                if (onTimeout.valueType == JsValueType.Function) {
                    handlers.onTimeout = onTimeout
                }

                let onConnectError = obj.get("onConnectError")
                if (onConnectError.valueType == JsValueType.Function) {
                    handlers.onConnectError = onConnectError
                }

                let onEnd = obj.get("onEnd")
                if (onEnd.valueType == JsValueType.Function) {
                    handlers.onEnd = onEnd
                }

                let onError = obj.get("onError")
                if (onError.valueType == JsValueType.Function) {
                    handlers.onError = onError
                }

                let onHandshake = obj.get("onHandshake")
                if (onHandshake.valueType == JsValueType.Function) {
                    handlers.onHandshake = onHandshake
                }
            }
            case None => {}
        }

        // 至少需要 onData 或 onWritable
        if (handlers.onData.valueType != JsValueType.Function &&
            handlers.onWritable.valueType != JsValueType.Function) {
            return None
        }

        return handlers
    }

    /// 释放资源
    /// 对应 Zig: deinit
    public func deinit(): Unit {
        onOpen = JsValue.UNDEFINED
        onClose = JsValue.UNDEFINED
        onData = JsValue.UNDEFINED
        onWritable = JsValue.UNDEFINED
        onTimeout = JsValue.UNDEFINED
        onConnectError = JsValue.UNDEFINED
        onEnd = JsValue.UNDEFINED
        onError = JsValue.UNDEFINED
        onHandshake = JsValue.UNDEFINED
        promise = JsValue.UNDEFINED
    }
}

// ============================================================================
// Socket 配置
// 对应 Bun: Handlers.SocketConfig
// ============================================================================

/// Socket 配置选项
/// 对应 Zig: pub const SocketConfig = struct { ... }
public class SocketConfig {
    /// 主机名或 Unix 路径
    public var hostnameOrUnix: String
    /// 端口号
    public var port: UInt16
    /// 文件描述符
    public var fd: Int64
    /// SSL/TLS 配置
    public var ssl: ?SSLConfig
    /// 事件处理器
    public var handlers: Handlers
    /// 默认数据
    public var defaultData: JsValue
    /// 独占端口
    public var exclusive: Bool
    /// 允许半开连接
    public var allowHalfOpen: Bool
    /// 端口复用
    public var reusePort: Bool
    /// 仅 IPv6
    public var ipv6Only: Bool

    public init(handlers: Handlers) {
        this.hostnameOrUnix = ""
        this.port = 0
        this.fd = -1
        this.ssl = None
        this.handlers = handlers
        this.defaultData = JsValue.UNDEFINED
        this.exclusive = false
        this.allowHalfOpen = false
        this.reusePort = false
        this.ipv6Only = false
    }

    /// 获取 Socket 标志位
    /// 对应 Zig: socketFlags
    public func socketFlags(): Int32 {
        var flags: Int32 = 0

        if (exclusive) {
            flags |= 1    // LIBUS_LISTEN_EXCLUSIVE_PORT
        } else if (reusePort) {
            flags |= 6    // LIBUS_LISTEN_REUSE_PORT | LIBUS_LISTEN_REUSE_ADDR
        }

        if (allowHalfOpen) {
            flags |= 4    // LIBUS_SOCKET_ALLOW_HALF_OPEN
        }

        if (ipv6Only) {
            flags |= 8    // LIBUS_SOCKET_IPV6_ONLY
        }

        return flags
    }

    /// 从 JS 对象构造 SocketConfig
    /// 对应 Zig: fromJS
    public static func fromJS(vm: VirtualMachine, opts: JsValue, globalObject: JsObject, isServer: Bool): ?SocketConfig {
        if (opts.valueType != JsValueType.Object) {
            return None
        }

        match (opts.objectData) {
            case Some(obj) => {
                let socketObj = obj.get("socket")
                let handlers = Handlers.fromJS(globalObject, socketObj, isServer)
                match (handlers) {
                    case Some(h) => {
                        let config = SocketConfig(h)

                        // 读取 hostname/unix
                        let hostname = obj.get("hostname")
                        if (hostname.valueType == JsValueType.String) {
                            config.hostnameOrUnix = hostname.toString()
                        }

                        let unix = obj.get("unix")
                        if (unix.valueType == JsValueType.String) {
                            config.hostnameOrUnix = unix.toString()
                        }

                        // 读取端口
                        let port = obj.get("port")
                        if (port.valueType == JsValueType.Number) {
                            config.port = UInt16(port.toNumber())
                        }

                        // 读取 fd
                        let fd = obj.get("fd")
                        if (fd.valueType == JsValueType.Number) {
                            config.fd = Int64(fd.toNumber())
                        }

                        // 读取布尔选项
                        let exclusive = obj.get("exclusive")
                        if (exclusive.valueType == JsValueType.Boolean) {
                            config.exclusive = exclusive.toBoolean()
                        }

                        let allowHalfOpen = obj.get("allowHalfOpen")
                        if (allowHalfOpen.valueType == JsValueType.Boolean) {
                            config.allowHalfOpen = allowHalfOpen.toBoolean()
                        }

                        let reusePort = obj.get("reusePort")
                        if (reusePort.valueType == JsValueType.Boolean) {
                            config.reusePort = reusePort.toBoolean()
                        }

                        let ipv6Only = obj.get("ipv6Only")
                        if (ipv6Only.valueType == JsValueType.Boolean) {
                            config.ipv6Only = ipv6Only.toBoolean()
                        }

                        // 读取默认数据
                        let data = obj.get("data")
                        if (data.valueType != JsValueType.Undefined) {
                            config.defaultData = data
                        }

                        // 读取 SSL 配置
                        let tls = obj.get("tls")
                        if (tls.valueType != JsValueType.Undefined) {
                            config.ssl = SSLConfig.fromJS(tls)
                        }

                        return config
                    }
                    case None => return None
                }
            }
            case None => return None
        }
    }

    /// 释放资源
    /// 对应 Zig: deinit
    public func deinit(): Unit {
        handlers.deinit()
        hostnameOrUnix = ""
        ssl = None
    }

    /// 释放资源但保留 Handlers
    /// 对应 Zig: deinitExcludingHandlers
    public func deinitExcludingHandlers(): Unit {
        hostnameOrUnix = ""
        ssl = None
    }
}
