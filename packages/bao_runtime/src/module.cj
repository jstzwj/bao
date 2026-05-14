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
        this.dir = PathModule.dirname(filename)
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
        readFileFn = { path => BaoFile.readAllText(path) }
    }

    public init(readFileFn: (String) -> String) {
        cache = HashMap<String, Module>()
        resolver = ModuleResolver()
        this.readFileFn = readFileFn
    }

    /// require(path) — CJS 模块加载
    /// 对应 Bun: src/runtime/module_loader.zig require
    public func require(specifier: String, referrer: String): JsValue {
        // 解析路径
        let resolvedPath = resolver.resolve(specifier, referrer)

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
        env.define("module", JsValue(cjsMod.exports), true)
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

        // 创建解释器
        let interpreter = Interpreter()

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
        // 简化: 将顶层声明作为导出
        collectExports(result.program, env, mod.exports)
    }

    /// 收集模块导出
    private func collectExports(stmts: ArrayList<Stmt>, env: Environment, exports: JsObject): Unit {
        for (stmt in stmts) {
            match (stmt.tag) {
                case StmtTag.Export => {
                    // export 声明
                    for (decl in stmt.decls) {
                        let name = decl.binding.name
                        match (env.lookup(name)) {
                            case Some(v) => exports.set(name, v)
                            case None => ()
                        }
                    }
                }
                case StmtTag.Function => {
                    // function 声明自动导出
                    if (stmt.fn != None) {
                        match (stmt.fn) {
                            case Some(fn) => {
                                match (env.lookup(fn.name)) {
                                    case Some(v) => exports.set(fn.name, v)
                                    case None => ()
                                }
                            }
                            case None => ()
                        }
                    }
                }
                case _ => ()
            }
        }
    }

    /// 检测源码是否为 ESM 模块
    /// 对应 Bun: 检测文件是 ESM 还是 CJS
    private func detectEsm(source: String): Bool {
        // 简化: 检测是否包含 import/export 关键字
        // 更精确的检测需要词法分析
        let lines = source.split("\n")
        for (line in lines) {
            let trimmed = line.trim()
            if (trimmed.startsWith("import ") || trimmed.startsWith("export ") ||
                trimmed == "import" || trimmed == "export") {
                return true
            }
        }
        return false
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
            "zlib", "console", "process", "timers", "module"
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
        // 1. 内置模块 → 返回 "node:${specifier}"
        if (builtins.contains(specifier)) {
            return "node:${specifier}"
        }

        // 2. 绝对路径
        if (specifier.startsWith("/")) {
            return resolveFile(specifier)
        }

        // 3. 相对路径 (./ ../)
        if (specifier.startsWith("./") || specifier.startsWith("../")) {
            let refDir = PathModule.dirname(referrer)
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
        var dir = PathModule.dirname(referrer)
        while (true) {
            let nodeModules = dir + "/node_modules/" + specifier
            let resolved = resolveFile(nodeModules)
            if (resolved != nodeModules || BaoFile.exists(resolved)) {
                return resolved
            }
            let parent = PathModule.dirname(dir)
            if (parent == dir) { break }
            dir = parent
        }
        return specifier
    }

    /// 规范化路径
    private func normalizePath(p: String): String {
        return PathModule.normalize(p)
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
        registry.put("fs", FsModule.toJsValue())
        registry.put("path", PathModule.toJsValue())
        registry.put("events", EventsModule.toJsValue())
        registry.put("console", ConsoleModule.toJsValue())

        // process — 特殊处理
        registry.put("process", ProcessModule.toJsValue())
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
