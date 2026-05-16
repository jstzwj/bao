// 严格翻译自: src/zlib_sys/shared.rs + shared.zig
package bao_zlib_sys


// ============================================================================
// DataType - zlib 数据类型枚举
// 严格翻译自: shared.rs / shared.zig DataType
// #define Z_BINARY   0
// #define Z_TEXT     1
// #define Z_ASCII    Z_TEXT
// #define Z_UNKNOWN  2
// ============================================================================
public enum ZDataType {
    | Binary
    | Text
    | Unknown
}

// ============================================================================
// ReturnCode - zlib 返回码枚举
// 严格翻译自: shared.rs / shared.zig ReturnCode
// #define Z_OK            0
// #define Z_STREAM_END    1
// #define Z_NEED_DICT     2
// #define Z_ERRNO        (-1)
// #define Z_STREAM_ERROR (-2)
// #define Z_DATA_ERROR   (-3)
// #define Z_MEM_ERROR    (-4)
// #define Z_BUF_ERROR    (-5)
// #define Z_VERSION_ERROR (-6)
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
// 严格翻译自: shared.rs / shared.zig FlushValue
// #define Z_NO_FLUSH      0
// #define Z_PARTIAL_FLUSH 1
// #define Z_SYNC_FLUSH    2
// #define Z_FULL_FLUSH    3
// #define Z_FINISH        4
// #define Z_BLOCK         5
// #define Z_TREES         6
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

// ============================================================================
// zconf.h 标量类型别名
// 严格翻译自: shared.rs - Byte, Bytef, uInt, uLong, uLongf, voidpf
//
// zlib (和 zlib-ng 兼容) 将 uLong 定义为 unsigned long,
// 在 LP64 (POSIX 64-bit) 上为 8 字节, 在 LLP64 (Windows) 上为 4 字节.
// 使用 UIntNative 确保 ABI 兼容.
// ============================================================================
public type ZByte = UInt8
public type ZBytef = UInt8
public type ZUInt = UInt32
public type ZULong = UIntNative
public type ZULongf = UIntNative
public type ZVoidpf = CPointer<Unit>

// ============================================================================
// 分配器函数指针类型
// 严格翻译自: shared.rs / shared.zig - alloc_func, free_func
//
// C 定义:
//   typedef voidpf (*alloc_func)(voidpf opaque, uInt items, uInt size);
//   typedef void   (*free_func) (voidpf opaque, voidpf address);
// ============================================================================
public type ZAllocFunc = CFunc<(CPointer<Unit>, UInt32, UInt32) -> CPointer<Unit>>
public type ZFreeFunc = CFunc<(CPointer<Unit>, CPointer<Unit>) -> Unit>

// ============================================================================
// 分配器函数指针的兼容别名
// 严格翻译自: shared.rs - z_alloc_fn, z_free_fn, z_alloc_func, z_free_func
// 保持下游代码的源码兼容性
// ============================================================================
public type ZAllocFn = ZAllocFunc
public type ZFreeFn = ZFreeFunc

// ============================================================================
// gzFile 不透明句柄类型
// 严格翻译自: shared.rs - gzFile, gzFile_s, struct_gzFile_s
//
// zlib.h 暴露 struct gzFile_s { unsigned have; unsigned char *next; z_off64_t pos; }
// 以便 gzgetc() 宏可以内联快速路径. 其他 API 将 gzFile 视为不透明指针.
// pos 是 z_off64_t — 在 Windows 上为 __int64, 在 LP64 Unix 上为 off64_t —
// 即在各平台上均为 i64.
// ============================================================================
public type GzFile = CPointer<GzFileS>

// ============================================================================
// z_stream 流类型别名
// 严格翻译自: shared.rs - z_stream, z_streamp, struct_z_stream_s, z_stream_s
// ============================================================================
public type ZStreamP = CPointer<ZStream>
