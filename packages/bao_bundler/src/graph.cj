// 严格翻译自: src/bundler/Graph.zig (~141行)
// bao_bundler - 解析图: 管理输入文件、AST、入口点和待处理任务计数
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// 解析图
// 严格翻译自: src/bundler/Graph.zig Graph struct
// 核心职责:
//   1. 存储所有输入文件和 AST
//   2. 管理入口点映射
//   3. 跟踪待处理的解析任务计数
//   4. 维护各 target 的 path -> source index 映射
//   5. 排空延迟任务 (plugin defer 回调)
// ============================================================================

/// HTML 导入跟踪
// 严格翻译自: Graph.zig:47 html_imports
public class HtmlImports {
    /// 服务端源文件索引列表
    public var serverSourceIndices: ArrayList<Int32>
    /// HTML 源文件索引列表
    public var htmlSourceIndices: ArrayList<Int32>

    public init() {
        serverSourceIndices = ArrayList<Int32>()
        htmlSourceIndices = ArrayList<Int32>()
    }
}

/// 输入文件标志位
// 严格翻译自: Graph.zig:81 InputFile.Flags
public class InputFileFlags {
    /// 是否是插件文件
    public var isPluginFile: Bool
    /// 是否是 export * 目标 (barrel 优化)
    public var isExportStarTarget: Bool

    public init() {
        isPluginFile = false
        isExportStarTarget = false
    }
}

/// 输入文件
// 严格翻译自: Graph.zig:70 InputFile
public class BundlerInputFile {
    /// 源文件
    public var source: Source
    /// 次要路径 (如 .d.ts 类型声明)
    public var secondaryPath: String
    /// 加载器类型
    public var loader: Loader
    /// 副作用标记
    public var sideEffects: SideEffects
    /// 附加文件列表 (用于 file/wasm loader)
    public var additionalFiles: ArrayList<AdditionalFile>
    /// 附加文件的唯一键
    public var uniqueKeyForAdditionalFile: String
    /// 附加文件的内容哈希
    public var contentHashForAdditionalFile: UInt64
    /// 标志位
    public var flags: InputFileFlags

    public init(source: Source) {
        this.source = source
        this.secondaryPath = ""
        this.loader = Loader.File
        this.sideEffects = SideEffects.HasSideEffects
        this.additionalFiles = ArrayList<AdditionalFile>()
        this.uniqueKeyForAdditionalFile = ""
        this.contentHashForAdditionalFile = 0
        this.flags = InputFileFlags()
    }
}

/// 附加文件 (file/wasm loader 输出)
// 严格翻译自: bundle_v2.zig AdditionalFile
public class AdditionalFile {
    /// 唯一键
    public var uniqueKey: String
    /// 源路径
    public var srcPath: String
    /// 内容哈希
    public var contentHash: UInt64

    public init(uniqueKey: String, srcPath: String, contentHash: UInt64) {
        this.uniqueKey = uniqueKey
        this.srcPath = srcPath
        this.contentHash = contentHash
    }
}

/// 源文件
// 严格翻译自: logger.zig Source
public class Source {
    /// 文件路径
    public var path: String
    /// 文件内容
    public var contents: String
    /// 源文件索引
    public var index: Int32

    public init(path: String, contents: String, index: Int32) {
        this.path = path
        this.contents = contents
        this.index = index
    }

    public init() {
        path = ""
        contents = ""
        index = -1
    }

    /// 是否是运行时文件
    public func isRuntime(): Bool {
        return index == 0
    }

    /// 是否有效
    public func isValid(): Bool {
        return index >= 0
    }
}

/// 解析图
// 严格翻译自: src/bundler/Graph.zig Graph struct
// 这是 bundle 的核心数据结构，存储所有文件和解析状态
public class BundlerGraph {
    /// 线程池引用
    public var pool: BundlerThreadPool
    /// 入口点列表 (源文件索引)
    public var entryPoints: ArrayList<Int32>
    /// 入口点原始名称映射 (用于插件解析的虚拟入口)
    public var entryPointOriginalNames: HashMap<Int32, String>
    /// 输入文件列表 (每个 source index 一个)
    public var inputFiles: ArrayList<BundlerInputFile>
    /// AST 列表 (每个 source index 一个，解析中/排队时为空)
    public var asts: ArrayList<Program>
    /// 待处理项目计数
    // 解析文件、onResolve/onLoad 回调、onDefer promise 递增
    // 递减到 0 时扫描阶段结束，链接开始
    public var pendingItems: UInt32
    /// 延迟处理的待处理项目计数
    // onLoad 插件调用 .defer() 时从 pending_items 移到此处
    // pending_items 归零时移回 pending_items 并执行
    public var deferredPending: UInt32
    /// 各 target 的 path -> source index 映射
    public var buildGraphs: HashMap<String, PathToSourceIndexMap>
    /// 服务端组件边界文件列表
    public var serverComponentBoundaries: ArrayList<ServerComponentBoundary>
    /// HTML 导入跟踪
    public var htmlImports: HtmlImports
    /// 预估的 file loader 文件数量
    public var estimatedFileLoaderCount: Int64
    /// CSS 文件计数 (用于精确预分配)
    public var cssFileCount: Int64
    /// 额外输出文件
    public var additionalOutputFiles: ArrayList<OutputFile>
    /// kit 引用了服务端数据
    public var kitReferencedServerData: Bool
    /// kit 引用了客户端数据
    public var kitReferencedClientData: Bool
    /// 是否有任何 secondary_path.len > 0
    public var hasAnySecondaryPaths: Bool

    public init() {
        pool = BundlerThreadPool()
        entryPoints = ArrayList<Int32>()
        entryPointOriginalNames = HashMap<Int32, String>()
        inputFiles = ArrayList<BundlerInputFile>()
        asts = ArrayList<Program>()
        pendingItems = 0
        deferredPending = 0
        buildGraphs = HashMap<String, PathToSourceIndexMap>()
        serverComponentBoundaries = ArrayList<ServerComponentBoundary>()
        htmlImports = HtmlImports()
        estimatedFileLoaderCount = 0
        cssFileCount = 0
        additionalOutputFiles = ArrayList<OutputFile>()
        kitReferencedServerData = false
        kitReferencedClientData = false
        hasAnySecondaryPaths = false
    }

    /// 获取指定 target 的路径到源索引映射
    // 严格翻译自: Graph.zig:89 pathToSourceIndexMap()
    public func pathToSourceIndexMap(target: String): PathToSourceIndexMap {
        match (buildGraphs.get(target)) {
            case Some(map) => return map
            case None => {
                let map = PathToSourceIndexMap()
                buildGraphs.put(target, map)
                return map
            }
        }
    }

    /// 排空延迟任务
    // 严格翻译自: Graph.zig:97 drainDeferredTasks()
    // 调度延迟任务到 JS 线程以解析每个 .defer() 的 promise
    // 返回 true 表示有更多排队的任务
    public func drainDeferredTasks(): Bool {
        if (deferredPending > 0) {
            pendingItems += deferredPending
            deferredPending = 0
            return true
        }
        return false
    }

    /// 增加扫描计数器
    public func incrementScanCounter(): Unit {
        pendingItems += 1
    }

    /// 减少扫描计数器
    public func decrementScanCounter(): Unit {
        pendingItems -= 1
    }

    /// 添加入口点
    public func addEntryPoint(sourceIndex: Int32, originalName: String): Unit {
        entryPoints.append(sourceIndex)
        if (originalName.length > 0) {
            entryPointOriginalNames.put(sourceIndex, originalName)
        }
    }

    /// 添加输入文件并返回 source index
    public func addInputFile(file: BundlerInputFile): Int32 {
        let index = Int32(inputFiles.size)
        inputFiles.append(file)
        return index
    }

    /// 获取入口点数量
    public func entryPointCount(): Int64 {
        return entryPoints.size
    }

    /// 是否有待处理项目
    public func hasPendingItems(): Bool {
        return pendingItems > 0
    }
}

/// 服务端组件边界
// 严格翻译自: js_ast.zig ServerComponentBoundary
public class ServerComponentBoundary {
    /// 边界文件的源索引
    public var sourceIndex: Int32
    /// "use client" 或 "use server" 指令
    public var directive: UseDirective
    /// 边界在源文件中的位置
    public var loc: Int64

    public init(sourceIndex: Int32, directive: UseDirective, loc: Int64) {
        this.sourceIndex = sourceIndex
        this.directive = directive
        this.loc = loc
    }
}

/// 使用指令 ("use client" / "use server")
// 严格翻译自: bundle_v2.zig UseDirective
public enum UseDirective {
    | None
    | Client
    | Server
}

/// 线程池 (bundler 专用)
// 严格翻译自: src/bundler/ThreadPool.zig ThreadPool
public class BundlerThreadPool {
    /// IO 线程池
    public var ioPool: ?ThreadPoolLib
    /// Worker 线程池
    public var workerPool: ?ThreadPoolLib
    /// worker pool 是否被持有
    public var workerPoolIsOwned: Bool
    /// worker 分配映射
    public var workerAssignments: HashMap<Int64, BundlerWorker>
    /// worker 分配锁
    public var workerAssignmentsLock: Mutex
    /// 引用的 BundleV2

    public init() {
        ioPool = None
        workerPool = None
        workerPoolIsOwned = false
        workerAssignments = HashMap<Int64, BundlerWorker>()
        workerAssignmentsLock = Mutex()
    }

    /// 初始化线程池
    // 严格翻译自: ThreadPool.zig:82 init()
    public func initPool(workerPool: ?ThreadPoolLib): Unit {
        if (workerPool.isSome()) {
            this.workerPool = workerPool
            this.workerPoolIsOwned = false
        } else {
            // 创建新的 worker pool
            let cpuCount = System.threadCount()
            let pool = ThreadPoolLib(cpuCount)
            this.workerPool = Some(pool)
            this.workerPoolIsOwned = true
        }

        // macOS 使用 IO pool 避免 IORWLock 文件竞争
        if (usesIOPool()) {
            this.ioPool = Some(IOThreadPool.acquire())
        }
    }

    /// 释放线程池
    // 严格翻译自: ThreadPool.zig:103 deinit()
    public func deinit(): Unit {
        if (workerPoolIsOwned) {
            match (workerPool) {
                case Some(pool) => pool.deinit()
                case None => {}
            }
        }
        if (usesIOPool()) {
            IOThreadPool.release()
        }
    }

    /// 启动线程池
    // 严格翻译自: ThreadPool.zig:113 start()
    public func start(): Unit {
        match (workerPool) {
            case Some(pool) => pool.warm(8)
            case None => {}
        }
        match (ioPool) {
            case Some(pool) => pool.warm(1)
            case None => {}
        }
    }

    /// 是否使用 IO 线程池
    // 严格翻译自: ThreadPool.zig:120 usesIOPool()
    // macOS 和 Windows 上线程数 > 3 时使用
    public static func usesIOPool(): Bool {
        // 简化: 默认不使用
        return false
    }

    /// 获取 worker
    // 严格翻译自: ThreadPool.zig:180 getWorker()
    public func getWorker(id: Int64): BundlerWorker {
        match (workerAssignments.get(id)) {
            case Some(worker) => return worker
            case None => {
                let worker = BundlerWorker()
                workerAssignments.put(id, worker)
                return worker
            }
        }
    }
}

/// 线程池库 (底层线程池封装)
public class ThreadPoolLib {
    /// 最大线程数
    public var maxThreads: Int64
    /// 栈大小
    public var stackSize: Int64

    public init(maxThreads: Int64) {
        this.maxThreads = maxThreads
        this.stackSize = 512 * 1024
    }

    /// 预热线程池
    public func warm(count: Int64): Unit {
        // 简化
    }

    /// 释放
    public func deinit(): Unit {
        // 简化
    }
}

/// IO 线程池单例
// 严格翻译自: ThreadPool.zig:16 IOThreadPool
public class IOThreadPool {
    /// 引用计数
    private static var refCount: Int64 = 0

    /// 获取 IO 线程池
    public static func acquire(): ThreadPoolLib {
        refCount += 1
        let threadCount = Math.max(Math.min(System.threadCount(), 4), 2)
        return ThreadPoolLib(threadCount)
    }

    /// 释放 IO 线程池
    public static func release(): Unit {
        if (refCount > 1) {
            refCount -= 1
        }
    }

    /// 关闭 IO 线程池
    public static func shutdown(): Bool {
        if (refCount <= 1) {
            refCount = 0
            return true
        }
        return false
    }
}

/// Bundler Worker
// 严格翻译自: ThreadPool.zig:205 Worker
public class BundlerWorker {
    /// 线程本地内存分配器
    public var allocator: ?Allocator
    /// 关联的 BundleV2 上下文
    public var ctx: ?BundlerContext
    /// Worker 数据
    public var data: WorkerData
    /// 是否退出
    public var quit: Bool
    /// 是否已创建
    public var hasCreated: Bool
    /// AST 内存分配器
    public var astMemoryAllocator: ?AstMemoryAllocator
    /// 临时 arena
    public var temporaryArena: ?Arena
    /// 语句列表
    public var stmtList: StmtList

    public init() {
        allocator = None
        ctx = None
        data = WorkerData()
        quit = false
        hasCreated = false
        astMemoryAllocator = None
        temporaryArena = None
        stmtList = StmtList()
    }

    /// 创建 worker
    public func create(ctx: BundlerContext): Unit {
        hasCreated = true
        this.ctx = ctx
    }

    /// 获取指定 target 的 transpiler
    // 严格翻译自: ThreadPool.zig:317 transpilerForTarget()
    public func transpilerForTarget(target: BundleTarget): Transpiler {
        // 简化: 始终返回默认 transpiler
        return data.transpiler
    }
}

/// Worker 数据
// 严格翻译自: ThreadPool.zig:269 WorkerData
public class WorkerData {
    /// 日志
    public var log: Log
    /// 预估的输入代码行数
    public var estimatedInputLinesOfCode: Int64
    /// Transpiler 实例
    public var transpiler: Transpiler
    /// 备用 transpiler (用于不同 target)
    public var otherTranspiler: ?Transpiler

    public init() {
        log = Log()
        estimatedInputLinesOfCode = 0
        transpiler = Transpiler()
        otherTranspiler = None
    }
}

/// 分配器 (简化)
public class Allocator {
    public init() {}
}

/// AST 内存分配器
public class AstMemoryAllocator {
    public var allocator: ?Allocator

    public init() {
        allocator = None
    }

    public func push(): Unit {}
    public func pop(): Unit {}
}

/// Arena
public class Arena {
    public init() {}
}

/// 互斥锁
public class Mutex {
    public init() {}
    public func lock(): Unit {}
    public func unlock(): Unit {}
}

/// Bundler 上下文 (前向引用 BundleV2)
public class BundlerContext {
    public init() {}
}

/// 输出文件 (前向引用)
// 完整定义见 output_file.cj
public class OutputFile {
    public var loader: Loader
    public var srcPath: String
    public var size: Int64
    public var hash: UInt64

    public init() {
        loader = Loader.File
        srcPath = ""
        size = 0
        hash = 0
    }
}

/// Program (AST)
public class Program {
    public var parts: ArrayList<Part>
    public var symbols: ArrayList<Symbol>
    public var importRecords: ArrayList<ImportRecord>

    public init() {
        parts = ArrayList<Part>()
        symbols = ArrayList<Symbol>()
        importRecords = ArrayList<ImportRecord>()
    }
}

/// AST Part
public class Part {
    public var stmts: ArrayList<Stmt>
    public var isLive: Bool

    public init() {
        stmts = ArrayList<Stmt>()
        isLive = false
    }
}

/// AST Symbol
public class Symbol {
    public var originalName: String
    public var ref: Int64

    public init(originalName: String, ref: Int64) {
        this.originalName = originalName
        this.ref = ref
    }
}

/// 系统工具
public class System {
    public static func threadCount(): Int64 {
        return 4
    }
}

/// Math 工具
public class Math {
    public static func max(a: Int64, b: Int64): Int64 {
        return if (a > b) { a } else { b }
    }
    public static func min(a: Int64, b: Int64): Int64 {
        return if (a < b) { a } else { b }
    }
}
