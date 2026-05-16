// 严格翻译自: src/zlib_sys/win32.rs + win32.zig
// Windows 平台的 zlib FFI 绑定
// 包含 Windows 特有类型别名和平台差异处理
//
// 注意: Windows 平台使用 LLP64 数据模型 (long 为 4 字节),
// 而 POSIX 平台使用 LP64 数据模型 (long 为 8 字节).
// Bao 的 Cangjie 映射使用 UIntNative/IntNative 自动适配平台.
package bao_zlib_sys

import std.core.*

// ============================================================================
// Windows 特有类型别名
// 严格翻译自: win32.rs / win32.zig - rsize_t, _ino_t, ino_t, _dev_t, dev_t, _off_t, off_t
// ============================================================================
public type WinRsizeT = UIntNative
public type WinInoT = UInt16
public type WinDevT = UInt32
public type WinOffT = IntNative

// ============================================================================
// zlib 标量类型别名 (Windows LLP64)
// 严格翻译自: win32.rs / win32.zig - Byte, Bytef, uInt, uLong, uLongf, voidpf
//
// 重要: zlib (和 zlib-ng 兼容) 将 uLong 定义为 unsigned long —
// 在 Windows LLP64 上为 4 字节. 使用 UIntNative 确保 ABI 兼容.
// ============================================================================
public type WinByte = UInt8
public type WinBytef = UInt8
public type WinUInt = UInt32
public type WinULong = UIntNative
public type WinULongf = UIntNative
public type WinVoidpf = CPointer<Unit>

// ============================================================================
// Windows 平台附加类型
// 严格翻译自: win32.rs / win32.zig - z_size_t, voidpc, voidp
// ============================================================================
public type WinZSizeT = UIntNative
public type WinVoidpc = CPointer<Unit>
public type WinVoidp = CPointer<Unit>

// ============================================================================
// Windows 平台 gzFile 和 gz_header 类型别名
// 严格翻译自: win32.rs / win32.zig
// zlib.cj 中已定义 GzFileS 和 GzHeader, 这里提供 Windows 兼容别名
// ============================================================================
public type WinGzFile = CPointer<GzFileS>
public type WinGzHeader = GzHeader
public type WinGzHeaderP = CPointer<GzHeader>

// ============================================================================
// z_off_t 类型别名 (Windows)
// 严格翻译自: win32.rs / win32.zig - z_off_t
// ============================================================================
public type WinZOffT = IntNative

// ============================================================================
// Windows 平台便捷初始化包装函数
// 严格翻译自: win32.rs / win32.zig 中的 inline 函数
// 与 posix.cj 功能相同, 但作为独立模块以便按平台条件编译
// ============================================================================

/// deflate 初始化 (Windows 简易版)
/// 严格翻译自: win32.zig - deflateInit inline fn
/// 对应 C 宏: deflateInit(strm, level)
public func winDeflateInit(strm: CPointer<ZStream>, level: Int32): Int32 {
    unsafe {
        deflateInit_(
            strm,
            level,
            zlibVersion(),
            Int32(112)
        )
    }
}

/// inflate 初始化 (Windows 简易版)
/// 严格翻译自: win32.zig - inflateInit inline fn
/// 对应 C 宏: inflateInit(strm)
public func winInflateInit(strm: CPointer<ZStream>): Int32 {
    unsafe {
        inflateInit_(
            strm,
            zlibVersion(),
            Int32(112)
        )
    }
}

/// deflate 初始化 (Windows 完整版)
/// 严格翻译自: win32.zig - deflateInit2 inline fn
/// 对应 C 宏: deflateInit2(strm, level, method, windowBits, memLevel, strategy)
public func winDeflateInit2(
    strm: CPointer<ZStream>,
    level: Int32,
    method: Int32,
    windowBits: Int32,
    memLevel: Int32,
    strategy: Int32
): Int32 {
    unsafe {
        deflateInit2_(
            strm,
            level,
            method,
            windowBits,
            memLevel,
            strategy,
            zlibVersion(),
            Int32(112)
        )
    }
}

/// inflate 初始化 (Windows 完整版)
/// 严格翻译自: win32.zig - inflateInit2 inline fn
/// 对应 C 宏: inflateInit2(strm, windowBits)
public func winInflateInit2(
    strm: CPointer<ZStream>,
    windowBits: Int32
): Int32 {
    unsafe {
        inflateInit2_(
            strm,
            windowBits,
            zlibVersion(),
            Int32(112)
        )
    }
}

/// inflateBack 初始化 (Windows)
/// 严格翻译自: win32.zig - inflateBackInit inline fn
/// 对应 C 宏: inflateBackInit(strm, windowBits, window)
public func winInflateBackInit(
    strm: CPointer<ZStream>,
    windowBits: Int32,
    window: CPointer<UInt8>
): Int32 {
    unsafe {
        inflateBackInit_(
            strm,
            windowBits,
            window,
            zlibVersion(),
            Int32(112)
        )
    }
}
