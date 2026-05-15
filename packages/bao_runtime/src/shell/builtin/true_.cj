// true_.cj - true命令
// 对应 Bun: src/runtime/shell/builtin/true.zig
// 严格翻译Bun shell true命令到仓颉

package bao_runtime

import bao_core.*

// ============================================================================
// true命令 - 总是返回退出码0
// ============================================================================

/// true命令
public class TrueCmd {
    /// 启动
    public func start(): Yield {
        return this.bltn().done(0)
    }

    /// 去初始化
    public func deinit() {}

    /// IO写入器数据块回调
    public func onIOWriterChunk(amount: UInt64, err: ?SystemError): Yield {
        return Yield.done
    }

    /// 获取Builtin引用
    public func bltn(): Builtin {
        return Builtin.fromImpl(this, "true")
    }
}
