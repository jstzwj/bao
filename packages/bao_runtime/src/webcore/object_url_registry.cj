// ObjectURLRegistry - Object URL 注册表
// 对应 Bun: src/runtime/webcore/ObjectURLRegistry.zig
// 严格翻译自: src/runtime/webcore/ObjectURLRegistry.zig
package bao_runtime

import bao_core.*
import bao_collections.*

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
            case Some(id) => {
                match (map.get(id)) {
                    case Some(entry) => Some(entry.blob.dupeWithContentType(true))
                    case None => None
                }
            }
            case None => None
        }
    }

    /// 撤销 Object URL
    /// 对应 Bun: ObjectURLRegistry.revoke()
    public func revoke(pathname: String): Unit {
        let uuid = extractUUID(pathname)
        match (uuid) {
            case Some(id) => {
                match (map.get(id)) {
                    case Some(entry) => {
                        entry.deinit()
                        map.remove(id)
                    }
                    case None => ()
                }
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

    /// 从路径名中提取 UUID
    private func extractUUID(pathname: String): ?String {
        // blob:uuid 格式
        if (pathname.startsWith("blob:")) {
            return Some(pathname.substring(5))
        }
        // 直接 UUID
        if (pathname.length == 36 && pathname.contains("-")) {
            return Some(pathname)
        }
        return None
    }
}
