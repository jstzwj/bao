// 严格翻译自: src/uws_sys/socket.zig
package bao_uws_sys

import bao_sys.*

// ============================================================================
// InternalSocket - 内部套接字联合体
// 严格翻译自: socket.zig InternalSocket = union(enum)
// ============================================================================
public enum InternalSocketTag {
    connected
    connecting
    detached
    upgraded_duplex
    pipe
}

public class InternalSocket {
    public var tag: InternalSocketTag = InternalSocketTag.detached
    public var connectedSocket: ?UsSocket = None
    public var connectingSocket: ?ConnectingSocket = None
    public var upgradedDuplex: ?CPointer<Unit> = None
    public var pipeSocket: ?CPointer<Unit> = None

    public init() {
        this.tag = InternalSocketTag.detached
    }

    public static func fromConnected(s: UsSocket): InternalSocket {
        let sock = InternalSocket()
        sock.tag = InternalSocketTag.connected
        sock.connectedSocket = s
        return sock
    }

    public static func fromConnecting(cs: ConnectingSocket): InternalSocket {
        let sock = InternalSocket()
        sock.tag = InternalSocketTag.connecting
        sock.connectingSocket = cs
        return sock
    }

    public static func detachedSocket(): InternalSocket {
        return InternalSocket()
    }

    public static func fromUpgradedDuplex(duplex: CPointer<Unit>): InternalSocket {
        let sock = InternalSocket()
        sock.tag = InternalSocketTag.upgraded_duplex
        sock.upgradedDuplex = duplex
        return sock
    }

    public static func fromPipe(pipe: CPointer<Unit>): InternalSocket {
        let sock = InternalSocket()
        sock.tag = InternalSocketTag.pipe
        sock.pipeSocket = pipe
        return sock
    }

    /// 对应 Bun: pub fn pauseResume(this, pause) bool
    public func pauseResume(pause: Bool): Bool {
        match (tag) {
            case InternalSocketTag.detached => return true
            case InternalSocketTag.connected =>
                if (let Some(socket) <- connectedSocket) {
                    if (pause) { socket.pause() } else { socket.resume() }
                    return true
                }
                return false
            case InternalSocketTag.connecting => return false
            case InternalSocketTag.upgraded_duplex => return false
            case InternalSocketTag.pipe => return false
        }
    }

    /// 对应 Bun: pub fn isDetached(this) bool
    public func isDetached(): Bool {
        return tag == InternalSocketTag.detached
    }

    /// 对应 Bun: pub fn isNamedPipe(this) bool
    public func isNamedPipe(): Bool {
        return tag == InternalSocketTag.pipe
    }

    /// 对应 Bun: pub fn detach(this) void
    public mutating func detach(): Unit {
        tag = InternalSocketTag.detached
        connectedSocket = None
        connectingSocket = None
        upgradedDuplex = None
        pipeSocket = None
    }

    /// 对应 Bun: pub fn setNoDelay(this, enabled) bool
    public func setNoDelay(enabled: Bool): Bool {
        match (tag) {
            case InternalSocketTag.connected =>
                if (let Some(socket) <- connectedSocket) {
                    socket.setNodelay(enabled)
                    return true
                }
                return false
            case _ => return false
        }
    }

    /// 对应 Bun: pub fn setKeepAlive(this, enabled, delay) bool
    public func setKeepAlive(enabled: Bool, delay: UInt32): Bool {
        match (tag) {
            case InternalSocketTag.connected =>
                if (let Some(socket) <- connectedSocket) {
                    return socket.setKeepalive(enabled, delay) == 0
                }
                return false
            case _ => return false
        }
    }

    /// 对应 Bun: pub fn close(this, code) void
    public func close(code: CloseCode): Unit {
        match (tag) {
            case InternalSocketTag.detached => ()
            case InternalSocketTag.connected =>
                if (let Some(socket) <- connectedSocket) { socket.close(code) }
            case InternalSocketTag.connecting =>
                if (let Some(cs) <- connectingSocket) { cs.close() }
            case InternalSocketTag.upgraded_duplex => ()
            case InternalSocketTag.pipe => ()
        }
    }

    /// 对应 Bun: pub fn isClosed(this) bool
    public func isClosed(): Bool {
        match (tag) {
            case InternalSocketTag.connected =>
                if (let Some(socket) <- connectedSocket) { return socket.isClosed() }
                return true
            case InternalSocketTag.connecting =>
                if (let Some(cs) <- connectingSocket) { return cs.isClosed() }
                return true
            case InternalSocketTag.detached => return true
            case InternalSocketTag.upgraded_duplex => return false
            case InternalSocketTag.pipe => return false
        }
    }

    /// 对应 Bun: pub fn get(this) ?*us_socket_t
    public func get(): ?UsSocket {
        match (tag) {
            case InternalSocketTag.connected => return connectedSocket
            case _ => return None
        }
    }

    /// 对应 Bun: pub fn eq(this, other) bool
    public func eq(other: InternalSocket): Bool {
        if (tag != other.tag) {
            return false
        }
        match (tag) {
            case InternalSocketTag.connected =>
                if (let Some(a) <- connectedSocket) {
                    if (let Some(b) <- other.connectedSocket) {
                        return a.getPtr() == b.getPtr()
                    }
                }
                return false
            case InternalSocketTag.connecting =>
                if (let Some(a) <- connectingSocket) {
                    if (let Some(b) <- other.connectingSocket) {
                        return a.getPtr() == b.getPtr()
                    }
                }
                return false
            case InternalSocketTag.detached => return true
            case InternalSocketTag.upgraded_duplex => return upgradedDuplex == other.upgradedDuplex
            case InternalSocketTag.pipe => return pipeSocket == other.pipeSocket
        }
    }
}

// ============================================================================
// NewSocketHandler - 高级套接字包装器
// 严格翻译自: socket.zig NewSocketHandler(comptime is_ssl: bool)
// ============================================================================
public class SocketHandler {
    public var isSsl: Bool
    public var socket: InternalSocket

    public init(isSsl: Bool, socket: InternalSocket) {
        this.isSsl = isSsl
        this.socket = socket
    }

    public static func detachedHandler(isSsl: Bool): SocketHandler {
        return SocketHandler(isSsl, InternalSocket.detachedSocket())
    }

    public static func fromConnected(isSsl: Bool, s: UsSocket): SocketHandler {
        return SocketHandler(isSsl, InternalSocket.fromConnected(s))
    }

    public static func fromConnecting(isSsl: Bool, cs: ConnectingSocket): SocketHandler {
        return SocketHandler(isSsl, InternalSocket.fromConnecting(cs))
    }

    public static func fromUpgradedDuplex(isSsl: Bool, duplex: CPointer<Unit>): SocketHandler {
        return SocketHandler(isSsl, InternalSocket.fromUpgradedDuplex(duplex))
    }

    public static func fromPipe(isSsl: Bool, pipe: CPointer<Unit>): SocketHandler {
        return SocketHandler(isSsl, InternalSocket.fromPipe(pipe))
    }

    public static func fromInternal(isSsl: Bool, s: InternalSocket): SocketHandler {
        return SocketHandler(isSsl, s)
    }

    /// 对应 Bun: pub fn setNoDelay(this, enabled) bool
    public func setNoDelay(enabled: Bool): Bool {
        return socket.setNoDelay(enabled)
    }

    /// 对应 Bun: pub fn setKeepAlive(this, enabled, delay) bool
    public func setKeepAlive(enabled: Bool, delay: UInt32): Bool {
        return socket.setKeepAlive(enabled, delay)
    }

    /// 对应 Bun: pub fn pauseStream(this) bool
    public func pauseStream(): Bool {
        return socket.pauseResume(true)
    }

    /// 对应 Bun: pub fn resumeStream(this) bool
    public func resumeStream(): Bool {
        return socket.pauseResume(false)
    }

    /// 对应 Bun: pub fn detach(this) void
    public func detach(): Unit {
        socket.detach()
    }

    /// 对应 Bun: pub fn isDetached(this) bool
    public func isDetached(): Bool {
        return socket.isDetached()
    }

    /// 对应 Bun: pub fn isNamedPipe(this) bool
    public func isNamedPipe(): Bool {
        return socket.isNamedPipe()
    }

    /// 对应 Bun: pub fn timeout(this, seconds) void
    public func timeout(seconds: UInt32): Unit {
        match (socket.tag) {
            case InternalSocketTag.upgraded_duplex => ()
            case InternalSocketTag.pipe => ()
            case InternalSocketTag.connected =>
                if (let Some(s) <- socket.connectedSocket) { s.setTimeout(seconds) }
            case InternalSocketTag.connecting =>
                if (let Some(cs) <- socket.connectingSocket) { cs.timeout(seconds) }
            case InternalSocketTag.detached => ()
        }
    }

    /// 对应 Bun: pub fn setTimeout(this, seconds) void
    public func setTimeout(seconds: UInt32): Unit {
        match (socket.tag) {
            case InternalSocketTag.connected =>
                if (let Some(s) <- socket.connectedSocket) {
                    if (seconds > 240) {
                        s.setTimeout(0)
                        s.setLongTimeout(seconds / 60)
                    } else {
                        s.setTimeout(seconds)
                        s.setLongTimeout(0)
                    }
                }
            case InternalSocketTag.connecting =>
                if (let Some(cs) <- socket.connectingSocket) {
                    if (seconds > 240) {
                        cs.timeout(0)
                        cs.longTimeout(seconds / 60)
                    } else {
                        cs.timeout(seconds)
                        cs.longTimeout(0)
                    }
                }
            case InternalSocketTag.detached => ()
            case InternalSocketTag.upgraded_duplex => ()
            case InternalSocketTag.pipe => ()
        }
    }

    /// 对应 Bun: pub fn shutdown(this) void
    public func shutdown(): Unit {
        match (socket.tag) {
            case InternalSocketTag.connected =>
                if (let Some(s) <- socket.connectedSocket) { s.shutdown() }
            case InternalSocketTag.connecting =>
                if (let Some(cs) <- socket.connectingSocket) { cs.shutdown() }
            case InternalSocketTag.detached => ()
            case InternalSocketTag.upgraded_duplex => ()
            case InternalSocketTag.pipe => ()
        }
    }

    /// 对应 Bun: pub fn shutdownRead(this) void
    public func shutdownRead(): Unit {
        match (socket.tag) {
            case InternalSocketTag.connected =>
                if (let Some(s) <- socket.connectedSocket) { s.shutdownRead() }
            case InternalSocketTag.connecting =>
                if (let Some(cs) <- socket.connectingSocket) { cs.shutdownRead() }
            case InternalSocketTag.upgraded_duplex => ()
            case InternalSocketTag.pipe => ()
            case InternalSocketTag.detached => ()
        }
    }

    /// 对应 Bun: pub fn isShutdown(this) bool
    public func isShutdown(): Bool {
        match (socket.tag) {
            case InternalSocketTag.connected =>
                if (let Some(s) <- socket.connectedSocket) { return s.isShutdown() }
                return true
            case InternalSocketTag.connecting =>
                if (let Some(cs) <- socket.connectingSocket) { return cs.isShutdown() }
                return true
            case InternalSocketTag.upgraded_duplex => return false
            case InternalSocketTag.pipe => return false
            case InternalSocketTag.detached => return true
        }
    }

    /// 对应 Bun: pub fn isClosedOrHasError(this) bool
    public func isClosedOrHasError(): Bool {
        if (isClosed() || isShutdown()) {
            return true
        }
        return getError() != 0
    }

    /// 对应 Bun: pub fn getError(this) i32
    public func getError(): Int32 {
        match (socket.tag) {
            case InternalSocketTag.connected =>
                if (let Some(s) <- socket.connectedSocket) { return s.getError() }
                return 0
            case InternalSocketTag.connecting =>
                if (let Some(cs) <- socket.connectingSocket) { return cs.getError() }
                return 0
            case InternalSocketTag.detached => return 0
            case InternalSocketTag.upgraded_duplex => return 0
            case InternalSocketTag.pipe => return 0
        }
    }

    /// 对应 Bun: pub fn isClosed(this) bool
    public func isClosed(): Bool {
        return socket.isClosed()
    }

    /// 对应 Bun: pub fn close(this, code) void
    public func close(code: CloseCode): Unit {
        socket.close(code)
    }

    /// 对应 Bun: pub fn localPort(this) i32
    public func localPort(): Int32 {
        match (socket.tag) {
            case InternalSocketTag.connected =>
                if (let Some(s) <- socket.connectedSocket) { return s.localPort() }
                return 0
            case _ => return 0
        }
    }

    /// 对应 Bun: pub fn remotePort(this) i32
    public func remotePort(): Int32 {
        match (socket.tag) {
            case InternalSocketTag.connected =>
                if (let Some(s) <- socket.connectedSocket) { return s.remotePort() }
                return 0
            case _ => return 0
        }
    }

    /// 对应 Bun: pub fn flush(this) void
    public func flush(): Unit {
        match (socket.tag) {
            case InternalSocketTag.upgraded_duplex => ()
            case InternalSocketTag.connected =>
                if (let Some(s) <- socket.connectedSocket) { s.flush() }
            case InternalSocketTag.connecting, InternalSocketTag.detached => return
            case InternalSocketTag.pipe => ()
        }
    }

    /// 对应 Bun: pub fn write(this, data) i32
    public func write(data: Array<UInt8>): Int32 {
        match (socket.tag) {
            case InternalSocketTag.upgraded_duplex => return 0
            case InternalSocketTag.connected =>
                if (let Some(s) <- socket.connectedSocket) { return s.write(data) }
                return 0
            case InternalSocketTag.connecting, InternalSocketTag.detached => return 0
            case InternalSocketTag.pipe => return 0
        }
    }

    /// 对应 Bun: pub fn writeFd(this, data, file_descriptor) i32
    public func writeFd(data: Array<UInt8>, fileDescriptor: Int32): Int32 {
        match (socket.tag) {
            case InternalSocketTag.connected =>
                if (let Some(s) <- socket.connectedSocket) { return s.writeFd(data, fileDescriptor) }
                return 0
            case _ => return write(data)
        }
    }

    /// 对应 Bun: pub fn rawWrite(this, data) i32
    public func rawWrite(data: Array<UInt8>): Int32 {
        match (socket.tag) {
            case InternalSocketTag.connected =>
                if (let Some(s) <- socket.connectedSocket) { return s.rawWrite(data) }
                return 0
            case InternalSocketTag.connecting, InternalSocketTag.detached => return 0
            case InternalSocketTag.upgraded_duplex => return 0
            case InternalSocketTag.pipe => return 0
        }
    }

    /// 对应 Bun: pub fn getNativeHandle(this) ?*anyopaque
    public func getNativeHandle(): CPointer<Unit> {
        match (socket.tag) {
            case InternalSocketTag.connected =>
                if (let Some(s) <- socket.connectedSocket) { return s.getNativeHandle() }
                return CPointer<Unit>.null
            case InternalSocketTag.connecting =>
                if (let Some(cs) <- socket.connectingSocket) { return cs.getNativeHandle() }
                return CPointer<Unit>.null
            case InternalSocketTag.detached => return CPointer<Unit>.null
            case _ => return CPointer<Unit>.null
        }
    }

    /// 对应 Bun: pub fn fd(this) bun.FD
    public func fd(): Int32 {
        if (let Some(s) <- socket.get()) {
            return s.getFd()
        }
        return -1
    }

    /// 对应 Bun: pub fn group(this) ?*SocketGroup
    public func group(): ?SocketGroup {
        match (socket.tag) {
            case InternalSocketTag.connected =>
                if (let Some(s) <- socket.connectedSocket) {
                    return Some(s.group())
                }
                return None
            case InternalSocketTag.connecting =>
                if (let Some(cs) <- socket.connectingSocket) {
                    return Some(cs.group())
                }
                return None
            case _ => return None
        }
    }
}

// ============================================================================
// SocketTCP / SocketTLS 类型别名
// 严格翻译自: socket.zig
//  pub const SocketTCP = NewSocketHandler(false)
//  pub const SocketTLS = NewSocketHandler(true)
// ============================================================================
public typealias SocketTCP = SocketHandler
public typealias SocketTLS = SocketHandler

// ============================================================================
// AnySocket - TCP/TLS 套接字联合体
// 严格翻译自: socket.zig AnySocket = union(enum)
// ============================================================================
public class AnySocket {
    public var isSsl: Bool
    public var handler: SocketHandler

    public init(isSsl: Bool, handler: SocketHandler) {
        this.isSsl = isSsl
        this.handler = handler
    }

    public static func tcp(handler: SocketHandler): AnySocket {
        return AnySocket(false, handler)
    }

    public static func tls(handler: SocketHandler): AnySocket {
        return AnySocket(true, handler)
    }

    /// 对应 Bun: pub fn setTimeout(this, seconds) void
    public func setTimeout(seconds: UInt32): Unit {
        handler.setTimeout(seconds)
    }

    /// 对应 Bun: pub fn shutdown(this) void
    public func shutdown(): Unit {
        handler.shutdown()
    }

    /// 对应 Bun: pub fn shutdownRead(this) void
    public func shutdownRead(): Unit {
        handler.shutdownRead()
    }

    /// 对应 Bun: pub fn isShutdown(this) bool
    public func isShutdown(): Bool {
        return handler.isShutdown()
    }

    /// 对应 Bun: pub fn isClosed(this) bool
    public func isClosed(): Bool {
        return handler.isClosed()
    }

    /// 对应 Bun: pub fn close(this) void
    public func close(): Unit {
        handler.close(CloseCode.normal)
    }

    /// 对应 Bun: pub fn terminate(this) void
    public func terminate(): Unit {
        handler.close(CloseCode.failure)
    }

    /// 对应 Bun: pub fn write(this, data) i32
    public func write(data: Array<UInt8>): Int32 {
        return handler.write(data)
    }

    /// 对应 Bun: pub fn getNativeHandle(this) ?*anyopaque
    public func getNativeHandle(): CPointer<Unit> {
        return handler.getNativeHandle()
    }

    /// 对应 Bun: pub fn localPort(this) i32
    public func localPort(): Int32 {
        return handler.localPort()
    }

    /// 对应 Bun: pub fn isSSL(this) bool
    public func isSSL(): Bool {
        return isSsl
    }

    /// 对应 Bun: pub fn socket(this) InternalSocket
    public func internalSocket(): InternalSocket {
        return handler.socket
    }

    /// 对应 Bun: pub fn group(this) *SocketGroup
    public func group(): ?SocketGroup {
        return handler.group()
    }
}
