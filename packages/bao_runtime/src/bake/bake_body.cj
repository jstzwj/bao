// 严格翻译自: src/runtime/bake/bake_body.rs
// Bake 是 Bun 用于构建客户端+服务器 Web 应用的工具包。
// 它结合了 Bun.build 和 Bun.serve，提供热重载开发服务器、服务器组件和其他集成。
// Bake 不是框架本身，而是框架构建的工具。

package bao_runtime.bake

import bao_bun_alloc.*
import bao_collections.*
import bao_core.*
import bao_jsc.*
import bao_options.schema as bun_schema
import bao_path.*

// ============================================================================
// 辅助函数 — JSValue 属性读取
// 对应 Bun: bake_body.rs 中的 get_optional_slice / get_boolean_strict 等
// ============================================================================

/// JSValue.getOptional(ZigString.Slice, ..) — 本地 shim。
/// 对于缺失/null/undefined 返回 None。
public func getOptionalSlice(
    target: JSValue,
    global: JSGlobalObject,
    property: String,
): ?ZigStringSlice {
    let v = target.get(global, property)
    if (v.isUndefinedOrNull()) {
        return None
    }
    return v.toSlice(global)
}

/// JSValue.getBooleanStrict — 本地 shim。
/// 仅当值是布尔类型时返回 Some。
public func getBooleanStrict(
    target: JSValue,
    global: JSGlobalObject,
    property: String,
): ?Bool {
    let v = target.get(global, property)
    if (v.isBoolean()) {
        return Some(v.asBoolean())
    }
    return None
}

/// JSValue.getBooleanLoose — 本地 shim。
/// 对于非 undefined/null 值进行宽松布尔转换。
public func getBooleanLoose(
    target: JSValue,
    global: JSGlobalObject,
    property: String,
): ?Bool {
    let v = target.get(global, property)
    if (v.isUndefinedOrNull()) {
        return None
    }
    return Some(v.toBoolean())
}

/// JSValue.getOptional(JSValue, ..) — 本地 shim: 过滤 undefined/null。
public func getOptionalValue(
    target: JSValue,
    global: JSGlobalObject,
    property: String,
): ?JSValue {
    let v = target.get(global, property)
    if (v.isUndefinedOrNull()) {
        return None
    }
    return Some(v)
}

/// JSValue.getFunction — 本地 shim。
/// 仅当值是可调用函数时返回 Some。
public func getFunction(
    target: JSValue,
    global: JSGlobalObject,
    property: String,
): ?JSValue {
    let v = target.get(global, property)
    if (v.isCallable()) {
        return Some(v)
    }
    return None
}

/// 将 bun_core.Error 转换为 JS 异常。
/// 对应 Zig globalThis.throwError(err, msg)。
public func throwCoreError(global: JSGlobalObject, e: Error, ctx: String): JsError {
    return global.throwError(e, ctx)
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
    return arena.dupe(bytes) + "\x00"
}

// ============================================================================
// UserOptions — 从 JS 配置构建
// 对应 Bun: bake_body.rs UserOptions::from_js
// ============================================================================

/// UserOptions 的扩展方法 — 从 JS 值构建配置
public func userOptionsFromJs(config: JSValue, global: JSGlobalObject): ?UserOptions {
    let arena = Arena.new()

    var allocations = StringRefList.empty
    var bundlerOptions = SplitBundlerOptions.empty

    // 如果配置不是对象，检查是否为字符串简写
    if (!config.isObject()) {
        if (config.isString()) {
            let bunstr = config.toBunString(global)
            let utf8String = bunstr.toUtf8()

            if (strings.eql(utf8String, "react")) {
                let root = arenaDupeZ(arena, getCwd())

                let framework = Framework.react(arena)
                if (framework.isErr()) {
                    return None
                }

                return UserOptions(
                    arena: arena,
                    allocations: allocations,
                    root: root,
                    framework: framework.unwrap(),
                    bundler_options: bundlerOptions,
                )
            }
        }
        return None
    }

    // 解析 bundlerOptions
    if (let Some(jsOptions) = getOptionalValue(config, global, "bundlerOptions")) {
        if (let Some(serverOptions) = getOptionalValue(jsOptions, global, "server")) {
            bundlerOptions.server = buildConfigSubsetFromJs(global, serverOptions)
        }
        if (let Some(clientOptions) = getOptionalValue(jsOptions, global, "client")) {
            bundlerOptions.client = buildConfigSubsetFromJs(global, clientOptions)
        }
        if (let Some(ssrOptions) = getOptionalValue(jsOptions, global, "ssr")) {
            bundlerOptions.ssr = buildConfigSubsetFromJs(global, ssrOptions)
        }
    }

    // 解析 framework
    let frameworkVal = config.get(global, "framework")
    if (frameworkVal.isUndefinedOrNull()) {
        return None
    }

    let framework = frameworkFromJs(frameworkVal, global, allocations, bundlerOptions, arena)
    if (framework.isErr()) {
        return None
    }

    // 解析 root
    var root: String = ""
    if (let Some(slice) = getOptionalSlice(config, global, "root")) {
        root = allocations.track(slice)
    } else {
        root = arenaDupeZ(arena, getCwd())
    }

    // 解析 plugins
    if (let Some(pluginArray) = config.get(global, "plugins")) {
        if (!pluginArray.isUndefinedOrNull()) {
            parsePluginArray(bundlerOptions, pluginArray, global)
        }
    }

    let rootZ = arenaDupeZ(arena, root)

    return UserOptions(
        arena: arena,
        allocations: allocations,
        root: rootZ,
        framework: framework.unwrap(),
        bundler_options: bundlerOptions,
    )
}

// ============================================================================
// SplitBundlerOptions — 插件解析
// 对应 Bun: bake_body.rs SplitBundlerOptions::parse_plugin_array
// ============================================================================

/// 解析插件数组
public func parsePluginArray(
    opts: SplitBundlerOptions,
    pluginArray: JSValue,
    global: JSGlobalObject,
): Bool {
    // 创建 Plugin 并在遍历前分配
    if (opts.plugin.isNone()) {
        opts.plugin = Plugin.create(global, BunPluginTarget.bun)
    }

    let emptyObject = JSValue.createEmptyObject(global, 0)
    var iter = pluginArray.arrayIterator(global)

    while (let Some(pluginConfig) = iter.next()) {
        if (!pluginConfig.isObject()) {
            return false
        }

        // 验证 name
        if (let Some(slice) = getOptionalSlice(pluginConfig, global, "name")) {
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

        // 添加插件
        let pluginResult = opts.plugin.addPlugin(
            function,
            emptyObject,
            JSValue.null,
            false,
            true,
        )

        if (let Some(promise) = pluginResult.asAnyPromise()) {
            promise.setHandled(global.vm())
            global.bunVm().waitForPromise(promise)
            match (promise.unwrap(global.vm(), PromiseUnwrapMode.markHandled)) {
                | pending => return false
                | fulfilled(_) => ()
                | rejected(err) => return false
            }
        }
    }
    return true
}

// ============================================================================
// BuildConfigSubset — 从 JS 值构建
// 对应 Bun: bake_body.rs BuildConfigSubset::from_js
// ============================================================================

/// 从 JS 值构建 BuildConfigSubset
public func buildConfigSubsetFromJs(global: JSGlobalObject, jsOptions: JSValue): BuildConfigSubset {
    var options = BuildConfigSubset()

    // 解析 sourcemap
    if (let Some(val) = getOptionalValue(jsOptions, global, "sourcemap")) {
        if (let Some(sourcemap) = sourceMapModeFromJs(global, val)) {
            options.source_map = sourcemap
        }
    }

    // 解析 minify
    if (let Some(minifyOptions) = getOptionalValue(jsOptions, global, "minify")) {
        if (minifyOptions.isBoolean() && minifyOptions.asBoolean()) {
            options.minify_syntax = Some(minifyOptions.asBoolean())
            options.minify_identifiers = Some(minifyOptions.asBoolean())
            options.minify_whitespace = Some(minifyOptions.asBoolean())
        } else {
            if (let Some(value) = getBooleanLoose(minifyOptions, global, "whitespace")) {
                options.minify_whitespace = Some(value)
            }
            if (let Some(value) = getBooleanLoose(minifyOptions, global, "syntax")) {
                options.minify_syntax = Some(value)
            }
            if (let Some(value) = getBooleanLoose(minifyOptions, global, "identifiers")) {
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
    return Framework(
        is_built_in_react: true,
        file_system_router_types: [
            FileSystemRouterType(
                root: "pages",
                prefix: "/",
                entry_client: Some("bun-framework-react/client.tsx"),
                entry_server: "bun-framework-react/server.tsx",
                ignore_underscores: true,
                ignore_dirs: [".git", "node_modules"],
                extensions: [".tsx", ".jsx"],
                style: FrameworkRouterStyle.nextjsPages,
                allow_layouts: true,
            ),
        ],
        server_components: Some(ServerComponents(
            separate_ssr_graph: true,
            server_runtime_import: "react-server-dom-bun/server",
        )),
        react_fast_refresh: Some(ReactFastRefresh()),
        built_in_modules: StringArrayHashMap<BuiltInModule>.fromEntries([
            ("bun-framework-react/client.tsx", BuiltInModule.code("// client placeholder")),
            ("bun-framework-react/server.tsx", BuiltInModule.code("// server placeholder")),
            ("bun-framework-react/ssr.tsx", BuiltInModule.code("// ssr placeholder")),
        ]),
    )
}

/// Framework 自动检测。
/// 默认不需要任何包或配置。
/// - 如果安装了 react-refresh，启用 react 快速刷新。
/// - 否则，如果安装了 react，使用捆绑的 react-refresh 副本。
/// - 如果提供了任何文件系统路由器类型，使用上述 react 配置。
public func frameworkAuto(
    arena: Arena,
    resolver: Resolver,
    fileSystemRouterTypes: Array<FileSystemRouterType>,
): Framework {
    var fw = frameworkNone()

    if (!fileSystemRouterTypes.isEmpty()) {
        fw = frameworkReact(arena)
        fw.file_system_router_types = fileSystemRouterTypes
    }

    if (let Some(rfr) = resolveOrNull(resolver, "react-refresh/runtime")) {
        fw.react_fast_refresh = Some(ReactFastRefresh(import_source: rfr))
    } else if (resolveOrNull(resolver, "react").isSome()) {
        fw.react_fast_refresh = Some(ReactFastRefresh(
            import_source: "react-refresh/runtime/index.js",
        ))
        fw.built_in_modules.put(
            "react-refresh/runtime/index.js",
            BuiltInModule.code("// react-refresh fallback placeholder"),
        )
    }

    return fw
}

/// 无框架配置
public func frameworkNone(): Framework {
    return Framework(
        is_built_in_react: false,
        file_system_router_types: [],
        server_components: None,
        react_fast_refresh: None,
        built_in_modules: StringArrayHashMap<BuiltInModule>(),
    )
}

/// Framework.clone() — 手动克隆，因为 ArrayHashMap 暴露了 fallible clone
public func frameworkClone(self: Framework): Framework {
    return Framework(
        is_built_in_react: self.is_built_in_react,
        file_system_router_types: self.file_system_router_types.clone(),
        server_components: self.server_components.clone(),
        react_fast_refresh: self.react_fast_refresh.clone(),
        built_in_modules: self.built_in_modules.clone(),
    )
}

/// 从 JS 值解析 Framework
public func frameworkFromJs(
    opts: JSValue,
    global: JSGlobalObject,
    refs: StringRefList,
    bundlerOptions: SplitBundlerOptions,
    arena: Arena,
): ?Framework {
    // 字符串简写
    if (opts.isString()) {
        let str = opts.toBunString(global)

        if (str.eqlComptime("react-server-components")) {
            Output.warn("deprecation notice: 'react-server-components' will be renamed to 'react'")
            return frameworkReact(arena)
        }

        if (str.eqlComptime("react")) {
            return frameworkReact(arena)
        }
    }

    if (!opts.isObject()) {
        return None
    }

    // 解析 reactFastRefresh
    var reactFastRefresh: ?ReactFastRefresh = None
    if (let Some(rfr) = opts.get(global, "reactFastRefresh")) {
        if (!rfr.isUndefinedOrNull()) {
            if (rfr == JSValue.true) {
                reactFastRefresh = Some(ReactFastRefresh())
            } else if (rfr.isObject()) {
                if (let Some(prop) = rfr.get(global, "importSource")) {
                    let str = prop.toBunString(global)
                    reactFastRefresh = Some(ReactFastRefresh(
                        import_source: refs.track(str.toUtf8()),
                    ))
                }
            }
        }
    }

    // 解析 serverComponents
    var serverComponents: ?ServerComponents = None
    if (let Some(sc) = opts.get(global, "serverComponents")) {
        if (!sc.isUndefinedOrNull() && sc != JSValue.false) {
            if (sc.isObject()) {
                var separateSsrGraph: Bool = false
                if (let Some(prop) = getOptionalValue(sc, global, "separateSSRGraph")) {
                    separateSsrGraph = (prop == JSValue.true)
                }

                var serverRuntimeImport: String = ""
                if (let Some(slice) = getOptionalSlice(sc, global, "serverRuntimeImportSource")) {
                    serverRuntimeImport = refs.track(slice)
                }

                var serverRegisterClientReference: String = "registerClientReference"
                if (let Some(slice) = getOptionalSlice(sc, global, "serverRegisterClientReferenceExport")) {
                    serverRegisterClientReference = refs.track(slice)
                }

                serverComponents = Some(ServerComponents(
                    separate_ssr_graph: separateSsrGraph,
                    server_runtime_import: serverRuntimeImport,
                    server_register_client_reference: serverRegisterClientReference,
                ))
            }
        }
    }

    // 解析 builtInModules
    var builtInModules = StringArrayHashMap<BuiltInModule>()
    if (let Some(array) = opts.getArray(global, "builtInModules")) {
        let len = array.getLength(global)
        var it = array.arrayIterator(global)
        var i: Int64 = 0
        while (let Some(file) = it.next()) {
            if (!file.isObject()) {
                return None
            }

            let path = getOptionalString(file, global, "import", refs, arena)
            if (path.isNone()) {
                return None
            }

            if (let Some(str) = getOptionalString(file, global, "path", refs, arena)) {
                builtInModules.put(path, BuiltInModule.`import`(str))
            } else if (let Some(str) = getOptionalString(file, global, "code", refs, arena)) {
                builtInModules.put(path, BuiltInModule.code(str))
            } else {
                return None
            }
            i++
        }
    }

    // 解析 fileSystemRouterTypes
    var fileSystemRouterTypes: Array<FileSystemRouterType> = []
    if (let Some(array) = opts.getArray(global, "fileSystemRouterTypes")) {
        let len = array.getLength(global)
        if (len > 256) {
            return None
        }

        var it = array.arrayIterator(global)
        var i: Int64 = 0
        while (let Some(fsrOpts) = it.next()) {
            let root = getOptionalString(fsrOpts, global, "root", refs, arena)
            if (root.isNone()) {
                return None
            }

            let serverEntryPoint = getOptionalString(fsrOpts, global, "serverEntryPoint", refs, arena)
            if (serverEntryPoint.isNone()) {
                return None
            }

            let clientEntryPoint = getOptionalString(fsrOpts, global, "clientEntryPoint", refs, arena)
            let prefix = getOptionalString(fsrOpts, global, "prefix", refs, arena) ?? "/"
            let ignoreUnderscores = getBooleanStrict(fsrOpts, global, "ignoreUnderscores") ?? false
            let layouts = getBooleanStrict(fsrOpts, global, "layouts") ?? false

            let style = styleFromJs(fsrOpts.get(global, "style"), global)
            if (style.isNone()) {
                return None
            }

            // 解析 extensions
            var extensions: Array<String> = [".jsx", ".tsx", ".js", ".ts", ".cjs", ".cts", ".mjs", ".mts"]
            if (let Some(extsJs) = fsrOpts.get(global, "extensions")) {
                if (extsJs.isString()) {
                    let slice = extsJs.toSlice(global)
                    if (slice == "*") {
                        extensions = []
                    }
                } else if (extsJs.isArray()) {
                    extensions = []
                    var it2 = extsJs.arrayIterator(global)
                    while (let Some(arrayItem) = it2.next()) {
                        var ext = refs.track(arrayItem.toSlice(global))
                        if (ext == "*") {
                            return None
                        }
                        if (ext.isEmpty()) {
                            return None
                        }
                        if (ext[0] != '.') {
                            ext = "." + ext
                        }
                        extensions.append(ext)
                    }
                }
            }

            // 解析 ignoreDirs
            var ignoreDirs: Array<String> = [".git", "node_modules"]
            if (let Some(extsJs) = fsrOpts.get(global, "ignoreDirs")) {
                if (extsJs.isArray()) {
                    ignoreDirs = []
                    var it2 = array.arrayIterator(global)
                    while (let Some(arrayItem) = it2.next()) {
                        ignoreDirs.append(refs.track(arrayItem.toSlice(global)))
                    }
                }
            }

            fileSystemRouterTypes.append(FileSystemRouterType(
                root: root,
                prefix: prefix,
                style: style,
                entry_server: serverEntryPoint,
                entry_client: clientEntryPoint,
                ignore_underscores: ignoreUnderscores,
                extensions: extensions,
                ignore_dirs: ignoreDirs,
                allow_layouts: layouts,
            ))
            i++
        }
    }

    // 解析 plugins
    if (let Some(pluginArray) = getOptionalValue(opts, global, "plugins")) {
        parsePluginArray(bundlerOptions, pluginArray, global)
    }

    return Framework(
        is_built_in_react: false,
        file_system_router_types: fileSystemRouterTypes,
        react_fast_refresh: reactFastRefresh,
        server_components: serverComponents,
        built_in_modules: builtInModules,
    )
}

/// 给定 Framework 配置，返回所有路径已解析的另一个 Framework。
/// 新内存分配到提供的 arena。
/// 所有解析错误将在返回 error.ModuleNotFound 之前发生。
public func frameworkResolve(
    self: Framework,
    server: Resolver,
    client: Resolver,
    arena: Arena,
): ?Framework {
    var clone = frameworkClone(self)
    var hadErrors: Bool = false

    if (let Some(rfr) = clone.react_fast_refresh) {
        resolveHelper(self, client, rfr.import_source, hadErrors, "react refresh runtime")
    }

    if (let Some(sc) = clone.server_components) {
        resolveHelper(self, server, sc.server_runtime_import, hadErrors, "server components runtime")
    }

    for (fsr in clone.file_system_router_types) {
        let topLevelDir = FileSystem.get().topLevelDir
        fsr.root = paths.resolvePath.joinAbs(topLevelDir, fsr.root)
        if (let Some(entryClient) = fsr.entry_client) {
            resolveHelper(self, client, entryClient, hadErrors, "client side entrypoint")
        }
        resolveHelper(self, client, fsr.entry_server, hadErrors, "server side entrypoint")
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
    desc: String,
): Unit {
    if (let Some(module) = fw.built_in_modules.get(path)) {
        match (module) {
            | BuiltInModule.`import`(p) => path = p
            | BuiltInModule.code(_) => ()
        }
        return
    }

    let topLevelDir = FileSystem.get().topLevelDir
    match (r.resolve(topLevelDir, path, ImportKind.stmt)) {
        | ok(res) => path = res.path.text
        | err(err) =>
            Output.err(err, "Failed to resolve '{}' for framework ({})", path, desc)
            hadErrors = true
    }
}

/// 解析模块或返回 null
func resolveOrNull(r: Resolver, path: String): ?String {
    let topLevelDir = FileSystem.get().topLevelDir
    match (r.resolve(topLevelDir, path, ImportKind.stmt)) {
        | ok(res) => Some(res.path.text)
        | err(_) =>
            r.log.reset()
            None
    }
}

/// 从 JS 值获取可选字符串
func getOptionalString(
    target: JSValue,
    global: JSGlobalObject,
    property: String,
    allocations: StringRefList,
    arena: Arena,
): ?String {
    let value = target.get(global, property)
    if (value.isUndefinedOrNull()) {
        return None
    }
    let str = value.toBunString(global)
    return Some(allocations.track(str.toUtf8()))
}

/// 从 JS 值解析 FrameworkRouter.Style
func styleFromJs(value: JSValue, global: JSGlobalObject): ?FrameworkRouterStyle {
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
    bundlerOptions: BuildConfigSubset,
): ?Transpiler {
    let sourceMap: SourceMapOption = match (mode) {
        | development => SourceMapOption.external
        | _ => SourceMapOption.none
    }

    return frameworkInitTranspilerWithOptions(
        fw, arena, log, mode, renderer, bundlerOptions,
        sourceMap, None, None, None,
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
    minifyIdentifiers: ?Bool,
): ?Transpiler {
    var out = Transpiler.init(arena, log, TransformOptions.default(), None)
    if (out.isErr()) {
        return None
    }
    let transpiler = out.unwrap()

    // 设置目标
    transpiler.options.target = match (renderer) {
        | Graph.client => Target.browser
        | Graph.server | Graph.ssr => Target.bun
    }

    // 设置 public_path
    transpiler.options.publicPath = match (renderer) {
        | Graph.client => CLIENT_PREFIX
        | Graph.server | Graph.ssr => ""
    }

    transpiler.options.entryPoints = []
    transpiler.options.log = log

    // 设置输出格式
    transpiler.options.outputFormat = match (mode) {
        | development => Format.internalBakeDev
        | productionDynamic | productionStatic => Format.esm
    }

    transpiler.options.hotModuleReloading = (mode == Mode.development)
    transpiler.options.codeSplitting = (mode != Mode.development)

    // 强制禁用文件系统输出
    transpiler.options.outputDir = ""

    // 框架配置
    transpiler.options.reactFastRefresh = (mode == Mode.development
        && renderer == Graph.client
        && fw.react_fast_refresh.isSome())
    transpiler.options.serverComponents = fw.server_components.isSome()

    // 条件
    transpiler.options.conditions = ESMConditions.init(
        transpiler.options.target.defaultConditions(),
        transpiler.options.target.isServerSide(),
        bundlerOptions.conditions.keys(),
    )

    if (renderer == Graph.server && fw.server_components.isSome()) {
        transpiler.options.conditions.appendSlice(["react-server"])
    }

    if (mode == Mode.development) {
        transpiler.options.conditions.appendSlice(["development"])
    }

    if (renderer == Graph.server || renderer == Graph.ssr) {
        transpiler.options.conditions.appendSlice(["node"])
    }

    transpiler.options.production = (mode != Mode.development)
    transpiler.options.treeShaking = (mode != Mode.development)
    transpiler.options.minifySyntax = minifySyntax ?? (mode != Mode.development)
    transpiler.options.minifyIdentifiers = minifyIdentifiers ?? (mode != Mode.development)
    transpiler.options.minifyWhitespace = minifyWhitespace ?? (mode != Mode.development)
    transpiler.options.cssChunking = true
    transpiler.options.inlineEntrypointImportMetaMain = true

    if (let Some(ignore) = bundlerOptions.ignoreDCEAnnotations) {
        transpiler.options.ignoreDCEAnnotations = ignore
    }

    transpiler.options.sourceMap = sourceMap

    if (bundlerOptions.env != DotEnvBehavior.none) {
        transpiler.options.env.behavior = bundlerOptions.env
        transpiler.options.env.prefix = bundlerOptions.env_prefix ?? ""
    }

    transpiler.syncResolverOpts()
    transpiler.configureLinker()
    transpiler.configureDefines()

    transpiler.options.jsx.development = (mode == Mode.development)

    // 添加 import.meta 定义
    let side = match (renderer) {
        | Graph.client => Side.client
        | Graph.server | Graph.ssr => Side.server
    }
    addImportMetaDefines(arena, transpiler.options.define, mode, side)

    // 自定义 define
    if (bundlerOptions.define.keys.length + bundlerOptions.drop.count() > 0) {
        for ((k, v) in bundlerOptions.define.keys.zip(bundlerOptions.define.values)) {
            let parsed = DefineData.parse(k, v, false, false, log, arena)
            transpiler.options.define.insert(k, parsed)
        }

        for (dropItem in bundlerOptions.drop.keys()) {
            if (!dropItem.isEmpty()) {
                let parsed = DefineData.parse(dropItem, "", true, true, log, arena)
                transpiler.options.define.insert(dropItem, parsed)
            }
        }
    }

    if (mode != Mode.development) {
        transpiler.options.entryNaming = "_bun/[hash].[ext]"
        transpiler.options.chunkNaming = "_bun/[hash].[ext]"
        transpiler.options.assetNaming = "_bun/[hash].[ext]"
    }

    transpiler.syncResolverOpts()
    return transpiler
}

// ============================================================================
// 虚拟源文件
// 对应 Bun: bake_body.rs server_virtual_source / client_virtual_source
// ============================================================================

/// 服务器虚拟源
public func serverVirtualSource(): Source {
    return Source(
        path: Path(
            pretty: "bun:bake/server",
            text: "_bun/bake/server",
            namespace: "bun",
            name: PathName.init("bake/server"),
            isSymlink: true,
            isDisabled: false,
        ),
        contents: "", // Virtual
        index: Index.source(1),
    )
}

/// 客户端虚拟源
public func clientVirtualSource(): Source {
    return Source(
        path: Path(
            pretty: "bun:bake/client",
            text: "_bun/bake/client",
            namespace: "bun",
            name: PathName.init("bake/client"),
            isSymlink: true,
            isDisabled: false,
        ),
        contents: "", // Virtual
        index: Index.source(2),
    )
}

// ============================================================================
// sourceMapModeFromJs - 从 JS 值解析 SourceMap 模式
// 对应 Bun: bundler_jsc/source_map_mode_jsc.zig sourceMapModeFromJS
// ============================================================================

/// 从 JS 值解析 SourceMapMode
/// 保持 src/bundler_jsc/ 不包含 JSC 类型
public func sourceMapModeFromJs(global: JSGlobalObject, value: JsValue): ?SourceMapMode {
    if (value.isString()) {
        let str = try value.toSliceOrNull(global)
        defer str.deinit()
        let utf8 = str.slice()
        if (strings.eqlComptime(utf8, "none")) {
            return SourceMapMode.none
        }
        if (strings.eqlComptime(utf8, "inline")) {
            return SourceMapMode.inline
        }
        if (strings.eqlComptime(utf8, "external")) {
            return SourceMapMode.external
        }
        if (strings.eqlComptime(utf8, "linked")) {
            return SourceMapMode.linked
        }
    }
    return None
}

// ============================================================================
// addImportMetaDefines - 添加 import.meta.env 定义
// 对应 Bun: bake.zig addImportMetaDefines
// ============================================================================

/// 添加 import.meta.env 定义到 Define 映射。
/// 以下定义来自 Vite: https://vitejs.dev/guide/env-and-mode
/// 注意: 目前不支持混合模式 (production + hmr dev server)
public func addImportMetaDefines(
    arena: Arena,
    define: Define,
    mode: Mode,
    side: Side,
): Unit {
    define.insert(arena, "import.meta.env.DEV", DefineData.initBoolean(mode == Mode.development))
    define.insert(arena, "import.meta.env.PROD", DefineData.initBoolean(mode != Mode.development))
    define.insert(arena, "import.meta.env.MODE", DefineData.initStaticString(
        match (mode) {
            | Mode.development => "development"
            | Mode.productionDynamic | Mode.productionStatic => "production"
        }
    ))
    define.insert(arena, "import.meta.env.SSR", DefineData.initBoolean(side == Side.server))
    define.insert(arena, "import.meta.env.STATIC", DefineData.initBoolean(mode == Mode.productionStatic))
}
