// bao_js - JavaScript 内置模块注册表和加载器
// 严格翻译自: src/js/lib.rs, src/js/builtins/*.ts, src/js/node/*.ts, src/js/internal/*.ts
//   Bun 的 js crate 管理所有 JavaScript 内置模块:
//   - ./node 包含所有 node:* 模块
//   - ./bun 包含所有 bun:* 模块
//   - ./thirdparty 包含替代的 npm 模块 (如 ws)
//   - ./internal 包含未分配给模块解析器的内部模块
//   每个 .ts/.js 文件在编译时分配一个数字 ID,
//   并内联到一个惰性初始化模块数组中。
package bao_js

import bao_core.*
import bao_jsc.*

// ============================================================================
// BuiltinModuleId - 内置模块 ID
// 严格翻译自: src/js/lib.rs + build/debug/codegen/generated.d.ts
//   每个内置模块在编译时分配一个数字 ID。
//   模块按 A-Z 顺序排列后分配递增 ID。
//   内部模块间引用通过 $requireId(n) 直接加载, 跳过解析器。
// ============================================================================

/// 内置模块 ID - 编译时分配的数字标识符
// 对应 Bun 中 $requireId(n) 使用的数字 ID
public enum BuiltinModuleId {
    | Id(Int32)  // 内置模块的数字 ID

    public func value(): Int32 {
        match (this) {
            case Id(v) => v
        }
    }
}

// ============================================================================
// BuiltinModuleKind - 内置模块种类
// 严格翻译自: src/js/README.md
//   - node:   node:* 模块 (fs, path, http, ...)
//   - bun:    bun:* 模块 (ffi, sqlite, sql, ...)
//   - internal: 内部模块 (不是模块解析器分配的)
//   - thirdparty: npm 替代模块 (ws, node-fetch, ...)
// ============================================================================

/// 内置模块种类
public enum BuiltinModuleKind {
    | Node        // node:* 模块
    | Bun         // bun:* 模块
    | Internal    // 内部模块
    | Thirdparty  // 第三方替代模块
}

// ============================================================================
// BuiltinModule - 内置模块描述
// 严格翻译自: src/js/README.md + build system
//   每个 .ts/.js 文件被预处理为一个 JS 函数:
//   - export default / export function -> return 语句
//   - require("module") -> $requireId(n)
//   - $ 前缀 -> __intrinsic__ -> @ (JSC intrinsics)
//
//   模块被包裹为:
//     $capture_start(function () {
//       const path = __intrinsic__requireId(23);
//       return { ... };
//     }).$capture_end;
// ============================================================================

/// 内置模块描述
public class BuiltinModule {
    /// 模块 ID (编译时分配)
    public let id: BuiltinModuleId

    /// 模块名称
    public let name: String

    /// 模块种类
    public let kind: BuiltinModuleKind

    /// 模块源码 (TypeScript/JavaScript)
    // 对应 Bun 中打包后的 JS 函数体
    public var source: String

    /// 是否已求值
    // 对应 Bun 中模块的惰性初始化状态
    public var evaluated: Bool

    /// 导出对象 (求值后填充)
    public var exports: ?AnyType

    public init(id: BuiltinModuleId, name: String, kind: BuiltinModuleKind, source: String) {
        this.id = id
        this.name = name
        this.kind = kind
        this.source = source
        this.evaluated = false
        this.exports = None
    }
}

// ============================================================================
// BuiltinRegistry - 内置模块注册表
// 严格翻译自: InternalModuleRegistry.cpp + src/js/README.md
//   在 Bun 中, 内置模块通过 createBuiltin 加载到 InternalModuleRegistry。
//   模块按数字 ID 索引, 惰性求值。
//   require("module") 被替换为 $getInternalField($internalModuleRegistry, <number>)
// ============================================================================

/// 内置模块注册表 - 管理所有内置模块的注册和加载
public class BuiltinRegistry {
    /// 模块 ID -> 模块映射
    private var modulesById: HashMap<Int32, BuiltinModule> = HashMap<Int32, BuiltinModule>()

    /// 模块名称 -> 模块映射
    private var modulesByName: HashMap<String, BuiltinModule> = HashMap<String, BuiltinModule>()

    /// Require 缓存映射
    // 对应 Bun JS 中的 $requireMap
    private var requireMap: HashMap<String, BuiltinModule> = HashMap<String, BuiltinModule>()

    public init() {}

    /// 注册内置模块
    public func register(module: BuiltinModule): Unit {
        modulesById.put(module.id.value(), module)
        modulesByName.put(module.name, module)
    }

    /// 通过 ID 获取模块
    // 对应 Bun: $getInternalField($internalModuleRegistry, id)
    public func getById(id: Int32): ?BuiltinModule {
        modulesById.get(id)
    }

    /// 通过名称获取模块
    // 对应 Bun: $requireMap.$get(name)
    public func getByName(name: String): ?BuiltinModule {
        modulesByName.get(name)
    }

    /// 解析模块名称
    // 对应 Bun: Loader.resolve(specifier, referrer)
    public func resolve(specifier: String, referrer: String): ?String {
        // 尝试直接匹配
        if (modulesByName.contains(specifier)) {
            return Some(specifier)
        }
        // 尝试 node: 前缀
        if (specifier.startsWith("node:")) {
            let stripped = specifier.substring(5)
            if (modulesByName.contains(stripped)) {
                return Some(stripped)
            }
        }
        None
    }

    /// 求值模块
    // 对应 Bun: $evaluateCommonJSModule(module, parent)
    public func evaluate(id: Int32): ?AnyType {
        match (modulesById.get(id)) {
            case Some(module) =>
                if (!module.evaluated) {
                    module.evaluated = true
                    // 在实际实现中, 这里会调用 JS 引擎执行模块源码
                    // module.exports = evaluateModuleSource(module.source)
                }
                module.exports
            case None => None
        }
    }
}

// ============================================================================
// BuiltinNames - 内置名称注册表
// 严格翻译自: src/js/builtins/BunBuiltinNames.h
//   在 Bun 中, 这定义了 JSC 使用的私有标识符名称。
//   $ 前缀用于在 TS 中访问私有属性和 JSC 内部函数。
//   构建时 $ 被替换为 @ (JSC 的内部前缀)。
// ============================================================================

/// 内置名称注册表
// 对应 Bun: BunBuiltinNames 类
// 定义所有 JSC 私有标识符
public class BuiltinNames {
    /// 流相关名称
    public static let READABLE_STREAM = "ReadableStream"
    public static let WRITABLE_STREAM = "WritableStream"
    public static let TRANSFORM_STREAM = "TransformStream"
    public static let READABLE_STREAM_DEFAULT_CONTROLLER = "ReadableStreamDefaultController"
    public static let READABLE_STREAM_DEFAULT_READER = "ReadableStreamDefaultReader"
    public static let READABLE_BYTE_STREAM_CONTROLLER = "ReadableByteStreamController"
    public static let READABLE_STREAM_BYOB_READER = "ReadableStreamBYOBReader"
    public static let READABLE_STREAM_BYOB_REQUEST = "ReadableStreamBYOBRequest"
    public static let WRITABLE_STREAM_DEFAULT_CONTROLLER = "WritableStreamDefaultController"
    public static let WRITABLE_STREAM_DEFAULT_WRITER = "WritableStreamDefaultWriter"
    public static let TRANSFORM_STREAM_DEFAULT_CONTROLLER = "TransformStreamDefaultController"

    /// 编码相关名称
    public static let TEXT_ENCODER_STREAM_ENCODER = "TextEncoderStreamEncoder"
    public static let TEXT_DECODER_STREAM_DECODER = "TextDecoderStreamDecoder"
    public static let TEXT_ENCODER_STREAM_TRANSFORM = "TextEncoderStreamTransform"
    public static let TEXT_DECODER_STREAM_TRANSFORM = "TextDecoderStreamTransform"

    /// 模块加载器名称
    public static let LOADER = "Loader"
    public static let INTERNAL_MODULE_REGISTRY = "internalModuleRegistry"
    public static let REQUIRE_MAP = "requireMap"

    /// CommonJS 名称
    public static let CREATE_COMMONJS_MODULE = "createCommonJSModule"
    public static let EVALUATE_COMMONJS_MODULE = "evaluateCommonJSModule"
    public static let INTERNAL_REQUIRE = "internalRequire"
    public static let OVERRIDABLE_REQUIRE = "overridableRequire"
    public static let REQUIRE_NATIVE_MODULE = "requireNativeModule"

    /// ESM 名称
    public static let FULFILL_MODULE_SYNC = "fulfillModuleSync"
    public static let ESM_NAMESPACE_FOR_CJS = "esmNamespaceForCjs"
    public static let ESM_REGISTRY_DELETE = "esmRegistryDelete"
    public static let ESM_REGISTRY_EVALUATED_KEYS = "esmRegistryEvaluatedKeys"
    public static let ESM_LOAD_SYNC = "esmLoadSync"
    public static let LOAD_ESM_INTO_CJS = "loadEsmIntoCjs"
    public static let REQUIRE_ESM = "requireESM"

    /// Abort 相关名称
    public static let ABORT_SIGNAL = "AbortSignal"
    public static let ABORT_ALGORITHM = "abortAlgorithm"
    public static let ABORT_STEPS = "abortSteps"
    public static let ADD_ABORT_ALGORITHM_TO_SIGNAL = "addAbortAlgorithmToSignal"
    public static let REMOVE_ABORT_ALGORITHM_FROM_SIGNAL = "removeAbortAlgorithmFromSignal"
    public static let IS_ABORT_SIGNAL = "isAbortSignal"
    public static let WHEN_SIGNAL_ABORTED = "whenSignalAborted"

    /// 流内部状态名称
    public static let BACKPRESSURE = "backpressure"
    public static let BACKPRESSURE_CHANGE_PROMISE = "backpressureChangePromise"
    public static let CLOSE_REQUEST = "closeRequest"
    public static let CLOSE_REQUESTED = "closeRequested"
    public static let CLOSED_PROMISE = "closedPromise"
    public static let CLOSED_PROMISE_CAPABILITY = "closedPromiseCapability"
    public static let CONTROLLED_READABLE_STREAM = "controlledReadableStream"
    public static let CONTROLLER = "controller"
    public static let DISTURBED = "disturbed"
    public static let IN_FLIGHT_CLOSE_REQUEST = "inFlightCloseRequest"
    public static let IN_FLIGHT_WRITE_REQUEST = "inFlightWriteRequest"
    public static let OWNER_READABLE_STREAM = "ownerReadableStream"
    public static let PENDING_ABORT_REQUEST = "pendingAbortRequest"
    public static let PENDING_PULL_INTOS = "pendingPullIntos"
    public static let PULL_AGAIN = "pullAgain"
    public static let PULLING = "pulling"
    public static let READ_REQUESTS = "readRequests"
    public static let READ_INTO_REQUESTS = "readIntoRequests"
    public static let READABLE = "readable"
    public static let READABLE_STREAM_CONTROLLER = "readableStreamController"
    public static let READER = "reader"
    public static let READY_PROMISE = "readyPromise"
    public static let STARTED = "started"
    public static let STATE = "state"
    public static let STORED_ERROR = "storedError"
    public static let STRATEGY = "strategy"
    public static let STRATEGY_HWM = "strategyHWM"
    public static let STRATEGY_SIZE_ALGORITHM = "strategySizeAlgorithm"
    public static let STREAM = "stream"
    public static let UNDERLYING_SOURCE = "underlyingSource"
    public static let UNDERLYING_SINK = "underlyingSink"
    public static let UNDERLYING_BYTE_SOURCE = "underlyingByteSource"
    public static let WRITABLE = "writable"
    public static let WRITE_REQUESTS = "writeRequests"

    /// Buffer / SQL 名称
    public static let BUFFER = "Buffer"
    public static let SQL = "SQL"

    /// 路径相关名称
    public static let BASENAME = "basename"
    public static let DIRNAME = "dirname"
    public static let EXTNAME = "extname"
    public static let IS_ABSOLUTE = "isAbsolute"
    public static let JOIN = "join"
    public static let NORMALIZE = "normalize"
    public static let RELATIVE = "relative"
    public static let TO_NAMESPACED_PATH = "toNamespacedPath"

    /// HTTP 相关名称
    public static let HEADERS = "headers"
    public static let METHOD = "method"
    public static let STATUS = "status"
    public static let STATUS_TEXT = "statusText"
    public static let URL = "url"
    public static let BODY = "body"
    public static let HOST = "host"
    public static let HOSTNAME = "hostname"
    public static let PORT = "port"
    public static let PATH = "path"
    public static let REDIRECT = "redirect"

    /// 其他常用名称
    public static let CANCEL = "cancel"
    public static let CLOSE = "close"
    public static let DATA = "data"
    public static let ENCODING = "encoding"
    public static let END = "end"
    public static let ERRNO = "errno"
    public static let FATAL = "fatal"
    public static let FORMAT = "format"
    public static let HIGH_WATER_MARK = "highWaterMark"
    public static let IGNORE_BOM = "ignoreBOM"
    public static let QUEUE = "queue"
    public static let READ = "read"
    public static let SIZE = "size"
    public static let START = "start"
    public static let WRITE = "write"
    public static let WRITTEN = "written"
    public static let SELF = "self"
    public static let SIGNAL = "signal"
    public static let SINK = "sink"
    public static let VIEW = "view"
}

// ============================================================================
// JscIntrinsics - JSC 内部函数
// 严格翻译自: src/js/private.d.ts + src/js/builtins.d.ts
//   在 Bun 中, $ 前缀用于访问 JSC 内部函数。
//   这些是字节码指令的直接映射, 不是普通的 JS 函数。
//   构建时 $ 前缀被替换为 @ (JSC 内部标识符)。
//
//   示例:
//     $Array.from(...)    -> @Array.from(...)
//     $newArrayWithSize(5) -> @newArrayWithSize(5)
//     map.$set(...)        -> map.@set(...)
// ============================================================================

/// JSC 内部函数 - 对应 Bun 的 $ 前缀函数
// 在仓颉中, 这些是声明性接口, 实际由 JS 引擎在运行时提供
public class JscIntrinsics {
    // ── Promise 内部函数 ──────────────────────────────────────────────
    // 对应 Bun:
    //   declare function $fulfillPromise<T>(promise, value): void
    //   declare function $resolvePromise<T>(promise, value): void
    //   declare function $rejectPromise(promise, value): void
    //   declare function $isPromise(value): boolean
    //   declare function $isPromiseFulfilled(promise): boolean
    //   declare function $isPromiseRejected(promise): boolean
    //   declare function $isPromisePending(promise): boolean

    public static let PROMISE_STATE_PENDING: Int32 = 0
    public static let PROMISE_STATE_FULFILLED: Int32 = 1
    public static let PROMISE_STATE_REJECTED: Int32 = 2
    public static let PROMISE_STATE_MASK: Int32 = 3

    public static let PROMISE_FIELD_FLAGS: Int32 = 0
    public static let PROMISE_FIELD_REACTIONS_OR_RESULT: Int32 = 1

    public static let PROMISE_FLAGS_IS_HANDLED: Int32 = 1 << 2

    // ── 模块状态常量 ──────────────────────────────────────────────────
    // 对应 Bun:
    //   declare const $ModuleFetch: number
    //   declare const $ModuleTranslate: number
    //   declare const $ModuleInstantiate: number
    //   declare const $ModuleSatisfy: number
    //   declare const $ModuleLink: number
    //   declare const $ModuleReady: number

    public static let MODULE_FETCH: Int32 = 0
    public static let MODULE_TRANSLATE: Int32 = 1
    public static let MODULE_INSTANTIATE: Int32 = 2
    public static let MODULE_SATISFY: Int32 = 3
    public static let MODULE_LINK: Int32 = 4
    public static let MODULE_READY: Int32 = 5

    // ── 迭代常量 ──────────────────────────────────────────────────────
    // 对应 Bun:
    //   declare const $iterationKindKey: TODO
    //   declare const $iterationKindValue: TODO
    //   declare const $iterationKindEntries: TODO

    public static let ITERATION_KIND_KEY: Int32 = 0
    public static let ITERATION_KIND_VALUE: Int32 = 1
    public static let ITERATION_KIND_ENTRIES: Int32 = 2

    // ── 流状态 ────────────────────────────────────────────────────────
    // 对应 Bun:
    //   declare function $streamClosed(): TODO
    //   declare function $streamErrored(): TODO
    //   declare function $streamReadable(): TODO
    //   declare function $streamWritable(): TODO

    public static let STREAM_STATE_READABLE: Int32 = 0
    public static let STREAM_STATE_CLOSED: Int32 = 1
    public static let STREAM_STATE_ERRORED: Int32 = 2
    public static let STREAM_STATE_WRITABLE: Int32 = 3

    // ── Generator 状态 ────────────────────────────────────────────────
    // 对应 Bun:
    //   declare const $GeneratorResumeModeNormal / Throw / Return
    //   declare const $GeneratorStateCompleted / Executing

    public static let GENERATOR_RESUME_MODE_NORMAL: Int32 = 0
    public static let GENERATOR_RESUME_MODE_THROW: Int32 = 1
    public static let GENERATOR_RESUME_MODE_RETURN: Int32 = 2

    public static let GENERATOR_STATE_COMPLETED: Int32 = 0
    public static let GENERATOR_STATE_EXECUTING: Int32 = 1

    // ── 数值限制 ──────────────────────────────────────────────────────
    // 对应 Bun:
    //   declare const $MAX_ARRAY_INDEX: number
    //   declare const $MAX_STRING_LENGTH: number
    //   declare const $MAX_SAFE_INTEGER: number

    public static let MAX_ARRAY_INDEX: UInt64 = 4294967295   // 2^32 - 1
    public static let MAX_STRING_LENGTH: Int64 = 1073741823    // 2^30 - 1 (JSC limit)
    public static let MAX_SAFE_INTEGER: Int64 = 9007199254740991  // 2^53 - 1
}

// ============================================================================
// CommonJSModuleLoader - CommonJS 模块加载器
// 严格翻译自: src/js/builtins/CommonJS.ts
//   Bun 的 CommonJS 加载器通过 $intrinsic 函数与 JSC 深度集成:
//   - require() -> $overridableRequire.$apply(this, arguments)
//   - 模块缓存 -> $requireMap
//   - 模块创建 -> $createCommonJSModule()
//   - 模块求值 -> $evaluateCommonJSModule()
//   - ESM 互操作 -> $loadEsmIntoCjs(), $requireESM()
// ============================================================================

/// CommonJS 模块 - 对应 Bun JSCommonJSModule
// 严格翻译自: src/js/private.d.ts:183-195
//   interface JSCommonJSModule {
//     $require(id, mod, args_count, args): any;
//     $requireNativeModule(id): any;
//     children: JSCommonJSModule[];
//     exports: any;
//     id: string;
//     loaded: boolean;
//     parent: undefined;
//     path: string;
//     paths: string[];
//     require: typeof require;
//     filename: string;
//   }
public class CommonJSModule {
    /// 模块 ID (文件路径)
    // 对应 Bun: id: string
    public var id: String

    /// 模块导出对象
    // 对应 Bun: exports: any
    public var exports: AnyType

    /// 是否已加载完成
    // 对应 Bun: loaded: boolean
    public var loaded: Bool

    /// 父模块
    // 对应 Bun: parent: undefined (始终为 undefined)
    public var parent: ?CommonJSModule

    /// 模块文件路径
    // 对应 Bun: filename: string
    public var filename: String

    /// 子模块列表
    // 对应 Bun: children: JSCommonJSModule[]
    public var children: ArrayList<CommonJSModule>

    /// 模块搜索路径
    // 对应 Bun: paths: string[]
    public var paths: ArrayList<String>

    public init(id: String, filename: String) {
        this.id = id
        this.filename = filename
        this.exports = AnyType()
        this.loaded = false
        this.parent = None
        this.children = ArrayList<CommonJSModule>()
        this.paths = ArrayList<String>()
    }

    /// require 函数
    // 严格翻译自: src/js/builtins/CommonJS.ts:10-13
    //   $visibility = "Private";
    //   export function require(this: JSCommonJSModule, _: string) {
    //       return $overridableRequire.$apply(this, arguments);
    //   }
    public func require(id: String): AnyType {
        overridableRequire(id)
    }

    /// 可覆盖的 require 函数
    // 严格翻译自: src/js/builtins/CommonJS.ts:16-141
    //   export function overridableRequire(this: JSCommonJSModule, originalId: string, ...) {
    //       const id = $resolveSync(originalId, this.filename, ...);
    //       if (id.startsWith("node:")) { ... return this.$requireNativeModule(id); }
    //       const existing = $requireMap.$get(id);
    //       if (existing) { ... return existing.exports; }
    //       ...
    //   }
    public func overridableRequire(id: String): AnyType {
        // 解析模块 ID
        // 对应 Bun: const id = $resolveSync(originalId, this.filename, ...)
        let resolvedId = resolveSync(id, this.filename)

        // node: 前缀 - 原生模块
        // 对应 Bun: if (id.startsWith("node:")) { return this.$requireNativeModule(id); }
        if (resolvedId.startsWith("node:")) {
            return requireNativeModule(resolvedId)
        }

        // 检查缓存
        // 对应 Bun: const existing = $requireMap.$get(id);
        //   if (existing) { return existing.exports; }
        let cached = requireMap.get(resolvedId)
        match (cached) {
            case Some(module) => return module.exports
            case None => ()
        }

        // 创建新模块并加载
        // 对应 Bun:
        //   const mod = $createCommonJSModule(id, {}, false, this);
        //   $requireMap.$set(id, mod);
        let newModule = createCommonJSModule(resolvedId, this)
        requireMap.put(resolvedId, newModule)

        // 加载模块
        // 对应 Bun: out = this.$require(id, mod, $argumentCount(), $argument(1));
        loadModule(newModule, resolvedId)

        // 求值
        // 对应 Bun: const c = $evaluateCommonJSModule(mod, this);
        evaluateCommonJSModule(newModule, this)

        newModule.loaded = true
        return newModule.exports
    }
}

// ============================================================================
// CommonJS 加载器函数
// 严格翻译自: src/js/builtins/CommonJS.ts 中的导出函数
// ============================================================================

/// 模块缓存映射
// 对应 Bun: declare const $requireMap: Map<string, JSCommonJSModule>
public let requireMap: HashMap<String, CommonJSModule> = HashMap<String, CommonJSModule>()

/// 解析模块路径
// 对应 Bun: $resolveSync(name, from, isESM, isUserRequireResolve, paths)
public func resolveSync(name: String, from: String): String {
    // 简化的模块解析逻辑
    // 实际实现需要完整的 Node.js 解析算法
    return name
}

/// 请求原生模块
// 对应 Bun: this.$requireNativeModule(id)
public func requireNativeModule(id: String): AnyType {
    // node:* 模块通过原生绑定加载
    AnyType()
}

/// 创建 CommonJS 模块
// 对应 Bun:
//   declare function $createCommonJSModule(
//     id: string, exports: any, hasEvaluated: boolean, parent: JSCommonJSModule | undefined
//   ): JSCommonJSModule;
public func createCommonJSModule(id: String, parent: ?CommonJSModule): CommonJSModule {
    let module = CommonJSModule(id, id)
    module.parent = parent
    return module
}

/// 加载模块源码
// 对应 Bun: this.$require(id, mod, $argumentCount(), $argument(1))
public func loadModule(module: CommonJSModule, id: String): Unit {
    // 在实际实现中, 这里从文件系统或内置注册表加载源码并执行
}

/// 求值 CommonJS 模块
// 对应 Bun:
//   declare function $evaluateCommonJSModule(
//     moduleToEvaluate: JSCommonJSModule,
//     sourceModule: JSCommonJSModule,
//   ): JSCommonJSModule[];
public func evaluateCommonJSModule(module: CommonJSModule, parent: CommonJSModule): ArrayList<CommonJSModule> {
    let children = ArrayList<CommonJSModule>()
    if (module.loaded) {
        children.append(module)
    }
    return children
}

/// 创建 require 缓存代理
// 严格翻译自: src/js/builtins/CommonJS.ts:358-423
//   export function createRequireCache() {
//     var moduleMap = new Map();
//     var proxy = new Proxy(inner, { get, set, has, deleteProperty, ownKeys, ... });
//     return proxy;
//   }
public func createRequireCache(): HashMap<String, CommonJSModule> {
    requireMap
}

// ============================================================================
// NodeBuiltinModules - Node.js 内置模块定义
// 严格翻译自: src/js/node/*.ts
//   Bun 实现了 Node.js 兼容层, 每个 node:* 模块对应一个 .ts 文件:
//   - fs.ts / fs.promises.ts -> fs 和 fs/promises
//   - path.ts / path.posix.ts / path.win32.ts -> path, path/win32, path/posix
//   - http.ts / https.ts -> http, https
//   - stream.ts / stream.web.ts -> stream, stream/web
//   - os.ts -> os
//   - crypto.ts -> crypto
//   - zlib.ts -> zlib
//   - ... (60+ 模块)
// ============================================================================

/// Node.js 内置模块列表
// 对应 Bun: src/js/node/ 目录中的所有模块
public class NodeBuiltinModules {
    /// 获取所有 Node.js 内置模块名称
    public static func listAll(): ArrayList<String> {
        let modules = ArrayList<String>()
        modules.append("assert")
        modules.append("assert/strict")
        modules.append("async_hooks")
        modules.append("buffer")
        modules.append("child_process")
        modules.append("cluster")
        modules.append("console")
        modules.append("constants")
        modules.append("crypto")
        modules.append("dgram")
        modules.append("diagnostics_channel")
        modules.append("dns")
        modules.append("dns/promises")
        modules.append("domain")
        modules.append("events")
        modules.append("fs")
        modules.append("fs/promises")
        modules.append("http")
        modules.append("http2")
        modules.append("https")
        modules.append("inspector")
        modules.append("inspector/promises")
        modules.append("module")
        modules.append("net")
        modules.append("os")
        modules.append("path")
        modules.append("path/posix")
        modules.append("path/win32")
        modules.append("perf_hooks")
        modules.append("process")
        modules.append("punycode")
        modules.append("querystring")
        modules.append("readline")
        modules.append("readline/promises")
        modules.append("repl")
        modules.append("stream")
        modules.append("stream/consumers")
        modules.append("stream/promises")
        modules.append("stream/web")
        modules.append("string_decoder")
        modules.append("sys")
        modules.append("timers")
        modules.append("timers/promises")
        modules.append("tls")
        modules.append("trace_events")
        modules.append("tty")
        modules.append("url")
        modules.append("util")
        modules.append("v8")
        modules.append("vm")
        modules.append("wasi")
        modules.append("worker_threads")
        modules.append("zlib")
        modules.append("test")
        return modules
    }

    /// 检查是否为 Node.js 内置模块
    public static func isNodeBuiltin(name: String): Bool {
        // 移除 node: 前缀后检查
        let stripped = if (name.startsWith("node:")) { name.substring(5) } else { name }
        let all = listAll()
        for (m in all) {
            if (m == stripped) {
                return true
            }
        }
        return false
    }
}

// ============================================================================
// BunBuiltinModules - Bun 特有内置模块
// 严格翻译自: src/js/bun/*.ts
//   bun:* 模块:
//   - bun.ffi -> FFI (外部函数接口)
//   - bun.sqlite -> SQLite 数据库
//   - bun.sql -> SQL 通用接口
// ============================================================================

/// Bun 特有内置模块
public class BunBuiltinModules {
    public static func listAll(): ArrayList<String> {
        let modules = ArrayList<String>()
        modules.append("bun:ffi")
        modules.append("bun:sqlite")
        modules.append("bun:sql")
        return modules
    }
}

// ============================================================================
// StreamBuiltins - 流内置模块
// 严格翻译自: src/js/builtins/ 中的流相关文件:
//   - ReadableStream.ts (17494 行)
//   - ReadableStreamInternals.ts (78383 行)
//   - ReadableByteStreamInternals.ts (30837 行)
//   - WritableStreamDefaultController.ts
//   - WritableStreamDefaultWriter.ts
//   - TransformStream.ts
//   - TransformStreamInternals.ts
//   - TextEncoderStream.ts
//   - TextDecoderStream.ts
//   - StreamInternals.ts
//   - ByteLengthQueuingStrategy.ts
//   - CountQueuingStrategy.ts
//   - CompressionStream.ts
//   - DecompressionStream.ts
// ============================================================================

/// 流状态枚举 - 对应 Bun 的 $streamReadable 等
public enum StreamState {
    | Readable    // 对应 $streamReadable
    | Closed      // 对应 $streamClosed
    | Errored     // 对应 $streamErrored
    | Writable    // 对应 $streamWritable
}

/// 流控制器类型
public enum StreamControllerKind {
    | Default     // ReadableStreamDefaultController
    | Byte        // ReadableByteStreamController
}

/// 流读取器类型
public enum StreamReaderKind {
    | Default     // ReadableStreamDefaultReader
    | BYOB        // ReadableStreamBYOBReader
}

// ============================================================================
// ErrorCodes - 内置错误码函数
// 严格翻译自: src/js/private.d.ts:653-779
//   Bun 实现了 Node.js 兼容的错误码系统:
//   $ERR_INVALID_ARG_TYPE, $ERR_STREAM_DESTROYED, $ERR_OUT_OF_RANGE 等
//   这些函数创建带有 code 属性的 Error/TypeError/RangeError 实例
// ============================================================================

/// 内置错误码工具
public class BuiltinErrorCodes {

    /// 创建无效参数类型错误
    // 对应 Bun: declare function $ERR_INVALID_ARG_TYPE(argName, expectedType, actualValue): TypeError
    public static func errInvalidArgType(argName: String, expectedType: String, actualValue: String): BaoError {
        BaoError(ErrorCode.InvalidArgument, "The \"${argName}\" argument must be of type ${expectedType}. Received ${actualValue}")
    }

    /// 创建缺少参数错误
    // 对应 Bun: declare function $ERR_MISSING_ARGS(...args): TypeError
    public static func errMissingArgs(args: ArrayList<String>): BaoError {
        BaoError(ErrorCode.InvalidArgument, "The ${String.join(",", args)} argument(s) must be specified")
    }

    /// 创建超出范围错误
    // 对应 Bun: declare function $ERR_OUT_OF_RANGE(name, reason, value): RangeError
    public static func errOutOfRange(name: String, reason: String, value: String): BaoError {
        BaoError(ErrorCode.Overflow, "The value of \"${name}\" ${reason}. Received ${value}")
    }

    /// 创建已销毁错误
    // 对应 Bun: declare function $ERR_STREAM_DESTROYED(method): Error
    public static func errStreamDestroyed(method: String): BaoError {
        BaoError(ErrorCode.InvalidArgument, "Cannot call ${method} after a stream was destroyed")
    }

    /// 创建未实现错误
    // 对应 Bun: declare function $ERR_METHOD_NOT_IMPLEMENTED(method): Error
    public static func errMethodNotImplemented(method: String): BaoError {
        BaoError(ErrorCode.NotImplemented, "The ${method} method is not implemented")
    }

    /// 创建无效状态错误
    // 对应 Bun: declare function $ERR_INVALID_STATE(message): Error
    public static func errInvalidState(message: String): BaoError {
        BaoError(ErrorCode.InvalidArgument, message)
    }

    /// 创建非法构造函数错误
    // 对应 Bun: declare function $ERR_ILLEGAL_CONSTRUCTOR(): TypeError
    public static func errIllegalConstructor(): BaoError {
        BaoError(ErrorCode.InvalidArgument, "Illegal constructor")
    }

    /// 创建中止错误
    // 对应 Bun: declare function $makeAbortError(message?, options?): Error
    public static func makeAbortError(message: String): BaoError {
        BaoError(ErrorCode.Aborted, message)
    }
}

// ============================================================================
// BuiltinPreprocessor - 内置模块预处理器
// 严格翻译自: src/js/README.md "Notes on how the build process works"
//   预处理步骤:
//   1. 扫描所有模块并分配数字 ID (按 A-Z 排序)
//   2. 将 $ 前缀标识符转换为 __intrinsic__
//   3. 将 require(string) 替换为 $requireId(n)
//   4. 将 export default 转换为 return 语句
//   5. 包裹为 $$capture_start$$(function() { ... }).$$capture_end$$
//   6. 捆绑后, __intrinsic__ 替换为 @
// ============================================================================

/// 内置模块预处理器
public class BuiltinPreprocessor {
    /// 预处理模块源码
    public static func preprocess(source: String, moduleId: Int32): String {
        var result = source
        // 1. 替换 require("...") 为 $requireId(n)
        //    在 Bun 中通过递归正则扫描实现
        // 2. 替换 $ 前缀为 __intrinsic__
        // 3. 转换 export default -> return
        // 4. 包裹函数体
        result = wrapInFunction(result, moduleId)
        return result
    }

    /// 包裹为 capture 函数
    // 对应 Bun:
    //   $$capture_start$$(function () {
    //     const path = __intrinsic__requireId(23);
    //     return { ... };
    //   }).$$capture_end$$;
    private static func wrapInFunction(source: String, moduleId: Int32): String {
        return "$$capture_start$$(function () {\n${source}\n}).$$capture_end$$"
    }
}
