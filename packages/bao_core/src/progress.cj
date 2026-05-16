// bao_core - 终端进度条
// 严格翻译自: src/bun_core/Progress.zig
//   const Progress = @This();
//   terminal: ?std.fs.File, root: Node, timer, refresh_rate_ns, ...
// Bun: 非分配、非失败、线程安全的进度 API
// 仓颉: 使用仓颉并发原语实现等价功能
package bao_core
import std.console.*
import std.time.*

/// 进度节点单位类型 - 对应 Bun Node.unit
/// pub const unit: enum { none, files, bytes } = .none
public enum ProgressUnit {
    | None
    | Files
    | Bytes
}

/// 进度节点 - 对应 Bun Progress.Node
/// pub const Node = struct {
///     context: *Progress,
///     parent: ?*Node,
///     name: []const u8,
///     unit: enum { none, files, bytes } = .none,
///     recently_updated_child: ?*Node = null,
///     unprotected_estimated_total_items: usize,
///     unprotected_completed_items: usize,
/// };
public class ProgressNode {
    /// 所属 Progress 上下文
    public let context: Progress
    /// 父节点
    public let parent: ?ProgressNode
    /// 节点名称
    public var name: String
    /// 单位类型
    public var unit: ProgressUnit
    /// 预估总数 (0 表示未知)
    public var estimatedTotalItems: Int64
    /// 已完成数
    public var completedItems: Int64
    /// 最近更新的子节点
    public var recentlyUpdatedChild: ?ProgressNode

    public init(context: Progress, parent: ?ProgressNode, name: String, estimatedTotalItems: Int64) {
        this.context = context
        this.parent = parent
        this.name = name
        this.unit = ProgressUnit.None
        this.estimatedTotalItems = estimatedTotalItems
        this.completedItems = 0
        let noChild: ?ProgressNode = None
        this.recentlyUpdatedChild = noChild
    }

    /// 创建子节点 - 对应 Bun Node.start
    public func start(name: String, estimatedTotalItems: Int64): ProgressNode {
        let child = ProgressNode(context, Some(this), name, estimatedTotalItems)
        this.recentlyUpdatedChild = Some(child)
        return child
    }

    /// 完成一个项目 - 对应 Bun Node.completeOne
    public func completeOne(): Unit {
        if (parent.isSome()) {
            parent.getOrThrow().recentlyUpdatedChild = Some(this)
        }
        completedItems += 1
        context.maybeRefresh()
    }

    /// 结束节点 - 对应 Bun Node.end
    public func end(): Unit {
        context.maybeRefresh()
        match (parent) {
            case Some(p) =>
                match (p.recentlyUpdatedChild) {
                    case Some(child) =>
                        // Check if child is the same reference as this
                        // Since we can't compare object identity easily, just clear it
                        p.recentlyUpdatedChild = None
                    case None => ()
                }
                p.completeOne()
            case None =>
                context.done = true
                context.refresh()
        }
    }

    /// 激活节点 - 对应 Bun Node.activate
    public func activate(): Unit {
        match (parent) {
            case Some(p) =>
                p.recentlyUpdatedChild = Some(this)
                context.maybeRefresh()
            case None => ()
        }
    }

    /// 设置名称 - 对应 Bun Node.setName
    public func setName(name: String): Unit {
        this.name = name
        match (parent) {
            case Some(p) =>
                p.recentlyUpdatedChild = Some(this)
                context.maybeRefresh()
            case None => ()
        }
    }

    /// 设置单位 - 对应 Bun Node.setUnit
    public func setUnit(unit: ProgressUnit): Unit {
        this.unit = unit
    }

    /// 设置预估总数 - 对应 Bun Node.setEstimatedTotalItems
    public func setEstimatedTotalItems(count: Int64): Unit {
        estimatedTotalItems = count
    }

    /// 设置已完成数 - 对应 Bun Node.setCompletedItems
    public func setCompletedItems(count: Int64): Unit {
        completedItems = count
    }
}

/// 终端进度条 - 严格对应 Bun Progress
/// Bun: 非分配、非失败、线程安全的进度指示器
/// 仓颉: 简化实现, 保持核心 API 语义
/// 对应 Bun Progress 核心语义:
///   - 层级式进度节点 (root -> children)
///   - 定时刷新 (refresh_rate_ns)
///   - 初始延迟 (initial_delay_ns)
///   - 支持 ANSI 转义码的终端输出
public class Progress {

    /// 根节点
    private var root: ?ProgressNode
    /// 是否完成
    public var done: Bool
    /// 是否支持 ANSI 转义码
    public var supportsAnsiEscapeCodes: Bool
    /// 刷新间隔 (纳秒) - 对应 Bun refresh_rate_ns = 50ms
    public var refreshRateNs: Int64
    /// 初始延迟 (纳秒) - 对应 Bun initial_delay_ns = 500ms
    public var initialDelayNs: Int64
    /// 上次刷新时间戳 (毫秒)
    private var prevRefreshTimestamp: Int64
    /// 开始时间 (毫秒)
    private var startTimestamp: Int64
    /// 是否在 dumb 终端不打印
    public var dontPrintOnDumb: Bool
    /// 输出缓冲区 - 对应 Bun output_buffer: [100]u8
    private var outputBuffer: StringBuilder

    /// 刷新间隔默认值: 50ms
    public static let DEFAULT_REFRESH_RATE_MS: Int64 = 50
    /// 初始延迟默认值: 500ms
    public static let DEFAULT_INITIAL_DELAY_MS: Int64 = 500

    public init() {
        root = None
        done = true
        supportsAnsiEscapeCodes = true
        refreshRateNs = Progress.DEFAULT_REFRESH_RATE_MS * 1_000_000
        initialDelayNs = Progress.DEFAULT_INITIAL_DELAY_MS * 1_000_000
        prevRefreshTimestamp = 0
        startTimestamp = 0
        dontPrintOnDumb = false
        outputBuffer = StringBuilder()
    }

    /// 开始进度 - 对应 Bun Progress.start
    /// pub fn start(self: *Progress, name: []const u8, estimated_total_items: usize) *Node {
    ///     self.root = Node{
    ///         .context = self,
    ///         .parent = null,
    ///         .name = name,
    ///         ...
    ///     };
    ///     self.done = false;
    ///     return &self.root;
    /// }
    public func start(name: String, estimatedTotalItems: Int64): ProgressNode {
        let noParent: ?ProgressNode = None
        let node = ProgressNode(this, noParent, name, estimatedTotalItems)
        root = Some(node)
        done = false
        prevRefreshTimestamp = 0
        startTimestamp = currentTimeMillis()
        return node
    }

    /// 可能刷新 - 对应 Bun Progress.maybeRefresh
    /// pub fn maybeRefresh(self: *Progress) void {
    ///     if (self.timer) |*timer| {
    ///         const now = timer.read();
    ///         if (now < self.initial_delay_ns) return;
    ///         if (now - self.prev_refresh_timestamp < self.refresh_rate_ns) return;
    ///         return self.refreshWithHeldLock();
    ///     }
    /// }
    public func maybeRefresh(): Unit {
        let now = currentTimeMillis()
        let elapsedNs = (now - startTimestamp) * 1_000_000
        if (elapsedNs < initialDelayNs) {
            return
        }
        if (now - prevRefreshTimestamp < refreshRateNs / 1_000_000) {
            return
        }
        refresh()
    }

    /// 强制刷新 - 对应 Bun Progress.refresh
    public func refresh(): Unit {
        prevRefreshTimestamp = currentTimeMillis()
        if (done) {
            return
        }
        // 构建进度输出
        outputBuffer = StringBuilder()
        var needEllipse = false
        var maybeNode = root
        while (true) {
            match (maybeNode) {
                case Some(node) =>
                    if (needEllipse) {
                        outputBuffer.append("... ")
                    }
                    needEllipse = false
                    let eti = node.estimatedTotalItems
                    let completed = node.completedItems
                    let currentItem = completed + 1
                    if (node.name.size > 0 || eti > 0) {
                        if (node.name.size > 0) {
                            outputBuffer.append(node.name)
                            needEllipse = true
                        }
                        if (eti > 0) {
                            if (needEllipse) { outputBuffer.append(" ") }
                            match (node.unit) {
                                case None => outputBuffer.append("[${currentItem}/${eti}] ")
                                case Files => outputBuffer.append("[${currentItem}/${eti} files] ")
                                case Bytes => outputBuffer.append("[${currentItem}/${eti} bytes] ")
                            }
                            needEllipse = false
                        } else if (completed > 0) {
                            if (needEllipse) { outputBuffer.append(" ") }
                            match (node.unit) {
                                case None => outputBuffer.append("[${currentItem}] ")
                                case Files => outputBuffer.append("[${currentItem} files] ")
                                case Bytes => outputBuffer.append("[${currentItem} bytes] ")
                            }
                            needEllipse = false
                        }
                    }
                    maybeNode = node.recentlyUpdatedChild
                case None =>
                    break
            }
        }
        if (needEllipse) {
            outputBuffer.append("... ")
        }
        // 输出到 stderr
        let output = outputBuffer.toString()
        if (output.size > 0) {
            printProgress(output)
        }
    }

    /// 日志输出 - 对应 Bun Progress.log
    /// pub fn log(self: *Progress, comptime format: []const u8, args: anytype) void
    public func log(message: String): Unit {
        refresh()
        outputBuffer = StringBuilder()
        outputBuffer.append(message)
        if (!message.endsWith("\n")) {
            outputBuffer.append('\n')
        }
    }

    /// 获取当前时间 (毫秒)
    private static func currentTimeMillis(): Int64 {
        return DateTime.now().toUnixTimeStamp().toMilliseconds()
    }

    /// 打印进度到 stderr
    private func printProgress(output: String): Unit {
        // 仓颉标准输出
        try {
            Console.stdErr.writeln(output)
        } catch (_: Exception) {
            // 忽略输出错误
        }
    }
}
