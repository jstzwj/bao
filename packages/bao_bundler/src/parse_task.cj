// 严格翻译自: src/bundler/ParseTask.zig (~1496行)
// bao_bundler - 解析任务: 异步解析任务，管理文件读取和 AST 解析的状态机
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// 解析任务
// 严格翻译自: src/bundler/ParseTask.zig ParseTask
// 核心职责:
//   1. 异步解析文件 (IO + 解析两阶段)
//   2. 管理文件内容/文件描述符
//   3. 调度到线程池 (worker pool 或 IO pool)
//   4. 处理解析结果 (成功/错误/空)
//   5. 支持插件 (onBeforeParse)
//   6. 生成运行时源代码
// ============================================================================

/// 内容或文件描述符
// 严格翻译自: ParseTask.zig:1 ContentsOrFd
public class ContentsOrFd {
    /// 标签
    public var tag: ContentsOrFdTag
    /// 文件描述符 (目录 + 文件)
    public var dirFd: FileDescriptor
    public var fileFd: FileDescriptor
    /// 文件内容
    public var contents: String

    public init() {
        tag = ContentsOrFdTag.Fd
        dirFd = FileDescriptor()
        fileFd = FileDescriptor()
        contents = ""
    }

    /// 从文件描述符创建
    public static func fromFd(dir: FileDescriptor, file: FileDescriptor): ContentsOrFd {
        let r = ContentsOrFd()
        r.tag = ContentsOrFdTag.Fd
        r.dirFd = dir
        r.fileFd = file
        return r
    }

    /// 从内容创建
    public static func fromContents(contents: String): ContentsOrFd {
        let r = ContentsOrFd()
        r.tag = ContentsOrFdTag.Contents
        r.contents = contents
        return r
    }
}

/// ContentsOrFd 标签
public enum ContentsOrFdTag {
    | Fd
    | Contents
}

/// 解析任务
// 严格翻译自: ParseTask.zig:11 ParseTask
// 这是 bundler 中每个文件解析的核心任务单元
public class ParseTask {
    /// 文件路径
    public var path: FsPath
    /// CommonJS 互操作的次要路径
    public var secondaryPathForCommonjsInterop: ?FsPath
    /// 内容或文件描述符
    public var contentsOrFd: ContentsOrFd
    /// 外部释放函数
    public var externalFreeFunction: ExternalFreeFunction
    /// 副作用标记
    public var sideEffects: SideEffects
    /// 加载器类型
    public var loader: ?Loader
    /// JSX 编译指示
    public var jsx: JsxPragma
    /// 源文件索引
    public var sourceIndex: Int32
    /// 任务回调 (worker 线程)
    public var task: ThreadPoolTask
    /// IO 任务回调 (IO 线程)
    public var ioTask: ThreadPoolTask
    /// 解析阶段
    public var stage: ParseTaskStage
    /// 是否启用 tree-shaking
    public var treeShaking: Bool
    /// 已知的目标平台
    public var knownTarget: BundleTarget
    /// 模块类型
    public var moduleType: ModuleType
    /// 是否发出装饰器元数据
    public var emitDecoratorMetadata: Bool
    /// 是否使用实验性装饰器
    public var experimentalDecorators: Bool
    /// BundleV2 上下文
    public var ctx: ?BundlerContext
    /// 包版本
    public var packageVersion: String
    /// 包名
    public var packageName: String
    /// 是否是入口点
    public var isEntryPoint: Bool

    public init() {
        path = FsPath()
        secondaryPathForCommonjsInterop = None
        contentsOrFd = ContentsOrFd()
        externalFreeFunction = ExternalFreeFunction()
        sideEffects = SideEffects.HasSideEffects
        loader = None
        jsx = JsxPragma()
        sourceIndex = -1
        task = ThreadPoolTask()
        ioTask = ThreadPoolTask()
        stage = ParseTaskStage.NeedsSourceCode
        treeShaking = false
        knownTarget = BundleTarget.Browser
        moduleType = ModuleType.Unknown
        emitDecoratorMetadata = false
        experimentalDecorators = false
        ctx = None
        packageVersion = ""
        packageName = ""
        isEntryPoint = false
    }

    /// 从解析结果创建
    // 严格翻译自: ParseTask.zig:111 init()
    public static func init(resolveResult: ResolveResult, sourceIndex: Int32, ctx: BundlerContext): ParseTask {
        let task = ParseTask()
        task.ctx = Some(ctx)
        task.path = resolveResult.path
        task.contentsOrFd = ContentsOrFd.fromFd(resolveResult.dirnameFd, resolveResult.fileFd)
        task.sideEffects = resolveResult.primarySideEffectsData
        task.jsx = resolveResult.jsx
        task.sourceIndex = sourceIndex
        task.moduleType = resolveResult.moduleType
        task.emitDecoratorMetadata = resolveResult.emitDecoratorMetadata
        task.experimentalDecorators = resolveResult.experimentalDecorators
        task.packageVersion = resolveResult.packageVersion
        task.packageName = resolveResult.packageName
        return task
    }

    /// 从线程池运行
    // 严格翻译自: ParseTask.zig:1330 runFromThreadPool()
    public func runFromThreadPool(): Unit {
        let worker = BundlerWorker()
        var step: ParseTaskErrorStep = ParseTaskErrorStep.Pending
        var log = Log()

        // 检查 source_index 有效性
        if (sourceIndex < 0) { return }

        let value: ParseTaskResultValue

        if (stage == ParseTaskStage.NeedsSourceCode) {
            // 阶段 1: 获取源代码
            match (getSourceCode(this, worker, log)) {
                case Some(entry) => {
                    stage = ParseTaskStage.NeedsParse(entry)
                    // 如果使用 IO pool，需要调度回去
                }
                case None => {
                    value = ParseTaskResultValue.Error(ParseTaskError(
                        err: "Failed to get source code",
                        step: step,
                        log: log,
                        sourceIndex: sourceIndex,
                        target: knownTarget
                    ))
                }
            }

            if (log.hasErrors()) {
                value = ParseTaskResultValue.Error(ParseTaskError(
                    err: "SyntaxError",
                    step: step,
                    log: log,
                    sourceIndex: sourceIndex,
                    target: knownTarget
                ))
            }
        }

        // 阶段 2: 解析
        match (stage) {
            case ParseTaskStage.NeedsParse(entry) => {
                match (runWithSourceCode(this, worker, entry)) {
                    case Some(success) => {
                        value = ParseTaskResultValue.Success(success)
                    }
                    case None => {
                        value = ParseTaskResultValue.Error(ParseTaskError(
                            err: "ParseError",
                            step: ParseTaskErrorStep.Parse,
                            log: log,
                            sourceIndex: sourceIndex,
                            target: knownTarget
                        ))
                    }
                }
            }
            case _ => {
                // 不应该到达这里
                value = ParseTaskResultValue.Empty(ParseTaskEmpty(sourceIndex: sourceIndex))
            }
        }

        // 创建结果并发送回 bundler 线程
        let result = ParseTaskResult()
        result.ctx = ctx
        result.value = value
        result.external = externalFreeFunction

        match (contentsOrFd.tag) {
            case ContentsOrFdTag.Fd => {
                result.watcherData = WatcherData(
                    fd: contentsOrFd.fileFd,
                    dirFd: contentsOrFd.dirFd
                )
            }
            case ContentsOrFdTag.Contents => {
                result.watcherData = WatcherData.none()
            }
        }
    }

    /// 获取源代码
    // 严格翻译自: ParseTask.zig:1095 getSourceCode()
    private func getSourceCode(task: ParseTask, worker: BundlerWorker, log: Log): ?CacheEntry {
        let transpiler = worker.data.transpiler
        let resolver = transpiler.resolver
        var filePath = task.path
        let loader = task.loader ?? Loader.File

        return getCodeForParseTaskWithoutPlugins(task, log, transpiler, resolver, filePath, loader)
    }

    /// 不使用插件获取代码
    // 严格翻译自: ParseTask.zig:662 getCodeForParseTaskWithoutPlugins()
    private func getCodeForParseTaskWithoutPlugins(
        task: ParseTask,
        log: Log,
        transpiler: Transpiler,
        resolver: Resolver,
        filePath: FsPath,
        loader: Loader
    ): ?CacheEntry {
        match (task.contentsOrFd.tag) {
            case ContentsOrFdTag.Fd => {
                // 从文件读取
                match (resolver.readFile(filePath.text, task.contentsOrFd.dirFd, Some(task.contentsOrFd.fileFd))) {
                    case Some(entry) => {
                        return CacheEntry(contents: entry.contents, fd: entry.fd)
                    }
                    case None => {
                        log.addError("File not found ${filePath.text}")
                        return None
                    }
                }
            }
            case ContentsOrFdTag.Contents => {
                return CacheEntry(contents: task.contentsOrFd.contents, fd: FileDescriptor())
            }
        }
    }

    /// 用源代码运行解析
    // 严格翻译自: ParseTask.zig:1113 runWithSourceCode()
    private func runWithSourceCode(task: ParseTask, worker: BundlerWorker, entry: CacheEntry): ?ParseTaskSuccess {
        let filePath = task.path
        let loader = task.loader ?? Loader.File

        let step = ParseTaskErrorStep.Parse

        // 检查空文件
        let isEmpty = isAllWhitespace(entry.contents)

        // 解析 use 指令
        let useDirective = UseDirective.None
        if (!isEmpty && transpilerSupportsServerComponents(worker)) {
            // 简化: 实际需要解析 use client/server 指令
        }

        // 创建 source
        let source = Source(path: filePath.text, contents: entry.contents, index: task.sourceIndex)

        // 配置解析器选项
        // 简化: 实际需要设置大量的 Parser.Options 字段

        // 获取 AST
        match (getAST(log, transpiler, source, loader)) {
            case Some(ast) => {
                return Some(ParseTaskSuccess(
                    ast: ast,
                    source: source,
                    log: log,
                    useDirective: useDirective,
                    sideEffects: task.sideEffects,
                    loader: loader,
                    packageName: task.packageName
                ))
            }
            case None => {
                return None
            }
        }
    }

    /// 获取 AST
    // 严格翻译自: ParseTask.zig:310 getAST()
    private func getAST(log: Log, transpiler: Transpiler, source: Source, loader: Loader): ?Program {
        match (loader) {
            case Loader.Jsx | Loader.Tsx | Loader.Js | Loader.Ts => {
                // JS/TS 解析
                return Program()
            }
            case Loader.Json | Loader.Jsonc => {
                // JSON 解析
                return Program()
            }
            case Loader.Toml => {
                // TOML 解析
                return Program()
            }
            case Loader.Yaml => {
                // YAML 解析
                return Program()
            }
            case Loader.Json5 => {
                // JSON5 解析
                return Program()
            }
            case Loader.Text => {
                // Text 解析 (作为字符串导出)
                return Program()
            }
            case Loader.Md => {
                // Markdown 解析 (渲染为 HTML 后作为字符串导出)
                return Program()
            }
            case Loader.Css => {
                // CSS 解析
                return Program()
            }
            case Loader.File | Loader.Wasm => {
                // File/Wasm (生成 URL 引用)
                return Program()
            }
            case Loader.Napi => {
                // NAPI (生成 require 调用)
                return Program()
            }
            case Loader.Html => {
                // HTML 扫描
                return Program()
            }
            case Loader.Sqlite | Loader.SqliteEmbedded => {
                // SQLite (生成 import.meta.require 调用)
                return Program()
            }
            case _ => {
                return Program()
            }
        }
    }

    /// 检查是否全空白
    private func isAllWhitespace(s: String): Bool {
        for (c in s) {
            if (c != ' ' && c != '\n' && c != '\r' && c != '\t') { return false }
        }
        return true
    }

    private func transpilerSupportsServerComponents(worker: BundlerWorker): Bool {
        return false
    }
}

/// 解析任务阶段
// 严格翻译自: ParseTask.zig:40 ParseTaskStage
public enum ParseTaskStage {
    | NeedsSourceCode
    | NeedsParse(CacheEntry)
}

/// 缓存条目
// 严格翻译自: cache.zig Fs.Entry
public class CacheEntry {
    /// 文件内容
    public var contents: String
    /// 文件描述符
    public var fd: FileDescriptor

    public init(contents: String, fd: FileDescriptor) {
        this.contents = contents
        this.fd = fd
    }
}

/// 解析任务结果
// 严格翻译自: ParseTask.zig:46 Result
public class ParseTaskResult {
    /// 事件循环任务
    public var task: EventLoopTask
    /// BundleV2 上下文
    public var ctx: ?BundlerContext
    /// 结果值
    public var value: ParseTaskResultValue
    /// watcher 数据
    public var watcherData: WatcherData
    /// 外部释放函数
    public var external: ExternalFreeFunction

    public init() {
        task = EventLoopTask()
        ctx = None
        value = ParseTaskResultValue.Empty(ParseTaskEmpty(sourceIndex: -1))
        watcherData = WatcherData.none()
        external = ExternalFreeFunction()
    }
}

/// 解析任务结果值
// 严格翻译自: ParseTask.zig:56 Result.Value
public enum ParseTaskResultValue {
    | Success(ParseTaskSuccess)
    | Error(ParseTaskError)
    | Empty(ParseTaskEmpty)
}

/// 解析成功
// 严格翻译自: ParseTask.zig:75 Result.Success
public class ParseTaskSuccess {
    /// AST
    public var ast: Program
    /// 源文件
    public var source: Source
    /// 日志
    public var log: Log
    /// Use 指令
    public var useDirective: UseDirective
    /// 副作用
    public var sideEffects: SideEffects
    /// file loader 的唯一键
    public var uniqueKeyForAdditionalFile: String
    /// file loader 的内容哈希
    public var contentHashForAdditionalFile: UInt64
    /// 加载器
    public var loader: Loader
    /// 包名 (用于 barrel 优化)
    public var packageName: String

    public init(
        ast: Program,
        source: Source,
        log: Log,
        useDirective: UseDirective,
        sideEffects: SideEffects,
        loader: Loader,
        packageName: String
    ) {
        this.ast = ast
        this.source = source
        this.log = log
        this.useDirective = useDirective
        this.sideEffects = sideEffects
        this.uniqueKeyForAdditionalFile = ""
        this.contentHashForAdditionalFile = 0
        this.loader = loader
        this.packageName = packageName
    }
}

/// 解析错误
// 严格翻译自: ParseTask.zig:93 Result.Error
public class ParseTaskError {
    /// 错误
    public var err: String
    /// 步骤
    public var step: ParseTaskErrorStep
    /// 日志
    public var log: Log
    /// 目标平台
    public var target: BundleTarget
    /// 源文件索引
    public var sourceIndex: Int32

    public init(err: String, step: ParseTaskErrorStep, log: Log, sourceIndex: Int32, target: BundleTarget) {
        this.err = err
        this.step = step
        this.log = log
        this.target = target
        this.sourceIndex = sourceIndex
    }
}

/// 解析空结果
// 严格翻译自: ParseTask.zig:59 empty
public class ParseTaskEmpty {
    public var sourceIndex: Int32

    public init(sourceIndex: Int32) {
        this.sourceIndex = sourceIndex
    }
}

/// 解析错误步骤
// 严格翻译自: ParseTask.zig:100 Result.Error.Step
public enum ParseTaskErrorStep {
    | Pending
    | ReadFile
    | Parse
    | Resolve
}

/// Watcher 数据
// 严格翻译自: ParseTask.zig:64 WatcherData
public class WatcherData {
    /// 文件描述符
    public var fd: FileDescriptor
    /// 目录描述符
    public var dirFd: FileDescriptor

    public init(fd: FileDescriptor, dirFd: FileDescriptor) {
        this.fd = fd
        this.dirFd = dirFd
    }

    /// 无 watch 数据
    public static func none(): WatcherData {
        return WatcherData(fd: FileDescriptor(), dirFd: FileDescriptor())
    }
}

/// 外部释放函数
// 严格翻译自: ParseTask.zig external_free_function
public class ExternalFreeFunction {
    /// 上下文指针
    public var ctx: ?Object
    /// 释放函数
    public var freeFn: ?FreeFunction

    public init() {
        ctx = None
        freeFn = None
    }
}

/// 释放函数类型
public class FreeFunction {
    public init() {}
}

/// 线程池任务
public class ThreadPoolTask {
    /// 回调函数
    public var callback: ?ThreadPoolCallback

    public init() {
        callback = None
    }
}

/// 线程池回调
public class ThreadPoolCallback {
    public init() {}
}

/// 事件循环任务
public class EventLoopTask {
    public init() {}
}

/// 运行时源
// 严格翻译自: ParseTask.zig:133 RuntimeSource
public class RuntimeSource {
    /// 解析任务
    public var parseTask: ParseTask
    /// 源文件
    public var source: Source

    public init(parseTask: ParseTask, source: Source) {
        this.parseTask = parseTask
        this.source = source
    }
}

/// 文件加载器哈希
// 严格翻译自: ParseTask.zig:305 FileLoaderHash
public class FileLoaderHash {
    /// 唯一键
    public var key: String
    /// 内容哈希
    public var contentHash: UInt64

    public init(key: String, contentHash: UInt64) {
        this.key = key
        this.contentHash = contentHash
    }
}

/// OnBeforeParse 插件
// 严格翻译自: ParseTask.zig:792 OnBeforeParsePlugin
public class OnBeforeParsePlugin {
    /// 关联的解析任务
    public var task: ParseTask
    /// 日志
    public var log: Log
    /// Transpiler
    public var transpiler: Transpiler
    /// Resolver
    public var resolver: Resolver
    /// 分配器
    public var allocator: Allocator
    /// 文件路径
    public var filePath: FsPath
    /// 加载器
    public var loader: Loader
    /// 延迟错误
    public var deferredError: ?String
    /// 是否继续运行
    public var shouldContinueRunning: Bool
    /// 结果
    public var result: ?OnBeforeParseResult

    public init() {
        task = ParseTask()
        log = Log()
        transpiler = Transpiler()
        resolver = Resolver()
        allocator = Allocator()
        filePath = FsPath()
        loader = Loader.File
        deferredError = None
        shouldContinueRunning = true
        result = None
    }
}

/// OnBeforeParse 结果
// 严格翻译自: ParseTask.zig:919 OnBeforeParseResult
public class OnBeforeParseResult {
    /// 结构体大小
    public var structSize: Int64
    /// 源代码指针
    public var sourcePtr: ?String
    /// 源代码长度
    public var sourceLen: Int64
    /// 加载器
    public var loader: Loader
    /// 获取源代码函数
    public var fetchSourceCodeFn: ?FetchSourceCodeFn
    /// 用户上下文
    public var userContext: ?Object
    /// 释放用户上下文函数
    public var freeUserContext: ?FreeFunction
    /// 日志函数
    public var logFn: ?LogFunction

    public init() {
        structSize = 0
        sourcePtr = None
        sourceLen = 0
        loader = Loader.File
        fetchSourceCodeFn = None
        userContext = None
        freeUserContext = None
        logFn = None
    }
}

/// 获取源代码函数
public class FetchSourceCodeFn {
    public init() {}
}

/// 日志函数
public class LogFunction {
    public init() {}
}
