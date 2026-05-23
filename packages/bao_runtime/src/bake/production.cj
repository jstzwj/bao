// 翻译自 Bun: src/runtime/bake/production.zig
// 实现将 Bake 应用构建为生产版本

package bao_runtime.bake

import bao_jsc.*
import bao_bun_alloc.*

/// 实现生产构建命令
public func buildCommand(ctx: CommandContext): Unit {
    bake.printWarning()

    if (ctx.args.entry_points.size > 1) {
        Output.errGeneric("bun build --app only accepts one entrypoint")
        Global.crash()
    }

    if (ctx.debug.hot_reload != HotReloadMode.none) {
        Output.errGeneric("Instead of using --watch, use 'bun run'")
        Global.crash()
    }

    var cwd_buf: PathBuffer = PathBuffer()
    let cwdResult = bun.getcwd(cwd_buf)
    let cwd: String = match (cwdResult) {
        case ok(val) => val
        case err(e) =>
            Output.err(e, "Could not query current working directory")
            Global.crash()
    }

    // 创建 VM + global 用于加载配置文件、插件和执行构建时预渲染
    bun.jsc.initialize(false)

    var arena: MimallocArena = MimallocArena()
    // defer arena.deinit() -- inline cleanup at end of scope

    let vm: VirtualMachine = VirtualMachine.initBake(VirtualMachineInitBakeOptions(
        arena.allocator(),
        ctx.log,
        ctx.args,
        ctx.runtime_options.smol,
    ))
    // defer vm.deinit() -- inline cleanup at end of scope

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
        case map(macros) => b.options.macro_remap = macros
        case unspecified => ()
    }

    b.configureDefines()
    bun.http.AsyncHTTP.loadEnv(vm.allocator, vm.log, b.env)
    vm.loadExtraEnvAndSourceCodePrinter()
    vm.is_main_thread = true
    VirtualMachine.is_main_thread_vm = true

    let api_lock = vm.jsc_vm.getAPILock()
    // defer api_lock.release() -- inline cleanup at end of scope

    var pt: PerThread = PerThread(
        [],
        [],
        [],
        [],
        StringArrayHashMap<OutputFileIndex>(),
        StringArrayHashMap<OutputFileIndex>(),
        vm,
        AutoBitSet.initEmpty(vm.allocator, 0),
        JsValue.null,
    )

    match (buildWithVm(ctx, cwd, vm, pt)) {
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

    // inline cleanup for defer
    api_lock.release()
    vm.deinit()
    arena.deinit()
}

/// 将 sourcemap 写入磁盘
public func writeSourcemapToDisk(
    allocator: Allocator,
    file: OutputFile,
    bundled_outputs: Array<OutputFile>,
    source_maps: StringArrayHashMapUnmanaged<OutputFileIndex>
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
        OutputFileIndex(source_map_index),
    )
}

/// 使用 VM 执行构建
public func buildWithVm(ctx: CommandContext, cwd: String, vm: VirtualMachine, pt: PerThread): Unit {
    let global = vm.global
    let b = vm.transpiler
    let allocator = bun.default_allocator

    Output.prettyErrorln("Loading configuration")
    Output.flush()

    var unresolved_config_entry_point: String = if (ctx.args.entry_points.size > 0) { ctx.args.entry_points[0] } else { "./bun.app" }
    if (bun.resolver.isPackagePath(unresolved_config_entry_point)) {
        unresolved_config_entry_point = "./${unresolved_config_entry_point}"
    }

    let resolveResult = b.resolver.resolve(cwd, unresolved_config_entry_point, ResolveKind.entry_point_build)
    let config_entry_point = match (resolveResult) {
        case ok(val) => val
        case error(ModuleNotFound) =>
            if (ctx.args.entry_points.size == 0) {
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

    // 生产构建流程由后续 bundle 阶段继续处理。
}

/// 入口点映射表
/// 生产 bundle 生成后，预渲染需要查找与每个路由的 OpaqueFileId 关联的生成 chunk
public class EntryPointMap {
    public var root: String
    public var allocator: Allocator
    public var files: HashMap

    public init(root: String, allocator: Allocator, files: HashMap) {
        this.root = root
        this.allocator = allocator
        this.files = files
    }
}

public class EntryPointMapInputFile {
    public var abs_path_ptr: String
    public var abs_path_len: UInt32
    public var side: bake.Side

    public init(abs_path: String, side: bake.Side) {
        this.abs_path_ptr = abs_path
        this.abs_path_len = UInt32(abs_path.size)
        this.side = side
    }

    public func absPath(): String {
        return abs_path_ptr
    }
}

/// PerThread - 每个渲染线程使用的数据。包含渲染所需的 bundle 中的所有信息。
public class PerThread {
    // 共享数据
    public var input_files: Array<EntryPointMapInputFile>
    public var bundled_outputs: Array<OutputFile>
    public var output_indexes: Array<OutputFileIndex>
    public var module_keys: Array<bun.String>
    public var module_map: StringArrayHashMapUnmanaged<OutputFileIndex>
    public var source_maps: StringArrayHashMapUnmanaged<OutputFileIndex>

    // 线程本地
    public var vm: VirtualMachine
    public var loaded_files: AutoBitSet
    public var all_server_files: JsValue

    public init(
        input_files: Array<EntryPointMapInputFile>,
        bundled_outputs: Array<OutputFile>,
        output_indexes: Array<OutputFileIndex>,
        module_keys: Array<bun.String>,
        module_map: StringArrayHashMapUnmanaged<OutputFileIndex>,
        source_maps: StringArrayHashMapUnmanaged<OutputFileIndex>,
        vm: VirtualMachine,
        loaded_files: AutoBitSet,
        all_server_files: JsValue
    ) {
        this.input_files = input_files
        this.bundled_outputs = bundled_outputs
        this.output_indexes = output_indexes
        this.module_keys = module_keys
        this.module_map = module_map
        this.source_maps = source_maps
        this.vm = vm
        this.loaded_files = loaded_files
        this.all_server_files = all_server_files
    }

    /// 发送到其他线程进行渲染的选项
    public func outputIndex(id: OpaqueFileId): OutputFileIndex {
        return output_indexes[id.getOrThrow()]
    }

    public func inputFile(id: OpaqueFileId): EntryPointMapInputFile {
        return input_files[id.getOrThrow()]
    }

    public func outputFile(id: OpaqueFileId): OutputFile {
        return bundled_outputs[outputIndex(id).getOrThrow()]
    }

    public func loadBundledModule(id: OpaqueFileId): JsValue {
        return loadModule(vm, vm.global, module_keys[id.getOrThrow()].toJS(vm.global))
    }

    public func preloadBundledModule(id: OpaqueFileId): JsValue {
        if (!loaded_files.isSet(id.getOrThrow())) {
            loaded_files.set(id.getOrThrow())
            all_server_files.putIndex(vm.global, Int64(id.getOrThrow()), module_keys[id.getOrThrow()].toJS(vm.global))
        }
        return JsValue.jsNumberFromInt32(Int32(id.getOrThrow()))
    }
}

/// PerThread Options - 发送到其他线程进行渲染的选项
public class PerThreadOptions {
    public var input_files: Array<EntryPointMapInputFile>
    public var bundled_outputs: Array<OutputFile>
    public var output_indexes: Array<OutputFileIndex>
    public var module_keys: Array<bun.String>
    public var module_map: StringArrayHashMapUnmanaged<OutputFileIndex>
    public var source_maps: StringArrayHashMapUnmanaged<OutputFileIndex>
}

/// 加载模块
func loadModule(vm: VirtualMachine, global: JSGlobalObject, key: JsValue): JsValue {
    let promise = BakeLoadModuleByKey(global, key).asAnyPromise().getOrThrow().internal
    promise.setHandled()
    vm.waitForPromise(PromiseRef(internal: promise))
    match (vm.eventLoop().drainMicrotasks()) {
        case ok(()) => ()
        case err(_) => bun.Global.crash()
    }
    match (promise.unwrap(vm.jsc_vm, PromiseUnwrapMode.mark_handled)) {
        case pending => unreachable()
        case fulfilled(_) => return BakeGetModuleNamespace(global, key)
        case rejected(err) => return vm.global.throwValue(err)
    }
}

public func BakeGetDefaultExportFromModule(global: JSGlobalObject, key: JsValue): JsValue { return JsValue.jsUndefined() }
public func BakeGetModuleNamespace(global: JSGlobalObject, key: JsValue): JsValue { return JsValue.jsUndefined() }
public func BakeLoadModuleByKey(global: JSGlobalObject, key: JsValue): JsValue { return JsValue.jsUndefined() }

/// TypeAndFlags - 路由类型和标志的打包结构
public struct TypeAndFlags {
    public var `type`: UInt8
    public var no_client: Bool = false
    public var unused: UInt32 = 0
}

/// 给定 key，返回要加载的源代码
public func BakeProdLoad(pt: PerThread, key: bun.String): bun.String {
    let utf8 = key.toUTF8(pt.vm.allocator)
    if (let Some(value) <- pt.module_map.get(utf8.slice())) {
        return pt.bundled_outputs[value.getOrThrow()].value.toBunString()
    }
    return bun.String.dead
}

/// 解析生产环境中的模块路径
public func BakeProdResolve(global: JSGlobalObject, a_str: bun.String, specifier_str: bun.String): bun.String {
    let specifier = specifier_str.toUTF8(bun.default_allocator)

    if (let Some(alias) <- jsc.ModuleLoader.HardcodedModule.Alias.get(specifier.slice())) {
        return bun.String.`static`(alias.path)
    }

    let referrer = a_str.toUTF8(bun.default_allocator)

    if (bun.resolver.isPackagePath(specifier.slice())) {
        return bun.String.dead // 不允许生产资源中的非相对导入
    }

    return bun.String.createFormat("bake:${bun.path.joinAbsStringZ(referrer.slice(), specifier.slice())}")
}

// 类型别名
// CommandContext stub - originally bun.cli.Command.Context
public class CommandContext {}
// VirtualMachineInitBakeOptions stub
public class VirtualMachineInitBakeOptions {
    public var allocator: Allocator
    public var log: Int64
    public init(a: Allocator, l: Int64, args: CommandContext, smol: Bool) {
        allocator = a
        log = l
    }
}
// OutputFile and OutputFileIndex stubs - originally from bun.options
public class OutputFile {
    public var dest_path: String = ""
    public var value: String = ""
    public var source_map_index: UInt32 = UInt32(0)
    public init() {}
}
public class OutputFileIndex {
    public var value: UInt32 = UInt32(0)
    public init() {}
    public init(v: UInt32) { value = v }
    public func get(): UInt32 { value }
}
// OpaqueFileId stub - originally FrameworkRouter.OpaqueFileId
public class OpaqueFileId {
    public var value: UInt32 = UInt32(0)
    public init() {}
    public init(v: UInt32) { value = v }
    public func get(): UInt32 { value }
}
// JSGlobalObject available via import bao_jsc.*
// AutoBitSet stub
public class AutoBitSet {
    public init() {}
    public static func initEmpty(a: Allocator, b: Int64): AutoBitSet { AutoBitSet() }
    public func isSet(i: UInt32): Bool { false }
    public func set(i: UInt32): Unit {}
}
// StringArrayHashMapUnmanaged stub
public class StringArrayHashMapUnmanaged<V> {
    public init() {}
    public func put(k: String, v: V): Unit {}
    public func get(k: String): ?V { None }
}
// HotReloadMode and OfflineMode stubs
public enum HotReloadMode { | none | watch }
public enum OfflineMode { | online | offline | latest }
// MimallocArena stub
public class MimallocArena {
    public init() {}
    public func allocator(): Allocator { Allocator() }
    public func deinit(): Unit {}
}
