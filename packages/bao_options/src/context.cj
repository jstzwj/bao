// Context - 命令上下文
// 严格翻译自: bun/src/options_types/Context.zig
//   pub const ContextData = struct { ... };
//   pub const Context = *ContextData;
//   pub const DebugOptions = struct { ... };
//   pub const TestOptions = struct { ... };
//   pub const RuntimeOptions = struct { ... };
package bao_options

import bao_core.*

// ============================================================================
// HotReload - 热重载模式
// 严格翻译自: Context.zig - HotReload
//   pub const HotReload = enum { none, hot, watch };
// ============================================================================

/// 热重载模式 - 对应 Bun HotReload
public enum HotReload {
    | None   // 无热重载
    | Hot    // HMR 热更新
    | Watch  // 文件监视
}

// ============================================================================
// MacroOptions - 宏选项
// 严格翻译自: Context.zig - MacroOptions
//   pub const MacroOptions = union(enum) {
//       unspecified: void, disable: void, map: MacroMap
//   };
// ============================================================================

/// 宏选项 - 对应 Bun MacroOptions
public enum MacroOptions {
    | Unspecified
    | Disable
    | Enable
}

// ============================================================================
// BundlerOptions - 打包器选项
// 严格翻译自: Context.zig - BundlerOptions
//   pub const BundlerOptions = struct {
//       outdir: []const u8 = "",
//       outfile: []const u8 = "",
//       ...
//   };
// ============================================================================

/// 打包器选项 - 对应 Bun BundlerOptions
public class BundlerOptions {
    /// 输出目录
    public var outdir: String
    /// 输出文件名
    public var outfile: String
    /// metafile 路径
    public var metafile: String
    /// metafile markdown 路径
    public var metafileMd: String
    /// 根目录
    public var rootDir: String
    /// 公共路径
    public var publicPath: String
    /// 入口命名模板
    public var entryNaming: String
    /// 代码块命名模板
    public var chunkNaming: String
    /// 资源命名模板
    public var assetNaming: String
    /// 是否启用服务器组件
    public var serverComponents: Bool
    /// 是否启用 React 快速刷新
    public var reactFastRefresh: Bool
    /// 是否启用代码分割
    public var codeSplitting: Bool
    /// 是否仅转换
    public var transformOnly: Bool
    /// 是否内联入口点 import.meta.main
    public var inlineEntrypointImportMetaMain: Bool
    /// 是否压缩语法
    public var minifySyntax: Bool
    /// 是否压缩空白
    public var minifyWhitespace: Bool
    /// 是否压缩标识符
    public var minifyIdentifiers: Bool
    /// 是否保留名称
    public var keepNames: Bool
    /// 是否忽略 DCE 注解
    public var ignoreDceAnnotations: Bool
    /// 是否发出 DCE 注解
    public var emitDceAnnotations: Bool
    /// 输出格式
    public var outputFormat: BundleFormat
    /// 是否生成字节码
    public var bytecode: Bool
    /// 横幅文本
    public var banner: String
    /// 页脚文本
    public var footer: String
    /// 是否启用 CSS 代码分割
    public var cssChunking: Bool
    /// 是否启用 Bake
    public var bake: Bool
    /// Bake 调试选项
    public var bakeDebugDumpServer: Bool
    public var bakeDebugDisableMinify: Bool
    /// 是否为生产模式
    public var production: Bool
    /// 环境变量行为
    public var envBehavior: String
    /// 环境变量前缀
    public var envPrefix: String
    /// 省略行数
    public var elideLines: ?Int64
    /// 编译选项
    public var compile: Bool
    /// 编译目标
    public var compileTarget: CompileTarget
    /// 编译执行参数
    public var compileExecArgv: ?String
    /// 编译自动加载 .env
    public var compileAutoloadDotenv: Bool
    /// 编译自动加载 bunfig
    public var compileAutoloadBunfig: Bool
    /// 编译自动加载 tsconfig
    public var compileAutoloadTsconfig: Bool
    /// 编译自动加载 package.json
    public var compileAutoloadPackageJson: Bool
    /// 编译可执行文件路径
    public var compileExecutablePath: ?String
    /// Windows 选项
    public var windows: WindowsOptions
    /// 允许未解析的导入
    public var allowUnresolved: ArrayList<String>

    public init() {
        outdir = ""
        outfile = ""
        metafile = ""
        metafileMd = ""
        rootDir = ""
        publicPath = ""
        entryNaming = "[dir]/[name].[ext]"
        chunkNaming = "./[name]-[hash].[ext]"
        assetNaming = "./[name]-[hash].[ext]"
        serverComponents = false
        reactFastRefresh = false
        codeSplitting = false
        transformOnly = false
        inlineEntrypointImportMetaMain = false
        minifySyntax = false
        minifyWhitespace = false
        minifyIdentifiers = false
        keepNames = false
        ignoreDceAnnotations = false
        emitDceAnnotations = true
        outputFormat = BundleFormat.Esm
        bytecode = false
        banner = ""
        footer = ""
        cssChunking = false
        bake = false
        bakeDebugDumpServer = false
        bakeDebugDisableMinify = false
        production = false
        envBehavior = "disable"
        envPrefix = ""
        elideLines = None
        compile = false
        compileTarget = CompileTarget()
        compileExecArgv = None
        compileAutoloadDotenv = true
        compileAutoloadBunfig = true
        compileAutoloadTsconfig = false
        compileAutoloadPackageJson = false
        compileExecutablePath = None
        windows = WindowsOptions()
        allowUnresolved = ArrayList<String>()
    }
}

// ============================================================================
// DebugOptions - 调试选项
// 严格翻译自: Context.zig - DebugOptions
//   pub const DebugOptions = struct { ... };
// ============================================================================

/// 调试选项 - 对应 Bun DebugOptions
public class DebugOptions {
    /// 是否导出环境变量
    public var dumpEnvironmentVariables: Bool
    /// 是否导出限制
    public var dumpLimits: Bool
    /// 是否仅使用回退
    public var fallbackOnly: Bool
    /// 是否静默
    public var silent: Bool
    /// 热重载模式
    public var hotReload: HotReload
    /// 全局缓存策略
    public var globalCache: GlobalCache
    /// 离线模式
    public var offlineModeSetting: ?OfflineMode
    /// 是否在 Bun 中运行
    public var runInBun: Bool
    /// 是否已加载 bunfig
    public var loadedBunfig: Bool
    /// 是否使用系统 shell
    public var useSystemShell: Bool
    /// 宏选项
    public var macros: MacroOptions
    /// 编辑器
    public var editor: String
    /// 测试目录
    public var testDirectory: String
    /// 输出文件
    public var outputFile: String

    public init() {
        dumpEnvironmentVariables = false
        dumpLimits = false
        fallbackOnly = false
        silent = false
        hotReload = HotReload.None
        globalCache = GlobalCache.Auto
        offlineModeSetting = None
        runInBun = false
        loadedBunfig = false
        useSystemShell = true
        macros = MacroOptions.Unspecified
        editor = ""
        testDirectory = ""
        outputFile = ""
    }
}

// ============================================================================
// TestOptions - 测试选项
// 严格翻译自: Context.zig - TestOptions
//   pub const TestOptions = struct {
//       default_timeout_ms: u32 = 5000,
//       update_snapshots: bool = false,
//       ...
//   };
// ============================================================================

/// 测试选项 - 对应 Bun TestOptions
public class TestOptions {
    /// 默认超时 (毫秒)
    public var defaultTimeoutMs: Int64
    /// 是否更新快照
    public var updateSnapshots: Bool
    /// 重复次数
    public var repeatCount: Int64
    /// 重试次数
    public var retry: Int64
    /// 是否运行 todo 测试
    public var runTodo: Bool
    /// 是否只运行标记的测试
    public var only: Bool
    /// 没有测试时是否通过
    public var passWithNoTests: Bool
    /// 是否并发执行
    public var concurrent: Bool
    /// 是否随机化顺序
    public var randomize: Bool
    /// 随机种子
    public var seed: ?Int64
    /// 并发测试 glob 模式
    public var concurrentTestGlob: ?ArrayList<String>
    /// bail 计数
    public var bail: Int64
    /// 覆盖率选项
    public var coverage: CodeCoverageOptions
    /// 路径忽略模式
    public var pathIgnorePatterns: ArrayList<String>
    /// 是否来自 CLI
    public var pathIgnorePatternsFromCli: Bool
    /// 测试过滤模式
    public var testFilterPattern: ?String
    /// 最大并发数
    public var maxConcurrency: Int64
    /// 是否隔离
    public var isolate: Bool
    /// 并行工作进程数
    public var parallel: Int64
    /// 并行延迟毫秒
    public var parallelDelayMs: ?Int64
    /// 是否为测试工作进程
    public var testWorker: Bool
    /// changed 选项
    public var changed: ?String
    /// shard (index, count)
    public var shardIndex: ?Int64
    public var shardCount: ?Int64
    /// 报告器选项
    public var reporterDots: Bool
    public var reporterOnlyFailures: Bool
    public var reporterJunit: Bool
    public var reporterOutfile: ?String

    public init() {
        defaultTimeoutMs = 5000
        updateSnapshots = false
        repeatCount = 0
        retry = 0
        runTodo = false
        only = false
        passWithNoTests = false
        concurrent = false
        randomize = false
        seed = None
        concurrentTestGlob = None
        bail = 0
        coverage = CodeCoverageOptions()
        pathIgnorePatterns = ArrayList<String>()
        pathIgnorePatternsFromCli = false
        testFilterPattern = None
        maxConcurrency = 20
        isolate = false
        parallel = 0
        parallelDelayMs = None
        testWorker = false
        changed = None
        shardIndex = None
        shardCount = None
        reporterDots = false
        reporterOnlyFailures = false
        reporterJunit = false
        reporterOutfile = None
    }
}

// ============================================================================
// Debugger - 调试器选项
// 严格翻译自: Context.zig - Debugger
//   pub const Debugger = union(enum) {
//       unspecified: void,
//       enable: struct { path_or_port, wait_for_connection, ... },
//   };
// ============================================================================

/// 调试器选项 - 对应 Bun Debugger
public class DebuggerOptions {
    /// 是否启用
    public var enabled: Bool
    /// 路径或端口
    public var pathOrPort: String
    /// 是否等待连接
    public var waitForConnection: Bool
    /// 是否在第一行设置断点
    public var setBreakpointOnFirstLine: Bool

    public init() {
        enabled = false
        pathOrPort = ""
        waitForConnection = false
        setBreakpointOnFirstLine = false
    }
}

// ============================================================================
// RuntimeOptions - 运行时选项
// 严格翻译自: Context.zig - RuntimeOptions
//   pub const RuntimeOptions = struct { ... };
// ============================================================================

/// 运行时选项 - 对应 Bun RuntimeOptions
public class RuntimeOptions {
    /// 是否使用 smol 堆
    public var smol: Bool
    /// 调试器选项
    public var debugger: DebuggerOptions
    /// 是否 if-present
    public var ifPresent: Bool
    /// 是否预连接 Redis
    public var redisPreconnect: Bool
    /// 是否预连接 SQL
    public var sqlPreconnect: Bool
    /// eval 相关
    public var evalScript: String
    public var evalAndPrint: Bool
    /// 预连接列表
    public var preconnect: ArrayList<String>
    /// 实验性 HTTP/2 fetch
    public var experimentalHttp2Fetch: Bool
    /// 实验性 HTTP/3 fetch
    public var experimentalHttp3Fetch: Bool
    /// DNS 结果顺序
    public var dnsResultOrder: String
    /// 是否暴露 GC
    public var exposeGc: Bool
    /// 是否保留符号链接 main
    public var preserveSymlinksMain: Bool
    /// 控制台深度
    public var consoleDepth: ?Int64
    /// Cron 标题
    public var cronTitle: String
    /// Cron 周期
    public var cronPeriod: String
    /// CPU 性能分析
    public var cpuProfEnabled: Bool
    public var cpuProfName: String
    public var cpuProfDir: String
    public var cpuProfInterval: Int64
    public var cpuProfMdFormat: Bool
    public var cpuProfJsonFormat: Bool
    /// 堆性能分析
    public var heapProfEnabled: Bool
    public var heapProfTextFormat: Bool
    public var heapProfName: String
    public var heapProfDir: String

    public init() {
        smol = false
        debugger = DebuggerOptions()
        ifPresent = false
        redisPreconnect = false
        sqlPreconnect = false
        evalScript = ""
        evalAndPrint = false
        preconnect = ArrayList<String>()
        experimentalHttp2Fetch = false
        experimentalHttp3Fetch = false
        dnsResultOrder = "verbatim"
        exposeGc = false
        preserveSymlinksMain = false
        consoleDepth = None
        cronTitle = ""
        cronPeriod = ""
        cpuProfEnabled = false
        cpuProfName = ""
        cpuProfDir = ""
        cpuProfInterval = 1000
        cpuProfMdFormat = false
        cpuProfJsonFormat = false
        heapProfEnabled = false
        heapProfTextFormat = false
        heapProfName = ""
        heapProfDir = ""
    }
}

// ============================================================================
// ContextData - 命令上下文数据
// 严格翻译自: Context.zig - ContextData
//   pub const ContextData = struct {
//       start_time: i128,
//       args: api.TransformOptions,
//       log: *logger.Log,
//       allocator: std.mem.Allocator,
//       ...
//   };
// ============================================================================

/// 命令上下文数据 - 对应 Bun ContextData
public class ContextData {
    /// 开始时间 (纳秒)
    public var startTime: Int64
    /// 位置参数
    public var positionals: ArrayList<String>
    /// 透传参数
    public var passthrough: ArrayList<String>
    /// 调试选项
    public var debug: DebugOptions
    /// 测试选项
    public var testOptions: TestOptions
    /// 打包器选项
    public var bundlerOptions: BundlerOptions
    /// 运行时选项
    public var runtimeOptions: RuntimeOptions
    /// 过滤器
    public var filters: ArrayList<String>
    /// 是否使用 workspaces
    public var workspaces: Bool
    /// 是否 if-present
    public var ifPresent: Bool
    /// 是否并行
    public var parallel: Bool
    /// 是否顺序执行
    public var sequential: Bool
    /// 是否 no-exit-on-error
    public var noExitOnError: Bool
    /// 预加载模块
    public var preloads: ArrayList<String>
    /// 是否已加载全局配置
    public var hasLoadedGlobalConfig: Bool

    public init() {
        startTime = 0
        positionals = ArrayList<String>()
        passthrough = ArrayList<String>()
        debug = DebugOptions()
        testOptions = TestOptions()
        bundlerOptions = BundlerOptions()
        runtimeOptions = RuntimeOptions()
        filters = ArrayList<String>()
        workspaces = false
        ifPresent = false
        parallel = false
        sequential = false
        noExitOnError = false
        preloads = ArrayList<String>()
        hasLoadedGlobalConfig = false
    }
}
