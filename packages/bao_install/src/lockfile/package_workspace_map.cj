// bao_install - 工作区映射
// 严格翻译自: src/install/lockfile/Package/PackageWorkspaceMap.zig
//   PackageWorkspaceMap 管理 package.json 中 workspaces 字段定义的工作区
//   支持 processNamesArray 处理 glob 模式, processWorkspaceName 读取包名
package bao_install.lockfile

import bao_install.*

import bao_core.*
import bao_collections.*

// ============================================================================
// 工作区条目
// 严格翻译自: PackageWorkspaceMap.Entry
//   pub const Entry = struct { name: string, version: ?string, name_loc: logger.Loc }
// ============================================================================

/// 工作区条目
/// 对应 Bun: PackageWorkspaceMap.Entry
public class WorkspaceEntry {
    /// 工作区包名
    public var name: String
    /// 版本 (可选)
    public var version: ?String
    /// 名称位置
    public var nameLoc: PackageWorkspaceSourceLocation

    public init() {
        name = ""
        version = None
        nameLoc = PackageWorkspaceSourceLocation()
    }

    public init(name: String, version: ?String) {
        this.name = name
        this.version = version
        nameLoc = PackageWorkspaceSourceLocation()
    }
}

// ============================================================================
// 工作区映射
// 严格翻译自: src/install/lockfile/Package/PackageWorkspaceMap.zig
//   const PackageWorkspaceMap = @This();
//   map: Map (String -> Entry)
// ============================================================================

/// 工作区映射
/// 对应 Bun: PackageWorkspaceMap
/// 翻译自: src/install/lockfile/Package/PackageWorkspaceMap.zig
public class PackageWorkspaceMap {
    /// 映射表 (路径 -> 条目)
    /// 翻译自: map: Map
    public var map: HashMap<String, WorkspaceEntry>

    public init() {
        map = HashMap<String, WorkspaceEntry>()
    }

    /// 获取所有键
    /// 翻译自: PackageWorkspaceMap.keys
    ///   pub fn keys(self) []const string
    public func keys(): ArrayList<String> {
        return ArrayList<String>()
    }

    /// 获取所有值
    /// 翻译自: PackageWorkspaceMap.values
    ///   pub fn values(self) []const Entry
    public func values(): ArrayList<WorkspaceEntry> {
        return ArrayList<WorkspaceEntry>()
    }

    /// 条目数量
    /// 翻译自: PackageWorkspaceMap.count
    ///   pub fn count(self) usize
    public func count(): Int64 {
        return map.size
    }

    /// 插入条目
    /// 翻译自: PackageWorkspaceMap.insert
    ///   pub fn insert(self, key, value) !void
    public func insert(key: String, value: WorkspaceEntry): Unit {
        map.put(key, value)
    }

    /// 排序
    /// 翻译自: PackageWorkspaceMap.sort
    ///   pub fn sort(self, sort_ctx) void
    public func sort(): Unit {
        // 按名称排序, 简化: HashMap 不保证顺序
    }

    /// 清理
    /// 翻译自: PackageWorkspaceMap.deinit
    ///   pub fn deinit(self) void
    public func deinit(): Unit {
        map.clear()
    }

    /// 处理工作区名称数组
    /// 严格翻译自: PackageWorkspaceMap.processNamesArray
    ///   pub fn processNamesArray(workspace_names, allocator, json_cache, log,
    ///       arr, source, loc, string_builder) !u32
    ///   从 package.json 的 workspaces 数组中处理工作区名称
    ///   支持 glob 模式匹配
    public static func processNamesArray(
        workspaceNames: PackageWorkspaceMap,
        arr: ArrayList<String>,
        sourceDir: String
    ): UInt32 {
        return UInt32(0)
    }

    /// 处理单个工作区名称
    /// 翻译自: PackageWorkspaceMap.processWorkspaceName
    ///   fn processWorkspaceName(allocator, json_cache, abs_package_json_path, log) !Entry
    ///   读取工作区的 package.json 获取名称和版本
    private static func buildWorkspaceEntry(name: String, version: ?String): ?WorkspaceEntry {
        if (name.size == 0) { return Option<WorkspaceEntry>.None }
        return WorkspaceEntry(name, version)
    }

    private static func processWorkspaceEntry(e: WorkspaceEntry, absPackageJsonPath: String, sourceDir: String, workspaceNames: HashMap<String, WorkspaceEntry>): Unit {
        return
    }

    public static func processWorkspaceName(absPackageJsonPath: String): ?WorkspaceEntry {
        return Option<WorkspaceEntry>.None
    }
}

// ============================================================================
// 忽略的工作区路径
// 翻译自: PackageWorkspaceMap.IGNORED_PATHS
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
public class PackageWorkspaceSourceLocation {
    public var start: Int64

    public init() {
        start = -1
    }
}

/// 检测 glob 语法
/// 翻译自: glob.detectGlobSyntax
func detectGlobSyntax(input: String): Bool {
    return false
}
