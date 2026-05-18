// bao_install.lockfile - Workspace 映射
// 严格翻译自: src/install/lockfile/Package/WorkspaceMap.zig
//   WorkspaceMap 维护 workspace 包名到路径/版本的映射
//   用于解析 workspace 协议依赖时查找对应的包
package bao_install.lockfile

import bao_install.*
import bao_core.*
import bao_collections.*

// ============================================================================
// Workspace 映射条目
// 严格翻译自: WorkspaceMap.Entry
//   pub const Entry = struct {
//       name: string,
//       version: ?string,
//       name_loc: logger.Loc,
//   }
// ============================================================================

/// Workspace 映射条目
/// 翻译自: WorkspaceMap.Entry
public class WorkspaceMapEntry {
    /// workspace 包名
    /// 翻译自: name: string
    public var name: String

    /// workspace 包版本 (可选)
    /// 翻译自: version: ?string
    public var version: ?String

    /// 名称位置 (用于日志)
    /// 翻译自: name_loc: logger.Loc
    public var nameLoc: SourceLocation

    public init(name: String) {
        this.name = name
        version = None
        nameLoc = SourceLocation()
    }

    public init(name: String, version: ?String) {
        this.name = name
        this.version = version
        nameLoc = SourceLocation()
    }

    public init(name: String, version: ?String, nameLoc: SourceLocation) {
        this.name = name
        this.version = version
        this.nameLoc = nameLoc
    }
}

/// 源码位置
/// 翻译自: logger.Loc
public class SourceLocation {
    public var start: Int64

    public init() {
        start = Int64(0)
    }

    public init(start: Int64) {
        this.start = start
    }
}

// ============================================================================
// Workspace 映射
// 严格翻译自: WorkspaceMap
//   pub const WorkspaceMap = struct {
//       map: Map,  // StringArrayHashMap(Entry)
//   }
//   提供从 workspace 路径到包名的映射
//   用于解析 workspace:* 和 workspace:^ 协议依赖
// ============================================================================

/// Workspace 映射
/// 翻译自: WorkspaceMap
///   维护 workspace 路径 -> Entry(name, version) 的映射
public class WorkspaceMap {
    /// 内部映射: 路径 -> Entry
    /// 翻译自: map: StringArrayHashMap(Entry)
    private var map: HashMap<String, WorkspaceMapEntry>

    /// 键的排序列表 (用于有序遍历)
    /// 翻译自: StringArrayHashMap 保持插入顺序
    private var keyList: ArrayList<String>

    public init() {
        map = HashMap<String, WorkspaceMapEntry>()
        keyList = ArrayList<String>()
    }

    /// 获取所有键
    /// 翻译自: WorkspaceMap.keys
    ///   pub fn keys(self) []const string
    public func keys(): ArrayList<String> {
        return keyList
    }

    /// 获取所有值
    /// 翻译自: WorkspaceMap.values
    ///   pub fn values(self) []const Entry
    public func values(): ArrayList<WorkspaceMapEntry> {
        let result = ArrayList<WorkspaceMapEntry>()
        for (key in keyList) {
            match (map.get(key)) {
                case Some(entry) => result.append(entry)
                case None => ()
            }
        }
        return result
    }

    /// 获取条目数
    /// 翻译自: WorkspaceMap.count
    ///   pub fn count(self) usize
    public func count(): Int64 {
        return keyList.size
    }

    /// 插入条目
    /// 翻译自: WorkspaceMap.insert
    ///   pub fn insert(self, key: string, value: Entry) !void
    ///   在 Debug 模式下验证 key 路径是否存在
    public func insert(key: String, value: WorkspaceMapEntry): Unit {
        match (map.get(key)) {
            case Some(_) =>
                // 已存在, 更新值
                map.put(key, value)
            case None =>
                // 新条目
                keyList.append(key)
                map.put(key, value)
        }
    }

    /// 获取条目
    /// 翻译自: WorkspaceMap.get (via map.get)
    public func get(key: String): ?WorkspaceMapEntry {
        return map.get(key)
    }

    /// 检查是否包含键
    public func contains(key: String): Bool {
        return map.contains(key)
    }

    /// 排序
    /// 翻译自: WorkspaceMap.sort
    ///   pub fn sort(self, sort_ctx) void
    ///   按键名字母顺序排序
    public func sort(): Unit {
        // 冒泡排序 (简化实现)
        var i: Int64 = 0
        while (i < keyList.size - 1) {
            var j: Int64 = 0
            while (j < keyList.size - 1 - i) {
                if (keyList[j].compareTo(keyList[j + 1]) > 0) {
                    let tmp = keyList[j]
                    keyList[j] = keyList[j + 1]
                    keyList[j + 1] = tmp
                }
                j += 1
            }
            i += 1
        }
    }

    /// 处理 workspace 名称
    /// 翻译自: WorkspaceMap.processWorkspaceName
    ///   读取 workspace 的 package.json, 提取 name 和 version
    ///   pub fn processWorkspaceName(allocator, json_cache, abs_package_json_path, log) !Entry
    public static func processWorkspaceName(
        absPackageJsonPath: String
    ): ?WorkspaceMapEntry {
        // 翻译自:
        //   1. json_cache.getWithPath(allocator, log, abs_package_json_path, .{...})
        //   2. 从 JSON 中读取 "name" 字段
        //   3. 从 JSON 中读取 "version" 字段 (可选)
        let content = BaoFile.readAllText(absPackageJsonPath)
        match (content) {
            case SysMaybe<String>.Ok(text) =>
                let parser = JsonParser()
                let json = parser.parse(text)
                if (let Some(JsonValue.Object(root)) <- json) {
                    var name = ""
                    var version: ?String = None

                    match (root.get("name")) {
                        case Some(JsonValue.Str(n)) => name = n
                        case _ => return None
                    }

                    match (root.get("version")) {
                        case Some(JsonValue.Str(v)) => version = v
                        case _ => ()
                    }

                    if (name.size == 0) { return None }

                    return WorkspaceMapEntry(name, version)
                }
                return None
            case SysMaybe<String>.Err(_) => return None
        }
    }

    /// 清空映射
    /// 翻译自: WorkspaceMap.deinit (只清空数据, 不释放内存)
    public func clear(): Unit {
        map = HashMap<String, WorkspaceMapEntry>()
        keyList = ArrayList<String>()
    }
}
