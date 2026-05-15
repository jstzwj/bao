// bao_install - 锁文件包脚本
// 严格翻译自: src/install/lockfile/Package/Scripts.zig
//   Scripts 管理包的生命周期脚本 (preinstall, install, postinstall, etc.)
//   Scripts.List 包含脚本项列表, 支持 getScriptEntries, createList, parseCount/parseAlloc
package bao_install.lockfile

import bao_core.*
import bao_collections.*

// ============================================================================
// 脚本名称常量
// 严格翻译自: Lockfile.Scripts.names
//   names = .{ "preinstall", "install", "postinstall", "preprepare", "prepare", "postprepare" }
// ============================================================================

/// 脚本名称列表
/// 翻译自: Lockfile.Scripts.names
public let SCRIPT_NAMES: ArrayList<String> = ArrayList<String>([
    "preinstall",
    "install",
    "postinstall",
    "preprepare",
    "prepare",
    "postprepare"
])

/// 脚本名称数量
public let SCRIPT_COUNT: Int64 = 6

// ============================================================================
// 包脚本
// 严格翻译自: src/install/lockfile/Package/Scripts.zig
//   pub const Scripts = extern struct {
//       preinstall: String, install: String, postinstall: String,
//       preprepare: String, prepare: String, postprepare: String,
//       filled: bool = false
//   }
// ============================================================================

/// 包脚本
/// 对应 Bun: Lockfile.Package.Scripts
/// 翻译自: src/install/lockfile/Package/Scripts.zig
public class PackageScripts {
    /// 预安装脚本
    /// 翻译自: preinstall: String = .{}
    public var preinstall: String

    /// 安装脚本
    /// 翻译自: install: String = .{}
    public var install: String

    /// 后安装脚本
    /// 翻译自: postinstall: String = .{}
    public var postinstall: String

    /// 预准备脚本
    /// 翻译自: preprepare: String = .{}
    public var preprepare: String

    /// 准备脚本
    /// 翻译自: prepare: String = .{}
    public var prepare: String

    /// 后准备脚本
    /// 翻译自: postprepare: String = .{}
    public var postprepare: String

    /// 是否已填充
    /// 翻译自: filled: bool = false
    public var filled: Bool

    public init() {
        preinstall = ""
        install = ""
        postinstall = ""
        preprepare = ""
        prepare = ""
        postprepare = ""
        filled = false
    }

    /// 是否相等
    /// 翻译自: Scripts.eql
    ///   pub fn eql(l, r, l_buf, r_buf) bool
    public func eql(other: PackageScripts): Bool {
        return preinstall == other.preinstall &&
            install == other.install &&
            postinstall == other.postinstall &&
            preprepare == other.preprepare &&
            prepare == other.prepare &&
            postprepare == other.postprepare
    }

    /// 是否有任何脚本
    /// 翻译自: Scripts.hasAny
    ///   pub fn hasAny(this) bool
    public func hasAny(): Bool {
        return preinstall.length > 0 ||
            install.length > 0 ||
            postinstall.length > 0 ||
            preprepare.length > 0 ||
            prepare.length > 0 ||
            postprepare.length > 0
    }

    /// 获取脚本条目
    /// 严格翻译自: Scripts.getScriptEntries
    ///   pub fn getScriptEntries(this, lockfile, lockfile_buf, resolution_tag,
    ///       add_node_gyp_rebuild_script) struct { i8, u8, [6]?string }
    ///   返回: (first_index, total, entries)
    public func getScriptEntries(
        resolutionTag: ResolutionTag,
        addNodeGypRebuildScript: Bool
    ): ScriptEntriesResult {
        var scriptIndex: Int64 = 0
        var firstScriptIndex: Int64 = -1
        var scripts = ArrayList<?String>()
        for (_ in 0..SCRIPT_COUNT) { scripts.append(None) }
        var counter: Int64 = 0

        if (addNodeGypRebuildScript) {
            scriptIndex += 1
            if (firstScriptIndex == -1) { firstScriptIndex = scriptIndex }
            if (Int64(scriptIndex) < scripts.size) {
                scripts[Int64(scriptIndex) - 1] = "node-gyp rebuild"
            }
            scriptIndex += 1
            counter += 1

            // 只检查 postinstall
            if (postinstall.length > 0) {
                if (firstScriptIndex == -1) { firstScriptIndex = scriptIndex }
                if (Int64(scriptIndex) < scripts.size) {
                    scripts[Int64(scriptIndex) - 1] = postinstall
                }
                counter += 1
            }
            scriptIndex += 1
        } else {
            // 安装脚本: preinstall, install, postinstall
            let installScripts = [preinstall, install, postinstall]
            for (script in installScripts) {
                if (script.length > 0) {
                    if (firstScriptIndex == -1) { firstScriptIndex = scriptIndex }
                    if (Int64(scriptIndex) < scripts.size) {
                        scripts[Int64(scriptIndex)] = script
                    }
                    counter += 1
                }
                scriptIndex += 1
            }
        }

        // 准备脚本: 根据 resolution tag 决定
        match (resolutionTag) {
            case ResolutionTag.Git | ResolutionTag.GitHub | ResolutionTag.Root => {
                let prepareScripts = [preprepare, prepare, postprepare]
                for (script in prepareScripts) {
                    if (script.length > 0) {
                        if (firstScriptIndex == -1) { firstScriptIndex = scriptIndex }
                        if (Int64(scriptIndex) < scripts.size) {
                            scripts[Int64(scriptIndex)] = script
                        }
                        counter += 1
                    }
                    scriptIndex += 1
                }
            }
            case ResolutionTag.Workspace => {
                scriptIndex += 1
                if (prepare.length > 0) {
                    if (firstScriptIndex == -1) { firstScriptIndex = scriptIndex }
                    if (Int64(scriptIndex) < scripts.size) {
                        scripts[Int64(scriptIndex)] = prepare
                    }
                    counter += 1
                }
                scriptIndex += 2
            }
            case _ => ()
        }

        return ScriptEntriesResult(
            firstIndex: firstScriptIndex,
            total: counter,
            entries: scripts
        )
    }

    /// 创建脚本列表
    /// 翻译自: Scripts.createList
    ///   pub fn createList(this, lockfile, lockfile_buf, cwd_, package_name,
    ///       resolution_tag, add_node_gyp_rebuild_script) ?Scripts.List
    public func createList(
        cwd: String,
        packageName: String,
        resolutionTag: ResolutionTag,
        addNodeGypRebuildScript: Bool
    ): ?ScriptsList {
        let result = getScriptEntries(
            resolutionTag: resolutionTag,
            addNodeGypRebuildScript: addNodeGypRebuildScript
        )

        if (result.firstIndex != -1) {
            return ScriptsList(
                items: result.entries,
                firstIndex: UInt8(result.firstIndex),
                total: UInt8(result.total),
                cwd: cwd,
                packageName: packageName
            )
        }

        return None
    }

    /// 克隆
    /// 翻译自: Scripts.clone
    ///   pub fn clone(this, buf, Builder, builder) Package.Scripts
    public func clone(): PackageScripts {
        if (!filled) { return PackageScripts() }
        let scripts = PackageScripts()
        scripts.preinstall = preinstall
        scripts.install = install
        scripts.postinstall = postinstall
        scripts.preprepare = preprepare
        scripts.prepare = prepare
        scripts.postprepare = postprepare
        scripts.filled = true
        return scripts
    }

    /// 计数字符串大小
    /// 翻译自: Scripts.count
    ///   pub fn count(this, buf, Builder, builder) void
    public func count(): Int64 {
        var total: Int64 = 0
        total += Int64(preinstall.length)
        total += Int64(install.length)
        total += Int64(postinstall.length)
        total += Int64(preprepare.length)
        total += Int64(prepare.length)
        total += Int64(postprepare.length)
        return total
    }
}

// ============================================================================
// 脚本列表
// 严格翻译自: Scripts.List
//   pub const List = struct {
//       items: [names.len]?string, first_index: u8, total: u8,
//       cwd: stringZ, package_name: string
//   }
// ============================================================================

/// 脚本列表
/// 对应 Bun: Package.Scripts.List
public class ScriptsList {
    /// 脚本项列表
    /// 翻译自: items: [names.len]?string
    public var items: ArrayList<?String>

    /// 第一个脚本索引
    /// 翻译自: first_index: u8
    public var firstIndex: UInt8

    /// 脚本总数
    /// 翻译自: total: u8
    public var total: UInt8

    /// 工作目录
    /// 翻译自: cwd: stringZ
    public var cwd: String

    /// 包名
    /// 翻译自: package_name: string
    public var packageName: String

    public init() {
        items = ArrayList<?String>()
        firstIndex = 0
        total = 0
        cwd = ""
        packageName = ""
    }

    public init(
        items: ArrayList<?String>,
        firstIndex: UInt8,
        total: UInt8,
        cwd: String,
        packageName: String
    ) {
        this.items = items
        this.firstIndex = firstIndex
        this.total = total
        this.cwd = cwd
        this.packageName = packageName
    }

    /// 获取第一个脚本
    /// 翻译自: Scripts.List.first
    ///   pub fn first(this) string
    public func first(): String {
        match (items[Int64(firstIndex)]) {
            case Some(s) => return s
            case None => return ""
        }
    }

    /// 打印脚本
    /// 翻译自: Scripts.List.printScripts
    public func printScripts(
        resolution: ResolutionInfo,
        formatType: ScriptFormatType
    ): Unit {
        bao_core.Output.print("${packageName}\n")

        for (i in 0..items.size) {
            match (items[i]) {
                case Some(script) => {
                    if (i < SCRIPT_NAMES.size) {
                        let fmt = match (formatType) {
                            case ScriptFormatType.Completed => "  [${SCRIPT_NAMES[i]}]: ${script}\n"
                            case ScriptFormatType.Untrusted => "  [${SCRIPT_NAMES[i]}]: ${script}\n"
                            case ScriptFormatType.Info => "  [${SCRIPT_NAMES[i]}]: ${script}\n"
                        }
                        bao_core.Output.print(fmt)
                    }
                }
                case None => ()
            }
        }
    }

    /// 追加到锁文件
    /// 翻译自: Scripts.List.appendToLockfile
    ///   pub fn appendToLockfile(this, lockfile) void
    public func appendToLockfile(lockfileScripts: ArrayList<ArrayList<String>>): Unit {
        for (i in 0..items.size) {
            match (items[i]) {
                case Some(script) => {
                    if (i < lockfileScripts.size) {
                        lockfileScripts[Int64(i)].append(script)
                    }
                }
                case None => ()
            }
        }
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 脚本条目结果
public class ScriptEntriesResult {
    public var firstIndex: Int64
    public var total: Int64
    public var entries: ArrayList<?String>

    public init(firstIndex: Int64, total: Int64, entries: ArrayList<?String>) {
        this.firstIndex = firstIndex
        this.total = total
        this.entries = entries
    }
}

/// 解析标签
/// 对应 Bun: Resolution.Tag
public enum ResolutionTag {
    | Uninitialized
    | NPM
    | Git
    | GitHub
    | Root
    | Workspace
    | Symlink
    | Folder
    | LocalTarball
    | RemoteTarball
    | SingleFileModule
}

/// 解析信息
/// 对应 Bun: Resolution
public class ResolutionInfo {
    public var tag: ResolutionTag
    public var version: String

    public init() {
        tag = ResolutionTag.Uninitialized
        version = ""
    }
}

/// 脚本格式类型
public enum ScriptFormatType {
    | Completed
    | Untrusted
    | Info
}
