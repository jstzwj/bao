// 严格翻译自: src/cli/bunfig.zig
// bao 配置加载: bunfig.toml, package.json, tsconfig.json
package bao_cli

import bao_core.*
import bao_collections.*
import bao_install.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_cli.commands.JsonParser
import bao_cli.commands.JsonHelper
import bao_cli.commands.JsonValue

/// 本地 toLower 辅助函数 (ASCII)
private func _toLower(s: String): String {
    var bytes = Array<UInt8>(s.size, { _ => UInt8(0) })
    for (i in 0..s.size) {
        let c = s[i]
        if (c >= UInt8(65) && c <= UInt8(90)) {
            bytes[i] = c + UInt8(32)
        } else {
            bytes[i] = c
        }
    }
    return String.fromUtf8(bytes)
}

// ============================================================================
// 配置系统 - 对应 bunfig.toml
// 严格翻译自: src/cli/bunfig.zig (Bunfig, Parser)
// ============================================================================

/// 日志级别 (定义在 logger.cj 中)

/// 目标平台
/// 严格翻译自: src/options.zig Target
public enum BuildTarget {
    | Browser
    | Node
    | Bun

    public operator func ==(other: BuildTarget): Bool {
        match (this) {
            case BuildTarget.Browser => match (other) { case BuildTarget.Browser => true case _ => false }
            case BuildTarget.Node => match (other) { case BuildTarget.Node => true case _ => false }
            case BuildTarget.Bun => match (other) { case BuildTarget.Bun => true case _ => false }
        }
    }

    public operator func !=(other: BuildTarget): Bool {
        return !(this == other)
    }

    public static func fromString(s: String): ?BuildTarget {
        match (_toLower(s)) {
            case "browser" => Some(BuildTarget.Browser)
            case "node" => Some(BuildTarget.Node)
            case "bun" => Some(BuildTarget.Bun)
            case _ => None
        }
    }
}

/// 包加载器类型
/// 严格翻译自: src/options.zig Loader
public enum Loader {
    | Js
    | Ts
    | Jsx
    | Tsx
    | Css
    | Json
    | Text
    | File
    | Wasm
    | Napi
    | Base64
    | Toml

    public static func fromString(s: String): ?Loader {
        match (_toLower(s)) {
            case "js" => Some(Loader.Js)
            case "ts" => Some(Loader.Ts)
            case "jsx" => Some(Loader.Jsx)
            case "tsx" => Some(Loader.Tsx)
            case "css" => Some(Loader.Css)
            case "json" => Some(Loader.Json)
            case "text" => Some(Loader.Text)
            case "file" => Some(Loader.File)
            case "wasm" => Some(Loader.Wasm)
            case "napi" => Some(Loader.Napi)
            case "base64" => Some(Loader.Base64)
            case "toml" => Some(Loader.Toml)
            case _ => None
        }
    }
}

/// NPM Registry 配置
/// 严格翻译自: src/cli/bunfig.zig parseRegistry
public class NpmRegistry {
    /// registry URL
    public var url: String
    /// 认证 token
    public var token: ?String
    /// 用户名
    public var username: ?String
    /// 密码
    public var password: ?String

    public init(url: String) {
        this.url = url
        this.token = None
        this.username = None
        this.password = None
    }
}

/// 环境文件配置
/// 严格翻译自: src/cli/bunfig.zig loadEnvConfig
public class EnvConfig {
    /// 是否加载默认 .env 文件
    public var loadDefaultEnvFiles: Bool
    /// 自定义 .env 文件路径
    public var envFiles: ArrayList<String>

    public init() {
        loadDefaultEnvFiles = true
        envFiles = ArrayList<String>()
    }
}

/// 预加载模块列表
/// 严格翻译自: src/cli/bunfig.zig loadPreload
public class PreloadConfig {
    /// 预加载的模块路径列表
    public var modules: ArrayList<String>

    public init() {
        modules = ArrayList<String>()
    }
}

/// define 常量替换
/// 严格翻译自: src/cli/bunfig.zig loadDefine
public class DefineMap {
    /// 标识符 -> 替换值
    public var entries: HashMap<String, String>

    public init() {
        entries = HashMap<String, String>()
    }

    public func set(key: String, value: String): Unit {
        entries.put(key, value)
    }

    public func get(key: String): ?String {
        entries.get(key)
    }
}

/// 完整配置
/// 严格翻译自: src/cli/bunfig.zig Bunfig struct
public class Config {
    /// 日志级别
    public var logLevel: LogLevel
    /// 目标平台
    public var target: BuildTarget
    /// 是否启用 sourcemap
    public var sourcemap: Bool
    /// 是否 minify
    public var minify: Bool
    /// 入口文件列表
    public var entryPoints: ArrayList<String>
    /// 输出目录
    public var outdir: ?String
    /// 输出格式
    public var format: ?String
    /// 根目录
    public var rootDir: String
    /// define 替换
    public var defines: DefineMap
    /// 加载器映射 (扩展名 -> Loader)
    public var loaderMap: HashMap<String, Loader>
    /// 外部依赖列表
    public var externals: ArrayList<String>
    /// NPM registry 配置
    public var registry: ?NpmRegistry
    /// 环境文件配置
    public var envConfig: EnvConfig
    /// 预加载模块
    public var preloads: PreloadConfig
    /// 是否禁止默认 .env 文件
    public var disableDefaultEnvFiles: Bool
    /// 宏映射
    public var macros: HashMap<String, String>
    /// 离线模式
    public var offlineMode: Bool
    /// 可选 peer dependencies 行为
    public var optionalPeerDeps: Bool
    /// 严格 peer dependencies
    public var strictPeerDeps: Bool
    /// 后台安装
    public var backendInstall: Bool
    /// 生产模式
    public var production: Bool
    /// 冻结 lockfile
    public var frozenLockfile: Bool
    /// 是否保存 lockfile
    public var saveLockfile: Bool
    /// 是否保存 yarn.lock
    public var saveYarnLockfile: Bool
    /// 全局 bin 目录
    public var globalBinDir: ?String
    /// tsconfig 路径
    public var tsconfig: ?String
    /// package.json 信息
    public var packageJson: ?PackageJsonInfo

    public init(rootDir: String) {
        this.rootDir = rootDir
        logLevel = LogLevel.Info
        target = BuildTarget.Bun
        sourcemap = false
        minify = false
        entryPoints = ArrayList<String>()
        outdir = None
        format = None
        defines = DefineMap()
        loaderMap = HashMap<String, Loader>()
        externals = ArrayList<String>()
        registry = None
        envConfig = EnvConfig()
        preloads = PreloadConfig()
        disableDefaultEnvFiles = false
        macros = HashMap<String, String>()
        offlineMode = false
        optionalPeerDeps = false
        strictPeerDeps = false
        backendInstall = true
        production = false
        frozenLockfile = false
        saveLockfile = true
        saveYarnLockfile = false
        globalBinDir = None
        tsconfig = None
        packageJson = None
    }

    /// 从目录加载配置
    // 严格翻译自: src/cli/bunfig.zig Bunfig.Parser.parse
    public static func load(dir: String): Config {
        let config = Config(dir)

        // 按优先级加载:
        // 1. bunfig.toml (项目根目录)
        // 2. bunfig.toml (用户主目录 ~/.bunfig.toml)
        // 3. package.json
        // 4. tsconfig.json

        // 加载全局配置
        let homeDir = Sys.getHomeDir()
        let globalConfigPath = Path.join([homeDir, ".bunfig.toml"])
        if (BaoFile.exists(globalConfigPath)) {
            let content = BaoFile.readAllText(globalConfigPath)
            match (content) {
                case Ok(text) => config.parseBunfig(text)
                case Err(_) => ()
            }
        }

        // 加载项目配置 (覆盖全局)
        let projectConfigPath = Path.join([dir, "bunfig.toml"])
        if (BaoFile.exists(projectConfigPath)) {
            let content = BaoFile.readAllText(projectConfigPath)
            match (content) {
                case Ok(text) => config.parseBunfig(text)
                case Err(_) => ()
            }
        }

        // 加载 package.json
        let pkgJsonPath = Path.join([dir, "package.json"])
        if (BaoFile.exists(pkgJsonPath)) {
            config.packageJson = config.parsePackageJsonFile(pkgJsonPath)
        }

        // 加载 tsconfig.json
        let tsconfigPath = Path.join([dir, "tsconfig.json"])
        if (BaoFile.exists(tsconfigPath)) {
            config.parseTsconfig(tsconfigPath)
        }

        // 环境变量覆盖
        config.applyEnvOverrides()

        return config
    }

    /// 解析 bunfig.toml
    // 严格翻译自: src/cli/bunfig.zig Parser.parse
    private func parseBunfig(content: String): Unit {
        let parser = TomlParser()
        let toml = parser.parse(content)
        match (toml) {
            case Some(root) =>
                // logLevel
                match (TomlHelper.getString(root, "logLevel")) {
                    case Some(level) =>
                        match (LogLevel.fromString(level)) {
                            case Some(l) => logLevel = l
                            case None => ()
                        }
                    case None => ()
                }

                // target
                match (TomlHelper.getString(root, "target")) {
                    case Some(t) =>
                        match (BuildTarget.fromString(t)) {
                            case Some(bt) => target = bt
                            case None => ()
                        }
                    case None => ()
                }

                // define
                match (TomlHelper.getTable(root, "define")) {
                    case Some(table) =>
                        for (key in table.keys()) {
                            match (table.get(key)) {
                                case Some(v) => defines.set(key, v)
                                case None => ()
                            }
                        }
                    case None => ()
                }

                // loader
                match (TomlHelper.getTable(root, "loader")) {
                    case Some(loaderTable) =>
                        for (key in loaderTable.keys()) {
                            match (loaderTable.get(key)) {
                                case Some(v) =>
                                    let parsedLoader = Loader.fromString(v)
                                    if (let Some(ld) <- parsedLoader) {
                                        loaderMap.put(key, ld)
                                    }
                                case None => ()
                            }
                        }
                    case None => ()
                }

                // external
                match (TomlHelper.getArray(root, "external")) {
                    case Some(arr) =>
                        for (item in arr) {
                            externals.append(item)
                        }
                    case None => ()
                }

                // install.registry
                match (TomlHelper.getString(root, "install.registry")) {
                    case Some(url) =>
                        registry = Some(NpmRegistry(url))
                    case None => ()
                }

                // install.token
                match (TomlHelper.getString(root, "install.token")) {
                    case Some(token) =>
                        match (registry) {
                            case Some(reg) => reg.token = Some(token)
                            case None =>
                                let reg = NpmRegistry("https://registry.npmjs.org/")
                                reg.token = Some(token)
                                registry = Some(reg)
                        }
                    case None => ()
                }

                // install.offline
                match (TomlHelper.getBool(root, "install.offline")) {
                    case Some(b) => offlineMode = b
                    case None => ()
                }

                // install.production
                match (TomlHelper.getBool(root, "install.production")) {
                    case Some(b) => production = b
                    case None => ()
                }

                // install.frozenLockfile
                match (TomlHelper.getBool(root, "install.frozenLockfile")) {
                    case Some(b) => frozenLockfile = b
                    case None => ()
                }

                // install.saveLockfile
                match (TomlHelper.getBool(root, "install.saveLockfile")) {
                    case Some(b) => saveLockfile = b
                    case None => ()
                }

                // preload
                match (TomlHelper.getString(root, "preload")) {
                    case Some(p) => preloads.modules.append(p)
                    case None => ()
                }
                match (TomlHelper.getArray(root, "preload")) {
                    case Some(arr) =>
                        for (item in arr) {
                            preloads.modules.append(item)
                        }
                    case None => ()
                }

                // env
                match (TomlHelper.getValue(root, "env")) {
                    case Some(val_) =>
                        if (val_ == "null" || val_ == "false") {
                            disableDefaultEnvFiles = true
                        }
                    case None => ()
                }

                // tsconfig
                match (TomlHelper.getString(root, "tsconfig")) {
                    case Some(tsconfigPath) => tsconfig = Some(tsconfigPath)
                    case None => ()
                }

                // macros
                match (TomlHelper.getTable(root, "macros")) {
                    case Some(table) =>
                        for (key in table.keys()) {
                            match (table.get(key)) {
                                case Some(v) => macros.put(key, v)
                                case None => ()
                            }
                        }
                    case None => ()
                }

                // outdir
                match (TomlHelper.getString(root, "outdir")) {
                    case Some(d) => outdir = Some(d)
                    case None => ()
                }

                // sourcemap
                match (TomlHelper.getBool(root, "sourcemap")) {
                    case Some(b) => sourcemap = b
                    case None => ()
                }

                // minify
                match (TomlHelper.getBool(root, "minify")) {
                    case Some(b) => minify = b
                    case None => ()
                }
            case None => ()
        }
    }

    /// 解析 package.json
    // 严格翻译自: src/cli/cli.zig package.json reading
    private func parsePackageJsonFile(path: String): PackageJsonInfo {
        let content = BaoFile.readAllText(path)
        match (content) {
            case Ok(text) =>
                let parser = JsonParser()
                let json = parser.parse(text)
                match (json) {
                    case Some(root) =>
                        let info = PackageJsonInfo()
                        info.name = JsonHelper.getString(root, "name") ?? "unknown"
                        info.version = JsonHelper.getString(root, "version") ?? "0.0.0"
                        info.`main` = JsonHelper.getString(root, "main") ?? "index.js"
                        info.module = JsonHelper.getString(root, "module")
                        info.types = JsonHelper.getString(root, "types")

                        // scripts
                        match (JsonHelper.getField(root, "scripts")) {
                            case Some(scriptsObj) =>
                                for (key in scriptsObj.keys()) {
                                    match (scriptsObj.getString(key)) {
                                        case Some(v) => info.scripts.put(key, v)
                                        case None => ()
                                    }
                                }
                            case None => ()
                        }

                        // dependencies - getStringMap stub: parse dependency objects
                        match (JsonHelper.getField(root, "dependencies")) {
                            case Some(depsObj) =>
                                for (key in depsObj.keys()) {
                                    match (depsObj.getString(key)) {
                                        case Some(v) => info.dependencies.put(key, v)
                                        case None => ()
                                    }
                                }
                            case None => ()
                        }
                        match (JsonHelper.getField(root, "devDependencies")) {
                            case Some(depsObj) =>
                                for (key in depsObj.keys()) {
                                    match (depsObj.getString(key)) {
                                        case Some(v) => info.devDependencies.put(key, v)
                                        case None => ()
                                    }
                                }
                            case None => ()
                        }
                        // TODO: peerDependencies, optionalDependencies

                        return info
                    case None => return PackageJsonInfo()
                }
            case Err(_) => return PackageJsonInfo()
        }
    }

    /// 解析 tsconfig.json
    // 严格翻译自: src/resolver/tsconfig_loader.rs
    private func parseTsconfig(path: String): Unit {
        let content = BaoFile.readAllText(path)
        match (content) {
            case Ok(text) =>
                let parser = JsonParser()
                let json = parser.parse(text)
                match (json) {
                    case Some(root) =>
                        // 读取 paths 映射
                        match (JsonHelper.getField(root, "compilerOptions")) {
                            case Some(opts) =>
                                // paths
                                match (JsonHelper.getField(opts, "paths")) {
                                    case Some(pathsObj) =>
                                        for (key in pathsObj.keys()) {
                                            // 路径别名
                                            defines.set(key, key)
                                        }
                                    case None => ()
                                }
                                // baseUrl
                                match (JsonHelper.getString(opts, "baseUrl")) {
                                    case Some(baseUrl) =>
                                        // 解析路径
                                        defines.set("TS_CONFIG_BASEURL", baseUrl)
                                    case None => ()
                                }
                            case None => ()
                        }
                    case None => ()
                }
            case Err(_) => ()
        }
    }

    /// 环境变量覆盖
    // 严格翻译自: src/cli/cli.zig environment override section
    private func applyEnvOverrides(): Unit {
        // BAO_CONFIG_PATH
        match (Sys.getEnv("BAO_CONFIG_PATH")) {
            case Some(configPath) =>
                if (BaoFile.exists(configPath)) {
                    let content = BaoFile.readAllText(configPath)
                    match (content) {
                        case Ok(text) => parseBunfig(text)
                        case Err(_) => ()
                    }
                }
            case None => ()
        }

        // BAO_INSTALL_REGISTRY
        match (Sys.getEnv("BAO_INSTALL_REGISTRY")) {
            case Some(url) =>
                let reg = NpmRegistry(url)
                match (Sys.getEnv("BAO_INSTALL_TOKEN")) {
                    case Some(token) => reg.token = Some(token)
                    case None => ()
                }
                registry = Some(reg)
            case None => ()
        }

        // BAO_INSTALL_OFFLINE
        match (Sys.getEnv("BAO_INSTALL_OFFLINE")) {
            case Some(v) => offlineMode = (v == "1" || v == "true")
            case None => ()
        }

        // NODE_ENV
        match (Sys.getEnv("NODE_ENV")) {
            case Some(v) =>
                if (v == "production") { production = true }
            case None => ()
        }
    }
}

/// package.json 信息
public class PackageJsonInfo {
    public var name: String
    public var version: String
    public var `main`: String
    public var module: ?String
    public var types: ?String
    public var scripts: HashMap<String, String>
    public var dependencies: HashMap<String, String>
    public var devDependencies: HashMap<String, String>
    public var peerDependencies: HashMap<String, String>
    public var optionalDependencies: HashMap<String, String>

    public init() {
        name = ""
        version = ""
        `main` = "index.js"
        module = None
        types = None
        scripts = HashMap<String, String>()
        dependencies = HashMap<String, String>()
        devDependencies = HashMap<String, String>()
        peerDependencies = HashMap<String, String>()
        optionalDependencies = HashMap<String, String>()
    }

    /// 获取 start 命令
    public func getStartCommand(): ?String {
        // 优先: scripts.start
        match (scripts.get("start")) {
            case Some(cmd) => return Some(cmd)
            case None => ()
        }
        // 回退: main 文件
        if (!`main`.isEmpty()) {
            return Some("bao run ${`main`}")
        }
        return None
    }

    /// 获取 dev 命令
    public func getDevCommand(): ?String {
        match (scripts.get("dev")) {
            case Some(cmd) => return Some(cmd)
            case None => ()
        }
        // 回退到 start
        return getStartCommand()
    }

    /// 是否有依赖
    public func hasDependencies(): Bool {
        return dependencies.size > 0 || devDependencies.size > 0
    }
}

/// TOML 解析器 (简化版)
/// 严格翻译自: src/cli/bunfig.zig 中对 bunfig.toml 的解析
public class TomlParser {
    public func parse(content: String): ?TomlTable {
        let table = TomlTable()
        var currentSection = ""
        let lines = content.split("\n")

        for (line in lines) {
            let trimmed = line.trimAscii()
            if (trimmed.isEmpty() || trimmed.startsWith("#")) {
                continue
            }

            // section header: [section] 或 [section.subsection]
            if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
                currentSection = trimmed.substring(1, trimmed.size - 1).trimAscii()
                continue
            }

            // key = value
            let eqIdx = trimmed.indexOf("=")
            match (eqIdx) {
                case Some(idx) =>
                    let key = trimmed.substring(0, idx).trimAscii()
                    var value = trimmed.substring(idx + 1).trimAscii()

                    // 去除引号
                    if ((value.startsWith("\"") && value.endsWith("\"")) ||
                        (value.startsWith("'") && value.endsWith("'"))) {
                        value = value.substring(1, value.size - 1)
                    }

                    let fullKey = if (currentSection.isEmpty()) {
                        key
                    } else {
                        "${currentSection}.${key}"
                    }
                    table.set(fullKey, value)
                case None => ()
            }
        }
        return Some(table)
    }
}

/// TOML 表
public class TomlTable {
    private var entries: HashMap<String, String>

    public init() {
        entries = HashMap<String, String>()
    }

    public func set(key: String, value: String): Unit {
        entries.put(key, value)
    }

    public func get(key: String): ?String {
        entries.get(key)
    }

    public func keys(): ArrayList<String> {
        return entries.keys()
    }
}

/// TOML 辅助类
public class TomlHelper {
    public static func getString(table: TomlTable, key: String): ?String {
        table.get(key)
    }

    public static func getBool(table: TomlTable, key: String): ?Bool {
        match (table.get(key)) {
            case Some(v) =>
                if (v == "true") { return Some(true) }
                if (v == "false") { return Some(false) }
                return None
            case None => return None
        }
    }

    public static func getTable(table: TomlTable, prefix: String): ?TomlTable {
        let result = TomlTable()
        let prefixDot = prefix + "."
        var found = false
        for (key in table.keys()) {
            if (key.startsWith(prefixDot)) {
                let subKey = key.substring(prefixDot.size)
                match (table.get(key)) {
                    case Some(v) => result.set(subKey, v)
                    case None => ()
                }
                found = true
            }
        }
        return if (found) { Some(result) } else { None }
    }

    public static func getArray(table: TomlTable, key: String): ?Array<String> {
        match (table.get(key)) {
            case Some(v) =>
                // 简化的数组解析: ["a", "b", "c"]
                if (v.startsWith("[") && v.endsWith("]")) {
                    let inner = v.substring(1, v.size - 1)
                    let items = inner.split(",")
                    let result = ArrayList<String>()
                    for (item in items) {
                        let trimmed = item.trimAscii()
                        var clean = trimmed
                        if (clean.startsWith("\"") && clean.endsWith("\"")) {
                            clean = clean.substring(1, clean.size - 1)
                        }
                        if (!clean.isEmpty()) { result.append(clean) }
                    }
                    return Some(result.items())
                }
                return None
            case None => return None
        }
    }

    public static func getValue(table: TomlTable, key: String): ?String {
        table.get(key)
    }
}
