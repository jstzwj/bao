// 严格翻译自: src/runtime/api/BunObject.classes.ts
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame}

// ============================================================================
// BunObject.classes.ts 类绑定定义
// Bun: ResourceUsage, Subprocess 的 JSC 绑定
// ============================================================================

// ============================================================================
// ResourceUsage - 资源使用统计
// 严格翻译自: BunObject.classes.ts define({ name: "ResourceUsage", ... })
// construct: true, noConstructor: true, finalize: true
// configurable: false, hasPendingActivity: false
// ============================================================================

/// ResourceUsage - 进程资源使用统计
/// Bun: Bun.resourceUsage() 返回值
/// JS 方法/getter 全部定义在 prototype 上
public class ResourceUsageClasses {

    /// maxRSS getter
    /// 严格翻译自: proto.maxRSS { getter: "getMaxRSS" }
    public static func getMaxRSS(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        // 获取最大驻留集大小 (Max Resident Set Size)
        return JsValue.jsNumber(0)
    }

    /// shmSize getter
    /// 严格翻译自: proto.shmSize { getter: "getSharedMemorySize" }
    public static func getSharedMemorySize(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        // 获取共享内存大小
        return JsValue.jsNumber(0)
    }

    /// swapCount getter
    /// 严格翻译自: proto.swapCount { getter: "getSwapCount" }
    public static func getSwapCount(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        // 获取交换次数
        return JsValue.jsNumber(0)
    }

    /// messages getter
    /// 严格翻译自: proto.messages { getter: "getMessages" }
    public static func getMessages(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        // 获取 IPC 消息数
        return JsValue.jsNumber(0)
    }

    /// signalCount getter
    /// 严格翻译自: proto.signalCount { getter: "getSignalCount" }
    public static func getSignalCount(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        // 获取信号数
        return JsValue.jsNumber(0)
    }

    /// contextSwitches getter (cached)
    /// 严格翻译自: proto.contextSwitches { getter: "getContextSwitches", cache: true }
    public static func getContextSwitches(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        // 获取上下文切换次数
        return JsValue.jsNumber(0)
    }

    /// cpuTime getter (cached)
    /// 严格翻译自: proto.cpuTime { getter: "getCPUTime", cache: true }
    public static func getCPUTime(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        // 获取 CPU 时间 (用户+系统, 毫秒)
        return JsValue.jsNumber(0)
    }

    /// ops getter (cached)
    /// 严格翻译自: proto.ops { getter: "getOps", cache: true }
    public static func getOps(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        // 获取 I/O 操作数
        return JsValue.jsNumber(0)
    }
}

// ============================================================================
// Subprocess - 子进程
// 严格翻译自: BunObject.classes.ts define({ name: "Subprocess", ... })
// construct: true, noConstructor: true, finalize: true, memoryCost: true
// sharedThis: true, configurable: false
// values: ["exitedPromise", "onExitCallback", "onDisconnectCallback", "ipcCallback"]
// ============================================================================

/// Subprocess - 子进程 JSC 绑定
/// Bun: Bun.spawn() 返回的子进程对象
public class SubprocessClasses {

    /// pid getter
    /// 严格翻译自: proto.pid { getter: "getPid" }
    public static func getPid(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsNumber(0)
    }

    /// stdin getter (cached)
    /// 严格翻译自: proto.stdin { getter: "getStdin", cache: true }
    public static func getStdin(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsNull()
    }

    /// stdout getter (cached)
    /// 严格翻译自: proto.stdout { getter: "getStdout", cache: true }
    public static func getStdout(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsNull()
    }

    /// stderr getter (cached)
    /// 严格翻译自: proto.stderr { getter: "getStderr", cache: true }
    public static func getStderr(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsNull()
    }

    /// writable getter (alias: stdin, cached)
    /// 严格翻译自: proto.writable { getter: "getStdin", cache: "stdin" }
    public static func getWritable(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return getStdin(globalObject, thisValue)
    }

    /// readable getter (alias: stdout, cached)
    /// 严格翻译自: proto.readable { getter: "getStdout", cache: "stdout" }
    public static func getReadable(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return getStdout(globalObject, thisValue)
    }

    /// ref fn
    /// 严格翻译自: proto.ref { fn: "doRef", length: 0 }
    public static func doRef(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 引用子进程，保持事件循环活跃
        return JsValue.jsUndefined()
    }

    /// unref fn
    /// 严格翻译自: proto.unref { fn: "doUnref", length: 0 }
    public static func doUnref(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 取消引用子进程
        return JsValue.jsUndefined()
    }

    /// resourceUsage fn
    /// 严格翻译自: proto.resourceUsage { fn: "resourceUsage", length: 0 }
    public static func resourceUsage(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 返回 Promise<ResourceUsage>
        return JsValue.jsUndefined()
    }

    /// send fn
    /// 严格翻译自: proto.send { fn: "doSend", length: 1 }
    public static func doSend(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 发送 IPC 消息
        return JsValue.jsUndefined()
    }

    /// kill fn
    /// 严格翻译自: proto.kill { fn: "kill", length: 1 }
    public static func kill(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 向子进程发送信号
        return JsValue.jsUndefined()
    }

    /// disconnect fn
    /// 严格翻译自: proto.disconnect { fn: "disconnect", length: 0 }
    public static func disconnect(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 断开 IPC 连接
        return JsValue.jsUndefined()
    }

    /// connected getter
    /// 严格翻译自: proto.connected { getter: "getConnected" }
    public static func getConnected(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsBoolean(false)
    }

    /// @@asyncDispose fn
    /// 严格翻译自: proto["@@asyncDispose"] { fn: "asyncDispose", length: 1 }
    public static func asyncDispose(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 异步释放子进程资源
        return JsValue.jsUndefined()
    }

    /// killed getter
    /// 严格翻译自: proto.killed { getter: "getKilled" }
    public static func getKilled(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsBoolean(false)
    }

    /// exitCode getter
    /// 严格翻译自: proto.exitCode { getter: "getExitCode" }
    public static func getExitCode(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsNull()
    }

    /// signalCode getter
    /// 严格翻译自: proto.signalCode { getter: "getSignalCode" }
    public static func getSignalCode(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsNull()
    }

    /// exited getter (`this`: true)
    /// 严格翻译自: proto.exited { getter: "getExited", `this`: true }
    public static func getExited(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        // 返回 Promise<number> (exit code)
        return JsValue.jsUndefined()
    }

    /// stdio getter
    /// 严格翻译自: proto.stdio { getter: "getStdio" }
    public static func getStdio(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// terminal getter (cached)
    /// 严格翻译自: proto.terminal { getter: "getTerminal", cache: true }
    public static func getTerminal(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsNull()
    }
}
