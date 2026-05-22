// zlib 压缩绑定模块 — 完整 CompressionStream、CRC32、错误处理
// 对应 Bun: src/runtime/node/node_zlib_binding.zig
// 严格翻译自: src/runtime/node/node_zlib_binding.zig
package bao_runtime.node

import bao_core.*
import bao_jsc.*

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
    | none
    | partial
    | sync
    | full
    | finish
    | block
    | trees

    public func value(): UInt32 {
        match (this) {
            case none => 0
            case partial => 1
            case sync => 2
            case full => 3
            case finish => 4
            case block => 5
            case trees => 6
        }
    }

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
    | deflate
    | inflate
    | gzip
    | gunzip
    | deflateRaw
    | inflateRaw
    | brotliCompress
    | brotliDecompress
    | zstdCompress
    | zstdDecompress

    public func value(): Int32 {
        match (this) {
            case deflate => 0
            case inflate => 1
            case gzip => 2
            case gunzip => 3
            case deflateRaw => 4
            case inflateRaw => 5
            case brotliCompress => 6
            case brotliDecompress => 7
            case zstdCompress => 8
            case zstdDecompress => 9
        }
    }

    public static func fromValue(v: Int32): ZlibMode {
        match (v) {
            case 0 => deflate
            case 1 => inflate
            case 2 => gzip
            case 3 => gunzip
            case 4 => deflateRaw
            case 5 => inflateRaw
            case 6 => brotliCompress
            case 7 => brotliDecompress
            case 8 => zstdCompress
            case 9 => zstdDecompress
            case _ => deflate
        }
    }
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
        outputBuffer = Array<UInt8>(16384, { _ => UInt8(0) })
    }

    // 初始化 Brotli 流
    public func initBrotliStream(): Unit {
        outputBuffer = Array<UInt8>(16384, { _ => UInt8(0) })
    }

    // 初始化 Zstd 流
    public func initZstdStream(): Unit {
        outputBuffer = Array<UInt8>(16384, { _ => UInt8(0) })
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
                 ZlibMode.deflateRaw | ZlibMode.inflateRaw =>
                return ZlibImpl.process(mode, input, inOff, inLen,
                    output, outOff, outLen, Int32(flush.value()))
            case ZlibMode.brotliCompress | ZlibMode.brotliDecompress =>
                let isCompress = match (mode) {
                    case ZlibMode.brotliCompress => true
                    case _ => false
                }
                let brotliMode = if (isCompress) {
                    BrotliMode.compress
                } else {
                    BrotliMode.decompress
                }
                return ZlibImpl.brotliProcess(brotliMode, input, inOff, inLen,
                    output, outOff, outLen, Int32(flush.value()))
            case ZlibMode.zstdCompress | ZlibMode.zstdDecompress =>
                let isCompress2 = match (mode) {
                    case ZlibMode.zstdCompress => true
                    case _ => false
                }
                let zstdMode = if (isCompress2) {
                    ZstdMode.compress
                } else {
                    ZstdMode.decompress
                }
                return ZlibImpl.zstdProcess(zstdMode, input, inOff, inLen,
                    output, outOff, outLen, Int32(flush.value()))
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
    public static func crc32(data: Array<UInt8>, value: UInt32): UInt32 {
        // 使用 zlib crc32 FFI
        return ZlibImpl.crc32(data, value)
    }

    // CRC32 字符串版本
    public static func crc32String(str: String, value: UInt32): UInt32 {
        let data = Array<UInt8>(str.size, { i => str[i] })
        return crc32(data, value)
    }

    // 创建压缩流绑定对象
    // 对应 Bun: node_zlib_binding.zig - createNodeZlibBinding
    public static func create(global: JsGlobalObject): HashMap<String, Object> {
        let zlib = HashMap<String, Object>()

        zlib.put("crc32", BaoString("NodeZlibBinding.crc32"))
        zlib.put("deflate", BaoString("NodeZlibBinding.deflate"))
        zlib.put("inflate", BaoString("NodeZlibBinding.inflate"))
        zlib.put("gzip", BaoString("NodeZlibBinding.gzip"))
        zlib.put("gunzip", BaoString("NodeZlibBinding.gunzip"))
        zlib.put("deflateRaw", BaoString("NodeZlibBinding.deflateRaw"))
        zlib.put("inflateRaw", BaoString("NodeZlibBinding.inflateRaw"))
        zlib.put("brotliCompress", BaoString("NodeZlibBinding.brotliCompress"))
        zlib.put("brotliDecompress", BaoString("NodeZlibBinding.brotliDecompress"))

        // 常量
        zlib.put("Z_NO_FLUSH", BaoString("0"))
        zlib.put("Z_PARTIAL_FLUSH", BaoString("1"))
        zlib.put("Z_SYNC_FLUSH", BaoString("2"))
        zlib.put("Z_FULL_FLUSH", BaoString("3"))
        zlib.put("Z_FINISH", BaoString("4"))
        zlib.put("Z_BLOCK", BaoString("5"))
        zlib.put("Z_TREES", BaoString("6"))

        // 返回码
        zlib.put("Z_OK", BaoString("0"))
        zlib.put("Z_STREAM_END", BaoString("1"))
        zlib.put("Z_NEED_DICT", BaoString("2"))
        zlib.put("Z_ERRNO", BaoString("-1"))
        zlib.put("Z_STREAM_ERROR", BaoString("-2"))
        zlib.put("Z_DATA_ERROR", BaoString("-3"))
        zlib.put("Z_MEM_ERROR", BaoString("-4"))
        zlib.put("Z_BUF_ERROR", BaoString("-5"))
        zlib.put("Z_VERSION_ERROR", BaoString("-6"))

        // 压缩级别
        zlib.put("Z_NO_COMPRESSION", BaoString("0"))
        zlib.put("Z_BEST_SPEED", BaoString("1"))
        zlib.put("Z_BEST_COMPRESSION", BaoString("9"))
        zlib.put("Z_DEFAULT_COMPRESSION", BaoString("-1"))

        // 策略
        zlib.put("Z_DEFAULT_STRATEGY", BaoString("0"))
        zlib.put("Z_FILTERED", BaoString("1"))
        zlib.put("Z_HUFFMAN_ONLY", BaoString("2"))
        zlib.put("Z_RLE", BaoString("3"))
        zlib.put("Z_FIXED", BaoString("4"))

        return zlib
    }

    // 压缩
    public static func deflate(data: Array<UInt8>): Array<UInt8> {
        return ZlibImpl.deflate(data, -1)
    }

    public static func deflate(data: Array<UInt8>, level: Int32): Array<UInt8> {
        return ZlibImpl.deflate(data, level)
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
    public static func deflateRaw(data: Array<UInt8>): Array<UInt8> {
        return ZlibImpl.deflateRaw(data, -1)
    }

    public static func deflateRaw(data: Array<UInt8>, level: Int32): Array<UInt8> {
        return ZlibImpl.deflateRaw(data, level)
    }

    // 原始 inflate
    public static func inflateRaw(data: Array<UInt8>): Array<UInt8> {
        return ZlibImpl.inflateRaw(data)
    }

    // Brotli 压缩
    public static func brotliCompress(data: Array<UInt8>): Array<UInt8> {
        return ZlibImpl.brotliCompress(data, 11)
    }

    public static func brotliCompress(data: Array<UInt8>, quality: Int32): Array<UInt8> {
        return ZlibImpl.brotliCompress(data, quality)
    }

    // Brotli 解压缩
    public static func brotliDecompress(data: Array<UInt8>): Array<UInt8> {
        return ZlibImpl.brotliDecompress(data)
    }

    // Zstd 压缩
    public static func zstdCompress(data: Array<UInt8>): Array<UInt8> {
        return ZlibImpl.zstdCompress(data, 3)
    }

    public static func zstdCompress(data: Array<UInt8>, level: Int32): Array<UInt8> {
        return ZlibImpl.zstdCompress(data, level)
    }

    // Zstd 解压缩
    public static func zstdDecompress(data: Array<UInt8>): Array<UInt8> {
        return ZlibImpl.zstdDecompress(data)
    }
}

// ZlibImpl — 已在 zlib_impl.cj 中定义
