// 严格翻译自: src/libdeflate_sys/libdeflate.zig

package bao_libdeflate_sys

// ============================================================================
// Opaque types
// ============================================================================

public opaque type Compressor {}
public opaque type Decompressor {}

// ============================================================================
// Options struct
// ============================================================================

public class Options {
    public var sizeof_options: UInt64 = 0
    public var malloc_func: CFunctionPointer<(UInt64) -> CPointer<None>> = CFunctionPointer<(UInt64) -> CPointer<None>>()
    public var free_func: CFunctionPointer<(CPointer<None>) -> Unit> = CFunctionPointer<(CPointer<None>) -> Unit>()

    public init() {
        sizeof_options = 16 // sizeOf(Options) placeholder
    }
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
// Status enum
// ============================================================================

public let LIBDEFLATE_SUCCESS: UInt32 = 0
public let LIBDEFLATE_BAD_DATA: UInt32 = 1
public let LIBDEFLATE_SHORT_OUTPUT: UInt32 = 2
public let LIBDEFLATE_INSUFFICIENT_SPACE: UInt32 = 3

public enum Status {
    success = 0   // LIBDEFLATE_SUCCESS
    bad_data = 1  // LIBDEFLATE_BAD_DATA
    short_output = 2  // LIBDEFLATE_SHORT_OUTPUT
    insufficient_space = 3  // LIBDEFLATE_INSUFFICIENT_SPACE
}

// ============================================================================
// Encoding enum
// ============================================================================

public enum Encoding {
    deflate
    zlib
    gzip
}

// ============================================================================
// Compressor FFI extern functions
// ============================================================================

@Extern
public func libdeflate_alloc_compressor(compression_level: Int32): CPointer<Compressor>

@Extern
public func libdeflate_alloc_compressor_ex(compression_level: Int32, options: CPointer<Options>): CPointer<Compressor>

@Extern
public func libdeflate_deflate_compress(compressor: CPointer<Compressor>, input: CPointer<None>, in_nbytes: UInt64, output: CPointer<None>, out_nbytes_avail: UInt64): UInt64

@Extern
public func libdeflate_deflate_compress_bound(compressor: CPointer<Compressor>, in_nbytes: UInt64): UInt64

@Extern
public func libdeflate_zlib_compress(compressor: CPointer<Compressor>, input: CPointer<None>, in_nbytes: UInt64, output: CPointer<None>, out_nbytes_avail: UInt64): UInt64

@Extern
public func libdeflate_zlib_compress_bound(compressor: CPointer<Compressor>, in_nbytes: UInt64): UInt64

@Extern
public func libdeflate_gzip_compress(compressor: CPointer<Compressor>, input: CPointer<None>, in_nbytes: UInt64, output: CPointer<None>, out_nbytes_avail: UInt64): UInt64

@Extern
public func libdeflate_gzip_compress_bound(compressor: CPointer<Compressor>, in_nbytes: UInt64): UInt64

@Extern
public func libdeflate_free_compressor(compressor: CPointer<Compressor>): Unit

// ============================================================================
// Decompressor FFI extern functions
// ============================================================================

@Extern
public func libdeflate_alloc_decompressor(): CPointer<Decompressor>

@Extern
public func libdeflate_alloc_decompressor_ex(options: CPointer<Options>): CPointer<Decompressor>

@Extern
public func libdeflate_deflate_decompress(decompressor: CPointer<Decompressor>, input: CPointer<None>, in_nbytes: UInt64, output: CPointer<None>, out_nbytes_avail: UInt64, actual_out_nbytes_ret: CPointer<UInt64>): Status

@Extern
public func libdeflate_deflate_decompress_ex(decompressor: CPointer<Decompressor>, input: CPointer<None>, in_nbytes: UInt64, output: CPointer<None>, out_nbytes_avail: UInt64, actual_in_nbytes_ret: CPointer<UInt64>, actual_out_nbytes_ret: CPointer<UInt64>): Status

@Extern
public func libdeflate_zlib_decompress(decompressor: CPointer<Decompressor>, input: CPointer<None>, in_nbytes: UInt64, output: CPointer<None>, out_nbytes_avail: UInt64, actual_out_nbytes_ret: CPointer<UInt64>): Status

@Extern
public func libdeflate_zlib_decompress_ex(decompressor: CPointer<Decompressor>, input: CPointer<None>, in_nbytes: UInt64, output: CPointer<None>, out_nbytes_avail: UInt64, actual_in_nbytes_ret: CPointer<UInt64>, actual_out_nbytes_ret: CPointer<UInt64>): Status

@Extern
public func libdeflate_gzip_decompress(decompressor: CPointer<Decompressor>, input: CPointer<None>, in_nbytes: UInt64, output: CPointer<None>, out_nbytes_avail: UInt64, actual_out_nbytes_ret: CPointer<UInt64>): Status

@Extern
public func libdeflate_gzip_decompress_ex(decompressor: CPointer<Decompressor>, input: CPointer<None>, in_nbytes: UInt64, output: CPointer<None>, out_nbytes_avail: UInt64, actual_in_nbytes_ret: CPointer<UInt64>, actual_out_nbytes_ret: CPointer<UInt64>): Status

@Extern
public func libdeflate_free_decompressor(decompressor: CPointer<Decompressor>): Unit

// ============================================================================
// Checksum FFI extern functions
// ============================================================================

@Extern
public func libdeflate_adler32(adler: UInt32, buffer: CPointer<None>, len: UInt64): UInt32

@Extern
public func libdeflate_crc32(crc: UInt32, buffer: CPointer<None>, len: UInt64): UInt32

// ============================================================================
// Memory allocator FFI extern function
// ============================================================================

@Extern
public func libdeflate_set_memory_allocator(malloc_func: CFunctionPointer<(UInt64) -> CPointer<None>>, free_func: CFunctionPointer<(CPointer<None>) -> Unit>): Unit

// ============================================================================
// Type aliases
// ============================================================================

public type LibdeflateCompressor = Compressor
public type LibdeflateDecompressor = Decompressor
public type LibdeflateOptions = Options
