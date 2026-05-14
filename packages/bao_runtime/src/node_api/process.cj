// Node.js process 模块 — 进程信息与控制
// 对应 Bun: src/runtime/node/process.zig
// 严格翻译 Bun 的 Node.js process 兼容层
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// process 模块 — Node.js 进程 API
// 对应 Bun: src/runtime/node/process.zig
// ============================================================================

/// process 模块 — 提供 Node.js 兼容的进程 API
public class ProcessModule {
    /// process.argv — 命令行参数
    public static var argv: ArrayList<String> = ArrayList<String>()

    /// process.env — 环境变量
    public static var env: HashMap<String, String> = HashMap<String, String>()

    /// process.execPath — Node.js 可执行文件路径
    public static var execPath: String = ""

    /// process.cwd() — 当前工作目录
    public static func cwd(): String {
        // 通过 bao_sys 获取
        return bao_sys.SysModule.getcwd()
    }

    /// process.exit(code) — 退出进程
    /// 对应 Bun: src/runtime/node/process.zig exit
    public static func exit(code: Int32): Unit {
        // 仓颉中无法直接调用 exit()
        // 通过 BaoSys 系统调用
        bao_sys.SysModule.exit(code)
    }

    /// process.nextTick(callback) — 下一个事件循环 tick 执行回调
    /// 对应 Bun: src/runtime/node/process.zig nextTick
    public static func nextTick(callback: () -> Unit): Unit {
        // 简化: 立即执行
        callback()
    }

    /// process.platform — 平台名称
    public static func platform(): String {
        return "linux"
    }

    /// process.version — Node.js 版本号 (Bao 模拟)
    public static func version(): String {
        return "v18.0.0"
    }

    /// process.versions — 版本信息
    public static func versions(): HashMap<String, String> {
        let m = HashMap<String, String>()
        m.put("node", "18.0.0")
        m.put("bao", "0.1.0")
        m.put("v8", "10.0.0")
        return m
    }

    /// process.pid — 进程 ID
    public static func pid(): Int32 {
        return bao_sys.SysModule.getpid()
    }

    /// process.ppid — 父进程 ID
    public static func ppid(): Int32 {
        return bao_sys.SysModule.getppid()
    }

    /// process.uptime() — 进程运行时间 (秒)
    public static func uptime(): Float64 {
        // 简化实现
        return 0.0
    }

    /// process.memoryUsage() — 内存使用情况
    public static func memoryUsage(): HashMap<String, Float64> {
        let m = HashMap<String, Float64>()
        m.put("rss", 0.0)
        m.put("heapTotal", 0.0)
        m.put("heapUsed", 0.0)
        m.put("external", 0.0)
        return m
    }

    /// process.title — 进程标题
    public static var title: String = "bao"

    /// process.arch — CPU 架构
    public static func arch(): String {
        return "x64"
    }

    /// process.chdir(dir) — 改变工作目录
    public static func chdir(dir: String): Unit {
        bao_sys.SysModule.chdir(dir)
    }

    /// process.kill(pid, signal) — 发送信号
    public static func kill(pid: Int32, signal: String): Unit {
        bao_sys.SysModule.kill(pid, signal)
    }

    /// process.hrtime() — 高精度时间
    public static func hrtime(): ArrayList<Int64> {
        let t = bao_sys.SysModule.hrtime()
        let arr = ArrayList<Int64>()
        arr.append(t / 1000000000)
        arr.append(t % 1000000000)
        return arr
    }

    /// 将 process 模块导出为 JsValue 对象
    public static func toJsValue(): JsValue {
        let obj = JsObject()

        // argv
        let argvArr = ArrayList<JsValue>()
        for (arg in argv) {
            argvArr.append(JsValue(BaoString(arg)))
        }
        obj.set("argv", JsValue.array(argvArr))

        // env
        let envObj = JsObject()
        for (key in env.keys()) {
            match (env.get(key)) {
                case Some(v) => envObj.set(key, JsValue(BaoString(v)))
                case None => ()
            }
        }
        obj.set("env", JsValue(envObj))

        // 静态属性
        obj.set("version", JsValue(BaoString(version())))
        obj.set("platform", JsValue(BaoString(platform())))
        obj.set("arch", JsValue(BaoString(arch())))
        obj.set("pid", JsValue(Float64(pid())))
        obj.set("ppid", JsValue(Float64(ppid())))
        obj.set("execPath", JsValue(BaoString(execPath)))
        obj.set("title", JsValue(BaoString(title)))

        // versions
        let versionsObj = JsObject()
        let v = versions()
        for (key in v.keys()) {
            match (v.get(key)) {
                case Some(val) => versionsObj.set(key, JsValue(BaoString(val)))
                case None => ()
            }
        }
        obj.set("versions", JsValue(versionsObj))

        // 方法
        obj.set("cwd", JsValue.nativeFunction(JsNativeFunction("cwd") { _ =>
            JsValue(BaoString(cwd()))
        }))

        obj.set("exit", JsValue.nativeFunction(JsNativeFunction("exit") { args =>
            let code = if (args.size > 0) { Int32(Interpreter.jsToNumber(args[0])) } else { 0 }
            exit(code)
            return JsValue.UNDEFINED
        }))

        obj.set("nextTick", JsValue.nativeFunction(JsNativeFunction("nextTick") { args =>
            // 简化: 立即执行回调
            if (args.size > 0) {
                // 无法在当前架构中直接调用 JS 函数
                // 占位
            }
            return JsValue.UNDEFINED
        }))

        obj.set("chdir", JsValue.nativeFunction(JsNativeFunction("chdir") { args =>
            if (args.size > 0) {
                chdir(Interpreter.jsToString(args[0]))
            }
            return JsValue.UNDEFINED
        }))

        obj.set("kill", JsValue.nativeFunction(JsNativeFunction("kill") { args =>
            if (args.size > 1) {
                let pid = Int32(Interpreter.jsToNumber(args[0]))
                let sig = Interpreter.jsToString(args[1])
                kill(pid, sig)
            }
            return JsValue.UNDEFINED
        }))

        obj.set("hrtime", JsValue.nativeFunction(JsNativeFunction("hrtime") { _ =>
            let t = hrtime()
            let arr = ArrayList<JsValue>()
            for (v in t) {
                arr.append(JsValue(Float64(v)))
            }
            return JsValue.array(arr)
        }))

        obj.set("memoryUsage", JsValue.nativeFunction(JsNativeFunction("memoryUsage") { _ =>
            let mu = memoryUsage()
            let muObj = JsObject()
            for (key in mu.keys()) {
                match (mu.get(key)) {
                    case Some(v) => muObj.set(key, JsValue(v))
                    case None => ()
                }
            }
            return JsValue(muObj)
        }))

        obj.set("uptime", JsValue.nativeFunction(JsNativeFunction("uptime") { _ =>
            JsValue(uptime())
        }))

        return JsValue(obj)
    }
}
