// 翻译自: src/runtime/api/bun/subprocess/SubprocessPipeReader.zig
//   PipeReader — 子进程 stdout/stderr 管道读取器
//   从子进程的 stdout/stderr fd 异步读取数据
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue}
import bao_sys.*

// ============================================================================
// JsNode — JS 节点 (占位)
// ============================================================================

public class JsNode {
    public init() {}
}

// ============================================================================
// PipeReader — 子进程管道读取器
// 翻译自: src/runtime/api/bun/subprocess/SubprocessPipeReader.zig:1-252
//   const PipeReader = @This();
//   从子进程的 stdout/stderr fd 异步读取数据
// ============================================================================

public class PipeReader {
    public var process: ?Subprocess = None
    public var eventLoop: EventLoop = EventLoop()
    public var state: PipeReaderState = PipeReaderState.pending
    public var stdioResult: StdioResult = StdioResult.unavailable
    public var buffer: Array<UInt8> = Array<UInt8>()

    public init() {}

    /// 创建 PipeReader
    /// 翻译自: SubprocessPipeReader.zig:36-51
    ///   pub fn create(event_loop, process, result, limit) -> *PipeReader
    public static func create(eventLoop!: EventLoop, process!: Subprocess, result!: StdioResult, limit!: ?MaxBuf): PipeReader {
        let reader = PipeReader()
        reader.eventLoop = eventLoop
        reader.process = Some(process)
        reader.stdioResult = result
        // 设置 maxbuf 限制
        MaxBuf.addToPipeReader(limit: limit, readerMaxbuf: reader)
        reader
    }

    /// 开始读取
    /// 翻译自: SubprocessPipeReader.zig:58-96
    ///   pub fn start(this, process, event_loop) -> bun.sys.Maybe(void)
    public func start(process!: Subprocess, eventLoop!: EventLoop): Maybe<Unit> {
        this.process = Some(process)
        this.eventLoop = eventLoop
        // TODO(bao-runtime-api): 启动 IO reader
        //   1. this.ref()
        //   2. this.reader.start(this.stdio_result.?, true)
        //   3. 设置 poll flags (socket, nonblocking, pollable)
        SysMaybe<Unit>.Ok(())
    }

    /// 读取所有可用数据
    /// 翻译自: SubprocessPipeReader.zig:53-56
    ///   pub fn readAll(this: *PipeReader) -> void
    public func readAll(): Unit {
        // TODO(bao-runtime-api): 调用 reader.read()
    }

    /// 获取已读取的数据 (转移所有权)
    /// 翻译自: SubprocessPipeReader.zig:122-137
    ///   pub fn toOwnedSlice(this: *PipeReader) -> []u8
    public func toOwnedSlice(): Array<UInt8> {
        // TODO: restore enum pattern matching when associated value destructuring works
        // match (state) { case PipeReaderState.done(bytes) => return bytes case _ => () }
        // 转移 buffer 所有权
        let out = buffer
        buffer = Array<UInt8>()
        return out
    }

    /// 转为 ReadableStream
    /// 翻译自: SubprocessPipeReader.zig:148-168
    ///   pub fn toReadableStream(this, globalObject) -> bun.JSError!jsc.JSValue
    public func toReadableStream(jsGlobalObject!: JsGlobalObject): JsValue {
        // 分离 (释放引用)
        detach()

        // TODO: restore enum pattern matching when associated value destructuring works
        state = PipeReaderState.done(Array<UInt8>())
        return JsValue.jsUndefined()
    }

    /// 转为 Buffer
    /// 翻译自: SubprocessPipeReader.zig:170-180
    ///   pub fn toBuffer(this, globalThis) -> jsc.JSValue
    public func toBuffer(globalThis!: JsGlobalObject): JsValue {
        // TODO: restore enum pattern matching when associated value destructuring works
        state = PipeReaderState.done(Array<UInt8>())
        return JsValue.jsUndefined()
    }

    /// 读取完成回调
    /// 翻译自: SubprocessPipeReader.zig:100-108
    ///   pub fn onReaderDone(this: *PipeReader) -> void
    public func onReaderDone(): Unit {
        let owned = toOwnedSlice()
        state = PipeReaderState.done(owned)
        if (process.isSome()) {
            let proc = process.getOrThrow()
            process = None
            proc.onCloseIO(kind: kind(process: proc))
        }
    }

    /// 读取错误回调
    /// 翻译自: SubprocessPipeReader.zig:182-192
    ///   pub fn onReaderError(this: *PipeReader, err: bun.sys.Error) -> void
    public func onReaderError(err!: SysError): Unit {
        state = PipeReaderState.pipeErr(err)
        if (process.isSome()) {
            let proc = process.getOrThrow()
            process = None
            proc.onCloseIO(kind: kind(process: proc))
        }
    }

    /// 判断是 stdout 还是 stderr
    /// 翻译自: SubprocessPipeReader.zig:110-120
    ///   pub fn kind(reader, process) -> StdioKind
    public func kind(process!: Subprocess): ApiStdioKind {
        // TODO(bao-runtime-api): 通过比较 process.stdout/stderr.pipe 确定
        ApiStdioKind.apiStdout
    }

    /// 分离 (释放引用)
    /// 翻译自: SubprocessPipeReader.zig:31-34
    ///   pub fn detach(this: *PipeReader) -> void
    public func detach(): Unit {
        process = None
    }

    /// 关闭
    /// 翻译自: SubprocessPipeReader.zig:194-202
    ///   pub fn close(this: *PipeReader) -> void
    public func close(): Unit {
        match (state) {
            case PipeReaderState.pending =>
                // TODO(bao-runtime-api): 调用 reader.close()
                state = PipeReaderState.done(Array<UInt8>())
            case _ => ()
        }
    }

    /// 更新引用
    /// 翻译自: SubprocessPipeReader.zig:139-141
    ///   pub fn updateRef(this: *PipeReader, add: bool) -> void
    public func updateRef(add!: Bool): Unit {
        // TODO(bao-runtime-api): 调用 reader.updateRef(add)
    }

    /// 注册 poll 监控
    /// 翻译自: SubprocessPipeReader.zig:143-146
    ///   pub fn watch(this: *PipeReader) -> void
    public func watch(): Unit {
        // TODO(bao-runtime-api): 调用 reader.watch()
    }

    /// 是否有待处理的活动
    /// 翻译自: SubprocessPipeReader.zig:24-29
    ///   pub fn hasPendingActivity(this: *const PipeReader) -> bool
    public func hasPendingActivity(): Bool {
        if (state.isPending()) { return true }
        // TODO(bao-runtime-api): 检查 reader.hasPendingActivity()
        return false
    }

    /// 内存占用
    /// 翻译自: SubprocessPipeReader.zig:20-22
    ///   pub fn memoryCost(this: *const PipeReader) -> usize
    public func memoryCost(): Int {
        // TODO(bao-runtime-api): reader.memoryCost()
        return buffer.size
    }

    /// 释放资源
    /// 翻译自: SubprocessPipeReader.zig:216-238
    ///   fn deinit(this: *PipeReader) -> void
    public func deinit(): Unit {
        // TODO: restore enum pattern matching when associated value destructuring works
        state = PipeReaderState.pending
        // TODO(bao-runtime-api): reader.deinit()
    }
}

/// 类型别名
/// 翻译自: SubprocessPipeReader.zig 尾部
///   pub type SubprocessPipeReader = PipeReader
public type SubprocessPipeReader = PipeReader
