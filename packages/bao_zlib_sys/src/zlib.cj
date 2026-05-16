// 严格翻译自: src/zlib_sys/posix.zig + win32.zig
package bao_zlib_sys

// ============================================================================
// zlib 类型别名
// 严格翻译自: posix.zig / win32.zig 类型定义
// ============================================================================

// ============================================================================
// 内部状态 (opaque)
// 严格翻译自: struct_internal_state
// ============================================================================
@C
public struct ZInternalState {
    public var dummy: Int32 = 0
}

// ============================================================================
// z_stream - zlib 流结构体
// 严格翻译自: z_stream_s / zStream_struct
// 对应 C: struct z_stream_s
// ============================================================================
@C
public struct ZStream {
    /// next input byte
    public var next_in: CPointer<UInt8> = CPointer<UInt8>()
    /// number of bytes available at next_in
    public var avail_in: UInt32 = 0
    /// total number of input bytes read so far
    public var total_in: UIntNative = 0

    /// next output byte will go here
    public var next_out: CPointer<UInt8> = CPointer<UInt8>()
    /// remaining free space at next_out
    public var avail_out: UInt32 = 0
    /// total number of bytes output so far
    public var total_out: UIntNative = 0

    /// last error message, NULL if no error
    public var msg: CString = CString(CPointer<UInt8>())
    /// not visible by applications
    public var state: CPointer<ZInternalState> = CPointer<ZInternalState>()

    /// used to allocate the internal state
    public var zalloc: CFunc<(CPointer<Unit>, UInt32, UInt32) -> CPointer<Unit>> = CFunc<(CPointer<Unit>, UInt32, UInt32) -> CPointer<Unit>>(CPointer<UInt8>())
    /// used to free the internal state
    public var zfree: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Unit> = CFunc<(CPointer<Unit>, CPointer<Unit>) -> Unit>(CPointer<UInt8>())
    /// private data object passed to zalloc and zfree
    public var opaque: CPointer<Unit> = CPointer<Unit>()

    /// best guess about the data type: binary or text
    public var data_type: Int32 = 0

    /// Adler-32 or CRC-32 value of the uncompressed data
    public var adler: UIntNative = 0
    /// reserved for future use
    public var reserved: UIntNative = 0
}

// ============================================================================
// gz_header - gzip 头结构体
// 严格翻译自: gz_header_s
// 对应 C: struct gz_header_s
// ============================================================================
@C
public struct GzHeader {
    public var text: Int32 = 0
    public var time: UIntNative = 0
    public var xflags: Int32 = 0
    public var os: Int32 = 0
    public var extra: CPointer<UInt8> = CPointer<UInt8>()
    public var extra_len: UInt32 = 0
    public var extra_max: UInt32 = 0
    public var name: CPointer<UInt8> = CPointer<UInt8>()
    public var name_max: UInt32 = 0
    public var comment: CPointer<UInt8> = CPointer<UInt8>()
    public var comm_max: UInt32 = 0
    public var hcrc: Int32 = 0
    public var done: Int32 = 0
}

// ============================================================================
// gzFile_s - gz 文件结构体
// 严格翻译自: struct_gzFile_s
// 对应 C: struct gzFile_s
// ============================================================================
@C
public struct GzFileS {
    public var have: UInt32 = 0
    public var next: CPointer<UInt8> = CPointer<UInt8>()
    public var pos: Int64 = 0
}

// ============================================================================
// zlib 常量 - 刷新值
// 严格翻译自: win32.zig Z_NO_FLUSH 等
// ============================================================================
public let Z_NO_FLUSH: Int32 = 0
public let Z_PARTIAL_FLUSH: Int32 = 1
public let Z_SYNC_FLUSH: Int32 = 2
public let Z_FULL_FLUSH: Int32 = 3
public let Z_FINISH: Int32 = 4
public let Z_BLOCK: Int32 = 5
public let Z_TREES: Int32 = 6

// ============================================================================
// zlib 常量 - 返回码
// 严格翻译自: win32.zig Z_OK 等
// ============================================================================
public let Z_OK: Int32 = 0
public let Z_STREAM_END: Int32 = 1
public let Z_NEED_DICT: Int32 = 2
public let Z_ERRNO: Int32 = -1
public let Z_STREAM_ERROR: Int32 = -2
public let Z_DATA_ERROR: Int32 = -3
public let Z_MEM_ERROR: Int32 = -4
public let Z_BUF_ERROR: Int32 = -5
public let Z_VERSION_ERROR: Int32 = -6

// ============================================================================
// zlib 常量 - 压缩级别
// 严格翻译自: win32.zig Z_NO_COMPRESSION 等
// ============================================================================
public let Z_NO_COMPRESSION: Int32 = 0
public let Z_BEST_SPEED: Int32 = 1
public let Z_BEST_COMPRESSION: Int32 = 9
public let Z_DEFAULT_COMPRESSION: Int32 = -1

// ============================================================================
// zlib 常量 - 压缩策略
// 严格翻译自: win32.zig Z_FILTERED 等
// ============================================================================
public let Z_FILTERED: Int32 = 1
public let Z_HUFFMAN_ONLY: Int32 = 2
public let Z_RLE: Int32 = 3
public let Z_FIXED: Int32 = 4
public let Z_DEFAULT_STRATEGY: Int32 = 0

// ============================================================================
// zlib 常量 - 数据类型
// 严格翻译自: win32.zig Z_BINARY 等
// ============================================================================
public let Z_BINARY: Int32 = 0
public let Z_TEXT: Int32 = 1
public let Z_ASCII: Int32 = Z_TEXT
public let Z_UNKNOWN: Int32 = 2

// ============================================================================
// zlib 常量 - 其他
// 严格翻译自: win32.zig Z_DEFLATED 等
// ============================================================================
public let Z_DEFLATED: Int32 = 8
public let Z_NULL: Int32 = 0

// ============================================================================
// zlib FFI 函数声明
// 严格翻译自: posix.zig / win32.zig 中所有 pub extern fn
// ============================================================================

// --- 版本信息 ---
foreign func zlibVersion(): CString

// --- 核心压缩/解压 ---
foreign func deflate(strm: CPointer<ZStream>, flush: Int32): Int32
foreign func deflateEnd(strm: CPointer<ZStream>): Int32
foreign func inflate(strm: CPointer<ZStream>, flush: Int32): Int32
foreign func inflateEnd(strm: CPointer<ZStream>): Int32

// --- 字典操作 ---
foreign func deflateSetDictionary(strm: CPointer<ZStream>, dictionary: CPointer<UInt8>, dictLength: UInt32): Int32
foreign func deflateGetDictionary(strm: CPointer<ZStream>, dictionary: CPointer<UInt8>, dictLength: CPointer<UInt32>): Int32
foreign func deflateCopy(dest: CPointer<ZStream>, source: CPointer<ZStream>): Int32
foreign func deflateReset(strm: CPointer<ZStream>): Int32
foreign func deflateParams(strm: CPointer<ZStream>, level: Int32, strategy: Int32): Int32
foreign func deflateTune(strm: CPointer<ZStream>, good_length: Int32, max_lazy: Int32, nice_length: Int32, max_chain: Int32): Int32
foreign func deflateBound(strm: CPointer<ZStream>, sourceLen: UIntNative): UIntNative
foreign func deflatePending(strm: CPointer<ZStream>, pending: CPointer<UInt32>, bits: CPointer<Int32>): Int32
foreign func deflatePrime(strm: CPointer<ZStream>, bits: Int32, value: Int32): Int32
foreign func deflateSetHeader(strm: CPointer<ZStream>, head: CPointer<GzHeader>): Int32
foreign func inflateSetDictionary(strm: CPointer<ZStream>, dictionary: CPointer<UInt8>, dictLength: UInt32): Int32
foreign func inflateGetDictionary(strm: CPointer<ZStream>, dictionary: CPointer<UInt8>, dictLength: CPointer<UInt32>): Int32
foreign func inflateSync(strm: CPointer<ZStream>): Int32
foreign func inflateCopy(dest: CPointer<ZStream>, source: CPointer<ZStream>): Int32
foreign func inflateReset(strm: CPointer<ZStream>): Int32
foreign func inflateReset2(strm: CPointer<ZStream>, windowBits: Int32): Int32
foreign func inflatePrime(strm: CPointer<ZStream>, bits: Int32, value: Int32): Int32
foreign func inflateMark(strm: CPointer<ZStream>): Int64
foreign func inflateGetHeader(strm: CPointer<ZStream>, head: CPointer<GzHeader>): Int32
foreign func inflateBackEnd(strm: CPointer<ZStream>): Int32
foreign func zlibCompileFlags(): UIntNative

// --- 高层压缩/解压 ---
foreign func compress(dest: CPointer<UInt8>, destLen: CPointer<UIntNative>, source: CPointer<UInt8>, sourceLen: UIntNative): Int32
foreign func compress2(dest: CPointer<UInt8>, destLen: CPointer<UIntNative>, source: CPointer<UInt8>, sourceLen: UIntNative, level: Int32): Int32
foreign func compressBound(sourceLen: UIntNative): UIntNative
foreign func uncompress(dest: CPointer<UInt8>, destLen: CPointer<UIntNative>, source: CPointer<UInt8>, sourceLen: UIntNative): Int32
foreign func uncompress2(dest: CPointer<UInt8>, destLen: CPointer<UIntNative>, source: CPointer<UInt8>, sourceLen: CPointer<UIntNative>): Int32

// --- gzip 文件操作 ---
foreign func gzdopen(fd: Int32, mode: CString): CPointer<GzFileS>
foreign func gzbuffer(file: CPointer<GzFileS>, size: UInt32): Int32
foreign func gzsetparams(file: CPointer<GzFileS>, level: Int32, strategy: Int32): Int32
foreign func gzread(file: CPointer<GzFileS>, buf: CPointer<Unit>, len: UInt32): Int32
foreign func gzfread(buf: CPointer<Unit>, size: UIntNative, nitems: UIntNative, file: CPointer<GzFileS>): UIntNative
foreign func gzwrite(file: CPointer<GzFileS>, buf: CPointer<Unit>, len: UInt32): Int32
foreign func gzfwrite(buf: CPointer<Unit>, size: UIntNative, nitems: UIntNative, file: CPointer<GzFileS>): UIntNative
foreign func gzprintf(file: CPointer<GzFileS>, format: CString, ...): Int32
foreign func gzputs(file: CPointer<GzFileS>, s: CString): Int32
foreign func gzgets(file: CPointer<GzFileS>, buf: CPointer<UInt8>, len: Int32): CPointer<UInt8>
foreign func gzputc(file: CPointer<GzFileS>, c: Int32): Int32
foreign func gzgetc(file: CPointer<GzFileS>): Int32
foreign func gzungetc(c: Int32, file: CPointer<GzFileS>): Int32
foreign func gzflush(file: CPointer<GzFileS>, flush: Int32): Int32
foreign func gzrewind(file: CPointer<GzFileS>): Int32
foreign func gzeof(file: CPointer<GzFileS>): Int32
foreign func gzdirect(file: CPointer<GzFileS>): Int32
foreign func gzclose(file: CPointer<GzFileS>): Int32
foreign func gzclose_r(file: CPointer<GzFileS>): Int32
foreign func gzclose_w(file: CPointer<GzFileS>): Int32
foreign func gzerror(file: CPointer<GzFileS>, errnum: CPointer<Int32>): CString
foreign func gzclearerr(file: CPointer<GzFileS>): Unit

// --- 校验和 ---
foreign func adler32(adler: UIntNative, buf: CPointer<UInt8>, len: UInt32): UIntNative
foreign func adler32_z(adler: UIntNative, buf: CPointer<UInt8>, len: UIntNative): UIntNative
foreign func crc32(crc: UIntNative, buf: CPointer<UInt8>, len: UInt32): UIntNative
foreign func crc32_z(crc: UIntNative, buf: CPointer<UInt8>, len: UIntNative): UIntNative
foreign func crc32_combine_op(crc1: UIntNative, crc2: UIntNative, op: UIntNative): UIntNative
foreign func adler32_combine(adler1: UIntNative, adler2: UIntNative, len2: Int64): UIntNative
foreign func crc32_combine(crc1: UIntNative, crc2: UIntNative, len2: Int64): UIntNative
foreign func crc32_combine_gen(len2: Int64): UIntNative

// --- 初始化函数 (内部使用) ---
foreign func deflateInit_(strm: CPointer<ZStream>, level: Int32, version: CString, stream_size: Int32): Int32
foreign func inflateInit_(strm: CPointer<ZStream>, version: CString, stream_size: Int32): Int32
foreign func deflateInit2_(strm: CPointer<ZStream>, level: Int32, method: Int32, windowBits: Int32, memLevel: Int32, strategy: Int32, version: CString, stream_size: Int32): Int32
foreign func inflateInit2_(strm: CPointer<ZStream>, windowBits: Int32, version: CString, stream_size: Int32): Int32
foreign func inflateBackInit_(strm: CPointer<ZStream>, windowBits: Int32, window: CPointer<UInt8>, version: CString, stream_size: Int32): Int32

// --- gzip 文件打开/定位 ---
foreign func gzopen(path: CString, mode: CString): CPointer<GzFileS>
foreign func gzseek(file: CPointer<GzFileS>, offset: Int64, whence: Int32): Int64
foreign func gztell(file: CPointer<GzFileS>): Int64
foreign func gzoffset(file: CPointer<GzFileS>): Int64
foreign func gzgetc_(file: CPointer<GzFileS>): Int32

// --- 错误信息 ---
foreign func zError(code: Int32): CString

// --- inflate 高级功能 ---
foreign func inflateSyncPoint(strm: CPointer<ZStream>): Int32
foreign func inflateUndermine(strm: CPointer<ZStream>, arg: Int32): Int32
foreign func inflateValidate(strm: CPointer<ZStream>, arg: Int32): Int32
foreign func inflateCodesUsed(strm: CPointer<ZStream>): UIntNative
foreign func inflateResetKeep(strm: CPointer<ZStream>): Int32
foreign func deflateResetKeep(strm: CPointer<ZStream>): Int32
