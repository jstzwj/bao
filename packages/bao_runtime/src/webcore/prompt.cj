// Prompt - Web 提示对话框 API
// 对应 Bun: src/runtime/webcore/prompt.zig
// 严格翻译自: src/runtime/webcore/prompt.zig
package bao_runtime

import bao_core.*

// ============================================================================
// Prompt - Web 提示对话框 API
// 对应 Bun: src/runtime/webcore/prompt.zig
// 对应 Web API: alert(), confirm(), prompt()
// ============================================================================

/// Prompt — Web 提示对话框 API
/// 对应 Web API: window.alert(), window.confirm(), window.prompt()
/// 对应 Bun: src/runtime/webcore/prompt.zig
public class Prompt {
    /// alert() — 显示警告对话框
    /// 对应 Web API: window.alert(message)
    /// 对应 Bun: alert()
    public static func alert(message: String): Unit {
        // 在终端环境中输出消息
        Output.print(message)
        Output.println(" [Enter]")
        Output.flush()
        // 等待用户按回车键
        Console.readln()
    }

    /// confirm() — 显示确认对话框
    /// 对应 Web API: window.confirm(message)
    /// 对应 Bun: confirm()
    public static func confirm(message: String): Bool {
        Output.print(message)
        Output.print(" [y/N] ")
        Output.flush()
        let input = Console.readln().trim().toLowerCase()
        return input == "y" || input == "yes"
    }

    /// prompt() — 显示输入对话框
    /// 对应 Web API: window.prompt(message, defaultValue)
    /// 对应 Bun: prompt.call()
    public static func prompt(message: String): ?String {
        Output.print(message)
        Output.print(": ")
        Output.flush()
        let input = Console.readln().trim()
        if (input.length == 0) {
            return None
        }
        return Some(input)
    }

    /// prompt() 带默认值
    public static func prompt(message: String, defaultValue: String): ?String {
        Output.print(message)
        Output.print(" [${defaultValue}]: ")
        Output.flush()
        let input = Console.readln().trim()
        if (input.length == 0) {
            if (defaultValue.length == 0) {
                return None
            }
            return Some(defaultValue)
        }
        return Some(input)
    }

    /// 转为 JsValue — alert
    public static func alertToJsValue(): JsValue {
        return JsValue.nativeFunction(JsNativeFunction("alert") { args =>
            let message = if (args.size >= 1) { Interpreter.jsToString(args[0]) } else { "Alert" }
            alert(message)
            JsValue.UNDEFINED
        })
    }

    /// 转为 JsValue — confirm
    public static func confirmToJsValue(): JsValue {
        return JsValue.nativeFunction(JsNativeFunction("confirm") { args =>
            let message = if (args.size >= 1) { Interpreter.jsToString(args[0]) } else { "Confirm?" }
            JsValue(confirm(message))
        })
    }

    /// 转为 JsValue — prompt
    public static func promptToJsValue(): JsValue {
        return JsValue.nativeFunction(JsNativeFunction("prompt") { args =>
            let message = if (args.size >= 1) { Interpreter.jsToString(args[0]) } else { "" }
            let defaultVal = if (args.size >= 2) { Interpreter.jsToString(args[1]) } else { "" }
            match (prompt(message, defaultVal)) {
                case Some(v) => JsValue(BaoString(v))
                case None => JsValue.NULL
            }
        })
    }
}
