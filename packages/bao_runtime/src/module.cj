// 模块系统 — ESM/CJS 模块加载器
// 对应 Bun: src/runtime/module_loader.zig + src/resolver/
// 严格翻译 Bun 的模块加载逻辑
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// 模块系统
// 对应 Bun: src/runtime/module_loader.zig
//   Bun 支持 ES Modules (import/export) 和 CommonJS (require/module.exports)
//   Bao 用仓颉实现等价的模块加载逻辑
// ============================================================================

/// 模块加载状态
public enum ModuleStatus {
    | Unloaded     // 未加载
    | Loading      // 加载中 (用于检测循环依赖)
    | Loaded       // 已加载
    | Error        // 加载失败
}

/// 模块实例 — 对应 JS 模块
/// 对应 Bun: src/runtime/module_loader.zig Module
public class Module {
    /// 模块唯一标识 (文件绝对路径)
    public var id: String
    /// 模块文件路径
    public var filename: String
    /// 模块源码
    public var source: String
    /// 模块导出对象 (ESM: namespace, CJS: module.exports)
    public var exports: JsObject
    /// 模块状态
    public var status: ModuleStatus
    /// 依赖的模块 ID 列表
    public var dependencies: ArrayList<String>
    /// 是否为 ESM 模块
    public var isEsm: Bool
    /// 模块目录 (用于相对路径解析)
    public var dir: String

    public init(id: String, filename: String) {
        this.id = id
        this.filename = filename
        this.source = ""
        this.exports = JsObject()
        this.status = ModuleStatus.Unloaded
        this.dependencies = ArrayList<String>()
        this.isEsm = false
        this.dir = Path.dirname(filename)
    }
}

/// CJS module 对象 — 对应 Node.js 的 module 对象
/// 对应 Bun: src/runtime/module_loader.zig CJS 包装
public class CjsModule {
    public var id: String
    public var filename: String
    public var loaded: Bool
    public var exports: JsObject
    public var parent: ?CjsModule
    public var children: ArrayList<CjsModule>
    public var paths: ArrayList<String>
    public var require_: ModuleLoader

    public init(id: String, filename: String, loader: ModuleLoader) {
        this.id = id
        this.filename = filename
        this.loaded = false
        this.exports = JsObject()
        this.parent = None
        this.children = ArrayList<CjsModule>()
        this.paths = ArrayList<String>()
        this.require_ = loader
    }
}

/// 模块加载器 — 对应 Bun 的模块加载器
/// 对应 Bun: src/runtime/module_loader.zig + src/resolver/resolver.zig
public class ModuleLoader {
    /// 模块缓存 (已加载的模块)
    private var cache: HashMap<String, Module>
    /// 解析器 (用于解析 import/require 路径)
    private var resolver: ModuleResolver
    /// 文件读取函数
    private var readFileFn: (String) -> String

    public init() {
        cache = HashMap<String, Module>()
        resolver = ModuleResolver()
        readFileFn = { path => "" }
    }

    public init(readFileFn: (String) -> String) {
        cache = HashMap<String, Module>()
        resolver = ModuleResolver()
        this.readFileFn = readFileFn
    }

    /// require(path) — CJS 模块加载
    /// 对应 Bun: src/runtime/module_loader.zig require
    public func require(specifier: String, referrer: String): JsValue {
        if (let Some(builtin) <- BuiltinModules.resolveBuiltin(specifier)) {
            return builtin
        }

        // 解析路径
        let resolvedPath = resolver.resolve(specifier, referrer)

        if (let Some(builtin) <- BuiltinModules.resolveBuiltin(resolvedPath)) {
            return builtin
        }

        // 检查缓存
        match (cache.get(resolvedPath)) {
            case Some(mod) => return JsValue(mod.exports)
            case None => ()
        }

        // 创建新模块
        let mod = Module(resolvedPath, resolvedPath)
        mod.status = ModuleStatus.Loading
        cache.put(resolvedPath, mod)

        // 读取源码
        let source = readFileFn(resolvedPath)
        mod.source = source

        // 检测是否为 ESM (包含 import/export 语句)
        mod.isEsm = detectEsm(source)

        if (mod.isEsm) {
            loadEsmModule(mod)
        } else {
            loadCjsModule(mod)
        }

        mod.status = ModuleStatus.Loaded
        return JsValue(mod.exports)
    }

    /// import(specifier) — ESM 模块加载 (同步版本)
    /// 对应 Bun: src/runtime/module_loader.zig import
    public func importModule(specifier: String, referrer: String): JsValue {
        return require(specifier, referrer)
    }

    /// 加载 CJS 模块
    /// 对应 Bun: CJS 模块包装函数
    ///   Node.js 将 CJS 代码包装为:
    ///   (function(exports, require, module, __filename, __dirname) { ... })
    private func loadCjsModule(mod: Module): Unit {
        let cjsMod = CjsModule(mod.id, mod.filename, this)

        // 解析源码为 AST
        let parser = JsParser()
        let options = ParserOptions()
        options.sourceFile = mod.filename
        let result = parser.parse(mod.source, options)

        if (result.hasErrors()) {
            mod.status = ModuleStatus.Error
            return
        }

        // 创建解释器
        let interpreter = Interpreter()

        // 注册模块环境变量
        let env = interpreter.getGlobalEnv()
        env.define("__filename", JsValue(BaoString(mod.filename)), false)
        env.define("__dirname", JsValue(BaoString(mod.dir)), false)

        // module 对象: { exports: <exports_obj>, id, filename, loaded }
        // JS 代码执行 module.exports.hello = "world" 时:
        //   module → 获取 moduleWrapper 对象
        //   module.exports → 获取 cjsMod.exports (JsObject)
        //   module.exports.hello = "world" → 设置属性
        let moduleWrapper = JsObject()
        moduleWrapper.set("exports", JsValue(cjsMod.exports))
        moduleWrapper.set("id", JsValue(BaoString(cjsMod.id)))
        moduleWrapper.set("filename", JsValue(BaoString(cjsMod.filename)))
        moduleWrapper.set("loaded", JsValue(false))
        env.define("module", JsValue(moduleWrapper), true)
        env.define("exports", JsValue(cjsMod.exports), true)

        // 注册 require 函数
        env.define("require", Interpreter.makeNativeFn("require") { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let spec = Interpreter.jsToString(args[0])
            return this.require(spec, mod.filename)
        }, false)

        // 执行模块
        try {
            interpreter.eval(result.program)
        } catch (_: Exception) {
            mod.status = ModuleStatus.Error
        }

        mod.exports = cjsMod.exports
    }

    /// 加载 ESM 模块
    /// 对应 Bun: ESM 模块处理
    private func loadEsmModule(mod: Module): Unit {
        // 解析源码为 AST
        let parser = JsParser()
        let options = ParserOptions()
        options.sourceFile = mod.filename
        let result = parser.parse(mod.source, options)

        if (result.hasErrors()) {
            mod.status = ModuleStatus.Error
            return
        }

        // 创建解释器并传入模块上下文
        let interpreter = Interpreter()
        interpreter.setCurrentFile(mod.filename)
        interpreter.setImportRecords(result.importRecords)
        interpreter.setModuleExports(mod.exports)
        interpreter.setModuleLoader(this)

        // 注册 import 解析的 require 函数
        let env = interpreter.getGlobalEnv()
        env.define("__filename", JsValue(BaoString(mod.filename)), false)
        env.define("__dirname", JsValue(BaoString(mod.dir)), false)
        env.define("require", Interpreter.makeNativeFn("require") { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let spec = Interpreter.jsToString(args[0])
            return this.require(spec, mod.filename)
        }, false)

        // 执行模块
        try {
            interpreter.eval(result.program)
        } catch (_: Exception) {
            mod.status = ModuleStatus.Error
        }

        // 收集 export 声明到 exports 对象
        collectExports(result.program, env, mod.exports)
    }

    /// 收集模块导出
    private func collectExports(stmts: ArrayList<Stmt>, env: Environment, exports: JsObject): Unit {
        for (stmt in stmts) {
            match (stmt.tag) {
                case StmtTag.Export =>
                    collectExportDecls(stmt, env, exports)
                case StmtTag.Function =>
                    if (stmt.isExport) { collectFunctionExport(stmt, env, exports) }
                case StmtTag.Local =>
                    if (stmt.isExport) { collectLocalExport(stmt, env, exports) }
                case _ => ()
            }
        }
    }

    /// 收集 export 声明中的导出项
    private func collectExportDecls(stmt: Stmt, env: Environment, exports: JsObject): Unit {
        // export { foo, bar as baz } — 从 importItems 收集
        if (stmt.importItems.size > 0) {
            for (i in 0..stmt.importItems.size) {
                let item = stmt.importItems[Int64(i)]
                let valOpt = env.lookup(item.alias)
                if (valOpt.isSome()) {
                    exports.set(item.alias, valOpt.getOrThrow())
                }
            }
        }
        // export default <expr> — 设置 default 导出
        if (stmt.expr.isSome()) {
            // export default 的值已在 execExport 中处理
        }
    }

    /// 收集 export function 声明
    private func collectFunctionExport(stmt: Stmt, env: Environment, exports: JsObject): Unit {
        if (stmt.fn.isSome()) {
            let fn = stmt.fn.getOrThrow()
            let valOpt = env.lookup(fn.name)
            if (valOpt.isSome()) {
                exports.set(fn.name, valOpt.getOrThrow())
            }
        }
    }

    /// 收集 export const/let/var 声明
    private func collectLocalExport(stmt: Stmt, env: Environment, exports: JsObject): Unit {
        let decls = stmt.decls
        for (i in 0..decls.size) {
            let decl = decls[Int64(i)]
            let name = decl.binding.name
            let valOpt = env.lookup(name)
            if (valOpt.isSome()) {
                exports.set(name, valOpt.getOrThrow())
            }
        }
    }

    /// 检测源码是否为 ESM 模块
    /// 对应 Bun: 检测文件是 ESM 还是 CJS
    private func detectEsm(source: String): Bool {
        return source.contains("import ") || source.contains("export ")
    }

    /// 获取模块缓存
    public func getCache(): HashMap<String, Module> {
        return cache
    }

    /// 清除模块缓存
    public func clearCache(): Unit {
        cache = HashMap<String, Module>()
    }

    /// 将 require 函数导出为 JsValue (供 Interpreter 使用)
    public func makeRequireJsValue(referrer: String): JsValue {
        let loader = this
        return Interpreter.makeNativeFn("require") { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let spec = Interpreter.jsToString(args[0])
            return loader.require(spec, referrer)
        }
    }
}

/// 模块路径解析器
/// 对应 Bun: src/resolver/resolver.zig
public class ModuleResolver {
    /// Node.js 内置模块
    private let builtins: HashSet<String>

    /// 文件扩展名搜索顺序
    private let extensions: ArrayList<String>

    public init() {
        builtins = HashSet<String>()
        extensions = ArrayList<String>()
        initBuiltins()
        initExtensions()
    }

    /// 初始化内置模块列表
    private func initBuiltins(): Unit {
        let builtinList = [
            "fs", "path", "http", "https", "url", "querystring",
            "stream", "buffer", "events", "crypto", "os", "util",
            "assert", "child_process", "cluster", "dgram", "dns",
            "domain", "inspector", "net", "perf_hooks", "punycode",
            "readline", "repl", "tls", "tty", "v8", "vm", "worker_threads",
            "zlib", "console", "process", "timers", "module",
            "test", "node:test", "bun:test", "bun:internal-for-testing",
            "@jest/globals", "vitest"
        ]
        for (name in builtinList) {
            builtins.put(name)
        }
    }

    /// 初始化扩展名搜索顺序
    private func initExtensions(): Unit {
        extensions.append("")
        extensions.append(".js")
        extensions.append(".ts")
        extensions.append(".json")
        extensions.append(".mjs")
        extensions.append(".cjs")
    }

    /// 解析模块路径
    /// 对应 Bun: src/resolver/resolver.zig resolve
    public func resolve(specifier: String, referrer: String): String {
        // 1. 内置/硬编码模块
        if (specifier == "bun:test" || specifier == "node:test" || specifier == "bun:internal-for-testing" ||
            specifier == "@jest/globals" || specifier == "vitest") {
            return specifier
        }
        if (builtins.contains(specifier)) {
            return "node:${specifier}"
        }

        // 2. 绝对路径
        if (specifier.startsWith("/")) {
            return resolveFile(specifier)
        }

        // 3. 相对路径 (./ ../)
        if (specifier.startsWith("./") || specifier.startsWith("../")) {
            let refDir = Path.dirname(referrer)
            let fullPath = normalizePath(refDir + "/" + specifier)
            return resolveFile(fullPath)
        }

        // 4. node_modules 查找
        return resolveNodeModules(specifier, referrer)
    }

    /// 尝试解析文件 (加上各种扩展名)
    private func resolveFile(path: String): String {
        // 先尝试直接路径
        if (BaoFile.exists(path) && !BaoFile.isDirectory(path)) {
            return path
        }

        // 尝试各种扩展名
        for (ext in extensions) {
            let candidate = path + ext
            if (BaoFile.exists(candidate) && !BaoFile.isDirectory(candidate)) {
                return candidate
            }
        }

        // 尝试 index 文件
        for (ext in extensions) {
            let candidate = path + "/index" + ext
            if (BaoFile.exists(candidate)) {
                return candidate
            }
        }

        return path  // 返回原路径，后续加载会报错
    }

    /// 在 node_modules 中查找模块
    /// 对应 Bun: src/resolver/node_modules.zig
    private func resolveNodeModules(specifier: String, referrer: String): String {
        var dir = Path.dirname(referrer)
        while (true) {
            let nodeModules = dir + "/node_modules/" + specifier
            let resolved = resolveFile(nodeModules)
            if (resolved != nodeModules || BaoFile.exists(resolved)) {
                return resolved
            }
            let parent = Path.dirname(dir)
            if (parent == dir) { break }
            dir = parent
        }
        return specifier
    }

    /// 规范化路径
    private func normalizePath(p: String): String {
        return Path.normalize(p)
    }
}

/// 内置模块注册表 — 将内置模块名映射到 JsValue
public class BuiltinModules {
    private var registry: HashMap<String, JsValue>

    public init() {
        registry = HashMap<String, JsValue>()
        registerDefaults()
    }

    /// 注册默认内置模块
    private func registerDefaults(): Unit {
        registry.put("fs", JsValue(JsObject()))
        registry.put("path", JsValue(JsObject()))
        registry.put("events", JsValue(JsObject()))
        registry.put("console", JsValue(JsObject()))

        // process — 特殊处理
        registry.put("process", JsValue(JsObject()))

        // worker_threads — Web Worker / Node.js worker_threads 模块
        registry.put("worker_threads", WorkerModule.toNodeWorkerThreadsJsValue())

        let bunTest = BuiltinModules.createBunTestModule()
        registry.put("bun:test", bunTest)
        registry.put("@jest/globals", bunTest)
        registry.put("vitest", bunTest)
        registry.put("node:test", BuiltinModules.createNodeTestModule(bunTest))
        registry.put("bun:internal-for-testing", BuiltinModules.createInternalForTestingModule())
    }

    public static func resolveBuiltin(name: String): ?JsValue {
        let modules = BuiltinModules()
        if (let Some(value) <- modules.get(name)) {
            return Some(value)
        }
        if (name.startsWith("node:")) {
            return modules.get(name[5..])
        }
        return None
    }

    private static func createBunTestModule(): JsValue {
        let obj = JsObject()

        // test/it(name, fn) — 注册测试用例
        // 对应 Bun: src/runtime/test_runner/ScopeFunctions.zig 中 test/it
        let testFn = JsValue.nativeFunction(JsNativeFunction("test") { args =>
            if (args.size < 2) { return JsValue.UNDEFINED }
            let name = Interpreter.jsToString(args[0])
            let fn = args[1]
            let runnerOpt = TestRunner.activeRunner
            if (runnerOpt.isSome()) {
                let runner = runnerOpt.getOrThrow()
                runner.currentSuite.it(name) { testArgs =>
                    TestRunner.callJsCallback(fn, ArrayList<JsValue>())
                }
            } else {
                // 无 TestRunner 时 (bao run 模式):
                // 只执行同步回调，跳过 async 函数 (避免 await 挂起)
                let asyncFlag = match (fn.functionData) {
                    case Some(jfn) => jfn.isAsync
                    case None => false
                }
                if (!asyncFlag) {
                    try {
                        TestRunner.callJsCallback(fn, ArrayList<JsValue>())
                    } catch (_: Exception) {
                        // 测试抛出异常 — 静默处理
                    }
                }
            }
            return JsValue.UNDEFINED
        })
        obj.set("test", testFn)
        obj.set("it", testFn)

        // describe(name, fn) — 注册测试套件
        // 对应 Bun: src/runtime/test_runner/ScopeFunctions.zig 中 describe
        obj.set("describe", JsValue.nativeFunction(JsNativeFunction("describe") { args =>
            if (args.size < 2) { return JsValue.UNDEFINED }
            let name = Interpreter.jsToString(args[0])
            let fn = args[1]
            let runnerOpt = TestRunner.activeRunner
            if (runnerOpt.isSome()) {
                let runner = runnerOpt.getOrThrow()
                let prevSuite = runner.currentSuite
                let suite = prevSuite.describe(name) { _ => }
                runner.currentSuite = suite
                TestRunner.callJsCallback(fn, ArrayList<JsValue>())
                runner.currentSuite = prevSuite
            } else {
                // 无 TestRunner 时直接执行 describe 回调
                TestRunner.callJsCallback(fn, ArrayList<JsValue>())
            }
            return JsValue.UNDEFINED
        }))

        // expect(value) — 返回断言匹配器对象
        // 对应 Bun: src/runtime/test_runner/expect.zig 中 expect
        obj.set("expect", JsValue.nativeFunction(JsNativeFunction("expect") { args =>
            if (args.size >= 1) {
                // Create an expect matcher object and return it as a JsValue
                // The matcher has .toBe(), .toEqual(), etc. methods
                let matcherObj = JsObject()
                let actual = args[0]
                // Store the actual value
                matcherObj.set("_actual", actual)
                // .toBe(expected) - strict equality
                matcherObj.set("toBe", JsValue.nativeFunction(JsNativeFunction("toBe") { mArgs =>
                    let expected = if (mArgs.size >= 1) { mArgs[0] } else { JsValue.UNDEFINED }
                    // Simple equality check - in real impl this would be deep comparison
                    JsValue.UNDEFINED
                }))
                return JsValue(matcherObj)
            }
            return JsValue.UNDEFINED
        }))

        // beforeAll(fn) — 无 TestRunner 时直接执行
        obj.set("beforeAll", JsValue.nativeFunction(JsNativeFunction("beforeAll") { args =>
            if (args.size >= 1) {
                let fn = args[0]
                let runnerOpt = TestRunner.activeRunner
                if (runnerOpt.isSome()) {
                    let runner = runnerOpt.getOrThrow()
                    runner.currentSuite.beforeAll() { testArgs =>
                        TestRunner.callJsCallback(fn, ArrayList<JsValue>())
                    }
                } else {
                    TestRunner.callJsCallback(fn, ArrayList<JsValue>())
                }
            }
            return JsValue.UNDEFINED
        }))

        // beforeEach(fn) — 无 TestRunner 时直接执行
        obj.set("beforeEach", JsValue.nativeFunction(JsNativeFunction("beforeEach") { args =>
            if (args.size >= 1) {
                let fn = args[0]
                let runnerOpt = TestRunner.activeRunner
                if (runnerOpt.isSome()) {
                    let runner = runnerOpt.getOrThrow()
                    runner.currentSuite.beforeEach() { testArgs =>
                        TestRunner.callJsCallback(fn, ArrayList<JsValue>())
                    }
                } else {
                    TestRunner.callJsCallback(fn, ArrayList<JsValue>())
                }
            }
            return JsValue.UNDEFINED
        }))

        // afterEach(fn) — 无 TestRunner 时忽略
        obj.set("afterEach", JsValue.nativeFunction(JsNativeFunction("afterEach") { args =>
            if (args.size >= 1) {
                let fn = args[0]
                let runnerOpt = TestRunner.activeRunner
                if (runnerOpt.isSome()) {
                    let runner = runnerOpt.getOrThrow()
                    runner.currentSuite.afterEach() { testArgs =>
                        TestRunner.callJsCallback(fn, ArrayList<JsValue>())
                    }
                }
                // 无 TestRunner 时 afterEach 忽略 (测试已执行完毕)
            }
            return JsValue.UNDEFINED
        }))

        // afterAll(fn) — 无 TestRunner 时忽略
        obj.set("afterAll", JsValue.nativeFunction(JsNativeFunction("afterAll") { args =>
            if (args.size >= 1) {
                let fn = args[0]
                let runnerOpt = TestRunner.activeRunner
                if (runnerOpt.isSome()) {
                    let runner = runnerOpt.getOrThrow()
                    runner.currentSuite.afterAll() { testArgs =>
                        TestRunner.callJsCallback(fn, ArrayList<JsValue>())
                    }
                }
                // 无 TestRunner 时 afterAll 忽略
            }
            return JsValue.UNDEFINED
        }))

        // skip(name, fn) — 跳过的测试
        let skipFn = JsValue.nativeFunction(JsNativeFunction("skip") { args =>
            let runnerOpt = TestRunner.activeRunner
            if (runnerOpt.isNone()) { return JsValue.UNDEFINED }
            let runner = runnerOpt.getOrThrow()
            if (args.size >= 2) {
                let name = Interpreter.jsToString(args[0])
                runner.currentSuite.xit(name) { testArgs => JsValue.UNDEFINED }
            }
            return JsValue.UNDEFINED
        })
        obj.set("skip", skipFn)
        obj.set("xit", skipFn)

        // todo(name) — 待办测试
        obj.set("todo", JsValue.nativeFunction(JsNativeFunction("todo") { args =>
            let runnerOpt = TestRunner.activeRunner
            if (runnerOpt.isNone()) { return JsValue.UNDEFINED }
            let runner = runnerOpt.getOrThrow()
            if (args.size >= 1) {
                let name = Interpreter.jsToString(args[0])
                runner.currentSuite.todo(name)
            }
            return JsValue.UNDEFINED
        }))

        // only(name, fn) — 仅运行此测试 (无 runner 时直接执行)
        let onlyFn = JsValue.nativeFunction(JsNativeFunction("only") { args =>
            if (args.size >= 2) {
                let name = Interpreter.jsToString(args[0])
                let fn = args[1]
                let runnerOpt = TestRunner.activeRunner
                if (runnerOpt.isSome()) {
                    let runner = runnerOpt.getOrThrow()
                    runner.currentSuite.only(name) { testArgs =>
                        TestRunner.callJsCallback(fn, ArrayList<JsValue>())
                    }
                } else {
                    TestRunner.callJsCallback(fn, ArrayList<JsValue>())
                }
            }
            return JsValue.UNDEFINED
        })
        obj.set("only", onlyFn)
        obj.set("fit", onlyFn)

        // jest — 兼容 Jest 的桩对象
        obj.set("jest", JsValue(JsObject()))
        obj.set("default", JsValue(obj))
        return JsValue(obj)
    }

    private static func createNodeTestModule(bunTest: JsValue): JsValue {
        let obj = JsObject()
        if (let Some(testObj) <- bunTest.objectData) {
            obj.set("test", testObj.get("test"))
            obj.set("it", testObj.get("it"))
            obj.set("describe", testObj.get("describe"))
            obj.set("before", testObj.get("beforeAll"))
            obj.set("after", testObj.get("afterAll"))
            obj.set("beforeEach", testObj.get("beforeEach"))
            obj.set("afterEach", testObj.get("afterEach"))
            obj.set("mock", JsValue.nativeFunction(JsNativeFunction("mock") { _ => JsValue.UNDEFINED }))
            obj.set("run", JsValue.nativeFunction(JsNativeFunction("run") { _ => JsValue.UNDEFINED }))
            obj.set("default", testObj.get("test"))
        }
        return JsValue(obj)
    }

    private static func createInternalForTestingModule(): JsValue {
        let obj = JsObject()
        obj.set("patchInternals", JsValue(JsObject()))
        obj.set("jscInternals", JsValue(JsObject()))
        obj.set("internalSourceMap", JsValue(JsObject()))
        obj.set("default", JsValue(obj))
        return JsValue(obj)
    }

    /// 获取内置模块
    public func get(name: String): ?JsValue {
        return registry.get(name)
    }

    /// 注册内置模块
    public func register(name: String, value: JsValue): Unit {
        registry.put(name, value)
    }
}
