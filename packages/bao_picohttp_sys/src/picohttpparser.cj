// 严格翻译自: src/picohttp_sys/picohttpparser.zig

package bao_picohttp_sys

// ============================================================================
// phr_header struct - must be @C struct for FFI
// ============================================================================

@C
public struct PhrHeader {
    public var name: CPointer<UInt8> = CPointer<UInt8>()
    public var name_len: UInt64 = 0
    public var value: CPointer<UInt8> = CPointer<UInt8>()
    public var value_len: UInt64 = 0
}

// ============================================================================
// Chunked encoding state constants
// ============================================================================

public let CHUNKED_IN_CHUNK_SIZE: Int32 = 0
public let CHUNKED_IN_CHUNK_EXT: Int32 = 1
public let CHUNKED_IN_CHUNK_DATA: Int32 = 2
public let CHUNKED_IN_CHUNK_CRLF: Int32 = 3
public let CHUNKED_IN_TRAILERS_LINE_HEAD: Int32 = 4
public let CHUNKED_IN_TRAILERS_LINE_MIDDLE: Int32 = 5

// ============================================================================
// phr_chunked_decoder struct - must be @C struct for FFI
// ============================================================================

@C
public struct PhrChunkedDecoder {
    public var bytes_left_in_chunk: UInt64 = 0
    public var consume_trailer: UInt8 = 0
    public var _hex_count: UInt8 = 0
    public var _state: Int32 = CHUNKED_IN_CHUNK_SIZE
}

// ============================================================================
// FFI extern functions
// ============================================================================

foreign func phr_parse_request(
    buf: CPointer<UInt8>,
    len: UInt64,
    method: CPointer<CPointer<UInt8>>,
    method_len: CPointer<UInt64>,
    path: CPointer<CPointer<UInt8>>,
    path_len: CPointer<UInt64>,
    minor_version: CPointer<Int32>,
    headers: CPointer<PhrHeader>,
    num_headers: CPointer<UInt64>,
    last_len: UInt64
): Int32

foreign func phr_parse_response(
    _buf: CPointer<UInt8>,
    len: UInt64,
    minor_version: CPointer<Int32>,
    status: CPointer<Int32>,
    msg: CPointer<CPointer<UInt8>>,
    msg_len: CPointer<UInt64>,
    headers: CPointer<PhrHeader>,
    num_headers: CPointer<UInt64>,
    last_len: UInt64
): Int32

foreign func phr_parse_headers(
    buf: CPointer<UInt8>,
    len: UInt64,
    headers: CPointer<PhrHeader>,
    num_headers: CPointer<UInt64>,
    last_len: UInt64
): Int32

foreign func phr_decode_chunked(
    decoder: CPointer<PhrChunkedDecoder>,
    buf: CPointer<UInt8>,
    bufsz: CPointer<UInt64>
): Int64

foreign func phr_decode_chunked_is_in_data(
    decoder: CPointer<PhrChunkedDecoder>
): Int32

// ============================================================================
// Type aliases matching Zig source
// ============================================================================

public type PhrHeaderPtr = CPointer<PhrHeader>
public type PhrChunkedDecoderPtr = CPointer<PhrChunkedDecoder>
