// 严格翻译自: src/zlib_sys/shared.zig
package bao_zlib_sys

// ============================================================================
// DataType - zlib 数据类型枚举
// 严格翻译自: shared.zig DataType
// ============================================================================
public enum ZDataType <: Int32 {
    Binary = 0
    Text = 1
    Unknown = 2
}

// ============================================================================
// ReturnCode - zlib 返回码枚举
// 严格翻译自: shared.zig ReturnCode
// ============================================================================
public enum ZReturnCode <: Int32 {
    Ok = 0
    StreamEnd = 1
    NeedDict = 2
    ErrNo = -1
    StreamError = -2
    DataError = -3
    MemError = -4
    BufError = -5
    VersionError = -6
}

// ============================================================================
// FlushValue - zlib 刷新值枚举
// 严格翻译自: shared.zig FlushValue
// ============================================================================
public enum ZFlushValue <: Int32 {
    NoFlush = 0
    PartialFlush = 1
    /// Z_SYNC_FLUSH requests that inflate() flush as much output as possible to the output buffer
    SyncFlush = 2
    FullFlush = 3
    Finish = 4
    /// Z_BLOCK requests that inflate() stop if and when it gets to the next deflate block boundary
    Block = 5
    /// The Z_TREES option behaves as Z_BLOCK does, but it also returns when the
    /// end of each deflate block header is reached
    Trees = 6
}
