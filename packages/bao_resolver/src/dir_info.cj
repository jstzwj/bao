// 严格翻译自: src/resolver/dir_info.zig
// 目录信息缓存
package bao_resolver

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_path.*

// ============================================================================
// DirInfo — 目录信息缓存
// 严格翻译自: src/resolver/dir_info.zig - DirInfo
// 对应 Bun: resolver 中用于缓存目录元数据的不可变结构
//
// Bun 的 DirInfo 是解析器核心数据结构之一:
//   1. 缓存目录中是否存在 package.json / tsconfig.json
//   2. 记录父目录链, 支持向上查找 enclosing_browser_scope
//   3. 记录是否在 node_modules 中
//   4. 存储目录条目 (文件列表) 的索引
// ============================================================================

/// 目录信息标志
/// 对应 Bun: DirInfo.Flags
public enum DirInfoFlag {
    | IsNodeModules      // 当前目录是 node_modules
    | HasNodeModules     // 当前目录下有 node_modules 子目录
    | InsideNodeModules  // 当前目录在 node_modules 内部
}

/// 目录信息
/// 对应 Bun: dir_info.zig 中的 DirInfo struct
///
/// 这些对象是不可变的 (immutable)，通过 parent 指针形成树结构，
//  避免重复锁定缓存。Bun 利用 .bss 段分配避免内存泄漏。
public class DirInfo {
    /// 父目录的 DirInfo
    // 对应 Bun: parent: Index
    public var parent: ?DirInfo

    /// 包含有效 "browser" 字段的最近 package.json 所在目录
    // 对应 Bun: enclosing_browser_scope: Index
    public var enclosingBrowserScope: ?DirInfo

    /// browser 字段对应的 PackageJSON
    // 对应 Bun: package_json_for_browser_field: ?*const PackageJSON
    public var packageJsonForBrowserField: ?PackageJSON

    /// 包含 tsconfig.json 的最近目录
    // 对应 Bun: enclosing_tsconfig_json: ?*const TSConfigJSON
    public var enclosingTsconfigJson: ?TSConfigJSON

    /// 包围的 package.json (打包用)
    // 对应 Bun: enclosing_package_json: ?*PackageJSON
    // 最深层含有 "name" 字段的 package.json
    // 或者 `bun run` 时 name 可选
    // 参考: https://github.com/oven-sh/bun/issues/229
    public var enclosingPackageJson: ?PackageJSON

    /// 用于依赖解析的 package.json
    // 对应 Bun: package_json_for_dependencies: ?*PackageJSON
    public var packageJsonForDependencies: ?PackageJSON

    /// 绝对路径
    // 对应 Bun: abs_path: string
    public var absPath: String

    /// 目录条目索引 (文件列表缓存)
    // 对应 Bun: entries: Index
    public var entries: ?DirEntry

    /// 当前目录的 package.json (如果有)
    // 对应 Bun: package_json: ?*PackageJSON
    public var packageJson: ?PackageJSON

    /// 当前目录的 tsconfig.json (如果有)
    // 对应 Bun: tsconfig_json: ?*TSConfigJSON
    public var tsconfigJson: ?TSConfigJSON

    /// 解析符号链接后的真实绝对路径
    // 对应 Bun: abs_real_path: string
    public var absRealPath: String

    /// 标志位集合
    // 对应 Bun: flags: Flags.Set
    public var flags: HashSet<DirInfoFlag>

    public init() {
        parent = None
        enclosingBrowserScope = None
        packageJsonForBrowserField = None
        enclosingTsconfigJson = None
        enclosingPackageJson = None
        packageJsonForDependencies = None
        absPath = ""
        entries = None
        packageJson = None
        tsconfigJson = None
        absRealPath = ""
        flags = HashSet<DirInfoFlag>()
    }

    /// 目录下是否有 node_modules 子目录
    // 对应 Bun: hasNodeModules()
    public func hasNodeModules(): Bool {
        return flags.contains(DirInfoFlag.HasNodeModules)
    }

    /// 当前目录是否是 node_modules
    // 对应 Bun: isNodeModules()
    public func isNodeModules(): Bool {
        return flags.contains(DirInfoFlag.IsNodeModules)
    }

    /// 当前目录是否在 node_modules 内部
    // 对应 Bun: isInsideNodeModules()
    public func isInsideNodeModules(): Bool {
        return flags.contains(DirInfoFlag.InsideNodeModules)
    }

    /// 是否有父级 package (非 node_modules 的父级)
    // 对应 Bun: hasParentPackage()
    public func hasParentPackage(): Bool {
        match (parent) {
            case Some(p) => return !p.isNodeModules()
            case None => return false
        }
    }

    /// 获取目录条目
    // 对应 Bun: getEntries()
    // 从文件系统缓存中获取目录中的文件列表
    public func getEntries(): ?DirEntry {
        return entries
    }

    /// 获取父级 DirInfo
    // 对应 Bun: getParent()
    public func getParent(): ?DirInfo {
        return parent
    }

    /// 获取 enclosing browser scope
    // 对应 Bun: getEnclosingBrowserScope()
    public func getEnclosingBrowserScope(): ?DirInfo {
        return enclosingBrowserScope
    }

    /// 释放资源
    // 对应 Bun: deinit()
    public func deinit(): Unit {
        packageJson = None
        tsconfigJson = None
    }
}

// ============================================================================
// DirEntry — 目录条目
// 严格翻译自: src/resolver/fs.zig 中 Fs.FileSystem.DirEntry
// 对应 Bun: 文件系统目录中的单个条目 (文件/目录/符号链接)
// ============================================================================

/// 目录条目类型
/// 对应 Bun: DirEntry.Kind
public enum DirEntryKind {
    | File
    | Dir
    | SymLink
}

/// 目录条目
/// 对应 Bun: Fs.FileSystem.DirEntry 中的数据
public class DirEntry {
    /// 条目名称
    public var name: String

    /// 条目类型
    public var kind: DirEntryKind

    /// 条目所在目录路径
    public var dir: String

    public init(name: String, kind: DirEntryKind, dir: String) {
        this.name = name
        this.kind = kind
        this.dir = dir
    }

    /// 获取基础文件名
    // 对应 Bun: DirEntry.base()
    public func base(): String {
        return name
    }

    /// 判断是否为文件
    public func isFile(): Bool {
        match (kind) {
            case File => return true
            case _ => return false
        }
    }

    /// 判断是否为目录
    public func isDir(): Bool {
        match (kind) {
            case Dir => return true
            case _ => return false
        }
    }
}

// ============================================================================
// DirInfoHashMap — 目录信息缓存映射
// 严格翻译自: dir_info.zig 中的 HashMap
// 对应 Bun: allocators.BSSMap(DirInfo, ...)
//
// 目标: 极快、低分配的目录映射:
//   1. 不存储不存在目录的键值
//   2. 查询后不期望 key 保持有效
//   3. 存储目录是否被查询过以及查询是否成功
//   4. 在 .bss 段分配以避免内存泄漏
// ============================================================================

/// 目录信息缓存
/// 对应 Bun: DirInfo.HashMap — BSSMap 实现
public class DirInfoCache {
    /// 缓存映射: 绝对路径 -> DirInfo
    private var cache: HashMap<String, DirInfo>

    public init() {
        cache = HashMap<String, DirInfo>()
    }

    /// 获取或创建目录信息
    // 对应 Bun: HashMap.instance.atIndex / put
    public func getOrCreate(absPath: String): DirInfo {
        match (cache.get(absPath)) {
            case Some(info) => return info
            case None => {
                let info = DirInfo()
                info.absPath = absPath
                cache.put(absPath, info)
                return info
            }
        }
    }

    /// 查找目录信息
    public func get(absPath: String): ?DirInfo {
        return cache.get(absPath)
    }

    /// 清除缓存
    public func clear(): Unit {
        cache.clear()
    }
}
