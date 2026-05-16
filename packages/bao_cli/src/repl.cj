// 严格翻译自: src/cli/repl.zig
package bao_cli

import bao_core.*
import bao_jsc.*
import bao_install.*

// ============================================================================
// Repl — Read-Eval-Print Loop
// 严格翻译自: src/cli/repl.zig
//
// 原生 REPL 实现, 支持:
// - 语法高亮 (QuickAndDirtySyntaxHighlighter)
// - 行编辑 (Emacs 风格键绑定)
// - 持久化历史
// - Tab 补全
// - 多行输入
// - REPL 命令 (.help, .exit, .clear, .load, .save, .editor)
// - 结果格式化
// ============================================================================

// ============================================================================
// 常量
// ============================================================================

/// 最大历史记录数
private let MAX_HISTORY_SIZE: Int64 = 1000

/// 最大行长度
private let MAX_LINE_LENGTH: Int64 = 16384

/// 历史文件名
private let HISTORY_FILENAME = ".bao_repl_history"

/// Tab 宽度
private let TAB_WIDTH: Int64 = 2

// ============================================================================
// ANSI 转义码
// ============================================================================

/// ANSI 颜色代码
private class Color {
    public static let reset = "\u001b[0m"
    public static let bold = "\u001b[1m"
    public static let dim = "\u001b[2m"
    public static let red = "\u001b[31m"
    public static let green = "\u001b[32m"
    public static let yellow = "\u001b[33m"
    public static let blue = "\u001b[34m"
    public static let magenta = "\u001b[35m"
    public static let cyan = "\u001b[36m"
    public static let white = "\u001b[37m"
}

/// 光标控制代码
private class CursorControl {
    public static let hide = "\u001b[?25l"
    public static let show = "\u001b[?25h"
    public static let save = "\u001b7"
    public static let restore = "\u001b8"
    public static let home = "\u001b[H"
    public static let clearLine = "\u001b[2K"
    public static let clearToEnd = "\u001b[0K"
    public static let clearToStart = "\u001b[1K"
    public static let clearScreen = "\u001b[2J"
    public static let clearScrollback = "\u001b[3J"
}

// ============================================================================
// 按键码
// ============================================================================

/// 按键码
/// 对应 Bun: Key
public enum Key {
    // 控制键
    | ctrlA
    | ctrlB
    | ctrlC
    | ctrlD
    | ctrlE
    | ctrlF
    | ctrlK
    | ctrlL
    | ctrlN
    | ctrlP
    | ctrlR
    | ctrlT
    | ctrlU
    | ctrlW
    | backspace
    | tab
    | enter
    | escape

    // 特殊键
    | delete
    | home
    | end
    | pageUp
    | pageDown
    | arrowUp
    | arrowDown
    | arrowRight
    | arrowLeft

    // Alt 组合键
    | altB
    | altD
    | altF
    | altBackspace
    | altLeft
    | altRight

    // 可打印字符
    | char_(UInt8)

    // 未知按键
    | unknown

    /// 从字节解析按键
    /// 对应 Bun: Key.fromByte
    public static func fromByte(byte: UInt8): Key {
        when (byte) {
            case 1 => return Key.ctrlA
            case 2 => return Key.ctrlB
            case 3 => return Key.ctrlC
            case 4 => return Key.ctrlD
            case 5 => return Key.ctrlE
            case 6 => return Key.ctrlF
            case 11 => return Key.ctrlK
            case 12 => return Key.ctrlL
            case 14 => return Key.ctrlN
            case 16 => return Key.ctrlP
            case 18 => return Key.ctrlR
            case 20 => return Key.ctrlT
            case 21 => return Key.ctrlU
            case 23 => return Key.ctrlW
            case 8, 127 => return Key.backspace
            case 9 => return Key.tab
            case 10, 13 => return Key.enter
            case 27 => return Key.escape
            case _ => {
                if (byte >= 32 && byte <= 126) {
                    return Key.char_(byte)
                }
                return Key.unknown
            }
        }
    }
}

// ============================================================================
// History — 历史记录
// ============================================================================

/// REPL 历史记录
/// 对应 Bun: History
public class History {
    public var entries: ArrayList<String> = ArrayList<String>()
    public var position: Int64 = 0
    public var tempLine: ?String = None
    public var filePath: ?String = None
    public var allocator: Allocator
    public var modified: Bool = false

    public init(allocator: Allocator) {
        this.allocator = allocator
    }

    /// 从文件加载历史
    /// 对应 Bun: History.load
    public func load(): Unit {
        let homePath = EnvVar.HOME.get()
        if (homePath == None || homePath!!.length == 0) {
            return
        }

        let path = Path.join([homePath!!, HISTORY_FILENAME])
        filePath = path

        let content = BaoFile.readAllText(path)
        if (content == None) {
            return
        }

        let lines = content!!.split('\n')
        for (line in lines) {
            if (line.length > 0) {
                entries.append(line)
            }
        }

        // 修剪到最大大小
        while (entries.size > MAX_HISTORY_SIZE) {
            entries.removeAt(0)
        }

        position = entries.size
    }

    /// 保存历史到文件
    /// 对应 Bun: History.save
    public func save(): Unit {
        if (!modified) {
            return
        }
        let path = filePath ?: return

        let start = if (entries.size > MAX_HISTORY_SIZE) {
            entries.size - MAX_HISTORY_SIZE
        } else {
            0
        }

        let content = StringBuilder()
        for (i in start..entries.size) {
            content.append(entries[i.toInt()])
            content.append('\n')
        }

        BaoFile.writeAllText(path, content.toString())
        modified = false
    }

    /// 添加历史条目
    /// 对应 Bun: History.add
    public func add(line: String): Unit {
        if (line.length == 0) {
            return
        }

        // 不添加与最后一条重复的条目
        if (entries.size > 0) {
            let last = entries[entries.size - 1]
            if (last == line) {
                position = entries.size
                return
            }
        }

        entries.append(line)
        position = entries.size
        modified = true

        // 修剪
        while (entries.size > MAX_HISTORY_SIZE) {
            entries.removeAt(0)
            if (position > 0) {
                position -= 1
            }
        }
    }

    /// 获取上一条历史
    /// 对应 Bun: History.prev
    public func prev(currentLine: String): ?String {
        if (entries.size == 0) {
            return None
        }

        // 如果在末尾, 保存当前行
        if (position == entries.size) {
            tempLine = currentLine
        }

        if (position > 0) {
            position -= 1
            return entries[position.toInt()]
        }

        return None
    }

    /// 获取下一条历史
    /// 对应 Bun: History.next
    public func next(): ?String {
        if (position < entries.size) {
            position += 1
        }

        if (position == entries.size) {
            return tempLine
        }

        if (position < entries.size) {
            return entries[position.toInt()]
        }

        return None
    }

    /// 重置位置
    /// 对应 Bun: History.resetPosition
    public func resetPosition(): Unit {
        position = entries.size
        tempLine = None
    }
}

// ============================================================================
// LineEditor — 行编辑器
// ============================================================================

/// 行编辑器
/// 对应 Bun: LineEditor
public class LineEditor {
    public var buffer: ArrayList<UInt8> = ArrayList<UInt8>()
    public var cursor: Int64 = 0
    public var allocator: Allocator

    public init(allocator: Allocator) {
        this.allocator = allocator
    }

    /// 清空
    /// 对应 Bun: LineEditor.clear
    public func clear(): Unit {
        buffer.clear()
        cursor = 0
    }

    /// 设置内容
    /// 对应 Bun: LineEditor.set
    public func set(text: String): Unit {
        buffer.clear()
        for (c in text) {
            buffer.append(c.toUInt8())
        }
        cursor = text.length
    }

    /// 插入字符
    /// 对应 Bun: LineEditor.insert
    public func insert(char: UInt8): Unit {
        if (cursor == buffer.size) {
            buffer.append(char)
        } else {
            buffer.insert(cursor.toInt(), char)
        }
        cursor += 1
    }

    /// 插入字符串
    /// 对应 Bun: LineEditor.insertSlice
    public func insertSlice(slice: String): Unit {
        if (cursor == buffer.size) {
            for (c in slice) {
                buffer.append(c.toUInt8())
            }
        } else {
            for ((i, c) in slice) {
                buffer.insert((cursor + i).toInt(), c.toUInt8())
            }
        }
        cursor += slice.length
    }

    /// 删除光标处字符
    /// 对应 Bun: LineEditor.deleteChar
    public func deleteChar(): Unit {
        if (cursor < buffer.size) {
            buffer.removeAt(cursor.toInt())
        }
    }

    /// 退格
    /// 对应 Bun: LineEditor.backspace
    public func backspace(): Unit {
        if (cursor > 0) {
            cursor -= 1
            buffer.removeAt(cursor.toInt())
        }
    }

    /// 向前删除单词
    /// 对应 Bun: LineEditor.deleteWord
    public func deleteWord(): Unit {
        while (cursor < buffer.size && buffer[cursor.toInt()].isWhitespace()) {
            buffer.removeAt(cursor.toInt())
        }
        while (cursor < buffer.size && !buffer[cursor.toInt()].isWhitespace()) {
            buffer.removeAt(cursor.toInt())
        }
    }

    /// 向后删除单词
    /// 对应 Bun: LineEditor.backspaceWord
    public func backspaceWord(): Unit {
        while (cursor > 0 && buffer[(cursor - 1).toInt()].isWhitespace()) {
            cursor -= 1
            buffer.removeAt(cursor.toInt())
        }
        while (cursor > 0 && !buffer[(cursor - 1).toInt()].isWhitespace()) {
            cursor -= 1
            buffer.removeAt(cursor.toInt())
        }
    }

    /// 删除到行尾
    /// 对应 Bun: LineEditor.deleteToEnd
    public func deleteToEnd(): Unit {
        while (buffer.size > cursor) {
            buffer.removeAt(cursor.toInt())
        }
    }

    /// 删除到行首
    /// 对应 Bun: LineEditor.deleteToStart
    public func deleteToStart(): Unit {
        if (cursor > 0) {
            while (cursor > 0) {
                cursor -= 1
                buffer.removeAt(cursor.toInt())
            }
        }
    }

    /// 左移光标
    /// 对应 Bun: LineEditor.moveLeft
    public func moveLeft(): Unit {
        if (cursor > 0) {
            cursor -= 1
        }
    }

    /// 右移光标
    /// 对应 Bun: LineEditor.moveRight
    public func moveRight(): Unit {
        if (cursor < buffer.size) {
            cursor += 1
        }
    }

    /// 左移一个单词
    /// 对应 Bun: LineEditor.moveWordLeft
    public func moveWordLeft(): Unit {
        while (cursor > 0 && buffer[(cursor - 1).toInt()].isWhitespace()) {
            cursor -= 1
        }
        while (cursor > 0 && !buffer[(cursor - 1).toInt()].isWhitespace()) {
            cursor -= 1
        }
    }

    /// 右移一个单词
    /// 对应 Bun: LineEditor.moveWordRight
    public func moveWordRight(): Unit {
        while (cursor < buffer.size && !buffer[cursor.toInt()].isWhitespace()) {
            cursor += 1
        }
        while (cursor < buffer.size && buffer[cursor.toInt()].isWhitespace()) {
            cursor += 1
        }
    }

    /// 移动到行首
    /// 对应 Bun: LineEditor.moveToStart
    public func moveToStart(): Unit {
        cursor = 0
    }

    /// 移动到行尾
    /// 对应 Bun: LineEditor.moveToEnd
    public func moveToEnd(): Unit {
        cursor = buffer.size
    }

    /// 交换字符
    /// 对应 Bun: LineEditor.swap
    public func swap(): Unit {
        if (cursor > 0 && cursor < buffer.size) {
            let temp = buffer[(cursor - 1).toInt()]
            buffer[(cursor - 1).toInt()] = buffer[cursor.toInt()]
            buffer[cursor.toInt()] = temp
            cursor += 1
        } else if (cursor > 1 && cursor == buffer.size) {
            let temp = buffer[(cursor - 2).toInt()]
            buffer[(cursor - 2).toInt()] = buffer[(cursor - 1).toInt()]
            buffer[(cursor - 1).toInt()] = temp
        }
    }

    /// 获取当前行
    /// 对应 Bun: LineEditor.getLine
    public func getLine(): String {
        let sb = StringBuilder()
        for (b in buffer) {
            sb.append(b.toChar())
        }
        return sb.toString()
    }
}

// ============================================================================
// ReplResult — REPL 命令结果
// ============================================================================

/// REPL 命令结果
/// 对应 Bun: ReplResult
public enum ReplResult {
    | continueRepl
    | exitRepl
    | skipEval
}

// ============================================================================
// ReplCommand — REPL 命令
// ============================================================================

/// REPL 命令定义
/// 对应 Bun: ReplCommand
public class ReplCommandDef {
    public var name: String
    public var help: String
    public var handler: (Repl, String) -> ReplResult

    public init(name: String, help: String, handler: (Repl, String) -> ReplResult) {
        this.name = name
        this.help = help
        this.handler = handler
    }

    /// 所有命令
    /// 对应 Bun: ReplCommand.all
    public static func all(): ArrayList<ReplCommandDef> {
        let result = ArrayList<ReplCommandDef>()
        result.append(ReplCommandDef(".help", "Print this help message", ReplCommandHandlers.cmdHelp))
        result.append(ReplCommandDef(".exit", "Exit the REPL", ReplCommandHandlers.cmdExit))
        result.append(ReplCommandDef(".clear", "Clear the screen", ReplCommandHandlers.cmdClear))
        result.append(ReplCommandDef(".copy", "Copy result to clipboard (.copy [expr])", ReplCommandHandlers.cmdCopy))
        result.append(ReplCommandDef(".load", "Load a file into the REPL session", ReplCommandHandlers.cmdLoad))
        result.append(ReplCommandDef(".save", "Save REPL history to a file", ReplCommandHandlers.cmdSave))
        result.append(ReplCommandDef(".editor", "Enter multi-line editor mode", ReplCommandHandlers.cmdEditor))
        result.append(ReplCommandDef(".break", "Cancel current input", ReplCommandHandlers.cmdBreak))
        result.append(ReplCommandDef(".history", "Show command history", ReplCommandHandlers.cmdHistory))
        return result
    }

    /// 查找命令
    /// 对应 Bun: ReplCommand.find
    public static func find(name: String): ?ReplCommandDef {
        for (cmd in all()) {
            if (cmd.name == name || (name.length > 1 && cmd.name.startsWith(name))) {
                return cmd
            }
        }
        return None
    }
}

/// REPL 命令处理器
/// 对应 Bun: cmdHelp, cmdExit, cmdClear, etc.
public class ReplCommandHandlers {
    public static func cmdHelp(repl: Repl, args: String): ReplResult {
        repl.print("\n${Color.bold}REPL Commands:${Color.reset}\n")
        for (cmd in ReplCommandDef.all()) {
            repl.print("  ${Color.cyan}${cmd.name.padEnd(12)}${Color.reset} ${cmd.help}\n")
        }
        repl.print("\n${Color.bold}Keybindings:${Color.reset}\n")
        repl.print("  ${Color.cyan}Ctrl+A${Color.reset}       Move to start of line\n")
        repl.print("  ${Color.cyan}Ctrl+E${Color.reset}       Move to end of line\n")
        repl.print("  ${Color.cyan}Ctrl+B/F${Color.reset}     Move backward/forward one character\n")
        repl.print("  ${Color.cyan}Alt+B/F${Color.reset}      Move backward/forward one word\n")
        repl.print("  ${Color.cyan}Ctrl+U${Color.reset}       Delete to start of line\n")
        repl.print("  ${Color.cyan}Ctrl+K${Color.reset}       Delete to end of line\n")
        repl.print("  ${Color.cyan}Ctrl+W${Color.reset}       Delete word backward\n")
        repl.print("  ${Color.cyan}Ctrl+D${Color.reset}       Delete character / Exit if line empty\n")
        repl.print("  ${Color.cyan}Ctrl+L${Color.reset}       Clear screen\n")
        repl.print("  ${Color.cyan}Ctrl+T${Color.reset}       Swap characters\n")
        repl.print("  ${Color.cyan}Up/Down${Color.reset}      Navigate history\n")
        repl.print("  ${Color.cyan}Tab${Color.reset}          Auto-complete\n")
        repl.print("\n${Color.bold}Special Variables:${Color.reset}\n")
        repl.print("  ${Color.cyan}_${Color.reset}            Last expression result\n")
        repl.print("  ${Color.cyan}_error${Color.reset}       Last error\n\n")
        return ReplResult.skipEval
    }

    public static func cmdExit(repl: Repl, args: String): ReplResult {
        return ReplResult.exitRepl
    }

    public static func cmdClear(repl: Repl, args: String): ReplResult {
        repl.write(CursorControl.clearScreen)
        repl.write(CursorControl.clearScrollback)
        repl.write(CursorControl.home)
        return ReplResult.skipEval
    }

    public static func cmdCopy(repl: Repl, args: String): ReplResult {
        let code = args.trim(" \t")
        if (code.length == 0) {
            // .copy 无参数 -> 复制上次结果
            repl.copyValueToClipboard(repl.lastResult)
            return ReplResult.skipEval
        }
        // .copy <code> -> 评估并复制结果
        repl.evaluateAndCopy(code)
        return ReplResult.skipEval
    }

    public static func cmdLoad(repl: Repl, args: String): ReplResult {
        let filename = args.trim(" \t")
        if (filename.length == 0) {
            repl.printError("Usage: .load <filename>\n")
            return ReplResult.skipEval
        }

        let content = BaoFile.readAllText(filename)
        if (content == None) {
            repl.printError("Failed to read ${filename}\n")
            return ReplResult.skipEval
        }

        repl.print("${Color.dim}Loading ${filename}...${Color.reset}\n")
        repl.evaluateAndPrint(content!!)
        return ReplResult.skipEval
    }

    public static func cmdSave(repl: Repl, args: String): ReplResult {
        let filename = args.trim(" \t")
        if (filename.length == 0) {
            repl.printError("Usage: .save <filename>\n")
            return ReplResult.skipEval
        }

        let content = StringBuilder()
        for (entry in repl.history.entries) {
            content.append(entry)
            content.append('\n')
        }

        BaoFile.writeAllText(filename, content.toString())
        repl.print("${Color.green}Session saved to ${filename}${Color.reset}\n")
        return ReplResult.skipEval
    }

    public static func cmdEditor(repl: Repl, args: String): ReplResult {
        repl.print("${Color.dim}// Entering editor mode (Ctrl+D to finish, Ctrl+C to cancel)${Color.reset}\n")
        repl.editorMode = true
        repl.editorBuffer.clear()
        return ReplResult.skipEval
    }

    public static func cmdBreak(repl: Repl, args: String): ReplResult {
        repl.lineEditor.clear()
        repl.multilineBuffer.clear()
        repl.inMultiline = false
        return ReplResult.skipEval
    }

    public static func cmdHistory(repl: Repl, args: String): ReplResult {
        repl.print("\n${Color.bold}Command History:${Color.reset}\n")
        let start = if (repl.history.entries.size > 20) {
            repl.history.entries.size - 20
        } else {
            0
        }
        for (i in start..repl.history.entries.size) {
            let num = (i + 1).toString().padStart(4)
            repl.print("  ${Color.dim}${num}${Color.reset}  ${repl.history.entries[i.toInt()]}\n")
        }
        repl.print("\n")
        return ReplResult.skipEval
    }
}

// ============================================================================
// Repl — 主 REPL 结构体
// ============================================================================

/// REPL 主结构体
/// 对应 Bun: Repl
public class Repl {
    public var allocator: Allocator
    public var lineEditor: LineEditor
    public var history: History
    public var multilineBuffer: ArrayList<UInt8> = ArrayList<UInt8>()
    public var editorBuffer: ArrayList<UInt8> = ArrayList<UInt8>()

    // 状态
    public var inMultiline: Bool = false
    public var editorMode: Bool = false
    public var running: Bool = false
    public var isTty: Bool = false
    public var useColors: Bool = false
    public var terminalWidth: UInt16 = 80
    public var terminalHeight: UInt16 = 24
    public var ctrlCPressed: Bool = false

    // 标准输入缓冲区
    public var stdinBuf: ArrayList<UInt8> = ArrayList<UInt8>()
    public var stdinBufStart: Int64 = 0
    public var stdinBufEnd: Int64 = 0

    // JavaScript VM
    public var vm: ?VirtualMachine = None
    public var global: ?JSGlobalObject = None

    // 特殊变量
    public var lastResult: JSValue = JSValue.jsUndefined()
    public var lastError: JSValue = JSValue.jsUndefined()

    public init(allocator: Allocator) {
        this.allocator = allocator
        this.lineEditor = LineEditor(allocator)
        this.history = History(allocator)
    }

    // ========================================================================
    // Terminal I/O
    // ========================================================================

    /// 设置终端
    /// 对应 Bun: Repl.setupTerminal
    public func setupTerminal(): Unit {
        isTty = Output.isStdoutTTY() && Output.isStdinTTY()

        if (!isTty) {
            useColors = false
            return
        }

        useColors = !EnvVar.NO_COLOR.get()

        if (Output.terminalSize.col > 0) {
            terminalWidth = Output.terminalSize.col
            terminalHeight = Output.terminalSize.row
        }

        // 启用 raw 模式
        Tty.setMode(0, TtyMode.raw)
    }

    /// 恢复终端
    /// 对应 Bun: Repl.restoreTerminal
    public func restoreTerminal(): Unit {
        Tty.setMode(0, TtyMode.normal)
    }

    /// 写入数据
    /// 对应 Bun: Repl.write
    public func write(data: String): Unit {
        Output.writer().writeAll(data)
    }

    /// 打印格式化
    /// 对应 Bun: Repl.print
    public func print(format: String): Unit {
        Output.writer().writeAll(format)
    }

    /// 打印错误
    /// 对应 Bun: Repl.printError
    public func printError(format: String): Unit {
        if (useColors) {
            Output.writer().writeAll(Color.red + format + Color.reset)
        } else {
            Output.writer().writeAll(format)
        }
    }

    /// 读取单个字节
    /// 对应 Bun: Repl.readByte
    public func readByte(): ?UInt8 {
        if (stdinBufStart < stdinBufEnd) {
            let b = stdinBuf[stdinBufStart.toInt()]
            stdinBufStart += 1
            return b
        }
        // 重新填充缓冲区
        let stdin = Stdio.stdin()
        let n = stdin.read(stdinBuf)
        if (n == 0) {
            return None
        }
        stdinBufStart = 1
        stdinBufEnd = n
        return stdinBuf[0]
    }

    /// 读取按键
    /// 对应 Bun: Repl.readKey
    public func readKey(): ?Key {
        let byte = readByte() ?: return None

        // 处理转义序列
        if (byte == 27) { // ESC
            let second = readByte() ?: return Key.escape

            if (second == '['.toUInt8()) { // CSI
                let third = readByte() ?: return Key.escape

                when (third) {
                    case 'A'.toUInt8() => return Key.arrowUp
                    case 'B'.toUInt8() => return Key.arrowDown
                    case 'C'.toUInt8() => return Key.arrowRight
                    case 'D'.toUInt8() => return Key.arrowLeft
                    case 'H'.toUInt8() => return Key.home
                    case 'F'.toUInt8() => return Key.end
                    case _ => {
                        // 处理数字后跟 ~
                        if (third >= '1'.toUInt8() && third <= '6'.toUInt8()) {
                            let fourth = readByte() ?: return Key.unknown
                            if (fourth == '~'.toUInt8()) {
                                when (third) {
                                    case '1'.toUInt8() => return Key.home
                                    case '3'.toUInt8() => return Key.delete
                                    case '4'.toUInt8() => return Key.end
                                    case '5'.toUInt8() => return Key.pageUp
                                    case '6'.toUInt8() => return Key.pageDown
                                    case _ => return Key.unknown
                                }
                            } else if (fourth == ';'.toUInt8()) {
                                let mod = readByte() ?: return Key.unknown
                                let dir = readByte() ?: return Key.unknown
                                if (mod == '5'.toUInt8() || mod == '3'.toUInt8()) {
                                    when (dir) {
                                        case 'C'.toUInt8() => return Key.altRight
                                        case 'D'.toUInt8() => return Key.altLeft
                                        case _ => return Key.unknown
                                    }
                                }
                                return Key.unknown
                            }
                        }
                        return Key.unknown
                    }
                }
            } else if (second == 'O'.toUInt8()) { // SS3
                let third = readByte() ?: return Key.escape
                when (third) {
                    case 'H'.toUInt8() => return Key.home
                    case 'F'.toUInt8() => return Key.end
                    case _ => return Key.unknown
                }
            } else if (second == 'b'.toUInt8()) {
                return Key.altB
            } else if (second == 'd'.toUInt8()) {
                return Key.altD
            } else if (second == 'f'.toUInt8()) {
                return Key.altF
            } else if (second == 127.toUInt8()) {
                return Key.altBackspace
            }

            return Key.escape
        }

        return Key.fromByte(byte)
    }

    // ========================================================================
    // 提示符和显示
    // ========================================================================

    /// 获取提示符
    /// 对应 Bun: Repl.getPrompt
    public func getPrompt(): String {
        if (inMultiline || editorMode) {
            return if (useColors) "${Color.dim}... ${Color.reset}" else "... "
        }
        return if (useColors) "${Color.dim}\u276f${Color.reset} " else "> "
    }

    /// 获取提示符长度
    /// 对应 Bun: Repl.getPromptLength
    public func getPromptLength(): Int64 {
        if (inMultiline || editorMode) {
            return 4
        }
        return 2
    }

    /// 刷新行显示
    /// 对应 Bun: Repl.refreshLine
    public func refreshLine(): Unit {
        Output.flush()

        let prompt = getPrompt()
        let promptLen = getPromptLength()
        let line = lineEditor.getLine()

        // 移动到行首
        write("\r")
        write(CursorControl.clearLine)

        // 写入提示符
        write(prompt)

        // 写入带语法高亮的行
        if (useColors && line.length > 0 && line.length <= 2048) {
            writeHighlighted(line)
        } else {
            write(line)
        }

        // 定位光标
        let cursorPos = promptLen + lineEditor.cursor
        if (cursorPos < terminalWidth) {
            write("\r")
            if (cursorPos > 0) {
                write("\u001b[${cursorPos}C")
            }
        }

        Output.flush()
    }

    /// 写入带语法高亮的文本
    /// 对应 Bun: Repl.writeHighlighted
    public func writeHighlighted(text: String): Unit {
        let highlighter = QuickAndDirtyJavaScriptSyntaxHighlighter(text, true)
        let highlighted = highlighter.format()
        Output.writer().writeAll(highlighted)
    }

    // ========================================================================
    // JavaScript 评估
    // ========================================================================

    /// 检查代码是否不完整
    /// 对应 Bun: isIncompleteCode
    public static func isIncompleteCode(code: String): Bool {
        var braceCount: Int64 = 0
        var bracketCount: Int64 = 0
        var parenCount: Int64 = 0
        var inString: UInt8 = 0
        var inTemplate = false
        var escaped = false

        for (char in code) {
            if (escaped) {
                escaped = false
                continue
            }

            if (char == '\\') {
                escaped = true
                continue
            }

            // 处理字符串
            if (inString == 0.toUInt8() && !inTemplate) {
                if (char == '"' || char == '\'') {
                    inString = char.toUInt8()
                    continue
                }
                if (char == '`') {
                    inTemplate = true
                    continue
                }
            } else if (inString != 0.toUInt8() && char.toUInt8() == inString) {
                inString = 0
                continue
            } else if (inTemplate && char == '`') {
                inTemplate = false
                continue
            }

            // 跳过字符串内容
            if (inString != 0.toUInt8() || inTemplate) {
                continue
            }

            // 计数括号
            when (char) {
                case '{' => braceCount += 1
                case '}' => braceCount -= 1
                case '[' => bracketCount += 1
                case ']' => bracketCount -= 1
                case '(' => parenCount += 1
                case ')' => parenCount -= 1
                case _ => ()
            }
        }

        return inString != 0.toUInt8() || inTemplate || braceCount > 0 || bracketCount > 0 || parenCount > 0
    }

    /// 评估并打印结果
    /// 对应 Bun: Repl.evaluateAndPrint
    public func evaluateAndPrint(code: String): Unit {
        let global = this.global ?: return
        let vm = this.vm ?: return

        // 转换代码
        let transformedCode = transformForRepl(code)
        if (transformedCode == None) {
            evaluateRaw(code)
            return
        }

        // 评估
        val (result, exception) = JscREPL.evaluate(global, transformedCode!!, "[repl]")

        // 检查异常
        if (!exception.isUndefined() && !exception.isNull()) {
            setLastError(exception)
            printJSError(exception)
            return
        }

        // 处理异步结果
        var resolvedResult = result
        let promise = result.asPromise()
        if (promise != None) {
            promise!!.setHandled()
            vm.waitForPromise(promise)

            if (vm.executionForbidden()) {
                vm.setExecutionForbidden(false)
                global.clearTerminationException()
                print("\n")
                return
            }

            when (promise!!.status()) {
                case PromiseStatus.fulfilled => {
                    resolvedResult = promise!!.result()
                }
                case PromiseStatus.rejected => {
                    let rejection = promise!!.result()
                    setLastError(rejection)
                    printJSError(rejection)
                    return
                }
                case PromiseStatus.pending => {
                    print("\n")
                    return
                }
            }
        }

        // 提取结果值
        var actualResult = resolvedResult
        if (resolvedResult.isObject()) {
            let maybeValue = resolvedResult.getOwn(global, "value")
            if (maybeValue != None) {
                actualResult = maybeValue!!
            }
        }

        // 存储并打印结果
        setLastResult(actualResult)

        if (!actualResult.isUndefined()) {
            global.putProperty("_", actualResult)
        }

        if (actualResult.isUndefined()) {
            if (useColors) {
                print("${Color.dim}undefined${Color.reset}\n")
            } else {
                print("undefined\n")
            }
        } else {
            printFormattedValue(actualResult)
        }

        vm.tick()
    }

    /// 评估脚本 (非交互式, 用于 -e/--eval)
    /// 对应 Bun: Repl.evalScript
    public func evalScript(code: String, printResult: Bool): Bool {
        let global = this.global ?: return true
        let vm = this.vm ?: return true

        let noColor = EnvVar.NO_COLOR.get()
        useColors = Output.enableAnsiColorsStdout && !noColor

        // 空脚本
        if (code.trim(" \t\n\r").length == 0) {
            if (printResult) {
                if (useColors) {
                    print("${Color.dim}undefined${Color.reset}\n")
                } else {
                    print("undefined\n")
                }
            }
            return false
        }

        let transformedCode = transformForRepl(code)
        if (transformedCode == None) {
            val (result, exception) = JscREPL.evaluate(global, code, "[eval]")
            if (!exception.isUndefined() && !exception.isNull()) {
                printJSError(exception)
            }
            return true
        }

        val (result, exception) = JscREPL.evaluate(global, transformedCode!!, "[eval]")

        if (!exception.isUndefined() && !exception.isNull()) {
            printJSError(exception)
            return true
        }

        // 处理异步
        var resolvedResult = result
        let promise = result.asPromise()
        if (promise != None) {
            promise!!.setHandled()
            vm.waitForPromise(promise)
            when (promise!!.status()) {
                case PromiseStatus.fulfilled => resolvedResult = promise!!.result()
                case PromiseStatus.rejected => {
                    printJSError(promise!!.result())
                    return true
                }
                case PromiseStatus.pending => return true
            }
        }

        var actualResult = resolvedResult
        if (resolvedResult.isObject()) {
            let maybeValue = resolvedResult.getOwn(global, "value")
            if (maybeValue != None) {
                actualResult = maybeValue!!
            }
        }

        // 排空事件循环
        vm.tick()
        while (vm.isEventLoopAlive()) {
            vm.tick()
        }

        if (printResult) {
            if (actualResult.isUndefined()) {
                if (useColors) {
                    print("${Color.dim}undefined${Color.reset}\n")
                } else {
                    print("undefined\n")
                }
            } else {
                printFormattedValue(actualResult)
            }
        }

        return false
    }

    /// 原始评估 (无 REPL 转换)
    /// 对应 Bun: Repl.evaluateRaw
    public func evaluateRaw(code: String): Unit {
        let global = this.global ?: return

        val (result, exception) = JscREPL.evaluate(global, code, "[repl]")

        if (!exception.isUndefined() && !exception.isNull()) {
            setLastError(exception)
            printJSError(exception)
            return
        }

        setLastResult(result)

        if (!result.isUndefined()) {
            printFormattedValue(result)
        } else {
            if (useColors) {
                print("${Color.dim}undefined${Color.reset}\n")
            } else {
                print("undefined\n")
            }
        }

        if (vm != None) {
            vm!!.tick()
        }
    }

    /// 评估并复制到剪贴板
    /// 对应 Bun: Repl.evaluateAndCopy
    public func evaluateAndCopy(code: String): Unit {
        let global = this.global ?: return
        let vm = this.vm ?: return

        let transformedCode = transformForRepl(code)
        if (transformedCode == None) {
            evaluateRaw(code)
            return
        }

        val (result, exception) = JscREPL.evaluate(global, transformedCode!!, "[repl]")

        if (!exception.isUndefined() && !exception.isNull()) {
            setLastError(exception)
            printJSError(exception)
            return
        }

        var resolvedResult = result
        let promise = result.asPromise()
        if (promise != None) {
            promise!!.setHandled()
            vm.waitForPromise(promise)
            when (promise!!.status()) {
                case PromiseStatus.fulfilled => resolvedResult = promise!!.result()
                case PromiseStatus.rejected => {
                    setLastError(promise!!.result())
                    printJSError(promise!!.result())
                    return
                }
                case PromiseStatus.pending => return
            }
        }

        var actualResult = resolvedResult
        if (resolvedResult.isObject()) {
            let maybeValue = resolvedResult.getOwn(global, "value")
            if (maybeValue != None) {
                actualResult = maybeValue!!
            }
        }

        setLastResult(actualResult)
        if (!actualResult.isUndefined()) {
            global.putProperty("_", actualResult)
        }

        copyValueToClipboard(actualResult)
        vm.tick()
    }

    /// 为 REPL 转换代码
    /// 对应 Bun: Repl.transformForRepl
    public func transformForRepl(code: String): ?String {
        let vm = this.vm ?: return None

        if (code.length == 0 || code.trim(" \t\n\r").length == 0) {
            return None
        }

        // 检查是否可能为对象字面量
        let isObjectLiteral = isLikelyObjectLiteral(code)
        let processedCode = if (isObjectLiteral) "(${code})" else code

        // 解析并转换
        // 对应 Bun: 使用 js_parser 并启用 repl_mode
        let transformed = JsParser.transformForReplMode(processedCode, vm.transpiler)
        return transformed
    }

    /// 检查是否可能为对象字面量
    /// 对应 Bun: Repl.isLikelyObjectLiteral
    public static func isLikelyObjectLiteral(code: String): Bool {
        var start: Int64 = 0
        while (start < code.length && (code[start.toInt()] == ' ' || code[start.toInt()] == '\t' || code[start.toInt()] == '\n' || code[start.toInt()] == '\r')) {
            start += 1
        }

        if (start >= code.length || code[start.toInt()] != '{') {
            return false
        }

        var end: Int64 = code.length
        while (end > 0 && (code[(end - 1).toInt()] == ' ' || code[(end - 1).toInt()] == '\t' || code[(end - 1).toInt()] == '\n' || code[(end - 1).toInt()] == '\r')) {
            end -= 1
        }

        if (end > 0 && code[(end - 1).toInt()] == ';') {
            return false
        }

        return true
    }

    /// 设置上次结果
    /// 对应 Bun: Repl.setLastResult
    public func setLastResult(value: JSValue): Unit {
        lastResult = value
    }

    /// 设置上次错误
    /// 对应 Bun: Repl.setLastError
    public func setLastError(value: JSValue): Unit {
        lastError = value
    }

    /// 打印 JS 错误
    /// 对应 Bun: Repl.printJSError
    public func printJSError(errorValue: JSValue): Unit {
        if (errorValue == None || errorValue.isUndefined()) {
            return
        }
        let formatted = ConsoleObject.formatError(errorValue, useColors)
        Output.writer().writeAll(formatted)
    }

    /// 格式化打印 JS 值
    /// 对应 Bun: Repl.printFormattedValue
    public func printFormattedValue(value: JSValue): Unit {
        let formatted = ConsoleObject.formatLog(value, useColors)
        Output.writer().writeAll(formatted)
    }

    /// 复制值到剪贴板
    /// 对应 Bun: Repl.copyValueToClipboard
    public func copyValueToClipboard(value: JSValue): Unit {
        let text = valueToClipboardString(value)
        if (text == None) {
            printError("Failed to format value for clipboard\n")
            return
        }

        copyToClipboardOSC52(text!!)
        if (useColors) {
            print("${Color.dim}Copied ${text!!.length} characters to clipboard${Color.reset}\n")
        } else {
            print("Copied ${text!!.length} characters to clipboard\n")
        }
    }

    /// 将值转换为剪贴板字符串
    /// 对应 Bun: Repl.valueToClipboardString
    public func valueToClipboardString(value: JSValue): ?String {
        if (value.isUndefined()) {
            return "undefined"
        }
        if (value.isNull()) {
            return "null"
        }
        if (value.isString()) {
            return value.asString()
        }
        // 其他类型使用 console 格式化
        return ConsoleObject.formatLog(value, false)
    }

    /// 通过 OSC52 复制到剪贴板
    /// 对应 Bun: Repl.copyToClipboardOSC52
    public func copyToClipboardOSC52(text: String): Unit {
        let encoded = Base64.encode(text)
        write("\u001b]52;c;${encoded}\u0007")
    }

    // ========================================================================
    // 主循环
    // ========================================================================

    /// 运行 REPL
    /// 对应 Bun: Repl.run
    public func run(): Unit {
        runWithVM(None)
    }

    /// 带 VM 运行 REPL
    /// 对应 Bun: Repl.runWithVM
    public func runWithVM(vm: ?VirtualMachine): Unit {
        this.vm = vm
        if (vm != None) {
            global = vm!!.global
        }

        setupTerminal()

        history.load()

        // 打印欢迎消息
        print("Welcome to Bao v${Global.packageJsonVersion}\n")
        print("Type ${Color.cyan}.copy [code]${Color.reset} to copy to clipboard. ${Color.cyan}.help${Color.reset} for more info.\n\n")

        running = true
        refreshLine()

        while (running) {
            let key = readKey()
            if (key == None) {
                // EOF
                print("\n")
                break
            }

            let k = key!!

            // 在任何其他按键时重置双 Ctrl+C 状态
            if (k != Key.ctrlC) {
                ctrlCPressed = false
            }

            when (k) {
                case Key.enter => handleEnter()
                case Key.ctrlC => handleCtrlC()
                case Key.ctrlD => {
                    if (editorMode) {
                        print("\n")
                        let code = editorBufferToString()
                        if (code.length > 0) {
                            evaluateAndPrint(code)
                        }
                        editorMode = false
                        editorBuffer.clear()
                        refreshLine()
                    } else if (lineEditor.buffer.size == 0 && !inMultiline) {
                        print("\n")
                        running = false
                    } else {
                        lineEditor.deleteChar()
                        refreshLine()
                    }
                }
                case Key.ctrlL => {
                    write(CursorControl.clearScreen)
                    write(CursorControl.home)
                    refreshLine()
                }
                case Key.ctrlA => {
                    lineEditor.moveToStart()
                    refreshLine()
                }
                case Key.ctrlE => {
                    lineEditor.moveToEnd()
                    refreshLine()
                }
                case Key.ctrlB, Key.arrowLeft => {
                    lineEditor.moveLeft()
                    refreshLine()
                }
                case Key.ctrlF, Key.arrowRight => {
                    lineEditor.moveRight()
                    refreshLine()
                }
                case Key.altB, Key.altLeft => {
                    lineEditor.moveWordLeft()
                    refreshLine()
                }
                case Key.altF, Key.altRight => {
                    lineEditor.moveWordRight()
                    refreshLine()
                }
                case Key.ctrlU => {
                    lineEditor.deleteToStart()
                    refreshLine()
                }
                case Key.ctrlK => {
                    lineEditor.deleteToEnd()
                    refreshLine()
                }
                case Key.ctrlW, Key.altBackspace => {
                    lineEditor.backspaceWord()
                    refreshLine()
                }
                case Key.altD => {
                    lineEditor.deleteWord()
                    refreshLine()
                }
                case Key.ctrlT => {
                    lineEditor.swap()
                    refreshLine()
                }
                case Key.backspace => {
                    lineEditor.backspace()
                    refreshLine()
                }
                case Key.delete => {
                    lineEditor.deleteChar()
                    refreshLine()
                }
                case Key.arrowUp, Key.ctrlP => {
                    let prevLine = history.prev(lineEditor.getLine())
                    if (prevLine != None) {
                        lineEditor.set(prevLine!!)
                        refreshLine()
                    }
                }
                case Key.arrowDown, Key.ctrlN => {
                    let nextLine = history.next()
                    if (nextLine != None) {
                        lineEditor.set(nextLine!!)
                    } else {
                        lineEditor.clear()
                    }
                    refreshLine()
                }
                case Key.tab => handleTab()
                case Key.home => {
                    lineEditor.moveToStart()
                    refreshLine()
                }
                case Key.end => {
                    lineEditor.moveToEnd()
                    refreshLine()
                }
                case Key.char_(c) => {
                    lineEditor.insert(c)
                    refreshLine()
                }
                case _ => ()
            }
        }

        history.save()
    }

    /// 获取编辑器缓冲区字符串
    private func editorBufferToString(): String {
        let sb = StringBuilder()
        for (b in editorBuffer) {
            sb.append(b.toChar())
        }
        return sb.toString()
    }

    /// 处理回车
    /// 对应 Bun: Repl.handleEnter
    public func handleEnter(): Unit {
        print("\n")

        let line = lineEditor.getLine()

        if (editorMode) {
            let trimmed = line.trim(" \t")
            if (trimmed.length == 0) {
                editorBuffer.append('\n'.toUInt8())
            } else {
                for (c in line) {
                    editorBuffer.append(c.toUInt8())
                }
                editorBuffer.append('\n'.toUInt8())
            }
            lineEditor.clear()
            refreshLine()
            return
        }

        // 检查 REPL 命令
        if (line.length > 0 && line[0] == '.') {
            let spaceIdx = line.indexOf(' ')
            let cmdName = if (spaceIdx >= 0) line.substring(0, spaceIdx) else line
            let args = if (spaceIdx >= 0) line.substring(spaceIdx + 1) else ""

            let cmd = ReplCommandDef.find(cmdName)
            if (cmd != None) {
                let result = cmd!!.handler(this, args)
                when (result) {
                    case ReplResult.exitRepl => {
                        running = false
                        return
                    }
                    case ReplResult.skipEval => {
                        lineEditor.clear()
                        history.resetPosition()
                        refreshLine()
                        return
                    }
                    case ReplResult.continueRepl => ()
                }
            } else {
                printError("Unknown command: ${cmdName}\n")
                print("Type ${Color.cyan}.help${Color.reset} for available commands\n")
                lineEditor.clear()
                refreshLine()
                return
            }
        }

        // 空行
        if (line.length == 0 && !inMultiline) {
            refreshLine()
            return
        }

        // 多行输入
        var fullCode = line
        if (inMultiline) {
            let sb = StringBuilder()
            for (b in multilineBuffer) {
                sb.append(b.toChar())
            }
            sb.append(line)
            sb.append('\n')
            fullCode = sb.toString()
        }

        if (Repl.isIncompleteCode(fullCode)) {
            if (!inMultiline) {
                inMultiline = true
                for (c in line) {
                    multilineBuffer.append(c.toUInt8())
                }
                multilineBuffer.append('\n'.toUInt8())
            }
            lineEditor.clear()
            refreshLine()
            return
        }

        // 完整代码 - 评估
        var codeToEval = line
        if (inMultiline) {
            let sb = StringBuilder()
            for (b in multilineBuffer) {
                sb.append(b.toChar())
            }
            codeToEval = sb.toString()
        }

        history.add(codeToEval.trim("\n"))

        evaluateAndPrint(codeToEval)

        // 重置状态
        lineEditor.clear()
        multilineBuffer.clear()
        inMultiline = false
        history.resetPosition()
        refreshLine()
    }

    /// 处理 Ctrl+C
    /// 对应 Bun: Repl.handleCtrlC
    public func handleCtrlC(): Unit {
        if (editorMode) {
            print("\n${Color.dim}// Editor mode cancelled${Color.reset}\n")
            editorMode = false
            editorBuffer.clear()
        } else if (inMultiline) {
            print("\n")
            inMultiline = false
            multilineBuffer.clear()
        } else if (lineEditor.buffer.size > 0) {
            print("^C\n")
            lineEditor.clear()
        } else if (ctrlCPressed) {
            // 第二次 Ctrl+C 退出
            print("\n")
            running = false
            return
        } else {
            ctrlCPressed = true
            print("\n${Color.dim}(press Ctrl+C again to exit, or Ctrl+D)${Color.reset}\n")
        }
        history.resetPosition()
        refreshLine()
    }

    /// 处理 Tab 补全
    /// 对应 Bun: Repl.handleTab
    public func handleTab(): Unit {
        let line = lineEditor.getLine()

        // 补全 REPL 命令
        if (line.length > 0 && line[0] == '.') {
            let matches = ArrayList<String>()
            for (cmd in ReplCommandDef.all()) {
                if (cmd.name.startsWith(line)) {
                    matches.append(cmd.name)
                }
            }

            if (matches.size == 1) {
                lineEditor.set(matches[0])
                lineEditor.insert(' '.toUInt8())
                refreshLine()
            } else if (matches.size > 1) {
                print("\n")
                for (match in matches) {
                    print("  ${Color.cyan}${match}${Color.reset}\n")
                }
                refreshLine()
            }
            return
        }

        // 属性补全
        if (global == None) {
            lineEditor.insert(' '.toUInt8())
            lineEditor.insert(' '.toUInt8())
            refreshLine()
            return
        }

        // 查找正在补全的单词
        var wordStart: Int64 = line.length
        while (wordStart > 0) {
            let c = line[(wordStart - 1).toInt()]
            if (!c.isAlphanumeric() && c != '_' && c != '$') {
                break
            }
            wordStart -= 1
        }

        let prefix = line.substring(wordStart)

        // 从全局对象获取补全
        let completions = JscREPL.getCompletions(global!!, JSValue.jsUndefined(), prefix)

        if (completions == None || !completions!!.isArray()) {
            lineEditor.insert(' '.toUInt8())
            lineEditor.insert(' '.toUInt8())
            refreshLine()
            return
        }

        let len = completions!!.getLength()
        if (len == 0) {
            lineEditor.insert(' '.toUInt8())
            lineEditor.insert(' '.toUInt8())
            refreshLine()
            return
        }

        if (len == 1) {
            // 单个补全
            let item = completions!!.getIndex(0)
            if (item.isString()) {
                let completion = item.asString()
                while (lineEditor.cursor > wordStart) {
                    lineEditor.backspace()
                }
                lineEditor.insertSlice(completion)
                refreshLine()
            }
        } else if (len <= 50) {
            // 多个补全 - 显示它们
            print("\n")
            for (i in 0..len) {
                let item = completions!!.getIndex(i)
                if (item.isString()) {
                    print("  ${Color.cyan}${item.asString()}${Color.reset}\n")
                }
            }
            refreshLine()
        } else {
            print("\n${Color.dim}${len} completions${Color.reset}\n")
            refreshLine()
        }
    }

    // ========================================================================
    // 公共入口点
    // ========================================================================

    /// CLI 入口
    /// 对应 Bun: Repl.exec
    public static func exec(ctx: CommandContext): Unit {
        let repl = Repl(ctx.allocator)
        repl.run()
    }
}
