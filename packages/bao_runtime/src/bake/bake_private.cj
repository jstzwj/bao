// 严格翻译自: src/runtime/bake/bake.private.d.ts
// Bake 私有类型定义 — 运行时内部使用的全局声明。
// 对应 Bun: bake.private.d.ts

package bao_runtime.bake

import bao_jsc.JsValue
import bao_jsc.JSGlobalObject
import bao_jsc.JsObject
import bao_jsc.JsFunction
import bao_jsc.JsError
import bao_jsc.Strong
import bao_jsc.ZigStringSlice
import bao_collections.*
import bao_threading.*

// ============================================================================
// 全局类型声明
// ============================================================================

/// 模块 ID 类型
/// 模块 ID 由 bundler 预解析，应视为不透明字符串。
/// 实际上，这些字符串是模块的相对文件路径。
public type Id = String

/// 文件索引，与 IncrementalGraph(.client).Index 用法相同
public type FileIndex = Int64

/// 运行时配置
/// 对应 Bun: bake.private.d.ts Config
public class BakeConfig {
    /// 服务器 + 客户端共用的主入口 ID
    public var `main`: Id
    /// 生成编号
    public var generation: Int64
    /// 是否分离 SSR 图
    public var separateSSRGraph: Bool = false
    /// Bun 版本
    public var bun: String = ""
    /// DevServer 的 configuration_hash_key
    public var version: String = ""
    /// 如果可用，这是 react-refresh/runtime 的 ID
    public var refresh: ?Id = None
    /// 客户端感知的 "roots" 列表。包括框架入口点和所有客户端组件。
    public var roots: Array<FileIndex> = []
    /// 如果为 true，客户端将从服务器接收控制台日志
    public var console: Bool = false

    public init(`main`: Id, generation: Int64) {
        this.`main` = `main`
        this.generation = generation
    }
}

/// DEBUG 命名空间 — 仅在 debug 构建中全局设置。
/// 在 release 中通过 --drop=ASSERT 移除。
public class BakeDebug {
    /// 断言条件为真，否则报错
    public static func ASSERT(condition: Bool): Unit {
        ASSERT(condition, "")
    }

    public static func ASSERT(condition: Bool, message: String): Unit {
        if (!condition) {
            if (message.isEmpty()) {
                Output.errGeneric("ASSERTION FAILED")
            } else {
                Output.errGeneric("ASSERTION FAILED: ${message}")
            }
        }
    }
}

/// 所有初始 bundle 的模块。由 bundler 生成。
/// 对应 Bun: unloadedModuleRegistry
public let unloadedModuleRegistry: HashMap<Id, UnloadedModule> = HashMap<Id, UnloadedModule>()

/// 未加载的模块可以是 ESM 或 CommonJS
public enum UnloadedModule {
    /// ESM 模块: [deps, exportKeys, starImports, load, isAsync]
    | esm(UnloadedESM)
    /// CommonJS 模块: (hmr, module, exports) => unknown
    | cjs(UnloadedCommonJS)
}

/// ESM 未加载模块
public class UnloadedESM {
    /// 编码的依赖数组
    public var deps: Array<Any>
    /// 导出键名列表
    public var exportKeys: Array<String>
    /// 星号导入的模块 ID 列表
    public var starImports: Array<Id>
    /// 加载函数
    public var load: (HMRModule) -> ?Promise<Unit>
    /// 是否为异步模块
    public var isAsync: Bool

    public init(deps: Array<Any>, exportKeys: Array<String>, starImports: Array<Id>,
                load: (HMRModule) -> ?Promise<Unit>, isAsync: Bool) {
        this.deps = deps
        this.exportKeys = exportKeys
        this.starImports = starImports
        this.load = load
        this.isAsync = isAsync
    }
}

/// CommonJS 未加载模块
public type UnloadedCommonJS = (HMRModule, HMRModuleCjs, Any) -> Any

/// CommonJS 模块对象
public class HMRModuleCjs {
    public var id: Id
    public var exports: Any
    public var require: (Id) -> Any

    public init(id: Id, exports: Any, require: (Id) -> Any) {
        this.id = id
        this.exports = exports
        this.require = require
    }
}

/// 编码的依赖数组类型
/// (string | number)[] 的 Cangjie 等价
public type EncodedDependencyArray = Array<Any>

/// 全局配置对象，由 DevServer 注入
public let config: BakeConfig = BakeConfig("", 0)

/// 运行时侧标识 — "client" 或 "server"
/// 影响如何建立 HMR 连接以及是否有窗口来可视化显示错误
public let side: String = "server"

/// 是否为 Bun 的 debug 构建
/// 这些 debug 构建应为处理 bundler 本身的人提供有用信息。
/// 面向最终用户的断言应始终启用。

/// 是否为回退错误页面
public let IS_ERROR_RUNTIME: Bool = false

/// 类型别名 — types available via imports above
// HashMap, Promise are imported from bao_collections and bao_threading respectively
