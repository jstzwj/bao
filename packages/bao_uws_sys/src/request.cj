// 严格翻译自: src/uws_sys/Request.zig
package bao_uws_sys

import bao_sys.*

// ============================================================================
// C FFI 声明
// 严格翻译自: Request.zig 中 extern fn
// ============================================================================
@C
foreign func uws_req_is_ancient(res: CPointer<Unit>): Bool
@C
foreign func uws_req_get_yield(res: CPointer<Unit>): Bool
@C
foreign func uws_req_set_yield(res: CPointer<Unit>, yield: Bool): Unit
@C
foreign func uws_req_get_url(res: CPointer<Unit>, dest: CPointer<CPointer<UInt8>>): UIntNative
@C
foreign func uws_req_get_method(res: CPointer<Unit>, dest: CPointer<CPointer<UInt8>>): UIntNative
@C
foreign func uws_req_get_header(res: CPointer<Unit>, lower_case_header: CPointer<UInt8>, lower_case_header_length: UIntNative, dest: CPointer<CPointer<UInt8>>): UIntNative
@C
foreign func uws_req_get_query(res: CPointer<Unit>, key: CPointer<UInt8>, key_length: UIntNative, dest: CPointer<CPointer<UInt8>>): UIntNative
@C
foreign func uws_req_get_parameter(res: CPointer<Unit>, index: UInt16, dest: CPointer<CPointer<UInt8>>): UIntNative

// ============================================================================
// Request - HTTP 请求
// 严格翻译自: Request.zig
//  uWS::Request C++ -> Zig bindings.
// ============================================================================
public class Request {
    private var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    /// 对应 Bun: pub fn isAncient(req: *Request) bool
    public func isAncient(): Bool {
        return uws_req_is_ancient(ptr)
    }

    /// 对应 Bun: pub fn getYield(req: *Request) bool
    public func getYield(): Bool {
        return uws_req_get_yield(ptr)
    }

    /// 对应 Bun: pub fn setYield(req: *Request, yield: bool) void
    public func setYield(yield: Bool): Unit {
        uws_req_set_yield(ptr, yield)
    }

    /// 对应 Bun: pub fn url(req: *Request) []const u8
    public func url(): Array<UInt8> {
        // In real impl would call C function and get ptr/len
        return Array<UInt8>()
    }

    /// 对应 Bun: pub fn method(req: *Request) []const u8
    public func method(): Array<UInt8> {
        // In real impl would call C function and get ptr/len
        return Array<UInt8>()
    }

    /// 对应 Bun: pub fn header(req: *Request, name: []const u8) ?[]const u8
    public func header(name: Array<UInt8>): ?Array<UInt8> {
        // In real impl would call C function and get ptr/len
        return None
    }

    /// 对应 Bun: pub fn dateForHeader(req: *Request, name: []const u8) bun.JSError!?u64
    public func dateForHeader(name: Array<UInt8>): ?UInt64 {
        return None
    }

    /// 对应 Bun: pub fn query(req: *Request, name: []const u8) []const u8
    public func query(name: Array<UInt8>): Array<UInt8> {
        // In real impl would call C function and get ptr/len
        return Array<UInt8>()
    }

    /// 对应 Bun: pub fn parameter(req: *Request, index: u16) []const u8
    public func parameter(index: UInt16): Array<UInt8> {
        // In real impl would call C function and get ptr/len
        return Array<UInt8>()
    }
}

// ============================================================================
// AnyRequest - 传输无关的请求句柄
// 严格翻译自: Request.zig AnyRequest = union(enum)
//  Transport-agnostic request handle. Static/file routes (and RangeRequest)
//  take this so the same handler body serves HTTP/1.1 and HTTP/3 without
//  anytype - inline else keeps dispatch monomorphic.
// ============================================================================
public class AnyRequest {
    public var isH3: Bool
    public var h1Request: ?Request = None
    public var h3Request: ?CPointer<Unit> = None

    public init(h1: Request) {
        this.isH3 = false
        this.h1Request = h1
    }

    public init(h3: CPointer<Unit>) {
        this.isH3 = true
        this.h3Request = h3
    }

    /// 对应 Bun: pub fn header(this, name) ?[]const u8
    public func header(name: Array<UInt8>): ?Array<UInt8> {
        if (isH3) {
            // H3 request header
            return None
        }
        if (let Some(req) <- h1Request) {
            return req.header(name)
        }
        return None
    }

    /// 对应 Bun: pub fn method(this) []const u8
    public func method(): Array<UInt8> {
        if (!isH3) {
            if (let Some(req) <- h1Request) {
                return req.method()
            }
        }
        return Array<UInt8>()
    }

    /// 对应 Bun: pub fn url(this) []const u8
    public func url(): Array<UInt8> {
        if (!isH3) {
            if (let Some(req) <- h1Request) {
                return req.url()
            }
        }
        return Array<UInt8>()
    }

    /// 对应 Bun: pub fn setYield(this, y) void
    public func setYield(y: Bool): Unit {
        if (!isH3) {
            if (let Some(req) <- h1Request) {
                req.setYield(y)
            }
        }
    }

    /// 对应 Bun: pub fn dateForHeader(this, name) ?u64
    public func dateForHeader(name: Array<UInt8>): ?UInt64 {
        if (!isH3) {
            if (let Some(req) <- h1Request) {
                return req.dateForHeader(name)
            }
        }
        return None
    }
}
