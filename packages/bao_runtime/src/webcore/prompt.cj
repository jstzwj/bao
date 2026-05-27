// Prompt - Web 提示对话框 API
// 对应 Bun: src/runtime/webcore/prompt.zig
// 严格翻译自: src/runtime/webcore/prompt.zig
package bao_runtime.webcore

import bao_core.*
import bao_jsc.*
import std.console.*

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
        print(message)
        println(" [Enter]")
        ()
        // 等待用户按回车键
        let _ = Console.stdIn.readln()
    }

    /// confirm() — 显示确认对话框
    /// 对应 Web API: window.confirm(message)
    /// 对应 Bun: confirm()
    public static func confirm(message: String): Bool {
        print(message)
        print(" [y/N] ")
        ()
        let rawInput = Console.stdIn.readln().getOrThrow().trimAscii()
        let input = if (rawInput == "Y") { "y" } else { rawInput }
        return input == "y" || input == "yes" || input == "Y" || input == "YES" || input == "Yes"
    }

    /// prompt() — 显示输入对话框
    /// 对应 Web API: window.prompt(message, defaultValue)
    /// 对应 Bun: prompt.call()
    public static func prompt(message: String): ?String {
        print(message)
        print(": ")
        ()
        let input = Console.stdIn.readln().getOrThrow().trimAscii()
        if (input.size == 0) {
            return None
        }
        return Some(input)
    }

    /// prompt() 带默认值
    public static func prompt(message: String, defaultValue: String): ?String {
        print(message)
        print(" [${defaultValue}]: ")
        ()
        let input = Console.stdIn.readln().getOrThrow().trimAscii()
        if (input.size == 0) {
            if (defaultValue.size == 0) {
                return None
            }
            return Some(defaultValue)
        }
        return Some(input)
    }

    /// 转为 JsValue — alert
    public static func alertToJsValue(): JsValue {
        return JsValue.undefined()
    }

    /// 转为 JsValue — confirm
    public static func confirmToJsValue(): JsValue {
        return JsValue.undefined()
    }

    /// 转为 JsValue — prompt
    public static func promptToJsValue(): JsValue {
        return JsValue.undefined()
    }
}
