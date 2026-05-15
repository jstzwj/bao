// bao_install - 后安装优化器
// 严格翻译自: src/install/postinstall_optimizer.zig
//   postinstall_optimizer.zig 负责在后安装阶段优化包:
//   - native_binlink: 将平台特定的二进制文件直接链接 (跳过脚本)
//   - ignore: 跳过生命周期脚本 (如 esbuild)
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 后安装优化模式
// 严格翻译自: src/install/postinstall_optimizer.zig
//   pub const PostinstallOptimizer = enum {
//       native_binlink,
//       ignore,
//   }
// ============================================================================

/// 后安装优化模式
/// 对应 Bun: PostinstallOptimizer
public enum PostinstallOptimizer {
    | NativeBinlink   // 本地二进制链接 (跳过脚本, 直接链接平台二进制)
    | Ignore          // 忽略生命周期脚本

    public func name(): String {
        match (this) {
            case NativeBinlink => "native_binlink"
            case Ignore => "ignore"
        }
    }
}

// ============================================================================
// 默认本地二进制链接包名哈希
// 严格翻译自: postinstall_optimizer.zig
//   const default_native_binlinks_name_hashes = &[_]PackageNameHash{
//       Semver.String.Builder.stringHash("esbuild"),
//       Semver.String.Builder.stringHash("@anthropic-ai/claude-code"),
//   }
// ============================================================================

/// 默认本地二进制链接包列表
/// 翻译自: default_native_binlinks_name_hashes
public class DefaultNativeBinlinks {
    public static let PACKAGES: ArrayList<String> = ArrayList<String>([
        "esbuild",
        "@anthropic-ai/claude-code"
    ])

    /// 检查包名是否匹配
    public static func contains(name: String): Bool {
        for (pkg in PACKAGES) {
            if (pkg == name) { return true }
        }
        return false
    }
}

// ============================================================================
// 默认忽略配置
// 严格翻译自: postinstall_optimizer.zig
//   const DefaultIgnore = struct {
//       name_hash: PackageNameHash,
//       minimum_version: Semver.Version,
//   }
//   const default_ignore = [1]DefaultIgnore{ .{ ... sharp >= 0.33.0 ... } }
// ============================================================================

/// 默认忽略条目
/// 翻译自: DefaultIgnore
public class DefaultIgnoreEntry {
    /// 包名
    public let name: String
    /// 最低版本
    public let minimumVersion: String

    public init(name: String, minimumVersion: String) {
        this.name = name
        this.minimumVersion = minimumVersion
    }
}

/// 默认忽略列表
/// 翻译自: default_ignore
public class DefaultIgnoreList {
    /// sharp >= 0.33.0
    public static let ENTRIES: ArrayList<DefaultIgnoreEntry> = ArrayList<DefaultIgnoreEntry>([
        DefaultIgnoreEntry(name: "sharp", minimumVersion: "0.33.0")
    ])

    /// 检查包是否在默认忽略列表中
    public static func shouldIgnore(name: String, version: ?String): Bool {
        for (entry in ENTRIES) {
            if (entry.name == name) {
                match (version) {
                    case Some(v) => {
                        // 检查版本是否 >= minimumVersion
                        let minVer = SemVer.parse(entry.minimumVersion)
                        let pkgVer = SemVer.parse(v)
                        match (minVer) {
                            case Some(min) => {
                                match (pkgVer) {
                                    case Some(pkg) => return pkg.compare(min) >= 0
                                    case None => return true
                                }
                            }
                            case None => return true
                        }
                    }
                    case None => return true
                }
            }
        }
        return false
    }
}

// ============================================================================
// 后安装优化列表
// 严格翻译自: postinstall_optimizer.zig
//   pub const List = struct {
//       dynamic: Map = .{},
//       disable_default_native_binlinks: bool = false,
//       disable_default_ignore: bool = false,
//       ...
//   }
// ============================================================================

/// 后安装优化列表
/// 对应 Bun: PostinstallOptimizer.List
public class PostinstallOptimizerList {
    /// 动态配置映射 (包名 -> 优化模式)
    /// 翻译自: dynamic: Map
    public var dynamic: HashMap<String, PostinstallOptimizer>
    /// 是否禁用默认 native binlinks
    /// 翻译自: disable_default_native_binlinks
    public var disableDefaultNativeBinlinks: Bool
    /// 是否禁用默认忽略
    /// 翻译自: disable_default_ignore
    public var disableDefaultIgnore: Bool

    public init() {
        dynamic = HashMap<String, PostinstallOptimizer>()
        disableDefaultNativeBinlinks = false
        disableDefaultIgnore = false
    }

    /// native binlink 是否启用
    /// 翻译自: List.isNativeBinlinkEnabled
    public func isNativeBinlinkEnabled(): Bool {
        if (dynamic.keys().size == 0) {
            if (disableDefaultNativeBinlinks) {
                return true
            }
        }
        return true
    }

    /// 从 package.json 解析配置
    /// 翻译自: PostinstallOptimizer.fromPackageJSON
    public func fromPackageJSON(config: HashMap<String, JsonValue>): Unit {
        // 解析 nativeDependencies
        match (config.get("nativeDependencies")) {
            case Some(JsonValue.Array(arr)) => {
                for (item in arr) {
                    match (item) {
                        case JsonValue.Str(name) => {
                            if (name.length > 0) {
                                dynamic.put(name, PostinstallOptimizer.NativeBinlink)
                            }
                        }
                        case _ => ()
                    }
                }
            }
            case _ => ()
        }

        // 解析 ignoreScripts
        match (config.get("ignoreScripts")) {
            case Some(JsonValue.Array(arr)) => {
                for (item in arr) {
                    match (item) {
                        case JsonValue.Str(name) => {
                            if (name.length > 0) {
                                dynamic.put(name, PostinstallOptimizer.Ignore)
                            }
                        }
                        case _ => ()
                    }
                }
            }
            case _ => ()
        }
    }

    /// 获取包的优化模式
    /// 翻译自: List.get
    public func getOptimizationMode(
        packageName: String,
        packageVersion: ?String
    ): ?PostinstallOptimizer {
        // 先检查动态配置
        match (dynamic.get(packageName)) {
            case Some(mode) => return mode
            case None => ()
        }

        // 检查默认 native binlinks
        if (!disableDefaultNativeBinlinks && DefaultNativeBinlinks.contains(packageName)) {
            return PostinstallOptimizer.NativeBinlink
        }

        // 检查默认忽略
        if (!disableDefaultIgnore && DefaultIgnoreList.shouldIgnore(packageName, packageVersion)) {
            return PostinstallOptimizer.Ignore
        }

        return None
    }

    /// 是否应该忽略生命周期脚本
    /// 严格翻译自: List.shouldIgnoreLifecycleScripts
    public func shouldIgnoreLifecycleScripts(
        packageName: String,
        packageVersion: ?String,
        resolutions: ArrayList<UInt32>,
        metas: ArrayList<PackageMeta>,
        targetCpu: String,
        targetOs: String,
        treeId: ?UInt32
    ): Bool {
        let mode = getOptimizationMode(packageName, packageVersion)
        match (mode) {
            case Some(m) => {
                match (m) {
                    case PostinstallOptimizer.NativeBinlink => {
                        // native_binlink: 只有在 tree_id 为 0 且找到平台特定依赖时才生效
                        let isRootTree = match (treeId) {
                            case Some(id) => id == UInt32(0)
                            case None => true
                        }
                        return isRootTree && getNativeBinlinkReplacementPackageId(
                            resolutions: resolutions,
                            metas: metas,
                            targetCpu: targetCpu,
                            targetOs: targetOs
                        ) != None
                    }
                    case PostinstallOptimizer.Ignore => return true
                }
            }
            case None => return false
        }
    }

    /// 获取 native binlink 替换包 ID
    /// 翻译自: PostinstallOptimizer.getNativeBinlinkReplacementPackageID
    public static func getNativeBinlinkReplacementPackageId(
        resolutions: ArrayList<UInt32>,
        metas: ArrayList<PackageMeta>,
        targetCpu: String,
        targetOs: String
    ): ?UInt32 {
        // 遍历可选依赖, 查找平台特定的匹配
        // 翻译自: loop through resolutions, check meta.arch + meta.os
        for (resolution in resolutions) {
            if (Int64(resolution) >= metas.size) { continue }
            let meta = metas[Int64(resolution)]
            if (meta.os.size == 0 && meta.cpu.size == 0) { continue }

            // 检查平台匹配
            var cpuMatch = meta.cpu.size == 0
            var osMatch = meta.os.size == 0
            for (cpu in meta.cpu) {
                if (cpu == targetCpu) { cpuMatch = true }
            }
            for (os in meta.os) {
                if (os == targetOs) { osMatch = true }
            }

            if (cpuMatch && osMatch) {
                return Some(resolution)
            }
        }
        return None
    }
}
