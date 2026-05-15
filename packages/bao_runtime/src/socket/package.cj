// Socket 模块入口
// 对应 Bun: src/runtime/socket/mod.rs + socket.zig
// 汇总导出所有 Socket 相关类型
package bao_runtime

// 地址相关
public typealias SocketAddr = SocketAddress
public typealias AddrFamily = AddressFamily

// 处理器与配置
public typealias SocketHandlers = Handlers
public typealias SocketCfg = SocketConfig
public typealias SocketBinType = BinaryType

// Socket 连接
public typealias TcpSocket = Socket
public typealias TlsSocket = Socket  // SSL 通过 Socket.isSsl 区分

// 监听器
public typealias SocketListener = Listener
public typealias ListenType = ListenerType

// SSL 配置
public typealias TlsConfig = SSLConfig

// UDP
public typealias UdpSock = UdpSocket
public typealias UdpSockConfig = UdpSocketConfig
