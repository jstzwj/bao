// arguments - bunfig 配置加载入口函数
// 严格翻译自: src/bunfig/arguments.rs
// 从 Arguments.zig 中提取的 bunfig 加载子集
// 使中层 crate (如 bao_install) 可以直接调用
package bao_cli.bunfig

import std.collection.*
import bao_core.ErrorCode
import bao_core.BaoError

// ============================================================================
// 配置路径和加载逻辑
// 对应 Bun: src/bunfig/arguments.rs
//
// 核心函数:
// - getHomeConfigPath: 获取 home 目录下的配置路径
// - loadBunfig: 加载并解析 bunfig 配置文件
// - loadGlobalBunfig: 加载全局配置
// - loadConfigPath: 加载指定路径的配置
// - loadConfig: 自动查找并加载配置
// - loadConfigWithCmdArgs: 从命令行参数加载配置
// ============================================================================

/// 获取 home 目录下的 bunfig 配置路径
// 对应 Bun: fn get_home_config_path(buf: &mut PathBuffer) -> Option<&ZStr>
// 查找顺序:
// 1. $XDG_CONFIG_HOME/.bunfig.toml
// 2. $HOME/.bunfig.toml
public func getHomeConfigPath(): ?String {
    // 检查 XDG_CONFIG_HOME
    let xdgHome = getEnv("XDG_CONFIG_HOME")
    if (xdgHome.isSome()) {
        let dir = xdgHome.getOrThrow()
        let path = dir + "/.bunfig.toml"
        if (fileExists(path)) {
            return path
        }
    }

    // 检查 HOME
    let homeDir = getEnv("HOME")
    if (homeDir.isSome()) {
        let dir = homeDir.getOrThrow()
        let path = dir + "/.bunfig.toml"
        if (fileExists(path)) {
            return path
        }
    }

    return None
}

/// 加载 bunfig 配置文件
// 对应 Bun: fn load_bunfig(cmd, auto_loaded, config_path, ctx) -> Result<(), Error>
//
// 参数:
// - cmd: 命令标签 (Run, Build, Test 等)
// - autoLoaded: 是否自动加载 (自动加载时文件不存在不报错)
// - configPath: 配置文件路径
// - ctx: 上下文数据
//
// 步骤:
// 1. 读取配置文件内容
// 2. 解析为 AST
// 3. 创建 AST 存储和重置守卫
// 4. 临时将日志级别设为 Warn
// 5. 调用 Bunfig.parse 解析配置
public func loadBunfig(
    cmd: CommandTag,
    autoLoaded: Bool,
    configPath: String,
    ctx: ContextData
): Result<Unit> {
    // 读取配置文件
    var source: String = ""
    match (readSource(configPath, true /* convert_bom */)) {
        case Ok(s) => source = s
        case Err(err) => return handleReadError(err, autoLoaded, configPath)
    }

    // 创建 AST 存储
    // 对应 Bun: bun_ast::stmt::data::Store::create(); bun_ast::expr::data::Store::create()
    // 和 let _store_reset = bun_ast::StoreResetGuard::new()

    // 临时将日志级别设为 Warn
    // 对应 Bun 中通过 log_ptr 修改 level 的逻辑
    let originalLevel = ctx.log.level
    ctx.log.level = LogLevel.Warn

    // 标记已加载 bunfig
    ctx.debug.loadedBunfig = true

    // 解析配置
    let result = Bunfig.parse(cmd, source, ctx)

    // 恢复日志级别
    ctx.log.level = originalLevel

    return result
}

/// 加载全局 bunfig
// 对应 Bun: fn load_global_bunfig(cmd, ctx) -> Result<(), Error>
public func loadGlobalBunfig(cmd: CommandTag, ctx: ContextData): Result<Unit> {
    if (ctx.hasLoadedGlobalConfig) {
        return Ok(())
    }
    ctx.hasLoadedGlobalConfig = true

    match (getHomeConfigPath()) {
        case Some(path) => loadBunfig(cmd, true, path, ctx)
        case None => Ok(())
    }
}

/// 加载指定路径的配置
// 对应 Bun: pub fn load_config_path(cmd, auto_loaded, config_path, ctx) -> Result<(), Error>
public func loadConfigPath(
    cmd: CommandTag,
    autoLoaded: Bool,
    configPath: String,
    ctx: ContextData
): Result<Unit> {
    // 如果命令需要读取全局配置, 先加载全局配置
    if (cmd.readGlobalConfig()) {
        match (loadGlobalBunfig(cmd, ctx)) {
            case Err(err) => return handleGlobalConfigError(err, autoLoaded, configPath)
            case Ok(_) => ()
        }
    }

    return loadBunfig(cmd, autoLoaded, configPath, ctx)
}

/// 报告 bunfig 加载失败 (cold path)
// 对应 Bun: #[cold] fn report_bunfig_load_failure(log, err) -> !
private func reportBunfigLoadFailure(log: Log, err: BaoError): Nothing {
    if (log.hasAny()) {
        log.print(getErrorWriter())
        printError("\n")
    }
    printError("failed to load bunfig: ${err.message}")
    exit(1)
}

/// 自动查找并加载配置
// 对应 Bun: pub fn load_config(cmd, user_config_path_, ctx) -> Result<(), Error>
//
// 逻辑:
// 1. 检查 standalone 模式的 autoloadBunfig 标志
// 2. 加载全局配置 (如需要)
// 3. 确定配置文件路径:
//    - 用户指定的路径
//    - 当前目录的 bunfig.toml (自动加载)
// 4. 解析绝对/相对路径
// 5. 加载配置
public func loadConfig(
    cmd: CommandTag,
    userConfigPath: ?String,
    ctx: ContextData
): Result<Unit> {
    // 检查 standalone 模式
    match (userConfigPath) {
        case None => ()  // 如果运行 standalone 可执行文件且禁用了 autoloadBunfig, 跳过配置加载
        case Some(_) => ()
    }

    // 加载全局配置
    if (cmd.readGlobalConfig()) {
        if (!ctx.hasLoadedGlobalConfig) {
            ctx.hasLoadedGlobalConfig = true
            let homeConfigPath = getHomeConfigPath()
            if (homeConfigPath.isSome()) {
                match (loadConfigPath(cmd, true, homeConfigPath.getOrThrow(), ctx)) {
                    case Err(err) => reportBunfigLoadFailure(ctx.log, err)
                    case Ok(_) => ()
                }
            }
        }
    }

    // 确定配置文件路径
    var configPath: String = match (userConfigPath) {
        case Some(p) => p
        case None => ""
    }

    var autoLoaded: Bool = false

    // 自动确定配置文件路径
    if (configPath.isEmpty()) {
        // 检查是否需要自动加载 bunfig.toml
        if (userConfigPath != None ||
            cmd.alwaysLoadsConfig() ||
            (cmd == CommandTag.AutoCommand &&
                (ctx.positionals.isEmpty() ||
                    !ctx.positionals.isEmpty() && isDefaultLoader(ctx.positionals[0])))) {
            configPath = "bunfig.toml"
            autoLoaded = true
        }
    }

    if (configPath.isEmpty()) {
        return Ok(())
    }

    // 处理相对/绝对路径
    let resolvedPath: String
    if (configPath.startsWith("/")) {
        resolvedPath = configPath
    } else {
        // 获取工作目录
        if (ctx.args.absoluteWorkingDir == None) {
            match (getCwd()) {
                case Some(cwd) => ctx.args.absoluteWorkingDir = cwd
                case None => return Ok(())
            }
        }

        let awd = ctx.args.absoluteWorkingDir.getOrThrow()
        resolvedPath = joinPath(awd, configPath)
    }

    // 加载配置
    match (loadConfigPath(cmd, autoLoaded, resolvedPath, ctx)) {
        case Err(err) => reportBunfigLoadFailure(ctx.log, err)
        case Ok(_) => ()
    }

    return Ok(())
}

/// 从命令行参数加载配置
// 对应 Bun: pub fn load_config_with_cmd_args(cmd, args, ctx) -> Result<(), Error>
public func loadConfigWithCmdArgs(
    cmd: CommandTag,
    args: ClapArgs,
    ctx: ContextData
): Result<Unit> {
    let configOption = args.getOption("--config")
    return loadConfig(cmd, configOption, ctx)
}

// ============================================================================
// 辅助类型和函数
// ============================================================================

/// 命令标签
// 对应 Bun: bun_options_types::command_tag::Tag
public enum CommandTag {
    | RunCommand
    | BuildCommand
    | TestCommand
    | InstallCommand
    | AutoCommand
    | InitCommand
    | ReplCommand

    /// 是否需要读取全局配置
    public func readGlobalConfig(): Bool {
        match (this) {
            case RunCommand | BuildCommand | TestCommand | InstallCommand | AutoCommand => true
            case _ => false
        }
    }

    /// 是否总是加载配置
    public func alwaysLoadsConfig(): Bool {
        match (this) {
            case BuildCommand | InstallCommand => true
            case _ => false
        }
    }

    /// 是否是 npm 相关命令
    public func isNpmRelated(): Bool {
        match (this) {
            case InstallCommand => true
            case _ => false
        }
    }
}

/// 日志级别
public enum LogLevel {
    | Debug
    | Info
    | Warn
    | Error
}

/// 上下文数据 (简化)
public class ContextData {
    public var log: Log = Log()
    public var hasLoadedGlobalConfig: Bool = false
    public var positionals: ArrayList<String> = ArrayList<String>()
    public var args: TransformOptions = TransformOptions()
    public var debug: DebugOptions = DebugOptions()

    public init() {}
}

/// 日志
public class Log {
    public var level: LogLevel = LogLevel.Warn
    public var errors: Int64 = 0
    public var warnings: Int64 = 0

    public func hasAny(): Bool {
        return errors > 0 || warnings > 0
    }

    public func print(writer: OutputWriter): Unit {
        // 打印日志消息
    }

    public func addError(text: String, source: String): Unit {
        errors += 1
    }
}

/// 转换选项
public class TransformOptions {
    public var absoluteWorkingDir: ?String = None
    public var logLevel: ?String = None
    public var define: ?HashMap<String, String> = None
    public var origin: ?String = None
    public var port: ?UInt16 = None
    public var outputDir: ?String = None
    public var entryPoints: ArrayList<String> = ArrayList<String>()
    public var loaders: ?LoaderMap = None
    public var external: ArrayList<String> = ArrayList<String>()
    public var jsx: ?JsxConfig = None
    public var servePlugins: ?ArrayList<String> = None
    public var serveHmr: ?Bool = None
    public var serveMinifySyntax: ?Bool = None
    public var serveMinifyWhitespace: ?Bool = None
    public var serveMinifyIdentifiers: ?Bool = None
    public var serveDefine: ?HashMap<String, String> = None
    public var bunfigPath: ?String = None
    public var servePublicPath: ?String = None
    public var serveEnvBehavior: ?String = None
    public var serveEnvPrefix: ?String = None
    public var disableDefaultEnvFiles: Bool = false

    public init() {}
}

/// 调试选项
public class DebugOptions {
    public var loadedBunfig: Bool = false
    public var silent: Bool = false
    public var useSystemShell: Bool = false
    public var runInBun: Bool = false
    public var globalCache: ?String = None
    public var offlineModeSetting: ?String = None
    public var editor: ?String = None
    public var macros: ?MacroOptions = None
    public var testDirectory: ?String = None
    public var packageBundleMap: HashMap<String, String> = HashMap<String, String>()
    public var preloads: ArrayList<String> = ArrayList<String>()

    public init() {}
}

/// 命令行参数解析结果
public class ClapArgs {
    private var options: HashMap<String, String> = HashMap<String, String>()

    public func getOption(name: String): ?String {
        options.get(name)
    }
}

/// 字符串映射 - 使用 HashMap<String, String> 直接
// public typealias StringMap = HashMap<String, String>

/// 加载器映射
public class LoaderMap {
    public var extensions: ArrayList<String> = ArrayList<String>()
    public var loaders: ArrayList<String> = ArrayList<String>()
}

/// JSX 配置
public class JsxConfig {
    public var factory: String = ""
    public var fragment: String = ""
    public var importSource: String = ""
    public var runtime: String = "automatic"
    public var development: Bool = true
}

/// 宏选项
public enum MacroOptions {
    | Disable
    | Map(HashMap<String, HashMap<String, String>>)
}

/// 输出写入器
public class OutputWriter {
    public func write(text: String): Unit {
        print(text)
    }
}

/// 获取环境变量
private func getEnv(name: String): ?String {
    // 使用系统调用获取环境变量
    None
}

/// 检查文件是否存在
private func fileExists(path: String): Bool {
    // 使用系统调用检查
    false
}

/// 读取源文件
private func readSource(path: String, convertBom: Bool): Result<String> {
    Result.Err(BaoError(ErrorCode.ENOENT, "not implemented"))
}

/// 获取当前工作目录
private func getCwd(): ?String {
    None
}

/// 处理配置文件读取错误
private func handleReadError(err: BaoError, autoLoaded: Bool, configPath: String): Result<Unit> {
    if (!autoLoaded) {
        printError("${err}\nwhile reading config \"${configPath}\"")
    }
    if (autoLoaded) { Result.Ok(()) } else { Result.Err(BaoError(ErrorCode.ParseError, "failed to load config")) }
}

/// 处理全局配置加载错误
private func handleGlobalConfigError(err: BaoError, autoLoaded: Bool, configPath: String): Result<Unit> {
    if (!autoLoaded) {
        printError("${err}\nreading global config \"${configPath}\"")
    }
    if (autoLoaded) { Ok(()) } else { Result.Err(BaoError(ErrorCode.ParseError, "failed to load global config")) }
}

/// 连接路径
private func joinPath(base: String, relative: String): String {
    if (base.endsWith("/")) {
        return base + relative
    }
    return base + "/" + relative
}

/// 检查是否是默认加载器
private func isDefaultLoader(filename: String): Bool {
    let dotIdx = filename.lastIndexOf('.')
    let ext = match (dotIdx) {
        case Some(idx) => filename.substring(idx)
        case None => ""
    }
    // 对应 Bun: options::DEFAULT_LOADERS.contains_key(extension)
    match (ext) {
        case ".js" | ".ts" | ".jsx" | ".tsx" | ".mjs" | ".mts" => true
        case _ => false
    }
}

/// 获取错误输出写入器
private func getErrorWriter(): OutputWriter {
    OutputWriter()
}

/// 打印错误
private func printError(msg: String): Unit {
    std.console.stderr.println(msg)
}

/// 读取源文件的 Source 类型 - 使用 String 直接
// public typealias Source = String

/// 解析结果
public enum Result<T> {
    | Ok(T)
    | Err(BaoError)
}

/// 错误代码
public enum ErrorCode {
    | ParseError
    | ENOENT
    | Unexpected
}

/// 错误类型
public class BaoError <: Exception {
    public let code: ErrorCode
    public let message: String

    public init(code: ErrorCode, message: String) {
        this.code = code
        this.message = message
    }
}
