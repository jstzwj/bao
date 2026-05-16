// perf - 系统级性能追踪
// 严格翻译自: bun/src/perf/perf.zig (160行)
//   提供使用系统级性能分析器追踪事件的功能:
//     - macOS: 使用 OSLog/Signpost (Instruments)
//     - Linux: 使用自定义 perf 事件
//     - 其他平台: 禁用 (no-op)
//
//   Zig 版本通过 comptime + union(enum) 实现零开销抽象
//   仓颉版本使用 sealed class 实现类似功能
package bao_perf

import bao_core.*

// ============================================================================
// PerfCtx - 性能追踪上下文
// 严格翻译自: perf.zig - Ctx
//   pub const Ctx = union(enum) {
//       disabled: Disabled,
//       enabled: switch (bun.Environment.os) {
//           .mac => Darwin,
//           .linux => Linux,
//           else => Disabled,
//       },
//       pub fn end(this: *const @This()) void { ... }
//   };
// ============================================================================

/// 性能追踪上下文基类
/// 对应 Bun perf.Ctx (tagged union)
/// 使用密封类层次结构替代 Zig 的 union(enum)
public sealed class PerfCtx {
    /// 结束追踪区间
    /// 对应 Zig: pub fn end(this: *const @This()) void
    public func end(): Unit {}
}

/// 禁用状态的追踪上下文
/// 对应 Zig: pub const Disabled = struct { pub inline fn end() void {} }
public class DisabledCtx <: PerfCtx {
    public init() {}

    /// 无操作 - 对应 Zig Disabled.end()
    public override func end(): Unit {
        // no-op
    }
}

/// macOS 上的追踪上下文 (OSLog Signpost)
/// 对应 Zig: pub const Darwin = struct { ... }
public class DarwinCtx <: PerfCtx {
    // OSLog Signpost Interval 句柄
    // 对应 Zig: interval: OSLog.Signpost.Interval
    private let intervalId: Int64
    private var ended: Bool = false

    public init(intervalId: Int64) {
        this.intervalId = intervalId
    }

    /// 结束追踪区间
    /// 对应 Zig Darwin.end() - 调用 OSLog.Signpost.Interval.end()
    public override func end(): Unit {
        if (!ended) {
            ended = true
            // 调用 OSLog signpost interval end
            // 仓颉版本通过 FFI 调用 os_signpost_interval_end
            Darwin.osLogEndInterval(intervalId)
        }
    }
}

/// Linux 上的追踪上下文 (自定义 perf 事件)
/// 对应 Zig: pub const Linux = struct { ... }
public class LinuxCtx <: PerfCtx {
    // 对应 Zig: start_time: u64, event: PerfEvent
    private let startTime: UInt64
    private let event: PerfEvent
    private var ended: Bool = false

    public init(startTime: UInt64, event: PerfEvent) {
        this.startTime = startTime
        this.event = event
    }

    /// 结束追踪区间
    /// 对应 Zig Linux.end() - 计算持续时间并发出事件
    ///   const duration = bun.timespec.now(.force_real_time).ns() -| this.start_time;
    ///   _ = Bun__linux_trace_emit(@tagName(this.event).ptr, @intCast(duration));
    public override func end(): Unit {
        if (!ended) {
            ended = true
            if (!Linux.isSupported()) {
                return
            }
            let nowNs = HwTimer.osMonotonicNs()
            let duration = nowNs - startTime
            // 对应 Zig: Bun__linux_trace_emit(@tagName(this.event).ptr, duration)
            Linux.traceEmit(event.tagName(), Int64(duration))
        }
    }
}

// ============================================================================
// Perf - 性能追踪入口
// 严格翻译自: perf.zig 模块级别函数
//   - isEnabled(): 检查性能追踪是否启用
//   - trace(name): 追踪一个命名事件
// ============================================================================

/// 性能追踪 - 对应 Bun perf 模块
public class Perf {
    // ========================================================================
    // isEnabled - 是否启用
    // 严格翻译自: perf.zig - isEnabled()
    //   var is_enabled_once = std.once(isEnabledOnce);
    //   var is_enabled = std.atomic.Value(bool).init(false);
    //   pub fn isEnabled() bool {
    //       is_enabled_once.call();
    //       return is_enabled.load(.seq_cst);
    //   }
    // ========================================================================

    /// 是否已检查过启用状态 (对应 Zig std.once)
    private static var enabledChecked: Bool = false

    /// 是否启用性能追踪 (对应 Zig is_enabled)
    private static var enabledValue: Bool = false

    /// 检查性能追踪是否启用
    /// 对应 Bun perf.isEnabled()
    /// macOS: 检查 DYLD_ROOT_PATH 或 BUN_INSTRUMENTS 环境变量，以及 OSLog 可用性
    /// Linux: 检查 BUN_TRACE 环境变量，以及 trace_init 成功
    public static func isEnabled(): Bool {
        if (!enabledChecked) {
            enabledChecked = true
            checkEnabledOnce()
        }
        return enabledValue
    }

    /// 一次性启用检查 - 对应 Zig isEnabledOnce()
    private static func checkEnabledOnce(): Unit {
        if (Environment.IS_MAC) {
            checkEnabledMacOS()
            if (Darwin.getOsLog() == None) {
                enabledValue = false
            }
        } else if (Environment.IS_LINUX) {
            checkEnabledLinux()
            if (!Linux.isSupported()) {
                enabledValue = false
            }
        }
        // 其他平台: 保持 false
    }

    /// macOS 启用检查 - 对应 Zig isEnabledOnMacOSOnce()
    /// 检查 DYLD_ROOT_PATH 或 BUN_INSTRUMENTS 环境变量
    private static func checkEnabledMacOS(): Unit {
        // 对应 Zig:
        //   if (bun.env_var.DYLD_ROOT_PATH.get() != null or bun.feature_flag.BUN_INSTRUMENTS.get()) {
        //       is_enabled.store(true, .seq_cst);
        //   }
        // 简化实现: 检查环境变量
        let dyldRoot = EnvVar.get("DYLD_ROOT_PATH")
        let bunInstruments = EnvVar.get("BUN_INSTRUMENTS")
        if (dyldRoot != None || bunInstruments != None) {
            enabledValue = true
        }
    }

    /// Linux 启用检查 - 对应 Zig isEnabledOnLinuxOnce()
    /// 检查 BUN_TRACE 环境变量
    private static func checkEnabledLinux(): Unit {
        // 对应 Zig:
        //   if (bun.feature_flag.BUN_TRACE.get()) {
        //       is_enabled.store(true, .seq_cst);
        //   }
        let bunTrace = EnvVar.get("BUN_TRACE")
        if (bunTrace != None) {
            enabledValue = true
        }
    }

    // ========================================================================
    // trace - 追踪一个命名事件
    // 严格翻译自: perf.zig - trace()
    //   pub fn trace(comptime name: [:0]const u8) Ctx {
    //       comptime {
    //           if (!@hasField(PerfEvent, name)) {
    //               @compileError(...);
    //           }
    //       }
    //       if (!isEnabled()) return .{ .disabled = .{} };
    //       if (comptime bun.Environment.isMac) {
    //           return .{ .enabled = Darwin.init(...) };
    //       } else if (comptime bun.Environment.isLinux) {
    //           return .{ .enabled = Linux.init(...) };
    //       }
    //       return .{ .disabled = .{} };
    //   }
    // ========================================================================

    /// 追踪一个命名性能事件
    /// 对应 Bun perf.trace()
    /// 使用字符串字面量精确匹配 PerfEvent 枚举
    /// 当 Instruments/perf 未连接时为 no-op
    public static func trace(event: PerfEvent): PerfCtx {
        if (!isEnabled()) {
            return DisabledCtx()
        }

        if (Environment.IS_MAC) {
            return Darwin.`init`(event)
        } else if (Environment.IS_LINUX) {
            return Linux.`init`(event)
        }

        return DisabledCtx()
    }

    /// 通过名称字符串追踪事件
    /// 对应 Bun perf.trace("name") 的编译时版本
    /// 仓颉没有编译时字符串检查，使用运行时查找
    public static func traceByName(name: String): PerfCtx {
        let event = fromPerfTag(name)
        if (event == None) {
            return DisabledCtx()
        }
        return trace(event.getOrThrow())
    }
}

// ============================================================================
// Darwin - macOS 性能追踪
// 严格翻译自: perf.zig - Darwin
//   pub const Darwin = struct {
//       const OSLog = bun.darwin.OSLog;
//       interval: OSLog.Signpost.Interval,
//       pub fn init(comptime name: i32) @This() { ... }
//       pub fn end(this: *const @This()) void { ... }
//       var os_log: ?*OSLog = null;
//       var os_log_once = std.once(getOnce);
//       fn getOnce() void { os_log = OSLog.init(); }
//       pub fn get() ?*OSLog { os_log_once.call(); return os_log; }
//   };
// ============================================================================

/// macOS 性能追踪 - 使用 OSLog Signpost
/// 对应 Bun perf.Darwin
public class Darwin {
    /// OSLog 实例 (对应 Zig var os_log: ?*OSLog = null)
    private static var osLogInstance: Int64 = 0
    private static var osLogInitialized: Bool = false

    /// 获取 OSLog 实例
    /// 对应 Zig: pub fn get() ?*OSLog
    public static func getOsLog(): ?Int64 {
        if (!osLogInitialized) {
            osLogInitialized = true
            // 对应 Zig: os_log = OSLog.init()
            // 仓颉: 通过 FFI 调用 os_log_create
            osLogInstance = osLogCreate()
        }
        if (osLogInstance == 0) {
            return None
        }
        return Some(osLogInstance)
    }

    /// 初始化追踪上下文
    /// 对应 Zig: pub fn init(comptime name: i32) @This()
    ///   return .{ .interval = os_log.?.signpost(name).interval(.PointsOfInterest) }
    public static func initFunc(event: PerfEvent): DarwinCtx {
        let log = getOsLog()
        if (log == None) {
            return DarwinCtx(intervalId: 0)
        }
        // 创建 OSLog signpost interval
        // 对应 Zig: os_log.?.signpost(name).interval(.PointsOfInterest)
        let intervalId = osLogSignpostBegin(log.getOrThrow(), event.toInt())
        return DarwinCtx(intervalId: intervalId)
    }

    /// 结束 OSLog signpost interval
    public static func osLogEndInterval(intervalId: Int64): Unit {
        if (intervalId == 0) {
            return
        }
        // 对应 FFI 调用 os_signpost_interval_end
        nativeOsLogEndInterval(intervalId)
    }

    // ========================================================================
    // FFI 声明 - macOS 原生函数
    // 对应 Zig 通过 bun.darwin.OSLog 调用的函数
    // ========================================================================

    /// 创建 OSLog - 对应 os_log_create("", "")
    @FFI
    private static func osLogCreate(): Int64 {
        // macOS FFI: os_log_create("dev.bao", "perf")
        // 返回 os_log_t 句柄
        return 0
    }

    /// 开始 signpost interval - 对应 os_signpost_interval_begin
    @FFI
    private static func osLogSignpostBegin(logHandle: Int64, eventId: Int64): Int64 {
        // macOS FFI: os_signpost_interval_begin(log, id, "perf", "%d", eventId)
        return 0
    }

    /// 结束 signpost interval - 对应 os_signpost_interval_end
    @FFI
    private static func nativeOsLogEndInterval(intervalId: Int64): Unit {
        // macOS FFI: os_signpost_interval_end(log, id, "perf")
    }
}

// ============================================================================
// Linux - Linux 性能追踪
// 严格翻译自: perf.zig - Linux
//   pub const Linux = struct {
//       start_time: u64,
//       event: PerfEvent,
//       var is_initialized = std.atomic.Value(bool).init(false);
//       var init_once = std.once(initOnce);
//       extern "c" fn Bun__linux_trace_init() c_int;
//       extern "c" fn Bun__linux_trace_close() void;
//       extern "c" fn Bun__linux_trace_emit(event_name: [*:0]const u8, duration_ns: i64) c_int;
//       fn initOnce() void { ... }
//       pub fn isSupported() bool { ... }
//       pub fn init(event: PerfEvent) @This() { ... }
//       pub fn end(this: *const @This()) void { ... }
//   };
// ============================================================================

/// Linux 性能追踪 - 使用自定义 trace 事件
/// 对应 Bun perf.Linux
public class Linux {
    /// 是否已初始化 (对应 Zig is_initialized)
    private static var initialized: Bool = false

    /// 是否已执行初始化检查 (对应 Zig init_once)
    private static var initChecked: Bool = false

    /// 初始化结果
    private static var initResult: Bool = false

    // ========================================================================
    // extern "c" 函数声明
    // 严格翻译自: perf.zig - extern "c" fn Bun__*
    // ========================================================================

    /// 初始化 Linux 追踪
    /// 对应 Zig: extern "c" fn Bun__linux_trace_init() c_int
    @FFI
    private static func linuxTraceInit(): Int64 {
        // FFI 调用 C 函数 Bun__linux_trace_init()
        // 设置 perf event buffer
        return 0
    }

    /// 关闭 Linux 追踪
    /// 对应 Zig: extern "c" fn Bun__linux_trace_close() void
    @FFI
    private static func linuxTraceClose(): Unit {
        // FFI 调用 C 函数 Bun__linux_trace_close()
    }

    /// 发出追踪事件
    /// 对应 Zig: extern "c" fn Bun__linux_trace_emit(event_name: [*:0]const u8, duration_ns: i64) c_int
    @FFI
    private static func linuxTraceEmit(eventName: String, durationNs: Int64): Int64 {
        // FFI 调用 C 函数 Bun__linux_trace_emit(name_ptr, duration_ns)
        return 0
    }

    /// 一次性初始化 - 对应 Zig initOnce()
    private static func initOnce(): Unit {
        let result = linuxTraceInit()
        initResult = (result != 0)
    }

    /// 是否支持 Linux 追踪
    /// 对应 Zig: pub fn isSupported() bool
    public static func isSupported(): Bool {
        if (!initChecked) {
            initChecked = true
            initOnce()
        }
        return initResult
    }

    /// 初始化追踪上下文
    /// 对应 Zig: pub fn init(event: PerfEvent) @This()
    ///   return .{
    ///       .start_time = bun.timespec.now(.force_real_time).ns(),
    ///       .event = event,
    ///   };
    public static func initFunc(event: PerfEvent): LinuxCtx {
        return LinuxCtx(
            startTime: HwTimer.osMonotonicNs(),
            event: event
        )
    }

    /// 发出追踪事件 (从 LinuxCtx.end() 调用)
    /// 对应 Zig Linux.end() 中的 Bun__linux_trace_emit
    public static func traceEmit(eventName: String, durationNs: Int64): Unit {
        linuxTraceEmit(eventName, durationNs)
    }
}

// ============================================================================
// PerfEvent 辅助扩展 - 通过标签名查找事件
// ========================================================================

/// PerfEvent 扩展: 通过 Bun 原始名称查找
public func fromPerfTag(tag: String): ?PerfEvent {
    // 所有事件的名称映射
    let allEvents: Array<(String, PerfEvent)> = [
        ("Bundler.BindImportsToExports", PerfEvent.BundlerBindImportsToExports),
        ("Bundler.breakOutputIntoPieces", PerfEvent.BundlerBreakOutputIntoPieces),
        ("Bundler.cloneAST", PerfEvent.BundlerCloneAST),
        ("Bundler.CloneLinkerGraph", PerfEvent.BundlerCloneLinkerGraph),
        ("Bundler.computeChunks", PerfEvent.BundlerComputeChunks),
        ("Bundler.CreateNamespaceExports", PerfEvent.BundlerCreateNamespaceExports),
        ("Bundler.FigureOutCommonJS", PerfEvent.BundlerFigureOutCommonJS),
        ("Bundler.findAllImportedPartsInJSOrder", PerfEvent.BundlerFindAllImportedPartsInJSOrder),
        ("Bundler.findReachableFiles", PerfEvent.BundlerFindReachableFiles),
        ("Bundler.generateChunksInParallel", PerfEvent.BundlerGenerateChunksInParallel),
        ("Bundler.generateCodeForFileInChunkCss", PerfEvent.BundlerGenerateCodeForFileInChunkCss),
        ("Bundler.generateCodeForFileInChunkJS", PerfEvent.BundlerGenerateCodeForFileInChunkJS),
        ("Bundler.generateIsolatedHash", PerfEvent.BundlerGenerateIsolatedHash),
        ("Bundler.generateSourceMapForChunk", PerfEvent.BundlerGenerateSourceMapForChunk),
        ("Bundler.markFileLiveForTreeShaking", PerfEvent.BundlerMarkFileLiveForTreeShaking),
        ("Bundler.markFileReachableForCodeSplitting", PerfEvent.BundlerMarkFileReachableForCodeSplitting),
        ("Bundler.MatchImportsWithExports", PerfEvent.BundlerMatchImportsWithExports),
        ("Bundler.onParseTaskComplete", PerfEvent.BundlerOnParseTaskComplete),
        ("Bundler.ParseJS", PerfEvent.BundlerParseJS),
        ("Bundler.ParseJSON", PerfEvent.BundlerParseJSON),
        ("Bundler.ParseJSON5", PerfEvent.BundlerParseJSON5),
        ("Bundler.ParseTOML", PerfEvent.BundlerParseTOML),
        ("Bundler.ParseYAML", PerfEvent.BundlerParseYAML),
        ("Bundler.postProcessJSChunk", PerfEvent.BundlerPostProcessJSChunk),
        ("Bundler.readFile", PerfEvent.BundlerReadFile),
        ("Bundler.renameSymbolsInChunk", PerfEvent.BundlerRenameSymbolsInChunk),
        ("Bundler.ResolveExportStarStatements", PerfEvent.BundlerResolveExportStarStatements),
        ("Bundler.scanImportsAndExports", PerfEvent.BundlerScanImportsAndExports),
        ("Bundler.treeShakingAndCodeSplitting", PerfEvent.BundlerTreeShakingAndCodeSplitting),
        ("Bundler.Worker.create", PerfEvent.BundlerWorkerCreate),
        ("Bundler.WrapDependencies", PerfEvent.BundlerWrapDependencies),
        ("Bundler.writeChunkToDisk", PerfEvent.BundlerWriteChunkToDisk),
        ("Bundler.writeOutputFilesToDisk", PerfEvent.BundlerWriteOutputFilesToDisk),
        ("ExtractTarball.extract", PerfEvent.ExtractTarballExtract),
        ("FolderResolver.readPackageJSONFromDisk.folder", PerfEvent.FolderResolverReadPackageJSONFromDiskFolder),
        ("FolderResolver.readPackageJSONFromDisk.workspace", PerfEvent.FolderResolverReadPackageJSONFromDiskWorkspace),
        ("JSBundler.addPlugin", PerfEvent.JSBundlerAddPlugin),
        ("JSBundler.hasAnyMatches", PerfEvent.JSBundlerHasAnyMatches),
        ("JSBundler.matchOnLoad", PerfEvent.JSBundlerMatchOnLoad),
        ("JSBundler.matchOnResolve", PerfEvent.JSBundlerMatchOnResolve),
        ("JSGlobalObject.create", PerfEvent.JSGlobalObjectCreate),
        ("JSParser.analyze", PerfEvent.JSParserAnalyze),
        ("JSParser.parse", PerfEvent.JSParserParse),
        ("JSParser.postvisit", PerfEvent.JSParserPostvisit),
        ("JSParser.visit", PerfEvent.JSParserVisit),
        ("JSPrinter.print", PerfEvent.JSPrinterPrint),
        ("JSPrinter.printWithSourceMap", PerfEvent.JSPrinterPrintWithSourceMap),
        ("ModuleResolver.resolve", PerfEvent.ModuleResolverResolve),
        ("PackageInstaller.install", PerfEvent.PackageInstallerInstall),
        ("PackageManifest.Serializer.loadByFile", PerfEvent.PackageManifestSerializerLoadByFile),
        ("PackageManifest.Serializer.save", PerfEvent.PackageManifestSerializerSave),
        ("RuntimeTranspilerCache.fromFile", PerfEvent.RuntimeTranspilerCacheFromFile),
        ("RuntimeTranspilerCache.save", PerfEvent.RuntimeTranspilerCacheSave),
        ("RuntimeTranspilerCache.toFile", PerfEvent.RuntimeTranspilerCacheToFile),
        ("StandaloneModuleGraph.serialize", PerfEvent.StandaloneModuleGraphSerialize),
        ("Symbols.followAll", PerfEvent.SymbolsFollowAll),
        ("TestCommand.printCodeCoverageLCov", PerfEvent.TestCommandPrintCodeCoverageLCov),
        ("TestCommand.printCodeCoverageLCovAndText", PerfEvent.TestCommandPrintCodeCoverageLCovAndText),
        ("TestCommand.printCodeCoverageText", PerfEvent.TestCommandPrintCodeCoverageText),
    ]

    for ((tagStr, event) in allEvents) {
        if (tagStr == tag) {
            return Some(event)
        }
    }
    return None
}
