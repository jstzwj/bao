// 严格翻译自: src/runtime/api/bun/spawn/stdio.zig
package bao_runtime

import bao_jsc.*
import bao_core.*
import bao_sys.*

// ============================================================================
// Stdio - 子进程标准输入/输出/错误配置
// 对应 Bun: src/runtime/api/bun/spawn/stdio.zig
// ============================================================================

/// Stdio 表示子进程的标准输入/输出/错误配置
public enum Stdio {
    /// 继承父进程的标准流
    case inherit
    /// 捕获到缓冲区
    case capture(ByteList)
    /// 忽略
    case ignore
    /// 使用文件描述符
    case fd(FD)
    /// dup2 重定向
    case dup2(Dup2Config)
    /// 使用文件路径
    case path(PathLike)
    /// 使用 Blob
    case blob(BlobAny)
    /// 使用 ArrayBuffer
    case array_buffer(ArrayBufferStrong)
    /// 使用内存文件描述符 (Linux)
    case memfd(FD)
    /// 使用管道
    case pipe
    /// IPC 通道
    case ipc
    /// 使用 ReadableStream
    case readable_stream(ReadableStream)

    // ========================================================================
    // Dup2 配置
    // ========================================================================

    public class Dup2Config {
        var out: StdioKind
        var to: StdioKind
    }

    // ========================================================================
    // ToSpawnOptsError - 转换错误
    // ========================================================================

    public enum ToSpawnOptsError {
        case stdin_used_as_out
        case out_used_as_stdin
        case blob_used_as_out
        case uv_pipe(SysError)

        public func toStr(): String {
            return switch (this) {
                case .stdin_used_as_out => "Stdin cannot be used for stdout or stderr"
                case .out_used_as_stdin => "Stdout and stderr cannot be used for stdin"
                case .blob_used_as_out => "Blobs are immutable, and cannot be used for stdout/stderr"
                case .uv_pipe => panic("TODO")
            }
        }

        public func throwJS(globalThis: JsGlobalObject): JsValue {
            return globalThis.throw("\{this.toStr()}")
        }
    }

    // ========================================================================
    // Result - 转换结果
    // ========================================================================

    public enum Result {
        case result(SpawnOptionsStdio)
        case err(ToSpawnOptsError)
    }

    // ========================================================================
    // 方法
    // ========================================================================

    /// 获取字节切片
    public func byteSlice(): Array<UInt8> {
        return switch (this) {
            case .capture(let buf) => buf.slice()
            case .array_buffer(let ab) => ab.array_buffer.byteSlice()
            case .blob(let b) => b.slice()
            else => []
        }
    }

    /// 释放资源
    public func deinit() {
        switch (this) {
            case .array_buffer(let ab) => ab.deinit()
            case .blob(let b) => b.detach()
            case .memfd(let fd) => fd.close()
            case .readable_stream => {
                // ReadableStream 清理由子进程处理
            }
            else => {}
        }
    }

    /// 是否可以使用 memfd (仅 Linux)
    public func canUseMemfd(isSync: Bool, hasMaxBuffer: Bool): Bool {
        if (!Environment.isLinux) { return false }

        return switch (this) {
            case .blob => !this.blob.needsToReadFile()
            case .memfd, .array_buffer => true
            case .pipe => isSync && !hasMaxBuffer
            else => false
        }
    }

    /// 尝试使用 memfd 替代
    public func useMemfd(index: UInt32): Bool {
        if (!Environment.isLinux) { return false }
        if (!Sys.canUseMemfd()) { return false }

        let label = switch (index) {
            case 0 => "spawn_stdio_stdin"
            case 1 => "spawn_stdio_stdout"
            case 2 => "spawn_stdio_stderr"
            else => "spawn_stdio_memory_file"
        }

        let fd = Sys.memfd_create(label, .cross_process).unwrap() catch { return false }

        var remain = this.byteSlice()

        if (remain.len > 0) {
            _ = Sys.ftruncate(fd, Int64(remain.len))
        }

        // 将所有字节写入 memfd
        var written: Int64 = 0
        while (remain.len > 0) {
            switch (Sys.pwrite(fd, remain, written)) {
                case .err(let err) => {
                    if (err.getErrno() == .AGAIN) { continue }
                    Output.debugWarn("Failed to write to memfd: \{err.getErrno()}")
                    fd.close()
                    return false
                }
                case .result(let result) => {
                    if (result == 0) {
                        Output.debugWarn("Failed to write to memfd: EOF")
                        fd.close()
                        return false
                    }
                    written += Int64(result)
                    remain = remain[result..]
                }
            }
        }

        switch (this) {
            case .array_buffer => this.array_buffer.deinit()
            case .blob => this.blob.detach()
            else => {}
        }

        this = Stdio.memfd(fd)
        return true
    }

    /// 转换为 POSIX spawn 选项
    public func toPosix(i: Int32): Result {
        return Result.result(
            switch (this) {
                case .blob(let blob) => {
                    let fd = FD.Stdio.fromInt(i).fd()
                    if (blob.needsToReadFile()) {
                        if (let store = blob.store()) {
                            if (store.data.file.pathlike == .fd) {
                                if (store.data.file.pathlike.fd == fd) {
                                    return SpawnOptionsStdio.inherit()
                                }
                                if (let tag = store.data.file.pathlike.fd.stdioTag()) {
                                    switch (tag) {
                                        case .std_in => {
                                            if (i == 1 || i == 2) {
                                                return Result.err(.stdin_used_as_out)
                                            }
                                        }
                                        case .std_out, .std_err => {
                                            if (i == 0) {
                                                return Result.err(.out_used_as_stdin)
                                            }
                                        }
                                    }
                                }
                                return SpawnOptionsStdio.pipe(store.data.file.pathlike.fd)
                            }
                            return SpawnOptionsStdio.path(store.data.file.pathlike.path.slice())
                        }
                    }
                    if (i == 1 || i == 2) {
                        return Result.err(.blob_used_as_out)
                    }
                    return SpawnOptionsStdio.buffer()
                }
                case .dup2(let dup2) => SpawnOptionsStdio.dup2(dup2.out, dup2.to)
                case .capture, .pipe, .array_buffer, .readable_stream => SpawnOptionsStdio.buffer()
                case .ipc => SpawnOptionsStdio.ipc()
                case .fd(let fd) => SpawnOptionsStdio.pipe(fd)
                case .memfd(let fd) => SpawnOptionsStdio.pipe(fd)
                case .path(let pathlike) => SpawnOptionsStdio.path(pathlike.slice())
                case .inherit => SpawnOptionsStdio.inherit()
                case .ignore => SpawnOptionsStdio.ignore()
            }
        )
    }

    /// 转换为 Windows spawn 选项
    public func toWindows(i: Int32): Result {
        return Result.result(
            switch (this) {
                case .blob(let blob) => {
                    let fd = FD.Stdio.fromInt(i).fd()
                    if (blob.needsToReadFile()) {
                        if (let store = blob.store()) {
                            if (store.data.file.pathlike == .fd) {
                                if (store.data.file.pathlike.fd == fd) {
                                    return SpawnOptionsStdio.inherit()
                                }
                                if (let tag = store.data.file.pathlike.fd.stdioTag()) {
                                    switch (tag) {
                                        case .std_in => {
                                            if (i == 1 || i == 2) {
                                                return Result.err(.stdin_used_as_out)
                                            }
                                        }
                                        case .std_out, .std_err => {
                                            if (i == 0) {
                                                return Result.err(.out_used_as_stdin)
                                            }
                                        }
                                    }
                                }
                                return SpawnOptionsStdio.pipe(store.data.file.pathlike.fd)
                            }
                            return SpawnOptionsStdio.path(store.data.file.pathlike.path.slice())
                        }
                    }
                    if (i == 1 || i == 2) {
                        return Result.err(.blob_used_as_out)
                    }
                    return SpawnOptionsStdio.buffer(createZeroedPipe())
                }
                case .ipc => SpawnOptionsStdio.ipc(createZeroedPipe())
                case .capture, .pipe, .array_buffer, .readable_stream => SpawnOptionsStdio.buffer(createZeroedPipe())
                case .fd(let fd) => SpawnOptionsStdio.pipe(fd)
                case .dup2(let dup2) => SpawnOptionsStdio.dup2(dup2.out, dup2.to)
                case .path(let pathlike) => SpawnOptionsStdio.path(pathlike.slice())
                case .inherit => SpawnOptionsStdio.inherit()
                case .ignore => SpawnOptionsStdio.ignore()
                case .memfd => panic("This should never happen")
            }
        )
    }

    /// 同步模式下的转换
    public func toSync(i: UInt32) {
        // 空的 stdin 管道没有意义
        if (i == 0 && this == .pipe) {
            this = Stdio.ignore()
        }
    }

    /// 根据平台转换为 spawn 选项
    public func asSpawnOption(i: Int32): Result {
        if (Environment.isWindows) {
            return this.toWindows(i)
        } else {
            return this.toPosix(i)
        }
    }

    /// 是否使用管道
    public func isPiped(): Bool {
        return switch (this) {
            case .capture, .array_buffer, .blob, .pipe, .readable_stream => true
            case .ipc => Environment.isWindows
            else => false
        }
    }

    // ========================================================================
    // extract - 从 JS 值提取 Stdio 配置
    // ========================================================================

    /// 从 JS 值提取 Stdio 配置
    public static func extract(outStdio: Stdio, globalThis: JsGlobalObject, i: Int32, value: JsValue, isSync: Bool) {
        if (value == JsValue.zero) { return }
        if (value.isUndefined()) { return }
        if (value.isNull()) {
            outStdio = Stdio.ignore()
            return
        }

        if (value.isString()) {
            let str = try value.getZigString(globalThis)
            if (str.eqlComptime("inherit")) {
                outStdio = Stdio.inherit()
            } else if (str.eqlComptime("ignore")) {
                outStdio = Stdio.ignore()
            } else if (str.eqlComptime("pipe") || str.eqlComptime("overlapped")) {
                outStdio = Stdio.pipe()
            } else if (str.eqlComptime("ipc")) {
                outStdio = Stdio.ipc()
            } else {
                return globalThis.throwInvalidArguments("stdio must be an array of 'inherit', 'pipe', 'ignore', Bun.file(pathOrFd), number, or null")
            }
            return
        } else if (value.isNumber()) {
            let fd = value.asFileDescriptor()
            let fileFd = fd.uv()
            if (fileFd < 0) {
                return globalThis.throwInvalidArguments("file descriptor must be a positive integer")
            }

            if (fileFd >= Int32.maxValue) {
                return globalThis.throwInvalidArguments("file descriptor must be a valid integer, received: \{value}")
            }

            if (let tag = fd.stdioTag()) {
                switch (tag) {
                    case .std_in => {
                        if (i == 1 || i == 2) {
                            return globalThis.throwInvalidArguments("stdin cannot be used for stdout or stderr")
                        }
                        outStdio = Stdio.inherit()
                        return
                    }
                    case .std_out, .std_err => {
                        if (i == 0) {
                            return globalThis.throwInvalidArguments("stdout and stderr cannot be used for stdin")
                        }
                        if (i == 1 && tag == .std_out) {
                            outStdio = Stdio.inherit()
                            return
                        } else if (i == 2 && tag == .std_err) {
                            outStdio = Stdio.inherit()
                            return
                        }
                    }
                }
            }

            outStdio = Stdio.fd(fd)
            return
        } else if (let blob = value.as(Blob)) {
            return outStdio.extractBlob(globalThis, BlobAny.Blob(blob.dupe()), i)
        } else if (let req = value.as(Request)) {
            return extractBodyValue(outStdio, globalThis, i, req.getBodyValue(), isSync)
        } else if (let res = value.as(Response)) {
            return extractBodyValue(outStdio, globalThis, i, res.getBodyValue(), isSync)
        }

        if (let stream = try ReadableStream.fromJS(value, globalThis)) {
            if (let blob = stream.toAnyBlob(globalThis)) {
                return outStdio.extractBlob(globalThis, blob, i)
            }

            let name = switch (i) {
                case 0 => "stdin"
                case 1 => "stdout"
                case 2 => "stderr"
                else => unreachable
            }

            if (isSync) {
                return globalThis.throwInvalidArguments("'\{name}' ReadableStream cannot be used in sync mode")
            }

            if (stream.isDisturbed(globalThis)) {
                return globalThis.ERR(.INVALID_STATE, "'\{name}' ReadableStream has already been used").throw()
            }
            outStdio = Stdio.readable_stream(stream)
            return
        }

        if (let arrayBuffer = value.asArrayBuffer(globalThis)) {
            if (arrayBuffer.byteSlice().len == 0) {
                outStdio = Stdio.ignore()
                return
            }

            outStdio = Stdio.array_buffer(ArrayBufferStrong{
                array_buffer = arrayBuffer,
                held = .create(arrayBuffer.value, globalThis),
            })
            return
        }

        return globalThis.throwInvalidArguments("stdio must be an array of 'inherit', 'ignore', or null")
    }

    /// 从 Blob 提取 Stdio 配置
    public static func extractBlob(stdio: Stdio, globalThis: JsGlobalObject, blob: BlobAny, i: Int32) {
        let fd = FD.Stdio.fromInt(i).fd()

        if (blob.needsToReadFile()) {
            if (let store = blob.store()) {
                if (store.data.file.pathlike == .fd) {
                    if (store.data.file.pathlike.fd == fd) {
                        stdio = Stdio.inherit()
                    } else {
                        if (let tag = FD.Stdio.fromInt(i)) {
                            switch (tag) {
                                case .std_in => {
                                    if (i == 1 || i == 2) {
                                        return globalThis.throwInvalidArguments("stdin cannot be used for stdout or stderr")
                                    }
                                }
                                case .std_out, .std_err => {
                                    if (i == 0) {
                                        return globalThis.throwInvalidArguments("stdout and stderr cannot be used for stdin")
                                    }
                                }
                            }
                        }
                        stdio = Stdio.fd(store.data.file.pathlike.fd)
                    }
                    return
                }
                stdio = Stdio.path(store.data.file.pathlike.path)
                return
            }
        }

        if (i == 1 || i == 2) {
            return globalThis.throwInvalidArguments("Blobs are immutable, and cannot be used for stdout/stderr")
        }

        if (blob.fastSize() == 0) {
            stdio = Stdio.ignore()
            return
        }

        stdio = Stdio.blob(blob)
        return
    }

    /// 从 Body.Value 提取
    static func extractBodyValue(outStdio: Stdio, globalThis: JsGlobalObject, i: Int32, body: BodyValue, isSync: Bool) {
        body.toBlobIfPossible()

        if (let blob = body.tryUseAsAnyBlob()) {
            return outStdio.extractBlob(globalThis, blob, i)
        }

        switch (body) {
            case .Null, .Empty => {
                outStdio = Stdio.ignore()
                return
            }
            case .Used => {
                return globalThis.ERR(.BODY_ALREADY_USED, "Body already used").throw()
            }
            case .Error => {
                return globalThis.throwValue(body.Error.toJS(globalThis))
            }
            case .Blob, .WTFStringImpl, .InternalBlob => unreachable // 上面已处理
            case .Locked => {
                if (isSync) {
                    return globalThis.throwInvalidArguments("ReadableStream cannot be used in sync mode")
                }

                switch (i) {
                    case 0 => {}
                    case 1 => {
                        return globalThis.throwInvalidArguments("ReadableStream cannot be used for stdout yet. For now, do .stdout")
                    }
                    case 2 => {
                        return globalThis.throwInvalidArguments("ReadableStream cannot be used for stderr yet. For now, do .stderr")
                    }
                    else => unreachable
                }

                let streamValue = try body.toReadableStream(globalThis)
                let stream = (try ReadableStream.fromJS(streamValue, globalThis)) ?? {
                    return globalThis.throwInvalidArguments("Failed to create ReadableStream")
                }

                if (stream.isDisturbed(globalThis)) {
                    return globalThis.ERR(.BODY_ALREADY_USED, "ReadableStream has already been used").throw()
                }

                outStdio = Stdio.readable_stream(stream)
            }
        }
        return
    }
}

/// 分配一个零初始化的 uv.Pipe
func createZeroedPipe(): UvPipe {
    return new UvPipe zeroes()
}

// ============================================================================
// 类型别名
// ============================================================================

public typealias StdioKind = StdioKind
public typealias BlobAny = BlobAny
public typealias ArrayBufferStrong = ArrayBufferStrong
public typealias PathLike = PathLike
public typealias ReadableStream = ReadableStream
public typealias SysError = SysError
