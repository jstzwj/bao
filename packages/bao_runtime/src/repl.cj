// REPL — 交互式读取-求值-打印循环
// 严格翻译自: src/cli/repl.rs
//   Bun 的 REPL 基于 JSC 的 InteractiveLoop 实现
//   仓颉使用 VirtualMachine + Interpreter 实现等价的 REPL
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*
import bao_threading.*

// ============================================================================
// REPL — 交互式读取-求值-打印循环
// 对应 Bun: src/cli/repl.rs
//   Bun 使用 JSC 的 JSEvaluateScript + JSObjectMakeFunction 执行 REPL 输入
//   仓颉通过 VirtualMachine.eval 实现等价逻辑
// ============================================================================

/// REPL 历史记录管理
/// 对应 Bun: src/cli/repl.rs History
public class REPLHistory {
    /// 历史条目列表
    private var entries: ArrayList<String>
    /// 最大条目数
    public var maxEntries: Int64
    /// 当前浏览索引 (用于上下键浏览)
    public var currentIndex: Int64

    public init() {
        entries = ArrayList<String>()
        maxEntries = 1000
        currentIndex = -1
    }

    public init(maxEntries: Int64) {
        entries = ArrayList<String>()
        this.maxEntries = maxEntries
        currentIndex = -1
    }

    /// 添加条目 - 对应 Bun repl 添加历史
    public func add(entry: String): Unit {
        let trimmed = entry.trim()
        if (trimmed.isEmpty()) {
            return
        }
        // 不添加与最后一条相同的条目
        if (entries.size > 0) {
            match (entries.get(entries.size - 1)) {
                case Some(last) =>
                    if (last == trimmed) {
                        return
                    }
                case None => ()
            }
        }
        entries.append(trimmed)
        // 超过上限则移除最旧的
        if (entries.size > maxEntries) {
            entries.removeAt(0)
        }
        currentIndex = Int64(entries.size)
    }

    /// 获取上一条历史 (上键) - 对应 Bun repl 向上浏览
    public func previous(): ?String {
        if (entries.size == 0) {
            return None
        }
        if (currentIndex > 0) {
            currentIndex -= 1
        }
        if (currentIndex >= 0 && currentIndex < Int64(entries.size)) {
            return entries[Int64(currentIndex)]
        }
        return None
    }

    /// 获取下一条历史 (下键) - 对应 Bun repl 向下浏览
    public func next(): ?String {
        if (entries.size == 0) {
            return None
        }
        currentIndex += 1
        if (currentIndex >= Int64(entries.size)) {
            currentIndex = Int64(entries.size)
            return None
        }
        return entries[Int64(currentIndex)]
    }

    /// 重置浏览索引
    public func resetIndex(): Unit {
        currentIndex = Int64(entries.size)
    }

    /// 清空历史
    public func clear(): Unit {
        entries.clear()
        currentIndex = -1
    }

    /// 获取历史条目数
    public func size(): Int64 {
        return entries.size
    }

    /// 从文件加载历史 - 对应 Bun ~/.bun_repl_history
    public func loadFromFile(path: String): Unit {
        try {
            let content = BaoFile.readAllText(path)
            let lines = content.split("\n")
            for (line in lines) {
                let trimmed = line.trim()
                if (!trimmed.isEmpty()) {
                    entries.append(trimmed)
                }
            }
            currentIndex = Int64(entries.size)
        } catch (_: Exception) {
            // 文件不存在或读取失败，忽略
        }
    }

    /// 保存历史到文件
    public func saveToFile(path: String): Unit {
        try {
            let sb = StringBuilder()
            let start = if (entries.size > maxEntries) {
                Int64(entries.size - maxEntries)
            } else {
                0
            }
            for (i in start..Int64(entries.size)) {
                sb.append(entries[Int64(i)])
                sb.append("\n")
            }
            BaoFile.writeAllText(path, sb.toString())
        } catch (_: Exception) {
            // 写入失败，忽略
        }
    }
}

/// 多行输入状态
/// 对应 Bun: src/cli/repl.rs 中检测不完整表达式
public enum REPLInputState {
    | Complete      // 表达式完整，可以求值
    | Incomplete    // 表达式不完整，需要更多输入
    | Error         // 语法错误
}

/// Tab 补全候选
/// 对应 Bun: src/cli/repl.rs 中 tab completion
public class CompletionResult {
    /// 候选项列表
    public var candidates: ArrayList<String>
    /// 共同前缀
    public var commonPrefix: String

    public init() {
        candidates = ArrayList<String>()
        commonPrefix = ""
    }

    public init(candidates: ArrayList<String>, commonPrefix: String) {
        this.candidates = candidates
        this.commonPrefix = commonPrefix
    }
}

// ============================================================================
// REPL — 主 REPL 类
// 对应 Bun: src/cli/repl.rs InteractiveLoop
// ============================================================================

/// REPL — 交互式读取-求值-打印循环
/// 对应 Bun: src/cli/repl.rs
///   Bun 使用 JSC 的 JSEvaluateScript 在全局作用域执行输入
///   仓颉使用 VirtualMachine + Interpreter 实现等价逻辑
public class REPL {
    /// 关联的虚拟机
    private var vm: VirtualMachine
    /// 历史记录
    public var history: REPLHistory
    /// 多行输入缓冲区
    private var inputBuffer: ArrayList<String>
    /// REPL 提示符
    public var prompt: String
    /// 续行提示符
    public var continuationPrompt: String
    /// 是否正在运行
    private var running: Bool
    /// 上一次求值结果 - 对应 Node.js repl 的 _
    public var lastResult: JsValue
    /// 全局变量补全缓存
    private var globalNames: ArrayList<String>
    /// 输出函数
    public var outputFn: (String) -> Unit

    public init(vm: VirtualMachine) {
        this.vm = vm
        history = REPLHistory()
        inputBuffer = ArrayList<String>()
        prompt = "> "
        continuationPrompt = "  "
        running = false
        lastResult = JsValue.UNDEFINED
        globalNames = ArrayList<String>()
        outputFn = { s => println(s) }
        refreshGlobalNames()
    }

    public init(vm: VirtualMachine, prompt: String) {
        this.vm = vm
        history = REPLHistory()
        inputBuffer = ArrayList<String>()
        this.prompt = prompt
        continuationPrompt = "  "
        running = false
        lastResult = JsValue.UNDEFINED
        globalNames = ArrayList<String>()
        outputFn = { s => println(s) }
        refreshGlobalNames()
    }

    // ========================================================================
    // 核心循环
    // ========================================================================

    /// 启动 REPL 循环 - 对应 Bun: repl.start()
    public func start(): Unit {
        running = true
        printWelcome()

        while (running) {
            // 读取一行输入
            let currentPrompt = if (inputBuffer.size > 0) {
                continuationPrompt
            } else {
                prompt
            }

            let line = readline(currentPrompt)
            if (line == None) {
                // EOF (Ctrl+D)
                outputFn("")
                break
            }

            let input = line.unwrap()

            // 空行处理
            if (input.trim().isEmpty()) {
                if (inputBuffer.size == 0) {
                    continue
                }
                // 多行模式下空行表示结束
            }

            // 添加到缓冲区
            inputBuffer.append(input)

            // 检查输入是否完整
            let fullInput = joinBuffer()
            let state = checkInputState(fullInput)

            match (state) {
                case REPLInputState.Complete => {
                    // 完整表达式，求值
                    history.add(fullInput)
                    inputBuffer.clear()
                    evalAndPrint(fullInput)
                }
                case REPLInputState.Incomplete => {
                    // 不完整，继续读取
                    // 不做任何事，循环继续
                }
                case REPLInputState.Error => {
                    // 语法错误，尝试求值以显示错误信息
                    history.add(fullInput)
                    inputBuffer.clear()
                    evalAndPrint(fullInput)
                }
            }
        }
    }

    /// 停止 REPL
    public func stop(): Unit {
        running = false
    }

    // ========================================================================
    // 读取-求值-打印
    // ========================================================================

    /// 读取一行输入 - 对应 Bun: repl readline
    /// 仓颉从 stdin 读取
    public func readline(prompt: String): ?String {
        // 输出提示符
        outputFn(prompt)
        // 从标准输入读取
        try {
            let line = BaoStdin.readLine()
            if (line == None) {
                return None
            }
            return line
        } catch (_: Exception) {
            return None
        }
    }

    /// 求值一行输入 - 对应 Bun: repl evalLine
    /// Bun 使用 JSEvaluateScript 在全局作用域执行
    public func evalLine(line: String): JsValue {
        // 处理 REPL 特殊命令
        let trimmed = line.trim()
        if (trimmed.startsWith(".")) {
            return handleDotCommand(trimmed)
        }

        // 使用虚拟机求值
        try {
            let result = vm.eval(line, "<repl>")
            lastResult = result
            return result
        } catch (e: Exception) {
            lastResult = JsValue.UNDEFINED
            return JsValue(BaoString("Error: ${e.message}"))
        }
    }

    /// 求值并打印 - 对应 Bun repl 中的 eval + display
    private func evalAndPrint(input: String): Unit {
        let result = evalLine(input)
        printResult(result)
    }

    /// 格式化并打印 JsValue - 对应 Bun repl display callback
    /// Bun 使用 JSC 的 JSValueToStringCompact/formatValue
    public func printResult(value: JsValue): Unit {
        match (value.valueType) {
            case JsValueType.Undefined => {
                // undefined 在 REPL 中不显示
                return
            }
            case _ => {
                let formatted = formatValue(value)
                outputFn(formatted)
            }
        }
    }

    /// 格式化 JsValue 为可读字符串
    /// 对应 Bun: formatValue / inspect
    public func formatValue(value: JsValue): String {
        match (value.valueType) {
            case JsValueType.Undefined => "undefined"
            case JsValueType.Null => "null"
            case JsValueType.Boolean => if (value.boolValue) { "true" } else { "false" }
            case JsValueType.Number => {
                let n = value.numberValue
                if (n == Float64(Int64(n)) && !n.isNaN()) {
                    // 整数显示为整数
                    return "${Int64(n)}"
                }
                return n.toString()
            }
            case JsValueType.String => "'${value.stringValue.toString()}'"
            case JsValueType.Object => formatObject(value)
            case JsValueType.Array => formatArray(value)
            case JsValueType.Function => {
                match (value.functionData) {
                    case Some(fn) => "[Function: ${fn.name}]"
                    case None => "[Function: anonymous]"
                }
            }
            case JsValueType.Symbol => "Symbol()"
            case JsValueType.BigInt => "${value.stringValue.toString()}n"
            case JsValueType.Date => "Date"
            case JsValueType.RegExp => value.stringValue.toString()
            case JsValueType.Promise => "Promise { <pending> }"
            case _ => value.toString()
        }
    }

    /// 格式化对象 - 对应 Bun inspect 对象
    private func formatObject(value: JsValue): String {
        match (value.objectData) {
            case Some(obj) => {
                let keys = obj.keys()
                if (keys.size == 0) {
                    return "{}"
                }
                let sb = StringBuilder()
                sb.append("{ ")
                var first = true
                for (key in keys) {
                    if (!first) {
                        sb.append(", ")
                    }
                    first = false
                    let val = obj.get(key)
                    sb.append(key)
                    sb.append(": ")
                    sb.append(formatValue(val))
                }
                sb.append(" }")
                return sb.toString()
            }
            case None => "{}"
        }
    }

    /// 格式化数组 - 对应 Bun inspect 数组
    private func formatArray(value: JsValue): String {
        match (value.arrayData) {
            case Some(arr) => {
                if (arr.size == 0) {
                    return "[]"
                }
                let sb = StringBuilder()
                sb.append("[ ")
                for (i in 0..arr.size) {
                    if (i > 0) {
                        sb.append(", ")
                    }
                    sb.append(formatValue(arr[Int64(i)]))
                }
                sb.append(" ]")
                return sb.toString()
            }
            case None => "[]"
        }
    }

    // ========================================================================
    // 多行输入检测
    // ========================================================================

    /// 检查输入状态 - 对应 Bun repl 检测不完整表达式
    /// Bun 通过 JSC 的 JSCheckScriptSyntax 检测
    public func checkInputState(input: String): REPLInputState {
        let trimmed = input.trim()
        if (trimmed.isEmpty()) {
            return REPLInputState.Complete
        }

        // 尝试解析
        let parser = JsParser()
        let options = ParserOptions()
        options.sourceFile = "<repl>"
        let result = parser.parse(input, options)

        if (!result.hasErrors()) {
            // 解析成功，检查是否有多行需求
            // 检查是否有未闭合的块
            if (hasUnclosedBlock(input)) {
                return REPLInputState.Incomplete
            }
            return REPLInputState.Complete
        }

        // 解析失败，判断是语法错误还是不完整
        if (isIncompleteError(input, result)) {
            return REPLInputState.Incomplete
        }

        return REPLInputState.Error
    }

    /// 检查是否有未闭合的块结构
    /// 对应 Bun repl 中检测 {, (, [, `, /* 等未闭合符号
    private func hasUnclosedBlock(input: String): Bool {
        var parenDepth = 0    // ()
        var bracketDepth = 0  // []
        var braceDepth = 0    // {}
        var inTemplate = false   // ``
        var inBlockComment = false  // /* */
        var inString: ?UInt8 = None  // '', "", backtick

        for (i in 0..input.size) {
            let c = input[i]

            if (inBlockComment) {
                if (c == '*' && i + 1 < input.size && input[i + 1] == '/') {
                    inBlockComment = false
                }
                continue
            }

            match (inString) {
                case Some(quote) =>
                    if (c == '\\' && i + 1 < input.size) {
                        continue  // 跳过转义字符
                    }
                    if (c == quote) {
                        inString = None
                    }
                    continue
                case None => ()
            }

            match (c) {
                case '/' =>
                    if (i + 1 < input.size) {
                        if (input[i + 1] == '*') {
                            inBlockComment = true
                        }
                    }
                case '\'' => inString = Some('\'')
                case '"' => inString = Some('"')
                case '`' => inString = Some('`')
                case '(' => parenDepth += 1
                case ')' => parenDepth -= 1
                case '[' => bracketDepth += 1
                case ']' => bracketDepth -= 1
                case '{' => braceDepth += 1
                case '}' => braceDepth -= 1
                case _ => ()
            }
        }

        return parenDepth > 0 || bracketDepth > 0 || braceDepth > 0 ||
               inBlockComment || inString != None
    }

    /// 判断解析错误是否因为输入不完整
    /// 对应 Bun: 检测 "Unexpected end of input" 类错误
    private func isIncompleteError(input: String, result: ParseResult): Bool {
        for (err in result.errors) {
            let msg = err.message.toLower()
            // 常见的不完整输入错误信息
            if (msg.contains("unexpected end") ||
                msg.contains("unexpected token") && input.trimEnd().endsWith(".") ||
                msg.contains("expected") && (msg.contains("}") || msg.contains(")") || msg.contains("]"))) {
                return true
            }
        }

        // 以这些结尾时通常表示不完整
        let trimmed = input.trimEnd()
        if (trimmed.endsWith("{") || trimmed.endsWith("(") || trimmed.endsWith("[") ||
            trimmed.endsWith(",") || trimmed.endsWith(".") || trimmed.endsWith("=>") ||
            trimmed.endsWith("else") || trimmed.endsWith("try") || trimmed.endsWith("catch") ||
            trimmed.endsWith("finally") || trimmed.endsWith("return") || trimmed.endsWith("throw")) {
            return true
        }

        return false
    }

    // ========================================================================
    // Tab 补全
    // ========================================================================

    /// Tab 补全 - 对应 Bun: repl completion callback
    /// Bun 使用 JSC 的 JSObjectCopyPropertyNames 获取属性列表
    public func complete(line: String): CompletionResult {
        let result = CompletionResult()

        let trimmed = line.trim()
        if (trimmed.isEmpty()) {
            return result
        }

        // 分割为对象路径
        let parts = trimmed.split(".")
        let prefix = parts[parts.size - 1]

        if (parts.size == 1) {
            // 补全全局变量名
            completeGlobals(prefix, result)
        } else {
            // 补全对象属性
            let objPath = ArrayList<String>()
            for (i in 0..parts.size - 1) {
                objPath.append(parts[i])
            }
            completeProperty(objPath, prefix, result)
        }

        // 计算共同前缀
        if (result.candidates.size == 1) {
            result.commonPrefix = result.candidates[0]
        } else if (result.candidates.size > 1) {
            result.commonPrefix = commonPrefixOf(result.candidates)
        }

        return result
    }

    /// 补全全局变量名
    private func completeGlobals(prefix: String, result: CompletionResult): Unit {
        for (name in globalNames) {
            if (name.startsWith(prefix)) {
                result.candidates.append(name)
            }
        }

        // JavaScript 关键字
        let keywords = [
            "break", "case", "catch", "class", "const", "continue", "debugger",
            "default", "delete", "do", "else", "export", "extends", "false",
            "finally", "for", "function", "if", "import", "in", "instanceof",
            "let", "new", "null", "return", "static", "super", "switch", "this",
            "throw", "true", "try", "typeof", "undefined", "var", "void", "while",
            "with", "yield", "async", "await", "of"
        ]
        for (kw in keywords) {
            if (kw.startsWith(prefix)) {
                result.candidates.append(kw)
            }
        }
    }

    /// 补全对象属性
    private func completeProperty(objPath: ArrayList<String>, prefix: String,
                                   result: CompletionResult): Unit {
        // 在全局环境中查找对象
        let env = vm.getInterpreter().getGlobalEnv()
        var current: ?JsValue = None

        for (part in objPath) {
            match (current) {
                case None => {
                    match (env.lookup(part)) {
                        case Some(v) => current = Some(v)
                        case None => return
                    }
                }
                case Some(val) => {
                    match (val.objectData) {
                        case Some(obj) => {
                            match (obj.get(part)) {
                                case Some(v) => current = Some(v)
                                case None => return
                            }
                        }
                        case None => return
                    }
                }
            }
        }

        // 获取对象的所有属性
        match (current) {
            case Some(val) =>
                match (val.objectData) {
                    case Some(obj) =>
                        let keys = obj.keys()
                        for (key in keys) {
                            if (key.startsWith(prefix)) {
                                result.candidates.append(key)
                            }
                        }
                    case None => ()
                }
            case None => ()
        }
    }

    /// 计算候选列表的共同前缀
    private func commonPrefixOf(candidates: ArrayList<String>): String {
        if (candidates.size == 0) {
            return ""
        }
        var prefix = candidates[0]
        for (i in 1..candidates.size) {
            let s = candidates[Int64(i)]
            while (!s.startsWith(prefix) && prefix.length > 0) {
                prefix = prefix.substring(0, prefix.length - 1)
            }
            if (prefix.isEmpty()) {
                return ""
            }
        }
        return prefix
    }

    // ========================================================================
    // 特殊命令
    // ========================================================================

    /// 处理点命令 - 对应 Bun/Node.js REPL 特殊命令
    private func handleDotCommand(command: String): JsValue {
        let cmd = command.toLower()
        match (cmd) {
            case ".exit" | ".quit" => {
                running = false
                return JsValue.UNDEFINED
            }
            case ".help" => {
                let helpText = StringBuilder()
                helpText.append(".exit     Exit the REPL\n")
                helpText.append(".help     Print this help message\n")
                helpText.append(".clear    Clear the REPL context\n")
                helpText.append(".save     Save REPL session to file\n")
                helpText.append(".load     Load REPL session from file\n")
                helpText.append(".history  Show command history\n")
                outputFn(helpText.toString())
                return JsValue.UNDEFINED
            }
            case ".clear" => {
                inputBuffer.clear()
                outputFn("Clearing context...")
                return JsValue.UNDEFINED
            }
            case ".history" => {
                let entries = history
                for (i in 0..entries.size()) {
                    outputFn("  ${i}: ${entries.previous().getOrElse { "" }}")
                }
                return JsValue.UNDEFINED
            }
            case ".save" => {
                // .save <filename> - 保存会话
                return JsValue.UNDEFINED
            }
            case ".load" => {
                // .load <filename> - 加载会话
                return JsValue.UNDEFINED
            }
            case _ => {
                outputFn("Invalid REPL command: ${command}")
                return JsValue.UNDEFINED
            }
        }
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 拼接输入缓冲区
    private func joinBuffer(): String {
        let sb = StringBuilder()
        for (i in 0..inputBuffer.size) {
            if (i > 0) {
                sb.append("\n")
            }
            sb.append(inputBuffer[Int64(i)])
        }
        return sb.toString()
    }

    /// 刷新全局变量名缓存
    private func refreshGlobalNames(): Unit {
        globalNames.clear()
        let env = vm.getInterpreter().getGlobalEnv()
        // 添加常见的全局变量名
        let builtins = [
            "undefined", "NaN", "Infinity", "console", "parseInt", "parseFloat",
            "isNaN", "isFinite", "String", "Number", "Boolean", "Array", "Object",
            "Function", "Symbol", "Date", "RegExp", "Error", "TypeError",
            "RangeError", "ReferenceError", "SyntaxError", "URIError", "EvalError",
            "JSON", "Math", "Promise", "Map", "Set", "WeakMap", "WeakSet",
            "Proxy", "Reflect", "require", "process", "globalThis", "Buffer",
            "setTimeout", "setInterval", "clearTimeout", "clearInterval",
            "setImmediate", "clearImmediate", "queueMicrotask"
        ]
        for (name in builtins) {
            globalNames.append(name)
        }
    }

    /// 打印欢迎信息 - 对应 Bun repl 启动横幅
    private func printWelcome(): Unit {
        outputFn("Welcome to Bao.js REPL v0.1.0")
        outputFn("Type \".help\" for more information.")
        outputFn("")
    }

    /// 将 REPL 导出为 JsValue (供 JS 调用)
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let repl = this

        obj.set("start", JsValue.nativeFunction(JsNativeFunction("start") { _ =>
            repl.start()
            return JsValue.UNDEFINED
        }))

        obj.set("stop", JsValue.nativeFunction(JsNativeFunction("stop") { _ =>
            repl.stop()
            return JsValue.UNDEFINED
        }))

        obj.set("evalLine", JsValue.nativeFunction(JsNativeFunction("evalLine") { args =>
            if (args.size >= 1) {
                let line = Interpreter.jsToString(args[0])
                return repl.evalLine(line)
            }
            return JsValue.UNDEFINED
        }))

        obj.set("printResult", JsValue.nativeFunction(JsNativeFunction("printResult") { args =>
            if (args.size >= 1) {
                repl.printResult(args[0])
            }
            return JsValue.UNDEFINED
        }))

        obj.set("complete", JsValue.nativeFunction(JsNativeFunction("complete") { args =>
            if (args.size >= 1) {
                let line = Interpreter.jsToString(args[0])
                let completion = repl.complete(line)
                let arr = ArrayList<JsValue>()
                for (c in completion.candidates) {
                    arr.append(JsValue(BaoString(c)))
                }
                return JsValue.array(arr)
            }
            return JsValue.array(ArrayList<JsValue>())
        }))

        return JsValue(obj)
    }
}

/// REPL 模块导出
public class REPLModule {
    /// 创建 REPL 实例
    public static func create(vm: VirtualMachine): REPL {
        return REPL(vm)
    }

    /// 创建带自定义提示符的 REPL
    public static func create(vm: VirtualMachine, prompt: String): REPL {
        return REPL(vm, prompt)
    }

    /// 将 REPL 类导出为 JsValue
    public static func toJsValue(): JsValue {
        let obj = JsObject()
        obj.set("REPL", JsValue.nativeFunction(JsNativeFunction("REPL") { args =>
            // 需要一个 VirtualMachine 来创建 REPL
            return JsValue.UNDEFINED
        }))
        return JsValue(obj)
    }
}
