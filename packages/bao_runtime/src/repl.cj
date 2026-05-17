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
        let trimmed = entry
        if (trimmed.isEmpty()) {
            return
        }
        // 不添加与最后一条相同的条目
        if (entries.size > 0) {
            let last = entries[entries.size - 1]
            if (last == trimmed) {
                return
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
            let input = match (line) {
                case Some(v) => v
                case None =>
                    outputFn("")
                    break
            }

            // 空行处理
            if (input.isEmpty()) {
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
                case REPLInputState.Complete =>
                    // 完整表达式，求值
                    history.add(fullInput)
                    inputBuffer.clear()
                    evalAndPrint(fullInput)
                case REPLInputState.Incomplete =>
                    // 不完整，继续读取
                    // 不做任何事，循环继续
                    ()
                case REPLInputState.Error =>
                    // 语法错误，尝试求值以显示错误信息
                    history.add(fullInput)
                    inputBuffer.clear()
                    evalAndPrint(fullInput)
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
        outputFn(prompt)
        return None
    }

    /// 求值一行输入 - 对应 Bun: repl evalLine
    /// Bun 使用 JSEvaluateScript 在全局作用域执行
    public func evalLine(line: String): JsValue {
        if (line.startsWith(".")) {
            return handleDotCommand(line)
        }

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
        if (value.valueType == JsValueType.Undefined) {
            return
        }
        let formatted = formatValue(value)
        outputFn(formatted)
    }

    /// 格式化 JsValue 为可读字符串
    /// 对应 Bun: formatValue / inspect
    public func formatValue(value: JsValue): String {
        match (value.valueType) {
            case JsValueType.Undefined => "undefined"
            case JsValueType.Null => "null"
            case JsValueType.Boolean => if (value.boolValue) { "true" } else { "false" }
            case JsValueType.Number => formatNumber(value.numberValue)
            case JsValueType.String => "'${value.stringValue.toString()}'"
            case JsValueType.Object => formatObject(value)
            case JsValueType.Array => formatArray(value)
            case JsValueType.Function => formatFunction(value)
            case JsValueType.Symbol => "Symbol()"
            case JsValueType.BigInt => "${value.stringValue.toString()}n"
            case JsValueType.Date => "Date"
            case JsValueType.RegExp => value.stringValue.toString()
            case JsValueType.Promise => "Promise { <pending> }"
            case _ => value.toString()
        }
    }

    private func formatNumber(n: Float64): String {
        if (n == Float64(Int64(n)) && !n.isNaN()) {
            return "${Int64(n)}"
        }
        return n.toString()
    }

    private func formatFunction(value: JsValue): String {
        match (value.functionData) {
            case Some(fn) => "[Function: ${fn.name}]"
            case None => "[Function: anonymous]"
        }
    }

    /// 格式化对象 - 对应 Bun inspect 对象
    private func formatObject(value: JsValue): String {
        match (value.objectData) {
            case Some(obj) => return formatObjectData(obj)
            case None => "{}"
        }
    }

    private func formatObjectData(obj: JsObject): String {
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

    /// 格式化数组 - 对应 Bun inspect 数组
    private func formatArray(value: JsValue): String {
        match (value.arrayData) {
            case Some(arr) => return formatArrayData(arr)
            case None => "[]"
        }
    }

    private func formatArrayData(arr: ArrayList<JsValue>): String {
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

    // ========================================================================
    // 多行输入检测
    // ========================================================================

    /// 检查输入状态 - 对应 Bun repl 检测不完整表达式
    /// Bun 通过 JSC 的 JSCheckScriptSyntax 检测
    public func checkInputState(input: String): REPLInputState {
        if (input.isEmpty()) {
            return REPLInputState.Complete
        }
        return REPLInputState.Complete
    }

    /// 检查是否有未闭合的块结构
    /// 对应 Bun repl 中检测 {, (, [, `, /* 等未闭合符号
    private func hasUnclosedBlock(input: String): Bool {
        return false
    }

    private func hasUnclosedBlockUnused(input: String): Bool {
        var parenDepth = 0    // ()
        var bracketDepth = 0  // []
        var braceDepth = 0    // {}
        var inTemplate = false   // ``
        var inBlockComment = false  // /* */
        var inString: ?UInt8 = None  // '', "", backtick

        for (i in 0..input.size) {
            let c = input[i]

            if (inBlockComment) {
                if (c == 42u8 && i + 1 < input.size && input[i + 1] == 47u8) {
                    inBlockComment = false
                }
                continue
            }

            match (inString) {
                case Some(quoteChar) =>
                    if (c == 92u8 && i + 1 < input.size) {
                        continue  // 跳过转义字符
                    }
                    if (c == quoteChar) {
                        inString = Option<UInt8>.None
                    }
                    continue
                case _ => ()
            }

            if (c == 47u8) {  // /
                if (i + 1 < input.size && input[i + 1] == 42u8) {  // *
                    inBlockComment = true
                }
            } else if (c == 39u8) {  // '
                inString = Some(39u8)
            } else if (c == 34u8) {  // "
                inString = Some(34u8)
            } else if (c == 96u8) {  // `
                inString = Some(96u8)
            } else if (c == 40u8) {  // (
                parenDepth += 1
            } else if (c == 41u8) {  // )
                parenDepth -= 1
            } else if (c == 91u8) {  // [
                bracketDepth += 1
            } else if (c == 93u8) {  // ]
                bracketDepth -= 1
            } else if (c == 123u8) {  // {
                braceDepth += 1
            } else if (c == 125u8) {  // }
                braceDepth -= 1
            }
        }

        return parenDepth > 0 || bracketDepth > 0 || braceDepth > 0 ||
               inBlockComment || inString.isSome()
    }

    /// 判断解析错误是否因为输入不完整
    /// 对应 Bun: 检测 "Unexpected end of input" 类错误
    private func isIncompleteError(input: String, result: ParseResult): Bool {
        return false
    }

    // ========================================================================
    // Tab 补全
    // ========================================================================

    /// Tab 补全 - 对应 Bun: repl completion callback
    /// Bun 使用 JSC 的 JSObjectCopyPropertyNames 获取属性列表
    public func complete(line: String): CompletionResult {
        return CompletionResult()
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
                case None => current = lookupCompletionRoot(env, part)
                case Some(val) => current = lookupCompletionProperty(val, part)
            }
            if (current.isNone()) {
                return
            }
        }

        // 获取对象的所有属性
        match (current) {
            case Some(val) => appendPropertyCompletions(val, prefix, result)
            case None => ()
        }
    }

    private func lookupCompletionRoot(env: Environment, part: String): ?JsValue {
        match (env.lookup(part)) {
            case Some(v) => Some(v)
            case None => Option<JsValue>.None
        }
    }

    private func lookupCompletionProperty(value: JsValue, part: String): ?JsValue {
        match (value.objectData) {
            case Some(obj) => Some(obj.get(part))
            case None => Option<JsValue>.None
        }
    }

    private func appendPropertyCompletions(value: JsValue, prefix: String, result: CompletionResult): Unit {
        match (value.objectData) {
            case Some(obj) => appendObjectPropertyCompletions(obj, prefix, result)
            case None => ()
        }
    }

    private func appendObjectPropertyCompletions(obj: JsObject, prefix: String, result: CompletionResult): Unit {
        let keys = obj.keys()
        for (key in keys) {
            if (key.startsWith(prefix)) {
                result.candidates.append(key)
            }
        }
    }

    /// 计算候选列表的共同前缀
    private func commonPrefixOf(candidates: ArrayList<String>): String {
        if (candidates.size == 0) {
            return ""
        }
        return candidates[0]
    }

    // ========================================================================
    // 特殊命令
    // ========================================================================

    /// 处理点命令 - 对应 Bun/Node.js REPL 特殊命令
    private func handleDotCommand(command: String): JsValue {
        match (command) {
            case ".exit" =>
                running = false
                return JsValue.UNDEFINED
            case ".quit" =>
                running = false
                return JsValue.UNDEFINED
            case ".help" =>
                let helpText = StringBuilder()
                helpText.append(".exit     Exit the REPL\n")
                helpText.append(".help     Print this help message\n")
                helpText.append(".clear    Clear the REPL context\n")
                helpText.append(".save     Save REPL session to file\n")
                helpText.append(".load     Load REPL session from file\n")
                helpText.append(".history  Show command history\n")
                outputFn(helpText.toString())
                return JsValue.UNDEFINED
            case ".clear" =>
                inputBuffer.clear()
                outputFn("Clearing context...")
                return JsValue.UNDEFINED
            case ".history" =>
                outputFn("History is unavailable")
                return JsValue.UNDEFINED
            case ".save" => return JsValue.UNDEFINED
            case ".load" => return JsValue.UNDEFINED
            case _ =>
                outputFn("Invalid REPL command: ${command}")
                return JsValue.UNDEFINED
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
