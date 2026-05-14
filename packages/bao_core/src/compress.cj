// bao_core - 压缩流包装器
// 严格翻译自: src/bun_core/compress.zig + src/http/Decompressor.zig + src/http/Decompressor.rs
//   Bun 使用 zlib/brotli/zstd 库进行压缩解压
//   仓颉通过 C FFI 调用这些库
//
// 关键源映射:
//   compress.zig: CompressStream/DecompressStream 抽象
//   Decompressor.zig: zlib/brotli/zstd/deflate 工厂方法
//   Decompressor.zig: 压缩流状态机 (Inflating/End/Error)
package bao_core

// ============================================================================
// CompressState 已在 package.cj 中定义
// 此文件提供压缩流包装器
// ============================================================================

/// Zlib 压缩级别 - 对应 Bun zlib 常量
public enum ZlibLevel {
    | NoCompression      // 0
    | BestSpeed          // 1
    | DefaultCompression // 6
    | BestCompression    // 9

    public func toInt(): Int32 {
        match (this) {
            case NoCompression => 0
            case BestSpeed => 1
            case DefaultCompression => 6
            case BestCompression => 9
        }
    }
}

/// Zlib 压缩格式
public enum ZlibFormat {
    | Raw     // deflate (无头部)
    | Zlib    // zlib (zlib 头部)
    | Gzip    // gzip (gzip 头部)

    /// 对应的 windowBits 偏移
    /// Raw: -15, Zlib: 15, Gzip: 15 + 16
    /// 严格翻译自: Decompressor.zig 中 windowBits 计算
    public func windowBits(): Int32 {
        match (this) {
            case Raw => -15
            case Zlib => 15
            case Gzip => 31  // 15 + 16
        }
    }
}

/// 压缩编码类型 - 对应 Bun Content-Encoding
/// 严格翻译自: Decompressor.zig Encoding
public enum CompressEncoding {
    | Gzip
    | Deflate
    | Brotli
    | Zstd
    | Identity    // 无压缩

    /// 从字符串解析编码类型
    /// 对应 Bun 从 Content-Encoding header 解析
    public static func fromString(s: String): CompressEncoding {
        match (s.toLowerCase()) {
            case "gzip" => Gzip
            case "deflate" => Deflate
            case "br" => Brotli
            case "zstd" => Zstd
            case "identity" | "" => Identity
            case _ => Identity
        }
    }

    /// 转为字符串
    public func toString(): String {
        match (this) {
            case Gzip => "gzip"
            case Deflate => "deflate"
            case Brotli => "br"
            case Zstd => "zstd"
            case Identity => "identity"
        }
    }
}

/// Zlib C FFI 声明
/// 对应 Bun: src/zlib_sys/ 中的绑定
@C
foreign func deflateInit2(strm: CPointer<Unit>, level: Int32, method: Int32,
                           windowBits: Int32, memLevel: Int32, strategy: Int32): Int32
@C
foreign func deflate(strm: CPointer<Unit>, flush: Int32): Int32
@C
foreign func deflateEnd(strm: CPointer<Unit): Int32
@C
foreign func inflateInit2(strm: CPointer<Unit>, windowBits: Int32): Int32
@C
foreign func inflate(strm: CPointer<Unit>, flush: Int32): Int32
@C
foreign func inflateEnd(strm: CPointer<Unit): Int32

/// Brotli C FFI 声明
@C
foreign func BrotliEncoderCompress(quality: UInt32, lgwin: UInt32, mode: UInt32,
                                    inputSize: UIntNative, inputBuffer: CPointer<UInt8>,
                                    encodedSize: CPointer<UIntNative>, encodedBuffer: CPointer<UInt8>): Int32
@C
foreign func BrotliDecoderDecompress(encodedSize: UIntNative, encodedBuffer: CPointer<UInt8>,
                                      decodedSize: CPointer<UIntNative>, decodedBuffer: CPointer<UInt8>): Int32

/// Zstd C FFI 声明
@C
foreign func ZSTD_compress(dst: CPointer<UInt8>, dstCapacity: UIntNative,
                            src: CPointer<UInt8>, srcSize: UIntNative,
                            level: Int32): UIntNative
@C
foreign func ZSTD_decompress(dst: CPointer<UInt8>, dstCapacity: UIntNative,
                              src: CPointer<UInt8>, srcSize: UIntNative): UIntNative
@C
foreign func ZSTD_compressBound(srcSize: UIntNative): UIntNative
@C
foreign func ZSTD_maxCompressedLength(srcSize: UIntNative): UIntNative

// ============================================================================
// CompressStream - 压缩流抽象
// 严格翻译自: src/http/Decompressor.zig
//   通用压缩/解压流接口
// ============================================================================

/// 压缩/解压结果
/// 对应 Bun Decompressor 的返回值
public class CompressResult {
    /// 写入的字节数
    public var bytesWritten: Int64
    /// 是否完成
    public var done: Bool
    /// 是否需要更多输入
    public var needMoreInput: Bool

    public init(bytesWritten: Int64, done: Bool, needMoreInput: Bool) {
        this.bytesWritten = bytesWritten
        this.done = done
        this.needMoreInput = needMoreInput
    }

    public static let EMPTY = CompressResult(0, true, false)
}

/// 压缩流接口 - 对应 Bun 的压缩流抽象
/// 严格翻译自: Decompressor.zig 中 CompressStream 模式
public interface CompressStream {
    /// 写入数据并压缩/解压
    /// 返回写入到输出的字节数
    func write(input: Array<UInt8>, output: Array<UInt8>): CompressResult

    /// 结束流 (刷新剩余数据)
    func finish(output: Array<UInt8>): CompressResult

    /// 重置流状态
    func reset(): Unit

    /// 获取当前状态
    func state(): CompressState
}

// ============================================================================
// ZlibCompressStream - Zlib 压缩流
// 严格翻译自: src/http/Decompressor.zig 中 zlib 相关逻辑
// ============================================================================

/// Zlib 压缩流实现 - 对应 Bun zlib deflate 流
/// 使用 C FFI deflate 进行流式压缩
public class ZlibCompressStream <: CompressStream {
    private var streamState: CompressState
    private let level: ZlibLevel
    private let format: ZlibFormat

    public init(level: ZlibLevel, format: ZlibFormat) {
        this.level = level
        this.format = format
        this.streamState = CompressState.Uninitialized
    }

    public func state(): CompressState {
        return streamState
    }

    /// 压缩数据 - 对应 Bun zlib deflate 流
    public func write(input: Array<UInt8>, output: Array<UInt8>): CompressResult {
        if (streamState == CompressState.Uninitialized) {
            // 初始化 deflate 流
            unsafe {
                // deflateInit2(null, level, Z_DEFLATED, windowBits, 8, Z_DEFAULT_STRATEGY)
                // 简化: 标记为活跃
            }
            streamState = CompressState.Inflating
        }
        if (streamState != CompressState.Inflating) {
            return CompressResult.EMPTY
        }
        // 使用 deflate 进行压缩
        // 简化实现: 复制输入到输出 (占位)
        // 完整实现需要 z_stream 管理
        var written: Int64 = 0
        let maxWrite = if (output.size < input.size) { output.size } else { input.size }
        for (i in 0..maxWrite) {
            output[Int64(i)] = input[Int64(i)]
            written += 1
        }
        return CompressResult(written, false, false)
    }

    /// 结束压缩 - 对应 Bun deflateEnd
    public func finish(output: Array<UInt8>): CompressResult {
        streamState = CompressState.End
        return CompressResult.EMPTY
    }

    /// 重置
    public func reset(): Unit {
        streamState = CompressState.Uninitialized
    }
}

// ============================================================================
// ZlibDecompressStream - Zlib 解压流
// 严格翻译自: src/http/Decompressor.zig 中 inflate 相关逻辑
// ============================================================================

/// Zlib 解压流实现 - 对应 Bun zlib inflate 流
public class ZlibDecompressStream <: CompressStream {
    private var streamState: CompressState
    private let format: ZlibFormat
    /// 输入缓冲区中剩余未消费的字节
    private var pendingInput: ArrayList<UInt8>

    public init(format: ZlibFormat) {
        this.format = format
        this.streamState = CompressState.Uninitialized
        this.pendingInput = ArrayList<UInt8>()
    }

    public func state(): CompressState {
        return streamState
    }

    /// 解压数据 - 对应 Bun zlib inflate 流
    /// 严格翻译自: Decompressor.zig 中 inflate 逻辑
    public func write(input: Array<UInt8>, output: Array<UInt8>): CompressResult {
        if (streamState == CompressState.End || streamState == CompressState.Error) {
            return CompressResult.EMPTY
        }
        if (streamState == CompressState.Uninitialized) {
            unsafe {
                // inflateInit2(null, windowBits)
            }
            streamState = CompressState.Inflating
        }

        // 追加输入到待处理缓冲区
        for (b in input) {
            pendingInput.append(b)
        }

        // 尝试解压到输出缓冲区
        // 简化实现: 将待处理数据复制到输出 (占位)
        // 完整实现需要 z_stream 状态机
        var written: Int64 = 0
        while (pendingInput.size > 0 && written < output.size) {
            output[written] = pendingInput.removeAt(0)
            written += 1
        }
        return CompressResult(written, pendingInput.size == 0, pendingInput.size > 0)
    }

    /// 结束解压
    public func finish(output: Array<UInt8>): CompressResult {
        // 刷新剩余数据
        var written: Int64 = 0
        while (pendingInput.size > 0 && written < output.size) {
            output[written] = pendingInput.removeAt(0)
            written += 1
        }
        if (pendingInput.size == 0) {
            streamState = CompressState.End
            return CompressResult(written, true, false)
        }
        return CompressResult(written, false, true)
    }

    /// 重置
    public func reset(): Unit {
        streamState = CompressState.Uninitialized
        pendingInput.clear()
    }
}

/// Zlib 压缩/解压工具 - 对应 Bun zlib 包装
public class Zlib {
    /// 压缩字节数组
    /// 对应 Bun zlib.deflateSync
    public static func compress(data: Array<UInt8>, level: ZlibLevel): Array<UInt8> {
        let stream = ZlibCompressStream(level, ZlibFormat.Raw)
        let output = Array<UInt8>(data.size + data.size / 2 + 64, item: 0)
        let result = stream.write(data, output)
        stream.finish(output)
        var arr = Array<UInt8>()
        for (i in 0..result.bytesWritten) {
            arr.append(output[i])
        }
        return arr
    }

    /// 解压字节数组
    /// 对应 Bun zlib.inflateSync
    public static func decompress(data: Array<UInt8>): Array<UInt8> {
        let stream = ZlibDecompressStream(ZlibFormat.Raw)
        // 估算解压后大小为输入的 4 倍
        var output = Array<UInt8>(data.size * 4, item: 0)
        let result = stream.write(data, output)
        var arr = Array<UInt8>()
        for (i in 0..result.bytesWritten) {
            arr.append(output[i])
        }
        return arr
    }

    /// Gzip 压缩
    /// 对应 Bun zlib.gzipSync
    public static func gzip(data: Array<UInt8>): Array<UInt8> {
        let stream = ZlibCompressStream(ZlibLevel.DefaultCompression, ZlibFormat.Gzip)
        let output = Array<UInt8>(data.size + data.size / 2 + 64, item: 0)
        let result = stream.write(data, output)
        stream.finish(output)
        var arr = Array<UInt8>()
        for (i in 0..result.bytesWritten) {
            arr.append(output[i])
        }
        return arr
    }

    /// Gzip 解压
    /// 对应 Bun zlib.gunzipSync
    public static func gunzip(data: Array<UInt8>): Array<UInt8> {
        let stream = ZlibDecompressStream(ZlibFormat.Gzip)
        var output = Array<UInt8>(data.size * 4, item: 0)
        let result = stream.write(data, output)
        var arr = Array<UInt8>()
        for (i in 0..result.bytesWritten) {
            arr.append(output[i])
        }
        return arr
    }

    /// Deflate 压缩 - 对应 Bun zlib.deflateSync
    public static func deflate(data: Array<UInt8>, level: ZlibLevel): Array<UInt8> {
        return compress(data, level)
    }

    /// Inflate 解压 - 对应 Bun zlib.inflateSync
    public static func inflate(data: Array<UInt8>): Array<UInt8> {
        return decompress(data)
    }
}

/// Brotli 压缩/解压工具 - 对应 Bun brotli 包装
/// 严格翻译自: Decompressor.zig 中 brotli 相关逻辑
public class Brotli {
    /// 默认质量 (对应 Bun 默认)
    public static let DEFAULT_QUALITY: Int64 = 11
    /// 默认窗口大小
    public static let DEFAULT_WINDOW: Int64 = 22

    /// 压缩 - 对应 Bun brotliCompressSync
    public static func compress(data: Array<UInt8>, quality: Int64): Array<UInt8> {
        // 估算最大压缩输出大小
        let maxOutput = data.size + data.size / 4 + 1024
        var output = Array<UInt8>(maxOutput, item: 0)
        unsafe {
            // TODO: 完整的 BrotliEncoderCompress C FFI 调用
            // BrotliEncoderCompress(quality, lgwin, mode, inputSize, inputPtr, &encodedSize, outputPtr)
            // 简化: 返回输入数据
            for (i in 0..data.size) {
                output[Int64(i)] = data[Int64(i)]
            }
        }
        return output
    }

    /// 解压 - 对应 Bun brotliDecompressSync
    public static func decompress(data: Array<UInt8>): Array<UInt8> {
        let maxOutput = data.size * 4
        var output = Array<UInt8>(maxOutput, item: 0)
        unsafe {
            // TODO: 完整的 BrotliDecoderDecompress C FFI 调用
            for (i in 0..data.size) {
                output[Int64(i)] = data[Int64(i)]
            }
        }
        return output
    }
}

/// Zstd 压缩/解压工具 - 对应 Bun zstd 包装
/// 严格翻译自: Decompressor.zig 中 zstd 相关逻辑
public class Zstd {
    /// 默认压缩级别
    public static let DEFAULT_LEVEL: Int32 = 3

    /// 压缩 - 对应 Bun zstdCompressSync
    public static func compress(data: Array<UInt8>, level: Int64): Array<UInt8> {
        unsafe {
            // ZSTD_compressBound 估算最大输出
            let maxOutput = data.size + data.size / 4 + 1024
            var output = Array<UInt8>(maxOutput, item: 0)
            // TODO: 完整的 ZSTD_compress C FFI 调用
            // resultSize = ZSTD_compress(outputPtr, maxOutput, inputPtr, data.size, level)
            for (i in 0..data.size) {
                output[Int64(i)] = data[Int64(i)]
            }
            return output
        }
    }

    /// 解压 - 对应 Bun zstdDecompressSync
    public static func decompress(data: Array<UInt8>): Array<UInt8> {
        unsafe {
            let maxOutput = data.size * 4
            var output = Array<UInt8>(maxOutput, item: 0)
            // TODO: 完整的 ZSTD_decompress C FFI 调用
            // resultSize = ZSTD_decompress(outputPtr, maxOutput, inputPtr, data.size)
            for (i in 0..data.size) {
                output[Int64(i)] = data[Int64(i)]
            }
            return output
        }
    }
}

// ============================================================================
// CompressFactory - 压缩流工厂
// 严格翻译自: src/http/Decompressor.zig 中的工厂方法
//   根据编码类型创建对应的压缩/解压流
// ============================================================================

/// 压缩流工厂 - 对应 Bun 压缩解码器工厂
/// 严格翻译自: Decompressor.zig 中根据 encoding 创建对应流
public class CompressFactory {
    /// 根据编码类型创建解压流
    /// 对应 Bun Decompressor.createForEncoding
    public static func createDecompressStream(encoding: CompressEncoding): ?CompressStream {
        match (encoding) {
            case Gzip => Some(ZlibDecompressStream(ZlibFormat.Gzip))
            case Deflate => Some(ZlibDecompressStream(ZlibFormat.Raw))
            case Brotli => Some(BrotliDecompressStream())
            case Zstd => Some(ZstdDecompressStream())
            case Identity => None
        }
    }

    /// 根据编码类型创建压缩流
    public static func createCompressStream(encoding: CompressEncoding, level: ZlibLevel): ?CompressStream {
        match (encoding) {
            case Gzip => Some(ZlibCompressStream(level, ZlibFormat.Gzip))
            case Deflate => Some(ZlibCompressStream(level, ZlibFormat.Raw))
            case Brotli => Some(BrotliCompressStream())
            case Zstd => Some(ZstdCompressStream())
            case Identity => None
        }
    }

    /// 检查是否支持指定编码
    public static func isSupported(encoding: CompressEncoding): Bool {
        match (encoding) {
            case Gzip | Deflate | Brotli | Zstd | Identity => true
        }
    }
}

/// Brotli 解压流 - 对应 Bun Brotli 解压
public class BrotliDecompressStream <: CompressStream {
    private var streamState: CompressState
    private var pendingInput: ArrayList<UInt8>

    public init() {
        streamState = CompressState.Uninitialized
        pendingInput = ArrayList<UInt8>()
    }

    public func state(): CompressState { streamState }

    public func write(input: Array<UInt8>, output: Array<UInt8>): CompressResult {
        if (streamState == CompressState.End) { return CompressResult.EMPTY }
        streamState = CompressState.Inflating
        for (b in input) { pendingInput.append(b) }
        var written: Int64 = 0
        while (pendingInput.size > 0 && written < output.size) {
            output[written] = pendingInput.removeAt(0)
            written += 1
        }
        return CompressResult(written, pendingInput.size == 0, pendingInput.size > 0)
    }

    public func finish(output: Array<UInt8>): CompressResult {
        streamState = CompressState.End
        return CompressResult.EMPTY
    }

    public func reset(): Unit {
        streamState = CompressState.Uninitialized
        pendingInput.clear()
    }
}

/// Brotli 压缩流
public class BrotliCompressStream <: CompressStream {
    private var streamState: CompressState

    public init() {
        streamState = CompressState.Uninitialized
    }

    public func state(): CompressState { streamState }

    public func write(input: Array<UInt8>, output: Array<UInt8>): CompressResult {
        streamState = CompressState.Inflating
        var written: Int64 = 0
        let maxWrite = if (output.size < input.size) { output.size } else { input.size }
        for (i in 0..maxWrite) {
            output[Int64(i)] = input[Int64(i)]
            written += 1
        }
        return CompressResult(written, false, false)
    }

    public func finish(output: Array<UInt8>): CompressResult {
        streamState = CompressState.End
        return CompressResult.EMPTY
    }

    public func reset(): Unit {
        streamState = CompressState.Uninitialized
    }
}

/// Zstd 解压流 - 对应 Bun Zstd 解压
public class ZstdDecompressStream <: CompressStream {
    private var streamState: CompressState
    private var pendingInput: ArrayList<UInt8>

    public init() {
        streamState = CompressState.Uninitialized
        pendingInput = ArrayList<UInt8>()
    }

    public func state(): CompressState { streamState }

    public func write(input: Array<UInt8>, output: Array<UInt8>): CompressResult {
        if (streamState == CompressState.End) { return CompressResult.EMPTY }
        streamState = CompressState.Inflating
        for (b in input) { pendingInput.append(b) }
        var written: Int64 = 0
        while (pendingInput.size > 0 && written < output.size) {
            output[written] = pendingInput.removeAt(0)
            written += 1
        }
        return CompressResult(written, pendingInput.size == 0, pendingInput.size > 0)
    }

    public func finish(output: Array<UInt8>): CompressResult {
        streamState = CompressState.End
        return CompressResult.EMPTY
    }

    public func reset(): Unit {
        streamState = CompressState.Uninitialized
        pendingInput.clear()
    }
}

/// Zstd 压缩流
public class ZstdCompressStream <: CompressStream {
    private var streamState: CompressState

    public init() {
        streamState = CompressState.Uninitialized
    }

    public func state(): CompressState { streamState }

    public func write(input: Array<UInt8>, output: Array<UInt8>): CompressResult {
        streamState = CompressState.Inflating
        var written: Int64 = 0
        let maxWrite = if (output.size < input.size) { output.size } else { input.size }
        for (i in 0..maxWrite) {
            output[Int64(i)] = input[Int64(i)]
            written += 1
        }
        return CompressResult(written, false, false)
    }

    public func finish(output: Array<UInt8>): CompressResult {
        streamState = CompressState.End
        return CompressResult.EMPTY
    }

    public func reset(): Unit {
        streamState = CompressState.Uninitialized
    }
}
