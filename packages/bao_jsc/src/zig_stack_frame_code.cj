// 严格翻译自: src/jsc/ZigStackFrameCode.zig
// Zig 栈帧代码类型

package bao_jsc

// ========== ZigStackFrameCode ==========
// 严格翻译自 ZigStackFrameCode
// 表示 JavaScript 栈帧的代码类型
public enum ZigStackFrameCode: UInt8 {
    case None = 0
    case Eval = 1
    case Module = 2
    case Function = 3
    case Global = 4
    case Wasm = 5
    case Constructor = 6

    // 严格翻译自 ZigStackFrameCode.emoji
    public func emoji() -> String {
        match (this) {
            case Eval => "\u{1F3C3}"
            case Module => "\u{1F4E6}"
            case Function => "\u{03BB}"
            case Global => "\u{1F30E}"
            case Wasm => "\u{FE0F}"
            case Constructor => "\u{F1477}"
            case _ => " "
        }
    }

    // 严格翻译自 ZigStackFrameCode.ansiColor
    public func ansiColor() -> String {
        match (this) {
            case Eval => "\u{1B}[31m"
            case Module => "\u{1B}[36m"
            case Function => "\u{1B}[32m"
            case Global => "\u{1B}[35m"
            case Wasm => "\u{1B}[37m"
            case Constructor => "\u{1B}[33m"
            case _ => ""
        }
    }
}
