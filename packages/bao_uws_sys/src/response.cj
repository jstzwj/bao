// 严格翻译自: src/uws_sys/Response.zig
package bao_uws_sys

import bao_sys.*

// ============================================================================
// C FFI 声明
// 严格翻译自: Response.zig 中 extern fn
// ============================================================================
@C
foreign func uws_res_mark_wrote_content_length_header(ssl: Int32, res: CPointer<Unit>): Unit
@C
foreign func uws_res_write_mark(ssl: Int32, res: CPointer<Unit>): Unit
@C
foreign func us_socket_mark_needs_more_not_ssl(socket: CPointer<Unit>): Unit
@C
foreign func uws_res_state(ssl: Int32, res: CPointer<Unit>): UInt8
@C
foreign func uws_res_is_connect_request(ssl: Int32, res: CPointer<Unit>): Bool
@C
foreign func uws_res_get_remote_address_info(res: CPointer<Unit>, dest: CPointer<CPointer<UInt8>>, port: CPointer<Int32>, is_ipv6: CPointer<Bool>): UIntNative
@C
foreign func uws_res_uncork(ssl: Int32, res: CPointer<Unit>): Unit
@C
foreign func uws_res_end(ssl: Int32, res: CPointer<Unit>, data: CPointer<UInt8>, length: UIntNative, close_connection: Bool): Unit
@C
foreign func uws_res_flush_headers(ssl: Int32, res: CPointer<Unit>, flushImmediately: Bool): Unit
@C
foreign func uws_res_is_corked(ssl: Int32, res: CPointer<Unit>): Bool
@C
foreign func uws_res_get_socket_data(ssl: Int32, res: CPointer<Unit>): CPointer<Unit>
@C
foreign func uws_res_pause(ssl: Int32, res: CPointer<Unit>): Unit
@C
foreign func uws_res_resume(ssl: Int32, res: CPointer<Unit>): Unit
@C
foreign func uws_res_write_continue(ssl: Int32, res: CPointer<Unit>): Unit
@C
foreign func uws_res_write_status(ssl: Int32, res: CPointer<Unit>, status: CPointer<UInt8>, length: UIntNative): Unit
@C
foreign func uws_res_write_header(ssl: Int32, res: CPointer<Unit>, key: CPointer<UInt8>, key_length: UIntNative, value: CPointer<UInt8>, value_length: UIntNative): Unit
@C
foreign func uws_res_write_header_int(ssl: Int32, res: CPointer<Unit>, key: CPointer<UInt8>, key_length: UIntNative, value: UInt64): Unit
@C
foreign func uws_res_end_without_body(ssl: Int32, res: CPointer<Unit>, close_connection: Bool): Unit
@C
foreign func uws_res_end_sendfile(ssl: Int32, res: CPointer<Unit>, write_offset: UInt64, close_connection: Bool): Unit
@C
foreign func uws_res_timeout(ssl: Int32, res: CPointer<Unit>, timeout: UInt8): Unit
@C
foreign func uws_res_reset_timeout(ssl: Int32, res: CPointer<Unit>): Unit
@C
foreign func uws_res_get_buffered_amount(ssl: Int32, res: CPointer<Unit>): UInt64
@C
foreign func uws_res_write(ssl: Int32, res: CPointer<Unit>, data: CPointer<UInt8>, length: CPointer<UIntNative>): Bool
@C
foreign func uws_res_get_write_offset(ssl: Int32, res: CPointer<Unit>): UInt64
@C
foreign func uws_res_override_write_offset(ssl: Int32, res: CPointer<Unit>, offset: UInt64): Unit
@C
foreign func uws_res_has_responded(ssl: Int32, res: CPointer<Unit>): Bool
@C
foreign func uws_res_on_writable(ssl: Int32, res: CPointer<Unit>, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_res_clear_on_writable(ssl: Int32, res: CPointer<Unit>): Unit
@C
foreign func uws_res_on_aborted(ssl: Int32, res: CPointer<Unit>, handler: CPointer<Unit>, optional_data: CPointer<Unit>): Unit
@C
foreign func uws_res_on_timeout(ssl: Int32, res: CPointer<Unit>, handler: CPointer<Unit>, optional_data: CPointer<Unit>): Unit
@C
foreign func uws_res_try_end(ssl: Int32, res: CPointer<Unit>, data: CPointer<UInt8>, length: UIntNative, total: UIntNative, close: Bool): Bool
@C
foreign func uws_res_end_stream(ssl: Int32, res: CPointer<Unit>, close_connection: Bool): Unit
@C
foreign func uws_res_prepare_for_sendfile(ssl: Int32, res: CPointer<Unit>): Unit
@C
foreign func uws_res_get_native_handle(ssl: Int32, res: CPointer<Unit>): CPointer<Unit>
@C
foreign func uws_res_get_remote_address_as_text(ssl: Int32, res: CPointer<Unit>, dest: CPointer<CPointer<UInt8>>): UIntNative
@C
foreign func uws_res_on_data(ssl: Int32, res: CPointer<Unit>, handler: CPointer<Unit>, optional_data: CPointer<Unit>): Unit
@C
foreign func uws_res_upgrade(ssl: Int32, res: CPointer<Unit>, data: CPointer<Unit>, sec_web_socket_key: CPointer<UInt8>, sec_web_socket_key_length: UIntNative, sec_web_socket_protocol: CPointer<UInt8>, sec_web_socket_protocol_length: UIntNative, sec_web_socket_extensions: CPointer<UInt8>, sec_web_socket_extensions_length: UIntNative, ws: CPointer<Unit>): CPointer<Unit>
@C
foreign func uws_res_cork(ssl: Int32, res: CPointer<Unit>, ctx: CPointer<Unit>, corker: CPointer<Unit>): Unit

// ============================================================================
// State - HTTP 响应状态
// 严格翻译自: Response.zig State = enum(u8)
// ============================================================================
public enum State {
    | HTTP_STATUS_CALLED
    | HTTP_WRITE_CALLED
    | HTTP_END_CALLED
    | HTTP_RESPONSE_PENDING
    | HTTP_CONNECTION_CLOSE
    | HTTP_WROTE_CONTENT_LENGTH_HEADER
}

    /// 对应 Bun: pub inline fn hasWrittenContentLengthHeader(this) bool
    public func hasWrittenContentLengthHeader(): Bool {
        return (UInt8(this) & UInt8(State.HTTP_WROTE_CONTENT_LENGTH_HEADER)) != 0
    }

    /// 对应 Bun: pub inline fn isHttpEndCalled(this) bool
    public func isHttpEndCalled(): Bool {
        return (UInt8(this) & UInt8(State.HTTP_END_CALLED)) != 0
    }

    /// 对应 Bun: pub inline fn isHttpWriteCalled(this) bool
    public func isHttpWriteCalled(): Bool {
        return (UInt8(this) & UInt8(State.HTTP_WRITE_CALLED)) != 0
    }

    /// 对应 Bun: pub inline fn isHttpStatusCalled(this) bool
    public func isHttpStatusCalled(): Bool {
        return (UInt8(this) & UInt8(State.HTTP_STATUS_CALLED)) != 0
    }

    /// 对应 Bun: pub inline fn isHttpConnectionClose(this) bool
    public func isHttpConnectionClose(): Bool {
        return (UInt8(this) & UInt8(State.HTTP_CONNECTION_CLOSE)) != 0
    }
}

// ============================================================================
// WriteResult - 写入结果
// 严格翻译自: Response.zig WriteResult = union(enum)
// ============================================================================
public open class WriteResult {}
public class WriteResultWantMore <: WriteResult {
    public let length: UIntNative
    public init(length: UIntNative) {
        this.length = length
    }
}
public class WriteResultBackpressure <: WriteResult {
    public let length: UIntNative
    public init(length: UIntNative) {
        this.length = length
    }
}

// ============================================================================
// SocketAddress - 套接字地址
// 严格翻译自: Response.zig SocketAddress (referenced from uws)
// ============================================================================
public class SocketAddress {
    public var ip: Array<UInt8> = Array<UInt8>()
    public var port: Int32 = 0
    public var is_ipv6: Bool = false

    public init() {}
}

// ============================================================================
// TcpResponse - TCP HTTP 响应
// 严格翻译自: Response.zig NewResponse(0)
// ============================================================================
public class TcpResponse {
    private var ptr: CPointer<Unit>
    private let sslFlag: Int32 = 0

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    /// 对应 Bun: pub fn end(res, data, close_connection) void
    public func end(data: Array<UInt8>, closeConnection: Bool): Unit {
        uws_res_end(sslFlag, ptr, CPointer<UInt8>.reinterpret(data), UIntNative(data.size), closeConnection)
    }

    /// 对应 Bun: pub fn tryEnd(res, data, total, close_) bool
    public func tryEnd(data: Array<UInt8>, total: UIntNative, close: Bool): Bool {
        return uws_res_try_end(sslFlag, ptr, CPointer<UInt8>.reinterpret(data), UIntNative(data.size), total, close)
    }

    /// 对应 Bun: pub fn getSocketData(res) ?*anyopaque
    public func getSocketData(): CPointer<Unit> {
        return uws_res_get_socket_data(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn isConnectRequest(res) bool
    public func isConnectRequest(): Bool {
        return uws_res_is_connect_request(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn flushHeaders(res, flushImmediately) void
    public func flushHeaders(flushImmediately: Bool): Unit {
        uws_res_flush_headers(sslFlag, ptr, flushImmediately)
    }

    /// 对应 Bun: pub fn isCorked(res) bool
    public func isCorked(): Bool {
        return uws_res_is_corked(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn state(res) State
    public func state(): State {
        return State(uws_res_state(sslFlag, ptr))
    }

    /// 对应 Bun: pub fn shouldCloseConnection(this) bool
    public func shouldCloseConnection(): Bool {
        return state().isHttpConnectionClose()
    }

    /// 对应 Bun: pub fn prepareForSendfile(res) void
    public func prepareForSendfile(): Unit {
        uws_res_prepare_for_sendfile(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn uncork(res) void
    public func uncork(): Unit {
        uws_res_uncork(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn pause(res) void
    public func pause(): Unit {
        uws_res_pause(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn @"resume"(res) void
    public func resume(): Unit {
        uws_res_resume(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn writeContinue(res) void
    public func writeContinue(): Unit {
        uws_res_write_continue(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn writeStatus(res, status) void
    public func writeStatus(status: Array<UInt8>): Unit {
        uws_res_write_status(sslFlag, ptr, CPointer<UInt8>.reinterpret(status), UIntNative(status.size))
    }

    /// 对应 Bun: pub fn writeHeader(res, key, value) void
    public func writeHeader(key: Array<UInt8>, value: Array<UInt8>): Unit {
        uws_res_write_header(sslFlag, ptr, CPointer<UInt8>.reinterpret(key), UIntNative(key.size), CPointer<UInt8>.reinterpret(value), UIntNative(value.size))
    }

    /// 对应 Bun: pub fn writeHeaderInt(res, key, value) void
    public func writeHeaderInt(key: Array<UInt8>, value: UInt64): Unit {
        uws_res_write_header_int(sslFlag, ptr, CPointer<UInt8>.reinterpret(key), UIntNative(key.size), value)
    }

    /// 对应 Bun: pub fn endWithoutBody(res, close_connection) void
    public func endWithoutBody(closeConnection: Bool): Unit {
        uws_res_end_without_body(sslFlag, ptr, closeConnection)
    }

    /// 对应 Bun: pub fn endSendFile(res, write_offset, close_connection) void
    public func endSendFile(writeOffset: UInt64, closeConnection: Bool): Unit {
        uws_res_end_sendfile(sslFlag, ptr, writeOffset, closeConnection)
    }

    /// 对应 Bun: pub fn timeout(res, seconds) void
    public func timeout(seconds: UInt8): Unit {
        uws_res_timeout(sslFlag, ptr, seconds)
    }

    /// 对应 Bun: pub fn resetTimeout(res) void
    public func resetTimeout(): Unit {
        uws_res_reset_timeout(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn getBufferedAmount(res) u64
    public func getBufferedAmount(): UInt64 {
        return uws_res_get_buffered_amount(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn write(res, data) WriteResult
    public func write(data: Array<UInt8>): WriteResult {
        var len: UIntNative = UIntNative(data.size)
        let success = uws_res_write(sslFlag, ptr, CPointer<UInt8>.reinterpret(data), CPointer<UIntNative>.reinterpret(len))
        if (success) {
            return WriteResultWantMore(len)
        }
        return WriteResultBackpressure(len)
    }

    /// 对应 Bun: pub fn getWriteOffset(res) u64
    public func getWriteOffset(): UInt64 {
        return uws_res_get_write_offset(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn overrideWriteOffset(res, offset) void
    public func overrideWriteOffset(offset: UInt64): Unit {
        uws_res_override_write_offset(sslFlag, ptr, offset)
    }

    /// 对应 Bun: pub fn hasResponded(res) bool
    public func hasResponded(): Bool {
        return uws_res_has_responded(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn markWroteContentLengthHeader(res) void
    public func markWroteContentLengthHeader(): Unit {
        uws_res_mark_wrote_content_length_header(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn writeMark(res) void
    public func writeMark(): Unit {
        uws_res_write_mark(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn markNeedsMore(res) void
    public func markNeedsMore(): Unit {
        us_socket_mark_needs_more_not_ssl(ptr)
    }

    /// 对应 Bun: pub fn getNativeHandle(res) bun.FD
    public func getNativeHandle(): CPointer<Unit> {
        return uws_res_get_native_handle(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn getRemoteAddressAsText(res) ?[]const u8
    public func getRemoteAddressAsText(): ?Array<UInt8> {
        return None
    }

    /// 对应 Bun: pub fn getRemoteSocketInfo(res) ?SocketAddress
    public func getRemoteSocketInfo(): ?SocketAddress {
        return None
    }

    /// 对应 Bun: pub fn clearOnWritable(res) void
    public func clearOnWritable(): Unit {
        uws_res_clear_on_writable(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn clearAborted(res) void
    public func clearAborted(): Unit {
        uws_res_on_aborted(sslFlag, ptr, CPointer<Unit>.null, CPointer<Unit>.null)
    }

    /// 对应 Bun: pub fn clearTimeout(res) void
    public func clearTimeout(): Unit {
        uws_res_on_timeout(sslFlag, ptr, CPointer<Unit>.null, CPointer<Unit>.null)
    }

    /// 对应 Bun: pub fn clearOnData(res) void
    public func clearOnData(): Unit {
        uws_res_on_data(sslFlag, ptr, CPointer<Unit>.null, CPointer<Unit>.null)
    }

    /// 对应 Bun: pub fn endStream(res, close_connection) void
    public func endStream(closeConnection: Bool): Unit {
        uws_res_end_stream(sslFlag, ptr, closeConnection)
    }

    /// 对应 Bun: pub fn upgrade(res, data, sec_web_socket_key, ...) *Socket
    public func upgrade(data: CPointer<Unit>, secWebSocketKey: Array<UInt8>, secWebSocketProtocol: Array<UInt8>, secWebSocketExtensions: Array<UInt8>, ctx: CPointer<Unit>): CPointer<Unit> {
        return uws_res_upgrade(sslFlag, ptr, data,
            CPointer<UInt8>.reinterpret(secWebSocketKey), UIntNative(secWebSocketKey.size),
            CPointer<UInt8>.reinterpret(secWebSocketProtocol), UIntNative(secWebSocketProtocol.size),
            CPointer<UInt8>.reinterpret(secWebSocketExtensions), UIntNative(secWebSocketExtensions.size),
            ctx)
    }
}

// ============================================================================
// TlsResponse - TLS HTTP 响应
// 严格翻译自: Response.zig NewResponse(1)
// ============================================================================
public class TlsResponse {
    private var ptr: CPointer<Unit>
    private let sslFlag: Int32 = 1

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    // Mirror all TcpResponse methods with sslFlag=1
    public func end(data: Array<UInt8>, closeConnection: Bool): Unit {
        uws_res_end(sslFlag, ptr, CPointer<UInt8>.reinterpret(data), UIntNative(data.size), closeConnection)
    }
    public func tryEnd(data: Array<UInt8>, total: UIntNative, close: Bool): Bool {
        return uws_res_try_end(sslFlag, ptr, CPointer<UInt8>.reinterpret(data), UIntNative(data.size), total, close)
    }
    public func getSocketData(): CPointer<Unit> {
        return uws_res_get_socket_data(sslFlag, ptr)
    }
    public func isConnectRequest(): Bool {
        return uws_res_is_connect_request(sslFlag, ptr)
    }
    public func flushHeaders(flushImmediately: Bool): Unit {
        uws_res_flush_headers(sslFlag, ptr, flushImmediately)
    }
    public func isCorked(): Bool {
        return uws_res_is_corked(sslFlag, ptr)
    }
    public func state(): State {
        return State(uws_res_state(sslFlag, ptr))
    }
    public func shouldCloseConnection(): Bool {
        return state().isHttpConnectionClose()
    }
    public func prepareForSendfile(): Unit {
        uws_res_prepare_for_sendfile(sslFlag, ptr)
    }
    public func uncork(): Unit {
        uws_res_uncork(sslFlag, ptr)
    }
    public func pause(): Unit {
        uws_res_pause(sslFlag, ptr)
    }
    public func resume(): Unit {
        uws_res_resume(sslFlag, ptr)
    }
    public func writeContinue(): Unit {
        uws_res_write_continue(sslFlag, ptr)
    }
    public func writeStatus(status: Array<UInt8>): Unit {
        uws_res_write_status(sslFlag, ptr, CPointer<UInt8>.reinterpret(status), UIntNative(status.size))
    }
    public func writeHeader(key: Array<UInt8>, value: Array<UInt8>): Unit {
        uws_res_write_header(sslFlag, ptr, CPointer<UInt8>.reinterpret(key), UIntNative(key.size), CPointer<UInt8>.reinterpret(value), UIntNative(value.size))
    }
    public func writeHeaderInt(key: Array<UInt8>, value: UInt64): Unit {
        uws_res_write_header_int(sslFlag, ptr, CPointer<UInt8>.reinterpret(key), UIntNative(key.size), value)
    }
    public func endWithoutBody(closeConnection: Bool): Unit {
        uws_res_end_without_body(sslFlag, ptr, closeConnection)
    }
    public func endSendFile(writeOffset: UInt64, closeConnection: Bool): Unit {
        uws_res_end_sendfile(sslFlag, ptr, writeOffset, closeConnection)
    }
    public func timeout(seconds: UInt8): Unit {
        uws_res_timeout(sslFlag, ptr, seconds)
    }
    public func resetTimeout(): Unit {
        uws_res_reset_timeout(sslFlag, ptr)
    }
    public func getBufferedAmount(): UInt64 {
        return uws_res_get_buffered_amount(sslFlag, ptr)
    }
    public func write(data: Array<UInt8>): WriteResult {
        var len: UIntNative = UIntNative(data.size)
        let success = uws_res_write(sslFlag, ptr, CPointer<UInt8>.reinterpret(data), CPointer<UIntNative>.reinterpret(len))
        if (success) {
            return WriteResultWantMore(len)
        }
        return WriteResultBackpressure(len)
    }
    public func getWriteOffset(): UInt64 {
        return uws_res_get_write_offset(sslFlag, ptr)
    }
    public func overrideWriteOffset(offset: UInt64): Unit {
        uws_res_override_write_offset(sslFlag, ptr, offset)
    }
    public func hasResponded(): Bool {
        return uws_res_has_responded(sslFlag, ptr)
    }
    public func markWroteContentLengthHeader(): Unit {
        uws_res_mark_wrote_content_length_header(sslFlag, ptr)
    }
    public func writeMark(): Unit {
        uws_res_write_mark(sslFlag, ptr)
    }
    public func getNativeHandle(): CPointer<Unit> {
        return uws_res_get_native_handle(sslFlag, ptr)
    }
    public func clearOnWritable(): Unit {
        uws_res_clear_on_writable(sslFlag, ptr)
    }
    public func clearAborted(): Unit {
        uws_res_on_aborted(sslFlag, ptr, CPointer<Unit>.null, CPointer<Unit>.null)
    }
    public func clearTimeout(): Unit {
        uws_res_on_timeout(sslFlag, ptr, CPointer<Unit>.null, CPointer<Unit>.null)
    }
    public func clearOnData(): Unit {
        uws_res_on_data(sslFlag, ptr, CPointer<Unit>.null, CPointer<Unit>.null)
    }
    public func endStream(closeConnection: Bool): Unit {
        uws_res_end_stream(sslFlag, ptr, closeConnection)
    }
    public func upgrade(data: CPointer<Unit>, secWebSocketKey: Array<UInt8>, secWebSocketProtocol: Array<UInt8>, secWebSocketExtensions: Array<UInt8>, ctx: CPointer<Unit>): CPointer<Unit> {
        return uws_res_upgrade(sslFlag, ptr, data,
            CPointer<UInt8>.reinterpret(secWebSocketKey), UIntNative(secWebSocketKey.size),
            CPointer<UInt8>.reinterpret(secWebSocketProtocol), UIntNative(secWebSocketProtocol.size),
            CPointer<UInt8>.reinterpret(secWebSocketExtensions), UIntNative(secWebSocketExtensions.size),
            ctx)
    }
}

// ============================================================================
// AnyResponse - TCP/TLS/H3 响应联合体
// 严格翻译自: Response.zig AnyResponse = union(enum)
// ============================================================================
public class AnyResponse {
    public enum ResponseType {
        ssl
        tcp
        h3
    }

    public var responseType: ResponseType
    public var tcpResp: ?TcpResponse = None
    public var tlsResp: ?TlsResponse = None
    public var h3Resp: ?CPointer<Unit> = None

    public init(tcp: TcpResponse) {
        this.responseType = ResponseType.tcp
        this.tcpResp = tcp
    }

    public init(tls: TlsResponse) {
        this.responseType = ResponseType.ssl
        this.tlsResp = tls
    }

    public init(h3: CPointer<Unit>) {
        this.responseType = ResponseType.h3
        this.h3Resp = h3
    }

    public func isSSL(): Bool {
        return responseType == ResponseType.ssl
    }

    /// 对应 Bun: pub fn end(this, data, close_connection) void
    public func end(data: Array<UInt8>, closeConnection: Bool): Unit {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { r.end(data, closeConnection) }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { r.end(data, closeConnection) }
            | ResponseType.h3 => {}
        }
    }

    /// 对应 Bun: pub fn tryEnd(this, data, total_size, close_connection) bool
    public func tryEnd(data: Array<UInt8>, totalSize: UIntNative, closeConnection: Bool): Bool {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { return r.tryEnd(data, totalSize, closeConnection) }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { return r.tryEnd(data, totalSize, closeConnection) }
            | ResponseType.h3 => {}
        }
        return false
    }

    /// 对应 Bun: pub fn writeStatus(this, status) void
    public func writeStatus(status: Array<UInt8>): Unit {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { r.writeStatus(status) }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { r.writeStatus(status) }
            | ResponseType.h3 => {}
        }
    }

    /// 对应 Bun: pub fn writeHeader(this, key, value) void
    public func writeHeader(key: Array<UInt8>, value: Array<UInt8>): Unit {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { r.writeHeader(key, value) }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { r.writeHeader(key, value) }
            | ResponseType.h3 => {}
        }
    }

    /// 对应 Bun: pub fn write(this, data) WriteResult
    public func write(data: Array<UInt8>): WriteResult {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { return r.write(data) }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { return r.write(data) }
            | ResponseType.h3 => {}
        }
        return WriteResultBackpressure(0)
    }

    /// 对应 Bun: pub fn writeHeaderInt(this, key, value) void
    public func writeHeaderInt(key: Array<UInt8>, value: UInt64): Unit {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { r.writeHeaderInt(key, value) }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { r.writeHeaderInt(key, value) }
            | ResponseType.h3 => {}
        }
    }

    /// 对应 Bun: pub fn endWithoutBody(this, close_connection) void
    public func endWithoutBody(closeConnection: Bool): Unit {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { r.endWithoutBody(closeConnection) }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { r.endWithoutBody(closeConnection) }
            | ResponseType.h3 => {}
        }
    }

    /// 对应 Bun: pub fn endSendFile(this, write_offset, close_connection) void
    public func endSendFile(writeOffset: UInt64, closeConnection: Bool): Unit {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { r.endSendFile(writeOffset, closeConnection) }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { r.endSendFile(writeOffset, closeConnection) }
            | ResponseType.h3 => {}
        }
    }

    /// 对应 Bun: pub fn timeout(this, seconds) void
    public func timeout(seconds: UInt8): Unit {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { r.timeout(seconds) }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { r.timeout(seconds) }
            | ResponseType.h3 => {}
        }
    }

    /// 对应 Bun: pub fn pause(this) void
    public func pause(): Unit {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { r.pause() }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { r.pause() }
            | ResponseType.h3 => {}
        }
    }

    /// 对应 Bun: pub fn @"resume"(this) void
    public func resume(): Unit {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { r.resume() }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { r.resume() }
            | ResponseType.h3 => {}
        }
    }

    /// 对应 Bun: pub fn shouldCloseConnection(this) bool
    public func shouldCloseConnection(): Bool {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { return r.shouldCloseConnection() }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { return r.shouldCloseConnection() }
            | ResponseType.h3 => {}
        }
        return false
    }

    /// 对应 Bun: pub fn getWriteOffset(this) u64
    public func getWriteOffset(): UInt64 {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { return r.getWriteOffset() }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { return r.getWriteOffset() }
            | ResponseType.h3 => {}
        }
        return 0
    }

    /// 对应 Bun: pub fn getBufferedAmount(this) u64
    public func getBufferedAmount(): UInt64 {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { return r.getBufferedAmount() }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { return r.getBufferedAmount() }
            | ResponseType.h3 => {}
        }
        return 0
    }

    /// 对应 Bun: pub fn writeContinue(this) void
    public func writeContinue(): Unit {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { r.writeContinue() }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { r.writeContinue() }
            | ResponseType.h3 => {}
        }
    }

    /// 对应 Bun: pub fn state(this) State
    public func state(): State {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { return r.state() }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { return r.state() }
            | ResponseType.h3 => {}
        }
        return State.HTTP_RESPONSE_PENDING
    }

    /// 对应 Bun: pub fn hasResponded - via state
    public func hasResponded(): Bool {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { return r.hasResponded() }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { return r.hasResponded() }
            | ResponseType.h3 => {}
        }
        return false
    }

    /// 对应 Bun: pub fn isCorked(this) bool
    public func isCorked(): Bool {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { return r.isCorked() }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { return r.isCorked() }
            | ResponseType.h3 => return false
        }
        return false
    }

    /// 对应 Bun: pub fn uncork(this) void
    public func uncork(): Unit {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { r.uncork() }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { r.uncork() }
            | ResponseType.h3 => {}
        }
    }

    /// 对应 Bun: pub fn markNeedsMore(this) void
    public func markNeedsMore(): Unit {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { r.markNeedsMore() }
            | ResponseType.ssl => {}
            | ResponseType.h3 => {}
        }
    }

    /// 对应 Bun: pub fn markWroteContentLengthHeader(this) void
    public func markWroteContentLengthHeader(): Unit {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { r.markWroteContentLengthHeader() }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { r.markWroteContentLengthHeader() }
            | ResponseType.h3 => {}
        }
    }

    /// 对应 Bun: pub fn writeMark(this) void
    public func writeMark(): Unit {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { r.writeMark() }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { r.writeMark() }
            | ResponseType.h3 => {}
        }
    }

    /// 对应 Bun: pub fn clearAborted(this) void
    public func clearAborted(): Unit {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { r.clearAborted() }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { r.clearAborted() }
            | ResponseType.h3 => {}
        }
    }

    /// 对应 Bun: pub fn clearTimeout(this) void
    public func clearTimeout(): Unit {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { r.clearTimeout() }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { r.clearTimeout() }
            | ResponseType.h3 => {}
        }
    }

    /// 对应 Bun: pub fn clearOnWritable(this) void
    public func clearOnWritable(): Unit {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { r.clearOnWritable() }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { r.clearOnWritable() }
            | ResponseType.h3 => {}
        }
    }

    /// 对应 Bun: pub fn clearOnData(this) void
    public func clearOnData(): Unit {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { r.clearOnData() }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { r.clearOnData() }
            | ResponseType.h3 => {}
        }
    }

    /// 对应 Bun: pub fn isConnectRequest(this) bool
    public func isConnectRequest(): Bool {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { return r.isConnectRequest() }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { return r.isConnectRequest() }
            | ResponseType.h3 => return false
        }
        return false
    }

    /// 对应 Bun: pub fn endStream(this, close_connection) void
    public func endStream(closeConnection: Bool): Unit {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { r.endStream(closeConnection) }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { r.endStream(closeConnection) }
            | ResponseType.h3 => {}
        }
    }

    /// 对应 Bun: pub fn prepareForSendfile(this) void
    public func prepareForSendfile(): Unit {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { r.prepareForSendfile() }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { r.prepareForSendfile() }
            | ResponseType.h3 => {}
        }
    }

    /// 对应 Bun: pub fn getNativeHandle(this) bun.FD
    public func getNativeHandle(): CPointer<Unit> {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { return r.getNativeHandle() }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { return r.getNativeHandle() }
            | ResponseType.h3 => return CPointer<Unit>.null
        }
        return CPointer<Unit>.null
    }

    /// 对应 Bun: pub fn getSocketData(this) ?*anyopaque
    public func getSocketData(): CPointer<Unit> {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) { return r.getSocketData() }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) { return r.getSocketData() }
            | ResponseType.h3 => return CPointer<Unit>.null
        }
        return CPointer<Unit>.null
    }

    /// 对应 Bun: pub fn getRemoteSocketInfo(this) ?SocketAddress
    public func getRemoteSocketInfo(): ?SocketAddress {
        return None
    }

    /// 对应 Bun: pub fn forceClose(this) void
    public func forceClose(): Unit {
        match (responseType) {
            | ResponseType.tcp => if (let Some(r) <- tcpResp) {
                let socket = UsSocket(r.getPtr())
                socket.close(CloseCode.failure)
            }
            | ResponseType.ssl => if (let Some(r) <- tlsResp) {
                let socket = UsSocket(r.getPtr())
                socket.close(CloseCode.failure)
            }
            | ResponseType.h3 => {}
        }
    }
}
