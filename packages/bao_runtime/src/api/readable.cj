// 翻译自: src/runtime/api/bun/subprocess/Readable.zig
//   Readable — 子进程 stdout/stderr 读取端
package bao_runtime.api

import bao_core.Allocator
import bao_jsc.{JsGlobalObject, JsValue}
import bao_sys.*

public type BlobSizeType = Int64

// ============================================================================
// Readable — 子进程 stdout/stderr 读取端
// 翻译自: src/runtime/api/bun/subprocess/Readable.zig:1-177
//   pub const Readable = union(enum) { fd, memfd, pipe, inherit, ignore, closed, buffer }
// ============================================================================

public enum Readable {
    | fd(FD)
    | memfd(FD)
    | pipe(PipeReader)
    | inherit
    | ignore
    | closed
    | buffer(Array<UInt8>)

    /// 内存占用
    /// 翻译自: src/runtime/api/bun/subprocess/Readable.zig:16-22
    ///   pub fn memoryCost(this: *const Readable) -> usize
    public func memoryCost(): Int {
        // TODO: restore match pattern when enum associated value destructuring works
        0
    }

    /// 是否有待处理的活动
    /// 翻译自: src/runtime/api/bun/subprocess/Readable.zig:24-29
    ///   pub fn hasPendingActivity(this: *const Readable) -> bool
    public func hasPendingActivity(): Bool {
        // TODO: restore enum pattern matching when associated value destructuring works
        false
    }

    /// 引用 (防止 GC)
    /// 翻译自: src/runtime/api/bun/subprocess/Readable.zig:31-37
    ///   pub fn ref(this: *Readable) -> void
    public func ref(): Unit {
        // TODO: restore when enum pattern matching works
    }

    /// 取消引用 (允许 GC)
    /// 翻译自: src/runtime/api/bun/subprocess/Readable.zig:39-45
    ///   pub fn unref(this: *Readable) -> void
    public func unref(): Unit {
        // TODO: restore when enum pattern matching works
    }

    /// 从 Stdio 初始化 Readable
    /// 翻译自: src/runtime/api/bun/subprocess/Readable.zig:49-71
    ///   pub fn init(stdio, event_loop, process, result, allocator, max_size, is_sync) -> Readable
    public static func initFunc(
        stdio!: Stdio,
        eventLoop!: EventLoop,
        process!: Subprocess,
        result!: StdioResult,
        allocator!: Allocator,
        maxSize!: MaxBuf,
        isSync!: Bool
    ): Readable {
        match (stdio) {
            case inherit => Readable.inherit
            case fd(fdValue) => Readable.fd(fdValue)
            case memfd(fdValue) => Readable.memfd(fdValue)
            case pipe => Readable.pipe(PipeReader.create(eventLoop: eventLoop, process: process, result: result, limit: Some(maxSize)))
            case capture(_) => Readable.buffer(Array<UInt8>())
            case _ => Readable.ignore
        }
    }

    /// 关闭
    /// 翻译自: src/runtime/api/bun/subprocess/Readable.zig:81-95
    ///   pub fn close(this: *Readable) -> void
    public func close(): Unit {
        // TODO: restore when enum pattern matching works
    }

    /// 转为 JS 值
    /// 翻译自: src/runtime/api/bun/subprocess/Readable.zig:117-145
    ///   pub fn toJS(this, globalThis, exited) -> bun.JSError!JSValue
    public func toJS(globalThis!: JsGlobalObject, exited!: Bool): JsValue {
        // TODO: restore when enum pattern matching works
        JsValue.jsUndefined()
    }

    /// 释放资源
    /// 翻译自: src/runtime/api/bun/subprocess/Readable.zig:97-115
    ///   pub fn finalize(this: *Readable) -> void
    public func finalize(): Unit {
        // TODO: restore when enum pattern matching works
    }

    /// 更新引用
    /// 翻译自: src/runtime/api/bun/subprocess/Readable.zig ref/unref
    public func updateRef(add!: Bool): Unit {
        // TODO: restore when enum pattern matching works
    }
}
