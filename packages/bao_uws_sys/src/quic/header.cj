// 严格翻译自: src/uws_sys/quic/Header.zig
package bao_uws_sys

import bao_sys.*

// ============================================================================
// QuicHeader - QUIC 头部
// 严格翻译自: quic/Header.zig
//  us_quic_header_t plus the QPACK static-table index (enum lsqpack_tnv,
//  RFC 9204 Appendix A).
// ============================================================================
public class QuicHeader {
    public var name: CPointer<UInt8> = CPointer<UInt8>.null
    public var name_len: UInt32 = 0
    public var value: CPointer<UInt8> = CPointer<UInt8>.null
    public var value_len: UInt32 = 0
    public var qpack_index: Int32 = -1

    public init() {}

    /// 对应 Bun: pub fn init(name_, value_, idx) Header
    public init(name: Array<UInt8>, value: Array<UInt8>, idx: ?Qpack) {
        this.name = CPointer<UInt8>.reinterpret(name)
        this.name_len = UInt32(name.size)
        this.value = CPointer<UInt8>.reinterpret(value)
        this.value_len = UInt32(value.size)
        if (let Some(i) <- idx) {
            this.qpack_index = Int32(i)
        } else {
            this.qpack_index = -1
        }
    }
}

// ============================================================================
// Qpack - QPACK 静态表索引
// 严格翻译自: quic/Header.zig Qpack = enum(u8)
//  enum lsqpack_tnv. Only the entries a request encoder actually emits are
//  named; the rest are still reachable via @enumFromInt.
// ============================================================================
public enum Qpack <: UInt8 {
    authority = 0
    path = 1
    content_disposition = 3
    content_length = 4
    cookie = 5
    date = 6
    etag = 7
    if_modified_since = 8
    if_none_match = 9
    last_modified = 10
    link = 11
    location = 12
    referer = 13
    set_cookie = 14
    method_get = 17
    scheme_https = 23
    accept = 29
    accept_encoding = 31
    accept_ranges = 32
    cache_control = 36
    content_encoding = 43
    content_type = 44
    range = 55
    vary = 59
    accept_language = 72
    authorization = 84
    forwarded = 88
    if_range = 89
    origin = 90
    server = 92
    user_agent = 95
    x_forwarded_for = 96
}

// ============================================================================
// QpackClass - QPACK 分类
// 严格翻译自: quic/Header.zig Qpack.Class = union(enum)
// ============================================================================
public open class QpackClass {}

/// RFC 9114 4.2 connection-specific field - MUST NOT be sent.
public class QpackClassForbidden <: QpackClass {}

/// Host header - drop and use the value as :authority.
public class QpackClassHost <: QpackClass {}

/// In the QPACK static table; name is the canonical lowercase form.
public class QpackClassIndexed <: QpackClass {
    public let name: String
    public let index: Qpack
    public init(name: String, index: Qpack) {
        this.name = name
        this.index = index
    }
}
