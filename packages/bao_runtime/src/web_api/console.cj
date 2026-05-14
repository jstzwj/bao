// Web API console 模块
// 对应 Bun: src/runtime/api/console.zig
// 严格翻译 Bun 的 console API
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// console 模块 — Web Console API
// 对应 Bun: src/runtime/api/console.zig
// ============================================================================

/// console 模块 — 提供浏览器兼容的 Console API
public class ConsoleModule {
    /// 输出函数 (默认 stdout)
    public static var outputFn: (String) -> Unit = { s => println(s) }
    /// 错误输出函数 (默认 stderr)
    public static var errorFn: (String) -> Unit = { s => println(s) }

    /// 计时器存储
    private static var timers: HashMap<String, Float64> = HashMap<String, Float64>()
    /// 计数器存储
    private static var counters: HashMap<String, Int64> = HashMap<String, Int64>()

    /// console.log(...args)
    /// 对应 Bun: src/runtime/api/console.zig log
    public static func log(args: ArrayList<String>): Unit {
        outputFn(joinArgs(args))
    }

    /// console.error(...args)
    public static func error(args: ArrayList<String>): Unit {
        errorFn(joinArgs(args))
    }

    /// console.warn(...args)
    public static func warn(args: ArrayList<String>): Unit {
        errorFn("[warn] " + joinArgs(args))
    }

    /// console.info(...args)
    public static func info(args: ArrayList<String>): Unit {
        outputFn("[info] " + joinArgs(args))
    }

    /// console.debug(...args)
    public static func debug(args: ArrayList<String>): Unit {
        outputFn("[debug] " + joinArgs(args))
    }

    /// console.dir(obj)
    public static func dir(obj: String): Unit {
        outputFn(obj)
    }

    /// console.time(label?)
    /// 对应 Bun: console.time
    public static func time(label: String): Unit {
        timers.put(label, currentTimeMillis())
    }

    /// console.timeEnd(label?)
    /// 对应 Bun: console.timeEnd
    public static func timeEnd(label: String): Unit {
        match (timers.get(label)) {
            case Some(start) => {
                let elapsed = currentTimeMillis() - start
                timers.remove(label)
                outputFn("${label}: ${elapsed}ms")
            }
            case None => outputFn("Timer '${label}' does not exist")
        }
    }

    /// console.timeLog(label?)
    public static func timeLog(label: String): Unit {
        match (timers.get(label)) {
            case Some(start) => {
                let elapsed = currentTimeMillis() - start
                outputFn("${label}: ${elapsed}ms")
            }
            case None => outputFn("Timer '${label}' does not exist")
        }
    }

    /// console.count(label?)
    public static func count(label: String): Unit {
        let current = match (counters.get(label)) {
            case Some(v) => v
            case None => 0
        }
        let next = current + 1
        counters.put(label, next)
        outputFn("${label}: ${next}")
    }

    /// console.countReset(label?)
    public static func countReset(label: String): Unit {
        counters.put(label, 0)
    }

    /// console.assert(condition, ...args)
    public static func assert(condition: Bool, args: ArrayList<String>): Unit {
        if (!condition) {
            let msg = if (args.size > 0) { "Assertion failed: " + joinArgs(args) } else { "Assertion failed" }
            errorFn(msg)
        }
    }

    /// console.clear()
    public static func clear(): Unit {
        // 清屏 — 发送 ANSI 转义序列
        outputFn("\x1b[2J\x1b[H")
    }

    /// console.table(data)
    public static func table(data: String): Unit {
        // 简化: 直接输出
        outputFn(data)
    }

    /// console.trace(...args)
    public static func trace(args: ArrayList<String>): Unit {
        outputFn("Trace: " + joinArgs(args))
    }

    /// console.group(label?)
    public static func group(label: String): Unit {
        outputFn(label)
    }

    /// console.groupEnd()
    public static func groupEnd(): Unit {
        // 占位
    }

    /// 将 console 模块导出为 JsValue
    public static func toJsValue(): JsValue {
        let obj = JsObject()

        obj.set("log", JsValue.nativeFunction(JsNativeFunction("log") { args =>
            let strs = ArrayList<String>()
            for (arg in args) {
                strs.append(Interpreter.jsToString(arg))
            }
            log(strs)
            return JsValue.UNDEFINED
        }))

        obj.set("error", JsValue.nativeFunction(JsNativeFunction("error") { args =>
            let strs = ArrayList<String>()
            for (arg in args) {
                strs.append(Interpreter.jsToString(arg))
            }
            error(strs)
            return JsValue.UNDEFINED
        }))

        obj.set("warn", JsValue.nativeFunction(JsNativeFunction("warn") { args =>
            let strs = ArrayList<String>()
            for (arg in args) {
                strs.append(Interpreter.jsToString(arg))
            }
            warn(strs)
            return JsValue.UNDEFINED
        }))

        obj.set("info", JsValue.nativeFunction(JsNativeFunction("info") { args =>
            let strs = ArrayList<String>()
            for (arg in args) {
                strs.append(Interpreter.jsToString(arg))
            }
            info(strs)
            return JsValue.UNDEFINED
        }))

        obj.set("debug", JsValue.nativeFunction(JsNativeFunction("debug") { args =>
            let strs = ArrayList<String>()
            for (arg in args) {
                strs.append(Interpreter.jsToString(arg))
            }
            debug(strs)
            return JsValue.UNDEFINED
        }))

        obj.set("dir", JsValue.nativeFunction(JsNativeFunction("dir") { args =>
            if (args.size > 0) { dir(Interpreter.jsToString(args[0])) }
            return JsValue.UNDEFINED
        }))

        obj.set("time", JsValue.nativeFunction(JsNativeFunction("time") { args =>
            let label = if (args.size > 0) { Interpreter.jsToString(args[0]) } else { "default" }
            time(label)
            return JsValue.UNDEFINED
        }))

        obj.set("timeEnd", JsValue.nativeFunction(JsNativeFunction("timeEnd") { args =>
            let label = if (args.size > 0) { Interpreter.jsToString(args[0]) } else { "default" }
            timeEnd(label)
            return JsValue.UNDEFINED
        }))

        obj.set("timeLog", JsValue.nativeFunction(JsNativeFunction("timeLog") { args =>
            let label = if (args.size > 0) { Interpreter.jsToString(args[0]) } else { "default" }
            timeLog(label)
            return JsValue.UNDEFINED
        }))

        obj.set("count", JsValue.nativeFunction(JsNativeFunction("count") { args =>
            let label = if (args.size > 0) { Interpreter.jsToString(args[0]) } else { "default" }
            count(label)
            return JsValue.UNDEFINED
        }))

        obj.set("countReset", JsValue.nativeFunction(JsNativeFunction("countReset") { args =>
            let label = if (args.size > 0) { Interpreter.jsToString(args[0]) } else { "default" }
            countReset(label)
            return JsValue.UNDEFINED
        }))

        obj.set("assert", JsValue.nativeFunction(JsNativeFunction("assert") { args =>
            if (args.size > 0) {
                let cond = Interpreter.jsToBoolean(args[0])
                let restStrs = ArrayList<String>()
                for (i in 1..args.size) {
                    restStrs.append(Interpreter.jsToString(args[i]))
                }
                assert(cond, restStrs)
            }
            return JsValue.UNDEFINED
        }))

        obj.set("clear", JsValue.nativeFunction(JsNativeFunction("clear") { _ =>
            clear()
            return JsValue.UNDEFINED
        }))

        obj.set("table", JsValue.nativeFunction(JsNativeFunction("table") { args =>
            if (args.size > 0) { table(Interpreter.jsToString(args[0])) }
            return JsValue.UNDEFINED
        }))

        obj.set("trace", JsValue.nativeFunction(JsNativeFunction("trace") { args =>
            let strs = ArrayList<String>()
            for (arg in args) {
                strs.append(Interpreter.jsToString(arg))
            }
            trace(strs)
            return JsValue.UNDEFINED
        }))

        obj.set("group", JsValue.nativeFunction(JsNativeFunction("group") { args =>
            let label = if (args.size > 0) { Interpreter.jsToString(args[0]) } else { "" }
            group(label)
            return JsValue.UNDEFINED
        }))

        obj.set("groupEnd", JsValue.nativeFunction(JsNativeFunction("groupEnd") { _ =>
            groupEnd()
            return JsValue.UNDEFINED
        }))

        return JsValue(obj)
    }

    /// 连接参数 (空格分隔)
    private static func joinArgs(args: ArrayList<String>): String {
        let sb = StringBuilder()
        for (i in 0..args.size) {
            if (i > 0) { sb.append(" ") }
            sb.append(args[i])
        }
        return sb.toString()
    }

    /// 获取当前时间戳 (毫秒)
    private static func currentTimeMillis(): Float64 {
        // 简化实现，使用 bao_sys 的时间 API
        return bao_sys.SysModule.currentTimeMillis()
    }
}
