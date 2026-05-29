// 严格翻译自: src/runtime/api/JSBundler.classes.ts
package bao_runtime.api

import bao_jsc.*

// ============================================================================
// JSBundler.classes.ts 类绑定定义
// Bun: Transpiler, BuildArtifact 的 JSC 绑定
// ============================================================================

// ============================================================================
// Transpiler - JS 转译器
// 严格翻译自: define({ name: "Transpiler", construct: true, finalize: true })
// configurable: false, hasPendingActivity: false
// rustPath: crate::api::js_transpiler::JSTranspiler
// ============================================================================

/// Transpiler JSC 绑定
/// Bun: new Bun.Transpiler(options) — JS/TS 转译器
public class TranspilerClasses {

    /// scanImports fn
    /// 严格翻译自: proto.scanImports { fn: "scanImports", length: 2 }
    /// 参数: (code: string, path?: string)
    /// 返回: Array<{ path: string, kind: string }>
    public static func scanImports(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// scan fn
    /// 严格翻译自: proto.scan { fn: "scan", length: 2 }
    /// 参数: (code: string, path?: string)
    /// 返回: ScanResult
    public static func scan(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// transform fn
    /// 严格翻译自: proto.transform { fn: "transform", length: 2 }
    /// 参数: (code: string, options?: TranspilerOptions)
    /// 返回: Promise<string>
    public static func transform(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// transformSync fn
    /// 严格翻译自: proto.transformSync { fn: "transformSync", length: 2 }
    /// 参数: (code: string, options?: TranspilerOptions)
    /// 返回: string
    public static func transformSync(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }
}

// ============================================================================
// BuildArtifact - 构建产物
// 严格翻译自: define({ name: "BuildArtifact", noConstructor: true, finalize: true })
// configurable: false, hasPendingActivity: false
// ============================================================================

/// BuildArtifact JSC 绑定
/// Bun: Bun.build() 返回的产物对象
public class BuildArtifactClasses {

    /// text fn
    /// 严格翻译自: proto.text { fn: "getText" }
    public static func getText(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsString("")
    }

    /// json fn
    /// 严格翻译自: proto.json { fn: "getJSON" }
    public static func getJSON(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// arrayBuffer fn
    /// 严格翻译自: proto.arrayBuffer { fn: "getArrayBuffer" }
    public static func getArrayBuffer(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// slice fn
    /// 严格翻译自: proto.slice { fn: "getSlice", length: 2 }
    public static func getSlice(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// stream fn
    /// 严格翻译自: proto.stream { fn: "getStream", length: 1 }
    public static func getStream(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        return JsValue.jsUndefined()
    }

    /// path getter (cached)
    /// 严格翻译自: proto.path { getter: "getPath", cache: true }
    public static func getPath(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsString("")
    }

    /// size getter
    /// 严格翻译自: proto.size { getter: "getSize" }
    public static func getSize(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsNumber(0)
    }

    /// hash getter (cached)
    /// 严格翻译自: proto.hash { getter: "getHash", cache: true }
    public static func getHash(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsString("")
    }

    /// sourcemap getter (cached)
    /// 严格翻译自: proto.sourcemap { getter: "getSourceMap", cache: true }
    public static func getSourceMap(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsNull()
    }

    /// loader getter (cached)
    /// 严格翻译自: proto.loader { getter: "getLoader", cache: true }
    public static func getLoader(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsString("js")
    }

    /// type getter (cached)
    /// 严格翻译自: proto.type { getter: "getMimeType", cache: true }
    public static func getMimeType(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsString("")
    }

    /// kind getter (cached)
    /// 严格翻译自: proto.kind { getter: "getOutputKind", cache: true }
    public static func getOutputKind(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsString("")
    }
}
