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
            case ReadError(err) => return None
            case ParseError(err) => return None
        }
    }

    /// 获取错误消息
    public func errorMessage(): ?String {
        match (this) {
            case ReadError(err) => return err
            case ParseError(err) => return err
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

        // 从磁盘读取
        let source = try {
            bao_io.File.readTextFile(absPackageJsonPath)
        } catch (e: Exception) {
            return PackageJsonGetResult.ReadError(e.message)
        }

        // 解析 JSON
        let json = try {
            bao_json.JsonParser.parse(source)
        } catch (e: Exception) {
            return PackageJsonGetResult.ParseError(e.message)
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

        // 解析 JSON
        let json = try {
            bao_json.JsonParser.parse(source)
        } catch (e: Exception) {
            return PackageJsonGetResult.ParseError(e.message)
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

    // 猜测缩进风格
    private static func guessIndentation(source: String): String {
        // 查找第一个缩进行
        let lines = source.split("\n")
        for (line in lines) {
            if (line.length > 0 && (line[0].value == 32 || line[0].value == 9)) { // 空格或制表符
                var spaces = 0
                var tabs = 0
                for (c in line) {
                    if (c.value == 32) { spaces += 1 }
                    else if (c.value == 9) { tabs += 1 }
                    else { break }
                }
                if (tabs > 0) { return "\t" }
                if (spaces >= 2) { return "  " }
                if (spaces >= 4) { return "    " }
                return "  "
            }
        }
        return "  "
    }
}
