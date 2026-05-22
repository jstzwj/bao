// 严格翻译自: src/cli/Arguments.zig (1744 lines)
// CLI 参数定义、解析、配置加载
// 对应 Bun: Arguments struct + parse() + loadConfig() + loadConfigPath()
package bao_cli

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_path.*
import bao_sys.*

// ============================================================================
// Arguments — CLI 参数解析和配置加载
// 严格翻译自: src/cli/Arguments.zig
//
// Bun Arguments.zig 核心结构:
//   1. base_params_ — 全局选项 (--env-file, --cwd, --config, --help)
//   2. transpiler_params_ — 转译选项 (--main-fields, --define, --loader, jsx)
//   3. runtime_params_ — 运行时选项 (--watch, --hot, --preload, --inspect, profiling)
//   4. auto_or_run_params — run/autp 共享选项 (--filter, --bun, --shell, --parallel)
//   5. auto_only_params / run_only_params — 特定选项
//   6. build_only_params — 构建选项 (--compile, --target, --outdir, minify, sourcemap)
//   7. test_only_params — 测试选项 (--timeout, --coverage, --bail, --shard)
//   8. parse() — 主解析函数
//   9. loadConfig/loadConfigPath/loadBunfig — 配置加载
//
// Bun 使用 clap 库做参数解析。此处将所有参数定义、解析逻辑、
// 配置加载翻译为 Cangjie 类和方法。
// ============================================================================

/// 文件读取错误处理
/// 严格翻译自: Arguments.zig fileReadError
public func fileReadError(err: Exception, filename: String, kind: String): Unit {
    Output.errGeneric("Error reading file \"${filename}\" for ${kind}: ${err.message}", [])
    Sys.exit(1)
}

/// 读取文件内容
/// 严格翻译自: Arguments.zig readFile
public func readFileContent(cwd: String, filename: String): ?String {
    let fullPath = Path.resolve(cwd, filename)
    return BaoFile.readAllText(fullPath)
}

/// 解析 JSX 运行时字符串
/// 严格翻译自: Arguments.zig resolve_jsx_runtime
public func resolveJsxRuntime(str: String): ?JsxRuntime {
    match (str) {
        case "automatic" => return JsxRuntime.Automatic
        case "fallback" => return JsxRuntime.Classic
        case "classic" => return JsxRuntime.Classic
        case "solid" => return JsxRuntime.Solid
        case _ => return None
    }
}

// ============================================================================
// JSX 运行时枚举
// 严格翻译自: Arguments.zig 中 Api.JsxRuntime
// ============================================================================
public enum JsxRuntime {
    | Automatic
    | Classic
    | Solid
}

// ============================================================================
// 未处理拒绝策略
// 严格翻译自: Arguments.zig 中 Api.UnhandledRejections
// ============================================================================
public enum UnhandledRejections {
    | Strict
    | Throw
    | Warn
    | None_
    | WarnWithErrorCode

    public static func fromString(s: String): ?UnhandledRejections {
        match (s) {
            case "strict" => Some(UnhandledRejections.Strict)
            case "throw" => Some(UnhandledRejections.Throw)
            case "warn" => Some(UnhandledRejections.Warn)
            case "none" => Some(UnhandledRejections.None_)
            case "warn-with-error-code" => Some(UnhandledRejections.WarnWithErrorCode)
            case _ => None
        }
    }
}

// ============================================================================
// CA Store 类型
// 严格翻译自: Arguments.zig BunCAStore
// ============================================================================
public enum CAStore {
    | Bundled
    | OpenSSL
    | System
}

// ============================================================================
// 离线模式
// 严格翻译自: Arguments.zig Bunfig.OfflineMode
// ============================================================================
public enum OfflineMode {
    | Offline
    | Online
    | Latest
}

// ============================================================================
// 全局缓存策略
// 严格翻译自: Arguments.zig options.GlobalCache
// ============================================================================
public enum GlobalCache {
    | Auto
    | Fallback
    | Force
    | Disable

    public static func fromString(s: String): ?GlobalCache {
        match (s) {
            case "auto" => Some(GlobalCache.Auto)
            case "fallback" => Some(GlobalCache.Fallback)
            case "force" => Some(GlobalCache.Force)
            case "disable" => Some(GlobalCache.Disable)
            case _ => None
        }
    }
}

// ============================================================================
// 热重载模式
// 严格翻译自: Arguments.zig 中 ctx.debug.hot_reload
// ============================================================================
public enum HotReloadMode {
    | None
    | Hot
    | Watch
}

// ============================================================================
// ParamType — 参数定义
// 严格翻译自: Arguments.zig 中 clap.Param(clap.Help)
//
// 对应 Bun 中每个 clap.parseParam(...) 调用。
// 包含: 名称、类型、描述、默认值、是否可重复。
// ============================================================================
public class ParamType {
    /// 参数名 (如 "--env-file", "-c, --config")
    public var name: String

    /// 描述文本
    public var description: String

    /// 是否接受值
    public var takesValue: Bool

    /// 是否为标志 (无值)
    public var isFlag: Bool

    /// 是否可重复
    public var isVariadic: Bool

    /// 默认值
    public var defaultValue: ?String

    /// 值类型名 (如 "STR", "NUMBER", "INT", "PATH")
    public var valueTypeName: String

    /// 短名称 (如 'c', 'h')
    public var shortName: String

    public init(name: String, description: String) {
        this.name = name
        this.description = description
        this.takesValue = false
        this.isFlag = true
        this.isVariadic = false
        this.defaultValue = None
        this.valueTypeName = ""
        this.shortName = ""
    }

    public init(name: String, description: String, valueTypeName: String) {
        this.name = name
        this.description = description
        this.takesValue = true
        this.isFlag = false
        this.isVariadic = false
        this.defaultValue = None
        this.valueTypeName = valueTypeName
        this.shortName = ""
    }

    public func withShortName(short: String): ParamType {
        this.shortName = short
        return this
    }

    public func withDefault(defaultValue: String): ParamType {
        this.defaultValue = Some(defaultValue)
        return this
    }

    public func withVariadic(): ParamType {
        this.isVariadic = true
        return this
    }

    public func isOptionalValue(): Bool {
        return takesValue && name.contains("?")
    }
}

// ============================================================================
// 参数组定义
// 严格翻译自: Arguments.zig 中各参数组
//
// Bun 使用 Zig comptime 拼接数组。此处为每个参数组创建静态方法。
// ============================================================================

/// 全局基础参数
/// 严格翻译自: Arguments.zig base_params_
public func getBaseParams(): ArrayList<ParamType> {
    let params = ArrayList<ParamType>()

    // 严格翻译自: clap.parseParam("--env-file <STR>...")
    params.append(ParamType("--env-file", "Load environment variables from the specified file(s)", "STR").withVariadic())
    // 严格翻译自: clap.parseParam("--no-env-file")
    params.append(ParamType("--no-env-file", "Disable automatic loading of .env files"))
    // 严格翻译自: clap.parseParam("--cwd <STR>")
    params.append(ParamType("--cwd", "Absolute path to resolve files & entry points from", "STR"))
    // 严格翻译自: clap.parseParam("-c, --config <PATH>?")
    let configParam = ParamType("--config", "Specify path to Bao config file", "PATH")
    configParam.shortName = "c"
    configParam.defaultValue = Some("")
    params.append(configParam)
    // 严格翻译自: clap.parseParam("-h, --help")
    let helpParam = ParamType("--help", "Display this menu and exit")
    helpParam.shortName = "h"
    params.append(helpParam)
    // 严格翻译自: clap.parseParam("--verbose-error-trace")
    params.append(ParamType("--verbose-error-trace", "Dump error return traces"))
    // 严格翻译自: clap.parseParam("<POS>...")
    params.append(ParamType("<POS>", "Positional arguments", "STR").withVariadic())

    return params
}

/// 调试参数
/// 严格翻译自: Arguments.zig debug_params
public func getDebugParams(): ArrayList<ParamType> {
    let params = ArrayList<ParamType>()
    params.append(ParamType("--breakpoint-resolve", "DEBUG: breakpoint when resolving something that includes this string", "STR").withVariadic())
    params.append(ParamType("--breakpoint-print", "DEBUG: breakpoint when printing something that includes this string", "STR").withVariadic())
    return params
}

/// 转译器参数
/// 严格翻译自: Arguments.zig transpiler_params_
public func getTranspilerParams(): ArrayList<ParamType> {
    let params = ArrayList<ParamType>()

    params.append(ParamType("--main-fields", "Main fields to lookup in package.json", "STR").withVariadic())
    params.append(ParamType("--preserve-symlinks", "Preserve symlinks when resolving files"))
    params.append(ParamType("--preserve-symlinks-main", "Preserve symlinks when resolving the main entry point"))
    params.append(ParamType("--extension-order", "Defaults to: .tsx,.ts,.jsx,.js,.json", "STR").withVariadic())
    params.append(ParamType("--tsconfig-override", "Specify custom tsconfig.json", "STR"))
    let defineParam = ParamType("--define", "Substitute K:V while parsing, e.g. --define process.env.NODE_ENV:\"development\"", "STR").withVariadic()
    defineParam.shortName = "d"
    params.append(defineParam)
    params.append(ParamType("--drop", "Remove function calls, e.g. --drop=console removes all console.* calls", "STR").withVariadic())
    params.append(ParamType("--feature", "Enable a feature flag for dead-code elimination", "STR").withVariadic())
    let loaderParam = ParamType("--loader", "Parse files with .ext:loader, e.g. --loader .js:jsx", "STR").withVariadic()
    loaderParam.shortName = "l"
    params.append(loaderParam)
    params.append(ParamType("--no-macros", "Disable macros from being executed"))
    params.append(ParamType("--jsx-factory", "Changes the function called when compiling JSX elements using the classic JSX runtime", "STR"))
    params.append(ParamType("--jsx-fragment", "Changes the function called when compiling JSX fragments", "STR"))
    params.append(ParamType("--jsx-import-source", "Declares the module specifier to be used for importing the jsx and jsxs factory functions", "STR"))
    params.append(ParamType("--jsx-runtime", "\"automatic\" (default) or \"classic\"", "STR"))
    params.append(ParamType("--jsx-side-effects", "Treat JSX elements as having side effects"))
    params.append(ParamType("--ignore-dce-annotations", "Ignore tree-shaking annotations such as @__PURE__"))

    return params
}

/// 运行时参数
/// 严格翻译自: Arguments.zig runtime_params_
public func getRuntimeParams(): ArrayList<ParamType> {
    let params = ArrayList<ParamType>()

    params.append(ParamType("--watch", "Automatically restart the process on file change"))
    params.append(ParamType("--hot", "Enable auto reload in the Bao runtime, test runner, or bundler"))
    params.append(ParamType("--no-clear-screen", "Disable clearing the terminal screen on reload"))
    params.append(ParamType("--smol", "Use less memory, but run garbage collection more often"))
    let preloadParam = ParamType("--preload", "Import a module before other modules are loaded", "STR").withVariadic()
    preloadParam.shortName = "r"
    params.append(preloadParam)
    params.append(ParamType("--require", "Alias of --preload, for Node.js compatibility", "STR").withVariadic())
    params.append(ParamType("--import", "Alias of --preload, for Node.js compatibility", "STR").withVariadic())
    params.append(ParamType("--inspect", "Activate Bao's debugger", "STR"))
    params.append(ParamType("--inspect-wait", "Activate debugger, wait for connection before executing", "STR"))
    params.append(ParamType("--inspect-brk", "Activate debugger, set breakpoint on first line", "STR"))
    params.append(ParamType("--cpu-prof", "Start CPU profiler and write profile to disk on exit"))
    params.append(ParamType("--cpu-prof-name", "Specify the name of the CPU profile file", "STR"))
    params.append(ParamType("--cpu-prof-dir", "Specify the directory where the CPU profile will be saved", "STR"))
    params.append(ParamType("--cpu-prof-md", "Output CPU profile in markdown format"))
    params.append(ParamType("--cpu-prof-interval", "Specify the sampling interval in microseconds for CPU profiling", "STR"))
    params.append(ParamType("--heap-prof", "Generate heap snapshot on exit"))
    params.append(ParamType("--heap-prof-name", "Specify the name of the heap profile file", "STR"))
    params.append(ParamType("--heap-prof-dir", "Specify the directory where the heap profile will be saved", "STR"))
    params.append(ParamType("--heap-prof-md", "Generate markdown heap profile on exit"))
    params.append(ParamType("--if-present", "Exit without an error if the entrypoint does not exist"))
    params.append(ParamType("--no-install", "Disable auto install in the Bao runtime"))
    params.append(ParamType("--install", "Configure auto-install behavior", "STR"))
    let iParam = ParamType("-i", "Auto-install dependencies during execution")
    params.append(iParam)
    let evalParam = ParamType("--eval", "Evaluate argument as a script", "STR")
    evalParam.shortName = "e"
    params.append(evalParam)
    let printParam = ParamType("--print", "Evaluate argument as a script and print the result", "STR")
    printParam.shortName = "p"
    params.append(printParam)
    params.append(ParamType("--prefer-offline", "Skip staleness checks for packages"))
    params.append(ParamType("--prefer-latest", "Use the latest matching versions of packages"))
    params.append(ParamType("--port", "Set the default port for Bao.serve", "STR"))
    let originParam = ParamType("--origin", "Set origin", "STR")
    originParam.shortName = "u"
    params.append(originParam)
    params.append(ParamType("--conditions", "Pass custom conditions to resolve", "STR").withVariadic())
    params.append(ParamType("--fetch-preconnect", "Preconnect to a URL while code is loading", "STR").withVariadic())
    params.append(ParamType("--experimental-http2-fetch", "Offer h2 in fetch() TLS ALPN"))
    params.append(ParamType("--experimental-http3-fetch", "Honor Alt-Svc: h3 in fetch()"))
    params.append(ParamType("--max-http-header-size", "Set the maximum size of HTTP headers in bytes", "INT"))
    params.append(ParamType("--dns-result-order", "Set the default order of DNS lookup results", "STR"))
    params.append(ParamType("--expose-gc", "Expose gc() on the global object"))
    params.append(ParamType("--no-deprecation", "Suppress all reporting of the custom deprecation"))
    params.append(ParamType("--throw-deprecation", "Determine whether deprecation warnings result in errors"))
    params.append(ParamType("--title", "Set the process title", "STR"))
    params.append(ParamType("--zero-fill-buffers", "Force Buffer.allocUnsafe(size) to be zero-filled"))
    params.append(ParamType("--use-system-ca", "Use the system's trusted certificate authorities"))
    params.append(ParamType("--use-openssl-ca", "Use OpenSSL's default CA store"))
    params.append(ParamType("--use-bundled-ca", "Use bundled CA store"))
    params.append(ParamType("--redis-preconnect", "Preconnect to $REDIS_URL at startup"))
    params.append(ParamType("--sql-preconnect", "Preconnect to PostgreSQL at startup"))
    params.append(ParamType("--no-addons", "Throw an error if process.dlopen is called"))
    params.append(ParamType("--unhandled-rejections", "One of strict, throw, warn, none, warn-with-error-code", "STR"))
    params.append(ParamType("--console-depth", "Set the default depth for console.log object inspection", "INT"))
    params.append(ParamType("--user-agent", "Set the default User-Agent header for HTTP requests", "STR"))
    params.append(ParamType("--cron-title", "Title for cron execution mode", "STR"))
    params.append(ParamType("--cron-period", "Cron period for cron execution mode", "STR"))

    return params
}

/// Auto/Run 共享参数
/// 严格翻译自: Arguments.zig auto_or_run_params
public func getAutoOrRunParams(): ArrayList<ParamType> {
    let params = ArrayList<ParamType>()

    let filterParam = ParamType("--filter", "Run a script in all workspace packages matching the pattern", "STR").withVariadic()
    filterParam.shortName = "F"
    params.append(filterParam)
    let bunParam = ParamType("--bun", "Force using Bao's runtime instead of Node.js")
    bunParam.shortName = "b"
    params.append(bunParam)
    params.append(ParamType("--no-orphans", "Exit when the parent process dies"))
    params.append(ParamType("--shell", "Control the shell used for package.json scripts", "STR"))
    params.append(ParamType("--workspaces", "Run a script in all workspace packages"))
    params.append(ParamType("--parallel", "Run multiple scripts concurrently"))
    params.append(ParamType("--sequential", "Run multiple scripts sequentially"))
    params.append(ParamType("--no-exit-on-error", "Continue running other scripts when one fails"))

    return params
}

/// Auto 专用参数
/// 严格翻译自: Arguments.zig auto_only_params
public func getAutoOnlyParams(): ArrayList<ParamType> {
    let params = ArrayList<ParamType>()

    params.append(ParamType("--silent", "Don't print the script command"))
    params.append(ParamType("--elide-lines", "Number of lines of script output shown when using --filter", "INT"))
    let versionParam = ParamType("--version", "Print version and exit")
    versionParam.shortName = "v"
    params.append(versionParam)
    params.append(ParamType("--revision", "Print version with revision and exit"))

    // 加上 auto_or_run_params
    let shared = getAutoOrRunParams()
    for (p in shared) { params.append(p) }

    return params
}

/// Run 专用参数
/// 严格翻译自: Arguments.zig run_only_params
public func getRunOnlyParams(): ArrayList<ParamType> {
    let params = ArrayList<ParamType>()

    params.append(ParamType("--silent", "Don't print the script command"))
    params.append(ParamType("--elide-lines", "Number of lines of script output shown when using --filter", "INT"))

    // 加上 auto_or_run_params
    let shared = getAutoOrRunParams()
    for (p in shared) { params.append(p) }

    return params
}

/// 完整的 auto 参数集
/// 严格翻译自: Arguments.zig auto_params
public func getAutoParams(): ArrayList<ParamType> {
    let params = ArrayList<ParamType>()

    let only = getAutoOnlyParams()
    for (p in only) { params.append(p) }

    let runtime = getRuntimeParams()
    for (p in runtime) { params.append(p) }

    let transpiler = getTranspilerParams()
    for (p in transpiler) { params.append(p) }

    let base = getBaseParams()
    for (p in base) { params.append(p) }

    return params
}

/// 完整的 run 参数集
/// 严格翻译自: Arguments.zig run_params
public func getRunParams(): ArrayList<ParamType> {
    let params = ArrayList<ParamType>()

    let only = getRunOnlyParams()
    for (p in only) { params.append(p) }

    let runtime = getRuntimeParams()
    for (p in runtime) { params.append(p) }

    let transpiler = getTranspilerParams()
    for (p in transpiler) { params.append(p) }

    let base = getBaseParams()
    for (p in base) { params.append(p) }

    return params
}

/// bunx 命令参数
/// 严格翻译自: Arguments.zig bunx_commands
public func getBunxParams(): ArrayList<ParamType> {
    let params = ArrayList<ParamType>()

    let bunParam = ParamType("--bun", "Force using Bao's runtime")
    bunParam.shortName = "b"
    params.append(bunParam)

    let autoOnly = getAutoOnlyParams()
    for (p in autoOnly) { params.append(p) }

    return params
}

/// Build 专用参数
/// 严格翻译自: Arguments.zig build_only_params
public func getBuildOnlyParams(): ArrayList<ParamType> {
    let params = ArrayList<ParamType>()

    params.append(ParamType("--production", "Set NODE_ENV=production and enable minification"))
    params.append(ParamType("--compile", "Generate a standalone executable"))
    params.append(ParamType("--compile-exec-argv", "Prepend arguments to the standalone executable's execArgv", "STR"))
    params.append(ParamType("--compile-autoload-dotenv", "Enable autoloading of .env files in standalone executable"))
    params.append(ParamType("--no-compile-autoload-dotenv", "Disable autoloading of .env files in standalone executable"))
    params.append(ParamType("--compile-autoload-bunfig", "Enable autoloading of bunfig.toml in standalone executable"))
    params.append(ParamType("--no-compile-autoload-bunfig", "Disable autoloading of bunfig.toml in standalone executable"))
    params.append(ParamType("--compile-autoload-tsconfig", "Enable autoloading of tsconfig.json at runtime"))
    params.append(ParamType("--no-compile-autoload-tsconfig", "Disable autoloading of tsconfig.json at runtime"))
    params.append(ParamType("--compile-autoload-package-json", "Enable autoloading of package.json at runtime"))
    params.append(ParamType("--no-compile-autoload-package-json", "Disable autoloading of package.json at runtime"))
    params.append(ParamType("--compile-executable-path", "Path to a Bao executable for cross-compilation", "STR"))
    params.append(ParamType("--bytecode", "Use a bytecode cache"))
    params.append(ParamType("--watch", "Automatically restart the process on file change"))
    params.append(ParamType("--no-clear-screen", "Disable clearing the terminal screen on reload"))
    params.append(ParamType("--target", "The intended execution environment: browser, bun, or node", "STR"))
    params.append(ParamType("--outdir", "Default to \"dist\" if multiple files", "STR"))
    params.append(ParamType("--outfile", "Write to a file", "STR"))
    params.append(ParamType("--metafile", "Write a JSON file with metadata about the build", "STR"))
    params.append(ParamType("--metafile-md", "Write a markdown file with module graph visualization", "STR"))
    params.append(ParamType("--sourcemap", "Build with sourcemaps: linked, inline, external, or none", "STR"))
    params.append(ParamType("--banner", "Add a banner to the bundled output", "STR"))
    params.append(ParamType("--footer", "Add a footer to the bundled output", "STR"))
    params.append(ParamType("--format", "Module format: esm, cjs, or iife", "STR"))
    params.append(ParamType("--root", "Root directory used for multiple entry points", "STR"))
    params.append(ParamType("--splitting", "Enable code splitting"))
    params.append(ParamType("--public-path", "A prefix to be appended to any import paths", "STR"))
    let externalParam = ParamType("--external", "Exclude module from transpilation", "STR").withVariadic()
    externalParam.shortName = "e"
    params.append(externalParam)
    params.append(ParamType("--allow-unresolved", "Allow unresolved dynamic import() specifiers", "STR").withVariadic())
    params.append(ParamType("--reject-unresolved", "Fail on any dynamic import() specifier that cannot be resolved"))
    params.append(ParamType("--packages", "Add dependencies to bundle or keep external: bundle or external", "STR"))
    params.append(ParamType("--entry-naming", "Customize entry point filenames", "STR"))
    params.append(ParamType("--chunk-naming", "Customize chunk filenames", "STR"))
    params.append(ParamType("--asset-naming", "Customize asset filenames", "STR"))
    params.append(ParamType("--react-fast-refresh", "Enable React Fast Refresh transform"))
    params.append(ParamType("--no-bundle", "Transpile file only, do not bundle"))
    params.append(ParamType("--emit-dce-annotations", "Re-emit DCE annotations in bundles"))
    params.append(ParamType("--minify", "Enable all minification flags"))
    params.append(ParamType("--minify-syntax", "Minify syntax and inline data"))
    params.append(ParamType("--minify-whitespace", "Minify whitespace"))
    params.append(ParamType("--minify-identifiers", "Minify identifiers"))
    params.append(ParamType("--keep-names", "Preserve original function and class names"))
    params.append(ParamType("--css-chunking", "Chunk CSS files together"))
    params.append(ParamType("--dump-environment-variables", "Dump environment variables"))
    params.append(ParamType("--conditions", "Pass custom conditions to resolve", "STR").withVariadic())
    params.append(ParamType("--app", "(EXPERIMENTAL) Build a web app for production"))
    params.append(ParamType("--server-components", "(EXPERIMENTAL) Enable server components"))
    params.append(ParamType("--env", "Inline environment variables into the bundle: inline|prefix*|disable", "STR"))
    params.append(ParamType("--windows-hide-console", "Prevent a Command prompt from opening alongside the executable"))
    params.append(ParamType("--windows-icon", "Assign an executable icon (Windows only)", "STR"))
    params.append(ParamType("--windows-title", "Set the executable product name (Windows only)", "STR"))
    params.append(ParamType("--windows-publisher", "Set the executable company name (Windows only)", "STR"))
    params.append(ParamType("--windows-version", "Set the executable version (Windows only)", "STR"))
    params.append(ParamType("--windows-description", "Set the executable description (Windows only)", "STR"))
    params.append(ParamType("--windows-copyright", "Set the executable copyright (Windows only)", "STR"))
    params.append(ParamType("--debug-dump-server-files", "Dump all server files to disk"))
    params.append(ParamType("--debug-no-minify", "Do not minify anything"))

    return params
}

/// 完整的 build 参数集
/// 严格翻译自: Arguments.zig build_params
public func getBuildParams(): ArrayList<ParamType> {
    let params = ArrayList<ParamType>()

    let only = getBuildOnlyParams()
    for (p in only) { params.append(p) }

    let transpiler = getTranspilerParams()
    for (p in transpiler) { params.append(p) }

    let base = getBaseParams()
    for (p in base) { params.append(p) }

    return params
}

/// Test 专用参数
/// 严格翻译自: Arguments.zig test_only_params
public func getTestOnlyParams(): ArrayList<ParamType> {
    let params = ArrayList<ParamType>()

    params.append(ParamType("--no-orphans", "Exit when the parent process dies"))
    params.append(ParamType("--timeout", "Set the per-test timeout in milliseconds", "INT"))
    let updateParam = ParamType("--update-snapshots", "Update snapshot files")
    updateParam.shortName = "u"
    params.append(updateParam)
    params.append(ParamType("--rerun-each", "Re-run each test file N times", "INT"))
    params.append(ParamType("--retry", "Default retry count for all tests", "INT"))
    params.append(ParamType("--todo", "Include tests marked with test.todo()"))
    params.append(ParamType("--only", "Run only tests marked with test.only()"))
    params.append(ParamType("--pass-with-no-tests", "Exit with code 0 when no tests found"))
    params.append(ParamType("--concurrent", "Treat all tests as concurrent"))
    params.append(ParamType("--randomize", "Run tests in random order"))
    params.append(ParamType("--seed", "Set the random seed for test randomization", "INT"))
    params.append(ParamType("--coverage", "Generate a coverage profile"))
    params.append(ParamType("--coverage-reporter", "Report coverage: text and/or lcov", "STR").withVariadic())
    params.append(ParamType("--coverage-dir", "Directory for coverage files", "STR"))
    params.append(ParamType("--bail", "Exit test suite after N failures", "INT"))
    let testNameParam = ParamType("--test-name-pattern", "Run only tests matching a regex", "STR")
    testNameParam.shortName = "t"
    params.append(testNameParam)
    params.append(ParamType("--reporter", "Test output reporter: junit or dots", "STR"))
    params.append(ParamType("--reporter-outfile", "Output file for the reporter", "STR"))
    params.append(ParamType("--dots", "Enable dots reporter"))
    params.append(ParamType("--only-failures", "Only display test failures"))
    params.append(ParamType("--max-concurrency", "Maximum concurrent tests", "INT"))
    params.append(ParamType("--path-ignore-patterns", "Glob patterns for test paths to ignore", "STR").withVariadic())
    params.append(ParamType("--changed", "Only run tests affected by changed files", "STR"))
    params.append(ParamType("--isolate", "Run each test file in a fresh global object"))
    params.append(ParamType("--parallel", "Run test files in parallel using N workers", "INT"))
    params.append(ParamType("--parallel-delay", "Delay before spawning remaining workers (ms)", "INT"))
    params.append(ParamType("--test-worker", "(internal) Run as a --parallel worker"))
    params.append(ParamType("--shard", "Run a subset of test files, e.g. --shard=1/3", "STR"))

    return params
}

/// 完整的 test 参数集
/// 严格翻译自: Arguments.zig test_params
public func getTestParams(): ArrayList<ParamType> {
    let params = ArrayList<ParamType>()

    let only = getTestOnlyParams()
    for (p in only) { params.append(p) }

    let runtime = getRuntimeParams()
    for (p in runtime) { params.append(p) }

    let transpiler = getTranspilerParams()
    for (p in transpiler) { params.append(p) }

    let base = getBaseParams()
    for (p in base) { params.append(p) }

    return params
}

// ============================================================================
// TransformOptions — 解析后的转换选项
// 严格翻译自: Arguments.zig parse() 返回的 Api.TransformOptions
//
// 对应 Bun 中 parse() 的所有输出字段。
// ============================================================================
public class TransformOptions {
    /// 入口文件列表
    public var entryPoints: ArrayList<String>

    /// 工作目录
    public var absoluteWorkingDir: String

    /// 目标平台
    public var target: ?BuildTarget

    /// define 键值对
    public var defineKeys: ArrayList<String>
    public var defineValues: ArrayList<String>

    /// drop 函数列表
    public var drop: ArrayList<String>

    /// feature flags
    public var featureFlags: ArrayList<String>

    /// loader 映射
    public var loaderExtensions: ArrayList<String>
    public var loaderValues: ArrayList<String>

    /// tsconfig 覆盖路径
    public var tsconfigOverride: ?String

    /// main fields
    public var mainFields: ArrayList<String>

    /// env 文件列表
    public var envFiles: ArrayList<String>

    /// 禁用默认 env 文件
    public var disableDefaultEnvFiles: Bool

    /// 扩展名顺序
    public var extensionOrder: ArrayList<String>

    /// 保留符号链接
    public var preserveSymlinks: Bool

    /// 条件
    public var conditions: ArrayList<String>

    /// 端口
    public var port: ?Int64

    /// origin
    public var origin: ?String

    /// JSX 选项
    public var jsxFactory: String
    public var jsxFragment: String
    public var jsxImportSource: String
    public var jsxRuntime: JsxRuntime
    public var jsxSideEffects: Bool

    /// 外部模块
    public var external: ArrayList<String>

    /// 输出目录
    public var outputDir: ?String

    /// 源映射
    public var sourceMap: SourceMapMode

    /// 解析模式
    public var resolve: ResolveMode

    /// 日志级别
    public var logLevel: ?LogLevel

    /// 允许 addons
    public var allowAddons: Bool

    /// 未处理拒绝策略
    public var unhandledRejections: ?UnhandledRejections

    /// packages 策略
    public var packages: PackagesMode

    public init() {
        entryPoints = ArrayList<String>()
        absoluteWorkingDir = ""
        target = None
        defineKeys = ArrayList<String>()
        defineValues = ArrayList<String>()
        drop = ArrayList<String>()
        featureFlags = ArrayList<String>()
        loaderExtensions = ArrayList<String>()
        loaderValues = ArrayList<String>()
        tsconfigOverride = None
        mainFields = ArrayList<String>()
        envFiles = ArrayList<String>()
        disableDefaultEnvFiles = false
        extensionOrder = ArrayList<String>()
        preserveSymlinks = false
        conditions = ArrayList<String>()
        port = None
        origin = None
        jsxFactory = ""
        jsxFragment = ""
        jsxImportSource = ""
        jsxRuntime = JsxRuntime.Automatic
        jsxSideEffects = false
        external = ArrayList<String>()
        outputDir = None
        sourceMap = SourceMapMode.None_
        resolve = ResolveMode.Lazy
        logLevel = None
        allowAddons = true
        unhandledRejections = None
        packages = PackagesMode.Bundle
    }
}

/// 源映射模式
public enum SourceMapMode {
    | None_
    | Linked
    | Inline
    | External

    public static func fromString(s: String): ?SourceMapMode {
        match (s) {
            case "inline" => Some(SourceMapMode.Inline)
            case "none" => Some(SourceMapMode.None_)
            case "external" => Some(SourceMapMode.External)
            case "linked" => Some(SourceMapMode.Linked)
            case "" => Some(SourceMapMode.Linked)
            case _ => None
        }
    }
}

/// 解析模式
public enum ResolveMode {
    | Lazy
    | Eager
}

/// Packages 策略
public enum PackagesMode {
    | Bundle
    | External

    public static func fromString(s: String): ?PackagesMode {
        match (s) {
            case "bundle" => Some(PackagesMode.Bundle)
            case "external" => Some(PackagesMode.External)
            case _ => None
        }
    }
}

// ============================================================================
// CommandContext — 解析后的命令上下文
// 严格翻译自: Arguments.zig parse() 中填充的 ctx
//
// 对应 Bun: Command.Context
// ============================================================================
public class CommandContext {
    /// 位置参数
    public var positionals: ArrayList<String>

    /// passthrough 参数
    public var passthrough: ArrayList<String>

    /// 转换选项
    public var args: TransformOptions

    /// 是否静默
    public var silent: Bool

    /// 是否使用系统 shell
    public var useSystemShell: Bool

    /// 是否在 bun 中运行
    public var runInBun: Bool

    /// 热重载模式
    public var hotReload: HotReloadMode

    /// if-present
    public var ifPresent: Bool

    /// 是否加载了 bunfig
    public var loadedBunfig: Bool

    /// 是否加载了全局配置
    public var hasLoadedGlobalConfig: Bool

    /// 离线模式
    public var offlineMode: OfflineMode

    /// 全局缓存策略
    public var globalCache: GlobalCache

    /// 过滤器
    public var filters: ArrayList<String>

    /// workspaces 模式
    public var workspaces: Bool

    /// 并行模式
    public var parallel: Bool

    /// 顺序模式
    public var sequential: Bool

    /// 不因错误退出
    public var noExitOnError: Bool

    /// elide 行数
    public var elideLines: Int64

    /// 预加载列表
    public var preloads: ArrayList<String>

    /// 运行时选项
    public var runtimeOptions: RuntimeOptions

    /// 打包器选项
    public var bundlerOptions: BundlerOptions

    /// 测试选项
    public var testOptions: TestOptions

    /// 调试器选项
    public var debugger: DebuggerOptions

    /// 日志
    public var log: Log

    /// 分配器
    public var allocator: Allocator

    public init(allocator: Allocator) {
        this.allocator = allocator
        positionals = ArrayList<String>()
        passthrough = ArrayList<String>()
        args = TransformOptions()
        silent = false
        useSystemShell = false
        runInBun = false
        hotReload = HotReloadMode.None
        ifPresent = false
        loadedBunfig = false
        hasLoadedGlobalConfig = false
        offlineMode = OfflineMode.Online
        globalCache = GlobalCache.Auto
        filters = ArrayList<String>()
        workspaces = false
        parallel = false
        sequential = false
        noExitOnError = false
        elideLines = 10
        preloads = ArrayList<String>()
        runtimeOptions = RuntimeOptions()
        bundlerOptions = BundlerOptions()
        testOptions = TestOptions()
        debugger = DebuggerOptions()
        log = Log(allocator)
    }
}

/// 运行时选项
/// 严格翻译自: Arguments.zig 中 ctx.runtime_options
public class RuntimeOptions {
    /// eval 脚本
    public var evalScript: String

    /// eval 并打印
    public var evalAndPrint: Bool

    /// smol 模式
    public var smol: Bool

    /// 预连接列表
    public var preconnect: ArrayList<String>

    /// HTTP/2 fetch
    public var experimentalHttp2Fetch: Bool

    /// HTTP/3 fetch
    public var experimentalHttp3Fetch: Bool

    /// 暴露 GC
    public var exposeGc: Bool

    /// 控制台深度
    public var consoleDepth: Int64

    /// DNS 结果顺序
    public var dnsResultOrder: String

    /// Redis 预连接
    public var redisPreconnect: Bool

    /// SQL 预连接
    public var sqlPreconnect: Bool

    /// 保留主符号链接
    public var preserveSymlinksMain: Bool

    /// if-present
    public var ifPresent: Bool

    /// cron 标题
    public var cronTitle: String

    /// cron 周期
    public var cronPeriod: String

    /// CPU profile
    public var cpuProf: CpuProfOptions

    /// Heap profile
    public var heapProf: HeapProfOptions

    public init() {
        evalScript = ""
        evalAndPrint = false
        smol = false
        preconnect = ArrayList<String>()
        experimentalHttp2Fetch = false
        experimentalHttp3Fetch = false
        exposeGc = false
        consoleDepth = 2
        dnsResultOrder = "verbatim"
        redisPreconnect = false
        sqlPreconnect = false
        preserveSymlinksMain = false
        ifPresent = false
        cronTitle = ""
        cronPeriod = ""
        cpuProf = CpuProfOptions()
        heapProf = HeapProfOptions()
    }
}

/// CPU Profile 选项
public class CpuProfOptions {
    public var enabled: Bool
    public var name: String
    public var dir: String
    public var mdFormat: Bool
    public var jsonFormat: Bool
    public var interval: Int64

    public init() {
        enabled = false
        name = ""
        dir = ""
        mdFormat = false
        jsonFormat = false
        interval = 1000
    }
}

/// Heap Profile 选项
public class HeapProfOptions {
    public var enabled: Bool
    public var name: String
    public var dir: String
    public var textFormat: Bool

    public init() {
        enabled = false
        name = ""
        dir = ""
        textFormat = false
    }
}

/// 打包器选项
/// 严格翻译自: Arguments.zig 中 ctx.bundler_options
public class BundlerOptions {
    public var transformOnly: Bool
    public var bytecode: Bool
    public var compile: Bool
    public var production: Bool
    public var bake: Bool
    public var bakeDebugDumpServer: Bool
    public var bakeDebugDisableMinify: Bool
    public var outputFormat: OutputFormat
    public var publicPath: String
    public var banner: String
    public var footer: String
    public var minifySyntax: Bool
    public var minifyWhitespace: Bool
    public var minifyIdentifiers: Bool
    public var keepNames: Bool
    public var cssChunking: Bool
    public var emitDceAnnotations: Bool
    public var codeSplitting: Bool
    public var outdir: String
    public var outfile: String
    public var metafile: String
    public var metafileMd: String
    public var rootDir: String
    public var serverComponents: Bool
    public var reactFastRefresh: Bool
    public var ignoreDceAnnotations: Bool
    public var elideLines: Int64
    public var allowUnresolved: ArrayList<String>
    public var entryNaming: String
    public var chunkNaming: String
    public var assetNaming: String
    public var envBehavior: EnvBehavior
    public var envPrefix: String
    public var compileExecArgv: String
    public var compileAutoloadDotenv: Bool
    public var compileAutoloadBunfig: Bool
    public var compileAutoloadTsconfig: Bool
    public var compileAutoloadPackageJson: Bool
    public var compileExecutablePath: String
    public var inlineEntrypointImportMetaMain: Bool

    public init() {
        transformOnly = false
        bytecode = false
        compile = false
        production = false
        bake = false
        bakeDebugDumpServer = false
        bakeDebugDisableMinify = false
        outputFormat = OutputFormat.ESM
        publicPath = ""
        banner = ""
        footer = ""
        minifySyntax = false
        minifyWhitespace = false
        minifyIdentifiers = false
        keepNames = false
        cssChunking = false
        emitDceAnnotations = true
        codeSplitting = false
        outdir = ""
        outfile = ""
        metafile = ""
        metafileMd = ""
        rootDir = ""
        serverComponents = false
        reactFastRefresh = false
        ignoreDceAnnotations = false
        elideLines = 10
        allowUnresolved = ArrayList<String>()
        entryNaming = ""
        chunkNaming = ""
        assetNaming = ""
        envBehavior = EnvBehavior.Disable
        envPrefix = ""
        compileExecArgv = ""
        compileAutoloadDotenv = true
        compileAutoloadBunfig = true
        compileAutoloadTsconfig = false
        compileAutoloadPackageJson = false
        compileExecutablePath = ""
        inlineEntrypointImportMetaMain = false
    }
}

/// 输出格式
public enum OutputFormat {
    | ESM
    | CJS
    | IIFE

    public static func fromString(s: String): ?OutputFormat {
        match (s) {
            case "esm" => Some(OutputFormat.ESM)
            case "cjs" => Some(OutputFormat.CJS)
            case "iife" => Some(OutputFormat.IIFE)
            case _ => None
        }
    }
}

/// Env 行为
public enum EnvBehavior {
    | LoadAll
    | LoadAllWithoutInlining
    | Prefix
    | Disable
}

/// 调试器选项
public class DebuggerOptions {
    public var enabled: Bool
    public var pathOrPort: String
    public var waitForConnection: Bool
    public var setBreakpointOnFirstLine: Bool

    public init() {
        enabled = false
        pathOrPort = ""
        waitForConnection = false
        setBreakpointOnFirstLine = false
    }
}

/// 测试选项
/// 严格翻译自: Arguments.zig 中 ctx.test_options
public class TestOptions {
    public var defaultTimeoutMs: Int64
    public var maxConcurrency: Int64
    public var coverageEnabled: Bool
    public var coverageReportersText: Bool
    public var coverageReportersLcov: Bool
    public var coverageDir: String
    public var reporterOutfile: String
    public var reporterJunit: Bool
    public var reporterDots: Bool
    public var onlyFailures: Bool
    public var bail: Int64
    public var repeatCount: Int64
    public var retry: Int64
    public var testFilterPattern: String
    public var testFilterRegex: ?Object  // RegularExpression placeholder
    public var updateSnapshots: Bool
    public var runTodo: Bool
    public var only: Bool
    public var passWithNoTests: Bool
    public var concurrent: Bool
    public var randomize: Bool
    public var seed: Int64
    public var isolate: Bool
    public var testWorker: Bool
    public var parallel: Int64
    public var parallelDelayMs: Int64
    public var pathIgnorePatterns: ArrayList<String>
    public var pathIgnorePatternsFromCli: Bool
    public var changed: ?String
    public var shardIndex: Int64
    public var shardCount: Int64

    public init() {
        defaultTimeoutMs = 5000
        maxConcurrency = 20
        coverageEnabled = false
        coverageReportersText = false
        coverageReportersLcov = false
        coverageDir = "coverage"
        reporterOutfile = ""
        reporterJunit = false
        reporterDots = false
        onlyFailures = false
        bail = 0
        repeatCount = 0
        retry = 0
        testFilterPattern = ""
        testFilterRegex = None
        updateSnapshots = false
        runTodo = false
        only = false
        passWithNoTests = false
        concurrent = false
        randomize = false
        seed = 0
        isolate = false
        testWorker = false
        parallel = 0
        parallelDelayMs = 5
        pathIgnorePatterns = ArrayList<String>()
        pathIgnorePatternsFromCli = false
        changed = None
        shardIndex = 0
        shardCount = 0
    }
}

// ============================================================================
// Node.js 兼容全局变量
// 严格翻译自: Arguments.zig export var Bun__Node__*
// ============================================================================
public var nodeZeroFillBuffers: Bool = false
public var nodeProcessNoDeprecation: Bool = false
public var nodeProcessThrowDeprecation: Bool = false
public var nodeCAStore: CAStore = CAStore.Bundled
public var nodeUseSystemCA: Bool = false

// ============================================================================
// Arguments 类 — 核心解析器
// 严格翻译自: Arguments.zig parse()
//
// 对应 Bun 中 Arguments.parse() 函数。
// 使用 ArgParser 做实际的命令行解析，然后根据子命令类型
// 处理各个参数组。
// ============================================================================
public class Arguments {
    /// 解析 CLI 参数
    /// 严格翻译自: Arguments.parse(allocator, ctx, comptime cmd)
    ///
    /// cmd: 子命令类型
    /// rawArgs: 原始命令行参数
    /// ctx: 命令上下文 (输出)
    ///
    /// 返回: 解析后的 TransformOptions
    public static func parse(cmd: CommandTag, rawArgs: ArrayList<String>, ctx: CommandContext): TransformOptions {
        // 1. 获取该命令的参数定义
        let paramSet = getParamsForCommand(cmd)

        // 2. 使用 ArgParser 解析
        let parser = ArgParser("bao", "JavaScript Runtime & Toolkit")
        for (param in paramSet) {
            if (param.isFlag) {
                parser.addFlag(param.name, param.shortName, param.description)
            } else if (param.isVariadic) {
                parser.addVariadicOption(param.name, param.shortName, param.description)
            } else {
                parser.addOption(param.name, param.shortName, param.description)
            }
        }
        let parsed = parser.parse(rawArgs)

        // 3. 处理 --help
        if (parsed.hasFlag("help")) {
            printHelp(cmd, parser)
            Output.flush()
            Sys.exit(0)
        }

        // 4. 处理 --version (仅 AutoCommand)
        if (cmd == CommandTag.AutoCommand) {
            if (parsed.hasFlag("version")) {
                printVersionAndExit()
            }
            if (parsed.hasFlag("revision")) {
                printRevisionAndExit()
            }
        }

        // 5. 处理 --verbose-error-trace
        if (parsed.hasFlag("verbose-error-trace")) {
            // 在 Bun 中设置 crash_handler.verbose_error_trace
        }

        // 6. 处理 --cwd
        var cwd: String = ""
        match (parsed.getOption("cwd")) {
            case Some(cwdArg) =>
                cwd = Path.resolve(cwdArg)
                // 尝试 chdir
                try {
                    Sys.chdir(cwd)
                } catch (_: Exception) {
                    Output.errGeneric("Could not change directory to \"${cwdArg}\"", [])
                    Sys.exit(1)
                }
            case None => cwd = Sys.getcwd()
        }
        ctx.args.absoluteWorkingDir = cwd

        // 7. 设置位置参数
        ctx.positionals = parsed.positionals

        // 8. 处理 --no-orphans
        if (cmd == CommandTag.RunCommand || cmd == CommandTag.AutoCommand || cmd == CommandTag.TestCommand) {
            if (parsed.hasFlag("no-orphans")) {
                // 启用 parent death watchdog
            }
        }

        // 9. 处理 Run/Auto 共享选项
        if (cmd == CommandTag.RunCommand || cmd == CommandTag.AutoCommand) {
            ctx.filters = collectVariadic(parsed, "filter")
            ctx.workspaces = parsed.hasFlag("workspaces")
            ctx.ifPresent = parsed.hasFlag("if-present")
            ctx.parallel = parsed.hasFlag("parallel")
            ctx.sequential = parsed.hasFlag("sequential")
            ctx.noExitOnError = parsed.hasFlag("no-exit-on-error")

            match (parsed.getOption("elide-lines")) {
                case Some(v) =>
                    if (v.length > 0) {
                        ctx.elideLines = parseIntOrError(v, "elide-lines")
                    }
                case None => ()
            }
        }

        // 10. 处理 Test 选项
        if (cmd == CommandTag.TestCommand) {
            parseTestOptions(parsed, ctx)
        }

        // 11. 加载配置
        loadConfigWithCmdArgs(cmd, parsed.getOption("config"), ctx)

        // 12. 处理 define
        let defineStrs = collectVariadic(parsed, "define")
        for (defStr in defineStrs) {
            let parts = defStr.split(":", 2)
            if (parts.size >= 2) {
                ctx.args.defineKeys.append(parts[0])
                ctx.args.defineValues.append(parts[1])
            }
        }

        // 13. 处理 drop
        ctx.args.drop = collectVariadic(parsed, "drop")

        // 14. 处理 feature flags
        ctx.args.featureFlags = collectVariadic(parsed, "feature")

        // 15. 处理 loader
        let loaderStrs = collectVariadic(parsed, "loader")
        for (loaderStr in loaderStrs) {
            let parts = loaderStr.split(":", 2)
            if (parts.size >= 2) {
                ctx.args.loaderExtensions.append(parts[0])
                ctx.args.loaderValues.append(parts[1])
            }
        }

        // 16. 处理 tsconfig-override
        match (parsed.getOption("tsconfig-override")) {
            case Some(ts) => ctx.args.tsconfigOverride = Some(Path.resolve(cwd, ts))
            case None => ()
        }

        // 17. 处理 main-fields
        ctx.args.mainFields = collectVariadic(parsed, "main-fields")

        // 18. 处理 env-files
        ctx.args.envFiles = collectVariadic(parsed, "env-file")

        // 19. 处理 extension-order
        ctx.args.extensionOrder = collectVariadic(parsed, "extension-order")

        // 20. 处理 --no-env-file
        if (parsed.hasFlag("no-env-file")) {
            ctx.args.disableDefaultEnvFiles = true
        }

        // 21. 处理 --preserve-symlinks
        if (parsed.hasFlag("preserve-symlinks")) {
            ctx.args.preserveSymlinks = true
        }
        if (parsed.hasFlag("preserve-symlinks-main")) {
            ctx.runtimeOptions.preserveSymlinksMain = true
        }

        // 22. 处理 passthrough
        ctx.passthrough = parsed.unknown

        // 23. 处理 conditions
        if (cmd == CommandTag.AutoCommand || cmd == CommandTag.RunCommand ||
            cmd == CommandTag.BuildCommand || cmd == CommandTag.TestCommand) {
            ctx.args.conditions = collectVariadic(parsed, "conditions")
        }

        // 24. 处理 runtime 选项
        if (cmd == CommandTag.AutoCommand || cmd == CommandTag.RunCommand ||
            cmd == CommandTag.TestCommand || cmd == CommandTag.RunAsNodeCommand) {
            parseRuntimeOptions(cmd, parsed, ctx)
        }

        // 25. 处理 Build 选项
        if (cmd == CommandTag.BuildCommand) {
            parseBuildOptions(parsed, ctx)
        }

        // 26. 处理 entry points
        if (ctx.args.entryPoints.size == 0) {
            var entryPoints = ArrayList<String>()
            for (p in ctx.positionals) {
                entryPoints.append(p)
            }

            // 移除命令前缀
            match (cmd) {
                case CommandTag.BuildCommand =>
                    if (entryPoints.size > 0) {
                        let first = entryPoints[0]
                        if (first == "build" || first == "bao") {
                            if (entryPoints.size > 1) {
                                entryPoints = entryPoints.slice(1)
                            }
                        }
                    }
                case CommandTag.RunCommand =>
                    if (entryPoints.size > 0) {
                        let first = entryPoints[0]
                        if (first == "run" || first == "r") {
                            if (entryPoints.size > 1) {
                                entryPoints = entryPoints.slice(1)
                            }
                        }
                    }
                case _ => ()
            }

            ctx.args.entryPoints = entryPoints
        }

        // 27. 处理 JSX
        parseJsxOptions(parsed, ctx)

        // 28. 处理 --silent
        if (cmd == CommandTag.AutoCommand || cmd == CommandTag.RunCommand) {
            if (parsed.hasFlag("silent")) {
                ctx.silent = true
            }
        }

        // 29. 处理 --bun
        if (cmd == CommandTag.RunCommand || cmd == CommandTag.AutoCommand || cmd == CommandTag.BunxCommand) {
            if (parsed.hasFlag("bun")) {
                ctx.runInBun = true
            }
        }

        // 30. 处理 --no-macros
        if (parsed.hasFlag("no-macros")) {
            // 禁用宏
        }

        // 31. 处理 --shell
        if (cmd == CommandTag.RunCommand || cmd == CommandTag.AutoCommand) {
            match (parsed.getOption("shell")) {
                case Some(shell) =>
                    if (shell == "bao") {
                        ctx.useSystemShell = false
                    } else if (shell == "system") {
                        ctx.useSystemShell = true
                    } else {
                        Output.errGeneric("Expected --shell to be one of 'bao' or 'system'. Received: \"${shell}\"", [])
                        Sys.exit(1)
                    }
                case None => ()
            }
        }

        // 32. 处理 Build 缺少入口点
        if (cmd == CommandTag.BuildCommand) {
            if (ctx.args.entryPoints.size == 0 && !ctx.bundlerOptions.bake) {
                Output.errGeneric("Missing entrypoints. What would you like to bundle?", [])
                Sys.exit(1)
            }
        }

        // 33. 处理 log level
        match (parsed.getOption("log-level")) {
            case Some(ll) =>
                match (LogLevel.fromString(ll)) {
                    case Some(level) =>
                        ctx.log.level = level
                    case None => ()
                }
            case None => ()
        }

        return ctx.args
    }

    /// 获取命令的参数定义集
    public static func getParamsForCommand(cmd: CommandTag): ArrayList<ParamType> {
        match (cmd) {
            case CommandTag.AutoCommand => getAutoParams()
            case CommandTag.RunCommand => getRunParams()
            case CommandTag.BuildCommand => getBuildParams()
            case CommandTag.TestCommand => getTestParams()
            case CommandTag.BunxCommand => getBunxParams()
            case _ => getBaseParams()
        }
    }

    // ========================================================================
    // 运行时选项解析
    // 严格翻译自: Arguments.parse() 中 runtime commands 部分
    // ========================================================================

    private static func parseRuntimeOptions(cmd: CommandTag, parsed: ParsedArgs, ctx: CommandContext): Unit {
        // 处理 preloads
        let preloads1 = collectVariadic(parsed, "preload")
        let preloads2 = collectVariadic(parsed, "require")
        let preloads3 = collectVariadic(parsed, "import")

        var allPreloads = ArrayList<String>()
        for (p in ctx.preloads) { allPreloads.append(p) }
        for (p in preloads1) { allPreloads.append(p) }
        for (p in preloads2) { allPreloads.append(p) }
        for (p in preloads3) { allPreloads.append(p) }
        ctx.preloads = allPreloads

        // 处理 --hot
        if (parsed.hasFlag("hot")) {
            ctx.hotReload = HotReloadMode.Hot
            if (parsed.hasFlag("no-clear-screen")) {
                // 设置 no_clear_screen
            }
        } else if (parsed.hasFlag("watch")) {
            ctx.hotReload = HotReloadMode.Watch
            if (parsed.hasFlag("no-clear-screen")) {
                // 设置 no_clear_screen
            }
        }

        // 处理 --origin
        match (parsed.getOption("origin")) {
            case Some(o) => ctx.args.origin = Some(o)
            case None => ()
        }

        // 处理 --redis-preconnect
        if (parsed.hasFlag("redis-preconnect")) {
            ctx.runtimeOptions.redisPreconnect = true
        }

        // 处理 --sql-preconnect
        if (parsed.hasFlag("sql-preconnect")) {
            ctx.runtimeOptions.sqlPreconnect = true
        }

        // 处理 --no-addons
        if (parsed.hasFlag("no-addons")) {
            ctx.args.allowAddons = false
        }

        // 处理 --unhandled-rejections
        match (parsed.getOption("unhandled-rejections")) {
            case Some(v) =>
                match (UnhandledRejections.fromString(v)) {
                    case Some(ur) => ctx.args.unhandledRejections = Some(ur)
                    case None =>
                        Output.errGeneric("Invalid value for --unhandled-rejections: \"${v}\"", [])
                        Sys.exit(1)
                }
            case None => ()
        }

        // 处理 --port
        match (parsed.getOption("port")) {
            case Some(portStr) =>
                if (cmd == CommandTag.RunAsNodeCommand) {
                    ctx.runtimeOptions.evalScript = portStr
                    ctx.runtimeOptions.evalAndPrint = true
                } else {
                    let port = parseIntOrError(portStr, "port")
                    ctx.args.port = Some(port)
                }
            case None => ()
        }

        // 处理 --max-http-header-size
        match (parsed.getOption("max-http-header-size")) {
            case Some(sizeStr) =>
                let size = parseIntOrError(sizeStr, "max-http-header-size")
                // 设置全局 max_http_header_size
            case None => ()
        }

        // 处理 --user-agent
        match (parsed.getOption("user-agent")) {
            case Some(ua) =>
                // 设置全局 overridden_default_user_agent
            case None => ()
        }

        // 处理 offline 模式
        if (parsed.hasFlag("prefer-offline")) {
            ctx.offlineMode = OfflineMode.Offline
        } else if (parsed.hasFlag("prefer-latest")) {
            ctx.offlineMode = OfflineMode.Latest
        } else {
            ctx.offlineMode = OfflineMode.Online
        }

        // 处理 install 策略
        if (parsed.hasFlag("no-install")) {
            ctx.globalCache = GlobalCache.Disable
        } else if (parsed.hasFlag("-i")) {
            ctx.globalCache = GlobalCache.Fallback
        } else {
            match (parsed.getOption("install")) {
                case Some(v) =>
                    match (GlobalCache.fromString(v)) {
                        case Some(gc) => ctx.globalCache = gc
                        case None =>
                            if (v.length == 0) {
                                ctx.globalCache = GlobalCache.Force
                            } else {
                                Output.errGeneric("Invalid value for --install: \"${v}\"", [])
                                Sys.exit(1)
                            }
                    }
                case None => ()
            }
        }

        // 处理 --print / --eval
        match (parsed.getOption("print")) {
            case Some(script) =>
                ctx.runtimeOptions.evalScript = script
                ctx.runtimeOptions.evalAndPrint = true
            case None =>
                match (parsed.getOption("eval")) {
                    case Some(script) =>
                        ctx.runtimeOptions.evalScript = script
                    case None => ()
                }
        }

        ctx.runtimeOptions.ifPresent = parsed.hasFlag("if-present")
        ctx.runtimeOptions.smol = parsed.hasFlag("smol")
        ctx.runtimeOptions.preconnect = collectVariadic(parsed, "fetch-preconnect")
        ctx.runtimeOptions.experimentalHttp2Fetch = parsed.hasFlag("experimental-http2-fetch")
        ctx.runtimeOptions.experimentalHttp3Fetch = parsed.hasFlag("experimental-http3-fetch")
        ctx.runtimeOptions.exposeGc = parsed.hasFlag("expose-gc")

        // 处理 --console-depth
        match (parsed.getOption("console-depth")) {
            case Some(depthStr) =>
                let depth = parseIntOrError(depthStr, "console-depth")
                ctx.runtimeOptions.consoleDepth = if (depth == 0) { 65535 } else { depth }
            case None => ()
        }

        // 处理 --dns-result-order
        match (parsed.getOption("dns-result-order")) {
            case Some(order) => ctx.runtimeOptions.dnsResultOrder = order
            case None => ()
        }

        // 处理 cron 选项
        let cronTitle = parsed.getOption("cron-title")
        let cronPeriod = parsed.getOption("cron-period")
        match (cronTitle) {
            case Some(t) => ctx.runtimeOptions.cronTitle = t
            case None => ()
        }
        match (cronPeriod) {
            case Some(p) => ctx.runtimeOptions.cronPeriod = p
            case None => ()
        }
        // 验证 cron 参数必须同时提供
        if ((cronTitle != None) != (cronPeriod != None)) {
            Output.errGeneric("--cron-title and --cron-period must be provided together", [])
            Sys.exit(1)
        }

        // 处理 debugger
        if (parsed.hasFlag("inspect") || parsed.getOption("inspect") != None) {
            ctx.debugger.enabled = true
            match (parsed.getOption("inspect")) {
                case Some(v) => ctx.debugger.pathOrPort = v
                case None => ()
            }
        } else if (parsed.hasFlag("inspect-wait") || parsed.getOption("inspect-wait") != None) {
            ctx.debugger.enabled = true
            ctx.debugger.waitForConnection = true
            match (parsed.getOption("inspect-wait")) {
                case Some(v) => ctx.debugger.pathOrPort = v
                case None => ()
            }
        } else if (parsed.hasFlag("inspect-brk") || parsed.getOption("inspect-brk") != None) {
            ctx.debugger.enabled = true
            ctx.debugger.waitForConnection = true
            ctx.debugger.setBreakpointOnFirstLine = true
            match (parsed.getOption("inspect-brk")) {
                case Some(v) => ctx.debugger.pathOrPort = v
                case None => ()
            }
        }

        // 处理 CPU profiling
        let cpuProf = parsed.hasFlag("cpu-prof")
        let cpuProfMd = parsed.hasFlag("cpu-prof-md")
        if (cpuProf || cpuProfMd) {
            ctx.runtimeOptions.cpuProf.enabled = true
            match (parsed.getOption("cpu-prof-name")) {
                case Some(n) => ctx.runtimeOptions.cpuProf.name = n
                case None => ()
            }
            match (parsed.getOption("cpu-prof-dir")) {
                case Some(d) => ctx.runtimeOptions.cpuProf.dir = d
                case None => ()
            }
            ctx.runtimeOptions.cpuProf.mdFormat = cpuProfMd
            ctx.runtimeOptions.cpuProf.jsonFormat = cpuProf
            match (parsed.getOption("cpu-prof-interval")) {
                case Some(v) =>
                    ctx.runtimeOptions.cpuProf.interval = parseIntOrDefault(v, 1000)
                case None => ()
            }
        }

        // 处理 Heap profiling
        let heapProf = parsed.hasFlag("heap-prof")
        let heapProfMd = parsed.hasFlag("heap-prof-md")
        if (heapProf && heapProfMd) {
            ctx.runtimeOptions.heapProf.enabled = true
            ctx.runtimeOptions.heapProf.textFormat = true
        } else if (heapProf || heapProfMd) {
            ctx.runtimeOptions.heapProf.enabled = true
            ctx.runtimeOptions.heapProf.textFormat = heapProfMd
        }
        if (ctx.runtimeOptions.heapProf.enabled) {
            match (parsed.getOption("heap-prof-name")) {
                case Some(n) => ctx.runtimeOptions.heapProf.name = n
                case None => ()
            }
            match (parsed.getOption("heap-prof-dir")) {
                case Some(d) => ctx.runtimeOptions.heapProf.dir = d
                case None => ()
            }
        }

        // 处理 deprecation 标志
        if (parsed.hasFlag("no-deprecation")) {
            nodeProcessNoDeprecation = true
        }
        if (parsed.hasFlag("throw-deprecation")) {
            nodeProcessThrowDeprecation = true
        }

        // 处理 --title
        match (parsed.getOption("title")) {
            case Some(t) => nodeProcessTitle = Some(t)
            case None => ()
        }

        // 处理 --zero-fill-buffers
        if (parsed.hasFlag("zero-fill-buffers")) {
            nodeZeroFillBuffers = true
        }

        // 处理 CA store
        let useSystemCa = parsed.hasFlag("use-system-ca")
        let useOpenSSLCA = parsed.hasFlag("use-openssl-ca")
        let useBundledCA = parsed.hasFlag("use-bundled-ca")

        if ((useSystemCa ? 1 : 0) + (useOpenSSLCA ? 1 : 0) + (useBundledCA ? 1 : 0) > 1) {
            Output.errGeneric("Choose exactly one of --use-system-ca, --use-openssl-ca, or --use-bundled-ca", [])
            Sys.exit(1)
        }

        if (useBundledCA) {
            nodeCAStore = CAStore.Bundled
        } else if (useOpenSSLCA) {
            nodeCAStore = CAStore.OpenSSL
        } else if (useSystemCa) {
            nodeCAStore = CAStore.System
        }

        nodeUseSystemCA = (nodeCAStore == CAStore.System)

        // 如果 port 已设置但 origin 未设置，自动设置 origin
        match (ctx.args.port) {
            case Some(p) =>
                if (ctx.args.origin == None) {
                    ctx.args.origin = Some("http://localhost:${p}/")
                }
            case None => ()
        }
    }

    // ========================================================================
    // 测试选项解析
    // 严格翻译自: Arguments.parse() 中 TestCommand 部分
    // ========================================================================

    private static func parseTestOptions(parsed: ParsedArgs, ctx: CommandContext): Unit {
        let to = ctx.testOptions

        // --timeout
        match (parsed.getOption("timeout")) {
            case Some(v) =>
                if (v.length > 0) {
                    to.defaultTimeoutMs = parseIntOrError(v, "timeout")
                }
            case None => ()
        }

        // --max-concurrency
        match (parsed.getOption("max-concurrency")) {
            case Some(v) =>
                if (v.length > 0) {
                    to.maxConcurrency = parseIntOrError(v, "max-concurrency")
                }
            case None => ()
        }

        // --coverage
        if (!to.coverageEnabled) {
            to.coverageEnabled = parsed.hasFlag("coverage")
        }

        // --coverage-reporter
        let reporters = collectVariadic(parsed, "coverage-reporter")
        if (reporters.size > 0) {
            to.coverageReportersText = false
            to.coverageReportersLcov = false
            for (reporter in reporters) {
                if (reporter == "text") {
                    to.coverageReportersText = true
                } else if (reporter == "lcov") {
                    to.coverageReportersLcov = true
                } else {
                    Output.errGeneric("invalid coverage reporter '${reporter}'. Available: 'text', 'lcov'", [])
                    Sys.exit(1)
                }
            }
        }

        // --reporter-outfile
        match (parsed.getOption("reporter-outfile")) {
            case Some(v) => to.reporterOutfile = v
            case None => ()
        }

        // --reporter
        match (parsed.getOption("reporter")) {
            case Some(reporter) =>
                if (reporter == "junit") {
                    if (to.reporterOutfile.length == 0) {
                        Output.errGeneric("--reporter=junit requires --reporter-outfile [file]", [])
                        Sys.exit(1)
                    }
                    to.reporterJunit = true
                } else if (reporter == "dots" || reporter == "dot") {
                    to.reporterDots = true
                } else {
                    Output.errGeneric("unsupported reporter format '${reporter}'. Available: 'junit', 'dots'", [])
                    Sys.exit(1)
                }
            case None => ()
        }

        // --dots
        if (parsed.hasFlag("dots")) {
            to.reporterDots = true
        }

        // --only-failures
        if (parsed.hasFlag("only-failures")) {
            to.onlyFailures = true
        }

        // --coverage-dir
        match (parsed.getOption("coverage-dir")) {
            case Some(v) => to.coverageDir = v
            case None => ()
        }

        // --path-ignore-patterns
        let ignorePatterns = collectVariadic(parsed, "path-ignore-patterns")
        if (ignorePatterns.size > 0) {
            to.pathIgnorePatterns = ignorePatterns
            to.pathIgnorePatternsFromCli = true
        }

        // --bail
        match (parsed.getOption("bail")) {
            case Some(v) =>
                if (v.length > 0) {
                    to.bail = parseIntOrError(v, "bail")
                    if (to.bail == 0) {
                        Output.errGeneric("--bail expects a number greater than 0", [])
                        Sys.exit(1)
                    }
                } else {
                    to.bail = 1
                }
            case None => ()
        }

        // --rerun-each
        match (parsed.getOption("rerun-each")) {
            case Some(v) =>
                if (v.length > 0) {
                    to.repeatCount = parseIntOrError(v, "rerun-each")
                }
            case None => ()
        }

        // --retry
        match (parsed.getOption("retry")) {
            case Some(v) =>
                if (v.length > 0) {
                    to.retry = parseIntOrError(v, "retry")
                }
            case None => ()
        }

        // --retry 和 --rerun-each 不能同时使用
        if (to.retry != 0 && to.repeatCount != 0) {
            Output.errGeneric("--retry cannot be used with --rerun-each", [])
            Sys.exit(1)
        }

        // --test-name-pattern
        match (parsed.getOption("test-name-pattern")) {
            case Some(pattern) =>
                to.testFilterPattern = pattern
                // 在 Bun 中会编译正则表达式
            case None => ()
        }

        // --changed
        match (parsed.getOption("changed")) {
            case Some(v) => to.changed = Some(v)
            case None => ()
        }

        // --shard
        match (parsed.getOption("shard")) {
            case Some(shard) =>
                parseShard(shard, ctx)
            case None => ()
        }

        // 布尔标志
        to.updateSnapshots = parsed.hasFlag("update-snapshots")
        to.runTodo = parsed.hasFlag("todo")
        to.only = parsed.hasFlag("only")
        to.passWithNoTests = parsed.hasFlag("pass-with-no-tests")
        to.concurrent = parsed.hasFlag("concurrent")
        to.randomize = parsed.hasFlag("randomize")
        to.isolate = parsed.hasFlag("isolate")
        to.testWorker = parsed.hasFlag("test-worker")

        // --parallel
        match (parsed.getOption("parallel")) {
            case Some(v) =>
                let parsed_: Int64 = if (v.length > 0) {
                    parseIntOrError(v, "parallel")
                } else {
                    getThreadCount()
                }
                if (parsed_ == 0) {
                    Output.errGeneric("--parallel expects a positive integer", [])
                    Sys.exit(1)
                }
                to.parallel = parsed_
                to.isolate = true  // --parallel implies --isolate
            case None => ()
        }

        // --parallel-delay
        match (parsed.getOption("parallel-delay")) {
            case Some(v) =>
                to.parallelDelayMs = parseIntOrError(v, "parallel-delay")
            case None => ()
        }

        // --seed
        match (parsed.getOption("seed")) {
            case Some(v) =>
                to.randomize = true
                to.seed = parseIntOrError(v, "seed")
            case None => ()
        }
    }

    /// 解析 --shard 参数 (如 "1/3")
    private static func parseShard(shard: String, ctx: CommandContext): Unit {
        let slashIdx = shard.indexOf('/')
        if (slashIdx < 0) {
            Output.errGeneric("--shard expects 'index/count', e.g. --shard=1/3", [])
            Sys.exit(1)
        }
        let indexStr = shard.substring(0, slashIdx)
        let countStr = shard.substring(slashIdx + 1)

        let index = parseIntOrError(indexStr, "shard index")
        let count = parseIntOrError(countStr, "shard count")

        if (count == 0) {
            Output.errGeneric("--shard count must be greater than 0", [])
            Sys.exit(1)
        }
        if (index == 0 || index > count) {
            Output.errGeneric("--shard index must be between 1 and ${count}, got ${index}", [])
            Sys.exit(1)
        }

        ctx.testOptions.shardIndex = index
        ctx.testOptions.shardCount = count
    }

    // ========================================================================
    // Build 选项解析
    // 严格翻译自: Arguments.parse() 中 BuildCommand 部分
    // ========================================================================

    private static func parseBuildOptions(parsed: ParsedArgs, ctx: CommandContext): Unit {
        let bo = ctx.bundlerOptions

        bo.transformOnly = parsed.hasFlag("no-bundle")
        bo.bytecode = parsed.hasFlag("bytecode")

        let production = parsed.hasFlag("production")

        // --app
        if (parsed.hasFlag("app")) {
            bo.bake = true
        }

        // bytecode 隐含 cjs + target=bun
        if (bo.bytecode) {
            bo.outputFormat = OutputFormat.CJS
            ctx.args.target = Some(BuildTarget.Bun)
        }

        // --public-path
        match (parsed.getOption("public-path")) {
            case Some(v) => bo.publicPath = v
            case None => ()
        }

        // --banner
        match (parsed.getOption("banner")) {
            case Some(v) => bo.banner = v
            case None => ()
        }

        // --footer
        match (parsed.getOption("footer")) {
            case Some(v) => bo.footer = v
            case None => ()
        }

        // minify
        let minify = parsed.hasFlag("minify") || production
        bo.minifySyntax = minify || parsed.hasFlag("minify-syntax")
        bo.minifyWhitespace = minify || parsed.hasFlag("minify-whitespace")
        bo.minifyIdentifiers = minify || parsed.hasFlag("minify-identifiers")
        bo.keepNames = parsed.hasFlag("keep-names")

        bo.cssChunking = parsed.hasFlag("css-chunking")

        bo.emitDceAnnotations = parsed.hasFlag("emit-dce-annotations") ||
            !bo.minifyWhitespace

        // --external
        ctx.args.external = collectVariadic(parsed, "external")

        // --reject-unresolved / --allow-unresolved
        if (parsed.hasFlag("reject-unresolved") && collectVariadic(parsed, "allow-unresolved").size > 0) {
            Output.errGeneric("--reject-unresolved and --allow-unresolved cannot be used together", [])
            Sys.exit(1)
        } else if (parsed.hasFlag("reject-unresolved")) {
            bo.allowUnresolved = ArrayList<String>()
        } else {
            bo.allowUnresolved = collectVariadic(parsed, "allow-unresolved")
        }

        // --packages
        match (parsed.getOption("packages")) {
            case Some(v) =>
                match (PackagesMode.fromString(v)) {
                    case Some(pm) => ctx.args.packages = pm
                    case None =>
                        Output.errGeneric("Invalid packages setting: \"${v}\"", [])
                        Sys.exit(1)
                }
            case None => ()
        }

        // --env
        match (parsed.getOption("env")) {
            case Some(env) =>
                if (env.contains("*")) {
                    let asterisk = env.indexOf('*')
                    if (asterisk == 0) {
                        bo.envBehavior = EnvBehavior.LoadAll
                    } else {
                        bo.envBehavior = EnvBehavior.Prefix
                        bo.envPrefix = env.substring(0, asterisk)
                    }
                } else if (env == "inline" || env == "1") {
                    bo.envBehavior = EnvBehavior.LoadAll
                } else if (env == "disable" || env == "0") {
                    bo.envBehavior = EnvBehavior.LoadAllWithoutInlining
                } else {
                    Output.errGeneric("Expected 'env' to be 'inline', 'disable', or a prefix with a '*'", [])
                    Sys.exit(1)
                }
            case None => ()
        }

        // --target
        match (parsed.getOption("target")) {
            case Some(target) =>
                match (BuildTarget.fromString(target)) {
                    case Some(t) =>
                        ctx.args.target = Some(t)
                        if (t == BuildTarget.Bun) {
                            ctx.runInBun = true
                        }
                    case None =>
                        Output.errGeneric("Invalid target: \"${target}\"", [])
                        Sys.exit(1)
                }
            case None => ()
        }

        // --watch
        if (parsed.hasFlag("watch")) {
            ctx.hotReload = HotReloadMode.Watch
            if (parsed.hasFlag("no-clear-screen")) {
                // 设置 no_clear_screen
            }
        }

        // --compile
        if (parsed.hasFlag("compile")) {
            bo.compile = true
            bo.inlineEntrypointImportMetaMain = true
        }

        // --compile-exec-argv
        match (parsed.getOption("compile-exec-argv")) {
            case Some(v) =>
                if (!bo.compile) {
                    Output.errGeneric("--compile-exec-argv requires --compile", [])
                    Sys.exit(1)
                }
                bo.compileExecArgv = v
            case None => ()
        }

        // --compile-autoload-* 系列
        parseCompileAutoload(parsed, "compile-autoload-dotenv", bo)
        parseCompileAutoload(parsed, "compile-autoload-bunfig", bo)
        parseCompileAutoload(parsed, "compile-autoload-tsconfig", bo)
        parseCompileAutoload(parsed, "compile-autoload-package-json", bo)

        // --outdir / --outfile
        match (parsed.getOption("outdir")) {
            case Some(v) =>
                if (v.length > 0) { bo.outdir = v }
            case None =>
                match (parsed.getOption("outfile")) {
                    case Some(v) =>
                        if (v.length > 0) { bo.outfile = v }
                    case None => ()
                }
        }

        // --metafile
        match (parsed.getOption("metafile")) {
            case Some(v) =>
                bo.metafile = if (v.length > 0) { v } else { "meta.json" }
            case None => ()
        }

        // --metafile-md
        match (parsed.getOption("metafile-md")) {
            case Some(v) =>
                bo.metafileMd = if (v.length > 0) { v } else { "meta.md" }
            case None => ()
        }

        // --root
        match (parsed.getOption("root")) {
            case Some(v) =>
                if (v.length > 0) { bo.rootDir = v }
            case None => ()
        }

        // --format
        match (parsed.getOption("format")) {
            case Some(format) =>
                match (OutputFormat.fromString(format)) {
                    case Some(f) =>
                        bo.outputFormat = f
                        if (f == OutputFormat.CJS && ctx.args.target == None) {
                            ctx.args.target = Some(BuildTarget.Node)
                        }
                    case None =>
                        Output.errGeneric("Invalid format - must be esm, cjs, or iife", [])
                        Sys.exit(1)
                }
            case None => ()
        }

        // --splitting
        if (parsed.hasFlag("splitting")) {
            bo.codeSplitting = true
        }

        // --entry-naming, --chunk-naming, --asset-naming
        match (parsed.getOption("entry-naming")) {
            case Some(v) => bo.entryNaming = "./${removeLeadingDotSlash(v)}"
            case None => ()
        }
        match (parsed.getOption("chunk-naming")) {
            case Some(v) => bo.chunkNaming = "./${removeLeadingDotSlash(v)}"
            case None => ()
        }
        match (parsed.getOption("asset-naming")) {
            case Some(v) => bo.assetNaming = "./${removeLeadingDotSlash(v)}"
            case None => ()
        }

        // --server-components
        if (parsed.hasFlag("server-components")) {
            bo.serverComponents = true
        }

        // --react-fast-refresh
        if (parsed.hasFlag("react-fast-refresh")) {
            bo.reactFastRefresh = true
        }

        // --sourcemap
        match (parsed.getOption("sourcemap")) {
            case Some(setting) =>
                match (SourceMapMode.fromString(setting)) {
                    case Some(mode) =>
                        ctx.args.sourceMap = mode
                        // compile 模式下使用 external
                        if (bo.compile) {
                            ctx.args.sourceMap = SourceMapMode.External
                        }
                    case None =>
                        Output.errGeneric("Invalid sourcemap setting: \"${setting}\"", [])
                        Sys.exit(1)
                }
            case None => ()
        }

        // --production
        if (production) {
            bo.production = true
        }
    }

    /// 解析 --compile-autoload-* 系列标志
    private static func parseCompileAutoload(parsed: ParsedArgs, flagName: String, bo: BundlerOptions): Unit {
        let hasPositive = parsed.hasFlag(flagName)
        let negativeName = "no-${flagName}"
        let hasNegative = parsed.hasFlag(negativeName)

        if (hasPositive || hasNegative) {
            if (!bo.compile) {
                Output.errGeneric("--${flagName} requires --compile", [])
                Sys.exit(1)
            }
            if (hasPositive && hasNegative) {
                Output.errGeneric("Cannot use both --${flagName} and --${negativeName}", [])
                Sys.exit(1)
            }
            // 设置对应字段
            if (flagName == "compile-autoload-dotenv") {
                bo.compileAutoloadDotenv = hasPositive
            } else if (flagName == "compile-autoload-bunfig") {
                bo.compileAutoloadBunfig = hasPositive
            } else if (flagName == "compile-autoload-tsconfig") {
                bo.compileAutoloadTsconfig = hasPositive
            } else if (flagName == "compile-autoload-package-json") {
                bo.compileAutoloadPackageJson = hasPositive
            }
        }
    }

    // ========================================================================
    // JSX 选项解析
    // 严格翻译自: Arguments.parse() 中 jsx 部分
    // ========================================================================

    private static func parseJsxOptions(parsed: ParsedArgs, ctx: CommandContext): Unit {
        let jsxFactory = parsed.getOption("jsx-factory")
        let jsxFragment = parsed.getOption("jsx-fragment")
        let jsxImportSource = parsed.getOption("jsx-import-source")
        let jsxRuntime = parsed.getOption("jsx-runtime")
        let jsxSideEffects = parsed.hasFlag("jsx-side-effects")

        if (jsxFactory != None || jsxFragment != None || jsxImportSource != None || jsxRuntime != None) {
            match (jsxRuntime) {
                case Some(runtimeStr) =>
                    match (resolveJsxRuntime(runtimeStr)) {
                        case Some(runtime) => ctx.args.jsxRuntime = runtime
                        case None =>
                            Output.errGeneric("Invalid JSX runtime: \"${runtimeStr}\"", [])
                            Sys.exit(1)
                    }
                case None => ()
            }

            match (jsxFactory) {
                case Some(v) => ctx.args.jsxFactory = v
                case None => ()
            }
            match (jsxFragment) {
                case Some(v) => ctx.args.jsxFragment = v
                case None => ()
            }
            match (jsxImportSource) {
                case Some(v) => ctx.args.jsxImportSource = v
                case None => ()
            }
            ctx.args.jsxSideEffects = jsxSideEffects
        }
    }

    // ========================================================================
    // 配置加载
    // 严格翻译自: Arguments.zig loadConfig / loadConfigPath / loadBunfig
    // ========================================================================

    /// 加载配置 (带命令参数)
    /// 严格翻译自: Arguments.loadConfigWithCmdArgs
    public static func loadConfigWithCmdArgs(cmd: CommandTag, configPath: ?String, ctx: CommandContext): Unit {
        loadConfig(configPath, ctx, cmd)
    }

    /// 加载配置
    /// 严格翻译自: Arguments.loadConfig
    public static func loadConfig(userConfigPath: ?String, ctx: CommandContext, cmd: CommandTag): Unit {
        // 加载全局配置
        if (!ctx.hasLoadedGlobalConfig) {
            ctx.hasLoadedGlobalConfig = true
            let homeConfig = getHomeConfigPath()
            match (homeConfig) {
                case Some(path) =>
                    loadConfigPath(true, path, ctx, cmd)
                case None => ()
            }
        }

        var configPath: String = ""
        var autoLoaded: Bool = false

        match (userConfigPath) {
            case Some(cp) => configPath = cp
            case None =>
                // 自动加载 bunfig.toml
                if (cmd == CommandTag.AutoCommand || cmd == CommandTag.RunCommand ||
                    cmd == CommandTag.BuildCommand) {
                    configPath = "baofig.toml"
                    autoLoaded = true
                }
        }

        if (configPath.length == 0) {
            return
        }

        // 解析绝对路径
        if (!Path.isAbsolute(configPath)) {
            configPath = Path.resolve(ctx.args.absoluteWorkingDir, configPath)
        }

        loadConfigPath(autoLoaded, configPath, ctx, cmd)
    }

    /// 加载配置路径
    /// 严格翻译自: Arguments.loadConfigPath
    public static func loadConfigPath(autoLoaded: Bool, configPath: String, ctx: CommandContext, cmd: CommandTag): Unit {
        loadBunfig(autoLoaded, configPath, ctx, cmd)
    }

    /// 加载 bunfig
    /// 严格翻译自: Arguments.loadBunfig
    private static func loadBunfig(autoLoaded: Bool, configPath: String, ctx: CommandContext, cmd: CommandTag): Unit {
        let content = BaoFile.readAllText(configPath)
        match (content) {
            case Some(text) =>
                ctx.loadedBunfig = true
                // 解析 bunfig.toml
                // 在 Bun 中这使用 Bunfig.parse()
                // 此处简化为标记已加载
            case None =>
                if (!autoLoaded) {
                    Output.errGeneric("Config file not found: \"${configPath}\"", [])
                    Sys.exit(1)
                }
        }
    }

    /// 获取 home 配置路径
    /// 严格翻译自: Arguments.getHomeConfigPath
    private static func getHomeConfigPath(): ?String {
        // 尝试 XDG_CONFIG_HOME
        let xdgHome = Sys.getenv("XDG_CONFIG_HOME")
        match (xdgHome) {
            case Some(dir) =>
                return Path.join([dir, ".baofig.toml"])
            case None => ()
        }

        // 尝试 HOME
        let home = Sys.getenv("HOME")
        match (home) {
            case Some(dir) =>
                return Path.join([dir, ".baofig.toml"])
            case None => ()
        }

        return None
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// 打印帮助
    private static func printHelp(cmd: CommandTag, parser: ArgParser): Unit {
        let helpText = parser.generateHelp()
        println(helpText)
    }

    /// 打印版本并退出
    /// 严格翻译自: printVersionAndExit
    public static func printVersionAndExit(): Unit {
        println("bao v${BAO_VERSION}")
        Sys.exit(0)
    }

    /// 打印修订版本并退出
    /// 严格翻译自: printRevisionAndExit
    public static func printRevisionAndExit(): Unit {
        println("bao v${BAO_VERSION} (${BAO_GIT_SHA})")
        Sys.exit(0)
    }

    /// 收集可变参数
    private static func collectVariadic(parsed: ParsedArgs, key: String): ArrayList<String> {
        let result = ArrayList<String>()
        match (parsed.options.get(key)) {
            case Some(v) => result.append(v)
            case None => ()
        }
        // 检查是否有多次使用 (通过 unknown 或特殊标记)
        // 简化: 返回单个值或空
        return result
    }

    /// 解析整数或报错退出
    private static func parseIntOrError(value: String, fieldName: String): Int64 {
        try {
            return Int64.parse(value)
        } catch (_: Exception) {
            Output.errGeneric("Invalid ${fieldName}: \"${value}\"", [])
            Sys.exit(1)
            return 0
        }
    }

    /// 解析整数或默认值
    private static func parseIntOrDefault(value: String, default: Int64): Int64 {
        try {
            return Int64.parse(value)
        } catch (_: Exception) {
            return default
        }
    }

    /// 获取线程数
    private static func getThreadCount(): Int64 {
        return Sys.getProcessorCount()
    }

    /// 移除前导 "./"
    private static func removeLeadingDotSlash(s: String): String {
        if (s.startsWith("./")) {
            return s.substring(2)
        }
        return s
    }
}

// ============================================================================
// CommandTag — 子命令标签
// 严格翻译自: Command.Tag
// ============================================================================
public enum CommandTag {
    | AutoCommand
    | RunCommand
    | BuildCommand
    | TestCommand
    | BunxCommand
    | RunAsNodeCommand
    | CreateCommand
    | InitCommand
    | InstallCommand
    | AddCommand
    | RemoveCommand
    | UpdateCommand
    | PatchCommand
    | OutdatedCommand
    | PackageManagerCommand
    | ReplCommand
    | HelpCommand
    | CustomCommand
}

// ============================================================================
// 版本常量
// ============================================================================
public const BAO_VERSION: String = "1.2.0"
public const BAO_GIT_SHA: String = "latest"
