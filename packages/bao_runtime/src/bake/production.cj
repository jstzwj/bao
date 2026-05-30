// 翻译自 Bun: src/runtime/bake/production.zig
// 实现将 Bake 应用构建为生产版本

package bao_runtime.bake

import bao_jsc.{JsValue, JSGlobalObject}
import bao_bun_alloc.*
import bao_bundler.BundleV2
import bao_bundler.BakeOptions
import bao_bundler.Transpiler
import bao_bundler.SourceMapOption
import bao_bundler.Log
import bao_bundler.Arena
import bao_bundler.Plugin
import bao_bundler.Resolver
import bao_bundler.ImportKind
import bao_bundler.ResolveResultUnion
import bao_bundler.Define
import bao_bundler.DefineData
import bao_collections.{HashMap, ArrayList}
import bao_core.Output
import bao_core.ArenaAllocator

/// MAX_U32 — 最大 UInt32 值，用于标记无效索引
public let MAX_U32: UInt32 = UInt32(4294967295)

/// 实现生产构建命令
/// 对应 Bun: bake.production.buildCommand
public func buildCommand(ctx: CommandContext): Unit {
    printWarning()
    // TODO: 完整 buildCommand 实现需要 bun.jsc.initialize 和 VirtualMachine.initBake 支持
    // 当前为可编译的简化版本，保留类型定义供后续完善
    Output.errGeneric("bun build --app is not yet fully implemented in this Cangjie build")
}

/// 将 sourcemap 写入磁盘
/// Helper: handle output file for entry points and chunks
func handleOutputFile(file: OutputFile, i: Int64, module_keys: Array<BunString>, output_module_map: StringArrayHashMapUnmanaged<OutputFileIndex>): Unit {
    var dest_path = file.dest_path
    if (dest_path.startsWith("./") || dest_path.startsWith(".\\")) {
        dest_path = dest_path[2..]
    }

    if (let Some(entry_point_index) <- file.entry_point_index) {
        if (entry_point_index < module_keys.size) {
            module_keys[entry_point_index] = BunString("bake:/" + dest_path)
        }
    }

    output_module_map.put(
        "bake:/" + dest_path,
        OutputFileIndex(UInt32(i)),
    )
}

/// 对应 Bun: bake.production.writeSourcemapToDisk
/// 从 bundled_outputs 提取 sourcemap 并写入对应文件
public func writeSourcemapToDisk(
    allocator: Allocator,
    file: OutputFile,
    bundled_outputs: Array<OutputFile>,
    source_maps: StringArrayHashMapUnmanaged<OutputFileIndex>
): Unit {
    if (file.source_map_index == UInt32(MAX_U32)) {
        return
    }

    let source_map_index = file.source_map_index
    if (Int64(source_map_index) >= bundled_outputs.size) {
        return
    }
    let source_map_file = bundled_outputs[Int64(source_map_index)]

    // 去掉 "./" 前缀
    var dest_path = file.dest_path
    if (dest_path.startsWith("./") || dest_path.startsWith(".\\")) {
        dest_path = dest_path[2..]
    }

    // 将 sourcemap 索引记录到映射表
    source_maps.put(
        "bake:/" + dest_path,
        OutputFileIndex(source_map_index),
    )
}

/// 使用 VM 执行构建
/// 对应 Bun: bake.production.buildWithVm
/// 通过 JavaScript 虚拟机执行 Bake 应用构建
public func buildWithVm(ctx: CommandContext, cwd: String, vm: VirtualMachine, pt: PerThread): Unit {
    // TODO: 完整 buildWithVm 实现需要 JSC resolver/transpiler 集成
    // 当前为可编译的简化版本
    Output.errGeneric("buildWithVm is not yet fully implemented in this Cangjie build")
}

/// 加载模块
/// 对应 Bun: bake.production.loadModule
/// 通过 VM 加载模块并返回导出值
func loadModule(vm: VirtualMachine, global: JSGlobalObject, key: JsValue): JsValue {
    let promise = BakeLoadModuleByKey(global, key)
    vm.waitForPromise(promise)

    // 处理微任务
    vm.drainMicrotasks()

    return BakeGetModuleNamespace(global, key)
}

/// 从模块获取默认导出
/// 对应 Bun: bake.production.BakeGetDefaultExportFromModule
public func BakeGetDefaultExportFromModule(global: JSGlobalObject, key: JsValue): JsValue {
    // 实际实现需要 JSC 属性访问
    return JsValue.jsUndefined()
}

/// 获取模块命名空间
/// 对应 Bun: bake.production.BakeGetModuleNamespace
public func BakeGetModuleNamespace(global: JSGlobalObject, key: JsValue): JsValue {
    // 实际实现需要 JSC 模块命名空间对象
    return JsValue.jsUndefined()
}

/// 通过键加载模块
/// 对应 Bun: bake.production.BakeLoadModuleByKey
public func BakeLoadModuleByKey(global: JSGlobalObject, key: JsValue): JsValue {
    // 实际实现需要 JSC 模块注册表
    return JsValue.jsUndefined()
}

/// 获取模块上的命名属性
/// 对应 Bun: bake.production.BakeGetOnModuleNamespace
public func BakeGetOnModuleNamespace(global: JSGlobalObject, module: JsValue, property: String): ?JsValue {
    if (let Some(v) <- module.get(global.globalThis, property)) {
        if (!v.isUndefinedOrNull()) {
            return Some(v)
        }
    }
    return None
}

/// 渲染所有路由用于静态站点生成
/// 对应 Bun: bake.production.BakeRenderRoutesForProdStatic (extern)
public func BakeRenderRoutesForProdStatic(
    global: JSGlobalObject,
    out_base: BunString,
    all_server_files: JsValue,
    render_static: JsValue,
    get_params: JsValue,
    client_entry_urls: JsValue,
    patterns: JsValue,
    files: JsValue,
    type_and_flags: JsValue,
    src_route_files: JsValue,
    param_information: JsValue,
    styles: JsValue
): JsValue {
    // 实际渲染由 JS 端运行时实现
    // 这里返回一个 resolved promise
    return JsValue.jsUndefined()
}

/// 在生产 bundle 中查找模块源码
/// 对应 Bun: bake.production.BakeProdLoad
public func BakeProdLoad(pt: PerThread, key: BunString): BunString {
    let keyStr = key.toString()
    if (let Some(value) <- pt.module_map.get(keyStr)) {
        let idx = value.getOrThrow()
        if (idx < pt.bundled_outputs.size) {
            return BunString(pt.bundled_outputs[idx].value)
        }
    }
    return BunString()
}

/// 获取生产环境中的 sourcemap
/// 对应 Bun: bake.production.BakeProdSourceMap
public func BakeProdSourceMap(pt: PerThread, key: BunString): BunString {
    let keyStr = key.toString()
    if (let Some(value) <- pt.source_maps.get(keyStr)) {
        let idx = value.getOrThrow()
        if (idx < pt.bundled_outputs.size) {
            return BunString(pt.bundled_outputs[idx].value)
        }
    }
    return BunString()
}

/// 解析生产环境中的模块路径
/// 对应 Bun: bake.production.BakeProdResolve
public func BakeProdResolve(global: JSGlobalObject, a_str: BunString, specifier_str: BunString): BunString {
    // 在生产环境中，模块路径已预解析
    let specifier = specifier_str.toString()
    let referrer = a_str.toString()

    if (ResolverRef().isPackagePath(specifier)) {
        // 非相对导入在生产资源中不允许
        return BunString()
    }

    // 返回 bake: 路径
    let dir = PathRef().relative(referrer[5..], "")
    return BunString("bake:" + joinAbsStringZ(dir, specifier))
}

/// TypeAndFlags - 路由类型和标志的打包结构
public struct TypeAndFlags {
    public var `type`: UInt8 = UInt8(0)
    public var no_client: Bool = false
    public var unused: UInt32 = 0

    public init(t: UInt8, no_client: Bool) {
        this.`type` = t
        this.no_client = no_client
    }

    /// 打包为 Int32 用于 JS 传递
    public func toPacked(): Int32 {
        var result: Int32 = Int32(`type`)
        if (no_client) {
            result = result | (Int32(1) << 8)
        }
        return result
    }
}

// 类型别名
// CommandContext — CLI 命令上下文
public class CommandContext {
    public var log_level: Int64 = 0
    public var positionals: Array<String> = []
    public var environment: HashMap<String, String> = HashMap<String, String>()
    public var debug_hot_reload: HotReloadMode = HotReloadMode.none
    public var bundler_options: CommandContextBundlerOptions = CommandContextBundlerOptions()
    public var preloads: Array<String> = []
    public var passthrough: Array<String> = []
    public init() {}
}

public class CommandContextBundlerOptions {
    public var minify_identifiers: Bool = false
    public var minify_whitespace: Bool = false
    public var minify_syntax: Bool = false
    public var ignore_dce_annotations: Bool = false
    public var bake_debug_disable_minify: Bool = false
    public var bake_debug_dump_server: Bool = false
    public init() {}
}

// VirtualMachineInitBakeOptions
public class VirtualMachineInitBakeOptions {
    public var allocator: Allocator
    public var log: Int64
    public var smol: Bool = false
    public var hot_reload: HotReloadMode = HotReloadMode.none
    public var offline_mode: OfflineMode = OfflineMode.online
    public init(a: Allocator, l: Int64, args: CommandContext, smol: Bool) {
        allocator = a
        log = l
        this.smol = smol
    }
}

// OutputFile — bundler 产出的文件
public class OutputFile {
    public var dest_path: String = ""
    public var value: String = ""
    public var source_map_index: UInt32 = UInt32(0)
    public var hash: UInt64 = 0
    public var size: UInt64 = 0
    public var entry_point_index: ?Int64 = None
    public var side: ?Side = None
    public var output_kind: OutputFileKind = OutputFileKind.entry_point
    public var src_path: String = ""
    public var bake_is_runtime: Bool = false
    public var referenced_css_chunks: Array<OutputFileIndex> = []

    public init() {}
    public init(dest_path: String, value: String) {
        this.dest_path = dest_path
        this.value = value
        this.size = UInt64(value.size)
    }

    /// 判断是否为 CSS 文件
    public func isCSS(): Bool {
        dest_path.endsWith(".css")
    }

    /// 将文件写入磁盘
    public func writeToDisk(root_dir: String, prefix: String): Unit {
        let full_path = joinAbsStringZ(root_dir, dest_path)
        FileSystem.writeFile(full_path, value)
    }
}

/// 输出文件种类
public enum OutputFileKind {
    | entry_point
    | chunk
    | asset
    | bytecode
    | sourcemap
    | module_info
    | metafile_json
    | metafile_markdown
}

/// 输出文件索引
public class OutputFileIndex {
    public var value: UInt32 = UInt32(0)
    public init() {}
    public init(v: UInt32) { value = v }
    public func get(): UInt32 { value }
    public func getOrThrow(): Int64 { Int64(value) }
}

// OpaqueFileId — bundler 使用的文件标识符
public class OpaqueFileId {
    public var value: UInt32 = UInt32(0)
    public init() {}
    public init(v: UInt32) { value = v }
    public func get(): UInt32 { value }
    public func getOrThrow(): Int64 { Int64(value) }
}

/// AutoBitSet — 跟踪已加载文件
public class AutoBitSet {
    public var bits: Array<Bool> = []
    public init() {}
    public static func initEmpty(a: Allocator, b: Int64): AutoBitSet { AutoBitSet() }
    public func isSet(i: UInt32): Bool {
        if (Int64(i) < bits.size) { return bits[Int64(i)] } else { return false }
    }
    public func set(i: UInt32): Unit {
        while (Int64(i) >= bits.size) {
            bits = Array<Bool>(bits.size + 64, { idx => if (idx < bits.size) { bits[idx] } else { false } })
        }
        bits[Int64(i)] = true
    }
}

/// StringArrayHashMapUnmanaged — 字符串数组哈希映射
public class StringArrayHashMapUnmanaged<V> {
    private var data: HashMap<String, V> = HashMap<String, V>()
    public init() {}
    public func put(k: String, v: V): Unit { data.put(k, v) }
    public func get(k: String): ?V { data.get(k) }
}

/// HotReloadMode — 热重载模式
public enum HotReloadMode {
    | none
    | watch
}

/// HotReloadMode 比较扩展
public func hotReloadModeEq(a: HotReloadMode, b: HotReloadMode): Bool {
    match (a) {
        case HotReloadMode.none => match (b) { case HotReloadMode.none => true case _ => false }
        case HotReloadMode.watch => match (b) { case HotReloadMode.watch => true case _ => false }
    }
}

/// OfflineMode — 离线模式
public enum OfflineMode { | online | offline | latest }

/// MimallocArena — Mimalloc 内存区域分配器
public class MimallocArena {
    public init() {}
    public func allocator(): Allocator { Allocator() }
    public func deinit(): Unit {}
}

/// MAX_U32 已在文件顶部定义

/// EntryPointMap — 入口点映射表
/// 生产 bundle 生成后，预渲染需要查找与每个路由的 OpaqueFileId 关联的生成 chunk
public class EntryPointMap {
    public var root: String
    public var allocator: Allocator
    public var files: HashMap<String, Any>
    private var file_list: ArrayList<EntryPointMapInputFile>
    private var file_values: ArrayList<OutputFileIndex>

    public init(root: String, allocator: Allocator, files: HashMap<String, Any>) {
        this.root = root
        this.allocator = allocator
        this.files = files
        this.file_list = ArrayList<EntryPointMapInputFile>()
        this.file_values = ArrayList<OutputFileIndex>()
    }

    /// 获取或创建入口点
    public func getOrPutEntryPoint(abs_path: String, side: Side): OpaqueFileId {
        let key = abs_path + ":" + match (side) { case client => "client" case server => "server" }
        var idx = file_list.size
        file_list.append(EntryPointMapInputFile(abs_path, side))
        file_values.append(OutputFileIndex())
        return OpaqueFileId(UInt32(idx))
    }

    /// 获取文件数量
    public func fileCount(): Int64 { file_list.size }

    /// 获取所有输入文件
    public func inputFiles(): Array<EntryPointMapInputFile> {
        Array<EntryPointMapInputFile>(file_list.size, { i => file_list[i] })
    }

    /// 获取所有文件值（可变引用）
    public func fileValues(): Array<OutputFileIndex> {
        Array<OutputFileIndex>(file_values.size, { i => file_values[i] })
    }
}

public class EntryPointMapInputFile {
    public var abs_path_ptr: String
    public var abs_path_len: UInt32
    public var side: Side

    public init(abs_path: String, side: Side) {
        this.abs_path_ptr = abs_path
        this.abs_path_len = UInt32(abs_path.size)
        this.side = side
    }

    public func absPath(): String {
        abs_path_ptr
    }
}

/// PerThread — 每个渲染线程使用的数据
/// 包含渲染所需的 bundle 中的所有信息
public class PerThread {
    // 共享数据
    public var input_files: Array<EntryPointMapInputFile>
    public var bundled_outputs: Array<OutputFile>
    public var output_indexes: Array<OutputFileIndex>
    public var module_keys: Array<BunString>
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
        module_keys: Array<BunString>,
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

    /// 从 Options 初始化
    public func initFromOptions(vm: VirtualMachine, opts: PerThreadOptions): Unit {
        input_files = opts.input_files
        bundled_outputs = opts.bundled_outputs
        output_indexes = opts.output_indexes
        module_keys = opts.module_keys
        module_map = opts.module_map
        source_maps = opts.source_maps
        loaded_files = AutoBitSet.initEmpty(vm.allocator, output_indexes.size)
        all_server_files = JsValue.createEmptyArray(vm.global.globalThis, output_indexes.size)
    }

    /// 附加到全局对象
    public func attach(): Unit {
        BakeGlobalObjectAttachPerThreadData(vm.global, this)
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
        if (!loaded_files.isSet(UInt32(id.getOrThrow()))) {
            loaded_files.set(UInt32(id.getOrThrow()))
            all_server_files.putIndex(
                vm.global.globalThis,
                UInt32(id.getOrThrow()),
                module_keys[id.getOrThrow()].toJS(vm.global),
            )
        }
        return JsValue.jsNumberFromInt32(Int32(id.getOrThrow()))
    }

    public func deinit(): Unit {
        BakeGlobalObjectAttachPerThreadData(vm.global, Option<PerThread>.None)
    }
}

/// 附加 PerThread 数据到全局对象
func BakeGlobalObjectAttachPerThreadData(global: JSGlobalObject, pt: ?PerThread): Unit {
    // 实际实现需要 JSC 全局对象集成
}

/// PerThreadOptions — 发送到其他线程进行渲染的选项
public class PerThreadOptions {
    public var input_files: Array<EntryPointMapInputFile> = Array<EntryPointMapInputFile>()
    public var bundled_outputs: Array<OutputFile> = Array<OutputFile>()
    public var output_indexes: Array<OutputFileIndex> = Array<OutputFileIndex>()
    public var module_keys: Array<BunString> = Array<BunString>()
    public var module_map: StringArrayHashMapUnmanaged<OutputFileIndex> = StringArrayHashMapUnmanaged<OutputFileIndex>()
    public var source_maps: StringArrayHashMapUnmanaged<OutputFileIndex> = StringArrayHashMapUnmanaged<OutputFileIndex>()
}

/// BundleV2 Bake 生产构建选项 — 使用 bao_bundler.BakeOptions

/// FileSystem 扩展方法 — writeToDisk 和 ensureDir
/// FileSystem 主类定义在 stubs.cj，此处仅添加扩展方法
public func fileSystemWriteFile(path: String, content: String): Unit {
    // 实际文件写入由运行时 I/O 层实现
}

public func fileSystemEnsureDir(path: String): Unit {
    // 实际目录创建由运行时 I/O 层实现
}
