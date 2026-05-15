// 严格翻译自: src/runtime/api/bun/subprocess/ResourceUsage.zig
package bao_runtime

import bao_jsc.*
import bao_core.*

// ============================================================================
// ResourceUsage - 子进程资源使用统计
// 对应 Bun: src/runtime/api/bun/subprocess/ResourceUsage.zig
// ============================================================================

/// ResourceUsage - 子进程资源使用报告
public class ResourceUsage {
    public var rusage: Rusage

    // ========================================================================
    // 创建
    // ========================================================================

    /// 从 rusage 创建 JS 值
    public static func create(rusage: Rusage, globalObject: JsGlobalObject): JsValue {
        return ResourceUsage(rusage: rusage).toJS(globalObject)
    }

    // ========================================================================
    // 属性获取器
    // ========================================================================

    /// getCPUTime - 获取 CPU 时间
    public func getCPUTime(globalObject: JsGlobalObject): JsValue {
        var cpu = JsValue.createEmptyObjectWithNullPrototype(globalObject)
        let rusage = this.rusage

        let usrTime = try JsValue.fromTimevalNoTruncate(globalObject, rusage.utime.usec, rusage.utime.sec)
        let sysTime = try JsValue.fromTimevalNoTruncate(globalObject, rusage.stime.usec, rusage.stime.sec)

        cpu.put(globalObject, ZigString.static("user"), usrTime)
        cpu.put(globalObject, ZigString.static("system"), sysTime)
        cpu.put(globalObject, ZigString.static("total"), JsValue.bigIntSum(globalObject, usrTime, sysTime))

        return cpu
    }

    /// getMaxRSS - 获取最大驻留集大小
    public func getMaxRSS(): JsValue {
        return JsValue.jsNumber(rusage.maxrss)
    }

    /// getSharedMemorySize - 获取共享内存大小
    public func getSharedMemorySize(): JsValue {
        return JsValue.jsNumber(rusage.ixrss)
    }

    /// getSwapCount - 获取交换次数
    public func getSwapCount(): JsValue {
        return JsValue.jsNumber(rusage.nswap)
    }

    /// getOps - 获取 I/O 操作数
    public func getOps(globalObject: JsGlobalObject): JsValue {
        var ops = JsValue.createEmptyObjectWithNullPrototype(globalObject)
        ops.put(globalObject, ZigString.static("in"), JsValue.jsNumber(rusage.inblock))
        ops.put(globalObject, ZigString.static("out"), JsValue.jsNumber(rusage.oublock))
        return ops
    }

    /// getMessages - 获取消息统计
    public func getMessages(globalObject: JsGlobalObject): JsValue {
        var msgs = JsValue.createEmptyObjectWithNullPrototype(globalObject)
        msgs.put(globalObject, ZigString.static("sent"), JsValue.jsNumber(rusage.msgsnd))
        msgs.put(globalObject, ZigString.static("received"), JsValue.jsNumber(rusage.msgrcv))
        return msgs
    }

    /// getSignalCount - 获取信号数
    public func getSignalCount(): JsValue {
        return JsValue.jsNumber(rusage.nsignals)
    }

    /// getContextSwitches - 获取上下文切换数
    public func getContextSwitches(globalObject: JsGlobalObject): JsValue {
        var ctx = JsValue.createEmptyObjectWithNullPrototype(globalObject)
        ctx.put(globalObject, ZigString.static("voluntary"), JsValue.jsNumber(rusage.nvcsw))
        ctx.put(globalObject, ZigString.static("involuntary"), JsValue.jsNumber(rusage.nivcsw))
        return ctx
    }

    // ========================================================================
    // finalize
    // ========================================================================

    /// finalize - GC 回收时调用
    public func finalize(): Unit {
        destroy(this)
    }
}
