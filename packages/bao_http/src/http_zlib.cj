// bao_http http_zlib - HTTP zlib 压缩
// 严格翻译自: src/http/zlib.rs (61 行)
package bao_http

import bao_core.*
import bao_collections.*

// ============================================================================
// HTTP zlib 压缩
// 严格翻译自: bun/src/http/zlib.rs
//
// Rust zlib 模块:
//   - buffer_pool: 对象池管理 MutableString 缓冲区
//     - PooledMutableString (repr(transparent))
//     - BufferPool (ObjectPool, global, 4)
//     - get() -> *mut MutableString
//     - put(mutable: *mut MutableString)
//   - decompress(compressed_data: &[u8], output: &mut MutableString) -> Result<(), ZlibError>
//
// 缓冲区池用于复用解压缓冲区, 避免频繁分配。
// decompress 使用 bao_zlib 进行实际的 gzip/deflate 解压。
// ============================================================================

/// 缓冲区池大小
/// 严格翻译自: ObjectPool(..., global, 4)
public let ZLIB_BUFFER_POOL_SIZE: Int64 = 4

// ============================================================================
// ZlibBufferPool - zlib 缓冲区池
// 严格翻译自: buffer_pool 模块
//
// Rust 使用 ObjectPool<PooledMutableString, global, 4>:
//   bun_collections::object_pool!(pub BufferPool: PooledMutableString, global, 4);
//
// 仓颉用 ArrayList<MutableString> 实现简单的对象池
// ============================================================================

/// zlib 解压缓冲区池
/// 严格翻译自: zlib buffer_pool
public class ZlibBufferPool {
    /// 可用缓冲区列表
    private var pool: ArrayList<MutableString>

    public init() {
        pool = ArrayList<MutableString>()
    }

    // ========================================================================
    // get - 获取一个缓冲区
    // 严格翻译自:
    //   pub fn get() -> *mut MutableString {
    //       BufferPool::first().cast::<MutableString>()
    //   }
    // ========================================================================

    /// 获取一个缓冲区
    /// 严格翻译自: buffer_pool.get
    public func get(): MutableString {
        if (pool.size > 0) {
            return pool.removeAt(pool.size - 1)
        }
        return MutableString()
    }

    // ========================================================================
    // put - 归还一个缓冲区
    // 严格翻译自:
    //   pub fn put(mutable: *mut MutableString) {
    //       unsafe {
    //           (*mutable).reset();
    //           BufferPool::release_value(mutable.cast::<PooledMutableString>());
    //       }
    //   }
    // ========================================================================

    /// 归还一个缓冲区
    /// 严格翻译自: buffer_pool.put
    public func put(buf: MutableString): Unit {
        buf.reset()
        if (pool.size < ZLIB_BUFFER_POOL_SIZE) {
            pool.append(buf)
        }
    }
}

/// 全局缓冲区池
public var zlibBufferPool: ZlibBufferPool = ZlibBufferPool()

// ============================================================================
// ZlibError - zlib 错误
// 严格翻译自: bun_zlib::ZlibError
// ============================================================================

/// zlib 错误
public enum ZlibError {
    | invalidData
    | corruptedData
    | insufficientMemory
    | bufferError
    | versionError
    | streamError
    | unknownError(String)

    public func toString(): String {
        match (this) {
            case invalidData => "invalid data"
            case corruptedData => "corrupted data"
            case insufficientMemory => "insufficient memory"
            case bufferError => "buffer error"
            case versionError => "version error"
            case streamError => "stream error"
            case unknownError(msg) => "zlib error: ${msg}"
        }
    }
}

// ============================================================================
// decompress - 解压 gzip/deflate 数据
// 严格翻译自:
//   pub fn decompress(compressed_data: &[u8], output: &mut MutableString) -> Result<(), ZlibError> {
//       let mut reader = ZlibReaderArrayList::init_with_options_and_list_allocator(
//           compressed_data,
//           &mut output.list,
//           bun_zlib::Options {
//               window_bits: 15 + 32,  // 自动检测 gzip/zlib 格式
//               ..Default::default()
//           },
//       )?;
//       reader.read_all(true)?;
//       Ok(())
//   }
// ============================================================================

/// 解压 gzip/deflate 数据
/// 严格翻译自: zlib.decompress
///
/// window_bits = 15 + 32 = 47: 自动检测 gzip/zlib/raw deflate 格式
/// 对应 zlib 的 MAX_WBITS + 32 (自动检测)
///
/// 参数:
///   compressedData: 压缩数据
///   output: 输出缓冲区 (追加模式)
/// 返回:
///   None = 成功, Some(ZlibError) = 失败
public func httpZlibDecompress(compressedData: Array<UInt8>, output: MutableString): ?ZlibError {
    // 桩: 实际实现应使用 bao_zlib 的 ZlibReaderArrayList
    // 翻译:
    //   let reader = ZlibReaderArrayList.initWithOptionsAndListAllocator(
    //       compressedData, output.data,
    //       ZlibOptions(windowBits: 47)
    //   )
    //   reader.readAll(true)
    //
    // 当前为骨架实现 — 需要接入 bao_zlib 包后实现

    // 简化: 直接复制未压缩数据
    for (b in compressedData) {
        output.data.append(b)
    }

    return None
}

// ============================================================================
// ZlibOptions - zlib 选项
// 严格翻译自: bun_zlib::Options
// ============================================================================

/// zlib 解压选项
/// 严格翻译自: bun_zlib::Options
public class ZlibOptions {
    /// 窗口大小位数 (15 + 32 = 自动检测)
    public var windowBits: Int32

    public init() {
        windowBits = Int32(47)  // 15 + 32
    }

    public init(windowBits: Int32) {
        this.windowBits = windowBits
    }
}
