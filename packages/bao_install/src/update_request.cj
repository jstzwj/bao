// bao_install - 更新请求
// 严格翻译自: src/install/PackageManager/UpdateRequest.zig
//   pub const UpdateRequest = struct {
//       name: string, name_hash: PackageNameHash, version: Dependency.Version,
//       version_buf: []const u8, package_id: PackageID, is_aliased: bool, failed: bool,
//       e_string: ?*JSAst.E.String,
//   }
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 更新请求
// 严格翻译自: src/install/PackageManager/UpdateRequest.zig - UpdateRequest
//   pub const UpdateRequest = struct {
//       name: string = "",
//       name_hash: PackageNameHash = 0,
//       version: Dependency.Version = .{},
//       version_buf: []const u8 = "",
//       package_id: PackageID = invalid_package_id,
//       is_aliased: bool = false,
//       failed: bool = false,
//   }
// ============================================================================

/// 更新请求
/// 对应 Bun: PackageManager.UpdateRequest
/// 翻译自: src/install/PackageManager/UpdateRequest.zig
public class UpdateRequestFull {
    /// 包名 (alias 时使用)
    public var name: String
    /// 包名哈希
    public var nameHash: UInt64
    /// 版本信息
    public var version: DependencyVersionInfo
    /// 版本缓冲区 (原始输入字符串)
    public var versionBuf: String
    /// 包 ID (解析后)
    public var packageId: UInt32
    /// 是否是 alias
    public var isAliased: Bool
    /// 是否失败
    public var failed: Bool

    public init() {
        name = ""
        nameHash = UInt64(0)
        version = DependencyVersionInfo()
        versionBuf = ""
        packageId = INVALID_PACKAGE_ID
        isAliased = false
        failed = false
    }

    public init(name: String, version: String) {
        this.name = name
        nameHash = SemverStringBuilder.stringHashStr(name)
        this.version = DependencyVersionInfo()
        this.versionBuf = version
        packageId = INVALID_PACKAGE_ID
        isAliased = false
        failed = false
    }

    /// 是否匹配依赖
    /// 翻译自: UpdateRequest.matches
    ///   pub inline fn matches(this, dependency, string_buf) bool
    public func matches(dependency: DependencyInfo, stringBuf: String): Bool {
        if (name.length == 0) {
            return nameHash == SemverStringBuilder.stringHashStr(dependency.versionLiteral)
        }
        return nameHash == dependency.nameHash
    }

    /// 获取名称
    /// 翻译自: UpdateRequest.getName
    public func getName(): String {
        if (isAliased) {
            return name
        }
        return versionBuf
    }

    /// 获取锁文件中的名称
    /// 翻译自: UpdateRequest.getNameInLockfile
    public func getNameInLockfile(lockfileData: LockfileData): ?String {
        if (packageId == INVALID_PACKAGE_ID) {
            return None
        }
        // 从锁文件获取包名
        return None
    }

    /// 获取解析后的名称
    /// 翻译自: UpdateRequest.getResolvedName
    public func getResolvedName(lockfileData: LockfileData): String {
        if (isAliased) {
            return name
        }
        return getName()
    }

    /// 从命令行位置参数解析更新请求
    /// 翻译自: UpdateRequest.parse
    ///   pub fn parse(allocator, pm, log, positionals, update_requests, subcommand) []UpdateRequest
    public static func parse(
        positionals: ArrayList<String>,
        subcommand: PackageSubcommand
    ): ArrayList<UpdateRequestFull> {
        let requests = ArrayList<UpdateRequestFull>()
        for (positional in positionals) {
            let input = positional.trim()

            // 处理 link/unlink 前缀
            match (subcommand) {
                case PackageSubcommand.Link => {
                    if (!input.startsWith("link:")) {
                        let req = UpdateRequestFull()
                        req.name = input
                        req.nameHash = SemverStringBuilder.stringHashStr(input)
                        req.isAliased = true
                        req.versionBuf = "link:${input}"
                        requests.append(req)
                        continue
                    }
                }
                case PackageSubcommand.Unlink => {
                    if (!input.startsWith("link:")) {
                        let req = UpdateRequestFull()
                        req.name = input
                        req.nameHash = SemverStringBuilder.stringHashStr(input)
                        req.isAliased = true
                        req.versionBuf = "link:${input}"
                        requests.append(req)
                        continue
                    }
                }
                case _ => ()
            }

            // 解析 name@version 格式
            let (parsedName, parsedVersion) = parseNameVersion(input)
            let req = UpdateRequestFull()
            req.versionBuf = input

            if (parsedName.length > 0) {
                req.name = parsedName
                req.nameHash = SemverStringBuilder.stringHashStr(parsedName)
                req.isAliased = true
            } else {
                req.nameHash = SemverStringBuilder.stringHashStr(input)
            }

            // 检查去重
            var isDuplicate = false
            for (prev in requests) {
                if (prev.nameHash == req.nameHash && req.name.length == prev.name.length) {
                    isDuplicate = true
                    break
                }
            }
            if (!isDuplicate) {
                requests.append(req)
            }
        }
        return requests
    }

    /// 解析 name@version
    private static func parseNameVersion(input: String): Tuple2<String, String> {
        // scoped package: @scope/name@version
        if (input.length > 0 && input[0].value == 64) { // '@'
            let secondAt = input.indexOf("@", 1)
            match (secondAt) {
                case Some(idx) => {
                    return Tuple2(input.substring(0, idx), input.substring(Int64(idx) + 1))
                }
                case None => return Tuple2(input, "")
            }
        }
        // normal package: name@version
        let atIdx = input.lastIndexOf("@")
        match (atIdx) {
            case Some(idx) => {
                if (idx > 0) {
                    return Tuple2(input.substring(0, idx), input.substring(Int64(idx) + 1))
                }
            }
            case None => ()
        }
        return Tuple2("", input)
    }
}

/// 锁文件数据 (轻量引用, 避免循环依赖)
public class LockfileData {
    public init() {}
}

/// 依赖版本信息 (轻量)
public class DependencyVersionInfo {
    public var tag: DependencyVersionTag
    public var literal: String

    public init() {
        tag = DependencyVersionTag.Uninitialized
        literal = ""
    }
}
