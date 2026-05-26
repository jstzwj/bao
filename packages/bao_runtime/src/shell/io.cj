// io.cj - IO重定向
// 对应 Bun: src/runtime/shell/IO.zig
// 严格翻译Bun shell IO到仓颉

package bao_runtime.shell

import bao_core.*
import bao_collections.*

// ============================================================================
// IO - 状态节点的标准输入/输出/错误信息载体
// ============================================================================

/// 输入类型联合体 - extracted from IO struct
public enum IOInKind {
    /// 文件描述符读取器
    | fd(IOReader)
    /// 忽略输入
    | ignore

    /// 增加引用
    public func ref(): IOInKind {
        match (this) {
            case fd(reader) =>
                reader.ref()
            case ignore =>
                () // 无操作
        }
        return this
    }

    /// 减少引用
    public func deref() {
        match (this) {
            case fd(reader) =>
                reader.deref()
            case ignore =>
                () // 无操作
        }
    }

    /// 关闭
    public func close() {
        match (this) {
            case fd(reader) =>
                reader.deref()
            case ignore =>
                () // 无操作
        }
    }

    /// 转换为子进程stdio
    public func toSubprocStdio(stdio: Stdio) {
        match (this) {
            case fd(reader) =>
                () // stdio = Stdio.fd(reader.fd)
            case ignore =>
                () // stdio = Stdio.ignore
        }
    }

    /// 内存开销
    public func memoryCost(): UInt64 {
        match (this) {
            case fd(reader) =>
                return reader.memoryCost()
            case ignore =>
                return 0
        }
    }
}

/// 输出类型联合体 - extracted from IO struct
public enum IOOutKind {
    /// 文件描述符写入器
    /// captured非null时，同时写入到缓冲区
    | fd(IOWriter, ?ArrayList<Byte>)
    /// 管道输出（在quiet模式下设置）
    | pipe
    /// 丢弃输出
    | ignore

    /// 内存开销
    public func memoryCost(): UInt64 {
        match (this) {
            case fd(writer, captured) =>
                var cost: UInt64 = writer.memoryCost()
                match (captured) {
                    case Some(capArr) =>
                        cost += UInt64(capArr.size)
                    case None => ()
                }
                return cost
            case pipe =>
                return 0
            case ignore =>
                return 0
        }
    }

    /// 增加引用
    public func ref(): IOOutKind {
        match (this) {
            case fd(writer, _) =>
                writer.ref()
            case pipe => ()
            case ignore => ()
        }
        return this
    }

    /// 减少引用
    public func deref() {
        this.close()
    }

    /// 将格式化错误信息入队
    public func enqueueFmtBltn(ptr: Any, kind: ?BuiltinKind, fmt: String, args: Array<Any>): Yield {
        match (this) {
            case fd(writer, captured) =>
                writer.enqueueFmtBltn(ptr, captured, kind, fmt, args)
            case pipe =>
                return Yield.done
            case ignore =>
                return Yield.done
        }
    }

    /// 关闭
    func close() {
        match (this) {
            case fd(writer, _) =>
                writer.deref()
            case pipe => ()
            case ignore => ()
        }
    }

    /// 转换为子进程stdio
    public func toSubprocStdio(shellio: ?IOWriter): Stdio {
        match (this) {
            case fd(val, captured) =>
                // stub: simplified — Stdio.capture not implemented
                return Stdio.fd(val.fd)
            case pipe =>
                return Stdio.pipe
            case ignore =>
                return Stdio.ignore
        }
    }
}

/// IO结构体
/// 携带状态节点的stdin/stdout/stderr信息
public struct IO {
    /// 标准输入
    public var stdin: IOInKind
    /// 标准输出
    public var stdout: IOOutKind
    /// 标准错误
    public var stderr: IOOutKind

    public init() {
        stdin = IOInKind.ignore
        stdout = IOOutKind.ignore
        stderr = IOOutKind.ignore
    }

    /// 内存开销
    public func memoryCost(): UInt64 {
        var size: UInt64 = 0
        size += this.stdin.memoryCost()
        size += this.stdout.memoryCost()
        size += this.stderr.memoryCost()
        return size
    }

    /// 释放资源
    public func deinit() {
        this.stdin.close()
        this.stdout.close()
        this.stderr.close()
    }

    /// 复制
    public func copy(): IO {
        this.ref()
        return this
    }

    /// 增加引用
    public func ref(): IO {
        this.stdin.ref()
        this.stdout.ref()
        this.stderr.ref()
        return this
    }

    /// 减少引用
    public func deref() {
        this.stdin.deref()
        this.stdout.deref()
        this.stderr.deref()
    }

    /// 转换为子进程stdio数组
    public func toSubprocStdio(stdio: Array<Stdio>, shellio: ShellIO) {
        this.stdin.toSubprocStdio(stdio[0])
        stdio[stdoutNo] = this.stdout.toSubprocStdio(shellio.stdout)
        stdio[stderrNo] = this.stderr.toSubprocStdio(shellio.stderr)
    }
}
