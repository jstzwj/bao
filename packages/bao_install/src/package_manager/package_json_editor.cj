// bao_install - Package.json 编辑器
// 严格翻译自: src/install/PackageManager/PackageJSONEditor.zig
//   editPatchedDependencies: 编辑补丁依赖
//   editTrustedDependencies: 编辑信任依赖
//   editUpdateNoArgs: 无参数更新编辑
//   edit: 主编辑函数 (处理 add/remove/update 依赖列表)
package bao_install.package_manager

import bao_install.*

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
        if (let query <- packageJson.get("patchedDependencies")) {
            if (query.isObject()) { patchedDeps = query }
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
            case Some(query) => collectTrustedDeps(query, originalTrustedDeps)
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
        allTrustedDeps.sort({ a: String, b: String => a.compareTo(b) })

        // 更新 package.json
        packageJson.putStringArray(TRUSTED_DEPENDENCIES_STRING, allTrustedDeps)
    }

    /// 无参数更新编辑
    /// 翻译自: editUpdateNoArgs
    ///   pub fn editUpdateNoArgs(manager, current_package_json, options) !void
    ///   当 bun update 不带包名时, 更新所有依赖
    public static func editUpdateNoArgs(
        manager: PackageJsonEditorManagerRef,
        currentPackageJson: JsonExpr,
        options: EditOptions
    ): Unit {
        for (group in DEPENDENCY_GROUPS) {
            match (currentPackageJson.get(group.name)) {
                case Some(root) => editUpdateNoArgsGroup(manager, root, options)
                case None => ()
            }
        }
    }

    /// editUpdateNoArgs per-group helper
    private static func editUpdateNoArgsGroup(
        manager: PackageJsonEditorManagerRef,
        root: JsonExpr,
        options: EditOptions
    ): Unit {
        if (!root.isObject()) { return }
        if (options.beforeInstall) {
            editUpdatePropsBeforeInstall(manager, root)
        }
    }

    /// editUpdateNoArgs before-install per-prop helper
    private static func editUpdatePropsBeforeInstall(
        manager: PackageJsonEditorManagerRef,
        root: JsonExpr
    ): Unit {
        for (propEntry in root.properties()) {
            let key = propEntry.key
            if (key.size == 0) { () }
            let value = propEntry.value
            if (!value.isString()) { () }

            let versionLiteral = value.asString()
            let tag = inferVersionTag(versionLiteral)

            if (tag != DependencyVersionTag.NPM &&
                (tag != DependencyVersionTag.DistTag || !manager.options.updateToLatest) &&
                tag != DependencyVersionTag.Catalog) {
                continue
            }

            let aliasInfo = resolveAliasInfo(manager, versionLiteral)
            if (manager.options.updateToLatest) {
                let tempVersion = resolveAliasVersion(versionLiteral, aliasInfo)
                propEntry.value = JsonExpr.fromString(tempVersion)
            }
        }
    }

    /// resolve alias index for npm: prefixed versions
    private static func resolveAliasInfo(manager: PackageJsonEditorManagerRef, versionLiteral: String): ?Int64 {
        let trimmed = versionLiteral.trim()
        if (!trimmed.startsWith("npm:")) { return None }
        let atIndex = trimmed.lastIndexOf("@")
        match (atIndex) {
            case Some(idx) => resolveAliasAtIdx(manager, trimmed, idx)
            case None => None
        }
    }

    /// resolve alias at index helper
    private static func resolveAliasAtIdx(manager: PackageJsonEditorManagerRef, trimmed: String, idx: Int64): ?Int64 {
        let innerTag = inferVersionTag(trimmed[Int64(idx) + 1..])
        if (innerTag != DependencyVersionTag.NPM &&
            (innerTag != DependencyVersionTag.DistTag || !manager.options.updateToLatest) &&
            innerTag != DependencyVersionTag.Catalog) {
            return None
        }
        return idx
    }

    /// resolve version string from alias info
    private static func resolveAliasVersion(versionLiteral: String, aliasInfo: ?Int64): String {
        let trimmed = versionLiteral.trim()
        match (aliasInfo) {
            case Some(atIdx) => "${trimmed[0..Int64(atIdx)]}@latest"
            case None => "latest"
        }
    }

    /// 编辑依赖
    /// 翻译自: edit
    ///   pub fn edit(manager, updates, current_package_json, dependency_list, options) !void
    ///   主编辑函数: 处理 add/remove/update 依赖列表
    public static func edit(
        manager: PackageJsonEditorManagerRef,
        updates: ArrayList<PackageJsonUpdateRequest>,
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
            case Some(depList) => editIntoDepList(depList, updates)
            case None => editCreateDepList(currentPackageJson, dependencyList, updates)
        }
    }

    /// edit helper: write updates into existing dep list
    private static func editIntoDepList(depList: JsonExpr, updates: ArrayList<PackageJsonUpdateRequest>): Unit {
        if (!depList.isObject()) { return }
        for (request in updates) {
            if (request.failed) { () }
            let versionStr = getReqVersion(request)
            match (versionStr) {
                case Some(s) => depList.put(request.getName(), JsonExpr.fromString(s))
                case None => ()
            }
        }
    }

    /// edit helper: create new dep list and write updates
    private static func editCreateDepList(currentPackageJson: JsonExpr, dependencyList: String, updates: ArrayList<PackageJsonUpdateRequest>): Unit {
        var newDepList = JsonExpr()
        for (request in updates) {
            if (request.failed) { () }
            let versionStr = getReqVersion(request)
            match (versionStr) {
                case Some(s) => newDepList.put(request.getName(), JsonExpr.fromString(s))
                case None => ()
            }
        }
        currentPackageJson.put(dependencyList, newDepList)
    }

    /// get version string from PackageJsonUpdateRequest
    private static func getReqVersion(request: PackageJsonUpdateRequest): ?String {
        let buf = request.versionBuf
        if (buf.size == 0) { return None }
        return Some(buf)
    }

    /// 推断版本标签
    private static func inferVersionTag(version: String): DependencyVersionTag {
        if (version.size == 0) { return DependencyVersionTag.Uninitialized }
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

    private static func collectTrustedDeps(query: JsonExpr, list: ArrayList<String>): Unit {
        if (query.isArray()) {
            for (item in query.arrayItems()) {
                if (item.isString()) {
                    list.append(item.asString())
                }
            }
        }
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
public class PackageJsonUpdateRequest {
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
        if (name.size > 0) { return name }
        return versionBuf
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
public class PackageJsonEditorManagerRef {
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
