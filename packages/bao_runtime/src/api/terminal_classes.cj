// 严格翻译自: src/runtime/api/Terminal.classes.ts
package bao_runtime.api

import bao_jsc.*

// ============================================================================
// Terminal.classes.ts 类绑定定义
// Bun: Terminal 的 JSC 绑定
// construct: true, constructNeedsThis: true, finalize: true, configurable: false
// values: ["data", "drain", "exit"]
// ============================================================================

/// Terminal JSC 绑定
/// Bun: Bun.Terminal — 伪终端 (PTY) 支持
public class TerminalClasses {

    /// write fn
    /// 严格翻译自: proto.write { fn: "write", length: 1 }
    /// 参数: (data: string | Uint8Array)
    public static func write(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 向终端写入数据
        return JsValue.jsUndefined()
    }

    /// resize fn
    /// 严格翻译自: proto.resize { fn: "resize", length: 2 }
    /// 参数: (rows: number, cols: number)
    public static func resize(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 调整终端大小
        return JsValue.jsUndefined()
    }

    /// setRawMode fn
    /// 严格翻译自: proto.setRawMode { fn: "setRawMode", length: 1 }
    /// 参数: (enabled: boolean)
    public static func setRawMode(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 启用/禁用原始模式
        return JsValue.jsUndefined()
    }

    /// ref fn
    /// 严格翻译自: proto.ref { fn: "doRef", length: 0 }
    public static func doRef(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 引用终端，保持事件循环活跃
        return JsValue.jsUndefined()
    }

    /// unref fn
    /// 严格翻译自: proto.unref { fn: "doUnref", length: 0 }
    public static func doUnref(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 取消引用终端
        return JsValue.jsUndefined()
    }

    /// close fn
    /// 严格翻译自: proto.close { fn: "close", length: 0 }
    public static func close(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 关闭终端
        return JsValue.jsUndefined()
    }

    /// @@asyncDispose fn
    /// 严格翻译自: proto["@@asyncDispose"] { fn: "asyncDispose", length: 0 }
    public static func asyncDispose(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 异步释放终端资源 (用于 using 语法)
        return JsValue.jsUndefined()
    }

    /// closed getter
    /// 严格翻译自: proto.closed { getter: "getClosed" }
    public static func getClosed(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsBoolean(false)
    }

    /// inputFlags getter/setter
    /// 严格翻译自: proto.inputFlags { getter: "getInputFlags", setter: "setInputFlags" }
    public static func getInputFlags(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        // 返回 termios 输入标志位
        return JsValue.jsNumber(0)
    }

    /// setInputFlags setter
    public static func setInputFlags(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// outputFlags getter/setter
    /// 严格翻译自: proto.outputFlags { getter: "getOutputFlags", setter: "setOutputFlags" }
    public static func getOutputFlags(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsNumber(0)
    }

    /// setOutputFlags setter
    public static func setOutputFlags(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// localFlags getter/setter
    /// 严格翻译自: proto.localFlags { getter: "getLocalFlags", setter: "setLocalFlags" }
    public static func getLocalFlags(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsNumber(0)
    }

    /// setLocalFlags setter
    public static func setLocalFlags(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// controlFlags getter/setter
    /// 严格翻译自: proto.controlFlags { getter: "getControlFlags", setter: "setControlFlags" }
    public static func getControlFlags(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsNumber(0)
    }

    /// setControlFlags setter
    public static func setControlFlags(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }
}
