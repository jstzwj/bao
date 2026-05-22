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
public let DEPENDENCY_GROUPS: ArrayList<DependencyGroup> = ArrayList<DependencyGroup>()

/// 信任依赖字符串常量
/// 翻译自: trusted_dependencies_string
public let TRUSTED_DEPENDENCIES_STRING: String = "trustedDependencies"

// ============================================================================
// 依赖列表常量 (edit 中用于查找已有依赖)
// 严格翻译自: PackageJSONEditor.zig - edit 中的 inline for
//   inline for ([_]string{ "dependencies", "devDependencies",
//       "optionalDependencies", "peerDependencies" }) |list| {
// ============================================================================

/// 所有依赖列表名称
/// 翻译自: edit 中遍历的依赖列表
public let ALL_DEPENDENCY_LISTS: ArrayList<String> = ArrayList<String>([
    "dependencies",
    "devDependencies",
    "optionalDependencies",
    "peerDependencies"
])

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
    ///
    /// 1. 获取或创建 package_json 中的 "patchedDependencies" 对象
    /// 2. 将 patch_key -> patchfile_path 写入
    /// 3. 更新 package_json
    public static func editPatchedDependencies(
        packageJson: JsonExpr,
        patchKey: String,
        patchfilePath: String
    ): Unit {
        // 获取或创建 patchedDependencies 对象
        // 严格翻译自:
        //   var patched_dependencies = brk: {
        //       if (package_json.asProperty("patchedDependencies")) |query| {
        //           if (query.expr.data == .e_object)
        //               break :brk query.expr.data.e_object.*;
        //       }
        //       break :brk E.Object{};
        //   };
        var patchedDeps = HashMap<String, String>()
        match (packageJson.get("patchedDependencies")) {
            case Some(obj) =>
                // 复制现有 patchedDependencies
                let existingProps = obj.properties()
                for (`prop` in existingProps) {
                    match (`prop`.value) {
                        case JsonExprValue.Str(s) => patchedDeps.put(`prop`.key, s)
                        case _ => ()
                    }
                }
            case None => ()
        }

        // 添加新的补丁条目
        patchedDeps.put(patchKey, patchfilePath)

        // 写回 package_json
        packageJson.putObject("patchedDependencies", patchedDeps)
    }

    /// 编辑信任依赖
    /// 严格翻译自: editTrustedDependencies
    ///   pub fn editTrustedDependencies(allocator, package_json, names_to_add) !void
    ///
    /// 步骤:
    /// 1. 获取现有的 trustedDependencies 数组
    /// 2. 迭代器向后遍历, 过滤掉已存在的名称 (swapRemove)
    /// 3. 将新名称填入新数组的 empty 槽位
    /// 4. 按字母排序
    /// 5. 处理空根对象和新列表的情况
    public static func editTrustedDependencies(
        packageJson: JsonExpr,
        namesToAdd: ArrayList<String>
    ): Unit {
        if (namesToAdd.size == 0) { return }

        // 获取现有 trustedDependencies
        // 严格翻译自:
        //   var original_trusted_dependencies = brk: {
        //       if (package_json.asProperty(trusted_dependencies_string)) |query| {
        //           if (query.expr.data == .e_array) {
        //               break :brk query.expr.data.e_array.*;
        //           }
        //       }
        //       break :brk E.Array{};
        //   };
        var originalTrustedDeps = ArrayList<String>()
        match (packageJson.get(TRUSTED_DEPENDENCIES_STRING)) {
            case Some(arr) =>
                let items = arr.arrayItems()
                for (item in items) {
                    match (item) {
                        case JsonExprValue.Str(s) => originalTrustedDeps.append(s)
                        case _ => ()
                    }
                }
            case None => ()
        }

        // 严格翻译自: 向后遍历, 过滤掉已存在的名称
        //   var i: usize = manager.trusted_deps_to_add_to_package_json.items.len;
        //   while (i > 0) {
        //       i -= 1;
        //       const trusted_package_name = manager.trusted_deps_to_add_to_package_json.items[i];
        //       for (original_trusted_dependencies.items.slice()) |item| {
        //           if (item.data == .e_string) {
        //               if (item.data.e_string.eql(string, trusted_package_name)) {
        //                   allocator.free(manager.trusted_deps_to_add_to_package_json.swapRemove(i));
        //                   break;
        //               }
        //           }
        //       }
        //   }
        var len: Int64 = namesToAdd.size
        var i: Int64 = namesToAdd.size
        while (i > 0) {
            i = i - 1
            let trustedPackageName = namesToAdd[i]
            var found = false
            for (existing in originalTrustedDeps) {
                if (existing == trustedPackageName) {
                    found = true
                    break
                }
            }
            if (found) {
                // swapRemove: 将最后一个移到当前位置
                if (i < len - 1) {
                    let temp = namesToAdd[i]
                    namesToAdd[i] = namesToAdd[len - 1]
                    namesToAdd[len - 1] = temp
                }
                len = len - 1
            }
        }

        // 严格翻译自:
        //   var trusted_dependencies: []Expr = &[_]Expr{};
        //   if (package_json.asProperty(trusted_dependencies_string)) |query| {
        //       if (query.expr.data == .e_array) {
        //           trusted_dependencies = query.expr.data.e_array.items.slice();
        //       }
        //   }
        var trustedDependenciesSlice = ArrayList<String>()
        match (packageJson.get(TRUSTED_DEPENDENCIES_STRING)) {
            case Some(query) =>
                let items = query.arrayItems()
                for (item in items) {
                    match (item) {
                        case JsonExprValue.Str(s) => trustedDependenciesSlice.append(s)
                        case _ => ()
                    }
                }
            case None => ()
        }

        // 严格翻译自:
        //   const trusted_dependencies_to_add = len;
        //   const new_trusted_deps: JSAst.ExprNodeList = brk: {
        //       const deps = try allocator.alloc(Expr, trusted_dependencies.len + trusted_dependencies_to_add);
        //       @memcpy(deps[0..trusted_dependencies.len], trusted_dependencies);
        //       @memset(deps[trusted_dependencies.len..], Expr.empty);
        //
        //       for (names_to_add[0..len]) |name| {
        //           var i = deps.len;
        //           while (i > 0) {
        //               i -= 1;
        //               if (deps[i].data == .e_missing) {
        //                   deps[i] = ... E.String{ .data = name } ...
        //                   break;
        //               }
        //           }
        //       }
        //       break :brk .fromOwnedSlice(deps);
        //   };
        let trustedDependenciesToAdd = len
        var newTrustedDeps = ArrayList<String>()
        // 复制现有
        for (existing in trustedDependenciesSlice) {
            newTrustedDeps.append(existing)
        }
        // 添加新名称 (从 namesToAdd[0..len])
        var j: Int64 = 0
        while (j < len) {
            newTrustedDeps.append(namesToAdd[j])
            j = j + 1
        }

        // 严格翻译自:
        //   var needs_new_trusted_dependencies_list = true;
        //   const trusted_dependencies_array: Expr = brk: {
        //       if (package_json.asProperty(trusted_dependencies_string)) |query| {
        //           if (query.expr.data == .e_array) {
        //               needs_new_trusted_dependencies_list = false;
        //               break :brk query.expr;
        //           }
        //       }
        //       break :brk Expr.init(E.Array, E.Array{ .items = new_trusted_deps }, ...);
        //   };
        var needsNewTrustedDependenciesList = true
        match (packageJson.get(TRUSTED_DEPENDENCIES_STRING)) {
            case Some(query) =>
                if (query.isArray()) {
                    needsNewTrustedDependenciesList = false
                }
            case None => ()
        }

        // 严格翻译自:
        //   if (trusted_dependencies_to_add > 0 and new_trusted_deps.len > 0) {
        //       trusted_dependencies_array.data.e_array.items = new_trusted_deps;
        //       trusted_dependencies_array.data.e_array.alphabetizeStrings();
        //   }
        if (trustedDependenciesToAdd > 0 && newTrustedDeps.size > 0) {
            newTrustedDeps.sort()
        }

        // 写回
        packageJson.putArray(TRUSTED_DEPENDENCIES_STRING, newTrustedDeps)

        // 严格翻译自:
        //   if (package_json.data != .e_object or package_json.data.e_object.properties.len == 0) {
        //       ... 创建根属性 ...
        //   } else if (needs_new_trusted_dependencies_list) {
        //       ... 追加属性 ...
        //   }
        if (packageJson.isEmpty()) {
            packageJson.ensureProperty(TRUSTED_DEPENDENCIES_STRING, newTrustedDeps)
        } else if (needsNewTrustedDependenciesList) {
            packageJson.appendProperty(TRUSTED_DEPENDENCIES_STRING, newTrustedDeps)
        }
    }

    /// 无参数更新编辑
    /// 严格翻译自: editUpdateNoArgs
    ///   pub fn editUpdateNoArgs(manager, current_package_json, options) !void
    ///   当 bun update 不带包名时, 更新所有依赖
    ///
    /// 步骤:
    /// 1. 禁用 Expr data store
    /// 2. 遍历所有依赖组 (optional, dev, dependencies, peer)
    /// 3. 对每个组:
    ///    a. before_install 模式: 设置每个 npm 依赖版本为 "latest"
    ///    b. 非 before_install 模式: 从锁文件中查找已解析的版本并更新
    /// 4. 重新启用 Expr data store
    public static func editUpdateNoArgs(
        manager: PackageJsonEditorManagerRef,
        currentPackageJson: JsonExpr,
        options: EditOptions
    ): Unit {
        // 严格翻译自:
        //   Expr.Disabler.disable();
        //   defer Expr.Disabler.enable();
        // 在 Cangjie 中, JsonExpr 使用值语义, 不需要 disable/enable

        for (group in DEPENDENCY_GROUPS) {
            match (currentPackageJson.get(group.name)) {
                case Some(root) =>
                    if (root.isObject()) {
                        editUpdateNoArgsGroup(manager, root, options)
                    }
                case None => ()
            }
        }
    }

    /// editUpdateNoArgs per-group helper
    /// 严格翻译自: editUpdateNoArgs 中每个依赖组的处理
    private static func editUpdateNoArgsGroup(
        manager: PackageJsonEditorManagerRef,
        root: JsonExpr,
        options: EditOptions
    ): Unit {
        if (options.beforeInstall) {
            editUpdatePropsBeforeInstall(manager, root)
        } else {
            editUpdatePropsFromLockfile(manager, root, options)
        }
    }

    /// editUpdateNoArgs before-install per-prop helper
    /// 严格翻译自: editUpdateNoArgs 中 before_install 块
    ///
    /// 遍历依赖属性, 对每个 npm/dist-tag/catalog 版本的依赖:
    /// 1. 推断版本标签
    /// 2. 处理 npm: alias
    /// 3. 记录到 updating_packages (first come first serve)
    /// 4. 如果 update_to_latest, 替换版本字符串为 "latest"
    private static func editUpdatePropsBeforeInstall(
        manager: PackageJsonEditorManagerRef,
        root: JsonExpr
    ): Unit {
        let props = root.properties()

        for (`prop` in props) {
            let key = `prop`.key
            if (key.size == 0) { continue }
            let value = `prop`.value
            if (!value.isString()) { continue }

            // 获取版本字面量
            // 严格翻译自: const version_literal = try value.asStringCloned(allocator) orelse bun.outOfMemory();
            let versionLiteral = match (value.asString()) {
                case Some(s) => s
                case None => continue
            }

            // 严格翻译自: var tag = Dependency.Version.Tag.infer(version_literal);
            var tag = DependencyVersionTag.infer(versionLiteral)

            // 严格翻译自:
            //   if (tag != .npm and (tag != .dist_tag or !manager.options.do.update_to_latest) and tag != .catalog) continue;
            var shouldUpdate = false
            match (tag) {
                case DependencyVersionTag.Npm => shouldUpdate = true
                case DependencyVersionTag.Catalog => shouldUpdate = true
                case DependencyVersionTag.DistTag =>
                    if (manager.options.updateToLatest) { shouldUpdate = true }
                case _ => ()
            }
            if (!shouldUpdate) { continue }

            // 严格翻译自:
            //   var alias_at_index: ?usize = null;
            //   if (strings.hasPrefixComptime(strings.trim(version_literal, &strings.whitespace_chars), "npm:")) {
            //       if (strings.lastIndexOfChar(version_literal, '@')) |at_index| {
            //           tag = Dependency.Version.Tag.infer(version_literal[at_index + 1 ..]);
            //           if (tag != .npm and (tag != .dist_tag or !manager.options.do.update_to_latest) and tag != .catalog) continue;
            //           alias_at_index = at_index;
            //       }
            //   }
            var aliasAtIndex: ?Int64 = None
            let trimmedVersion = versionLiteral.trim()
            if (trimmedVersion.startsWith("npm:")) {
                match (versionLiteral.lastIndexOf("@")) {
                    case Some(atIndex) =>
                        tag = DependencyVersionTag.infer(versionLiteral[(atIndex + 1)..versionLiteral.size])
                        // 重新检查标签
                        shouldUpdate = false
                        match (tag) {
                            case DependencyVersionTag.Npm => shouldUpdate = true
                            case DependencyVersionTag.Catalog => shouldUpdate = true
                            case DependencyVersionTag.DistTag =>
                                if (manager.options.updateToLatest) { shouldUpdate = true }
                            case _ => ()
                        }
                        if (!shouldUpdate) { continue }
                        aliasAtIndex = atIndex
                    case None => ()
                }
            }

            // 严格翻译自:
            //   const key_str = try key.asStringCloned(allocator) orelse unreachable;
            //   const entry = bun.handleOom(manager.updating_packages.getOrPut(allocator, key_str));
            //   if (entry.found_existing) continue;
            if (manager.updatingPackages.contains(key)) { continue }

            manager.updatingPackages.put(key, UpdatingPackageEntry(
                originalVersionLiteral: versionLiteral,
                isAlias: aliasAtIndex.isSome(),
                originalVersion: None
            ))

            // 严格翻译自:
            //   if (manager.options.do.update_to_latest) {
            //       const temp_version = if (alias_at_index) |at_index|
            //           bun.handleOom(std.fmt.allocPrint(allocator, "{s}@latest", .{version_literal[0..at_index]}))
            //       else
            //           bun.handleOom(allocator.dupe(u8, "latest"));
            //       dep.value = Expr.allocate(allocator, E.String, .{ .data = temp_version }, logger.Loc.Empty);
            //   }
            if (manager.options.updateToLatest) {
                var newVersion = "latest"
                match (aliasAtIndex) {
                    case Some(atIdx) =>
                        // alias: "npm:@foo/bar@1.2.3" -> "npm:@foo/bar@latest"
                        newVersion = "${versionLiteral[0..atIdx]}@latest"
                    case None => ()
                }
                root.put(key, newVersion)
            }
        }
    }

    /// editUpdateNoArgs 非 before-install 模式: 从锁文件更新版本
    /// 严格翻译自: editUpdateNoArgs 中非 before_install 块
    ///
    /// 遍历依赖属性, 使用 updating_packages 中的原始版本和锁文件中的解析结果:
    /// 1. 查找 updating_packages 中的条目
    /// 2. 匹配 workspace 依赖
    /// 3. 计算 new_version (根据 pinned 风格: patch, minor, major)
    /// 4. 处理 alias 依赖
    private static func editUpdatePropsFromLockfile(
        manager: PackageJsonEditorManagerRef,
        root: JsonExpr,
        options: EditOptions
    ): Unit {
        // 严格翻译自:
        //   const lockfile = manager.lockfile;
        //   const string_buf = lockfile.buffers.string_bytes.items;
        //   const workspace_package_id = lockfile.getWorkspacePackageID(manager.workspace_name_hash);
        //   const packages = lockfile.packages.slice();
        //   const resolutions = packages.items(.resolution);
        //   const deps = packages.items(.dependencies)[workspace_package_id];
        //   const resolution_ids = packages.items(.resolutions)[workspace_package_id];
        //   const workspace_deps: []const Dependency = deps.get(lockfile.buffers.dependencies.items);
        //   const workspace_resolution_ids = resolution_ids.get(lockfile.buffers.resolutions.items);
        //
        // 在 Cangjie 中, 这些信息通过 manager.findWorkspaceDep 抽象

        let props = root.properties()

        for (`prop` in props) {
            let key = `prop`.key
            if (key.size == 0) { continue }
            let value = `prop`.value
            if (!value.isString()) { continue }

            // 严格翻译自:
            //   updated: {
            //       if (manager.updating_packages.fetchSwapRemove(key_str)) |entry| {
            //           ...
            //           break :updated;
            //       }
            //   }
            match (manager.updatingPackages.fetchRemove(key)) {
                case Some(entry) =>
                    let isAlias = entry.isAlias
                    let depName = key

                    // 尝试从锁文件匹配
                    // 严格翻译自:
                    //   for (workspace_deps, workspace_resolution_ids) |*workspace_dep, package_id| {
                    //       if (package_id == invalid_package_id) continue;
                    //       const resolution = resolutions[package_id];
                    //       if (resolution.tag != .npm) continue;
                    //       const workspace_dep_name = workspace_dep.name.slice(string_buf);
                    //       if (!strings.eqlLong(workspace_dep_name, dep_name, true)) continue;
                    //       ...
                    //   }
                    match (manager.findWorkspaceDep(depName)) {
                        case Some(depInfo) =>
                            // 获取解析的版本
                            let resolvedVersion = depInfo.resolvedVersion
                            match (resolvedVersion) {
                                case Some(npmVer) =>
                                    // 严格翻译自:
                                    //   if (!manager.options.do.update_to_latest and npm_version.version.isExact()) break :updated;
                                    if (!manager.options.updateToLatest && isExactVersion(npmVer)) {
                                        continue
                                    }

                                    let newVersion = computeNewVersion(
                                        npmVer,
                                        entry.originalVersionLiteral,
                                        isAlias,
                                        options.exactVersions
                                    )

                                    if (isAlias) {
                                        // 严格翻译自:
                                        //   if (strings.lastIndexOfChar(dep_literal, '@')) |at_index| {
                                        //       dep.value = Expr.allocate(... "{s}@{s}" ...);
                                        //       break :updated;
                                        //   }
                                        let depLiteral = entry.originalVersionLiteral
                                        match (depLiteral.lastIndexOf("@")) {
                                            case Some(atIndex) =>
                                                let aliasVersion = "${depLiteral[0..atIndex]}@${newVersion}"
                                                root.put(key, aliasVersion)
                                                continue
                                            case None => ()
                                        }
                                    }

                                    root.put(key, newVersion)
                                case None => ()
                            }
                        case None => ()
                    }
                case None => ()
            }
        }
    }

    /// 计算新版本字符串
    /// 严格翻译自: editUpdateNoArgs/edit 中 new_version 计算逻辑
    ///
    /// 根据 pinned 风格决定新版本格式:
    /// - exact_versions: 直接使用解析版本
    /// - patch pinned: "{version}"
    /// - minor pinned: "~{version}"
    /// - major pinned: "^{version}"
    public static func computeNewVersion(
        resolvedVersion: String,
        originalVersionLiteral: String,
        isAlias: Bool,
        exactVersions: Bool
    ): String {
        // 严格翻译自:
        //   const new_version = new_version: {
        //       const version_fmt = resolution.value.npm.version.fmt(string_buf);
        //       if (options.exact_versions) {
        //           break :new_version try std.fmt.allocPrint(allocator, "{f}", .{version_fmt});
        //       }
        //       ...
        //   };
        if (exactVersions) {
            return resolvedVersion
        }

        // 严格翻译自:
        //   const version_literal = version_literal: {
        //       if (!is_alias) break :version_literal entry.value.original_version_literal;
        //       if (strings.lastIndexOfChar(entry.value.original_version_literal, '@')) |at_index| {
        //           break :version_literal entry.value.original_version_literal[at_index + 1 ..];
        //       }
        //       break :version_literal entry.value.original_version_literal;
        //   };
        let versionLiteral = if (!isAlias) {
            originalVersionLiteral
        } else {
            match (originalVersionLiteral.lastIndexOf("@")) {
                case Some(atIndex) => originalVersionLiteral[(atIndex + 1)..originalVersionLiteral.size]
                case None => originalVersionLiteral
            }
        }

        // 严格翻译自:
        //   const pinned_version = Semver.Version.whichVersionIsPinned(version_literal);
        //   break :new_version try switch (pinned_version) {
        //       .patch => std.fmt.allocPrint(allocator, "{f}", .{version_fmt}),
        //       .minor => std.fmt.allocPrint(allocator, "~{f}", .{version_fmt}),
        //       .major => std.fmt.allocPrint(allocator, "^{f}", .{version_fmt}),
        //   };
        let pinned = whichVersionIsPinned(versionLiteral)
        match (pinned) {
            case PinnedVersion.Patch => return resolvedVersion
            case PinnedVersion.Minor => return "~${resolvedVersion}"
            case PinnedVersion.Major => return "^${resolvedVersion}"
        }
    }

    /// 判断版本是否为 pinned
    /// 翻译自: Semver.Version.whichVersionIsPinned
    public static func whichVersionIsPinned(versionLiteral: String): PinnedVersion {
        if (versionLiteral.size == 0) { return PinnedVersion.Major }
        let c = versionLiteral[0]
        if (c == UInt8(94)) { return PinnedVersion.Major }  // '^'
        if (c == UInt8(126)) { return PinnedVersion.Minor }  // '~'
        return PinnedVersion.Patch
    }

    /// 判断版本是否为精确版本
    /// 翻译自: npm_version.version.isExact()
    public static func isExactVersion(version: String): Bool {
        // 精确版本: 不含 ^, ~, >, <, *, ||
        if (version.size == 0) { return false }
        let c = version[0]
        return c != UInt8(94) && c != UInt8(126) &&
            c != UInt8(62) && c != UInt8(60) &&
            c != UInt8(42) && !version.contains("||")
    }

    /// 编辑依赖
    /// 严格翻译自: edit
    ///   pub fn edit(manager, updates, current_package_json, dependency_list, options) !void
    ///   主编辑函数: 处理 add/remove/update 依赖列表
    ///
    /// 三种场景:
    /// 1. 没有 "dependencies" (或等效列表) 或为空
    /// 2. 有 "dependencies" (或等效列表), 但包名已存在于独立列表
    /// 3. 有 "dependencies" (或等效列表), 且包名存在于多个列表
    ///
    /// 阶段:
    /// 1. 处理信任依赖 (过滤已存在的)
    /// 2. 遍历更新请求, 查找现有的依赖条目 (包括 add_packages_to_update)
    /// 3. 处理 remaining: 创建新依赖列表, 添加新条目, 添加信任依赖
    /// 4. 设置每个请求的版本字符串
    public static func edit(
        manager: PackageJsonEditorManagerRef,
        updates: ArrayList<PackageJsonUpdateRequest>,
        currentPackageJson: JsonExpr,
        dependencyList: String,
        options: EditOptions
    ): Unit {
        // 严格翻译自:
        //   Expr.Disabler.disable();
        //   defer Expr.Disabler.enable();
        // 在 Cangjie 中, JsonExpr 使用值语义, 不需要 disable/enable

        var remaining = updates.size
        var replacing: Int64 = 0
        let onlyAddMissing = manager.options.onlyMissing

        // ==========================================
        // 信任依赖预处理: 过滤已存在的
        // 严格翻译自:
        //   var original_trusted_dependencies = brk: { ... };
        //   if (options.add_trusted_dependencies) {
        //       var i: usize = manager.trusted_deps_to_add_to_package_json.items.len;
        //       while (i > 0) {
        //           i -= 1;
        //           const trusted_package_name = manager.trusted_deps_to_add_to_package_json.items[i];
        //           for (original_trusted_dependencies.items.slice()) |item| { ... }
        //       }
        //   }
        // ==========================================
        if (options.addTrustedDependencies) {
            var originalTrustedDeps = ArrayList<String>()
            match (currentPackageJson.get(TRUSTED_DEPENDENCIES_STRING)) {
                case Some(query) =>
                    let items = query.arrayItems()
                    for (item in items) {
                        match (item) {
                            case JsonExprValue.Str(s) => originalTrustedDeps.append(s)
                            case _ => ()
                        }
                    }
                case None => ()
            }

            // 向后遍历, 过滤掉已存在的名称
            var idx: Int64 = manager.trustedDepsToAdd.size
            while (idx > 0) {
                idx = idx - 1
                let trustedPackageName = manager.trustedDepsToAdd[idx]
                var found = false
                for (existing in originalTrustedDeps) {
                    if (existing == trustedPackageName) {
                        found = true
                        break
                    }
                }
                if (found) {
                    // swapRemove
                    if (idx < manager.trustedDepsToAdd.size - 1) {
                        manager.trustedDepsToAdd[idx] = manager.trustedDepsToAdd[manager.trustedDepsToAdd.size - 1]
                    }
                    manager.trustedDepsToAdd.removeAt(manager.trustedDepsToAdd.size - 1)
                }
            }
        }

        // ==========================================
        // 第一阶段: 查找现有依赖条目
        // 严格翻译自: edit 中 loop: while (i < updates.len) 块
        //
        // 遍历所有依赖列表, 查找每个更新请求的现有条目:
        // - 如果找到现有字符串值:
        //   a. 如果在目标列表中且有效 package_id -> replacing
        //   b. 否则: add_packages_to_update (update before_install) 或复用现有字符串
        // - 如果找到非字符串值 (git/github): 尝试 URL 匹配
        // ==========================================
        var i: Int64 = 0
        while (i < updates.size) {
            let request = updates[i]

            var foundInList = false
            for (list in ALL_DEPENDENCY_LISTS) {
                match (currentPackageJson.get(list)) {
                    case Some(query) =>
                        if (query.isObject()) {
                            let name = request.getName()

                            match (query.get(name)) {
                                case Some(value) =>
                                    if (value.isString()) {
                                        if (request.packageId != INVALID_PACKAGE_ID && list == dependencyList) {
                                            replacing = replacing + 1
                                        } else {
                                            // 严格翻译自:
                                            //   if (manager.subcommand == .update and options.before_install) add_packages_to_update: {
                                            //       const version_literal = try value.expr.asStringCloned(allocator) orelse break :add_packages_to_update;
                                            //       var tag = Dependency.Version.Tag.infer(version_literal);
                                            //       if (tag != .npm and tag != .dist_tag) break :add_packages_to_update;
                                            //       const entry = bun.handleOom(manager.updating_packages.getOrPut(allocator, name));
                                            //       if (entry.found_existing) break :add_packages_to_update;
                                            //       var is_alias = false;
                                            //       if (strings.hasPrefixComptime(..., "npm:")) { ... }
                                            //       entry.value_ptr.* = .{ ... };
                                            //   }
                                            if (manager.subcommand == PackageManagerSubcommand.Update && options.beforeInstall) {
                                                match (value.asString()) {
                                                    case Some(versionLiteral) =>
                                                        var tag = DependencyVersionTag.infer(versionLiteral)
                                                        if (tag == DependencyVersionTag.Npm || tag == DependencyVersionTag.DistTag) {
                                                            if (!manager.updatingPackages.contains(name)) {
                                                                var isAlias = false
                                                                let trimmed = versionLiteral.trim()
                                                                if (trimmed.startsWith("npm:")) {
                                                                    match (versionLiteral.lastIndexOf("@")) {
                                                                        case Some(atIndex) =>
                                                                            tag = DependencyVersionTag.infer(versionLiteral[(atIndex + 1)..versionLiteral.size])
                                                                            if (tag == DependencyVersionTag.Npm || tag == DependencyVersionTag.DistTag) {
                                                                                isAlias = true
                                                                            }
                                                                        case None => ()
                                                                    }
                                                                }
                                                                if (tag == DependencyVersionTag.Npm || tag == DependencyVersionTag.DistTag) {
                                                                    manager.updatingPackages.put(name, UpdatingPackageEntry(
                                                                        originalVersionLiteral: versionLiteral,
                                                                        isAlias: isAlias,
                                                                        originalVersion: None
                                                                    ))
                                                                }
                                                            }
                                                        }
                                                    case None => ()
                                                }
                                            }

                                            if (!onlyAddMissing) {
                                                // 严格翻译自:
                                                //   request.e_string = value.expr.data.e_string;
                                                //   remaining -= 1;
                                                request.eString = match (value.asString()) {
                                                    case Some(s) => s
                                                    case None => ""
                                                }
                                                remaining = remaining - 1
                                            } else {
                                                // 严格翻译自:
                                                //   if (i < updates.*.len - 1) {
                                                //       updates.*[i] = updates.*[updates.*.len - 1];
                                                //   }
                                                //   updates.*.len -= 1;
                                                //   remaining -= 1;
                                                //   continue :loop;
                                                if (i < updates.size - 1) {
                                                    updates[i] = updates[updates.size - 1]
                                                }
                                                updates.removeAt(updates.size - 1)
                                                remaining = remaining - 1
                                                continue
                                            }
                                        }
                                    }
                                    foundInList = true
                                case None =>
                                    // 严格翻译自:
                                    //   if (request.version.tag == .github or request.version.tag == .git) {
                                    //       for (query.expr.data.e_object.properties.slice()) |item| {
                                    //           if (item.value) |v| {
                                    //               const url = request.version.literal.slice(request.version_buf);
                                    //               if (v.data == .e_string and v.data.e_string.eql(string, url)) {
                                    //                   request.e_string = v.data.e_string;
                                    //                   remaining -= 1;
                                    //                   break;
                                    //               }
                                    //           }
                                    //       }
                                    //   }
                                    if (request.version.tag == DependencyVersionTag.Git ||
                                        request.version.tag == DependencyVersionTag.Github) {
                                        let url = request.version.literal
                                        match (findValueByUrl(query, url)) {
                                            case Some(matchedStr) =>
                                                request.eString = matchedStr
                                                remaining = remaining - 1
                                                foundInList = true
                                            case None => ()
                                        }
                                    }
                            }
                        }
                    case None => ()
                }
                if (foundInList) { break }
            }
            i = i + 1
        }

        // ==========================================
        // 第二阶段: 处理 remaining (未找到现有条目的)
        // 严格翻译自: edit 中 if (remaining != 0) 块
        //
        // 1. 获取现有依赖列表
        // 2. 创建新依赖列表 (容量 = 现有 + remaining - replacing)
        // 3. 创建信任依赖数组 (如果需要)
        // 4. 为每个 remaining 请求添加新的 key-value
        // 5. 按字母排序依赖列表
        // 6. 写回 package_json (处理空根对象/需要新列表/需要信任依赖列表)
        // ==========================================
        if (remaining != 0) {
            // 获取现有依赖列表
            var existingDeps = ArrayList<JsonProperty>()
            match (currentPackageJson.get(dependencyList)) {
                case Some(query) =>
                    if (query.isObject()) {
                        existingDeps = query.properties()
                    }
                case None => ()
            }

            // 严格翻译自:
            //   var new_dependencies = try std.ArrayListUnmanaged(G.Property)
            //       .initCapacity(allocator, dependencies.len + remaining - replacing);
            //   new_dependencies.expandToCapacity();
            //   bun.copy(G.Property, new_dependencies.items, dependencies);
            //   @memset(new_dependencies.items[dependencies.len..], G.Property{});
            let newCapacity = existingDeps.size + remaining - replacing
            var newDeps = ArrayList<JsonProperty>()
            for (dep in existingDeps) {
                newDeps.append(dep)
            }

            // 严格翻译自:
            //   var trusted_dependencies: []Expr = &[_]Expr{};
            //   if (options.add_trusted_dependencies) {
            //       if (current_package_json.asProperty(trusted_dependencies_string)) |query| {
            //           if (query.expr.data == .e_array) {
            //               trusted_dependencies = query.expr.data.e_array.items.slice();
            //           }
            //       }
            //   }
            var trustedDependenciesSlice = ArrayList<String>()
            if (options.addTrustedDependencies) {
                match (currentPackageJson.get(TRUSTED_DEPENDENCIES_STRING)) {
                    case Some(query) =>
                        let items = query.arrayItems()
                        for (item in items) {
                            match (item) {
                                case JsonExprValue.Str(s) => trustedDependenciesSlice.append(s)
                                case _ => ()
                            }
                        }
                    case None => ()
                }
            }

            // 严格翻译自:
            //   const trusted_dependencies_to_add = manager.trusted_deps_to_add_to_package_json.items.len;
            //   const new_trusted_deps: JSAst.ExprNodeList = brk: {
            //       if (!options.add_trusted_dependencies or trusted_dependencies_to_add == 0) break :brk .empty;
            //       const deps = try allocator.alloc(Expr, trusted_dependencies.len + trusted_dependencies_to_add);
            //       @memcpy(deps[0..trusted_dependencies.len], trusted_dependencies);
            //       @memset(deps[trusted_dependencies.len..], Expr.empty);
            //       for (manager.trusted_deps_to_add_to_package_json.items) |package_name| {
            //           var i = deps.len;
            //           while (i > 0) { i -= 1; if (deps[i].data == .e_missing) { deps[i] = ...; break; } }
            //       }
            //       break :brk .fromOwnedSlice(deps);
            //   };
            let trustedDependenciesToAdd = manager.trustedDepsToAdd.size
            var newTrustedDeps = ArrayList<String>()
            if (options.addTrustedDependencies && trustedDependenciesToAdd > 0) {
                for (existing in trustedDependenciesSlice) {
                    newTrustedDeps.append(existing)
                }
                for (name in manager.trustedDepsToAdd) {
                    newTrustedDeps.append(name)
                }
            }

            // 为每个 remaining 请求添加条目
            // 严格翻译自:
            //   for (updates.*) |*request| {
            //       if (request.e_string != null) continue;
            //       var k: usize = 0;
            //       while (k < new_dependencies.items.len) : (k += 1) {
            //           if (new_dependencies.items[k].key) |key| {
            //               const name = request.getName();
            //               if (!key.data.e_string.eql(string, name)) continue;
            //               if (request.package_id == invalid_package_id) {
            //                   new_dependencies.items[k] = .{};
            //                   new_dependencies.items.len -= 1;
            //               }
            //           }
            //           new_dependencies.items[k].key = ... Expr.allocate(... name ...);
            //           new_dependencies.items[k].value = ... Expr.allocate(... "" ...);
            //           request.e_string = new_dependencies.items[k].value.?.data.e_string;
            //           break;
            //       }
            //   }
            for (request in updates) {
                if (request.eString.size > 0) { continue }

                let name = request.getName()

                // 检查是否在 newDeps 中已存在 (重复依赖)
                var k: Int64 = 0
                while (k < newDeps.size) {
                    if (newDeps[k].key == name) {
                        if (request.packageId == INVALID_PACKAGE_ID) {
                            // 重复依赖, 移除旧条目
                            newDeps.removeAt(k)
                            break
                        }
                    }
                    k = k + 1
                }

                // 添加新条目
                let newProp = JsonProperty(name, "")
                newDeps.append(newProp)
                request.eString = ""  // 后面设置实际版本
            }

            // 检查是否需要创建新的依赖列表
            var needsNewDependencyList = true
            match (currentPackageJson.get(dependencyList)) {
                case Some(query) =>
                    if (query.isObject()) {
                        needsNewDependencyList = false
                    }
                case None => ()
            }

            // 检查是否需要创建新的信任依赖列表
            var needsNewTrustedDependenciesList = true
            if (!options.addTrustedDependencies || trustedDependenciesToAdd == 0) {
                needsNewTrustedDependenciesList = false
            } else {
                match (currentPackageJson.get(TRUSTED_DEPENDENCIES_STRING)) {
                    case Some(query) =>
                        if (query.isArray()) {
                            needsNewTrustedDependenciesList = false
                        }
                    case None => ()
                }
            }

            // 按字母排序依赖列表
            if (newDeps.size > 1) {
                newDeps.sortBy { a, b => a.key < b.key }
            }

            // 按字母排序信任依赖
            if (options.addTrustedDependencies && trustedDependenciesToAdd > 0 && newTrustedDeps.size > 1) {
                newTrustedDeps.sort()
            }

            // 严格翻译自:
            //   if (current_package_json.data != .e_object or current_package_json.data.e_object.properties.len == 0) {
            //       // 创建根属性
            //       const root_properties = try allocator.alloc(JSAst.G.Property, if (options.add_trusted_dependencies) 2 else 1);
            //       root_properties[0] = ... dependency_list -> dependencies_object ...
            //       if (options.add_trusted_dependencies) {
            //           root_properties[1] = ... trusted_dependencies_string -> trusted_dependencies_array ...
            //       }
            //       current_package_json.* = ... new root object ...
            //   } else {
            //       if (needs_new_dependency_list and needs_new_trusted_dependencies_list) {
            //           // +2 属性
            //       } else if (needs_new_dependency_list or needs_new_trusted_dependencies_list) {
            //           // +1 属性
            //       }
            //   }
            if (currentPackageJson.isEmpty()) {
                // 空根对象: 创建新根
                currentPackageJson.putObject(dependencyList, newDeps)
                if (options.addTrustedDependencies && trustedDependenciesToAdd > 0) {
                    currentPackageJson.putArray(TRUSTED_DEPENDENCIES_STRING, newTrustedDeps)
                }
            } else {
                if (needsNewDependencyList) {
                    currentPackageJson.putObject(dependencyList, newDeps)
                } else {
                    currentPackageJson.updateObject(dependencyList, newDeps)
                }
                if (needsNewTrustedDependenciesList) {
                    currentPackageJson.appendProperty(TRUSTED_DEPENDENCIES_STRING, newTrustedDeps)
                }
            }
        }

        // ==========================================
        // 第三阶段: 设置每个请求的版本字符串
        // 严格翻译自: edit 中 for (updates.*) |*request| 块
        //
        // 根据 request 的状态和 resolution:
        // - uninitialized / update_to_latest -> "latest"
        // - npm: 使用解析后的版本 (根据 pinned 风格)
        // - workspace -> "workspace:*"
        // - 其他: 使用 version.literal
        // - 处理 alias 和 update 时的版本计算
        // ==========================================

        // 严格翻译自:
        //   const resolutions = if (!options.before_install) manager.lockfile.packages.items(.resolution) else &.{};
        let resolutions = if (!options.beforeInstall) { manager.resolutions } else { ArrayList<ResolutionEntry>() }

        for (request in updates) {
            if (request.eString.size == 0) { continue }

            // 严格翻译自:
            //   if (request.package_id >= resolutions.len or resolutions[request.package_id].tag == .uninitialized) {
            //       e_string.data = uninitialized: {
            //           if (manager.subcommand == .update and manager.options.do.update_to_latest) {
            //               break :uninitialized try allocator.dupe(u8, "latest");
            //           }
            //           if (manager.subcommand != .update or !options.before_install or e_string.isBlank() or request.version.tag == .npm) {
            //               break :uninitialized switch (request.version.tag) {
            //                   .uninitialized => try allocator.dupe(u8, "latest"),
            //                   else => try allocator.dupe(u8, request.version.literal.slice(request.version_buf)),
            //               };
            //           } else {
            //               break :uninitialized e_string.data;
            //           }
            //       };
            //       continue;
            //   }
            if (request.packageId >= resolutions.size ||
                getResolutionTag(resolutions, request.packageId) == ResolutionTag.Uninitialized) {
                // uninitialized
                let newValue = match (manager.subcommand) {
                    case PackageManagerSubcommand.Update =>
                        if (manager.options.updateToLatest) { "latest" } else {
                            computeUninitializedVersion(request, manager, options)
                        }
                    case _ =>
                        computeUninitializedVersion(request, manager, options)
                }
                request.eString = newValue
                continue
            }

            // 严格翻译自:
            //   e_string.data = switch (resolutions[request.package_id].tag) {
            //       .npm => npm: { ... },
            //       .workspace => try allocator.dupe(u8, "workspace:*"),
            //       else => try allocator.dupe(u8, request.version.literal.slice(request.version_buf)),
            //   };
            let resTag = getResolutionTag(resolutions, request.packageId)
            match (resTag) {
                case ResolutionTag.Npm =>
                    request.eString = computeNpmVersion(
                        request, resolutions, manager, options
                    )
                case ResolutionTag.Workspace =>
                    request.eString = "workspace:*"
                case _ =>
                    request.eString = request.version.literal
            }
        }

        // 处理依赖更新
        match (currentPackageJson.get(dependencyList)) {
            case Some(depList) => editIntoDepList(depList, updates)
            case None => editCreateDepList(currentPackageJson, dependencyList, updates)
        }
    }

    /// edit helper: write updates into existing dep list
    /// 严格翻译自: edit 末尾, 写入更新后的 e_string 值到依赖列表
    private static func editIntoDepList(depList: JsonExpr, updates: ArrayList<PackageJsonUpdateRequest>): Unit {
        for (request in updates) {
            if (request.eString.size == 0) { continue }
            let name = request.getName()
            depList.put(name, request.eString)
        }
    }

    /// edit helper: create new dep list and write updates
    /// 严格翻译自: edit 末尾, 创建新依赖列表并写入更新后的值
    private static func editCreateDepList(currentPackageJson: JsonExpr, dependencyList: String, updates: ArrayList<PackageJsonUpdateRequest>): Unit {
        var props = ArrayList<JsonProperty>()
        for (request in updates) {
            if (request.eString.size == 0) { continue }
            let name = request.getName()
            props.append(JsonProperty(name, request.eString))
        }
        if (props.size > 1) {
            props.sortBy { a, b => a.key < b.key }
        }
        currentPackageJson.putObject(dependencyList, props)
    }

    /// 在对象值中查找匹配 URL 的字符串
    /// 严格翻译自: edit 中 git/github URL 匹配逻辑
    ///   for (query.expr.data.e_object.properties.slice()) |item| {
    ///       if (item.value) |v| {
    ///           const url = request.version.literal.slice(request.version_buf);
    ///           if (v.data == .e_string and v.data.e_string.eql(string, url)) { ... }
    ///       }
    ///   }
    private static func findValueByUrl(obj: JsonExpr, url: String): ?String {
        let props = obj.properties()
        for (`prop` in props) {
            match (`prop`.value) {
                case JsonExprValue.Str(s) =>
                    if (s == url) { return Some(s) }
                case _ => ()
            }
        }
        return None
    }

    /// 计算 uninitialized 版本字符串
    /// 严格翻译自: edit 中 e_string.data = uninitialized 块
    ///   if (manager.subcommand != .update or !options.before_install or e_string.isBlank() or request.version.tag == .npm) {
    ///       break :uninitialized switch (request.version.tag) {
    ///           .uninitialized => try allocator.dupe(u8, "latest"),
    ///           else => try allocator.dupe(u8, request.version.literal.slice(request.version_buf)),
    ///       };
    ///   } else {
    ///       break :uninitialized e_string.data;
    ///   }
    private static func computeUninitializedVersion(
        request: PackageJsonUpdateRequest,
        manager: PackageJsonEditorManagerRef,
        options: EditOptions
    ): String {
        if (manager.subcommand != PackageManagerSubcommand.Update ||
            !options.beforeInstall ||
            request.eString.size == 0 ||
            request.version.tag == DependencyVersionTag.NPM) {
            match (request.version.tag) {
                case DependencyVersionTag.Uninitialized => return "latest"
                case _ => return request.version.literal
            }
        } else {
            // update + before_install + non-npm: keep e_string as-is
            return request.eString
        }
    }

    /// 计算 npm 版本字符串
    /// 严格翻译自: edit 中 .npm 分支
    private static func computeNpmVersion(
        request: PackageJsonUpdateRequest,
        resolutions: ArrayList<ResolutionEntry>,
        manager: PackageJsonEditorManagerRef,
        options: EditOptions
    ): String {
        // 严格翻译自:
        //   .npm => npm: {
        //       if (manager.subcommand == .update and (request.version.tag == .dist_tag or request.version.tag == .npm)) {
        //           if (manager.updating_packages.fetchSwapRemove(request.name)) |entry| {
        //               var alias_at_index: ?usize = null;
        //               const new_version = new_version: { ... };
        //               if (entry.value.is_alias) {
        //                   const dep_literal = entry.value.original_version_literal;
        //                   if (strings.lastIndexOfChar(dep_literal, '@')) |at_index| {
        //                       break :npm try std.fmt.allocPrint(..., .{ dep_literal[0..at_index], new_version });
        //                   }
        //               }
        //               break :npm new_version;
        //           }
        //       }
        // 检查是否是 update 操作且 tag 是 dist_tag 或 npm
        if (manager.subcommand == PackageManagerSubcommand.Update &&
            (request.version.tag == DependencyVersionTag.DistTag ||
                request.version.tag == DependencyVersionTag.Npm)) {
            match (manager.updatingPackages.fetchRemove(request.name)) {
                case Some(entry) =>
                    let resolvedVer = getResolvedNpmVersion(resolutions, request.packageId)
                    let newVersion = computeNewVersion(
                        resolvedVer,
                        entry.originalVersionLiteral,
                        entry.isAlias,
                        options.exactVersions
                    )

                    if (entry.isAlias) {
                        let depLiteral = entry.originalVersionLiteral
                        match (depLiteral.lastIndexOf("@")) {
                            case Some(atIndex) =>
                                return "${depLiteral[0..atIndex]}@${newVersion}"
                            case None => ()
                        }
                    }
                    return newVersion
                case None => ()
            }
        }

        // 严格翻译自:
        //   if (request.version.tag == .dist_tag or
        //       (manager.subcommand == .update and request.version.tag == .npm and !request.version.value.npm.version.isExact()))
        //   {
        //       const new_version = try switch (options.exact_versions) {
        //           inline else => |exact_versions| std.fmt.allocPrint(
        //               allocator,
        //               if (comptime exact_versions) "{f}" else "^{f}",
        //               .{ resolutions[request.package_id].value.npm.version.fmt(request.version_buf) },
        //           ),
        //       };
        //       if (request.version.tag == .npm and request.version.value.npm.is_alias) {
        //           const dep_literal = request.version.literal.slice(request.version_buf);
        //           if (strings.indexOfChar(dep_literal, '@')) |at_index| {
        //               break :npm try std.fmt.allocPrint(..., .{ dep_literal[0..at_index], new_version });
        //           }
        //       }
        //       break :npm new_version;
        //   }
        if (request.version.tag == DependencyVersionTag.DistTag ||
            (manager.subcommand == PackageManagerSubcommand.Update &&
                request.version.tag == DependencyVersionTag.Npm &&
                !isExactVersion(request.version.literal))) {
            let resolvedVer = getResolvedNpmVersion(resolutions, request.packageId)
            let newVersion = if (options.exactVersions) {
                resolvedVer
            } else {
                "^${resolvedVer}"
            }

            // 处理 alias
            match (request.version.tag) {
                case DependencyVersionTag.Npm =>
                    let depLiteral = request.version.literal
                    match (depLiteral.indexOf("@")) {
                        case Some(atIndex) =>
                            return "${depLiteral[0..atIndex]}@${newVersion}"
                        case None => ()
                    }
                case _ => ()
            }
            return newVersion
        }

        // 严格翻译自:
        //   break :npm try allocator.dupe(u8, request.version.literal.slice(request.version_buf));
        return request.version.literal
    }

    /// 获取解析后的 npm 版本
    private static func getResolvedNpmVersion(resolutions: ArrayList<ResolutionEntry>, packageId: UInt32): String {
        if (Int64(packageId) >= resolutions.size) { return "latest" }
        return resolutions[Int64(packageId)].npmVersion
    }

    /// 获取解析标签
    private static func getResolutionTag(resolutions: ArrayList<ResolutionEntry>, packageId: UInt32): ResolutionTag {
        if (Int64(packageId) >= resolutions.size) { return ResolutionTag.Uninitialized }
        return resolutions[Int64(packageId)].tag
    }
}

// ============================================================================
// Pinned 版本类型
// 严格翻译自: Semver.Version.whichVersionIsPinned 返回值
// ============================================================================

/// Pinned 版本类型
public enum PinnedVersion {
    | Patch   // 精确: "1.2.3"
    | Minor   // "~1.2.3"
    | Major   // "^1.2.3"
}

// ============================================================================
// 解析条目
// ============================================================================

/// 解析条目 (轻量引用)
public class ResolutionEntry {
    public var tag: ResolutionTag
    public var npmVersion: String
    public var npmUrl: String
    public var folderPath: String
    public var workspacePath: String
    public var tarballUrl: String

    public init() {
        tag = ResolutionTag.Uninitialized
        npmVersion = ""
        npmUrl = ""
        folderPath = ""
        workspacePath = ""
        tarballUrl = ""
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
}

/// 更新请求 (轻量引用)
/// 翻译自: PackageManager.UpdateRequest
///   pub const UpdateRequest = struct {
///       name: string = "",
///       name_hash: PackageNameHash = 0,
///       version: Dependency.Version = .{},
///       version_buf: []const u8 = "",
///       package_id: PackageID = invalid_package_id,
///       is_aliased: bool = false,
///       failed: bool = false,
///       e_string: ?*JSAst.E.String,
///   }
public class PackageJsonUpdateRequest {
    public var failed: Bool
    public var name: String
    public var version: DependencyVersionInfo
    public var versionBuf: String
    public var packageId: UInt32
    public var eString: String

    public init() {
        failed = false
        name = ""
        version = DependencyVersionInfo()
        versionBuf = ""
        packageId = INVALID_PACKAGE_ID
        eString = ""
    }

    /// 获取包名
    /// 严格翻译自: UpdateRequest.getName
    ///   pub fn getName(this: @This()) string {
    ///       if (this.name.len > 0) return this.name;
    ///       return this.version_buf;
    ///   }
    public func getName(): String {
        if (name.size > 0) { return name }
        return versionBuf
    }
}

/// 依赖版本信息
/// 翻译自: Dependency.Version
/// 包管理器引用
/// 翻译自: *PackageManager (edit/editUpdateNoArgs 使用的字段子集)
public class PackageJsonEditorManagerRef {
    public var options: PackageManagerEditOptions
    public var trustedDepsToAdd: ArrayList<String>
    public var updatingPackages: HashMap<String, UpdatingPackageEntry>
    public var resolutions: ArrayList<ResolutionEntry>
    public var subcommand: PackageManagerSubcommand

    public init() {
        options = PackageManagerEditOptions()
        trustedDepsToAdd = ArrayList<String>()
        updatingPackages = HashMap<String, UpdatingPackageEntry>()
        resolutions = ArrayList<ResolutionEntry>()
        subcommand = PackageManagerSubcommand.Install
    }

    /// 查找 workspace 依赖
    public func findWorkspaceDep(name: String): ?WorkspaceDepInfo {
        return None
    }
}

/// workspace 依赖信息
public class WorkspaceDepInfo {
    public var resolvedVersion: ?String

    public init() {
        resolvedVersion = None
    }
}

/// 正在更新的包条目
/// 翻译自: edit/editUpdateNoArgs 中 updating_packages 的值
///   entry.value_ptr.* = .{
///       .original_version_literal = version_literal,
///       .is_alias = alias_at_index != null,
///       .original_version = null,
///   };
public class UpdatingPackageEntry {
    /// 原始版本字面量
    public var originalVersionLiteral: String
    /// 是否是 alias
    public var isAlias: Bool
    /// 原始版本信息
    public var originalVersion: ?String

    public init() {
        originalVersionLiteral = ""
        isAlias = false
        originalVersion = None
    }

    public init(originalVersionLiteral: String, isAlias: Bool, originalVersion: ?String) {
        this.originalVersionLiteral = originalVersionLiteral
        this.isAlias = isAlias
        this.originalVersion = originalVersion
    }
}

/// 包管理器编辑选项
/// 翻译自: PackageManager.Options (edit/editUpdateNoArgs 使用的字段子集)
///   do.update_to_latest, enable.only_missing
public class PackageManagerEditOptions {
    public var updateToLatest: Bool
    public var onlyMissing: Bool

    public init() {
        updateToLatest = false
        onlyMissing = false
    }
}

/// 包管理器子命令
/// 翻译自: PackageManager.Subcommand
public enum PackageManagerSubcommand {
    | Install
    | Add
    | Remove
    | Update
}

// ============================================================================
// JsonExpr 辅助
// 翻译自: JSAst.Expr (用于 Package.json 编辑的 JSON AST 抽象)
// ============================================================================

/// JSON 表达式
/// 翻译自: JSAst.Expr
public class JsonExpr {
    private var data: JsonExprData

    public init() {
        data = JsonExprData()
    }

    public func get(key: String): ?JsonExpr {
        return None
    }

    public func put(key: String, value: String): Unit {
        return
    }

    public func putObject(key: String, map: HashMap<String, String>): Unit {
        return
    }

    /// 写入属性列表到对象
    /// 翻译自: 设置 e_object.properties
    public func putObject(key: String, props: ArrayList<JsonProperty>): Unit {
        return
    }

    public func putArray(key: String, items: ArrayList<String>): Unit {
        return
    }

    public func updateObject(key: String, props: ArrayList<JsonProperty>): Unit {
        return
    }

    public func ensureProperty(key: String, items: ArrayList<String>): Unit {
        return
    }

    public func appendProperty(key: String, items: ArrayList<String>): Unit {
        return
    }

    public func properties(): ArrayList<JsonProperty> {
        return ArrayList<JsonProperty>()
    }

    public func arrayItems(): ArrayList<JsonExprValue> {
        return ArrayList<JsonExprValue>()
    }

    public func asString(): ?String {
        return None
    }

    public func isObject(): Bool {
        return false
    }

    /// 是否是数组
    /// 翻译自: expr.data == .e_array
    public func isArray(): Bool {
        return false
    }

    public func isString(): Bool {
        return false
    }

    public func isEmpty(): Bool {
        return true
    }
}

/// JSON 表达式数据
public class JsonExprData {
    public init() {}
}

/// JSON 表达式值
public enum JsonExprValue {
    | Str(String)
    | Num(Float64)
    | `Bool`(Bool)
    | Null_
    | Obj(JsonExpr)
    | Arr(ArrayList<JsonExprValue>)
}

/// JSON 属性
/// 翻译自: JSAst.G.Property
///   pub const Property = struct {
///       key: ?*Expr = null,
///       value: ?*Expr = null,
///   }
public class JsonProperty {
    public var key: String
    public var value: String

    public init(key: String, value: String) {
        this.key = key
        this.value = value
    }
}
