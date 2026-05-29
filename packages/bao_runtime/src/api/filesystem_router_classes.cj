// 严格翻译自: src/runtime/api/filesystem_router.classes.ts
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue}

// ============================================================================
// filesystem_router.classes.ts 类绑定定义
// Bun: FileSystemRouter, FrameworkFileSystemRouter, MatchedRoute 的 JSC 绑定
// ============================================================================

// ============================================================================
// FileSystemRouter - 文件系统路由器
// 严格翻译自: define({ name: "FileSystemRouter", construct: true, finalize: true })
// configurable: false
// ============================================================================

/// FileSystemRouter JSC 绑定
public class FileSystemRouterClasses {

    /// match fn
    /// 严格翻译自: proto.match { fn: "match", length: 1 }
    public static func `match`(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 匹配 URL 路径到路由
        // 参数: (url: string | URL | Request)
        // 返回: MatchedRoute | null
        return JsValue.jsNull()
    }

    /// routes getter (cached)
    /// 严格翻译自: proto.routes { getter: "getRoutes", cache: true }
    public static func getRoutes(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        // 返回所有已注册路由的对象
        return JsValue.jsObject()
    }

    /// reload fn
    /// 严格翻译自: proto.reload { fn: "reload", length: 0 }
    public static func reload(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 重新扫描文件系统以发现新路由
        return JsValue.jsUndefined()
    }

    /// origin getter (cached)
    /// 严格翻译自: proto.origin { getter: "getOrigin", cache: true }
    public static func getOrigin(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsString("")
    }

    /// style getter (cached)
    /// 严格翻译自: proto.style { getter: "getStyle", cache: true }
    public static func getStyle(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsString("nextjs")
    }
}

// ============================================================================
// FrameworkFileSystemRouter - 框架文件系统路由器
// 严格翻译自: define({ name: "FrameworkFileSystemRouter", construct: true, finalize: true })
// configurable: false
// ============================================================================

/// FrameworkFileSystemRouter JSC 绑定
public class FrameworkFileSystemRouterClasses {

    /// toJSON fn
    /// 严格翻译自: proto.toJSON { fn: "toJSON", length: 0 }
    public static func toJSON(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 返回路由表的 JSON 表示
        return JsValue.jsObject()
    }

    /// match fn
    /// 严格翻译自: proto.match { fn: "match", length: 1 }
    public static func `match`(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 匹配请求到路由
        return JsValue.jsNull()
    }
}

// ============================================================================
// MatchedRoute - 匹配的路由
// 严格翻译自: define({ name: "MatchedRoute", noConstructor: true, construct: true, finalize: true })
// ============================================================================

/// MatchedRoute JSC 绑定
public class MatchedRouteClasses {

    /// params getter (cached)
    /// 严格翻译自: proto.params { getter: "getParams", cache: true }
    public static func getParams(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        // 返回路由参数对象 (如 { id: "123" })
        return JsValue.jsObject()
    }

    /// pathname getter (cached)
    /// 严格翻译自: proto.pathname { getter: "getPathname", cache: true }
    public static func getPathname(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsString("")
    }

    /// query getter (cached)
    /// 严格翻译自: proto.query { getter: "getQuery", cache: true }
    public static func getQuery(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        // 返回查询参数对象
        return JsValue.jsObject()
    }

    /// name getter (cached)
    /// 严格翻译自: proto.name { getter: "getName", cache: true }
    public static func getName(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        // 返回路由名称
        return JsValue.jsString("")
    }

    /// kind getter (cached)
    /// 严格翻译自: proto.kind { getter: "getKind", cache: true }
    public static func getKind(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        // 返回路由类型 (exact, prefix, etc.)
        return JsValue.jsString("")
    }

    /// filePath getter (cached)
    /// 严格翻译自: proto.filePath { getter: "getFilePath", cache: true }
    public static func getFilePath(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        // 返回对应的文件路径
        return JsValue.jsString("")
    }

    /// scriptSrc getter (cached)
    /// 严格翻译自: proto.scriptSrc { getter: "getScriptSrc", cache: true }
    /// 兼容旧版 bun-framework-next
    public static func getScriptSrc(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return JsValue.jsString("")
    }

    /// src getter (cached, alias: scriptSrc)
    /// 严格翻译自: proto.src { getter: "getScriptSrc", cache: "scriptSrc" }
    public static func getSrc(jsGlobalObject!: JsGlobalObject, thisValue!: JsValue): JsValue {
        return getScriptSrc(globalObject, thisValue)
    }
}
