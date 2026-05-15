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
public enum ScriptExecutionStatus <: Int32 {
    | Running(0)     // 脚本正在执行
    | Suspended(1)   // 脚本已暂停 (如遇到断点或 debugger 语句)
    | Stopped(2)     // 脚本已停止执行

    public init(value: Int32) {
        match (value) {
            case 0 => this = Running
            case 1 => this = Suspended
            case 2 => this = Stopped
            case _ => this = Stopped
        }
    }

    // 是否正在运行
    public func isRunning() -> Bool {
        this == Running
    }

    // 是否已暂停
    public func isSuspended() -> Bool {
        this == Suspended
    }

    // 是否已停止
    public func isStopped() -> Bool {
        this == Stopped
    }
}
