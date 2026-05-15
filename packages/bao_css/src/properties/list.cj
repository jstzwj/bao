// bao_css - CSS Properties: List
// 严格翻译自: bun/src/css/properties/list.rs
//   对应: list.zig - CSS 列表属性
//   对应: ListStyleType, CounterStyle, Symbols, Symbol
//   对应: PredefinedCounterStyle, SymbolsType, ListStylePosition
//   对应: ListStyle, MarkerSide
// ============================================================================

package bao.css

import bao_core.*

// ============================================================================
// ListStyleType
// 严格翻译自 ListStyleType
// ============================================================================

/// list-style-type 属性值
/// 严格翻译自 ListStyleType
public enum ListStyleType {
    | None                     // 无标记
    | Str(String)              // 显式标记字符串
    | CounterStyle(CounterStyle) // 命名计数器样式

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Str(s) => s
            case CounterStyle(cs) => cs.toCss()
        }
    }
}

// ============================================================================
// CounterStyle
// 严格翻译自 CounterStyle
// ============================================================================

/// 计数器样式名称
/// 严格翻译自 CounterStyle
public enum CounterStyle {
    | Predefined(PredefinedCounterStyle) // 预定义计数器样式
    | Name(String)                       // 自定义计数器样式名称
    | Symbols(Symbols)                   // 内联 symbols() 定义

    public func toCss(): String {
        match (this) {
            case Predefined(p) => p.toCss()
            case Name(n) => n
            case Symbols(s) => s.toCss()
        }
    }
}

// ============================================================================
// Symbols
// 严格翻译自 Symbols
// ============================================================================

/// symbols() 函数定义
/// 严格翻译自 Symbols
public class Symbols {
    public var system: SymbolsType    // 计数器系统
    public var symbols: ArrayList<Symbol>  // 符号列表

    public init(system: SymbolsType, symbols: ArrayList<Symbol>) {
        this.system = system
        this.symbols = symbols
    }

    public func toCss(): String {
        var parts = ArrayList<String>()
        if (system != SymbolsType.Cyclic) {
            parts.append(system.toCss())
        }
        for (sym in symbols) {
            parts.append(sym.toCss())
        }
        return "symbols(" + String.join(" ", parts) + ")"
    }
}

// ============================================================================
// Symbol
// 严格翻译自 Symbol
// ============================================================================

/// 单个符号
/// 严格翻译自 Symbol
public enum Symbol {
    | Str(String)    // 字符串符号
    | Image(String)  // 图片符号

    public func toCss(): String {
        match (this) {
            case Str(s) => s
            case Image(u) => "url(" + u + ")"
        }
    }
}

// ============================================================================
// 占位类型 (Zig 源码中为 DefineEnumProperty(@compileError(...)) 占位)
// ============================================================================

/// 预定义计数器样式（占位）
/// Zig 源码为 @compileError(css.todo_stuff.depth) 占位
/// 严格翻译自 PredefinedCounterStyle
public enum PredefinedCounterStyle {
    | Disc
    | Circle
    | Square
    | Decimal
    | DecimalLeadingZero
    | LowerRoman
    | UpperRoman
    | LowerGreek
    | LowerLatin
    | UpperLatin
    | LowerAlpha
    | UpperAlpha
    | Armenian
    | Georgian

    public func toCss(): String {
        match (this) {
            case Disc => "disc"
            case Circle => "circle"
            case Square => "square"
            case Decimal => "decimal"
            case DecimalLeadingZero => "decimal-leading-zero"
            case LowerRoman => "lower-roman"
            case UpperRoman => "upper-roman"
            case LowerGreek => "lower-greek"
            case LowerLatin => "lower-latin"
            case UpperLatin => "upper-latin"
            case LowerAlpha => "lower-alpha"
            case UpperAlpha => "upper-alpha"
            case Armenian => "armenian"
            case Georgian => "georgian"
        }
    }
}

/// symbols-type 值（占位）
/// Zig 源码为 DefineEnumProperty(@compileError(...)) 占位
/// 严格翻译自 SymbolsType
public enum SymbolsType {
    | Cyclic
    | Numeric
    | Alphabetic
    | Symbolic
    | Fixed

    public func toCss(): String {
        match (this) {
            case Cyclic => "cyclic"
            case Numeric => "numeric"
            case Alphabetic => "alphabetic"
            case Symbolic => "symbolic"
            case Fixed => "fixed"
        }
    }
}

/// list-style-position 属性值（占位）
/// Zig 源码为 DefineEnumProperty(@compileError(...)) 占位
/// 严格翻译自 ListStylePosition
public enum ListStylePosition {
    | Inside
    | Outside

    public func toCss(): String {
        match (this) {
            case Inside => "inside"
            case Outside => "outside"
        }
    }
}

/// list-style 属性值（占位）
/// Zig 源码为 @compileError(css.todo_stuff.depth) 占位
/// 严格翻译自 ListStyle
public struct ListStyle {
}

/// marker-side 属性值（占位）
/// Zig 源码为 DefineEnumProperty(@compileError(...)) 占位
/// 严格翻译自 MarkerSide
public enum MarkerSide {
    | Marker
    | ListContainer

    public func toCss(): String {
        match (this) {
            case Marker => "marker"
            case ListContainer => "list-container"
        }
    }
}
