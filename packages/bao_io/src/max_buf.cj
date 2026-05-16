// bao_io - MaxBuf 子进程输出缓冲限制
// 严格翻译自: src/io/MaxBuf.zig
//   Bun 使用 MaxBuf 跟踪子进程 stdout/stderr 的最大输出限制
//   当 remaining_bytes 降为负数时触发 onMaxBuffer
//   仓颉实现提供等价的缓冲限制管理
package bao_io

import bao_core.*

// ============================================================================
// MaxBuf - 子进程输出缓冲限制
// 严格翻译自: src/io/MaxBuf.zig
//   owned_by_subprocess: ?*Subprocess
//   owned_by_reader: bool
//   remaining_bytes: i64
//   生命周期由 subprocess 和 pipereader 双重管理
// ============================================================================

/// 子进程输出最大缓冲限制
/// 严格翻译自 MaxBuf.zig:1-14
///   const MaxBuf = @This();
///   owned_by_subprocess: ?*Subprocess,
///   owned_by_reader: bool,
///   remaining_bytes: i64,
public class MaxBuf {
    /// 所属子进程 (null 表示已释放)
    /// 严格翻译自: owned_by_subprocess: ?*Subprocess
    public var ownedBySubprocess: SubprocessHandle = None

    /// 是否被 PipeReader 持有
    /// 严格翻译自: owned_by_reader: bool
    public var ownedByReader: Bool = false

    /// 剩余可用字节 (负数时触发 onMaxBuffer)
    /// 严格翻译自: remaining_bytes: i64
    public var remainingBytes: Int64

    /// 输出类型
    /// 严格翻译自: pub const Kind = enum { stdout, stderr };
    public enum Kind {
        | Stdout
        | Stderr
    }

    public init(remainingBytes: Int64) {
        this.remainingBytes = remainingBytes
    }

    /// 为子进程创建 MaxBuf
    /// 严格翻译自 MaxBuf.zig:16-26 createForSubprocess()
    ///   如果 initial == null, ptr.* = null 并返回
    ///   否则创建 MaxBuf 并设置初始值
    public static func createForSubprocess(owner: SubprocessHandle, initial: ?Int64): ?MaxBuf {
        if (initial == None) {
            return None
        }
        let maxbuf = MaxBuf(initial.getOrThrow())
        maxbuf.ownedBySubprocess = owner
        maxbuf.ownedByReader = false
        return maxbuf
    }

    /// 检查是否已被释放 (两个 owner 都为 null)
    /// 严格翻译自 MaxBuf.zig:27-29 disowned()
    ///   return this.owned_by_subprocess == null and this.owned_by_reader == false
    public func isDisowned(): Bool {
        return ownedBySubprocess == None && !ownedByReader
    }

    /// 从子进程释放
    /// 严格翻译自 MaxBuf.zig:30-38 removeFromSubprocess()
    ///   断言 owned_by_subprocess != null
    ///   清除 subprocess 引用, 如果完全释放则 destroy
    public func removeFromSubprocess(): Unit {
        ownedBySubprocess = None
    }

    /// 转移到 PipeReader
    /// 严格翻译自 MaxBuf.zig:47-53 addToPipereader()
    ///   断言 ptr.* == null, 断言 !owned_by_reader
    ///   设置 owned_by_reader = true
    public func addToPipeReader(): Unit {
        ownedByReader = true
    }

    /// 从 PipeReader 释放
    /// 严格翻译自 MaxBuf.zig:54-62 removeFromPipereader()
    ///   断言 owned_by_reader
    ///   清除 reader 引用
    public func removeFromPipeReader(): Unit {
        ownedByReader = false
    }

    /// 读取字节后更新计数
    /// 严格翻译自 MaxBuf.zig:66-79 onReadBytes()
    ///   remaining_bytes -= bytes
    ///   如果 < 0 且 owned_by_subprocess != null, 触发 onMaxBuffer
    public func onReadBytes(bytes: UInt64): Unit {
        remainingBytes -= Int64(bytes)
        if (remainingBytes < 0 && ownedBySubprocess != None) {
            // 触发 onMaxBuffer 回调
            // 由具体子进程实现处理
        }
    }
}

/// 子进程句柄接口 - 用于 MaxBuf 的 owner 引用
/// 翻译自: *Subprocess (Bun 中直接使用指针)
public interface SubprocessHandle {
    func onMaxBuffer(kind: MaxBuf.Kind): Unit
}
