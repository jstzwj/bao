// Bunfig — bunfig.toml config file parser
// Strict port of: src/bunfig/bunfig.rs
//
// Original Rust module comment:
//   Port of `src/runtime/cli/bunfig.zig`.
//   `Bunfig::parse` and the inner `Parser` route through the real
//   `bun_parsers::{toml,json}` parsers (which produce the value-shaped
//   `bun_ast::Expr` tree) and write into `ctx.args`
//   (`api::TransformOptions`), `ctx.install` (`api::BunInstall`), and the rest
//   of `ContextData`.
package bao_bunfig

import std.collection.*
import bao_core.*

// ============================================================================
// Re-exports — corresponds to Bun:
//   pub use bun_options_types::offline_mode::OfflineMode;
// ============================================================================

// ============================================================================
// Bunfig — corresponds to Bun: pub struct Bunfig;
// TODO: replace api.TransformOptions with Bunfig
// ============================================================================

public class Bunfig {
    /// Parse a bunfig config source.
    // Corresponds to Bun: pub fn parse(cmd, source, ctx) -> Result<(), Error>
    //
    // Steps:
    //   1. Get the log and record current error/warning count
    //   2. Determine if the source is TOML or JSON by file extension
    //   3. Parse the source with the appropriate parser
    //   4. Create a Parser and parse the expression tree
    public static func parse(
        cmd: CommandTag,
        source: Source,
        ctx: ContextData
    ): Result<Unit, BaoError> {
        let log = ctx.log
        let logCount = log.errors + log.warnings

        // Determine file type by extension
        // Corresponds to Bun: let is_toml = ext.len() > 1 && &ext[1..] == b"toml"
        let ext = source.path.name.ext
        let isToml = ext.size > 1 && ext[1..] == "toml"

        var expr: Expr
        if (isToml) {
            match (TOML.parse(source, log, true)) {
                case Ok(e) =>
                    expr = e
                case Err(e) =>
                    if (log.errors + log.warnings == logCount) {
                        log.addErrorOpts(
                            "Failed to parse",
                            Some(source),
                            0,
                            true
                        )
                    }
                    return Err(e)
            }
        } else {
            match (json_parser.parseTsConfig(source, log)) {
                case Ok(e) =>
                    expr = e
                case Err(e) =>
                    if (log.errors + log.warnings == logCount) {
                        log.addErrorOpts(
                            "Failed to parse",
                            Some(source),
                            0,
                            true
                        )
                    }
                    return Err(e)
            }
        }

        // PORT NOTE: reshaped for borrowck — Zig stored both `&mut ctx` and
        // `&mut ctx.args` simultaneously inside Parser. In Cangjie we route
        // bunfig writes through `self.ctx.args` directly. `log` is derived from
        // the copied raw pointer above so it does not overlap the `&mut ctx` borrow.
        let parser = Parser(expr, source, ctx)
        return parser.parse(cmd)
    }
}

// ============================================================================
// Parser — corresponds to Bun: pub struct Parser<'a>
// ============================================================================

public class Parser {
    private var json: Expr
    private var source: Source
    // PORT NOTE: Zig held both `bunfig: *api.TransformOptions` (= `&ctx.args`)
    // and `ctx: *Command.Context` simultaneously. In Cangjie, `bunfig` writes
    // route through `self.ctx` directly.
    private var ctx: ContextData

    public init(json: Expr, source: Source, ctx: ContextData) {
        this.json = json
        this.source = source
        this.ctx = ctx
    }

    // ========================================================================
    // Error helpers — corresponds to Bun: Parser::add_error, add_error_format
    // ========================================================================

    /// Add an error at the given location.
    // Corresponds to Bun: fn add_error(&mut self, loc, text) -> Result<(), Error>
    public func addError(loc: Int64, text: String): Result<Unit, BaoError> {
        ctx.log.addErrorOpts(text, Some(source), loc, true)
        return Err(BaoError(ErrorCode.InvalidBunfig, "Invalid Bunfig"))
    }

    /// Add a formatted error at the given location.
    // Corresponds to Bun: fn add_error_format(&mut self, loc, args) -> Result<(), Error>
    public func addErrorFormat(loc: Int64, text: String): Result<Unit, BaoError> {
        ctx.log.addErrorFmtOpts(text, Some(source), loc, true)
        return Err(BaoError(ErrorCode.InvalidBunfig, "Invalid Bunfig"))
    }

    // ========================================================================
    // Type expectation helpers — corresponds to Bun: Parser::expect_string, expect
    // ========================================================================

    /// Expect the expression to be a string type.
    // Corresponds to Bun: pub fn expect_string(&mut self, expr) -> Result<(), Error>
    public func expectString(expr: Expr): Result<Unit, BaoError> {
        match (expr.data) {
            case ExprData.String_(_) =>
                return Ok(())
            case _ =>
                return addErrorFormat(
                    expr.loc,
                    "expected string but received ${expr.dataTagName()}"
                )
        }
    }

    /// Expect the expression to match a specific tag.
    // Corresponds to Bun: pub fn expect(&mut self, expr, token) -> Result<(), Error>
    public func expect(expr: Expr, token: ExprTag): Result<Unit, BaoError> {
        if (expr.dataTag() != token) {
            return addErrorFormat(
                expr.loc,
                "expected ${token.name()} but received ${expr.dataTagName()}"
            )
        }
        return Ok(())
    }

    // ========================================================================
    // Parse entry point — corresponds to Bun: Parser::parse(&mut self, cmd)
    // ========================================================================

    /// Parse the bunfig expression tree for the given command.
    // Corresponds to Bun: pub fn parse(&mut self, cmd: CommandTag) -> Result<(), Error>
    //
    // PORT NOTE: `comptime cmd: Command.Tag` demoted to a runtime arg —
    // the Zig original monomorphised over `cmd` purely to dead-code-eliminate
    // untaken arms; the runtime branches below are equivalent.
    public func parse(cmd: CommandTag): Result<Unit, BaoError> {
        // Corresponds to Bun: bun_analytics::features::bunfig.fetch_add(1, Ordering::Relaxed)
        // Analytics.trackBunfig()

        let json = this.json

        // Root must be an object
        if (!json.isObject()) {
            let r = addError(json.loc, "bunfig expects an object { } at the root")
            if (r.isErr()) { return r }
        }

        // ── logLevel ─────────────────────────────────────────────────────────
        if (let Some(expr) <- json.get("logLevel")) {
            let r = loadLogLevel(expr)
            if (r.isErr()) { return r }
        }

        // ── define ───────────────────────────────────────────────────────────
        if (let Some(expr) <- json.get("define")) {
            let r = parseDefineMap(expr)
            match (r) {
                case Ok(map) => ctx.args.define = map
                case Err(e) => return Err(e)
            }
        }

        // ── origin ───────────────────────────────────────────────────────────
        if (let Some(expr) <- json.get("origin")) {
            let r = expectString(expr)
            if (r.isErr()) { return r }
            match (expr.data) {
                case ExprData.String_(s) =>
                    ctx.args.origin = s
                case _ => ()
            }
        }

        // ── env ──────────────────────────────────────────────────────────────
        if (let Some(envExpr) <- json.get("env")) {
            let r = loadEnvConfig(envExpr)
            if (r.isErr()) { return r }
        }

        // ── RunCommand / AutoCommand specific ────────────────────────────────
        if (cmd == CommandTag.RunCommand || cmd == CommandTag.AutoCommand) {
            // serve.port
            if (let Some(serveExpr) <- json.get("serve")) {
                if (let Some(port) <- serveExpr.get("port")) {
                    let r = expect(port, ExprTag.Number)
                    if (r.isErr()) { return r }
                    let p = port.asNumber().getOrThrow()
                    let portValue: UInt16 = if (p == 0.0) { UInt16(3000) } else { UInt16(p) }
                    ctx.args.port = portValue
                }
            }

            // preload
            if (let Some(expr) <- json.get("preload")) {
                let r = loadPreload(expr)
                if (r.isErr()) { return r }
            }

            // telemetry
            if (let Some(expr) <- json.get("telemetry")) {
                let r = expect(expr, ExprTag.Boolean)
                if (r.isErr()) { return r }
                // Corresponds to Bun: bun_analytics::set_enabled(...)
                // Analytics.setEnabled(expr.asBool().getOrThrow())
            }
        }

        // smol
        if (cmd == CommandTag.RunCommand || cmd == CommandTag.AutoCommand) {
            if (let Some(expr) <- json.get("smol")) {
                let r = expect(expr, ExprTag.Boolean)
                if (r.isErr()) { return r }
                ctx.runtimeOptions.smol = expr.asBool().getOrThrow()
            }
        }

        // ── TestCommand specific ─────────────────────────────────────────────
        if (cmd == CommandTag.TestCommand) {
            if (let Some(testExpr) <- json.get("test")) {
                let r = parseTestSection(testExpr)
                if (r.isErr()) { return r }
            }
        }

        // ── npm-related / Run / Auto / Test ──────────────────────────────────
        if (cmd.isNpmRelated()
            || cmd == CommandTag.RunCommand
            || cmd == CommandTag.AutoCommand
            || cmd == CommandTag.TestCommand
        ) {
            // install
            if (let Some(installObj) <- json.getObject("install")) {
                // Ensure ctx.install is allocated
                if (ctx.install.isNone()) {
                    ctx.install = BunInstall()
                }

                // auto install setting
                if (let Some(autoInstallExpr) <- installObj.get("auto")) {
                    match (autoInstallExpr.data) {
                        case ExprData.String_(s) =>
                            let key = s
                            match (GlobalCache.MAP(key)) {
                                case Some(v) =>
                                    ctx.debug.globalCache = v
                                case None =>
                                    let r = addError(
                                        autoInstallExpr.loc,
                                        "Invalid auto install setting, must be one of true, false, or \"force\" \"fallback\" \"disable\""
                                    )
                                    if (r.isErr()) { return r }
                                    return Ok(())
                            }
                        case ExprData.Boolean(b) =>
                            ctx.debug.globalCache = if (b) {
                                GlobalCache.ALLOW_INSTALL
                            } else {
                                GlobalCache.DISABLE
                            }
                        case _ =>
                            let r = addError(
                                autoInstallExpr.loc,
                                "Invalid auto install setting, must be one of true, false, or \"force\" \"fallback\" \"disable\""
                            )
                            if (r.isErr()) { return r }
                            return Ok(())
                    }
                }

                // prefer (offline mode)
                if (let Some(preferExpr) <- installObj.get("prefer")) {
                    let r = expectString(preferExpr)
                    if (r.isErr()) { return r }
                    let key = preferExpr.asString()
                    match (OfflineModePREFER.get(key)) {
                        case Some(setting) =>
                            ctx.debug.offlineModeSetting = setting
                        case None =>
                            let r = addError(
                                preferExpr.loc,
                                "Invalid prefer setting, must be one of online or offline"
                            )
                            if (r.isErr()) { return r }
                    }
                }

                // install.logLevel
                if (let Some(expr) <- installObj.get("logLevel")) {
                    let r = loadLogLevel(expr)
                    if (r.isErr()) { return r }
                }

                // Parse remaining install fields
                let r = parseInstall(installObj)
                if (r.isErr()) { return r }
            }

            // run
            if (let Some(runExpr) <- json.get("run")) {
                let r = parseRunConfig(runExpr)
                if (r.isErr()) { return r }
            }

            // console
            if (let Some(consoleExpr) <- json.get("console")) {
                let r = parseConsoleConfig(consoleExpr)
                if (r.isErr()) { return r }
            }
        }

        // ── serve.static ────────────────────────────────────────────────────
        if (let Some(serveObj2) <- json.getObject("serve")) {
            if (let Some(serveObj) <- serveObj2.getObject("static")) {
                let r = parseServeStatic(serveObj)
                if (r.isErr()) { return r }
            }
        }

        // ── bundle ──────────────────────────────────────────────────────────
        if (let Some(bunExpr) <- json.get("bundle")) {
            let r = parseBundleConfig(cmd, bunExpr)
            if (r.isErr()) { return r }
        }

        // ── jsx ─────────────────────────────────────────────────────────────
        let r = parseJsxConfig(json)
        if (r.isErr()) { return r }

        // ── debug ───────────────────────────────────────────────────────────
        if (let Some(debugExpr) <- json.get("debug")) {
            if (let Some(editor) <- debugExpr.get("editor")) {
                ctx.debug.editor = editor.asString()
            }
        }

        // ── macros ──────────────────────────────────────────────────────────
        if (let Some(expr) <- json.get("macros")) {
            match (expr.data) {
                case ExprData.Boolean(b) =>
                    if (!b) {
                        ctx.debug.macros = MacroOptions.Disable
                    }
                case _ =>
                    ctx.debug.macros = MacroOptions.Map(
                        parseMacrosJson(expr, ctx.log, source)
                    )
            }
            // Corresponds to Bun: bun_analytics::features::macros.fetch_add(1, Ordering::Relaxed)
            // Analytics.trackMacros()
        }

        // ── external ────────────────────────────────────────────────────────
        if (let Some(expr) <- json.get("external")) {
            let r = parseExternal(expr)
            if (r.isErr()) { return r }
        }

        // ── loader ──────────────────────────────────────────────────────────
        if (let Some(expr) <- json.get("loader")) {
            let r = parseLoader(expr)
            if (r.isErr()) { return r }
        }

        return Ok(())
    }

    // ========================================================================
    // loadLogLevel — corresponds to Bun: Parser::load_log_level
    // ========================================================================

    /// Load the log level setting.
    // Corresponds to Bun: fn load_log_level(&mut self, expr) -> Result<(), Error>
    private func loadLogLevel(expr: Expr): Result<Unit, BaoError> {
        let r = expectString(expr)
        if (r.isErr()) { return r }
        // PERF(port): Zig used strings.ExactSizeMatcher(8)
        let level = expr.asString()
        match (level) {
            case "debug" => ctx.args.logLevel = MessageLevel.Debug
            case "error" => ctx.args.logLevel = MessageLevel.Err
            case "warn"  => ctx.args.logLevel = MessageLevel.Warn
            case "info"  => ctx.args.logLevel = MessageLevel.Info
            case _ =>
                return addError(
                    expr.loc,
                    "Invalid log level, must be one of debug, error, or warn"
                )
        }
        return Ok(())
    }

    // ========================================================================
    // loadPreload — corresponds to Bun: Parser::load_preload
    // ========================================================================

    /// Load the preload setting.
    // Corresponds to Bun: fn load_preload(&mut self, expr) -> Result<(), Error>
    private func loadPreload(expr: Expr): Result<Unit, BaoError> {
        match (expr.data) {
            case ExprData.Array(array) =>
                var preloads = ArrayList<String>()
                preloads.reserve(array.size)
                for (item in array) {
                    let r = expectString(item)
                    if (r.isErr()) { return r }
                    match (item.data) {
                        case ExprData.String_(s) =>
                            if (!s.isEmpty()) {
                                // PERF(port): was appendAssumeCapacity
                                preloads.add(s)
                            }
                        case _ => ()
                    }
                }
                ctx.debug.preloads = preloads
            case ExprData.String_(s) =>
                if (!s.isEmpty()) {
                    var preloads = ArrayList<String>()
                    preloads.add(s)
                    ctx.debug.preloads = preloads
                }
            case ExprData.Null_ =>
                () // null -> no preloads
            case _ =>
                return addError(expr.loc, "Expected preload to be an array")
        }
        return Ok(())
    }

    // ========================================================================
    // loadEnvConfig — corresponds to Bun: Parser::load_env_config
    // ========================================================================

    /// Load the env configuration.
    // Corresponds to Bun: fn load_env_config(&mut self, expr) -> Result<(), Error>
    private func loadEnvConfig(expr: Expr): Result<Unit, BaoError> {
        match (expr.data) {
            case ExprData.Null_ =>
                // env = null -> disable default .env files
                ctx.args.disableDefaultEnvFiles = true
            case ExprData.Boolean(boolean) =>
                if (!boolean) {
                    ctx.args.disableDefaultEnvFiles = true
                }
            case ExprData.Object(obj) =>
                if (let Some(fileExpr) <- obj.get("file")) {
                    match (fileExpr.data) {
                        case ExprData.Null_ =>
                            ctx.args.disableDefaultEnvFiles = true
                        case ExprData.Boolean(b) =>
                            if (!b) {
                                ctx.args.disableDefaultEnvFiles = true
                            }
                        case _ =>
                            return addError(
                                fileExpr.loc,
                                "Expected 'file' to be a boolean or null"
                            )
                    }
                }
            case _ =>
                return addError(
                    expr.loc,
                    "Expected 'env' to be a boolean, null, or an object"
                )
        }
        return Ok(())
    }

    // ========================================================================
    // parseDefineMap — corresponds to Bun: Parser::parse_define_map
    // ========================================================================

    /// Parse the define map.
    // Corresponds to Bun: fn parse_define_map(&mut self, expr) -> Result<StringMap, Error>
    private func parseDefineMap(expr: Expr): Result<StringMap, BaoError> {
        let r = expect(expr, ExprTag.Object)
        if (r.isErr()) { return Err(r.asErr().getOrThrow()) }
        let obj = expr.data.eObject().getOrThrow()
        let properties = obj.properties()
        var keys = ArrayList<String>()
        var values = ArrayList<String>()
        // Count valid entries first for pre-allocation
        var validCount = 0
        for (property in properties) {
            match (property.value.data) {
                case ExprData.String_(_) => validCount++
                case _ => ()
            }
        }
        keys.reserve(validCount)
        values.reserve(validCount)
        for (property in properties) {
            let v = property.value
            let k = property.key
            match (v.data) {
                case ExprData.String_(sv) =>
                    match (k.data) {
                        case ExprData.String_(sk) =>
                            keys.add(sk)
                            values.add(sv)
                        case _ => ()
                    }
                case _ => ()
            }
        }
        return Ok(StringMap(keys, values))
    }

    // ========================================================================
    // parseTestSection — corresponds to Bun: Parser::parse (TestCommand branch)
    // ========================================================================

    /// Parse the test section of bunfig.
    // Corresponds to Bun: the TestCommand branch in Parser::parse
    private func parseTestSection(testExpr: Expr): Result<Unit, BaoError> {
        // test.root
        if (let Some(root) <- testExpr.get("root")) {
            ctx.debug.testDirectory = root.asString()
        }

        // test.preload
        if (let Some(expr) <- testExpr.get("preload")) {
            let r = loadPreload(expr)
            if (r.isErr()) { return r }
        }

        // test.smol
        if (let Some(expr) <- testExpr.get("smol")) {
            let r = expect(expr, ExprTag.Boolean)
            if (r.isErr()) { return r }
            ctx.runtimeOptions.smol = expr.asBool().getOrThrow()
        }

        // test.coverage
        if (let Some(expr) <- testExpr.get("coverage")) {
            let r = expect(expr, ExprTag.Boolean)
            if (r.isErr()) { return r }
            ctx.testOptions.coverage.enabled = expr.asBool().getOrThrow()
        }

        // test.onlyFailures
        if (let Some(expr) <- testExpr.get("onlyFailures")) {
            let r = expect(expr, ExprTag.Boolean)
            if (r.isErr()) { return r }
            ctx.testOptions.reporters.onlyFailures = expr.asBool().getOrThrow()
        }

        // test.reporter
        if (let Some(expr) <- testExpr.get("reporter")) {
            let r = expect(expr, ExprTag.Object)
            if (r.isErr()) { return r }
            // reporter.junit
            if (let Some(junitExpr) <- expr.get("junit")) {
                let r = expectString(junitExpr)
                if (r.isErr()) { return r }
                match (junitExpr.data) {
                    case ExprData.String_(s) =>
                        if (!s.isEmpty()) {
                            ctx.testOptions.reporters.junit = true
                            ctx.testOptions.reporters.reporterOutfile = s
                        }
                    case _ => ()
                }
            }
            // reporter.dots / reporter.dot
            let dotsExpr = if (let Some(d) <- expr.get("dots")) {
                Some(d)
            } else {
                expr.get("dot")
            }
            if (dotsExpr.isSome()) {
                let r = expect(dotsExpr.getOrThrow(), ExprTag.Boolean)
                if (r.isErr()) { return r }
                ctx.testOptions.reporters.dots = dotsExpr.getOrThrow().asBool().getOrThrow()
            }
        }

        // test.coverageReporter
        if (let Some(expr) <- testExpr.get("coverageReporter")) {
            ctx.testOptions.coverage.reporters = CoverageReporters(false, false)
            match (expr.data) {
                case ExprData.String_(_) =>
                    let r = applyCoverageReporterItem(expr)
                    if (r.isErr()) { return r }
                case _ =>
                    let r = expect(expr, ExprTag.Array)
                    if (r.isErr()) { return r }
                    let arr = expr.data.eArray().getOrThrow()
                    for (item in arr) {
                        let r = expectString(item)
                        if (r.isErr()) { return r }
                        let r2 = applyCoverageReporterItem(item)
                        if (r2.isErr()) { return r2 }
                    }
            }
        }

        // test.coverageDir
        if (let Some(expr) <- testExpr.get("coverageDir")) {
            let r = expectString(expr)
            if (r.isErr()) { return r }
            ctx.testOptions.coverage.reportsDirectory = expr.asString()
        }

        // test.coverageThreshold
        if (let Some(expr) <- testExpr.get("coverageThreshold")) {
            match (expr.data) {
                case ExprData.Number(n) =>
                    ctx.testOptions.coverage.fractions.functions = n
                    ctx.testOptions.coverage.fractions.lines = n
                    ctx.testOptions.coverage.fractions.stmts = n
                    ctx.testOptions.coverage.failOnLowCoverage = true
                case _ =>
                    let r = expect(expr, ExprTag.Object)
                    if (r.isErr()) { return r }
                    // functions
                    if (let Some(functions) <- expr.get("functions")) {
                        let r = expect(functions, ExprTag.Number)
                        if (r.isErr()) { return r }
                        ctx.testOptions.coverage.fractions.functions = functions.asNumber().getOrThrow()
                        ctx.testOptions.coverage.failOnLowCoverage = true
                    }
                    // lines
                    if (let Some(lines) <- expr.get("lines")) {
                        let r = expect(lines, ExprTag.Number)
                        if (r.isErr()) { return r }
                        ctx.testOptions.coverage.fractions.lines = lines.asNumber().getOrThrow()
                        ctx.testOptions.coverage.failOnLowCoverage = true
                    }
                    // statements
                    if (let Some(stmts) <- expr.get("statements")) {
                        let r = expect(stmts, ExprTag.Number)
                        if (r.isErr()) { return r }
                        ctx.testOptions.coverage.fractions.stmts = stmts.asNumber().getOrThrow()
                        ctx.testOptions.coverage.failOnLowCoverage = true
                    }
            }
        }

        // test.coverageIgnoreSourcemaps
        if (let Some(expr) <- testExpr.get("coverageIgnoreSourcemaps")) {
            let r = expect(expr, ExprTag.Boolean)
            if (r.isErr()) { return r }
            ctx.testOptions.coverage.ignoreSourcemap = expr.asBool().getOrThrow()
        }

        // test.coverageSkipTestFiles
        if (let Some(expr) <- testExpr.get("coverageSkipTestFiles")) {
            let r = expect(expr, ExprTag.Boolean)
            if (r.isErr()) { return r }
            ctx.testOptions.coverage.skipTestFiles = expr.asBool().getOrThrow()
        }

        // test.randomize and test.seed
        var randomizeFromConfig: ?Bool = None

        if (let Some(expr) <- testExpr.get("randomize")) {
            let r = expect(expr, ExprTag.Boolean)
            if (r.isErr()) { return r }
            randomizeFromConfig = expr.asBool()
            ctx.testOptions.randomize = expr.asBool().getOrThrow()
        }

        if (let Some(expr) <- testExpr.get("seed")) {
            let r = expect(expr, ExprTag.Number)
            if (r.isErr()) { return r }
            let seedValue = numToU32(expr.asNumber().getOrThrow())

            // Validate that randomize is true when seed is specified
            let hasRandomizeTrue = randomizeFromConfig.getOrElse(ctx.testOptions.randomize)
            if (!hasRandomizeTrue) {
                return addError(
                    expr.loc,
                    "\"seed\" can only be used when \"randomize\" is true"
                )
            }

            ctx.testOptions.seed = seedValue
        }

        // test.rerunEach
        if (let Some(expr) <- testExpr.get("rerunEach")) {
            let r = expect(expr, ExprTag.Number)
            if (r.isErr()) { return r }
            if (ctx.testOptions.retry != 0) {
                return addError(expr.loc, "\"rerunEach\" cannot be used with \"retry\"")
            }
            ctx.testOptions.repeatCount = numToU32(expr.asNumber().getOrThrow())
        }

        // test.retry
        if (let Some(expr) <- testExpr.get("retry")) {
            let r = expect(expr, ExprTag.Number)
            if (r.isErr()) { return r }
            if (ctx.testOptions.repeatCount != 0) {
                return addError(expr.loc, "\"retry\" cannot be used with \"rerunEach\"")
            }
            ctx.testOptions.retry = numToU32(expr.asNumber().getOrThrow())
        }

        // test.concurrentTestGlob
        if (let Some(expr) <- testExpr.get("concurrentTestGlob")) {
            match (expr.data) {
                case ExprData.String_(s) =>
                    if (s.isEmpty()) {
                        return addError(expr.loc, "concurrentTestGlob cannot be an empty string")
                    }
                    let singlePattern = ArrayList<String>()
                    singlePattern.add(s)
                    ctx.testOptions.concurrentTestGlob = singlePattern
                case ExprData.Array(arr) =>
                    if (arr.isEmpty()) {
                        return addError(expr.loc, "concurrentTestGlob array cannot be empty")
                    }
                    var patterns = ArrayList<String>()
                    patterns.reserve(arr.size)
                    for (item in arr) {
                        match (item.data) {
                            case ExprData.String_(s) =>
                                if (s.isEmpty()) {
                                    return addError(
                                        item.loc,
                                        "concurrentTestGlob patterns cannot be empty strings"
                                    )
                                }
                                patterns.add(s)
                            case _ =>
                                return addError(
                                    item.loc,
                                    "concurrentTestGlob array must contain only strings"
                                )
                        }
                    }
                    ctx.testOptions.concurrentTestGlob = patterns
                case _ =>
                    return addError(
                        expr.loc,
                        "concurrentTestGlob must be a string or array of strings"
                    )
            }
        }

        // test.coveragePathIgnorePatterns
        if (let Some(expr) <- testExpr.get("coveragePathIgnorePatterns")) {
            match (expr.data) {
                case ExprData.String_(s) =>
                    ctx.testOptions.coverage.ignorePatterns = ArrayList<String>()
                    ctx.testOptions.coverage.ignorePatterns.add(s)
                case ExprData.Array(arr) =>
                    if (!arr.isEmpty()) {
                        var patterns = ArrayList<String>()
                        patterns.reserve(arr.size)
                        for (item in arr) {
                            match (item.data) {
                                case ExprData.String_(s) =>
                                    patterns.add(s)
                                case _ =>
                                    return addError(
                                        item.loc,
                                        "coveragePathIgnorePatterns array must contain only strings"
                                    )
                            }
                        }
                        ctx.testOptions.coverage.ignorePatterns = patterns
                    }
                case _ =>
                    return addError(
                        expr.loc,
                        "coveragePathIgnorePatterns must be a string or array of strings"
                    )
            }
        }

        // test.pathIgnorePatterns
        if (let Some(expr) <- testExpr.get("pathIgnorePatterns")) {
            // Only skip if --path-ignore-patterns was explicitly passed via CLI
            if (!ctx.testOptions.pathIgnorePatternsFromCli) {
                match (expr.data) {
                    case ExprData.String_(s) =>
                        ctx.testOptions.pathIgnorePatterns = ArrayList<String>()
                        ctx.testOptions.pathIgnorePatterns.add(s)
                    case ExprData.Array(arr) =>
                        if (!arr.isEmpty()) {
                            var patterns = ArrayList<String>()
                            patterns.reserve(arr.size)
                            for (item in arr) {
                                match (item.data) {
                                    case ExprData.String_(s) =>
                                        patterns.add(s)
                                    case _ =>
                                        return addError(
                                            item.loc,
                                            "pathIgnorePatterns array must contain only strings"
                                        )
                                }
                            }
                            ctx.testOptions.pathIgnorePatterns = patterns
                        }
                    case _ =>
                        return addError(
                            expr.loc,
                            "pathIgnorePatterns must be a string or array of strings"
                        )
                }
            }
        }

        return Ok(())
    }

    // ========================================================================
    // applyCoverageReporterItem — corresponds to Bun: Parser::apply_coverage_reporter_item
    // ========================================================================

    /// Apply a coverage reporter item.
    // Corresponds to Bun: fn apply_coverage_reporter_item(&mut self, item) -> Result<(), Error>
    private func applyCoverageReporterItem(item: Expr): Result<Unit, BaoError> {
        let itemStr = item.asString()
        if (itemStr == "text") {
            ctx.testOptions.coverage.reporters.text = true
        } else if (itemStr == "lcov") {
            ctx.testOptions.coverage.reporters.lcov = true
        } else {
            return addErrorFormat(
                item.loc,
                "Invalid coverage reporter \"${itemStr}\""
            )
        }
        return Ok(())
    }

    // ========================================================================
    // parseInstall — corresponds to Bun: Parser::parse_install / parse_install_inner
    // ========================================================================

    /// Parse the install section.
    // Corresponds to Bun: fn parse_install(&mut self, install_obj) -> Result<(), Error>
    private func parseInstall(installObj: Expr): Result<Unit, BaoError> {
        // cafile
        if (let Some(cafile) <- installObj.get("cafile")) {
            let s = cafile.asString()
            match (s) {
                case "" =>
                    return addError(cafile.loc, "Invalid cafile. Expected a string.")
                case _ =>
                    if (ctx.install.isSome()) {
                        ctx.install.getOrThrow().cafile = s
                    }
            }
        }

        // ca
        if (let Some(ca) <- installObj.get("ca")) {
            let install = ctx.install.getOrThrow()
            match (ca.data) {
                case ExprData.Array(arr) =>
                    var list = ArrayList<String>()
                    list.reserve(arr.size)
                    for (item in arr) {
                        let s = item.asString()
                        if (s.isEmpty()) {
                            return addError(item.loc, "Invalid CA. Expected a string.")
                        }
                        list.add(s)
                    }
                    install.ca = Ca.List(list)
                case ExprData.String_(s) =>
                    install.ca = Ca.Str(s)
                case _ =>
                    return addError(
                        ca.loc,
                        "Invalid CA. Expected a string or an array of strings."
                    )
            }
        }

        // exact
        if (let Some(exact) <- installObj.get("exact")) {
            match (exact.asBool()) {
                case Some(v) =>
                    ctx.install.getOrThrow().exact = v
                case None => ()
            }
        }

        // registry
        if (let Some(registry) <- installObj.get("registry")) {
            ctx.install.getOrThrow().defaultRegistry = parseRegistry(registry)
        }

        // scopes
        if (let Some(scopes) <- installObj.get("scopes")) {
            let r = expect(scopes, ExprTag.Object)
            if (r.isErr()) { return r }
            let obj = scopes.data.eObject().getOrThrow()
            var registryMap = ScopedRegistries()
            registryMap.scopes = HashMap<String, NpmRegistry>()
            let properties = obj.properties()
            for (property in properties) {
                let name_ = property.key.asString()
                let value = property.value
                if (name_.isEmpty()) {
                    continue
                }
                // Strip leading @ if present
                let name = if (name_.startsWith("@")) {
                    name_[1..]
                } else {
                    name_
                }
                registryMap.scopes[name] = parseRegistry(value)
            }
            ctx.install.getOrThrow().scoped = registryMap
        }

        // Boolean flags: dryRun, production, frozenLockfile, saveTextLockfile, ignoreScripts, globalStore
        if (let Some(v) <- installObj.get("dryRun").andThen({ x => x.asBool() })) {
            ctx.install.getOrThrow().dryRun = v
        }
        if (let Some(v) <- installObj.get("production").andThen({ x => x.asBool() })) {
            ctx.install.getOrThrow().production = v
        }
        if (let Some(v) <- installObj.get("frozenLockfile").andThen({ x => x.asBool() })) {
            ctx.install.getOrThrow().frozenLockfile = v
        }
        if (let Some(v) <- installObj.get("saveTextLockfile").andThen({ x => x.asBool() })) {
            ctx.install.getOrThrow().saveTextLockfile = v
        }
        if (let Some(jobs) <- installObj.get("concurrentScripts")) {
            match (jobs.asNumber()) {
                case Some(n) =>
                    let n32 = numToU32(n)
                    ctx.install.getOrThrow().concurrentScripts = if (n32 == 0) {
                        None
                    } else {
                        Some(n32)
                    }
                case None => ()
            }
        }
        if (let Some(v) <- installObj.get("ignoreScripts").andThen({ x => x.asBool() })) {
            ctx.install.getOrThrow().ignoreScripts = v
        }

        // linker (node_linker)
        if (let Some(nodeLinkerExpr) <- installObj.get("linker")) {
            let r = expectString(nodeLinkerExpr)
            if (r.isErr()) { return r }
            let s = nodeLinkerExpr.asString()
            let linker = NodeLinker.fromStr(s)
            if (linker.isNone()) {
                return addError(
                    nodeLinkerExpr.loc,
                    "Expected one of \"isolated\" or \"hoisted\""
                )
            }
            ctx.install.getOrThrow().nodeLinker = linker
        }

        if (let Some(v) <- installObj.get("globalStore").andThen({ x => x.asBool() })) {
            ctx.install.getOrThrow().globalStore = v
        }

        // lockfile
        if (let Some(lockfileExpr) <- installObj.get("lockfile")) {
            let install = ctx.install.getOrThrow()
            // lockfile.print
            if (let Some(lockfile) <- lockfileExpr.get("print")) {
                let r = expectString(lockfile)
                if (r.isErr()) { return r }
                let value = lockfile.asString()
                if (value != "bun") {
                    if (value != "yarn") {
                        return addError(
                            lockfile.loc,
                            "Invalid lockfile format, only 'yarn' output is implemented"
                        )
                    }
                    install.saveYarnLockfile = true
                }
            }
            // lockfile.save
            if (let Some(v) <- lockfileExpr.get("save").andThen({ x => x.asBool() })) {
                install.saveLockfile = v
            }
            // lockfile.path
            if (let Some(v) <- lockfileExpr.get("path").andThen({ x => x.asString() })) {
                install.lockfilePath = v
            }
            // lockfile.savePath
            if (let Some(v) <- lockfileExpr.get("savePath").andThen({ x => x.asString() })) {
                install.saveLockfilePath = v
            }
        }

        // optional, peer, dev
        if (let Some(v) <- installObj.get("optional").andThen({ x => x.asBool() })) {
            ctx.install.getOrThrow().saveOptional = v
        }
        if (let Some(v) <- installObj.get("peer").andThen({ x => x.asBool() })) {
            ctx.install.getOrThrow().savePeer = v
        }
        if (let Some(v) <- installObj.get("dev").andThen({ x => x.asBool() })) {
            ctx.install.getOrThrow().saveDev = v
        }

        // globalDir, globalBinDir
        if (let Some(v) <- installObj.get("globalDir").andThen({ x => x.asString() })) {
            ctx.install.getOrThrow().globalDir = v
        }
        if (let Some(v) <- installObj.get("globalBinDir").andThen({ x => x.asString() })) {
            ctx.install.getOrThrow().globalBinDir = v
        }

        // cache
        if (let Some(cache) <- installObj.get("cache")) {
            let install = ctx.install.getOrThrow()
            match (cache.asBool()) {
                case Some(value) =>
                    if (!value) {
                        install.disableCache = true
                        install.disableManifestCache = true
                    }
                case None =>
                    match (cache.data) {
                        case ExprData.String_(s) =>
                            install.cacheDirectory = s
                        case ExprData.Object(_) =>
                            if (let Some(v) <- cache.get("disable").andThen({ x => x.asBool() })) {
                                install.disableCache = v
                            }
                            if (let Some(v) <- cache.get("disableManifest").andThen({ x => x.asBool() })) {
                                install.disableManifestCache = v
                            }
                            if (let Some(v) <- cache.get("dir").andThen({ x => x.asString() })) {
                                install.cacheDirectory = v
                            }
                        case _ => ()
                    }
            }
        }

        // linkWorkspacePackages
        if (let Some(v) <- installObj.get("linkWorkspacePackages").andThen({ x => x.asBool() })) {
            ctx.install.getOrThrow().linkWorkspacePackages = v
        }

        // security
        if (let Some(securityObj) <- installObj.get("security")) {
            match (securityObj.data) {
                case ExprData.Object(_) =>
                    if (let Some(scanner) <- securityObj.get("scanner")) {
                        let r = expectString(scanner)
                        if (r.isErr()) { return r }
                        ctx.install.getOrThrow().securityScanner = scanner.asString()
                    }
                case _ =>
                    return addError(
                        securityObj.loc,
                        "Invalid security config, expected an object"
                    )
            }
        }

        // minimumReleaseAge
        if (let Some(minAge) <- installObj.get("minimumReleaseAge")) {
            match (minAge.data) {
                case ExprData.Number(seconds) =>
                    if (seconds < 0.0) {
                        return addError(
                            minAge.loc,
                            "Expected positive number of seconds for minimumReleaseAge"
                        )
                    }
                    let MS_PER_S: Float64 = 1000.0
                    ctx.install.getOrThrow().minimumReleaseAgeMs = seconds * MS_PER_S
                case _ =>
                    return addError(
                        minAge.loc,
                        "Expected number of seconds for minimumReleaseAge"
                    )
            }
        }

        // minimumReleaseAgeExcludes
        if (let Some(exclusions) <- installObj.get("minimumReleaseAgeExcludes")) {
            match (exclusions.data) {
                case ExprData.Array(arr) =>
                    if (!arr.isEmpty()) {
                        var list = ArrayList<String>()
                        list.reserve(arr.size)
                        for (p in arr) {
                            let r = expectString(p)
                            if (r.isErr()) { return r }
                            list.add(p.asString())
                        }
                        ctx.install.getOrThrow().minimumReleaseAgeExcludes = list
                    }
                case _ =>
                    return addError(
                        exclusions.loc,
                        "Expected array for minimumReleaseAgeExcludes"
                    )
            }
        }

        // publicHoistPattern
        if (let Some(publicHoistPatternExpr) <- installObj.get("publicHoistPattern")) {
            // Corresponds to Bun: PnpmMatcher::from_expr
            // PORT NOTE: simplified — full PnpmMatcher would need its own implementation
            ctx.install.getOrThrow().publicHoistPattern = parsePnpmMatcher(publicHoistPatternExpr)
        }

        // hoistPattern
        if (let Some(hoistPatternExpr) <- installObj.get("hoistPattern")) {
            ctx.install.getOrThrow().hoistPattern = parsePnpmMatcher(hoistPatternExpr)
        }

        return Ok(())
    }

    // ========================================================================
    // parseRegistry — corresponds to Bun: Parser::parse_registry / parse_registry_object / parse_registry_url_string
    // ========================================================================

    /// Parse a registry expression.
    // Corresponds to Bun: fn parse_registry(&mut self, expr) -> Result<NpmRegistry, Error>
    private func parseRegistry(expr: Expr): NpmRegistry {
        match (expr.data) {
            case ExprData.String_(s) =>
                return parseRegistryUrlString(s)
            case ExprData.Object(o) =>
                return parseRegistryObject(o)
            case _ =>
                addError(
                    expr.loc,
                    "Expected registry to be a URL string or an object"
                )
                return NpmRegistry()
        }
    }

    /// Parse a registry URL string.
    // Corresponds to Bun: fn parse_registry_url_string
    private func parseRegistryUrlString(str: String): NpmRegistry {
        // Dedup D009: body is the canonical port in bun_api::npm_registry
        let registry = NpmRegistry()
        registry.url = str
        return registry
    }

    /// Parse a registry object.
    // Corresponds to Bun: fn parse_registry_object
    private func parseRegistryObject(obj: ExprObject): NpmRegistry {
        let registry = NpmRegistry()

        if (let Some(url) <- obj.get("url")) {
            let r = expectString(url)
            if (r.isErr()) { return registry }
            registry.url = url.asString()
        }
        if (let Some(username) <- obj.get("username")) {
            let r = expectString(username)
            if (r.isErr()) { return registry }
            registry.username = username.asString()
        }
        if (let Some(password) <- obj.get("password")) {
            let r = expectString(password)
            if (r.isErr()) { return registry }
            registry.password = password.asString()
        }
        if (let Some(token) <- obj.get("token")) {
            let r = expectString(token)
            if (r.isErr()) { return registry }
            registry.token = token.asString()
        }

        return registry
    }

    // ========================================================================
    // parseRunConfig — corresponds to Bun: Parser (run section in parse)
    // ========================================================================

    /// Parse the run section.
    // Corresponds to Bun: the run section in Parser::parse
    private func parseRunConfig(runExpr: Expr): Result<Unit, BaoError> {
        // silent
        if (let Some(silent) <- runExpr.get("silent")) {
            match (silent.asBool()) {
                case Some(value) =>
                    ctx.debug.silent = value
                case None =>
                    return addError(silent.loc, "Expected boolean")
            }
        }

        // elide-lines
        if (let Some(elideLines) <- runExpr.get("elide-lines")) {
            match (elideLines.asNumber()) {
                case Some(n) =>
                    // Note: Rust `as` saturates on overflow/NaN where Zig @intFromFloat is UB
                    ctx.bundlerOptions.elideLines = Some(n)
                case None =>
                    return addError(elideLines.loc, "Expected number")
            }
        }

        // shell
        if (let Some(shell) <- runExpr.get("shell")) {
            let value = shell.asString()
            if (value == "bun") {
                ctx.debug.useSystemShell = false
            } else if (value == "system") {
                ctx.debug.useSystemShell = true
            } else {
                return addError(
                    shell.loc,
                    "Invalid shell, only 'bun' and 'system' are supported"
                )
            }
        }

        // bun
        if (let Some(bunFlag) <- runExpr.get("bun")) {
            match (bunFlag.asBool()) {
                case Some(value) =>
                    ctx.debug.runInBun = value
                case None =>
                    return addError(bunFlag.loc, "Expected boolean")
            }
        }

        // noOrphans
        if (let Some(noOrphans) <- runExpr.get("noOrphans")) {
            match (noOrphans.asBool()) {
                case Some(value) =>
                    if (value) {
                        // Corresponds to Bun: bun_io::ParentDeathWatchdog::enable()
                        // ParentDeathWatchdog.enable()
                    }
                case None =>
                    return addError(noOrphans.loc, "Expected boolean")
            }
        }

        return Ok(())
    }

    // ========================================================================
    // parseConsoleConfig — corresponds to Bun: Parser (console section in parse)
    // ========================================================================

    /// Parse the console section.
    // Corresponds to Bun: the console section in Parser::parse
    private func parseConsoleConfig(consoleExpr: Expr): Result<Unit, BaoError> {
        if (let Some(depth) <- consoleExpr.get("depth")) {
            match (depth.asNumber()) {
                case Some(n) =>
                    let depthValue = UInt16(n)
                    // Treat depth=0 as max UInt16 for infinite depth
                    ctx.runtimeOptions.consoleDepth = if (depthValue == UInt16(0)) {
                        UInt16(65535)
                    } else {
                        depthValue
                    }
                case None =>
                    return addError(depth.loc, "Expected number")
            }
        }
        return Ok(())
    }

    // ========================================================================
    // parseServeStatic — corresponds to Bun: Parser::parse_serve_static
    // ========================================================================

    /// Parse the serve.static section.
    // Corresponds to Bun: fn parse_serve_static(&mut self, serve_obj) -> Result<(), Error>
    private func parseServeStatic(serveObj: Expr): Result<Unit, BaoError> {
        // plugins
        if (let Some(configPlugins) <- serveObj.get("plugins")) {
            let plugins: ?ArrayList<String> = match (configPlugins.data) {
                case ExprData.Array(arr) =>
                    if (arr.isEmpty()) {
                        None
                    } else {
                        var pluginList = ArrayList<String>()
                        pluginList.reserve(arr.size)
                        for (p in arr) {
                            let r = expectString(p)
                            if (r.isErr()) { return r }
                            pluginList.add(p.asString())
                        }
                        Some(pluginList)
                    }
                case _ =>
                    let r = expectString(configPlugins)
                    if (r.isErr()) { return r }
                    let s = configPlugins.asString()
                    let pluginList = ArrayList<String>()
                    pluginList.add(s)
                    Some(pluginList)
            }
            // TODO: accept entire config object
            ctx.args.servePlugins = plugins
        }

        // hmr
        if (let Some(hmr) <- serveObj.get("hmr")) {
            match (hmr.asBool()) {
                case Some(v) => ctx.args.serveHmr = v
                case None => ()
            }
        }

        // minify
        if (let Some(minify) <- serveObj.get("minify")) {
            match (minify.asBool()) {
                case Some(v) =>
                    ctx.args.serveMinifySyntax = v
                    ctx.args.serveMinifyWhitespace = v
                    ctx.args.serveMinifyIdentifiers = v
                case None =>
                    if (minify.isObject()) {
                        if (let Some(syntax) <- minify.get("syntax")) {
                            ctx.args.serveMinifySyntax = syntax.asBool().getOrElse(false)
                        }
                        if (let Some(whitespace) <- minify.get("whitespace")) {
                            ctx.args.serveMinifyWhitespace = whitespace.asBool().getOrElse(false)
                        }
                        if (let Some(identifiers) <- minify.get("identifiers")) {
                            ctx.args.serveMinifyIdentifiers = identifiers.asBool().getOrElse(false)
                        }
                    } else {
                        return addError(minify.loc, "Expected minify to be boolean or object")
                    }
            }
        }

        // define
        if (let Some(expr) <- serveObj.get("define")) {
            let r = parseDefineMap(expr)
            match (r) {
                case Ok(map) => ctx.args.serveDefine = map
                case Err(e) => return Err(e)
            }
        }

        // bunfigPath
        ctx.args.bunfigPath = source.path.text

        // publicPath
        if (let Some(publicPath) <- serveObj.get("publicPath")) {
            match (publicPath.asString()) {
                case "" => ()
                case v => ctx.args.servePublicPath = v
            }
        }

        // env
        if (let Some(env) <- serveObj.get("env")) {
            match (env.data) {
                case ExprData.Null_ =>
                    ctx.args.serveEnvBehavior = DotEnvBehavior.DISABLE
                case ExprData.Boolean(b) =>
                    ctx.args.serveEnvBehavior = if (b) {
                        DotEnvBehavior.LOAD_ALL
                    } else {
                        DotEnvBehavior.DISABLE
                    }
                case ExprData.String_(s) =>
                    let result = DotEnvBehavior.parseStr(s)
                    match (result) {
                        case Some(tuple) =>
                            if (tuple[1].isSome()) {
                                ctx.args.serveEnvPrefix = tuple[1]
                            }
                            ctx.args.serveEnvBehavior = tuple[0]
                        case None =>
                            return addError(
                                env.loc,
                                "Invalid env behavior, must be 'inline', 'disable', or a string with a '*' character"
                            )
                    }
                case _ =>
                    return addError(
                        env.loc,
                        "Invalid env behavior, must be 'inline', 'disable', or a string with a '*' character"
                    )
            }
        }

        return Ok(())
    }

    // ========================================================================
    // parseBundleConfig — corresponds to Bun: Parser (bundle section in parse)
    // ========================================================================

    /// Parse the bundle section.
    // Corresponds to Bun: the bundle section in Parser::parse
    private func parseBundleConfig(cmd: CommandTag, bundleExpr: Expr): Result<Unit, BaoError> {
        if (cmd == CommandTag.BuildCommand ||
            cmd == CommandTag.RunCommand ||
            cmd == CommandTag.AutoCommand) {
            // outdir
            if (let Some(dir) <- bundleExpr.get("outdir")) {
                let r = expectString(dir)
                if (r.isErr()) { return r }
                ctx.args.outputDir = dir.asString()
            }
        }

        if (cmd == CommandTag.BuildCommand) {
            // logLevel
            if (let Some(expr) <- bundleExpr.get("logLevel")) {
                let r = loadLogLevel(expr)
                if (r.isErr()) { return r }
            }

            // entryPoints
            if (let Some(entryPoints) <- bundleExpr.get("entryPoints")) {
                let r = expect(entryPoints, ExprTag.Array)
                if (r.isErr()) { return r }
                let arr = entryPoints.data.eArray().getOrThrow()
                var names = ArrayList<String>()
                names.reserve(arr.size)
                for (item in arr) {
                    let r = expectString(item)
                    if (r.isErr()) { return r }
                    names.add(item.asString())
                }
                ctx.args.entryPoints = names
            }

            // packages
            if (let Some(expr) <- bundleExpr.get("packages")) {
                let r = expect(expr, ExprTag.Object)
                if (r.isErr()) { return r }
                let object = expr.data.eObject().getOrThrow()
                let properties = object.properties()
                // Count valid entries
                var validCount = 0
                for (property in properties) {
                    match (property.value.data) {
                        case ExprData.Boolean(_) => validCount++
                        case _ => ()
                    }
                }
                ctx.debug.packageBundleMap.reserve(
                    validCount - ctx.debug.packageBundleMap.size
                )

                for (property in properties) {
                    match (property.value.data) {
                        case ExprData.Boolean(b) =>
                            let keyExpr = property.key
                            match (keyExpr.data) {
                                case ExprData.String_(k) =>
                                    let path = k
                                    if (!isPackagePath(path)) {
                                        return addError(keyExpr.loc, "Expected package name")
                                    }
                                    // PERF(port): was putAssumeCapacity
                                    ctx.debug.packageBundleMap[path] = if (b) {
                                        BundlePackage.Always
                                    } else {
                                        BundlePackage.Never
                                    }
                                case _ => ()
                            }
                        case _ => ()
                    }
                }
            }
        }

        return Ok(())
    }

    // ========================================================================
    // parseJsxConfig — corresponds to Bun: Parser (jsx section in parse)
    // ========================================================================

    /// Parse the JSX configuration.
    // Corresponds to Bun: the jsx section in Parser::parse
    private func parseJsxConfig(jsonExpr: Expr): Result<Unit, BaoError> {
        var jsxFactory: String = ""
        var jsxFragment: String = ""
        var jsxImportSource: String = ""
        var jsxRuntime: JsxRuntime = JsxRuntime.Automatic
        var jsxDev: Bool = true

        // jsx
        if (let Some(expr) <- jsonExpr.get("jsx")) {
            let value = expr.asString()
            if (value == "react") {
                jsxRuntime = JsxRuntime.Classic
            } else if (value == "solid") {
                jsxRuntime = JsxRuntime.Solid
            } else if (value == "react-jsx") {
                jsxRuntime = JsxRuntime.Automatic
                jsxDev = false
            } else if (value == "react-jsxDEV") {
                jsxRuntime = JsxRuntime.Automatic
                jsxDev = true
            } else {
                return addError(
                    expr.loc,
                    "Invalid jsx runtime, only 'react', 'solid', 'react-jsx', and 'react-jsxDEV' are supported"
                )
            }
        }

        // jsxImportSource
        if (let Some(expr) <- jsonExpr.get("jsxImportSource")) {
            jsxImportSource = expr.asString()
        }

        // jsxFragment
        if (let Some(expr) <- jsonExpr.get("jsxFragment")) {
            jsxFragment = expr.asString()
        }

        // jsxFactory
        if (let Some(expr) <- jsonExpr.get("jsxFactory")) {
            jsxFactory = expr.asString()
        }

        // Apply jsx config to ctx.args
        if (ctx.args.jsx.isNone()) {
            let jsx = JsxConfig()
            jsx.factory = jsxFactory
            jsx.fragment = jsxFragment
            jsx.importSource = jsxImportSource
            jsx.runtime = jsxRuntime
            jsx.development = jsxDev
            ctx.args.jsx = jsx
        } else {
            let jsx = ctx.args.jsx.getOrThrow()
            if (!jsxFactory.isEmpty()) {
                jsx.factory = jsxFactory
            }
            if (!jsxFragment.isEmpty()) {
                jsx.fragment = jsxFragment
            }
            if (!jsxImportSource.isEmpty()) {
                jsx.importSource = jsxImportSource
            }
            jsx.runtime = jsxRuntime
            jsx.development = jsxDev
        }

        return Ok(())
    }

    // ========================================================================
    // parseExternal — corresponds to Bun: Parser (external section in parse)
    // ========================================================================

    /// Parse the external section.
    // Corresponds to Bun: the external section in Parser::parse
    private func parseExternal(expr: Expr): Result<Unit, BaoError> {
        match (expr.data) {
            case ExprData.String_(s) =>
                ctx.args.external = ArrayList<String>()
                ctx.args.external.add(s)
            case ExprData.Array(array) =>
                var externals = ArrayList<String>()
                externals.reserve(array.size)
                for (item in array) {
                    let r = expectString(item)
                    if (r.isErr()) { return r }
                    externals.add(item.asString())
                }
                ctx.args.external = externals
            case _ =>
                return addError(expr.loc, "Expected string or array")
        }
        return Ok(())
    }

    // ========================================================================
    // parseLoader — corresponds to Bun: Parser (loader section in parse)
    // ========================================================================

    /// Parse the loader section.
    // Corresponds to Bun: the loader section in Parser::parse
    private func parseLoader(expr: Expr): Result<Unit, BaoError> {
        let r = expect(expr, ExprTag.Object)
        if (r.isErr()) { return r }
        let obj = expr.data.eObject().getOrThrow()
        let properties = obj.properties()
        var loaderNames = ArrayList<String>()
        var loaderValues = ArrayList<String>()
        loaderNames.reserve(properties.size)
        loaderValues.reserve(properties.size)
        for (item in properties) {
            let key = item.key.asString()
            if (key.isEmpty()) {
                continue
            }
            if (!key.startsWith(".")) {
                return addError(
                    item.key.loc,
                    "file extension for loader must start with a '.'"
                )
            }
            let value = item.value
            let r = expectString(value)
            if (r.isErr()) { return r }
            let loaderStr = value.asString()
            if (loaderStr.isEmpty()) {
                return addError(value.loc, "Invalid loader")
            }
            loaderNames.add(key)
            loaderValues.add(loaderStr)
        }
        ctx.args.loaders = LoaderMap(loaderNames, loaderValues)
        return Ok(())
    }

    // ========================================================================
    // parseMacrosJson — corresponds to Bun: parse_macros_json
    // ========================================================================

    /// Parse macros JSON configuration.
    // Corresponds to Bun: fn parse_macros_json(macros, log, json_source, bump) -> MacroMap
    private func parseMacrosJson(
        macros: Expr,
        log: Log,
        jsonSource: Source
    ): HashMap<String, HashMap<String, String>> {
        var macroMap = HashMap<String, HashMap<String, String>>()
        match (macros.data) {
            case ExprData.Object(obj) =>
                for (property in obj.properties()) {
                    let key = property.key.asString()
                    if (key.isEmpty()) {
                        continue
                    }
                    if (!isPackagePath(key)) {
                        log.addRangeWarningFmt(
                            Some(jsonSource),
                            0,
                            "\"${key}\" is not a package path. \"macros\" remaps package paths to macros. Skipping."
                        )
                        continue
                    }

                    let value = property.value
                    match (value.data) {
                        case ExprData.Object(valueObj) =>
                            let remapProperties = valueObj.properties()
                            if (remapProperties.isEmpty()) {
                                continue
                            }
                            var map = HashMap<String, String>()
                            for (remap in remapProperties) {
                                let importName = remap.key.asString()
                                if (importName.isEmpty()) {
                                    continue
                                }
                                match (remap.value.data) {
                                    case ExprData.String_(s) =>
                                        if (!s.isEmpty()) {
                                            map[importName] = s
                                        }
                                    case _ =>
                                        log.addWarningFmt(
                                            Some(jsonSource),
                                            remap.value.loc,
                                            "Invalid macro remapping for import \"${importName}\": expected string to remap to. e.g. \"graphql\": \"bun-macro-relay\""
                                        )
                                }
                            }
                            if (!map.isEmpty()) {
                                macroMap[key] = map
                            }
                        case _ =>
                            log.addWarningFmt(
                                Some(jsonSource),
                                value.loc,
                                "Invalid macro remapping in \"${key}\": expected object where the keys are import names and the value is a string path to replace"
                            )
                    }
                }
            case _ => ()
        }
        return macroMap
    }

    // ========================================================================
    // parsePnpmMatcher — simplified PnpmMatcher::from_expr
    // ========================================================================

    /// Parse a pnpm matcher expression.
    // Corresponds to Bun: PnpmMatcher::from_expr
    private func parsePnpmMatcher(expr: Expr): PnpmMatcher {
        match (expr.data) {
            case ExprData.String_(s) =>
                let patterns = ArrayList<String>()
                patterns.add(s)
                return PnpmMatcher.patterns(patterns)
            case ExprData.Array(arr) =>
                var patterns = ArrayList<String>()
                for (item in arr) {
                    let s = item.asString()
                    if (!s.isEmpty()) {
                        patterns.add(s)
                    }
                }
                return PnpmMatcher.patterns(patterns)
            case _ =>
                return PnpmMatcher.none()
        }
    }
}

// ============================================================================
// Helper: numToU32
// ============================================================================

/// Convert a float to u32, saturating on overflow/NaN.
// Corresponds to Bun: #[inline] fn num_to_u32(n: f64) -> u32
public func numToU32(n: Float64): UInt32 {
    if (n.isNaN() || n < 0.0) {
        return UInt32(0)
    }
    if (n > 4294967295.0) {
        return UInt32(4294967295)
    }
    return UInt32(n)
}

// ============================================================================
// Helper: isPackagePath
// ============================================================================

/// Check if a string is a valid package path.
// Corresponds to Bun: bun_resolver::is_package_path
public func isPackagePath(path: String): Bool {
    if (path.isEmpty()) {
        return false
    }
    // A package path starts with @ (scoped) or a letter/digit
    let c = path[0]
    return c == UInt8(0x40) || (c >= UInt8(0x61) && c <= UInt8(0x7A)) || (c >= UInt8(0x41) && c <= UInt8(0x5A)) || (c >= UInt8(0x30) && c <= UInt8(0x39))
}
