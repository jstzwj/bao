// 翻译自 Bun: src/runtime/bake/production.zig
// 实现将 Bake 应用构建为生产版本

package bao_runtime.bake

/// 实现生产构建命令
public func buildCommand(ctx: CommandContext): Unit {
    bake.printWarning()

    if (ctx.args.entry_points.length > 1) {
        Output.errGeneric("bun build --app only accepts one entrypoint")
        Global.crash()
    }

    if (ctx.debug.hot_reload != HotReloadMode.none) {
        Output.errGeneric("Instead of using --watch, use 'bun run'")
        Global.crash()
    }

    var cwd_buf: PathBuffer = PathBuffer()
    let cwd: String = bun.getcwd(cwd_buf) match {
        case ok(val) => val
        case err(e) =>
            Output.err(e, "Could not query current working directory")
            Global.crash()
    }

    // 创建 VM + global 用于加载配置文件、插件和执行构建时预渲染
    bun.jsc.initialize(false)

    var arena: MimallocArena = MimallocArena.init()
    defer arena.deinit()

    let vm: VirtualMachine = VirtualMachine.initBake(VirtualMachineInitBakeOptions(
        allocator: arena.allocator(),
        log: ctx.log,
        args: ctx.args,
        smol: ctx.runtime_options.smol,
    ))
    defer vm.deinit()

    vm.regular_event_loop.global = vm.global
    vm.event_loop.ensureWaker()
    let b: Transpiler = vm.transpiler
    vm.preload = ctx.preloads
    vm.argv = ctx.passthrough
    vm.arena = arena
    vm.allocator = arena.allocator()
    b.options.install = ctx.install
    b.resolver.opts.install = ctx.install
    b.resolver.opts.global_cache = ctx.debug.global_cache
    b.resolver.opts.prefer_offline_install = (ctx.debug.offline_mode_setting ?? OfflineMode.online) == OfflineMode.offline
    b.resolver.opts.prefer_latest_install = (ctx.debug.offline_mode_setting ?? OfflineMode.online) == OfflineMode.latest
    b.options.global_cache = b.resolver.opts.global_cache
    b.options.prefer_offline_install = b.resolver.opts.prefer_offline_install
    b.options.prefer_latest_install = b.resolver.opts.prefer_latest_install
    b.resolver.env_loader = b.env
    b.options.minify_identifiers = ctx.bundler_options.minify_identifiers
    b.options.minify_whitespace = ctx.bundler_options.minify_whitespace
    b.options.ignore_dce_annotations = ctx.bundler_options.ignore_dce_annotations
    b.resolver.opts.minify_identifiers = ctx.bundler_options.minify_identifiers
    b.resolver.opts.minify_whitespace = ctx.bundler_options.minify_whitespace
    b.options.env.behavior = DotEnvBehavior.load_all_without_inlining
    vm.event_loop.ensureWaker()

    match (ctx.debug.macros) {
        case disable => b.options.no_macros = true
        case map(let macros) => b.options.macro_remap = macros
        case unspecified => ()
    }

    b.configureDefines()
    bun.http.AsyncHTTP.loadEnv(vm.allocator, vm.log, b.env)
    vm.loadExtraEnvAndSourceCodePrinter()
    vm.is_main_thread = true
    VirtualMachine.is_main_thread_vm = true

    let api_lock = vm.jsc_vm.getAPILock()
    defer api_lock.release()

    var pt: PerThread = PerThread(
        input_files: [],
        bundled_outputs: [],
        output_indexes: [],
        module_keys: [],
        module_map: StringArrayHashMap<OutputFileIndex>(),
        source_maps: StringArrayHashMap<OutputFileIndex>(),
        vm: vm,
        loaded_files: AutoBitSet.initEmpty(vm.allocator, 0),
        all_server_files: JSValue.null,
    )

    buildWithVm(ctx, cwd, vm, pt) match {
        case ok(()) => ()
        case error(JSError) =>
            let err_value = vm.global.takeException()
            vm.printErrorLikeObjectToConsole(err_value.toError() ?? err_value)
            if (vm.exit_handler.exit_code == 0) {
                vm.exit_handler.exit_code = 1
            }
            vm.onExit()
            vm.globalExit()
        case error(e) => return e
    }
}

/// 将 sourcemap 写入磁盘
public func writeSourcemapToDisk(
    allocator: Allocator,
    file: OutputFile,
    bundled_outputs: Array<OutputFile>,
    source_maps: StringArrayHashMapUnmanaged<OutputFileIndex>,
): Unit {
    let source_map_index = file.source_map_index
    let source_map_file: OutputFile = bundled_outputs[source_map_index]

    let without_prefix: String = if (bun.strings.hasPrefixComptime(file.dest_path, "./") ||
        bun.strings.hasPrefixComptime(file.dest_path, ".\\")) {
        file.dest_path.slice(2)
    } else {
        file.dest_path
    }

    source_maps.put(
        allocator,
        "bake:/${without_prefix}",
        OutputFileIndex.init(source_map_index),
    )
}

/// 使用 VM 执行构建
public func buildWithVm(ctx: CommandContext, cwd: String, vm: VirtualMachine, pt: PerThread): Unit {
    let global = vm.global
    let b = vm.transpiler
    let allocator = bun.default_allocator

    Output.prettyErrorln("Loading configuration")
    Output.flush()

    var unresolved_config_entry_point: String = if (ctx.args.entry_points.length > 0) ctx.args.entry_points[0] else "./bun.app"
    if (bun.resolver.isPackagePath(unresolved_config_entry_point)) {
        unresolved_config_entry_point = "./${unresolved_config_entry_point}"
    }

    let config_entry_point = b.resolver.resolve(cwd, unresolved_config_entry_point, ResolveKind.entry_point_build) match {
        case ok(val) => val
        case error(ModuleNotFound) =>
            if (ctx.args.entry_points.length == 0) {
                Output.err(error.ModuleNotFound,
                    "'bun build --app' cannot find your application's config file\n\nThe default location for this is `bun.app.ts`")
                Global.crash()
            }
            Output.err(error.ModuleNotFound, "could not resolve application config file '${unresolved_config_entry_point}'")
            Global.crash()
        case error(e) =>
            Output.err(e, "could not resolve application config file '${unresolved_config_entry_point}'")
            Global.crash()
    }

    // TODO: 完整的生产构建流程实现
}

/// 入口点映射表
/// 生产 bundle 生成后，预渲染需要查找与每个路由的 OpaqueFileId 关联的生成 chunk
public class EntryPointMap {
    public var root: String
    public var allocator: Allocator
    public var files: HashMap

    public class InputFile {
        public var abs_path_ptr: String
        public var abs_path_len: UInt32
        public var side: bake.Side

        public init(abs_path: String, side: bake.Side) {
            this.abs_path_ptr = abs_path
            this.abs_path_len = UInt32(abs_path.length)
            this.side = side
        }

        public func absPath(): String {
            return abs_path_ptr
        }
    }
}

/// PerThread - 每个渲染线程使用的数据。包含渲染所需的 bundle 中的所有信息。
public class PerThread {
    // 共享数据
    public var input_files: Array<EntryPointMap.InputFile>
    public var bundled_outputs: Array<OutputFile>
    public var output_indexes: Array<OutputFileIndex>
    public var module_keys: Array<bun.String>
    public var module_map: StringArrayHashMapUnmanaged<OutputFileIndex>
    public var source_maps: StringArrayHashMapUnmanaged<OutputFileIndex>

    // 线程本地
    public var vm: VirtualMachine
    public var loaded_files: AutoBitSet
    public var all_server_files: JSValue

    /// 发送到其他线程进行渲染的选项
    public class Options {
        public var input_files: Array<EntryPointMap.InputFile>
        public var bundled_outputs: Array<OutputFile>
        public var output_indexes: Array<OutputFileIndex>
        public var module_keys: Array<bun.String>
        public var module_map: StringArrayHashMapUnmanaged<OutputFileIndex>
        public var source_maps: StringArrayHashMapUnmanaged<OutputFileIndex>
    }

    public func outputIndex(id: OpaqueFileId): OutputFileIndex {
        return output_indexes[id.get()]
    }

    public func inputFile(id: OpaqueFileId): EntryPointMap.InputFile {
        return input_files[id.get()]
    }

    public func outputFile(id: OpaqueFileId): OutputFile {
        return bundled_outputs[outputIndex(id).get()]
    }

    public func loadBundledModule(id: OpaqueFileId): JSValue {
        return loadModule(vm, vm.global, module_keys[id.get()].toJS(vm.global))
    }

    public func preloadBundledModule(id: OpaqueFileId): JSValue {
        if (!loaded_files.isSet(id.get())) {
            loaded_files.set(id.get())
            all_server_files.putIndex(vm.global, Int64(id.get()), module_keys[id.get()].toJS(vm.global))
        }
        return JSValue.jsNumberFromInt32(Int32(id.get()))
    }
}

/// 加载模块
func loadModule(vm: VirtualMachine, global: JSGlobalObject, key: JSValue): JSValue {
    // TODO: 完整实现
    return JSValue.null
}

/// TypeAndFlags - 路由类型和标志的打包结构
public struct TypeAndFlags <: Int32 {
    public var type: UInt8
    public var no_client: Bool = false
    public var unused: UInt32 = 0
}

/// 给定 key，返回要加载的源代码
public func BakeProdLoad(pt: PerThread, key: bun.String): bun.String {
    let utf8 = key.toUTF8(pt.vm.allocator)
    if (let Some(value) = pt.module_map.get(utf8.slice())) {
        return pt.bundled_outputs[value.get()].value.toBunString()
    }
    return bun.String.dead
}

/// 解析生产环境中的模块路径
public func BakeProdResolve(global: JSGlobalObject, a_str: bun.String, specifier_str: bun.String): bun.String {
    let specifier = specifier_str.toUTF8(bun.default_allocator)

    if (jsc.ModuleLoader.HardcodedModule.Alias.get(specifier.slice(), .bun, .{})) {
        // 返回硬编码模块路径
        return bun.String.dead // placeholder
    }

    let referrer = a_str.toUTF8(bun.default_allocator)

    if (bun.resolver.isPackagePath(specifier.slice())) {
        return bun.String.dead // 不允许生产资源中的非相对导入
    }

    return bun.String.createFormat("bake:${bun.path.joinAbs(...)}")
}

// 类型别名
public type CommandContext = bun.cli.Command.Context
public type VirtualMachine = jsc.VirtualMachine
public type VirtualMachineInitBakeOptions = VirtualMachine.InitBakeOptions
public type Transpiler = bun.transpiler.Transpiler
public type OutputFile = bun.options.OutputFile
public type OutputFileIndex = bun.options.OutputFile.Index
public type OpaqueFileId = FrameworkRouter.OpaqueFileId
public type JSValue = jsc.JSValue
public type JSGlobalObject = jsc.JSGlobalObject
public type AutoBitSet = bun.bit_set.AutoBitSet
public type StringArrayHashMapUnmanaged<V> = std.StringArrayHashMapUnmanaged<V>
public type HotReloadMode = bun.cli.HotReloadMode
public type OfflineMode = bun.cli.OfflineMode
public type MimallocArena = bun.MimallocArena
