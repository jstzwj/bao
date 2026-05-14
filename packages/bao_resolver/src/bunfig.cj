// Bunfig.toml 解析器 (Bao 配置文件)
// 严格翻译自: src/bunfig/ 和 src/cli/bunfig.zig
//
// Bun 的 bunfig.toml 是项目级配置文件，包含:
//   [install]
//     preload = ["./foo.ts"]
//     optional = true
//   [run]
//     silent = true
//   [define]
//     "process.env.NODE_ENV" = "\"production\""
//   [test]
//     preload = ["./setup.ts"]
//     coverage = true
//   外部模块配置:
//     external = ["react"]
//   加载器配置:
//     [loader]
//     ".png" = "file"
//     ".txt" = "text"
//
// Bunfig.toml 使用 TOML 格式，Bun 有自己的 TOML 解析器
// 此处为仓颉实现的等价逻辑
package bao_resolver

import bao_core.*
import bao_collections.*

// ============================================================================
// BunfigToml - Bunfig 配置解析结果
// 严格对应 Bun 的 bunfig.toml 结构
// ============================================================================

/// Bunfig.toml 配置 - 对应 Bun 的 bunfig 配置
public class BunfigToml {
    /// 预加载文件列表 - 对应 Bunfig preload
    /// 在所有脚本执行前加载
    public var preload: ArrayList<String>
    /// 定义常量 - 对应 Bunfig define
    /// 替换标识符为常量值
    public var define: HashMap<String, String>
    /// 外部模块 - 对应 Bunfig external
    /// 这些模块不会被解析或打包
    public var external: ArrayList<String>
    /// 加载器映射 - 对应 Bunfig loader
    /// 文件扩展名到加载器类型的映射
    public var loader: HashMap<String, String>
    /// 测试配置 - 对应 Bunfig test
    public var test: TestConfig
    /// 安装配置 - 对应 Bunfig install
    public var install: InstallConfig
    /// 运行配置 - 对应 Bunfig run
    public var run: RunConfig
    /// 打包配置 - 对应 Bunfig bundle
    public var bundle: BundleConfig
    /// 原始 TOML 文本
    public var rawToml: String

    public init() {
        preload = ArrayList<String>()
        define = HashMap<String, String>()
        external = ArrayList<String>()
        loader = HashMap<String, String>()
        test = TestConfig()
        install = InstallConfig()
        run = RunConfig()
        bundle = BundleConfig()
        rawToml = ""
    }
}

/// 测试配置 - 对应 Bunfig [test] section
public class TestConfig {
    /// 测试预加载文件
    public var preload: ArrayList<String>
    /// 是否启用覆盖率
    public var coverage: Bool
    /// 覆盖率目录
    public var coverageDir: String
    /// 覆盖率报告器
    public var coverageReporters: ArrayList<String>
    /// 测试超时 (毫秒)
    public var timeout: Int64
    /// 更新模式
    public var updateSnapshot: Bool
    /// 测试模式
    public var testFilter: ArrayList<String>
    /// 是否只运行失败的测试
    public var onlyFailures: Bool

    public init() {
        preload = ArrayList<String>()
        coverage = false
        coverageDir = "coverage"
        coverageReporters = ArrayList<String>()
        timeout = 5000
        updateSnapshot = false
        testFilter = ArrayList<String>()
        onlyFailures = false
    }
}

/// 安装配置 - 对应 Bunfig [install] section
public class InstallConfig {
    /// 是否使用可选依赖
    public var optional: Bool
    /// 全局缓存目录
    public var globalCacheDir: String
    /// 注册表 URL
    public var registry: String
    /// 保存精确版本
    public var saveExact: Bool
    /// 保存生产依赖
    public var saveProduction: Bool
    /// 锁文件路径
    public var lockfile: String
    /// peer 依赖处理策略
    public var peer: Bool
    /// 干跑模式
    public var dryRun: Bool

    public init() {
        optional = false
        globalCacheDir = ""
        registry = "https://registry.npmjs.org"
        saveExact = false
        saveProduction = false
        lockfile = "bun.lockb"
        peer = false
        dryRun = false
    }
}

/// 运行配置 - 对应 Bunfig [run] section
public class RunConfig {
    /// 静默模式
    public var silent: Bool
    /// shell 类型
    public var shell: String
    /// 工作目录
    public var cwd: String

    public init() {
        silent = false
        shell = "bun"
        cwd = ""
    }
}

/// 打包配置 - 对应 Bunfig [bundle] section
public class BundleConfig {
    /// 入口点
    public var entryPoints: ArrayList<String>
    /// 输出目录
    public var outdir: String
    /// 目标平台
    public var target: String
    /// 格式
    public var format: String
    /// 是否压缩
    public var minify: Bool
    /// 是否生成 sourcemap
    public var sourcemap: Bool
    /// 包名 (用于 IIFE/UMD)
    public var name: String
    /// 根目录
    public var rootdir: String
    /// 是否拆分 chunk
    public var splitting: Bool

    public init() {
        entryPoints = ArrayList<String>()
        outdir = "./dist"
        target = "browser"
        format = "esm"
        minify = false
        sourcemap = false
        name = ""
        rootdir = ""
        splitting = false
    }
}

// ============================================================================
// BunfigParser - Bunfig.toml 解析器
// 对应 Bun 中 bunfig.toml 解析逻辑
// Bun 使用自定义的 TOML 解析器 (不是标准 TOML)
// 此处实现简化的 TOML-like 解析
// ============================================================================

/// Bunfig.toml 解析器
public class BunfigParser {
    private var source: String
    private var pos: Int64
    private var currentSection: String

    public init() {
        source = ""
        pos = 0
        currentSection = ""
    }

    /// 解析 Bunfig.toml 文本
    public func parse(text: String): BunfigToml {
        source = text
        pos = 0
        currentSection = ""
        let result = BunfigToml()
        result.rawToml = text

        while (pos < source.length) {
            skipWhitespace()
            if (pos >= source.length) {
                break
            }

            let ch = source[Int64(pos)]

            // 跳过注释
            if (ch == Char('#')) {
                skipComment()
                continue
            }

            // 空行
            if (ch == Char('\n') || ch == Char('\r')) {
                pos += 1
                continue
            }

            // section 头: [section] 或 [[section]]
            if (ch == Char('[')) {
                parseSectionHeader(result)
                continue
            }

            // key = value
            parseKeyValue(result)
        }

        return result
    }

    /// 解析 section 头
    /// [section] 或 [section.subsection] 或 [[array_section]]
    private func parseSectionHeader(result: BunfigToml): Unit {
        pos += 1  // skip '['

        let isArray = pos < source.length && source[Int64(pos)] == Char('[')
        if (isArray) {
            pos += 1  // skip second '['
        }

        skipWhitespace()
        let sectionName = readUntilChar(']')
        if (pos < source.length && source[Int64(pos)] == Char(']')) {
            pos += 1
        }
        if (isArray && pos < source.length && source[Int64(pos)] == Char(']')) {
            pos += 1
        }
        skipWhitespace()
        if (pos < source.length && source[Int64(pos)] == Char('\n')) {
            pos += 1
        }

        currentSection = sectionName.trim()
    }

    /// 解析 key = value 对
    private func parseKeyValue(result: BunfigToml): Unit {
        // 读取 key
        let key = readUntilChar('=').trim()
        if (key.length == 0) {
            skipLine()
            return
        }

        // 跳过 '='
        if (pos < source.length && source[Int64(pos)] == Char('=')) {
            pos += 1
        }
        skipWhitespace()

        // 读取 value
        let value = readValue()

        // 根据 section 和 key 赋值
        assignValue(result, key, value)
    }

    /// 将解析的 key=value 赋值到结果对象
    private func assignValue(result: BunfigToml, key: String, value: String): Unit {
        match (currentSection) {
            case "" => {
                // 顶层
                match (key) {
                    case "preload" => {
                        result.preload = parseArrayValue(value)
                    }
                    case "external" => {
                        result.external = parseArrayValue(value)
                    }
                    case _ => {}
                }
            }
            case "define" => {
                // [define] section
                // key 是标识符名 (可能带引号)
                let cleanKey = stripQuotes(key)
                let cleanValue = stripQuotes(value)
                result.define.put(cleanKey, cleanValue)
            }
            case "loader" => {
                // [loader] section
                // ".png" = "file"
                let extKey = stripQuotes(key)
                result.loader.put(extKey, stripQuotes(value))
            }
            case "test" => {
                assignTestValue(result.test, key, value)
            }
            case "install" => {
                assignInstallValue(result.install, key, value)
            }
            case "run" => {
                assignRunValue(result.run, key, value)
            }
            case "bundle" => {
                assignBundleValue(result.bundle, key, value)
            }
            case _ => {
                // 不认识的 section，忽略
            }
        }
    }

    /// 赋值测试配置
    private func assignTestValue(config: TestConfig, key: String, value: String): Unit {
        match (key) {
            case "preload" => config.preload = parseArrayValue(value)
            case "coverage" => config.coverage = parseBool(value)
            case "coverageDir" => config.coverageDir = stripQuotes(value)
            case "timeout" => config.timeout = parseInt(value)
            case "update" | "updateSnapshot" => config.updateSnapshot = parseBool(value)
            case "onlyFailures" => config.onlyFailures = parseBool(value)
            case "filter" | "path" => {
                config.testFilter.append(stripQuotes(value))
            }
            case _ => {}
        }
    }

    /// 赋值安装配置
    private func assignInstallValue(config: InstallConfig, key: String, value: String): Unit {
        match (key) {
            case "optional" => config.optional = parseBool(value)
            case "globalCache" | "globalCacheDir" => config.globalCacheDir = stripQuotes(value)
            case "registry" => config.registry = stripQuotes(value)
            case "saveExact" => config.saveExact = parseBool(value)
            case "saveProduction" => config.saveProduction = parseBool(value)
            case "lockfile" => config.lockfile = stripQuotes(value)
            case "peer" => config.peer = parseBool(value)
            case "dryRun" => config.dryRun = parseBool(value)
            case _ => {}
        }
    }

    /// 赋值运行配置
    private func assignRunValue(config: RunConfig, key: String, value: String): Unit {
        match (key) {
            case "silent" => config.silent = parseBool(value)
            case "shell" => config.shell = stripQuotes(value)
            case "cwd" => config.cwd = stripQuotes(value)
            case _ => {}
        }
    }

    /// 赋值打包配置
    private func assignBundleValue(config: BundleConfig, key: String, value: String): Unit {
        match (key) {
            case "entryPoints" | "entry" => config.entryPoints = parseArrayValue(value)
            case "outdir" => config.outdir = stripQuotes(value)
            case "target" => config.target = stripQuotes(value)
            case "format" => config.format = stripQuotes(value)
            case "minify" => config.minify = parseBool(value)
            case "sourcemap" => config.sourcemap = parseBool(value)
            case "name" => config.name = stripQuotes(value)
            case "rootdir" => config.rootdir = stripQuotes(value)
            case "splitting" => config.splitting = parseBool(value)
            case _ => {}
        }
    }

    // ========================================================================
    // TOML 值解析
    // ========================================================================

    /// 读取值
    private func readValue(): String {
        skipWhitespace()
        if (pos >= source.length) {
            return ""
        }

        let ch = source[Int64(pos)]

        // 字符串
        if (ch == Char('"') || ch == Char('\'')) {
            return readQuotedString()
        }

        // 数组
        if (ch == Char('[')) {
            return readArrayString()
        }

        // 内联表
        if (ch == Char('{')) {
            return readInlineTableString()
        }

        // 多行字符串
        if (ch == Char('`')) {
            return readMultiLineString()
        }

        // 简单值 (布尔、数字、裸字符串)
        let sb = StringBuilder()
        while (pos < source.length) {
            let c = source[Int64(pos)]
            if (c == Char('\n') || c == Char('\r') || c == Char('#')) {
                break
            }
            sb.append(c)
            pos += 1
        }
        return sb.toString().trim()
    }

    /// 读取引号字符串
    private func readQuotedString(): String {
        let quote = source[Int64(pos)]
        pos += 1

        let sb = StringBuilder()
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            if (ch == Char('\\') && pos + 1 < source.length) {
                pos += 1
                let escaped = source[Int64(pos)]
                match (escaped.value) {
                    case 34 => sb.append(Char(34))
                    case 92 => sb.append(Char(92))
                    case 110 => sb.append(Char(10))
                    case 114 => sb.append(Char(13))
                    case 116 => sb.append(Char(9))
                    case _ => sb.append(escaped)
                }
                pos += 1
            } else if (ch == quote) {
                pos += 1
                break
            } else {
                sb.append(ch)
                pos += 1
            }
        }
        return sb.toString()
    }

    /// 读取数组字符串表示
    private func readArrayString(): String {
        let sb = StringBuilder()
        var depth = 0
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            sb.append(ch)
            if (ch == Char('[')) { depth += 1 }
            else if (ch == Char(']')) {
                depth -= 1
                if (depth == 0) {
                    pos += 1
                    break
                }
            }
            pos += 1
        }
        return sb.toString()
    }

    /// 读取内联表字符串表示
    private func readInlineTableString(): String {
        let sb = StringBuilder()
        var depth = 0
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            sb.append(ch)
            if (ch == Char('{')) { depth += 1 }
            else if (ch == Char('}')) {
                depth -= 1
                if (depth == 0) {
                    pos += 1
                    break
                }
            }
            pos += 1
        }
        return sb.toString()
    }

    /// 读取多行字符串
    private func readMultiLineString(): String {
        pos += 1  // skip '`'
        let sb = StringBuilder()
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            if (ch == Char('`')) {
                pos += 1
                break
            }
            sb.append(ch)
            pos += 1
        }
        return sb.toString()
    }

    /// 读取直到指定字符
    private func readUntilChar(stopChar: Char): String {
        let sb = StringBuilder()
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            if (ch == stopChar) {
                break
            }
            sb.append(ch)
            pos += 1
        }
        return sb.toString()
    }

    // ========================================================================
    // 值转换工具
    // ========================================================================

    /// 解析数组值
    /// TOML 数组: ["foo", "bar", "baz"]
    private func parseArrayValue(value: String): ArrayList<String> {
        let result = ArrayList<String>()
        let trimmed = value.trim()
        if (!trimmed.startsWith("[") || !trimmed.endsWith("]")) {
            return result
        }

        let inner = trimmed.substring(Int64(1), Int64(trimmed.length - 1))
        var i = 0
        while (i < inner.length) {
            // 跳过空白
            while (i < inner.length && (inner[Int64(i)] == Char(' ') || inner[Int64(i)] == Char('\t'))) {
                i += 1
            }
            if (i >= inner.length) { break }

            // 读取元素
            if (inner[Int64(i)] == Char('"') || inner[Int64(i)] == Char('\'')) {
                // 引号字符串
                let quote = inner[Int64(i)]
                i += 1
                let sb = StringBuilder()
                while (i < inner.length && inner[Int64(i)] != quote) {
                    if (inner[Int64(i)] == Char('\\') && i + 1 < inner.length) {
                        i += 1
                        sb.append(inner[Int64(i)])
                    } else {
                        sb.append(inner[Int64(i)])
                    }
                    i += 1
                }
                i += 1  // skip closing quote
                result.append(sb.toString())
            } else {
                // 裸值
                let sb = StringBuilder()
                while (i < inner.length && inner[Int64(i)] != Char(',') && inner[Int64(i)] != Char(']')) {
                    sb.append(inner[Int64(i)])
                    i += 1
                }
                let val = sb.toString().trim()
                if (val.length > 0) {
                    result.append(val)
                }
            }

            // 跳过逗号
            while (i < inner.length && (inner[Int64(i)] == Char(',') || inner[Int64(i)] == Char(' '))) {
                i += 1
            }
        }

        return result
    }

    /// 解析布尔值
    private func parseBool(value: String): Bool {
        let lower = value.trim().toLowerCase()
        return lower == "true"
    }

    /// 解析整数
    private func parseInt(value: String): Int64 {
        var result: Int64 = 0
        for (ch in value.trim()) {
            let v = ch.value
            if (v >= 48 && v <= 57) {
                result = result * 10 + Int64(v - 48)
            }
        }
        return result
    }

    /// 去除引号
    private func stripQuotes(s: String): String {
        let trimmed = s.trim()
        if (trimmed.length >= 2) {
            if ((trimmed.startsWith("\"") && trimmed.endsWith("\"")) ||
                (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
                return trimmed.substring(Int64(1), Int64(trimmed.length - 1))
            }
        }
        return trimmed
    }

    // ========================================================================
    // 基础工具
    // ========================================================================

    /// 跳过空白
    private func skipWhitespace(): Unit {
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            if (ch == Char(' ') || ch == Char('\t') || ch == Char('\r')) {
                pos += 1
            } else {
                break
            }
        }
    }

    /// 跳过注释
    private func skipComment(): Unit {
        while (pos < source.length && source[Int64(pos)] != Char('\n')) {
            pos += 1
        }
        if (pos < source.length) {
            pos += 1  // skip '\n'
        }
    }

    /// 跳过当前行
    private func skipLine(): Unit {
        while (pos < source.length && source[Int64(pos)] != Char('\n')) {
            pos += 1
        }
        if (pos < source.length) {
            pos += 1
        }
    }
}
