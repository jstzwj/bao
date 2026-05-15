// 严格翻译自: src/bundler_jsc/JSBundleCompletionTask.zig
//! `JSBundleCompletionTask` and the JS-facing entrypoints for `Bun.build()`.
package bao_bundler_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// JSBundleCompletionTask - JS Bundle 完成任务
// 严格翻译自: src/bundler_jsc/JSBundleCompletionTask.zig:8-200+
// ============================================================================

/// JS Bundle 完成任务 - 严格对应 Bun JSBundleCompletionTask
public class JSBundleCompletionTask {
    public var refCount: RefCount
    public var config: JSBundlerConfig
    public var jscEventLoop: EventLoop
    public var task: AnyTask
    public var globalThis: JSGlobalObject
    public var promise: JSPromiseStrong
    public var pollRef: AsyncKeepAlive
    public var env: DotEnvLoader
    public var log: LoggerLog
    public var cancelled: Bool
    public var htmlBuildTask: ?HTMLBundleRoute
    public var result: BundleV2Result
    public var next: ?JSBundleCompletionTask
    public var transpiler: Transpiler
    public var plugins: ?JSBundlerPlugin
    public var startedAtNs: UInt64

    public init() {
        refCount = RefCount()
        config = JSBundlerConfig()
        jscEventLoop = EventLoop()
        task = AnyTask()
        globalThis = JSGlobalObject()
        promise = JSPromiseStrong()
        pollRef = AsyncKeepAlive()
        env = DotEnvLoader()
        log = LoggerLog()
        cancelled = false
        htmlBuildTask = None
        result = BundleV2Result.pending()
        next = None
        startedAtNs = 0
    }

    /// 创建并调度完成任务的引用计数操作
    public func ref(): Unit {
        refCount.ref()
    }

    public func deref(): Unit {
        refCount.deref()
    }

    /// 配置 bundler - 严格对应 Bun configureBundler
    public func configureBundler(transpiler: Transpiler, alloc: Allocator): Unit {
        let config = this.config

        transpiler.configure(config, alloc, env, log)

        // 设置 JSX 配置
        transpiler.options.jsx = JSXPragma(
            factory: if (config.jsx.factory.size > 0) JSXPragma.memberListToComponentsIfDifferent(alloc, [], config.jsx.factory) else JSXPragma.Defaults.Factory,
            fragment: if (config.jsx.fragment.size > 0) JSXPragma.memberListToComponentsIfDifferent(alloc, [], config.jsx.jsxFragment) else JSXPragma.Defaults.Fragment,
            runtime: config.jsx.runtime,
            development: config.jsx.development,
            packageName: if (config.jsx.importSource.size > 0) config.jsx.importSource else "react",
            classicImportSource: if (config.jsx.importSource.size > 0) config.jsx.importSource else "react",
            sideEffects: config.jsx.sideEffects,
            parse: true,
            importSource: ImportSourceConfig(
                development: if (config.jsx.importSource.size > 0) "${config.jsx.importSource}/jsx-dev-runtime" else "react/jsx-dev-runtime",
                production: if (config.jsx.importSource.size > 0) "${config.jsx.importSource}/jsx-runtime" else "react/jsx-runtime"
            )
        )

        transpiler.options.noMacros = config.noMacros
        transpiler.options.loaders = options.loadersFromTransformOptions(alloc, config.loaders, config.target)
        transpiler.options.entryNaming = config.names.entryPoint.data
        transpiler.options.chunkNaming = config.names.chunk.data
        transpiler.options.assetNaming = config.names.asset.data
        transpiler.options.outputFormat = config.format
        transpiler.options.bytecode = config.bytecode
        transpiler.options.compile = config.compile != None

        if (let compileOpts = config.compile) {
            let basePublicPath = StandaloneModuleGraph.targetBasePublicPath(compileOpts.compileTarget.os, "root/")
            transpiler.options.publicPath = basePublicPath
        } else {
            transpiler.options.publicPath = config.publicPath.list.items
        }

        transpiler.options.outputDir = config.outdir.slice()
        transpiler.options.rootDir = config.rootdir.slice()
        transpiler.options.minifySyntax = config.minify.syntax
        transpiler.options.minifyWhitespace = config.minify.whitespace
        transpiler.options.minifyIdentifiers = config.minify.identifiers
        transpiler.options.keepNames = config.minify.keepNames
        transpiler.options.inlining = config.minify.syntax
        transpiler.options.sourceMap = config.sourceMap
        transpiler.options.packages = config.packages
        transpiler.options.codeSplitting = config.codeSplitting
        transpiler.options.emitDceAnnotations = config.emitDceAnnotations ?? !config.minify.whitespace
        transpiler.options.ignoreDceAnnotations = config.ignoreDceAnnotations
        transpiler.options.cssChunking = config.cssChunking
        transpiler.options.banner = config.banner.slice()
        transpiler.options.footer = config.footer.slice()
        transpiler.options.reactFastRefresh = config.reactFastRefresh
    }
}

/// 创建并调度完成事件 - 严格对应 Bun createAndScheduleCompletionTask
public func createAndScheduleCompletionTask(
    config: JSBundlerConfig,
    plugins: ?JSBundlerPlugin,
    globalThis: JSGlobalObject,
    eventLoop: EventLoop,
    allocator: Allocator
): JSBundleCompletionTask {
    let completion = JSBundleCompletionTask()
    completion.config = config
    completion.jscEventLoop = eventLoop
    completion.globalThis = globalThis
    completion.env = globalThis.bunVM().transpiler.env
    completion.plugins = plugins
    completion.log = LoggerLog(Allocator.default)

    if (let plugin = plugins) {
        plugin.setConfig(completion)
    }

    JSBundleThread.singleton.enqueue(completion)
    completion.pollRef.ref(globalThis.bunVM())

    return completion
}

/// 从 JavaScript 生成 bundle - 严格对应 Bun generateFromJavaScript
public func generateFromJavaScript(
    config: JSBundlerConfig,
    plugins: ?JSBundlerPlugin,
    globalThis: JSGlobalObject,
    eventLoop: EventLoop,
    alloc: Allocator
): JSValue {
    let completion = createAndScheduleCompletionTask(config, plugins, globalThis, eventLoop, alloc)
    completion.promise = JSPromiseStrong(globalThis)
    return completion.promise.value()
}
