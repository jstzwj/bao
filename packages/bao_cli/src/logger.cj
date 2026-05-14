// 严格翻译自: src/logger.zig, src/output.zig, src/progress.zig
// bao CLI 日志与输出格式化
package bao_cli

import bao_core.*
import bao_collections.*
import bao_sys.*

// ============================================================================
// CLI 日志器 - 对应 Bun: src/output.zig, src/logger.zig
// 严格翻译自: src/output.zig (Output), src/progress.zig (Progress)
// ============================================================================

/// ANSI 颜色代码
/// 严格翻译自: src/output.zig ANSI color codes
public class AnsiColors {
    public static let RESET = "\u{001B}[0m"
    public static let BOLD = "\u{001B}[1m"
    public static let DIM = "\u{001B}[2m"
    public static let ITALIC = "\u{001B}[3m"
    public static let UNDERLINE = "\u{001B}[4m"

    // 前景色
    public static let RED = "\u{001B}[31m"
    public static let GREEN = "\u{001B}[32m"
    public static let YELLOW = "\u{001B}[33m"
    public static let BLUE = "\u{001B}[34m"
    public static let MAGENTA = "\u{001B}[35m"
    public static let CYAN = "\u{001B}[36m"
    public static let WHITE = "\u{001B}[37m"

    // 亮色
    public static let BRIGHT_RED = "\u{001B}[91m"
    public static let BRIGHT_GREEN = "\u{001B}[92m"
    public static let BRIGHT_YELLOW = "\u{001B}[93m"
    public static let BRIGHT_BLUE = "\u{001B}[94m"
    public static let BRIGHT_CYAN = "\u{001B}[96m"

    // 背景色
    public static let BG_RED = "\u{001B}[41m"
    public static let BG_GREEN = "\u{001B}[42m"
    public static let BG_BLUE = "\u{001B}[44m"

    /// 检测终端是否支持 ANSI 颜色
    // 严格翻译自: src/output.zig enable_ansi_colors
    public static func supportsColor(): Bool {
        // 检查 NO_COLOR 环境变量
        match (Sys.getEnv("NO_COLOR")) {
            case Some(_) => return false
            case None => {}
        }
        // 检查 FORCE_COLOR
        match (Sys.getEnv("FORCE_COLOR")) {
            case Some(_) => return true
            case None => {}
        }
        // 检查 TERM
        match (Sys.getEnv("TERM")) {
            case Some(term) => {
                if (term == "dumb") { return false }
                if (term.contains("color") || term.contains("256")) { return true }
            }
            case None => {}
        }
        // 检查是否是 TTY
        return Sys.isTerminal()
    }

    /// 给文本着色
    public static func colorize(text: String, color: String): String {
        if (!supportsColor()) { return text }
        return color + text + RESET
    }

    /// 红色文本
    public static func red(text: String): String {
        return colorize(text, RED)
    }

    /// 绿色文本
    public static func green(text: String): String {
        return colorize(text, GREEN)
    }

    /// 黄色文本
    public static func yellow(text: String): String {
        return colorize(text, YELLOW)
    }

    /// 蓝色文本
    public static func blue(text: String): String {
        return colorize(text, BLUE)
    }

    /// 青色文本
    public static func cyan(text: String): String {
        return colorize(text, CYAN)
    }

    /// 粗体文本
    public static func bold(text: String): String {
        return colorize(text, BOLD)
    }

    /// 暗淡文本
    public static func dim(text: String): String {
        return colorize(text, DIM)
    }
}

/// 日志级别
public enum LogLevel {
    | Debug
    | Info
    | Warn
    | Error
    | Silent

    public func toInt(): Int64 {
        match (this) {
            case Debug => 0
            case Info => 1
            case Warn => 2
            case Error => 3
            case Silent => 4
        }
    }
}

/// CLI 日志器
/// 严格翻译自: src/output.zig Output + src/logger.zig Log
public class Logger {
    private var level: LogLevel
    /// 是否启用 ANSI 颜色
    private var useColors: Bool
    /// 日志前缀
    private var prefix: String
    /// 是否启用缓冲
    private var buffered: Bool
    /// 缓冲区
    private var buffer: ArrayList<String>

    public init() {
        level = LogLevel.Info
        useColors = AnsiColors.supportsColor()
        prefix = ""
        buffered = false
        buffer = ArrayList<String>()
    }

    /// 设置日志级别
    public func setLevel(l: LogLevel): Unit {
        level = l
    }

    /// 设置前缀
    public func setPrefix(p: String): Unit {
        prefix = p
    }

    /// 启用/禁用缓冲
    public func setBuffered(b: Bool): Unit {
        buffered = b
        if (!b && buffer.size > 0) {
            flush()
        }
    }

    /// 刷新缓冲区
    public func flush(): Unit {
        for (line in buffer) {
            print(line)
        }
        buffer.clear()
    }

    /// Debug 级别日志
    // 严格翻译自: src/output.zig Output.pretty Debug
    public func debug(message: String): Unit {
        if (level.toInt() <= LogLevel.Debug.toInt()) {
            let formatted = formatMessage("debug", message, AnsiColors.DIM)
            output(formatted)
        }
    }

    /// Info 级别日志
    // 严格翻译自: src/output.zig Output.pretty Info
    public func info(message: String): Unit {
        if (level.toInt() <= LogLevel.Info.toInt()) {
            let formatted = formatMessage("info", message, AnsiColors.CYAN)
            output(formatted)
        }
    }

    /// 警告日志
    // 严格翻译自: src/output.zig Output.prettyWarn
    public func warn(message: String): Unit {
        if (level.toInt() <= LogLevel.Warn.toInt()) {
            let formatted = formatMessage("warn", message, AnsiColors.YELLOW)
            outputError(formatted)
        }
    }

    /// 错误日志
    // 严格翻译自: src/output.zig Output.prettyError
    public func error(message: String): Unit {
        if (level.toInt() <= LogLevel.Error.toInt()) {
            let formatted = formatMessage("error", message, AnsiColors.RED)
            outputError(formatted)
        }
    }

    /// 成功日志
    // 严格翻译自: src/output.zig Output.prettySuccess
    public func success(message: String): Unit {
        if (level.toInt() <= LogLevel.Info.toInt()) {
            let prefix = if (useColors) {
                AnsiColors.GREEN + AnsiColors.BOLD + "success" + AnsiColors.RESET
            } else {
                "success"
            }
            output("${prefix}: ${message}")
        }
    }

    /// 格式化消息
    private func formatMessage(tag: String, message: String, color: String): String {
        let tagPart = if (useColors) {
            color + tag + AnsiColors.RESET
        } else {
            tag
        }
        let prefixPart = if (prefix.isEmpty()) { "" } else { "[${prefix}] " }
        return "${prefixPart}${tagPart}: ${message}"
    }

    /// 输出到 stdout
    private func output(message: String): Unit {
        if (buffered) {
            buffer.append(message + "\n")
        } else {
            println(message)
        }
    }

    /// 输出到 stderr
    private func outputError(message: String): Unit {
        if (buffered) {
            buffer.append(message + "\n")
        } else {
            eprintln(message)
        }
    }
}

/// 进度条
/// 严格翻译自: src/progress.zig Progress / Progress.Node
public class ProgressBar {
    /// 总项数
    private var total: Int64
    /// 已完成项数
    private var completed: Int64
    /// 进度条宽度 (字符数)
    private var width: Int64
    /// 描述文字
    private var description: String
    /// 单位
    private var unit: ProgressUnit
    /// 开始时间 (毫秒)
    private var startTime: Int64
    /// 是否启用
    private var enabled: Bool
    /// 上次更新的完成数
    private var lastRendered: Int64

    public init(description: String, total: Int64) {
        this.total = total
        this.completed = 0
        this.width = 40
        this.description = description
        this.unit = ProgressUnit.Items
        this.startTime = Sys.currentTimeMillis()
        this.enabled = Sys.isTerminal()
        this.lastRendered = -1
    }

    /// 设置单位
    public func setUnit(u: ProgressUnit): ProgressBar {
        unit = u
        return this
    }

    /// 增加一个完成项
    public func completeOne(): Unit {
        completed++
        maybeRender()
    }

    /// 增加多个完成项
    public func complete(n: Int64): Unit {
        completed += n
        maybeRender()
    }

    /// 设置总项数
    public func setTotal(t: Int64): Unit {
        total = t
        maybeRender()
    }

    /// 设置描述
    public func setDescription(d: String): Unit {
        description = d
        maybeRender()
    }

    /// 结束进度条
    // 严格翻译自: src/progress.zig Progress.end
    public func end(): Unit {
        if (!enabled) { return }
        // 输出换行
        print("\r" + " ".repeat(Int64(width + 60)) + "\r")
        // 打印完成信息
        let elapsed = Sys.currentTimeMillis() - startTime
        let elapsedStr = formatDuration(elapsed)
        let msg = "${description} done in ${elapsedStr}"
        if (AnsiColors.supportsColor()) {
            println(AnsiColors.dim(msg))
        } else {
            println(msg)
        }
    }

    /// 刷新显示
    // 严格翻译自: src/progress.zig Progress.refresh
    public func refresh(): Unit {
        render()
    }

    /// 条件性渲染 (节流)
    private func maybeRender(): Unit {
        if (!enabled) { return }
        // 每 100ms 刷新一次, 或者完成时刷新
        if (completed != lastRendered || completed >= total) {
            render()
            lastRendered = completed
        }
    }

    /// 渲染进度条
    private func render(): Unit {
        if (!enabled) { return }
        if (total == 0) {
            // 不确定进度
            let spinner = getSpinnerChar()
            let line = "\r${spinner} ${description}..."
            print(line)
            return
        }

        let pct = completed * 100 / total
        let filled = completed * width / total
        let empty = width - filled

        let bar = "#".repeat(filled) + "-".repeat(empty)
        let pctStr = "${pct}%"

        // 额外信息
        let extra = match (unit) {
            case ProgressUnit.Items => " ${completed}/${total}"
            case ProgressUnit.Bytes => " ${formatBytes(completed)}/${formatBytes(total)}"
            case ProgressUnit.Seconds => ""
        }

        let line = "\r  ${description} [${bar}] ${pctStr}${extra}"
        print(line)
    }

    /// 获取 spinner 字符
    private var spinnerIndex: Int64 = 0
    private func getSpinnerChar(): String {
        let chars = ["-", "\\", "|", "/"]
        let idx = spinnerIndex % 4
        spinnerIndex++
        return chars[Int64(idx)]
    }

    /// 格式化持续时间
    private func formatDuration(ms: Int64): String {
        if (ms < 1000) {
            return "${ms}ms"
        }
        let seconds = ms / 1000
        if (seconds < 60) {
            let frac = (ms % 1000) / 100
            return "${seconds}.${frac}s"
        }
        let minutes = seconds / 60
        let secs = seconds % 60
        return "${minutes}m${secs}s"
    }

    /// 格式化字节数
    private func formatBytes(bytes: Int64): String {
        if (bytes < 1024) { return "${bytes}B" }
        if (bytes < 1024 * 1024) { return "${bytes / 1024}KB" }
        if (bytes < 1024 * 1024 * 1024) { return "${bytes / (1024 * 1024)}MB" }
        return "${bytes / (1024 * 1024 * 1024)}GB"
    }
}

/// 进度单位
/// 严格翻译自: src/progress.zig Progress.unit
public enum ProgressUnit {
    | Items
    | Bytes
    | Seconds
}

/// Spinner 加载指示器
/// 严格翻译自: src/progress.zig spinner animation
public class Spinner {
    private var frames: Array<String>
    private var currentIndex: Int64
    private var message: String
    private var running: Bool
    private var startTime: Int64

    public init(message: String) {
        this.frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
        this.currentIndex = 0
        this.message = message
        this.running = false
        this.startTime = Sys.currentTimeMillis()
    }

    /// 设置消息
    public func setMessage(msg: String): Unit {
        message = msg
        render()
    }

    /// 开始 spinner
    public func start(): Unit {
        running = true
        startTime = Sys.currentTimeMillis()
        render()
    }

    /// 停止 spinner 并显示完成消息
    // 严格翻译自: src/progress.zig end with success
    public func stop(success: Bool): Unit {
        running = false
        let elapsed = Sys.currentTimeMillis() - startTime
        let elapsedStr = formatElapsed(elapsed)
        let symbol = if (success) {
            if (AnsiColors.supportsColor()) {
                AnsiColors.GREEN + "done" + AnsiColors.RESET
            } else {
                "done"
            }
        } else {
            if (AnsiColors.supportsColor()) {
                AnsiColors.RED + "fail" + AnsiColors.RESET
            } else {
                "fail"
            }
        }
        // 清除行并打印结果
        println("\r${symbol} ${message} (${elapsedStr})")
    }

    /// 渲染当前帧
    private func render(): Unit {
        if (!running) { return }
        if (!Sys.isTerminal()) { return }
        let frame = frames[Int64(currentIndex % frames.size)]
        let line = "\r${frame} ${message}"
        print(line)
        currentIndex++
    }

    /// 格式化耗时
    private func formatElapsed(ms: Int64): String {
        if (ms < 1000) { return "${ms}ms" }
        let s = ms / 1000
        let frac = (ms % 1000) / 100
        return "${s}.${frac}s"
    }
}

/// 输出格式化工具
/// 严格翻译自: src/output.zig (Output.pretty, prettyError, etc.)
public class OutputFormatter {
    /// 格式化错误消息
    // 严格翻译自: src/output.zig prettyErr
    public static func formatError(message: String): String {
        if (AnsiColors.supportsColor()) {
            return AnsiColors.RED + "error" + AnsiColors.RESET + ": " + message
        }
        return "error: " + message
    }

    /// 格式化警告消息
    public static func formatWarn(message: String): String {
        if (AnsiColors.supportsColor()) {
            return AnsiColors.YELLOW + "warn" + AnsiColors.RESET + ": " + message
        }
        return "warn: " + message
    }

    /// 格式化信息消息
    public static func formatInfo(message: String): String {
        if (AnsiColors.supportsColor()) {
            return AnsiColors.CYAN + "info" + AnsiColors.RESET + ": " + message
        }
        return "info: " + message
    }

    /// 格式化成功消息
    public static func formatSuccess(message: String): String {
        if (AnsiColors.supportsColor()) {
            return AnsiColors.GREEN + "success" + AnsiColors.RESET + ": " + message
        }
        return "success: " + message
    }

    /// 格式化耗时
    // 严格翻译自: src/output.zig printStartEnd
    public static func formatElapsed(startTime: Int64, endTime: Int64): String {
        let diff = endTime - startTime
        if (diff < 1000) {
            return "${diff}ms"
        }
        let seconds = diff / 1000
        let frac = (diff % 1000) / 100
        return "${seconds}.${frac}s"
    }

    /// 格式化包大小
    public static func formatSize(bytes: Int64): String {
        if (bytes < 1024) { return "${bytes} B" }
        if (bytes < 1024 * 1024) {
            let kb = bytes / 1024
            return "${kb} KB"
        }
        let mb = bytes / (1024 * 1024)
        let kb = (bytes % (1024 * 1024)) / 1024
        return "${mb}.${kb} MB"
    }

    /// 格式化数量 (带复数)
    public static func pluralize(count: Int64, singular: String, plural: String): String {
        if (count == 1) { return "${count} ${singular}" }
        return "${count} ${plural}"
    }

    /// 格式化包列表 (用于 install/add 输出)
    public static func formatPackageList(packages: ArrayList<String>, maxShow: Int64): String {
        if (packages.size == 0) { return "(none)" }
        if (packages.size <= maxShow) {
            return packages.join(", ")
        }
        let shown = packages.slice(0, Int64(maxShow))
        return shown.join(", ") + ", +${packages.size - maxShow} more"
    }

    /// 输出带颜色的命令行
    public static func formatCommand(cmd: String): String {
        if (AnsiColors.supportsColor()) {
            return AnsiColors.DIM + "$ " + AnsiColors.BOLD + AnsiColors.CYAN + cmd + AnsiColors.RESET
        }
        return "$ ${cmd}"
    }
}
