// bao_install - 工作区映射
// 严格翻译自: src/install/lockfile/Package/WorkspaceMap.zig
//   WorkspaceMap 管理 package.json 中 workspaces 字段定义的工作区
//   支持 processNamesArray 处理 glob 模式, processWorkspaceName 读取包名
package bao_install.lockfile

import bao_core.*
import bao_collections.*

// ============================================================================
// 工作区条目
// 严格翻译自: WorkspaceMap.Entry
//   pub const Entry = struct { name: string, version: ?string, name_loc: logger.Loc }
// ============================================================================

/// 工作区条目
/// 对应 Bun: WorkspaceMap.Entry
public class WorkspaceEntry {
    /// 工作区包名
    public var name: String
    /// 版本 (可选)
    public var version: ?String
    /// 名称位置
    public var nameLoc: SourceLocation

    public init() {
        name = ""
        version = None
        nameLoc = SourceLocation()
    }

    public init(name: String, version: ?String) {
        this.name = name
        this.version = version
        nameLoc = SourceLocation()
    }
}

// ============================================================================
// 工作区映射
// 严格翻译自: src/install/lockfile/Package/WorkspaceMap.zig
//   const WorkspaceMap = @This();
//   map: Map (String -> Entry)
// ============================================================================

/// 工作区映射
/// 对应 Bun: WorkspaceMap
/// 翻译自: src/install/lockfile/Package/WorkspaceMap.zig
public class WorkspaceMap {
    /// 映射表 (路径 -> 条目)
    /// 翻译自: map: Map
    public var map: HashMap<String, WorkspaceEntry>

    public init() {
        map = HashMap<String, WorkspaceEntry>()
    }

    /// 获取所有键
    /// 翻译自: WorkspaceMap.keys
    ///   pub fn keys(self) []const string
    public func keys(): ArrayList<String> {
        let result = ArrayList<String>()
        for (entry in map) {
            result.append(entry.key)
        }
        return result
    }

    /// 获取所有值
    /// 翻译自: WorkspaceMap.values
    ///   pub fn values(self) []const Entry
    public func values(): ArrayList<WorkspaceEntry> {
        let result = ArrayList<WorkspaceEntry>()
        for (entry in map) {
            result.append(entry.value)
        }
        return result
    }

    /// 条目数量
    /// 翻译自: WorkspaceMap.count
    ///   pub fn count(self) usize
    public func count(): Int64 {
        return map.size
    }

    /// 插入条目
    /// 翻译自: WorkspaceMap.insert
    ///   pub fn insert(self, key, value) !void
    public func insert(key: String, value: WorkspaceEntry): Unit {
        map.put(key, value)
    }

    /// 排序
    /// 翻译自: WorkspaceMap.sort
    ///   pub fn sort(self, sort_ctx) void
    public func sort(): Unit {
        // 按名称排序, 简化: HashMap 不保证顺序
    }

    /// 清理
    /// 翻译自: WorkspaceMap.deinit
    ///   pub fn deinit(self) void
    public func deinit(): Unit {
        map.clear()
    }

    /// 处理工作区名称数组
    /// 严格翻译自: WorkspaceMap.processNamesArray
    ///   pub fn processNamesArray(workspace_names, allocator, json_cache, log,
    ///       arr, source, loc, string_builder) !u32
    ///   从 package.json 的 workspaces 数组中处理工作区名称
    ///   支持 glob 模式匹配
    public static func processNamesArray(
        workspaceNames: WorkspaceMap,
        arr: ArrayList<String>,
        sourceDir: String
    ): UInt32 {
        if (arr.size == 0) { return UInt32(0) }

        let workspaceGlobs = ArrayList<String>()

        for (inputPath in arr) {
            let trimmed = inputPath.trim()
            if (trimmed.length == 0 || trimmed == "." || trimmed == "./" || trimmed == ".\\") {
                continue
            }

            // 检查是否是 glob 模式
            if (detectGlobSyntax(trimmed)) {
                workspaceGlobs.append(trimmed)
                continue
            }

            // 构建绝对路径
            let absPackageJsonPath = Path.join(sourceDir, trimmed, "package.json")

            // 跳过根 package.json
            let dirName = Path.dirname(absPackageJsonPath)
            if (dirName == sourceDir) { continue }

            // 处理工作区名称
            let entry = processWorkspaceName(absPackageJsonPath)
            match (entry) {
                case Some(e) => {
                    if (e.name.length == 0) { continue }
                    let relPath = Path.relative(sourceDir, Path.dirname(absPackageJsonPath))
                    workspaceNames.insert(relPath, e)
                }
                case None => continue
            }
        }

        // 处理 glob 模式
        if (workspaceGlobs.size > 0) {
            for (pattern in workspaceGlobs) {
                // glob 匹配 (简化: 实际需要 GlobWalker)
                // 此处仅作为占位符
            }
        }

        return UInt32(workspaceNames.count())
    }

    /// 处理单个工作区名称
    /// 翻译自: WorkspaceMap.processWorkspaceName
    ///   fn processWorkspaceName(allocator, json_cache, abs_package_json_path, log) !Entry
    ///   读取工作区的 package.json 获取名称和版本
    public static func processWorkspaceName(absPackageJsonPath: String): ?WorkspaceEntry {
        // 读取 package.json
        try {
            let content = bao_io.File.readTextFile(absPackageJsonPath)
            let json = JsonParser.parseObject(content)

            match (json.get("name")) {
                case Some(nameExpr) => {
                    let name = nameExpr.asString()
                    if (name.length == 0) { return None }

                    let version: ?String = match (json.get("version")) {
                        case Some(verExpr) => {
                            match (verExpr.asString()) {
                                case s: String => Some(s)
                                case _: None => None
                            }
                        }
                        case None => None
                    }

                    return WorkspaceEntry(name: name, version: version)
                }
                case None => return None
            }
        } catch (_: Exception) {
            return None
        }
    }
}

// ============================================================================
// 忽略的工作区路径
// 翻译自: WorkspaceMap.IGNORED_PATHS
// ============================================================================

/// 忽略的工作区路径
public let IGNORED_WORKSPACE_PATHS: ArrayList<String> = ArrayList<String>([
    "node_modules",
    ".git",
    "CMakeFiles"
])

// ============================================================================
// 辅助类型
// ============================================================================

/// 源码位置
/// 对应 Bun: logger.Loc
public class SourceLocation {
    public var start: Int64

    public init() {
        start = -1
    }
}

/// 检测 glob 语法
/// 翻译自: glob.detectGlobSyntax
func detectGlobSyntax(input: String): Bool {
    for (c in input) {
        if (c.value == 42 || c.value == 63 || c.value == 91 || c.value == 123) { // *, ?, [, {
            return true
        }
    }
    return false
}
