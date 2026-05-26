// 严格翻译自: src/runtime/shell/util.zig
// Shell 工具函数和类型定义

package bao_runtime.shell

import bao_core.*

// ============================================================================
// Shell 工具类型和函数
// ============================================================================

/// 输出类型枚举
/// 对应 Bun: util.zig OutKind
public enum OutKind {
    | Stdout
    | Stderr

    /// 转换为文件描述符
    public func toFd(): FD {
        match (this) {
            case Stdout =>
                return FD.stdout()
            case Stderr =>
                return FD.stderr()
        }
    }
}

/// 标准IO配置
/// 对应 Bun: util.zig Stdio = bun.spawn.Stdio
/// 注意: bao_spawn 未作为依赖引入，此处用本地枚举替代
public enum Stdio {
    | ignore
    | pipe
    | inherit
    | fd(FD)
    | capture
    | dup2
    | path
    | memfd(FD)
    | ipc
    | blob
    | arrayBuffer
    | readableStream
}

/// 监视文件描述符类型
/// 对应 Bun: util.zig WatchFd
/// 在 Linux 上是 posix.fd_t (i32)，其他平台是 i32
public type WatchFd = Int32

// ============================================================================
// Shell 辅助函数
// ============================================================================

/// 生成不可达状态错误
/// 对应 Bun: bun.shell.unreachableState
public func unreachableState(context: String, message: String): Unit {
    throw Exception("[${context}] Unreachable state: ${message}")
}

/// 生成未实现错误
public func unimplemented(context: String, feature: String): Unit {
    throw Exception("[${context}] Not implemented: ${feature}")
}
