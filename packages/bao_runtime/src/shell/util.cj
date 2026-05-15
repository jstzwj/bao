// util.cj - Shell工具函数
// 对应 Bun: src/runtime/shell/util.zig
// 严格翻译Bun shell工具函数到仓颉

package bao_runtime

import bao_core.*

// ============================================================================
// Shell工具类型和函数
// ============================================================================

/// 输出类型枚举
public enum OutKind {
    case stdout
    case stderr

    /// 转换为文件描述符
    public func toFd(): FD {
        switch (this) {
            case .stdout =>
                return FD.stdout()
            case .stderr =>
                return FD.stderr()
        }
    }
}

/// 标准IO配置
public typealias Stdio = bao_spawn.Stdio

/// 监视文件描述符类型
public typealias WatchFd = Int32
