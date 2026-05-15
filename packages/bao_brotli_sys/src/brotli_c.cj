// 严格翻译自: src/brotli_sys/brotli_c.zig

package bao_brotli_sys

// ============================================================================
// Callback function types
// ============================================================================

public type BrotliAllocFunc = CFunc<(CPointer<Unit>, UInt64) -> CPointer<Unit>>
public type BrotliFreeFunc = CFunc<(CPointer<Unit>, CPointer<Unit>) -> Unit>

// ============================================================================
// Opaque types
// ============================================================================

@C
public struct BrotliSharedDictionary {}
@C
public struct BrotliEncoderPreparedDictionary {}
@C
public struct BrotliDecoder {}
@C
public struct BrotliEncoder {}

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
    | err
    | success
    | needs_more_input
    | needs_more_output
}

public enum BrotliDecoderErrorCode {
    | FORMAT_EXUBERANT_NIBBLE
    | FORMAT_RESERVED
    | FORMAT_EXUBERANT_META_NIBBLE
    | FORMAT_SIMPLE_HUFFMAN_ALPHABET
    | FORMAT_SIMPLE_HUFFMAN_SAME
    | FORMAT_CL_SPACE
    | FORMAT_HUFFMAN_SPACE
    | FORMAT_CONTEXT_MAP_REPEAT
    | FORMAT_BLOCK_LENGTH_1
    | FORMAT_BLOCK_LENGTH_2
    | FORMAT_TRANSFORM
    | FORMAT_DICTIONARY
    | FORMAT_WINDOW_BITS
    | FORMAT_PADDING_1
    | FORMAT_PADDING_2
    | FORMAT_DISTANCE
    | COMPOUND_DICTIONARY
    | DICTIONARY_NOT_SET
    | INVALID_ARGUMENTS
    | ALLOC_CONTEXT_MODES
    | ALLOC_TREE_GROUPS
    | ALLOC_CONTEXT_MAP
    | ALLOC_RING_BUFFER_1
    | ALLOC_RING_BUFFER_2
    | ALLOC_BLOCK_TYPE_TREES
    | UNREACHABLE
}

public enum BrotliDecoderErrorCode2 {
    | NO_ERROR
    | SUCCESS
    | NEEDS_MORE_INPUT
    | NEEDS_MORE_OUTPUT
    | ERROR_FORMAT_EXUBERANT_NIBBLE
    | ERROR_FORMAT_RESERVED
    | ERROR_FORMAT_EXUBERANT_META_NIBBLE
    | ERROR_FORMAT_SIMPLE_HUFFMAN_ALPHABET
    | ERROR_FORMAT_SIMPLE_HUFFMAN_SAME
    | ERROR_FORMAT_CL_SPACE
    | ERROR_FORMAT_HUFFMAN_SPACE
    | ERROR_FORMAT_CONTEXT_MAP_REPEAT
    | ERROR_FORMAT_BLOCK_LENGTH_1
    | ERROR_FORMAT_BLOCK_LENGTH_2
    | ERROR_FORMAT_TRANSFORM
    | ERROR_FORMAT_DICTIONARY
    | ERROR_FORMAT_WINDOW_BITS
    | ERROR_FORMAT_PADDING_1
    | ERROR_FORMAT_PADDING_2
    | ERROR_FORMAT_DISTANCE
    | ERROR_COMPOUND_DICTIONARY
    | ERROR_DICTIONARY_NOT_SET
    | ERROR_INVALID_ARGUMENTS
    | ERROR_ALLOC_CONTEXT_MODES
    | ERROR_ALLOC_TREE_GROUPS
    | ERROR_ALLOC_CONTEXT_MAP
    | ERROR_ALLOC_RING_BUFFER_1
    | ERROR_ALLOC_RING_BUFFER_2
    | ERROR_ALLOC_BLOCK_TYPE_TREES
    | ERROR_UNREACHABLE
}

public enum BrotliDecoderParameter {
    | DISABLE_RING_BUFFER_REALLOCATION
    | LARGE_WINDOW
}

public enum BrotliEncoderMode {
    | generic
    | text
    | font
}

public enum BrotliEncoderParameter {
    | mode
    | quality
    | lgwin
    | lgblock
    | disable_literal_context_modeling
    | size_hint
    | large_window
    | npostfix
    | ndirect
    | stream_offset
}

public enum BrotliEncoderOperation {
    | process
    | flush
    | finish
    | emit_metadata
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

foreign func BrotliDecoderSetParameter(state: CPointer<BrotliDecoder>, param: UInt32, value: UInt32): Int32

foreign func BrotliDecoderAttachDictionary(state: CPointer<BrotliDecoder>, typ: BrotliSharedDictionaryType, data_size: UInt64, data: CPointer<UInt8>): Int32

foreign func BrotliDecoderCreateInstance(alloc_func: BrotliAllocFunc, free_func: BrotliFreeFunc, opaque: CPointer<Unit>): CPointer<BrotliDecoder>

foreign func BrotliDecoderDestroyInstance(state: CPointer<BrotliDecoder>): Unit

foreign func BrotliDecoderDecompress(encoded_size: UInt64, encoded_buffer: CPointer<UInt8>, decoded_size: CPointer<UInt64>, decoded_buffer: CPointer<UInt8>): Int32

foreign func BrotliDecoderDecompressStream(state: CPointer<BrotliDecoder>, available_in: CPointer<UInt64>, next_in: CPointer<CPointer<UInt8>>, available_out: CPointer<UInt64>, next_out: CPointer<CPointer<UInt8>>, total_out: CPointer<UInt64>): Int32

foreign func BrotliDecoderHasMoreOutput(state: CPointer<BrotliDecoder>): Int32

foreign func BrotliDecoderTakeOutput(state: CPointer<BrotliDecoder>, size: CPointer<UInt64>): CPointer<UInt8>

foreign func BrotliDecoderIsUsed(state: CPointer<BrotliDecoder>): Int32

foreign func BrotliDecoderIsFinished(state: CPointer<BrotliDecoder>): Int32

foreign func BrotliDecoderGetErrorCode(state: CPointer<BrotliDecoder>): Int32

foreign func BrotliDecoderErrorString(c: Int32): CPointer<UInt8>

foreign func BrotliDecoderVersion(): UInt32

// ============================================================================
// Shared Dictionary FFI extern functions
// ============================================================================

foreign func BrotliSharedDictionaryCreateInstance(alloc_func: BrotliAllocFunc, free_func: BrotliFreeFunc, opaque: CPointer<Unit>): CPointer<BrotliSharedDictionary>

foreign func BrotliSharedDictionaryDestroyInstance(dict: CPointer<BrotliSharedDictionary>): Unit

foreign func BrotliSharedDictionaryAttach(dict: CPointer<BrotliSharedDictionary>, typ: BrotliSharedDictionaryType, data_size: UInt64, data: CPointer<UInt8>): Int32

// ============================================================================
// Encoder FFI extern functions
// ============================================================================

foreign func BrotliEncoderSetParameter(state: CPointer<BrotliEncoder>, param: UInt32, value: UInt32): Int32

foreign func BrotliEncoderCreateInstance(alloc_func: BrotliAllocFunc, free_func: BrotliFreeFunc, opaque: CPointer<Unit>): CPointer<BrotliEncoder>

foreign func BrotliEncoderDestroyInstance(state: CPointer<BrotliEncoder>): Unit

foreign func BrotliEncoderPrepareDictionary(typ: BrotliSharedDictionaryType, data_size: UInt64, data: CPointer<UInt8>, quality: Int32, alloc_func: BrotliAllocFunc, free_func: BrotliFreeFunc, opaque: CPointer<Unit>): CPointer<BrotliEncoderPreparedDictionary>

foreign func BrotliEncoderDestroyPreparedDictionary(dictionary: CPointer<BrotliEncoderPreparedDictionary>): Unit

foreign func BrotliEncoderAttachPreparedDictionary(state: CPointer<BrotliEncoder>, dictionary: CPointer<BrotliEncoderPreparedDictionary>): Int32

foreign func BrotliEncoderMaxCompressedSize(input_size: UInt64): UInt64

foreign func BrotliEncoderCompress(quality: Int32, lgwin: Int32, mode: UInt32, input_size: UInt64, input_buffer: CPointer<UInt8>, encoded_size: CPointer<UInt64>, encoded_buffer: CPointer<UInt8>): Int32

foreign func BrotliEncoderCompressStream(state: CPointer<BrotliEncoder>, op: UInt32, available_in: CPointer<UInt64>, next_in: CPointer<CPointer<UInt8>>, available_out: CPointer<UInt64>, next_out: CPointer<CPointer<UInt8>>, total_out: CPointer<UInt64>): Int32

foreign func BrotliEncoderIsFinished(state: CPointer<BrotliEncoder>): Int32

foreign func BrotliEncoderHasMoreOutput(state: CPointer<BrotliEncoder>): Int32

foreign func BrotliEncoderTakeOutput(state: CPointer<BrotliEncoder>, size: CPointer<UInt64>): CPointer<UInt8>

foreign func BrotliEncoderEstimatePeakMemoryUsage(quality: Int32, lgwin: Int32, input_size: UInt64): UInt64

foreign func BrotliEncoderGetPreparedDictionarySize(dictionary: CPointer<BrotliEncoderPreparedDictionary>): UInt64

foreign func BrotliEncoderVersion(): UInt32

// ============================================================================
// BROTLI_UINT32_MAX and BROTLI_SIZE_MAX
// ============================================================================

public let BROTLI_UINT32_MAX: UInt32 = 4294967295 // 0xFFFFFFFF
public let BROTLI_SIZE_MAX: UInt64 = 18446744073709551615 // 0xFFFFFFFFFFFFFFFF on 64-bit
public let BROTLI_LAST_ERROR_CODE: Int32 = -31 // BROTLI_DECODER_ERROR_UNREACHABLE
