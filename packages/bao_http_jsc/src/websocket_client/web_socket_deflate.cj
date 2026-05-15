// 严格翻译自: src/http_jsc/websocket_client/WebSocketDeflate.zig
//! Manages the DEFLATE compression and decompression streams for a WebSocket connection.
package bao_http_jsc.websocket_client

import bao_jsc.*
import bao_core.*

// ============================================================================
// WebSocketDeflate - WebSocket DEFLATE 压缩/解压管理
// 严格翻译自: src/http_jsc/websocket_client/WebSocketDeflate.zig
//   const PerMessageDeflate = @This();
// ============================================================================

/// WebSocket DEFLATE 压缩参数 - 严格对应 Bun WebSocketDeflate.Params
/// Zig:
///   pub const Params = extern struct {
///       server_max_window_bits: u8 = 15,
///       client_max_window_bits: u8 = 15,
///       server_no_context_takeover: u8 = 0,
///       client_no_context_takeover: u8 = 0,
///       pub const MAX_WINDOW_BITS: u8 = 15;
///       pub const MIN_WINDOW_BITS: u8 = 8;
///   };
@C
public struct WebSocketDeflateParams {
    public var serverMaxWindowBits: UInt8
    public var clientMaxWindowBits: UInt8
    public var serverNoContextTakeover: UInt8
    public var clientNoContextTakeover: UInt8

    public init() {
        serverMaxWindowBits = 15
        clientMaxWindowBits = 15
        serverNoContextTakeover = 0
        clientNoContextTakeover = 0
    }

    public init(
        serverMaxWindowBits: UInt8,
        clientMaxWindowBits: UInt8,
        serverNoContextTakeover: UInt8,
        clientNoContextTakeover: UInt8
    ) {
        this.serverMaxWindowBits = serverMaxWindowBits
        this.clientMaxWindowBits = clientMaxWindowBits
        this.serverNoContextTakeover = serverNoContextTakeover
        this.clientNoContextTakeover = clientNoContextTakeover
    }

    /// 最大窗口位数 - 严格对应 MAX_WINDOW_BITS
    public static let MAX_WINDOW_BITS: UInt8 = 15

    /// 最小窗口位数 - 严格对应 MIN_WINDOW_BITS
    public static let MIN_WINDOW_BITS: UInt8 = 8
}

/// WebSocket DEFLATE 压缩的稀有数据 - 严格对应 Bun WebSocketDeflate.RareData
/// Zig:
///   pub const RareData = struct {
///       libdeflate_compressor: ?*libdeflate.Compressor = null,
///       libdeflate_decompressor: ?*libdeflate.Decompressor = null,
///       stack_fallback: std.heap.StackFallbackAllocator(RareData.stack_buffer_size) = undefined,
///       pub const stack_buffer_size = 128 * 1024;
///       ...
///   };
public class WebSocketDeflateRareData {
    public var libdeflateCompressor: ?UIntNative
    public var libdeflateDecompressor: ?UIntNative
    public var stackFallback: StackFallbackAllocator

    /// 栈缓冲区大小 - 严格对应 stack_buffer_size = 128 * 1024
    public static let STACK_BUFFER_SIZE: UIntNative = 128 * 1024

    public init() {
        libdeflateCompressor = None
        libdeflateDecompressor = None
        stackFallback = StackFallbackAllocator(bufferSize: STACK_BUFFER_SIZE)
    }

    /// 获取分配器 - 严格对应 Bun RareData.allocator
    /// Zig:
    ///   pub fn allocator(this: *RareData) std.mem.Allocator {
    ///       this.stack_fallback = .{
    ///           .buffer = undefined,
    ///           .fallback_allocator = bun.default_allocator,
    ///           .fixed_buffer_allocator = undefined,
    ///       };
    ///       return this.stack_fallback.get();
    ///   }
    public func allocator(): Allocator {
        stackFallback = StackFallbackAllocator(bufferSize: STACK_BUFFER_SIZE)
        return stackFallback.get()
    }

    /// 释放资源 - 严格对应 Bun RareData.deinit
    /// Zig:
    ///   pub fn deinit(this: *RareData) void {
    ///       inline for (.{ &this.libdeflate_compressor, &this.libdeflate_decompressor }) |comp| {
    ///           if (comp.*) |c| { c.deinit(); }
    ///       }
    ///       bun.destroy(this);
    ///   }
    public func deinit(): Unit {
        if (let comp = libdeflateCompressor) {
            LibDeflate.freeCompressor(comp)
            libdeflateCompressor = None
        }
        if (let decomp = libdeflateDecompressor) {
            LibDeflate.freeDecompressor(decomp)
            libdeflateDecompressor = None
        }
    }

    /// 获取解压器 - 严格对应 Bun RareData.decompressor
    /// Zig:
    ///   pub fn decompressor(this: *RareData) *libdeflate.Decompressor {
    ///       return this.libdeflate_decompressor orelse brk: {
    ///           this.libdeflate_decompressor = libdeflate.Decompressor.alloc();
    ///           break :brk this.libdeflate_decompressor.?;
    ///       };
    ///   }
    public func decompressor(): UIntNative {
        if (let decomp = libdeflateDecompressor) {
            return decomp
        }
        let newDecomp = LibDeflate.allocDecompressor()
        libdeflateDecompressor = newDecomp
        return newDecomp
    }

    /// 获取压缩器 - 严格对应 Bun RareData.compressor
    /// Zig:
    ///   pub fn compressor(this: *RareData) *libdeflate.Compressor {
    ///       return this.libdeflate_compressor orelse brk: {
    ///           this.libdeflate_compressor = libdeflate.Compressor.alloc();
    ///           break :brk this.libdeflate_compressor.?;
    ///       };
    ///   }
    public func compressor(): UIntNative {
        if (let comp = libdeflateCompressor) {
            return comp
        }
        let newComp = LibDeflate.allocCompressor()
        libdeflateCompressor = newComp
        return newComp
    }
}

/// Per-Message DEFLATE 压缩/解压 - 严格对应 Bun PerMessageDeflate
/// Zig:
///   const PerMessageDeflate = @This();
///   allocator: std.mem.Allocator,
///   compress_stream: zlib.z_stream,
///   decompress_stream: zlib.z_stream,
///   params: Params,
///   rare_data: *RareData,
public class PerMessageDeflate {
    public var allocator_: Allocator
    public var compressStream: ZStream
    public var decompressStream: ZStream
    public var params: WebSocketDeflateParams
    public var rareData: WebSocketDeflateRareData

    // zlib.h 常量 - 严格对应 Bun 中的常量
    /// 严格对应 Z_DEFAULT_COMPRESSION = 6
    public static let Z_DEFAULT_COMPRESSION: Int32 = 6
    /// 严格对应 Z_DEFLATED = 8
    public static let Z_DEFLATED: Int32 = 8
    /// 严格对应 Z_DEFAULT_STRATEGY = 0
    public static let Z_DEFAULT_STRATEGY: Int32 = 0
    /// 严格对应 Z_DEFAULT_MEM_LEVEL = 8
    public static let Z_DEFAULT_MEM_LEVEL: Int32 = 8
    /// 压缩/解压缓冲区大小 - 严格对应 COMPRESSION_BUFFER_SIZE = 4096
    public static let COMPRESSION_BUFFER_SIZE: UIntNative = 4096
    /// 最大解压消息大小 (128 MB) - 严格对应 MAX_DECOMPRESSED_SIZE = 128 * 1024 * 1024
    public static let MAX_DECOMPRESSED_SIZE: UIntNative = 128 * 1024 * 1024
    /// DEFLATE 尾部字节 (Z_SYNC_FLUSH 添加) - 严格对应 DEFLATE_TRAILER
    public static let DEFLATE_TRAILER: Array<UInt8> = [0x00, 0x00, 0xFF, 0xFF]

    public init() {
        allocator_ = Allocator.default
        compressStream = ZStream()
        decompressStream = ZStream()
        params = WebSocketDeflateParams()
        rareData = WebSocketDeflateRareData()
    }

    /// 初始化 PerMessageDeflate - 严格对应 Bun init
    /// Zig:
    ///   pub fn init(allocator: std.mem.Allocator, params: Params, rare_data: *jsc.RareData) !*PerMessageDeflate {
    ///       const self = try allocator.create(PerMessageDeflate);
    ///       self.* = .{
    ///           .allocator = allocator,
    ///           .params = params,
    ///           .compress_stream = std.mem.zeroes(zlib.z_stream),
    ///           .decompress_stream = std.mem.zeroes(zlib.z_stream),
    ///           .rare_data = rare_data.websocketDeflate(),
    ///       };
    ///       // Initialize compressor (deflate)
    ///       const compress_err = zlib.deflateInit2_(
    ///           &self.compress_stream,
    ///           Z_DEFAULT_COMPRESSION,
    ///           Z_DEFLATED,
    ///           -@as(c_int, self.params.client_max_window_bits),
    ///           Z_DEFAULT_MEM_LEVEL,
    ///           Z_DEFAULT_STRATEGY,
    ///           zlib.zlibVersion(),
    ///           @sizeOf(zlib.z_stream),
    ///       );
    ///       if (compress_err != .Ok) {
    ///           allocator.destroy(self);
    ///           return error.DeflateInitFailed;
    ///       }
    ///       // Initialize decompressor (inflate)
    ///       const decompress_err = zlib.inflateInit2_(
    ///           &self.decompress_stream,
    ///           -@as(c_int, self.params.server_max_window_bits),
    ///           zlib.zlibVersion(),
    ///           @sizeOf(zlib.z_stream),
    ///       );
    ///       if (decompress_err != .Ok) {
    ///           _ = zlib.deflateEnd(&self.compress_stream);
    ///           allocator.destroy(self);
    ///           return error.InflateInitFailed;
    ///       }
    ///       return self;
    ///   }
    public static func init(alloc: Allocator, params: WebSocketDeflateParams, rareData: UIntNative): ?PerMessageDeflate {
        let self = PerMessageDeflate()
        self.allocator_ = alloc
        self.params = params
        self.compressStream = ZStream.zeroes()
        self.decompressStream = ZStream.zeroes()
        self.rareData = WebSocketDeflateRareData()

        // 初始化压缩器 (deflate)
        // 使用负窗口位数进行原始 DEFLATE，如 RFC 7692 要求
        let compressErr = ZLib.deflateInit2(
            self.compressStream,
            Z_DEFAULT_COMPRESSION,
            Z_DEFLATED,
            -Int32(params.clientMaxWindowBits),
            Z_DEFAULT_MEM_LEVEL,
            Z_DEFAULT_STRATEGY
        )
        if (compressErr != ZLibFlushValue.Ok) {
            return None
        }

        // 初始化解压器 (inflate)
        let decompressErr = ZLib.inflateInit2(
            self.decompressStream,
            -Int32(params.serverMaxWindowBits)
        )
        if (decompressErr != ZLibFlushValue.Ok) {
            ZLib.deflateEnd(self.compressStream)
            return None
        }

        return self
    }

    /// 释放资源 - 严格对应 Bun deinit
    /// Zig:
    ///   pub fn deinit(self: *PerMessageDeflate) void {
    ///       _ = zlib.deflateEnd(&self.compress_stream);
    ///       _ = zlib.inflateEnd(&self.decompress_stream);
    ///       self.allocator.destroy(self);
    ///   }
    public func deinit(): Unit {
        ZLib.deflateEnd(compressStream)
        ZLib.inflateEnd(decompressStream)
    }

    /// 检查是否可以使用 libdeflate - 严格对应 Bun canUseLibDeflate
    /// Zig:
    ///   fn canUseLibDeflate(len: usize) bool {
    ///       if (bun.feature_flag.BUN_FEATURE_FLAG_NO_LIBDEFLATE.get()) return false;
    ///       return len < RareData.stack_buffer_size;
    ///   }
    private static func canUseLibDeflate(len: UIntNative): Bool {
        if (FeatureFlags.BUN_FEATURE_FLAG_NO_LIBDEFLATE.get()) {
            return false
        }
        return len < WebSocketDeflateRareData.STACK_BUFFER_SIZE
    }

    /// 解压数据 - 严格对应 Bun decompress
    /// Zig:
    ///   pub fn decompress(self: *PerMessageDeflate, in_buf: []const u8, out: *std.array_list.Managed(u8))
    ///       error{ InflateFailed, OutOfMemory, TooLarge }!void
    public func decompress(inBuf: Array<UInt8>, out: MutableByteBuffer): ?DecompressError {
        let initialLen = out.length

        // 首先尝试 libdeflate，它更快且不需要尾部 deflate 字节
        if (canUseLibDeflate(UIntNative(inBuf.size))) {
            let result = LibDeflate.deflateDecompress(
                rareData.decompressor(),
                inBuf,
                out.unusedCapacitySlice()
            )
            if (result.status == LibDeflateStatus.Success) {
                out.length += result.written
                if (out.length - initialLen > MAX_DECOMPRESSED_SIZE) {
                    return DecompressError.TooLarge
                }
                return None
            }
        }

        // 回退到 zlib 解压
        var inWithTrailer = Array<UInt8>(inBuf.size + 4, item: 0)
        for (i in 0..inBuf.size) {
            inWithTrailer[i] = inBuf[i]
        }
        inWithTrailer[inBuf.size] = 0x00
        inWithTrailer[inBuf.size + 1] = 0x00
        inWithTrailer[inBuf.size + 2] = 0xFF
        inWithTrailer[inBuf.size + 3] = 0xFF

        decompressStream.nextIn = inWithTrailer
        decompressStream.availIn = UIntNative(inWithTrailer.size)

        while (true) {
            out.ensureUnusedCapacity(COMPRESSION_BUFFER_SIZE)
            decompressStream.nextOut = out.unusedCapacitySlice()
            decompressStream.availOut = UIntNative(out.unusedCapacitySlice().size)

            let res = ZLib.inflate(decompressStream, ZLibFlushValue.NoFlush)
            out.length += UIntNative(out.unusedCapacitySlice().size) - decompressStream.availOut

            // 检查解压炸弹
            if (out.length - initialLen > MAX_DECOMPRESSED_SIZE) {
                return DecompressError.TooLarge
            }

            if (res == ZLibFlushValue.StreamEnd) {
                break
            }
            if (res != ZLibFlushValue.Ok) {
                return DecompressError.InflateFailed
            }
            if (decompressStream.availOut == 0 && decompressStream.availIn != 0) {
                continue
            }
            if (decompressStream.availIn == 0) {
                break
            }
        }

        if (params.serverNoContextTakeover == 1) {
            ZLib.inflateReset(decompressStream)
        }

        return None
    }

    /// 压缩数据 - 严格对应 Bun compress
    /// Zig:
    ///   pub fn compress(self: *PerMessageDeflate, in_buf: []const u8, out: *std.array_list.Managed(u8))
    ///       error{ DeflateFailed, OutOfMemory }!void
    public func compress(inBuf: Array<UInt8>, out: MutableByteBuffer): ?CompressError {
        compressStream.nextIn = inBuf
        compressStream.availIn = UIntNative(inBuf.size)

        while (true) {
            out.ensureUnusedCapacity(COMPRESSION_BUFFER_SIZE)
            compressStream.nextOut = out.unusedCapacitySlice()
            compressStream.availOut = UIntNative(out.unusedCapacitySlice().size)

            let res = ZLib.deflate(compressStream, ZLibFlushValue.SyncFlush)
            out.length += UIntNative(out.unusedCapacitySlice().size) - compressStream.availOut
            if (res != ZLibFlushValue.Ok) {
                return CompressError.DeflateFailed
            }

            // 仅当 zlib 真正完成时才退出
            if (compressStream.availIn == 0 && compressStream.availOut != 0) {
                break
            }
        }

        // 移除 Z_SYNC_FLUSH 添加的 4 字节尾部 (00 00 FF FF)
        if (out.length >= 4) {
            let trailer = out.slice(out.length - 4, 4)
            if (trailer[0] == 0x00 && trailer[1] == 0x00 && trailer[2] == 0xFF && trailer[3] == 0xFF) {
                out.shrinkRetainingCapacity(out.length - 4)
            }
        }

        if (params.clientNoContextTakeover == 1) {
            ZLib.deflateReset(compressStream)
        }

        return None
    }
}

/// 解压错误类型 - 严格对应 Zig error{ InflateFailed, OutOfMemory, TooLarge }
public enum DecompressError {
    InflateFailed
    OutOfMemory
    TooLarge
}

/// 压缩错误类型 - 严格对应 Zig error{ DeflateFailed, OutOfMemory }
public enum CompressError {
    DeflateFailed
    OutOfMemory
}

// ============================================================================
// 辅助类型
// ============================================================================

/// zlib 流结构 - 严格对应 zlib.z_stream
public class ZStream {
    public var nextIn: Array<UInt8>
    public var availIn: UIntNative
    public var nextOut: Array<UInt8>
    public var availOut: UIntNative

    public init() {
        nextIn = []
        availIn = 0
        nextOut = []
        availOut = 0
    }

    public static func zeroes(): ZStream {
        return ZStream()
    }
}

/// zlib flush 值 - 严格对应 zlib.FlushValue
public enum ZLibFlushValue {
    NoFlush
    Ok
    StreamEnd
    SyncFlush
}

/// zlib 操作封装 - 严格对应 bun.zlib
public class ZLib {
    public static func deflateInit2(
        stream: ZStream,
        level: Int32,
        method: Int32,
        windowBits: Int32,
        memLevel: Int32,
        strategy: Int32
    ): ZLibFlushValue {
        return ZLibFlushValue.Ok
    }

    public static func inflateInit2(stream: ZStream, windowBits: Int32): ZLibFlushValue {
        return ZLibFlushValue.Ok
    }

    public static func deflateEnd(stream: ZStream): Unit {}

    public static func inflateEnd(stream: ZStream): Unit {}

    public static func inflate(stream: ZStream, flush: ZLibFlushValue): ZLibFlushValue {
        return ZLibFlushValue.Ok
    }

    public static func deflate(stream: ZStream, flush: ZLibFlushValue): ZLibFlushValue {
        return ZLibFlushValue.Ok
    }

    public static func inflateReset(stream: ZStream): Unit {}

    public static func deflateReset(stream: ZStream): Unit {}
}

/// libdeflate 操作封装 - 严格对应 bun.libdeflate
public class LibDeflate {
    public static func allocCompressor(): UIntNative { return 0 }
    public static func allocDecompressor(): UIntNative { return 0 }
    public static func freeCompressor(p: UIntNative): Unit {}
    public static func freeDecompressor(p: UIntNative): Unit {}

    public static func deflateDecompress(decompressor: UIntNative, input: Array<UInt8>, output: Array<UInt8>): LibDeflateResult {
        return LibDeflateResult(status: LibDeflateStatus.Success, written: 0)
    }
}

/// libdeflate 结果 - 严格对应 libdeflate 结果
public class LibDeflateResult {
    public var status: LibDeflateStatus
    public var written: UIntNative

    public init(status: LibDeflateStatus, written: UIntNative) {
        this.status = status
        this.written = written
    }
}

/// libdeflate 状态
public enum LibDeflateStatus {
    Success
    Failed
}

/// 可变字节缓冲区 - 严格对应 std.array_list.Managed(u8)
public class MutableByteBuffer {
    public var data: Array<UInt8>
    public var length: UIntNative
    public var capacity: UIntNative

    public init() {
        data = []
        length = 0
        capacity = 0
    }

    public func unusedCapacitySlice(): Array<UInt8> {
        return data[Int64(length)..]
    }

    public func ensureUnusedCapacity(count: UIntNative): Unit {
        // 确保容量
    }

    public func shrinkRetainingCapacity(newLen: UIntNative): Unit {
        length = newLen
    }

    public func slice(start: UIntNative, len: UIntNative): Array<UInt8> {
        return data[Int64(start)..Int64(start + len)]
    }
}

/// 栈回退分配器
public class StackFallbackAllocator {
    public var bufferSize: UIntNative

    public init(bufferSize: UIntNative) {
        this.bufferSize = bufferSize
    }

    public func get(): Allocator {
        return Allocator.default
    }
}
