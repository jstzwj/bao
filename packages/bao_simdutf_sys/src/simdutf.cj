// 严格翻译自: src/simdutf_sys/simdutf.zig

package bao_simdutf_sys

// ============================================================================
// SIMDUTFResult struct
// ============================================================================

public class SIMDUTFResult {
    public var status: SIMDUTFStatus = SIMDUTFStatus.success
    public var count: UInt64 = 0

    public init() {}
    public init(status: SIMDUTFStatus, count: UInt64) {
        this.status = status
        this.count = count
    }

    public func isSuccessful(): Bool {
        return status == SIMDUTFStatus.success
    }
}

// ============================================================================
// Status enum
// ============================================================================

public enum SIMDUTFStatus {
    | success
    | header_bits
    | too_short
    | too_long
    | overlong
    | too_large
    | surrogate
    | invalid_base64_character
    | base64_input_remainder
    | output_buffer_too_small
}

// ============================================================================
// Detection FFI extern functions
// ============================================================================

foreign func simdutf__detect_encodings(input: CPointer<UInt8>, length: UInt64): Int32

// ============================================================================
// Validation FFI extern functions
// ============================================================================

foreign func simdutf__validate_utf8(buf: CPointer<UInt8>, len: UInt64): Bool

foreign func simdutf__validate_utf8_with_errors(buf: CPointer<UInt8>, len: UInt64): SIMDUTFResult

foreign func simdutf__validate_ascii(buf: CPointer<UInt8>, len: UInt64): Bool

foreign func simdutf__validate_ascii_with_errors(buf: CPointer<UInt8>, len: UInt64): SIMDUTFResult

foreign func simdutf__validate_utf16le(buf: CPointer<UInt16>, len: UInt64): Bool

foreign func simdutf__validate_utf16be(buf: CPointer<UInt16>, len: UInt64): Bool

foreign func simdutf__validate_utf16le_with_errors(buf: CPointer<UInt16>, len: UInt64): SIMDUTFResult

foreign func simdutf__validate_utf16be_with_errors(buf: CPointer<UInt16>, len: UInt64): SIMDUTFResult

foreign func simdutf__validate_utf32(buf: CPointer<UInt32>, len: UInt64): Bool

foreign func simdutf__validate_utf32_with_errors(buf: CPointer<UInt32>, len: UInt64): SIMDUTFResult

// ============================================================================
// UTF-8 to UTF-16 conversion FFI extern functions
// ============================================================================

foreign func simdutf__convert_utf8_to_utf16le(buf: CPointer<UInt8>, len: UInt64, utf16_output: CPointer<UInt16>): UInt64

foreign func simdutf__convert_utf8_to_utf16be(buf: CPointer<UInt8>, len: UInt64, utf16_output: CPointer<UInt16>): UInt64

foreign func simdutf__convert_utf8_to_utf16le_with_errors(buf: CPointer<UInt8>, len: UInt64, utf16_output: CPointer<UInt16>): SIMDUTFResult

foreign func simdutf__convert_utf8_to_utf16be_with_errors(buf: CPointer<UInt8>, len: UInt64, utf16_output: CPointer<UInt16>): SIMDUTFResult

foreign func simdutf__convert_valid_utf8_to_utf16be(buf: CPointer<UInt8>, len: UInt64, utf16_buffer: CPointer<UInt16>): UInt64

// ============================================================================
// UTF-8 to UTF-32 conversion FFI extern functions
// ============================================================================

foreign func simdutf__convert_utf8_to_utf32(buf: CPointer<UInt8>, len: UInt64, utf32_output: CPointer<UInt32>): UInt64

foreign func simdutf__convert_utf8_to_utf32_with_errors(buf: CPointer<UInt8>, len: UInt64, utf32_output: CPointer<UInt32>): SIMDUTFResult

foreign func simdutf__convert_valid_utf8_to_utf32(buf: CPointer<UInt8>, len: UInt64, utf32_buffer: CPointer<UInt32>): UInt64

// ============================================================================
// UTF-16 to UTF-8 conversion FFI extern functions
// ============================================================================

foreign func simdutf__convert_utf16le_to_utf8(buf: CPointer<UInt16>, len: UInt64, utf8_buffer: CPointer<UInt8>): UInt64

foreign func simdutf__convert_utf16be_to_utf8(buf: CPointer<UInt16>, len: UInt64, utf8_buffer: CPointer<UInt8>): UInt64

foreign func simdutf__convert_utf16le_to_utf8_with_errors(buf: CPointer<UInt16>, len: UInt64, utf8_buffer: CPointer<UInt8>): SIMDUTFResult

foreign func simdutf__convert_utf16be_to_utf8_with_errors(buf: CPointer<UInt16>, len: UInt64, utf8_buffer: CPointer<UInt8>): SIMDUTFResult

foreign func simdutf__convert_valid_utf16le_to_utf8(buf: CPointer<UInt16>, len: UInt64, utf8_buffer: CPointer<UInt8>): UInt64

foreign func simdutf__convert_valid_utf16be_to_utf8(buf: CPointer<UInt16>, len: UInt64, utf8_buffer: CPointer<UInt8>): UInt64

// ============================================================================
// UTF-32 to UTF-8 conversion FFI extern functions
// ============================================================================

foreign func simdutf__convert_utf32_to_utf8(buf: CPointer<UInt32>, len: UInt64, utf8_buffer: CPointer<UInt8>): UInt64

foreign func simdutf__convert_utf32_to_utf8_with_errors(buf: CPointer<UInt32>, len: UInt64, utf8_buffer: CPointer<UInt8>): SIMDUTFResult

foreign func simdutf__convert_valid_utf32_to_utf8(buf: CPointer<UInt32>, len: UInt64, utf8_buffer: CPointer<UInt8>): UInt64

// ============================================================================
// UTF-32 to UTF-16 conversion FFI extern functions
// ============================================================================

foreign func simdutf__convert_utf32_to_utf16le(buf: CPointer<UInt32>, len: UInt64, utf16_buffer: CPointer<UInt16>): UInt64

foreign func simdutf__convert_utf32_to_utf16be(buf: CPointer<UInt32>, len: UInt64, utf16_buffer: CPointer<UInt16>): UInt64

foreign func simdutf__convert_utf32_to_utf16le_with_errors(buf: CPointer<UInt32>, len: UInt64, utf16_buffer: CPointer<UInt16>): SIMDUTFResult

foreign func simdutf__convert_utf32_to_utf16be_with_errors(buf: CPointer<UInt32>, len: UInt64, utf16_buffer: CPointer<UInt16>): SIMDUTFResult

foreign func simdutf__convert_valid_utf32_to_utf16le(buf: CPointer<UInt32>, len: UInt64, utf16_buffer: CPointer<UInt16>): UInt64

foreign func simdutf__convert_valid_utf32_to_utf16be(buf: CPointer<UInt32>, len: UInt64, utf16_buffer: CPointer<UInt16>): UInt64

// ============================================================================
// UTF-16 to UTF-32 conversion FFI extern functions
// ============================================================================

foreign func simdutf__convert_utf16le_to_utf32(buf: CPointer<UInt16>, len: UInt64, utf32_buffer: CPointer<UInt32>): UInt64

foreign func simdutf__convert_utf16be_to_utf32(buf: CPointer<UInt16>, len: UInt64, utf32_buffer: CPointer<UInt32>): UInt64

foreign func simdutf__convert_utf16le_to_utf32_with_errors(buf: CPointer<UInt16>, len: UInt64, utf32_buffer: CPointer<UInt32>): SIMDUTFResult

foreign func simdutf__convert_utf16be_to_utf32_with_errors(buf: CPointer<UInt16>, len: UInt64, utf32_buffer: CPointer<UInt32>): SIMDUTFResult

foreign func simdutf__convert_valid_utf16le_to_utf32(buf: CPointer<UInt16>, len: UInt64, utf32_buffer: CPointer<UInt32>): UInt64

foreign func simdutf__convert_valid_utf16be_to_utf32(buf: CPointer<UInt16>, len: UInt64, utf32_buffer: CPointer<UInt32>): UInt64

// ============================================================================
// Latin1 conversion FFI extern functions
// ============================================================================

foreign func simdutf__convert_latin1_to_utf8(buf: CPointer<UInt8>, len: UInt64, utf8_buffer: CPointer<UInt8>): UInt64

// ============================================================================
// Endianness / count FFI extern functions
// ============================================================================

foreign func simdutf__change_endianness_utf16(buf: CPointer<UInt16>, length: UInt64, output: CPointer<UInt16>): Unit

foreign func simdutf__count_utf16le(buf: CPointer<UInt16>, length: UInt64): UInt64

foreign func simdutf__count_utf16be(buf: CPointer<UInt16>, length: UInt64): UInt64

foreign func simdutf__count_utf8(buf: CPointer<UInt8>, length: UInt64): UInt64

// ============================================================================
// Length estimation FFI extern functions
// ============================================================================

foreign func simdutf__utf8_length_from_utf16le(input: CPointer<UInt16>, length: UInt64): UInt64

foreign func simdutf__utf8_length_from_utf16be(input: CPointer<UInt16>, length: UInt64): UInt64

foreign func simdutf__utf32_length_from_utf16le(input: CPointer<UInt16>, length: UInt64): UInt64

foreign func simdutf__utf32_length_from_utf16be(input: CPointer<UInt16>, length: UInt64): UInt64

foreign func simdutf__utf16_length_from_utf8(input: CPointer<UInt8>, length: UInt64): UInt64

foreign func simdutf__utf8_length_from_utf32(input: CPointer<UInt32>, length: UInt64): UInt64

foreign func simdutf__utf16_length_from_utf32(input: CPointer<UInt32>, length: UInt64): UInt64

foreign func simdutf__utf32_length_from_utf8(input: CPointer<UInt8>, length: UInt64): UInt64

foreign func simdutf__utf8_length_from_latin1(input: CPointer<UInt8>, length: UInt64): UInt64

foreign func simdutf__utf16_length_from_latin1(input: CPointer<UInt8>, length: UInt64): UInt64

// ============================================================================
// Base64 FFI extern functions
// ============================================================================

foreign func simdutf__base64_encode(input: CPointer<UInt8>, length: UInt64, output: CPointer<UInt8>, is_urlsafe: Int32): UInt64

foreign func simdutf__base64_decode_from_binary(input: CPointer<UInt8>, length: UInt64, output: CPointer<UInt8>, outlen: UInt64, is_urlsafe: Int32): SIMDUTFResult

foreign func simdutf__base64_decode_from_binary16(input: CPointer<UInt16>, length: UInt64, output: CPointer<UInt8>, outlen: UInt64, is_urlsafe: Int32): SIMDUTFResult

foreign func simdutf__base64_length_from_binary(length: UInt64, options: Int32): UInt64

// ============================================================================
// Detect encoding constants
// ============================================================================

public let SIMDUTF_ENCODING_UTF8: Int32 = 1
public let SIMDUTF_ENCODING_UTF16_LE: Int32 = 2
public let SIMDUTF_ENCODING_UTF16_BE: Int32 = 3
public let SIMDUTF_ENCODING_UTF32_LE: Int32 = 4
public let SIMDUTF_ENCODING_UTF32_BE: Int32 = 5
public let SIMDUTF_ENCODING_LATIN1: Int32 = 6
