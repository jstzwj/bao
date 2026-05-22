// Socket 模块入口
// 对应 Bun: src/runtime/socket/mod.rs + socket.zig
// 汇总导出所有 Socket 相关类型
package bao_runtime.socket

// 地址相关
public type SocketAddr = SocketAddress
public type AddrFamily = AddressFamily

// 处理器与配置
public type SocketHandlers = Handlers
public type SocketCfg = SocketConfig
public type SocketBinType = BinaryType

// Socket 连接
public type TcpSocket = Socket
public type TlsSocket = Socket  // SSL 通过 Socket.isSsl 区分

// 监听器
public type SocketListener = Listener
public type ListenType = ListenerType

// SSL 配置
public type TlsConfig = SSLConfig

// UDP
public type UdpSock = UdpSocket
public type UdpSockConfig = UdpSocketConfig
