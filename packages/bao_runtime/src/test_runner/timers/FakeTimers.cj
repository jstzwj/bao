// FakeTimers.cj - 假定时器
// 严格翻译自 bun/src/runtime/test_runner/timers/FakeTimers.zig

package bao_runtime

// ========== FakeTimers - 假定时器 ==========

/// 假定时器，用于在测试中模拟和控制时间
public class FakeTimers {
    public var now: UInt64 = 0
    public var timers: ArrayList<TimerEntry> = ArrayList<TimerEntry>()
    public var installed: Bool = false

    public init() {}

    /// 定时器条目
    public class TimerEntry {
        public var id: UInt32 = 0
        public var delay: UInt64 = 0
        public var callback: ?JSValue = None
        public var args: Array<JSValue> = Array<JSValue>()
        public var repeats: Bool = false

        public init() {}
    }

    /// 安装假定时器
    public func install(globalThis: JSGlobalObject) {
        installed = true
        // TODO: 替换全局的setTimeout/setInterval等
    }

    /// 卸载假定时器
    public func uninstall(globalThis: JSGlobalObject) {
        installed = false
        // TODO: 恢复原始的定时器函数
    }

    /// 推进时间
    public func advanceTimersByTime(msToAdvance: UInt64) {
        now += msToAdvance
        // TODO: 执行到期的定时器回调
    }

    /// 推进到下一个定时器
    public func advanceTimersToNextTimer(steps: UInt32) {
        // TODO: 实现
    }

    /// 运行所有定时器
    public func runAllTimers() {
        // TODO: 执行所有待处理的定时器
    }

    /// 运行待处理的定时器
    public func runOnlyPendingTimers() {
        // TODO: 只执行当前待处理的定时器
    }

    /// 获取所有定时器数量
    public func getTimerCount(): UInt32 {
        return UInt32(timers.size)
    }

    /// 设置系统时间
    public func setSystemTime(now: UInt64) {
        this.now = now
    }

    /// 获取当前时间
    public func getSystemTime(): UInt64 {
        return now
    }

    /// 清除所有定时器
    public func clearAllTimers() {
        timers.clear()
    }

    /// 定时器函数数量
    public static let timerFnsCount: UInt32 = 8

    /// 将定时器函数放入对象
    public static func putTimersFns(globalThis: JSGlobalObject, jest: JSValue, vi: JSValue) {
        // TODO: 实现 - 添加 useFakeTimers/advanceTimersByTime 等到 jest 和 vi 对象
    }
}
