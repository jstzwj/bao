// bao_install - 命令行参数
// 严格翻译自: src/install/PackageManager/CommandLineArguments.zig
//   CLI Arguments for: bun install, bun update, bun patch, bun patch-commit,
//   bun pm, bun add, bun remove, bun link, bun audit
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 审计级别
// 严格翻译自: CommandLineArguments.AuditLevel
// ============================================================================

/// 审计级别
/// 翻译自: CommandLineArguments.AuditLevel
public enum AuditLevel {
    | Low
    | Moderate
    | High
    | Critical

    public static func fromString(str: String): ?AuditLevel {
        if (str == "low") { return Low }
        if (str == "moderate") { return Moderate }
        if (str == "high") { return High }
        if (str == "critical") { return Critical }
        return None
    }

    public func shouldIncludeSeverity(severity: String): Bool {
        let severityLevel = AuditLevel.fromString(severity).getOr(Moderate)
        return severityLevel.toInt() >= toInt()
    }

    public func toInt(): Int64 {
        match (this) {
            case Low => 0
            case Moderate => 1
            case High => 2
            case Critical => 3
        }
    }
}

// ============================================================================
// Patch 选项
// 严格翻译自: CommandLineArguments.PatchOpts
//   const PatchOpts = union(enum) {
//       nothing: struct {},
//       patch: struct {},
//       commit: struct { patches_dir: []const u8 = "patches" },
//   }
// ============================================================================

/// Patch 选项
/// 翻译自: CommandLineArguments.PatchOpts
public enum PatchOpts {
    | Nothing
    | Patch
    | Commit(String)   // patches_dir
}

// ============================================================================
// Omit 选项
// 严格翻译自: CommandLineArguments.Omit
//   const Omit = struct { dev: bool, optional: bool, peer: bool }
// ============================================================================

/// Omit 选项
/// 翻译自: CommandLineArguments.Omit
public class OmitOptions {
    public var dev: Bool
    public var optional: Bool
    public var peer: Bool

    public init() {
        dev = false
        optional = false
        peer = false
    }
}

// ============================================================================
// 命令行参数
// 严格翻译自: src/install/PackageManager/CommandLineArguments.zig - CommandLineArguments
//   const CommandLineArguments = @This();
//   cache_dir: ?string, token: string, global: bool, config: ?string,
//   positionals: []const string, yarn: bool, production: bool, ...
// ============================================================================

/// 命令行参数
/// 对应 Bun: PackageManager.CommandLineArguments
/// 翻译自: src/install/PackageManager/CommandLineArguments.zig
public class CommandLineArgumentsFull {
    // ===== 缓存与配置 =====

    /// 缓存目录
    public var cacheDir: ?String
    /// 锁文件路径
    public var lockfile: String
    /// 认证 token
    public var token: String
    /// 是否全局安装
    public var global: Bool
    /// 配置文件路径
    public var config: ?String
    /// 网络并发数
    public var networkConcurrency: ?UInt16
    /// 后端方式
    public var backend: ?String

    // ===== 位置参数 =====

    /// 位置参数列表
    public var positionals: ArrayList<String>

    // ===== 标志位 =====

    /// 是否写 yarn.lock
    public var yarn: Bool
    /// 生产模式
    public var production: Bool
    /// 冻结锁文件
    public var frozenLockfile: Bool
    /// 不保存
    public var noSave: Bool
    /// 干运行
    public var dryRun: Bool
    /// 强制
    public var force: Bool
    /// 不使用缓存
    public var noCache: Bool
    /// 静默模式
    public var silent: Bool
    /// 安静模式
    public var quiet: Bool
    /// 详细模式
    public var verbose: Bool
    /// 不显示进度条
    public var noProgress: Bool
    /// 不验证
    public var noVerify: Bool
    /// 忽略脚本
    public var ignoreScripts: Bool
    /// 信任依赖
    public var trusted: Bool
    /// 不显示摘要
    public var noSummary: Bool
    /// 更新到最新
    public var latest: Bool
    /// 交互模式
    public var interactive: Bool
    /// JSON 输出
    public var jsonOutput: Bool
    /// 递归
    public var recursive: Bool

    // ===== 过滤器 =====

    /// Workspace 过滤模式
    public var filters: ArrayList<String>

    // ===== Pack 选项 =====

    /// pack 目标目录
    public var packDestination: String
    /// pack 文件名
    public var packFilename: String
    /// pack gzip 压缩级别
    public var packGzipLevel: ?String

    // ===== 依赖类型 =====

    /// 开发依赖
    public var development: Bool
    /// 可选依赖
    public var optional: Bool
    /// peer 依赖
    public var peer: Bool
    /// 精确版本
    public var exact: Bool
    /// 分析模式
    public var analyze: Bool
    /// 仅缺失
    public var onlyMissing: Bool

    // ===== 并发 =====

    /// 并发脚本数
    public var concurrentScripts: ?Int64

    // ===== Patch =====

    /// patch 选项
    public var patch: PatchOpts

    // ===== 注册表 =====

    /// 注册表 URL
    public var registry: String

    // ===== 发布配置 =====

    /// 发布访问级别
    public var publishAccess: ?String
    /// 发布标签
    public var publishTag: String
    /// OTP 密码
    public var publishOtp: String
    /// 认证类型
    public var publishAuthType: ?String
    /// 允许重新发布
    public var tolerateRepublish: Bool

    // ===== CA 证书 =====

    /// CA 证书
    public var ca: ArrayList<String>
    /// CA 文件
    public var caFileName: String

    // ===== 锁文件 =====

    /// 保存文本锁文件
    public var saveTextLockfile: ?Bool
    /// 仅锁文件
    public var lockfileOnly: Bool

    // ===== 链接模式 =====

    /// node 链接模式
    public var nodeLinker: ?NodeLinker

    // ===== 最小发布年龄 =====

    /// 最小发布年龄 (毫秒)
    public var minimumReleaseAgeMs: ?Float64

    // ===== pm version 选项 =====

    /// Git tag 版本
    public var gitTagVersion: Bool
    /// 允许相同版本
    public var allowSameVersion: Bool
    /// pre-id
    public var preid: String
    /// 提交消息
    public var message: ?String

    // ===== pm why 选项 =====

    /// 仅显示顶层
    public var topOnly: Bool
    /// 深度
    public var depth: ?Int64

    // ===== audit 选项 =====

    /// 审计级别
    public var auditLevel: ?AuditLevel
    /// 审计忽略列表
    public var auditIgnoreList: ArrayList<String>

    public init() {
        cacheDir = None
        lockfile = ""
        token = ""
        global = false
        config = None
        networkConcurrency = None
        backend = None
        positionals = ArrayList<String>()
        yarn = false
        production = false
        frozenLockfile = false
        noSave = false
        dryRun = false
        force = false
        noCache = false
        silent = false
        quiet = false
        verbose = false
        noProgress = false
        noVerify = false
        ignoreScripts = false
        trusted = false
        noSummary = false
        latest = false
        interactive = false
        jsonOutput = false
        recursive = false
        filters = ArrayList<String>()
        packDestination = ""
        packFilename = ""
        packGzipLevel = None
        development = false
        optional = false
        peer = false
        exact = false
        analyze = false
        onlyMissing = false
        concurrentScripts = None
        patch = PatchOpts.Nothing
        registry = ""
        publishAccess = None
        publishTag = ""
        publishOtp = ""
        publishAuthType = None
        tolerateRepublish = false
        ca = ArrayList<String>()
        caFileName = ""
        saveTextLockfile = None
        lockfileOnly = false
        nodeLinker = None
        minimumReleaseAgeMs = None
        gitTagVersion = true
        allowSameVersion = false
        preid = ""
        message = None
        topOnly = false
        depth = None
        auditLevel = None
        auditIgnoreList = ArrayList<String>()
    }
}
