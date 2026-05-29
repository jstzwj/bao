// 翻译自 Bun: src/runtime/bake/bake.zig
// Bake 是 Bun 用于构建客户端+服务器 Web 应用的工具包。
// 它结合了 `Bun.build` 和 `Bun.serve`，提供热重载开发服务器、服务器组件和其他集成。
// Bake 不是框架本身，而是框架构建的工具。

package bao_runtime.bake

import bao_bun_alloc.Allocator
import bao_collections.ArrayList
import bao_bundler.Define
import bao_bundler.DefineData
import bao_bundler.Plugin
import bao_core.ArenaAllocator
import bao_core.Output
import bao_jsc.ZigStringSlice
import bao_options.LoaderMap
import bao_options.DotEnvBehavior
import bao_options.SourceMapMode
import bao_options.StringMap

// 导入子模块
// DevServer is in bao_runtime.bake.dev_server package

/// export default { app: ... };
public const api_name: String = "app"

/// Mode 枚举
public enum Mode {
    | development
    | production_dynamic
    | production_static

    public operator func ==(other: Mode): Bool {
        match (this) {
            case development => match (other) { case development => true case _ => false }
            case production_dynamic => match (other) { case production_dynamic => true case _ => false }
            case production_static => match (other) { case production_static => true case _ => false }
        }
    }

    public operator func !=(other: Mode): Bool {
        !(this == other)
    }
}

/// Side 枚举
public enum Side {
    | client
    | server

    public operator func ==(other: Side): Bool {
        match (this) {
            case client => match (other) { case client => true case _ => false }
            case server => match (other) { case server => true case _ => false }
        }
    }

    public operator func !=(other: Side): Bool {
        !(this == other)
    }
}

/// Graph 枚举 — 渲染目标
public enum Graph {
    | client
    | server
    | ssr

    public operator func ==(other: Graph): Bool {
        match (this) {
            case client => match (other) { case client => true case _ => false }
            case server => match (other) { case server => true case _ => false }
            case ssr => match (other) { case ssr => true case _ => false }
        }
    }

    public operator func !=(other: Graph): Bool {
        !(this == other)
    }
}

/// Zig 版本的 TypeScript 定义 'Bake.Options'
public class UserOptions {
    public var arena: ArenaAllocator = ArenaAllocator()
    public var allocations: StringRefList = StringRefList()
    public var root: String = ""
    public var framework: Framework = Framework(false, [])
    public var bundler_options: SplitBundlerOptions = SplitBundlerOptions()

    public init() {}

    public init(arena: ArenaAllocator, allocations: StringRefList, root: String, framework: Framework, bundler_options: SplitBundlerOptions) {
        this.arena = arena
        this.allocations = allocations
        this.root = root
        this.framework = framework
        this.bundler_options = bundler_options
    }

    public func deinit() {
        arena.reset()
        allocations.free()
        if (let Some(p) <- bundler_options.plugin) {
            // Plugin cleanup not needed in this context
        }
    }
}

/// 每个字符串存储其分配器，因为某些可能持有对 JSC 的引用计数
public class StringRefList {
    public var strings: ArrayList<ZigStringSlice> = ArrayList<ZigStringSlice>()

    public init() {}

    public static let empty: StringRefList = StringRefList()

    public func track(str: ZigStringSlice): String {
        strings.append(str)
        return str.slice()
    }

    public func free() {
        for (item in strings) {
            item.deinit()
        }
        strings.clearAndFree()
    }
}

/// 分割的 Bundler 选项
public class SplitBundlerOptions {
    public var plugin: ?Plugin = None
    public var client: BuildConfigSubset = BuildConfigSubset()
    public var server: BuildConfigSubset = BuildConfigSubset()
    public var ssr: BuildConfigSubset = BuildConfigSubset()

    public init() {}

    public static let empty: SplitBundlerOptions = SplitBundlerOptions()
}

/// 构建配置子集
public class BuildConfigSubset {
    public var loader: ?LoaderMap = None
    public var ignoreDCEAnnotations: ?Bool = None
    public var conditions: StringArrayHashMap<Unit> = StringArrayHashMap<Unit>()
    public var drop: StringArrayHashMap<Unit> = StringArrayHashMap<Unit>()
    public var env: DotEnvBehavior = DotEnvBehavior.Disable
    public var env_prefix: ?String = None
    public var define: StringMap = StringMap()
    public var source_map: SourceMapMode = SourceMapMode.External

    public var minify_syntax: ?Bool = None
    public var minify_identifiers: ?Bool = None
    public var minify_whitespace: ?Bool = None
}

/// Framework 配置结构体
/// Framework 只是一组 bundler 选项，框架作者设置这些选项以将框架与应用集成。
/// 由于许多字段具有默认值，可能指向静态内存，此结构体始终使用 arena 分配。
public class Framework {
    public var is_built_in_react: Bool = false
    public var fileSystemRouterTypes: Array<FileSystemRouterType> = []
    public var serverComponents: ?ServerComponents = None
    public var reactFastRefresh: ?ReactFastRefresh = None
    public var react: FrameworkReactConfig = FrameworkReactConfig()
    public var built_in_modules: StringArrayHashMap<BuiltInModule> = StringArrayHashMap<BuiltInModule>()

    public init() {}

    public init(is_built_in_react: Bool, file_system_router_types: Array<FileSystemRouterType>) {
        this.is_built_in_react = is_built_in_react
        this.fileSystemRouterTypes = file_system_router_types
    }

    public static let react_install_command: String = "bun i react@experimental react-dom@experimental react-server-dom-bun react-refresh@experimental"
}

/// Framework react config
public class FrameworkReactConfig {
    public init() {}
}

/// 文件系统路由器类型
public class FileSystemRouterType {
    public var root: String = ""
    public var prefix: String = "/"
    public var entry_server: String = ""
    public var entry_client: ?String = None
    public var ignore_underscores: Bool = false
    public var ignore_dirs: Array<String> = [".git", "node_modules"]
    public var extensions: Array<String> = []
    public var style: FrameworkRouterStyle = FrameworkRouterStyle.nextjs_pages
    public var allow_layouts: Bool = false
    public init() {}
}

/// 内置模块
public enum BuiltInModule {
    | `import`(String)
    | code(String)
}

/// 服务器组件配置
public class ServerComponents {
    public var separate_ssr_graph: Bool = false
    public var server_runtime_import: String = ""
    public var server_register_client_reference: String = "registerClientReference"
    public var server_register_server_reference: String = "registerServerReference"
    public var client_register_server_reference: String = "registerServerReference"
    public init() {}
}

/// React 快速刷新配置
public class ReactFastRefresh {
    public var import_source: String = "react-refresh/runtime"
    public init() {}
    public init(importSource: String) { import_source = importSource }
}

/// 运行时嵌入资源加载器。
/// 对应 Bun: bun.runtimeEmbedFile / bun_core::runtime_embed_file!。
public class RuntimeEmbedFile {
    public static func codegen(path: String): String {
        return runtimeEmbedFileCodegenFFI(path)
    }
}

public func runtimeEmbedFileCodegenFFI(path: String): String { return "" }

/// HMR 运行时
public class HmrRuntime {
    public var code: String
    /// HMR 运行时中的行数。用于 sourcemap 生成，其中前 n 行被跳过。
    public var line_count: UInt32

    public init(code: String) {
        this.code = code
        this.line_count = UInt32(code.count('\n'))
    }
}

/// 获取 HMR 运行时代码
public func getHmrRuntime(side: Side): HmrRuntime {
    // 对应 Bun bake.zig 中嵌入的 hmr-runtime-client.ts / hmr-runtime-server.ts。
    match (side) {
        case client => HmrRuntime(hmrRuntimeClientSource)
        case server => HmrRuntime(hmrRuntimeServerSource)
    }
}

/// 添加 import.meta 定义
public func addImportMetaDefines(
    allocator: Allocator,
    define: Define,
    mode: Mode,
    side: Side
): Unit {
    // import.meta.env.DEV
    define.insert("import.meta.env.DEV", DefineData.initBoolean(mode == Mode.development))
    // import.meta.env.PROD
    define.insert("import.meta.env.PROD", DefineData.initBoolean(mode != Mode.development))
    // import.meta.env.MODE
    let mode_str: String = match (mode) {
        case development => "development"
        case production_dynamic | production_static => "production"
    }
    define.insert("import.meta.env.MODE", DefineData.initStaticString(mode_str))
    // import.meta.env.SSR
    define.insert("import.meta.env.SSR", DefineData.initBoolean(side == Side.server))
    // import.meta.env.STATIC
    define.insert("import.meta.env.STATIC", DefineData.initBoolean(mode == Mode.production_static))
}

/// PatternBuffer - 栈分配的结构，从末尾向前写入。用于构建模式字符串的暂存区。
public class PatternBuffer {
    public var bytes: PathBuffer = PathBuffer()
    public var i: Int64 = 0

    public init() {}

    public static let empty: PatternBuffer = PatternBuffer()

    public func prepend(chunk: String): Unit {
        i -= chunk.size
    }

    public func prependPart(part: FrameworkRouterPart): Unit {
        match (part) {
            case text(t) =>
                prepend(t)
                prepend("/")
            case param(name) =>
                prepend(name)
                prepend("/:")
            case catch_all(name) =>
                prepend(name)
                prepend("/:")
            case catch_all_optional(name) =>
                prepend(name)
                prepend("/:")
            case group(_) => () // 分组不影响模式
        }
    }

    public func slice(): String {
        return ""
    }
}

/// 打印 Bake 实验性警告
public func printWarning(): Unit {
    Output.warn("Be advised that Bun Bake is highly experimental, and its API will have breaking changes.")
    Output.flush()
}

// 以下为类型别名和前向声明，用于跨模块引用
// Types from imports: Define, DefineData, Plugin from bao_bundler
// LoaderMap, DotEnvBehavior, SourceMapMode from bao_options (bun_schema)
// ZigStringSlice from bao_jsc

// 尚未在仓颉中实现的类型的替代定义:
public type PathBuffer = Array<Byte>
public type Int = Int64
public class StringArrayHashMap<V> {
    public init() {}
    public func put(k: String, v: V): Unit {}
    public func get(k: String): ?V { None }
    public static func fromEntries(entries: Array<(String, V)>): StringArrayHashMap<V> {
        let map = StringArrayHashMap<V>()
        for (entry in entries) {
            map.put(entry[0], entry[1])
        }
        return map
    }
    public func keys(): Array<String> { Array<String>() }
    public func deinit(alloc: Allocator): Unit {}
    public func iterator(): MapIterator<String, V> { MapIterator<String, V>() }
}
public type Error = Exception
