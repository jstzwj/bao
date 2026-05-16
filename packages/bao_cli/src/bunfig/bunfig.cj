// Bunfig - bunfig.toml config file parser
package bao_cli.bunfig

import std.collection.*
import bao_core.ErrorCode
import bao_core.BaoError

public class Bunfig {
    public static func parse(cmd: CommandTag, source: String, ctx: ContextData): Result<Unit> {
        let log = ctx.log
        let logCount = log.errors + log.warnings
        let ext = getExtension(source)
        let isToml = ext == "toml"
        var expr: Expr = Expr()
        if (isToml) {
            match (parseToml(source, log)) {
                case Ok(e) => expr = e
                case Err(err) => return handleParseError(err, log, logCount, source)
            }
        } else {
            match (parseJson(source, log)) {
                case Ok(e) => expr = e
                case Err(err) => return handleParseError(err, log, logCount, source)
            }
        }
        let parser = Parser(expr, source, ctx)
        return parser.parse(cmd)
    }

    private static func handleParseError(err: BaoError, log: Log, logCount: Int64, source: String): Result<Unit> {
        if (log.errors + log.warnings == logCount) {
            log.addError("Failed to parse", source)
        }
        return Result.Err(err)
    }
}

public class Parser {
    private var json: Expr
    private var source: String
    private var ctx: ContextData

    public init(json: Expr, source: String, ctx: ContextData) {
        this.json = json
        this.source = source
        this.ctx = ctx
    }

    public func addError(text: String): Result<Unit> {
        ctx.log.addError(text, source)
        return Result.Err(BaoError(ErrorCode.ParseError, "Invalid Bunfig"))
    }

    public func expectString(expr: Expr): Result<Unit> {
        if (!expr.isString()) {
            return addError("expected string but received ${expr.dataTagName()}")
        }
        return Result.Ok(())
    }

    public func expect(expr: Expr, tag: ExprTag): Result<Unit> {
        if (expr.dataTag() != tag) {
            return addError("expected ${tag.name()} but received ${expr.dataTagName()}")
        }
        return Result.Ok(())
    }

    public func parse(cmd: CommandTag): Result<Unit> {
        if (!json.isObject()) {
            addError("bunfig expects an object { } at the root")
        }
        match (json.get("logLevel")) {
            case Some(expr) => loadLogLevel(expr)
            case None => ()
        }
        match (json.get("define")) {
            case Some(expr) => ctx.args.define = parseDefineMap(expr)
            case None => ()
        }
        let originOpt = json.get("origin")
        if (originOpt.isSome()) {
            let e = originOpt.getOrThrow()
            expectString(e)
            ctx.args.origin = e.asString()
        }
        match (json.get("env")) {
            case Some(expr) => loadEnvConfig(expr)
            case None => ()
        }
        if (cmd == CommandTag.RunCommand || cmd == CommandTag.AutoCommand) {
            let serveOpt = json.get("serve")
            if (serveOpt.isSome()) {
                let serveExpr = serveOpt.getOrThrow()
                let portOpt = serveExpr.get("port")
                if (portOpt.isSome()) {
                    let portExpr = portOpt.getOrThrow()
                    expect(portExpr, ExprTag.Number)
                    let p = portExpr.asNumber()
                    let portValue = match (p) {
                        case Some(v) => if (v == 0.0) { UInt16(3000) } else { UInt16(v) }
                        case None => UInt16(3000)
                    }
                    ctx.args.port = portValue
                }
            }
            match (json.get("preload")) {
                case Some(expr) => loadPreload(expr)
                case None => ()
            }
            let telemetryOpt = json.get("telemetry")
            if (telemetryOpt.isSome()) {
                expect(telemetryOpt.getOrThrow(), ExprTag.Boolean)
            }
        }
        if (cmd == CommandTag.RunCommand || cmd == CommandTag.AutoCommand) {
            let smolOpt = json.get("smol")
            if (smolOpt.isSome()) {
                expect(smolOpt.getOrThrow(), ExprTag.Boolean)
            }
        }
        if (cmd == CommandTag.TestCommand) {
            match (json.get("test")) {
                case Some(testExpr) => parseTestConfig(testExpr)
                case None => ()
            }
        }
        if (cmd.isNpmRelated() || cmd == CommandTag.RunCommand ||
            cmd == CommandTag.AutoCommand || cmd == CommandTag.TestCommand) {
            match (json.getObject("install")) {
                case Some(installObj) => parseInstall(installObj)
                case None => ()
            }
            match (json.get("run")) {
                case Some(runExpr) => parseRunConfig(runExpr)
                case None => ()
            }
            match (json.get("console")) {
                case Some(consoleExpr) => parseConsoleConfig(consoleExpr)
                case None => ()
            }
        }
        let serveObjOpt = json.getObject("serve")
        if (serveObjOpt.isSome()) {
            let staticOpt = serveObjOpt.getOrThrow().getObject("static")
            if (staticOpt.isSome()) {
                parseServeStatic(staticOpt.getOrThrow())
            }
        }
        match (json.get("bundle")) {
            case Some(bundleExpr) => parseBundleConfig(cmd, bundleExpr)
            case None => ()
        }
        parseJsxConfig(json)
        let debugOpt = json.get("debug")
        if (debugOpt.isSome()) {
            let editorOpt = debugOpt.getOrThrow().get("editor")
            if (editorOpt.isSome()) {
                ctx.debug.editor = editorOpt.getOrThrow().asString()
            }
        }
        let macrosOpt = json.get("macros")
        if (macrosOpt.isSome()) {
            let expr = macrosOpt.getOrThrow()
            if (expr.isBoolean() && !expr.asBool()) {
                ctx.debug.macros = MacroOptions.Disable
            }
        }
        match (json.get("external")) {
            case Some(expr) => parseExternal(expr)
            case None => ()
        }
        match (json.get("loader")) {
            case Some(expr) => parseLoader(expr)
            case None => ()
        }
        return Result.Ok(())
    }

    private func loadLogLevel(expr: Expr): Result<Unit> {
        expectString(expr)
        let level = expr.asString()
        match (level) {
            case "debug" => ctx.args.logLevel = "debug"
            case "error" => ctx.args.logLevel = "error"
            case "warn" => ctx.args.logLevel = "warn"
            case "info" => ctx.args.logLevel = "info"
            case _ => return addError("Invalid log level")
        }
        return Result.Ok(())
    }

    private func loadPreload(expr: Expr): Result<Unit> {
        if (expr.isArray()) {
            var preloads = ArrayList<String>()
            for (item in expr.asArray()) {
                expectString(item)
                let s = item.asString()
                if (!s.isEmpty()) { preloads.add(s) }
            }
            ctx.debug.preloads = preloads
        } else if (expr.isString()) {
            let s = expr.asString()
            if (!s.isEmpty()) {
                var preloads = ArrayList<String>()
                preloads.add(s)
                ctx.debug.preloads = preloads
            }
        }
        return Result.Ok(())
    }

    private func loadEnvConfig(expr: Expr): Result<Unit> {
        if (expr.isNull()) {
            ctx.args.disableDefaultEnvFiles = true
        } else if (expr.isBoolean() && !expr.asBool()) {
            ctx.args.disableDefaultEnvFiles = true
        } else if (expr.isObject()) {
            let fileOpt = expr.get("file")
            if (fileOpt.isSome()) {
                let fe = fileOpt.getOrThrow()
                if (fe.isNull() || (fe.isBoolean() && !fe.asBool())) {
                    ctx.args.disableDefaultEnvFiles = true
                }
            }
        }
        return Result.Ok(())
    }

    private func parseDefineMap(expr: Expr): ?HashMap<String, String> {
        if (!expr.isObject()) { return None }
        let map = HashMap<String, String>()
        for (p in expr.asProperties()) {
            let k = p.key.asString()
            if (!k.isEmpty()) { map.put(k, p.value.asString()) }
        }
        return map
    }

    private func parseTestConfig(testExpr: Expr): Result<Unit> {
        match (testExpr.get("root")) {
            case Some(e) => ctx.debug.testDirectory = e.asString()
            case None => ()
        }
        match (testExpr.get("preload")) {
            case Some(e) => loadPreload(e)
            case None => ()
        }
        let smolOpt = testExpr.get("smol")
        if (smolOpt.isSome()) { expect(smolOpt.getOrThrow(), ExprTag.Boolean) }
        let covOpt = testExpr.get("coverage")
        if (covOpt.isSome()) { expect(covOpt.getOrThrow(), ExprTag.Boolean) }
        let ofOpt = testExpr.get("onlyFailures")
        if (ofOpt.isSome()) { expect(ofOpt.getOrThrow(), ExprTag.Boolean) }
        let repOpt = testExpr.get("reporter")
        if (repOpt.isSome()) {
            let repExpr = repOpt.getOrThrow()
            let junitOpt = repExpr.get("junit")
            if (junitOpt.isSome()) { expectString(junitOpt.getOrThrow()) }
            let dotsOpt = repExpr.get("dots")
            if (dotsOpt.isSome()) { expect(dotsOpt.getOrThrow(), ExprTag.Boolean) }
        }
        let crOpt = testExpr.get("coverageReporter")
        if (crOpt.isSome()) {
            let e = crOpt.getOrThrow()
            if (e.isString()) { applyCoverageReporterItem(e) }
            else if (e.isArray()) {
                for (item in e.asArray()) { expectString(item); applyCoverageReporterItem(item) }
            }
        }
        let cdOpt = testExpr.get("coverageDir")
        if (cdOpt.isSome()) { expectString(cdOpt.getOrThrow()) }
        let seedOpt = testExpr.get("seed")
        if (seedOpt.isSome()) { expect(seedOpt.getOrThrow(), ExprTag.Number) }
        let retryOpt = testExpr.get("retry")
        if (retryOpt.isSome()) { expect(retryOpt.getOrThrow(), ExprTag.Number) }
        let rerunOpt = testExpr.get("rerunEach")
        if (rerunOpt.isSome()) { expect(rerunOpt.getOrThrow(), ExprTag.Number) }
        let cgOpt = testExpr.get("concurrentTestGlob")
        if (cgOpt.isSome()) {
            let e = cgOpt.getOrThrow()
            if (e.isString()) {
                if (e.asString().isEmpty()) { addError("concurrentTestGlob cannot be empty") }
            } else if (e.isArray()) {
                if (e.asArray().isEmpty()) { addError("concurrentTestGlob array cannot be empty") }
            }
        }
        return Result.Ok(())
    }

    private func applyCoverageReporterItem(item: Expr): Result<Unit> {
        let s = item.asString()
        if (s != "text" && s != "lcov") { return addError("Invalid coverage reporter") }
        return Result.Ok(())
    }

    private func parseInstall(installObj: Expr): Result<Unit> {
        let autoOpt = installObj.get("auto")
        if (autoOpt.isSome()) {
            let e = autoOpt.getOrThrow()
            if (!e.isString() && !e.isBoolean()) { addError("Invalid auto install setting") }
        }
        let preferOpt = installObj.get("prefer")
        if (preferOpt.isSome()) { expectString(preferOpt.getOrThrow()) }
        let llOpt = installObj.get("logLevel")
        if (llOpt.isSome()) { loadLogLevel(llOpt.getOrThrow()) }
        let cafileOpt = installObj.get("cafile")
        if (cafileOpt.isSome()) {
            match (cafileOpt.getOrThrow().asString()) { case Some(_) => () case None => addError("Invalid cafile") }
        }
        let exactOpt = installObj.get("exact")
        if (exactOpt.isSome()) {
            match (exactOpt.getOrThrow().asBool()) { case Some(_) => () case None => () }
        }
        let regOpt = installObj.get("registry")
        if (regOpt.isSome()) { /* parse registry */ }
        let scopesOpt = installObj.get("scopes")
        if (scopesOpt.isSome()) { expect(scopesOpt.getOrThrow(), ExprTag.Object) }
        let lfOpt = installObj.get("lockfile")
        if (lfOpt.isSome()) {
            let lfExpr = lfOpt.getOrThrow()
            let printOpt = lfExpr.get("print")
            if (printOpt.isSome()) { expectString(printOpt.getOrThrow()) }
            let saveOpt = lfExpr.get("save")
            if (saveOpt.isSome()) {
                match (saveOpt.getOrThrow().asBool()) { case Some(_) => () case None => () }
            }
            let pathOpt = lfExpr.get("path")
            if (pathOpt.isSome()) {
                match (pathOpt.getOrThrow().asString()) { case Some(_) => () case None => () }
            }
        }
        let cacheOpt = installObj.get("cache")
        if (cacheOpt.isSome()) {
            let e = cacheOpt.getOrThrow()
            if (e.isObject()) {
                match (e.get("disable")) { case Some(v) => match (v.asBool()) { case Some(_) => () case None => () } case None => () }
            }
        }
        for (field in ["optional", "peer", "dev", "dryRun", "production", "frozenLockfile",
                        "saveTextLockfile", "ignoreScripts", "globalStore"]) {
            let fOpt = installObj.get(field)
            if (fOpt.isSome()) { match (fOpt.getOrThrow().asBool()) { case Some(_) => () case None => () } }
        }
        let csOpt = installObj.get("concurrentScripts")
        if (csOpt.isSome()) { match (csOpt.getOrThrow().asNumber()) { case Some(_) => () case None => () } }
        let linkerOpt = installObj.get("linker")
        if (linkerOpt.isSome()) { expectString(linkerOpt.getOrThrow()) }
        let minAgeOpt = installObj.get("minimumReleaseAge")
        if (minAgeOpt.isSome()) {
            let e = minAgeOpt.getOrThrow()
            if (!e.isNumber()) { addError("Expected number for minimumReleaseAge") }
        }
        let secOpt = installObj.get("security")
        if (secOpt.isSome()) {
            let e = secOpt.getOrThrow()
            if (e.isObject()) {
                match (e.get("scanner")) { case Some(se) => expectString(se) case None => () }
            }
        }
        return Result.Ok(())
    }

    private func parseRunConfig(runExpr: Expr): Result<Unit> {
        let silentOpt = runExpr.get("silent")
        if (silentOpt.isSome()) {
            match (silentOpt.getOrThrow().asBool()) { case Some(v) => ctx.debug.silent = v case None => addError("Expected boolean") }
        }
        let elideOpt = runExpr.get("elide-lines")
        if (elideOpt.isSome()) {
            match (elideOpt.getOrThrow().asNumber()) { case Some(_) => () case None => addError("Expected number") }
        }
        let shellOpt = runExpr.get("shell")
        if (shellOpt.isSome()) {
            match (shellOpt.getOrThrow().asString()) {
                case "bun" => ctx.debug.useSystemShell = false
                case "system" => ctx.debug.useSystemShell = true
                case _ => addError("Invalid shell")
            }
        }
        let bunOpt = runExpr.get("bun")
        if (bunOpt.isSome()) {
            match (bunOpt.getOrThrow().asBool()) { case Some(v) => ctx.debug.runInBun = v case None => addError("Expected boolean") }
        }
        let noOpt = runExpr.get("noOrphans")
        if (noOpt.isSome()) {
            match (noOpt.getOrThrow().asBool()) { case Some(_) => () case None => addError("Expected boolean") }
        }
        return Result.Ok(())
    }

    private func parseConsoleConfig(consoleExpr: Expr): Result<Unit> {
        let depthOpt = consoleExpr.get("depth")
        if (depthOpt.isSome()) {
            match (depthOpt.getOrThrow().asNumber()) { case Some(_) => () case None => addError("Expected number") }
        }
        return Result.Ok(())
    }

    private func parseBundleConfig(cmd: CommandTag, bundleExpr: Expr): Result<Unit> {
        if (cmd == CommandTag.BuildCommand || cmd == CommandTag.RunCommand || cmd == CommandTag.AutoCommand) {
            let outOpt = bundleExpr.get("outdir")
            if (outOpt.isSome()) {
                let e = outOpt.getOrThrow()
                expectString(e)
                ctx.args.outputDir = e.asString()
            }
        }
        if (cmd == CommandTag.BuildCommand) {
            let llOpt = bundleExpr.get("logLevel")
            if (llOpt.isSome()) { loadLogLevel(llOpt.getOrThrow()) }
            let epOpt = bundleExpr.get("entryPoints")
            if (epOpt.isSome()) {
                let e = epOpt.getOrThrow()
                expect(e, ExprTag.Array)
                var names = ArrayList<String>()
                for (item in e.asArray()) { expectString(item); names.add(item.asString()) }
                ctx.args.entryPoints = names
            }
            let pkgOpt = bundleExpr.get("packages")
            if (pkgOpt.isSome()) { expect(pkgOpt.getOrThrow(), ExprTag.Object) }
        }
        return Result.Ok(())
    }

    private func parseJsxConfig(jsonExpr: Expr): Result<Unit> {
        var jsxFactory: String = ""
        var jsxFragment: String = ""
        var jsxImportString: String = ""
        var jsxRuntime: String = "automatic"
        var jsxDev: Bool = true
        let jsxOpt = jsonExpr.get("jsx")
        if (jsxOpt.isSome()) {
            let s = jsxOpt.getOrThrow().asString()
            if (s == "react") { jsxRuntime = "classic" }
            else if (s == "solid") { jsxRuntime = "solid" }
            else if (s == "react-jsx") { jsxRuntime = "automatic"; jsxDev = false }
            else if (s == "react-jsxDEV") { jsxRuntime = "automatic"; jsxDev = true }
        }
        let isOpt = jsonExpr.get("jsxImportString")
        if (isOpt.isSome()) { jsxImportString = isOpt.getOrThrow().asString() }
        let fragOpt = jsonExpr.get("jsxFragment")
        if (fragOpt.isSome()) { jsxFragment = fragOpt.getOrThrow().asString() }
        let factOpt = jsonExpr.get("jsxFactory")
        if (factOpt.isSome()) { jsxFactory = factOpt.getOrThrow().asString() }
        if (ctx.args.jsx.isNone()) {
            let jsx = JsxConfig()
            jsx.factory = jsxFactory
            jsx.fragment = jsxFragment
            jsx.importSource = jsxImportString
            jsx.runtime = jsxRuntime
            jsx.development = jsxDev
            ctx.args.jsx = jsx
        } else {
            let jsx = ctx.args.jsx.getOrThrow()
            if (!jsxFactory.isEmpty()) { jsx.factory = jsxFactory }
            if (!jsxFragment.isEmpty()) { jsx.fragment = jsxFragment }
            jsx.runtime = jsxRuntime
            jsx.development = jsxDev
        }
        return Result.Ok(())
    }

    private func parseExternal(expr: Expr): Result<Unit> {
        if (expr.isString()) {
            ctx.args.external = ArrayList<String>()
            ctx.args.external.add(expr.asString())
        } else if (expr.isArray()) {
            var exts = ArrayList<String>()
            for (item in expr.asArray()) { expectString(item); exts.add(item.asString()) }
            ctx.args.external = exts
        }
        return Result.Ok(())
    }

    private func parseLoader(expr: Expr): Result<Unit> {
        expect(expr, ExprTag.Object)
        var extensions = ArrayList<String>()
        var loaders = ArrayList<String>()
        for (p in expr.asProperties()) {
            let k = p.key.asString()
            if (k.isEmpty()) { continue }
            if (!k.startsWith(".")) { addError("file extension for loader must start with a '.'") }
            expectString(p.value)
            extensions.add(k)
            loaders.add(p.value.asString())
        }
        let loaderMap = LoaderMap()
        loaderMap.extensions = extensions
        loaderMap.loaders = loaders
        ctx.args.loaders = loaderMap
        return Result.Ok(())
    }

    private func parseServeStatic(serveObj: Expr): Result<Unit> {
        let pluginsOpt = serveObj.get("plugins")
        if (pluginsOpt.isSome()) {
            let e = pluginsOpt.getOrThrow()
            if (e.isArray()) {
                var plugins = ArrayList<String>()
                for (item in e.asArray()) { expectString(item); plugins.add(item.asString()) }
                ctx.args.servePlugins = plugins
            } else if (e.isString()) {
                var plugins = ArrayList<String>()
                plugins.add(e.asString())
                ctx.args.servePlugins = plugins
            }
        }
        let hmrOpt = serveObj.get("hmr")
        if (hmrOpt.isSome()) {
            match (hmrOpt.getOrThrow().asBool()) { case Some(v) => ctx.args.serveHmr = v case None => () }
        }
        let minOpt = serveObj.get("minify")
        if (minOpt.isSome()) {
            let e = minOpt.getOrThrow()
            let bOpt = e.asBool()
            if (bOpt.isSome()) {
                let v = bOpt.getOrThrow()
                ctx.args.serveMinifySyntax = v
                ctx.args.serveMinifyWhitespace = v
                ctx.args.serveMinifyIdentifiers = v
            } else if (e.isObject()) {
                let _synOpt = e.get("syntax"); if (_synOpt.isSome()) { ctx.args.serveMinifySyntax = match (_synOpt.getOrThrow().asBool()) { case Some(b) => b case None => false } }
                let _wsOpt = e.get("whitespace"); if (_wsOpt.isSome()) { ctx.args.serveMinifyWhitespace = match (_wsOpt.getOrThrow().asBool()) { case Some(b) => b case None => false } }
                let _idOpt = e.get("identifiers"); if (_idOpt.isSome()) { ctx.args.serveMinifyIdentifiers = match (_idOpt.getOrThrow().asBool()) { case Some(b) => b case None => false } }
            }
        }
        match (serveObj.get("define")) {
            case Some(e) => ctx.args.serveDefine = parseDefineMap(e)
            case None => ()
        }
        match (serveObj.get("publicPath")) {
            case Some(e) => ctx.args.servePublicPath = e.asString()
            case None => ()
        }
        let envOpt = serveObj.get("env")
        if (envOpt.isSome()) {
            let e = envOpt.getOrThrow()
            if (e.isNull()) { ctx.args.serveEnvBehavior = "disable" }
            else if (e.isBoolean()) { ctx.args.serveEnvBehavior = if (e.asBool()) { "load_all" } else { "disable" } }
            else if (e.isString()) { ctx.args.serveEnvBehavior = e.asString() }
        }
        ctx.args.bunfigPath = source
        return Result.Ok(())
    }
}

public enum ExprTag {
    | Object
    | Array
    | String_
    | Number
    | Boolean
    | Null_

    public operator func ==(right: ExprTag): Bool {
        match (this) {
            case Object => match (right) { case Object => true case _ => false }
            case Array => match (right) { case Array => true case _ => false }
            case String_ => match (right) { case String_ => true case _ => false }
            case Number => match (right) { case Number => true case _ => false }
            case Boolean => match (right) { case Boolean => true case _ => false }
            case Null_ => match (right) { case Null_ => true case _ => false }
        }
    }

    public operator func !=(right: ExprTag): Bool {
        !(this == right)
    }

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

public class Expr {
    public var data: ExprData
    public var loc: Int64

    public init() { data = ExprData.Null_; loc = 0 }
    public init(data: ExprData) { this.data = data; loc = 0 }

    public static func from(s: String): Expr { Expr(data: ExprData.String_(s)) }

    public func dataTag(): ExprTag {
        match (data) {
            case ExprData.Object(_) => ExprTag.Object
            case ExprData.Array(_) => ExprTag.Array
            case ExprData.String_(_) => ExprTag.String_
            case ExprData.Number(_) => ExprTag.Number
            case ExprData.Boolean(_) => ExprTag.Boolean
            case ExprData.Null_ => ExprTag.Null_
        }
    }
    public func dataTagName(): String { dataTag().name() }
    public func isObject(): Bool { dataTag() == ExprTag.Object }
    public func isArray(): Bool { dataTag() == ExprTag.Array }
    public func isString(): Bool { dataTag() == ExprTag.String_ }
    public func isNumber(): Bool { dataTag() == ExprTag.Number }
    public func isBoolean(): Bool { dataTag() == ExprTag.Boolean }
    public func isNull(): Bool { dataTag() == ExprTag.Null_ }

    public func get(key: String): ?Expr {
        match (data) { case ExprData.Object(obj) => obj.get(key) case _ => None }
    }
    public func getObject(key: String): ?Expr {
        match (get(key)) { case Some(expr) => if (expr.isObject()) { expr } else { None } case None => None }
    }
    public func asString(): String {
        match (data) { case ExprData.String_(s) => s case _ => "" }
    }
    public func asBool(): ?Bool {
        match (data) { case ExprData.Boolean(b) => b case _ => None }
    }
    public func asNumber(): ?Float64 {
        match (data) { case ExprData.Number(n) => n case _ => None }
    }
    public func asArray(): ArrayList<Expr> {
        match (data) { case ExprData.Array(arr) => arr case _ => ArrayList<Expr>() }
    }
    public func asProperties(): ArrayList<Property> {
        match (data) { case ExprData.Object(obj) => obj.properties() case _ => ArrayList<Property>() }
    }
}

public enum ExprData {
    | Object(ExprObject)
    | Array(ArrayList<Expr>)
    | String_(String)
    | Number(Float64)
    | Boolean(Bool)
    | Null_
}

public class ExprObject {
    private var entries: HashMap<String, Expr> = HashMap<String, Expr>()
    public func get(key: String): ?Expr { entries.get(key) }
    public func properties(): ArrayList<Property> {
        var result = ArrayList<Property>()
        for (key in entries.keys()) {
            match (entries.get(key)) {
                case Some(value) => result.add(Property(key: Expr.from(key), value: value))
                case None => ()
            }
        }
        return result
    }
    public func put(key: String, value: Expr): Unit { entries.put(key, value) }
}

public class Property {
    public let key: Expr
    public let value: Expr
    public init(key: Expr, value: Expr) { this.key = key; this.value = value }
}

public func exprFrom(s: String): Expr { Expr(data: ExprData.String_(s)) }
public func exprFromStr(s: String): Expr { Expr(data: ExprData.String_(s)) }

/// Log addError helper (extension not supported at top level)
public func logAddError(log: Log, text: String, source: String): Unit { log.errors += 1 }

/// Option getOrElse helper
public func optionGetOrElse<T>(opt: ?T, default: T): T {
    match (opt) { case Some(v) => v case None => default }
}

private func getExtension(source: String): String {
    let dotIdx = source.lastIndexOf('.')
    match (dotIdx) { case Some(idx) => source[(idx + 1)..] case None => "" }
}

private func parseToml(source: String, log: Log): Result<Expr> {
    Result.Err(BaoError(ErrorCode.ParseError, "TOML parser not implemented"))
}

private func parseJson(source: String, log: Log): Result<Expr> {
    Result.Err(BaoError(ErrorCode.ParseError, "JSON parser not implemented"))
}
