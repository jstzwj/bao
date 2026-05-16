// types — shared data types used by the bunfig parser
// Port of types from multiple Bun crates:
//   - bun_ast: Expr, ExprData, ExprTag, ExprObject, Property
//   - bun_options_types/context: ContextData, DebugOptions, RuntimeOptions
//   - bun_options_types/schema/api: TransformOptions, Jsx, StringMap, LoaderMap, BunInstall, etc.
//   - bun_install_types: NodeLinker
package bao_bunfig

import std.collection.*
import bao_core.*
import bao_parsers.*

// ============================================================================
// Expression types — corresponds to Bun: bun_ast::{Expr, ExprTag, expr::Data}
// ============================================================================

/// Expression tag — corresponds to Bun: ExprTag
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

/// Expression data — corresponds to Bun: bun_ast::expr::Data
public enum ExprData {
    | Object(ExprObject)
    | Array(ArrayList<Expr>)
    | String_(String)
    | Number(Float64)
    | Boolean(Bool)
    | Null_

    /// Get the tag for this data variant.
    public func tag(): ExprTag {
        match (this) {
            case Object(_) => ExprTag.Object
            case Array(_) => ExprTag.Array
            case String_(_) => ExprTag.String_
            case Number(_) => ExprTag.Number
            case Boolean(_) => ExprTag.Boolean
            case Null_ => ExprTag.Null_
        }
    }

    /// Get tag name as string.
    public func tagName(): String {
        tag().name()
    }

    /// Try to get as ExprObject.
    // Corresponds to Bun: expr.data.e_object()
    public func eObject(): ?ExprObject {
        match (this) {
            case Object(o) => Some(o)
            case _ => None
        }
    }

    /// Try to get as ArrayList<Expr>.
    // Corresponds to Bun: expr.data.e_array()
    public func eArray(): ?ArrayList<Expr> {
        match (this) {
            case Array(arr) => Some(arr)
            case _ => None
        }
    }

    /// Try to get as EString.
    // Corresponds to Bun: expr.data.e_string()
    public func eString(): ?EString {
        match (this) {
            case String_(s) => Some(EString(s))
            case _ => None
        }
    }
}

/// EString wrapper — corresponds to Bun: E::EString
public class EString {
    public let value: String

    public init(value: String) {
        this.value = value
    }

    public func len(): Int64 {
        value.size
    }

    public func get(): String {
        value
    }
}

/// Expression — corresponds to Bun: bun_ast::Expr
public class Expr {
    public var data: ExprData
    public var loc: Int64

    public init() {
        data = ExprData.Null_
        loc = 0
    }

    public init(data: ExprData) {
        this.data = data
        loc = 0
    }

    public init(data: ExprData, loc: Int64) {
        this.data = data
        this.loc = loc
    }

    public static func from(s: String): Expr {
        Expr(ExprData.String_(s))
    }

    /// Get the data tag.
    public func dataTag(): ExprTag {
        data.tag()
    }

    /// Get the data tag name as a string.
    public func dataTagName(): String {
        data.tagName()
    }

    /// Check if this expression is an object.
    public func isObject(): Bool {
        dataTag() == ExprTag.Object
    }

    /// Check if this expression is an array.
    public func isArray(): Bool {
        dataTag() == ExprTag.Array
    }

    /// Check if this expression is a string.
    public func isString(): Bool {
        dataTag() == ExprTag.String_
    }

    /// Check if this expression is a number.
    public func isNumber(): Bool {
        dataTag() == ExprTag.Number
    }

    /// Check if this expression is a boolean.
    public func isBoolean(): Bool {
        dataTag() == ExprTag.Boolean
    }

    /// Check if this expression is null.
    public func isNull(): Bool {
        dataTag() == ExprTag.Null_
    }

    /// Get a property by key from an object expression.
    // Corresponds to Bun: expr.get(b"key")
    public func get(key: String): ?Expr {
        match (data) {
            case Object(obj) => obj.get(key)
            case _ => None
        }
    }

    /// Get a property as an object expression.
    // Corresponds to Bun: json.get_object(b"key")
    public func getObject(key: String): ?Expr {
        match (get(key)) {
            case Some(expr) =>
                if (expr.isObject()) {
                    expr
                } else {
                    None
                }
            case None => None
        }
    }

    /// Get the string value, or empty string if not a string.
    public func asString(): String {
        match (data) {
            case String_(s) => s
            case _ => ""
        }
    }

    /// Get the boolean value, or None if not a boolean.
    public func asBool(): ?Bool {
        match (data) {
            case Boolean(b) => b
            case _ => None
        }
    }

    /// Get the number value, or None if not a number.
    public func asNumber(): ?Float64 {
        match (data) {
            case Number(n) => n
            case _ => None
        }
    }

    /// Get the array value, or empty ArrayList if not an array.
    public func asArray(): ArrayList<Expr> {
        match (data) {
            case Array(arr) => arr
            case _ => ArrayList<Expr>()
        }
    }

    /// Get properties as a list.
    public func asProperties(): ArrayList<Property> {
        match (data) {
            case Object(obj) => obj.properties()
            case _ => ArrayList<Property>()
        }
    }
}

/// Expression object — corresponds to Bun: E::Object
public class ExprObject {
    private var entries: HashMap<String, Expr> = HashMap<String, Expr>()

    public init() {}

    /// Get a property by key.
    public func get(key: String): ?Expr {
        entries.get(key)
    }

    /// Get all properties as a list.
    public func properties(): ArrayList<Property> {
        var result = ArrayList<Property>()
        for ((key, value) in entries) {
            result.add(Property(Expr.from(key), value))
        }
        return result
    }

    /// Put a property.
    public func put(key: String, value: Expr): Unit {
        entries[key] = value
    }
}

/// Property — corresponds to Bun: property in E::Object
public class Property {
    public let key: Expr
    public let value: Expr

    public init(key: Expr, value: Expr) {
        this.key = key
        this.value = value
    }
}

// ============================================================================
// Option helpers
// ============================================================================

/// Option andThen helper.
extend<T> Option<T> {
    func andThen<U>(f: (T) -> ?U): ?U {
        match (this) {
            case Some(v) => f(v)
            case None => None
        }
    }
}

/// Option getOrElse helper.
extend<T> Option<T> {
    func getOrElse(default: T): T {
        match (this) {
            case Some(v) => v
            case None => default
        }
    }
}


// ============================================================================
// Context data types — corresponds to Bun: bun_options_types::context::ContextData
// ============================================================================

/// Context data — corresponds to Bun: ContextData
public class ContextData {
    public var log: Log = Log()
    public var hasLoadedGlobalConfig: Bool = false
    public var positionals: ArrayList<String> = ArrayList<String>()
    public var args: TransformOptions = TransformOptions()
    public var debug: DebugOptions = DebugOptions()
    public var install: ?BunInstall = None
    public var runtimeOptions: RuntimeOptions = RuntimeOptions()
    public var testOptions: TestOptions = TestOptions()
    public var bundlerOptions: BundlerOptions = BundlerOptions()
    public var preloads: ArrayList<String> = ArrayList<String>()

    public init() {}
}

/// Transform options — corresponds to Bun: api::TransformOptions
public class TransformOptions {
    public var absoluteWorkingDir: ?String = None
    public var logLevel: ?MessageLevel = None
    public var define: ?StringMap = None
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
    public var serveDefine: ?StringMap = None
    public var bunfigPath: ?String = None
    public var servePublicPath: ?String = None
    public var serveEnvBehavior: ?DotEnvBehavior = None
    public var serveEnvPrefix: ?String = None
    public var disableDefaultEnvFiles: Bool = false

    public init() {}
}

/// Debug options — corresponds to Bun: DebugOptions
public class DebugOptions {
    public var loadedBunfig: Bool = false
    public var silent: Bool = false
    public var useSystemShell: Bool = false
    public var runInBun: Bool = false
    public var globalCache: ?GlobalCache = None
    public var offlineModeSetting: ?OfflineMode = None
    public var editor: ?String = None
    public var macros: ?MacroOptions = None
    public var testDirectory: ?String = None
    public var packageBundleMap: HashMap<String, BundlePackage> = HashMap<String, BundlePackage>()
    public var preloads: ArrayList<String> = ArrayList<String>()

    public init() {}

    /// Reserve capacity in the package bundle map.
    public func reserve(additional: Int64): Unit {
        // HashMap in Cangjie auto-resizes; this is a no-op
    }
}

/// Runtime options — corresponds to Bun: RuntimeOptions
public class RuntimeOptions {
    public var smol: Bool = false
    public var consoleDepth: ?UInt16 = None

    public init() {}
}

/// Bundler options — corresponds to Bun: BundlerOptions
public class BundlerOptions {
    public var elideLines: ?Float64 = None

    public init() {}
}

// ============================================================================
// Test options — corresponds to Bun: test_options
// ============================================================================

/// Test options — corresponds to Bun: TestOptions
public class TestOptions {
    public var coverage: CoverageOptions = CoverageOptions()
    public var reporters: TestReporters = TestReporters()
    public var randomize: Bool = false
    public var seed: ?UInt32 = None
    public var repeatCount: UInt32 = 0
    public var retry: UInt32 = 0
    public var concurrentTestGlob: ?ArrayList<String> = None
    public var pathIgnorePatterns: ArrayList<String> = ArrayList<String>()
    public var pathIgnorePatternsFromCli: Bool = false

    public init() {}
}

/// Coverage options — corresponds to Bun: CoverageOptions
public class CoverageOptions {
    public var enabled: Bool = false
    public var reporters: CoverageReporters = CoverageReporters(true, false)
    public var reportsDirectory: ?String = None
    public var fractions: CoverageFractions = CoverageFractions()
    public var failOnLowCoverage: Bool = false
    public var ignoreSourcemap: Bool = false
    public var skipTestFiles: Bool = false
    public var ignorePatterns: ArrayList<String> = ArrayList<String>()

    public init() {}
}

/// Coverage reporters — corresponds to Bun: CoverageReporters
public class CoverageReporters {
    public var text: Bool
    public var lcov: Bool

    public init(text: Bool, lcov: Bool) {
        this.text = text
        this.lcov = lcov
    }
}

/// Coverage fractions — corresponds to Bun: CoverageFractions
public class CoverageFractions {
    public var functions: Float64 = 0.0
    public var lines: Float64 = 0.0
    public var stmts: Float64 = 0.0

    public init() {}
}

/// Test reporters — corresponds to Bun: TestReporters
public class TestReporters {
    public var onlyFailures: Bool = false
    public var junit: Bool = false
    public var dots: Bool = false
    public var reporterOutfile: ?String = None

    public init() {}
}

// ============================================================================
// Message level — corresponds to Bun: api::MessageLevel
// ============================================================================

public enum MessageLevel {
    | Debug
    | Err
    | Warn
    | Info
}

// ============================================================================
// String map — corresponds to Bun: api::StringMap
// ============================================================================

/// String map with separate keys and values arrays.
// Corresponds to Bun: api::StringMap { keys, values }
public class StringMap {
    public var keys: ArrayList<String>
    public var values: ArrayList<String>

    public init(keys: ArrayList<String>, values: ArrayList<String>) {
        this.keys = keys
        this.values = values
    }

    public init() {
        keys = ArrayList<String>()
        values = ArrayList<String>()
    }
}

// ============================================================================
// Loader map — corresponds to Bun: api::LoaderMap
// ============================================================================

public class LoaderMap {
    public var extensions: ArrayList<String>
    public var loaders: ArrayList<String>

    public init(extensions: ArrayList<String>, loaders: ArrayList<String>) {
        this.extensions = extensions
        this.loaders = loaders
    }

    public init() {
        extensions = ArrayList<String>()
        loaders = ArrayList<String>()
    }
}

// ============================================================================
// JSX types — corresponds to Bun: api::Jsx, api::JsxRuntime
// ============================================================================

/// JSX runtime — corresponds to Bun: api::JsxRuntime
public enum JsxRuntime {
    | Classic
    | Automatic
    | Solid
}

/// JSX configuration — corresponds to Bun: api::Jsx
public class JsxConfig {
    public var factory: String = ""
    public var fragment: String = ""
    public var importSource: String = ""
    public var runtime: JsxRuntime = JsxRuntime.Automatic
    public var development: Bool = true

    public init() {}
}

// ============================================================================
// Macro options — corresponds to Bun: MacroOptions
// ============================================================================

public enum MacroOptions {
    | Disable
    | Map(HashMap<String, HashMap<String, String>>)
}

// ============================================================================
// Bundle package — corresponds to Bun: bun_options_types::BundlePackage
// ============================================================================

public enum BundlePackage {
    | Always
    | Never
}

// ============================================================================
// Global cache — corresponds to Bun: GlobalCache
// ============================================================================

public enum GlobalCache {
    | ALLOW_INSTALL
    | DISABLE
    | FORCE
    | FALLBACK

    /// Look up a global cache setting by string key.
    // Corresponds to Bun: GlobalCache::MAP.get(key)
    public static func MAP(key: String): ?GlobalCache {
        if (key == "force") {
            return Some(GlobalCache.FORCE)
        }
        if (key == "fallback") {
            return Some(GlobalCache.FALLBACK)
        }
        if (key == "disable") {
            return Some(GlobalCache.DISABLE)
        }
        return None
    }
}

// ============================================================================
// Offline mode — corresponds to Bun: OfflineModePREFER
// ============================================================================

/// Offline mode PREFER lookup — corresponds to Bun: OFFLINE_PREFER.get(key)
public class OfflineModePREFER {
    public static func get(key: String): ?OfflineMode {
        if (key == "online") {
            return Some(OfflineMode.Online)
        }
        if (key == "offline") {
            return Some(OfflineMode.Offline)
        }
        return None
    }
}

/// Offline mode enum — corresponds to Bun: OfflineMode
public enum OfflineMode {
    | Online
    | Offline
}

// ============================================================================
// DotEnv behavior — corresponds to Bun: api::DotEnvBehavior
// ============================================================================

public enum DotEnvBehavior {
    | DISABLE
    | LOAD_ALL
    | INLINE

    /// Parse a string to a DotEnvBehavior.
    // Corresponds to Bun: DotEnvBehavior::parse_str
    public static func parseStr(s: String): ?(DotEnvBehavior, ?String) {
        if (s == "inline") {
            return Some((DotEnvBehavior.INLINE, None))
        }
        if (s == "disable") {
            return Some((DotEnvBehavior.DISABLE, None))
        }
        // If the string contains a '*' character, it's a prefix pattern
        if (s.contains("*")) {
            return Some((DotEnvBehavior.LOAD_ALL, Some(s)))
        }
        return None
    }
}

// ============================================================================
// NPM registry — corresponds to Bun: api::NpmRegistry
// ============================================================================

public class NpmRegistry {
    public var url: String = ""
    public var username: String = ""
    public var password: String = ""
    public var token: String = ""

    public init() {}
}

// ============================================================================
// BunInstall — corresponds to Bun: api::BunInstall
// ============================================================================

public class BunInstall {
    public var cafile: ?String = None
    public var ca: ?Ca = None
    public var exact: ?Bool = None
    public var defaultRegistry: ?NpmRegistry = None
    public var scoped: ?ScopedRegistries = None
    public var dryRun: ?Bool = None
    public var production: ?Bool = None
    public var frozenLockfile: ?Bool = None
    public var saveTextLockfile: ?Bool = None
    public var concurrentScripts: ?UInt32 = None
    public var ignoreScripts: ?Bool = None
    public var nodeLinker: ?NodeLinker = None
    public var globalStore: ?Bool = None
    public var saveYarnLockfile: Bool = false
    public var saveLockfile: ?Bool = None
    public var lockfilePath: ?String = None
    public var saveLockfilePath: ?String = None
    public var saveOptional: ?Bool = None
    public var savePeer: ?Bool = None
    public var saveDev: ?Bool = None
    public var globalDir: ?String = None
    public var globalBinDir: ?String = None
    public var disableCache: Bool = false
    public var disableManifestCache: Bool = false
    public var cacheDirectory: ?String = None
    public var linkWorkspacePackages: ?Bool = None
    public var securityScanner: ?String = None
    public var minimumReleaseAgeMs: ?Float64 = None
    public var minimumReleaseAgeExcludes: ?ArrayList<String> = None
    public var publicHoistPattern: ?PnpmMatcher = None
    public var hoistPattern: ?PnpmMatcher = None

    public init() {}
}

// ============================================================================
// CA types — corresponds to Bun: api::Ca
// ============================================================================

public enum Ca {
    | List(ArrayList<String>)
    | Str(String)
}

// ============================================================================
// Scoped registries — corresponds to Bun: ScopedRegistries
// ============================================================================

public class ScopedRegistries {
    public var scopes: HashMap<String, NpmRegistry> = HashMap<String, NpmRegistry>()

    public init() {}
}

// ============================================================================
// Node linker — corresponds to Bun: api::NodeLinker
// ============================================================================

public enum NodeLinker {
    | Isolated
    | Hoisted

    /// Parse a NodeLinker from a string.
    // Corresponds to Bun: NodeLinker::from_str
    public static func fromStr(s: String): ?NodeLinker {
        if (s == "isolated") {
            return Some(NodeLinker.Isolated)
        }
        if (s == "hoisted") {
            return Some(NodeLinker.Hoisted)
        }
        return None
    }
}

// ============================================================================
// PnpmMatcher — corresponds to Bun: PnpmMatcher
// ============================================================================

public enum PnpmMatcher {
    | None_
    | Patterns(ArrayList<String>)

    public static func none(): PnpmMatcher {
        PnpmMatcher.None_
    }

    public static func patterns(p: ArrayList<String>): PnpmMatcher {
        PnpmMatcher.Patterns(p)
    }
}

// ============================================================================
// TOML parser stub — corresponds to Bun: bun_parsers::toml::TOML
// ============================================================================

public class TOML {
    /// Parse a TOML source.
    // Corresponds to Bun: TOML::parse(source, log, bump, allow_slow)
    public static func parse(source: Source, log: Log, allowSlow: Bool): Result<Expr, BaoError> {
        let parser = TomlParser(source.contents)
        let parsed = parser.parse()
        if (parsed.hasErrors()) {
            for (err in parsed.errors) {
                log.addErrorOpts(err.format(), Some(source), err.offset, true)
            }
            return Err(BaoError(ErrorCode.ParseError, "Failed to parse TOML"))
        }
        match (parsed.value) {
            case Some(value) => return Ok(tomlValueToExpr(value))
            case None => return Err(BaoError(ErrorCode.ParseError, "Failed to parse TOML"))
        }
    }

    private static func tomlValueToExpr(value: TomlValue): Expr {
        match (value.kind) {
            case TomlKind.String => return Expr(ExprData.String_(value.stringValue))
            case TomlKind.Integer => return Expr(ExprData.Number(Float64(value.intValue)))
            case TomlKind.Float => return Expr(ExprData.Number(value.floatValue))
            case TomlKind.Boolean => return Expr(ExprData.Boolean(value.boolValue))
            case TomlKind.Date | TomlKind.Time | TomlKind.Datetime => return Expr(ExprData.String_(value.datetimeValue.toISO()))
            case TomlKind.Array =>

                let arr = ArrayList<Expr>()
                for (item in value.arrayValue) {
                    arr.add(tomlValueToExpr(item))
                }
                return Expr(ExprData.Array(arr))
            case TomlKind.Table =>

                let obj = ExprObject()
                for (key in value.tableValue.keys()) {
                    match (value.tableValue.get(key)) {
                        case Some(child) => obj.put(key, tomlValueToExpr(child))
                        case None => ()
                    }
                }
                return Expr(ExprData.Object(obj))
        }
    }
}

// ============================================================================
// JSON parser stub — corresponds to Bun: bun_parsers::json
// ============================================================================

public class json_parser {
    /// Parse a tsconfig-style JSON source.
    // Corresponds to Bun: json_parser::parse_ts_config::<true>(source, log, bump)
    public static func parseTsConfig(source: Source, log: Log): Result<Expr, BaoError> {
        // PORT NOTE: This should call the actual JSON parser from bao_parsers
        // For now, returns a not-implemented error
        return Err(BaoError(ErrorCode.NotImplemented, "JSON parser not yet implemented"))
    }
}

// ============================================================================
// Error types
// ============================================================================

/// Error code enum — corresponds to various Bun error conditions.
public enum ErrorCode {
    | InvalidBunfig
    | ENOENT
    | Unexpected
    | NotImplemented
    | ParseError
    | OutOfMemory
}

/// Error class — corresponds to Bun: bun_core::Error
public class BaoError <: Exception {
    public let code: ErrorCode
    public let errorMsg: String

    public init(code: ErrorCode, message: String) {
        super(message)
        this.code = code
        this.errorMsg = message
    }
}
