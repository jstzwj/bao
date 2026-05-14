// 热模块替换 — 文件监视与模块热重载
// 严格翻译自: src/runtime/ hot module replacement
//   Bun 支持通过 HMR (Hot Module Replacement) 实现开发时的模块热更新
//   仓颉通过 FileWatcher + ModuleReloader 实现等价功能
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*
import bao_threading.*

// ============================================================================
// HotModuleState — 热模块状态
// ============================================================================

/// 热模块状态
public enum HotModuleState {
    | Active       // 模块活跃，可以被热更新
    | Accepted     // 模块已接受热更新
    | Declined     // 模块拒绝热更新
    | Disposed     // 模块已被销毁
    | Error        // 模块出错
}

// ============================================================================
// HotAcceptDecline — 热更新接受/拒绝标记
// 对应 Bun: import.meta.hot.accept / import.meta.hot.decline
// ============================================================================

/// 热更新回调类型
public type HotUpdateCallback = (HashMap<String, JsValue>) -> Unit

/// 热更新接受/拒绝记录
/// 对应 Bun: import.meta.hot.accept(cb)
public class HotAcceptRecord {
    /// 模块路径
    public var modulePath: String
    /// 是否接受热更新
    public var accepted: Bool
    /// 接受回调
    public var acceptCallback: ?HotUpdateCallback
    /// 销毁回调
    public var disposeCallback: ?HotUpdateCallback
    /// 依赖的模块路径列表 (如果这些模块更新，需要通知本模块)
    public var deps: ArrayList<String>

    public init(modulePath: String) {
        this.modulePath = modulePath
        accepted = false
        acceptCallback = None
        disposeCallback = None
        deps = ArrayList<String>()
    }
}

// ============================================================================
// HotModuleInfo — 热模块信息
// 对应 Bun: 追踪可热更新的模块
// ============================================================================

/// 热模块信息 — 追踪单个模块的热更新状态
public class HotModuleInfo {
    /// 模块绝对路径
    public var path: String
    /// 模块 ID
    public var id: String
    /// 当前状态
    public var state: HotModuleState
    /// 上次修改时间戳
    public var lastModified: Float64
    /// 模块导出数据 (用于在热更新时保留状态)
    public var savedState: HashMap<String, JsValue>
    /// 接受记录
    public var acceptRecord: ?HotAcceptRecord
    /// 导入此模块的父模块列表
    public var importers: ArrayList<String>
    /// 此模块导入的子模块列表
    public var importedModules: ArrayList<String>
    /// 模块版本号 (每次更新递增)
    public var version: Int64

    public init(path: String) {
        this.path = path
        this.id = path
        state = HotModuleState.Active
        lastModified = 0.0
        savedState = HashMap<String, JsValue>()
        acceptRecord = None
        importers = ArrayList<String>()
        importedModules = ArrayList<String>()
        version = 0
    }
}

// ============================================================================
// HotModuleRegistry — 热模块注册表
// 对应 Bun: 追踪所有可热更新的模块
// ============================================================================

/// 热模块注册表 — 追踪所有注册了热更新的模块
/// 对应 Bun: HMR 注册表
public class HotModuleRegistry {
    /// 已注册的模块 (path -> HotModuleInfo)
    private var modules: HashMap<String, HotModuleInfo>
    /// 模块依赖图 (被依赖 -> 依赖者列表)
    private var dependencyGraph: HashMap<String, ArrayList<String>>
    /// 是否启用
    public var enabled: Bool

    public init() {
        modules = HashMap<String, HotModuleInfo>()
        dependencyGraph = HashMap<String, ArrayList<String>>()
        enabled = true
    }

    /// 注册模块 - 对应 Bun HMR 注册模块
    public func register(modulePath: String): HotModuleInfo {
        match (modules.get(modulePath)) {
            case Some(info) => return info
            case None => {
                let info = HotModuleInfo(modulePath)
                info.lastModified = currentTimeMillis()
                modules.put(modulePath, info)
                return info
            }
        }
    }

    /// 取消注册模块
    public func unregister(modulePath: String): Unit {
        modules.remove(modulePath)
        dependencyGraph.remove(modulePath)
        // 从其他模块的 importers 中移除
        for (key in modules.keys()) {
            match (modules.get(key)) {
                case Some(info) =>
                    let newImporters = ArrayList<String>()
                    for (imp in info.importers) {
                        if (imp != modulePath) {
                            newImporters.append(imp)
                        }
                    }
                    info.importers = newImporters
                case None => ()
            }
        }
    }

    /// 获取模块信息
    public func get(modulePath: String): ?HotModuleInfo {
        return modules.get(modulePath)
    }

    /// 标记模块接受热更新 - 对应 import.meta.hot.accept()
    public func accept(modulePath: String, callback: ?HotUpdateCallback): Unit {
        let info = register(modulePath)
        let record = HotAcceptRecord(modulePath)
        record.accepted = true
        record.acceptCallback = callback
        info.acceptRecord = Some(record)
        info.state = HotModuleState.Accepted
    }

    /// 标记模块拒绝热更新 - 对应 import.meta.hot.decline()
    public func decline(modulePath: String): Unit {
        let info = register(modulePath)
        let record = HotAcceptRecord(modulePath)
        record.accepted = false
        info.acceptRecord = Some(record)
        info.state = HotModuleState.Declined
    }

    /// 注册销毁回调 - 对应 import.meta.hot.dispose(cb)
    public func dispose(modulePath: String, callback: HotUpdateCallback): Unit {
        let info = register(modulePath)
        match (info.acceptRecord) {
            case Some(record) => record.disposeCallback = Some(callback)
            case None => {
                let record = HotAcceptRecord(modulePath)
                record.disposeCallback = Some(callback)
                info.acceptRecord = Some(record)
            }
        }
    }

    /// 添加模块依赖关系
    public func addDependency(importer: String, imported: String): Unit {
        let importerInfo = register(importer)
        let importedInfo = register(imported)

        // 添加到导入列表
        if (!importerInfo.importedModules.contains(imported)) {
            importerInfo.importedModules.append(imported)
        }
        // 添加到被导入列表
        if (!importedInfo.importers.contains(importer)) {
            importedInfo.importers.append(importer)
        }

        // 更新依赖图
        match (dependencyGraph.get(imported)) {
            case Some(list) =>
                if (!list.contains(importer)) {
                    list.append(importer)
                }
            case None =>
                let list = ArrayList<String>()
                list.append(importer)
                dependencyGraph.put(imported, list)
        }
    }

    /// 获取受影响的模块列表 (当某个模块变更时，需要通知哪些模块)
    /// 对应 Bun HMR: 传播更新
    public func getAffectedModules(changedPath: String): ArrayList<String> {
        let affected = ArrayList<String>()
        affected.append(changedPath)

        // 递归查找所有依赖此模块的父模块
        collectImporters(changedPath, affected, 0)
        return affected
    }

    /// 递归收集导入者
    private func collectImporters(path: String, result: ArrayList<String>, depth: Int64): Unit {
        if (depth > 50) {
            return  // 防止无限递归
        }
        match (modules.get(path)) {
            case Some(info) =>
                for (importer in info.importers) {
                    if (!result.contains(importer)) {
                        result.append(importer)
                        collectImporters(importer, result, depth + 1)
                    }
                }
            case None => ()
        }
    }

    /// 获取所有已注册模块路径
    public func getAllPaths(): ArrayList<String> {
        return ArrayList<String>(modules.keys())
    }

    /// 清空注册表
    public func clear(): Unit {
        modules.clear()
        dependencyGraph.clear()
    }

    /// 获取注册模块数
    public func size(): Int64 {
        return modules.keys().size
    }

    /// 获取当前时间 (毫秒)
    private func currentTimeMillis(): Float64 {
        return bao_sys.SysModule.currentTimeMillis()
    }
}

// ============================================================================
// ModuleReloader — 模块重载器
// 对应 Bun: HMR 中的模块重新加载逻辑
// ============================================================================

/// 模块重载器 — 重新加载已修改的模块
/// 对应 Bun: HMR 模块重新加载引擎
public class ModuleReloader {
    /// 关联的虚拟机
    private var vm: VirtualMachine
    /// 模块注册表
    public var registry: HotModuleRegistry
    /// 文件读取函数
    private var readFileFn: (String) -> String

    public init(vm: VirtualMachine) {
        this.vm = vm
        registry = HotModuleRegistry()
        readFileFn = { path => BaoFile.readAllText(path) }
    }

    public init(vm: VirtualMachine, registry: HotModuleRegistry) {
        this.vm = vm
        this.registry = registry
        readFileFn = { path => BaoFile.readAllText(path) }
    }

    /// 重载指定模块 - 对应 Bun HMR 重新加载模块
    /// 返回重载后的新导出
    public func reloadModule(modulePath: String): ?JsValue {
        let info = registry.get(modulePath)
        if (info == None) {
            return None
        }
        let moduleInfo = info.unwrap()

        // 1. 检查模块是否接受热更新
        var canHotReload = false
        match (moduleInfo.acceptRecord) {
            case Some(record) =>
                if (record.accepted) {
                    canHotReload = true
                }
            case None => ()
        }

        if (!canHotReload) {
            // 模块不支持热更新，需要完整重载
            return fullReload(modulePath)
        }

        // 2. 调用 dispose 回调 (保存当前状态)
        match (moduleInfo.acceptRecord) {
            case Some(record) =>
                match (record.disposeCallback) {
                    Some(cb) =>
                        // 保存当前模块状态
                        cb(moduleInfo.savedState)
                    case None => ()
                }
            case None => ()
        }

        // 3. 读取新源码
        let newSource = readFileFn(modulePath)

        // 4. 重新编译并执行
        try {
            let result = vm.eval(newSource, modulePath)

            // 5. 更新模块信息
            moduleInfo.version += 1
            moduleInfo.lastModified = bao_sys.SysModule.currentTimeMillis()
            moduleInfo.state = HotModuleState.Accepted

            // 6. 调用 accept 回调 (传入新模块数据)
            match (moduleInfo.acceptRecord) {
                case Some(record) =>
                    match (record.acceptCallback) {
                        Some(cb) =>
                            let newState = HashMap<String, JsValue>()
                            newState.put("module", result)
                            cb(newState)
                        case None => ()
                    }
                case None => ()
            }

            return Some(result)
        } catch (e: Exception) {
            moduleInfo.state = HotModuleState.Error
            return None
        }
    }

    /// 完整重载 (不支持热更新的模块)
    private func fullReload(modulePath: String): ?JsValue {
        try {
            let source = readFileFn(modulePath)
            return Some(vm.eval(source, modulePath))
        } catch (_: Exception) {
            return None
        }
    }

    /// 批量重载受影响的模块
    /// 对应 Bun HMR: 当一个文件变更时，传播更新
    public func reloadAffected(changedPath: String): ArrayList<String> {
        let affected = registry.getAffectedModules(changedPath)
        let reloaded = ArrayList<String>()

        for (path in affected) {
            let result = reloadModule(path)
            if (result != None) {
                reloaded.append(path)
            }
        }

        return reloaded
    }
}

// ============================================================================
// HotReloader — 热重载器主类
// 对应 Bun: HMR 主控制器
// ============================================================================

/// 热重载器 — 集成文件监视与模块重载
/// 对应 Bun: HMR 完整实现
///   Bun 使用 FSEvents/inotify 监视文件变化
///   检测到变化后重新加载受影响的模块
public class HotReloader {
    /// 虚拟机
    private var vm: VirtualMachine
    /// 文件监视器
    private var watcher: ?FileWatcher
    /// 模块重载器
    public var reloader: ModuleReloader
    /// 模块注册表
    public var registry: HotModuleRegistry
    /// 监视的目录列表
    private var watchedDirs: ArrayList<String>
    /// 是否正在运行
    private var running: Bool
    /// 文件变化回调
    public var onChangeFn: ?(String, ArrayList<String>) -> Unit
    /// 错误回调
    public var onErrorFn: ?(String, String) -> Unit
    /// 变更事件监听器列表
    private var listeners: ArrayList<(FileWatchEvent) -> Unit>
    /// 轮询间隔 (毫秒)
    public var pollInterval: Float64

    public init(vm: VirtualMachine) {
        this.vm = vm
        watcher = None
        registry = HotModuleRegistry()
        reloader = ModuleReloader(vm, registry)
        watchedDirs = ArrayList<String>()
        running = false
        onChangeFn = None
        onErrorFn = None
        listeners = ArrayList<(FileWatchEvent) -> Unit>()
        pollInterval = 100.0
    }

    /// 启动热重载 - 对应 Bun HMR 启动
    public func start(directories: ArrayList<String>): Unit {
        if (running) {
            return
        }

        // 创建文件监视器
        let watcherResult = FileWatcher.create()
        match (watcherResult) {
            case SysMaybe.Ok(w) =>
                watcher = Some(w)
            case SysMaybe.Err(e) =>
                match (onErrorFn) {
                    case Some(cb) => cb("watcher", "Failed to create file watcher: ${e.code}")
                    case None => ()
                }
                return
        }

        // 添加监视目录
        let w = watcher.unwrap()
        for (dir in directories) {
            if (BaoFile.isDirectory(dir)) {
                w.watch(dir)
                watchedDirs.append(dir)
                watchRecursively(w, dir)
            }
        }

        running = true

        // 启动监视循环
        watchLoop()
    }

    /// 递归监视目录
    private func watchRecursively(w: FileWatcher, dir: String): Unit {
        let entries = BaoFile.readDir(dir)
        match (entries) {
            case Some(list) =>
                for (entry in list) {
                    let fullPath = dir + "/" + entry
                    if (BaoFile.isDirectory(fullPath)) {
                        // 跳过 node_modules, .git 等
                        if (entry != "node_modules" && entry != ".git" &&
                            entry != "dist" && entry != "build") {
                            w.watch(fullPath)
                            watchRecursively(w, fullPath)
                        }
                    }
                }
            case None => ()
        }
    }

    /// 监视循环
    private func watchLoop(): Unit {
        match (watcher) {
            case Some(w) =>
                while (running) {
                    let events = w.readEvents()
                    if (events.size > 0) {
                        handleEvents(events)
                    }
                    // 简短休眠避免 busy-loop
                    bao_sys.SysModule.sleep(Int64(pollInterval))
                }
            case None => ()
        }
    }

    /// 处理文件变化事件
    private func handleEvents(events: ArrayList<FileWatchEvent>): Unit {
        let changedModules = ArrayList<String>()

        for (event in events) {
            // 只处理 .js, .ts 等源码文件
            if (isSourceFile(event.fileName)) {
                // 检查是否是已注册的模块
                match (registry.get(event.fileName)) {
                    case Some(_) =>
                        if (!changedModules.contains(event.fileName)) {
                            changedModules.append(event.fileName)
                        }
                    case None => ()
                }

                // 通知监听器
                for (listener in listeners) {
                    listener(event)
                }
            }
        }

        // 重载受影响的模块
        if (changedModules.size > 0) {
            for (changed in changedModules) {
                let reloaded = reloader.reloadAffected(changed)
                match (onChangeFn) {
                    case Some(cb) => cb(changed, reloaded)
                    case None => ()
                }
            }
        }
    }

    /// 停止热重载
    public func stop(): Unit {
        running = false
        match (watcher) {
            case Some(w) =>
                w.close()
                watcher = None
            case None => ()
        }
    }

    /// 添加变更监听器
    public func onChange(listener: (FileWatchEvent) -> Unit): Unit {
        listeners.append(listener)
    }

    /// 手动触发重载 (用于测试或外部触发)
    public func triggerReload(modulePath: String): ?JsValue {
        return reloader.reloadModule(modulePath)
    }

    /// 注册模块为可热更新
    public func registerModule(modulePath: String): HotModuleInfo {
        return registry.register(modulePath)
    }

    /// 注册模块并标记接受热更新
    public func acceptModule(modulePath: String, callback: ?HotUpdateCallback): Unit {
        registry.accept(modulePath, callback)
    }

    /// 注册模块并标记拒绝热更新
    public func declineModule(modulePath: String): Unit {
        registry.decline(modulePath)
    }

    /// 判断是否为源码文件
    private func isSourceFile(path: String): Bool {
        let lower = path.toLower()
        return lower.endsWith(".js") || lower.endsWith(".ts") ||
               lower.endsWith(".jsx") || lower.endsWith(".tsx") ||
               lower.endsWith(".mjs") || lower.endsWith(".cjs")
    }

    /// 将热更新 API 导出为 JsValue (供 import.meta.hot 使用)
    public func toJsValue(modulePath: String): JsValue {
        let obj = JsObject()
        let hot = this
        let path = modulePath

        // import.meta.hot.accept(cb)
        obj.set("accept", JsValue.nativeFunction(JsNativeFunction("accept") { args =>
            hot.acceptModule(path, None)
            return JsValue.UNDEFINED
        }))

        // import.meta.hot.decline()
        obj.set("decline", JsValue.nativeFunction(JsNativeFunction("decline") { _ =>
            hot.declineModule(path)
            return JsValue.UNDEFINED
        }))

        // import.meta.hot.dispose(cb)
        obj.set("dispose", JsValue.nativeFunction(JsNativeFunction("dispose") { args =>
            hot.registry.dispose(path) { _ => }
            return JsValue.UNDEFINED
        }))

        // import.meta.hot.data — 持久化数据
        let info = hot.registry.register(path)
        let dataObj = JsObject()
        for (key in info.savedState.keys()) {
            match (info.savedState.get(key)) {
                case Some(v) => dataObj.set(key, v)
                case None => ()
            }
        }
        obj.set("data", JsValue(dataObj))

        // import.meta.hot.id
        obj.set("id", JsValue(BaoString(path)))

        return JsValue(obj)
    }
}

/// HotReload 模块导出
public class HotReloadModule {
    /// 创建热重载器
    public static func create(vm: VirtualMachine): HotReloader {
        return HotReloader(vm)
    }

    /// 将 HMR API 导出为 JsValue
    public static func toJsValue(): JsValue {
        let obj = JsObject()
        obj.set("create", JsValue.nativeFunction(JsNativeFunction("create") { _ =>
            return JsValue.UNDEFINED
        }))
        return JsValue(obj)
    }
}
