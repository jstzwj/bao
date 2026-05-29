// 严格翻译自: src/runtime/bake/bake_body.rs
// Bake 是 Bun 用于构建客户端+服务器 Web 应用的工具包。
// 它结合了 Bun.build 和 Bun.serve，提供热重载开发服务器、服务器组件和其他集成。
// Bake 不是框架本身，而是框架构建的工具。

package bao_runtime.bake

import bao_bun_alloc.Allocator
import bao_bundler.Define
import bao_bundler.DefineData
import bao_bundler.Log
import bao_bundler.Source
import bao_bundler.Transpiler
import bao_bundler.Plugin
import bao_bundler.BundleV2
import bao_bundler.Arena
import bao_bundler.Resolver
import bao_bundler.SourceMapOption
import bao_bundler.ResolveResultUnion
import bao_bundler.Target
import bao_bundler.OutputFormat
import bao_collections.*
import bao_core.ArenaAllocator
import bao_core.Output
import bao_jsc.JsValue
import bao_jsc.JSGlobalObject
import bao_jsc.JsObject
import bao_jsc.JsString
import bao_jsc.JsArray
import bao_jsc.JsFunction
import bao_jsc.JsError
import bao_jsc.Strong
import bao_jsc.ZigStringSlice
import bao_jsc.CallFrame
import bao_jsc.HostFunction
import bao_jsc.JSFunction
import bao_options.LoaderMap
import bao_options.DotEnvBehavior
import bao_options.SourceMapMode
import bao_path.*

// ============================================================================
// 辅助函数 — JsValue 属性读取
// 对应 Bun: bake_body.rs 中的 get_optional_slice / get_boolean_strict 等
// ============================================================================

/// JsValue.getOptional(ZigString.Slice, ..) — 本地 shim。
/// 对于缺失/null/undefined 返回 None。
public func getOptionalSlice(
    target: JsValue,
    global: JSGlobalObject,
    property: String
): ?ZigStringSlice {
    if (let Some(v) <- target.get(global.globalThis, property)) {
        if (v.isUndefinedOrNull()) {
            return None
        }
        return ZigStringSlice(v.toSlice(global.globalThis))
    }
    return None
}

/// JsValue.getBooleanStrict — 本地 shim。
/// 仅当值是布尔类型时返回 Some。
public func getBooleanStrict(
    target: JsValue,
    global: JSGlobalObject,
    property: String
): ?Bool {
    if (let Some(v) <- target.get(global.globalThis, property)) {
        if (v.isBoolean()) {
            return Some(v.asBoolean())
        }
    }
    return None
}

/// JsValue.getBooleanLoose — 本地 shim。
/// 对于非 undefined/null 值进行宽松布尔转换。
public func getBooleanLoose(
    target: JsValue,
    global: JSGlobalObject,
    property: String
): ?Bool {
    if (let Some(v) <- target.get(global.globalThis, property)) {
        if (v.isUndefinedOrNull()) {
            return None
        }
        return Some(v.toBoolean())
    }
    return None
}

/// JsValue.getOptional(JsValue, ..) — 本地 shim: 过滤 undefined/null。
public func getOptionalValue(
    target: JsValue,
    global: JSGlobalObject,
    property: String
): ?JsValue {
    if (let Some(v) <- target.get(global.globalThis, property)) {
        if (v.isUndefinedOrNull()) {
            return None
        }
        return Some(v)
    }
    return None
}

/// JsValue.getFunction — 本地 shim。
/// 仅当值是可调用函数时返回 Some。
public func getFunction(
    target: JsValue,
    global: JSGlobalObject,
    property: String
): ?JsValue {
    if (let Some(v) <- target.get(global.globalThis, property)) {
        if (v.isCallable()) {
            return Some(v)
        }
    }
    return None
}

/// 将 bun_core.Error 转换为 JS 异常。
/// 对应 Zig globalThis.throwError(err, msg)。
public func throwCoreError(global: JSGlobalObject, e: Error, ctx: String): JsError {
    global.throwError(ctx + ": " + e.message)
    return JsError("", ctx + ": " + e.message)
}

/// 擦除 arena 支持的切片的生命周期。
/// Phase-A 约定: UserOptions.arena 比所有借用者存活更久。
public func arenaErase<T>(r: T): T {
    // SAFETY: arena-backed; UserOptions 拥有 bump 并最后被丢弃。
    // 仅在 bake from_js 自引用模式中使用。
    return r
}

/// arena.dupeZ(u8, bytes) — 将 bytes + 尾部 NUL 复制到 bump arena。
/// 返回 arena 拥有的字符串。
public func arenaDupeZ(arena: Arena, bytes: String): String {
    return bytes + "\0"
}

// ============================================================================
// UserOptions — 从 JS 配置构建
// 对应 Bun: bake_body.rs UserOptions::from_js
// ============================================================================

/// UserOptions 的扩展方法 — 从 JS 值构建配置
public func userOptionsFromJs(config: JsValue, global: JSGlobalObject): ?UserOptions {
    let arena = Arena()

    var allocations = StringRefList.empty
    var bundlerOptions = SplitBundlerOptions.empty

    // 如果配置不是对象，检查是否为字符串简写
    if (!config.isObject()) {
        if (config.isString()) {
            let bunstr = config.toString()
            let utf8String = bunstr.toString()

            if (StringsRef.eql(utf8String, "react")) {
                let root = arenaDupeZ(arena, getCwd())

                let fw = frameworkReact(arena)

                return UserOptions(
                    ArenaAllocator(),
                    allocations,
                    root,
                    fw,
                    bundlerOptions,
                )
            }
        }
        return None
    }

    // 解析 bundlerOptions
    if (let Some(jsOptions) <- getOptionalValue(config, global, "bundlerOptions")) {
        if (let Some(serverOptions) <- getOptionalValue(jsOptions, global, "server")) {
            bundlerOptions.server = buildConfigSubsetFromJs(global, serverOptions)
        }
        if (let Some(clientOptions) <- getOptionalValue(jsOptions, global, "client")) {
            bundlerOptions.client = buildConfigSubsetFromJs(global, clientOptions)
        }
        if (let Some(ssrOptions) <- getOptionalValue(jsOptions, global, "ssr")) {
            bundlerOptions.ssr = buildConfigSubsetFromJs(global, ssrOptions)
        }
    }

    // 解析 framework
    let frameworkValOpt = config.get(global.globalThis, "framework")
    if (frameworkValOpt.isNone()) {
        return None
    }
    let frameworkVal = frameworkValOpt.getOrThrow()
    if (frameworkVal.isUndefinedOrNull()) {
        return None
    }

    let frameworkOpt = frameworkFromJs(frameworkVal, global, allocations, bundlerOptions, arena)
    if (frameworkOpt.isNone()) {
        return None
    }

    // 解析 root
    var root: String = ""
    if (let Some(slice) <- getOptionalSlice(config, global, "root")) {
        root = allocations.track(slice)
    } else {
        root = arenaDupeZ(arena, getCwd())
    }

    // 解析 plugins
    if (let Some(pluginArray) <- config.get(global.globalThis, "plugins")) {
        if (!pluginArray.isUndefinedOrNull()) {
            parsePluginArray(bundlerOptions, pluginArray, global)
        }
    }

    let rootZ = arenaDupeZ(arena, root)

    return UserOptions(
        ArenaAllocator(),
        allocations,
        rootZ,
        frameworkOpt.getOrThrow(),
        bundlerOptions,
    )
}

// ============================================================================
// SplitBundlerOptions — 插件解析
// 对应 Bun: bake_body.rs SplitBundlerOptions::parse_plugin_array
// ============================================================================

/// 解析插件数组
public func parsePluginArray(
    opts: SplitBundlerOptions,
    pluginArray: JsValue,
    global: JSGlobalObject
): Bool {
    // 创建 Plugin 并在遍历前分配
    if (opts.plugin.isNone()) {
        opts.plugin = Plugin("bake-plugin")
    }

    let emptyObject = JsValue.createEmptyObject(global.globalThis, 0)
    var iter = pluginArray.arrayIterator(global.globalThis)

    while (let Some(pluginConfig) <- iter.next()) {
        if (!pluginConfig.isObject()) {
            return false
        }

        // 验证 name
        if (let Some(slice) <- getOptionalSlice(pluginConfig, global, "name")) {
            if (slice.slice().isEmpty()) {
                return false
            }
        } else {
            return false
        }

        // 验证 setup 函数
        let function = getFunction(pluginConfig, global, "setup")
        if (function.isNone()) {
            return false
        }

        // 添加插件 (stub implementation)
        // opts.plugin.getOrThrow().hooks.append(...)
    }
    return true
}

// ============================================================================
// BuildConfigSubset — 从 JS 值构建
// 对应 Bun: bake_body.rs BuildConfigSubset::from_js
// ============================================================================

/// 从 JS 值构建 BuildConfigSubset
public func buildConfigSubsetFromJs(global: JSGlobalObject, jsOptions: JsValue): BuildConfigSubset {
    var options = BuildConfigSubset()

    // 解析 sourcemap
    if (let Some(val) <- getOptionalValue(jsOptions, global, "sourcemap")) {
        if (let Some(sourcemap) <- sourceMapModeFromJs(global, val)) {
            options.source_map = sourcemap
        }
    }

    // 解析 minify
    if (let Some(minifyOptions) <- getOptionalValue(jsOptions, global, "minify")) {
        if (minifyOptions.isBoolean() && minifyOptions.asBoolean()) {
            options.minify_syntax = Some(minifyOptions.asBoolean())
            options.minify_identifiers = Some(minifyOptions.asBoolean())
            options.minify_whitespace = Some(minifyOptions.asBoolean())
        } else {
            if (let Some(value) <- getBooleanLoose(minifyOptions, global, "whitespace")) {
                options.minify_whitespace = Some(value)
            }
            if (let Some(value) <- getBooleanLoose(minifyOptions, global, "syntax")) {
                options.minify_syntax = Some(value)
            }
            if (let Some(value) <- getBooleanLoose(minifyOptions, global, "identifiers")) {
                options.minify_identifiers = Some(value)
            }
        }
    }

    return options
}

// ============================================================================
// Framework — 扩展方法
// 对应 Bun: bake_body.rs Framework::{react, auto, none, from_js, resolve, ...}
// ============================================================================

/// Framework React 预设。
/// Bun 提供对 React 作为框架的内置支持。依赖外部提供的 React。
public func frameworkReact(arena: Arena): Framework {
    var fsr = FileSystemRouterType()
    fsr.root = "pages"
    fsr.prefix = "/"
    fsr.entry_client = Some("bun-framework-react/client.tsx")
    fsr.entry_server = "bun-framework-react/server.tsx"
    fsr.ignore_underscores = true
    fsr.ignore_dirs = [".git", "node_modules"]
    fsr.extensions = [".tsx", ".jsx"]
    fsr.style = FrameworkRouterStyle.nextjs_pages
    fsr.allow_layouts = true

    var fw = Framework(true, [fsr])
    var sc = ServerComponents()
    sc.separate_ssr_graph = true
    sc.server_runtime_import = "react-server-dom-bun/server"
    fw.serverComponents = Some(sc)
    fw.reactFastRefresh = Some(ReactFastRefresh())
    return fw
}

/// 读取 codegen 嵌入资源。
/// 对应 Bun: bun.runtimeEmbedFile(.codegen, path) / runtime_embed_file!(Codegen, path)。
public func runtimeEmbedFileCodegen(path: String): String {
    return RuntimeEmbedFile.codegen(path)
}

/// Framework 自动检测。
/// 默认不需要任何包或配置。
/// - 如果安装了 react-refresh，启用 react 快速刷新。
/// - 否则，如果安装了 react，使用捆绑的 react-refresh 副本。
/// - 如果提供了任何文件系统路由器类型，使用上述 react 配置。
public func frameworkAuto(
    arena: Arena,
    resolver: Resolver,
    fileSystemRouterTypes: Array<FileSystemRouterType>
): Framework {
    var fw = frameworkNone()

    if (!fileSystemRouterTypes.isEmpty()) {
        fw = frameworkReact(arena)
        fw.fileSystemRouterTypes = fileSystemRouterTypes
    }

    if (let Some(rfr) <- resolveOrNull(resolver, "react-refresh/runtime")) {
        var rfrObj = ReactFastRefresh()
        rfrObj.import_source = rfr
        fw.reactFastRefresh = Some(rfrObj)
    } else if (resolveOrNull(resolver, "react").isSome()) {
        var rfrObj2 = ReactFastRefresh()
        rfrObj2.import_source = "react-refresh/runtime/index.js"
        fw.reactFastRefresh = Some(rfrObj2)
        fw.built_in_modules.put(
            "react-refresh/runtime/index.js",
            BuiltInModule.code(runtimeEmbedFileCodegen("node-fallbacks/react-refresh.js")),
        )
    }

    return fw
}

/// 无框架配置
public func frameworkNone(): Framework {
    return Framework(false, [])
}

/// Framework.clone()
public func frameworkClone(self: Framework): Framework {
    return Framework(self.is_built_in_react, self.fileSystemRouterTypes)
}

/// 从 JS 值解析 Framework
public func frameworkFromJs(
    opts: JsValue,
    global: JSGlobalObject,
    refs: StringRefList,
    bundlerOptions: SplitBundlerOptions,
    arena: Arena
): ?Framework {
    // 字符串简写
    if (opts.isString()) {
        let str = opts.toString()

        if (str == ("react-server-components")) {
            Output.warn("deprecation notice: 'react-server-components' will be renamed to 'react'")
            return frameworkReact(arena)
        }

        if (str == ("react")) {
            return frameworkReact(arena)
        }
    }

    if (!opts.isObject()) {
        return None
    }

    // 解析 reactFastRefresh
    var reactFastRefresh: ?ReactFastRefresh = Option<ReactFastRefresh>.None
    if (let Some(rfr) <- opts.get(global.globalThis, "reactFastRefresh")) {
        if (!rfr.isUndefinedOrNull()) {
            if (rfr == JsValue.jsTrue()) {
                reactFastRefresh = Some(ReactFastRefresh())
            } else if (rfr.isObject()) {
                if (let Some(propVal) <- rfr.get(global.globalThis, "importSource")) {
                    let str = propVal.toString()
                    var rfrObj3 = ReactFastRefresh()
                    rfrObj3.import_source = refs.track(ZigStringSlice(str.toString()))
                    reactFastRefresh = Some(rfrObj3)
                }
            }
        }
    }

    // 解析 serverComponents
    var serverComponents: ?ServerComponents = Option<ServerComponents>.None
    if (let Some(sc) <- opts.get(global.globalThis, "serverComponents")) {
        if (!sc.isUndefinedOrNull() && sc != JsValue.jsFalse()) {
            if (sc.isObject()) {
                var separateSsrGraph: Bool = false
                if (let Some(propVal) <- getOptionalValue(sc, global, "separateSSRGraph")) {
                    separateSsrGraph = (propVal == JsValue.jsTrue())
                }

                var serverRuntimeImport: String = ""
                if (let Some(slice) <- getOptionalSlice(sc, global, "serverRuntimeImportSource")) {
                    serverRuntimeImport = refs.track(slice)
                }

                var serverRegisterClientReference: String = "registerClientReference"
                if (let Some(slice) <- getOptionalSlice(sc, global, "serverRegisterClientReferenceExport")) {
                    serverRegisterClientReference = refs.track(slice)
                }

                var sc = ServerComponents()
                sc.separate_ssr_graph = separateSsrGraph
                sc.server_runtime_import = serverRuntimeImport
                sc.server_register_client_reference = serverRegisterClientReference
                serverComponents = Some(sc)
            }
        }
    }

    // 解析 builtInModules
    var builtInModules = StringArrayHashMap<BuiltInModule>()
    if (let Some(array) <- opts.getArray(global.globalThis, "builtInModules")) {
        let len = array.getLength(global.globalThis)
        var it = array.arrayIterator(global.globalThis)
        var i: Int64 = 0
        while (let Some(fileItem) <- it.next()) {
            if (!fileItem.isObject()) {
                return None
            }

            let pathValOpt = getOptionalString(fileItem, global, "import", refs, arena)
            if (pathValOpt.isNone()) {
                return None
            }
            let pathVal = pathValOpt.getOrThrow()

            if (let Some(strVal) <- getOptionalString(fileItem, global, "path", refs, arena)) {
                builtInModules.put(pathVal, BuiltInModule.`import`(strVal))
            } else if (let Some(strVal) <- getOptionalString(fileItem, global, "code", refs, arena)) {
                builtInModules.put(pathVal, BuiltInModule.code(strVal))
            } else {
                return None
            }
            i++
        }
    }

    // 解析 fileSystemRouterTypes
    var fileSystemRouterTypes = ArrayList<FileSystemRouterType>()
    if (let Some(array) <- opts.getArray(global.globalThis, "fileSystemRouterTypes")) {
        let len = array.getLength(global.globalThis)
        if (len > 256) {
            return None
        }

        var it = array.arrayIterator(global.globalThis)
        var i: Int64 = 0
        while (let Some(fsrOpts) <- it.next()) {
            let rootOpt = getOptionalString(fsrOpts, global, "root", refs, arena)
            if (rootOpt.isNone()) {
                return None
            }
            let root = rootOpt.getOrThrow()

            let serverEntryPointOpt = getOptionalString(fsrOpts, global, "serverEntryPoint", refs, arena)
            if (serverEntryPointOpt.isNone()) {
                return None
            }
            let serverEntryPoint = serverEntryPointOpt.getOrThrow()

            let clientEntryPoint = getOptionalString(fsrOpts, global, "clientEntryPoint", refs, arena)
            let prefix = getOptionalString(fsrOpts, global, "prefix", refs, arena) ?? "/"
            let ignoreUnderscores = getBooleanStrict(fsrOpts, global, "ignoreUnderscores") ?? false
            let layouts = getBooleanStrict(fsrOpts, global, "layouts") ?? false

            let style = styleFromJs(fsrOpts.get(global.globalThis, "style").getOrThrow(), global)
            if (style.isNone()) {
                return None
            }

            // 解析 extensions
            var extensions: Array<String> = [".jsx", ".tsx", ".js", ".ts", ".cjs", ".cts", ".mjs", ".mts"]
            if (let Some(extsJs) <- fsrOpts.get(global.globalThis, "extensions")) {
                if (extsJs.isString()) {
                    let slice = extsJs.toSlice(global.globalThis)
                    if (slice == "*") {
                        extensions = []
                    }
                } else if (extsJs.isArray()) {
                    var extList = ArrayList<String>()
                    var it2 = extsJs.arrayIterator(global.globalThis)
                    while (let Some(arrayItem) <- it2.next()) {
                        var ext = refs.track(ZigStringSlice(arrayItem.toSlice(global.globalThis)))
                        if (ext == "*") {
                            return None
                        }
                        if (ext.isEmpty()) {
                            return None
                        }
                        if (!ext.startsWith(".")) {
                            ext = "." + ext
                        }
                        extList.append(ext)
                    }
                    let extListFrozen = extList
                    extensions = Array<String>(extListFrozen.size, { i => extListFrozen[i] })
                }
            }

            // 解析 ignoreDirs
            var ignoreDirs: Array<String> = [".git", "node_modules"]
            if (let Some(extsJs) <- fsrOpts.get(global.globalThis, "ignoreDirs")) {
                if (extsJs.isArray()) {
                    var dirList = ArrayList<String>()
                    var it2 = array.arrayIterator(global.globalThis)
                    while (let Some(arrayItem) <- it2.next()) {
                        dirList.append(refs.track(ZigStringSlice(arrayItem.toSlice(global.globalThis))))
                    }
                    let dirListFrozen = dirList
                    ignoreDirs = Array<String>(dirListFrozen.size, { i => dirListFrozen[i] })
                }
            }

            var fsrt = FileSystemRouterType()
            fsrt.root = root
            fsrt.prefix = prefix
            fsrt.style = style.getOrThrow()
            fsrt.entry_server = serverEntryPoint
            fsrt.entry_client = clientEntryPoint
            fsrt.ignore_underscores = ignoreUnderscores
            fsrt.extensions = extensions
            fsrt.ignore_dirs = ignoreDirs
            fsrt.allow_layouts = layouts
            fileSystemRouterTypes.append(fsrt)
            i++
        }
    }

    // 解析 plugins
    if (let Some(pluginArray) <- getOptionalValue(opts, global, "plugins")) {
        parsePluginArray(bundlerOptions, pluginArray, global)
    }

    let fsrtFrozen = fileSystemRouterTypes
    var fw = Framework(false, Array<FileSystemRouterType>(fsrtFrozen.size, { i => fsrtFrozen[i] }))
    fw.reactFastRefresh = reactFastRefresh
    fw.serverComponents = serverComponents
    return fw
}

/// 给定 Framework 配置，返回所有路径已解析的另一个 Framework。
/// 新内存分配到提供的 arena。
/// 所有解析错误将在返回 error.ModuleNotFound 之前发生。
public func frameworkResolve(
    self: Framework,
    server: Resolver,
    client: Resolver,
    arena: Arena
): ?Framework {
    var clone = frameworkClone(self)
    var hadErrors: Bool = false

    if (let Some(rfr) <- clone.reactFastRefresh) {
        hadErrors = resolveHelper(self, client, rfr.import_source, hadErrors, "react refresh runtime")
    }

    if (let Some(sc) <- clone.serverComponents) {
        hadErrors = resolveHelper(self, server, sc.server_runtime_import, hadErrors, "server components runtime")
    }

    for (fsr in clone.fileSystemRouterTypes) {
        let topLevelDir = FileSystem.get().topLevelDir
        fsr.root = joinAbsStringZ(topLevelDir, fsr.root)
        if (let Some(entryClient) <- fsr.entry_client) {
            hadErrors = resolveHelper(self, client, entryClient, hadErrors, "client side entrypoint")
        }
        hadErrors = resolveHelper(self, client, fsr.entry_server, hadErrors, "server side entrypoint")
    }

    if (hadErrors) {
        return None
    }

    return clone
}

/// 解析辅助函数
func resolveHelper(
    fw: Framework,
    r: Resolver,
    path: String,
    hadErrors: Bool,
    desc: String
): Bool {
    var resultPath = path
    var errors = hadErrors
    if (let Some(module) <- fw.built_in_modules.get(resultPath)) {
        match (module) {
            case BuiltInModule.`import`(p) => resultPath = p
            case BuiltInModule.code(_) => ()
        }
        return errors
    }

    let topLevelDir = FileSystem.get().topLevelDir
    let resolveResult = r.resolve(topLevelDir, resultPath)
    if (resolveResult.isNone()) {
        errors = true
    } else {
        resultPath = resolveResult.getOrThrow()
    }
    return errors
}

/// 解析模块或返回 null
func resolveOrNull(r: Resolver, path: String): ?String {
    let topLevelDir = FileSystem.get().topLevelDir
    let resolveResult = r.resolve(topLevelDir, path)
    if (resolveResult.isSome()) {
        return resolveResult
    }
    return None
}

/// 从 JS 值获取可选字符串
func getOptionalString(
    target: JsValue,
    global: JSGlobalObject,
    property: String,
    allocations: StringRefList,
    arena: Arena
): ?String {
    if (let Some(value) <- target.get(global.globalThis, property)) {
        if (value.isUndefinedOrNull()) {
            return None
        }
        let str = value.toString()
        return Some(allocations.track(ZigStringSlice(str)))
    }
    return None
}

/// 从 JS 值解析 FrameworkRouter.Style
func styleFromJs(value: JsValue, global: JSGlobalObject): ?FrameworkRouterStyle {
    if (value.isUndefinedOrNull()) {
        return None
    }
    return FrameworkRouterStyle.fromJs(value, global)
}

// ============================================================================
// Framework — initTranspiler / initTranspilerWithOptions
// 对应 Bun: bake_body.rs Framework::init_transpiler / init_transpiler_with_options
// ============================================================================

/// 初始化 Transpiler 用于 Bake 框架。
/// 使用给定的 Mode 和 Graph 配置 bundler 选项。
public func frameworkInitTranspiler(
    fw: Framework,
    arena: Arena,
    log: Log,
    mode: Mode,
    renderer: Graph,
    bundlerOptions: BuildConfigSubset
): ?Transpiler {
    let sourceMap: SourceMapOption = match (mode) {
        case development => SourceMapOption.External
        case _ => SourceMapOption.None
    }

    return frameworkInitTranspilerWithOptions(
        fw, arena, log, mode, renderer, bundlerOptions,
        sourceMap, Option<Bool>.None, Option<Bool>.None, Option<Bool>.None,
    )
}

/// 使用完整选项初始化 Transpiler。
/// 对应 Bun: bake_body.rs Framework::init_transpiler_with_options
public func frameworkInitTranspilerWithOptions(
    fw: Framework,
    arena: Arena,
    log: Log,
    mode: Mode,
    renderer: Graph,
    bundlerOptions: BuildConfigSubset,
    sourceMap: SourceMapOption,
    minifyWhitespace: ?Bool,
    minifySyntax: ?Bool,
    minifyIdentifiers: ?Bool
): ?Transpiler {
    let transpiler = Transpiler()
    // Stub implementation - full bundler options configuration is not yet available
    return transpiler
}

// ============================================================================
// 虚拟源文件
// 对应 Bun: bake_body.rs server_virtual_source / client_virtual_source
// ============================================================================

/// 服务器虚拟源
public func serverVirtualSource(): Source {
    return Source()
}

/// 客户端虚拟源
public func clientVirtualSource(): Source {
    return Source()
}

// ============================================================================
// sourceMapModeFromJs - 从 JS 值解析 SourceMap 模式
// 对应 Bun: bundler_jsc/source_map_mode_jsc.zig sourceMapModeFromJS
// ============================================================================

/// 从 JS 值解析 SourceMapMode
/// 保持 src/bundler_jsc/ 不包含 JSC 类型
public func sourceMapModeFromJs(global: JSGlobalObject, value: JsValue): ?SourceMapMode {
    if (value.isString()) {
        let str = value.toString()
        if (str == "none") {
            return SourceMapMode.None
        }
        if (str == "inline") {
            return SourceMapMode.Inline
        }
        if (str == "external") {
            return SourceMapMode.External
        }
        if (str == "linked") {
            return SourceMapMode.Linked
        }
    }
    return Option<SourceMapMode>.None
}

// ============================================================================
// addImportMetaDefines - 添加 import.meta.env 定义
// 对应 Bun: bake.zig addImportMetaDefines
// ============================================================================

/// 添加 import.meta.env 定义到 Define 映射。
/// 以下定义来自 Vite: https://vitejs.dev/guide/env-and-mode
/// 注意: 目前不支持混合模式 (production + hmr dev server)
/// 注意: 实际实现在 bake.cj 中，这里只是转发
public func addImportMetaDefines(
    arena: Arena,
    define: Define,
    mode: Mode,
    side: Side
): Unit {
    // import.meta.env.DEV
    define.insert("import.meta.env.DEV", DefineData.initBoolean(mode == Mode.development))
    // import.meta.env.PROD
    define.insert("import.meta.env.PROD", DefineData.initBoolean(mode != Mode.development))
    // import.meta.env.MODE
    let mode_str: String = match (mode) {
        case development => "development"
        case production_dynamic | production_static => "production"
    }
    define.insert("import.meta.env.MODE", DefineData.initStaticString(mode_str))
    // import.meta.env.SSR
    define.insert("import.meta.env.SSR", DefineData.initBoolean(side == Side.server))
    // import.meta.env.STATIC
    define.insert("import.meta.env.STATIC", DefineData.initBoolean(mode == Mode.production_static))
}
