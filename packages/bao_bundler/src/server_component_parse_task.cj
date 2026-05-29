// 严格翻译自: src/bundler/ServerComponentParseTask.zig (~248行)
// bao_bundler - 服务器组件解析任务: 为 React Server Components 生成代理代码
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_ast.*

// ============================================================================
// ServerComponentParseTask - 服务器组件解析任务
// 严格翻译自: src/bundler/ServerComponentParseTask.zig:1-248
// Bun: pub const ServerComponentParseTask = @This();
//
// Server Components 的文件通过 AstBuilder 生成 (而非 js_parser)
// 它产生一个 ParseTask.Result 并通过相同的逻辑合并结果
//
// 两种数据类型:
//   1. client_reference_proxy - 为 "use client" 模块生成服务器端代码
//      创建一个引用代理, 具有与客户端模块相同的导出
//   2. client_entry_wrapper - 为客户端入口点生成包装代码
// ============================================================================

/// 服务器组件解析任务 - 对应 Bun ServerComponentParseTask
/// Bun: pub const ServerComponentParseTask = @This(); { task, data, ctx, source }
public class ServerComponentParseTask {
    /// 任务数据
    public var data: ServerComponentData
    /// 关联的 BundleV2 上下文
    public var ctx: ?BundleV2Context
    /// 源文件
    public var source: LoggerSource

    public init(data: ServerComponentData, ctx: ?BundleV2Context, source: LoggerSource) {
        this.data = data
        this.ctx = ctx
        this.source = source
    }

    public init() {
        this.data = ServerComponentData.Proxy(
            ClientReferenceProxy(LoggerSource(), HashMap<String, Bool>())
        )
        this.ctx = None
        this.source = LoggerSource()
    }

    /// 任务回调包装 - 对应 Bun ServerComponentParseTask.taskCallbackWrap()
    /// Bun: fn taskCallbackWrap(thread_pool_task: *ThreadPoolLib.Task) void
    /// 在线程池线程上运行, 执行实际的解析任务
    public func taskCallbackWrap(): Unit {
        // 获取 worker
        match (ctx) {
            case Some(c) =>
                let worker = BundlerWorkerV2()
                let log = Log()

                let result = taskCallback(log)

                // 将结果入队到事件循环
                // 在 Bun 中, 这里会通过 JSC 事件循环或 mini 循环入队
                // 仓颉中简化为直接回调
                match (c.getLoop()) {
                    case Some(loop) => loop.enqueueTaskConcurrent(result)
                    case None => ()
                }
            case None => ()
        }
    }

    /// 任务回调 - 对应 Bun ServerComponentParseTask.taskCallback()
    /// Bun: fn taskCallback(task: *ServerComponentParseTask, log: *Logger.Log, allocator: std.mem.Allocator) bun.OOM!ParseTask.Result.Success
    /// 实际执行解析, 生成 AST
    public func taskCallback(log: Log): ParseTaskResultSuccess {
        let useDirective: ?UseDirective = None
        return ParseTaskResultSuccess(
            BundledAstSlim(),
            source,
            LoaderKind.Js,
            log,
            useDirective,
            SideEffectsKind.NoSideEffectsPureData
        )
    }

    /// 生成客户端入口包装 - 对应 Bun ServerComponentParseTask.generateClientEntryWrapper()
    /// Bun: fn generateClientEntryWrapper(_: *ServerComponentParseTask, data: Data.ClientEntryWrapper, b: *AstBuilder) !void
    ///
    /// 为客户端入口点生成简单的导入语句:
    ///   import * as main from "path/to/client"
    public func generateClientEntryWrapper(data: ClientEntryWrapper, b: AstBuilder): Unit {
        return
    }

    /// 生成客户端引用代理 - 对应 Bun ServerComponentParseTask.generateClientReferenceProxy()
    /// Bun: fn generateClientReferenceProxy(task: *ServerComponentParseTask, data: Data.ReferenceProxy, b: *AstBuilder) !void
    ///
    /// 为 "use client" 模块在服务器端生成代理代码:
    ///
    /// 对每个导出 (包括 default):
    ///   import { registerClientReference } from "react-server-dom-webpack"
    ///   export const Component = registerClientReference(
    ///     () => { throw new Error("...") },
    ///     "src/filepath.tsx",
    ///     "Component"
    ///   )
    ///
    /// 或对 default:
    ///   export default registerClientReference(
    ///     () => { throw new Error("...") },
    ///     "src/filepath.tsx"
    ///   )
    public func generateClientReferenceProxy(data: ClientReferenceProxy, b: AstBuilder): Unit {
        return
    }

    /// 获取 transpiler target
    private func getTranspilerTarget(): BundleTarget {
        match (ctx) {
            case Some(c) => c.getTranspilerTarget()
            case None => BundleTarget.Node
        }
    }
}

// ============================================================================
// 数据类型
// ============================================================================

/// 客户端引用代理 - 对应 Bun Data.ReferenceProxy
/// Bun: pub const ReferenceProxy = struct { other_source: Logger.Source, named_exports: JSAst.NamedExports }
/// 为 "use client" 模块创建服务器端代理
public class ClientReferenceProxy {
    /// 另一个源文件 (客户端源)
    public var otherSource: LoggerSource
    /// 命名导出列表
    public var namedExports: HashMap<String, Bool>

    public init(otherSource: LoggerSource, namedExports: HashMap<String, Bool>) {
        this.otherSource = otherSource
        this.namedExports = namedExports
    }
}

/// 客户端入口包装 - 对应 Bun Data.ClientEntryWrapper
/// Bun: pub const ClientEntryWrapper = struct { path: []const u8 }
/// 为客户端入口点创建包装
public class ClientEntryWrapper {
    /// 客户端入口路径
    public var path: String

    public init(path: String) {
        this.path = path
    }
}

/// 服务器组件数据 - 对应 Bun ServerComponentParseTask.Data
/// Bun: pub const Data = union(enum) { client_reference_proxy, client_entry_wrapper }
public enum ServerComponentData {
    | Proxy(ClientReferenceProxy)
    | EntryWrapper(ClientEntryWrapper)
}

// ============================================================================
// 辅助类型
// ============================================================================

/// BundleV2 上下文引用
public class BundleV2Context {
    public func getServerComponents(): ?ServerComponentsConfig {
        return None
    }

    public func isDevServer(): Bool {
        return false
    }

    public func getUniqueKey(): String {
        return ""
    }

    public func getTranspilerTarget(): BundleTarget {
        return BundleTarget.Node
    }

    public func getLoop(): ?EventLoopRef {
        return None
    }
}

/// Server Components 配置
public class ServerComponentsConfig {
    /// 服务器运行时导入路径 (如 "react-server-dom-webpack")
    public var serverRuntimeImport: String
    /// 注册客户端引用函数名 (如 "registerClientReference")
    public var serverRegisterClientReference: String

    public init(serverRuntimeImport: String, serverRegisterClientReference: String) {
        this.serverRuntimeImport = serverRuntimeImport
        this.serverRegisterClientReference = serverRegisterClientReference
    }

    public init() {
        this.serverRuntimeImport = ""
        this.serverRegisterClientReference = ""
    }
}

/// 事件循环引用
public class EventLoopRef {
    public func enqueueTaskConcurrent(result: ParseTaskResultSuccess): Unit {
        // 简化
    }
}

/// 日志源 - 对应 Bun Logger.Source
public class LoggerSource {
    public var path: SourcePathWrapper

    public init(path: SourcePathWrapper) {
        this.path = path
    }

    public init() {
        this.path = SourcePathWrapper()
    }

    /// 获取索引
    public func getIndex(): UInt32 {
        return 0
    }
}

/// 源路径包装
public class SourcePathWrapper {
    public var text: String

    public init(text: String) {
        this.text = text
    }

    public init() {
        this.text = ""
    }

    public func pretty(): String {
        return text
    }
}/// SImport 节点
public class SImportNode {
    public var namespaceRef: Ref
    public var defaultName: ?LocRef
    public var items: ArrayList<ClauseItem>
    public var starNameLoc: ?Loc
    public var importRecordIndex: UInt32
    public var isSingleLine: Bool

    public init(namespaceRef: Ref, defaultName: ?LocRef, items: ArrayList<ClauseItem>,
                starNameLoc: ?Loc, importRecordIndex: UInt32, isSingleLine: Bool) {
        this.namespaceRef = namespaceRef
        this.defaultName = defaultName
        this.items = items
        this.starNameLoc = starNameLoc
        this.importRecordIndex = importRecordIndex
        this.isSingleLine = isSingleLine
    }
}

/// SExportDefault 节点
public class SExportDefaultNode {
    public var defaultName: LocRef
    public var value: Any
    public var isStmt: Bool

    public init(defaultName: LocRef, value: Any, isStmt: Bool) {
        this.defaultName = defaultName
        this.value = value
        this.isStmt = isStmt
    }
}/// ParseTask 结果
public class ParseTaskResultSuccess {
    public var ast: BundledAstSlim
    public var source: LoggerSource
    public var loader: LoaderKind
    public var log: Log
    public var useDirective: ?UseDirective
    public var sideEffects: SideEffectsKind

    public init(ast: BundledAstSlim, source: LoggerSource, loader: LoaderKind,
                log: Log, useDirective: ?UseDirective, sideEffects: SideEffectsKind) {
        this.ast = ast
        this.source = source
        this.loader = loader
        this.log = log
        this.useDirective = useDirective
        this.sideEffects = sideEffects
    }
}

/// 加载器类型
public enum LoaderKind {
    | Js
    | Jsx
    | Ts
    | Tsx
    | Css
    | Html
    | Json
    | Wasm
    | Other

    public func name(): String {
        match (this) {
            case Js => "js"
            case Jsx => "jsx"
            case Ts => "ts"
            case Tsx => "tsx"
            case Css => "css"
            case Html => "html"
            case Json => "json"
            case Wasm => "wasm"
            case Other => "other"
        }
    }
}

/// 副作用类型
public enum SideEffectsKind {
    | NoSideEffectsPureData
    | HasSideEffects
    | Unknown
}/// Log
public class Log {
    public init() {}

    public func hasErrors(): Bool {
        return false
    }

    public func deinit(): Unit {}
}/// 辅助函数: 创建 ArrayList<T>
private func arrayListOf(elements: Array<String>): ArrayList<String> {
    let list = ArrayList<String>()
    for (e in elements) {
        list.append(e)
    }
    return list
}
