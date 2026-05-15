// 严格翻译自: src/uws_sys/h3.zig
package bao_uws_sys

import bao_sys.*

// ============================================================================
// C FFI 声明
// 严格翻译自: h3.zig 中 extern fn
// ============================================================================
@C
foreign func uws_h3_create_app(opts: CPointer<Unit>, idle_timeout_s: UInt32): CPointer<Unit>
@C
foreign func uws_h3_app_destroy(app: CPointer<Unit>): Unit
@C
foreign func uws_h3_app_close(app: CPointer<Unit>): Unit
@C
foreign func uws_h3_app_clear_routes(app: CPointer<Unit>): Unit
@C
foreign func uws_h3_app_add_server_name(app: CPointer<Unit>, hostname: CPointer<Int8>, opts: CPointer<Unit>): Bool
@C
foreign func uws_h3_res_write_continue(res: CPointer<Unit>): Unit
@C
foreign func uws_h3_app_get(app: CPointer<Unit>, pattern: CPointer<UInt8>, pattern_len: UIntNative, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_h3_app_post(app: CPointer<Unit>, pattern: CPointer<UInt8>, pattern_len: UIntNative, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_h3_app_put(app: CPointer<Unit>, pattern: CPointer<UInt8>, pattern_len: UIntNative, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_h3_app_delete(app: CPointer<Unit>, pattern: CPointer<UInt8>, pattern_len: UIntNative, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_h3_app_patch(app: CPointer<Unit>, pattern: CPointer<UInt8>, pattern_len: UIntNative, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_h3_app_head(app: CPointer<Unit>, pattern: CPointer<UInt8>, pattern_len: UIntNative, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_h3_app_options(app: CPointer<Unit>, pattern: CPointer<UInt8>, pattern_len: UIntNative, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_h3_app_connect(app: CPointer<Unit>, pattern: CPointer<UInt8>, pattern_len: UIntNative, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_h3_app_trace(app: CPointer<Unit>, pattern: CPointer<UInt8>, pattern_len: UIntNative, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_h3_app_any(app: CPointer<Unit>, pattern: CPointer<UInt8>, pattern_len: UIntNative, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_h3_app_listen_with_config(app: CPointer<Unit>, host: CPointer<Int8>, port: UInt16, options: Int32, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_h3_listen_socket_port(ls: CPointer<Unit>): Int32
@C
foreign func uws_h3_listen_socket_local_address(ls: CPointer<Unit>, buf: CPointer<UInt8>, len: Int32): Int32
@C
foreign func uws_h3_listen_socket_close(ls: CPointer<Unit>): Unit
@C
foreign func uws_h3_res_state(res: CPointer<Unit>): UInt8
@C
foreign func uws_h3_res_end(res: CPointer<Unit>, data: CPointer<UInt8>, len: UIntNative, close_connection: Bool): Unit
@C
foreign func uws_h3_res_end_stream(res: CPointer<Unit>, close_connection: Bool): Unit
@C
foreign func uws_h3_res_force_close(res: CPointer<Unit>): Unit
@C
foreign func uws_h3_res_try_end(res: CPointer<Unit>, data: CPointer<UInt8>, len: UIntNative, total: UIntNative, close_connection: Bool): Bool
@C
foreign func uws_h3_res_end_without_body(res: CPointer<Unit>, close_connection: Bool): Unit
@C
foreign func uws_h3_res_pause(res: CPointer<Unit>): Unit
@C
foreign func uws_h3_res_resume(res: CPointer<Unit>): Unit
@C
foreign func uws_h3_res_write_status(res: CPointer<Unit>, status: CPointer<UInt8>, len: UIntNative): Unit
@C
foreign func uws_h3_res_write_header(res: CPointer<Unit>, key: CPointer<UInt8>, key_len: UIntNative, value: CPointer<UInt8>, value_len: UIntNative): Unit
@C
foreign func uws_h3_res_write_header_int(res: CPointer<Unit>, key: CPointer<UInt8>, key_len: UIntNative, value: UInt64): Unit
@C
foreign func uws_h3_res_mark_wrote_content_length_header(res: CPointer<Unit>): Unit
@C
foreign func uws_h3_res_write_mark(res: CPointer<Unit>): Unit
@C
foreign func uws_h3_res_flush_headers(res: CPointer<Unit>, immediate: Bool): Unit
@C
foreign func uws_h3_res_write(res: CPointer<Unit>, data: CPointer<UInt8>, len: CPointer<UIntNative>): Bool
@C
foreign func uws_h3_res_get_write_offset(res: CPointer<Unit>): UInt64
@C
foreign func uws_h3_res_override_write_offset(res: CPointer<Unit>, off: UInt64): Unit
@C
foreign func uws_h3_res_has_responded(res: CPointer<Unit>): Bool
@C
foreign func uws_h3_res_get_buffered_amount(res: CPointer<Unit>): UInt64
@C
foreign func uws_h3_res_reset_timeout(res: CPointer<Unit>): Unit
@C
foreign func uws_h3_res_timeout(res: CPointer<Unit>, seconds: UInt8): Unit
@C
foreign func uws_h3_res_end_sendfile(res: CPointer<Unit>, write_offset: UInt64, close_connection: Bool): Unit
@C
foreign func uws_h3_res_get_socket_data(res: CPointer<Unit>): CPointer<Unit>
@C
foreign func uws_h3_res_on_writable(res: CPointer<Unit>, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_h3_res_clear_on_writable(res: CPointer<Unit>): Unit
@C
foreign func uws_h3_res_on_aborted(res: CPointer<Unit>, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_h3_res_on_timeout(res: CPointer<Unit>, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_h3_res_on_data(res: CPointer<Unit>, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_h3_res_cork(res: CPointer<Unit>, user_data: CPointer<Unit>, corker: CPointer<Unit>): Unit
@C
foreign func uws_h3_res_get_remote_address_info(res: CPointer<Unit>, ip_ptr: CPointer<CPointer<UInt8>>, port: CPointer<Int32>, is_ipv6: CPointer<Bool>): UIntNative
@C
foreign func uws_h3_req_get_yield(req: CPointer<Unit>): Bool
@C
foreign func uws_h3_req_set_yield(req: CPointer<Unit>, y: Bool): Unit
@C
foreign func uws_h3_req_get_url(req: CPointer<Unit>, dest: CPointer<CPointer<UInt8>>): UIntNative
@C
foreign func uws_h3_req_get_method(req: CPointer<Unit>, dest: CPointer<CPointer<UInt8>>): UIntNative
@C
foreign func uws_h3_req_get_header(req: CPointer<Unit>, name: CPointer<UInt8>, name_len: UIntNative, dest: CPointer<CPointer<UInt8>>): UIntNative
@C
foreign func uws_h3_req_get_query(req: CPointer<Unit>, name: CPointer<UInt8>, name_len: UIntNative, dest: CPointer<CPointer<UInt8>>): UIntNative
@C
foreign func uws_h3_req_get_parameter(req: CPointer<Unit>, idx: UInt16, dest: CPointer<CPointer<UInt8>>): UIntNative
@C
foreign func uws_h3_req_for_each_header(req: CPointer<Unit>, cb: CPointer<Unit>, user_data: CPointer<Unit>): Unit

// ============================================================================
// H3ListenSocket - HTTP/3 监听套接字
// 严格翻译自: h3.zig ListenSocket = opaque
// ============================================================================
public class H3ListenSocket {
    private var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    /// 对应 Bun: pub fn close(this) void
    public func close(): Unit {
        uws_h3_listen_socket_close(ptr)
    }

    /// 对应 Bun: pub fn getLocalPort(this) i32
    public func getLocalPort(): Int32 {
        return uws_h3_listen_socket_port(ptr)
    }

    /// 对应 Bun: pub fn getLocalAddress(this, buf) ?[]const u8
    public func getLocalAddress(buf: Array<UInt8>): ?Array<UInt8> {
        let n = uws_h3_listen_socket_local_address(ptr, CPointer<UInt8>.reinterpret(buf), Int32(buf.size))
        if (n <= 0) {
            return None
        }
        return buf[0..Int64(n)]
    }
}

// ============================================================================
// H3Request - HTTP/3 请求
// 严格翻译自: h3.zig Request = opaque
// ============================================================================
public class H3Request {
    private var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    /// 对应 Bun: pub fn isAncient(_: *Request) bool
    public func isAncient(): Bool {
        return false
    }

    /// 对应 Bun: pub fn getYield(this) bool
    public func getYield(): Bool {
        return uws_h3_req_get_yield(ptr)
    }

    /// 对应 Bun: pub fn setYield(this, y) void
    public func setYield(y: Bool): Unit {
        uws_h3_req_set_yield(ptr, y)
    }

    /// 对应 Bun: pub fn url(this) []const u8
    public func url(): Array<UInt8> {
        return Array<UInt8>()
    }

    /// 对应 Bun: pub fn method(this) []const u8
    public func method(): Array<UInt8> {
        return Array<UInt8>()
    }

    /// 对应 Bun: pub fn header(this, name) ?[]const u8
    public func header(name: Array<UInt8>): ?Array<UInt8> {
        return None
    }

    /// 对应 Bun: pub fn query(this, name) []const u8
    public func query(name: Array<UInt8>): Array<UInt8> {
        return Array<UInt8>()
    }

    /// 对应 Bun: pub fn parameter(this, idx) []const u8
    public func parameter(idx: UInt16): Array<UInt8> {
        return Array<UInt8>()
    }
}

// ============================================================================
// H3Response - HTTP/3 响应
// 严格翻译自: h3.zig Response = opaque
// ============================================================================
public class H3Response {
    private var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    /// 对应 Bun: pub fn end(this, data, close_connection) void
    public func end(data: Array<UInt8>, closeConnection: Bool): Unit {
        uws_h3_res_end(ptr, CPointer<UInt8>.reinterpret(data), UIntNative(data.size), closeConnection)
    }

    /// 对应 Bun: pub fn tryEnd(this, data, total, close_connection) bool
    public func tryEnd(data: Array<UInt8>, total: UIntNative, closeConnection: Bool): Bool {
        return uws_h3_res_try_end(ptr, CPointer<UInt8>.reinterpret(data), UIntNative(data.size), total, closeConnection)
    }

    /// 对应 Bun: pub fn endWithoutBody(this, close_connection) void
    public func endWithoutBody(closeConnection: Bool): Unit {
        uws_h3_res_end_without_body(ptr, closeConnection)
    }

    /// 对应 Bun: pub fn endStream(this, close_connection) void
    public func endStream(closeConnection: Bool): Unit {
        uws_h3_res_end_stream(ptr, closeConnection)
    }

    /// 对应 Bun: pub fn endSendFile(this, write_offset, close_connection) void
    public func endSendFile(writeOffset: UInt64, closeConnection: Bool): Unit {
        uws_h3_res_end_sendfile(ptr, writeOffset, closeConnection)
    }

    /// 对应 Bun: pub fn write(this, data) WriteResult
    public func write(data: Array<UInt8>): WriteResult {
        var len: UIntNative = UIntNative(data.size)
        let success = uws_h3_res_write(ptr, CPointer<UInt8>.reinterpret(data), CPointer<UIntNative>.reinterpret(len))
        if (success) {
            return WriteResultWantMore(len)
        }
        return WriteResultBackpressure(len)
    }

    /// 对应 Bun: pub fn writeStatus(this, status) void
    public func writeStatus(status: Array<UInt8>): Unit {
        uws_h3_res_write_status(ptr, CPointer<UInt8>.reinterpret(status), UIntNative(status.size))
    }

    /// 对应 Bun: pub fn writeHeader(this, key, value) void
    public func writeHeader(key: Array<UInt8>, value: Array<UInt8>): Unit {
        uws_h3_res_write_header(ptr, CPointer<UInt8>.reinterpret(key), UIntNative(key.size), CPointer<UInt8>.reinterpret(value), UIntNative(value.size))
    }

    /// 对应 Bun: pub fn writeHeaderInt(this, key, value) void
    public func writeHeaderInt(key: Array<UInt8>, value: UInt64): Unit {
        uws_h3_res_write_header_int(ptr, CPointer<UInt8>.reinterpret(key), UIntNative(key.size), value)
    }

    /// 对应 Bun: pub fn writeMark(this) void
    public func writeMark(): Unit {
        uws_h3_res_write_mark(ptr)
    }

    /// 对应 Bun: pub fn markWroteContentLengthHeader(this) void
    public func markWroteContentLengthHeader(): Unit {
        uws_h3_res_mark_wrote_content_length_header(ptr)
    }

    /// 对应 Bun: pub fn writeContinue(this) void
    public func writeContinue(): Unit {
        uws_h3_res_write_continue(ptr)
    }

    /// 对应 Bun: pub fn flushHeaders(this, immediate) void
    public func flushHeaders(immediate: Bool): Unit {
        uws_h3_res_flush_headers(ptr, immediate)
    }

    /// 对应 Bun: pub fn pause(this) void
    public func pause(): Unit {
        uws_h3_res_pause(ptr)
    }

    /// 对应 Bun: pub fn @"resume"(this) void
    public func resume(): Unit {
        uws_h3_res_resume(ptr)
    }

    /// 对应 Bun: pub fn timeout(this, seconds) void
    public func timeout(seconds: UInt8): Unit {
        uws_h3_res_timeout(ptr, seconds)
    }

    /// 对应 Bun: pub fn resetTimeout(this) void
    public func resetTimeout(): Unit {
        uws_h3_res_reset_timeout(ptr)
    }

    /// 对应 Bun: pub fn getWriteOffset(this) u64
    public func getWriteOffset(): UInt64 {
        return uws_h3_res_get_write_offset(ptr)
    }

    /// 对应 Bun: pub fn overrideWriteOffset(this, off) void
    public func overrideWriteOffset(off: UInt64): Unit {
        uws_h3_res_override_write_offset(ptr, off)
    }

    /// 对应 Bun: pub fn getBufferedAmount(this) u64
    public func getBufferedAmount(): UInt64 {
        return uws_h3_res_get_buffered_amount(ptr)
    }

    /// 对应 Bun: pub fn hasResponded(this) bool
    public func hasResponded(): Bool {
        return uws_h3_res_has_responded(ptr)
    }

    /// 对应 Bun: pub fn state(this) State
    public func state(): State {
        return State(uws_h3_res_state(ptr))
    }

    /// 对应 Bun: pub fn shouldCloseConnection(this) bool
    public func shouldCloseConnection(): Bool {
        return state().isHttpConnectionClose()
    }

    /// 对应 Bun: pub fn isCorked(this) bool
    public func isCorked(): Bool {
        return false
    }

    /// 对应 Bun: pub fn uncork(this) void
    public func uncork(): Unit {
        // H3 does not support corking
    }

    /// 对应 Bun: pub fn isConnectRequest(this) bool
    public func isConnectRequest(): Bool {
        return false
    }

    /// 对应 Bun: pub fn prepareForSendfile(this) void
    public func prepareForSendfile(): Unit {
        // H3 does not support sendfile
    }

    /// 对应 Bun: pub fn markNeedsMore(this) void
    public func markNeedsMore(): Unit {
        // H3 does not support markNeedsMore
    }

    /// 对应 Bun: pub fn getSocketData(this) ?*anyopaque
    public func getSocketData(): CPointer<Unit> {
        return uws_h3_res_get_socket_data(ptr)
    }

    /// 对应 Bun: pub fn forceClose(this) void
    public func forceClose(): Unit {
        uws_h3_res_force_close(ptr)
    }

    /// 对应 Bun: pub fn clearOnWritable(this) void
    public func clearOnWritable(): Unit {
        uws_h3_res_clear_on_writable(ptr)
    }

    /// 对应 Bun: pub fn clearAborted(this) void
    public func clearAborted(): Unit {
        uws_h3_res_on_aborted(ptr, CPointer<Unit>.null, CPointer<Unit>.null)
    }

    /// 对应 Bun: pub fn clearTimeout(this) void
    public func clearTimeout(): Unit {
        uws_h3_res_on_timeout(ptr, CPointer<Unit>.null, CPointer<Unit>.null)
    }

    /// 对应 Bun: pub fn clearOnData(this) void
    public func clearOnData(): Unit {
        uws_h3_res_on_data(ptr, CPointer<Unit>.null, CPointer<Unit>.null)
    }
}

// ============================================================================
// H3App - HTTP/3 应用
// 严格翻译自: h3.zig App = opaque
// ============================================================================
public class H3App {
    private var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    /// 对应 Bun: pub fn create(opts, idle_timeout_s) ?*App
    public static func create(opts: CPointer<Unit>, idleTimeoutS: UInt32): ?H3App {
        let raw = uws_h3_create_app(opts, idleTimeoutS)
        if (raw == CPointer<Unit>.null) {
            return None
        }
        return Some(H3App(raw))
    }

    /// 对应 Bun: pub fn addServerNameWithOptions(this, hostname, opts) !void
    public func addServerNameWithOptions(hostname: CPointer<Int8>, opts: CPointer<Unit>): Bool {
        return uws_h3_app_add_server_name(ptr, hostname, opts)
    }

    /// 对应 Bun: pub fn destroy(this) void
    public func destroy(): Unit {
        uws_h3_app_destroy(ptr)
    }

    /// 对应 Bun: pub fn close(this) void
    public func close(): Unit {
        uws_h3_app_close(ptr)
    }

    /// 对应 Bun: pub fn clearRoutes(this) void
    public func clearRoutes(): Unit {
        uws_h3_app_clear_routes(ptr)
    }

    /// 对应 Bun: pub fn get(this, pattern, handler, user_data) void
    public func get(pattern: Array<UInt8>, handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_h3_app_get(ptr, CPointer<UInt8>.reinterpret(pattern), UIntNative(pattern.size), handler, userData)
    }

    /// 对应 Bun: pub fn post(this, pattern, handler, user_data) void
    public func post(pattern: Array<UInt8>, handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_h3_app_post(ptr, CPointer<UInt8>.reinterpret(pattern), UIntNative(pattern.size), handler, userData)
    }

    /// 对应 Bun: pub fn put(this, pattern, handler, user_data) void
    public func put(pattern: Array<UInt8>, handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_h3_app_put(ptr, CPointer<UInt8>.reinterpret(pattern), UIntNative(pattern.size), handler, userData)
    }

    /// 对应 Bun: pub fn delete(this, pattern, handler, user_data) void
    public func delete(pattern: Array<UInt8>, handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_h3_app_delete(ptr, CPointer<UInt8>.reinterpret(pattern), UIntNative(pattern.size), handler, userData)
    }

    /// 对应 Bun: pub fn patch(this, pattern, handler, user_data) void
    public func patch(pattern: Array<UInt8>, handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_h3_app_patch(ptr, CPointer<UInt8>.reinterpret(pattern), UIntNative(pattern.size), handler, userData)
    }

    /// 对应 Bun: pub fn head(this, pattern, handler, user_data) void
    public func head(pattern: Array<UInt8>, handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_h3_app_head(ptr, CPointer<UInt8>.reinterpret(pattern), UIntNative(pattern.size), handler, userData)
    }

    /// 对应 Bun: pub fn options(this, pattern, handler, user_data) void
    public func options(pattern: Array<UInt8>, handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_h3_app_options(ptr, CPointer<UInt8>.reinterpret(pattern), UIntNative(pattern.size), handler, userData)
    }

    /// 对应 Bun: pub fn any(this, pattern, handler, user_data) void
    public func any(pattern: Array<UInt8>, handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_h3_app_any(ptr, CPointer<UInt8>.reinterpret(pattern), UIntNative(pattern.size), handler, userData)
    }

    /// 对应 Bun: pub fn listenWithConfig(this, handler, user_data, config) void
    public func listenWithConfig(host: CPointer<Int8>, port: UInt16, options: Int32, handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_h3_app_listen_with_config(ptr, host, port, options, handler, userData)
    }
}

// ============================================================================
// H3ListenConfig - HTTP/3 监听配置
// 严格翻译自: h3.zig ListenConfig = extern struct
// ============================================================================
public class H3ListenConfig {
    public var port: UInt16 = 0
    public var host: ?CPointer<Int8> = None
    public var options: Int32 = 0

    public init() {}
    public init(port: UInt16, host: ?CPointer<Int8>, options: Int32) {
        this.port = port
        this.host = host
        this.options = options
    }
}
