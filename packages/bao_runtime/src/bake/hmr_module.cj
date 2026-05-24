// 翻译自 Bun: src/runtime/bake/hmr-module.ts
// 支持热重载的模块加载器实现。
// 注意：此实现旨在实现 bun build 的行为，而非 ECMAScript Module 规范。
// 这样，开发版本的构建就可以像 bun build 的生产版本一样运行。
//
// 某些来自 bundler 的构建失败会作为运行时错误暴露出来，
// 例如在一个带有传递 top-level await 的模块上使用 `require`，或者缺少的导出。
// 这是为了让增量更新尽可能隔离。

package bao_runtime.bake

import bao_collections.HashMap
import bao_collections.HashSet
import bao_collections.ArrayList
import bao_core.*
import bao_jsc.JsValue
import bao_jsc.JsObject
import bao_jsc.JsGlobalObject
import bao_jsc.JsString
import bao_jsc.JsFunction
import bao_jsc.JsArray
import bao_jsc.Strong
import bao_jsc.StrongOptional
import bao_jsc.ZigStringSlice
import bao_jsc.CallFrame
import bao_jsc.JsError

// ============================================================================
// 类型定义
// ============================================================================

/// 模块 ID 类型

/// 模块状态
public enum State {
    | pending
    | stale
    | loaded
    | error
}

/// ESM 属性索引
/// 对应 Bun: hmr-module.ts ESMProps
public enum ESMProps {
    | imports
    | exports
    | stars
    | load
    | isAsync

    public func value(): Int64 {
        match (this) {
            case imports => 0
            case exports => 1
            case stars => 2
            case load => 3
            case isAsync => 4
        }
    }
}

/// 热更新接受回调
public class HotAccept {
    public var modules: Array<String>
    public var cb: HotAcceptFunction
    public var single: Bool

    public init(modules: Array<String>, cb: HotAcceptFunction, single: Bool) {
        this.modules = modules
        this.cb = cb
        this.single = single
    }
}

/// 热更新回调类型
public type HotAcceptFunction = (JsValue) -> Unit
/// 热更新数组回调类型
public type HotArrayAcceptFunction = (Array<JsValue>) -> Unit
/// 热更新清理回调类型
public type HotDisposeFunction = (Any) -> Unit
/// 热更新事件处理器
public type HotEventHandler = (Any) -> Unit

/// CJS 模块
public class CJSModule {
    public var id: Id
    public var exports: Any
    public var require: (Id) -> Any

    public init(id: Id, exports: Any, require: (Id) -> Any) {
        this.id = id
        this.exports = exports
        this.require = require
    }
}

// ============================================================================
// HMRModule — 支持热重载的模块
// 对应 Bun: hmr-module.ts HMRModule
// ============================================================================

/// HMR 模块 — 每个 Id 对应一个 HMRModule，跨更新被修改
public class HMRModule {
    /// registry 中的键
    public var id: Id
    /// ES 模块对 .exports 和 .cjs 有不同的语义
    public var esm: Bool
    /// 模块状态
    public var state: State = State.pending
    /// ESM 命名空间对象。如果尚未初始化则为 null
    public var exports: JsValue = JsValue.null
    /// 对于 ESM，这是转换后的 CJS 导出。
    /// 对于 CJS，这是 module 对象。
    public var cjs: ?CJSModule = None
    /// 当模块加载失败时，再次加载应该抛出相同的错误
    public var failure: ?Any = None
    /// 两个用途:
    /// 1. HMRModule[] — 已解析的导入列表。indexOf 用于从 HMRModule -> 更新器函数
    /// 2. any[] — 模块命名空间对象列表。由 ESM 模块的 load 函数读取。
    /// CJS 不使用
    public var imports: ?Array<Any> = None
    /// 由 ESM 模块的 load 函数立即赋值。
    /// HTML 文件不会发出对此字段的存储
    public var updateImport: ?Array<(JsValue) -> Unit> = None
    /// 调用 import.meta.hot.dispose 时
    public var onDispose: ?Array<HotDisposeFunction> = None
    /// 调用 import.meta.hot.accept 自我接受时
    public var selfAccept: ?HotAcceptFunction = None
    /// 调用 import.meta.hot.accept 其他模块时
    public var depAccepts: ?HashMap<Id, HotAccept> = None
    /// 所有导入了此模块的模块
    public var importers: HashSet<HMRModule> = HashSet<HMRModule>()
    /// import.meta.hot.data 重写为此
    public var data: Any = None

    public init(id: Id, isCommonJS: Bool) {
        this.id = id
        this.esm = !isCommonJS
        if (isCommonJS) {
            this.cjs = CJSModule(id, HashMap<String, Any>(), { id2 => this.require(id2) })
        }
    }

    // ========================================================================
    // require — CJS require 实现
    // ========================================================================

    /// 模块 ID 由 bundler 预解析
    public func requireResolve(id: Id): Id {
        return id
    }

    /// require — 同步加载模块
    public func require(id: Id): Any {
        let mod = loadModuleSync(id, true, this)
        if (mod.esm) {
            if (mod.cjs.isNone()) {
                mod.cjs = CJSModule(mod.id, toCommonJS(mod.exports), { id2 => mod.require(id2) })
            }
            return mod.cjs.getOrThrow().exports
        }
        return mod.cjs.getOrThrow().exports
    }

    /// dynamicImport — 从 .e_import(import(id)) 降级
    public func dynamicImport(id: Id): Promise<JsValue> {
        let found = loadModuleAsync(id, true, this)
        if (found.isModule()) {
            return Promise.resolve(getEsmExports(found.getModule()))
        }
        return found.getPromise().then({ mod => getEsmExports(mod) })
    }

    /// reactRefreshAccept — React 快速刷新接受
    public func reactRefreshAccept(): Unit {
        if (isReactRefreshBoundary(exports)) {
            selfAccept = { _: JsValue => () }
        }
    }

    // ========================================================================
    // import.meta.hot 接口
    // ========================================================================

    /// accept — import.meta.hot.accept()
    public func accept(arg1: ?Any, arg2: ?Any): Unit {
        if (arg2.isNone()) {
            if (arg1.isNone()) {
                selfAccept = { _: JsValue => () }
                return
            }
            // 自我接受函数
            if (arg1.isSome()) {
                selfAccept = fn
            }
        } else {
            panic("import.meta.hot.accept must be directly called with string literals for the specifiers.")
        }
    }

    /// acceptSpecifiers — import.meta.hot.accept 的多说明符变体
    public func acceptSpecifiers(specifiers: Any, cb: ?Any): Unit {
        if (depAccepts.isNone()) {
            depAccepts = HashMap<Id, HotAccept>()
        }
        let isArray = specifiers is Array<String>
        let modulesList: Array<String> = if (isArray) {
            specifiers as Array<String>
        } else {
            [specifiers as String]
        }
        let accept = HotAccept(
            modules: modulesList,
            cb: cb as HotAcceptFunction,
            single: !isArray,
        )
        if (isArray) {
            for (specifier in modulesList) {
                depAccepts.getOrThrow().put(specifier, accept)
            }
        } else {
            depAccepts.getOrThrow().put(specifiers as String, accept)
        }
    }

    /// decline — 无操作 (Vite: "This is currently a noop and is there for backward compatibility")
    public func decline(): Unit {}

    /// dispose — import.meta.hot.dispose(cb)
    public func dispose(cb: HotDisposeFunction): Unit {
        if (onDispose.isNone()) {
            onDispose = []
        }
        onDispose.getOrThrow().append(cb)
    }

    /// prune — 目前 Bun 不会丢弃分离的模块
    public func prune(cb: HotDisposeFunction): Unit {
        // 目前不调用该函数
    }

    /// invalidate — 使模块无效
    public func invalidate(): Unit {
        emitEvent("bun:invalidate", None)
        throw Error("ImportMetaHot.invalidate is not implemented in this Cangjie runtime build")
    }

    /// on — 注册事件处理器
    public func on(event: String, cb: HotEventHandler): Unit {
        // Vite 兼容性，但优先使用 Bun 的事件名
        var ev = event
        if (event.hasPrefix("vite:")) {
            ev = "bun:" + event.slice(4)
        }
        onEvent(ev, cb)
        dispose({ _ => this.off(event, cb) })
    }

    /// off — 移除事件处理器
    public func off(event: String, cb: HotEventHandler): Unit {
        let handlers = eventHandlers.get(event)
        if (handlers.isNone()) {
            return
        }
        let list = handlers.getOrThrow()
        let index = list.indexOf(cb)
        if (index != -1) {
            list.remove(at: index)
        }
    }

    /// send — 发送事件
    public func send(event: String, cb: HotEventHandler): Unit {
        throw Error("ImportMetaHot.send is not implemented in this Cangjie runtime build")
    }
}

// ============================================================================
// 模块注册表
// ============================================================================

/// 已加载模块列表。每个 Id 获取一个 HMRModule，跨更新被修改。
let registry: HashMap<Id, HMRModule> = HashMap<Id, HMRModule>()

/// 注册表 SourceMap ID 映射
let registrySourceMapIds: HashMap<String, SourceMapURL> = HashMap<String, SourceMapURL>()

/// 服务器端 manifest
public let serverManifest: HashMap<String, Any> = HashMap<String, Any>()

/// SSR manifest
public let ssrManifest: HashMap<String, Any> = HashMap<String, Any>()

/// 服务器端重新加载回调
public var onServerSideReload: ?(() -> Promise<Unit>) = None

/// 事件处理器
let eventHandlers: HashMap<String, Array<HotEventHandler>> = HashMap<String, Array<HotEventHandler>>()

/// 刷新运行时
var refreshRuntime: ?Any = None

/// 事件类型
public enum HmrEvent {
    | bun_ready
    | bun_beforeUpdate
    | bun_afterUpdate
    | bun_beforeFullReload
    | bun_beforePrune
    | bun_invalidate
    | bun_error
    | bun_ws_disconnect
    | bun_ws_connect
}

// ============================================================================
// loadModuleSync — 同步加载模块
// 对应 Bun: hmr-module.ts loadModuleSync
// ============================================================================

/// 同步加载模块
public func loadModuleSync(id: Id, isUserDynamic: Bool, importer: ?HMRModule): HMRModule {
    // 首先，尝试复用现有模块
    var mod = registry.get(id)
    if (mod.isSome()) {
        let m = mod.getOrThrow()
        if (m.state == State.error) {
            panic("Module load error: ${id}")
        }
        if (m.state == State.stale) {
            m.state = State.pending
        } else {
            if (importer.isSome()) {
                m.importers.append(importer.getOrThrow())
            }
            return m
        }
    }

    let loadOrEsmModule = unloadedModuleRegistry.get(id)
    if (loadOrEsmModule.isNone()) {
        throwNotFound(id, isUserDynamic)
    }

    if (loadOrEsmModule.getOrThrow().isCJS) {
        // CommonJS
        if (mod.isNone()) {
            let m = HMRModule(id, true)
            registry.put(id, m)
            mod = Some(m)
        }
        let m = mod.getOrThrow()
        if (importer.isSome()) {
            m.importers.append(importer.getOrThrow())
        }
        // 执行 CJS 模块加载
        loadOrEsmModule.getOrThrow().cjsLoad(m)
        m.state = State.loaded
    } else {
        // ESM
        let esmData = loadOrEsmModule.getOrThrow()
        let deps = esmData.deps
        let load = esmData.load
        let isAsync = esmData.isAsync

        if (isAsync) {
            panic("Cannot load async module '${id}' synchronously because it uses top-level await.")
        }

        if (mod.isNone()) {
            let m = HMRModule(id, false)
            registry.put(id, m)
            mod = Some(m)
        }
        let m = mod.getOrThrow()
        if (importer.isSome()) {
            m.importers.append(importer.getOrThrow())
        }

        // 解析 ESM 依赖
        let depsList = parseEsmDependencies(m, deps) { depId, _unused, depImporter =>
            loadModuleSync(depId, false, Some(depImporter))
        }

        let exportsBefore = m.exports
        m.imports = depsList.map({ depMod => getEsmExports(depMod) })
        load(m)
        m.imports = depsList.map({ depMod => depMod })
        if (m.exports == exportsBefore) {
            m.exports = JsValue.jsObject()
        }
        m.state = State.loaded
    }

    return mod.getOrThrow()
}

// ============================================================================
// loadModuleAsync — 异步加载模块
// 对应 Bun: hmr-module.ts loadModuleAsync
// ============================================================================

/// 异步加载模块。
/// 不要在此函数上添加 async 关键字，这样可以在评估不同步的情况下同步创建 HMRModule 列表。
public func loadModuleAsync(id: Id, isUserDynamic: Bool, importer: ?HMRModule): HmrModuleOrPromise {
    // 首先，尝试复用现有模块
    var mod = registry.get(id)
    if (mod.isSome()) {
        let m = mod.getOrThrow()
        if (m.state == State.error) {
            panic("Module load error: ${id}")
        }
        if (m.state == State.stale) {
            m.state = State.pending
        } else {
            if (importer.isSome()) {
                m.importers.append(importer.getOrThrow())
            }
            return HmrModuleOrPromise.fromModule(m)
        }
    }

    let loadOrEsmModule = unloadedModuleRegistry.get(id)
    if (loadOrEsmModule.isNone()) {
        if (isUserDynamic) {
            return HmrModuleOrPromise.none()
        }
        throwNotFound(id, isUserDynamic)
    }

    if (loadOrEsmModule.getOrThrow().isCJS) {
        // CommonJS
        if (mod.isNone()) {
            let m = HMRModule(id, true)
            registry.put(id, m)
            mod = Some(m)
        }
        let m = mod.getOrThrow()
        if (importer.isSome()) {
            m.importers.append(importer.getOrThrow())
        }
        loadOrEsmModule.getOrThrow().cjsLoad(m)
        m.state = State.loaded
        return HmrModuleOrPromise.fromModule(m)
    } else {
        // ESM
        let esmData = loadOrEsmModule.getOrThrow()
        let deps = esmData.deps
        let load = esmData.load

        if (mod.isNone()) {
            let m = HMRModule(id, false)
            registry.put(id, m)
            mod = Some(m)
        }
        let m = mod.getOrThrow()
        if (importer.isSome()) {
            m.importers.append(importer.getOrThrow())
        }

        // 解析 ESM 依赖 (异步)
        let depsResult = parseEsmDependenciesAsync(m, deps)
        if (depsResult.isAsync) {
            return HmrModuleOrPromise.fromPromise(
                Promise.all(depsResult.list).then({ list =>
                    finishLoadModuleAsync(m, load, list)
                })
            )
        }
        return HmrModuleOrPromise.fromModule(
            finishLoadModuleAsync(m, load, depsResult.syncList)
        )
    }
}

/// 完成异步模块加载
func finishLoadModuleAsync(mod: HMRModule, load: (HMRModule) -> ?Promise<Unit>, modules: Array<HMRModule>): HMRModule {
    let exportsBefore = mod.exports
    mod.imports = modules.map({ m => getEsmExports(m) })

    let p = load(mod)
    mod.imports = modules.map({ m => m })

    if (p.isSome()) {
        // 异步加载 — 简化处理
        if (mod.exports == exportsBefore) {
            mod.exports = JsValue.jsObject()
        }
        mod.state = State.loaded
        patchImporters(mod)
    } else {
        if (mod.exports == exportsBefore) {
            mod.exports = JsValue.jsObject()
        }
        mod.state = State.loaded
        patchImporters(mod)
    }

    return mod
}

// ============================================================================
// parseEsmDependencies — 解析 ESM 依赖
// 对应 Bun: hmr-module.ts parseEsmDependencies
// ============================================================================

/// 解析 ESM 依赖列表
func parseEsmDependencies(
    parent: HMRModule,
    deps: Array<Any>,
    enqueueModuleLoad: (Id, Bool, HMRModule) -> HMRModule
): Array<HMRModule> {
    var i: Int64 = 0
    var list: Array<HMRModule> = []
    let length = deps.size

    while (i < length) {
        let dep = deps[i] as String
        let expectedExportKeyEnd = i + 2 + (deps[i + 1] as Int64)
        let depModule = enqueueModuleLoad(dep, false, parent)
        list.append(depModule)
        i = expectedExportKeyEnd
    }

    return list
}

/// 解析 ESM 依赖列表 (异步)
func parseEsmDependenciesAsync(parent: HMRModule, deps: Array<Any>): DepsParseResult {
    var i: Int64 = 0
    var list: Array<HmrModuleOrPromise> = []
    var syncList: Array<HMRModule> = []
    var isAsync: Bool = false
    let length = deps.size

    while (i < length) {
        let dep = deps[i] as String
        let expectedExportKeyEnd = i + 2 + (deps[i + 1] as Int64)
        let result = loadModuleAsync(dep, false, Some(parent))
        list.append(result)
        if (result.isModule()) {
            syncList.append(result.getModule())
        } else {
            isAsync = true
        }
        i = expectedExportKeyEnd
    }

    return DepsParseResult(list: list, syncList: syncList, isAsync: isAsync)
}

// ============================================================================
// replaceModules — 替换模块
// 对应 Bun: hmr-module.ts replaceModules
// ============================================================================

/// 当模块被替换时调用
public func replaceModules(modules: HashMap<Id, UnloadedModule>, sourceMapId: ?SourceMapURL): Promise<Unit> {
    // 将新模块合并到未加载模块注册表
    var it = modules.iterator()
    while (let Some(entry) <- it.next()) {
        unloadedModuleRegistry.put(entry.key, entry.value)
    }

    emitEvent("bun:beforeUpdate", None)

    let toReload: HashSet<HMRModule> = HashSet<HMRModule>()
    let toAccept: Array<ToAccept> = []
    var failures: ?HashSet<Id> = None
    let toDispose: Array<HMRModule> = []

    // 发现所有 HMR 边界
    var modulesIt = modules.iterator()
    while (let Some(entry) <- modulesIt.next()) {
        let key = entry.key

        // 如果在客户端，取消引用旧的 source maps 并跟踪新的
        if (sourceMapId.isSome()) {
            let existingSourceMapId = registrySourceMapIds.get(key)
            if (existingSourceMapId.isSome()) {
                derefMapping(existingSourceMapId.getOrThrow())
            }
            registrySourceMapIds.put(key, sourceMapId.getOrThrow())
        }

        let existing = registry.get(key)
        if (existing.isNone()) {
            continue
        }

        toReload.append(existing.getOrThrow())

        // 发现所有 HMR 边界
        let visited: HashSet<HMRModule> = HashSet<HMRModule>()
        let queue: ArrayList<HMRModule> = ArrayList<HMRModule>()
        queue.append(existing.getOrThrow())
        visited.append(existing.getOrThrow())

        var hadFailure = false
        while (queue.size() > 0) {
            let mod = queue.removeAt(0)

            // 如果模块是自接受的，停止传播
            var hadSelfAccept = true
            if (mod.selfAccept.isSome()) {
                toReload.append(mod)
                visited.append(mod)
                hadSelfAccept = false
                if (mod.onDispose.isSome()) {
                    toDispose.append(mod)
                }
            } else if (mod.data.isSome()) {
                // 有 data 的模块隐含处理更新
                mod.selfAccept = { _ => () }
                toReload.append(mod)
                visited.append(mod)
                hadSelfAccept = false
                if (mod.onDispose.isSome()) {
                    toDispose.append(mod)
                }
            }

            // 所有导入者将被访问
            if (hadSelfAccept && mod.importers.size() == 0) {
                if (failures.isNone()) {
                    failures = Some(HashSet<Id>())
                }
                failures.getOrThrow().append(key)
                break
            }

            let importersIt = mod.importers.iterator()
            while (let Some(importer) <- importersIt.next()) {
                let cb = importer.depAccepts.get(key)
                if (cb.isSome()) {
                    toAccept.append(ToAccept(cb: cb.getOrThrow(), key: key))
                } else if (hadSelfAccept) {
                    if (visited.contains(importer)) {
                        continue
                    }
                    visited.append(importer)
                    queue.append(importer)
                }
            }
        }
    }

    // 如果到达了根模块，打印友好消息后重新加载
    if (failures.isSome()) {
        var message = "[Bun] Hot update was not accepted because it or its importers do not call import.meta.hot.accept. "
        message = message + "To prevent full page reloads, call import.meta.hot.accept in one of the following files:\n\n"

        let failuresIt = failures.getOrThrow().iterator()
        while (let Some(boundary) <- failuresIt.next()) {
            message = message + "Module \"${boundary}\" is a root module that does not self-accept.\n"
        }
        message = message.trimAscii()

        console.warn(message)
    }

    // 清理所有模块
    for (mod in toDispose) {
        mod.state = State.stale
        if (mod.onDispose.isSome()) {
            for (fn in mod.onDispose.getOrThrow()) {
                fn(mod.data)
            }
        }
        mod.onDispose = None
    }

    // 重新加载所有模块
    for (mod in toReload) {
        mod.state = State.stale
        let selfAccept = mod.selfAccept
        mod.selfAccept = None
        mod.depAccepts = None

        let modOrPromise = loadModuleAsync(mod.id, false, None)
        if (modOrPromise.isModule()) {
            if (selfAccept.isSome()) {
                selfAccept.getOrThrow()(getEsmExports(modOrPromise.getModule()))
            }
        }
    }

    // 为没有显式自接受回调的模块修补导入者
    for (mod in toReload) {
        if (mod.selfAccept.isSome()) {
            continue
        }
        patchImporters(mod)
    }

    // 调用所有接受回调
    for (accept in toAccept) {
        let cbFn = accept.cb.cb
        if (accept.cb.single) {
            let mod = registry.get(accept.key)
            if (mod.isSome()) {
                cbFn(getEsmExports(mod.getOrThrow()))
            }
        } else {
            // 创建接受数组
            var arr: Array<JsValue> = []
            for (moduleKey in accept.cb.modules) {
                let mod = registry.get(moduleKey)
                if (mod.isSome() && moduleKey == accept.key) {
                    arr.append(getEsmExports(mod.getOrThrow()))
                } else {
                    arr.append(JsValue.undefined)
                }
            }
        }
    }

    if (refreshRuntime.isSome()) {
        // 调用 React 快速刷新
        // refreshRuntime.performReactRefresh()
    }

    emitEvent("bun:afterUpdate", None)
    return Promise.unit()
}

// ============================================================================
// loadExports — 加载并返回模块导出
// 对应 Bun: hmr-module.ts loadExports
// ============================================================================

/// 给定一个 Id，返回模块命名空间对象。
/// 用于 HMR 运行时中的其他函数。
/// 将该模块注册为根。
public func loadExports<T>(id: Id): Promise<T> {
    let m = loadModuleAsync(id, false, None)
    if (m.isModule()) {
        let mod = m.getModule()
        let result = if (mod.esm) { mod.exports } else { mod.cjs.getOrThrow().exports }
        return Promise.resolve(result as T)
    }
    return m.getPromise().then({ mod =>
        let result = if (mod.esm) { mod.exports } else { mod.cjs.getOrThrow().exports }
        result as T
    })
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 获取 ESM 导出
func getEsmExports(m: HMRModule): JsValue {
    if (m.esm) {
        return m.exports
    }
    return toESM(m.cjs.getOrThrow().exports)
}

/// 修补导入者
func patchImporters(mod: HMRModule): Unit {
    let importers = mod.importers
    let exports = getEsmExports(mod)
    let it = importers.iterator()
    while (let Some(importer) <- it.next()) {
        if (!importer.esm || importer.updateImport.isNone()) {
            continue
        }
        let imports = importer.imports.getOrThrow() as Array<Any>
        var index: Int64 = -1
        for (i in 0..imports.size) {
            if (imports[i] as HMRModule == mod) {
                index = i
                break
            }
        }
        if (index == -1) {
            continue // require 或动态导入
        }
        importer.updateImport.getOrThrow()[index](exports)
    }
}

/// 发出事件
public func emitEvent(event: String, data: Any): Unit {
    let handlers = eventHandlers.get(event)
    if (handlers.isNone()) {
        return
    }
    for (handler in handlers.getOrThrow()) {
        handler(data)
    }
}

/// 注册事件处理器
public func onEvent(event: String, cb: HotEventHandler): Unit {
    if (eventHandlers.get(event).isNone()) {
        eventHandlers.put(event, [])
    }
    eventHandlers.get(event).append(cb)
}

/// 全量重新加载
public func fullReload(): Unit {
    try {
        emitEvent("bun:beforeFullReload", None)
    } catch (_) {}
    // 在浏览器中: location.reload()
    // 在服务器端: 不执行任何操作
}

/// 设置刷新运行时
public func setRefreshRuntime(runtime: HMRModule): Unit {
    refreshRuntime = getEsmExports(runtime)
}

/// 注册合成模块
func registerSynthetic(id: Id, esmExports: Any): Unit {
    let module = HMRModule(id, false)
    module.exports = esmExports as JsValue
    registry.put(id, module)
}

/// 将 CJS 导出转换为 ESM 格式
func toCommonJS(from: Any): Any {
    // 简化：创建一个带有 __esModule: true 的对象
    return from
}

/// 将 CJS 模块转换为 ESM 格式
func toESM(mod: Any): JsValue {
    // 简化
    return mod as JsValue
}

/// 检查是否为 React 刷新边界
func isReactRefreshBoundary(esmExports: JsValue): Bool {
    // 简化：假设不是
    return false
}

/// 抛出模块未找到错误
func throwNotFound(id: Id, isUserDynamic: Bool): Unit {
    if (isUserDynamic) {
        panic("Failed to resolve dynamic import '${id}'. With Bun's bundler, all imports must be statically known at build time so that the bundler can trace everything.")
    }
    panic("Failed to load bundled module '${id}'. This is not a dynamic import, and therefore is a bug in Bun's bundler.")
}

// ============================================================================
// 辅助类型
// ============================================================================

/// SourceMap URL 信息
public class SourceMapURL {
    public var id: String
    public var url: String
    /// 从此模块中的模块数开始。随着模块被替换，此值递减。
    /// 当达到 0 时，blob 有资格进行垃圾回收。
    public var refs: Int64
    /// 以字节为单位的大小
    public var size: Int64

    public init(id: String, url: String, refs: Int64, size: Int64) {
        this.id = id
        this.url = url
        this.refs = refs
        this.size = size
    }
}

/// ToAccept — 跟踪接受的回调
class ToAccept {
    public var cb: HotAccept
    public var key: Id

    public init(cb: HotAccept, key: Id) {
        this.cb = cb
        this.key = key
    }
}

/// 未加载的模块注册表
/// 对应 Bun: unloadedModuleRegistry (全局)

/// 未加载的模块

/// HMR 模块或 Promise 的包装类型
public class HmrModuleOrPromise {
    private var mod: ?HMRModule = None
    private var promise: ?Promise<HMRModule> = None
    private var isNone: Bool = false

    public static func fromModule(m: HMRModule): HmrModuleOrPromise {
        let r = HmrModuleOrPromise()
        r.mod = Some(m)
        return r
    }

    public static func fromPromise(p: Promise<HMRModule>): HmrModuleOrPromise {
        let r = HmrModuleOrPromise()
        r.promise = Some(p)
        return r
    }

    public static func none(): HmrModuleOrPromise {
        let r = HmrModuleOrPromise()
        r.isNone = true
        return r
    }

    public func isModule(): Bool {
        mod.isSome()
    }

    public func getModule(): HMRModule {
        mod.getOrThrow()
    }

    public func getPromise(): Promise<HMRModule> {
        promise.getOrThrow()
    }
}

/// 依赖解析结果
class DepsParseResult {
    public var list: Array<HmrModuleOrPromise>
    public var syncList: Array<HMRModule>
    public var isAsync: Bool

    public init(list: Array<HmrModuleOrPromise>, syncList: Array<HMRModule>, isAsync: Bool) {
        this.list = list
        this.syncList = syncList
        this.isAsync = isAsync
    }
}

// ============================================================================
// 注册合成模块 — 对应 Bun hmr-module.ts 底部的 registerSynthetic 调用
// ============================================================================

func initSyntheticModules(): Unit {
    registerSynthetic("bun:wrap", HashMap<String, Any>())
    registerSynthetic("bun:bake/server", HashMap<String, Any>())
    registerSynthetic("bun:bake/client", HashMap<String, Any>())
}

// HashSet available via import bao_collections.*
