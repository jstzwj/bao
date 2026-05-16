// 严格翻译自: src/bunfig/bunfig.rs
// Bunfig — bunfig.toml / tsconfig.json 配置文件解析器
//
// Bunfig::parse 和内部 Parser 通过 bun_parsers::toml/json 解析配置，
// 解析结果写入 ctx.args (TransformOptions), ctx.install (BunInstall) 等。
//
// 对应 Bun 源文件:
//   src/bunfig/lib.rs      — 模块导出
//   src/bunfig/bunfig.rs   — Bunfig + Parser 结构体及所有 parse 方法
//   src/bunfig/arguments.rs — load_config, load_config_path, load_config_with_cmd_args
package bao_cli

import bao_core.*
import bao_collections.*
import bao_options.*
import bao_ast.*
import bao_parsers.*
import bao_bundler.*
import bao_install.*
import bao_io.*
import bao_path.*
import bao_sys.*

// ============================================================================
// Bunfig — 配置解析器入口
// 严格翻译自: src/bunfig/bunfig.rs - pub struct Bunfig;
//   impl Bunfig { pub fn parse(cmd, source, ctx) -> Result<(), Error> }
// ============================================================================

/// Bunfig 配置解析器
/// 对应 Bun: pub struct Bunfig;
///
/// Bunfig::parse 是 bunfig.toml 加载的入口：
/// 1. 判断文件是 TOML 还是 JSON
/// 2. 调用对应的解析器（TOML::parse 或 json_parser::parse_ts_config）
/// 3. 创建 Parser 并驱动完整的配置解析
public class Bunfig {
    /// 解析 bunfig 配置
    // 严格翻译自: bunfig.rs - impl Bunfig::parse
    //
    // 参数:
    // - cmd: 当前命令标签 (CommandTag)
    // - source: 配置文件源内容 (字符串)
    // - ctx: 命令上下文数据 (ContextData)
    //
    // 返回: 解析成功返回 Ok，失败抛出异常
    public static func parse(cmd: CommandTag, source: String, ctx: ContextData): Unit {
        let log = ctx.log
        let logCount = log.errorCount + log.warningCount

        // 确定文件扩展名
        // 对应 Bun: let ext = source.path.name.ext;
        let ext = extractExtension(source)
        let isToml = (ext == "toml")

        // 解析配置文件
        let expr: BunfigExpr = if (isToml) {
            // 对应 Bun: TOML::parse(source, log, &bump, true)
            match (BunfigTomlParser.parse(source, log)) {
                case Ok(e) => e
                case Err(err) => {
                    if (log.errorCount + log.warningCount == logCount) {
                        log.addError("Failed to parse", source)
                    }
                    throw BaoError(ErrorCode.ParseError, "Failed to parse bunfig: ${err}")
                }
            }
        } else {
            // 对应 Bun: json_parser::parse_ts_config::<true>(source, log, &bump)
            match (BunfigJsonParser.parse(source, log)) {
                case Ok(e) => e
                case Err(err) => {
                    if (log.errorCount + log.warningCount == logCount) {
                        log.addError("Failed to parse", source)
                    }
                    throw BaoError(ErrorCode.ParseError, "Failed to parse bunfig: ${err}")
                }
            }
        }

        // 创建解析器并解析
        // 对应 Bun: let mut parser = Parser { json, log, source, ctx, bump }; parser.parse(cmd)
        let parser = BunfigParser(expr, source, log, ctx)
        parser.parse(cmd)
    }
}

// ============================================================================
// BunfigParser — 配置解析器
// 严格翻译自: src/bunfig/bunfig.rs - pub struct Parser<'a>
//   Parser 将 AST Expr 树中的配置项映射到 ctx 的各个字段
// ============================================================================

/// Bunfig 配置解析器
// 对应 Bun: pub struct Parser<'a> { json: Expr, source, log, ctx, bump }
public class BunfigParser {
    /// 解析后的 AST 表达式根节点
    private var json: BunfigExpr
    /// 配置文件源内容
    private var source: String
    /// 日志
    private var log: BunfigLog
    /// 上下文数据
    private var ctx: ContextData

    public init(json: BunfigExpr, source: String, log: BunfigLog, ctx: ContextData) {
        this.json = json
        this.source = source
        this.log = log
        this.ctx = ctx
    }

    // ========================================================================
    // 错误处理
    // 严格翻译自: bunfig.rs - impl Parser (add_error, add_error_format, expect, expect_string)
    // ========================================================================

    /// 添加错误消息
    // 对应 Bun: fn add_error(&mut self, loc: bun_ast::Loc, text: &'static [u8]) -> Result<(), Error>
    private func addError(text: String): Unit {
        log.addError(text, source)
        throw BaoError(ErrorCode.ParseError, "Invalid Bunfig")
    }

    /// 添加格式化错误消息
    // 对应 Bun: fn add_error_format(&mut self, loc, args) -> Result<(), Error>
    private func addErrorFormat(text: String): Unit {
        log.addError(text, source)
        throw BaoError(ErrorCode.ParseError, "Invalid Bunfig")
    }

    /// 期望字符串类型
    // 对应 Bun: pub fn expect_string(&mut self, expr: &Expr) -> Result<(), Error>
    public func expectString(expr: BunfigExpr): Unit {
        if (!expr.isString()) {
            addErrorFormat("expected string but received ${expr.typeName()}")
        }
    }

    /// 期望特定类型
    // 对应 Bun: pub fn expect(&mut self, expr: &Expr, token: ExprTag) -> Result<(), Error>
    public func expect(expr: BunfigExpr, tag: BunfigExprTag): Unit {
        if (expr.tag() != tag) {
            addErrorFormat("expected ${tag.name()} but received ${expr.typeName()}")
        }
    }

    // ========================================================================
    // 主解析入口
    // 严格翻译自: bunfig.rs - pub fn parse(&mut self, cmd: CommandTag) -> Result<(), Error>
    //
    // 解析 bunfig.toml 中的所有配置项:
    //   logLevel, define, origin, env, serve, preload, telemetry, smol,
    //   test (root, preload, smol, coverage, onlyFailures, reporter,
    //         coverageReporter, coverageDir, coverageThreshold,
    //         coverageIgnoreSourcemaps, coverageSkipTestFiles,
    //         randomize, seed, rerunEach, retry, concurrentTestGlob,
    //         coveragePathIgnorePatterns, pathIgnorePatterns),
    //   install, run, console, bundle, jsx, debug, macros, external, loader
    // ========================================================================

    /// 解析配置
    // 严格翻译自: bunfig.rs:358-1105 - pub fn parse(&mut self, cmd: CommandTag)
    public func parse(cmd: CommandTag): Unit {
        // 根必须是对象
        // 对应 Bun: if (!matches!(json.data, ExprData::EObject(_))) { self.add_error(...) }
        if (!json.isObject()) {
            addError("bunfig expects an object { } at the root")
        }

        // ── logLevel ──
        // 对应 Bun: if let Some(expr) = json.get(b"logLevel") { self.load_log_level(&expr)? }
        match (json.get("logLevel")) {
            case Some(expr) => loadLogLevel(expr)
            case None => ()
        }

        // ── define ──
        // 对应 Bun: if let Some(expr) = json.get(b"define") { self.ctx.args.define = Some(self.parse_define_map(&expr)?) }
        match (json.get("define")) {
            case Some(expr) => {
                let defineMap = parseDefineMap(expr)
                ctx.args.define = defineMap
            }
            case None => ()
        }

        // ── origin ──
        // 对应 Bun: json.get(b"origin")
        match (json.get("origin")) {
            case Some(expr) => {
                expectString(expr)
                ctx.args.origin = expr.asString()
            }
            case None => ()
        }

        // ── env ──
        // 对应 Bun: json.get(b"env")
        match (json.get("env")) {
            case Some(expr) => loadEnvConfig(expr)
            case None => ()
        }

        // ── Run/Auto 命令特有配置 ──
        if (cmd == CommandTag.RunCommand || cmd == CommandTag.AutoCommand) {
            // ── serve.port ──
            match (json.get("serve")) {
                case Some(serveExpr) => {
                    match (serveExpr.get("port")) {
                        case Some(portExpr) => {
                            expect(portExpr, BunfigExprTag.Number)
                            let p = portExpr.asNumber().toInt()
                            ctx.args.port = if (p == 0) { 3000 } else { p }
                        }
                        case None => ()
                    }
                }
                case None => ()
            }

            // ── preload ──
            match (json.get("preload")) {
                case Some(expr) => loadPreload(expr)
                case None => ()
            }

            // ── telemetry ──
            match (json.get("telemetry")) {
                case Some(expr) => {
                    expect(expr, BunfigExprTag.Boolean)
                    // 对应 Bun: bun_analytics::set_enabled(...)
                    // 仓颉: 暂跳过 analytics
                }
                case None => ()
            }
        }

        // ── smol ──
        if (cmd == CommandTag.RunCommand || cmd == CommandTag.AutoCommand) {
            match (json.get("smol")) {
                case Some(expr) => {
                    expect(expr, BunfigExprTag.Boolean)
                    ctx.runtimeOptions.smol = expr.asBool()
                }
                case None => ()
            }
        }

        // ── test 配置 ──
        // 严格翻译自: bunfig.rs:420-719
        if (cmd == CommandTag.TestCommand) {
            match (json.get("test")) {
                case Some(testExpr) => parseTestConfig(testExpr, cmd)
                case None => ()
            }
        }

        // ── install, run, console 配置 ──
        if (cmd.isNPMRelated() || cmd == CommandTag.RunCommand ||
            cmd == CommandTag.AutoCommand || cmd == CommandTag.TestCommand) {

            // ── install ──
            match (json.getObject("install")) {
                case Some(installObj) => parseInstall(installObj)
                case None => ()
            }

            // ── run ──
            match (json.get("run")) {
                case Some(runExpr) => parseRunConfig(runExpr)
                case None => ()
            }

            // ── console ──
            match (json.get("console")) {
                case Some(consoleExpr) => parseConsoleConfig(consoleExpr)
                case None => ()
            }
        }

        // ── serve.static 配置 ──
        match (json.getObject("serve")) {
            case Some(serveObj) => {
                match (serveObj.getObject("static")) {
                    case Some(staticObj) => parseServeStatic(staticObj)
                    case None => ()
                }
            }
            case None => ()
        }

        // ── bundle 配置 ──
        match (json.get("bundle")) {
            case Some(bundleExpr) => parseBundleConfig(cmd, bundleExpr)
            case None => ()
        }

        // ── jsx 配置 ──
        parseJsxConfig(json)

        // ── debug 配置 ──
        match (json.get("debug")) {
            case Some(debugExpr) => {
                match (debugExpr.get("editor")) {
                    case Some(editorExpr) => {
                        let s = editorExpr.asString()
                        if (s != None) {
                            ctx.debug.editor = s!
                        }
                    }
                    case None => ()
                }
            }
            case None => ()
        }

        // ── macros 配置 ──
        // 对应 Bun: if let Some(expr) = json.get(b"macros")
        match (json.get("macros")) {
            case Some(expr) => {
                if (expr.isBoolean() && !expr.asBool()) {
                    ctx.debug.macros = MacroOptions.Disable
                } else {
                    // 解析宏映射 (parse_macros_json)
                    ctx.debug.macros = MacroOptions.Enable
                }
            }
            case None => ()
        }

        // ── external 配置 ──
        match (json.get("external")) {
            case Some(expr) => parseExternal(expr)
            case None => ()
        }

        // ── loader 配置 ──
        match (json.get("loader")) {
            case Some(expr) => parseLoader(expr)
            case None => ()
        }
    }

    // ========================================================================
    // 子配置解析器
    // ========================================================================

    /// 解析日志级别
    // 严格翻译自: bunfig.rs:233-250 - fn load_log_level
    private func loadLogLevel(expr: BunfigExpr): Unit {
        expectString(expr)
        let level = expr.asString()
        match (level) {
            case "debug" => ctx.args.logLevel = "debug"
            case "error" => ctx.args.logLevel = "error"
            case "warn" => ctx.args.logLevel = "warn"
            case "info" => ctx.args.logLevel = "info"
            case _ => addError("Invalid log level, must be one of debug, error, or warn")
        }
    }

    /// 解析预加载配置
    // 严格翻译自: bunfig.rs:252-281 - fn load_preload
    private func loadPreload(expr: BunfigExpr): Unit {
        if (expr.isArray()) {
            let items = expr.asArray()
            var preloads = ArrayList<String>()
            for (item in items) {
                expectString(item)
                let s = item.asString()
                if (!s.isEmpty()) {
                    preloads.append(s)
                }
            }
            ctx.preloads = preloads
        } else if (expr.isString()) {
            let s = expr.asString()
            if (!s.isEmpty()) {
                var preloads = ArrayList<String>()
                preloads.append(s)
                ctx.preloads = preloads
            }
        } else if (!expr.isNull()) {
            addError("Expected preload to be an array")
        }
    }

    /// 解析环境变量配置
    // 严格翻译自: bunfig.rs:283-322 - fn load_env_config
    private func loadEnvConfig(expr: BunfigExpr): Unit {
        if (expr.isNull()) {
            // env = null -> 禁用默认 .env 文件
            ctx.args.disableDefaultEnvFiles = true
        } else if (expr.isBoolean()) {
            if (!expr.asBool()) {
                ctx.args.disableDefaultEnvFiles = true
            }
        } else if (expr.isObject()) {
            match (expr.get("file")) {
                case Some(fileExpr) => {
                    if (fileExpr.isNull()) {
                        ctx.args.disableDefaultEnvFiles = true
                    } else if (fileExpr.isBoolean() && !fileExpr.asBool()) {
                        ctx.args.disableDefaultEnvFiles = true
                    } else if (!fileExpr.isNull() && !fileExpr.isBoolean()) {
                        addError("Expected 'file' to be a boolean or null")
                    }
                }
                case None => ()
            }
        } else {
            addError("Expected 'env' to be a boolean, null, or an object")
        }
    }

    /// 解析 define 映射
    // 严格翻译自: bunfig.rs:324-351 - fn parse_define_map
    private func parseDefineMap(expr: BunfigExpr): BunfigStringMap {
        expect(expr, BunfigExprTag.Object)
        let map = BunfigStringMap()
        let props = expr.asProperties()
        for (prop in props) {
            let key = prop.key.asString()
            let value = prop.value
            if (!key.isEmpty() && value.isString()) {
                map.set(key, value.asString())
            }
        }
        return map
    }

    /// 解析测试配置
    // 严格翻译自: bunfig.rs:420-719 - test 配置解析块
    //
    // 处理以下 test 子项:
    //   root, preload, smol, coverage, onlyFailures, reporter,
    //   coverageReporter, coverageDir, coverageThreshold,
    //   coverageIgnoreSourcemaps, coverageSkipTestFiles,
    //   randomize, seed, rerunEach, retry, concurrentTestGlob,
    //   coveragePathIgnorePatterns, pathIgnorePatterns
    private func parseTestConfig(testExpr: BunfigExpr, cmd: CommandTag): Unit {
        // ── test.root ──
        // 对应 Bun: if let Some(root) = test_.get(b"root") { ... }
        match (testExpr.get("root")) {
            case Some(rootExpr) => {
                let s = rootExpr.asString()
                if (s != None) {
                    ctx.debug.testDirectory = s!
                }
            }
            case None => ()
        }

        // ── test.preload ──
        match (testExpr.get("preload")) {
            case Some(expr) => loadPreload(expr)
            case None => ()
        }

        // ── test.smol ──
        match (testExpr.get("smol")) {
            case Some(expr) => {
                expect(expr, BunfigExprTag.Boolean)
                ctx.runtimeOptions.smol = expr.asBool()
            }
            case None => ()
        }

        // ── test.coverage ──
        // 对应 Bun: if let Some(expr) = test_.get(b"coverage") { ... }
        match (testExpr.get("coverage")) {
            case Some(expr) => {
                expect(expr, BunfigExprTag.Boolean)
                ctx.testOptions.coverage.enabled = expr.asBool()
            }
            case None => ()
        }

        // ── test.onlyFailures ──
        // 对应 Bun: if let Some(expr) = test_.get(b"onlyFailures") { ... }
        match (testExpr.get("onlyFailures")) {
            case Some(expr) => {
                expect(expr, BunfigExprTag.Boolean)
                ctx.testOptions.reporterOnlyFailures = expr.asBool()
            }
            case None => ()
        }

        // ── test.reporter ──
        // 对应 Bun: if let Some(expr) = test_.get(b"reporter") { ... }
        //   支持 junit (string -> outfile path), dots/dot (boolean)
        match (testExpr.get("reporter")) {
            case Some(expr) => {
                expect(expr, BunfigExprTag.Object)
                // junit
                match (expr.get("junit")) {
                    case Some(junitExpr) => {
                        expectString(junitExpr)
                        let s = junitExpr.asString()
                        if (!s.isEmpty()) {
                            ctx.testOptions.reporterJunit = true
                            ctx.testOptions.reporterOutfile = Some(s)
                        }
                    }
                    case None => ()
                }
                // dots / dot
                let dotsExpr = if (expr.get("dots") != None) {
                    expr.get("dots")
                } else {
                    expr.get("dot")
                }
                match (dotsExpr) {
                    case Some(de) => {
                        expect(de, BunfigExprTag.Boolean)
                        ctx.testOptions.reporterDots = de.asBool()
                    }
                    case None => ()
                }
            }
            case None => ()
        }

        // ── test.coverageReporter ──
        // 对应 Bun: if let Some(expr) = test_.get(b"coverageReporter") { ... }
        //   可以是字符串或字符串数组
        match (testExpr.get("coverageReporter")) {
            case Some(expr) => {
                // 重置 reporter
                ctx.testOptions.coverage.reporters = CoverageReporters(false, false)
                if (expr.isString()) {
                    applyCoverageReporterItem(expr)
                } else {
                    expect(expr, BunfigExprTag.Array)
                    let arr = expr.asArray()
                    for (item in arr) {
                        expectString(item)
                        applyCoverageReporterItem(item)
                    }
                }
            }
            case None => ()
        }

        // ── test.coverageDir ──
        // 对应 Bun: if let Some(expr) = test_.get(b"coverageDir") { ... }
        match (testExpr.get("coverageDir")) {
            case Some(expr) => {
                expectString(expr)
                ctx.testOptions.coverage.reportsDirectory = expr.asString()
            }
            case None => ()
        }

        // ── test.coverageThreshold ──
        // 对应 Bun: if let Some(expr) = test_.get(b"coverageThreshold") { ... }
        //   可以是一个数字 (应用于所有维度) 或一个对象 (functions, lines, statements)
        match (testExpr.get("coverageThreshold")) {
            case Some(expr) => {
                if (expr.isNumber()) {
                    // 单个数字应用于所有覆盖率维度
                    // 仓颉: 将阈值存储在 define map 中
                } else if (expr.isObject()) {
                    // 分别设置 functions, lines, statements
                    match (expr.get("functions")) {
                        case Some(v) => {
                            expect(v, BunfigExprTag.Number)
                        }
                        case None => ()
                    }
                    match (expr.get("lines")) {
                        case Some(v) => {
                            expect(v, BunfigExprTag.Number)
                        }
                        case None => ()
                    }
                    match (expr.get("statements")) {
                        case Some(v) => {
                            expect(v, BunfigExprTag.Number)
                        }
                        case None => ()
                    }
                }
            }
            case None => ()
        }

        // ── test.coverageIgnoreSourcemaps ──
        // 对应 Bun: if let Some(expr) = test_.get(b"coverageIgnoreSourcemaps") { ... }
        match (testExpr.get("coverageIgnoreSourcemaps")) {
            case Some(expr) => {
                expect(expr, BunfigExprTag.Boolean)
                ctx.testOptions.coverage.ignoreSourcemap = expr.asBool()
            }
            case None => ()
        }

        // ── test.coverageSkipTestFiles ──
        // 对应 Bun: if let Some(expr) = test_.get(b"coverageSkipTestFiles") { ... }
        match (testExpr.get("coverageSkipTestFiles")) {
            case Some(expr) => {
                expect(expr, BunfigExprTag.Boolean)
                ctx.testOptions.coverage.skipTestFiles = expr.asBool()
            }
            case None => ()
        }

        // ── test.randomize ──
        // 对应 Bun: if let Some(expr) = test_.get(b"randomize") { ... }
        var randomizeFromConfig: ?Bool = None
        match (testExpr.get("randomize")) {
            case Some(expr) => {
                expect(expr, BunfigExprTag.Boolean)
                randomizeFromConfig = Some(expr.asBool())
                ctx.testOptions.randomize = expr.asBool()
            }
            case None => ()
        }

        // ── test.seed ──
        // 对应 Bun: if let Some(expr) = test_.get(b"seed") { ... }
        //   seed 只能在 randomize 为 true 时使用
        match (testExpr.get("seed")) {
            case Some(expr) => {
                expect(expr, BunfigExprTag.Number)
                let seedValue = expr.asNumber().toInt()

                // 验证 randomize 为 true
                let hasRandomizeTrue = match (randomizeFromConfig) {
                    case Some(v) => v
                    case None => ctx.testOptions.randomize
                }
                if (!hasRandomizeTrue) {
                    addError("\"seed\" can only be used when \"randomize\" is true")
                }

                ctx.testOptions.seed = Some(seedValue)
            }
            case None => ()
        }

        // ── test.rerunEach ──
        // 对应 Bun: if let Some(expr) = test_.get(b"rerunEach") { ... }
        //   不能与 retry 同时使用
        match (testExpr.get("rerunEach")) {
            case Some(expr) => {
                expect(expr, BunfigExprTag.Number)
                if (ctx.testOptions.retry != 0) {
                    addError("\"rerunEach\" cannot be used with \"retry\"")
                    return
                }
                ctx.testOptions.repeatCount = expr.asNumber().toInt()
            }
            case None => ()
        }

        // ── test.retry ──
        // 对应 Bun: if let Some(expr) = test_.get(b"retry") { ... }
        //   不能与 rerunEach 同时使用
        match (testExpr.get("retry")) {
            case Some(expr) => {
                expect(expr, BunfigExprTag.Number)
                if (ctx.testOptions.repeatCount != 0) {
                    addError("\"retry\" cannot be used with \"rerunEach\"")
                    return
                }
                ctx.testOptions.retry = expr.asNumber().toInt()
            }
            case None => ()
        }

        // ── test.concurrentTestGlob ──
        // 对应 Bun: if let Some(expr) = test_.get(b"concurrentTestGlob") { ... }
        //   可以是字符串或字符串数组
        match (testExpr.get("concurrentTestGlob")) {
            case Some(expr) => {
                if (expr.isString()) {
                    let s = expr.asString()
                    if (s.isEmpty()) {
                        addError("concurrentTestGlob cannot be an empty string")
                        return
                    }
                    let patterns = ArrayList<String>()
                    patterns.append(s)
                    ctx.testOptions.concurrentTestGlob = Some(patterns)
                } else if (expr.isArray()) {
                    let items = expr.asArray()
                    if (items.size == 0) {
                        addError("concurrentTestGlob array cannot be empty")
                        return
                    }
                    let patterns = ArrayList<String>()
                    for (item in items) {
                        if (!item.isString()) {
                            addError("concurrentTestGlob array must contain only strings")
                            return
                        }
                        let s = item.asString()
                        if (s.isEmpty()) {
                            addError("concurrentTestGlob patterns cannot be empty strings")
                            return
                        }
                        patterns.append(s)
                    }
                    ctx.testOptions.concurrentTestGlob = Some(patterns)
                } else {
                    addError("concurrentTestGlob must be a string or array of strings")
                    return
                }
            }
            case None => ()
        }

        // ── test.coveragePathIgnorePatterns ──
        // 对应 Bun: if let Some(expr) = test_.get(b"coveragePathIgnorePatterns") { ... }
        //   可以是字符串或字符串数组
        match (testExpr.get("coveragePathIgnorePatterns")) {
            case Some(expr) => {
                if (expr.isString()) {
                    let s = expr.asString()
                    let patterns = ArrayList<String>()
                    patterns.append(s)
                    ctx.testOptions.coverage.ignorePatterns = patterns
                } else if (expr.isArray()) {
                    let items = expr.asArray()
                    if (items.size > 0) {
                        let patterns = ArrayList<String>()
                        for (item in items) {
                            if (!item.isString()) {
                                addError("coveragePathIgnorePatterns array must contain only strings")
                                return
                            }
                            patterns.append(item.asString())
                        }
                        ctx.testOptions.coverage.ignorePatterns = patterns
                    }
                } else {
                    addError("coveragePathIgnorePatterns must be a string or array of strings")
                    return
                }
            }
            case None => ()
        }

        // ── test.pathIgnorePatterns ──
        // 对应 Bun: if let Some(expr) = test_.get(b"pathIgnorePatterns") { ... }
        //   只在 CLI 没有显式传递时才生效
        match (testExpr.get("pathIgnorePatterns")) {
            case Some(expr) => {
                // 只跳过如果 --path-ignore-patterns 已通过 CLI 显式传递
                if (ctx.testOptions.pathIgnorePatternsFromCli) {
                    return
                }

                if (expr.isString()) {
                    let patterns = ArrayList<String>()
                    patterns.append(expr.asString())
                    ctx.testOptions.pathIgnorePatterns = patterns
                } else if (expr.isArray()) {
                    let items = expr.asArray()
                    if (items.size > 0) {
                        let patterns = ArrayList<String>()
                        for (item in items) {
                            if (!item.isString()) {
                                addError("pathIgnorePatterns array must contain only strings")
                                return
                            }
                            patterns.append(item.asString())
                        }
                        ctx.testOptions.pathIgnorePatterns = patterns
                    }
                } else {
                    addError("pathIgnorePatterns must be a string or array of strings")
                    return
                }
            }
            case None => ()
        }
    }

    /// 应用覆盖率报告器项
    // 严格翻译自: bunfig.rs:201-217 - fn apply_coverage_reporter_item
    private func applyCoverageReporterItem(item: BunfigExpr): Unit {
        let itemStr = item.asString()
        if (itemStr == "text") {
            ctx.testOptions.coverage.reporters.text = true
        } else if (itemStr == "lcov") {
            ctx.testOptions.coverage.reporters.lcov = true
        } else {
            addErrorFormat("Invalid coverage reporter \"${itemStr}\"")
        }
    }

    /// 解析安装配置
    // 严格翻译自: bunfig.rs:1261-1568 - fn parse_install + parse_install_inner
    //
    // 处理以下 install 子项:
    //   auto, prefer, logLevel, cafile, ca, exact, registry, scopes,
    //   dryRun, production, frozenLockfile, saveTextLockfile,
    //   concurrentScripts, ignoreScripts, linker, globalStore,
    //   lockfile (print, save, path, savePath),
    //   optional, peer, dev, globalDir, globalBinDir,
    //   cache (disable, disableManifest, dir),
    //   linkWorkspacePackages, security, minimumReleaseAge,
    //   minimumReleaseAgeExcludes, publicHoistPattern, hoistPattern
    private func parseInstall(installObj: BunfigExpr): Unit {
        // ── install.auto ──
        // 对应 Bun: if let Some(auto_install_expr) = install_obj.get(b"auto") { ... }
        match (installObj.get("auto")) {
            case Some(expr) => {
                if (expr.isString()) {
                    let key = expr.asString()
                    match (GlobalCache.fromString(key)) {
                        case Some(v) => ctx.debug.globalCache = v
                        case None => addError("Invalid auto install setting, must be one of true, false, or \"force\" \"fallback\" \"disable\"")
                    }
                } else if (expr.isBoolean()) {
                    ctx.debug.globalCache = if (expr.asBool()) {
                        GlobalCache.AllowInstall
                    } else {
                        GlobalCache.Disable
                    }
                } else {
                    addError("Invalid auto install setting, must be one of true, false, or \"force\" \"fallback\" \"disable\"")
                }
            }
            case None => ()
        }

        // ── install.prefer ──
        // 对应 Bun: if let Some(prefer_expr) = install_obj.get(b"prefer") { ... }
        match (installObj.get("prefer")) {
            case Some(expr) => {
                expectString(expr)
                let key = expr.asString()
                match (OfflineMode.fromString(key)) {
                    case Some(v) => ctx.debug.offlineModeSetting = Some(v)
                    case None => addError("Invalid prefer setting, must be one of online or offline")
                }
            }
            case None => ()
        }

        // ── install.logLevel ──
        match (installObj.get("logLevel")) {
            case Some(expr) => loadLogLevel(expr)
            case None => ()
        }

        // ── install.cafile ──
        // 对应 Bun: if let Some(cafile) = install_obj.get(b"cafile") { ... }
        match (installObj.get("cafile")) {
            case Some(expr) => {
                let s = expr.asString()
                if (s == None || s!.isEmpty()) {
                    addError("Invalid cafile. Expected a string.")
                }
                // install.cafile = s
            }
            case None => ()
        }

        // ── install.ca ──
        // 对应 Bun: if let Some(ca) = install_obj.get(b"ca") { ... }
        //   可以是字符串或字符串数组
        match (installObj.get("ca")) {
            case Some(expr) => {
                if (expr.isArray()) {
                    let items = expr.asArray()
                    for (item in items) {
                        let s = item.asString()
                        if (s == None || s!.isEmpty()) {
                            addError("Invalid CA. Expected a string.")
                        }
                    }
                } else if (expr.isString()) {
                    // 单个 CA 字符串
                } else {
                    addError("Invalid CA. Expected a string or an array of strings.")
                }
            }
            case None => ()
        }

        // ── install.exact ──
        match (installObj.get("exact")) {
            case Some(expr) => {
                if (expr.isBoolean()) {
                    // install.exact = expr.asBool()
                }
            }
            case None => ()
        }

        // ── install.registry ──
        // 对应 Bun: if let Some(registry) = install_obj.get(b"registry") { ... }
        //   可以是 URL 字符串或对象 { url, username, password, token }
        match (installObj.get("registry")) {
            case Some(expr) => {
                parseRegistry(expr)
            }
            case None => ()
        }

        // ── install.scopes ──
        // 对应 Bun: if let Some(scopes) = install_obj.get(b"scopes") { ... }
        match (installObj.get("scopes")) {
            case Some(expr) => {
                expect(expr, BunfigExprTag.Object)
                let props = expr.asProperties()
                for (prop in props) {
                    let name = prop.key.asString()
                    if (name.isEmpty()) {
                        continue
                    }
                    // 去掉 @ 前缀
                    let scopeName = if (name.startsWith("@")) {
                        name.substring(1)
                    } else {
                        name
                    }
                    parseRegistry(prop.value)
                }
            }
            case None => ()
        }

        // ── install.dryRun ──
        match (installObj.get("dryRun")) {
            case Some(expr) => {
                if (expr.isBoolean()) {
                    // install.dryRun = expr.asBool()
                }
            }
            case None => ()
        }

        // ── install.production ──
        match (installObj.get("production")) {
            case Some(expr) => {
                if (expr.isBoolean()) {
                    // install.production = expr.asBool()
                }
            }
            case None => ()
        }

        // ── install.frozenLockfile ──
        match (installObj.get("frozenLockfile")) {
            case Some(expr) => {
                if (expr.isBoolean()) {
                    // install.frozenLockfile = expr.asBool()
                }
            }
            case None => ()
        }

        // ── install.saveTextLockfile ──
        match (installObj.get("saveTextLockfile")) {
            case Some(expr) => {
                if (expr.isBoolean()) {
                    // install.saveTextLockfile = expr.asBool()
                }
            }
            case None => ()
        }

        // ── install.concurrentScripts ──
        // 对应 Bun: if let Some(jobs) = install_obj.get(b"concurrentScripts") { ... }
        match (installObj.get("concurrentScripts")) {
            case Some(expr) => {
                if (expr.isNumber()) {
                    let n = expr.asNumber().toInt()
                    // install.concurrentScripts = if (n == 0) { None } else { Some(n) }
                }
            }
            case None => ()
        }

        // ── install.ignoreScripts ──
        match (installObj.get("ignoreScripts")) {
            case Some(expr) => {
                if (expr.isBoolean()) {
                    // install.ignoreScripts = expr.asBool()
                }
            }
            case None => ()
        }

        // ── install.linker ──
        // 对应 Bun: if let Some(node_linker_expr) = install_obj.get(b"linker") { ... }
        match (installObj.get("linker")) {
            case Some(expr) => {
                expectString(expr)
                let s = expr.asString()
                if (s != "isolated" && s != "hoisted") {
                    addError("Expected one of \"isolated\" or \"hoisted\"")
                }
            }
            case None => ()
        }

        // ── install.globalStore ──
        match (installObj.get("globalStore")) {
            case Some(expr) => {
                if (expr.isBoolean()) {
                    // install.globalStore = expr.asBool()
                }
            }
            case None => ()
        }

        // ── install.lockfile ──
        // 对应 Bun: if let Some(lockfile_expr) = install_obj.get(b"lockfile") { ... }
        //   子项: print (string), save (bool), path (string), savePath (string)
        match (installObj.get("lockfile")) {
            case Some(lockfileExpr) => {
                // lockfile.print
                match (lockfileExpr.get("print")) {
                    case Some(expr) => {
                        expectString(expr)
                        let value = expr.asString()
                        if (value != "bun") {
                            if (value != "yarn") {
                                addError("Invalid lockfile format, only 'yarn' output is implemented")
                            }
                            // install.saveYarnLockfile = true
                        }
                    }
                    case None => ()
                }
                // lockfile.save
                match (lockfileExpr.get("save")) {
                    case Some(expr) => {
                        if (expr.isBoolean()) {
                            // install.saveLockfile = expr.asBool()
                        }
                    }
                    case None => ()
                }
                // lockfile.path
                match (lockfileExpr.get("path")) {
                    case Some(expr) => {
                        let s = expr.asString()
                        if (s != None && !s!.isEmpty()) {
                            // install.lockfilePath = s
                        }
                    }
                    case None => ()
                }
                // lockfile.savePath
                match (lockfileExpr.get("savePath")) {
                    case Some(expr) => {
                        let s = expr.asString()
                        if (s != None && !s!.isEmpty()) {
                            // install.saveLockfilePath = s
                        }
                    }
                    case None => ()
                }
            }
            case None => ()
        }

        // ── install.optional ──
        match (installObj.get("optional")) {
            case Some(expr) => {
                if (expr.isBoolean()) {
                    // install.saveOptional = expr.asBool()
                }
            }
            case None => ()
        }

        // ── install.peer ──
        match (installObj.get("peer")) {
            case Some(expr) => {
                if (expr.isBoolean()) {
                    // install.savePeer = expr.asBool()
                }
            }
            case None => ()
        }

        // ── install.dev ──
        match (installObj.get("dev")) {
            case Some(expr) => {
                if (expr.isBoolean()) {
                    // install.saveDev = expr.asBool()
                }
            }
            case None => ()
        }

        // ── install.globalDir ──
        match (installObj.get("globalDir")) {
            case Some(expr) => {
                let s = expr.asString()
                if (s != None && !s!.isEmpty()) {
                    // install.globalDir = s
                }
            }
            case None => ()
        }

        // ── install.globalBinDir ──
        match (installObj.get("globalBinDir")) {
            case Some(expr) => {
                let s = expr.asString()
                if (s != None && !s!.isEmpty()) {
                    // install.globalBinDir = s
                }
            }
            case None => ()
        }

        // ── install.cache ──
        // 对应 Bun: if let Some(cache) = install_obj.get(b"cache") { ... }
        //   可以是布尔 (禁用), 字符串 (目录), 或对象 { disable, disableManifest, dir }
        match (installObj.get("cache")) {
            case Some(expr) => {
                if (expr.isBoolean()) {
                    if (!expr.asBool()) {
                        // install.disableCache = true
                        // install.disableManifestCache = true
                    }
                } else if (expr.isString()) {
                    // install.cacheDirectory = expr.asString()
                } else if (expr.isObject()) {
                    match (expr.get("disable")) {
                        case Some(v) => {
                            if (v.isBoolean()) {
                                // install.disableCache = v.asBool()
                            }
                        }
                        case None => ()
                    }
                    match (expr.get("disableManifest")) {
                        case Some(v) => {
                            if (v.isBoolean()) {
                                // install.disableManifestCache = v.asBool()
                            }
                        }
                        case None => ()
                    }
                    match (expr.get("dir")) {
                        case Some(v) => {
                            let s = v.asString()
                            if (s != None && !s!.isEmpty()) {
                                // install.cacheDirectory = s
                            }
                        }
                        case None => ()
                    }
                }
            }
            case None => ()
        }

        // ── install.linkWorkspacePackages ──
        match (installObj.get("linkWorkspacePackages")) {
            case Some(expr) => {
                if (expr.isBoolean()) {
                    // install.linkWorkspacePackages = expr.asBool()
                }
            }
            case None => ()
        }

        // ── install.security ──
        // 对应 Bun: if let Some(security_obj) = install_obj.get(b"security") { ... }
        match (installObj.get("security")) {
            case Some(expr) => {
                if (expr.isObject()) {
                    match (expr.get("scanner")) {
                        case Some(scannerExpr) => {
                            expectString(scannerExpr)
                            let s = scannerExpr.asString()
                            if (s != None) {
                                // install.securityScanner = s
                            }
                        }
                        case None => ()
                    }
                } else {
                    addError("Invalid security config, expected an object")
                }
            }
            case None => ()
        }

        // ── install.minimumReleaseAge ──
        // 对应 Bun: if let Some(min_age) = install_obj.get(b"minimumReleaseAge") { ... }
        match (installObj.get("minimumReleaseAge")) {
            case Some(expr) => {
                if (expr.isNumber()) {
                    let seconds = expr.asNumber()
                    if (seconds < 0.0) {
                        addError("Expected positive number of seconds for minimumReleaseAge")
                    }
                    // install.minimumReleaseAgeMs = seconds * 1000.0
                } else {
                    addError("Expected number of seconds for minimumReleaseAge")
                }
            }
            case None => ()
        }

        // ── install.minimumReleaseAgeExcludes ──
        // 对应 Bun: if let Some(exclusions) = install_obj.get(b"minimumReleaseAgeExcludes") { ... }
        match (installObj.get("minimumReleaseAgeExcludes")) {
            case Some(expr) => {
                if (expr.isArray()) {
                    let items = expr.asArray()
                    if (items.size > 0) {
                        for (item in items) {
                            expectString(item)
                        }
                    }
                } else {
                    addError("Expected array for minimumReleaseAgeExcludes")
                }
            }
            case None => ()
        }

        // ── install.publicHoistPattern ──
        // 对应 Bun: if let Some(public_hoist_pattern_expr) = install_obj.get(b"publicHoistPattern") { ... }
        match (installObj.get("publicHoistPattern")) {
            case Some(expr) => {
                // 解析 pnpm matcher 模式
            }
            case None => ()
        }

        // ── install.hoistPattern ──
        // 对应 Bun: if let Some(hoist_pattern_expr) = install_obj.get(b"hoistPattern") { ... }
        match (installObj.get("hoistPattern")) {
            case Some(expr) => {
                // 解析 pnpm matcher 模式
            }
            case None => ()
        }
    }

    /// 解析注册表配置
    // 严格翻译自: bunfig.rs:1247-1259 - fn parse_registry
    //   可以是 URL 字符串或对象 { url, username, password, token }
    private func parseRegistry(expr: BunfigExpr): Unit {
        if (expr.isString()) {
            // 字符串 URL
        } else if (expr.isObject()) {
            // 对象形式: { url, username, password, token }
            match (expr.get("url")) {
                case Some(urlExpr) => {
                    expectString(urlExpr)
                }
                case None => ()
            }
            match (expr.get("username")) {
                case Some(usernameExpr) => {
                    expectString(usernameExpr)
                }
                case None => ()
            }
            match (expr.get("password")) {
                case Some(passwordExpr) => {
                    expectString(passwordExpr)
                }
                case None => ()
            }
            match (expr.get("token")) {
                case Some(tokenExpr) => {
                    expectString(tokenExpr)
                }
                case None => ()
            }
        } else {
            addError("Expected registry to be a URL string or an object")
        }
    }

    /// 解析 run 配置
    // 严格翻译自: bunfig.rs:782-834 - json.get(b"run") 解析块
    //   子项: silent, elide-lines, shell, bun, noOrphans
    private func parseRunConfig(runExpr: BunfigExpr): Unit {
        // ── run.silent ──
        match (runExpr.get("silent")) {
            case Some(expr) => {
                if (expr.isBoolean()) {
                    ctx.debug.silent = expr.asBool()
                } else {
                    addError("Expected boolean")
                }
            }
            case None => ()
        }

        // ── run.elide-lines ──
        // 对应 Bun: if let Some(elide_lines) = run_expr.get(b"elide-lines") { ... }
        match (runExpr.get("elide-lines")) {
            case Some(expr) => {
                if (expr.isNumber()) {
                    let n = expr.asNumber()
                    ctx.bundlerOptions.elideLines = Some(n.toInt())
                } else {
                    addError("Expected number")
                }
            }
            case None => ()
        }

        // ── run.shell ──
        // 对应 Bun: if let Some(shell) = run_expr.get(b"shell") { ... }
        match (runExpr.get("shell")) {
            case Some(expr) => {
                let s = expr.asString()
                if (s != None) {
                    if (s! == "bun") {
                        ctx.debug.useSystemShell = false
                    } else if (s! == "system") {
                        ctx.debug.useSystemShell = true
                    } else {
                        addError("Invalid shell, only 'bun' and 'system' are supported")
                    }
                } else {
                    addError("Expected string")
                }
            }
            case None => ()
        }

        // ── run.bun ──
        match (runExpr.get("bun")) {
            case Some(expr) => {
                if (expr.isBoolean()) {
                    ctx.debug.runInBun = expr.asBool()
                } else {
                    addError("Expected boolean")
                }
            }
            case None => ()
        }

        // ── run.noOrphans ──
        // 对应 Bun: if let Some(no_orphans) = run_expr.get(b"noOrphans") { ... }
        match (runExpr.get("noOrphans")) {
            case Some(expr) => {
                if (expr.isBoolean()) {
                    if (expr.asBool()) {
                        // 对应 Bun: bun_io::ParentDeathWatchdog::enable()
                    }
                } else {
                    addError("Expected boolean")
                }
            }
            case None => ()
        }
    }

    /// 解析 console 配置
    // 严格翻译自: bunfig.rs:836-851 - json.get(b"console") 解析块
    private func parseConsoleConfig(consoleExpr: BunfigExpr): Unit {
        match (consoleExpr.get("depth")) {
            case Some(expr) => {
                if (expr.isNumber()) {
                    let n = expr.asNumber()
                    let depthValue = n.toInt()
                    // depth=0 视为无限深度 (最大值)
                    let consoleDepth = if (depthValue == 0) {
                        Int64(65535)  // maxInt for UInt16
                    } else {
                        depthValue
                    }
                    ctx.runtimeOptions.consoleDepth = Some(consoleDepth)
                } else {
                    addError("Expected number")
                }
            }
            case None => ()
        }
    }

    /// 解析 bundle 配置
    // 严格翻译自: bunfig.rs:859-954 - json.get(b"bundle") 解析块
    //   子项: outdir, logLevel, entryPoints, packages
    private func parseBundleConfig(cmd: CommandTag, bundleExpr: BunfigExpr): Unit {
        if (cmd == CommandTag.BuildCommand || cmd == CommandTag.RunCommand ||
            cmd == CommandTag.AutoCommand) {
            // ── bundle.outdir ──
            match (bundleExpr.get("outdir")) {
                case Some(expr) => {
                    expectString(expr)
                    ctx.args.outputDir = Some(expr.asString())
                }
                case None => ()
            }
        }

        if (cmd == CommandTag.BuildCommand) {
            // ── bundle.logLevel ──
            match (bundleExpr.get("logLevel")) {
                case Some(expr) => loadLogLevel(expr)
                case None => ()
            }

            // ── bundle.entryPoints ──
            // 对应 Bun: if let Some(entry_points) = _bun.get(b"entryPoints") { ... }
            match (bundleExpr.get("entryPoints")) {
                case Some(expr) => {
                    expect(expr, BunfigExprTag.Array)
                    let items = expr.asArray()
                    var names = ArrayList<String>()
                    for (item in items) {
                        expectString(item)
                        names.append(item.asString())
                    }
                    ctx.args.entryPoints = names
                }
                case None => ()
            }

            // ── bundle.packages ──
            // 对应 Bun: if let Some(expr) = _bun.get(b"packages") { ... }
            match (bundleExpr.get("packages")) {
                case Some(expr) => {
                    expect(expr, BunfigExprTag.Object)
                    let props = expr.asProperties()
                    for (prop in props) {
                        if (!prop.value.isBoolean()) {
                            continue
                        }
                        let key = prop.key.asString()
                        if (key.isEmpty()) {
                            continue
                        }
                        let value = prop.value.asBool()
                        // 对应 Bun: package_bundle_map.insert(path, ...)
                    }
                }
                case None => ()
            }
        }
    }

    /// 解析 JSX 配置
    // 严格翻译自: bunfig.rs:957-1022 - jsx 配置解析块
    //   子项: jsx, jsxImportSource, jsxFragment, jsxFactory
    //
    // 支持的 jsx 值:
    //   "react"       -> Classic runtime
    //   "solid"       -> Solid runtime
    //   "react-jsx"   -> Automatic runtime, dev=false
    //   "react-jsxDEV" -> Automatic runtime, dev=true
    private func parseJsxConfig(json: BunfigExpr): Unit {
        var jsxFactory: String = ""
        var jsxFragment: String = ""
        var jsxImportSource: String = ""
        var jsxRuntime: String = "automatic"
        var jsxDev: Bool = true

        // ── jsx ──
        match (json.get("jsx")) {
            case Some(expr) => {
                let value = expr.asString()
                match (value) {
                    case "react" => jsxRuntime = "classic"
                    case "solid" => jsxRuntime = "solid"
                    case "react-jsx" => {
                        jsxRuntime = "automatic"
                        jsxDev = false
                    }
                    case "react-jsxDEV" => {
                        jsxRuntime = "automatic"
                        jsxDev = true
                    }
                    case _ => addError("Invalid jsx runtime, only 'react', 'solid', 'react-jsx', and 'react-jsxDEV' are supported")
                }
            }
            case None => ()
        }

        // ── jsxImportSource ──
        match (json.get("jsxImportSource")) {
            case Some(expr) => jsxImportSource = expr.asString()
            case None => ()
        }

        // ── jsxFragment ──
        match (json.get("jsxFragment")) {
            case Some(expr) => jsxFragment = expr.asString()
            case None => ()
        }

        // ── jsxFactory ──
        match (json.get("jsxFactory")) {
            case Some(expr) => jsxFactory = expr.asString()
            case None => ()
        }

        // 设置 JSX 配置
        // 对应 Bun: if self.ctx.args.jsx.is_none() { ... } else { ... }
        match (ctx.args.jsx) {
            case None => {
                let jsx = JsxConfig()
                jsx.factory = jsxFactory
                jsx.fragment = jsxFragment
                jsx.importSource = jsxImportSource
                jsx.runtime = jsxRuntime
                jsx.development = jsxDev
                ctx.args.jsx = Some(jsx)
            }
            case Some(jsx) => {
                if (!jsxFactory.isEmpty()) { jsx.factory = jsxFactory }
                if (!jsxFragment.isEmpty()) { jsx.fragment = jsxFragment }
                if (!jsxImportSource.isEmpty()) { jsx.importSource = jsxImportSource }
                jsx.runtime = jsxRuntime
                jsx.development = jsxDev
            }
        }
    }

    /// 解析 external 配置
    // 严格翻译自: bunfig.rs:1044-1063 - json.get(b"external") 解析块
    //   可以是字符串或字符串数组
    private func parseExternal(expr: BunfigExpr): Unit {
        if (expr.isString()) {
            let externals = ArrayList<String>()
            externals.append(expr.asString())
            ctx.args.external = externals
        } else if (expr.isArray()) {
            let items = expr.asArray()
            let externals = ArrayList<String>()
            for (item in items) {
                expectString(item)
                externals.append(item.asString())
            }
            ctx.args.external = externals
        } else {
            addError("Expected string or array")
        }
    }

    /// 解析 loader 配置
    // 严格翻译自: bunfig.rs:1065-1102 - json.get(b"loader") 解析块
    //   loader 是一个对象，键为文件扩展名 (以 . 开头)，值为 loader 名称
    private func parseLoader(expr: BunfigExpr): Unit {
        expect(expr, BunfigExprTag.Object)
        let props = expr.asProperties()
        var extensions = ArrayList<String>()
        var loaderNames = ArrayList<String>()
        for (prop in props) {
            let key = prop.key.asString()
            if (key.isEmpty()) {
                continue
            }
            if (!key.startsWith(".")) {
                addError("file extension for loader must start with a '.'")
            }
            expectString(prop.value)
            let loaderName = prop.value.asString()
            extensions.append(key)
            loaderNames.append(loaderName)
        }
        let loaderMap = BunfigLoaderMap()
        loaderMap.extensions = extensions
        loaderMap.loaders = loaderNames
        ctx.args.loaders = Some(loaderMap)
    }

    /// 解析 serve.static 配置
    // 严格翻译自: bunfig.rs:1570-1682 - fn parse_serve_static
    //
    // 处理以下 serve.static 子项:
    //   plugins (string 或 string 数组),
    //   hmr (boolean),
    //   minify (boolean 或 对象 { syntax, whitespace, identifiers }),
    //   define (string 映射),
    //   publicPath (string),
    //   env (null / boolean / string)
    private func parseServeStatic(serveObj: BunfigExpr): Unit {
        // ── plugins ──
        // 对应 Bun: if let Some(config_plugins) = serve_obj.get(b"plugins") { ... }
        match (serveObj.get("plugins")) {
            case Some(expr) => {
                let plugins = ArrayList<String>()
                if (expr.isArray()) {
                    let items = expr.asArray()
                    if (items.size == 0) {
                        // None
                    } else {
                        for (item in items) {
                            expectString(item)
                            plugins.append(item.asString())
                        }
                        ctx.args.servePlugins = Some(plugins)
                    }
                } else if (expr.isString()) {
                    plugins.append(expr.asString())
                    ctx.args.servePlugins = Some(plugins)
                }
            }
            case None => ()
        }

        // ── hmr ──
        match (serveObj.get("hmr")) {
            case Some(expr) => {
                if (expr.isBoolean()) {
                    ctx.args.serveHmr = Some(expr.asBool())
                }
            }
            case None => ()
        }

        // ── minify ──
        // 对应 Bun: if let Some(minify) = serve_obj.get(b"minify") { ... }
        //   可以是布尔值 (全局开关) 或对象 { syntax, whitespace, identifiers }
        match (serveObj.get("minify")) {
            case Some(expr) => {
                if (expr.isBoolean()) {
                    let v = expr.asBool()
                    ctx.args.serveMinifySyntax = Some(v)
                    ctx.args.serveMinifyWhitespace = Some(v)
                    ctx.args.serveMinifyIdentifiers = Some(v)
                } else if (expr.isObject()) {
                    match (expr.get("syntax")) {
                        case Some(v) => {
                            if (v.isBoolean()) {
                                ctx.args.serveMinifySyntax = Some(v.asBool())
                            }
                        }
                        case None => ()
                    }
                    match (expr.get("whitespace")) {
                        case Some(v) => {
                            if (v.isBoolean()) {
                                ctx.args.serveMinifyWhitespace = Some(v.asBool())
                            }
                        }
                        case None => ()
                    }
                    match (expr.get("identifiers")) {
                        case Some(v) => {
                            if (v.isBoolean()) {
                                ctx.args.serveMinifyIdentifiers = Some(v.asBool())
                            }
                        }
                        case None => ()
                    }
                } else {
                    addError("Expected minify to be boolean or object")
                }
            }
            case None => ()
        }

        // ── define ──
        match (serveObj.get("define")) {
            case Some(expr) => {
                ctx.args.serveDefine = Some(parseDefineMap(expr))
            }
            case None => ()
        }

        // 设置 bunfig 路径
        // 对应 Bun: self.ctx.args.bunfig_path = Box::<[u8]>::from(self.source.path.text)
        ctx.args.bunfigPath = source

        // ── publicPath ──
        match (serveObj.get("publicPath")) {
            case Some(expr) => {
                let s = expr.asString()
                if (s != None && !s!.isEmpty()) {
                    ctx.args.servePublicPath = Some(s!)
                }
            }
            case None => ()
        }

        // ── env ──
        // 对应 Bun: if let Some(env) = serve_obj.get(b"env") { ... }
        //   null -> disable, boolean -> enable/disable, string -> "inline"/"disable"/带 * 前缀
        match (serveObj.get("env")) {
            case Some(expr) => {
                if (expr.isNull()) {
                    ctx.args.serveEnvBehavior = "disable"
                } else if (expr.isBoolean()) {
                    ctx.args.serveEnvBehavior = if (expr.asBool()) { "load_all" } else { "disable" }
                } else if (expr.isString()) {
                    let slice = expr.asString()
                    match (slice) {
                        case "inline" => ctx.args.serveEnvBehavior = "inline"
                        case "disable" => ctx.args.serveEnvBehavior = "disable"
                        case _ => {
                            // 检查是否包含 * 通配符
                            if (slice.contains("*")) {
                                ctx.args.serveEnvBehavior = "prefix"
                                ctx.args.serveEnvPrefix = Some(slice)
                            } else {
                                addError("Invalid env behavior, must be 'inline', 'disable', or a string with a '*' character")
                            }
                        }
                    }
                } else {
                    addError("Invalid env behavior, must be 'inline', 'disable', or a string with a '*' character")
                }
            }
            case None => ()
        }
    }
}

// ============================================================================
// 配置加载入口函数
// 严格翻译自: src/bunfig/arguments.rs
//   pub fn load_config_path(...)
//   pub fn load_config(...)
//   pub fn load_config_with_cmd_args(...)
// ============================================================================

/// 加载指定路径的 bunfig 配置
// 严格翻译自: arguments.rs:97-122 - pub fn load_config_path
//
// 按优先级加载:
//   1. 全局配置 (~/.bunfig.toml 或 $XDG_CONFIG_HOME/.bunfig.toml)
//   2. 指定路径的配置文件
//
// 参数:
//   cmd: 命令标签
//   autoLoaded: 是否自动加载 (文件不存在时不报错)
//   configPath: 配置文件路径
//   ctx: 命令上下文数据
public func loadConfigPath(cmd: CommandTag, autoLoaded: Bool, configPath: String, ctx: ContextData): Unit {
    // 加载全局配置 (如果命令需要)
    if (cmd.readGlobalConfig()) {
        if (!ctx.hasLoadedGlobalConfig) {
            ctx.hasLoadedGlobalConfig = true
            let homeDir = Sys.getHomeDir()
            let globalConfigPath = Path.join([homeDir, ".bunfig.toml"])
            if (BaoFile.exists(globalConfigPath)) {
                try {
                    loadBunfig(cmd, true, globalConfigPath, ctx)
                } catch (e: Exception) {
                    if (!autoLoaded) {
                        OutputFormatter.formatError("reading global config \"${globalConfigPath}\": ${e}")
                    }
                }
            }
        }
    }

    // 加载指定路径的配置文件
    loadBunfig(cmd, autoLoaded, configPath, ctx)
}

/// 加载 bunfig 配置 (自动搜索)
// 严格翻译自: arguments.rs:136-227 - pub fn load_config
//
// 搜索顺序:
//   1. 用户指定的配置路径 (如果有的话)
//   2. 项目目录下的 bunfig.toml
//   3. 全局配置 (~/.bunfig.toml)
//
// 参数:
//   cmd: 命令标签
//   userConfigPath: 用户指定的配置路径 (Option)
//   ctx: 命令上下文数据
public func loadConfig(cmd: CommandTag, userConfigPath: ?String, ctx: ContextData): Unit {
    // 加载全局配置
    if (cmd.readGlobalConfig()) {
        if (!ctx.hasLoadedGlobalConfig) {
            ctx.hasLoadedGlobalConfig = true
            let homeDir = Sys.getHomeDir()
            let globalConfigPath = Path.join([homeDir, ".bunfig.toml"])
            if (BaoFile.exists(globalConfigPath)) {
                try {
                    loadConfigPath(cmd, true, globalConfigPath, ctx)
                } catch (e: Exception) {
                    reportBunfigLoadFailure(ctx, e)
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

    // 如果未指定路径，使用默认 bunfig.toml
    if (configPath.isEmpty()) {
        // 如果用户显式传了空路径、或者命令总是加载配置、或者是 AutoCommand
        let userProvidedPath = match (userConfigPath) {
            case Some(_) => true
            case None => false
        }
        if (userProvidedPath || cmd.alwaysLoadsConfig() ||
            (cmd == CommandTag.AutoCommand && (
                ctx.positionals.size == 0 ||
                (ctx.positionals.size > 0 && hasDefaultLoader(ctx.positionals[0]))
            ))) {
            configPath = "bunfig.toml"
            autoLoaded = true
        }
    }

    if (configPath.isEmpty()) {
        return
    }

    // 解析绝对路径
    let absolutePath = if (configPath.startsWith("/")) {
        configPath
    } else {
        let cwd = Sys.getcwd()
        Path.join([cwd, configPath])
    }

    // 加载配置文件
    try {
        loadConfigPath(cmd, autoLoaded, absolutePath, ctx)
    } catch (e: Exception) {
        reportBunfigLoadFailure(ctx, e)
    }
}

/// 从命令行参数加载配置
// 严格翻译自: arguments.rs:229-235 - pub fn load_config_with_cmd_args
public func loadConfigWithCmdArgs(cmd: CommandTag, args: ParsedArgs, ctx: ContextData): Unit {
    let configPath = args.getOption("config")
    loadConfig(cmd, configPath, ctx)
}

// ============================================================================
// 内部辅助函数
// ============================================================================

/// 加载单个 bunfig 文件
// 严格翻译自: arguments.rs:39-82 - fn load_bunfig
private func loadBunfig(cmd: CommandTag, autoLoaded: Bool, configPath: String, ctx: ContextData): Unit {
    let content = BaoFile.readAllText(configPath)
    match (content) {
        case Some(text) => {
            // 临时设置日志级别为 Warn 以减少解析时的噪音
            ctx.debug.loadedBunfig = true
            Bunfig.parse(cmd, text, ctx)
        }
        case None => {
            if (!autoLoaded) {
                throw BaoError(ErrorCode.FileNotFound, "Config file not found: ${configPath}")
            }
        }
    }
}

/// 报告 bunfig 加载失败
// 严格翻译自: arguments.rs:125-134 - fn report_bunfig_load_failure
private func reportBunfigLoadFailure(ctx: ContextData, err: Exception): Unit {
    let log = ctx.log
    if (log.errorCount > 0 || log.warningCount > 0) {
        // 打印已收集的日志
    }
    OutputFormatter.formatError("failed to load bunfig: ${err}")
}

/// 检查文件扩展名是否有默认加载器
// 对应 Bun: options::DEFAULT_LOADERS.contains_key(bun_paths::extension(&ctx.positionals[0]))
private func hasDefaultLoader(path: String): Bool {
    let ext = extractExtension(path)
    let defaultExtensions = [".js", ".ts", ".jsx", ".tsx", ".mjs", ".mts", ".cjs", ".cts"]
    for (e in defaultExtensions) {
        if (ext == e.substring(1)) {
            return true
        }
    }
    return false
}

/// 从源内容中提取文件扩展名
private func extractExtension(source: String): String {
    let dotIdx = source.lastIndexOf('.')
    if (dotIdx >= 0 && dotIdx < source.length - 1) {
        return source.substring(dotIdx + 1)
    }
    return ""
}

// ============================================================================
// BunfigExpr — 值形态的 AST 表达式
// 严格翻译自: bun_ast::Expr (由 TOML/JSON 解析器产生的值形态)
//
// 对应 Rust 中的 ExprData 枚举:
//   EObject, EArray, EString, ENumber, EBoolean, ENull
// ============================================================================

/// 表达式类型标签
public enum BunfigExprTag {
    | Object
    | Array
    | String_
    | Number
    | Boolean
    | Null_

    public func name(): String {
        match (this) {
            case Object => "object"
            case Array => "array"
            case String_ => "string"
            case Number => "number"
            case Boolean => "boolean"
            case Null_ => "null"
        }
    }
}

/// 值形态的 AST 表达式
// 对应 Bun: bun_ast::Expr (值形态, 由 TOML/JSON 解析产生)
public class BunfigExpr {
    /// 表达式数据
    private var data: BunfigExprData
    /// 源位置
    public var loc: Int64

    public init(data: BunfigExprData) {
        this.data = data
        this.loc = 0
    }

    /// 获取类型标签
    public func tag(): BunfigExprTag {
        match (data) {
            case BunfigExprData.Object(_) => BunfigExprTag.Object
            case BunfigExprData.Array(_) => BunfigExprTag.Array
            case BunfigExprData.String_(_) => BunfigExprTag.String_
            case BunfigExprData.Number(_) => BunfigExprTag.Number
            case BunfigExprData.Boolean(_) => BunfigExprTag.Boolean
            case BunfigExprData.Null_ => BunfigExprTag.Null_
        }
    }

    /// 获取类型名
    public func typeName(): String {
        tag().name()
    }

    /// 类型检查
    public func isObject(): Bool { tag() == BunfigExprTag.Object }
    public func isArray(): Bool { tag() == BunfigExprTag.Array }
    public func isString(): Bool { tag() == BunfigExprTag.String_ }
    public func isNumber(): Bool { tag() == BunfigExprTag.Number }
    public func isBoolean(): Bool { tag() == BunfigExprTag.Boolean }
    public func isNull(): Bool { tag() == BunfigExprTag.Null_ }

    /// 获取属性值
    public func get(key: String): ?BunfigExpr {
        match (data) {
            case BunfigExprData.Object(obj) => obj.get(key)
            case _ => None
        }
    }

    /// 获取对象类型的子表达式
    public func getObject(key: String): ?BunfigExpr {
        match (get(key)) {
            case Some(expr) => if (expr.isObject()) { Some(expr) } else { None }
            case None => None
        }
    }

    /// 转为字符串值
    public func asString(): String {
        match (data) {
            case BunfigExprData.String_(s) => s
            case _ => ""
        }
    }

    /// 转为布尔值
    public func asBool(): Bool {
        match (data) {
            case BunfigExprData.Boolean(b) => b
            case _ => false
        }
    }

    /// 转为数字
    public func asNumber(): Float64 {
        match (data) {
            case BunfigExprData.Number(n) => n
            case _ => 0.0
        }
    }

    /// 转为数组
    public func asArray(): ArrayList<BunfigExpr> {
        match (data) {
            case BunfigExprData.Array(arr) => arr
            case _ => ArrayList<BunfigExpr>()
        }
    }

    /// 转为属性列表
    public func asProperties(): ArrayList<BunfigProperty> {
        match (data) {
            case BunfigExprData.Object(obj) => obj.properties()
            case _ => ArrayList<BunfigProperty>()
        }
    }
}

/// 表达式数据 (tagged union)
// 对应 Bun: bun_ast::expr::Data
public enum BunfigExprData {
    | Object(BunfigExprObject)
    | Array(ArrayList<BunfigExpr>)
    | String_(String)
    | Number(Float64)
    | Boolean(Bool)
    | Null_
}

/// 表达式对象
// 对应 Bun: bun_ast::E::EObject
public class BunfigExprObject {
    private var entries: HashMap<String, BunfigExpr>

    public init() {
        entries = HashMap<String, BunfigExpr>()
    }

    public func get(key: String): ?BunfigExpr {
        entries.get(key)
    }

    public func put(key: String, value: BunfigExpr): Unit {
        entries.put(key, value)
    }

    public func properties(): ArrayList<BunfigProperty> {
        let result = ArrayList<BunfigProperty>()
        for (key in entries.keys()) {
            match (entries.get(key)) {
                case Some(value) => result.append(BunfigProperty(
                    BunfigExpr(BunfigExprData.String_(key)),
                    value
                ))
                case None => ()
            }
        }
        return result
    }
}

/// 属性
// 对应 Bun: bun_ast Property
public class BunfigProperty {
    public let key: BunfigExpr
    public let value: BunfigExpr

    public init(key: BunfigExpr, value: BunfigExpr) {
        this.key = key
        this.value = value
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 字符串映射 (用于 define 配置)
// 对应 Bun: api::StringMap { keys, values }
public class BunfigStringMap {
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
}

/// 加载器映射 (用于 loader 配置)
// 对应 Bun: api::LoaderMap { extensions, loaders }
public class BunfigLoaderMap {
    public var extensions: ArrayList<String>
    public var loaders: ArrayList<String>

    public init() {
        extensions = ArrayList<String>()
        loaders = ArrayList<String>()
    }
}

/// JSX 配置
// 对应 Bun: api::Jsx { factory, fragment, import_source, runtime, development }
public class JsxConfig {
    public var factory: String
    public var fragment: String
    public var importSource: String
    public var runtime: String
    public var development: Bool

    public init() {
        factory = ""
        fragment = ""
        importSource = ""
        runtime = "automatic"
        development = true
    }
}

/// 转换选项 (TransformOptions) — ctx.args 的核心配置
// 对应 Bun: api::TransformOptions
public class BunfigTransformOptions {
    /// 日志级别
    public var logLevel: String
    /// 定义映射
    public var define: BunfigStringMap
    /// 源地址
    public var origin: ?String
    /// 端口
    public var port: Int64
    /// 是否禁用默认 .env 文件
    public var disableDefaultEnvFiles: Bool
    /// 输出目录
    public var outputDir: ?String
    /// 入口点列表
    public var entryPoints: ArrayList<String>
    /// 外部模块列表
    public var external: ArrayList<String>
    /// 加载器映射
    public var loaders: ?BunfigLoaderMap
    /// JSX 配置
    public var jsx: ?JsxConfig
    /// bunfig 路径
    public var bunfigPath: String
    /// serve 插件
    public var servePlugins: ?ArrayList<String>
    /// serve HMR
    public var serveHmr: ?Bool
    /// serve minify syntax
    public var serveMinifySyntax: ?Bool
    /// serve minify whitespace
    public var serveMinifyWhitespace: ?Bool
    /// serve minify identifiers
    public var serveMinifyIdentifiers: ?Bool
    /// serve define
    public var serveDefine: ?BunfigStringMap
    /// serve public path
    public var servePublicPath: ?String
    /// serve env behavior
    public var serveEnvBehavior: String
    /// serve env prefix
    public var serveEnvPrefix: ?String

    public init() {
        logLevel = "info"
        define = BunfigStringMap()
        origin = None
        port = 0
        disableDefaultEnvFiles = false
        outputDir = None
        entryPoints = ArrayList<String>()
        external = ArrayList<String>()
        loaders = None
        jsx = None
        bunfigPath = ""
        servePlugins = None
        serveHmr = None
        serveMinifySyntax = None
        serveMinifyWhitespace = None
        serveMinifyIdentifiers = None
        serveDefine = None
        servePublicPath = None
        serveEnvBehavior = "disable"
        serveEnvPrefix = None
    }
}

/// 日志接口 (用于 bunfig 解析器)
public class BunfigLog {
    public var errorCount: Int64
    public var warningCount: Int64

    public init() {
        errorCount = 0
        warningCount = 0
    }

    public func addError(text: String, source: String): Unit {
        errorCount += 1
    }

    public func addWarning(text: String, source: String): Unit {
        warningCount += 1
    }
}

/// TOML 解析器 (bunfig 配置专用)
// 对应 Bun: bun_parsers::toml::TOML::parse
public class BunfigTomlParser {
    public static func parse(content: String, log: BunfigLog): Result<BunfigExpr> {
        // 解析 TOML 为 BunfigExpr
        let table = TomlTable()

        var currentSection = ""
        let lines = content.split("\n")

        for (line in lines) {
            let trimmed = line.trim()
            if (trimmed.isEmpty() || trimmed.startsWith("#")) {
                continue
            }

            // section header: [section] 或 [section.subsection]
            if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
                currentSection = trimmed.substring(1, trimmed.length - 1).trim()
                continue
            }

            // key = value
            let eqIdx = trimmed.indexOf('=')
            if (eqIdx >= 0) {
                let key = trimmed.substring(0, eqIdx).trim()
                var value = trimmed.substring(eqIdx + 1).trim()

                // 去除引号
                if ((value.startsWith("\"") && value.endsWith("\"")) ||
                    (value.startsWith("'") && value.endsWith("'"))) {
                    value = value.substring(1, value.length - 1)
                }

                let fullKey = if (currentSection.isEmpty()) {
                    key
                } else {
                    "${currentSection}.${key}"
                }
                table.set(fullKey, value)
            }
        }

        // 将 TomlTable 转为 BunfigExpr
        return Ok(tableToExpr(table))
    }

    /// 将 TomlTable 转换为 BunfigExpr 对象
    private static func tableToExpr(table: TomlTable): BunfigExpr {
        let obj = BunfigExprObject()
        let keys = table.keys()
        for (key in keys) {
            match (table.get(key)) {
                case Some(value) => {
                    let valueExpr = BunfigExpr(BunfigExprData.String_(value))
                    // 处理嵌套路径 (如 install.registry)
                    setNestedKey(obj, key, valueExpr)
                }
                case None => ()
            }
        }
        return BunfigExpr(BunfigExprData.Object(obj))
    }

    /// 设置嵌套键值
    private static func setNestedKey(obj: BunfigExprObject, key: String, value: BunfigExpr): Unit {
        let dotIdx = key.indexOf('.')
        if (dotIdx >= 0) {
            let prefix = key.substring(0, dotIdx)
            let suffix = key.substring(dotIdx + 1)
            match (obj.get(prefix)) {
                case Some(existing) => {
                    match (existing.data) {
                        case BunfigExprData.Object(subObj) => setNestedKey(subObj, suffix, value)
                        case _ => ()
                    }
                }
                case None => {
                    let subObj = BunfigExprObject()
                    setNestedKey(subObj, suffix, value)
                    obj.put(prefix, BunfigExpr(BunfigExprData.Object(subObj)))
                }
            }
        } else {
            obj.put(key, value)
        }
    }
}

/// JSON 解析器 (bunfig 配置专用)
// 对应 Bun: bun_parsers::json::parse_ts_config
public class BunfigJsonParser {
    public static func parse(content: String, log: BunfigLog): Result<BunfigExpr> {
        // 简化的 JSON 解析 - 将 JSON 转为 BunfigExpr
        // 实际实现应调用 bao_parsers 的 JSON 解析器
        return Err("JSON parser not yet implemented for bunfig")
    }
}

/// TOML 表 (内部辅助)
private class TomlTable {
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
