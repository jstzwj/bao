// 严格翻译自: src/paths/path_buffer_pool.rs (Rust 版本)
//   PathBufferPoolT<T> - 路径缓冲区池 (线程本地)
//   PoolGuard<T> - RAII 守卫
//   PoolStorage - 池存储 trait
//   path_buffer_pool / w_path_buffer_pool - 具体池类型
//
// 也参考了 src/paths/path_buffer_pool.zig (Zig 原版):
//   fn PathBufferPoolT(comptime T: type) type
//   使用 ObjectPool<T, null, true, 4> 实现线程本地缓冲区池
//
// Bun 使用线程本地对象池来避免频繁的堆分配 (Windows 上每个缓冲区 64KB)
// 仓颉使用简单的池化结构实现类似语义
package bao_path

import bao_core.*
import bao_collections.*

// ============================================================================
// PathBufferPoolT - 路径缓冲区池 (泛型)
// 严格翻译自: src/paths/path_buffer_pool.rs - PathBufferPoolT<T>
//   pub struct PathBufferPoolT<T: 'static + Default>(PhantomData<T>);
//
// Zig 原版:
//   fn PathBufferPoolT(comptime T: type) type {
//       return struct {
//           const Pool = ObjectPool(T, null, true, 4);
//           pub fn get() *T { ... }
//           pub fn put(buffer: *const T) void { ... }
//           pub fn deleteAll() void { ... }
//       };
//   }
//
// 核心设计:
//   - 每个线程最多保持 4 个缓冲区 (POOL_CAP = 4)
//   - get() 从池中取缓冲区，池空时创建新的
//   - put() 归还缓冲区，池满时丢弃
//   - Rust 版本使用 RAII PoolGuard 自动归还
// ============================================================================

/// 池最大容量 - 对应 Bun POOL_CAP = 4
/// Bun: const POOL_CAP: usize = 4;
/// Windows 上每个缓冲区 64KB, 4 个 = 256KB 栈上内存上限
public let POOL_CAP: Int64 = 4

/// 路径缓冲区池 - 对应 Bun PathBufferPoolT<PathBuffer>
/// Bun 使用线程本地 ObjectPool，仓颉使用简单的 ArrayList 池
public class PathBufferPoolT {
    private var pool: ArrayList<PathBuffer>
    private let maxPoolSize: Int64

    public init() {
        pool = ArrayList<PathBuffer>()
        maxPoolSize = POOL_CAP
    }

    public init(maxSize: Int64) {
        pool = ArrayList<PathBuffer>()
        maxPoolSize = maxSize
    }

    /// 获取一个缓冲区 - 对应 Bun PathBufferPoolT::get()
    /// Rust: pub fn get() -> PoolGuard<T> {
    ///     let buf = T::with_pool(|p| p.borrow_mut().pop()).unwrap_or_else(T::new_boxed);
    ///     PoolGuard { buf: Some(buf) }
    /// }
    ///
    /// Zig: pub fn get() *T {
    ///     return &Pool.get(bun.threadLocalAllocator()).data;
    /// }
    ///
    /// 如果池中有可用缓冲区则复用, 否则创建新的
    public func get(): PathBuffer {
        if (pool.size > 0) {
            let buf = pool[pool.size - 1]
            pool.removeAt(pool.size - 1)
            buf.clear()
            return buf
        }
        return PathBuffer()
    }

    /// 归还缓冲区 - 对应 Bun PathBufferPoolT::put()
    /// Rust: pub fn put(buf: Box<T>) {
    ///     T::with_pool(|p| {
    ///         let mut p = p.borrow_mut();
    ///         if (p.len() < POOL_CAP) { p.push(buf); }
    ///     });
    /// }
    ///
    /// Zig: pub fn put(buffer: *const T) void {
    ///     var node = @fieldParentPtr("data", @constCast(buffer));
    ///     node.release();
    /// }
    public func put(buf: PathBuffer): Unit {
        if (Int64(pool.size) < maxPoolSize) {
            pool.append(buf)
        }
        // 池满时丢弃 - 对应 Rust "else: drop — mimalloc frees it"
    }

    /// 清空所有缓冲区 - 对应 Bun PathBufferPoolT::deleteAll()
    /// Rust: pub fn deleteAll() { T::with_pool(|p| p.borrow_mut().clear()); }
    /// Zig: pub fn deleteAll() void { Pool.deleteAll(); }
    public func deleteAll(): Unit {
        pool.clear()
    }

    /// 当前池中的缓冲区数量
    public func size(): Int64 {
        return pool.size
    }

    /// 池是否为空
    public func isEmpty(): Bool {
        return pool.size == 0
    }
}

// ============================================================================
// PoolGuard - RAII 守卫 (简化版)
// 严格翻译自: src/paths/path_buffer_pool.rs - PoolGuard<T>
//   pub struct PoolGuard<T: PoolStorage> {
//       buf: Option<Box<T>>,
//   }
//   impl<T: PoolStorage> Drop for PoolGuard<T> {
//       fn drop(&mut self) {
//           if let Some(buf) = self.buf.take() {
//               PathBufferPoolT::<T>::put(buf);
//           }
//       }
//   }
//
// 仓颉没有 RAII Drop，使用显式 close() 模式
// ============================================================================

/// RAII 风格的缓冲区守卫 - 对应 Bun PoolGuard
/// 使用时需要在作用域结束时调用 close() 归还缓冲区
public class PoolGuard {
    private var buf: ?PathBuffer
    private let pool: PathBufferPoolT
    private var closed: Bool

    public init(buf: PathBuffer, pool: PathBufferPoolT) {
        this.buf = buf
        this.pool = pool
        this.closed = false
    }

    /// 获取缓冲区引用
    /// 对应 Rust impl Deref for PoolGuard<T>
    public func get(): PathBuffer {
        match (buf) {
            case Some(b) => b
            case None => PathBuffer() // 不应发生
        }
    }

    /// 归还缓冲区到池 - 对应 Rust impl Drop for PoolGuard<T>
    /// 必须在作用域结束时调用
    public func close(): Unit {
        if (!closed) {
            match (buf) {
                case Some(b) =>
                    pool.put(b)
                    buf = None
                    closed = true
                case None => ()
            }
        }
    }

    /// 提取缓冲区 (不归还池)
    /// 对应 Rust: pub fn into_box(mut self) -> Box<T>
    public func intoBuffer(): ?PathBuffer {
        closed = true // 防止 close() 再次归还
        let b = buf
        buf = None
        return b
    }

    /// 是否已关闭
    public func isClosed(): Bool {
        return closed
    }
}

// ============================================================================
// 全局缓冲区池实例
// 严格翻译自: src/paths/path_buffer_pool.rs 中的全局池
//   pub type path_buffer_pool = PathBufferPoolT<PathBuffer>;
//   pub type w_path_buffer_pool = PathBufferPoolT<WPathBuffer>;
//   pub type os_path_buffer_pool = path_buffer_pool; // POSIX
// ============================================================================

/// 全局路径缓冲区池 (POSIX u8 路径) - 对应 Bun path_buffer_pool
/// Bun: pub type path_buffer_pool = PathBufferPoolT<PathBuffer>;
public let globalPathBufferPool: PathBufferPoolT = PathBufferPoolT()

/// 从全局池获取缓冲区 - 对应 Bun path_buffer_pool.get()
public func poolGet(): PathBuffer {
    return globalPathBufferPool.get()
}

/// 归还缓冲区到全局池 - 对应 Bun path_buffer_pool.put()
public func poolPut(buf: PathBuffer): Unit {
    globalPathBufferPool.put(buf)
}

/// 清空全局池 - 对应 Bun path_buffer_pool.deleteAll()
public func poolDeleteAll(): Unit {
    globalPathBufferPool.deleteAll()
}

/// 获取 RAII 守卫 - 对应 Bun PoolGuard
public func poolGetGuard(): PoolGuard {
    return PoolGuard(poolGet(), globalPathBufferPool)
}
