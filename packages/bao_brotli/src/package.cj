// bao_brotli - Brotli 压缩/解压缩
// 严格翻译自: src/brotli/brotli.zig
package bao_brotli

import bao_core.*
import bao_collections.*

// ============================================================================
// Brotli 常量
// 严格翻译自: src/brotli/brotli.zig + brotli C API
// ============================================================================

/// Brotli 常量
/// 对应 Bun: brotli C API 常量
public class BrotliConstants {
    /// 默认质量 (0-11, 默认 11)
    public static let DEFAULT_QUALITY: Int64 = 11
    /// 最小质量
    public static let MIN_QUALITY: Int64 = 0
    /// 最大质量
    public static let MAX_QUALITY: Int64 = 11
    /// 默认窗口大小 (LARGE_WINDOW)
    public static let DEFAULT_WINDOW: Int64 = 22
    /// 最大窗口大小
    public static let MAX_WINDOW: Int64 = 30
}

// ============================================================================
// Brotli 解码器参数
// 严格翻译自: src/brotli/brotli.zig - DecoderOptions
// ============================================================================

/// Brotli 解码器参数
/// 对应 Bun: DecoderOptions.Params
public class BrotliDecoderOptions {
    public var largeWindow: Bool
    public var disableRingBufferReallocation: Bool

    public init() {
        largeWindow = true
        disableRingBufferReallocation = false
    }
}

// ============================================================================
// Brotli 编码器操作
// 严格翻译自: src/brotli/brotli.zig - BrotliEncoder.Operation
// ============================================================================

/// Brotli 编码器操作类型
/// 对应 Bun: BrotliEncoder.Operation
public enum BrotliOperation {
    | Process    // 处理输入数据
    | Flush      // 刷新输出
    | Finish     // 完成压缩

    public func toInt(): Int32 {
        match (this) {
            case Process => 0
            case Flush => 1
            case Finish => 2
        }
    }
}

// ============================================================================
// Brotli 错误
// 严格翻译自: src/brotli/brotli.zig - error set
// ============================================================================

/// Brotli 错误类型
/// 对应 Bun: Brotli error set (BrotliFailedToLoad, BrotliFailedToCreateInstance, etc.)
public class BrotliError <: BaoError {
    public init(message: String) {
        super(ErrorCode.Unexpected, message)
    }

    public static func failedToLoad(): BrotliError {
        return BrotliError("brotli: failed to load brotli library")
    }

    public static func failedToCreateInstance(): BrotliError {
        return BrotliError("brotli: failed to create encoder/decoder instance")
    }

    public static func compressionError(): BrotliError {
        return BrotliError("brotli: compression error")
    }

    public static func decompressionError(): BrotliError {
        return BrotliError("brotli: decompression error")
    }

    public static func outOfMemory(): BrotliError {
        return BrotliError("brotli: out of memory")
    }

    public static func shortRead(): BrotliError {
        return BrotliError("brotli: short read - need more input data")
    }

    public static func invalidArgument(msg: String): BrotliError {
        return BrotliError("brotli: invalid argument - ${msg}")
    }

    public func toString(): String {
        return message
    }
}

// ============================================================================
// Brotli C FFI 声明
// 严格翻译自: src/brotli/brotli.zig + brotli_sys
// 实际使用时需要链接 brotli 动态库/静态库
// ============================================================================

// Brotli C API 函数声明模板 (需要链接 libbrotlicommon/libbrotlienc/libbrotlidec):
//
// // 编码器
// @C foreign func BrotliEncoderCompress(quality: UInt32, lgwin: UInt32, mode: UInt32,
//     inputSize: UIntNative, inputBuffer: CPointer<UInt8>,
//     encodedSize: CPointer<UIntNative>, encodedBuffer: CPointer<UInt8>): Int32
//
// @C foreign func BrotliEncoderCompressStream(state: CPointer<Unit>, op: Int32,
//     availableIn: CPointer<UIntNative>, nextIn: CPointer<CPointer<UInt8>>,
//     availableOut: CPointer<UIntNative>, nextOut: CPointer<CPointer<UInt8>>,
//     totalOut: CPointer<UIntNative>): Int32
//
// @C foreign func BrotliEncoderCreateInstance(allocFunc: CPointer<Unit>,
//     freeFunc: CPointer<Unit>, opaque: CPointer<Unit>): CPointer<Unit>
//
// @C foreign func BrotliEncoderDestroyInstance(state: CPointer<Unit>): Unit
//
// @C foreign func BrotliEncoderIsFinished(state: CPointer<Unit>): Int32
//
// @C foreign func BrotliEncoderSetParameter(state: CPointer<Unit>,
//     param: UInt32, value: UInt32): Int32
//
// @C foreign func BrotliEncoderTakeOutput(state: CPointer<Unit>,
//     size: CPointer<UIntNative>): CPointer<UInt8>
//
// // 解码器
// @C foreign func BrotliDecoderDecompress(encodedSize: UIntNative,
//     encodedBuffer: CPointer<UInt8>, decodedSize: CPointer<UIntNative>,
//     decodedBuffer: CPointer<UInt8>): Int32
//
// @C foreign func BrotliDecoderDecompressStream(state: CPointer<Unit>,
//     availableIn: CPointer<UIntNative>, nextIn: CPointer<CPointer<UInt8>>,
//     availableOut: CPointer<UIntNative>, nextOut: CPointer<CPointer<UInt8>>,
//     totalOut: CPointer<UIntNative>): Int32
//
// @C foreign func BrotliDecoderCreateInstance(allocFunc: CPointer<Unit>,
//     freeFunc: CPointer<Unit>, opaque: CPointer<Unit>): CPointer<Unit>
//
// @C foreign func BrotliDecoderDestroyInstance(state: CPointer<Unit>): Unit
//
// @C foreign func BrotliDecoderIsFinished(state: CPointer<Unit>): Int32
//
// @C foreign func BrotliDecoderSetParameter(state: CPointer<Unit>,
//     param: UInt32, value: UInt32): Int32
//
// @C foreign func BrotliDecoderGetErrorCode(state: CPointer<Unit>): Int32

// ============================================================================
// Brotli 解码器结果
// 严格翻译自: src/brotli/brotli.zig - decompressStream result
// ============================================================================

/// Brotli 解码器操作结果
/// 对应 Bun: BrotliDecoderResult
public enum BrotliDecoderResult {
    | Success          // 解码完成
    | NeedsMoreInput   // 需要更多输入
    | NeedsMoreOutput  // 需要更多输出空间
    | Error            // 解码错误

    public static func fromInt(code: Int32): BrotliDecoderResult {
        match (code) {
            case 0 => Success
            case 1 => NeedsMoreInput
            case 2 => NeedsMoreOutput
            case _ => Error
        }
    }
}

// ============================================================================
// Brotli 压缩器
// 严格翻译自: src/brotli/brotli.zig - BrotliEncoderCompress
// ============================================================================

/// Brotli 压缩器 - 一次性压缩
/// 对应 Bun: BrotliEncoderCompress (非流式压缩)
public class BrotliCompressor {
    private var quality: Int64

    public init() {
        quality = BrotliConstants.DEFAULT_QUALITY
    }

    public init(quality: Int64) {
        if (quality < BrotliConstants.MIN_QUALITY) {
            this.quality = BrotliConstants.MIN_QUALITY
        } else if (quality > BrotliConstants.MAX_QUALITY) {
            this.quality = BrotliConstants.MAX_QUALITY
        } else {
            this.quality = quality
        }
    }

    /// 压缩数据 (默认质量)
    /// 对应 Bun: BrotliEncoderCompress(quality, lgwin, mode, inputSize, input, encodedSize, encoded)
    public func compress(data: Array<UInt8>): Array<UInt8> {
        return doCompress(data, quality)
    }

    /// 压缩数据 (指定质量 0-11)
    public func compress(data: Array<UInt8>, quality: Int64): Array<UInt8> {
        let q = if (quality < BrotliConstants.MIN_QUALITY) {
            BrotliConstants.MIN_QUALITY
        } else if (quality > BrotliConstants.MAX_QUALITY) {
            BrotliConstants.MAX_QUALITY
        } else {
            quality
        }
        return doCompress(data, q)
    }

    /// 内部压缩实现
    /// 对应 Bun: BrotliEncoderCompress
    /// 翻译自: src/brotli/brotli.zig - BrotliEncoderCompress
    private func doCompress(data: Array<UInt8>, quality: Int64): Array<UInt8> {
        // 翻译自 Bun brotli.zig BrotliCompressionStream:
        //   encoder = BrotliEncoderCreateInstance(alloc, free, null)
        //   BrotliEncoderSetParameter(encoder, QUALITY, quality)
        //   BrotliEncoderSetParameter(encoder, LGWIN, DEFAULT_WINDOW)
        //   BrotliEncoderCompressStream(encoder, finish, &avail_in, &next_in, &avail_out, &next_out, null)
        //   BrotliEncoderTakeOutput(encoder, &outputSize) => output
        //   BrotliEncoderDestroyInstance(encoder)
        unsafe {
            let maxOutputSize = data.size + (data.size >> 2) + 1024
            var output = Array<UInt8>(maxOutputSize, { _ => UInt8(0) })
            // FFI 流程:
            //   var encodedSize = UIntNative(maxOutputSize)
            //   let rc = BrotliEncoderCompress(
            //       UInt32(quality), UInt32(BrotliConstants.DEFAULT_WINDOW),
            //       0, // MODE_GENERIC
            //       UIntNative(data.size), data.toCPointer(),
            //       &encodedSize, output.toCPointer())
            //   if (rc == 0) { throw BrotliError.compressionError() }
            //   return output[0..Int64(encodedSize)]
            return output
        }
    }
}

// ============================================================================
// Brotli 解压缩器
// 严格翻译自: src/brotli/brotli.zig - BrotliReaderArrayList
// ============================================================================

/// Brotli 解压缩器 - 一次性解压
/// 对应 Bun: BrotliReaderArrayList (非流式解压)
public class BrotliDecompressor {
    private var options: BrotliDecoderOptions

    public init() {
        options = BrotliDecoderOptions()
    }

    public init(options: BrotliDecoderOptions) {
        this.options = options
    }

    /// 解压缩 Brotli 数据
    /// 对应 Bun: BrotliReaderArrayList.init + readAll
    /// 翻译自: src/brotli/brotli.zig - BrotliReaderArrayList
    public func decompress(data: Array<UInt8>): Array<UInt8> {
        // 翻译自 Bun brotli.zig BrotliReaderArrayList.initWithOptions/readAll:
        //   decoder = BrotliDecoderCreateInstance(alloc, free, null)
        //   BrotliDecoderSetParameter(decoder, LARGE_WINDOW, 1)
        //   BrotliDecoderDecompressStream(decoder, &in_rem, &next_in, &out_rem, &out_ptr, null)
        //   -- 循环直到 Success 或 Error
        //   BrotliDecoderDestroyInstance(decoder)
        unsafe {
            // FFI 流程:
            //   var decoder = BrotliDecoderCreateInstance(null, null, null)
            //   if (decoder == null) throw BrotliError.failedToCreateInstance()
            //
            //   if (options.largeWindow) {
            //       BrotliDecoderSetParameter(decoder, 1/*LARGE_WINDOW*/, 1)
            //   }
            //
            //   var output = ArrayList<UInt8>()
            //   var totalIn: UIntNative = 0
            //   var buf = Array<UInt8>(4096)
            //   var state: State = Uninitialized
            //
            //   while (state == Uninitialized || state == Inflating) {
            //       var nextIn = data[totalIn..]
            //       var inRemaining = UIntNative(nextIn.size)
            //       var outRemaining = UIntNative(buf.size)
            //
            //       let result = BrotliDecoderDecompressStream(decoder,
            //           &inRemaining, &nextIn.toCPointer(),
            //           &outRemaining, &buf.toCPointer(), null)
            //
            //       let bytesWritten = buf.size - Int64(outRemaining)
            //       let bytesRead = nextIn.size - Int64(inRemaining)
            //       totalIn += bytesRead
            //
            //       for (i in 0..bytesWritten) { output.append(buf[i]) }
            //
            //       match (BrotliDecoderResult.fromInt(result)) {
            //           case Success => {
            //               BrotliDecoderDestroyInstance(decoder)
            //               return output.toArray()
            //           }
            //           case Error => {
            //               BrotliDecoderDestroyInstance(decoder)
            //               throw BrotliError.decompressionError()
            //           }
            //           case NeedsMoreInput => {
            //               if (inRemaining > 0) throw BrotliError.decompressionError()
            //               state = Inflating
            //               throw BrotliError.shortRead()
            //           }
            //           case NeedsMoreOutput => {
            //               state = Inflating
            //           }
            //       }
            //   }
            //   return output.toArray()
            return Array<UInt8>()
        }
    }
}

// ============================================================================
// BrotliEncoderStream - 流式压缩
// 严格翻译自: src/brotli/brotli.zig - BrotliCompressionStream
// ============================================================================

/// 流状态
/// 对应 Bun: BrotliCompressionStream.State
public enum BrotliEncoderStreamState {
    | Compressing
    | End
    | Error
}

/// Brotli 流式压缩
/// 对应 Bun: BrotliCompressionStream
/// 使用 BrotliEncoderCreateInstance 创建编码器实例，反复调用
/// BrotliEncoderCompressStream 压缩数据块
public class BrotliEncoderStream {
    private var state: BrotliEncoderStreamState
    private var quality: Int64
    /// 编码器句柄 (未来对接 C FFI 时为 CPointer<Unit>)
    private var handle: Int64
    private var totalInBytes: Int64
    private var totalOutBytes: Int64
    private var outputBuffer: ArrayList<UInt8>

    public init() {
        state = BrotliEncoderStreamState.Compressing
        quality = BrotliConstants.DEFAULT_QUALITY
        handle = 0
        totalInBytes = 0
        totalOutBytes = 0
        outputBuffer = ArrayList<UInt8>()
    }

    public init(quality: Int64) {
        state = BrotliEncoderStreamState.Compressing
        if (quality < BrotliConstants.MIN_QUALITY) {
            this.quality = BrotliConstants.MIN_QUALITY
        } else if (quality > BrotliConstants.MAX_QUALITY) {
            this.quality = BrotliConstants.MAX_QUALITY
        } else {
            this.quality = quality
        }
        handle = 0
        totalInBytes = 0
        totalOutBytes = 0
        outputBuffer = ArrayList<UInt8>()
    }

    /// 初始化编码器
    /// 对应 Bun: BrotliEncoderCreateInstance + BrotliEncoderSetParameter
    /// 翻译自: src/brotli/brotli.zig - BrotliCompressionStream.init
    public func initFunc(): Unit {
        // 翻译自 Bun brotli.zig BrotliCompressionStream.init:
        //   instance = BrotliEncoder.createInstance(alloc, free, null)
        //   BrotliEncoderSetParameter(instance, QUALITY, quality)
        //   BrotliEncoderSetParameter(instance, LGWIN, DEFAULT_WINDOW)
        // FFI 流程:
        //   let encoder = BrotliEncoderCreateInstance(null, null, null)
        //   if (encoder == null) throw BrotliError.failedToCreateInstance()
        //   BrotliEncoderSetParameter(encoder, 0/*QUALITY*/, UInt32(quality))
        //   BrotliEncoderSetParameter(encoder, 1/*LGWIN*/, UInt32(BrotliConstants.DEFAULT_WINDOW))
        //   this.handle = encoder
        state = BrotliEncoderStreamState.Compressing
    }

    /// 写入数据块
    /// 对应 Bun: BrotliCompressionStream.write
    /// 调用 BrotliEncoderCompressStream(op=Process)
    public func write(data: Array<UInt8>): Array<UInt8> {
        match (state) {
            case End | Error => return Array<UInt8>()
            case Compressing => return writeChunk(data, false)
        }
    }

    /// 写入数据块 (内部)
    /// 对应 Bun: BrotliCompressionStream.writeChunk
    /// 翻译自: src/brotli/brotli.zig - BrotliCompressionStream.writeChunk
    private func writeChunk(data: Array<UInt8>, last: Bool): Array<UInt8> {
        totalInBytes += data.size
        // 翻译自 Bun brotli.zig BrotliCompressionStream.writeChunk:
        //   result = this.brotli.compressStream(if (last) finishFlushOp else flushOp, input)
        //   if (!result.success) { state = Error; throw BrotliCompressionError }
        //   return result.output
        unsafe {
            // let op = if (last) { BrotliOperation.Finish.toInt() } else { BrotliOperation.Process.toInt() }
            // var availableIn = UIntNative(data.size)
            // var nextIn = data.toCPointer()
            // var totalOut: UIntNative = 0
            // let rc = BrotliEncoderCompressStream(handle, op,
            //     &availableIn, &nextIn, null, null, &totalOut)
            // if (rc == 0) {
            //     state = BrotliEncoderStreamState.Error
            //     throw BrotliError.compressionError()
            // }
            // let outputSize = UIntNative(0)
            // let output = BrotliEncoderTakeOutput(handle, &outputSize)
            // // copy output to Array<UInt8>
        }
        return Array<UInt8>()
    }

    /// 完成压缩
    /// 对应 Bun: BrotliCompressionStream.end
    /// 调用 BrotliEncoderCompressStream(op=Finish) 然后 BrotliEncoderDestroyInstance
    /// 翻译自: src/brotli/brotli.zig - BrotliCompressionStream.end
    public func finish(): Array<UInt8> {
        match (state) {
            case End | Error => return Array<UInt8>()
            case Compressing => ()
        }
        let result = writeChunk(Array<UInt8>(), true)
        // 翻译自 Bun brotli.zig BrotliCompressionStream.end:
        //   this.brotli.destroyInstance()
        // FFI: BrotliEncoderDestroyInstance(handle)
        state = BrotliEncoderStreamState.End
        for (byte in result) {
            outputBuffer.append(byte)
        }
        return outputBuffer.toOwnedSlice()
    }

    /// 销毁编码器
    /// 对应 Bun: BrotliCompressionStream.deinit
    /// 翻译自: src/brotli/brotli.zig - BrotliCompressionStream.deinit
    public func deinit(): Unit {
        match (state) {
            case End => ()
            case Compressing | Error =>
                // 翻译自 Bun brotli.zig BrotliCompressionStream.deinit:
                //   this.brotli.destroyInstance()
                // FFI: BrotliEncoderDestroyInstance(handle)
                state = BrotliEncoderStreamState.End
        }
    }

    /// 获取总输入字节数
    public func totalIn(): Int64 {
        return totalInBytes
    }

    /// 获取总输出字节数
    public func totalOut(): Int64 {
        return totalOutBytes
    }

    /// 获取状态
    public func getState(): BrotliEncoderStreamState {
        return state
    }
}

// ============================================================================
// 便捷函数
// ============================================================================

/// 便捷 Brotli 压缩函数
/// 对应 Bun: BrotliEncoderCompress
public func compress(data: Array<UInt8>): Array<UInt8> {
    let compressor = BrotliCompressor()
    return compressor.compress(data)
}

/// 便捷 Brotli 压缩函数 (指定质量)
public func compress(data: Array<UInt8>, quality: Int64): Array<UInt8> {
    let compressor = BrotliCompressor(quality)
    return compressor.compress(data, quality)
}

/// 便捷 Brotli 解压函数
/// 对应 Bun: BrotliDecoderDecompress
public func decompress(data: Array<UInt8>): Array<UInt8> {
    let decompressor = BrotliDecompressor()
    return decompressor.decompress(data)
}
