// UDP Socket — 数据报套接字
// 对应 Bun: src/runtime/socket/udp_socket.zig
// 管理 UDP 数据报的发送、接收和事件处理
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// UDP Socket 配置
// 对应 Bun: UDPSocketConfig
// ============================================================================

/// UDP Socket 配置选项
public class UdpSocketConfig {
    /// 绑定主机名
    public var hostname: String
    /// 连接目标
    public var connect: ?UdpConnectConfig
    /// 绑定端口
    public var port: UInt16
    /// Socket 标志
    public var flags: Int32
    /// 数据二进制类型
    public var binaryType: BinaryType

    public init() {
        hostname = ""
        connect = None
        port = 0
        flags = 0
        binaryType = BinaryType.Buffer
    }

    /// 从 JS 对象解析
    public static func fromJS(globalObject: JsObject, options: JsValue): ?UdpSocketConfig {
        if (options.valueType != JsValueType.Object) {
            return None
        }

        let config = UdpSocketConfig()

        match (options.objectData) {
            case Some(obj) => {
                let hostname = obj.get("hostname")
                if (hostname.valueType == JsValueType.String) {
                    config.hostname = hostname.toString()
                }

                let port = obj.get("port")
                if (port.valueType == JsValueType.Number) {
                    config.port = UInt16(port.toNumber())
                }

                let binaryType = obj.get("binaryType")
                if (binaryType.valueType == JsValueType.String) {
                    config.binaryType = BinaryType.fromString(binaryType.toString())
                }

                // 连接配置
                let connectObj = obj.get("connect")
                if (connectObj.valueType == JsValueType.Object) {
                    match (connectObj.objectData) {
                        case Some(conn) => {
                            let addr = conn.get("address")
                            let port = conn.get("port")
                            if (addr.valueType == JsValueType.String &&
                                port.valueType == JsValueType.Number) {
                                config.connect = Some(UdpConnectConfig(
                                    address: addr.toString(),
                                    port: UInt16(port.toNumber())
                                ))
                            }
                        }
                        case None => {}
                    }
                }
            }
            case None => {}
        }

        return config
    }
}

/// UDP 连接配置
public class UdpConnectConfig {
    public var address: String
    public var port: UInt16

    public init(address: String, port: UInt16) {
        this.address = address
        this.port = port
    }
}

// ============================================================================
// UDP 数据包缓冲区
// ============================================================================

/// UDP 数据包缓冲区
public class UdpPacketBuffer {
    /// 有效载荷数据
    public var payload: ArrayList<Array<UInt8>>
    /// 对端地址
    public var peers: ArrayList<UdpPeerAddress>
    /// 截断标志
    public var truncated: ArrayList<Bool>

    public init(count: Int64) {
        payload = ArrayList<Array<UInt8>>()
        peers = ArrayList<UdpPeerAddress>()
        truncated = ArrayList<Bool>()
    }

    /// 获取第 i 个包的有效载荷
    public func getPayload(i: Int64): Array<UInt8> {
        if (i < payload.size) {
            return payload[i]
        }
        return Array<UInt8>()
    }

    /// 获取第 i 个包的对端地址
    public func getPeer(i: Int64): UdpPeerAddress {
        return peers[i]
    }

    /// 获取第 i 个包的截断标志
    public func getTruncated(i: Int64): Bool {
        return truncated[i]
    }
}

/// UDP 对端地址
public class UdpPeerAddress {
    /// 地址族
    public var family: Int32
    /// IPv4 地址 (4字节)
    public var addr4: Array<UInt8>
    /// IPv6 地址 (16字节)
    public var addr6: Array<UInt8>
    /// 端口 (网络字节序)
    public var port: UInt16
    /// IPv6 scope_id
    public var scopeId: UInt32

    public init() {
        family = 0
        addr4 = Array<UInt8>()
        addr6 = Array<UInt8>()
        port = 0
        scopeId = 0
    }
}

// ============================================================================
// UDP Socket
// 对应 Bun: UDPSocket
// ============================================================================

/// UDP 数据报套接字
/// 对应 Zig: const UDPSocket = @This()
public class UdpSocket {
    /// 文件描述符
    public var fd: Int64
    /// 是否已关闭
    public var closed: Bool
    /// Socket 配置
    public var config: UdpSocketConfig
    /// 关联的全局对象
    public var globalObject: JsObject
    /// 关联的虚拟机
    public var vm: VirtualMachine
    /// JS 包装器引用
    public var thisValue: JsValue
    /// 绑定地址
    public var boundAddress: ?SocketAddress

    public init(config: UdpSocketConfig, globalObject: JsObject, vm: VirtualMachine) {
        this.fd = -1
        this.closed = false
        this.config = config
        this.globalObject = globalObject
        this.vm = vm
        this.thisValue = JsValue.UNDEFINED
        this.boundAddress = None
    }

    // ========================================================================
    // 绑定与连接
    // ========================================================================

    /// 绑定到指定地址和端口
    /// 对应 Bun: UDPSocket.bind
    public func bind(): Unit {
        // 通过 bao_sys socket/bind/recvmsg 系统调用
        // 创建 UDP socket, 绑定到 config.hostname:config.port
        fd = createUdpSocket()
        if (fd < 0) {
            throw BaoError("Failed to create UDP socket")
        }

        // 绑定地址
        bindSocket(fd, config.hostname, config.port)

        // 如果有连接目标, 执行 connect
        match (config.connect) {
            case Some(conn) => {
                connectSocket(fd, conn.address, conn.port)
            }
            case None => {}
        }
    }

    // ========================================================================
    // 数据收发
    // ========================================================================

    /// 发送数据报到指定目标
    /// 对应 Bun: UDPSocket.send (JS 层)
    public func send(data: Array<UInt8>, port: UInt16, address: String): Int64 {
        if (closed || fd < 0) {
            return -1
        }

        // 通过 bao_sys sendto 发送
        return sendto(fd, data, port, address)
    }

    /// 接收数据报 (由事件循环触发)
    /// 对应 Zig: onData 回调
    public func onData(buf: UdpPacketBuffer, packets: Int64): Unit {
        let thisVal = thisValue
        if (thisVal.valueType == JsValueType.Undefined) {
            return
        }

        // 获取 on_data 回调
        let callback = JsValue.UNDEFINED  // 从 JS 包装器获取
        if (callback.valueType != JsValueType.Function) {
            return
        }

        // 遍历所有数据包
        var i: Int64 = 0
        while (i < packets) {
            let peer = buf.getPeer(i)
            let payload = buf.getPayload(i)
            let truncated = buf.getTruncated(i)

            // 格式化对端地址
            var hostname = ""
            var port: UInt16 = 0

            match (peer.family) {
                case 2 => {
                    // IPv4
                    hostname = formatAddrV4(peer.addr4)
                    port = peer.port
                }
                case 10 => {
                    // IPv6
                    hostname = formatAddrV6(peer.addr6)
                    port = peer.port
                }
                case _ => {
                    i += 1
                    continue
                }
            }

            // 构建回调参数: (thisValue, data, port, hostname, flags)
            let flags = JsObject()
            flags.set("truncated", JsValue(truncated))

            i += 1
        }
    }

    /// 处理接收错误
    /// 对应 Zig: onRecvError
    public func onRecvError(errno: Int64): Unit {
        // 构建系统错误
        let errorMsg = "UDP recv error: ${errno}"
        callErrorHandler(JsValue.UNDEFINED, JsValue(errorMsg))
    }

    /// 处理 drain 事件
    /// 对应 Zig: onDrain
    public func onDrain(): Unit {
        // 触发 on_drain 回调
    }

    /// 关闭 UDP socket
    /// 对应 Zig: onClose
    public func onClose(): Unit {
        closed = true
        fd = -1
        thisValue = JsValue.UNDEFINED
    }

    // ========================================================================
    // Socket 选项
    // ========================================================================

    /// 获取本地地址
    public func getAddress(): JsValue {
        match (boundAddress) {
            case Some(addr) => return JsValue(addr.getAddress())
            case None => return JsValue.UNDEFINED
        }
    }

    /// 获取本地端口
    public func getPort(): JsValue {
        match (boundAddress) {
            case Some(addr) => return JsValue(Float64(addr.getPort()))
            case None => return JsValue.UNDEFINED
        }
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 调用错误处理器
    private func callErrorHandler(thisValue: JsValue, error: JsValue): Unit {
        // 通过 JS 引擎调用 on_error 回调
    }

    /// 格式化 IPv4 地址
    private func formatAddrV4(bytes: Array<UInt8>): String {
        if (bytes.size < 4) {
            return "0.0.0.0"
        }
        return "${bytes[0]}.${bytes[1]}.${bytes[2]}.${bytes[3]}"
    }

    /// 格式化 IPv6 地址
    private func formatAddrV6(bytes: Array<UInt8>): String {
        if (bytes.size < 16) {
            return "::"
        }
        // 简化实现
        var groups = ArrayList<String>()
        var i: Int64 = 0
        while (i < 16) {
            let hi = bytes[i].toInt()
            let lo = bytes[i + 1].toInt()
            let val = (hi << 8) | lo
            groups.append(val.toHexString())
            i += 2
        }
        return groups.join(":")
    }

    // ========================================================================
    // FFI — 通过 bao_sys socket 接口映射
    // ========================================================================

    // 创建 UDP socket (FFI)
    // 对应 C: socket(AF_INET, SOCK_DGRAM, 0)
    private func createUdpSocket(): Int64 {
        // foreign func socket(domain: Int32, type: Int32, protocol: Int32): Int64
        return -1  // 占位, 实际通过 FFI 调用
    }

    // 绑定 socket (FFI)
    private func bindSocket(fd: Int64, hostname: String, port: UInt16): Int64 {
        // foreign func bind(fd: Int64, addr: CPointer<Unit>, addrlen: UInt32): Int64
        return 0  // 占位
    }

    // 连接 socket (FFI)
    private func connectSocket(fd: Int64, address: String, port: UInt16): Int64 {
        // foreign func connect(fd: Int64, addr: CPointer<Unit>, addrlen: UInt32): Int64
        return 0  // 占位
    }

    // 发送数据报 (FFI)
    private func sendto(fd: Int64, data: Array<UInt8>, port: UInt16, address: String): Int64 {
        // foreign func sendto(fd: Int64, buf: CPointer<UInt8>, len: UInt64, flags: Int32,
        //                     addr: CPointer<Unit>, addrlen: UInt32): Int64
        return Int64(data.size)  // 占位
    }
}
