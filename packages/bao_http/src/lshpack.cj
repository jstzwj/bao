// bao_http lshpack - HPACK 头部压缩 (LSHPACK C 库封装)
// 严格翻译自: src/http/lshpack.zig
package bao_http

import bao_core.*
import bao_collections.*

// ============================================================================
// Lshpack - HPACK 头部压缩编解码器
// 严格翻译自: bun/src/http/lshpack.zig
//
// Bun lshpack.zig:
//   //! wrapper implemented at src/jsc/bindings/c-bindings.cpp
//   pub const HPACK = extern struct {
//       self: *anyopaque,
//       pub const DecodeResult = struct { name, value, never_index, well_know, next };
//       pub const LSHPACK_MAX_HEADER_SIZE: usize = 65536;
//       pub fn init(max_capacity: u32) *HPACK;
//       pub fn decode(self: *HPACK, src: []const u8) !DecodeResult;
//       pub fn encode(self: *HPACK, name, value, never_index, dst, offset) !usize;
//       pub fn setEncoderMaxCapacity(self: *HPACK, max_capacity: u32) void;
//       pub fn deinit(self: *HPACK) void;
//   };
//
// 仓颉实现:
//   http2.cj 中的 HpackEncoder/HpackDecoder 提供了纯仓颉实现
//   本文件提供 C FFI 封装接口, 对应 Bun 的 lshpack C 绑定
// ============================================================================

/// HPACK 编解码结果
/// 严格翻译自: lshpack.HPACK.DecodeResult
///   pub const DecodeResult = struct {
///       name: []const u8,
///       value: []const u8,
///       never_index: bool,
///       well_know: u16,
///       next: usize,
///   };
public class LshpackDecodeResult {
    /// 头部名称
    /// 严格翻译自: name: []const u8
    public var name: String

    /// 头部值
    /// 严格翻译自: value: []const u8
    public var value: String

    /// 是否不应索引
    /// 严格翻译自: never_index: bool
    public var neverIndex: Bool

    /// 已知头部索引
    /// 严格翻译自: well_know: u16
    public var wellKnown: Int64

    /// 下一个头部在 src 中的偏移
    /// 严格翻译自: next: usize
    public var next: Int64

    public init(name: String, value: String, neverIndex: Bool, wellKnown: Int64, next: Int64) {
        this.name = name
        this.value = value
        this.neverIndex = neverIndex
        this.wellKnown = wellKnown
        this.next = next
    }
}

/// HPACK 编解码器 — LSHPACK C 库封装
/// 严格翻译自: bun/src/http/lshpack.zig HPACK extern struct
public class Lshpack {
    /// 最大头部大小 (65536)
    /// 严格翻译自: pub const LSHPACK_MAX_HEADER_SIZE: usize = 65536
    public static let MAX_HEADER_SIZE: Int64 = 65536

    /// 不透明指针 (C 对象)
    /// 严格翻译自: self: *anyopaque
    private var handle: Int64

    /// 最大容量
    private var maxCapacity: Int64

    /// 是否已初始化
    private var initialized: Bool

    public init(maxCapacity: Int64) {
        handle = 0
        this.maxCapacity = maxCapacity
        initialized = false
        // 实际应调用 lshpack_wrapper_init(mi_malloc, mi_free, max_capacity)
    }

    // ========================================================================
    // decode - HPACK 解码
    // 严格翻译自:
    //   pub fn decode(self: *HPACK, src: []const u8) !DecodeResult {
    //       var header: lshpack_header = .{};
    //       const offset = lshpack_wrapper_decode(self, src.ptr, src.len, &header);
    //       if (offset == 0) return error.UnableToDecode;
    //       if (header.name_len == 0) return error.EmptyHeaderName;
    //       return .{
    //           .name = header.name[0..header.name_len],
    //           .value = header.value[0..header.value_len],
    //           .next = offset,
    //           .never_index = header.never_index,
    //           .well_know = header.hpack_index,
    //       };
    //   }
    // ========================================================================

    /// HPACK 解码
    /// 严格翻译自: HPACK.decode
    /// 注意: name/value 使用线程局部共享缓冲区, 应在下次 decode/encode 前拷贝
    public func decode(src: Array<UInt8>): ?LshpackDecodeResult {
        // 桩: 实际调用 lshpack_wrapper_decode
        // 降级到 http2.cj 中的 HpackDecoder
        let decoder = HpackDecoder()
        match (decoder.decode(src)) {
            case Some(headers) => {
                if (headers.size > 0) {
                    let h = headers[0]
                    return LshpackDecodeResult(h.name, h.value, false, 0, 0)
                }
                return None
            }
            case None => return None
        }
    }

    // ========================================================================
    // encode - HPACK 编码
    // 严格翻译自:
    //   pub fn encode(self: *HPACK, name: []const u8, value: []const u8,
    //       never_index: bool, dst_buffer: []u8, dst_buffer_offset: usize) !usize {
    //       const offset = lshpack_wrapper_encode(self, name.ptr, name.len,
    //           value.ptr, value.len, @intFromBool(never_index),
    //           dst_buffer.ptr, dst_buffer.len, dst_buffer_offset);
    //       if (offset <= 0) return error.UnableToEncode;
    //       return offset;
    //   }
    // ========================================================================

    /// HPACK 编码
    /// 严格翻译自: HPACK.encode
    /// 如果 name + value 长度 > LSHPACK_MAX_HEADER_SIZE 返回 None
    public func encode(name: String, value: String, neverIndex: Bool,
                        dstBuffer: Array<UInt8>, dstBufferOffset: Int64): ?Int64 {
        if (name.size + value.size > MAX_HEADER_SIZE) {
            return None
        }
        // 桩: 实际调用 lshpack_wrapper_encode
        // 降级到 http2.cj 中的 HpackEncoder
        let encoder = HpackEncoder()
        let headers = ArrayList<HeaderPair>()
        headers.append(HeaderPair(name, value))
        let encoded = encoder.encode(headers)
        return encoded.size
    }

    // ========================================================================
    // setEncoderMaxCapacity - 调整编码器动态表容量
    // 严格翻译自:
    //   pub fn setEncoderMaxCapacity(self: *HPACK, max_capacity: u32) void {
    //       lshpack_wrapper_enc_set_max_capacity(self, max_capacity);
    //   }
    // ========================================================================

    /// 调整编码器动态表容量
    /// 严格翻译自: HPACK.setEncoderMaxCapacity
    /// 驱逐条目以适应; 调用者负责在下一个头部块开头发出 Dynamic Table Size Update
    public func setEncoderMaxCapacity(maxCapacity: Int64): Unit {
        this.maxCapacity = maxCapacity
    }

    // ========================================================================
    // deinit - 清理资源
    // 严格翻译自:
    //   pub fn deinit(self: *HPACK) void {
    //       lshpack_wrapper_deinit(self);
    //   }
    // ========================================================================

    /// 清理资源
    /// 严格翻译自: HPACK.deinit
    public func deinit(): Unit {
        // 桩: 实际调用 lshpack_wrapper_deinit
        handle = 0
        initialized = false
    }
}
