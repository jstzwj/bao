// 严格翻译自: src/brotli_sys/brotli_c.zig

package bao_brotli_sys

// ============================================================================
// Callback function types
// ============================================================================

public type BrotliAllocFunc = CFunctionPointer<(CPointer<None>, UInt64) -> CPointer<None>>
public type BrotliFreeFunc = CFunctionPointer<(CPointer<None>, CPointer<None>) -> Unit>

// ============================================================================
// Opaque types
// ============================================================================

public opaque type BrotliSharedDictionary {}
public opaque type BrotliEncoderPreparedDictionary {}
public opaque type BrotliDecoder {}
public opaque type BrotliEncoder {}

// ============================================================================
// Shared Dictionary constants
// ============================================================================

public let BROTLI_SHARED_DICTIONARY_RAW: Int32 = 0
public let BROTLI_SHARED_DICTIONARY_SERIALIZED: Int32 = 1

public type BrotliSharedDictionaryType = UInt32

// ============================================================================
// Decoder constants
// ============================================================================

public let BROTLI_DECODER_NO_ERROR: Int32 = 0
public let BROTLI_DECODER_SUCCESS: Int32 = 1
public let BROTLI_DECODER_NEEDS_MORE_INPUT: Int32 = 2
public let BROTLI_DECODER_NEEDS_MORE_OUTPUT: Int32 = 3
public let BROTLI_DECODER_ERROR_FORMAT_EXUBERANT_NIBBLE: Int32 = -1
public let BROTLI_DECODER_ERROR_FORMAT_RESERVED: Int32 = -2
public let BROTLI_DECODER_ERROR_FORMAT_EXUBERANT_META_NIBBLE: Int32 = -3
public let BROTLI_DECODER_ERROR_FORMAT_SIMPLE_HUFFMAN_ALPHABET: Int32 = -4
public let BROTLI_DECODER_ERROR_FORMAT_SIMPLE_HUFFMAN_SAME: Int32 = -5
public let BROTLI_DECODER_ERROR_FORMAT_CL_SPACE: Int32 = -6
public let BROTLI_DECODER_ERROR_FORMAT_HUFFMAN_SPACE: Int32 = -7
public let BROTLI_DECODER_ERROR_FORMAT_CONTEXT_MAP_REPEAT: Int32 = -8
public let BROTLI_DECODER_ERROR_FORMAT_BLOCK_LENGTH_1: Int32 = -9
public let BROTLI_DECODER_ERROR_FORMAT_BLOCK_LENGTH_2: Int32 = -10
public let BROTLI_DECODER_ERROR_FORMAT_TRANSFORM: Int32 = -11
public let BROTLI_DECODER_ERROR_FORMAT_DICTIONARY: Int32 = -12
public let BROTLI_DECODER_ERROR_FORMAT_WINDOW_BITS: Int32 = -13
public let BROTLI_DECODER_ERROR_FORMAT_PADDING_1: Int32 = -14
public let BROTLI_DECODER_ERROR_FORMAT_PADDING_2: Int32 = -15
public let BROTLI_DECODER_ERROR_FORMAT_DISTANCE: Int32 = -16
public let BROTLI_DECODER_ERROR_COMPOUND_DICTIONARY: Int32 = -18
public let BROTLI_DECODER_ERROR_DICTIONARY_NOT_SET: Int32 = -19
public let BROTLI_DECODER_ERROR_INVALID_ARGUMENTS: Int32 = -20
public let BROTLI_DECODER_ERROR_ALLOC_CONTEXT_MODES: Int32 = -21
public let BROTLI_DECODER_ERROR_ALLOC_TREE_GROUPS: Int32 = -22
public let BROTLI_DECODER_ERROR_ALLOC_CONTEXT_MAP: Int32 = -25
public let BROTLI_DECODER_ERROR_ALLOC_RING_BUFFER_1: Int32 = -26
public let BROTLI_DECODER_ERROR_ALLOC_RING_BUFFER_2: Int32 = -27
public let BROTLI_DECODER_ERROR_ALLOC_BLOCK_TYPE_TREES: Int32 = -30
public let BROTLI_DECODER_ERROR_UNREACHABLE: Int32 = -31

// ============================================================================
// Decoder parameter constants
// ============================================================================

public let BROTLI_DECODER_PARAM_DISABLE_RING_BUFFER_REALLOCATION: Int32 = 0
public let BROTLI_DECODER_PARAM_LARGE_WINDOW: Int32 = 1

// ============================================================================
// Encoder mode constants
// ============================================================================

public let BROTLI_MODE_GENERIC: Int32 = 0
public let BROTLI_MODE_TEXT: Int32 = 1
public let BROTLI_MODE_FONT: Int32 = 2

// ============================================================================
// Encoder operation constants
// ============================================================================

public let BROTLI_OPERATION_PROCESS: Int32 = 0
public let BROTLI_OPERATION_FLUSH: Int32 = 1
public let BROTLI_OPERATION_FINISH: Int32 = 2
public let BROTLI_OPERATION_EMIT_METADATA: Int32 = 3

// ============================================================================
// Encoder parameter constants
// ============================================================================

public let BROTLI_PARAM_MODE: Int32 = 0
public let BROTLI_PARAM_QUALITY: Int32 = 1
public let BROTLI_PARAM_LGWIN: Int32 = 2
public let BROTLI_PARAM_LGBLOCK: Int32 = 3
public let BROTLI_PARAM_DISABLE_LITERAL_CONTEXT_MODELING: Int32 = 4
public let BROTLI_PARAM_SIZE_HINT: Int32 = 5
public let BROTLI_PARAM_LARGE_WINDOW: Int32 = 6
public let BROTLI_PARAM_NPOSTFIX: Int32 = 7
public let BROTLI_PARAM_NDIRECT: Int32 = 8
public let BROTLI_PARAM_STREAM_OFFSET: Int32 = 9

// ============================================================================
// Limits and defaults
// ============================================================================

public let SHARED_BROTLI_MIN_DICTIONARY_WORD_LENGTH: Int32 = 4
public let SHARED_BROTLI_MAX_DICTIONARY_WORD_LENGTH: Int32 = 31
public let SHARED_BROTLI_NUM_DICTIONARY_CONTEXTS: Int32 = 64
public let SHARED_BROTLI_MAX_COMPOUND_DICTS: Int32 = 15
public let BROTLI_MIN_WINDOW_BITS: Int32 = 10
public let BROTLI_MAX_WINDOW_BITS: Int32 = 24
public let BROTLI_LARGE_MAX_WINDOW_BITS: Int32 = 30
public let BROTLI_MIN_INPUT_BLOCK_BITS: Int32 = 16
public let BROTLI_MAX_INPUT_BLOCK_BITS: Int32 = 24
public let BROTLI_MIN_QUALITY: Int32 = 0
public let BROTLI_MAX_QUALITY: Int32 = 11
public let BROTLI_DEFAULT_QUALITY: Int32 = 11
public let BROTLI_DEFAULT_WINDOW: Int32 = 22
public let BROTLI_DEFAULT_MODE: Int32 = 0 // BROTLI_MODE_GENERIC

// ============================================================================
// Enums
// ============================================================================

public enum BrotliDecoderResult {
    err = 0
    success = 1
    needs_more_input = 2
    needs_more_output = 3
}

public enum BrotliDecoderErrorCode {
    FORMAT_EXUBERANT_NIBBLE = -1
    FORMAT_RESERVED = -2
    FORMAT_EXUBERANT_META_NIBBLE = -3
    FORMAT_SIMPLE_HUFFMAN_ALPHABET = -4
    FORMAT_SIMPLE_HUFFMAN_SAME = -5
    FORMAT_CL_SPACE = -6
    FORMAT_HUFFMAN_SPACE = -7
    FORMAT_CONTEXT_MAP_REPEAT = -8
    FORMAT_BLOCK_LENGTH_1 = -9
    FORMAT_BLOCK_LENGTH_2 = -10
    FORMAT_TRANSFORM = -11
    FORMAT_DICTIONARY = -12
    FORMAT_WINDOW_BITS = -13
    FORMAT_PADDING_1 = -14
    FORMAT_PADDING_2 = -15
    FORMAT_DISTANCE = -16
    COMPOUND_DICTIONARY = -18
    DICTIONARY_NOT_SET = -19
    INVALID_ARGUMENTS = -20
    ALLOC_CONTEXT_MODES = -21
    ALLOC_TREE_GROUPS = -22
    ALLOC_CONTEXT_MAP = -25
    ALLOC_RING_BUFFER_1 = -26
    ALLOC_RING_BUFFER_2 = -27
    ALLOC_BLOCK_TYPE_TREES = -30
    UNREACHABLE = -31
}

public enum BrotliDecoderErrorCode2 {
    NO_ERROR = 0
    SUCCESS = 1
    NEEDS_MORE_INPUT = 2
    NEEDS_MORE_OUTPUT = 3
    ERROR_FORMAT_EXUBERANT_NIBBLE = -1
    ERROR_FORMAT_RESERVED = -2
    ERROR_FORMAT_EXUBERANT_META_NIBBLE = -3
    ERROR_FORMAT_SIMPLE_HUFFMAN_ALPHABET = -4
    ERROR_FORMAT_SIMPLE_HUFFMAN_SAME = -5
    ERROR_FORMAT_CL_SPACE = -6
    ERROR_FORMAT_HUFFMAN_SPACE = -7
    ERROR_FORMAT_CONTEXT_MAP_REPEAT = -8
    ERROR_FORMAT_BLOCK_LENGTH_1 = -9
    ERROR_FORMAT_BLOCK_LENGTH_2 = -10
    ERROR_FORMAT_TRANSFORM = -11
    ERROR_FORMAT_DICTIONARY = -12
    ERROR_FORMAT_WINDOW_BITS = -13
    ERROR_FORMAT_PADDING_1 = -14
    ERROR_FORMAT_PADDING_2 = -15
    ERROR_FORMAT_DISTANCE = -16
    ERROR_COMPOUND_DICTIONARY = -18
    ERROR_DICTIONARY_NOT_SET = -19
    ERROR_INVALID_ARGUMENTS = -20
    ERROR_ALLOC_CONTEXT_MODES = -21
    ERROR_ALLOC_TREE_GROUPS = -22
    ERROR_ALLOC_CONTEXT_MAP = -25
    ERROR_ALLOC_RING_BUFFER_1 = -26
    ERROR_ALLOC_RING_BUFFER_2 = -27
    ERROR_ALLOC_BLOCK_TYPE_TREES = -30
    ERROR_UNREACHABLE = -31
}

public enum BrotliDecoderParameter {
    DISABLE_RING_BUFFER_REALLOCATION = 0
    LARGE_WINDOW = 1
}

public enum BrotliEncoderMode {
    generic = 0
    text = 1
    font = 2
}

public enum BrotliEncoderParameter {
    mode = 0
    quality = 1
    lgwin = 2
    lgblock = 3
    disable_literal_context_modeling = 4
    size_hint = 5
    large_window = 6
    npostfix = 7
    ndirect = 8
    stream_offset = 9
}

public enum BrotliEncoderOperation {
    process = 0
    flush = 1
    finish = 2
    emit_metadata = 3
}

// ============================================================================
// Compression result struct
// ============================================================================

public class CompressionResult {
    public var success: Bool = false
    public var has_more: Bool = false
    public var output: Array<UInt8> = Array<UInt8>()

    public init() {}
    public init(success: Bool, has_more: Bool, output: Array<UInt8>) {
        this.success = success
        this.has_more = has_more
        this.output = output
    }
}

// ============================================================================
// Decoder FFI extern functions
// ============================================================================

@Extern
public func BrotliDecoderSetParameter(state: CPointer<BrotliDecoder>, param: UInt32, value: UInt32): Int32

@Extern
public func BrotliDecoderAttachDictionary(state: CPointer<BrotliDecoder>, typ: BrotliSharedDictionaryType, data_size: UInt64, data: CPointer<UInt8>): Int32

@Extern
public func BrotliDecoderCreateInstance(alloc_func: BrotliAllocFunc, free_func: BrotliFreeFunc, opaque: CPointer<None>): CPointer<BrotliDecoder>

@Extern
public func BrotliDecoderDestroyInstance(state: CPointer<BrotliDecoder>): Unit

@Extern
public func BrotliDecoderDecompress(encoded_size: UInt64, encoded_buffer: CPointer<UInt8>, decoded_size: CPointer<UInt64>, decoded_buffer: CPointer<UInt8>): Int32

@Extern
public func BrotliDecoderDecompressStream(state: CPointer<BrotliDecoder>, available_in: CPointer<UInt64>, next_in: CPointer<CPointer<UInt8>>, available_out: CPointer<UInt64>, next_out: CPointer<CPointer<UInt8>>, total_out: CPointer<UInt64>): Int32

@Extern
public func BrotliDecoderHasMoreOutput(state: CPointer<BrotliDecoder>): Int32

@Extern
public func BrotliDecoderTakeOutput(state: CPointer<BrotliDecoder>, size: CPointer<UInt64>): CPointer<UInt8>

@Extern
public func BrotliDecoderIsUsed(state: CPointer<BrotliDecoder>): Int32

@Extern
public func BrotliDecoderIsFinished(state: CPointer<BrotliDecoder>): Int32

@Extern
public func BrotliDecoderGetErrorCode(state: CPointer<BrotliDecoder>): Int32

@Extern
public func BrotliDecoderErrorString(c: Int32): CPointer<UInt8>

@Extern
public func BrotliDecoderVersion(): UInt32

// ============================================================================
// Shared Dictionary FFI extern functions
// ============================================================================

@Extern
public func BrotliSharedDictionaryCreateInstance(alloc_func: BrotliAllocFunc, free_func: BrotliFreeFunc, opaque: CPointer<None>): CPointer<BrotliSharedDictionary>

@Extern
public func BrotliSharedDictionaryDestroyInstance(dict: CPointer<BrotliSharedDictionary>): Unit

@Extern
public func BrotliSharedDictionaryAttach(dict: CPointer<BrotliSharedDictionary>, typ: BrotliSharedDictionaryType, data_size: UInt64, data: CPointer<UInt8>): Int32

// ============================================================================
// Encoder FFI extern functions
// ============================================================================

@Extern
public func BrotliEncoderSetParameter(state: CPointer<BrotliEncoder>, param: UInt32, value: UInt32): Int32

@Extern
public func BrotliEncoderCreateInstance(alloc_func: BrotliAllocFunc, free_func: BrotliFreeFunc, opaque: CPointer<None>): CPointer<BrotliEncoder>

@Extern
public func BrotliEncoderDestroyInstance(state: CPointer<BrotliEncoder>): Unit

@Extern
public func BrotliEncoderPrepareDictionary(typ: BrotliSharedDictionaryType, data_size: UInt64, data: CPointer<UInt8>, quality: Int32, alloc_func: BrotliAllocFunc, free_func: BrotliFreeFunc, opaque: CPointer<None>): CPointer<BrotliEncoderPreparedDictionary>

@Extern
public func BrotliEncoderDestroyPreparedDictionary(dictionary: CPointer<BrotliEncoderPreparedDictionary>): Unit

@Extern
public func BrotliEncoderAttachPreparedDictionary(state: CPointer<BrotliEncoder>, dictionary: CPointer<BrotliEncoderPreparedDictionary>): Int32

@Extern
public func BrotliEncoderMaxCompressedSize(input_size: UInt64): UInt64

@Extern
public func BrotliEncoderCompress(quality: Int32, lgwin: Int32, mode: UInt32, input_size: UInt64, input_buffer: CPointer<UInt8>, encoded_size: CPointer<UInt64>, encoded_buffer: CPointer<UInt8>): Int32

@Extern
public func BrotliEncoderCompressStream(state: CPointer<BrotliEncoder>, op: UInt32, available_in: CPointer<UInt64>, next_in: CPointer<CPointer<UInt8>>, available_out: CPointer<UInt64>, next_out: CPointer<CPointer<UInt8>>, total_out: CPointer<UInt64>): Int32

@Extern
public func BrotliEncoderIsFinished(state: CPointer<BrotliEncoder>): Int32

@Extern
public func BrotliEncoderHasMoreOutput(state: CPointer<BrotliEncoder>): Int32

@Extern
public func BrotliEncoderTakeOutput(state: CPointer<BrotliEncoder>, size: CPointer<UInt64>): CPointer<UInt8>

@Extern
public func BrotliEncoderEstimatePeakMemoryUsage(quality: Int32, lgwin: Int32, input_size: UInt64): UInt64

@Extern
public func BrotliEncoderGetPreparedDictionarySize(dictionary: CPointer<BrotliEncoderPreparedDictionary>): UInt64

@Extern
public func BrotliEncoderVersion(): UInt32

// ============================================================================
// BROTLI_UINT32_MAX and BROTLI_SIZE_MAX
// ============================================================================

public let BROTLI_UINT32_MAX: UInt32 = 4294967295 // 0xFFFFFFFF
public let BROTLI_SIZE_MAX: UInt64 = 18446744073709551615 // 0xFFFFFFFFFFFFFFFF on 64-bit
public let BROTLI_LAST_ERROR_CODE: Int32 = -31 // BROTLI_DECODER_ERROR_UNREACHABLE
