// 严格翻译自: src/zlib_sys/shared.zig
package bao_zlib_sys

// ============================================================================
// DataType - zlib 数据类型枚举
// 严格翻译自: shared.zig DataType
// ============================================================================
public enum ZDataType {
    | Binary
    | Text
    | Unknown
}

// ============================================================================
// ReturnCode - zlib 返回码枚举
// 严格翻译自: shared.zig ReturnCode
// ============================================================================
public enum ZReturnCode {
    | Ok
    | StreamEnd
    | NeedDict
    | ErrNo
    | StreamError
    | DataError
    | MemError
    | BufError
    | VersionError
}

// ============================================================================
// FlushValue - zlib 刷新值枚举
// 严格翻译自: shared.zig FlushValue
// ============================================================================
public enum ZFlushValue {
    | NoFlush
    | PartialFlush
    | SyncFlush
    | FullFlush
    | Finish
    | Block
    | Trees
}
