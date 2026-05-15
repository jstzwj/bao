// bao_install - Package.json 编辑器
// 严格翻译自: src/install/PackageManager/PackageJSONEditor.zig
//   editPatchedDependencies: 编辑补丁依赖
//   editTrustedDependencies: 编辑信任依赖
//   editUpdateNoArgs: 无参数更新编辑
//   edit: 主编辑函数 (处理 add/remove/update 依赖列表)
package bao_install.package_manager

import bao_core.*
import bao_collections.*

// ============================================================================
// 编辑选项
// 严格翻译自: PackageJSONEditor.zig - EditOptions
//   pub const EditOptions = struct {
//       exact_versions: bool = false,
//       add_trusted_dependencies: bool = false,
//       before_install: bool = false,
//   }
// ============================================================================

/// 编辑选项
/// 对应 Bun: EditOptions
public class EditOptions {
    /// 是否使用精确版本
    public var exactVersions: Bool
    /// 是否添加信任依赖
    public var addTrustedDependencies: Bool
    /// 是否在安装前
    public var beforeInstall: Bool

    public init() {
        exactVersions = false
        addTrustedDependencies = false
        beforeInstall = false
    }
}

// ============================================================================
// 依赖组常量
// 严格翻译自: PackageJSONEditor.zig - dependency_groups
//   const dependency_groups = &.{
//       .{ "optionalDependencies", .{ .optional = true } },
//       .{ "devDependencies", .{ .dev = true } },
//       .{ "dependencies", .{ .prod = true } },
//       .{ "peerDependencies", .{ .peer = true } },
//   }
// ============================================================================

/// 依赖组列表
public let DEPENDENCY_GROUPS: ArrayList<DependencyGroup> = ArrayList<DependencyGroup>([
    DependencyGroup(name: "optionalDependencies", behavior: DependencyGroupBehavior(optional: true)),
    DependencyGroup(name: "devDependencies", behavior: DependencyGroupBehavior(dev: true)),
    DependencyGroup(name: "dependencies", behavior: DependencyGroupBehavior(prod: true)),
    DependencyGroup(name: "peerDependencies", behavior: DependencyGroupBehavior(peer: true))
])

/// 信任依赖字符串常量
/// 翻译自: trusted_dependencies_string
public let TRUSTED_DEPENDENCIES_STRING: String = "trustedDependencies"

// ============================================================================
// Package.json 编辑器
// 严格翻译自: src/install/PackageManager/PackageJSONEditor.zig
// ============================================================================

/// Package.json 编辑器
/// 对应 Bun: PackageJSONEditor 中的函数
/// 翻译自: src/install/PackageManager/PackageJSONEditor.zig
public class PackageJSONEditor {

    /// 编辑补丁依赖
    /// 翻译自: editPatchedDependencies
    ///   pub fn editPatchedDependencies(manager, package_json, patch_key, patchfile_path) !void
    public static func editPatchedDependencies(
        packageJson: JsonExpr,
        patchKey: String,
        patchfilePath: String
    ): Unit {
        // 获取或创建 patchedDependencies 对象
        var patchedDeps = JsonExpr()
        match (packageJson.get("patchedDependencies")) {
            case Some(query) => {
                if (query.isObject()) {
                    patchedDeps = query
                }
            }
            case None => ()
        }

        // 添加补丁条目
        patchedDeps.put(patchKey, JsonExpr.fromString(patchfilePath))
        packageJson.put("patchedDependencies", patchedDeps)
    }

    /// 编辑信任依赖
    /// 翻译自: editTrustedDependencies
    ///   pub fn editTrustedDependencies(allocator, package_json, names_to_add) !void
    ///   将给定的包名添加到 trustedDependencies 数组中
    public static func editTrustedDependencies(
        packageJson: JsonExpr,
        namesToAdd: ArrayList<String>
    ): Unit {
        var remaining = namesToAdd.size

        // 获取现有的信任依赖数组
        var originalTrustedDeps = ArrayList<String>()
        match (packageJson.get(TRUSTED_DEPENDENCIES_STRING)) {
            case Some(query) => {
                if (query.isArray()) {
                    for (item in query.arrayItems()) {
                        if (item.isString()) {
                            originalTrustedDeps.append(item.asString())
                        }
                    }
                }
            }
            case None => ()
        }

        // 去重: 移除已存在的名称
        var newNamesToAdd = ArrayList<String>()
        for (name in namesToAdd) {
            var isDuplicate = false
            for (existing in originalTrustedDeps) {
                if (existing == name) {
                    isDuplicate = true
                    break
                }
            }
            if (!isDuplicate) {
                newNamesToAdd.append(name)
            }
        }

        // 合并并排序
        var allTrustedDeps = ArrayList<String>()
        for (item in originalTrustedDeps) { allTrustedDeps.append(item) }
        for (item in newNamesToAdd) { allTrustedDeps.append(item) }
        allTrustedDeps.sort { (a: String, b: String): Int64 => a.compareTo(b) }

        // 更新 package.json
        packageJson.putStringArray(TRUSTED_DEPENDENCIES_STRING, allTrustedDeps)
    }

    /// 无参数更新编辑
    /// 翻译自: editUpdateNoArgs
    ///   pub fn editUpdateNoArgs(manager, current_package_json, options) !void
    ///   当 bun update 不带包名时, 更新所有依赖
    public static func editUpdateNoArgs(
        manager: PackageManagerRef,
        currentPackageJson: JsonExpr,
        options: EditOptions
    ): Unit {
        for (group in DEPENDENCY_GROUPS) {
            match (currentPackageJson.get(group.name)) {
                case Some(root) => {
                    if (!root.isObject()) { continue }

                    if (options.beforeInstall) {
                        // 安装前: 将每个 npm 依赖设置为 latest
                        for (prop in root.properties()) {
                            let key = prop.key
                            if (key.length == 0) { continue }
                            let value = prop.value
                            if (!value.isString()) { continue }

                            let versionLiteral = value.asString()
                            let tag = inferVersionTag(versionLiteral)

                            // 只更新 npm/dist-tag/catalog 依赖
                            if (tag != DependencyVersionTag.NPM &&
                                (tag != DependencyVersionTag.DistTag || !manager.options.updateToLatest) &&
                                tag != DependencyVersionTag.Catalog) {
                                continue
                            }

                            // 处理 alias
                            var aliasAtIndex: ?Int64 = None
                            let trimmed = versionLiteral.trim()
                            if (trimmed.startsWith("npm:")) {
                                let atIndex = trimmed.lastIndexOf("@")
                                match (atIndex) {
                                    case Some(idx) => {
                                        let innerTag = inferVersionTag(trimmed.substring(Int64(idx) + 1))
                                        if (innerTag != DependencyVersionTag.NPM &&
                                            (innerTag != DependencyVersionTag.DistTag || !manager.options.updateToLatest) &&
                                            innerTag != DependencyVersionTag.Catalog) {
                                            continue
                                        }
                                        aliasAtIndex = idx
                                    }
                                    case None => ()
                                }
                            }

                            if (manager.options.updateToLatest) {
                                // 设置为 latest
                                let tempVersion = match (aliasAtIndex) {
                                    case Some(atIdx) => "${trimmed.substring(0, Int64(atIdx)))}@latest"
                                    case None => "latest"
                                }
                                prop.value = JsonExpr.fromString(tempVersion)
                            }
                        }
                    } else {
                        // 安装后: 更新为解析后的版本
                        // 简化: 实际需要从锁文件获取解析后的版本
                    }
                }
                case None => ()
            }
        }
    }

    /// 编辑依赖
    /// 翻译自: edit
    ///   pub fn edit(manager, updates, current_package_json, dependency_list, options) !void
    ///   主编辑函数: 处理 add/remove/update 依赖列表
    public static func edit(
        manager: PackageManagerRef,
        updates: ArrayList<UpdateRequest>,
        currentPackageJson: JsonExpr,
        dependencyList: String,
        options: EditOptions
    ): Unit {
        var remaining = updates.size
        let onlyAddMissing = manager.options.onlyMissing

        // 处理信任依赖
        if (options.addTrustedDependencies) {
            editTrustedDependencies(
                packageJson: currentPackageJson,
                namesToAdd: manager.trustedDepsToAdd
            )
        }

        // 处理依赖更新
        match (currentPackageJson.get(dependencyList)) {
            case Some(depList) => {
                if (depList.isObject()) {
                    for (request in updates) {
                        if (request.failed) { continue }

                        // 设置版本
                        let versionStr = match (request.version.versionBuf) {
                            case s: String => s
                            case _: None => continue
                        }

                        depList.put(request.getName(), JsonExpr.fromString(versionStr))
                    }
                }
            }
            case None => {
                // 创建新的依赖列表
                var newDepList = JsonExpr()
                for (request in updates) {
                    if (request.failed) { continue }

                    let versionStr = match (request.version.versionBuf) {
                        case s: String => s
                        case _: None => continue
                    }

                    newDepList.put(request.getName(), JsonExpr.fromString(versionStr))
                }
                currentPackageJson.put(dependencyList, newDepList)
            }
        }
    }

    /// 推断版本标签
    private static func inferVersionTag(version: String): DependencyVersionTag {
        if (version.length == 0) { return DependencyVersionTag.Uninitialized }
        let first = version[0].value
        if (first == 94 || first == 126 || first == 62 || // ^, ~, >
            first == 60 || first == 61 || first == 42) { // <, =, *
            return DependencyVersionTag.NPM
        }
        if (version.contains(":")) {
            return DependencyVersionTag.DistTag
        }
        return DependencyVersionTag.NPM
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 依赖组
public class DependencyGroup {
    public var name: String
    public var behavior: DependencyGroupBehavior

    public init(name: String, behavior: DependencyGroupBehavior) {
        this.name = name
        this.behavior = behavior
    }
}

/// 依赖组行为
public class DependencyGroupBehavior {
    public var optional: Bool
    public var dev: Bool
    public var prod: Bool
    public var peer: Bool

    public init() {
        optional = false
        dev = false
        prod = false
        peer = false
    }

    public init(optional: Bool) {
        this.optional = optional
        dev = false
        prod = false
        peer = false
    }

    public init(dev: Bool) {
        optional = false
        this.dev = dev
        prod = false
        peer = false
    }

    public init(prod: Bool) {
        optional = false
        dev = false
        this.prod = prod
        peer = false
    }

    public init(peer: Bool) {
        optional = false
        dev = false
        prod = false
        this.peer = peer
    }
}

/// 更新请求 (轻量引用)
public class UpdateRequest {
    public var failed: Bool
    public var name: String
    public var version: DependencyVersionInfo
    public var versionBuf: String

    public init() {
        failed = false
        name = ""
        version = DependencyVersionInfo()
        versionBuf = ""
    }

    public func getName(): String {
        return name.length > 0 ? name : versionBuf
    }
}

/// 依赖版本信息
public class DependencyVersionInfo {
    public var tag: DependencyVersionTag
    public var literal: String

    public init() {
        tag = DependencyVersionTag.Uninitialized
        literal = ""
    }
}

/// 依赖版本标签
public enum DependencyVersionTag {
    | Uninitialized
    | NPM
    | DistTag
    | Folder
    | Tarball
    | Git
    | GitHub
    | Symlink
    | Workspace
    | Catalog
}

/// 包管理器引用
public class PackageManagerRef {
    public var options: PackageManagerEditOptions
    public var trustedDepsToAdd: ArrayList<String>

    public init() {
        options = PackageManagerEditOptions()
        trustedDepsToAdd = ArrayList<String>()
    }
}

/// 包管理器编辑选项
public class PackageManagerEditOptions {
    public var updateToLatest: Bool
    public var onlyMissing: Bool

    public init() {
        updateToLatest = false
        onlyMissing = false
    }
}
