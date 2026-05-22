// 严格翻译自: src/jsc/ScriptExecutionStatus.zig (5行)
// JavaScriptCore 脚本执行状态枚举

package bao_jsc

// ========== ScriptExecutionStatus ==========
// 严格翻译自 ScriptExecutionStatus.zig
// 表示脚本执行的生命周期状态
//
// 原始 Zig 代码:
//   pub const ScriptExecutionStatus = enum(i32) {
//       running = 0,
//       suspended = 1,
//       stopped = 2,
//   };
public enum ScriptExecutionStatus {
    | Running
    | Suspended
    | Stopped
    | None

    public operator func ==(other: ScriptExecutionStatus): Bool {
        match (this) {
            case Running => match (other) { case Running => true case _ => false }
            case Suspended => match (other) { case Suspended => true case _ => false }
            case Stopped => match (other) { case Stopped => true case _ => false }
            case None => match (other) { case None => true case _ => false }
        }
    }

    public operator func !=(other: ScriptExecutionStatus): Bool {
        !(this == other)
    }

    // 是否正在运行
    public func isRunning(): Bool {
        this == Running
    }

    // 是否已暂停
    public func isSuspended(): Bool {
        this == Suspended
    }

    // 是否已停止
    public func isStopped(): Bool {
        this == Stopped
    }
}
