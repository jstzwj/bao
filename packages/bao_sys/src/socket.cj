// bao_sys - Socket 网络编程
// 严格翻译自: src/sys/socket.zig
//   Bun 使用 POSIX socket API 进行网络通信
//   仓颉通过 C FFI 调用 socket 系统调用
package bao_sys

import bao_core.*

// ============================================================================
// Socket 地址族 - 对应 Bun socket.AF_*
// ============================================================================

/// 地址族 - 对应 POSIX AF_*
public enum AddressFamily {
    | Unspecified  // AF_UNSPEC = 0
    | Unix         // AF_UNIX = 1
    | Inet         // AF_INET = 2
    | Inet6        // AF_INET6 = 10

    public func toInt(): Int32 {
        match (this) {
            case Unspecified => 0
            case Unix => 1
            case Inet => 2
            case Inet6 => 10
        }
    }
}

/// Socket 类型 - 对应 POSIX SOCK_*
public enum SocketType {
    | Stream   // SOCK_STREAM = 1
    | Datagram // SOCK_DGRAM = 2
    | Raw      // SOCK_RAW = 3

    public func toInt(): Int32 {
        match (this) {
            case Stream => 1
            case Datagram => 2
            case Raw => 3
        }
    }
}

/// Socket 协议 - 对应 POSIX IPPROTO_*
public enum SocketProtocol {
    | Default  // IPPROTO_IP = 0
    | Tcp      // IPPROTO_TCP = 6
    | Udp      // IPPROTO_UDP = 17

    public func toInt(): Int32 {
        match (this) {
            case Default => 0
            case Tcp => 6
            case Udp => 17
        }
    }
}

// ============================================================================
// Socket C FFI 声明
// 对应 Bun: src/sys/socket.zig 中的系统调用绑定
// ============================================================================

@C
foreign func socket(domain: Int32, sockType: Int32, protocol: Int32): Int32
@C
foreign func bind(fd: Int32, addr: CPointer<Unit>, addrlen: UInt32): Int32
@C
foreign func listen(fd: Int32, backlog: Int32): Int32
@C
foreign func accept(fd: Int32, addr: CPointer<Unit>, addrlen: CPointer<UInt32>): Int32
@C
foreign func connect(fd: Int32, addr: CPointer<Unit>, addrlen: UInt32): Int32
@C
foreign func recv(fd: Int32, buf: CPointer<Unit>, len: UIntNative, flags: Int32): UIntNative
@C
foreign func send(fd: Int32, buf: CPointer<Unit>, len: UIntNative, flags: Int32): UIntNative
@C
foreign func recvfrom(fd: Int32, buf: CPointer<Unit>, len: UIntNative, flags: Int32,
                       srcAddr: CPointer<Unit>, addrlen: CPointer<UInt32>): UIntNative
@C
foreign func sendto(fd: Int32, buf: CPointer<Unit>, len: UIntNative, flags: Int32,
                     destAddr: CPointer<Unit>, addrlen: UInt32): UIntNative
@C
foreign func setsockopt(fd: Int32, level: Int32, optname: Int32,
                         optval: CPointer<Unit>, optlen: UInt32): Int32
@C
foreign func getsockopt(fd: Int32, level: Int32, optname: Int32,
                         optval: CPointer<Unit>, optlen: CPointer<UInt32>): Int32
@C
foreign func shutdown(fd: Int32, how: Int32): Int32
@C
foreign func inet_pton(af: Int32, src: CPointer<Int8>, dst: CPointer<Unit>): Int32
@C
foreign func htons(hostshort: UInt16): UInt16
@C
foreign func ntohs(netshort: UInt16): UInt16
@C
foreign func htonl(hostlong: UInt32): UInt32
@C
foreign func ntohl(netlong: UInt32): UInt32

// Socket 选项常量
public class SocketOption {
    public static let SOCK_NONBLOCK: Int32 = 2048  // O_NONBLOCK on Linux
    public static let SOCK_CLOEXEC: Int32 = 524288  // O_CLOEXEC on Linux
    public static let SOL_SOCKET: Int32 = 1
    public static let SO_REUSEADDR: Int32 = 2
    public static let SO_REUSEPORT: Int32 = 15
    public static let SO_KEEPALIVE: Int32 = 9
    public static let SO_LINGER: Int32 = 13
    public static let SO_RCVBUF: Int32 = 8
    public static let SO_SNDBUF: Int32 = 7
    public static let SO_RCVTIMEO: Int32 = 20
    public static let SO_SNDTIMEO: Int32 = 21
    public static let TCP_NODELAY: Int32 = 1
    public static let IPPROTO_TCP: Int32 = 6
    public static let SHUT_RD: Int32 = 0
    public static let SHUT_WR: Int32 = 1
    public static let SHUT_RDWR: Int32 = 2
    public static let MSG_DONTWAIT: Int32 = 64
    public static let MSG_NOSIGNAL: Int32 = 16384
}

// ============================================================================
// Socket 地址结构体
// 严格翻译自: POSIX sockaddr_in / sockaddr_in6
// ============================================================================

/// IPv4 地址 + 端口 - 对应 POSIX sockaddr_in
public class SocketAddrV4 {
    public var port: UInt16
    public var addr: Array<UInt8>  // 4 bytes

    public init(port: UInt16, a: UInt8, b: UInt8, c: UInt8, d: UInt8) {
        this.port = port
        this.addr = [a, b, c, d]
    }

    /// 从 "x.x.x.x" 字符串构造
    public init(port: UInt16, ip: String) {
        this.port = port
        this.addr = [UInt8(0), UInt8(0), UInt8(0), UInt8(0)]
        var parts = ArrayList<String>()
        var current = StringBuilder()
        for (i in 0..ip.size) {
            let c = ip[Int64(i)]
            if (c == Char('.')) {
                parts.append(current.toString())
                current = StringBuilder()
            } else {
                current.append(c)
            }
        }
        if (current.length() > 0) { parts.append(current.toString()) }
        if (parts.size == 4) {
            for (i in 0..4) {
                addr[Int64(i)] = UInt8(Int64.parse(parts[Int64(i)]))
            }
        }
    }

    /// Loopback 127.0.0.1
    public static func loopback(port: UInt16): SocketAddrV4 {
        return SocketAddrV4(port, UInt8(127), UInt8(0), UInt8(0), UInt8(1))
    }

    /// Any 0.0.0.0
    public static func anyAddr(port: UInt16): SocketAddrV4 {
        return SocketAddrV4(port, UInt8(0), UInt8(0), UInt8(0), UInt8(0))
    }

    /// 格式化为字符串
    public func toString(): String {
        return "${addr[0]}.${addr[1]}.${addr[2]}.${addr[3]}:${port}"
    }
}

/// IPv6 地址 - 对应 POSIX sockaddr_in6
public class SocketAddrV6 {
    public var port: UInt16
    public var flowInfo: UInt32
    public var scopeId: UInt32
    public var addr: Array<UInt8>  // 16 bytes

    public init(port: UInt16) {
        this.port = port
        this.flowInfo = 0
        this.scopeId = 0
        this.addr = Array<UInt8>(16, item: UInt8(0))
    }

    /// Loopback ::1
    public static func loopback(port: UInt16): SocketAddrV6 {
        let addr = SocketAddrV6(port)
        addr.addr[15] = UInt8(1)
        return addr
    }

    /// Any ::
    public static func anyAddr(port: UInt16): SocketAddrV6 {
        return SocketAddrV6(port)
    }
}

/// 通用 Socket 地址
public enum SocketAddr {
    | V4(SocketAddrV4)
    | V6(SocketAddrV6)

    public func port(): UInt16 {
        match (this) {
            case V4(a) => a.port
            case V6(a) => a.port
        }
    }

    public func family(): AddressFamily {
        match (this) {
            case V4(_) => AddressFamily.Inet
            case V6(_) => AddressFamily.Inet6
        }
    }
}

// ============================================================================
// TcpSocket - TCP Socket 封装
// 严格翻译自: src/sys/socket.zig
// ============================================================================

/// TCP Socket - 对应 Bun TCP socket 封装
public class TcpSocket {
    private var fd: Int64

    public init(fd: Int64) {
        this.fd = fd
    }

    /// 获取文件描述符
    public func fd(): Int64 {
        return fd
    }

    /// 创建 TCP socket
    /// 对应 Bun: sys.socket(AF_INET, SOCK_STREAM, 0)
    public static func create(family: AddressFamily): SysMaybe<TcpSocket> {
        let sockFd = socket(family.toInt(), SocketType.Stream.toInt(),
                            SocketProtocol.Default.toInt())
        if (sockFd < 0) {
            return SysMaybe<TcpSocket>.Err(
                SysError(UInt16(Int64(OS.errno())), SysTag.Connect))
        }
        return SysMaybe<TcpSocket>.Ok(TcpSocket(Int64(sockFd)))
    }

    /// 绑定地址 — 完整实现，构造 sockaddr_in
    /// 对应 Bun: sys.bind(fd, addr, len)
    public func bind(addr: SocketAddr): SysMaybe<Unit> {
        unsafe {
            match (addr) {
                case V4(v4) =>
                    // 分配 sockaddr_in (16 bytes)
                    let addrBuf = malloc(UIntNative(16))
                    // 清零
                    for (i in 0..16) {
                        let bytePtr = CPointer<Int8>(addrBuf) + IntNative(i)
                        bytePtr.write(Int8(0))
                    }
                    // sin_family = AF_INET
                    let familyPtr = CPointer<Int16>(addrBuf)
                    familyPtr.write(Int16(2))  // AF_INET
                    // sin_port = htons(port)
                    let portPtr = CPointer<UInt16>(addrBuf + UIntNative(2))
                    portPtr.write(htons(v4.port))
                    // sin_addr
                    let addrPtr = CPointer<UInt8>(addrBuf + UIntNative(4))
                    for (i in 0..4) {
                        let bytePtr = addrPtr + IntNative(i)
                        bytePtr.write(v4.addr[Int64(i)])
                    }
                    let rc = bao_sys.bind(Int32(fd), addrBuf, UInt32(16))
                    free(addrBuf)
                    if (rc != 0) {
                        return SysMaybe<Unit>.Err(
                            SysError(UInt16(Int64(OS.errno())), SysTag.Bind))
                    }
                case V6(v6) =>
                    // 分配 sockaddr_in6 (28 bytes)
                    let addrBuf = malloc(UIntNative(28))
                    for (i in 0..28) {
                        let bytePtr = CPointer<Int8>(addrBuf) + IntNative(i)
                        bytePtr.write(Int8(0))
                    }
                    // sin6_family = AF_INET6
                    let familyPtr = CPointer<Int16>(addrBuf)
                    familyPtr.write(Int16(10))  // AF_INET6
                    // sin6_port = htons(port)
                    let portPtr = CPointer<UInt16>(addrBuf + UIntNative(2))
                    portPtr.write(htons(v6.port))
                    // sin6_addr (16 bytes at offset 8)
                    let addrPtr = CPointer<UInt8>(addrBuf + UIntNative(8))
                    for (i in 0..16) {
                        let bytePtr = addrPtr + IntNative(i)
                        bytePtr.write(v6.addr[Int64(i)])
                    }
                    let rc = bao_sys.bind(Int32(fd), addrBuf, UInt32(28))
                    free(addrBuf)
                    if (rc != 0) {
                        return SysMaybe<Unit>.Err(
                            SysError(UInt16(Int64(OS.errno())), SysTag.Bind))
                    }
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// 监听
    /// 对应 Bun: sys.listen(fd, backlog)
    public func listen(backlog: Int64): SysMaybe<Unit> {
        let rc = bao_sys.listen(Int32(fd), Int32(backlog))
        if (rc != 0) {
            return SysMaybe<Unit>.Err(
                SysError(UInt16(Int64(OS.errno())), SysTag.Listen))
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 接受连接
    /// 对应 Bun: sys.accept(fd, addr, len)
    public func accept(): SysMaybe<TcpSocket> {
        let clientFd = bao_sys.accept(Int32(fd), CPointer<Unit>(),
                                       CPointer<UInt32>())
        if (clientFd < 0) {
            return SysMaybe<TcpSocket>.Err(
                SysError(UInt16(Int64(OS.errno())), SysTag.Accept))
        }
        return SysMaybe<TcpSocket>.Ok(TcpSocket(Int64(clientFd)))
    }

    /// 连接远程 — 完整实现，构造 sockaddr_in
    /// 对应 Bun: sys.connect(fd, addr, len)
    public func connect(addr: SocketAddr): SysMaybe<Unit> {
        unsafe {
            match (addr) {
                case V4(v4) =>
                    let addrBuf = malloc(UIntNative(16))
                    for (i in 0..16) {
                        let bytePtr = CPointer<Int8>(addrBuf) + IntNative(i)
                        bytePtr.write(Int8(0))
                    }
                    let familyPtr = CPointer<Int16>(addrBuf)
                    familyPtr.write(Int16(2))
                    let portPtr = CPointer<UInt16>(addrBuf + UIntNative(2))
                    portPtr.write(htons(v4.port))
                    let addrPtr = CPointer<UInt8>(addrBuf + UIntNative(4))
                    for (i in 0..4) {
                        let bytePtr = addrPtr + IntNative(i)
                        bytePtr.write(v4.addr[Int64(i)])
                    }
                    let rc = bao_sys.connect(Int32(fd), addrBuf, UInt32(16))
                    free(addrBuf)
                    if (rc != 0) {
                        return SysMaybe<Unit>.Err(
                            SysError(UInt16(Int64(OS.errno())), SysTag.Connect))
                    }
                case V6(v6) =>
                    let addrBuf = malloc(UIntNative(28))
                    for (i in 0..28) {
                        let bytePtr = CPointer<Int8>(addrBuf) + IntNative(i)
                        bytePtr.write(Int8(0))
                    }
                    let familyPtr = CPointer<Int16>(addrBuf)
                    familyPtr.write(Int16(10))
                    let portPtr = CPointer<UInt16>(addrBuf + UIntNative(2))
                    portPtr.write(htons(v6.port))
                    let addrPtr = CPointer<UInt8>(addrBuf + UIntNative(8))
                    for (i in 0..16) {
                        let bytePtr = addrPtr + IntNative(i)
                        bytePtr.write(v6.addr[Int64(i)])
                    }
                    let rc = bao_sys.connect(Int32(fd), addrBuf, UInt32(28))
                    free(addrBuf)
                    if (rc != 0) {
                        return SysMaybe<Unit>.Err(
                            SysError(UInt16(Int64(OS.errno())), SysTag.Connect))
                    }
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// 设置非阻塞 — 通过 fcntl F_SETFL O_NONBLOCK
    //  严格翻译自: POSIX fcntl(fd, F_SETFL, O_NONBLOCK)
    @C
    foreign func fcntl(fd: Int32, cmd: Int32, arg: Int32): Int32

    public func setNonblocking(nonblocking: Bool): SysMaybe<Unit> {
        unsafe {
            // F_GETFL = 3, F_SETFL = 4
            let flags = fcntl(Int32(fd), 3, 0)
            if (flags < 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Fcntl))
            }
            let newFlags = if (nonblocking) {
                flags | 2048  // O_NONBLOCK
            } else {
                flags & ~2048
            }
            let rc = fcntl(Int32(fd), 4, newFlags)  // F_SETFL
            if (rc < 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Fcntl))
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// 设置 SO_REUSEADDR — 完整实现
    //  严格翻译自: POSIX setsockopt(SOL_SOCKET, SO_REUSEADDR)
    public func setReuseAddr(reuse: Bool): SysMaybe<Unit> {
        unsafe {
            let valBuf = malloc(UIntNative(4))
            let valPtr = CPointer<Int32>(valBuf)
            valPtr.write(if (reuse) { 1 } else { 0 })
            let rc = setsockopt(Int32(fd), SocketOption.SOL_SOCKET,
                                SocketOption.SO_REUSEADDR, valBuf, UInt32(4))
            free(valBuf)
            if (rc != 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Bind))
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// 设置 TCP_NODELAY — 完整实现
    //  严格翻译自: POSIX setsockopt(IPPROTO_TCP, TCP_NODELAY)
    public func setNoDelay(noDelay: Bool): SysMaybe<Unit> {
        unsafe {
            let valBuf = malloc(UIntNative(4))
            let valPtr = CPointer<Int32>(valBuf)
            valPtr.write(if (noDelay) { 1 } else { 0 })
            let rc = setsockopt(Int32(fd), SocketOption.IPPROTO_TCP,
                                SocketOption.TCP_NODELAY, valBuf, UInt32(4))
            free(valBuf)
            if (rc != 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Connect))
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// 设置 SO_KEEPALIVE
    public func setKeepalive(enable: Bool): SysMaybe<Unit> {
        unsafe {
            let valBuf = malloc(UIntNative(4))
            let valPtr = CPointer<Int32>(valBuf)
            valPtr.write(if (enable) { 1 } else { 0 })
            let rc = setsockopt(Int32(fd), SocketOption.SOL_SOCKET,
                                SocketOption.SO_KEEPALIVE, valBuf, UInt32(4))
            free(valBuf)
            if (rc != 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Connect))
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// 设置 SO_RCVBUF
    public func setRecvBufSize(size: Int32): SysMaybe<Unit> {
        unsafe {
            let valBuf = malloc(UIntNative(4))
            let valPtr = CPointer<Int32>(valBuf)
            valPtr.write(size)
            let rc = setsockopt(Int32(fd), SocketOption.SOL_SOCKET,
                                SocketOption.SO_RCVBUF, valBuf, UInt32(4))
            free(valBuf)
            if (rc != 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Setsockopt))
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// 设置 SO_SNDBUF
    public func setSendBufSize(size: Int32): SysMaybe<Unit> {
        unsafe {
            let valBuf = malloc(UIntNative(4))
            let valPtr = CPointer<Int32>(valBuf)
            valPtr.write(size)
            let rc = setsockopt(Int32(fd), SocketOption.SOL_SOCKET,
                                SocketOption.SO_SNDBUF, valBuf, UInt32(4))
            free(valBuf)
            if (rc != 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Setsockopt))
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// 获取 SO_ERROR (pending error)
    public func getError(): SysMaybe<Int32> {
        unsafe {
            let valBuf = malloc(UIntNative(4))
            let lenBuf = malloc(UIntNative(4))
            let lenPtr = CPointer<UInt32>(lenBuf)
            lenPtr.write(UInt32(4))
            let rc = getsockopt(Int32(fd), SocketOption.SOL_SOCKET,
                                Int32(4), valBuf, lenBuf)  // SO_ERROR = 4
            let valPtr = CPointer<Int32>(valBuf)
            let err = valPtr.read()
            free(valBuf)
            free(lenBuf)
            if (rc != 0) {
                return SysMaybe<Int32>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Setsockopt))
            }
            return SysMaybe<Int32>.Ok(err)
        }
    }

    /// 读取数据
    /// 对应 Bun: sys.recv(fd, buf, flags)
    public func recv(buf: Array<UInt8>): SysMaybe<Int64> {
        unsafe {
            let bufPtr = malloc(UIntNative(buf.size))
            let bytesRead = bao_sys.recv(Int32(fd), bufPtr, UIntNative(buf.size), 0)
            if (Int64(bytesRead) < 0) {
                free(bufPtr)
                return SysMaybe<Int64>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Recv))
            }
            let count = Int64(bytesRead)
            for (i in 0..count) {
                let bytePtr = CPointer<Int8>(bufPtr) + IntNative(i)
                buf[Int64(i)] = UInt8(Int32(bytePtr.read()) & 0xFF)
            }
            free(bufPtr)
            return SysMaybe<Int64>.Ok(count)
        }
    }

    /// 发送数据
    /// 对应 Bun: sys.send(fd, buf, flags)
    public func send(data: Array<UInt8>): SysMaybe<Int64> {
        unsafe {
            let bufPtr = malloc(UIntNative(data.size))
            for (i in 0..data.size) {
                let bytePtr = CPointer<Int8>(bufPtr) + IntNative(i)
                bytePtr.write(Int8(Int32(data[Int64(i)])))
            }
            let bytesWritten = bao_sys.send(Int32(fd), bufPtr, UIntNative(data.size),
                                             SocketOption.MSG_NOSIGNAL)
            free(bufPtr)
            if (Int64(bytesWritten) < 0) {
                return SysMaybe<Int64>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Send))
            }
            return SysMaybe<Int64>.Ok(Int64(bytesWritten))
        }
    }

    /// 关闭连接
    public func close(): SysMaybe<Unit> {
        return SysFs.close(fd)
    }

    /// 关闭写端
    public func shutdownWrite(): SysMaybe<Unit> {
        let rc = shutdown(Int32(fd), SocketOption.SHUT_WR)
        if (rc != 0) {
            return SysMaybe<Unit>.Err(
                SysError(UInt16(Int64(OS.errno())), SysTag.Shutdown))
        }
        return SysMaybe<Unit>.Ok(())
    }
}

/// TCP 监听器 - 对应 Bun TcpListener
public class TcpListener {
    private var socket: TcpSocket

    public init(socket: TcpSocket) {
        this.socket = socket
    }

    /// 绑定并监听 — 完整实现，设置 SO_REUSEADDR
    /// 对应 Bun: net.listen(addr, backlog)
    public static func listen(addr: SocketAddr, backlog: Int64): SysMaybe<TcpListener> {
        let family = addr.family()
        let sockResult = TcpSocket.create(family)
        match (sockResult) {
            case Err(e) => return SysMaybe<TcpListener>.Err(e)
            case Ok(sock) =>
                // 设置 SO_REUSEADDR — 对应 Bun: setsockopt SO_REUSEADDR
                _ = sock.setReuseAddr(true)
                // 设置 TCP_NODELAY
                _ = sock.setNoDelay(true)
                // 绑定地址
                let bindResult = sock.bind(addr)
                match (bindResult) {
                    case Err(e) => sock.close()
                        return SysMaybe<TcpListener>.Err(e)
                    case Ok(_) => ()
                }
                // 开始监听
                let listenResult = sock.listen(backlog)
                match (listenResult) {
                    case Err(e) => sock.close()
                        return SysMaybe<TcpListener>.Err(e)
                    case Ok(_) => return SysMaybe<TcpListener>.Ok(TcpListener(sock))
                }
        }
    }

    /// 接受新连接
    /// 对应 Bun: TcpListener.accept()
    public func accept(): SysMaybe<TcpSocket> {
        return socket.accept()
    }

    /// 获取底层 socket
    public func socket(): TcpSocket {
        return socket
    }

    /// 关闭监听器
    public func close(): SysMaybe<Unit> {
        return socket.close()
    }
}
