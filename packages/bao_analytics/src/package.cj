// bao_analytics - 遥测与分析数据结构
// 严格翻译自: bun/src/analytics/analytics.zig (381行) + schema.zig (527行)
//   匿名使用统计、平台检测、事件收集
package bao_analytics

import bao_core.*

// ============================================================================
// TriState - 三态枚举 (yes/no/unknown)
// 严格翻译自: analytics.zig - enabled, is_ci
//   pub var enabled: enum { yes, no, unknown } = .unknown;
// ============================================================================

/// 三态枚举 - 对应 Bun analytics enabled/is_ci
public enum TriState {
    | Yes
    | No
    | Unknown
}

// ============================================================================
// OperatingSystem - 操作系统枚举
// 严格翻译自: schema.zig - analytics.OperatingSystem
//   pub const OperatingSystem = enum(u8) {
//       _none, linux, macos, windows, wsl, android, freebsd, _,
//   };
// ============================================================================

/// 操作系统枚举 - 对应 Bun analytics.OperatingSystem
public enum OperatingSystem {
    | None
}
    }
}

// ============================================================================
// Architecture - CPU 架构枚举
// 严格翻译自: schema.zig - analytics.Architecture
//   pub const Architecture = enum(u8) { _none, x64, arm, _ };
// ============================================================================

/// CPU 架构枚举 - 对应 Bun analytics.Architecture
public enum Architecture {
    | None
}
    }
}

// ============================================================================
// Platform - 平台信息
// 严格翻译自: schema.zig - analytics.Platform
//   pub const Platform = struct {
//       os: OperatingSystem, arch: Architecture, version: []const u8,
//       pub fn decode(reader) !Platform
//       pub fn encode(this, writer) !void
//   };
// ============================================================================

/// 平台信息 - 对应 Bun analytics.Platform
public class Platform {
    /// 操作系统
    public var os: OperatingSystem
    /// CPU 架构
    public var arch: Architecture
    /// 系统版本
    public var version: String

    public init() {
        os = OperatingSystem.None
        arch = Architecture.None
        version = ""
    }

    public init(os: OperatingSystem, arch: Architecture, version: String) {
        this.os = os
        this.arch = arch
        this.version = version
    }

    /// 编码为字节数组
    /// 对应 Bun Platform.encode()
    public func encode(): Array<Byte> {
        let buf = ArrayList<Byte>()
        buf.append(os.value)
        buf.append(arch.value)
        // 写入版本字符串长度 (u32 LE) + 内容
        let vBytes = version.toArray()
        appendInt32LE(buf, Int32(vBytes.size))
        for (b in vBytes) { buf.append(b) }
        buf.toArray()
    }

    /// 从字节数组解码
    /// 对应 Bun Platform.decode()
    public static func decode(data: Array<Byte>): ?Platform {
        if (data.size < 2) { return None }
        let os = OperatingSystem(data[0])
        let arch = Architecture(data[1])
        if (data.size < 6) { return None }
        let versionLen = Int32(readInt32LE(data, 2))
        if (versionLen < 0 || data.size < 6 + versionLen) { return None }
        let version = String.fromUtf8(data[6..(6 + versionLen)])
        Platform(os, arch, version)
    }
}

// ============================================================================
// EventKind - 事件类型
// 严格翻译自: schema.zig - analytics.EventKind
//   pub const EventKind = enum(u32) {
//       _none, bundle_success, bundle_fail, http_start, http_build, bundle_start, _,
//   };
// ============================================================================

/// 事件类型枚举 - 对应 Bun analytics.EventKind
public enum EventKind {
    | None
}
    }

    public static func fromName(name: String): ?EventKind {
        match (name) {
            case "_none" => EventKind.None
            case "bundle_success" => EventKind.BundleSuccess
            case "bundle_fail" => EventKind.BundleFail
            case "http_start" => EventKind.HttpStart
            case "http_build" => EventKind.HttpBuild
            case "bundle_start" => EventKind.BundleStart
            | _ => None
        }
    }
}

// ============================================================================
// EventName - 事件名称枚举 (analytics.zig)
// 严格翻译自: analytics.zig - EventName
//   pub const EventName = enum(u8) {
//       bundle_success, bundle_fail, bundle_start, http_start, http_build,
//   };
// ============================================================================

/// 事件名称枚举 - 对应 Bun analytics.EventName
public enum EventName {
    | None
}

// ============================================================================
// Uint64 - 分割的 64 位整数 (两个 u32)
// 严格翻译自: schema.zig - analytics.Uint64
//   pub const Uint64 = packed struct { first: u32 = 0, second: u32 = 0 };
// ============================================================================

/// 分割的 64 位整数 - 对应 Bun analytics.Uint64
/// 将 u64 拆分为两个 u32, 便于跨平台传输
public class AnalyticsUint64 {
    public var first: UInt32
    public var second: UInt32

    public init() {
        first = 0
        second = 0
    }

    public init(first: UInt32, second: UInt32) {
        this.first = first
        this.second = second
    }

    /// 从 UInt64 构造
    public init(v: UInt64) {
        first = UInt32(v & 0xFFFFFFFF)
        second = UInt32((v >> 32) & 0xFFFFFFFF)
    }

    /// 转换为 UInt64
    public func toUInt64(): UInt64 {
        UInt64(first) | (UInt64(second) << 32)
    }

    /// 编码为字节数组
    public func encode(): Array<Byte> {
        let buf = ArrayList<Byte>()
        appendInt32LE(buf, Int32(first))
        appendInt32LE(buf, Int32(second))
        buf.toArray()
    }

    /// 从字节数组解码
    public static func decode(data: Array<Byte>): ?AnalyticsUint64 {
        if (data.size < 8) { return None }
        let first = UInt32(readInt32LE(data, 0))
        let second = UInt32(readInt32LE(data, 4))
        AnalyticsUint64(first, second)
    }
}

// ============================================================================
// EventListHeader - 事件列表头
// 严格翻译自: schema.zig - analytics.EventListHeader
//   pub const EventListHeader = struct {
//       machine_id: Uint64, session_id: u32, platform: Platform,
//       build_id: u32, project_id: Uint64, session_length: u32, feature_usage: u32,
//   };
// ============================================================================

/// 事件列表头 - 对应 Bun analytics.EventListHeader
public class EventListHeader {
    /// 机器 ID
    public var machineId: AnalyticsUint64
    /// 会话 ID
    public var sessionId: UInt32
    /// 平台信息
    public var platform: Platform
    /// 构建 ID
    public var buildId: UInt32
    /// 项目 ID
    public var projectId: AnalyticsUint64
    /// 会话长度
    public var sessionLength: UInt32
    /// 特性使用计数
    public var featureUsage: UInt32

    public init() {
        machineId = AnalyticsUint64()
        sessionId = 0
        platform = Platform()
        buildId = 0
        projectId = AnalyticsUint64()
        sessionLength = 0
        featureUsage = 0
    }

    /// 编码为字节数组
    /// 对应 Bun EventListHeader.encode()
    public func encode(): Array<Byte> {
        let buf = ArrayList<Byte>()
        // machine_id (8 bytes)
        for (b in machineId.encode()) { buf.append(b) }
        // session_id (4 bytes)
        appendInt32LE(buf, Int32(sessionId))
        // platform (variable)
        for (b in platform.encode()) { buf.append(b) }
        // build_id (4 bytes)
        appendInt32LE(buf, Int32(buildId))
        // project_id (8 bytes)
        for (b in projectId.encode()) { buf.append(b) }
        // session_length (4 bytes)
        appendInt32LE(buf, Int32(sessionLength))
        // feature_usage (4 bytes)
        appendInt32LE(buf, Int32(featureUsage))
        buf.toArray()
    }

    /// 从字节数组解码
    /// 对应 Bun EventListHeader.decode()
    public static func decode(data: Array<Byte>): ?EventListHeader {
        let header = EventListHeader()
        var offset = 0

        // machine_id
        if (data.size < offset + 8) { return None }
        let machineId = AnalyticsUint64.decode(data[offset..(offset + 8)])
        if (machineId.isNone()) { return None }
        header.machineId = machineId.getOrThrow()
        offset += 8

        // session_id
        if (data.size < offset + 4) { return None }
        header.sessionId = UInt32(readInt32LE(data, offset))
        offset += 4

        // platform
        let plat = Platform.decode(data[offset..])
        if (plat.isNone()) { return None }
        header.platform = plat.getOrThrow()
        // 跳过: os(1) + arch(1) + version_len(4) + version
        offset += 2
        if (data.size < offset + 4) { return None }
        let versionLen = Int32(readInt32LE(data, offset))
        offset += 4 + versionLen

        // build_id
        if (data.size < offset + 4) { return None }
        header.buildId = UInt32(readInt32LE(data, offset))
        offset += 4

        // project_id
        if (data.size < offset + 8) { return None }
        let projectId = AnalyticsUint64.decode(data[offset..(offset + 8)])
        if (projectId.isNone()) { return None }
        header.projectId = projectId.getOrThrow()
        offset += 8

        // session_length
        if (data.size < offset + 4) { return None }
        header.sessionLength = UInt32(readInt32LE(data, offset))
        offset += 4

        // feature_usage
        if (data.size < offset + 4) { return None }
        header.featureUsage = UInt32(readInt32LE(data, offset))

        header
    }
}

// ============================================================================
// EventHeader - 事件头
// 严格翻译自: schema.zig - analytics.EventHeader
//   pub const EventHeader = struct {
//       timestamp: Uint64, kind: EventKind,
//   };
// ============================================================================

/// 事件头 - 对应 Bun analytics.EventHeader
public class EventHeader {
    /// 时间戳
    public var timestamp: AnalyticsUint64
    /// 事件类型
    public var kind: EventKind

    public init() {
        timestamp = AnalyticsUint64()
        kind = EventKind.None
    }

    public init(timestamp: AnalyticsUint64, kind: EventKind) {
        this.timestamp = timestamp
        this.kind = kind
    }

    /// 编码为字节数组
    public func encode(): Array<Byte> {
        let buf = ArrayList<Byte>()
        for (b in timestamp.encode()) { buf.append(b) }
        appendInt32LE(buf, Int32(kind.value))
        appendInt32LE(buf, 0) // u32 高位补齐
        buf.toArray()
    }

    /// 从字节数组解码
    public static func decode(data: Array<Byte>): ?EventHeader {
        if (data.size < 12) { return None }
        let ts = AnalyticsUint64.decode(data[0..8])
        if (ts.isNone()) { return None }
        let kind = EventKind(UInt32(readInt32LE(data, 8)))
        EventHeader(ts.getOrThrow(), kind)
    }
}

// ============================================================================
// EventList - 事件列表
// 严格翻译自: schema.zig - analytics.EventList
//   pub const EventList = struct {
//       header: EventListHeader, event_count: u32,
//   };
// ============================================================================

/// 事件列表 - 对应 Bun analytics.EventList
public class EventList {
    /// 列表头
    public var header: EventListHeader
    /// 事件数量
    public var eventCount: UInt32

    public init() {
        header = EventListHeader()
        eventCount = 0
    }

    public init(header: EventListHeader, eventCount: UInt32) {
        this.header = header
        this.eventCount = eventCount
    }

    /// 编码为字节数组
    public func encode(): Array<Byte> {
        let buf = ArrayList<Byte>()
        for (b in header.encode()) { buf.append(b) }
        appendInt32LE(buf, Int32(eventCount))
        buf.toArray()
    }
}

// ============================================================================
// Features - 功能特性使用计数
// 严格翻译自: analytics.zig - Features
//   pub const Features = struct {
//       pub var builtin_modules, Bun.stderr, Bun.stdin, Bun.stdout, WebSocket, ...
//       pub fn formatter() Formatter
//       pub const Formatter = struct { pub fn format(...) !void }
//   };
// ============================================================================

/// 功能特性使用计数 - 对应 Bun analytics.Features
/// 跟踪用户使用的 Bun 功能
public class Features {
    // 标准 I/O
    /// Bun.stderr 使用次数
    public var bunStderr: Int64 = 0
    /// Bun.stdin 使用次数
    public var bunStdin: Int64 = 0
    /// Bun.stdout 使用次数
    public var bunStdout: Int64 = 0
    // 网络
    /// WebSocket 使用次数
    public var webSocket: Int64 = 0
    /// fetch 使用次数
    public var fetch: Int64 = 0
    /// TCP 服务器使用次数
    public var tcpServer: Int64 = 0
    /// TLS 服务器使用次数
    public var tlsServer: Int64 = 0
    /// HTTP 服务器使用次数
    public var httpServer: Int64 = 0
    /// HTTPS 服务器使用次数
    public var httpsServer: Int64 = 0
    /// HTTP 客户端代理使用次数
    public var httpClientProxy: Int64 = 0
    // 构建工具
    /// bunfig 配置使用次数
    public var bunfig: Int64 = 0
    /// define 使用次数
    public var define: Int64 = 0
    /// dotenv 使用次数
    public var dotenv: Int64 = 0
    /// 外部模块使用次数
    public var external: Int64 = 0
    /// loader 使用次数
    public var loaders: Int64 = 0
    /// 转译缓存使用次数
    public var transpilerCache: Int64 = 0
    /// 宏使用次数
    public var macros: Int64 = 0
    /// TypeScript 配置使用次数
    public var tsconfig: Int64 = 0
    /// tsconfig paths 使用次数
    public var tsconfigPaths: Int64 = 0
    /// 虚拟模块使用次数
    public var virtualModules: Int64 = 0
    // 进程
    /// spawn 使用次数
    public var spawn: Int64 = 0
    /// shell 使用次数
    public var shell: Int64 = 0
    /// abort_signal 使用次数
    public var abortSignal: Int64 = 0
    /// 调试器使用次数
    public var debugger: Int64 = 0
    // 安装
    /// binlinks 使用次数
    public var binlinks: Int64 = 0
    /// git 依赖使用次数
    public var gitDependencies: Int64 = 0
    /// 生命周期脚本使用次数
    public var lifecycleScripts: Int64 = 0
    /// 提取的包数
    public var extractedPackages: Int64 = 0
    /// lockfile 从 package-lock 迁移次数
    public var lockfileMigrationFromPackageLock: Int64 = 0
    /// 文本 lockfile 使用次数
    public var textLockfile: Int64 = 0
    /// 隔离安装使用次数
    public var isolatedBunInstall: Int64 = 0
    /// 提升 install 使用次数
    public var hoistedBunInstall: Int64 = 0
    /// 独立可执行文件使用次数
    public var standaloneExecutable: Int64 = 0
    /// 独立 shell 使用次数
    public var standaloneShell: Int64 = 0
    /// yarn 迁移使用次数
    public var yarnMigration: Int64 = 0
    /// pnpm 迁移使用次数
    public var pnpmMigration: Int64 = 0
    // 运行时
    /// JSC 初始化次数
    public var jsc: Int64 = 0
    /// 开发服务器初始化次数
    public var devServer: Int64 = 0
    /// Worker 启动数
    public var workersSpawned: Int64 = 0
    /// Worker 终止数
    public var workersTerminated: Int64 = 0
    /// NAPI 模块注册数
    public var napiModuleRegister: Int64 = 0
    /// process.dlopen 调用数
    public var processDlopen: Int64 = 0
    // 数据库
    /// PostgreSQL 连接数
    public var postgresConnections: Int64 = 0
    /// S3 操作数
    public var s3: Int64 = 0
    /// Valkey 操作数
    public var valkey: Int64 = 0
    // HTML
    /// HTML 重写器使用次数
    public var htmlRewriter: Int64 = 0
    // 安全
    /// CSRF 验证次数
    public var csrfVerify: Int64 = 0
    /// CSRF 生成次数
    public var csrfGenerate: Int64 = 0
    // 系统特性
    /// NO_AVX2 标志
    public var noAvx2: Int64 = 0
    /// NO_AVX 标志
    public var noAvx: Int64 = 0
    /// 不支持的 UV 函数数
    public var unsupportedUvFunction: Int64 = 0
    /// todo panic 数
    public var todoPanic: Int64 = 0
    /// 进程退出数
    public var exited: Int64 = 0
    // 性能分析
    /// CPU 性能分析使用次数
    public var cpuProfile: Int64 = 0
    /// 堆快照使用次数
    public var heapSnapshot: Int64 = 0
    // YAML
    /// YAML 解析使用次数
    public var yamlParse: Int64 = 0
    // WebView
    /// Chrome WebView 使用次数
    public var webviewChrome: Int64 = 0
    /// WebKit WebView 使用次数
    public var webviewWebkit: Int64 = 0

    public init() {}

    /// 格式化特性摘要
    /// 对应 Bun Features.Formatter.format()
    public func format(): String {
        let sb = StringBuilder()
        var isFirst = true

        let fields = listFields()
        for (entry in fields) {
            if (entry.count > 0) {
                if (isFirst) {
                    sb.append("Features: ")
                    isFirst = false
                }
                sb.append(entry.name)
                if (entry.count > 1) {
                    sb.append("(${entry.count}) ")
                } else {
                    sb.append(" ")
                }
            }
        }
        if (!isFirst) {
            sb.append("\n")
        }
        sb.toString()
    }

    /// 列出所有非零特性
    func listFields(): ArrayList<FeatureEntry> {
        let entries = ArrayList<FeatureEntry>()
        maybeAdd(entries, "Bun.stderr", bunStderr)
        maybeAdd(entries, "Bun.stdin", bunStdin)
        maybeAdd(entries, "Bun.stdout", bunStdout)
        maybeAdd(entries, "WebSocket", webSocket)
        maybeAdd(entries, "abort_signal", abortSignal)
        maybeAdd(entries, "binlinks", binlinks)
        maybeAdd(entries, "bunfig", bunfig)
        maybeAdd(entries, "define", define)
        maybeAdd(entries, "dotenv", dotenv)
        maybeAdd(entries, "debugger", debugger)
        maybeAdd(entries, "external", external)
        maybeAdd(entries, "extracted_packages", extractedPackages)
        maybeAdd(entries, "fetch", fetch)
        maybeAdd(entries, "git_dependencies", gitDependencies)
        maybeAdd(entries, "html_rewriter", htmlRewriter)
        maybeAdd(entries, "tcp_server", tcpServer)
        maybeAdd(entries, "tls_server", tlsServer)
        maybeAdd(entries, "http_server", httpServer)
        maybeAdd(entries, "https_server", httpsServer)
        maybeAdd(entries, "http_client_proxy", httpClientProxy)
        maybeAdd(entries, "jsc", jsc)
        maybeAdd(entries, "dev_server", devServer)
        maybeAdd(entries, "lifecycle_scripts", lifecycleScripts)
        maybeAdd(entries, "loaders", loaders)
        maybeAdd(entries, "lockfile_migration_from_package_lock", lockfileMigrationFromPackageLock)
        maybeAdd(entries, "text_lockfile", textLockfile)
        maybeAdd(entries, "isolated_bun_install", isolatedBunInstall)
        maybeAdd(entries, "hoisted_bun_install", hoistedBunInstall)
        maybeAdd(entries, "macros", macros)
        maybeAdd(entries, "no_avx2", noAvx2)
        maybeAdd(entries, "no_avx", noAvx)
        maybeAdd(entries, "shell", shell)
        maybeAdd(entries, "spawn", spawn)
        maybeAdd(entries, "standalone_executable", standaloneExecutable)
        maybeAdd(entries, "standalone_shell", standaloneShell)
        maybeAdd(entries, "todo_panic", todoPanic)
        maybeAdd(entries, "transpiler_cache", transpilerCache)
        maybeAdd(entries, "tsconfig", tsconfig)
        maybeAdd(entries, "tsconfig_paths", tsconfigPaths)
        maybeAdd(entries, "virtual_modules", virtualModules)
        maybeAdd(entries, "workers_spawned", workersSpawned)
        maybeAdd(entries, "workers_terminated", workersTerminated)
        maybeAdd(entries, "napi_module_register", napiModuleRegister)
        maybeAdd(entries, "process_dlopen", processDlopen)
        maybeAdd(entries, "postgres_connections", postgresConnections)
        maybeAdd(entries, "s3", s3)
        maybeAdd(entries, "valkey", valkey)
        maybeAdd(entries, "csrf_verify", csrfVerify)
        maybeAdd(entries, "csrf_generate", csrfGenerate)
        maybeAdd(entries, "unsupported_uv_function", unsupportedUvFunction)
        maybeAdd(entries, "exited", exited)
        maybeAdd(entries, "yarn_migration", yarnMigration)
        maybeAdd(entries, "pnpm_migration", pnpmMigration)
        maybeAdd(entries, "yaml_parse", yamlParse)
        maybeAdd(entries, "cpu_profile", cpuProfile)
        maybeAdd(entries, "heap_snapshot", heapSnapshot)
        maybeAdd(entries, "webview_chrome", webviewChrome)
        maybeAdd(entries, "webview_webkit", webviewWebkit)
        entries
    }

    static func maybeAdd(entries: ArrayList<FeatureEntry>, name: String, count: Int64): Unit {
        if (count > 0) {
            entries.append(FeatureEntry(name, count))
        }
    }
}

// ============================================================================
// FeatureEntry - 特性条目 (辅助)
// ============================================================================

/// 特性条目 - 用于格式化输出
class FeatureEntry {
    var name: String
    var count: Int64

    init(name: String, count: Int64) {
        this.name = name
        this.count = count
    }
}

// ============================================================================
// PackedFeatures - 位压缩特性标志
// 严格翻译自: analytics.zig - PackedFeatures
//   pub const PackedFeatures = @Type(.{ .@"struct" = .{
//       .layout = .@"packed", .backing_integer = u64, ...
//   }});
//   pub fn packedFeatures() PackedFeatures
// ============================================================================

/// 位压缩特性标志 - 对应 Bun analytics.PackedFeatures
/// 使用 UInt64 位图表示哪些特性被使用
public class PackedFeatures {
    public var bits: UInt64 = 0

    public init() {}

    /// 设置特性位
    public func setBit(index: Int64): Unit {
        if (index >= 0 && index < 64) {
            bits = bits | (UInt64(1) << index)
        }
    }

    /// 检查特性位
    public func hasBit(index: Int64): Bool {
        if (index < 0 || index >= 64) { return false }
        (bits & (UInt64(1) << index)) != 0
    }

    /// 从 Features 生成位图
    /// 对应 Bun packedFeatures()
    public static func fromFeatures(features: Features): PackedFeatures {
        let packed = PackedFeatures()
        var idx = 0
        if (features.bunStderr > 0) { packed.setBit(idx) }; idx += 1
        if (features.bunStdin > 0) { packed.setBit(idx) }; idx += 1
        if (features.bunStdout > 0) { packed.setBit(idx) }; idx += 1
        if (features.webSocket > 0) { packed.setBit(idx) }; idx += 1
        if (features.fetch > 0) { packed.setBit(idx) }; idx += 1
        if (features.spawn > 0) { packed.setBit(idx) }; idx += 1
        if (features.shell > 0) { packed.setBit(idx) }; idx += 1
        if (features.jsc > 0) { packed.setBit(idx) }; idx += 1
        packed
    }
}

// ============================================================================
// AnalyticsState - 分析状态
// 严格翻译自: analytics.zig - enabled, is_ci, isEnabled()
//   pub var enabled: enum { yes, no, unknown } = .unknown;
//   pub fn isEnabled() bool { ... }
// ============================================================================

/// 分析状态 - 对应 Bun analytics 模块级状态
public class AnalyticsState {
    /// 是否启用遥测
    public static var enabled: TriState = TriState.Unknown
    /// 是否 CI 环境
    public static var isCI: TriState = TriState.Unknown

    /// 检测是否启用遥测
    /// 对应 Bun isEnabled()
    /// 检查 DO_NOT_TRACK 环境变量, 默认启用
    public static func isEnabled(): Bool {
        match (enabled) {
            | Yes => true
            | No => false
            | Unknown => {
                // 检查 DO_NOT_TRACK 环境变量
                let doNotTrack = System.env("DO_NOT_TRACK")
                if (doNotTrack.isSome()) {
                    enabled = TriState.No
                    return false
                }
                // 默认启用
                enabled = TriState.Yes
                true
            }
        }
    }

    /// 检测是否 CI 环境
    public static func isCIEnvironment(): Bool {
        match (isCI) {
            | Yes => true
            | No => false
            | Unknown => {
                // 检查常见 CI 环境变量
                let ci = System.env("CI")
                if (ci.isSome()) {
                    isCI = TriState.Yes
                    return true
                }
                let tfBuild = System.env("TF_BUILD")
                if (tfBuild.isSome()) {
                    isCI = TriState.Yes
                    return true
                }
                isCI = TriState.No
                false
            }
        }
    }
}

// ============================================================================
// GeneratePlatform - 平台检测
// 严格翻译自: analytics.zig - GenerateHeader.GeneratePlatform
//   pub const GeneratePlatform = struct {
//       fn forMac() Platform
//       fn forLinux() Platform
//       fn forFreeBSD() Platform
//       pub fn forOS() Platform
//   };
// ============================================================================

/// 平台检测工具 - 对应 Bun analytics.GenerateHeader.GeneratePlatform
public class GeneratePlatform {
    /// 缓存的平台信息
    static var cachedPlatform: ?Platform = None

    /// 检测当前平台
    /// 对应 Bun GeneratePlatform.forOS()
    public static func forOS(): Platform {
        if (cachedPlatform.isSome()) {
            return cachedPlatform.getOrThrow()
        }

        let osName = System.osName()
        let archName = System.archName()

        let os = match (osName) {
            case "linux" => OperatingSystem.Linux
            case "darwin" | "macos" => OperatingSystem.MacOS
            case "windows" => OperatingSystem.Windows
            case "freebsd" => OperatingSystem.FreeBSD
            case "android" => OperatingSystem.Android
            | _ => OperatingSystem.Other
        }

        let arch = match (archName) {
            case "x86_64" | "x64" | "amd64" => Architecture.X64
            case "aarch64" | "arm64" => Architecture.ARM
            | _ => Architecture.Other
        }

        let version = System.osVersion()
        let platform = Platform(os, arch, version)
        cachedPlatform = platform
        platform
    }
}

// ============================================================================
// AnalyticsReader - 遥测数据读取器
// 严格翻译自: schema.zig - Reader
//   pub const Reader = struct {
//       buf, remain, allocator,
//       pub fn read, readAs, readByte, readEnum, readArray, readByteArray,
//              readInt, readBool, readValue
//   };
// ============================================================================

/// 遥测数据读取器 - 对应 Bun schema.Reader
/// 从二进制缓冲区解码遥测数据
public class AnalyticsReader {
    private var buffer: Array<Byte>
    private var pos: Int64

    public init(buffer: Array<Byte>) {
        this.buffer = buffer
        pos = 0
    }

    /// 剩余字节数
    public func remaining(): Int64 {
        buffer.size - pos
    }

    /// 读取指定数量字节
    /// 对应 Bun Reader.read()
    public func read(count: Int64): ?Array<Byte> {
        if (pos + count > buffer.size) { return None }
        let result = buffer[pos..(pos + count)]
        pos += count
        result
    }

    /// 读取一个字节
    /// 对应 Bun Reader.readByte()
    public func readByte(): ?Byte {
        if (pos >= buffer.size) { return None }
        let b = buffer[pos]
        pos += 1
        b
    }

    /// 读取 Int32 (小端)
    /// 对应 Bun Reader.readInt()
    public func readInt32(): ?Int32 {
        if (pos + 4 > buffer.size) { return None }
        let v = readInt32LE(buffer, pos)
        pos += 4
        v
    }

    /// 读取 UInt32 (小端)
    public func readUInt32(): ?UInt32 {
        let v = readInt32()
        if (v.isNone()) { return None }
        UInt32(v.getOrThrow())
    }

    /// 读取布尔值
    /// 对应 Bun Reader.readBool()
    public func readBool(): ?Bool {
        let b = readByte()
        if (b.isNone()) { return None }
        b.getOrThrow().value > 0
    }

    /// 读取字节数组 (长度前缀)
    /// 对应 Bun Reader.readByteArray()
    public func readByteArray(): ?Array<Byte> {
        let length = readUInt32()
        if (length.isNone()) { return None }
        let len = Int64(length.getOrThrow())
        if (len == 0) { return Array<Byte>() }
        read(len)
    }

    /// 读取字符串 (长度前缀)
    public func readString(): ?String {
        let bytes = readByteArray()
        if (bytes.isNone()) { return None }
        String.fromUtf8(bytes.getOrThrow())
    }

    /// 读取枚举值
    /// 对应 Bun Reader.readEnum()
    public func readEventKind(): ?EventKind {
        let v = readUInt32()
        if (v.isNone()) { return None }
        EventKind(v.getOrThrow())
    }

    /// 读取操作系统枚举
    public func readOperatingSystem(): ?OperatingSystem {
        let b = readByte()
        if (b.isNone()) { return None }
        OperatingSystem(b.getOrThrow())
    }

    /// 读取架构枚举
    public func readArchitecture(): ?Architecture {
        let b = readByte()
        if (b.isNone()) { return None }
        Architecture(b.getOrThrow())
    }
}

// ============================================================================
// AnalyticsWriter - 遥测数据写入器
// 严格翻译自: schema.zig - Writer
//   pub fn Writer(comptime WritableStream: type) type {
//       return struct {
//           writable, pub fn write, writeByte, writeInt, writeFieldID,
//                  writeEnum, writeValue, writeArray, endMessage
//       };
//   };
// ============================================================================

/// 遥测数据写入器 - 对应 Bun schema.Writer
/// 将遥测数据编码为二进制格式
public class AnalyticsWriter {
    private var buffer: ArrayList<Byte>

    public init() {
        buffer = ArrayList<Byte>()
    }

    /// 获取写入的字节数
    public func size(): Int64 {
        buffer.size
    }

    /// 获取写入结果
    public func toBytes(): Array<Byte> {
        buffer.toArray()
    }

    /// 写入原始字节
    /// 对应 Bun Writer.write()
    public func write(bytes: Array<Byte>): Unit {
        for (b in bytes) { buffer.append(b) }
    }

    /// 写入单个字节
    /// 对应 Bun Writer.writeByte()
    public func writeByte(b: Byte): Unit {
        buffer.append(b)
    }

    /// 写入 Int32 (小端)
    /// 对应 Bun Writer.writeInt()
    public func writeInt32(v: Int32): Unit {
        appendInt32LE(buffer, v)
    }

    /// 写入 UInt32 (小端)
    public func writeUInt32(v: UInt32): Unit {
        appendInt32LE(buffer, Int32(v))
    }

    /// 写入字段 ID
    /// 对应 Bun Writer.writeFieldID()
    public func writeFieldID(id: UInt8): Unit {
        buffer.append(id)
    }

    /// 写入枚举值
    /// 对应 Bun Writer.writeEnum()
    public func writeEventKind(kind: EventKind): Unit {
        writeUInt32(kind.value)
    }

    /// 写入操作系统枚举
    public func writeOperatingSystem(os: OperatingSystem): Unit {
        buffer.append(os.value)
    }

    /// 写入架构枚举
    public func writeArchitecture(arch: Architecture): Unit {
        buffer.append(arch.value)
    }

    /// 写入字节数组 (长度前缀)
    /// 对应 Bun Writer.writeArray(u8, slice)
    public func writeByteArray(bytes: Array<Byte>): Unit {
        writeUInt32(UInt32(bytes.size))
        for (b in bytes) { buffer.append(b) }
    }

    /// 写入字符串 (长度前缀)
    public func writeString(s: String): Unit {
        writeByteArray(s.toArray())
    }

    /// 结束消息
    /// 对应 Bun Writer.endMessage()
    public func endMessage(): Unit {
        buffer.append(0)
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 将 Int32 以小端字节序追加到 ArrayList
static func appendInt32LE(buf: ArrayList<Byte>, v: Int32): Unit {
    var val = v
    for (_ in 0..4) {
        buf.append(Byte(val % 256))
        val /= 256
    }
}

/// 从字节数组读取 Int32 (小端)
static func readInt32LE(arr: Array<Byte>, offset: Int64): Int32 {
    var result = 0
    for (i in 0..4) {
        result = result + Int32(arr[offset + i].value) * (1 << (i * 8))
    }
    result
}
