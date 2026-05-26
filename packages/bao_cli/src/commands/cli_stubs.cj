// CLI command stubs - shared types used by multiple command files
// These are stub implementations to allow compilation while the full
// implementations in the parent bao_cli package are not importable.
package bao_cli.commands

import bao_core.*
import bao_collections.*

// ============================================================================
// Logger - CLI logging utility
// ============================================================================

/// CLI 日志器
/// 翻译自: src/cli/logger.zig
public class Logger {
    public var verbose: Bool
    private var level: Int64

    public init() {
        verbose = false
        level = 1
    }

    public func info(msg: String): Unit {
        println(msg)
    }

    public func warn(msg: String): Unit {
        println("warn: ${msg}")
    }

    public func error(msg: String): Unit {
        println("error: ${msg}")
    }

    public func debug(msg: String): Unit {
        if (verbose) {
            println("debug: ${msg}")
        }
    }

    public func setLevel(l: Int64): Unit {
        level = l
    }
}

// ============================================================================
// Config - Bunfig.toml configuration
// ============================================================================

/// 配置
/// 翻译自: src/cli/config.zig
public class Config {
    public var registry: ?String
    public var cacheDir: ?String

    public init() {
        registry = None
        cacheDir = None
    }

    public static func load(dir: String): Config {
        return Config()
    }
}

// ============================================================================
// InitOptions - bun init options
// ============================================================================

/// Init 命令选项
/// 翻译自: src/cli/init_command.zig InitOptions
public class InitOptions {
    public var name: String
    public var force: Bool
    public var interactive: Bool
    public var noGit: Bool
    public var noInstall: Bool
    public var yes: Bool

    public init() {
        name = ""
        force = false
        interactive = true
        noGit = false
        noInstall = false
        yes = false
    }
}

// ============================================================================
// MutablePackageJson - mutable package.json representation
// ============================================================================

/// 可变的 package.json 表示
/// 翻译自: MutablePackageJson in Bun src/install/package-json.zig
public class MutablePackageJson {
    public var name: String
    public var version: String
    public var dependencies: HashMap<String, String>
    public var devDependencies: HashMap<String, String>
    public var optionalDependencies: HashMap<String, String>
    public var peerDependencies: HashMap<String, String>

    public init(name: String, version: String) {
        this.name = name
        this.version = version
        dependencies = HashMap<String, String>()
        devDependencies = HashMap<String, String>()
        optionalDependencies = HashMap<String, String>()
        peerDependencies = HashMap<String, String>()
    }

    public static func fromJson(root: JsonValue): ?MutablePackageJson {
        return None
    }

    public func save(dir: String): Unit {}
    public func rollback(dir: String): Unit {}
    public func addDependency(name: String, version: String): Unit {}
    public func addDevDependency(name: String, version: String): Unit {}
    public func addOptionalDependency(name: String, version: String): Unit {}
    public func addPeerDependency(name: String, version: String): Unit {}
    public func removeDependency(name: String): Bool { return false }
}

// ============================================================================
// JSON types - stubs for JSON parsing
// ============================================================================

/// JSON 值
public class JsonValue {}

/// JSON 解析器
public class JsonParser {
    public init() {}

    public func parse(text: String): ?JsonValue {
        return None
    }
}

// ============================================================================
// PackageManager - stub for publish command
// ============================================================================

/// 包管理器 stub
public class PackageManager {
    public init() {}
    public func install(ctx: CommandContext): Unit {}
    public func addPackage(ctx: CommandContext, name: String, version: String): Unit {}
}

// ============================================================================
// CommandContext - stub for run command
// ============================================================================

/// 命令上下文 stub
public class CommandContext {
    public init() {}
}
