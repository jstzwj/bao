// io.cj - IO重定向
// 对应 Bun: src/runtime/shell/IO.zig
// 严格翻译Bun shell IO到仓颉

package bao_runtime

import bao_core.*
import bao_jsc.*

// ============================================================================
// IO - 状态节点的标准输入/输出/错误信息载体
// ============================================================================

/// IO结构体
/// 携带状态节点的stdin/stdout/stderr信息
public struct IO {
    /// 标准输入
    public var stdin: InKind
    /// 标准输出
    public var stdout: OutKind
    /// 标准错误
    public var stderr: OutKind

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

    // ========================================================================
    // InKind - 输入类型
    // ========================================================================

    /// 输入类型联合体
    public enum InKind {
        /// 文件描述符读取器
        case fd(IOReader)
        /// 忽略输入
        case ignore

        /// 增加引用
        public func ref(): InKind {
            switch (this) {
                case .fd(let reader) =>
                    reader.ref()
                case .ignore =>
                    // 无操作
            }
            return this
        }

        /// 减少引用
        public func deref() {
            switch (this) {
                case .fd(let reader) =>
                    reader.deref()
                case .ignore =>
                    // 无操作
            }
        }

        /// 关闭
        public func close() {
            switch (this) {
                case .fd(let reader) =>
                    reader.deref()
                case .ignore =>
                    // 无操作
            }
        }

        /// 转换为子进程stdio
        public func toSubprocStdio(stdio: Stdio) {
            switch (this) {
                case .fd(let reader) =>
                    // stdio = Stdio.fd(reader.fd)
                case .ignore =>
                    // stdio = Stdio.ignore
            }
        }

        /// 内存开销
        public func memoryCost(): UInt64 {
            switch (this) {
                case .fd(let reader) =>
                    return reader.memoryCost()
                case .ignore =>
                    return 0
            }
        }
    }

    // ========================================================================
    // OutKind - 输出类型
    // ========================================================================

    /// 输出类型联合体
    public enum OutKind {
        /// 文件描述符写入器
        /// captured非null时，同时写入到缓冲区
        case fd(writer: IOWriter, captured: ?ByteList)
        /// 管道输出（在quiet模式下设置）
        case pipe
        /// 丢弃输出
        case ignore

        /// 内存开销
        public func memoryCost(): UInt64 {
            switch (this) {
                case .fd(let writer, let captured) =>
                    var cost: UInt64 = writer.memoryCost()
                    if (let cap = captured) {
                        cost += cap.memoryCost()
                    }
                    return cost
                case .pipe =>
                    return 0
                case .ignore =>
                    return 0
            }
        }

        /// 增加引用
        public func ref(): OutKind {
            switch (this) {
                case .fd(let writer, _) =>
                    writer.ref()
                case .pipe, .ignore =>
                    // 无操作
            }
            return this
        }

        /// 减少引用
        public func deref() {
            this.close()
        }

        /// 将格式化错误信息入队
        public func enqueueFmtBltn(ptr: Any, kind: ?BuiltinKind, fmt: String, args: Array<Any>): Yield {
            switch (this) {
                case .fd(let writer, let captured) =>
                    writer.enqueueFmtBltn(ptr, captured, kind, fmt, args)
                case .pipe, .ignore =>
                    return Yield.done
            }
        }

        /// 关闭
        func close() {
            switch (this) {
                case .fd(let writer, _) =>
                    writer.deref()
                case .pipe, .ignore =>
                    // 无操作
            }
        }

        /// 转换为子进程stdio
        public func toSubprocStdio(shellio: ?IOWriter): Stdio {
            switch (this) {
                case .fd(let val, let captured) =>
                    // 根据是否有captured和fd状态返回对应的stdio
                    if (let cap = captured) {
                        return Stdio.capture(buf: cap)
                    }
                    return Stdio.fd(val.fd)
                case .pipe =>
                    return Stdio.pipe
                case .ignore =>
                    return Stdio.ignore
            }
        }
    }

    /// 转换为子进程stdio数组
    public func toSubprocStdio(stdio: Array<Stdio>, shellio: ShellIO) {
        this.stdin.toSubprocStdio(stdio[0])
        stdio[stdoutNo] = this.stdout.toSubprocStdio(shellio.stdout)
        stdio[stderrNo] = this.stderr.toSubprocStdio(shellio.stderr)
    }
}

/// 标准输出编号
public const stdoutNo: Int64 = 1

/// 标准错误编号
public const stderrNo: Int64 = 2

/// 标准输入编号
public const stdinNo: Int64 = 0
