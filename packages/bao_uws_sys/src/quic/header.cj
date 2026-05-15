// 严格翻译自: src/uws_sys/quic/Header.zig
package bao_uws_sys.quic

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
public enum Qpack {
    | authority
    | path
    | content_disposition
    | content_length
    | cookie
    | date
    | etag
    | if_modified_since
    | if_none_match
    | last_modified
    | link
    | location
    | referer
    | set_cookie
    | method_get
    | scheme_https
    | accept
    | accept_encoding
    | accept_ranges
    | cache_control
    | content_encoding
    | content_type
    | range
    | vary
    | accept_language
    | authorization
    | forwarded
    | if_range
    | origin
    | server
    | user_agent
    | x_forwarded_for
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
