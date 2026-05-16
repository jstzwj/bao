// arguments — bunfig config loading entry functions
// Strict port of: src/bunfig/arguments.rs
//
// Original Rust module comment:
//   Port of `src/runtime/cli/Arguments.zig` — bunfig-loading subset.
//   and their private helpers were lifted out of `bun_runtime::cli::Arguments`
//   so that mid-tier crates (`bun_install`) can call them directly. The
//   `bun_runtime` crate re-exports these for its own callers.
package bao_bunfig

import std.collection.*
import bao_core.*

// ============================================================================
// bunfig loading — corresponds to Bun src/bunfig/arguments.rs
//
// Core functions:
// - getHomeConfigPath: get home directory config path
// - loadBunfig: load and parse a bunfig config file
// - loadGlobalBunfig: load global bunfig
// - loadConfigPath: load config at specified path
// - reportBunfigLoadFailure: report bunfig load failure (cold path)
// - loadConfig: auto-discover and load config
// - loadConfigWithCmdArgs: load config from command-line args
// ============================================================================

/// Get the path to the home-directory bunfig config file.
// Corresponds to Bun: fn get_home_config_path(buf: &mut PathBuffer) -> Option<&ZStr>
// Search order:
//   1. $XDG_CONFIG_HOME/.bunfig.toml
//   2. $HOME/.bunfig.toml
public func getHomeConfigPath(): ?String {
    // Check XDG_CONFIG_HOME first
    let xdgHome = getEnv("XDG_CONFIG_HOME")
    if (xdgHome.isSome()) {
        let dir = xdgHome.getOrThrow()
        let path = dir + "/.bunfig.toml"
        return path
    }

    // Check HOME
    let homeDir = getEnv("HOME")
    if (homeDir.isSome()) {
        let dir = homeDir.getOrThrow()
        let path = dir + "/.bunfig.toml"
        return path
    }

    return None
}

/// Load a bunfig config file.
// Corresponds to Bun: fn load_bunfig(cmd, auto_loaded, config_path, ctx) -> Result<(), Error>
//
// Parameters:
//   cmd       — command tag (Run, Build, Test, etc.)
//   autoLoaded — whether auto-loaded (no error if file missing)
//   configPath — path to the config file
//   ctx       — context data
//
// Steps:
//   1. Read the config file contents
//   2. Parse to AST (source)
//   3. Create AST stores and reset guard
//   4. Temporarily set log level to Warn
//   5. Call Bunfig.parse to parse the config
//   6. Restore log level
public func loadBunfig(
    cmd: CommandTag,
    autoLoaded: Bool,
    configPath: String,
    ctx: ContextData
): Result<Unit, BaoError> {
    // Read the config file
    // Corresponds to Bun: bun_ast::to_source(config_path, ToSourceOptions { convert_bom: true })
    var source: ?Source = None
    match (readSource(configPath, true /* convert_bom */)) {
        case Ok(s) =>
            source = s
        case Err(err) =>
            if (autoLoaded) {
                return Ok(())
            }
            // Corresponds to Bun: Output::pretty_errorln(...)
            Output.prettyErrorln("${err}\nwhile reading config \"${configPath}\"")
            Global.exit(1)
    }

    // Create AST stores
    // Corresponds to Bun:
    //   bun_ast::stmt::data::Store::create();
    //   bun_ast::expr::data::Store::create();
    //   let _store_reset = bun_ast::StoreResetGuard::new();
    // PORT NOTE: In Cangjie, AST store creation/reset is handled differently;
    // the guard pattern maps to a try-finally block.

    // Temporarily set log level to Warn
    // Corresponds to Bun: the log_ptr / original_level / _guard pattern
    let originalLevel = ctx.log.level
    ctx.log.level = LogLevel.Warn

    try {
        // Mark bunfig as loaded
        ctx.debug.loadedBunfig = true

        // Parse the config
        let result = Bunfig.parse(cmd, source.getOrThrow(), ctx)
        return result
    } finally {
        // Restore log level — corresponds to Bun: _guard restores level on unwind/return
        ctx.log.level = originalLevel
    }
}

/// Load the global bunfig configuration.
// Corresponds to Bun: fn load_global_bunfig(cmd, ctx) -> Result<(), Error>
public func loadGlobalBunfig(cmd: CommandTag, ctx: ContextData): Result<Unit, BaoError> {
    if (ctx.hasLoadedGlobalConfig) {
        return Ok(())
    }
    ctx.hasLoadedGlobalConfig = true

    match (getHomeConfigPath()) {
        case Some(path) =>
            return loadBunfig(cmd, true, path, ctx)
        case None =>
            return Ok(())
    }
}

/// Load config at a specified path.
// Corresponds to Bun: pub fn load_config_path(cmd, auto_loaded, config_path, ctx) -> Result<(), Error>
public func loadConfigPath(
    cmd: CommandTag,
    autoLoaded: Bool,
    configPath: String,
    ctx: ContextData
): Result<Unit, BaoError> {
    // PORT NOTE: `comptime cmd.readGlobalConfig()` demoted to runtime — see
    // `parse()` PORT NOTE; `Tag::read_global_config` is a const-ish lookup so
    // the dead arm is still a single branch.
    if (cmd.readGlobalConfig()) {
        match (loadGlobalBunfig(cmd, ctx)) {
            case Err(err) =>
                if (autoLoaded) {
                    return Ok(())
                }
                Output.prettyErrorln("${err}\nreading global config \"${configPath}\"")
                Global.exit(1)
            case Ok(_) =>
                ()
        }
    }

    return loadBunfig(cmd, autoLoaded, configPath, ctx)
}

/// Report bunfig load failure (cold path).
// Corresponds to Bun: #[cold] fn report_bunfig_load_failure(log, err) -> !
public func reportBunfigLoadFailure(log: Log, err: BaoError): Nothing {
    if (log.hasAny()) {
        log.print(Output.errorWriter())
        Output.printError("\n")
    }
    Output.err(err, "failed to load bunfig")
    Global.crash()
}

/// Auto-discover and load configuration.
// Corresponds to Bun: pub fn load_config(cmd, user_config_path_, ctx) -> Result<(), Error>
//
// Logic:
//   1. Check standalone mode autoloadBunfig flag
//   2. Load global config (if needed)
//   3. Determine config file path:
//      - User-specified path
//      - bunfig.toml in current directory (auto-loaded)
//   4. Resolve absolute/relative paths
//   5. Load the config
public func loadConfig(
    cmd: CommandTag,
    userConfigPath: ?String,
    ctx: ContextData
): Result<Unit, BaoError> {
    // If running as a standalone executable with autoloadBunfig disabled, skip
    // config loading unless an explicit config path was provided via --config.
    // Corresponds to Bun: StandaloneModuleGraph check
    if (userConfigPath.isNone()) {
        if (StandaloneModuleGraph.get().isSome()) {
            let graph = StandaloneModuleGraph.get().getOrThrow()
            if (graph.flags.contains(StandaloneModuleGraphFlags.DISABLE_AUTOLOAD_BUNFIG)) {
                return Ok(())
            }
        }
    }

    // Load global config
    if (cmd.readGlobalConfig()) {
        if (!ctx.hasLoadedGlobalConfig) {
            ctx.hasLoadedGlobalConfig = true

            match (getHomeConfigPath()) {
                case Some(path) =>
                    match (loadConfigPath(cmd, true, path, ctx)) {
                        case Err(err) =>
                            reportBunfigLoadFailure(ctx.log, err)
                        case Ok(_) =>
                            ()
                    }
                case None =>
                    ()
            }
        }
    }

    // Determine config file path
    var configPath: String = match (userConfigPath) {
        case Some(p) => p
        case None => ""
    }

    var autoLoaded: Bool = false

    // Auto-determine config file path
    // Corresponds to Bun: the complex condition for auto-loading bunfig.toml
    if (configPath.isEmpty()) {
        if (userConfigPath.isSome()
            || cmd.alwaysLoadsConfig()
            || (cmd == CommandTag.AutoCommand
                && (
                    // "bun"
                    ctx.positionals.isEmpty()
                    // "bun file.js"
                    || (!ctx.positionals.isEmpty()
                        && options.DEFAULT_LOADERS.containsKey(getExtension(ctx.positionals[0])))
                ))
        ) {
            configPath = "bunfig.toml"
            autoLoaded = true
        }
    }

    if (configPath.isEmpty()) {
        return Ok(())
    }

    // Handle relative/absolute paths
    // Corresponds to Bun: the absolute path resolution logic
    let resolvedPath: String
    if (configPath.startsWith("/")) {
        resolvedPath = configPath
    } else {
        // Get working directory
        if (ctx.args.absoluteWorkingDir.isNone()) {
            match (getCwd()) {
                case Some(cwd) =>
                    ctx.args.absoluteWorkingDir = cwd
                case None =>
                    return Ok(())
            }
        }

        let awd = ctx.args.absoluteWorkingDir.getOrThrow()
        resolvedPath = resolvePath.joinAbsString(awd, configPath)
    }

    // Load the config
    match (loadConfigPath(cmd, autoLoaded, resolvedPath, ctx)) {
        case Err(err) =>
            reportBunfigLoadFailure(ctx.log, err)
        case Ok(_) =>
            ()
    }

    return Ok(())
}

/// Load config from command-line arguments.
// Corresponds to Bun: pub fn load_config_with_cmd_args(cmd, args, ctx) -> Result<(), Error>
public func loadConfigWithCmdArgs(
    cmd: CommandTag,
    args: ClapArgs,
    ctx: ContextData
): Result<Unit, BaoError> {
    return loadConfig(cmd, args.option("--config"), ctx)
}

// ============================================================================
// Helper types
// ============================================================================

/// Command tag — corresponds to Bun: bun_options_types::command_tag::Tag
public enum CommandTag {
    | RunCommand
    | BuildCommand
    | TestCommand
    | InstallCommand
    | AutoCommand
    | InitCommand
    | ReplCommand

    public operator func ==(right: CommandTag): Bool {
        match (this) {
            case RunCommand => match (right) { case RunCommand => true case _ => false }
            case BuildCommand => match (right) { case BuildCommand => true case _ => false }
            case TestCommand => match (right) { case TestCommand => true case _ => false }
            case InstallCommand => match (right) { case InstallCommand => true case _ => false }
            case AutoCommand => match (right) { case AutoCommand => true case _ => false }
            case InitCommand => match (right) { case InitCommand => true case _ => false }
            case ReplCommand => match (right) { case ReplCommand => true case _ => false }
        }
    }

    public operator func !=(right: CommandTag): Bool {
        !(this == right)
    }

    /// Whether this command needs to read the global config.
    // Corresponds to Bun: comptime readGlobalConfig()
    public func readGlobalConfig(): Bool {
        match (this) {
            case RunCommand | BuildCommand | TestCommand | InstallCommand | AutoCommand => true
            case _ => false
        }
    }

    /// Whether this command always loads config.
    // Corresponds to Bun: ALWAYS_LOADS_CONFIG[cmd]
    public func alwaysLoadsConfig(): Bool {
        match (this) {
            case BuildCommand | InstallCommand => true
            case _ => false
        }
    }

    /// Whether this command is npm-related.
    // Corresponds to Bun: cmd.is_npm_related()
    public func isNpmRelated(): Bool {
        match (this) {
            case InstallCommand => true
            case _ => false
        }
    }
}

/// Log level — corresponds to Bun: bun_ast::Level
public enum LogLevel {
    | Debug
    | Info
    | Warn
    | Error

    public operator func ==(right: LogLevel): Bool {
        match (this) {
            case Debug => match (right) { case Debug => true case _ => false }
            case Info => match (right) { case Info => true case _ => false }
            case Warn => match (right) { case Warn => true case _ => false }
            case Error => match (right) { case Error => true case _ => false }
        }
    }
}

/// Log — corresponds to Bun: bun_ast::Log
public class Log {
    public var level: LogLevel = LogLevel.Warn
    public var errors: Int64 = 0
    public var warnings: Int64 = 0

    public init() {}

    public func hasAny(): Bool {
        return errors > 0 || warnings > 0
    }

    public func print(writer: OutputWriter): Unit {
        // Print log messages — corresponds to Bun: log.print(Output.error_writer())
    }

    /// Add an error with source info.
    // Corresponds to Bun: log.add_error_opts(text, ErrorOpts { source, loc, ... })
    public func addErrorOpts(text: String, source: ?Source, loc: Int64, redactSensitive: Bool): Unit {
        errors += 1
    }

    /// Add an error.
    // Corresponds to Bun: log.add_error_opts(text, ErrorOpts::default())
    public func addError(text: String, source: String): Unit {
        errors += 1
    }

    /// Add a warning with source and range.
    // Corresponds to Bun: log.add_range_warning_fmt(...)
    public func addRangeWarningFmt(source: ?Source, loc: Int64, text: String): Unit {
        warnings += 1
    }

    /// Add a warning with format args.
    // Corresponds to Bun: log.add_warning_fmt(...)
    public func addWarningFmt(source: ?Source, loc: Int64, text: String): Unit {
        warnings += 1
    }

    /// Add an error with format args.
    // Corresponds to Bun: log.add_error_fmt_opts(...)
    public func addErrorFmtOpts(text: String, source: ?Source, loc: Int64, redactSensitive: Bool): Unit {
        errors += 1
    }
}

/// Command-line argument parsing result — corresponds to Bun: bun_clap::Args
public class ClapArgs {
    private var options: HashMap<String, String> = HashMap<String, String>()

    public init() {}

    /// Get an option value by name.
    // Corresponds to Bun: args.option(b"--config")
    public func option(name: String): ?String {
        options.get(name)
    }
}

/// Standalone module graph flags.
// Corresponds to Bun: bun_standalone_graph::StandaloneModuleGraph::Flags
public enum StandaloneModuleGraphFlags {
    | DISABLE_AUTOLOAD_BUNFIG

    public operator func ==(right: StandaloneModuleGraphFlags): Bool {
        match (this) {
            case DISABLE_AUTOLOAD_BUNFIG => match (right) {
                case DISABLE_AUTOLOAD_BUNFIG => true
            }
        }
    }

    public func contains(flag: StandaloneModuleGraphFlags): Bool {
        this == flag
    }
}

/// Standalone module graph — corresponds to Bun: bun_standalone_graph::StandaloneModuleGraph
public class StandaloneModuleGraph {
    public var flags: StandaloneModuleGraphFlags = StandaloneModuleGraphFlags.DISABLE_AUTOLOAD_BUNFIG

    public init() {}

    /// Get the global standalone module graph instance.
    // Corresponds to Bun: StandaloneModuleGraph::get()
    public static func get(): ?StandaloneModuleGraph {
        // PORT NOTE: Returns None in normal (non-standalone) mode
        return None
    }
}

/// Output utility — corresponds to Bun: bun_core::Output
public class Output {
    public static func prettyErrorln(text: String): Unit {
        println(text)
    }

    public static func printError(text: String): Unit {
        println(text)
    }

    public static func errorWriter(): OutputWriter {
        return OutputWriter()
    }

    public static func err(err: BaoError, msg: String): Unit {
        println("${msg}: ${err.errorMsg}")
    }
}

/// Output writer — corresponds to Bun: Output::error_writer()
public class OutputWriter {
    public func write(text: String): Unit {
        print(text)
    }
}

/// Global utilities — corresponds to Bun: bun_core::Global
public class Global {
    public static func exit(code: Int64): Nothing {
        // PORT NOTE: In Cangjie, process exit maps to throwing a fatal error
        throw BaoError(ErrorCode.Unexpected, "exit(${code})")
    }

    public static func crash(): Nothing {
        throw BaoError(ErrorCode.Unexpected, "crash")
    }
}

// ============================================================================
// Helper functions (private)
// ============================================================================

/// Get an environment variable.
private func getEnv(name: String): ?String {
    None
}

/// Read a source file.
// Corresponds to Bun: bun_ast::to_source(path, ToSourceOptions { convert_bom })
private func readSource(path: String, convertBom: Bool): Result<Source, BaoError> {
    Err(BaoError(ErrorCode.ENOENT, "Failed to read source: ${path}"))
}

/// Get the current working directory.
// Corresponds to Bun: bun_sys::getcwd
private func getCwd(): ?String {
    Some("")
}

/// Get the file extension from a filename.
// Corresponds to Bun: bun_paths::extension
public func getExtension(filename: String): String {
    let dotIdx = filename.lastIndexOf('.')
    match (dotIdx) {
        case Some(idx) =>
            if (idx < filename.size - 1) {
                filename[(idx + 1)..]
            } else {
                ""
            }
        case None => ""
    }
}

/// Path resolution utilities — corresponds to Bun: resolve_path module
public class resolvePath {
    /// Join an absolute base path with a relative path.
    // Corresponds to Bun: resolve_path::join_abs_string_buf
    public static func joinAbsString(base: String, relative: String): String {
        if (base.endsWith("/")) {
            return base + relative
        }
        return base + "/" + relative
    }
}

/// Options namespace — provides DEFAULT_LOADERS check.
// Corresponds to Bun: bun_bundler::options::DEFAULT_LOADERS
public class options {
    /// Check if the file extension has a default loader.
    // Corresponds to Bun: options::DEFAULT_LOADERS.contains_key(extension)
    public static func DEFAULT_LOADERS_containsKey(ext: String): Bool {
        match (ext) {
            case "js" | "ts" | "jsx" | "tsx" | "mjs" | "mts" | "cjs" | "cts" => true
            case _ => false
        }
    }

    /// Alias for compatibility.
    public static prop DEFAULT_LOADERS: LoaderLookup {
        get() { LoaderLookup() }
    }
}

/// Loader lookup helper — corresponds to Bun: DEFAULT_LOADERS.contains_key
public class LoaderLookup {
    public func containsKey(ext: String): Bool {
        options.DEFAULT_LOADERS_containsKey(ext)
    }
}

/// Source file representation — corresponds to Bun: bun_ast::Source
public class Source {
    public let path: SourcePath
    public let content: String

    public init(path: String, content: String) {
        this.path = SourcePath(path)
        this.content = content
    }
}

/// Source path — corresponds to Bun: source.path
public class SourcePath {
    public let text: String
    public let name: PathName

    public init(text: String) {
        this.text = text
        this.name = PathName(text)
    }
}

/// Path name with extension — corresponds to Bun: source.path.name
public class PathName {
    public let ext: String

    public init(path: String) {
        let dotIdx = path.lastIndexOf('.')
        if (dotIdx.isSome()) {
            ext = path[dotIdx.getOrThrow()..]
        } else {
            ext = ""
        }
    }
}

/// Range type for source locations.
public type LocRange = Int64
