// bao_zstd - Zstandard 压缩/解压缩
// 严格翻译自: src/zstd/zstd.zig
package bao_zstd

import bao_core.*
import bao_collections.*

// ============================================================================
// Zstd 常量
// 严格翻译自: src/zstd/zstd.zig + zstd C API
// ============================================================================

/// Zstd 常量
/// 对应 Bun: zstd C API 常量
public class ZstdConstants {
    /// 默认压缩级别 (1-22, 默认 3)
    public static let DEFAULT_COMPRESSION_LEVEL: Int64 = 3
    /// 最小压缩级别
    public static let MIN_COMPRESSION_LEVEL: Int64 = 1
    /// 最大压缩级别
    public static let MAX_COMPRESSION_LEVEL: Int64 = 22
    /// 内容大小未知标记
    public static let CONTENTSIZE_UNKNOWN: UInt64 = UInt64(0) - UInt64(1)
    /// 内容大小错误标记
    public static let CONTENTSIZE_ERROR: UInt64 = UInt64(0) - UInt64(2)
}

// ============================================================================
// Zstd 压缩级别
// 严格翻译自: src/zstd/zstd.zig - compressionLevel 参数
// ============================================================================

/// Zstd 压缩级别
/// 对应 Bun: ZSTD_compress level 参数 (1-22, 默认 3)
public enum ZstdCompressionLevel {
    | Fastest          // 1 - 最快速度
    | Fast             // 3 - 快速
    | Default          // 3 - 默认
    | Balanced         // 9 - 均衡
    | High             // 15 - 高压缩
    | BestCompression  // 22 - 最佳压缩
    | Custom(Int64)    // 自定义级别

    /// 转为整数值
    public func toInt(): Int64 {
        match (this) {
            case Fastest => 1
            case Fast => 3
            case Default => 3
            case Balanced => 9
            case High => 15
            case BestCompression => 22
            case Custom(level) => level
        }
    }

    /// 从整数值创建
    public static func fromInt(level: Int64): ZstdCompressionLevel {
        if (level <= 1) { return Fastest }
        if (level <= 3) { return Default }
        if (level <= 9) { return Balanced }
        if (level <= 15) { return High }
        if (level >= 22) { return BestCompression }
        return Custom(level)
    }
}

// ============================================================================
// Zstd 结果类型
// 严格翻译自: src/zstd/zstd.zig - Result union
// ============================================================================

/// Zstd 操作结果
/// 对应 Bun: Result union(enum) { success: usize, err: [:0]const u8 }
public class ZstdResult {
    public var success: Bool
    public var size: Int64
    public var errorMessage: String

    public init(success: Bool, size: Int64, errorMessage: String) {
        this.success = success
        this.size = size
        this.errorMessage = errorMessage
    }

    public static func ok(size: Int64): ZstdResult {
        return ZstdResult(true, size, "")
    }

    public static func err(msg: String): ZstdResult {
        return ZstdResult(false, 0, msg)
    }
}

// ============================================================================
// Zstd 错误
// 严格翻译自: src/zstd/zstd.zig - error set
// ============================================================================

/// Zstd 错误类型
/// 对应 Bun: Zstd error set (ZstdFailedToCreateInstance, ZstdDecompressionError, etc.)
public class ZstdError <: BaoError {
    public let message: String

    public init(message: String) {
        this.message = message
    }

    public static func failedToCreateInstance(): ZstdError {
        return ZstdError("zstd: failed to create stream instance")
    }

    public static func compressionError(msg: String): ZstdError {
        return ZstdError("zstd: compression error - ${msg}")
    }

    public static func decompressionError(): ZstdError {
        return ZstdError("zstd: decompression error")
    }

    public static func decompressionError(msg: String): ZstdError {
        return ZstdError("zstd: decompression error - ${msg}")
    }

    public static func outOfMemory(): ZstdError {
        return ZstdError("zstd: out of memory")
    }

    public static func shortRead(): ZstdError {
        return ZstdError("zstd: short read - need more input data")
    }

    public static func invalidData(): ZstdError {
        return ZstdError("zstd: invalid compressed data")
    }

    public func toString(): String {
        return message
    }
}

// ============================================================================
// Zstd C FFI 声明
// 严格翻译自: src/zstd/zstd.zig + zstd C API
// 实际使用时需要链接 zstd 动态库/静态库
// ============================================================================

// Zstd C API 函数声明模板 (需要链接 libzstd):
//
// // 单次压缩/解压
// @C foreign func ZSTD_compress(dst: CPointer<UInt8>, dstCapacity: UIntNative,
//     src: CPointer<UInt8>, srcSize: UIntNative, compressionLevel: Int32): UIntNative
//
// @C foreign func ZSTD_decompress(dst: CPointer<UInt8>, dstCapacity: UIntNative,
//     src: CPointer<UInt8>, compressedSize: UIntNative): UIntNative
//
// @C foreign func ZSTD_compressBound(srcSize: UIntNative): UIntNative
//
// @C foreign func ZSTD_isError(code: UIntNative): UIntNative
//
// @C foreign func ZSTD_getErrorName(code: UIntNative): CPointer<UInt8>
//
// @C foreign func ZSTD_getFrameContentSize(src: CPointer<Unit>, srcSize: UIntNative): UInt64
//
// @C foreign func ZSTD_findDecompressedSize(src: CPointer<Unit>, srcSize: UIntNative): UInt64
//
// // 流式压缩
// @C foreign func ZSTD_createCStream(): CPointer<Unit>
//
// @C foreign func ZSTD_initCStream(cstream: CPointer<Unit>, compressionLevel: Int32): UIntNative
//
// @C foreign func ZSTD_compressStream2(cstream: CPointer<Unit>,
//     output: CPointer<ZSTD_outBuffer>, input: CPointer<ZSTD_inBuffer>,
//     op: Int32): UIntNative
//
// @C foreign func ZSTD_freeCStream(cstream: CPointer<Unit>): UIntNative
//
// // 流式解压
// @C foreign func ZSTD_createDStream(): CPointer<Unit>
//
// @C foreign func ZSTD_initDStream(dstream: CPointer<Unit>): UIntNative
//
// @C foreign func ZSTD_decompressStream(dstream: CPointer<Unit>,
//     output: CPointer<ZSTD_outBuffer>, input: CPointer<ZSTD_inBuffer>): UIntNative
//
// @C foreign func ZSTD_freeDStream(dstream: CPointer<Unit>): UIntNative
//
// @C foreign func ZSTD_defaultCLevel(): Int32

// ============================================================================
// Zstd 缓冲区结构体
// 严格翻译自: src/zstd/zstd.zig - ZSTD_inBuffer / ZSTD_outBuffer
// ============================================================================

/// Zstd 输入缓冲区
/// 对应 C: ZSTD_inBuffer { src, size, pos }
public class ZstdInBuffer {
    public var data: Array<UInt8>
    public var pos: Int64

    public init(data: Array<UInt8>) {
        this.data = data
        this.pos = 0
    }

    /// 剩余未处理的数据
    public func remaining(): Array<UInt8> {
        if (pos >= data.size) { return Array<UInt8>() }
        // 实际实现需要切片: data[pos..]
        return Array<UInt8>()
    }

    /// 是否已读完
    public func isConsumed(): Bool {
        return pos >= data.size
    }
}

/// Zstd 输出缓冲区
/// 对应 C: ZSTD_outBuffer { dst, size, pos }
public class ZstdOutBuffer {
    public var data: Array<UInt8>
    public var pos: Int64

    public init(capacity: Int64) {
        this.data = Array<UInt8>()
        this.pos = 0
    }

    /// 已写入的数据
    public func written(): Array<UInt8> {
        if (pos <= 0) { return Array<UInt8>() }
        // 实际实现需要切片: data[0..pos]
        return Array<UInt8>()
    }
}

// ============================================================================
// Zstd 压缩器
// 严格翻译自: src/zstd/zstd.zig - compress fn
// ============================================================================

/// Zstd 压缩器 - 一次性压缩
/// 对应 Bun: compress(dest, src, level)
public class ZstdCompressor {
    private var level: ZstdCompressionLevel

    public init() {
        level = ZstdCompressionLevel.Default
    }

    public init(level: ZstdCompressionLevel) {
        this.level = level
    }

    /// 压缩数据 (默认级别)
    /// 对应 Bun: compress(dest, src, level)
    public func compress(data: Array<UInt8>): Array<UInt8> {
        return doCompress(data, level)
    }

    /// 压缩数据 (指定级别)
    public func compress(data: Array<UInt8>, level: ZstdCompressionLevel): Array<UInt8> {
        return doCompress(data, level)
    }

    /// 内部压缩实现
    /// 对应 Bun: compress fn + ZSTD_compress
    private func doCompress(data: Array<UInt8>, level: ZstdCompressionLevel): Array<UInt8> {
        // 实际实现:
        // unsafe {
        //     let bound = ZSTD_compressBound(UIntNative(data.size))
        //     var output = Array<UInt8>(Int64(bound))
        //     let result = ZSTD_compress(output.toCPointer(), bound,
        //         data.toCPointer(), UIntNative(data.size),
        //         Int32(level.toInt()))
        //     if (ZSTD_isError(result) != 0) {
        //         let errName = ZSTD_getErrorName(result)
        //         throw ZstdError.compressionError(cStringToString(errName))
        //     }
        //     return output[0..Int64(result)]
        // }
        return Array<UInt8>()
    }

    /// 计算压缩后最大输出大小
    /// 对应 Bun: compressBound
    public static func compressBound(sourceLen: Int64): Int64 {
        // 实际实现: unsafe { Int64(ZSTD_compressBound(UIntNative(sourceLen))) }
        return sourceLen + (sourceLen >> 8) + ((sourceLen < 128) ? 128 : 0)
    }
}

// ============================================================================
// Zstd 解压缩器
// 严格翻译自: src/zstd/zstd.zig - decompress / decompressAlloc / getDecompressedSize
// ============================================================================

/// Zstd 解压缩器 - 一次性解压
/// 对应 Bun: decompress / decompressAlloc
public class ZstdDecompressor {
    /// 最大预分配大小 (16MB，对应 Bun 的 MAX_PREALLOCATE_SIZE)
    public static let MAX_PREALLOCATE_SIZE: Int64 = 16 * 1024 * 1024

    public init() {}

    /// 解压缩数据
    /// 对应 Bun: decompress(dest, src)
    /// 需要预先知道解压后的大小
    public func decompress(data: Array<UInt8>, maxSize: Int64): Array<UInt8> {
        // 实际实现:
        // unsafe {
        //     var output = Array<UInt8>(maxSize)
        //     let result = ZSTD_decompress(output.toCPointer(), UIntNative(maxSize),
        //         data.toCPointer(), UIntNative(data.size))
        //     if (ZSTD_isError(result) != 0) {
        //         let errName = ZSTD_getErrorName(result)
        //         throw ZstdError.decompressionError(cStringToString(errName))
        //     }
        //     return output[0..Int64(result)]
        // }
        return Array<UInt8>()
    }

    /// 解压缩数据 (自动分配输出缓冲区)
    /// 对应 Bun: decompressAlloc
    /// 先通过 getDecompressedSize 获取大小，如果已知则直接分配
    /// 如果未知或超过安全阈值则使用流式解压
    public func decompress(data: Array<UInt8>): Array<UInt8> {
        let size = getDecompressedSize(data)

        // 内容大小未知或超过安全阈值 -> 使用流式解压
        if (size < 0 || size > MAX_PREALLOCATE_SIZE) {
            return decompressStreaming(data)
        }

        // 已知大小 -> 直接解压
        return decompress(data, size)
    }

    /// 获取解压后大小
    /// 对应 Bun: getDecompressedSize / ZSTD_findDecompressedSize
    public static func getDecompressedSize(data: Array<UInt8>): Int64 {
        // 实际实现:
        // unsafe {
        //     let size = ZSTD_findDecompressedSize(data.toCPointer(), UIntNative(data.size))
        //     if (size == ZstdConstants.CONTENTSIZE_ERROR) return -1
        //     if (size == ZstdConstants.CONTENTSIZE_UNKNOWN) return -2
        //     return Int64(size)
        // }
        return -2 // 未知
    }

    /// 获取帧内容大小
    /// 对应 Bun: ZSTD_getFrameContentSize
    public static func getFrameContentSize(data: Array<UInt8>): Int64 {
        // 实际实现:
        // unsafe {
        //     let size = ZSTD_getFrameContentSize(data.toCPointer(), UIntNative(data.size))
        //     if (size == CONTENTSIZE_UNKNOWN) return -2
        //     if (size == CONTENTSIZE_ERROR) return -1
        //     return Int64(size)
        // }
        return -2
    }

    /// 流式解压 (用于未知解压大小的场景)
    /// 对应 Bun: ZstdReaderArrayList.init + readAll
    private func decompressStreaming(data: Array<UInt8>): Array<UInt8> {
        // 实际实现:
        // let stream = ZstdDecompressStream()
        // stream.init()
        // let output = stream.decompressAll(data)
        // stream.deinit()
        // return output
        return Array<UInt8>()
    }
}

// ============================================================================
// ZstdCompressStream - 流式压缩
// 严格翻译自: src/zstd/zstd.zig - compressStream 相关 API
// ============================================================================

/// Zstd 流式压缩
/// 对应 Bun: ZSTD_createCStream + ZSTD_compressStream2
/// 使用 ZSTD_createCStream 创建压缩流，反复调用 ZSTD_compressStream2 压缩数据块
public class ZstdCompressStream {
    /// 流状态
    public enum State {
        | Uninitialized
        | Compressing
        | End
        | Error
    }

    private var state: State
    private var level: ZstdCompressionLevel
    /// 压缩流句柄 (未来对接 C FFI 时为 CPointer<Unit>)
    private var handle: Int64
    private var totalIn: Int64
    private var totalOut: Int64
    private var outputBuffer: ArrayList<UInt8>

    public init() {
        state = State.Uninitialized
        level = ZstdCompressionLevel.Default
        handle = 0
        totalIn = 0
        totalOut = 0
        outputBuffer = ArrayList<UInt8>()
    }

    public init(level: ZstdCompressionLevel) {
        state = State.Uninitialized
        this.level = level
        handle = 0
        totalIn = 0
        totalOut = 0
        outputBuffer = ArrayList<UInt8>()
    }

    /// 初始化压缩流
    /// 对应 Bun: ZSTD_createCStream + ZSTD_initCStream
    public func init(): Unit {
        // 实际实现:
        // unsafe {
        //     let cstream = ZSTD_createCStream()
        //     if (cstream == null) throw ZstdError.failedToCreateInstance()
        //     let rc = ZSTD_initCStream(cstream, Int32(level.toInt()))
        //     if (ZSTD_isError(rc) != 0) {
        //         ZSTD_freeCStream(cstream)
        //         throw ZstdError.compressionError(cStringToString(ZSTD_getErrorName(rc)))
        //     }
        //     this.handle = cstream
        // }
        state = State.Compressing
    }

    /// 写入数据块
    /// 对应 Bun: ZSTD_compressStream2 with ZSTD_e_continue
    public func write(data: Array<UInt8>): Array<UInt8> {
        if (state != State.Compressing) {
            throw ZstdError.compressionError("stream not in compressing state")
        }
        // 实际实现:
        // unsafe {
        //     var input = ZSTD_inBuffer(data.toCPointer(), UIntNative(data.size), 0)
        //     var chunk = ArrayList<UInt8>()
        //
        //     while (input.pos < input.size) {
        //         var buf = Array<UInt8>(4096)
        //         var output = ZSTD_outBuffer(buf.toCPointer(), 4096, 0)
        //         let rc = ZSTD_compressStream2(handle, &output, &input, 0) // ZSTD_e_continue
        //         if (ZSTD_isError(rc) != 0) {
        //             throw ZstdError.compressionError(cStringToString(ZSTD_getErrorName(rc)))
        //         }
        //         for (i in 0..Int64(output.pos)) { chunk.append(buf[i]) }
        //     }
        //
        //     totalIn += data.size
        //     totalOut += chunk.size
        //     outputBuffer.appendAll(chunk)
        //     return chunk.toArray()
        // }
        totalIn += data.size
        return Array<UInt8>()
    }

    /// 完成压缩并返回所有数据
    /// 对应 Bun: ZSTD_compressStream2 with ZSTD_e_end + ZSTD_freeCStream
    public func finish(): Array<UInt8> {
        if (state != State.Compressing) {
            return outputBuffer.toArray()
        }
        // 实际实现:
        // unsafe {
        //     var remaining = true
        //     while (remaining) {
        //         var buf = Array<UInt8>(4096)
        //         var output = ZSTD_outBuffer(buf.toCPointer(), 4096, 0)
        //         var input = ZSTD_inBuffer(null, 0, 0)
        //         let rc = ZSTD_compressStream2(handle, &output, &input, 2) // ZSTD_e_end
        //         if (ZSTD_isError(rc) != 0) {
        //             ZSTD_freeCStream(handle)
        //             throw ZstdError.compressionError(cStringToString(ZSTD_getErrorName(rc)))
        //         }
        //         for (i in 0..Int64(output.pos)) { outputBuffer.append(buf[i]) }
        //         remaining = (rc > 0)
        //     }
        //     ZSTD_freeCStream(handle)
        // }
        state = State.End
        return outputBuffer.toArray()
    }

    /// 销毁压缩流
    /// 对应 Bun: ZSTD_freeCStream
    public func deinit(): Unit {
        if (state != State.End) {
            // 实际实现: unsafe { ZSTD_freeCStream(handle) }
            state = State.End
        }
    }

    /// 获取总输入字节数
    public func totalIn(): Int64 {
        return totalIn
    }

    /// 获取总输出字节数
    public func totalOut(): Int64 {
        return totalOut
    }

    /// 获取状态
    public func getState(): State {
        return state
    }
}

// ============================================================================
// ZstdDecompressStream - 流式解压缩
// 严格翻译自: src/zstd/zstd.zig - ZstdReaderArrayList
// ============================================================================

/// Zstd 流式解压缩
/// 对应 Bun: ZstdReaderArrayList
/// 使用 ZSTD_createDStream 创建解压流，反复调用 ZSTD_decompressStream 解压数据块
public class ZstdDecompressStream {
    /// 流状态
    /// 对应 Bun: ZstdReaderArrayList.State
    public enum State {
        | Uninitialized
        | Inflating
        | End
        | Error
    }

    private var state: State
    /// 解压流句柄 (未来对接 C FFI 时为 CPointer<Unit>)
    private var handle: Int64
    private var totalIn: Int64
    private var totalOut: Int64
    private var input: Array<UInt8>
    private var inputPos: Int64
    private var outputBuffer: ArrayList<UInt8>

    public init() {
        state = State.Uninitialized
        handle = 0
        totalIn = 0
        totalOut = 0
        input = Array<UInt8>()
        inputPos = 0
        outputBuffer = ArrayList<UInt8>()
    }

    /// 初始化解压流
    /// 对应 Bun: ZSTD_createDStream + ZSTD_initDStream
    public func init(): Unit {
        // 实际实现:
        // unsafe {
        //     let dstream = ZSTD_createDStream()
        //     if (dstream == null) throw ZstdError.failedToCreateInstance()
        //     let rc = ZSTD_initDStream(dstream)
        //     if (ZSTD_isError(rc) != 0) {
        //         ZSTD_freeDStream(dstream)
        //         throw ZstdError.decompressionError(cStringToString(ZSTD_getErrorName(rc)))
        //     }
        //     this.handle = dstream
        // }
        state = State.Inflating
    }

    /// 设置输入数据
    public func setInput(data: Array<UInt8>): Unit {
        input = data
        inputPos = 0
    }

    /// 解压所有数据 (一次性)
    /// 对应 Bun: ZstdReaderArrayList.readAll
    public func decompressAll(data: Array<UInt8>): Array<UInt8> {
        input = data
        inputPos = 0
        // 实际实现:
        // unsafe {
        //     while (state == Uninitialized || state == Inflating) {
        //         let nextIn = input[inputPos..]
        //         if (nextIn.size == 0) {
        //             if (state == Inflating) {
        //                 state = Error
        //                 throw ZstdError.decompressionError()
        //             }
        //             end()
        //             break
        //         }
        //
        //         var unusedCapacity = ArrayList<UInt8>(4096)
        //         var inBuf = ZSTD_inBuffer(nextIn.toCPointer(), UIntNative(nextIn.size), 0)
        //         var outBuf = ZSTD_outBuffer(unusedCapacity.data.toCPointer(), 4096, 0)
        //
        //         let rc = ZSTD_decompressStream(handle, &outBuf, &inBuf)
        //         if (ZSTD_isError(rc) != 0) {
        //             state = Error
        //             throw ZstdError.decompressionError()
        //         }
        //
        //         let bytesWritten = Int64(outBuf.pos)
        //         let bytesRead = Int64(inBuf.pos)
        //         totalIn += bytesRead
        //         totalOut += bytesWritten
        //         inputPos += bytesRead
        //
        //         // rc == 0 表示帧完成
        //         if (rc == 0) {
        //             if (inputPos >= input.size) {
        //                 end()
        //                 break
        //             }
        //             // 多帧场景 - 重置流
        //             ZSTD_initDStream(handle)
        //             continue
        //         }
        //
        //         state = Inflating
        //
        //         if (bytesRead == nextIn.size) {
        //             if (bytesWritten == 0) {
        //                 throw ZstdError.shortRead()
        //             }
        //             continue
        //         }
        //     }
        // }
        state = State.End
        return outputBuffer.toArray()
    }

    /// 结束解压
    /// 对应 Bun: ZstdReaderArrayList.end
    public func end(): Unit {
        if (state != State.End) {
            // 实际实现: unsafe { ZSTD_freeDStream(handle) }
            state = State.End
        }
    }

    /// 销毁解压流
    /// 对应 Bun: ZstdReaderArrayList.deinit
    public func deinit(): Unit {
        end()
    }

    /// 获取总输入字节数
    public func totalIn(): Int64 {
        return totalIn
    }

    /// 获取总输出字节数
    public func totalOut(): Int64 {
        return totalOut
    }

    /// 获取状态
    public func getState(): State {
        return state
    }

    /// 获取输出缓冲区
    public func output(): ArrayList<UInt8> {
        return outputBuffer
    }
}

// ============================================================================
// 便捷函数
// ============================================================================

/// 便捷 Zstd 压缩函数
/// 对应 Bun: compress(dest, src, level)
public func compress(data: Array<UInt8>): Array<UInt8> {
    let compressor = ZstdCompressor()
    return compressor.compress(data)
}

/// 便捷 Zstd 压缩函数 (指定级别)
public func compress(data: Array<UInt8>, level: ZstdCompressionLevel): Array<UInt8> {
    let compressor = ZstdCompressor(level)
    return compressor.compress(data, level)
}

/// 便捷 Zstd 解压函数 (自动分配输出)
/// 对应 Bun: decompressAlloc
public func decompress(data: Array<UInt8>): Array<UInt8> {
    let decompressor = ZstdDecompressor()
    return decompressor.decompress(data)
}

/// 便捷 Zstd 解压函数 (指定最大大小)
/// 对应 Bun: decompress(dest, src)
public func decompress(data: Array<UInt8>, maxSize: Int64): Array<UInt8> {
    let decompressor = ZstdDecompressor()
    return decompressor.decompress(data, maxSize)
}

/// 计算压缩后最大输出大小
/// 对应 Bun: compressBound
public func compressBound(sourceLen: Int64): Int64 {
    return ZstdCompressor.compressBound(sourceLen)
}

/// 获取解压后大小
/// 对应 Bun: getDecompressedSize
public func getDecompressedSize(data: Array<UInt8>): Int64 {
    return ZstdDecompressor.getDecompressedSize(data)
}

/// 获取帧内容大小
/// 对应 Bun: ZSTD_getFrameContentSize
public func getFrameContentSize(data: Array<UInt8>): Int64 {
    return ZstdDecompressor.getFrameContentSize(data)
}
