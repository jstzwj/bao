// Web API Performance 模块
// 对应 Bun: src/runtime/api/bun/performance.zig
// 严格翻译自 Web Performance API
package bao_runtime.web_api

import bao_core.*
import bao_collections.*

// ============================================================================
// PerformanceEntry — 性能条目基类
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/PerformanceEntry
// ============================================================================

/// PerformanceEntryType — 性能条目类型
/// 对应 Web API: PerformanceEntry.entryType
public enum PerformanceEntryType {
    | Mark        // "mark" — PerformanceMark
    | Measure     // "measure" — PerformanceMeasure
    | Navigation  // "navigation" — PerformanceNavigationTiming
    | Resource    // "resource" — PerformanceResourceTiming
    | Paint       // "paint" — PerformancePaintTiming
    | UserTiming  // 自定义用户计时

    public func toString(): String {
        match (this) {
            case Mark => "mark"
            case Measure => "measure"
            case Navigation => "navigation"
            case Resource => "resource"
            case Paint => "paint"
            case UserTiming => "user"
        }
    }
}

/// PerformanceEntry — 性能条目
/// 对应 Web API: PerformanceEntry
public class PerformanceEntry {
    /// 条目名称
    public var name: String
    /// 条目类型
    public var entryType: PerformanceEntryType
    /// 开始时间 (毫秒)
    public var startTime: Float64
    /// 持续时间 (毫秒)
    public var duration: Float64

    public init(name: String, entryType: PerformanceEntryType, startTime: Float64, duration: Float64) {
        this.name = name
        this.entryType = entryType
        this.startTime = startTime
        this.duration = duration
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        obj.set("name", JsValue(BaoString(name)))
        obj.set("entryType", JsValue(BaoString(entryType.toString())))
        obj.set("startTime", JsValue(startTime))
        obj.set("duration", JsValue(duration))

        obj.set("toJSON", JsValue.nativeFunction(JsNativeFunction("toJSON") { _ =>
            let json = JsObject()
            json.set("name", JsValue(BaoString(name)))
            json.set("entryType", JsValue(BaoString(entryType.toString())))
            json.set("startTime", JsValue(startTime))
            json.set("duration", JsValue(duration))
            return JsValue(json)
        }))

        return JsValue(obj)
    }
}

// ============================================================================
// PerformanceMark — 性能标记
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/PerformanceMark
// ============================================================================

/// PerformanceMark — 性能标记 (继承 PerformanceEntry)
/// 对应 Web API: PerformanceMark
public class PerformanceMark extends PerformanceEntry {
    /// 标记的详细信息
    public var detail: JsValue

    public init(name: String, startTime: Float64) {
        super(name, PerformanceEntryType.Mark, startTime, 0.0)
        detail = JsValue.UNDEFINED
    }

    public init(name: String, startTime: Float64, detail: JsValue) {
        super(name, PerformanceEntryType.Mark, startTime, 0.0)
        this.detail = detail
    }

    /// 转为 JsValue
    public func toJsValueMark(): JsValue {
        let base = super.toJsValue()
        match (base.objectData) {
            case Some(obj) => {
                obj.set("detail", detail)
            }
            case None => ()
        }
        return base
    }
}

// ============================================================================
// PerformanceMeasure — 性能度量
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/PerformanceMeasure
// ============================================================================

/// PerformanceMeasure — 性能度量 (继承 PerformanceEntry)
/// 对应 Web API: PerformanceMeasure
public class PerformanceMeasure extends PerformanceEntry {
    /// 度量的详细信息
    public var detail: JsValue

    public init(name: String, startTime: Float64, duration: Float64) {
        super(name, PerformanceEntryType.Measure, startTime, duration)
        detail = JsValue.UNDEFINED
    }

    public init(name: String, startTime: Float64, duration: Float64, detail: JsValue) {
        super(name, PerformanceEntryType.Measure, startTime, duration)
        this.detail = detail
    }

    /// 转为 JsValue
    public func toJsValueMeasure(): JsValue {
        let base = super.toJsValue()
        match (base.objectData) {
            case Some(obj) => {
                obj.set("detail", detail)
            }
            case None => ()
        }
        return base
    }
}

// ============================================================================
// PerformanceObserver — 性能观察者
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/PerformanceObserver
// ============================================================================

/// PerformanceObserver 回调类型
public type PerformanceObserverCallback = (ArrayList<PerformanceEntry>) -> Unit

/// PerformanceObserver — 监听性能条目
/// 对应 Web API: PerformanceObserver
public class PerformanceObserver {
    /// 回调函数
    private var callback: PerformanceObserverCallback
    /// 观察的类型列表
    private var observedTypes: ArrayList<String>
    /// 是否已断开
    private var disconnected: Bool

    public init(callback: PerformanceObserverCallback) {
        this.callback = callback
        observedTypes = ArrayList<String>()
        disconnected = false
    }

    /// 开始观察指定类型
    /// 对应 Web API: observer.observe({ entryTypes: [...] })
    public func observe(entryTypes: ArrayList<String>): Unit {
        for (t in entryTypes) {
            observedTypes.append(t)
        }
        disconnected = false
    }

    /// 观察单个类型
    /// 对应 Web API: observer.observe({ type: "..." })
    public func observe(type: String): Unit {
        observedTypes.append(type)
        disconnected = false
    }

    /// 断开观察
    /// 对应 Web API: observer.disconnect()
    public func disconnect(): Unit {
        disconnected = true
        observedTypes.clear()
    }

    /// 通知新条目
    public func notify(entries: ArrayList<PerformanceEntry>): Unit {
        if (disconnected) {
            return
        }
        // 过滤匹配的条目
        let matched = ArrayList<PerformanceEntry>()
        for (entry in entries) {
            let typeStr = entry.entryType.toString()
            for (observed in observedTypes) {
                if (observed == typeStr) {
                    matched.append(entry)
                    break
                }
            }
        }
        if (matched.size > 0) {
            callback(matched)
        }
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("observe", JsValue.nativeFunction(JsNativeFunction("observe") { args =>
            if (args.size >= 1) {
                match (args[0].objectData) {
                    case Some(obj) => {
                        let typeVal = obj.get("type")
                        if (typeVal.valueType == JsValueType.String) {
                            self.observe(typeVal.stringValue.toString())
                        }
                    }
                    case None => ()
                }
            }
            return JsValue.UNDEFINED
        }))

        obj.set("disconnect", JsValue.nativeFunction(JsNativeFunction("disconnect") { _ =>
            self.disconnect()
            return JsValue.UNDEFINED
        }))

        obj.set("takeRecords", JsValue.nativeFunction(JsNativeFunction("takeRecords") { _ =>
            // 简化: 返回空数组
            return JsValue.emptyArray()
        }))

        return JsValue(obj)
    }

    /// 静态方法: supportedEntryTypes
    public static func supportedEntryTypes(): ArrayList<String> {
        let types = ArrayList<String>()
        types.append("mark")
        types.append("measure")
        types.append("navigation")
        types.append("resource")
        types.append("paint")
        return types
    }
}

// ============================================================================
// Performance — 性能 API
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/Performance
// 对应 Bun: src/runtime/api/bun/performance.zig
// ============================================================================

/// Performance — 性能监控接口
/// 对应 Web API: Performance
/// 对应 Bun: performance 全局对象
public class Performance extends EventTarget {
    /// 性能条目列表
    private var entries: ArrayList<PerformanceEntry>
    /// 时间原点 (进程启动时间)
    public var timeOrigin: Float64
    /// 已注册的观察者
    private var observers: ArrayList<PerformanceObserver>

    public init() {
        super()
        entries = ArrayList<PerformanceEntry>()
        timeOrigin = currentTimeMillis()
        observers = ArrayList<PerformanceObserver>()
    }

    /// 获取从 timeOrigin 到现在的高精度时间戳 (毫秒)
    /// 对应 Web API: performance.now()
    public func now(): Float64 {
        return currentTimeMillis() - timeOrigin
    }

    /// 创建标记
    /// 对应 Web API: performance.mark(name)
    public func mark(name: String): PerformanceMark {
        let mark = PerformanceMark(name, now())
        entries.append(mark)
        notifyObservers(mark)
        return mark
    }

    /// 创建标记 (带选项)
    /// 对应 Web API: performance.mark(name, { detail, startTime })
    public func mark(name: String, detail: JsValue, startTime: Float64): PerformanceMark {
        let mark = PerformanceMark(name, startTime, detail)
        entries.append(mark)
        notifyObservers(mark)
        return mark
    }

    /// 创建度量
    /// 对应 Web API: performance.measure(name, startMark, endMark)
    public func measure(name: String, startMark: String, endMark: String): ?PerformanceMeasure {
        let start = findMarkTime(startMark)
        let end = findMarkTime(endMark)
        match (start) {
            case Some(s) => {
                let e = match (end) {
                    case Some(v) => v
                    case None => now()
                }
                let duration = e - s
                let measure = PerformanceMeasure(name, s, duration)
                entries.append(measure)
                notifyObservers(measure)
                return Some(measure)
            }
            case None => return None
        }
    }

    /// 创建度量 (指定开始/结束时间)
    /// 对应 Web API: performance.measure(name, { start, end })
    public func measure(name: String, start: Float64, end: Float64): PerformanceMeasure {
        let duration = end - start
        let measure = PerformanceMeasure(name, start, duration)
        entries.append(measure)
        notifyObservers(measure)
        return measure
    }

    /// 清除指定类型的性能条目
    /// 对应 Web API: performance.clearMarks(name) / clearMeasures(name)
    public func clearMarks(name: String): Unit {
        if (name.length == 0) {
            // 清除所有 mark
            let newArr = ArrayList<PerformanceEntry>()
            for (entry in entries) {
                if (entry.entryType != PerformanceEntryType.Mark) {
                    newArr.append(entry)
                }
            }
            entries = newArr
        } else {
            let newArr = ArrayList<PerformanceEntry>()
            for (entry in entries) {
                if (entry.entryType == PerformanceEntryType.Mark && entry.name == name) {
                    continue
                }
                newArr.append(entry)
            }
            entries = newArr
        }
    }

    /// 清除所有 measure
    /// 对应 Web API: performance.clearMeasures(name)
    public func clearMeasures(name: String): Unit {
        if (name.length == 0) {
            let newArr = ArrayList<PerformanceEntry>()
            for (entry in entries) {
                if (entry.entryType != PerformanceEntryType.Measure) {
                    newArr.append(entry)
                }
            }
            entries = newArr
        } else {
            let newArr = ArrayList<PerformanceEntry>()
            for (entry in entries) {
                if (entry.entryType == PerformanceEntryType.Measure && entry.name == name) {
                    continue
                }
                newArr.append(entry)
            }
            entries = newArr
        }
    }

    /// 获取所有性能条目
    /// 对应 Web API: performance.getEntries()
    public func getEntries(): ArrayList<PerformanceEntry> {
        return ArrayList<PerformanceEntry>(entries)
    }

    /// 获取指定类型的性能条目
    /// 对应 Web API: performance.getEntriesByType(type)
    public func getEntriesByType(type: String): ArrayList<PerformanceEntry> {
        let result = ArrayList<PerformanceEntry>()
        let targetType = parseEntryType(type)
        match (targetType) {
            case Some(t) => {
                for (entry in entries) {
                    if (entry.entryType == t) {
                        result.append(entry)
                    }
                }
            }
            case None => ()
        }
        return result
    }

    /// 获取指定名称的性能条目
    /// 对应 Web API: performance.getEntriesByName(name)
    public func getEntriesByName(name: String): ArrayList<PerformanceEntry> {
        let result = ArrayList<PerformanceEntry>()
        for (entry in entries) {
            if (entry.name == name) {
                result.append(entry)
            }
        }
        return result
    }

    /// 获取指定名称和类型的性能条目
    /// 对应 Web API: performance.getEntriesByName(name, type)
    public func getEntriesByName(name: String, type: String): ArrayList<PerformanceEntry> {
        let result = ArrayList<PerformanceEntry>()
        let targetType = parseEntryType(type)
        match (targetType) {
            case Some(t) => {
                for (entry in entries) {
                    if (entry.name == name && entry.entryType == t) {
                        result.append(entry)
                    }
                }
            }
            case None => ()
        }
        return result
    }

    /// 注册观察者
    public func addObserver(observer: PerformanceObserver): Unit {
        observers.append(observer)
    }

    /// 通知观察者
    private func notifyObservers(entry: PerformanceEntry): Unit {
        let list = ArrayList<PerformanceEntry>()
        list.append(entry)
        for (observer in observers) {
            observer.notify(list)
        }
    }

    /// 查找标记的时间
    private func findMarkTime(name: String): ?Float64 {
        for (entry in entries) {
            if (entry.name == name) {
                return Some(entry.startTime)
            }
        }
        return None
    }

    /// 解析条目类型字符串
    private static func parseEntryType(type: String): ?PerformanceEntryType {
        match (type) {
            case "mark" => Some(PerformanceEntryType.Mark)
            case "measure" => Some(PerformanceEntryType.Measure)
            case "navigation" => Some(PerformanceEntryType.Navigation)
            case "resource" => Some(PerformanceEntryType.Resource)
            case "paint" => Some(PerformanceEntryType.Paint)
            case _ => None
        }
    }

    /// 转为 JsValue
    public func toJsValuePerformance(): JsValue {
        let base = super.toJsValue()
        match (base.objectData) {
            case Some(obj) => {
                let self = this

                obj.set("timeOrigin", JsValue(self.timeOrigin))

                obj.set("now", JsValue.nativeFunction(JsNativeFunction("now") { _ =>
                    return JsValue(self.now())
                }))

                obj.set("mark", JsValue.nativeFunction(JsNativeFunction("mark") { args =>
                    let name = if (args.size >= 1) { Interpreter.jsToString(args[0]) } else { "" }
                    let mark = self.mark(name)
                    return mark.toJsValueMark()
                }))

                obj.set("measure", JsValue.nativeFunction(JsNativeFunction("measure") { args =>
                    let name = if (args.size >= 1) { Interpreter.jsToString(args[0]) } else { "" }
                    let measure = if (args.size >= 3) {
                        let start = Interpreter.jsToString(args[1])
                        let end = Interpreter.jsToString(args[2])
                        self.measure(name, start, end)
                    } else if (args.size >= 2) {
                        let start = Interpreter.jsToNumber(args[1])
                        let end = self.now()
                        Some(self.measure(name, start, end))
                    } else {
                        Some(self.measure(name, 0.0, self.now()))
                    }
                    match (measure) {
                        case Some(m) => m.toJsValueMeasure()
                        case None => JsValue.NULL
                    }
                }))

                obj.set("clearMarks", JsValue.nativeFunction(JsNativeFunction("clearMarks") { args =>
                    let name = if (args.size >= 1) { Interpreter.jsToString(args[0]) } else { "" }
                    self.clearMarks(name)
                    return JsValue.UNDEFINED
                }))

                obj.set("clearMeasures", JsValue.nativeFunction(JsNativeFunction("clearMeasures") { args =>
                    let name = if (args.size >= 1) { Interpreter.jsToString(args[0]) } else { "" }
                    self.clearMeasures(name)
                    return JsValue.UNDEFINED
                }))

                obj.set("getEntries", JsValue.nativeFunction(JsNativeFunction("getEntries") { _ =>
                    let entries = self.getEntries()
                    let arr = ArrayList<JsValue>()
                    for (entry in entries) {
                        arr.append(entry.toJsValue())
                    }
                    return JsValue.array(arr)
                }))

                obj.set("getEntriesByType", JsValue.nativeFunction(JsNativeFunction("getEntriesByType") { args =>
                    if (args.size >= 1) {
                        let type = Interpreter.jsToString(args[0])
                        let entries = self.getEntriesByType(type)
                        let arr = ArrayList<JsValue>()
                        for (entry in entries) {
                            arr.append(entry.toJsValue())
                        }
                        return JsValue.array(arr)
                    }
                    return JsValue.emptyArray()
                }))

                obj.set("getEntriesByName", JsValue.nativeFunction(JsNativeFunction("getEntriesByName") { args =>
                    if (args.size >= 1) {
                        let name = Interpreter.jsToString(args[0])
                        let entries = self.getEntriesByName(name)
                        let arr = ArrayList<JsValue>()
                        for (entry in entries) {
                            arr.append(entry.toJsValue())
                        }
                        return JsValue.array(arr)
                    }
                    return JsValue.emptyArray()
                }))

                obj.set("toJSON", JsValue.nativeFunction(JsNativeFunction("toJSON") { _ =>
                    let json = JsObject()
                    json.set("timeOrigin", JsValue(self.timeOrigin))
                    return JsValue(json)
                }))
            }
            case None => ()
        }
        return base
    }

    private static func currentTimeMillis(): Float64 {
        return bao_sys.SysModule.currentTimeMillis()
    }
}

// ============================================================================
// PerformanceModule — Performance 模块导出
// ============================================================================

/// Performance 模块导出 — 将 Performance API 注册到全局
public class PerformanceModule {
    /// 全局 Performance 实例
    public static var instance: Performance = Performance()

    /// 将 Performance API 注册到全局环境
    public static func registerGlobals(env: Environment): Unit {
        env.define("performance", instance.toJsValuePerformance(), false)

        // PerformanceObserver 构造函数
        env.define("PerformanceObserver", Interpreter.makeNativeFn("PerformanceObserver") { args =>
            // 简化: 创建一个空的 PerformanceObserver
            let observer = PerformanceObserver({ _ => () })
            return observer.toJsValue()
        }, false)

        // PerformanceEntry, PerformanceMark, PerformanceMeasure (作为构造函数不可用但可引用)
        env.define("PerformanceEntry", Interpreter.makeNativeFn("PerformanceEntry") { _ =>
            JsValue.NULL
        }, false)

        env.define("PerformanceMark", Interpreter.makeNativeFn("PerformanceMark") { args =>
            let name = if (args.size >= 1) { Interpreter.jsToString(args[0]) } else { "" }
            let mark = PerformanceMark(name, instance.now())
            return mark.toJsValueMark()
        }, false)

        env.define("PerformanceMeasure", Interpreter.makeNativeFn("PerformanceMeasure") { args =>
            let name = if (args.size >= 1) { Interpreter.jsToString(args[0]) } else { "" }
            let measure = PerformanceMeasure(name, 0.0, 0.0)
            return measure.toJsValueMeasure()
        }, false)
    }
}
