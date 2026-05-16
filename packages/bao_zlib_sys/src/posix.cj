// 严格翻译自: src/zlib_sys/posix.rs + posix.zig
// POSIX 平台 (Linux/macOS) 的 zlib FFI 绑定
// 包含 POSIX 特有类型别名、函数指针类型和便捷初始化包装函数
package bao_zlib_sys

import std.core.*

// ============================================================================
// POSIX 特有类型别名
// 严格翻译自: posix.rs - rsize_t, ino_t, dev_t, off_t
// ============================================================================
public type PosixRsizeT = UIntNative
public type PosixInoT = UInt16
public type PosixDevT = UInt32
public type PosixOffT = IntNative

// ============================================================================
// zlib 附加类型别名
// 严格翻译自: posix.rs - z_size_t, voidpc, voidp
// ============================================================================
public type ZSizeT = UIntNative
public type Voidpc = CPointer<Unit>
public type Voidp = CPointer<Unit>

// ============================================================================
// gz_header - gzip 头结构体 (POSIX 版本)
// 严格翻译自: posix.rs - struct_gz_header_s
// 与 zlib.cj 中 GzHeader 功能相同，此为 POSIX 平台别名
// ============================================================================
public type GzHeaderPosix = GzHeader
public type GzHeaderP = CPointer<GzHeader>

// ============================================================================
// 函数指针类型
// 严格翻译自: posix.rs - in_func, out_func
// zlib inflateBack() 使用回调函数
// ============================================================================

/// zlib inflateBack 输入回调函数类型
/// 对应 C: typedef unsigned (*in_func)(void *, unsigned char **)
/// 翻译自: posix.rs - in_func
public type InFunc = CFunc<(CPointer<Unit>, CPointer<CPointer<UInt8>>) -> UInt32>

/// zlib inflateBack 输出回调函数类型
/// 对应 C: typedef int (*out_func)(void *, unsigned char *, unsigned)
/// 翻译自: posix.rs - out_func
public type OutFunc = CFunc<(CPointer<Unit>, CPointer<UInt8>, UInt32) -> Int32>

// ============================================================================
// z_off_t 类型别名
// 严格翻译自: posix.rs / posix.zig - z_off_t
// ============================================================================
public type ZOffT = IntNative

// ============================================================================
// inflateBack FFI 声明 (使用回调函数版本)
// 严格翻译自: posix.rs - inflateBack extern fn
// ============================================================================
foreign func inflateBack(
    strm: CPointer<ZStream>,
    inFn: InFunc,
    inDesc: CPointer<Unit>,
    outFn: OutFunc,
    outDesc: CPointer<Unit>
): Int32

// ============================================================================
// 便捷初始化包装函数
// 严格翻译自: posix.rs - deflate_init, inflate_init, deflate_init2,
//            inflate_init2, inflate_back_init
// 这些函数封装了 zlib 版本检查和结构体大小传递
// ============================================================================

/// deflate 初始化 (简易版)
/// 严格翻译自: posix.rs - deflate_init
/// 对应 C 宏: deflateInit(strm, level)
/// 自动传递 zlibVersion() 和 sizeof(z_stream)
public func deflateInit(strm: CPointer<ZStream>, level: Int32): Int32 {
    unsafe {
        deflateInit_(
            strm,
            level,
            zlibVersion(),
            Int32(112)
        )
    }
}

/// inflate 初始化 (简易版)
/// 严格翻译自: posix.rs - inflate_init
/// 对应 C 宏: inflateInit(strm)
/// 自动传递 zlibVersion() 和 sizeof(z_stream)
public func inflateInit(strm: CPointer<ZStream>): Int32 {
    unsafe {
        inflateInit_(
            strm,
            zlibVersion(),
            Int32(112)
        )
    }
}

/// deflate 初始化 (完整版)
/// 严格翻译自: posix.rs - deflate_init2
/// 对应 C 宏: deflateInit2(strm, level, method, windowBits, memLevel, strategy)
/// 自动传递 zlibVersion() 和 sizeof(z_stream)
public func deflateInit2(
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

/// inflate 初始化 (完整版)
/// 严格翻译自: posix.rs - inflate_init2
/// 对应 C 宏: inflateInit2(strm, windowBits)
/// 自动传递 zlibVersion() 和 sizeof(z_stream)
public func inflateInit2(
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

/// inflateBack 初始化
/// 严格翻译自: posix.rs - inflate_back_init
/// 对应 C 宏: inflateBackInit(strm, windowBits, window)
/// 自动传递 zlibVersion() 和 sizeof(z_stream)
public func inflateBackInit(
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
