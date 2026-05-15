// false_.cj - false命令
// 对应 Bun: src/runtime/shell/builtin/false.zig
// 严格翻译Bun shell false命令到仓颉

package bao_runtime

import bao_core.*

// ============================================================================
// false命令 - 总是返回退出码1
// ============================================================================

/// false命令
public class FalseCmd {
    /// 启动
    public func start(): Yield {
        return this.bltn().done(1)
    }

    /// 去初始化
    public func deinit() {}

    /// IO写入器数据块回调
    public func onIOWriterChunk(amount: UInt64, err: ?SystemError): Yield {
        return Yield.done
    }

    /// 获取Builtin引用
    public func bltn(): Builtin {
        return Builtin.fromImpl(this, "false")
    }
}
