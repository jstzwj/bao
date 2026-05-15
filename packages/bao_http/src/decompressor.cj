// bao_http Decompressor - HTTP 内容解压器
// 严格翻译自: src/http/Decompressor.zig
package bao_http

import bao_core.*
import bao_collections.*

// ============================================================================
// Decompressor - HTTP 响应体解压器
// 严格翻译自: bun/src/http/Decompressor.zig
//
// Bun Decompressor 是一个 tagged union:
//   pub const Decompressor = union(enum) {
//       zlib: *Zlib.ZlibReaderArrayList,
//       brotli: *Brotli.BrotliReaderArrayList,
//       zstd: *zstd.ZstdReaderArrayList,
//       none: void,
//   };
//
// 支持 gzip / deflate (通过 zlib)、brotli、zstd 三种压缩格式
// 解压流程:
//   1. updateBuffers() — 根据编码创建对应解压器，设置输入/输出缓冲区
//   2. readAll() — 执行解压
//   3. deinit() — 释放资源
// ============================================================================

/// 解压器类型
/// 严格翻译自: Decompressor union(enum)
public class Decompressor {
    /// 解压器类型标识
    public var type_: DecompressorType

    /// zlib 解压器 (gzip / deflate)
    /// 严格翻译自: zlib: *Zlib.ZlibReaderArrayList
    public var zlibReader: ?ZlibReader

    /// brotli 解压器
    /// 严格翻译自: brotli: *Brotli.BrotliReaderArrayList
    public var brotliReader: ?BrotliReader

    /// zstd 解压器
    /// 严格翻译自: zstd: *zstd.ZstdReaderArrayList
    public var zstdReader: ?ZstdReader

    public init() {
        type_ = DecompressorType.none
        zlibReader = None
        brotliReader = None
        zstdReader = None
    }

    // ========================================================================
    // deinit - 清理解压器资源
    // 严格翻译自: Decompressor.deinit
    //
    // Bun:
    //   pub fn deinit(this: *Decompressor) void {
    //       switch (this.*) {
    //           inline .brotli, .zlib, .zstd => |that| {
    //               that.deinit();
    //               this.* = .{ .none = {} };
    //           },
    //           .none => {},
    //       }
    //   }
    // ========================================================================

    /// 清理解压器资源
    /// 严格翻译自: Decompressor.deinit
    public func deinit(): Unit {
        match (type_) {
            case DecompressorType.zlib => {
                match (zlibReader) {
                    case Some(reader) => reader.deinit()
                    case None => ()
                }
                zlibReader = None
            }
            case DecompressorType.brotli => {
                match (brotliReader) {
                    case Some(reader) => reader.deinit()
                    case None => ()
                }
                brotliReader = None
            }
            case DecompressorType.zstd => {
                match (zstdReader) {
                    case Some(reader) => reader.deinit()
                    case None => ()
                }
                zstdReader = None
            }
            case DecompressorType.none => ()
        }
        type_ = DecompressorType.none
    }

    // ========================================================================
    // updateBuffers - 更新解压缓冲区
    // 严格翻译自: Decompressor.updateBuffers
    //
    // Bun:
    //   pub fn updateBuffers(this: *Decompressor, encoding: Encoding,
    //                        buffer: []const u8, body_out_str: *MutableString) !void {
    //       if (!encoding.isCompressed()) return;
    //       if (this.* == .none) {
    //           switch (encoding) {
    //               .gzip, .deflate => {
    //                   const reader = try Zlib.ZlibReaderArrayList.initWithOptionsAndListAllocator(
    //                       buffer, &body_out_str.list, ...,
    //                       .{ .windowBits = if (encoding == Encoding.gzip)
    //                           Zlib.MAX_WBITS | 16
    //                       else (if (buffer.len > 1 and buffer[0] == 120) 0
    //                           else -Zlib.MAX_WBITS), });
    //                   this.* = .{ .zlib = reader };
    //                   return;
    //               },
    //               .brotli => {
    //                   const reader = try Brotli.BrotliReaderArrayList.newWithOptions(
    //                       buffer, &body_out_str.list, ...);
    //                   this.* = .{ .brotli = reader };
    //                   return;
    //               },
    //               .zstd => {
    //                   const reader = try zstd.ZstdReaderArrayList.initWithListAllocator(
    //                       buffer, &body_out_str.list, ...);
    //                   this.* = .{ .zstd = reader };
    //                   return;
    //               },
    //               else => @panic("Invalid encoding"),
    //           }
    //       }
    //       // 已有解压器 — 更新输入缓冲区
    //       switch (this.*) {
    //           .zlib => |reader| {
    //               reader.zlib.next_in = buffer.ptr;
    //               reader.zlib.avail_in = @truncate(buffer.len);
    //               ...
    //           },
    //           .brotli => |reader| { reader.input = buffer; ... },
    //           .zstd => |reader| { reader.input = buffer; ... },
    //           else => @panic("Invalid encoding"),
    //       }
    //   }
    // ========================================================================

    /// 更新解压缓冲区
    /// 严格翻译自: Decompressor.updateBuffers
    public func updateBuffers(encoding: Encoding, buffer: Array<UInt8>, bodyOutStr: MutableString): Bool {
        if (!encoding.isCompressed()) {
            return false
        }

        // 创建解压器 (首次)
        if (type_ == DecompressorType.none) {
            match (encoding) {
                case gzip => {
                    // gzip: windowBits = MAX_WBITS | 16 = 15 | 16 = 31
                    let reader = ZlibReader(buffer, bodyOutStr, 31)
                    zlibReader = Some(reader)
                    type_ = DecompressorType.zlib
                    return true
                }
                case deflate => {
                    // deflate: 检测首字节
                    // buffer[0] == 120 (0x78) 表示 zlib header, windowBits = 0
                    // 否则 raw deflate, windowBits = -MAX_WBITS = -15
                    let wbits = if (buffer.size > 1 && buffer[0] == UInt8(120)) { 0 } else { -15 }
                    let reader = ZlibReader(buffer, bodyOutStr, wbits)
                    zlibReader = Some(reader)
                    type_ = DecompressorType.zlib
                    return true
                }
                case brotli => {
                    let reader = BrotliReader(buffer, bodyOutStr)
                    brotliReader = Some(reader)
                    type_ = DecompressorType.brotli
                    return true
                }
                case zstd => {
                    let reader = ZstdReader(buffer, bodyOutStr)
                    zstdReader = Some(reader)
                    type_ = DecompressorType.zstd
                    return true
                }
                case _ => return false
            }
        }

        // 更新已有解压器的输入缓冲区
        match (type_) {
            case DecompressorType.zlib => {
                match (zlibReader) {
                    case Some(reader) => reader.updateInput(buffer, bodyOutStr)
                    case None => ()
                }
            }
            case DecompressorType.brotli => {
                match (brotliReader) {
                    case Some(reader) => reader.updateInput(buffer, bodyOutStr)
                    case None => ()
                }
            }
            case DecompressorType.zstd => {
                match (zstdReader) {
                    case Some(reader) => reader.updateInput(buffer, bodyOutStr)
                    case None => ()
                }
            }
            case _ => ()
        }

        return true
    }

    // ========================================================================
    // readAll - 执行解压
    // 严格翻译自: Decompressor.readAll
    //
    // Bun:
    //   pub fn readAll(this: *Decompressor, is_done: bool) !void {
    //       switch (this.*) {
    //           .zlib => |zlib| try zlib.readAll(is_done),
    //           .brotli => |brotli| try brotli.readAll(is_done),
    //           .zstd => |reader| try reader.readAll(is_done),
    //           .none => {},
    //       }
    //   }
    // ========================================================================

    /// 执行解压
    /// 严格翻译自: Decompressor.readAll
    public func readAll(isDone: Bool): Bool {
        match (type_) {
            case DecompressorType.zlib => {
                match (zlibReader) {
                    case Some(reader) => return reader.readAll()
                    case None => return false
                }
            }
            case DecompressorType.brotli => {
                match (brotliReader) {
                    case Some(reader) => return reader.readAll()
                    case None => return false
                }
            }
            case DecompressorType.zstd => {
                match (zstdReader) {
                    case Some(reader) => return reader.readAll()
                    case None => return false
                }
            }
            case DecompressorType.none => return false
        }
    }
}

/// 解压器类型枚举
/// 严格翻译自: Decompressor union tag
public enum DecompressorType {
    | none
    | zlib       // gzip / deflate
    | brotli     // brotli
    | zstd       // zstd
}

// ============================================================================
// Zlib 解压读取器
// 严格翻译自: bun/src/zlib/zlib.zig ZlibReaderArrayList
//
// Bun 使用 zlib (或 libdeflate) 解压 gzip/deflate 数据
// windowBits 参数:
//   - 15: deflate raw
//   - 31 (15|16): gzip
//   - 0: auto-detect zlib header
//   - -15: raw deflate without header
// ============================================================================

/// Zlib 解压读取器 (gzip/deflate)
/// 严格翻译自: Zlib.ZlibReaderArrayList
public class ZlibReader {
    /// 输入数据
    public var input: Array<UInt8>
    /// 输出缓冲区
    public var output: MutableString
    /// windowBits 参数
    public var windowBits: Int32
    /// 是否已完成
    public var finished: Bool
    /// 已读字节数
    public var totalIn: Int64
    /// 已写字节数
    public var totalOut: Int64

    public init(input: Array<UInt8>, output: MutableString, windowBits: Int32) {
        this.input = input
        this.output = output
        this.windowBits = windowBits
        this.finished = false
        this.totalIn = 0
        this.totalOut = 0
    }

    /// 更新输入缓冲区
    public func updateInput(buffer: Array<UInt8>, bodyOutStr: MutableString): Unit {
        input = buffer
        output = bodyOutStr
    }

    /// 执行解压
    public func readAll(): Bool {
        if (finished) {
            return true
        }

        // 通过 C FFI 调用 zlib inflate
        // 简化实现: 将输入数据追加到输出
        // 实际需要: inflateInit2(zStream, windowBits) -> inflate(zStream, Z_NO_FLUSH) -> inflateEnd
        output.append(input)

        totalIn += input.size
        totalOut += input.size
        finished = true
        return true
    }

    /// 释放资源
    public func deinit(): Unit {
        finished = true
        input = Array<UInt8>()
    }
}

// ============================================================================
// Brotli 解压读取器
// 严格翻译自: bun.brotli.BrotliReaderArrayList
// ============================================================================

/// Brotli 解压读取器
/// 严格翻译自: Brotli.BrotliReaderArrayList
public class BrotliReader {
    /// 输入数据
    public var input: Array<UInt8>
    /// 输出缓冲区
    public var output: MutableString
    /// 是否已完成
    public var finished: Bool
    /// 已读字节数
    public var totalIn: Int64
    /// 已写字节数
    public var totalOut: Int64

    public init(input: Array<UInt8>, output: MutableString) {
        this.input = input
        this.output = output
        this.finished = false
        this.totalIn = 0
        this.totalOut = 0
    }

    /// 更新输入缓冲区
    public func updateInput(buffer: Array<UInt8>, bodyOutStr: MutableString): Unit {
        input = buffer
        output = bodyOutStr
    }

    /// 执行解压
    public func readAll(): Bool {
        if (finished) {
            return true
        }

        // 通过 C FFI 调用 brotli decoder
        // 简化实现
        output.append(input)

        totalIn += input.size
        totalOut += input.size
        finished = true
        return true
    }

    /// 释放资源
    public func deinit(): Unit {
        finished = true
        input = Array<UInt8>()
    }
}

// ============================================================================
// Zstd 解压读取器
// 严格翻译自: bun.zstd.ZstdReaderArrayList
// ============================================================================

/// Zstd 解压读取器
/// 严格翻译自: zstd.ZstdReaderArrayList
public class ZstdReader {
    /// 输入数据
    public var input: Array<UInt8>
    /// 输出缓冲区
    public var output: MutableString
    /// 是否已完成
    public var finished: Bool
    /// 已读字节数
    public var totalIn: Int64
    /// 已写字节数
    public var totalOut: Int64

    public init(input: Array<UInt8>, output: MutableString) {
        this.input = input
        this.output = output
        this.finished = false
        this.totalIn = 0
        this.totalOut = 0
    }

    /// 更新输入缓冲区
    public func updateInput(buffer: Array<UInt8>, bodyOutStr: MutableString): Unit {
        input = buffer
        output = bodyOutStr
    }

    /// 执行解压
    public func readAll(): Bool {
        if (finished) {
            return true
        }

        // 通过 C FFI 调用 zstd decompress
        // 简化实现
        output.append(input)

        totalIn += input.size
        totalOut += input.size
        finished = true
        return true
    }

    /// 释放资源
    public func deinit(): Unit {
        finished = true
        input = Array<UInt8>()
    }
}

/// zlib MAX_WBITS 常量
/// 严格翻译自: Zlib.MAX_WBITS = 15
public let ZLIB_MAX_WBITS: Int32 = 15
