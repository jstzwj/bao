// 严格翻译自: src/runtime/api/bun/subprocess/SubprocessPipeReader.zig
package bao_runtime.api

import bao_jsc.*
import bao_core.*
import bao_io.*
import bao_sys.*

// 本地 stub 类型
public class JsNode { public init() {} }

// ============================================================================
// SubprocessPipeReader - 子进程管道读取器
// 对应 Bun: src/runtime/api/bun/subprocess/SubprocessPipeReader.zig
// ============================================================================

/// PipeReader - 子进程输出管道读取器
/// 用于读取子进程的 stdout/stderr
public class PipeReader {
    public var reader: IOReader
    public var process: ?Subprocess
    public var eventLoop: EventLoop
    public var refCount: RefCount
    public var state: PipeReaderState
    public var stdioResult: StdioResult

    /// PipeReaderState - 读取器状态
//    public enum PipeReaderState {
//        | pending
//        | done(Array<UInt8>)
//        | err(SysError)
//    }

    // ========================================================================
    // 创建和启动
    // ========================================================================

    /// 创建 PipeReader
    public static func create(eventLoop!: EventLoop, process!: Subprocess, result!: StdioResult, limit!: ?MaxBuf): PipeReader {
        let reader = PipeReader(
            refCount: RefCount(),
            process: process,
            reader: IOReader(INVALID_FD, PIPE_BUF_SIZE),
            eventLoop: eventLoop,
            stdioResult: result,
            state: PipeReaderState.pending,
        )
        MaxBuf.addToPipeReader(limit, reader)
        reader.reader.setParent(reader)
        return reader
    }

    /// 启动读取
    public func start(process!: Subprocess, eventLoop!: EventLoop): Maybe<Unit> {
        ref()
        this.process = process
        this.eventLoop = eventLoop

        match (reader.start(stdioResult, true)) {
            case err(err) => return Maybe<Unit>.err(err)
            case result =>
                if (Environment.isPosix) {
                    let poll = reader.handle.poll
                    poll.flags.insert(PollFlags.socket)
                    reader.flags.socket = true
                    reader.flags.nonblocking = true
                    reader.flags.pollable = true
                    poll.flags.insert(PollFlags.nonblocking)
                }
                return Maybe<Unit>.success
        }
    }

    // ========================================================================
    // 读取操作
    // ========================================================================

    /// readAll - 读取所有数据
    public func readAll(): Unit {
        if (state.isPending()) {
            reader.read()
        }
    }

    /// toOwnedSlice - 获取拥有的数据切片
    public func toOwnedSlice(): Array<UInt8> {
        match (state) {
            case done(bytes) => return bytes
            case _ =>
                let out = reader.buffer
                reader.buffer = []
                return out
        }
    }

    /// toReadableStream - 转换为可读流
    public func toReadableStream(jsGlobalObject!: JsGlobalObject): JsValue {
        match (state) {
            case pending =>
                let stream = ReadableStream.fromPipe(globalObject, this, reader)
                state = PipeReaderState.done(Array<UInt8>())
                return stream
            case done(bytes) =>
                state = PipeReaderState.done(Array<UInt8>())
                return ReadableStream.fromOwnedSlice(globalObject, bytes, 0)
            case err =>
                let empty = ReadableStream.empty(globalObject)
                return empty
        }
        detach()
    }

    /// toBuffer - 转换为 Buffer
    public func toBuffer(globalThis!: JsGlobalObject): JsValue {
        match (state) {
            case done(bytes) =>
                 state = PipeReaderState.done(Array<UInt8>())
                return MarkedArrayBuffer.fromBytes(bytes, default_allocator, TypedArrayKind.Uint8Array).toNodeBuffer(globalThis)
            case _ => return JsValue.jsUndefined()
        }
    }

    // ========================================================================
    // 回调
    // ========================================================================

    /// onReaderDone - 读取完成回调
    public func onReaderDone(): Unit {
        let owned = toOwnedSlice()
        state = PipeReaderState.done(owned)
        if (let process <- process) {
            this.process = none
            process.onCloseIO(kind(process))
            deref()
        }
    }

    /// onReaderError - 读取错误回调
    public func onReaderError(err!: SysError): Unit {
        state = PipeReaderState.err(err)
        if (let process <- process) {
            this.process = none
            process.onCloseIO(kind(process))
            deref()
        }
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// kind - 确定是 stdout 还是 stderr
    public func kind(process!: Subprocess): ApiStdioKind {
        match (process.stdout) {
            case pipe(pipe) =>
                if (pipe == this) {
                    return ApiStdioKind.stdout
                }
            case _ => ()
        }
        match (process.stderr) {
            case pipe(pipe) =>
                if (pipe == this) {
                    return ApiStdioKind.stderr
                }
            case _ => ()
        }
        fatalError("We should be either stdout or stderr")
    }

    /// detach - 分离
    public func detach(): Unit {
        process = none
        deref()
    }

    /// close - 关闭
    public func close(): Unit {
        match (state) {
            case pending => reader.close()
            case _ => ()
        }
    }

    /// updateRef - 更新引用
    public func updateRef(add!: Bool): Unit {
        reader.updateRef(add)
    }

    /// watch - 监视
    public func watch(): Unit {
        if (!reader.isDone()) {
            reader.watch()
        }
    }

    /// hasPendingActivity - 是否有待处理的活动
    public func hasPendingActivity(): Bool {
        if (state.isPending()) { return true }
        return reader.hasPendingActivity()
    }

    /// memoryCost - 内存开销
    public func memoryCost(): Int {
        return reader.memoryCost()
    }

    /// deinit - 内部释放
    public func deinit(): Unit {
        if (state.isDone()) {
            // 释放数据
        }
        reader.deinit()
        destroy(this)
    }
}
