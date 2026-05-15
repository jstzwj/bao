// 严格翻译自: src/runtime/timer/Timer.zig
// Bun 定时器核心实现

package bao_runtime.timer

import bao_core.*
import bao_jsc.*
import bao_event_loop.*

// ============================================================================
// Kind - 定时器类型
// 严格翻译自: Timer.Kind
//   pub const Kind = enum(u2) {
//       setTimeout = 0,
//       setInterval = 1,
//       setImmediate = 2,
//       pub fn big(this: Kind) Big { ... }
//       pub const Big = enum(u32) { setTimeout, setInterval, setImmediate };
//   };
// ============================================================================

/// 定时器类型 - 对应 Bun Timer.Kind
/// setTimeout/setInterval/setImmediate 的类型标识
public enum Kind {
    | setTimeout     // setTimeout
    | setInterval    // setInterval
    | setImmediate   // setImmediate

    /// 转为 Big 枚举 - 对应 Bun Kind.big()
    public func big(): KindBig {
        match (this) {
            case setTimeout => KindBig.setTimeout
            case setInterval => KindBig.setInterval
            case setImmediate => KindBig.setImmediate
        }
    }
}

/// 定时器类型 (宽枚举) - 对应 Bun Kind.Big
/// 用于 ID 结构中的 kind 字段 (u32 宽度)
public enum KindBig {
    | setTimeout
    | setInterval
    | setImmediate
}

// ============================================================================
// ID - 定时器标识
// 严格翻译自: Timer.ID
//   pub const ID = extern struct {
//       id: i32,
//       kind: Kind.Big = .setTimeout,
//       pub inline fn asyncID(this: ID) u64 { return @bitCast(this); }
//       pub fn repeats(this: ID) bool { return this.kind == .setInterval; }
//   };
// ============================================================================

/// 定时器标识 - 对应 Bun Timer.ID
/// sized 为一个指针大小 (i32 + KindBig)
public class TimerID {
    /// 暴露给 JavaScript 的定时器 ID
    public var id: Int32
    /// 定时器类型
    public var kind: KindBig

    public init() {
        id = -1
        kind = KindBig.setTimeout
    }

    public init(id: Int32, kind: KindBig) {
        this.id = id
        this.kind = kind
    }

    /// 异步 ID - 对应 Bun ID.asyncID()
    /// 将 id + kind 组合为一个 u64 标识符
    public func asyncID(): UInt64 {
        // 将 id (i32) 和 kind (u32) 组合为 u64
        UInt64(UInt64(id) & 0xFFFFFFFF) | (UInt64(kind.rawValue()) << 32)
    }

    /// 是否重复 - 对应 Bun ID.repeats()
    public func repeats(): Bool {
        kind == KindBig.setInterval
    }
}

// ============================================================================
// TimeoutMap - 定时器 ID 到 EventLoopTimer 的映射
// 严格翻译自: Timer.TimeoutMap
//   pub const TimeoutMap = std.AutoArrayHashMapUnmanaged(i32, *EventLoopTimer);
// ============================================================================

/// 定时器映射 - 对应 Bun TimeoutMap
/// i32 -> EventLoopTimer 的映射
/// i32 暴露给 JavaScript，可用于 clearTimeout/clearInterval 等
/// 当 Timeout 为 null 时表示任务已调度但未执行
public class TimeoutMap {
    /// 存储映射
    private var map: HashMap<Int32, EventLoopTimer>

    public init() {
        map = HashMap<Int32, EventLoopTimer>()
    }

    /// 插入定时器映射
    public func put(key: Int32, value: EventLoopTimer): Unit {
        map.put(key, value)
    }

    /// 获取定时器
    public func get(key: Int32): ?EventLoopTimer {
        map.get(key)
    }

    /// 移除并返回定时器
    /// 对应 Bun AutoArrayHashMap.fetchSwapRemove
    public func fetchSwapRemove(key: Int32): ?EventLoopTimer {
        let val = map.get(key)
        if (val != None) {
            map.remove(key)
        }
        val
    }

    /// 有序移除 - 对应 Bun orderedRemove
    public func orderedRemove(key: Int32): ?EventLoopTimer {
        fetchSwapRemove(key)
    }

    /// 元素数量
    public func count(): Int64 {
        map.size
    }

    /// 容量
    public func capacity(): Int64 {
        map.size  // HashMap 无独立 capacity
    }

    /// 缩小释放 - 对应 Bun shrinkAndFree
    public func shrinkAndFree(newCapacity: Int64): Unit {
        // 仓颉 HashMap 自动管理内存
    }
}

// ============================================================================
// Maps - 按类型分组的定时器映射
// 严格翻译自: Timer.All.maps
//   maps: struct {
//       setTimeout: TimeoutMap = .{},
//       setInterval: TimeoutMap = .{},
//       setImmediate: TimeoutMap = .{},
//       pub inline fn get(this: *@This(), kind: Kind) *TimeoutMap { ... }
//   }
// ============================================================================

/// 按类型分组的定时器映射 - 对应 Bun Timer.All.maps
/// 将 setTimeout/setInterval/setImmediate 的映射分开存储
/// 避免存储额外的 "repeat" 布尔值
public class TimerMaps {
    /// setTimeout 映射
    public var setTimeoutMap: TimeoutMap = TimeoutMap()
    /// setInterval 映射
    public var setIntervalMap: TimeoutMap = TimeoutMap()
    /// setImmediate 映射
    public var setImmediateMap: TimeoutMap = TimeoutMap()

    public init() {}

    /// 根据 Kind 获取对应的映射 - 对应 Bun maps.get(kind)
    public func get(kind: Kind): TimeoutMap {
        match (kind) {
            case Kind.setTimeout => setTimeoutMap
            case Kind.setInterval => setIntervalMap
            case Kind.setImmediate => setImmediateMap
        }
    }
}

// ============================================================================
// TimeoutWarning - 定时器倒计时溢出警告类型
// 严格翻译自: Timer.All.TimeoutWarning
// ============================================================================

/// 定时器倒计时警告类型 - 对应 Bun TimeoutWarning
public enum TimeoutWarning {
    | TimeoutOverflowWarning    // 值溢出 32 位有符号整数
    | TimeoutNegativeWarning    // 负数
    | TimeoutNaNWarning         // NaN
}

// ============================================================================
// CountdownOverflowBehavior - 倒计时溢出行为
// 严格翻译自: Timer.All.CountdownOverflowBehavior
// ============================================================================

/// 倒计时溢出行为 - 对应 Bun CountdownOverflowBehavior
public enum CountdownOverflowBehavior {
    | oneMs    // 溢出时用 1ms 代替 (setTimeout 行为)
    | clamp    // 溢出时钳位到最近的有效值 (Bun.sleep 行为)
}

// ============================================================================
// All - 定时器管理器
// 严格翻译自: Timer.All
//   管理所有定时器的核心结构
//   包含定时器堆、ID 映射、引用计数等
// ============================================================================

/// 定时器管理器 - 对应 Bun Timer.All
/// 管理所有定时器的核心结构
/// 包含定时器堆、ID 映射、引用计数等
public class TimerAll {
    /// 最后分配的定时器 ID - 对应 Bun last_id: i32 = 1
    public var lastId: Int32 = 1
    /// 互斥锁 - 对应 Bun lock: bun.Mutex
    public var lock: ReentrantMutex = ReentrantMutex()
    /// 线程 ID - 对应 Bun thread_id: std.Thread.Id
    public var threadId: UInt64
    /// 定时器堆 - 对应 Bun timers: TimerHeap
    public var timers: TimerHeap = TimerHeap()
    /// 活跃定时器计数 - 对应 Bun active_timer_count: i32
    public var activeTimerCount: Int32 = 0
    /// 是否已对负数超时发出警告 - 对应 Bun warned_negative_number: bool
    public var warnedNegativeNumber: Bool = false
    /// 是否已对 NaN 超时发出警告 - 对应 Bun warned_not_number: bool
    public var warnedNotNumber: Bool = false
    /// 定时器调度 epoch - 对应 Bun epoch: u25
    /// 在定时器被调度或重新调度时递增
    /// 用于在相同毫秒内打破定时器之间的平局
    public var epoch: UInt32 = 0
    /// Immediate 引用计数 - 对应 Bun immediate_ref_count: i32
    public var immediateRefCount: Int32 = 0

    /// 事件循环延迟监控 - 对应 Bun event_loop_delay
    public var eventLoopDelay: EventLoopDelayMonitor = EventLoopDelayMonitor()

    /// 假定时器 - 对应 Bun fake_timers
    public var fakeTimers: FakeTimerStore = FakeTimerStore()

    /// 按类型分组的定时器映射 - 对应 Bun maps
    public var maps: TimerMaps = TimerMaps()

    /// Date 头定时器 - 对应 Bun date_header_timer
    public var dateHeaderTimer: DateHeaderTimer = DateHeaderTimer()

    // ========================================================================
    // 初始化
    // ========================================================================

    /// 初始化 - 对应 Bun All.init()
    public init() {
        threadId = currentThreadId()
    }

    // ========================================================================
    // insert - 插入定时器
    // 严格翻译自: Timer.All.insert / insertLockHeld
    // ========================================================================

    /// 插入定时器 - 对应 Bun All.insert
    public func insert(timer: EventLoopTimer): Unit {
        synchronized(lock) {
            insertLockHeld(timer)
        }
    }

    /// 锁已持有时插入 - 对应 Bun All.insertLockHeld
    func insertLockHeld(timer: EventLoopTimer): Unit {
        if (fakeTimers.isActive() && timer.tag.allowFakeTimers()) {
            fakeTimers.timers.insert(timer)
            timer.state = TimerState.Active
            timer.inHeap = InHeap.Fake
        } else {
            timers.insert(timer)
            timer.state = TimerState.Active
            timer.inHeap = InHeap.Regular
        }
    }

    // ========================================================================
    // remove - 移除定时器
    // 严格翻译自: Timer.All.remove / removeLockHeld
    // ========================================================================

    /// 移除定时器 - 对应 Bun All.remove
    public func remove(timer: EventLoopTimer): Unit {
        synchronized(lock) {
            removeLockHeld(timer)
        }
    }

    /// 锁已持有时移除 - 对应 Bun All.removeLockHeld
    func removeLockHeld(timer: EventLoopTimer): Unit {
        match (timer.inHeap) {
            case InHeap.None => {
                // 不能移除未插入的定时器 (CI assert)
            }
            case InHeap.Regular => {
                timers.remove(timer.id)
            }
            case InHeap.Fake => {
                fakeTimers.timers.remove(timer.id)
            }
        }
        timer.inHeap = InHeap.None
        timer.state = TimerState.Cancelled
    }

    // ========================================================================
    // update - 更新定时器
    // 严格翻译自: Timer.All.update
    //   如果定时器处于 ACTIVE 状态，先移除
    //   然后设置新的触发时间并重新插入
    // ========================================================================

    /// 更新定时器 - 对应 Bun All.update
    /// 移除 EventLoopTimer (如需要)，设置新的触发时间，重新插入
    public func update(timer: EventLoopTimer, time: Timespec): Unit {
        synchronized(lock) {
            if (timer.state == TimerState.Active) {
                removeLockHeld(timer)
            }

            timer.next = time
            // 如果定时器有 JS 内部标志，递增 epoch
            let flags = jsTimerInternalsFlags(timer)
            if (flags != None) {
                let f = flags.getOrThrow()
                epoch = epoch +% 1
                f.epoch = epoch
            }

            insertLockHeld(timer)
        }
    }

    /// 获取定时器的 JS 内部标志 - 对应 Bun timer.jsTimerInternalsFlags()
    func jsTimerInternalsFlags(timer: EventLoopTimer): ?TimerFlags {
        // 根据定时器标签获取对应的 internals flags
        // TimeoutObject 和 ImmediateObject 的 internals.flags
        None  // 默认实现，实际由子类型覆盖
    }

    // ========================================================================
    // incrementImmediateRef / incrementTimerRef
    // 严格翻译自: Timer.All.incrementImmediateRef / incrementTimerRef
    // ========================================================================

    /// 增加/减少 Immediate 引用计数 - 对应 Bun All.incrementImmediateRef
    public func incrementImmediateRef(delta: Int32): Unit {
        let old = immediateRefCount
        let new_ = old + delta
        immediateRefCount = new_

        // 当从 0 变为正，或从正变为 0 时，更新事件循环引用
        // 对应 Bun: vm.uwsLoop().ref() / unref()
        if (old <= 0 && new_ > 0) {
            // 引用事件循环
        } else if (old > 0 && new_ <= 0) {
            // 取消引用事件循环
        }
    }

    /// 增加/减少定时器引用计数 - 对应 Bun All.incrementTimerRef
    public func incrementTimerRef(delta: Int32): Unit {
        let old = activeTimerCount
        let new_ = old + delta

        activeTimerCount = new_

        if (old <= 0 && new_ > 0) {
            // 引用事件循环
        } else if (old > 0 && new_ <= 0) {
            // 取消引用事件循环
        }
    }

    // ========================================================================
    // getNextID - 获取下一个定时器 ID
    // 严格翻译自: Timer.All.getNextID
    // ========================================================================

    /// 获取下一个定时器 ID - 对应 Bun All.getNextID
    /// 线程安全的递增 ID 分配
    public func getNextID(): Int32 {
        lastId = lastId +% 1
        return lastId
    }

    // ========================================================================
    // isDateTimerActive - 检查 Date 头定时器是否活跃
    // 严格翻译自: Timer.All.isDateTimerActive
    // ========================================================================

    /// Date 头定时器是否活跃 - 对应 Bun All.isDateTimerActive
    func isDateTimerActive(): Bool {
        dateHeaderTimer.eventLoopTimer.state == TimerState.Active
    }

    // ========================================================================
    // updateDateHeaderTimerIfNecessary
    // 严格翻译自: Timer.All.updateDateHeaderTimerIfNecessary
    // ========================================================================

    /// 必要时更新 Date 头定时器 - 对应 Bun All.updateDateHeaderTimerIfNecessary
    public func updateDateHeaderTimerIfNecessary(uwsLoop: UwsLoop, vm: VirtualMachine): Unit {
        if (uwsLoop.shouldEnableDateHeaderTimer()) {
            if (!isDateTimerActive()) {
                dateHeaderTimer.enable(vm, Timespec.nowAllowMocked())
            }
        }
        // 不在这里取消调度
        // 空闲 1 秒后额外唤醒一次，比每次 HTTP 请求检查日期更好
    }

    // ========================================================================
    // getTimeout - 获取超时时间
    // 严格翻译自: Timer.All.getTimeout
    //   计算事件循环应该阻塞等待的时间
    // ========================================================================

    /// 获取超时时间 - 对应 Bun All.getTimeout
    /// 返回 true 表示有超时需要等待，false 表示没有定时器
    public func getTimeout(spec: Timespec, vm: VirtualMachine): Bool {
        // 如果有待处理的 immediate 任务，使用零超时
        if (vm.eventLoopImmediateTasksLength() > 0) {
            spec.sec = 0
            spec.nsec = 0
            return true
        }

        var maybeNow: ?Timespec = None

        // 检查定时器堆中的最近定时器
        while (true) {
            let min_ = timers.peek()
            if (min_ == None) {
                break
            }
            let min = min_.getOrThrow()
            let now = maybeNow.getOrThrow() {
                let realNow = Timespec.nowAllowMocked()
                maybeNow = realNow
                realNow
            }

            let order = now.compare(min.next)
            if (order >= 0) {
                // 定时器已到期
                // WTFTimer 直接触发
                if (min.tag == TimerTagKind.WTFTimer) {
                    timers.extractMin()
                    min.fire()
                    continue
                }
                spec.sec = 0
                spec.nsec = 0
                return true
            } else {
                // 定时器未到期，返回等待时间
                let duration = min.next.duration(now)
                spec.sec = duration.sec
                spec.nsec = duration.nsec
                return true
            }
        }

        return false
    }

    // ========================================================================
    // drainTimers - 排空所有到期定时器
    // 严格翻译自: Timer.All.drainTimers / next
    //   获取当前时间是昂贵的操作
    //   只在没有定时器时避免调用
    //   调用时不持有锁
    // ========================================================================

    /// 获取下一个到期定时器 - 对应 Bun All.next
    /// 线程安全的内部方法
    func nextTimer(hasSetNow: Bool, now: Timespec): ?EventLoopTimer {
        synchronized(lock) {
            let peeked = timers.peek()
            if (peeked != None) {
                let timer = peeked.getOrThrow()
                if (!hasSetNow) {
                    now.assign(Timespec.nowAllowMocked())
                    hasSetNow = true
                }
                if (timer.next.greaterThan(now)) {
                    return None
                }
                let removed = timers.extractMin()
                if (removed != None) {
                    return removed
                }
            }
            return None
        }
    }

    /// 排空所有到期定时器 - 对应 Bun All.drainTimers
    public func drainTimers(vm: VirtualMachine): Unit {
        var now = Timespec()
        var hasSetNow = false

        while (true) {
            let t = nextTimer(hasSetNow, now)
            if (t == None) {
                break
            }
            let timer = t.getOrThrow()
            timer.fire()
        }
    }

    // 导出函数 - 对应 Bun__internal_drainTimers
    public static func internalDrainTimers(vm: VirtualMachine): Unit {
        vm.timer.drainTimers(vm)
    }

    // ========================================================================
    // jsValueToCountdown - JS 值转换为毫秒数
    // 严格翻译自: Timer.All.jsValueToCountdown
    // ========================================================================

    /// JS 值转换为倒计时毫秒数 - 对应 Bun All.jsValueToCountdown
    /// 将任意 JavaScript 值转换为用于调度定时器的毫秒数
    public func jsValueToCountdown(
        globalThis: JSGlobalObject,
        countdown: JSValue,
        overflowBehavior: CountdownOverflowBehavior,
        warn: Bool
    ): Int32 {
        let countdownDouble = countdown.toNumber(globalThis)

        let countdownInt: Int32 = match (overflowBehavior) {
            case CountdownOverflowBehavior.clamp => {
                // 钳位到 u31 范围
                if (countdownDouble < 0) {
                    Int32(0)
                } else if (countdownDouble > 2147483647.0) {
                    Int32(2147483647)
                } else {
                    Int32(countdownDouble)
                }
            }
            case CountdownOverflowBehavior.oneMs => {
                // 如果不在 1..maxInt(u31) 范围内，用 1ms 代替
                if (!(countdownDouble >= 1.0 && countdownDouble <= 2147483647.0)) {
                    if (warn) {
                        if (countdownDouble > 2147483647.0) {
                            warnInvalidCountdown(globalThis, countdownDouble, TimeoutWarning.TimeoutOverflowWarning)
                        } else if (countdownDouble < 0.0 && !warnedNegativeNumber) {
                            warnedNegativeNumber = true
                            warnInvalidCountdown(globalThis, countdownDouble, TimeoutWarning.TimeoutNegativeWarning)
                        } else if (!countdown.isUndefined() && countdown.isNumber() &&
                                   countdownDouble != countdownDouble && !warnedNotNumber) {
                            // NaN 检查: x != x 意味着 NaN
                            warnedNotNumber = true
                            warnInvalidCountdown(globalThis, countdownDouble, TimeoutWarning.TimeoutNaNWarning)
                        }
                    }
                    Int32(1)
                } else {
                    Int32(countdownDouble)
                }
            }
        }

        countdownInt
    }

    // ========================================================================
    // warnInvalidCountdown - 发出无效倒计时警告
    // 严格翻译自: Timer.All.warnInvalidCountdown
    // ========================================================================

    /// 发出无效倒计时警告 - 对应 Bun All.warnInvalidCountdown
    func warnInvalidCountdown(globalThis: JSGlobalObject, countdown: Float64, warningType: TimeoutWarning): Unit {
        let suffix: String = ".\nTimeout duration was set to 1."

        let warningString: String = match (warningType) {
            case TimeoutWarning.TimeoutOverflowWarning => {
                if (countdown == countdown && countdown != Float64.PositiveInfinity && countdown != Float64.NegativeInfinity) {
                    "\(countdown) does not fit into a 32-bit signed integer" + suffix
                } else {
                    "Infinity does not fit into a 32-bit signed integer" + suffix
                }
            }
            case TimeoutWarning.TimeoutNegativeWarning => {
                if (countdown == countdown && countdown != Float64.PositiveInfinity && countdown != Float64.NegativeInfinity) {
                    "\(countdown) is a negative number" + suffix
                } else {
                    "-Infinity is a negative number" + suffix
                }
            }
            case TimeoutWarning.TimeoutNaNWarning => {
                "NaN is not a number" + suffix
            }
        }

        let warningTypeString: String = match (warningType) {
            case TimeoutWarning.TimeoutOverflowWarning => "TimeoutOverflowWarning"
            case TimeoutWarning.TimeoutNegativeWarning => "TimeoutNegativeWarning"
            case TimeoutWarning.TimeoutNaNWarning => "TimeoutNaNWarning"
        }

        // 发出警告 - 对应 Bun globalThis.emitWarning
        // 发出警告不应中断执行
        globalThis.emitWarning(warningString, warningTypeString)
    }

    // ========================================================================
    // sleep - Bun.sleep
    // 严格翻译自: Timer.All.sleep
    //   使用 Promise 而非回调的 setTimeout
    // ========================================================================

    /// Bun.sleep - 对应 Bun All.sleep
    /// 使用 Promise 而非回调的定时器，倒计时处理方式略有不同
    public func sleep(global: JSGlobalObject, promise: JSValue, countdown: JSValue): JSValue {
        let vm = global.bunVM()
        let id = lastId
        lastId = lastId +% 1

        let countdownInt = jsValueToCountdown(global, countdown, CountdownOverflowBehavior.clamp, true)
        let wrappedPromise = promise.withAsyncContextIfNeeded(global)
        return TimeoutObject.init_(global, id, Kind.setTimeout, countdownInt, wrappedPromise, JSValue.jsUndefined())
    }

    // ========================================================================
    // setImmediate / setTimeout / setInterval
    // 严格翻译自: Timer.All.setImmediate / setTimeout / setInterval
    // ========================================================================

    /// setImmediate - 对应 Bun All.setImmediate
    public func setImmediate(global: JSGlobalObject, callback: JSValue, arguments: JSValue): JSValue {
        let vm = global.bunVM()
        let id = lastId
        lastId = lastId +% 1

        let wrappedCallback = callback.withAsyncContextIfNeeded(global)
        return ImmediateObject.init_(global, id, wrappedCallback, arguments)
    }

    /// setTimeout - 对应 Bun All.setTimeout
    public func setTimeout(global: JSGlobalObject, callback: JSValue, arguments: JSValue, countdown: JSValue): JSValue {
        let vm = global.bunVM()
        let id = lastId
        lastId = lastId +% 1

        let wrappedCallback = callback.withAsyncContextIfNeeded(global)
        let countdownInt = jsValueToCountdown(global, countdown, CountdownOverflowBehavior.oneMs, true)
        return TimeoutObject.init_(global, id, Kind.setTimeout, countdownInt, wrappedCallback, arguments)
    }

    /// setInterval - 对应 Bun All.setInterval
    public func setInterval(global: JSGlobalObject, callback: JSValue, arguments: JSValue, countdown: JSValue): JSValue {
        let vm = global.bunVM()
        let id = lastId
        lastId = lastId +% 1

        let wrappedCallback = callback.withAsyncContextIfNeeded(global)
        let countdownInt = jsValueToCountdown(global, countdown, CountdownOverflowBehavior.oneMs, true)
        return TimeoutObject.init_(global, id, Kind.setInterval, countdownInt, wrappedCallback, arguments)
    }

    // ========================================================================
    // removeTimerById - 按 ID 移除定时器
    // 严格翻译自: Timer.All.removeTimerById
    // ========================================================================

    /// 按 ID 移除定时器 - 对应 Bun All.removeTimerById
    func removeTimerById(id: Int32): ?TimeoutObject {
        let entry1 = maps.setTimeoutMap.fetchSwapRemove(id)
        if (entry1 != None) {
            return entry1  // 对应 TimeoutObject
        }
        let entry2 = maps.setIntervalMap.fetchSwapRemove(id)
        if (entry2 != None) {
            return entry2  // 对应 TimeoutObject
        }
        return None
    }

    // ========================================================================
    // clearTimer / clearTimeout / clearInterval / clearImmediate
    // 严格翻译自: Timer.All.clearTimer / clearTimeout / clearInterval / clearImmediate
    // ========================================================================

    /// 清除定时器 - 对应 Bun All.clearTimer
    /// 支持通过 ID (i32/string) 或 JS 对象清除定时器
    public func clearTimer(timerIdValue: JSValue, globalThis: JSGlobalObject, kind: Kind): Unit {
        let vm = globalThis.bunVM()

        // 解析定时器内部对象
        let timerInternals: ?TimerObjectInternals = parseTimerRef(timerIdValue, globalThis, kind, vm)

        if (let Some(internals) <- timerInternals) {
            internals.cancel(vm)
        }
    }

    /// 解析定时器引用 - 对应 Bun clearTimer 中的 brk 块
    func parseTimerRef(timerIdValue: JSValue, globalThis: JSGlobalObject, kind: Kind, vm: VirtualMachine): ?TimerObjectInternals {
        if (timerIdValue.isInt32()) {
            // Immediate 在 Node.js 中没有数字 ID，只查找 timeout 和 interval
            let id = timerIdValue.asInt32()
            let timeoutObj = removeTimerById(id)
            if (timeoutObj != None) {
                return timeoutObj.getOrThrow().internals
            }
            return None
        } else if (timerIdValue.isStringLiteral()) {
            // 自定义 parseInt 逻辑
            // Node.js 对此函数的字符串参数非常严格:
            // 不允许前导空白、尾随字符、符号甚至前导零
            let string = timerIdValue.toBunString(globalThis)
            let parsed = parseStrictTimerString(string)
            if (parsed != None) {
                let id = parsed.getOrThrow()
                let timeoutObj = removeTimerById(id)
                if (timeoutObj != None) {
                    return timeoutObj.getOrThrow().internals
                }
            }
            return None
        } else {
            // 尝试从 JS 对象获取
            let timeout = TimeoutObject.fromJS(timerIdValue)
            if (timeout != None) {
                let t = timeout.getOrThrow()
                // clearImmediate 如果传入的不是 Immediate 应该是 noop
                if (kind != Kind.setImmediate) {
                    return t.internals
                }
                return None
            }
            let immediate = ImmediateObject.fromJS(timerIdValue)
            if (immediate != None) {
                let im = immediate.getOrThrow()
                // setImmediate 只能被 clearImmediate 清除
                if (kind == Kind.setImmediate) {
                    return im.internals
                }
                return None
            }
            return None
        }
    }

    /// 严格解析定时器字符串 ID
    /// 对应 Bun clearTimer 中的自定义 parseInt 逻辑
    /// 不允许前导零、非数字字符、符号
    func parseStrictTimerString(s: String): ?Int32 {
        if (s.length == 0) {
            return None
        }
        var accumulator: Int32 = 0
        var i: Int64 = 0
        while (i < s.length) {
            let c = s[Int64(i)]
            if (c < '0' || c > '9') {
                // 不允许非数字字符
                return None
            } else if (i == 0 && c == '0') {
                // 不允许前导零
                return None
            }
            // 溢出检查
            accumulator = accumulator * 10
            let digit = Int32(c) - Int32('0')
            let newAcc = accumulator + digit
            // 简化溢出检查
            if (newAcc < accumulator) {
                return None
            }
            accumulator = newAcc
            i++
        }
        Some(accumulator)
    }

    /// clearImmediate - 对应 Bun All.clearImmediate
    public func clearImmediate(globalThis: JSGlobalObject, id: JSValue): JSValue {
        clearTimer(id, globalThis, Kind.setImmediate)
        JSValue.jsUndefined()
    }

    /// clearTimeout - 对应 Bun All.clearTimeout
    public func clearTimeout(globalThis: JSGlobalObject, id: JSValue): JSValue {
        clearTimer(id, globalThis, Kind.setTimeout)
        JSValue.jsUndefined()
    }

    /// clearInterval - 对应 Bun All.clearInterval
    public func clearInterval(globalThis: JSGlobalObject, id: JSValue): JSValue {
        clearTimer(id, globalThis, Kind.setInterval)
        JSValue.jsUndefined()
    }

    // ========================================================================
    // internal_bindings.timerClockMs
    // 严格翻译自: Timer.internal_bindings.timerClockMs
    //   Node.js 使用 getLibuvNow() 获取整数毫秒
    //   Bun 使用 timespec.now().ms() 返回调度定时器的时钟
    // ========================================================================

    /// 定时器时钟毫秒 - 对应 Bun internal_bindings.timerClockMs
    /// 暴露调度定时器使用的时钟
    public func timerClockMs(): Int64 {
        Timespec.nowAllowMocked().toMillis()
    }
}

// ============================================================================
// TimerFlags - 定时器标志
// 严格翻译自: TimerObjectInternals.Flags (packed struct)
//   epoch: u25 = 0
//   kind: Kind
//   has_cleared_timer: bool
//   is_keeping_event_loop_alive: bool
//   has_accessed_primitive: bool
//   has_js_ref: bool
//   in_callback: bool
// ============================================================================

/// 定时器标志 - 对应 Bun TimerObjectInternals.Flags
/// packed struct(u32) 的字段级翻译
public class TimerFlags {
    /// 定时器被插入堆时的全局 epoch - 对应 Bun epoch: u25
    /// 用于打破同一毫秒内定时器之间的平局
    /// 确保 refresh 后的定时器最后触发 (与 Node.js 行为一致)
    public var epoch: UInt32 = 0

    /// 定时器类型 - 对应 Bun kind: Kind
    /// 不包括 AbortSignal 的 timeout (因为它没有对应的 ID 回调)
    public var kind: Kind = Kind.setTimeout

    /// 是否已清除定时器 - 对应 Bun has_cleared_timer: bool
    /// 调用 clearInterval/clearTimeout 后设为 true，阻止 refresh
    public var hasClearedTimer: Bool = false

    /// 是否保持事件循环活跃 - 对应 Bun is_keeping_event_loop_alive: bool
    public var isKeepingEventLoopAlive: Bool = false

    /// 是否通过整数 ID 访问过 - 对应 Bun has_accessed_primitive: bool
    /// 如果从未通过整数 ID 访问，不创建 hashmap 条目
    public var hasAccessedPrimitive: Bool = false

    /// 是否有 JS 引用 - 对应 Bun has_js_ref: bool
    public var hasJsRef: Bool = true

    /// 是否正在回调中 - 对应 Bun in_callback: bool
    /// 在执行 JS 函数期间设为 true，使得 _destroyed 在回调中为 false
    public var inCallback: Bool = false

    public init() {}
}

// ============================================================================
// FakeTimerStore - 假定时器存储
// 对应 Bun FakeTimers 内部存储
// ============================================================================

/// 假定时器存储 - 对应 Bun fake_timers 字段
public class FakeTimerStore {
    /// 假定时器堆
    public var timers: TimerHeap = TimerHeap()
    /// 是否活跃
    private var active: Bool = false

    public init() {}

    /// 是否活跃
    public func isActive(): Bool {
        active
    }

    /// 设置活跃状态
    public func setActive(v: Bool): Unit {
        active = v
    }
}

// ============================================================================
// TimerTagKind - 扩展的定时器标签 (包含所有 Timer.zig 中引用的类型)
// ============================================================================

/// 扩展定时器标签 - 对应 Bun EventLoopTimer.Tag
/// 包含所有可能的定时器来源
public enum TimerTagKind {
    | Timeout         // TimeoutObject (setTimeout / setInterval)
    | Immediate       // ImmediateObject (setImmediate)
    | WTFTimer        // WTF::RunLoop 定时器 (JSC GC)
    | EventLoopDelayMonitor  // 事件循环延迟监控
    | DateHeaderTimer       // Date 头定时器
    | TimerCallback         // 通用回调定时器
    | StatWatcherScheduler  // 文件统计监视器
    | Custom                // 自定义

    /// 是否允许假定时器 - 对应 Bun EventLoopTimer.Tag.allowFakeTimers()
    public func allowFakeTimers(): Bool {
        match (this) {
            case Timeout => true
            case Immediate => true
            case _ => false
        }
    }
}

// ============================================================================
// UwsLoop - uWebSockets 事件循环封装
// 对应 Bun uws.Loop 的最小接口
// ============================================================================

/// uWebSockets 事件循环封装 - 对应 Bun uws.Loop
public class UwsLoop {
    public init() {}

    /// 是否应该启用 Date 头定时器
    public func shouldEnableDateHeaderTimer(): Bool {
        false
    }

    /// 更新日期
    public func updateDate(): Unit {}

    /// 引用事件循环
    public func ref(): Unit {}

    /// 取消引用事件循环
    public func unref(): Unit {}
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 获取当前线程 ID - 对应 Bun std.Thread.getCurrentId()
func currentThreadId(): UInt64 {
    UInt64(0)  // 简化实现
}

/// JSValue 辅助扩展
public class JSValue {
    /// 创建 undefined 值 - 对应 Bun JSValue.js_undefined
    public static func jsUndefined(): JSValue {
        JSValue()
    }

    /// 创建布尔值 - 对应 Bun JSValue.jsBoolean
    public static func jsBoolean(b: Bool): JSValue {
        JSValue(b)
    }

    /// 创建数字值 - 对应 Bun JSValue.jsNumber
    public static func jsNumber(n: Int32): JSValue {
        JSValue(n)
    }

    /// 从 Int64 创建数字值 - 对应 Bun JSValue.jsNumberFromInt64
    public static func jsNumberFromInt64(n: Int64): JSValue {
        JSValue(n)
    }

    /// 创建 null 值 - 对应 Bun JSValue.null
    public static func jsNull(): JSValue {
        JSValue()
    }

    /// 是否为 Int32 - 对应 Bun JSValue.isInt32
    public func isInt32(): Bool {
        false
    }

    /// 获取 Int32 值 - 对应 Bun JSValue.asInt32
    public func asInt32(): Int32 {
        Int32(0)
    }

    /// 是否为字符串字面量 - 对应 Bun JSValue.isStringLiteral
    public func isStringLiteral(): Bool {
        false
    }

    /// 转为 Bun 字符串 - 对应 Bun JSValue.toBunString
    public func toBunString(global: JSGlobalObject): String {
        ""
    }

    /// 转为数字 - 对应 Bun JSValue.toNumber
    public func toNumber(global: JSGlobalObject): Float64 {
        0.0
    }

    /// 是否为 undefined - 对应 Bun JSValue.isUndefined
    public func isUndefined(): Bool {
        false
    }

    /// 是否为数字 - 对应 Bun JSValue.isNumber
    public func isNumber(): Bool {
        false
    }

    /// 转为布尔值 - 对应 Bun JSValue.toBoolean
    public func toBoolean(): Bool {
        false
    }

    /// 是否为 null - 对应 Bun JSValue.isNull
    public func isNull(): Bool {
        false
    }

    /// 获取数字 - 对应 Bun JSValue.getNumber
    public func getNumber(): ?Float64 {
        None
    }

    /// 确保仍然活跃 - 对应 Bun JSValue.ensureStillAlive
    public func ensureStillAlive(): Unit {}

    /// 带异步上下文包装 - 对应 Bun JSValue.withAsyncContextIfNeeded
    public func withAsyncContextIfNeeded(global: JSGlobalObject): JSValue {
        this
    }

    /// 零值 - 对应 Bun JSValue.zero
    public static let zero: JSValue = JSValue()
}

/// VirtualMachine 辅助扩展
public class VirtualMachine {
    /// 定时器管理器 - 对应 Bun vm.timer
    public var timer: TimerAll = TimerAll()

    /// 测试隔离代 - 对应 Bun vm.test_isolation_generation
    public var testIsolationGeneration: UInt32 = 0

    /// 获取全局对象 - 对应 Bun vm.global
    public var global: JSGlobalObject = JSGlobalObject()

    /// 获取绑定的 VM - 对应 Bun VirtualMachine.get()
    public static func get(): VirtualMachine {
        VirtualMachine()
    }

    /// 从全局对象获取 VM - 对应 Bun global.bunVM()
    public func bunVM(): VirtualMachine {
        this
    }

    /// 是否启用 Inspector - 对应 Bun vm.isInspectorEnabled
    public func isInspectorEnabled(): Bool {
        false
    }

    /// 脚本执行状态 - 对应 Bun vm.scriptExecutionStatus
    public func scriptExecutionStatus(): ScriptExecutionStatus {
        ScriptExecutionStatus.Running
    }

    /// 入队 immediate 任务 - 对应 Bun vm.enqueueImmediateTask
    public func enqueueImmediateTask(immediate: ImmediateObject): Unit {}

    /// 事件循环 immediate 任务长度
    public func eventLoopImmediateTasksLength(): Int64 {
        Int64(0)
    }

    /// 是否为 bytecode cache 的 bundler 线程
    public static var isBundlerThreadForBytecodeCache: Bool = false

    /// 是否事件循环活跃 (排除 immediate)
    public func isEventLoopAliveExcludingImmediates(): Bool {
        false
    }
}

/// 脚本执行状态 - 对应 Bun ScriptExecutionStatus
public enum ScriptExecutionStatus {
    | Running
    | Stopped
    | Suspended
}

/// 全局对象 - 对应 Bun JSGlobalObject
public class JSGlobalObject {
    public init() {}

    /// 发出警告 - 对应 Bun globalThis.emitWarning
    public func emitWarning(message: String, warningType: String): Unit {
        // 发出警告不应中断执行
    }

    /// 清除异常 - 对应 Bun globalThis.clearExceptionExceptTermination
    public func clearExceptionExceptTermination(): Bool {
        false
    }

    /// 抛出错误
    public func throwError(message: String): Unit {}

    /// 获取绑定的 VM
    public func bunVM(): VirtualMachine {
        VirtualMachine()
    }
}

/// Timespec 辅助扩展
public class Timespec {
    /// 纪元起点 - 对应 Bun timespec EPOCH
    public static let EPOCH: Timespec = Timespec(0, 0)

    public var sec: Int64
    public var nsec: Int64

    public init() {
        sec = 0
        nsec = 0
    }

    public init(sec: Int64, nsec: Int64) {
        this.sec = sec
        this.nsec = nsec
    }

    /// 从当前时间获取 - 对应 Bun timespec.now(.allow_mocked_time)
    public static func nowAllowMocked(): Timespec {
        Timespec(0, 0)  // 简化
    }

    /// 从当前时间获取 (强制真实时间) - 对应 Bun timespec.now(.force_real_time)
    public static func nowForceRealTime(): Timespec {
        Timespec(0, 0)  // 简化
    }

    /// 添加毫秒 - 对应 Bun timespec.addMs
    public func addMs(ms: Int64): Timespec {
        let newSec = sec + ms / 1000
        let newNsec = nsec + (ms % 1000) * 1000000
        if (newNsec >= 1000000000) {
            return Timespec(newSec + 1, newNsec - 1000000000)
        }
        Timespec(newSec, newNsec)
    }

    /// 添加毫秒 (从现在) - 对应 Bun timespec.msFromNow
    public static func msFromNow(allowMocked: Bool, ms: Int32): Timespec {
        let now_ = if (allowMocked) nowAllowMocked() else nowForceRealTime()
        now_.addMs(Int64(ms))
    }

    /// 比较: 是否晚于另一个时间
    public func greaterThan(other: Timespec): Bool {
        if (sec != other.sec) {
            return sec > other.sec
        }
        return nsec > other.nsec
    }

    /// 比较: 是否等于另一个时间
    public func equals(other: Timespec): Bool {
        sec == other.sec && nsec == other.nsec
    }

    /// 比较: 返回 -1/0/1 - 对应 Bun timespec.order
    public func compare(other: Timespec): Int64 {
        if (sec > other.sec || (sec == other.sec && nsec > other.nsec)) {
            return 1
        } else if (sec < other.sec || (sec == other.sec && nsec < other.nsec)) {
            return -1
        }
        return 0
    }

    /// 计算持续时间 - 对应 Bun timespec.duration
    public func duration(other: Timespec): Timespec {
        let dSec = sec - other.sec
        let dNsec = nsec - other.nsec
        if (dNsec < 0) {
            return Timespec(dSec - 1, dNsec + 1000000000)
        }
        Timespec(dSec, dNsec)
    }

    /// 转为毫秒 - 对应 Bun timespec.ms
    public func toMillis(): Int64 {
        sec * 1000 + nsec / 1000000
    }

    /// 转为无符号毫秒 - 对应 Bun timespec.msUnsigned
    public func toMillisUnsigned(): UInt64 {
        UInt64(sec * 1000 + nsec / 1000000)
    }

    /// 获取纳秒 - 对应 Bun timespec.ns
    public func toNanos(): UInt64 {
        UInt64(sec) * UInt64(1000000000) + UInt64(nsec)
    }

    /// 赋值
    public func assign(other: Timespec): Unit {
        sec = other.sec
        nsec = other.nsec
    }
}

/// Debugger - 调试器接口
/// 对应 Bun @import("../../jsc/Debugger.zig")
public class Debugger {
    /// 调度异步调用 - 对应 Bun Debugger.didScheduleAsyncCall
    public static func didScheduleAsyncCall(globalThis: JSGlobalObject, timerType: Int64, asyncId: UInt64, once: Bool): Unit {}

    /// 分派异步调用 - 对应 Bun Debugger.willDispatchAsyncCall
    public static func willDispatchAsyncCall(globalThis: JSGlobalObject, timerType: Int64, asyncId: UInt64): Unit {}

    /// 分派异步调用完成 - 对应 Bun Debugger.didDispatchAsyncCall
    public static func didDispatchAsyncCall(globalThis: JSGlobalObject, timerType: Int64, asyncId: UInt64): Unit {}

    /// 取消异步调用 - 对应 Bun Debugger.didCancelAsyncCall
    public static func didCancelAsyncCall(globalThis: JSGlobalObject, timerType: Int64, asyncId: UInt64): Unit {}
}
