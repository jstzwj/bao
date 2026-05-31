// Prompt - Web 提示对话框 API
// 严格翻译自: src/runtime/webcore/prompt.rs (415行)
// 对应 Web API: alert(), confirm(), prompt()
package bao_runtime.webcore

import bao_core.*
import bao_jsc.*
import std.console.*
import std.collection.*

// ============================================================================
// Prompt - Web 提示对话框 API
// 对应 Bun: src/runtime/webcore/prompt.rs
// 对应 Web API: alert(), confirm(), prompt()
// https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html
// ============================================================================

/// 从 Console.stdIn 读取一个字节，返回 None 表示 EOF 或错误
/// 对应 Bun: reader.takeByte() / reader.readByte()
func stdinReadByte(): ?UInt8 {
    try {
        let ch = Console.stdIn.read()
        match (ch) {
            case Some(r) => Some(UInt8(r))
            case None => None
        }
    } catch (_: Exception) {
        None
    }
}

/// 从 Console.stdIn 读取一行，返回空字符串表示 EOF 或错误
func stdinReadLine(): String {
    try {
        let line = Console.stdIn.readln()
        match (line) {
            case Some(s) => s
            case None => ""
        }
    } catch (_: Exception) {
        ""
    }
}

// ============================================================================
// JS Host Function 导出 — 对应 Bun: #[bun_jsc::host_fn] exported functions
// ============================================================================

/// https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-alert
/// 对应 Bun: WebCore__alert (host_fn export)
/// alert() 显示一个警告对话框，等待用户按 Enter 确认
public func webcoreAlert(global: JsGlobalObject, frame: CallFrame): JsValue {
    let arguments = frame.argumentsOld(1).slice()
    let hasMessage = arguments.size != 0

    // 2. If the method was invoked with no arguments, then let message be
    //    the empty string; otherwise, let message be the method's first argument.
    if (hasMessage) {
        let message = arguments[0].toString()

        if (message.size > 0) {
            // 3. Set message to the result of normalizing newlines given message.
            // *  We skip step 3 because they are already done in most terminals by default.

            // 4. Set message to the result of optionally truncating message.
            // *  We just don't do this because it's not necessary.

            // 5. Show message to the user, treating U+000A LF as a line break.
            print(message)
        }
    }

    if (hasMessage) {
        print(" [Enter] ")
    } else {
        print("Alert [Enter] ")
    }

    // 6. Invoke WebDriver BiDi user prompt opened with this, "alert", and message.
    // *  Not pertinent to use their complex system in a server context.
    Output.flush()

    // 7. Optionally, pause while waiting for the user to acknowledge the message.
    // 逐字节读取，直到遇到换行符
    while (true) {
        let byte = stdinReadByte()
        match (byte) {
            case Some(b) =>
                if (b == UInt8('\n')) {
                    break
                }
            case None => break
        }
    }

    // 8. Invoke WebDriver BiDi user prompt closed with this and true.
    // *  Again, not necessary in a server context.

    return JsValue.UNDEFINED
}

/// https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-confirm
/// 对应 Bun: WebCore__confirm (host_fn export)
/// confirm() 显示确认对话框，用户输入 y/Y 确认，其余为否定
///
/// 实现细节 (严格匹配 Bun/Zig 行为):
/// - 仅检查首字节是否为 'y'/'Y' 并紧跟 '\n' (或 '\r\n')
/// - '\n' 单独 = false (否定)
/// - '\r\n' = false (否定)
/// - 其他所有输入均视为否定
/// - 多余输入会被消费直到换行符
public func webcoreConfirm(global: JsGlobalObject, frame: CallFrame): JsValue {
    let arguments = frame.argumentsOld(1).slice()
    let hasMessage = arguments.size != 0

    if (hasMessage) {
        // 2. Set message to the result of normalizing newlines given message.
        // *  Not pertinent to a server runtime so we will just let the terminal handle this.

        // 3. Set message to the result of optionally truncating message.
        // *  Not necessary so we won't do it.
        let message = arguments[0].toString()

        print(message)
    }

    // 4. Show message to the user, treating U+000A LF as a line break,
    //    and ask the user to respond with a positive or negative
    //    response.
    if (hasMessage) {
        print(" [y/N] ")
    } else {
        print("Confirm [y/N] ")
    }

    // 5. Invoke WebDriver BiDi user prompt opened with this, "confirm", and message.
    // *  Not relevant in a server context.
    Output.flush()

    // 6. Pause until the user responds either positively or negatively.
    let firstByte = stdinReadByte()
    if (firstByte == None) {
        return JsValue.jsFalse()
    }
    let first = firstByte.get()

    // 7. Invoke WebDriver BiDi user prompt closed with this, and true if
    //    the user responded positively or false otherwise.
    // *  Not relevant in a server context.

    // 根据首字节判断用户响应
    if (first == UInt8('\n')) {
        // 直接回车 = 否定
        return JsValue.jsFalse()
    } else if (first == UInt8('\r')) {
        // \r 开头 — 可能是 Windows 换行 \r\n
        let nextByte = stdinReadByte()
        if (nextByte == None) {
            // They may have said yes, but the stdin is invalid.
            return JsValue.jsFalse()
        }
        if (nextByte.get() == UInt8('\n')) {
            return JsValue.jsFalse()
        }
    } else if (first == UInt8('y') || first == UInt8('Y')) {
        // 以 y/Y 开头 — 检查下一个字节
        let nextByte = stdinReadByte()
        if (nextByte == None) {
            // They may have said yes, but the stdin is invalid.
            return JsValue.jsFalse()
        }
        let next = nextByte.get()

        if (next == UInt8('\n')) {
            // 8. If the user responded positively, return true;
            //    otherwise, the user responded negatively: return false.
            return JsValue.jsTrue()
        } else if (next == UInt8('\r')) {
            // Check Windows style: \r\n
            let secondByte = stdinReadByte()
            if (secondByte == None) {
                return JsValue.jsFalse()
            }
            if (secondByte.get() == UInt8('\n')) {
                return JsValue.jsTrue()
            }
        }
    }
    // else: 其他字符 — 不是肯定回答

    // 消费剩余的输入直到换行符
    while (true) {
        let b = stdinReadByte()
        match (b) {
            case Some(byte) =>
                if (byte == UInt8('\n') || byte == UInt8('\r')) {
                    break
                }
            case None => break
        }
    }

    // 8. If the user responded positively, return true; otherwise, the user
    //    responded negatively: return false.
    return JsValue.jsFalse()
}

// ============================================================================
// Prompt 读取辅助函数 — 对应 Bun: pub mod prompt 内部辅助函数
// ============================================================================

/// 读取直到分隔符 — 追加到缓冲区 (固定容量上限)
/// 对应 Bun: read_until_delimiter_array_list_append_assume_capacity
/// 从 stdin 逐字节读取直到遇到 delimiter 或达到 max_size
/// 返回 true 表示成功读到分隔符，false 表示超出 max_size (StreamTooLong)
func readUntilDelimiterAppendAssumeCapacity(
    array: ArrayList<UInt8>,
    delimiter: UInt8,
    maxSize: Int64
): Bool {
    while (true) {
        if (Int64(array.size) == maxSize) {
            // StreamTooLong — 超出容量限制
            return false
        }

        let byte = stdinReadByte()
        match (byte) {
            case Some(b) =>
                if (b == delimiter) {
                    return true
                }
                array.append(b)
            case None => return true
        }
    }
}

/// 读取直到分隔符 — 无限追加 (无容量限制)
/// 对应 Bun: read_until_delimiter_array_list_infinity
/// 从 stdin 逐字节读取直到遇到 delimiter，无大小限制
func readUntilDelimiterInfinity(
    array: ArrayList<UInt8>,
    delimiter: UInt8
): Unit {
    while (true) {
        let byte = stdinReadByte()
        match (byte) {
            case Some(b) =>
                if (b == delimiter) {
                    return
                }
                array.append(b)
            case None => return
        }
    }
}

/// 将 ArrayList<UInt8> 转为 String
func bytesToString(bytes: ArrayList<UInt8>): String {
    var sb = StringBuilder()
    for (b in bytes) {
        sb.append(Char(b))
    }
    sb.toString()
}

// ============================================================================
// prompt() — JS Host Function 导出
// ============================================================================

/// https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-prompt
/// 对应 Bun: WebCore__prompt (host_fn export)
/// prompt() 显示输入提示，让用户输入字符串
///
/// 实现细节:
/// - 支持消息和默认值参数
/// - 逐字节读取以精确处理 \r\n / \n 换行
/// - 三级缓冲策略: 先尝试 2048 字节，再 4096，最后无限增长
/// - 修剪末尾 \r 以处理 Windows 换行
public func webcorePrompt(global: JsGlobalObject, frame: CallFrame): JsValue {
    let arguments = frame.argumentsOld(3).slice()
    let hasMessage = arguments.size != 0
    let hasDefault = arguments.size >= 2

    // 4. Set default to the result of optionally truncating default.
    // *  We don't really need to do this.
    let defaultValue = if (hasDefault) { arguments[1] } else { JsValue.NULL }

    if (hasMessage) {
        // 2. Set message to the result of normalizing newlines given message.
        // *  Not pertinent to a server runtime so we will just let the terminal handle this.

        // 3. Set message to the result of optionally truncating message.
        // *  Not necessary so we won't do it.
        let message = arguments[0].toString()

        print(message)
    }

    // 5. Show message to the user, treating U+000A LF as a line break,
    //    and ask the user to either respond with a string value or
    //    abort. The response must be defaulted to the value given by
    //    default.
    if (hasMessage) {
        print(" ")
    } else {
        print("Prompt ")
    }

    if (hasDefault) {
        let defaultString = arguments[1].toString()
        print("[${defaultString}] ")
    }

    // 6. Invoke WebDriver BiDi user prompt opened with this, "prompt" and message.
    // *  Not relevant in a server context.
    Output.flush()

    // 7. Pause while waiting for the user's response.
    // 逐字节读取用户输入
    var secondByte: ?UInt8 = None

    let firstByte = stdinReadByte()
    if (firstByte == None) {
        // 8. Let result be null if the user aborts, or otherwise the string
        //    that the user responded with.
        return JsValue.NULL
    }
    let first = firstByte.get()

    // 处理首字节: 空行 → 返回默认值
    if (first == UInt8('\n')) {
        // 8. Let result be null if the user aborts, or otherwise the string
        //    that the user responded with.
        return defaultValue
    } else if (first == UInt8('\r')) {
        let second = stdinReadByte()
        if (second == None) {
            return JsValue.NULL
        }
        secondByte = second
        if (second.get() == UInt8('\n')) {
            return defaultValue
        }
    }

    // 构建输入缓冲区 — 三级容量策略
    var input = ArrayList<UInt8>()
    input.reserve(2048)

    // 追加首字节（和次字节，如果有的话）
    input.append(first)
    if (let Some(second) <- secondByte) {
        input.append(second)
    }

    // 第一级: 尝试读入 2048 字节缓冲区
    let reachedDelimiter = readUntilDelimiterAppendAssumeCapacity(input, UInt8('\n'), 2048)
    if (!reachedDelimiter) {
        // 第二级: 扩充到 4096 字节
        input.reserve(4096)

        let reachedDelimiter2 = readUntilDelimiterAppendAssumeCapacity(input, UInt8('\n'), 4096)
        if (!reachedDelimiter2) {
            // 第三级: 无限增长
            readUntilDelimiterInfinity(input, UInt8('\n'))
        }
    }

    // 修剪末尾 \r (Windows 换行处理)
    if (input.size > 0 && input[input.size - 1] == UInt8('\r')) {
        input.removeAt(input.size - 1)
    }

    // 调试断言: 输入非空且不以 \r 结尾
    // if (debug_mode) { assert(input.size > 0); assert(input[input.size-1] != '\r'); }

    // 8. Let result be null if the user aborts, or otherwise the string
    //    that the user responded with.
    let resultString = bytesToString(input)

    // 9. Invoke WebDriver BiDi user prompt closed with this, false if
    //    result is null or true otherwise, and result.
    // *  Too complex for server context.

    // 9. Return result.
    return JsValue(resultString)
}

// ============================================================================
// Prompt — 面向仓颉原生调用的简便 API
// 对应 Bun: src/runtime/webcore/prompt.rs 中各函数的仓颉友好封装
// ============================================================================

/// Prompt — Web 提示对话框 API (仓颉原生调用版本)
/// 对应 Web API: window.alert(), window.confirm(), window.prompt()
/// 对应 Bun: src/runtime/webcore/prompt.rs
public class Prompt {
    /// alert() — 显示警告对话框
    /// 对应 Web API: window.alert(message)
    /// 对应 Bun: alert()
    /// https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-alert
    ///
    /// 显示消息并等待用户按回车确认。如果没有提供消息，
    /// 则显示默认的 "Alert" 提示。
    public static func alert(message: String): Unit {
        if (message.size > 0) {
            print(message)
            print(" [Enter] ")
        } else {
            print("Alert [Enter] ")
        }
        Output.flush()

        // 7. Optionally, pause while waiting for the user to acknowledge the message.
        // 逐字节读取，直到遇到换行符
        while (true) {
            let byte = stdinReadByte()
            match (byte) {
                case Some(b) =>
                    if (b == UInt8('\n')) {
                        break
                    }
                case None => break
            }
        }
    }

    /// confirm() — 显示确认对话框
    /// 对应 Web API: window.confirm(message)
    /// 对应 Bun: confirm()
    /// https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-confirm
    ///
    /// 实现细节 (严格匹配 Bun/Zig 行为):
    /// - 仅检查首字节是否为 'y'/'Y' 并紧跟 '\n' (或 '\r\n')
    /// - '\n' 单独 = false (否定)
    /// - '\r\n' = false (否定)
    /// - 其他所有输入均视为否定
    /// - 多余输入会被消费直到换行符
    public static func confirm(message: String): Bool {
        if (message.size > 0) {
            print(message)
            print(" [y/N] ")
        } else {
            print("Confirm [y/N] ")
        }
        Output.flush()

        // 6. Pause until the user responds either positively or negatively.
        let firstByte = stdinReadByte()
        if (firstByte == None) {
            return false
        }
        let first = firstByte.get()

        // \n = 否定
        if (first == UInt8('\n')) {
            return false
        }

        // \r 开头 — 可能是 Windows \r\n
        if (first == UInt8('\r')) {
            let nextByte = stdinReadByte()
            if (nextByte == None) {
                // They may have said yes, but the stdin is invalid.
                return false
            }
            if (nextByte.get() == UInt8('\n')) {
                return false
            }
        } else if (first == UInt8('y') || first == UInt8('Y')) {
            // 以 y/Y 开头
            let nextByte = stdinReadByte()
            if (nextByte == None) {
                // They may have said yes, but the stdin is invalid.
                return false
            }
            let next = nextByte.get()

            if (next == UInt8('\n')) {
                // 8. If the user responded positively, return true;
                //    otherwise, the user responded negatively: return false.
                return true
            } else if (next == UInt8('\r')) {
                // Windows: \r\n
                let secondByte = stdinReadByte()
                if (secondByte == None) {
                    return false
                }
                if (secondByte.get() == UInt8('\n')) {
                    return true
                }
            }
        }

        // 消费剩余输入直到换行
        while (true) {
            let b = stdinReadByte()
            match (b) {
                case Some(byte) =>
                    if (byte == UInt8('\n') || byte == UInt8('\r')) {
                        break
                    }
                case None => break
            }
        }

        return false
    }

    /// prompt() — 显示输入对话框 (无默认值)
    /// 对应 Web API: window.prompt(message)
    /// 对应 Bun: prompt.call()
    /// https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-prompt
    ///
    /// 返回 None 表示用户取消 (空行)
    /// 返回 Some(string) 表示用户的输入
    ///
    /// 实现细节:
    /// - 逐字节读取以精确处理 \r\n / \n 换行
    /// - 三级缓冲策略: 先尝试 2048 字节，再 4096，最后无限增长
    /// - 修剪末尾 \r 以处理 Windows 换行
    public static func prompt(message: String): ?String {
        if (message.size > 0) {
            print(message)
            print(" ")
        } else {
            print("Prompt ")
        }
        Output.flush()

        // 7. Pause while waiting for the user's response.
        // 逐字节读取输入
        var secondByte: ?UInt8 = None

        let firstByte = stdinReadByte()
        if (firstByte == None) {
            // 8. Let result be null if the user aborts
            return None
        }
        let first = firstByte.get()

        // 首字节是换行 → 用户取消 → 返回 None
        if (first == UInt8('\n')) {
            return None
        }

        if (first == UInt8('\r')) {
            let second = stdinReadByte()
            if (second == None) {
                return None
            }
            secondByte = second
            if (second.get() == UInt8('\n')) {
                return None
            }
        }

        // 构建输入缓冲区
        var input = ArrayList<UInt8>()
        input.reserve(2048)
        input.append(first)
        if (let Some(second) <- secondByte) {
            input.append(second)
        }

        // 三级缓冲策略读取剩余内容
        let reachedDelimiter = readUntilDelimiterAppendAssumeCapacity(input, UInt8('\n'), 2048)
        if (!reachedDelimiter) {
            input.reserve(4096)
            let reachedDelimiter2 = readUntilDelimiterAppendAssumeCapacity(input, UInt8('\n'), 4096)
            if (!reachedDelimiter2) {
                readUntilDelimiterInfinity(input, UInt8('\n'))
            }
        }

        // 修剪末尾 \r
        if (input.size > 0 && input[input.size - 1] == UInt8('\r')) {
            input.removeAt(input.size - 1)
        }

        let result = bytesToString(input)
        if (result.size == 0) {
            return None
        }
        return Some(result)
    }

    /// prompt() — 带默认值
    /// 对应 Web API: window.prompt(message, defaultValue)
    ///
    /// 当用户直接按回车时返回 defaultValue
    /// 当 defaultValue 为空且用户直接按回车时返回 None
    ///
    /// 实现细节:
    /// - 逐字节读取以精确处理 \r\n / \n 换行
    /// - 三级缓冲策略: 先尝试 2048 字节，再 4096，最后无限增长
    /// - 修剪末尾 \r 以处理 Windows 换行
    public static func prompt(message: String, defaultValue: String): ?String {
        if (message.size > 0) {
            print(message)
            print(" ")
        } else {
            print("Prompt ")
        }

        if (defaultValue.size > 0) {
            print("[${defaultValue}] ")
        }
        Output.flush()

        // 7. Pause while waiting for the user's response.
        var secondByte: ?UInt8 = None

        let firstByte = stdinReadByte()
        if (firstByte == None) {
            // 用户取消 — 如果有默认值则返回
            if (defaultValue.size > 0) {
                return Some(defaultValue)
            }
            return None
        }
        let first = firstByte.get()

        // 首字节是换行 → 返回默认值
        if (first == UInt8('\n')) {
            if (defaultValue.size > 0) {
                return Some(defaultValue)
            }
            return None
        }

        if (first == UInt8('\r')) {
            let second = stdinReadByte()
            if (second == None) {
                if (defaultValue.size > 0) {
                    return Some(defaultValue)
                }
                return None
            }
            secondByte = second
            if (second.get() == UInt8('\n')) {
                if (defaultValue.size > 0) {
                    return Some(defaultValue)
                }
                return None
            }
        }

        // 构建输入缓冲区
        var input = ArrayList<UInt8>()
        input.reserve(2048)
        input.append(first)
        if (let Some(second) <- secondByte) {
            input.append(second)
        }

        // 三级缓冲策略读取剩余内容
        let reachedDelimiter = readUntilDelimiterAppendAssumeCapacity(input, UInt8('\n'), 2048)
        if (!reachedDelimiter) {
            input.reserve(4096)
            let reachedDelimiter2 = readUntilDelimiterAppendAssumeCapacity(input, UInt8('\n'), 4096)
            if (!reachedDelimiter2) {
                readUntilDelimiterInfinity(input, UInt8('\n'))
            }
        }

        // 修剪末尾 \r
        if (input.size > 0 && input[input.size - 1] == UInt8('\r')) {
            input.removeAt(input.size - 1)
        }

        let result = bytesToString(input)
        if (result.size == 0) {
            if (defaultValue.size > 0) {
                return Some(defaultValue)
            }
            return None
        }
        return Some(result)
    }

    /// 转为 JsValue — alert
    /// 对应 Bun: WebCore__alert 导出函数
    public static func alertToJsValue(global: JsGlobalObject, frame: CallFrame): JsValue {
        webcoreAlert(global, frame)
    }

    /// 转为 JsValue — confirm
    /// 对应 Bun: WebCore__confirm 导出函数
    public static func confirmToJsValue(global: JsGlobalObject, frame: CallFrame): JsValue {
        webcoreConfirm(global, frame)
    }

    /// 转为 JsValue — prompt
    /// 对应 Bun: WebCore__prompt 导出函数
    public static func promptToJsValue(global: JsGlobalObject, frame: CallFrame): JsValue {
        webcorePrompt(global, frame)
    }
}
