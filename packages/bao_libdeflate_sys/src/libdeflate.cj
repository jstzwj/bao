// 严格翻译自: src/libdeflate_sys/libdeflate.zig

package bao_libdeflate_sys

// ============================================================================
// Opaque types
// ============================================================================

@C
public struct Compressor {}
@C
public struct Decompressor {}

// ============================================================================
// Options struct - must be @C struct for FFI
// ============================================================================

@C
public struct Options {
    public var sizeof_options: UInt64 = 0
    public var malloc_func: CFunc<(UInt64) -> CPointer<Unit>> = CFunc<(UInt64) -> CPointer<Unit>>(CPointer<UInt8>())
    public var free_func: CFunc<(CPointer<Unit>) -> Unit> = CFunc<(CPointer<Unit>) -> Unit>(CPointer<UInt8>())
}

// ============================================================================
// Result struct
// ============================================================================

public class Result {
    public var read: UInt64 = 0
    public var written: UInt64 = 0
    public var status: Status = Status.success

    public init() {}
    public init(read: UInt64, written: UInt64, status: Status) {
        this.read = read
        this.written = written
        this.status = status
    }
}

// ============================================================================
// Status constants (enum cannot be used as FFI return type)
// ============================================================================

public let LIBDEFLATE_SUCCESS: UInt32 = 0
public let LIBDEFLATE_BAD_DATA: UInt32 = 1
public let LIBDEFLATE_SHORT_OUTPUT: UInt32 = 2
public let LIBDEFLATE_INSUFFICIENT_SPACE: UInt32 = 3

public enum Status {
    | success
    | bad_data
    | short_output
    | insufficient_space
}

// ============================================================================
// Encoding constants (enum values cannot use reserved words directly)
// ============================================================================

public let ENCODING_DEFLATE: Int32 = 0
public let ENCODING_ZLIB: Int32 = 1
public let ENCODING_GZIP: Int32 = 2

public enum Encoding {
    | deflate
    | `zlib`
    | `gzip`
}

// ============================================================================
// Compressor FFI extern functions
// ============================================================================

foreign func libdeflate_alloc_compressor(compression_level: Int32): CPointer<Compressor>

foreign func libdeflate_alloc_compressor_ex(compression_level: Int32, options: CPointer<Options>): CPointer<Compressor>

foreign func libdeflate_deflate_compress(compressor: CPointer<Compressor>, input: CPointer<Unit>, in_nbytes: UInt64, output: CPointer<Unit>, out_nbytes_avail: UInt64): UInt64

foreign func libdeflate_deflate_compress_bound(compressor: CPointer<Compressor>, in_nbytes: UInt64): UInt64

foreign func libdeflate_zlib_compress(compressor: CPointer<Compressor>, input: CPointer<Unit>, in_nbytes: UInt64, output: CPointer<Unit>, out_nbytes_avail: UInt64): UInt64

foreign func libdeflate_zlib_compress_bound(compressor: CPointer<Compressor>, in_nbytes: UInt64): UInt64

foreign func libdeflate_gzip_compress(compressor: CPointer<Compressor>, input: CPointer<Unit>, in_nbytes: UInt64, output: CPointer<Unit>, out_nbytes_avail: UInt64): UInt64

foreign func libdeflate_gzip_compress_bound(compressor: CPointer<Compressor>, in_nbytes: UInt64): UInt64

foreign func libdeflate_free_compressor(compressor: CPointer<Compressor>): Unit

// ============================================================================
// Decompressor FFI extern functions
// ============================================================================

foreign func libdeflate_alloc_decompressor(): CPointer<Decompressor>

foreign func libdeflate_alloc_decompressor_ex(options: CPointer<Options>): CPointer<Decompressor>

foreign func libdeflate_deflate_decompress(decompressor: CPointer<Decompressor>, input: CPointer<Unit>, in_nbytes: UInt64, output: CPointer<Unit>, out_nbytes_avail: UInt64, actual_out_nbytes_ret: CPointer<UInt64>): Int32

foreign func libdeflate_deflate_decompress_ex(decompressor: CPointer<Decompressor>, input: CPointer<Unit>, in_nbytes: UInt64, output: CPointer<Unit>, out_nbytes_avail: UInt64, actual_in_nbytes_ret: CPointer<UInt64>, actual_out_nbytes_ret: CPointer<UInt64>): Int32

foreign func libdeflate_zlib_decompress(decompressor: CPointer<Decompressor>, input: CPointer<Unit>, in_nbytes: UInt64, output: CPointer<Unit>, out_nbytes_avail: UInt64, actual_out_nbytes_ret: CPointer<UInt64>): Int32

foreign func libdeflate_zlib_decompress_ex(decompressor: CPointer<Decompressor>, input: CPointer<Unit>, in_nbytes: UInt64, output: CPointer<Unit>, out_nbytes_avail: UInt64, actual_in_nbytes_ret: CPointer<UInt64>, actual_out_nbytes_ret: CPointer<UInt64>): Int32

foreign func libdeflate_gzip_decompress(decompressor: CPointer<Decompressor>, input: CPointer<Unit>, in_nbytes: UInt64, output: CPointer<Unit>, out_nbytes_avail: UInt64, actual_out_nbytes_ret: CPointer<UInt64>): Int32

foreign func libdeflate_gzip_decompress_ex(decompressor: CPointer<Decompressor>, input: CPointer<Unit>, in_nbytes: UInt64, output: CPointer<Unit>, out_nbytes_avail: UInt64, actual_in_nbytes_ret: CPointer<UInt64>, actual_out_nbytes_ret: CPointer<UInt64>): Int32

foreign func libdeflate_free_decompressor(decompressor: CPointer<Decompressor>): Unit

// ============================================================================
// Checksum FFI extern functions
// ============================================================================

foreign func libdeflate_adler32(adler: UInt32, buffer: CPointer<Unit>, len: UInt64): UInt32

foreign func libdeflate_crc32(crc: UInt32, buffer: CPointer<Unit>, len: UInt64): UInt32

// ============================================================================
// Memory allocator FFI extern function
// ============================================================================

foreign func libdeflate_set_memory_allocator(malloc_func: CFunc<(UInt64) -> CPointer<Unit>>, free_func: CFunc<(CPointer<Unit>) -> Unit>): Unit

// ============================================================================
// Type aliases
// ============================================================================

public type LibdeflateCompressor = Compressor
public type LibdeflateDecompressor = Decompressor
public type LibdeflateOptions = Options
