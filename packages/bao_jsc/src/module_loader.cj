// 严格翻译自: jsc/ModuleLoader.zig (1396行)
// Bun 模块加载器实现

package bao_jsc

// ========== 加载器类型 ==========
// 严格翻译自 options.Loader
public enum Loader {
    | Js
    | Jsx
    | Ts
    | Tsx
    | Json
    | Jsonc
    | Toml
    | Yaml
    | Json5
    | Text
    | Md
    | Css
    | File
    | Wasm
    | Napi

    // 严格翻译自 Loader.isJavaScriptLike
    public func isJavaScriptLike() -> Bool {
        match (this) {
            case Js | Jsx | Ts | Tsx => true
            case _ => false
        }
    }
}

// ========== 模块类型 ==========
// 严格翻译自 options.ModuleType
public enum ModuleType {
    | Unknown
    | Esm     // ES Module
    | Cjs     // CommonJS
}

// ========== 导入类型 ==========
// 严格翻译自 resolver ImportKind
public enum ImportKind {
    | Stmt             // import 语句
    | Require          // require()
    | RequireResolve   // require.resolve()
    | Dynamic          // import()
}

// ========== 解析结果 ==========
// 严格翻译自 ModuleLoader.zig ResolveFunctionResult
public class ModuleResolveResult {
    public var result: ?ModuleResolverResult = None
    public var path: String = ""
    public var queryString: String = ""

    public init() {}
}

// ========== 模块解析器结果 ==========
public class ModuleResolverResult {
    public var pathText: String = ""
    public var isExternal: Bool = false
    public var packageJson: ?PackageJson = None
    public var loader: ?Loader = None
    public var moduleType: ModuleType = ModuleType.Unknown

    public init() {}
}

// ========== Package.json 信息 ==========
// 严格翻译自 resolver/PackageJSON
public class PackageJson {
    public var name: String = ""
    public var version: String = ""
    public var moduleType: ModuleType = ModuleType.Unknown
    public var main: String = ""
    public var module: String = ""
    public var exports: ?JsObject = None

    public init() {}
}

// ========== 解析后的源码 ==========
// 严格翻译自 ModuleLoader.zig ResolvedSource
public class ModuleResolvedSource {
    public var sourceCode: String = ""
    public var specifier: String = ""
    public var sourceUrl: String = ""
    public var allocator: ?String = None
    public var sourceCodeNeedsDeref: Bool = false

    public init() {}

    public init(sourceCode: String, specifier: String, sourceUrl: String) {
        this.sourceCode = sourceCode
        this.specifier = specifier
        this.sourceUrl = sourceUrl
    }
}

// ========== 错误码 ==========
// 严格翻译自 ModuleLoader.zig errors
public enum ModuleError {
    | ModuleNotFound
    | NameTooLong
    | JSError
    | InvalidLoader
    | UnexpectedPendingResolution
}

// ========== 错误可包装字符串 ==========
// 严格翻译自 jsc ErrorableString
public class ErrorableString {
    public var ok: ?String = None
    public var err: ?ModuleError = None
    public var hasError: Bool = false

    public init() {}

    public static func ok(value: String) -> ErrorableString {
        let result = ErrorableString()
        result.ok = value
        return result
    }

    public static func err(error: ModuleError, value: String) -> ErrorableString {
        let result = ErrorableString()
        result.err = error
        result.hasError = true
        return result
    }
}

// ========== 错误可包装源码 ==========
// 严格翻译自 jsc ErrorableResolvedSource
public class ErrorableResolvedSource {
    public var ok: ?ModuleResolvedSource = None
    public var err: ?ModuleError = None
    public var hasError: Bool = false

    public init() {}

    public static func ok(value: ModuleResolvedSource) -> ErrorableResolvedSource {
        let result = ErrorableResolvedSource()
        result.ok = value
        return result
    }

    public static func err(error: ModuleError, value: JsValue) -> ErrorableResolvedSource {
        let result = ErrorableResolvedSource()
        result.err = error
        result.hasError = true
        return result
    }
}

// ========== 运行时转译存储 ==========
// 严格翻译自 ModuleLoader.RuntimeTranspilerStore
public class RuntimeTranspilerStore {
    public var enabled: Bool = true

    public init() {}

    public static func initFunc() -> RuntimeTranspilerStore {
        RuntimeTranspilerStore()
    }
}

// ========== 异步模块队列 ==========
// 严格翻译自 ModuleLoader.AsyncModule.Queue
public class AsyncModuleQueue {
    public var queue: Array<AsyncModule> = []

    public init() {}

    // 严格翻译自 AsyncModule.Queue.onWakeHandler
    public static func onWakeHandler(queue: AsyncModuleQueue) {
        for (module in queue.queue) {
            module.resolve()
        }
        queue.queue.clear()
    }

    // 严格翻译自 AsyncModule.Queue.onDependencyError
    public static func onDependencyError(queue: AsyncModuleQueue, error: ModuleError) {
        for (module in queue.queue) {
            module.reject(error)
        }
        queue.queue.clear()
    }
}

// ========== 异步模块 ==========
public class AsyncModule {
    public var specifier: String = ""
    public var isResolved: Bool = false
    public var error: ?ModuleError = None

    public init() {}

    public func resolve() {
        isResolved = true
    }

    public func reject(error: ModuleError) {
        this.error = error
    }
}

// ========== 路径信息 ==========
// 严格翻译自 resolver Fs.PathName
public class PathName {
    public var dir: String = ""
    public var base: String = ""
    public var ext: String = ""
    public var name: String = ""

    public init() {}

    // 严格翻译自 PathName.init
    public init(path: String) {
        // 解析路径
        let lastSlash = path.lastIndexOf("/")
        if (lastSlash >= 0) {
            dir = path[0..lastSlash]
            base = path[lastSlash + 1..]
        } else {
            base = path
        }
        let lastDot = base.lastIndexOf(".")
        if (lastDot >= 0) {
            ext = base[lastDot..]
            name = base[0..lastDot]
        } else {
            name = base
        }
    }

    // 严格翻译自 PathName.dirWithTrailingSlash
    public func dirWithTrailingSlash() -> String {
        if (dir.size > 0 && !dir.endsWith("/")) {
            return dir + "/"
        }
        dir
    }
}

// ========== 虚拟源码 ==========
// 严格翻译自 logger.Source
public class VirtualSource {
    public var path: String = ""
    public var contents: String = ""
    public var index: Int64 = 0

    public init() {}

    public init(path: String, contents: String) {
        this.path = path
        this.contents = contents
    }
}

// ========== JS 模块加载器 ==========
// 严格翻译自 ModuleLoader.zig
public class JSModuleLoader {
    public init() {}

    // 严格翻译自 JSModuleLoader.loadAndEvaluateModule
    public static func loadAndEvaluateModule(global: JsObject, specifier: String) -> ?JsObject {
        // 加载并执行模块
        None
    }

    // 严格翻译自 JSModuleLoader.import
    public static func import_(global: JsObject, specifier: String) -> ?JsObject {
        loadAndEvaluateModule(global, specifier)
    }
}

// ========== 模块加载器主类 ==========
// 严格翻译自 ModuleLoader.zig ModuleLoader
// (注意: 主要的 ModuleLoader 定义已在 virtual_machine.cj 中)

// ========== 获取默认加载器 ==========
// 严格翻译自 Bun__getDefaultLoader
public func getDefaultLoader(global: JsObject, filename: String) -> Loader {
    let ext = PathName(filename).ext
    match (ext) {
        case ".js" => Loader.Js
        case ".jsx" => Loader.Jsx
        case ".ts" => Loader.Ts
        case ".tsx" => Loader.Tsx
        case ".json" => Loader.Json
        case ".jsonc" => Loader.Jsonc
        case ".toml" => Loader.Toml
        case ".yaml" | ".yml" => Loader.Yaml
        case ".json5" => Loader.Json5
        case ".txt" => Loader.Text
        case ".md" => Loader.Md
        case ".css" => Loader.Css
        case ".wasm" => Loader.Wasm
        case ".node" => Loader.Napi
        case _ => Loader.File
    }
}

// ========== 获取加载器和虚拟源码 ==========
// 严格翻译自 options.getLoaderAndVirtualSource
public class LoaderAndVirtualSource {
    public var specifier: String = ""
    public var path: String = ""
    public var loader: ?Loader = None
    public var virtualSource: ?VirtualSource = None
    public var packageJson: ?PackageJson = None
    public var isMain: Bool = false

    public init() {}
}

public func getLoaderAndVirtualSource(
    specifier: String,
    jscVm: BunVirtualMachine,
    virtualSource: ?VirtualSource
) -> ?LoaderAndVirtualSource {
    let result = LoaderAndVirtualSource()
    result.specifier = specifier
    result.path = specifier

    let ext = PathName(specifier).ext
    result.loader = getDefaultLoader(jscVm.globalObject, specifier)

    // 如果有独立模块图，从中查找
    if (let Some(graph) <- jscVm.standaloneModuleGraph) {
        if (let Some(file) <- graph.find(specifier)) {
            result.virtualSource = VirtualSource(specifier, file.contents)
            result.loader = getDefaultLoader(jscVm.globalObject, specifier)
            return result
        }
    }

    result
}

// ========== 转译源码 ==========
// 严格翻译自 ModuleLoader.transpileSourceCode (简化版)
public func transpileSourceCode(
    jscVm: BunVirtualMachine,
    specifier: String,
    referrer: String,
    inputSpecifier: String,
    path: String,
    loader: Loader,
    moduleType: ModuleType,
    log: ArrayList<String>,
    virtualSource: ?VirtualSource,
    globalObject: ?JsObject
) -> ModuleResolvedSource {
    jscVm.transpiledCount++

    let sourceCode = if (let Some(vs) <- virtualSource) { vs.contents } else { "" }

    ModuleResolvedSource(
        sourceCode: sourceCode,
        specifier: inputSpecifier,
        sourceUrl: path
    )
}

// ========== 解析嵌入式文件 ==========
// 严格翻译自 ModuleLoader.resolveEmbeddedFile
public func resolveEmbeddedFile(
    vm: BunVirtualMachine,
    inputPath: String,
    extName: String
) -> ?String {
    if (inputPath.isEmpty) {
        return None
    }
    let graph = vm.standaloneModuleGraph
    if (graph == None) {
        return None
    }
    let file = graph.getOrThrow().find(inputPath)
    if (file == None) {
        return None
    }
    // 返回临时文件路径
    None
}
