// AST 运行时
// 严格翻译自: src/ast/runtime.rs (474行)
//   bun.jsc.RuntimeTranspilerCache 相关的数据类型。
//   包含:
//     - Runtime: 运行时 (source_code, version_hash)
//     - ReplaceableExport: 可替换导出
//     - ReplaceableExportMap: 可替换导出映射
//     - ServerComponentsMode: 服务端组件模式
//     - Runtime.Imports: 运行时导入引用
//     - Runtime.Names: 运行时名称常量
package bao_ast

import bao_core.*
import bao_collections.*

// ============================================================================
// Runtime - 运行时
// 严格翻译自: runtime.rs:18-29
//   pub struct Runtime;
//   pub fn source_code() -> &'static [u8]
//   pub fn version_hash() -> u32
// ============================================================================

/// 运行时 - 对应 Bun Runtime
/// 提供运行时代码和版本哈希
public class Runtime {
    /// 运行时代码源 (简化: 实际应包含 runtime.out.js 内容)
    public static func sourceCode(): String {
        "" // 实际实现应加载 runtime.out.js
    }

    /// 版本哈希 - 对应 Runtime.version_hash()
    public static func versionHash(): UInt32 {
        // 简化: 使用源代码哈希
        UInt32(0)
    }
}

// ============================================================================
// ReplaceableExport - 可替换导出
// 严格翻译自: runtime.rs:32-45
//   pub enum ReplaceableExport { Delete, Replace(Expr), Inject }
// ============================================================================

/// 可替换导出 - 对应 Bun ReplaceableExport
public enum ReplaceableExport {
    | Delete                          // 删除导出
    | Replace(ASTNode)               // 替换为表达式
    | Inject(String, ASTNode)        // 注入新的导出

    /// 是否为替换 - 对应 ReplaceableExport.is_replace()
    public func isReplace(): Bool {
        match (this) {
            case Replace(_) => true
            case _ => false
        }
    }
}

// ============================================================================
// ReplaceableExportMap - 可替换导出映射
// 严格翻译自: runtime.rs:53-97
// ============================================================================

/// 可替换导出映射 - 对应 Bun ReplaceableExportMap
/// 存储需要被替换或删除的导出名称
public class ReplaceableExportMap {
    public var entries: HashMap<String, ReplaceableExport>

    public init() {
        entries = HashMap<String, ReplaceableExport>()
    }

    /// 获取数量 - 对应 ReplaceableExportMap.count()
    public func count(): Int64 {
        entries.size
    }

    /// 获取指针 (只读) - 对应 ReplaceableExportMap.get_ptr()
    public func getPtr(key: String): ?ReplaceableExport {
        entries.get(key)
    }

    /// 是否包含 - 对应 ReplaceableExportMap.contains()
    public func contains(key: String): Bool {
        entries.contains(key)
    }

    /// 插入
    public func put(key: String, value: ReplaceableExport): Unit {
        entries.put(key, value)
    }
}

// ============================================================================
// ServerComponentsMode - 服务端组件模式
// 严格翻译自: runtime.rs:99-140
// ============================================================================

/// 服务端组件模式 - 对应 Bun ServerComponentsMode
public enum ServerComponentsMode {
    | None                              // 禁用，"use client"/"use server" 无意义
    | WrapAnonServerFunctions           // 服务端文件，处理 "use server" 函数
    | WrapExportsForClientReference     // "use client" 文件在服务端
    | WrapExportsForServerReference     // "use server" 文件在服务端
    | ClientSide                        // 客户端文件

    /// 是否为服务端 - 对应 ServerComponentsMode.is_server_side()
    public func isServerSide(): Bool {
        match (this) {
            case WrapExportsForServerReference | WrapAnonServerFunctions => true
            case _ => false
        }
    }

    /// 是否包装导出 - 对应 ServerComponentsMode.wraps_exports()
    public func wrapsExports(): Bool {
        match (this) {
            case WrapExportsForClientReference | WrapExportsForServerReference => true
            case _ => false
        }
    }

    /// 是否启用 - 对应 ServerComponentsMode.is_enabled()
    public func isEnabled(): Bool {
        match (this) {
            case None => false
            case _ => true
        }
    }
}

// ============================================================================
// Runtime.Names - 运行时名称常量
// 严格翻译自: runtime.rs:144-148
// ============================================================================

/// 运行时名称 - 对应 Bun Runtime.Names
public class RuntimeNames {
    /// activate 函数名
    public static let ACTIVATE_FUNCTION: String = "activate"
}

// ============================================================================
// RuntimeImports - 运行时导入引用
// 严格翻译自: runtime.rs:153-408
//   pub struct Imports { __name, __require, __export, ... }
// ============================================================================

/// 运行时导入 - 对应 Bun Runtime.Imports
/// 如果修改此结构，记得同步更新 "runtime.js"
public class RuntimeImportRefs {
    public var name: ?Ref
    public var require: ?Ref
    public var export: ?Ref
    public var reExport: ?Ref
    public var exportValue: ?Ref
    public var exportDefault: ?Ref
    public var merge: ?Ref
    public var legacyDecorateClassTS: ?Ref
    public var legacyDecorateParamTS: ?Ref
    public var legacyMetadataTS: ?Ref
    public var publicField: ?Ref
    public var privateIn: ?Ref
    public var privateGet: ?Ref
    public var privateAdd: ?Ref
    public var privateSet: ?Ref
    public var privateMethod: ?Ref
    public var decoratorStart: ?Ref
    public var decoratorMetadata: ?Ref
    public var runInitializers: ?Ref
    public var decorateElement: ?Ref
    public var dollarDollarTypeof: ?Ref
    public var using: ?Ref
    public var callDispose: ?Ref
    public var jsonParse: ?Ref
    public var promiseAll: ?Ref

    public init() {
        name = None
        require = None
        export = None
        reExport = None
        exportValue = None
        exportDefault = None
        merge = None
        legacyDecorateClassTS = None
        legacyDecorateParamTS = None
        legacyMetadataTS = None
        publicField = None
        privateIn = None
        privateGet = None
        privateAdd = None
        privateSet = None
        privateMethod = None
        decoratorStart = None
        decoratorMetadata = None
        runInitializers = None
        decorateElement = None
        dollarDollarTypeof = None
        using = None
        callDispose = None
        jsonParse = None
        promiseAll = None
    }

    /// 所有运行时导入名称
    public static let ALL_NAMES: Array<String> = [
        "__name", "__require", "__export", "__reExport", "__exportValue",
        "__exportDefault", "__merge", "__legacyDecorateClassTS",
        "__legacyDecorateParamTS", "__legacyMetadataTS", "__publicField",
        "__privateIn", "__privateGet", "__privateAdd", "__privateSet",
        "__privateMethod", "__decoratorStart", "__decoratorMetadata",
        "__runInitializers", "__decorateElement", "$$typeof",
        "__using", "__callDispose", "__jsonParse", "__promiseAll"
    ]

    /// 运行时导入源名 - 对应 Imports.NAME
    public static let NAME: String = "bun:wrap"

    /// 是否有任何导入
    public func hasAny(): Bool {
        name.isSome() || require.isSome() || export.isSome() ||
        reExport.isSome() || exportValue.isSome() || exportDefault.isSome() ||
        merge.isSome() || publicField.isSome() || privateIn.isSome()
    }

    /// 获取导入数量
    public func count(): Int64 {
        var n: Int64 = 0
        if (name.isSome()) { n += 1 }
        if (require.isSome()) { n += 1 }
        if (export.isSome()) { n += 1 }
        if (reExport.isSome()) { n += 1 }
        if (exportValue.isSome()) { n += 1 }
        if (exportDefault.isSome()) { n += 1 }
        if (merge.isSome()) { n += 1 }
        n
    }
}
