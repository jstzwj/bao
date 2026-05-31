// 翻译自: src/runtime/api/bun/subprocess/Writable.zig
//   Writable — 子进程 stdin 写入端
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue}
import bao_sys.*

// ============================================================================
// Writable — 子进程 stdin 写入端
// 翻译自: src/runtime/api/bun/subprocess/Writable.zig:1-328
//   pub const Writable = union(enum) { pipe, fd, buffer, memfd, inherit, ignore }
// ============================================================================

public enum Writable {
    | pipe(FileSink)
    | buffer(StaticPipeWriter)
    | fd(FD)
    | memfd(FD)
    | ignore
    | inherit
    | other

    /// 是否有待处理的活动
    /// 翻译自: src/runtime/api/bun/subprocess/Writable.zig:18-26
    ///   pub fn hasPendingActivity(this: *const Writable) -> bool
    public func hasPendingActivity(): Bool {
        match (this) {
            case buffer(_) => true
            case _ => false
        }
    }

    /// 内存占用
    /// 翻译自: src/runtime/api/bun/subprocess/Writable.zig:9-16
    ///   pub fn memoryCost(this: *const Writable) -> usize
    public func memoryCost(): Int {
        // TODO: restore enum pattern matching when associated value destructuring works
        0
    }

    /// 引用
    /// 翻译自: src/runtime/api/bun/subprocess/Writable.zig:28-37
    ///   pub fn ref(this: *Writable) -> void
    public func ref(): Unit {
        match (this) {
            case pipe(pipeVal) => pipeVal.updateRef(add: true)
            case buffer(bufVal) => bufVal.updateRef(add: true)
            case _ => ()
        }
    }

    /// 取消引用
    /// 翻译自: src/runtime/api/bun/subprocess/Writable.zig:39-49
    ///   pub fn unref(this: *Writable) -> void
    public func unref(): Unit {
        match (this) {
            case pipe(pipeVal) => pipeVal.updateRef(add: false)
            case buffer(bufVal) => bufVal.updateRef(add: false)
            case _ => ()
        }
    }

    /// 关闭回调
    /// 翻译自: src/runtime/api/bun/subprocess/Writable.zig:54-78
    ///   pub fn onClose(this: *Writable, _: ?bun.sys.Error) -> void
    public func onClose(err!: SysError): Unit {
        // 当流关闭时需要通知以防止 use-after-free
        match (this) {
            case buffer(bufVal) => bufVal.deref()
            case pipe(pipeVal) => pipeVal.deref()
            case _ => ()
        }
    }

    /// 就绪回调
    /// 翻译自: src/runtime/api/bun/subprocess/Writable.zig:79
    public func onReady(size!: BlobSizeType, totalSize!: BlobSizeType): Unit {}

    /// 开始回调
    /// 翻译自: src/runtime/api/bun/subprocess/Writable.zig:80
    public func onStart(): Unit {}

    /// 从 Stdio 初始化 Writable
    /// 翻译自: src/runtime/api/bun/subprocess/Writable.zig:82-236
    ///   pub fn init(stdio, event_loop, subprocess, result, promise_for_stream) -> !Writable
    public static func initFunc(
        stdio!: Stdio,
        eventLoop!: EventLoop,
        subprocess!: Subprocess,
        result!: StdioResult,
        promiseForStream!: JsValue
    ): Writable {
        match (stdio) {
            case inherit => Writable.inherit
            case fd(fdValue) => Writable.fd(fdValue)
            case memfd(fdValue) => Writable.memfd(fdValue)
            case pipe =>
                // TODO(bao-runtime-api): 创建 FileSink 并启动 writer
                //   1. FileSink.create(eventLoop, result)
                //   2. pipe.writer.start(pipe.fd, true)
                //   3. subprocess.weak_file_sink_stdin_ptr = pipe
                //   4. subprocess.ref()
                Writable.pipe(FileSink())

            case blob(blobValue) =>
                Writable.buffer(StaticPipeWriter.create(
                    eventLoop: eventLoop,
                    subprocess: subprocess,
                    result: result,
                    source: StaticPipeWriterSource.blob(blobValue)
                ))

            case array_buffer(arrayBufferValue) =>
                Writable.buffer(StaticPipeWriter.create(
                    eventLoop: eventLoop,
                    subprocess: subprocess,
                    result: result,
                    source: StaticPipeWriterSource.arrayBuffer(arrayBufferValue)
                ))

            case readable_stream(_) =>
                // ReadableStream 处理方式与 pipe 相同
                Writable.pipe(FileSink())

            case _ => Writable.ignore
        }
    }

    /// 转为 JS 值
    /// 翻译自: src/runtime/api/bun/subprocess/Writable.zig:238-276
    ///   pub fn toJS(this, globalThis, subprocess) -> JSValue
    public func toJS(globalThis!: JsGlobalObject, subprocess!: Subprocess): JsValue {
        match (this) {
            case fd(f) => f.toJS(globalThis: globalThis)
            case pipe(pipeVal) =>
                // TODO(bao-runtime-api): 处理 pipe 到 JS 的转换
                JsValue.jsUndefined()
            case _ => JsValue.jsUndefined()
        }
    }

    /// 释放资源
    /// 翻译自: src/runtime/api/bun/subprocess/Writable.zig:278-307
    ///   pub fn finalize(this: *Writable) -> void
    public func finalize(): Unit {
        // TODO: restore enum pattern matching when associated value destructuring works
    }

    /// 关闭
    /// 翻译自: src/runtime/api/bun/subprocess/Writable.zig:309-327
    ///   pub fn close(this: *Writable) -> void
    public func close(): Unit {
        // TODO: restore enum pattern matching when associated value destructuring works
    }
}
