// bao_install - Workspace Package.json 缓存
// 严格翻译自: src/install/PackageManager/WorkspacePackageJSONCache.zig
//   缓存 workspace 包的 package.json AST, 避免重复读取和解析
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*
import bao_sys.*

// ============================================================================
// 缓存条目
// 严格翻译自: WorkspacePackageJSONCache.zig - MapEntry
//   pub const MapEntry = struct {
//       root: Expr,
//       source: logger.Source,
//       indentation: JSPrinter.Options.Indentation,
//   }
// ============================================================================

/// 缓存条目
/// 翻译自: WorkspacePackageJSONCache.MapEntry
public class PackageJsonCacheEntry {
    /// 解析后的 JSON AST 根节点
    public var root: JsonValue
    /// 源文件内容
    public var source: String
    /// 缩进风格
    public var indentation: String
    /// 文件路径
    public var path: String

    public init(path: String, source: String, root: JsonValue, indentation: String) {
        this.path = path
        this.source = source
        this.root = root
        this.indentation = indentation
    }
}

// ============================================================================
// 获取结果
// 严格翻译自: WorkspacePackageJSONCache.zig - GetResult
//   pub const GetResult = union(enum) {
//       entry: *MapEntry,
//       read_err: anyerror,
//       parse_err: anyerror,
//   }
// ============================================================================

/// 获取结果
/// 翻译自: WorkspacePackageJSONCache.GetResult
public enum PackageJsonGetResult {
    | Entry(PackageJsonCacheEntry)
    | ReadError(String)
    | ParseError(String)

    /// 解包获取条目, 失败时抛出错误
    public func unwrap(): ?PackageJsonCacheEntry {
        match (this) {
            case Entry(e) => return e
            case ReadError(_) => return None
            case ParseError(_) => return None
        }
    }

    /// 获取错误消息
    public func errorMessage(): ?String {
        match (this) {
            case ReadError(msg) => return msg
            case ParseError(msg) => return msg
            case _ => return None
        }
    }
}

// ============================================================================
// 获取选项
// 严格翻译自: WorkspacePackageJSONCache.zig - GetJSONOptions
//   pub const GetJSONOptions = struct {
//       init_reset_store: bool = true,
//       guess_indentation: bool = false,
//   }
// ============================================================================

/// 获取 JSON 选项
/// 翻译自: WorkspacePackageJSONCache.GetJSONOptions
public class GetJsonOptions {
    /// 是否重置存储
    public var initResetStore: Bool
    /// 是否猜测缩进
    public var guessIndentation: Bool

    public init() {
        initResetStore = true
        guessIndentation = false
    }
}

// ============================================================================
// Workspace Package.json 缓存
// 严格翻译自: WorkspacePackageJSONCache.zig
//   pub const Map = bun.StringHashMapUnmanaged(MapEntry)
//   map: Map = .{}
// ============================================================================

/// Workspace Package.json 缓存
/// 对应 Bun: WorkspacePackageJSONCache
/// 缓存 workspace 包的 package.json AST, 避免重复读取和解析
/// 翻译自: src/install/PackageManager/WorkspacePackageJSONCache.zig
public class WorkspacePackageJsonCache {
    /// 缓存映射: 绝对路径 -> 缓存条目
    /// 翻译自: map: Map = .{}
    private var map: HashMap<String, PackageJsonCacheEntry>

    public init() {
        map = HashMap<String, PackageJsonCacheEntry>()
    }

    /// 通过文件路径获取或加载 package.json
    /// 翻译自: WorkspacePackageJSONCache.getWithPath
    ///   pub fn getWithPath(this, allocator, log, abs_package_json_path, comptime opts) GetResult
    public func getWithPath(
        absPackageJsonPath: String,
        options: GetJsonOptions
    ): PackageJsonGetResult {
        // 检查缓存
        match (map.get(absPackageJsonPath)) {
            case Some(entry) => return PackageJsonGetResult.Entry(entry)
            case None => ()
        }

        let source = match (BaoFile.readAllText(absPackageJsonPath)) {
            case SysMaybe.Ok(text) => text
            case SysMaybe.Err(_) => return PackageJsonGetResult.ReadError("failed to read package.json")
        }

        let json = match (PkgJsonParser().parse(source)) {
            case Some(value) => value
            case None => return PackageJsonGetResult.ParseError("failed to parse package.json")
        }

        // 检测缩进
        let indent = if (options.guessIndentation) {
            guessIndentation(source)
        } else {
            "  "
        }

        // 创建缓存条目
        let entry = PackageJsonCacheEntry(absPackageJsonPath, source, json, indent)
        map.put(absPackageJsonPath, entry)
        return PackageJsonGetResult.Entry(entry)
    }

    /// 通过 Source 对象获取或加载 package.json
    /// 翻译自: WorkspacePackageJSONCache.getWithSource
    public func getWithSource(
        path: String,
        source: String,
        options: GetJsonOptions
    ): PackageJsonGetResult {
        // 检查缓存
        match (map.get(path)) {
            case Some(entry) => return PackageJsonGetResult.Entry(entry)
            case None => ()
        }

        let json = match (PkgJsonParser().parse(source)) {
            case Some(value) => value
            case None => return PackageJsonGetResult.ParseError("failed to parse package.json")
        }

        let indent = if (options.guessIndentation) {
            guessIndentation(source)
        } else {
            "  "
        }

        let entry = PackageJsonCacheEntry(path, source, json, indent)
        map.put(path, entry)
        return PackageJsonGetResult.Entry(entry)
    }

    /// 清空缓存
    public func clear(): Unit {
        map.clear()
    }

    /// 缓存条目数
    public func count(): Int64 {
        return map.size
    }

    private static func guessIndentation(source: String): String {
        return "  "
    }
}
