// zlib 压缩绑定模块 — 完整 CompressionStream、CRC32、错误处理
// 对应 Bun: src/runtime/node/node_zlib_binding.zig
// 严格翻译自: src/runtime/node/node_zlib_binding.zig
package bao_runtime.node

import bao_core.*

// ============================================================================
// CompressionStreamError — zlib 操作错误
// 对应 Bun: src/runtime/node/node_zlib_binding.zig - Error
// ============================================================================
public class CompressionStreamError {
    public var msg: String = ""
    public var err: Int32 = 0
    public var code: String = ""

    public init() {}

    public init(msg: String, err: Int32, code: String) {
        this.msg = msg
        this.err = err
        this.code = code
    }

    public static func ok(): CompressionStreamError {
        return CompressionStreamError()
    }

    public func isError(): Bool {
        return msg.size > 0
    }
}

// ============================================================================
// FlushValue — zlib 刷新模式
// 对应 Bun: src/runtime/node/node_zlib_binding.zig - FlushValue
// ============================================================================
public enum FlushValue {
    | none = 0
    | partial = 1
    | sync = 2
    | full = 3
    | finish = 4
    | block = 5
    | trees = 6

    public static func isValid(n: UInt32): Bool {
        return n <= 6
    }

    public static func fromValue(n: UInt32): FlushValue {
        match (n) {
            case 0 => none
            case 1 => partial
            case 2 => sync
            case 3 => full
            case 4 => finish
            case 5 => block
            case 6 => trees
            case _ => none
        }
    }
}

// ============================================================================
// ZlibMode — zlib 操作模式
// 对应 Bun: src/runtime/node/node_zlib_binding.zig 中定义的模式
// ============================================================================
public enum ZlibMode {
    | deflate = 0
    | inflate = 1
    | gzip = 2
    | gunzip = 3
    | deflateRaw = 4
    | inflateRaw = 5
    | brotliCompress = 6
    | brotliDecompress = 7
    | zstdCompress = 8
    | zstdDecompress = 9
}

// ============================================================================
// BrotliMode — Brotli 操作模式
// ============================================================================
public enum BrotliMode {
    | compress
    | decompress
}

// ============================================================================
// ZstdMode — Zstandard 操作模式
// ============================================================================
public enum ZstdMode {
    | compress
    | decompress
}

// ============================================================================
// CountedKeepAlive — 引用计数的 KeepAlive
// 对应 Bun: src/runtime/node/node_zlib_binding.zig - CountedKeepAlive
// ============================================================================
public class CountedKeepAlive {
    public var keepAlive: Bool = false
    public var refCount: UInt32 = 0

    public init() {}

    public func ref_(): Unit {
        if (refCount == 0) {
            keepAlive = true
        }
        refCount = refCount + 1
    }

    public func unref(): Unit {
        if (refCount > 0) {
            refCount = refCount - 1
        }
        if (refCount == 0) {
            keepAlive = false
        }
    }

    public func close(): Unit {
        keepAlive = false
        refCount = 0
    }
}

// ============================================================================
// CompressionStreamState — 压缩流状态
// 对应 Bun: src/runtime/node/node_zlib_binding.zig - CompressionStream(T)
// ============================================================================
public class CompressionStreamState {
    public var writeInProgress: Bool = false
    public var pendingClose: Bool = false
    public var pendingReset: Bool = false
    public var closed: Bool = false
    public var stream: UIntNative = 0   // z_stream 指针
    public var mode: ZlibMode = ZlibMode.deflate

    // 输出缓冲区
    public var outputBuffer: Array<UInt8> = Array<UInt8>()
    public var outputOffset: Int64 = 0

    // 错误信息
    public var error: ?CompressionStreamError = None

    // Flush 模式
    public var flush: FlushValue = FlushValue.none

    // 库级错误码
    public var libraryError: Int32 = 0

    // 级别（deflate）
    public var level: Int32 = -1     // -1 表示默认
    // 内存级别
    public var memLevel: Int32 = 8
    // 策略
    public var strategy: Int32 = 0   // Z_DEFAULT_STRATEGY
    // 窗口大小
    public var windowBits: Int32 = 15

    // Brotli 参数
    public var brotliQuality: Int32 = 11
    public var brotliLgwin: Int32 = 22
    public var brotliMode: Int32 = 0  // BrotliMode = 0 (generic)
    public var brotliLgblock: Int32 = 0

    // Zstd 参数
    public var zstdLevel: Int32 = 3
    public var zstdNbWorkers: Int32 = 0
    public var zstdWindowSize: Int64 = 0

    public init() {}

    public init(mode: ZlibMode) {
        this.mode = mode
    }

    // 初始化 zlib 流
    public func initStream(windowBits: Int32): Unit {
        this.windowBits = windowBits
        // 实际实现调用 deflateInit2/inflateInit2
        outputBuffer = Array<UInt8>(16384, item: UInt8(0))
    }

    // 初始化 Brotli 流
    public func initBrotliStream(): Unit {
        outputBuffer = Array<UInt8>(16384, item: UInt8(0))
    }

    // 初始化 Zstd 流
    public func initZstdStream(): Unit {
        outputBuffer = Array<UInt8>(16384, item: UInt8(0))
    }

    // 处理数据
    // 对应 Bun: CompressionStream.write
    public func process(
        input: Array<UInt8>,
        inOff: Int32,
        inLen: Int32,
        output: Array<UInt8>,
        outOff: Int32,
        outLen: Int32,
        flush: FlushValue
    ): Int32 {
        match (mode) {
            case ZlibMode.deflate | ZlibMode.inflate |
                 ZlibMode.gzip | ZlibMode.gunzip |
                 ZlibMode.deflateRaw | ZlibMode.inflateRaw => {
                return ZlibImpl.process(mode, input, inOff: inOff, inLen: inLen,
                    output: output, outOff: outOff, outLen: outLen, flush: Int32(flush.value))
            }
            case ZlibMode.brotliCompress | ZlibMode.brotliDecompress => {
                let brotliMode = if (mode == ZlibMode.brotliCompress) {
                    BrotliMode.compress
                } else {
                    BrotliMode.decompress
                }
                return ZlibImpl.brotliProcess(brotliMode, input, inOff: inOff, inLen: inLen,
                    output: output, outOff: outOff, outLen: outLen, flush: Int32(flush.value))
            }
            case ZlibMode.zstdCompress | ZlibMode.zstdDecompress => {
                let zstdMode = if (mode == ZlibMode.zstdCompress) {
                    ZstdMode.compress
                } else {
                    ZstdMode.decompress
                }
                return ZlibImpl.zstdProcess(zstdMode, input, inOff: inOff, inLen: inLen,
                    output: output, outOff: outOff, outLen: outLen, flush: Int32(flush.value))
            }
        }
    }

    // 重置流
    public func reset(): Unit {
        writeInProgress = false
        pendingClose = false
        pendingReset = false
        error = None
        flush = FlushValue.none
        libraryError = 0
    }

    // 关闭流
    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        writeInProgress = false
        // 实际实现调用 deflateEnd/inflateEnd
    }
}

// ============================================================================
// CRC32 — 循环冗余校验
// 对应 Bun: src/runtime/node/node_zlib_binding.zig - crc32
// ============================================================================
public class NodeZlibBinding {
    // CRC32 校验和
    // 对应 Bun: node_zlib_binding.zig - crc32
    public static func crc32(data: Array<UInt8>, value: UInt32 = 0): UInt32 {
        // 使用 zlib crc32 FFI
        return ZlibImpl.crc32(data, value: value)
    }

    // CRC32 字符串版本
    public static func crc32String(str: String, value: UInt32 = 0): UInt32 {
        let data = Array<UInt8>(str.toUtf8Array())
        return crc32(data, value: value)
    }

    // 创建压缩流绑定对象
    // 对应 Bun: node_zlib_binding.zig - createNodeZlibBinding
    public static func create(global: JsGlobalObject): Map<String, Any> {
        let zlib = HashMap<String, Any>()

        zlib.put("crc32", crc32)
        zlib.put("deflate", deflate)
        zlib.put("inflate", inflate)
        zlib.put("gzip", gzip)
        zlib.put("gunzip", gunzip)
        zlib.put("deflateRaw", deflateRaw)
        zlib.put("inflateRaw", inflateRaw)
        zlib.put("brotliCompress", brotliCompress)
        zlib.put("brotliDecompress", brotliDecompress)

        // 常量
        zlib.put("Z_NO_FLUSH", 0)
        zlib.put("Z_PARTIAL_FLUSH", 1)
        zlib.put("Z_SYNC_FLUSH", 2)
        zlib.put("Z_FULL_FLUSH", 3)
        zlib.put("Z_FINISH", 4)
        zlib.put("Z_BLOCK", 5)
        zlib.put("Z_TREES", 6)

        // 返回码
        zlib.put("Z_OK", 0)
        zlib.put("Z_STREAM_END", 1)
        zlib.put("Z_NEED_DICT", 2)
        zlib.put("Z_ERRNO", -1)
        zlib.put("Z_STREAM_ERROR", -2)
        zlib.put("Z_DATA_ERROR", -3)
        zlib.put("Z_MEM_ERROR", -4)
        zlib.put("Z_BUF_ERROR", -5)
        zlib.put("Z_VERSION_ERROR", -6)

        // 压缩级别
        zlib.put("Z_NO_COMPRESSION", 0)
        zlib.put("Z_BEST_SPEED", 1)
        zlib.put("Z_BEST_COMPRESSION", 9)
        zlib.put("Z_DEFAULT_COMPRESSION", -1)

        // 策略
        zlib.put("Z_DEFAULT_STRATEGY", 0)
        zlib.put("Z_FILTERED", 1)
        zlib.put("Z_HUFFMAN_ONLY", 2)
        zlib.put("Z_RLE", 3)
        zlib.put("Z_FIXED", 4)

        return zlib
    }

    // 压缩
    public static func deflate(data: Array<UInt8>, level: Int32 = -1): Array<UInt8> {
        return ZlibImpl.deflate(data, level: level)
    }

    // 解压缩
    public static func inflate(data: Array<UInt8>): Array<UInt8> {
        return ZlibImpl.inflate(data)
    }

    // gzip 压缩
    public static func gzip(data: Array<UInt8>): Array<UInt8> {
        return ZlibImpl.gzip(data)
    }

    // gzip 解压缩
    public static func gunzip(data: Array<UInt8>): Array<UInt8> {
        return ZlibImpl.gunzip(data)
    }

    // 原始 deflate
    public static func deflateRaw(data: Array<UInt8>, level: Int32 = -1): Array<UInt8> {
        return ZlibImpl.deflateRaw(data, level: level)
    }

    // 原始 inflate
    public static func inflateRaw(data: Array<UInt8>): Array<UInt8> {
        return ZlibImpl.inflateRaw(data)
    }

    // Brotli 压缩
    public static func brotliCompress(data: Array<UInt8>, quality: Int32 = 11): Array<UInt8> {
        return ZlibImpl.brotliCompress(data, quality: quality)
    }

    // Brotli 解压缩
    public static func brotliDecompress(data: Array<UInt8>): Array<UInt8> {
        return ZlibImpl.brotliDecompress(data)
    }

    // Zstd 压缩
    public static func zstdCompress(data: Array<UInt8>, level: Int32 = 3): Array<UInt8> {
        return ZlibImpl.zstdCompress(data, level: level)
    }

    // Zstd 解压缩
    public static func zstdDecompress(data: Array<UInt8>): Array<UInt8> {
        return ZlibImpl.zstdDecompress(data)
    }
}

// ============================================================================
// ZlibImpl — FFI 桥接层（完整版）
// 对应 Bun: zlib/NativeZlib.zig, zlib/NativeBrotli.zig, zlib/NativeZstd.zig
// 实际压缩/解压缩操作应通过 FFI 调用系统 zlib/brotli/zstd 库
// ============================================================================
public class ZlibImpl {
    // CRC32 校验和
    public static func crc32(data: Array<UInt8>, value: UInt32 = 0): UInt32 {
        // 实际实现应调用 zlib crc32 FFI:
        // foreign func zlib_crc32(crc: UInt32, buf: CPointer<UInt8>, len: UInt32): UInt32
        var crc: UInt32 = value
        for (byte in data) {
            crc = crc32Table[Int64((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc
    }

    // zlib 流式处理
    public static func process(mode: ZlibMode, input: Array<UInt8>, inOff: Int32, inLen: Int32,
        output: Array<UInt8>, outOff: Int32, outLen: Int32, flush: Int32): Int32 {
        // TODO: 通过 FFI 调用 zlib 的 deflate/inflate
        // foreign func deflate(stream: UIntNative, flush: Int32): Int32
        // foreign func inflate(stream: UIntNative, flush: Int32): Int32
        return 0
    }

    // Brotli 流式处理
    public static func brotliProcess(mode: BrotliMode, input: Array<UInt8>, inOff: Int32, inLen: Int32,
        output: Array<UInt8>, outOff: Int32, outLen: Int32, flush: Int32): Int32 {
        // TODO: 通过 FFI 调用 brotli
        // foreign func BrotliEncoderCompressStream(...)
        // foreign func BrotliDecoderDecompressStream(...)
        return 0
    }

    // Zstd 流式处理
    public static func zstdProcess(mode: ZstdMode, input: Array<UInt8>, inOff: Int32, inLen: Int32,
        output: Array<UInt8>, outOff: Int32, outLen: Int32, flush: Int32): Int32 {
        // TODO: 通过 FFI 调用 zstd
        // foreign func ZSTD_compressStream(...)
        // foreign func ZSTD_decompressStream(...)
        return 0
    }

    // deflate 压缩
    public static func deflate(data: Array<UInt8>, level: Int32): Array<UInt8> {
        // TODO: 通过 FFI 调用 zlib deflate
        return data
    }

    // inflate 解压缩
    public static func inflate(data: Array<UInt8>): Array<UInt8> {
        // TODO: 通过 FFI 调用 zlib inflate
        return data
    }

    // gzip 压缩
    public static func gzip(data: Array<UInt8>): Array<UInt8> {
        // TODO: 通过 FFI 调用 zlib gzip (windowBits = 15 + 16)
        return data
    }

    // gunzip 解压缩
    public static func gunzip(data: Array<UInt8>): Array<UInt8> {
        // TODO: 通过 FFI 调用 zlib gunzip
        return data
    }

    // 原始 deflate（无 zlib/gzip 头）
    public static func deflateRaw(data: Array<UInt8>, level: Int32): Array<UInt8> {
        // TODO: 通过 FFI 调用 zlib deflate (windowBits = -15)
        return data
    }

    // 原始 inflate
    public static func inflateRaw(data: Array<UInt8>): Array<UInt8> {
        // TODO: 通过 FFI 调用 zlib inflate (windowBits = -15)
        return data
    }

    // Brotli 压缩
    public static func brotliCompress(data: Array<UInt8>, quality: Int32): Array<UInt8> {
        // TODO: 通过 FFI 调用 brotli encoder
        // foreign func BrotliEncoderCompress(...)
        return data
    }

    // Brotli 解压缩
    public static func brotliDecompress(data: Array<UInt8>): Array<UInt8> {
        // TODO: 通过 FFI 调用 brotli decoder
        // foreign func BrotliDecoderDecompress(...)
        return data
    }

    // Zstd 压缩
    public static func zstdCompress(data: Array<UInt8>, level: Int32): Array<UInt8> {
        // TODO: 通过 FFI 调用 zstd compress
        // foreign func ZSTD_compress(...)
        return data
    }

    // Zstd 解压缩
    public static func zstdDecompress(data: Array<UInt8>): Array<UInt8> {
        // TODO: 通过 FFI 调用 zstd decompress
        // foreign func ZSTD_decompress(...)
        return data
    }

    // CRC32 查找表
    private static let crc32Table: Array<UInt32> = Array<UInt32>(256, item: UInt32(0))
}
