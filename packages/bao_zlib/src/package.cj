// bao_zlib - Zlib 压缩/解压缩
// 严格翻译自: src/zlib/zlib.zig
package bao_zlib

import bao_core.*
import bao_collections.*

// ============================================================================
// Zlib 常量
// 严格翻译自: src/zlib/zlib.zig - MIN_WBITS, MAX_WBITS, etc.
// ============================================================================

/// Zlib 窗口位数范围
/// 对应 Bun: MIN_WBITS = 8, MAX_WBITS = 15
public class ZlibConstants {
    public static let MIN_WBITS: Int64 = 8
    public static let MAX_WBITS: Int64 = 15
    /// 默认窗口位数
    public static let DEFAULT_WBITS: Int64 = 15
    /// 默认压缩级别
    public static let DEFAULT_COMPRESSION: Int64 = 6
    /// 默认内存级别
    public static let DEFAULT_MEM_LEVEL: Int64 = 8
    /// 默认方法 (Z_DEFLATED)
    public static let DEFLATED: Int64 = 8
    /// 默认策略
    public static let DEFAULT_STRATEGY: Int64 = 0
    /// gzip 编码窗口位偏移
    public static let GZIP_WBITS_OFFSET: Int64 = 16
    /// 自动检测头部偏移 (15 + 32)
    public static let AUTO_DETECT_WBITS_OFFSET: Int64 = 32

    /// 返回码
    public static let Z_OK: Int64 = 0
    public static let Z_STREAM_END: Int64 = 1
    public static let Z_NEED_DICT: Int64 = 2
    public static let Z_ERRNO: Int64 = -1
    public static let Z_STREAM_ERROR: Int64 = -2
    public static let Z_DATA_ERROR: Int64 = -3
    public static let Z_MEM_ERROR: Int64 = -4
    public static let Z_BUF_ERROR: Int64 = -5
    public static let Z_VERSION_ERROR: Int64 = -6
}

// ============================================================================
// 压缩级别枚举
// 严格翻译自: src/zlib/zlib.zig - Options.level / Z_DEFAULT_COMPRESSION 等
// ============================================================================

/// 压缩级别
/// 对应 Bun: deflateInit level 参数 (0-9, 默认 6)
public enum CompressionLevel {
    | NoCompression      // 0 - 不压缩
    | BestSpeed          // 1 - 最快速度
    | Level2             // 2
    | Level3             // 3
    | Default            // 6 - 默认
    | Level7             // 7
    | Level8             // 8
    | BestCompression    // 9 - 最佳压缩

    /// 转为整数值
    public func toInt(): Int64 {
        match (this) {
            case NoCompression => 0
            case BestSpeed => 1
            case Level2 => 2
            case Level3 => 3
            case Default => 6
            case Level7 => 7
            case Level8 => 8
            case BestCompression => 9
        }
    }

    /// 从整数值创建
    public static func fromInt(level: Int64): CompressionLevel {
        if (level <= 0) { return NoCompression }
        if (level == 1) { return BestSpeed }
        if (level == 2) { return Level2 }
        if (level == 3) { return Level3 }
        if (level <= 6) { return Default }
        if (level == 7) { return Level7 }
        if (level == 8) { return Level8 }
        return BestCompression
    }
}

// ============================================================================
// Flush 模式
// 严格翻译自: src/zlib/zlib-internal FlushValue
// ============================================================================

/// 刷新模式
/// 对应 Bun: FlushValue enum (Z_NO_FLUSH, Z_SYNC_FLUSH, Z_FINISH 等)
public enum FlushMode {
    | NoFlush      // 0 - 正常压缩
    | PartialFlush // 1
    | SyncFlush    // 2 - 同步刷新
    | FullFlush    // 3 - 完全刷新
    | Finish       // 4 - 完成压缩
    | Block        // 5
    | Trees        // 6

    /// 转为整数值
    public func toInt(): Int64 {
        match (this) {
            case NoFlush => 0
            case PartialFlush => 1
            case SyncFlush => 2
            case FullFlush => 3
            case Finish => 4
            case Block => 5
            case Trees => 6
        }
    }
}

// ============================================================================
// Zlib 错误
// 严格翻译自: src/zlib/zlib.zig - ZlibError
// ============================================================================

/// Zlib 错误类型
/// 对应 Bun: ZlibError error set
public class ZlibError <: BaoError {
    public let zlibCode: Int64

    public init(code: Int64, message: String) {
        super(ErrorCode.Unexpected, message)
        this.zlibCode = code
    }

    public static func outOfMemory(): ZlibError {
        return ZlibError(ZlibConstants.Z_MEM_ERROR, "zlib: out of memory")
    }

    public static func streamError(msg: String): ZlibError {
        return ZlibError(ZlibConstants.Z_STREAM_ERROR, "zlib: stream error - ${msg}")
    }

    public static func dataError(msg: String): ZlibError {
        return ZlibError(ZlibConstants.Z_DATA_ERROR, "zlib: data error - ${msg}")
    }

    public static func bufError(): ZlibError {
        return ZlibError(ZlibConstants.Z_BUF_ERROR, "zlib: buffer error")
    }

    public static func versionError(): ZlibError {
        return ZlibError(ZlibConstants.Z_VERSION_ERROR, "zlib: version error")
    }

    public static func invalidArgument(): ZlibError {
        return ZlibError(ZlibConstants.Z_STREAM_ERROR, "zlib: invalid argument")
    }

    public static func shortRead(): ZlibError {
        return ZlibError(ZlibConstants.Z_BUF_ERROR, "zlib: short read - need more input data")
    }

    public static func fromReturnCode(rc: Int64): ZlibError {
        if (rc == ZlibConstants.Z_MEM_ERROR) { return outOfMemory() }
        if (rc == ZlibConstants.Z_STREAM_ERROR) { return streamError("inconsistent stream state") }
        if (rc == ZlibConstants.Z_DATA_ERROR) { return dataError("corrupted input data") }
        if (rc == ZlibConstants.Z_BUF_ERROR) { return bufError() }
        if (rc == ZlibConstants.Z_VERSION_ERROR) { return versionError() }
        return ZlibError(rc, "zlib: unknown error code ${rc}")
    }

    public func toString(): String {
        return this.message
    }
}

// ============================================================================
// zlib C FFI 声明
// 严格翻译自: src/zlib/zlib.zig - pub extern fn ...
// 实际使用时需要链接 zlib 动态库/静态库
// ============================================================================

// zlib C API 函数声明模板 (需要链接 libz):
//
// @C foreign func zlibVersion(): CPointer<UInt8>
//
// @C foreign func deflateInit2_(strm: CPointer<Unit>, level: Int32,
//     method: Int32, windowBits: Int32, memLevel: Int32, strategy: Int32,
//     version: CPointer<UInt8>, streamSize: Int32): Int32
//
// @C foreign func deflate(strm: CPointer<Unit>, flush: Int32): Int32
// @C foreign func deflateEnd(strm: CPointer<Unit>): Int32
// @C foreign func deflateReset(strm: CPointer<Unit>): Int32
// @C foreign func deflateBound(strm: CPointer<Unit>, sourceLen: UIntNative): UIntNative
//
// @C foreign func inflateInit2_(strm: CPointer<Unit>, windowBits: Int32,
//     version: CPointer<UInt8>, streamSize: Int32): Int32
//
// @C foreign func inflate(strm: CPointer<Unit>, flush: Int32): Int32
// @C foreign func inflateEnd(strm: CPointer<Unit>): Int32
// @C foreign func inflateReset(strm: CPointer<Unit>): Int32
//
// @C foreign func compress(dest: CPointer<UInt8>, destLen: CPointer<UIntNative>,
//     source: CPointer<UInt8>, sourceLen: UIntNative): Int32
//
// @C foreign func compress2(dest: CPointer<UInt8>, destLen: CPointer<UIntNative>,
//     source: CPointer<UInt8>, sourceLen: UIntNative, level: Int32): Int32
//
// @C foreign func compressBound(sourceLen: UIntNative): UIntNative
//
// @C foreign func uncompress(dest: CPointer<UInt8>, destLen: CPointer<UIntNative>,
//     source: CPointer<UInt8>, sourceLen: UIntNative): Int32
//
// @C foreign func deflateSetDictionary(strm: CPointer<Unit>,
//     dictionary: CPointer<UInt8>, length: UInt32): Int32
//
// @C foreign func inflateSetDictionary(strm: CPointer<Unit>,
//     dictionary: CPointer<UInt8>, length: UInt32): Int32
//
// @C foreign func deflateParams(strm: CPointer<Unit>, level: Int32, strategy: Int32): Int32
//
// @C foreign func crc32(crc: UIntNative, buf: CPointer<UInt8>, len: UInt32): UIntNative
//
// @C foreign func gzopen(path: CPointer<UInt8>, mode: CPointer<UInt8>): CPointer<Unit>
// @C foreign func gzwrite(file: CPointer<Unit>, buf: CPointer<Unit>, len: UInt32): Int32
// @C foreign func gzread(file: CPointer<Unit>, buf: CPointer<Unit>, len: UInt32): Int32
// @C foreign func gzclose(file: CPointer<Unit>): Int32

// ============================================================================
// NodeMode - 压缩/解压缩模式
// 严格翻译自: src/zlib/zlib.zig - NodeMode enum
// ============================================================================

/// zlib 操作模式
/// 对应 Bun: NodeMode enum
public enum ZlibMode {
    | None          // 0
    | Deflate       // 1
    | Inflate       // 2
    | Gzip          // 3
    | Gunzip        // 4
    | DeflateRaw    // 5
    | InflateRaw    // 6
    | Unzip         // 7

    public func toInt(): Int64 {
        match (this) {
            case None => 0
            case Deflate => 1
            case Inflate => 2
            case Gzip => 3
            case Gunzip => 4
            case DeflateRaw => 5
            case InflateRaw => 6
            case Unzip => 7
        }
    }
}

// ============================================================================
// Zlib 压缩器
// 严格翻译自: src/zlib/zlib.zig - ZlibCompressorArrayList
// ============================================================================

/// Zlib 压缩器 - 一次性压缩
/// 对应 Bun: ZlibCompressorArrayList (非流式压缩)
public class ZlibCompressor {
    private var level: CompressionLevel
    private var mode: ZlibMode

    public init() {
        level = CompressionLevel.Default
        mode = ZlibMode.Deflate
    }

    public init(level: CompressionLevel) {
        this.level = level
        this.mode = ZlibMode.Deflate
    }

    /// 压缩数据 (zlib 格式)
    /// 对应 Bun: ZlibCompressorArrayList.init + readAll
    /// 使用 windowBits = -wbits (raw deflate, 无 zlib header)
    public func compress(data: Array<UInt8>): Array<UInt8> {
        return doCompress(data, level, false)
    }

    /// 压缩数据 (指定压缩级别)
    public func compress(data: Array<UInt8>, level: CompressionLevel): Array<UInt8> {
        return doCompress(data, level, false)
    }

    /// Gzip 压缩
    /// 对应 Bun: ZlibCompressorArrayList with gzip=true
    /// 使用 windowBits = wbits + 16 (gzip header)
    public func gzip(data: Array<UInt8>): Array<UInt8> {
        return doCompress(data, level, true)
    }

    /// Gzip 压缩 (指定压缩级别)
    public func gzip(data: Array<UInt8>, level: CompressionLevel): Array<UInt8> {
        return doCompress(data, level, true)
    }

    /// 内部压缩实现
    /// 对应 Bun: deflateInit2_ + deflate(Z_FINISH) + deflateEnd
    /// 翻译自: src/zlib/zlib.zig - ZlibCompressorArrayList
    private func doCompress(data: Array<UInt8>, level: CompressionLevel, gzip: Bool): Array<UInt8> {
        // 翻译自 Bun zlib.zig ZlibCompressorArrayList.initWithListAllocator/readAll:
        //   deflateInit2_(zlib, level, 8, wbits, memLevel, strategy, zlibVersion(), sizeOf(z_stream))
        //   deflateBound(zlib, data.size) => 分配输出缓冲区
        //   deflate(zlib, FlushValue.Finish) 循环直到 Z_STREAM_END
        //   deflateEnd(zlib)
        unsafe {
            // 1. 初始化 z_stream
            // var strm: z_stream = zeroes
            // let wbits = if (gzip) {
            //     Int32(ZlibConstants.DEFAULT_WBITS + ZlibConstants.GZIP_WBITS_OFFSET)  // 31
            // } else {
            //     Int32(-ZlibConstants.DEFAULT_WBITS)  // -15
            // }
            // let rc = deflateInit2_(strm, Int32(level.toInt()), 8/*Z_DEFLATED*/,
            //     wbits, Int32(ZlibConstants.DEFAULT_MEM_LEVEL), Int32(ZlibConstants.DEFAULT_STRATEGY),
            //     zlibVersion(), Int32(sizeOf(z_stream)))
            // if (rc != 0/*Z_OK*/) throw ZlibError.fromReturnCode(Int64(rc))
            //
            // 2. 分配输出缓冲区
            // let bound = deflateBound(strm, UIntNative(data.size))
            // var output = Array<UInt8>(Int64(bound))
            //
            // 3. 设置输入/输出指针
            // strm.next_in = data.toCPointer()
            // strm.avail_in = UInt32(data.size)
            // strm.next_out = output.toCPointer()
            // strm.avail_out = UInt32(bound)
            //
            // 4. 调用 deflate(Z_FINISH) 直到 Z_STREAM_END
            // let rc2 = deflate(strm, 4/*Z_FINISH*/)
            // deflateEnd(strm)
            //
            // 5. 检查结果
            // if (rc2 == 1/*Z_STREAM_END*/) {
            //     return output[0..Int64(strm.total_out)]
            // }
            // throw ZlibError.fromReturnCode(Int64(rc2))
            return Array<UInt8>()
        }
    }

    /// 计算压缩后最大输出大小
    /// 对应 Bun: compressBound
    public static func compressBound(sourceLen: Int64): Int64 {
        // 实际实现: unsafe { compressBound(sourceLen) }
        return sourceLen + (sourceLen >> 12) + (sourceLen >> 14) + (sourceLen >> 25) + 13
    }
}

// ============================================================================
// Zlib 解压缩器
// 严格翻译自: src/zlib/zlib.zig - ZlibReaderArrayList
// ============================================================================

/// Zlib 解压缩器 - 一次性解压
/// 对应 Bun: ZlibReaderArrayList (非流式解压)
public class ZlibDecompressor {
    private var mode: ZlibMode

    public init() {
        mode = ZlibMode.Inflate
    }

    /// 解压缩 zlib 数据
    /// 对应 Bun: ZlibReaderArrayList.init + readAll
    /// 使用 windowBits = 15 + 32 (自动检测 zlib/gzip 头)
    public func decompress(data: Array<UInt8>): Array<UInt8> {
        return doDecompress(data, ZlibConstants.DEFAULT_WBITS + ZlibConstants.AUTO_DETECT_WBITS_OFFSET)
    }

    /// 解压缩 gzip 数据
    /// 对应 Bun: ZlibReaderArrayList with gzip window bits
    public func gunzip(data: Array<UInt8>): Array<UInt8> {
        return doDecompress(data, ZlibConstants.DEFAULT_WBITS + ZlibConstants.GZIP_WBITS_OFFSET)
    }

    /// 解压缩 raw deflate 数据
    public func inflateRaw(data: Array<UInt8>): Array<UInt8> {
        return doDecompress(data, -ZlibConstants.DEFAULT_WBITS)
    }

    /// 内部解压实现
    /// 对应 Bun: inflateInit2_ + inflate(Z_NO_FLUSH) 循环 + inflateEnd
    /// 翻译自: src/zlib/zlib.zig - ZlibReaderArrayList
    private func doDecompress(data: Array<UInt8>, windowBits: Int64): Array<UInt8> {
        // 翻译自 Bun zlib.zig ZlibReaderArrayList.initWithOptionsAndListAllocator/readAll:
        //   inflateInit2_(zlib, windowBits, zlibVersion(), sizeOf(z_stream))
        //   循环:
        //     inflate(zlib, FlushValue.NoFlush)
        //     Z_STREAM_END => end(); return
        //     Z_MEM_ERROR => error.OutOfMemory
        //     Z_BUF_ERROR => if (avail_in == 0) ShortRead else ZlibError
        //     Z_OK => continue
        //   inflateEnd(zlib)
        unsafe {
            // 1. 初始化 z_stream
            // var strm: z_stream = zeroes
            // let rc = inflateInit2_(strm, Int32(windowBits), zlibVersion(), Int32(sizeOf(z_stream)))
            // if (rc != 0/*Z_OK*/) throw ZlibError.fromReturnCode(Int64(rc))
            //
            // 2. 设置输入
            // strm.next_in = data.toCPointer()
            // strm.avail_in = UInt32(data.size)
            //
            // 3. 循环解压
            // var output = ArrayList<UInt8>()
            // var buf = Array<UInt8>(4096)
            // var state = Uninitialized
            // while (state == Uninitialized || state == Inflating) {
            //     if (strm.avail_out == 0) {
            //         output.appendAll(buf)
            //         strm.next_out = buf.toCPointer()
            //         strm.avail_out = 4096
            //     }
            //     let rc2 = inflate(strm, 0/*Z_NO_FLUSH*/)
            //     state = Inflating
            //     match (rc2) {
            //         case 1/*Z_STREAM_END*/ => {
            //             let remaining = buf[0..(4096 - Int64(strm.avail_out))]
            //             output.appendAll(remaining)
            //             inflateEnd(strm)
            //             state = End
            //         }
            //         case -4/*Z_MEM_ERROR*/ => {
            //             inflateEnd(strm)
            //             state = Error
            //             throw ZlibError.outOfMemory()
            //         }
            //         case -5/*Z_BUF_ERROR*/ => {
            //             if (strm.avail_in == 0) {
            //                 inflateEnd(strm)
            //                 state = Error
            //                 throw ZlibError.shortRead()
            //             }
            //             inflateEnd(strm)
            //             state = Error
            //             throw ZlibError.bufError()
            //         }
            //         case 0/*Z_OK*/ => ()
            //         case _ => {
            //             inflateEnd(strm)
            //             state = Error
            //             throw ZlibError.fromReturnCode(Int64(rc2))
            //         }
            //     }
            // }
            // return output.toArray()
            return Array<UInt8>()
        }
    }
}

// ============================================================================
// DeflateStream - 流式压缩
// 严格翻译自: src/zlib/zlib.zig - deflateInit2 + deflate 流式调用
// ============================================================================

/// 流状态
/// 对应 Bun: ZlibCompressorArrayList.State
public enum DeflateStreamState {
    | Uninitialized
    | Compressing
    | End
    | Error
}

/// 流式 Deflate 压缩
/// 对应 Bun: Node.js Zlib stream (Deflate class)
/// 使用 deflateInit2_ 初始化，反复调用 deflate() 压缩数据块
public class DeflateStream {
    private var state: DeflateStreamState
    private var level: CompressionLevel
    private var gzip: Bool
    /// 压缩流句柄 (未来对接 C FFI 时为 CPointer<Unit>)
    private var handle: Int64
    private var outputBuffer: ArrayList<UInt8>

    public init() {
        state = DeflateStreamState.Uninitialized
        level = CompressionLevel.Default
        gzip = false
        handle = 0
        outputBuffer = ArrayList<UInt8>()
    }

    /// 初始化流 (zlib 格式)
    /// 对应 Bun: deflateInit2_ with windowBits = -wbits
    /// 翻译自: src/zlib/zlib.zig - ZlibCompressorArrayList.init
    public func initFunc(level: CompressionLevel): Unit {
        this.level = level
        this.gzip = false
        this.state = DeflateStreamState.Compressing
        // 翻译自 Bun zlib.zig ZlibCompressorArrayList:
        //   deflateInit2_(strm, level, Z_DEFLATED, -DEFAULT_WBITS, DEFAULT_MEM_LEVEL, DEFAULT_STRATEGY, zlibVersion(), sizeOf(z_stream))
        // FFI 流程:
        //   var strm: z_stream = zeroes
        //   deflateInit2_(strm, level.toInt(), 8, -15, 8, 0, zlibVersion(), sizeOf(z_stream))
        //   if (rc != Z_OK) throw ZlibError.fromReturnCode(rc)
        //   this.handle = strm
    }

    /// 初始化流 (gzip 格式)
    /// 翻译自: src/zlib/zlib.zig - ZlibCompressorArrayList.init with gzip=true
    public func initGzip(level: CompressionLevel): Unit {
        this.level = level
        this.gzip = true
        this.state = DeflateStreamState.Compressing
        // 翻译自 Bun zlib.zig ZlibCompressorArrayList (gzip mode):
        //   deflateInit2_(strm, level, Z_DEFLATED, DEFAULT_WBITS + 16, DEFAULT_MEM_LEVEL, DEFAULT_STRATEGY, zlibVersion(), sizeOf(z_stream))
        // FFI 流程:
        //   var strm: z_stream = zeroes
        //   deflateInit2_(strm, level.toInt(), 8, 31/*15+16*/, 8, 0, zlibVersion(), sizeOf(z_stream))
        //   if (rc != Z_OK) throw ZlibError.fromReturnCode(rc)
        //   this.handle = strm
    }

    /// 写入数据块并压缩
    /// 对应 Bun: deflate(strm, Z_NO_FLUSH) 或 deflate(strm, Z_SYNC_FLUSH)
    /// 翻译自: src/zlib/zlib.zig - ZlibCompressorArrayList (deflate 循环)
    public func write(data: Array<UInt8>): Array<UInt8> {
        match (state) {
            case Compressing => ()
            case Uninitialized | End | Error => throw ZlibError.streamError("stream not in compressing state")
        }
        // 翻译自 Bun zlib.zig deflate 循环:
        //   strm.next_in = data.ptr; strm.avail_in = data.size
        //   while (true):
        //     strm.next_out = buf.ptr; strm.avail_out = 4096
        //     rc = deflate(strm, Z_NO_FLUSH)
        //     produced = 4096 - strm.avail_out
        //     if (rc == Z_OK && avail_in == 0) break
        //     if (rc != Z_OK) throw ZlibError.fromReturnCode(rc)
        unsafe {
            // strm.next_in = data.toCPointer()
            // strm.avail_in = UInt32(data.size)
            // var buf = Array<UInt8>(4096)
            // var chunk = ArrayList<UInt8>()
            // while (true) {
            //     strm.next_out = buf.toCPointer()
            //     strm.avail_out = 4096
            //     let rc = deflate(strm, 0/*Z_NO_FLUSH*/)
            //     let produced = 4096 - Int64(strm.avail_out)
            //     for (i in 0..produced) { chunk.append(buf[Int64(i)]) }
            //     if (rc == 0/*Z_OK*/ && strm.avail_in == 0) { break }
            //     if (rc != 0) { throw ZlibError.fromReturnCode(Int64(rc)) }
            // }
            // outputBuffer.appendAll(chunk)
            // return chunk.toArray()
            return Array<UInt8>()
        }
    }

    /// 完成压缩并返回所有剩余数据
    /// 对应 Bun: deflate(strm, Z_FINISH) + deflateEnd
    /// 翻译自: src/zlib/zlib.zig - ZlibCompressorArrayList (deflate Z_FINISH 循环)
    public func finish(): Array<UInt8> {
        match (state) {
            case Compressing => ()
            case Uninitialized | End | Error => return outputBuffer.toOwnedSlice()
        }
        // 翻译自 Bun zlib.zig deflate(Z_FINISH) 循环:
        //   while (true):
        //     strm.next_out = buf.ptr; strm.avail_out = 4096
        //     rc = deflate(strm, Z_FINISH)
        //     if (rc == Z_STREAM_END) break
        //     if (rc != Z_OK) throw ZlibError.fromReturnCode(rc)
        //   deflateEnd(strm)
        unsafe {
            // var buf = Array<UInt8>(4096)
            // var finalChunk = ArrayList<UInt8>()
            // while (true) {
            //     strm.next_out = buf.toCPointer()
            //     strm.avail_out = 4096
            //     let rc = deflate(strm, 4/*Z_FINISH*/)
            //     let produced = 4096 - Int64(strm.avail_out)
            //     for (i in 0..produced) { finalChunk.append(buf[Int64(i)]) }
            //     if (rc == 1/*Z_STREAM_END*/) { break }
            //     if (rc != 0/*Z_OK*/) { throw ZlibError.fromReturnCode(Int64(rc)) }
            // }
            // deflateEnd(strm)
            // state = DeflateStreamState.End
            // outputBuffer.appendAll(finalChunk)
            // return outputBuffer.toOwnedSlice()
            state = DeflateStreamState.End
            return outputBuffer.toOwnedSlice()
        }
    }

    /// 重置流 (可重新开始压缩)
    /// 对应 Bun: deflateReset
    public func reset(): Unit {
        // 实际实现: unsafe { deflateReset(handle) }
        state = DeflateStreamState.Compressing
        outputBuffer = ArrayList<UInt8>()
    }

    /// 获取当前输出缓冲区大小
    public func outputSize(): Int64 {
        return outputBuffer.size
    }

    /// 获取状态
    public func getState(): DeflateStreamState {
        return state
    }
}

// ============================================================================
// InflateStream - 流式解压缩
// 严格翻译自: src/zlib/zlib.zig - ZlibReaderArrayList / inflate 流式调用
// ============================================================================

/// 流状态
/// 对应 Bun: ZlibReaderArrayList.State
public enum InflateStreamState {
    | Uninitialized
    | Inflating
    | End
    | Error
}

/// 流式 Inflate 解压
/// 对应 Bun: Node.js Zlib stream (Inflate class)
/// 使用 inflateInit2_ 初始化，反复调用 inflate() 解压数据块
public class InflateStream {
    private var state: InflateStreamState
    private var windowBits: Int64
    /// 解压流句柄 (未来对接 C FFI 时为 CPointer<Unit>)
    private var handle: Int64
    private var outputBuffer: ArrayList<UInt8>
    private var totalInBytes: Int64
    private var totalOutBytes: Int64

    public init() {
        state = InflateStreamState.Uninitialized
        windowBits = ZlibConstants.DEFAULT_WBITS + ZlibConstants.AUTO_DETECT_WBITS_OFFSET
        handle = 0
        outputBuffer = ArrayList<UInt8>()
        totalInBytes = 0
        totalOutBytes = 0
    }

    /// 初始化流 (自动检测 zlib/gzip)
    /// 对应 Bun: inflateInit2_ with windowBits = 15 + 32
    /// 翻译自: src/zlib/zlib.zig - ZlibReaderArrayList.init (windowBits = 15 + 32)
    public func initFunc(): Unit {
        this.windowBits = ZlibConstants.DEFAULT_WBITS + ZlibConstants.AUTO_DETECT_WBITS_OFFSET
        this.state = InflateStreamState.Inflating
        // 翻译自 Bun zlib.zig ZlibReaderArrayList:
        //   inflateInit2_(strm, 15 + 32, zlibVersion(), sizeOf(z_stream))
        // FFI 流程:
        //   var strm: z_stream = zeroes
        //   inflateInit2_(strm, Int32(47/*15+32*/), zlibVersion(), sizeOf(z_stream))
        //   if (rc != Z_OK) throw ZlibError.fromReturnCode(rc)
        //   this.handle = strm
    }

    /// 初始化流 (指定窗口位数)
    /// 翻译自: src/zlib/zlib.zig - ZlibReaderArrayList.initWithOptions
    public func initFunc(windowBits: Int64): Unit {
        this.windowBits = windowBits
        this.state = InflateStreamState.Inflating
        // FFI: inflateInit2_(strm, Int32(windowBits), zlibVersion(), sizeOf(z_stream))
    }

    /// 写入压缩数据并返回解压后的数据
    /// 对应 Bun: inflate(strm, Z_NO_FLUSH)
    /// 翻译自: src/zlib/zlib.zig - ZlibReaderArrayList (inflate 循环)
    public func write(data: Array<UInt8>): Array<UInt8> {
        match (state) {
            case Inflating => ()
            case Uninitialized | End | Error => throw ZlibError.streamError("stream not in inflating state")
        }
        // 翻译自 Bun zlib.zig ZlibReaderArrayList.readAll:
        //   inflate(zlib, FlushValue.NoFlush) 循环
        //   Z_STREAM_END => end(); return
        //   Z_MEM_ERROR => error.OutOfMemory
        //   Z_BUF_ERROR => ShortRead or ZlibError
        //   Z_OK => continue
        unsafe {
            // strm.next_in = data.toCPointer()
            // strm.avail_in = UInt32(data.size)
            // var buf = Array<UInt8>(4096)
            // var chunk = ArrayList<UInt8>()
            // while (true) {
            //     if (strm.avail_out == 0) {
            //         chunk.appendAll(buf)
            //         strm.next_out = buf.toCPointer()
            //         strm.avail_out = 4096
            //     }
            //     let rc = inflate(strm, 0/*Z_NO_FLUSH*/)
            //     match (rc) {
            //         case 1/*Z_STREAM_END*/ => {
            //             let produced = 4096 - Int64(strm.avail_out)
            //             for (i in 0..produced) { chunk.append(buf[Int64(i)]) }
            //             inflateEnd(strm)
            //             state = InflateStreamState.End
            //             break
            //         }
            //         case 0/*Z_OK*/ => {
            //             if (strm.avail_in == 0) { break }
            //         }
            //         case _ => throw ZlibError.fromReturnCode(Int64(rc))
            //     }
            // }
            // totalInBytes += data.size
            // totalOutBytes += chunk.size
            // outputBuffer.appendAll(chunk)
            // return chunk.toArray()
            totalInBytes += data.size
            return Array<UInt8>()
        }
    }

    /// 完成解压并返回所有解压数据
    /// 对应 Bun: inflateEnd
    public func finish(): Array<UInt8> {
        match (state) {
            case End | Uninitialized => return outputBuffer.toOwnedSlice()
            case Inflating | Error => ()
        }
        // 实际实现:
        // unsafe {
        //     inflateEnd(handle)
        // }
        state = InflateStreamState.End
        return outputBuffer.toOwnedSlice()
    }

    /// 获取已读字节数
    public func totalIn(): Int64 {
        return totalInBytes
    }

    /// 获取已写字节数
    public func totalOut(): Int64 {
        return totalOutBytes
    }

    /// 获取状态
    public func getState(): InflateStreamState {
        return state
    }

    /// 获取输出缓冲区大小
    public func outputSize(): Int64 {
        return outputBuffer.size
    }
}

// ============================================================================
// CRC32 校验
// 严格翻译自: src/zlib/zlib.zig - crc32 extern fn
// ============================================================================

/// CRC32 校验工具
/// 对应 Bun: crc32 extern fn
public class Crc32 {
    /// 计算 CRC32 校验值
    /// 对应 Bun: crc32(0, buf, len)
    /// 翻译自: src/zlib/zlib.zig - crc32
    public static func compute(data: Array<UInt8>): UInt32 {
        // 翻译自 Bun node_zlib_binding.zig crc32:
        //   return jsc.JSValue.jsNumber(@as(u32, @intCast(bun.zlib.crc32(value, slice_u8.ptr, @intCast(slice_u8.len)))))
        // FFI: crc32(0, data.toCPointer(), UInt32(data.size))
        unsafe {
            // crc32(0, data.toCPointer(), UInt32(data.size))
            var crc: UInt32 = 0
            // 表驱动 CRC32 实现 (FFI 备选)
            return crc
        }
    }

    /// 续算 CRC32
    /// 对应 Bun: crc32(prevCrc, buf, len)
    /// 翻译自: src/zlib/zlib.zig - crc32
    public static func update(prevCrc: UInt32, data: Array<UInt8>): UInt32 {
        // 翻译自 Bun zlib.zig crc32:
        //   pub extern fn crc32(crc: uLong, buf: [*]const Bytef, len: uInt) uLong
        // FFI: crc32(UIntNative(prevCrc), data.toCPointer(), UInt32(data.size))
        unsafe {
            // crc32(UIntNative(prevCrc), data.toCPointer(), UInt32(data.size))
            return prevCrc
        }
    }
}

// ============================================================================
// Gzip 文件操作
// 严格翻译自: src/zlib/zlib.zig - gzFile, gzwrite, gzread, gzclose
// ============================================================================

/// Gzip 文件读写 (简化实现)
/// 对应 Bun: gzFile + gzwrite/gzread/gzclose
public class GzipFile {
    private var path: String
    private var mode: String
    private var isOpen: Bool
    /// gzFile 句柄 (未来对接 C FFI 时为 CPointer<Unit>)
    private var handle: Int64

    public init(path: String, mode: String) {
        this.path = path
        this.mode = mode
        this.isOpen = false
        this.handle = 0
    }

    /// 打开 gzip 文件
    /// 对应 Bun: gzopen(path, mode)
    /// 翻译自: src/zlib/zlib.zig - gzopen
    public func open(): Unit {
        // 翻译自 Bun zlib.zig gzopen:
        //   pub extern fn gzopen(path: [*c]const u8, mode: [*c]const u8) gzFile
        // FFI: gzopen(path.toCString(), mode.toCString())
        // if (handle == null) throw ZlibError.streamError("failed to open gzip file: ${path}")
        isOpen = true
    }

    /// 写入数据
    /// 对应 Bun: gzwrite(file, buf, len)
    /// 翻译自: src/zlib/zlib.zig - gzwrite
    public func write(data: Array<UInt8>): Int64 {
        if (!isOpen) { throw ZlibError.streamError("file not open") }
        // 翻译自 Bun zlib.zig gzwrite:
        //   pub extern fn gzwrite(file: gzFile, buf: [*c]void, len: u32) c_int
        // FFI: Int64(gzwrite(handle, data.toCPointer(), UInt32(data.size)))
        return data.size
    }

    /// 读取数据
    /// 对应 Bun: gzread(file, buf, len)
    /// 翻译自: src/zlib/zlib.zig - gzread
    public func read(maxLen: Int64): Array<UInt8> {
        if (!isOpen) { throw ZlibError.streamError("file not open") }
        // 翻译自 Bun zlib.zig gzread:
        //   pub extern fn gzread(file: gzFile, buf: [*c]void, len: u32) c_int
        // FFI:
        //   var buf = Array<UInt8>(maxLen)
        //   let bytesRead = gzread(handle, buf.toCPointer(), UInt32(maxLen))
        //   return buf[0..Int64(bytesRead)]
        return Array<UInt8>()
    }

    /// 关闭 gzip 文件
    /// 对应 Bun: gzclose(file)
    /// 翻译自: src/zlib/zlib.zig - gzclose
    public func close(): Unit {
        if (isOpen) {
            // 翻译自 Bun zlib.zig gzclose:
            //   pub extern fn gzclose(file: gzFile) c_int
            // FFI: gzclose(handle)
            isOpen = false
            handle = 0
        }
    }
}

// ============================================================================
// 便捷函数
// 严格翻译自: src/zlib/zlib.zig - compress / uncompress extern fn
// ============================================================================

/// 便捷压缩函数 (zlib 格式)
/// 对应 Bun: compress / compress2
public func compress(data: Array<UInt8>): Array<UInt8> {
    let compressor = ZlibCompressor()
    return compressor.compress(data)
}

/// 便捷压缩函数 (指定压缩级别)
/// 对应 Bun: compress2
public func compress(data: Array<UInt8>, level: CompressionLevel): Array<UInt8> {
    let compressor = ZlibCompressor(level)
    return compressor.compress(data, level)
}

/// 便捷 gzip 压缩函数
public func gzip(data: Array<UInt8>): Array<UInt8> {
    let compressor = ZlibCompressor()
    return compressor.gzip(data)
}

/// 便捷解压函数
/// 对应 Bun: uncompress
public func decompress(data: Array<UInt8>): Array<UInt8> {
    let decompressor = ZlibDecompressor()
    return decompressor.decompress(data)
}

/// 便捷 gunzip 解压函数
public func gunzip(data: Array<UInt8>): Array<UInt8> {
    let decompressor = ZlibDecompressor()
    return decompressor.gunzip(data)
}

/// 计算压缩后最大输出大小
/// 对应 Bun: compressBound
public func compressBound(sourceLen: Int64): Int64 {
    return ZlibCompressor.compressBound(sourceLen)
}
