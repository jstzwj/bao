// bao_bundler - Plugin System (插件系统)
// 严格翻译自: src/bundler/ 中插件钩子逻辑
//   对应: src/bundler/PluginRunner.zig - 插件运行器
//   对应: src/resolver/ 中 plugin resolve 支持
//   对应: src/js_ast.zig 中 loader 类型
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// Plugin Hooks - 插件钩子
// 严格翻译自: bun 中 esbuild 兼容的插件 API (onLoad, onResolve, onBuild)
// ============================================================================

/// 插件钩子类型
public enum PluginHookKind {
    | OnResolve                       // 解析路径时调用
    | OnLoad                          // 加载文件时调用
    | OnBuild                         // 构建开始时调用
}

/// 插件过滤器 (决定钩子应用于哪些模块)
public class PluginFilter {
    /// 正则表达式模式 (如 "\\.css$")
    public var regex: String
    /// 命名空间 (如 "file", "http", 或空字符串表示所有)
    public var namespace: String

    public init(regex: String) {
        this.regex = regex
        this.namespace = ""
    }

    public init(regex: String, namespace: String) {
        this.regex = regex
        this.namespace = namespace
    }

    /// 测试路径是否匹配过滤器
    public func matches(path: String, pathNamespace: String): Bool {
        // 命名空间不匹配
        if (namespace.length > 0 && namespace != pathNamespace) {
            return false
        }
        // 简易正则匹配 (支持 * 通配符和 $ 后缀)
        return matchRegex(path, regex)
    }

    /// 简易正则匹配
    private static func matchRegex(path: String, pattern: String): Bool {
        // 处理常见的后缀模式: "\.css$"
        if (pattern.startsWith("\\.") && pattern.endsWith("$")) {
            let ext = pattern.substring(2, pattern.length - 1)
            return path.endsWith("." + ext)
        }
        // 处理前缀模式: "^node:"
        if (pattern.startsWith("^")) {
            let prefix = pattern.substring(1)
            return path.startsWith(prefix)
        }
        // 处理包含模式: "node_modules"
        if (!pattern.startsWith("^") && !pattern.endsWith("$") && !pattern.contains("*")) {
            return path.contains(pattern)
        }
        // 通配符: * 匹配任意字符
        if (pattern.contains("*")) {
            return matchGlobPattern(path, pattern)
        }
        return path == pattern
    }

    /// 通配符匹配
    private static func matchGlobPattern(path: String, pattern: String): Array<String> {
        // 将 pattern 按 * 分割，检查各段依次出现在 path 中
        let parts = pattern.split("*")
        var pos: Int64 = 0
        for (part in parts) {
            if (part.length == 0) { continue }
            let idx = path.indexOf(part, pos)
            match (idx) {
                case Some(i) => pos = i + part.length
                case None => return false
            }
        }
        return true
    }
}

/// 插件钩子注册
public class PluginHook {
    public var kind: PluginHookKind
    public var filter: PluginFilter
    public var callback: PluginCallback
    public var pluginName: String

    public init(kind: PluginHookKind, filter: PluginFilter, callback: PluginCallback, pluginName: String) {
        this.kind = kind
        this.filter = filter
        this.callback = callback
        this.pluginName = pluginName
    }
}

/// 插件回调函数类型
public type PluginCallback = (PluginContext) -> PluginResult

// ============================================================================
// PluginContext - 插件上下文
// 严格翻译自: bun 中 esbuild 兼容的插件 Build/OnResolve/OnLoad args
// ============================================================================

/// 插件上下文 - 传递给插件回调的参数
public class PluginContext {
    /// 当前处理的路径
    public var path: String
    /// 路径的命名空间
    public var namespace: String
    /// 导入者路径 (解析时)
    public var importer: String
    /// 导入种类
    public var importKind: ImportKind
    /// 解析选项
    public var resolveDir: String
    /// 源代码 (加载时)
    public var source: String
    /// 附加数据
    public var pluginData: ?Any
    /// 日志信息
    public var warnings: ArrayList<String>
    public var errors: ArrayList<String>

    public init() {
        this.path = ""
        this.namespace = "file"
        this.importer = ""
        this.importKind = ImportKind.Stmt
        this.resolveDir = ""
        this.source = ""
        this.pluginData = None
        this.warnings = ArrayList<String>()
        this.errors = ArrayList<String>()
    }

    /// 添加警告
    public func addWarning(message: String): Unit {
        warnings.append(message)
    }

    /// 添加错误
    public func addError(message: String): Unit {
        errors.append(message)
    }

    /// 创建解析上下文
    public static func forResolve(path: String, importer: String, kind: ImportKind): PluginContext {
        let ctx = PluginContext()
        ctx.path = path
        ctx.importer = importer
        ctx.importKind = kind
        return ctx
    }

    /// 创建加载上下文
    public static func forLoad(path: String, namespace: String): PluginContext {
        let ctx = PluginContext()
        ctx.path = path
        ctx.namespace = namespace
        return ctx
    }
}

// ============================================================================
// PluginResult - 插件结果
// 严格翻译自: bun 中 esbuild 兼容的插件 OnResolveResult / OnLoadResult
// ============================================================================

/// 解析结果
public class PluginResolveResult {
    /// 解析后的路径
    public var path: String
    /// 命名空间
    public var namespace: String
    /// 外部标记
    public var external: Bool
    /// 副作用标记
    public var sideEffects: Bool
    /// 插件数据 (传递给 onLoad)
    public var pluginData: ?Any

    public init(path: String) {
        this.path = path
        this.namespace = "file"
        this.external = false
        this.sideEffects = true
        this.pluginData = None
    }
}

/// 加载结果
public class PluginLoadResult {
    /// 加载的内容
    public var contents: String
    /// 加载器类型 (js, ts, css, json, text, binary, etc.)
    public var loader: String
    /// 解析后的路径 (可覆盖)
    public var resolveDir: String
    /// 插件数据
    public var pluginData: ?Any

    public init(contents: String, loader: String) {
        this.contents = contents
        this.loader = loader
        this.resolveDir = ""
        this.pluginData = None
    }
}

/// 插件返回结果
public union PluginResult {
    | Resolve(PluginResolveResult)    // onResolve 结果
    | Load(PluginLoadResult)          // onLoad 结果
    | None                            // 未处理 (继续下一个插件)
    | Error(String)                   // 插件错误
}

// ============================================================================
// Plugin - 插件定义
// ============================================================================

/// 插件定义
public class Plugin {
    /// 插件名称
    public var name: String
    /// 注册的钩子列表
    public var hooks: ArrayList<PluginHook>
    /// 插件初始化函数
    public var setup: ?(PluginSystem) -> Unit

    public init(name: String) {
        this.name = name
        this.hooks = ArrayList<PluginHook>()
        this.setup = None
    }

    public init(name: String, setup: (PluginSystem) -> Unit) {
        this.name = name
        this.hooks = ArrayList<PluginHook>()
        this.setup = Some(setup)
    }

    /// 注册 onResolve 钩子
    public func onResolve(filter: String, callback: PluginCallback): Unit {
        let hook = PluginHook(
            PluginHookKind.OnResolve,
            PluginFilter(filter),
            callback,
            name
        )
        hooks.append(hook)
    }

    /// 注册 onResolve 钩子 (带命名空间)
    public func onResolve(filter: String, namespace: String, callback: PluginCallback): Unit {
        let hook = PluginHook(
            PluginHookKind.OnResolve,
            PluginFilter(filter, namespace),
            callback,
            name
        )
        hooks.append(hook)
    }

    /// 注册 onLoad 钩子
    public func onLoad(filter: String, callback: PluginCallback): Unit {
        let hook = PluginHook(
            PluginHookKind.OnLoad,
            PluginFilter(filter),
            callback,
            name
        )
        hooks.append(hook)
    }

    /// 注册 onLoad 钩子 (带命名空间)
    public func onLoad(filter: String, namespace: String, callback: PluginCallback): Unit {
        let hook = PluginHook(
            PluginHookKind.OnLoad,
            PluginFilter(filter, namespace),
            callback,
            name
        )
        hooks.append(hook)
    }

    /// 注册 onBuild 钩子
    public func onBuild(callback: PluginCallback): Unit {
        let hook = PluginHook(
            PluginHookKind.OnBuild,
            PluginFilter(".*"),
            callback,
            name
        )
        hooks.append(hook)
    }
}

// ============================================================================
// PluginSystem - 插件系统
// 严格翻译自: src/bundler/PluginRunner.zig
// ============================================================================

/// 插件系统 - 管理插件的注册和执行
// 严格翻译自: PluginRunner 中插件的调度逻辑
public class PluginSystem {
    /// 已注册的插件列表
    private var plugins: ArrayList<Plugin>
    /// onResolve 钩子 (按注册顺序)
    private var resolveHooks: ArrayList<PluginHook>
    /// onLoad 钩子 (按注册顺序)
    private var loadHooks: ArrayList<PluginHook>
    /// onBuild 钩子
    private var buildHooks: ArrayList<PluginHook>
    /// 已注册的内置加载器 (文件扩展名 -> 加载器类型)
    private var builtinLoaders: HashMap<String, String>
    /// 插件错误
    private var errors: ArrayList<String>
    /// 插件警告
    private var warnings: ArrayList<String>

    public init() {
        this.plugins = ArrayList<Plugin>()
        this.resolveHooks = ArrayList<PluginHook>()
        this.loadHooks = ArrayList<PluginHook>()
        this.buildHooks = ArrayList<PluginHook>()
        this.builtinLoaders = HashMap<String, String>()
        this.errors = ArrayList<String>()
        this.warnings = ArrayList<String>()
        registerBuiltinLoaders()
    }

    /// 注册插件
    public func register(plugin: Plugin): Unit {
        plugins.append(plugin)

        // 执行 setup 函数
        match (plugin.setup) {
            case Some(setup) => setup(this)
            case None => {}
        }

        // 收集钩子
        for (hook in plugin.hooks) {
            match (hook.kind) {
                case PluginHookKind.OnResolve => resolveHooks.append(hook)
                case PluginHookKind.OnLoad => loadHooks.append(hook)
                case PluginHookKind.OnBuild => buildHooks.append(hook)
            }
        }
    }

    /// 通过 setup 函数注册插件
    public func plugin(name: String, setup: (PluginSystem) -> Unit): Unit {
        let p = Plugin(name, setup)
        register(p)
    }

    // -----------------------------------------------------------------------
    // 钩子执行
    // -----------------------------------------------------------------------

    /// 执行 onResolve 钩子
    // 严格翻译自: PluginRunner.onResolve()
    public func runOnResolve(path: String, importer: String, kind: ImportKind): ?PluginResolveResult {
        let ctx = PluginContext.forResolve(path, importer, kind)

        for (hook in resolveHooks) {
            if (hook.filter.matches(path, "file")) {
                let result = hook.callback(ctx)
                match (result) {
                    case PluginResult.Resolve(resolveResult) =>
                        return Some(resolveResult)
                    case PluginResult.Error(msg) =>
                        errors.append("[${hook.pluginName}] ${msg}")
                        return None
                    case PluginResult.None => {}
                    case _ => {}
                }
            }
        }

        return None
    }

    /// 执行 onLoad 钩子
    // 严格翻译自: PluginRunner.onLoad()
    public func runOnLoad(path: String, namespace: String): ?PluginLoadResult {
        let ctx = PluginContext.forLoad(path, namespace)

        for (hook in loadHooks) {
            if (hook.filter.matches(path, namespace)) {
                let result = hook.callback(ctx)
                match (result) {
                    case PluginResult.Load(loadResult) =>
                        return Some(loadResult)
                    case PluginResult.Error(msg) =>
                        errors.append("[${hook.pluginName}] ${msg}")
                        return None
                    case PluginResult.None => {}
                    case _ => {}
                }
            }
        }

        return None
    }

    /// 执行 onBuild 钩子
    public func runOnBuild(options: BundleOptions): Unit {
        for (hook in buildHooks) {
            let ctx = PluginContext()
            ctx.path = "build"
            let result = hook.callback(ctx)
            match (result) {
                case PluginResult.Error(msg) =>
                    errors.append("[${hook.pluginName}] ${msg}")
                case _ => {}
            }
        }
    }

    /// 检查是否有加载器可以处理此文件
    public func hasLoader(path: String): Bool {
        let ext = Path.extname(path)
        match (builtinLoaders.get(ext)) {
            case Some(_) => return true
            case None => {}
        }
        // 检查插件 onLoad
        for (hook in loadHooks) {
            if (hook.filter.matches(path, "file")) {
                return true
            }
        }
        return false
    }

    /// 获取内置加载器类型
    public func getLoaderType(path: String): String {
        let ext = Path.extname(path)
        match (builtinLoaders.get(ext)) {
            case Some(loader) => return loader
            case None => return "file"
        }
    }

    /// 收集所有警告
    public func getWarnings(): ArrayList<String> {
        return warnings
    }

    /// 收集所有错误
    public func getErrors(): ArrayList<String> {
        return errors
    }

    /// 是否有错误
    public func hasErrors(): Bool {
        return errors.size > 0
    }

    // -----------------------------------------------------------------------
    // 内置加载器注册
    // -----------------------------------------------------------------------

    /// 注册内置文件加载器
    private func registerBuiltinLoaders(): Unit {
        builtinLoaders.put(".js", "js")
        builtinLoaders.put(".mjs", "js")
        builtinLoaders.put(".cjs", "js")
        builtinLoaders.put(".ts", "ts")
        builtinLoaders.put(".mts", "ts")
        builtinLoaders.put(".cts", "ts")
        builtinLoaders.put(".jsx", "jsx")
        builtinLoaders.put(".tsx", "tsx")
        builtinLoaders.put(".css", "css")
        builtinLoaders.put(".json", "json")
        builtinLoaders.put(".wasm", "wasm")
        builtinLoaders.put(".txt", "text")
        builtinLoaders.put(".html", "html")
        builtinLoaders.put(".svg", "dataurl")
        builtinLoaders.put(".png", "dataurl")
        builtinLoaders.put(".jpg", "dataurl")
        builtinLoaders.put(".gif", "dataurl")
        builtinLoaders.put(".woff", "dataurl")
        builtinLoaders.put(".woff2", "dataurl")
        builtinLoaders.put(".ttf", "dataurl")
        builtinLoaders.put(".eot", "dataurl")
    }
}

// ============================================================================
// BuiltinPlugins - 内置插件
// 严格翻译自: src/bundler/ 中内置的 JSON, CSS, Wasm 处理
//   对应: bun 中对各种文件类型的内置 loader 支持
// ============================================================================

/// 内置插件工厂
public class BuiltinPlugins {

    /// JSON 插件 - 将 .json 文件转为 JS 模块
    // 严格翻译自: bun 中对 json loader 的处理
    //   JSON 文件被转换为: export default {...}; 或 module.exports = {...};
    public static func jsonPlugin(): Plugin {
        let plugin = Plugin("bao:json")

        plugin.onLoad("\\.json$", "file", func(ctx: PluginContext): PluginResult {
            let contents = ctx.source
            // 验证 JSON 有效性
            if (!isValidJson(contents)) {
                return PluginResult.Error("Invalid JSON: ${ctx.path}")
            }
            // 包装为 ESM
            let moduleCode = "// JSON module\nexport default ${contents};\n"
            return PluginResult.Load(PluginLoadResult(moduleCode, "js"))
        })

        return plugin
    }

    /// CSS 插件 - 处理 CSS 文件
    // 严格翻译自: bun 中 css loader 的处理
    public static func cssPlugin(): Plugin {
        let plugin = Plugin("bao:css")

        plugin.onLoad("\\.css$", "file", func(ctx: PluginContext): PluginResult {
            // CSS 文件直接传递，不做转换
            return PluginResult.Load(PluginLoadResult(ctx.source, "css"))
        })

        return plugin
    }

    /// Wasm 插件 - 处理 .wasm 文件
    // 严格翻译自: bun 中 wasm loader 的处理
    //   .wasm 文件被转换为使用 WebAssembly.instantiate 的 JS 模块
    public static func wasmPlugin(): Plugin {
        let plugin = Plugin("bao:wasm")

        plugin.onLoad("\\.wasm$", "file", func(ctx: PluginContext): PluginResult {
            // 将 wasm 文件路径包装为异步加载模块
            let moduleCode = StringBuilder()
            moduleCode.append("// WASM module wrapper\n")
            moduleCode.append("var _wasm;\n")
            moduleCode.append("export async function instantiate() {\n")
            moduleCode.append("  if (_wasm) return _wasm;\n")
            moduleCode.append("  const response = await fetch(\"${ctx.path}\");\n")
            moduleCode.append("  const buffer = await response.arrayBuffer();\n")
            moduleCode.append("  const result = await WebAssembly.instantiate(buffer);\n")
            moduleCode.append("  _wasm = result.instance.exports;\n")
            moduleCode.append("  return _wasm;\n")
            moduleCode.append("}\n")
            moduleCode.append("export default instantiate();\n")
            return PluginResult.Load(PluginLoadResult(moduleCode.toString(), "js"))
        })

        return plugin
    }

    /// Text 插件 - 将文件作为文本导入
    // 严格翻译自: bun 中 text loader 的处理
    public static func textPlugin(): Plugin {
        let plugin = Plugin("bao:text")

        plugin.onLoad("\\.txt$", "file", func(ctx: PluginContext): PluginResult {
            // 转义字符串
            let escaped = escapeString(ctx.source)
            let moduleCode = "export default \"${escaped}\";\n"
            return PluginResult.Load(PluginLoadResult(moduleCode, "js"))
        })

        return plugin
    }

    /// 数据 URL 插件 - 处理 data: URL 导入
    public static func dataUrlPlugin(): Plugin {
        let plugin = Plugin("bao:dataurl")

        plugin.onResolve("^data:", "file", func(ctx: PluginContext): PluginResult {
            return PluginResult.Resolve(PluginResolveResult(ctx.path))
        })

        return plugin
    }

    /// HTTP 插件 - 处理 http:// 和 https:// 导入
    public static func httpPlugin(): Plugin {
        let plugin = Plugin("bao:http")

        plugin.onResolve("^https?://", "file", func(ctx: PluginContext): PluginResult {
            let result = PluginResolveResult(ctx.path)
            result.external = true
            result.namespace = "http"
            return PluginResult.Resolve(result)
        })

        return plugin
    }

    /// 注册所有内置插件
    public static func registerAll(system: PluginSystem): Unit {
        system.register(jsonPlugin())
        system.register(cssPlugin())
        system.register(wasmPlugin())
        system.register(textPlugin())
        system.register(dataUrlPlugin())
        system.register(httpPlugin())
    }

    /// 验证 JSON
    private static func isValidJson(s: String): Bool {
        let trimmed = s.trim()
        if (trimmed.length == 0) { return false }
        // 简易验证: 检查首尾括号
        if (trimmed[0] == '{' && trimmed[trimmed.length - 1] == '}') { return true }
        if (trimmed[0] == '[' && trimmed[trimmed.length - 1] == ']') { return true }
        if (trimmed == "true" || trimmed == "false" || trimmed == "null") { return true }
        // 数字
        var allDigits = true
        for (c in trimmed) {
            if (!((c >= '0' && c <= '9') || c == '-' || c == '.' || c == 'e' || c == 'E' || c == '+')) {
                allDigits = false
                break
            }
        }
        return allDigits
    }

    /// 转义字符串
    private static func escapeString(s: String): String {
        let sb = StringBuilder()
        for (c in s) {
            match (c) {
                case '\\' => sb.append("\\\\")
                case '"' => sb.append("\\\"")
                case '\n' => sb.append("\\n")
                case '\r' => sb.append("\\r")
                case '\t' => sb.append("\\t")
                case _ => sb.append(c)
            }
        }
        return sb.toString()
    }
}
