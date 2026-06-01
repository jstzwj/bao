// 严格翻译自: src/runtime/cli/bunfig.zig
// Bunfig 配置文件解析器
//   解析 bunfig.toml / baofig.toml 配置文件, 提供运行时配置选项
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_path.*
import bao_io.*
import bao_sys.*

// ============================================================================
// BunfigLogLevel — 日志级别
// ============================================================================

/// 日志级别
public enum BunfigLogLevel {
    | Debug
    | Error
    | Warn
    | Info
    | Silent

    public operator func ==(right: BunfigLogLevel): Bool {
        match (this) {
            case Debug =>
                match (right) { case Debug => true case _ => false }
            case Error =>
                match (right) { case Error => true case _ => false }
            case Warn =>
                match (right) { case Warn => true case _ => false }
            case Info =>
                match (right) { case Info => true case _ => false }
            case Silent =>
                match (right) { case Silent => true case _ => false }
        }
    }

    public operator func !=(right: BunfigLogLevel): Bool {
        !(this == right)
    }
}

// ============================================================================
// BunfigRegistry — npm 注册表配置
// 严格翻译自: bunfig.zig NpmRegistry
// ============================================================================

/// npm 注册表配置
public class BunfigRegistry {
    public var url: String
    public var username: String
    public var password: String
    public var token: String

    public init() {
        url = "https://registry.npmjs.org/"
        username = ""
        password = ""
        token = ""
    }
}

// ============================================================================
// BunfigOfflineMode — 离线模式
// ============================================================================

/// 离线模式
public enum BunfigOfflineMode {
    | Auto
    | Offline
    | Online

    public operator func ==(right: BunfigOfflineMode): Bool {
        match (this) {
            case Auto =>
                match (right) { case Auto => true case _ => false }
            case Offline =>
                match (right) { case Offline => true case _ => false }
            case Online =>
                match (right) { case Online => true case _ => false }
        }
    }

    public operator func !=(right: BunfigOfflineMode): Bool {
        !(this == right)
    }
}

// ============================================================================
// BunfigConfig — bunfig 配置
// 严格翻译自: bunfig.zig Bunfig (TransformOptions 映射)
// ============================================================================

/// Bunfig 配置
public class BunfigConfig {
    /// 日志级别
    public var logLevel: BunfigLogLevel
    /// 是否禁用默认 .env 文件
    public var disableDefaultEnvFiles: Bool
    /// 离线模式
    public var offlineMode: BunfigOfflineMode
    /// 预加载模块列表
    public var preloads: ArrayList<String>
    /// 宏映射
    public var macros: HashMap<String, HashMap<String, String>>
    /// 定义项
    public var defines: HashMap<String, String>
    /// 外部依赖
    public var externals: ArrayList<String>
    /// 加载器映射 (扩展名 -> 加载器)
    public var loaders: HashMap<String, String>
    /// 主入口点
    public var `main`: String
    /// 输出目录
    public var outdir: String
    /// 输出文件
    public var outfile: String
    /// 目标平台
    public var target: String
    /// 是否最小化
    public var minify: Bool
    /// 是否启用 source map
    public var sourceMap: Bool
    /// 是否启用代码分割
    public var codeSplitting: Bool
    /// 是否启用 tree shaking
    public var treeShaking: Bool
    /// npm 注册表配置
    public var registry: BunfigRegistry
    /// 保存安装的 lockfile 路径
    public var lockfileSavePath: String
    /// 是否保存 lockfile
    public var saveLockfile: Bool
    /// 是否保存 yarn lockfile
    public var saveYarnLockfile: Bool
    /// 是否使用硬链接
    public var hardLinkToNpmCache: Bool
    /// 是否禁止安装可选依赖
    public var optionalInstallDisable: Bool
    /// 望远镜限制
    public var telescope: String
    /// 全局目录
    public var globalDir: String
    /// 本地目录
    public var localDir: String
    /// 包覆盖
    public var overrides: HashMap<String, String>
    /// 额外配置项
    public var extra: HashMap<String, String>

    public init() {
        logLevel = BunfigLogLevel.Info
        disableDefaultEnvFiles = false
        offlineMode = BunfigOfflineMode.Auto
        preloads = ArrayList<String>()
        macros = HashMap<String, HashMap<String, String>>()
        defines = HashMap<String, String>()
        externals = ArrayList<String>()
        loaders = HashMap<String, String>()
        this.`main` = ""
        outdir = ""
        outfile = ""
        target = "bun"
        minify = false
        sourceMap = false
        codeSplitting = false
        treeShaking = false
        registry = BunfigRegistry()
        lockfileSavePath = ""
        saveLockfile = true
        saveYarnLockfile = false
        hardLinkToNpmCache = false
        optionalInstallDisable = false
        telescope = ""
        globalDir = ""
        localDir = ""
        overrides = HashMap<String, String>()
        extra = HashMap<String, String>()
    }
}

// ============================================================================
// BunfigParser — 配置文件解析器
// 严格翻译自: bunfig.zig Parser
// ============================================================================

/// Bunfig 配置解析器
/// 解析 bunfig.toml 配置文件并填充 BunfigConfig
public class BunfigParser {
    /// 解析配置文件
    // 严格翻译自: bunfig.zig Parser.parse()
    public static func parseFile(path: String): BunfigConfig {
        let config = BunfigConfig()

        if (!BaoFile.exists(path)) {
            return config
        }

        let contentResult = BaoFile.readAllText(path)
        let contentOpt = contentResult.result()
        if (contentOpt.isNone()) {
            return config
        }
        let content = contentOpt.getOrThrow()
        if (content.size == 0) {
            return config
        }

        return parseContent(content, config)
    }

    /// 解析配置内容
    public static func parseContent(content: String, config: BunfigConfig): BunfigConfig {
        // TOML 格式简化解析
        let lines = content.split("\n")
        var currentSection = ""
        var currentKey = ""

        for (line in lines) {
            let trimmed = line.trimAscii()
            if (trimmed.size == 0) { continue }
            if (trimmed.startsWith("#")) { continue }

            // 检查 section header
            if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
                currentSection = trimmed[1..(trimmed.size - 1)].trimAscii()
                continue
            }

            // 解析 key = value
            let eqIdx = trimmed.indexOf("=")
            match (eqIdx) {
                case Some(idx) =>
                    let key = trimmed[0..idx].trimAscii()
                    let rawValue = trimmed[(idx + 1)..trimmed.size].trimAscii()

                    // 去掉引号
                    var value = rawValue
                    if (value.size >= 2 && value.startsWith("\"") && value.endsWith("\"")) {
                        value = value[1..(value.size - 1)]
                    }

                    // 按当前 section 和 key 设置配置
                    applyConfig(config, currentSection, key, value)
                case None => ()
            }
        }

        return config
    }

    /// 应用配置项
    private static func applyConfig(
        config: BunfigConfig,
        section: String,
        key: String,
        value: String
    ): Unit {
        match (section) {
            case "" =>
                // 顶层配置
                match (key) {
                    case "logLevel" =>
                        config.logLevel = parseLogLevel(value)
                    case "main" =>
                        config.`main` = value
                    case "outdir" =>
                        config.outdir = value
                    case "outfile" =>
                        config.outfile = value
                    case "target" =>
                        config.target = value
                    case "minify" =>
                        config.minify = parseBool(value)
                    case "sourcemap" =>
                        config.sourceMap = parseBool(value)
                    case "codeSplitting" =>
                        config.codeSplitting = parseBool(value)
                    case "treeShaking" =>
                        config.treeShaking = parseBool(value)
                    case "saveLockfile" =>
                        config.saveLockfile = parseBool(value)
                    case "saveYarnLockfile" =>
                        config.saveYarnLockfile = parseBool(value)
                    case "hardLinkToNpmCache" =>
                        config.hardLinkToNpmCache = parseBool(value)
                    case "optionalInstallDisable" =>
                        config.optionalInstallDisable = parseBool(value)
                    case "globalDir" =>
                        config.globalDir = value
                    case "localDir" =>
                        config.localDir = value
                    case "telescope" =>
                        config.telescope = value
                    case "lockfileSavePath" =>
                        config.lockfileSavePath = value
                    case _ =>
                        config.extra.put(key, value)
                }
            case "install" =>
                match (key) {
                    case "optional" =>
                        config.optionalInstallDisable = !parseBool(value)
                    case "saveLockfile" =>
                        config.saveLockfile = parseBool(value)
                    case "lockfileSavePath" =>
                        config.lockfileSavePath = value
                    case "globalDir" =>
                        config.globalDir = value
                    case "localDir" =>
                        config.localDir = value
                    case "hardLinkToNpmCache" =>
                        config.hardLinkToNpmCache = parseBool(value)
                    case _ =>
                        config.extra.put("install.${key}", value)
                }
            case "run" =>
                match (key) {
                    case "silent" =>
                        if (parseBool(value)) {
                            config.logLevel = BunfigLogLevel.Silent
                        }
                    case _ =>
                        config.extra.put("run.${key}", value)
                }
            case "registry" =>
                match (key) {
                    case "url" =>
                        config.registry.url = value
                    case "username" =>
                        config.registry.username = value
                    case "password" =>
                        config.registry.password = value
                    case "token" =>
                        config.registry.token = value
                    case _ =>
                        config.extra.put("registry.${key}", value)
                }
            case "define" =>
                config.defines.put(key, value)
            case "external" =>
                config.externals.append(value)
            case "loader" =>
                config.loaders.put(key, value)
            case "override" =>
                config.overrides.put(key, value)
            case _ =>
                config.extra.put("${section}.${key}", value)
        }
    }

    /// 解析布尔值
    private static func parseBool(value: String): Bool {
        match (value.toAsciiLower()) {
            case "true" => true
            case "false" => false
            case "1" => true
            case "0" => false
            case "yes" => true
            case "no" => false
            case _ => false
        }
    }

    /// 解析日志级别
    private static func parseLogLevel(value: String): BunfigLogLevel {
        match (value.toAsciiLower()) {
            case "debug" => BunfigLogLevel.Debug
            case "error" => BunfigLogLevel.Error
            case "warn" => BunfigLogLevel.Warn
            case "info" => BunfigLogLevel.Info
            case "silent" => BunfigLogLevel.Silent
            case _ => BunfigLogLevel.Info
        }
    }
}

/// Bunfig 辅助函数
public class Bunfig {
    /// 查找并加载 bunfig 配置
    public static func load(cwd: String): BunfigConfig {
        // 尝试多个配置文件名
        let configNames = ["baofig.toml", "bunfig.toml", ".baofig.toml", ".bunfig.toml"]
        for (name in configNames) {
            let path = Path.join(cwd, name)
            if (BaoFile.exists(path)) {
                return BunfigParser.parseFile(path)
            }
        }
        return BunfigConfig()
    }
}
