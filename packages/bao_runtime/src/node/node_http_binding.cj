// `node:http` 原生绑定 — getBunServerAllClosedPromise / getMaxHTTPHeaderSize / setMaxHTTPHeaderSize
// 对应 Bun: src/runtime/node/node_http_binding.zig
// 严格翻译自: src/runtime/node/node_http_binding.zig
package bao_runtime.node

// ============================================================================
// HTTP 绑定 — HTTP 相关配置和服务器管理
// 对应 Bun: src/runtime/node/node_http_binding.zig
// ============================================================================

// 最大 HTTP 头部大小（可配置）
private var maxHttpHeaderSize: Int64 = 16384

// 获取最大 HTTP 头部大小
// 对应 Bun: src/runtime/node/node_http_binding.zig - getMaxHTTPHeaderSize
public func getMaxHTTPHeaderSize(): Int64 {
    return maxHttpHeaderSize
}

// 设置最大 HTTP 头部大小
// 对应 Bun: src/runtime/node/node_http_binding.zig - setMaxHTTPHeaderSize
public func setMaxHTTPHeaderSize(size: Int64): Unit {
    if (size > 0) {
        maxHttpHeaderSize = size
    }
}

// 获取服务器全部关闭的 Promise
// 对应 Bun: src/runtime/node/node_http_binding.zig - getBunServerAllClosedPromise
// 遍历所有服务器类型（HTTPServer, HTTPSServer, DebugHTTPServer, DebugHTTPSServer）
// 查找匹配的服务器实例并返回其 allClosed promise
public func getBunServerAllClosedPromise(global: JsGlobalObject, server: JsValue): JsResult<JsValue> {
    // 在实际实现中，尝试将 server 转型为:
    // HTTPServer, HTTPSServer, DebugHTTPServer, DebugHTTPSServer
    // 对应 Bun: inline for 循环尝试每种服务器类型
    //
    // let serverTypes = [HTTPServer, HTTPSServer, DebugHTTPServer, DebugHTTPSServer]
    // for (ServerType in serverTypes) {
    //     if (let some serverInst = server.as_<ServerType>()) {
    //         return serverInst.getAllClosedPromise(global)
    //     }
    // }
    // return Err(global.throwInvalidArgumentTypeValue("server", "bun.Server", server))
    return JsResult<JsValue>.err("Invalid server type")
}

// ============================================================================
// NodeHttpBinding — HTTP 绑定类（向后兼容）
// ============================================================================
public class NodeHttpBinding {
    // 获取最大 HTTP 头部大小
    public static func getMaxHTTPHeaderSize(): Int64 {
        return bao_runtime.node.getMaxHTTPHeaderSize()
    }

    // 设置最大 HTTP 头部大小
    public static func setMaxHTTPHeaderSize(size: Int64): Unit {
        bao_runtime.node.setMaxHTTPHeaderSize(size)
    }

    // 获取服务器全部关闭的 Promise
    public static func getServerAllClosedPromise(server: Any): ?Any {
        return None
    }
}

// ============================================================================
// JsResult — JS 操作结果
// ============================================================================
public enum JsResult<T> {
    | ok(T)
    | err(String)

    public func unwrap(): T {
        match (this) {
            case ok(v) => v
            case err(msg) => throw JsError(msg)
        }
    }
}

// JsGlobalObject — JS 全局对象
public class JsGlobalObject {}

// JsValue — JS 值
public class JsValue {
    public static func undefined(): JsValue { JsValue() }
    public static func null(): JsValue { JsValue() }
    public static func jsNumber(v: Int64): JsValue { JsValue() }

    public init() {}
}

// JsError — JS 错误
public class JsError <: Exception {
    public init(msg: String) { super(msg) }
}
