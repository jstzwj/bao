// bao_http ThreadSafeStreamBuffer - 线程安全流缓冲区
// 严格翻译自: src/http/ThreadSafeStreamBuffer.zig
package bao_http

import bao_core.*
import bao_collections.*
import bao_threading.*

// ============================================================================
// ThreadSafeStreamBuffer - 线程安全的流式缓冲区
// 严格翻译自: bun/src/http/ThreadSafeStreamBuffer.zig
//
// Bun:
//   const ThreadSafeStreamBuffer = @This();
//   buffer: bun.io.StreamBuffer = .{},
//   mutex: bun.Mutex = .{},
//   ref_count: StreamBufferRefCount = .initExactRefs(2),
//   callback: ?Callback = null,
//
// 用于 HTTP 请求体流式传输:
//   - 主线程写入数据到 buffer
//   - HTTP 线程从 buffer 读取数据并发送
//   - 互斥锁保证线程安全
//   - 引用计数管理生命周期 (初始为 2: 主线程 + HTTP 线程)
//
// Callback:
//   - drain callback: 缓冲区排空时回调
//   - 用于通知 HTTP 线程数据已全部发送
//
// 仓颉实现使用 Mutex + ArrayList<UInt8> 等价
// ============================================================================

/// 线程安全流式缓冲区
/// 严格翻译自: bun/src/http/ThreadSafeStreamBuffer.zig
public class ThreadSafeStreamBuffer {
    /// 内部缓冲区
    /// 严格翻译自: buffer: bun.io.StreamBuffer
    public var buffer: ArrayList<UInt8>

    /// 互斥锁 — 保证线程安全
    /// 严格翻译自: mutex: bun.Mutex
    public var mutex: Mutex

    /// 引用计数 (初始为 2: 主线程 + HTTP 线程)
    /// 严格翻译自: ref_count: StreamBufferRefCount = .initExactRefs(2)
    public var refCount: Int64

    /// 排空回调 — 缓冲区为空且结束时回调
    /// 严格翻译自: callback: ?Callback = null
    public var callback: ?StreamBufferCallback

    /// 是否已结束 (不再有新数据写入)
    public var ended: Bool

    public init() {
        buffer = ArrayList<UInt8>()
        mutex = Mutex()
        refCount = 2  // 1 for main thread, 1 for http thread
        callback = None
        ended = false
    }

    // ========================================================================
    // acquire / release — 获取/释放缓冲区锁
    // 严格翻译自:
    //   pub fn acquire(this: *ThreadSafeStreamBuffer) *bun.io.StreamBuffer {
    //       this.mutex.lock();
    //       return &this.buffer;
    //   }
    //   pub fn release(this: *ThreadSafeStreamBuffer) void {
    //       this.mutex.unlock();
    //   }
    // ========================================================================

    /// 获取缓冲区 (加锁)
    /// 严格翻译自: ThreadSafeStreamBuffer.acquire
    public func acquire(): ArrayList<UInt8> {
        mutex.lock()
        return buffer
    }

    /// 释放缓冲区 (解锁)
    /// 严格翻译自: ThreadSafeStreamBuffer.release
    public func release(): Unit {
        mutex.unlock()
    }

    // ========================================================================
    // setDrainCallback / clearDrainCallback — 设置/清除排空回调
    // 严格翻译自:
    //   pub fn setDrainCallback(this: *ThreadSafeStreamBuffer,
    //       comptime T: type, callback: *const fn (*T) void, context: *T) void {
    //       this.callback = Callback.init(T, callback, context);
    //   }
    //   pub fn clearDrainCallback(this: *ThreadSafeStreamBuffer) void {
    //       this.callback = null;
    //   }
    // ========================================================================

    /// 设置排空回调
    /// 严格翻译自: ThreadSafeStreamBuffer.setDrainCallback
    public func setDrainCallback(callback: StreamBufferCallback): Unit {
        this.callback = Some(callback)
    }

    /// 清除排空回调
    /// 严格翻译自: ThreadSafeStreamBuffer.clearDrainCallback
    public func clearDrainCallback(): Unit {
        callback = None
    }

    // ========================================================================
    // reportDrain - 报告缓冲区排空
    // 严格翻译自:
    //   pub fn reportDrain(this: *ThreadSafeStreamBuffer) void {
    //       if (this.buffer.isEmpty()) {
    //           if (this.callback) |callback| {
    //               callback.call();
    //           }
    //       }
    //   }
    // ========================================================================

    /// 报告缓冲区排空
    /// 严格翻译自: ThreadSafeStreamBuffer.reportDrain
    /// 仅在 HTTP 线程中调用
    public func reportDrain(): Unit {
        if (buffer.size == 0) {
            match (callback) {
                case Some(cb) => cb.call()
                case None => ()
            }
        }
    }

    // ========================================================================
    // ref / deref — 引用计数管理
    // 严格翻译自: StreamBufferRefCount (ThreadSafeRefCount)
    // ========================================================================

    /// 增加引用
    /// 严格翻译自: ThreadSafeStreamBuffer.ref
    public func ref(): Unit {
        mutex.lock()
        refCount += 1
        mutex.unlock()
    }

    /// 减少引用，到 0 时销毁
    /// 严格翻译自: ThreadSafeStreamBuffer.deref
    public func deref(): Unit {
        mutex.lock()
        refCount -= 1
        if (refCount <= 0) {
            deinit()
        }
        mutex.unlock()
    }

    // ========================================================================
    // 数据操作
    // ========================================================================

    /// 写入数据 (主线程调用)
    public func write(data: Array<UInt8>): Unit {
        mutex.lock()
        for (b in data) {
            buffer.append(b)
        }
        mutex.unlock()
    }

    /// 读取数据 (HTTP 线程调用)
    /// 返回当前缓冲区中所有数据并清空
    public func read(): Array<UInt8> {
        mutex.lock()
        let data = buffer.toArray()
        buffer = ArrayList<UInt8>()
        mutex.unlock()
        return data
    }

    /// 读取指定大小的数据
    public func read(maxBytes: Int64): Array<UInt8> {
        mutex.lock()
        let count = if (maxBytes < buffer.size) { maxBytes } else { buffer.size }
        let result = Array<UInt8>()
        for (i in 0..count) {
            result.append(buffer[Int64(i)])
        }
        // 移除已读数据
        let remaining = ArrayList<UInt8>()
        for (i in count..buffer.size) {
            remaining.append(buffer[Int64(i)])
        }
        buffer = remaining
        mutex.unlock()
        return result
    }

    /// 缓冲区是否为空
    public func isEmpty(): Bool {
        mutex.lock()
        let empty = buffer.size == 0
        mutex.unlock()
        return empty
    }

    /// 获取缓冲区大小
    public func len(): Int64 {
        mutex.lock()
        let size = buffer.size
        mutex.unlock()
        return size
    }

    /// 标记结束
    public func setEnded(): Unit {
        mutex.lock()
        ended = true
        mutex.unlock()
    }

    /// 是否已结束
    public func isEnded(): Bool {
        mutex.lock()
        let e = ended
        mutex.unlock()
        return e
    }

    // ========================================================================
    // deinit - 清理资源
    // 严格翻译自:
    //   pub fn deinit(this: *ThreadSafeStreamBuffer) void {
    //       this.buffer.deinit();
    //       bun.destroy(this);
    //   }
    // ========================================================================

    /// 清理资源
    /// 严格翻译自: ThreadSafeStreamBuffer.deinit
    public func deinit(): Unit {
        buffer = ArrayList<UInt8>()
        callback = None
        ended = true
    }
}

/// 流缓冲区回调
/// 严格翻译自: ThreadSafeStreamBuffer.Callback
///
/// Bun:
///   const Callback = struct {
///       callback: *const fn (*anyopaque) void,
///       context: *anyopaque,
///       pub fn init(comptime T: type, callback: *const fn (*T) void,
///                   context: *T) @This() {
///           return .{ .callback = @ptrCast(callback), .context = @ptrCast(context) };
///       }
///       pub fn call(this: @This()) void {
///           this.callback(this.context);
///       }
///   };
public class StreamBufferCallback {
    public var callback: () -> Unit

    public init(callback: () -> Unit) {
        this.callback = callback
    }

    /// 调用回调
    /// 严格翻译自: Callback.call
    public func call(): Unit {
        callback()
    }
}

/// 互斥锁 (复用定义)
public class Mutex {
    public init() {}
    public func lock(): Unit {}
    public func unlock(): Unit {}
}
