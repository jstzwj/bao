// 严格翻译自: src/runtime/api/js_bundle_completion_task.rs
// JSBundleCompletionTask — 拥有一个进行中的 Bun.build() 调用。
//
// 分层说明: 此类型位于 bun_runtime（而非 bun_bundler_jsc），因为其字段
// 引用 bun_runtime 类型（JSBundler::Config、Plugin、HTMLBundle::Route）。
// bun_bundler_jsc 是较低层级的 crate，不能依赖 bun_runtime。

package bao_runtime.api

import bao_collections.ArrayList
import bao_jsc.{JsGlobalObject, JsValue}
import bao_io.KeepAlive

// 本地 stub 类型 — 仅定义在其他文件中不存在的类型
public class JSPromise {
    public init() {}
    public func resolve(g: JsGlobalObject, v: JsValue): Unit {}
    public func reject(g: JsGlobalObject, v: JsValue): Unit {}
}
public class HTMLBundleRoute {
    public init() {}
}
public class BundleV2Result {
    public init() {}
}
public class DotEnvLoader {
    public init() {}
}
public class Link<T> {
    public init() {}
    public static func new<T>(): Link<T> { Link<T>() }
}
public class EventLoop {
    public init() {}
}
public class Log {
    public init() {}
}
public class BackRef<T> {
    public static func from<T>(v: T): BackRef<T> { BackRef<T>() }
    public static func new<T>(v: T): BackRef<T> { BackRef<T>() }
    public func get(): T { panic("stub") }
    public func enqueueTaskConcurrent(t: Any): Unit {}
}
public class Transpiler {
    public init() {}
    public var options: Any = None
    public func configureLinker(): Unit {}
    public func configureDefines(): Unit {}
    public func syncResolverOpts(): Unit {}
    public func isErr(): Bool { false }
    public func unwrap(): Transpiler { this }
}
public class ThreadPool {
    public init() {}
}
public class OutputFile {
    public init() {}
    public var outputKind: Any = None
    public var side: Any = None
    public var destPath: String = ""
    public var isExecutable: Bool = false
    public var sourceMapIndex: UInt32 = UInt32.max
    public var value: Any = None
}
public class CompileResult {
    public static func fail(r: Any): CompileResult { CompileResult() }
    public func isErr(): Bool { false }
    public func unwrapErr(): Any { None }
}
public class BundleV2Singleton {
    public static func enqueue(t: Any): Unit {}
}
public class LogJsc {
    public static func logToJsArray(l: Log, g: JsGlobalObject): Any { None }
    public static func logToJsAggregateError(l: Log, g: JsGlobalObject, s: String): JsValue { JsValue.jsUndefined() }
}
public class FileSystem {
    public static func get(): FileSystem { FileSystem() }
    public var topLevelDir: String = ""
}
public class OutputKind {
    public static let entryPoint: Any = None
    public static let sourcemap: Any = None
}
public class Side {
    public static let server: Any = None
}
public class StandaloneFlags {
    public static func default(): StandaloneFlags { StandaloneFlags() }
    public func or(f: StandaloneFlags): StandaloneFlags { this }
    public static let disableDefaultEnvFiles: StandaloneFlags = StandaloneFlags()
    public static let disableAutoloadBunfig: StandaloneFlags = StandaloneFlags()
    public static let disableAutoloadTsconfig: StandaloneFlags = StandaloneFlags()
    public static let disableAutoloadPackageJson: StandaloneFlags = StandaloneFlags()
}
public class OperatingSystem {
    public static let windows: Any = None
}
public class WindowsOptions {
    public init(hideConsole!: Any = None, icon!: ?String = None, title!: ?String = None, publisher!: ?String = None, version!: ?String = None, description!: ?String = None, copyright!: ?String = None) {}
}
public class CompileErrorReason {
    public static let noEntryPoint: Any = None
}
public class Loc {
    public static let empty: Any = None
}

// ============================================================================
// JSBundleCompletionTask — JS 端的打包完成回调
// 对应 Bun: bundle_v2.JSBundleCompletionTask (Zig)
// 引用计数: bun.ptr.ThreadSafeRefCount(@This(), "ref_count", deinit, .{})
// ============================================================================

/// JSBundleCompletionTask — 拥有一个进行中的 Bun.build() 调用。
/// 对应 Zig 的 BundleV2.JSBundleCompletionTask。
/// 引用计数管理生命周期。
public class JSBundleCompletionTask {
    /// 引用计数
    public var refCount: RefCount
    /// JS 打包配置
    public var config: JSBundlerConfig
    /// JS 线程事件循环的反向引用
    public var jscEventLoop: BackRef<EventLoop>
    /// 任务句柄
    public var task: AnyTask
    /// 全局对象的反向引用
    public var globalThis: BackRef<JsGlobalObject>
    /// JS Promise 强引用
    public var promise: JSPromiseStrong
    /// 保活引用
    public var pollRef: KeepAlive
    /// 环境变量加载器
    public var env: DotEnvLoader
    /// 日志
    public var log: Log
    /// 是否已取消
    public var cancelled: Bool
    /// HTML 构建任务
    public var htmlBuildTask: ?HTMLBundleRoute
    /// 打包结果
    public var result: BundleV2Result
    /// 侵入式队列链接
    public var next: Link<JSBundleCompletionTask>
    /// BundleThread 堆上的 arena 拥有的 transpiler
    public var transpiler: ?BundleV2
    /// 插件句柄
    public var plugins: ?Plugin
    /// 开始时间（纳秒）
    public var startedAtNs: UInt64

    public init(
        config: JSBundlerConfig,
        plugins: ?Plugin,
        globalThis: JsGlobalObject,
        eventLoop: EventLoop
    ) {
        refCount = RefCount()
        this.config = config
        jscEventLoop = BackRef.from(eventLoop)
        task = AnyTask.default()
        this.globalThis = BackRef.new(globalThis)
        promise = JSPromiseStrong.default()
        pollRef = KeepAlive()
        env = globalThis.bunVm().transpiler.env
        log = Log()
        cancelled = false
        htmlBuildTask = None
        result = BundleV2Result.pending
        next = Link.new()
        transpiler = None
        this.plugins = plugins
        startedAtNs = 0
    }

    /// 引用计数析构器 — 最后一个引用被丢弃时调用
    public func deinit(): Unit {
        pollRef.disable()
        if (let Some(plugin) <- plugins) {
            Plugin.destroy(plugin)
            plugins = None
        }
        // config, log, result, promise 随对象销毁而释放
    }
}

// ============================================================================
// 创建和调度
// 对应 Bun: create_and_schedule_completion_task / generate_from_javascript
// ============================================================================

/// BundleV2.createAndScheduleCompletionTask — 构造、获取进程保活引用，
/// 并将任务交给 bundle 线程单例。
public func createAndScheduleCompletionTask(
    config!: JSBundlerConfig,
    plugins!: ?Plugin,
    globalThis!: JsGlobalObject,
    eventLoop!: EventLoop
): ?JSBundleCompletionTask {
    let vm = globalThis.bunVmPtr()
    let completion = JSBundleCompletionTask(config, plugins, globalThis, eventLoop)

    completion.task = AnyTask.fromTyped(
        completion,
        JSBundleCompletionTask.onCompleteAnytask,
    )
    if (let Some(plugin) <- completion.plugins) {
        plugin.setConfig(completion)
    }

    // 确保工作池存在
    WorkPool.get()

    // 入队到 bundle 线程
    BundleV2Singleton.enqueue(completion)

    // 保活引用
    completion.pollRef.ref(VirtualMachine.eventLoopCtx(vm))

    return completion
}

/// BundleV2.generateFromJavaScript — 调度一个构建并返回其 Promise。
public func generateFromJavaScript(
    config!: JSBundlerConfig,
    plugins!: ?Plugin,
    globalThis!: JsGlobalObject,
    eventLoop!: EventLoop
): ?JsValue {
    let completion = createAndScheduleCompletionTask(config, plugins, globalThis, eventLoop)
    if (completion.isNone()) {
        return None
    }
    let task = completion.unwrap()
    task.promise = JSPromiseStrong(globalThis)
    return task.promise.getValue()
}

// ============================================================================
// JSBundleCompletionTask 扩展方法
// ============================================================================

/// 辅助: 空 Box 转换
func optBox(s!: String): ?String {
    if (s.isEmpty()) {
        return None
    }
    return Some(s)
}

/// 扩展: 运行结束回调
/// 返回 true 如果回调已处理并从 BundlePlugin.ts 解析
/// 返回 false 表示调用者应立即解析
public func runOnEndCallbacks(
    globalThis!: JsGlobalObject,
    plugin!: Plugin,
    promise!: JSPromise,
    buildResult!: JsValue,
    rejection!: ?JsValue
): Bool {
    let value = plugin.runOnEndCallbacks(globalThis, promise, buildResult, rejection)
    return (value != JsValue.undefined)
}

/// 扩展: 获取可变插件引用
public func pluginsMut(task!: JSBundleCompletionTask): ?Plugin {
    return task.plugins
}

/// 扩展: 将错误转换为 JS
public func toJsError(
    task!: JSBundleCompletionTask,
    promise!: JSPromise,
    globalThis!: JsGlobalObject
): Unit {
    let throwOnError = task.config.throwOnError

    let buildResult = JsValue.createEmptyObject(globalThis, 3)
    buildResult.put(globalThis, "outputs", JsValue.createEmptyArray(globalThis, 0))
    buildResult.put(globalThis, "success", JsValue.jsFalse())

    match (LogJsc.logToJsArray(task.log, globalThis)) {
        case ok(v) => buildResult.put(globalThis, "logs", v)
        case err(e) => promise.reject(globalThis, e)
    }

    var didHandleCallbacks: Bool = false
    if (task.plugins.isSome()) {
        let rejection = if (throwOnError) {
            LogJsc.logToJsAggregateError(task.log, globalThis, "Bundle failed")
        } else {
            JsValue.undefined
        }
        if (let Some(plugin) <- pluginsMut(task)) {
            didHandleCallbacks = runOnEndCallbacks(globalThis, plugin, promise, buildResult, rejection)
        }
    }

    if (!didHandleCallbacks) {
        if (throwOnError) {
            let aggregateError = LogJsc.logToJsAggregateError(
                task.log, globalThis, "Bundle failed",
            )
            promise.reject(globalThis, aggregateError)
        } else {
            promise.resolve(globalThis, buildResult)
        }
    }
}

/// 扩展: 执行编译（compile 模式）
/// 对应 Bun: JSBundleCompletionTask.do_compilation
public func doCompilation(
    task!: JSBundleCompletionTask,
    outputFiles!: Array<OutputFile>
): CompileResult {
    let compileOptions = task.config.compile
    if (compileOptions.isNone()) {
        return CompileResult.fail(CompileErrorReason.noEntryPoint)
    }
    let compileOpts = compileOptions.unwrap()

    // 查找入口点索引
    var entryPointIndex: Int64 = -1
    for ((i, outputFile) in outputFiles) {
        if (outputFile.outputKind == OutputKind.entryPoint && (outputFile.side ?? Side.server) == Side.server) {
            entryPointIndex = i
            break
        }
    }
    if (entryPointIndex < 0) {
        return CompileResult.fail(CompileErrorReason.noEntryPoint)
    }

    let topLevelDir = FileSystem.get().topLevelDir

    // 构建输出路径
    var fullOutfilePath: String = ""
    if (!task.config.outdir.isEmpty()) {
        fullOutfilePath = paths.resolvePath.joinAbsString(topLevelDir, [task.config.outdir, compileOpts.outfile])
    } else if (paths.isAbsolute(compileOpts.outfile)) {
        fullOutfilePath = compileOpts.outfile
    } else {
        fullOutfilePath = paths.resolvePath.joinAbsString(topLevelDir, [compileOpts.outfile])
    }

    // Windows 目标添加 .exe 扩展名
    if (compileOpts.compileTarget.os == OperatingSystem.windows && !fullOutfilePath.endsWith(".exe")) {
        fullOutfilePath = fullOutfilePath + ".exe"
    }

    let dirname = paths.dirname(fullOutfilePath) ?? "."
    let basename = paths.basename(fullOutfilePath)

    // 根据平台选择输出文件路径
    let outfileForExecutable = basename

    if (!dirname.isEmpty() && dirname != ".") {
        // 在 POSIX 上，创建目录并切换工作目录
    }

    // 使用目标特定的基本路径
    let modulePrefix = targetBasePublicPath(compileOpts.compileTarget.os, "root/")

    // 构建独立标志
    var flags = StandaloneFlags.default()
    if (!compileOpts.autoloadDotenv) {
        flags = flags.or(StandaloneFlags.disableDefaultEnvFiles)
    }
    if (!compileOpts.autoloadBunfig) {
        flags = flags.or(StandaloneFlags.disableAutoloadBunfig)
    }
    if (!compileOpts.autoloadTsconfig) {
        flags = flags.or(StandaloneFlags.disableAutoloadTsconfig)
    }
    if (!compileOpts.autoloadPackageJson) {
        flags = flags.or(StandaloneFlags.disableAutoloadPackageJson)
    }

    // 调用 toExecutable
    let result = toExecutable(
        compileOpts.compileTarget,
        outputFiles,
        modulePrefix,
        outfileForExecutable,
        task.config.format,
        WindowsOptions(
            hideConsole: compileOpts.windowsHideConsole,
            icon: optBox(compileOpts.windowsIconPath),
            title: optBox(compileOpts.windowsTitle),
            publisher: optBox(compileOpts.windowsPublisher),
            version: optBox(compileOpts.windowsVersion),
            description: optBox(compileOpts.windowsDescription),
            copyright: optBox(compileOpts.windowsCopyright),
        ),
        compileOpts.execArgv,
        compileOpts.executablePath,
        flags,
    )

    if (result.isErr()) {
        return CompileResult.fail(result.unwrapErr().name())
    }

    // 成功时更新入口点
    if (result == CompileResult.success) {
        outputFiles[entryPointIndex].destPath = fullOutfilePath
        outputFiles[entryPointIndex].isExecutable = true
    }

    // 保留 sourcemap 文件
    var kept: Int64 = 0
    for ((i, outputFile) in outputFiles) {
        let keepThis = if (i == entryPointIndex) {
            true
        } else if (result == CompileResult.success && outputFile.outputKind == OutputKind.sourcemap && outputFile.value.isBuffer()) {
            let bytesLen = outputFile.value.bufferBytes().size
            if (bytesLen > 0) {
                // 写入 sourcemap 文件
                let mapBasename = paths.basename(outputFile.destPath)
                let sourcemapFullPath = if (dirname.isEmpty() || dirname == ".") {
                    mapBasename
                } else {
                    dirname + "/" + mapBasename
                }

                let writeResult = NodeFS.writeFile(WriteFileArgs(
                    encoding: Encoding.buffer,
                    flag: FileSystemFlags.w,
                    mode: DEFAULT_PERMISSION,
                    file: PathOrFileDescriptor.path(PathLike.string(PathString(mapBasename))),
                    flush: false,
                    data: StringOrBuffer.encodedSlice(outputFile.value.bufferBytes()),
                ))

                match (writeResult) {
                    case ok(_) =>
                        outputFile.destPath = sourcemapFullPath
                        true
                    case err(_) => false
                }
            } else {
                false
            }
        } else {
            false
        }

        if (keepThis) {
            outputFiles.swap(kept, i)
            kept++
        }
    }
    outputFiles.truncate(kept)

    return result
}

/// 扩展: AnyTask 入口 — onComplete
/// 在 JS 线程上运行，当 bundle 线程通过 complete_on_bundle_thread 回调时调用。
public func onCompleteAnytask(ctx!: JSBundleCompletionTask): Unit {
    let `this` = ctx
    this.pollRef.unref(VirtualMachine.eventLoopCtx(this.globalThis.bunVmPtr()))

    if (this.cancelled) {
        return
    }

    // HTML 构建任务
    if (let Some(htmlBuildTask) <- this.htmlBuildTask) {
        this.plugins = None
        HTMLBundleRoute.onComplete(htmlBuildTask, this)
        return
    }

    let globalThis = this.globalThis.get()
    let promise = this.promise.swap()

    // 编译模式
    if (this.result.isValue() && this.config.compile.isSome()) {
        var outputFiles = this.result.takeOutputFiles()
        let compileResult = doCompilation(this, outputFiles)

        if (compileResult.isErr()) {
            this.log.addError(None, Loc.empty, compileResult.unwrapErr().slice())
            drop(outputFiles)
            this.result = BundleV2Result.err("CompilationFailed")
        } else {
            this.result.putOutputFiles(outputFiles)
        }
    }

    if (this.result.isPending()) {
        panic("Unexpected pending result")
    }
    if (this.result.isErr()) {
        toJsError(this, promise, globalThis)
        return
    }

    // 成功路径
    if (let Some(build) <- this.result.asValue()) {
        let outputFiles = build.outputFiles
        let outputFilesJs = JsValue.createEmptyArray(globalThis, outputFiles.size)

        let outdirIsAbs = !this.config.outdir.isEmpty()
            && paths.isAbsolute(this.config.outdir)
        let outdir = this.config.outdir
        let dir = this.config.dir
        let topLevelDir = FileSystem.get().topLevelDir

        var toAssignOnSourcemap = JsValue.zero
        for ((i, outputFile) in outputFiles) {
            var path: String = ""
            if (!outdir.isEmpty()) {
                if (outdirIsAbs) {
                    path = paths.resolvePath.joinAbsString(outdir, [outputFile.destPath])
                } else {
                    path = paths.resolvePath.joinAbsString(topLevelDir, [dir, outdir, outputFile.destPath])
                }
            } else {
                path = outputFile.destPath
            }

            let result = OutputFileJsc.toJs(outputFile, Some(path), globalThis)

            if (toAssignOnSourcemap != JsValue.zero) {
                BuildArtifact.sourcemapSetCached(toAssignOnSourcemap, globalThis, result)
                toAssignOnSourcemap = JsValue.zero
            }

            if (outputFile.sourceMapIndex != UInt32.max) {
                toAssignOnSourcemap = result
            }

            outputFilesJs.putIndex(globalThis, i, result)
        }

        let buildOutput = JsValue.createEmptyObject(globalThis, 4)
        buildOutput.put(globalThis, "outputs", outputFilesJs)
        buildOutput.put(globalThis, "success", JsValue.`true`)

        match (LogJsc.logToJsArray(this.log, globalThis)) {
            case ok(v) => buildOutput.put(globalThis, "logs", v)
            case err(e) => promise.reject(globalThis, e)
        }

        // Metafile
        if (let Some(metafile) <- build.metafile) {
            let metafileJsStr = createUtf8ForJs(globalThis, metafile)
            let metafileMdStr = if (let Some(md) <- build.metafileMarkdown) {
                createUtf8ForJs(globalThis, md)
            } else {
                JsValue.undefined
            }
            setupLazyMetafile(globalThis, buildOutput, metafileJsStr, metafileMdStr)
        }

        var didHandleCallbacks: Bool = false
        if (let Some(plugin) <- pluginsMut(this)) {
            didHandleCallbacks = runOnEndCallbacks(
                globalThis, plugin, promise, buildOutput, None,
            )
        }

        if (!didHandleCallbacks) {
            promise.resolve(globalThis, buildOutput)
        }
    }
}

// ============================================================================
// CompletionStruct 实现 — BundleThread 需要的字段访问器
// 对应 Bun: CompletionStruct impl for JSBundleCompletionTask
// ============================================================================

/// 配置 bundler — post-init 阶段
/// 对应 Bun: JSBundleCompletionTask.configureBundler
public func configureBundler(
    task!: JSBundleCompletionTask,
    transpiler!: Transpiler,
    bump!: Arena
): Bool {
    let config = task.config

    transpiler.options.env.behavior = config.envBehavior
    transpiler.options.env.prefix = config.envPrefix
    transpiler.options.bundlerFeatureFlags = Some(config.features.clone())

    if (config.forceNodeEnv != ForceNodeEnv.unspecified) {
        transpiler.options.forceNodeEnv = config.forceNodeEnv
    }

    transpiler.options.entryPoints = config.entryPoints.keys()
    transpiler.options.outputFormat = config.format
    transpiler.options.bytecode = config.bytecode
    transpiler.options.compile = config.compile.isSome()

    // 编译模式的 public_path
    if (let Some(compileOpts) <- config.compile) {
        transpiler.options.publicPath = targetBasePublicPath(compileOpts.compileTarget.os, "root/")
    } else {
        transpiler.options.publicPath = config.publicPath
    }

    transpiler.options.outputDir = config.outdir
    transpiler.options.rootDir = config.rootdir
    transpiler.options.minifySyntax = config.minify.syntax
    transpiler.options.minifyWhitespace = config.minify.whitespace
    transpiler.options.minifyIdentifiers = config.minify.identifiers
    transpiler.options.keepNames = config.minify.keepNames
    transpiler.options.inlining = config.minify.syntax
    transpiler.options.sourceMap = config.sourceMap
    transpiler.options.packages = config.packages
    transpiler.options.codeSplitting = config.codeSplitting
    transpiler.options.emitDceAnnotations = config.emitDceAnnotations ?? (!config.minify.whitespace)
    transpiler.options.ignoreDceAnnotations = config.ignoreDceAnnotations
    transpiler.options.cssChunking = config.cssChunking

    transpiler.options.banner = config.banner
    transpiler.options.footer = config.footer
    transpiler.options.reactFastRefresh = config.reactFastRefresh
    transpiler.options.metafile = config.metafile

    if (transpiler.options.compile) {
        transpiler.options.emitDceAnnotations = false
    }

    transpiler.configureLinker()
    transpiler.configureDefines()

    if (!transpiler.options.production) {
        transpiler.options.conditions.appendSlice(["development"])
    }

    transpiler.syncResolverOpts()
    return true
}

/// 在 bundle 线程上完成
public func completeOnBundleThread(task!: JSBundleCompletionTask): Unit {
    task.jscEventLoop.enqueueTaskConcurrent(
        ConcurrentTask.create(task.task.task()),
    )
}

/// 创建和配置 Transpiler
/// 对应 Bun: JSBundleCompletionTask.create_and_configure_transpiler
public func createAndConfigureTranspiler(
    task!: JSBundleCompletionTask,
    bump!: Arena
): ?Transpiler {
    let config = task.config
    let opts = TransformOptions(
        define: if (config.define.count() > 0) {
            Some(StringMap(keys: config.define.keys(), values: config.define.values()))
        } else {
            None
        },
        entryPoints: config.entryPoints.keys(),
        target: Some(config.target.toApi()),
        external: config.external.keys(),
        conditions: config.conditions.keys(),
        ignoreDceAnnotations: config.ignoreDceAnnotations,
        drop: config.drop.keys(),
        jsx: Some(config.jsx.clone()),
    )

    let t = Transpiler(bump, task.log, opts, Some(task.env))
    if (t.isErr()) {
        return None
    }
    let transpiler = bump.alloc(t.unwrap())

    configureBundler(task, transpiler, bump)
    return transpiler
}

/// 初始化并运行
/// 对应 Bun: JSBundleCompletionTask.init_and_run
public func initAndRun(
    task!: JSBundleCompletionTask,
    transpiler!: Transpiler,
    bump!: Arena,
    threadPool!: ?ThreadPool
): Bool {
    // 创建 BundleV2 并运行
    let bv2 = BundleV2(transpiler, None, bump, None, false, threadPool)
    if (bv2.isErr()) {
        return false
    }

    let bundleV2 = bv2.unwrap()
    bundleV2.plugins = task.plugins
    bundleV2.completion = Some(task.asJsBundleCompletionTask())
    bundleV2.fileMap = task.fileMap()

    task.transpiler = bundleV2

    let entryPoints = task.config.entryPoints.keys()
    let run = bundleV2.runFromJsInNewThread(entryPoints)

    match (run) {
        case ok(build) =>
            task.result = BundleV2Result.value(build)
            bundleV2.deinitWithoutFreeingArena()
            true
        case err(err) =>
            bundleV2.linker.sourceMaps.lineOffsetWaitGroup.wait()
            bundleV2.linker.sourceMaps.quotedContentsWaitGroup.wait()
            bundleV2.deinitWithoutFreeingArena()
            false
    }
}
