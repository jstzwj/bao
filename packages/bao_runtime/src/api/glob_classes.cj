// 严格翻译自: src/runtime/api/Glob.classes.ts
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue}

// ============================================================================
// Glob.classes.ts 类绑定定义
// Bun: Glob 的 JSC 绑定
// construct: true, finalize: true, hasPendingActivity: true, configurable: false
// ============================================================================

/// Glob JSC 绑定
/// Bun: new Bun.Glob(pattern) 文件模式匹配
public class GlobClasses {

    /// scan fn (builtin codegen)
    /// 严格翻译自: proto.scan { builtin: "globScanCodeGenerator", length: 1 }
    /// 参数: (opts?: { cwd?: string, dot?: boolean, absolute?: boolean, onlyFiles?: boolean })
    /// 返回: AsyncIterableIterator<string> (异步生成器)
    public static func scan(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // globScanCodeGenerator — 由 builtin 代码生成器处理
        // 返回异步迭代器
        return JsValue.jsUndefined()
    }

    /// scanSync fn (builtin codegen)
    /// 严格翻译自: proto.scanSync { builtin: "globScanSyncCodeGenerator", length: 1 }
    /// 参数: (opts?: { cwd?: string, dot?: boolean, absolute?: boolean, onlyFiles?: boolean })
    /// 返回: string[] (同步结果)
    public static func scanSync(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // globScanSyncCodeGenerator — 由 builtin 代码生成器处理
        // 返回字符串数组
        return JsValue.jsUndefined()
    }

    /// __scan fn (private symbol: "pull")
    /// 严格翻译自: proto.__scan { fn: "__scan", length: 1, privateSymbol: "pull" }
    public static func scanInternal(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 内部扫描方法，使用私有符号 "pull"
        return JsValue.jsUndefined()
    }

    /// __scanSync fn (private symbol: "resolveSync")
    /// 严格翻译自: proto.__scanSync { fn: "__scanSync", length: 1, privateSymbol: "resolveSync" }
    public static func scanSyncInternal(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 内部同步扫描方法，使用私有符号 "resolveSync"
        return JsValue.jsUndefined()
    }

    /// match fn
    /// 严格翻译自: proto.match { fn: "match", length: 1 }
    /// 参数: (path: string)
    /// 返回: boolean
    public static func `match`(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 测试路径是否匹配 glob 模式
        return JsValue.jsBoolean(false)
    }
}
