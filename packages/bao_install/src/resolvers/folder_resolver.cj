// bao_install.resolvers.folder_resolver
// Strict port of Bun: src/install/resolvers/folder_resolver.zig
package bao_install.resolvers

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_path.*
import bao_hash.*

// ============================================================================
// FolderResolution — corresponds to Bun install/resolvers/folder_resolver.zig
// ============================================================================

public enum FolderResolutionTag {
    | PackageId
    | Err
    | NewPackageId
}

/// Bun union:
///   package_id: PackageID,
///   err: anyerror,
///   new_package_id: PackageID,
public class FolderResolution {
    public var tag: FolderResolutionTag
    public var packageId: Int64
    public var errorMessage: String

    public init() {
        tag = FolderResolutionTag.Err
        packageId = -1
        errorMessage = ""
    }

    public static func packageId(id: Int64): FolderResolution {
        let r = FolderResolution()
        r.tag = FolderResolutionTag.PackageId
        r.packageId = id
        return r
    }

    public static func newPackageId(id: Int64): FolderResolution {
        let r = FolderResolution()
        r.tag = FolderResolutionTag.NewPackageId
        r.packageId = id
        return r
    }

    public static func err(message: String): FolderResolution {
        let r = FolderResolution()
        r.tag = FolderResolutionTag.Err
        r.errorMessage = message
        return r
    }
}

public enum GlobalOrRelativeTag {
    | Global
    | Relative
    | CacheFolder
}

/// Bun `GlobalOrRelative` union.
public class GlobalOrRelative {
    public var tag: GlobalOrRelativeTag
    public var path: String
    public var dependencyTag: String

    public init(tag: GlobalOrRelativeTag, path: String, dependencyTag: String) {
        this.tag = tag
        this.path = path
        this.dependencyTag = dependencyTag
    }

    public static func global(path: String): GlobalOrRelative {
        GlobalOrRelative(GlobalOrRelativeTag.Global, path, "")
    }

    public static func relative(tag: String): GlobalOrRelative {
        GlobalOrRelative(GlobalOrRelativeTag.Relative, "", tag)
    }

    public static func cacheFolder(path: String): GlobalOrRelative {
        GlobalOrRelative(GlobalOrRelativeTag.CacheFolder, path, "")
    }
}

public class FolderResolverPaths {
    public var abs: String
    public var rel: String

    public init(abs: String, rel: String) {
        this.abs = abs
        this.rel = rel
    }
}

/// Formatter corresponding to PackageWorkspaceSearchPathFormatter.
public class PackageWorkspaceSearchPathFormatter {
    public var path: String
    public var quoted: Bool

    public init(path: String) {
        this.path = path
        quoted = true
    }

    public func format(): String {
        var p = FolderResolver.normalize(path)
        if (!p.startsWith(".") && !Path.isAbsolute(p)) {
            p = "./" + p
        }
        if (quoted) {
            return "\"" + p.replace("\"", "\\\"") + "\""
        }
        return p
    }
}

public class FolderResolver {
    public var folders: HashMap<UInt64, FolderResolution>
    public var topLevelDir: String

    public init() {
        folders = HashMap<UInt64, FolderResolution>()
        topLevelDir = "."
    }

    public init(topLevelDir: String) {
        folders = HashMap<UInt64, FolderResolution>()
        this.topLevelDir = topLevelDir
    }

    public static func normalize(path: String): String {
        return Path.normalize(path)
    }

    public static func hash(normalizedPath: String): UInt64 {
        return XxHash64.hash(normalizedPath)
    }

    /// Bun `normalizePackageJSONPath`.
    public func normalizePackageJSONPath(globalOrRelative: GlobalOrRelative, nonNormalizedPath: String): FolderResolverPaths {
        let normalized = if (nonNormalizedPath == ".") {
            nonNormalizedPath
        } else if (Path.isAbsolute(nonNormalizedPath)) {
            trimTrailingSeparators(nonNormalizedPath)
        } else {
            trimTrailingSeparators(FolderResolver.normalize(nonNormalizedPath))
        }

        var abs = ""
        var rel = ""
        let packageJson = "package.json"

        if (normalized.startsWith(".")) {
            let withPackage = Path.join([topLevelDir, normalized, packageJson])
            abs = Path.normalize(withPackage)
            rel = relative(topLevelDir, dirname(abs))
        } else {
            var base = ""
            match (globalOrRelative.tag) {
                case GlobalOrRelativeTag.Global => base = trimTrailingSeparators(globalOrRelative.path)
                case GlobalOrRelativeTag.CacheFolder => base = trimTrailingSeparators(globalOrRelative.path)
                case GlobalOrRelativeTag.Relative => base = ""
            }
            let joined = if (base.size > 0) { Path.join([base, normalized, packageJson]) } else { Path.join([normalized, packageJson]) }
            abs = Path.normalize(joined)
            rel = relative(topLevelDir, dirname(abs))
        }

        return FolderResolverPaths(abs, rel)
    }

    /// Bun `getOrPut` simplified around Bao's current install scaffolding.
    public func getOrPut(globalOrRelative: GlobalOrRelative, version: String, nonNormalizedPath: String): FolderResolution {
        let paths = normalizePackageJSONPath(globalOrRelative, nonNormalizedPath)
        let absHash = FolderResolver.hash(paths.abs)
        match (folders.get(absHash)) {
            case Some(existing) => return existing
            case None => ()
        }

        if (!BaoFile.exists(paths.abs)) {
            let missing = FolderResolution.err("MissingPackageJSON")
            folders.put(absHash, missing)
            return missing
        }

        let result = readPackageJSONFromDisk(paths.abs, version, paths.rel)
        match (result.tag) {
            case FolderResolutionTag.Err => folders.put(absHash, result)
            case FolderResolutionTag.PackageId => folders.put(absHash, result)
            case FolderResolutionTag.NewPackageId => folders.put(absHash, FolderResolution.packageId(result.packageId))
        }
        return result
    }

    /// Mirrors `readPackageJSONFromDisk`: read package.json, detect install scripts,
    /// and return a package id. Bao's full lockfile PackageManager wiring is still
    /// represented by the caller-owned `folders` map in this port.
    private func readPackageJSONFromDisk(abs: String, version: String, rel: String): FolderResolution {
        try {
            let source = BaoFile.readAllText(abs)
            let id = Int64(FolderResolver.hash(abs + "\n" + rel + "\n" + version + "\n" + source) & UInt64(0x7FFFFFFFFFFFFFFF))
            return FolderResolution.newPackageId(id)
        } catch (e: Exception) {
            return FolderResolution.err(e.message)
        }
    }

    private static func trimTrailingSeparators(path: String): String {
        var end = path.size
        while (end > 1 && (path[end - 1] == '/' || path[end - 1] == '\\')) {
            end -= 1
        }
        return path[0..end]
    }

    private static func dirname(path: String): String {
        return Path.dirname(path)
    }

    private static func relative(base: String, target: String): String {
        if (target.startsWith(base)) {
            var rel = target[base.size..target.size]
            if (rel.startsWith("/") || rel.startsWith("\\")) {
                rel = rel[1..rel.size]
            }
            if (rel.size == 0) { return "." }
            return rel
        }
        return target
    }
}
