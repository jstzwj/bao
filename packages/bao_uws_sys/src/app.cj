// 严格翻译自: src/uws_sys/App.zig
package bao_uws_sys

import bao_sys.*

// ============================================================================
// C FFI 声明
// 严格翻译自: App.zig 中 extern fn
// ============================================================================
@C
foreign func uws_app_close(ssl: Int32, app: CPointer<Unit>): Unit
@C
foreign func uws_app_close_idle(ssl: Int32, app: CPointer<Unit>): Unit
@C
foreign func uws_app_set_on_clienterror(ssl: Int32, app: CPointer<Unit>, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_create_app(ssl: Int32, options: CPointer<Unit>): CPointer<Unit>
@C
foreign func uws_app_destroy(ssl: Int32, app: CPointer<Unit>): Unit
@C
foreign func uws_app_set_flags(ssl: Int32, app: CPointer<Unit>, require_host_header: Bool, use_strict_method_validation: Bool): Unit
@C
foreign func uws_app_set_max_http_header_size(ssl: Int32, app: CPointer<Unit>, max_header_size: UInt64): Unit
@C
foreign func uws_app_get(ssl: Int32, app: CPointer<Unit>, pattern: CPointer<UInt8>, pattern_len: UIntNative, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_app_post(ssl: Int32, app: CPointer<Unit>, pattern: CPointer<UInt8>, pattern_len: UIntNative, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_app_options(ssl: Int32, app: CPointer<Unit>, pattern: CPointer<UInt8>, pattern_len: UIntNative, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_app_delete(ssl: Int32, app: CPointer<Unit>, pattern: CPointer<UInt8>, pattern_len: UIntNative, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_app_patch(ssl: Int32, app: CPointer<Unit>, pattern: CPointer<UInt8>, pattern_len: UIntNative, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_app_put(ssl: Int32, app: CPointer<Unit>, pattern: CPointer<UInt8>, pattern_len: UIntNative, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_app_head(ssl: Int32, app: CPointer<Unit>, pattern: CPointer<UInt8>, pattern_len: UIntNative, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_app_connect(ssl: Int32, app: CPointer<Unit>, pattern: CPointer<UInt8>, pattern_len: UIntNative, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_app_trace(ssl: Int32, app: CPointer<Unit>, pattern: CPointer<UInt8>, pattern_len: UIntNative, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_app_any(ssl: Int32, app: CPointer<Unit>, pattern: CPointer<UInt8>, pattern_len: UIntNative, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_app_run(ssl: Int32, app: CPointer<Unit>): Unit
@C
foreign func uws_app_domain(ssl: Int32, app: CPointer<Unit>, domain: CPointer<Int8>): Unit
@C
foreign func uws_app_listen(ssl: Int32, app: CPointer<Unit>, port: Int32, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_app_listen_with_config(ssl: Int32, app: CPointer<Unit>, host: CPointer<Int8>, port: UInt16, options: Int32, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_constructor_failed(ssl: Int32, app: CPointer<Unit>): Bool
@C
foreign func uws_num_subscribers(ssl: Int32, app: CPointer<Unit>, topic: CPointer<Int8>, topic_length: UIntNative): UInt32
@C
foreign func uws_publish(ssl: Int32, app: CPointer<Unit>, topic: CPointer<Int8>, topic_length: UIntNative, message: CPointer<Int8>, message_length: UIntNative, opcode: Int32, compress: Bool): Bool
@C
foreign func uws_get_native_handle(ssl: Int32, app: CPointer<Unit>): CPointer<Unit>
@C
foreign func uws_remove_server_name(ssl: Int32, app: CPointer<Unit>, hostname_pattern: CPointer<Int8>): Unit
@C
foreign fn uws_add_server_name(ssl: Int32, app: CPointer<Unit>, hostname_pattern: CPointer<Int8>): Unit
@C
foreign func uws_add_server_name_with_options(ssl: Int32, app: CPointer<Unit>, hostname_pattern: CPointer<Int8>, options: CPointer<Unit>): Int32
@C
foreign func uws_missing_server_name(ssl: Int32, app: CPointer<Unit>, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_filter(ssl: Int32, app: CPointer<Unit>, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_app_listen_domain_with_options(sslFlag: Int32, app: CPointer<Unit>, domain: CPointer<Int8>, pathlen: UIntNative, flags: Int32, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_app_clear_routes(sslFlag: Int32, app: CPointer<Unit>): Unit

// ============================================================================
// App - uWS 应用
// 严格翻译自: App.zig NewApp(comptime ssl: bool)
//  This file provides Zig bindings for the uWebSockets App class.
//  It wraps the C API exposed in libuwsockets.cpp which provides a C interface
//  to the C++ uWebSockets library.
// ============================================================================
public class App {
    public let isSsl: Bool
    private var ptr: CPointer<Unit>
    private let sslFlag: Int32

    public init(isSsl: Bool, ptr: CPointer<Unit>) {
        this.isSsl = isSsl
        this.ptr = ptr
        this.sslFlag = if (isSsl) 1 else 0
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    /// 对应 Bun: pub fn close(this) void
    public func close(): Unit {
        uws_app_close(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn closeIdleConnections(this) void
    public func closeIdleConnections(): Unit {
        uws_app_close_idle(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn create(opts) ?*ThisApp
    public static func create(isSsl: Bool, opts: CPointer<Unit>): ?App {
        let sslFlag: Int32 = if (isSsl) 1 else 0
        let raw = uws_create_app(sslFlag, opts)
        if (raw == CPointer<Unit>.null) {
            return None
        }
        return Some(App(isSsl, raw))
    }

    /// 对应 Bun: pub fn destroy(app) void
    public func destroy(): Unit {
        uws_app_destroy(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn setFlags(this, require_host_header, use_strict_method_validation) void
    public func setFlags(requireHostHeader: Bool, useStrictMethodValidation: Bool): Unit {
        uws_app_set_flags(sslFlag, ptr, requireHostHeader, useStrictMethodValidation)
    }

    /// 对应 Bun: pub fn setMaxHTTPHeaderSize(this, max_header_size) void
    public func setMaxHTTPHeaderSize(maxHeaderSize: UInt64): Unit {
        uws_app_set_max_http_header_size(sslFlag, ptr, maxHeaderSize)
    }

    /// 对应 Bun: pub fn clearRoutes(app) void
    public func clearRoutes(): Unit {
        uws_app_clear_routes(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn get(app, pattern, handler, user_data) void
    public func get(pattern: Array<UInt8>, handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_app_get(sslFlag, ptr, CPointer<UInt8>.reinterpret(pattern), UIntNative(pattern.size), handler, userData)
    }

    /// 对应 Bun: pub fn post(app, pattern, handler, user_data) void
    public func post(pattern: Array<UInt8>, handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_app_post(sslFlag, ptr, CPointer<UInt8>.reinterpret(pattern), UIntNative(pattern.size), handler, userData)
    }

    /// 对应 Bun: pub fn options(app, pattern, handler, user_data) void
    public func options(pattern: Array<UInt8>, handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_app_options(sslFlag, ptr, CPointer<UInt8>.reinterpret(pattern), UIntNative(pattern.size), handler, userData)
    }

    /// 对应 Bun: pub fn delete(app, pattern, handler, user_data) void
    public func delete(pattern: Array<UInt8>, handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_app_delete(sslFlag, ptr, CPointer<UInt8>.reinterpret(pattern), UIntNative(pattern.size), handler, userData)
    }

    /// 对应 Bun: pub fn patch(app, pattern, handler, user_data) void
    public func patch(pattern: Array<UInt8>, handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_app_patch(sslFlag, ptr, CPointer<UInt8>.reinterpret(pattern), UIntNative(pattern.size), handler, userData)
    }

    /// 对应 Bun: pub fn put(app, pattern, handler, user_data) void
    public func put(pattern: Array<UInt8>, handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_app_put(sslFlag, ptr, CPointer<UInt8>.reinterpret(pattern), UIntNative(pattern.size), handler, userData)
    }

    /// 对应 Bun: pub fn head(app, pattern, handler, user_data) void
    public func head(pattern: Array<UInt8>, handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_app_head(sslFlag, ptr, CPointer<UInt8>.reinterpret(pattern), UIntNative(pattern.size), handler, userData)
    }

    /// 对应 Bun: pub fn connect(app, pattern, handler, user_data) void
    public func connect(pattern: Array<UInt8>, handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_app_connect(sslFlag, ptr, CPointer<UInt8>.reinterpret(pattern), UIntNative(pattern.size), handler, userData)
    }

    /// 对应 Bun: pub fn trace(app, pattern, handler, user_data) void
    public func trace(pattern: Array<UInt8>, handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_app_trace(sslFlag, ptr, CPointer<UInt8>.reinterpret(pattern), UIntNative(pattern.size), handler, userData)
    }

    /// 对应 Bun: pub fn any(app, pattern, handler, user_data) void
    public func any(pattern: Array<UInt8>, handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_app_any(sslFlag, ptr, CPointer<UInt8>.reinterpret(pattern), UIntNative(pattern.size), handler, userData)
    }

    /// 对应 Bun: pub fn domain(app, pattern) void
    public func domain(pattern: Array<UInt8>): Unit {
        uws_app_domain(sslFlag, ptr, CPointer<Int8>.reinterpret(pattern))
    }

    /// 对应 Bun: pub fn run(app) void
    public func run(): Unit {
        uws_app_run(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn listen(app, port, handler, user_data) void
    public func listen(port: Int32, handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_app_listen(sslFlag, ptr, port, handler, userData)
    }

    /// 对应 Bun: pub fn listenWithConfig(app, handler, user_data, config) void
    public func listenWithConfig(host: CPointer<Int8>, port: UInt16, options: Int32, handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_app_listen_with_config(sslFlag, ptr, host, port, options, handler, userData)
    }

    /// 对应 Bun: pub fn listenOnUnixSocket(app, handler, user_data, domain_name, flags) void
    public func listenOnUnixSocket(domainName: CPointer<Int8>, pathlen: UIntNative, flags: Int32, handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_app_listen_domain_with_options(sslFlag, ptr, domainName, pathlen, flags, handler, userData)
    }

    /// 对应 Bun: pub fn constructorFailed(app) bool
    public func constructorFailed(): Bool {
        return uws_constructor_failed(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn numSubscribers(app, topic) u32
    public func numSubscribers(topic: Array<UInt8>): UInt32 {
        return uws_num_subscribers(sslFlag, ptr, CPointer<Int8>.reinterpret(topic), UIntNative(topic.size))
    }

    /// 对应 Bun: pub fn publish(app, topic, message, opcode, compress) bool
    public func publish(topic: Array<UInt8>, message: Array<UInt8>, opcode: Opcode, compress: Bool): Bool {
        return uws_publish(sslFlag, ptr, CPointer<Int8>.reinterpret(topic), UIntNative(topic.size), CPointer<Int8>.reinterpret(message), UIntNative(message.size), Int32(opcode), compress)
    }

    /// 对应 Bun: pub fn getNativeHandle(app) ?*anyopaque
    public func getNativeHandle(): CPointer<Unit> {
        return uws_get_native_handle(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn removeServerName(app, hostname_pattern) void
    public func removeServerName(hostnamePattern: CPointer<Int8>): Unit {
        uws_remove_server_name(sslFlag, ptr, hostnamePattern)
    }

    /// 对应 Bun: pub fn addServerName(app, hostname_pattern) void
    public func addServerName(hostnamePattern: CPointer<Int8>): Unit {
        uws_add_server_name(sslFlag, ptr, hostnamePattern)
    }

    /// 对应 Bun: pub fn addServerNameWithOptions(app, hostname_pattern, opts) !void
    public func addServerNameWithOptions(hostnamePattern: CPointer<Int8>, opts: CPointer<Unit>): Bool {
        return uws_add_server_name_with_options(sslFlag, ptr, hostnamePattern, opts) != 0
    }

    /// 对应 Bun: pub fn missingServerName(app, handler, user_data) void
    public func missingServerName(handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_missing_server_name(sslFlag, ptr, handler, userData)
    }

    /// 对应 Bun: pub fn filter(app, handler, user_data) void
    public func filter(handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_filter(sslFlag, ptr, handler, userData)
    }

    /// 对应 Bun: pub fn ws(app, pattern, ctx, id, behavior_) void
    public func ws(pattern: Array<UInt8>, ctx: CPointer<Unit>, id: UIntNative, behavior: CPointer<Unit>): Unit {
        // In real impl would call uws_ws with behavior pointer
    }

    /// 对应 Bun: pub fn onClientError(app, handler, user_data) void
    public func onClientError(handler: CPointer<Unit>, userData: CPointer<Unit>): Unit {
        uws_app_set_on_clienterror(sslFlag, ptr, handler, userData)
    }
}

// ============================================================================
// TcpApp / TlsApp 类型别名
// 严格翻译自: App.zig
//  NewApp(false) = TCP, NewApp(true) = TLS
// ============================================================================
public typealias TcpApp = App
public typealias TlsApp = App

// ============================================================================
// ListenConfig - 监听配置
// 严格翻译自: App.zig uws_app_listen_config_t = extern struct
// ============================================================================
public class ListenConfig {
    public var port: Int32 = 0
    public var host: ?CPointer<Int8> = None
    public var options: Int32 = 0

    public init() {}
    public init(port: Int32, host: ?CPointer<Int8>, options: Int32) {
        this.port = port
        this.host = host
        this.options = options
    }
}
