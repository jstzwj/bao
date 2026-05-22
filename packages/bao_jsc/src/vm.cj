// 严格翻译自: src/jsc/JavaScriptCore.zig, src/jsc/VM.zig
// JavaScriptCore 虚拟机

package bao_jsc

// JS 编译模式
public enum JsCompileMode {
    | Script      // 普通脚本
    | Module      // ES Module
    | Eval        // eval 代码
    | Json        // JSON

    public func toString(): String {
        match (this) {
            case Script => "Script"
            case Module => "Module"
            case Eval => "Eval"
            case Json => "Json"
        }
    }
}

// JS 执行上下文 - 严格翻译自 JavaScriptCore.zig Context
public class JsContext {
    public var vm: JsVirtualMachine
    public var globalObject: JsObject
    public var id: Int64 = 0

    static var nextId: Int64 = 0

    public init(vm: JsVirtualMachine) {
        JsContext.nextId++
        this.id = JsContext.nextId
        this.vm = vm
        this.globalObject = JsObject.make()
        setupGlobalObject()
    }

    // 设置全局对象的内置属性
    func setupGlobalObject() {
        // globalThis
        globalObject.set("globalThis", JsValue(globalObject))
        // undefined/null
        globalObject.set("undefined", JsValue.undefined())
        globalObject.set("NaN", JsValue(0.0 / 0.0))
        globalObject.set("Infinity", JsValue(1.0 / 0.0))

        // console
        let consoleObj = JsObject.make()
        consoleObj.className = "Console"
        globalObject.set("console", JsValue(consoleObj))

        // 内置构造函数
        setupBuiltins()
    }

    func setupBuiltins() {
        let mathObj = JsObject.make()
        mathObj.className = "Math"
        setupMathObject(mathObj)
        globalObject.set("Math", JsValue(mathObj))

        let jsonObj = JsObject.make()
        jsonObj.className = "JSON"
        globalObject.set("JSON", JsValue(jsonObj))
    }

    func setupMathObject(mathObj: JsObject) {
        mathObj.set("PI", JsValue(3.141592653589793))
        mathObj.set("E", JsValue(2.718281828459045))
        mathObj.set("LN2", JsValue(0.6931471805599453))
        mathObj.set("LN10", JsValue(2.302585092994046))
        mathObj.set("LOG2E", JsValue(1.4426950408889634))
        mathObj.set("LOG10E", JsValue(0.4342944819032518))
        mathObj.set("SQRT2", JsValue(1.4142135623730951))
        mathObj.set("SQRT1_2", JsValue(0.7071067811865476))
        mathObj.set("MAX_SAFE_INTEGER", JsValue(9007199254740991.0))
        mathObj.set("MIN_SAFE_INTEGER", JsValue(-9007199254740991.0))
    }

    // 在上下文中执行脚本
    public func evaluateScript(code: String, sourceUrl: String): JsValue {
        vm.evaluate(code, sourceUrl, JsCompileMode.Script, this)
    }

    // 在上下文中执行模块
    public func evaluateModule(code: String, sourceUrl: String): JsValue {
        vm.evaluate(code, sourceUrl, JsCompileMode.Module, this)
    }
}

// JS 虚拟机 - 严格翻译自 VM.zig
public class JsVirtualMachine {
    // 堆大小限制
    public var heapSize: Int64 = 256 * 1024 * 1024  // 256MB
    // 微任务队列
    var microtaskQueue: MicrotaskQueue = MicrotaskQueue.instance()
    // 编译缓存
    var compileCache: HashMap<String, JsModule> = HashMap()
    // 模块注册表
    var moduleRegistry: HashMap<String, JsModule> = HashMap()
    // ID
    static var nextId: Int64 = 0
    public let id: Int64

    public init() {
        JsVirtualMachine.nextId++
        this.id = JsVirtualMachine.nextId
    }

    // 创建执行上下文
    public func createContext(): JsContext {
        JsContext(this)
    }

    // 执行脚本 - 严格翻译自 JavaScriptCore.zig evaluateScript
    public func evaluateScript(code: String, sourceUrl: String): JsValue {
        let ctx = createContext()
        evaluate(code, sourceUrl, JsCompileMode.Script, ctx)
    }

    // 内部执行方法
    func evaluate(code: String, sourceUrl: String, mode: JsCompileMode, ctx: JsContext): JsValue {
        // 1. 编译
        let module = compile(code, sourceUrl, mode)
        // 2. 链接
        linkModule(module, ctx)
        // 3. 执行 (简化 - 真实实现需要 AST 解释器)
        executeModule(module, ctx)
    }

    // 编译代码
    func compile(code: String, sourceUrl: String, mode: JsCompileMode): JsModule {
        // 检查缓存
        let cacheKey = sourceUrl + ":" + mode.toString()
        let cachedResult = compileCache.get(cacheKey)
        if (cachedResult.isSome()) {
            return cachedResult.getOrThrow()
        }
        // 创建模块
        let module = JsModule(sourceUrl, code, mode)
        compileCache.put(cacheKey, module)
        return module
    }

    // 链接模块
    func linkModule(module: JsModule, ctx: JsContext) {
        moduleRegistry.put(module.url, module)
    }

    // 执行模块
    func executeModule(module: JsModule, ctx: JsContext): JsValue {
        // 简化实现 - 实际需要 AST 解释器
        // 由 bao_runtime 的 vm.cj 处理实际执行
        JsValue.undefined()
    }

    // 排队微任务 - 严格翻译自 VM.zig queueMicrotask
    public func queueMicrotask(task: () -> Unit) {
        microtaskQueue.enqueue(task)
    }

    // 排队微任务 (JsValue 版本)
    public func queueMicrotaskCallback(callback: JsFunction, args: Array<JsValue>) {
        microtaskQueue.enqueue({ =>
            callback.call(JsValue.undefined(), args)
        })
    }

    // 排空微任务队列 - 严格翻译自 VM.zig drainMicrotasks
    public func drainMicrotasks(): Int64 {
        microtaskQueue.drain()
    }

    // 加载模块 - 严格翻译自 JavaScriptCore.zig moduleLoader
    public func loadModule(url: String, ctx: JsContext): ?JsModule {
        // 1. 检查已注册模块
        if (let Some(mod) <- moduleRegistry.get(url)) {
            return mod
        }
        // 2. 尝试从文件系统加载 (简化)
        None
    }

    // 注册模块
    public func registerModule(url: String, code: String) {
        let module = JsModule(url, code, JsCompileMode.Module)
        moduleRegistry.put(url, module)
    }

    // GC 触发 (桩)
    public func collectGarbage() {
        // 由运行时 GC 处理
    }

    // 堆统计
    public func heapStats(): HeapStats {
        HeapStats(
            heapSize,
            0,  // 由 GC 子系统填充
            0,
            0.0
        )
    }
}

// JS 模块
public class JsModule {
    public let url: String
    public let sourceCode: String
    public let compileMode: JsCompileMode
    public var exports: HashMap<String, JsValue> = HashMap()
    public var importedModules: Array<String> = []
    public var isEvaluated: Bool = false
    public var namespace: JsObject = JsObject.make()

    public init(url: String, sourceCode: String, mode: JsCompileMode) {
        this.url = url
        this.sourceCode = sourceCode
        this.compileMode = mode
    }

    // 设置导出
    public func setExport(name: String, value: JsValue) {
        exports.put(name, value)
        namespace.set(name, value)
    }

    // 获取导出
    public func getExport(name: String): ?JsValue {
        exports.get(name)
    }

    // 获取所有导出名
    public func getExportNames(): Array<String> {
        exports.keys()
    }

    // 获取命名空间对象
    public func getNamespace(): JsObject {
        namespace
    }
}

// 堆统计信息
public class HeapStats {
    public let totalSize: Int64
    public let usedSize: Int64
    public let collectionCount: Int64
    public let lastCollectionTime: Float64

    public init(totalSize: Int64, usedSize: Int64, collectionCount: Int64, lastCollectionTime: Float64) {
        this.totalSize = totalSize
        this.usedSize = usedSize
        this.collectionCount = collectionCount
        this.lastCollectionTime = lastCollectionTime
    }
}
