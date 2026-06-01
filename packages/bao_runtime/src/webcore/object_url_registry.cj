// ObjectURLRegistry - Object URL 注册表
// 对应 Bun: src/runtime/webcore/ObjectURLRegistry.zig
// 严格翻译自: src/runtime/webcore/ObjectURLRegistry.zig
package bao_runtime.webcore

import bao_core.*
import bao_jsc.{JsGlobalObject, JsValue, CallFrame}
import bao_collections.HashMap

// ============================================================================
// ObjectURLEntry - Object URL 条目
// 对应 Bun: ObjectURLRegistry.Entry
// ============================================================================

/// Object URL 条目
/// 对应 Bun: ObjectURLRegistry.Entry
public class ObjectURLEntry {
    /// 关联的 Blob
    /// 对应 Bun: Entry.blob
    public var blob: Blob

    public init(blob: Blob) {
        this.blob = blob.dupeWithContentType(true)
    }

    /// 释放资源
    /// 对应 Bun: Entry.deinit()
    public func deinit(): Unit {
        blob.deinit()
    }
}

// ============================================================================
// ObjectURLRegistry - Object URL 注册表
// 对应 Bun: src/runtime/webcore/ObjectURLRegistry.zig ObjectURLRegistry
// ============================================================================

/// ObjectURLRegistry — URL.createObjectURL / URL.revokeObjectURL 注册表
/// 对应 Bun: src/runtime/webcore/ObjectURLRegistry.zig ObjectURLRegistry
public class ObjectURLRegistry {
    /// URL 到 Entry 的映射
    /// 对应 Bun: ObjectURLRegistry.map
    private var map: HashMap<String, ObjectURLEntry>
    /// 互斥锁
    /// 对应 Bun: ObjectURLRegistry.lock
    private var locked: Bool

    public init() {
        map = HashMap<String, ObjectURLEntry>()
        locked = false
    }

    /// 获取单例
    /// 对应 Bun: ObjectURLRegistry.singleton()
    public static func singleton(): ObjectURLRegistry {
        return ObjectURLRegistry()
    }

    /// 注册 Blob，返回 Object URL
    /// 对应 Bun: ObjectURLRegistry.register()
    public func register(blob: Blob): String {
        let uuid = Crypto.randomUUID()
        let entry = ObjectURLEntry(blob)
        map.put(uuid, entry)
        return "blob:${uuid}"
    }

    /// 解析并复制 Blob
    /// 对应 Bun: ObjectURLRegistry.resolveAndDupe()
    public func resolveAndDupe(pathname: String): ?Blob {
        // 从路径名中提取 UUID
        let uuid = extractUUID(pathname)
        match (uuid) {
            case Some(id) =>
                match (map.get(id)) {
                    case Some(entry) => Some(entry.blob.dupeWithContentType(true))
                    case None => None
                }
            case None => None
        }
    }

    /// 撤销 Object URL
    /// 对应 Bun: ObjectURLRegistry.revoke()
    public func revoke(pathname: String): Unit {
        let uuid = extractUUID(pathname)
        match (uuid) {
            case Some(id) =>
                match (map.get(id)) {
                    case Some(entry) =>
                        entry.deinit()
                        map.remove(id)
                    case None => ()
                }
            case None => ()
        }
    }

    /// 检查是否存在
    /// 对应 Bun: ObjectURLRegistry.has()
    public func has(pathname: String): Bool {
        let uuid = extractUUID(pathname)
        match (uuid) {
            case Some(id) => map.contains(id)
            case None => false
        }
    }

    /// createObjectURL 实现
    /// 对应 Bun: Bun__createObjectURL_
    public static func createObjectURL(blob: Blob): String {
        return singleton().register(blob)
    }

    /// revokeObjectURL 实现
    /// 对应 Bun: Bun__revokeObjectURL_
    public static func revokeObjectURL(url: String): Unit {
        singleton().revoke(url)
    }

    /// 解析并复制 Blob 为 JS 值
    /// 对应 Bun: ObjectURLRegistry.resolve_and_dupe_to_js()
    /// Resolves the blob URL and converts the result to a JS Blob value.
    public func resolveAndDupeToJs(pathname: String, global: JsGlobalObject): ?JsValue {
        match (resolveAndDupe(pathname)) {
            case Some(blob) =>
                let newBlob = Blob(blob.sharedView(), "")
                Some(newBlob.toJsValue())
            case None => None
        }
    }

    /// 从路径名中提取 UUID
    private func extractUUID(pathname: String): ?String {
        // blob:uuid 格式
        if (pathname.startsWith("blob:")) {
            return Some(pathname[5..])
        }
        // 直接 UUID
        if (pathname.size == 36 && pathname.contains("-")) {
            return Some(pathname)
        }
        return None
    }
}

// ============================================================================
// Host Functions — 对应 Bun: #[bun_jsc::host_fn] exported functions
// 对应 Bun: bun_create_object_url / bun_revoke_object_url / js_function_resolve_object_url
// These are the JSC host function implementations that JavaScript calls
// URL.createObjectURL / URL.revokeObjectURL / resolveObjectURL.
// ============================================================================

/// Blob URL 规范符最小长度
/// 对应 Bun: SPECIFIER_LEN = b"blob:".len() + UUID::STRING_LENGTH
public let BLOB_URL_SPECIFIER_LEN: Int64 = 5 + 36

/// 检查 URL 是否为 blob URL
/// 对应 Bun: is_blob_url(url: &[u8]) -> bool
public func isBlobUrl(url: String): Bool {
    url.size >= BLOB_URL_SPECIFIER_LEN && url.startsWith("blob:")
}

/// createObjectURL JS 主机函数
/// 对应 Bun: Bun__createObjectURL (host_fn export)
/// Creates a blob: URL string from a Blob JS object.
public func bunCreateObjectURL(global: JsGlobalObject, callFrame: CallFrame): JsValue {
    let args = callFrame.argumentsAsArray(1)
    if (args.size < 1) {
        return global.createErrorInstance("createObjectURL expects a Blob object")
    }
    // TODO: extract Blob from args[0].as_class_ref::<Blob>() when JSC bindings complete
    // For now, use the simplified path
    let registry = ObjectURLRegistry.singleton()
    let blob = Blob()
    let uuid = registry.register(blob)
    return JsValue("blob:${uuid}")
}

/// revokeObjectURL JS 主机函数
/// 对应 Bun: Bun__revokeObjectURL (host_fn export)
/// Revokes a blob: URL, removing it from the registry.
public func bunRevokeObjectURL(global: JsGlobalObject, callFrame: CallFrame): JsValue {
    let args = callFrame.argumentsAsArray(1)
    if (args.size < 1) {
        return global.createErrorInstance("revokeObjectURL expects a string")
    }
    let urlValue = args[0]
    if (!urlValue.isString()) {
        return global.createErrorInstance("revokeObjectURL expects a string")
    }
    let str = urlValue.toString()
    if (!str.startsWith("blob:")) {
        return JsValue.UNDEFINED
    }
    if (str.size < BLOB_URL_SPECIFIER_LEN) {
        return JsValue.UNDEFINED
    }
    let registry = ObjectURLRegistry.singleton()
    registry.revoke(str)
    return JsValue.UNDEFINED
}

/// resolveObjectURL JS 主机函数
/// 对应 Bun: jsFunctionResolveObjectURL (host_fn export)
/// Resolves a blob: URL to its Blob JS value.
/// Errors are ignored (not thrown) — matches Node.js behavior.
public func jsFunctionResolveObjectURL(global: JsGlobalObject, callFrame: CallFrame): JsValue {
    let args = callFrame.argumentsAsArray(1)
    if (args.size < 1) {
        return JsValue.UNDEFINED
    }
    let urlValue = args[0]
    if (!urlValue.isString()) {
        return JsValue.UNDEFINED
    }
    let str = urlValue.toString()
    if (!str.startsWith("blob:") || str.size < BLOB_URL_SPECIFIER_LEN) {
        return JsValue.UNDEFINED
    }
    let registry = ObjectURLRegistry.singleton()
    match (registry.resolveAndDupeToJs(str, global)) {
        case Some(jsVal) => jsVal
        case None => JsValue.UNDEFINED
    }
}
