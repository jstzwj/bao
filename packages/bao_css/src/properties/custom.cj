// bao_css - CSS Properties: Custom (var/env/unparsed)
// 严格翻译自: bun/src/css/properties/custom.rs
//   对应: custom.zig - CSS 自定义属性 / var() / env() / 未解析令牌列表
//   对应: TokenList, UnresolvedColor, Variable, EnvironmentVariable
//   对应: EnvironmentVariableName, UAEnvironmentVariable, Function
//   对应: TokenOrValue, UnparsedProperty, CustomProperty, CustomPropertyName
// ============================================================================

package bao.css

import bao_core.*

// ============================================================================
// TokenList
// 严格翻译自 TokenList
// ============================================================================

/// CSS 令牌列表（自定义属性值）
/// 严格翻译自 TokenList
public class TokenList {
    public var v: ArrayList<TokenOrValue>  // 令牌/值列表

    public init() {
        this.v = ArrayList<TokenOrValue>()
    }

    public init(v: ArrayList<TokenOrValue>) {
        this.v = v
    }

    public func toCss(): String {
        if (v.isEmpty()) {
            return ""
        }
        var parts = ArrayList<String>()
        for (item in v) {
            parts.append(item.toCss())
        }
        return String.join(" ", parts)
    }
}

// ============================================================================
// UnresolvedColor
// 严格翻译自 UnresolvedColor
// ============================================================================

/// 具有未解析 alpha 的颜色值
/// 严格翻译自 UnresolvedColor
public enum UnresolvedColor {
    | RGB(Float32, Float32, Float32, TokenList)             // RGB + 未解析 alpha
    | HSL(Float32, Float32, Float32, TokenList)             // HSL + 未解析 alpha
    | LightDark(TokenList, TokenList)                        // light-dark() 函数

    public func toCss(): String {
        match (this) {
            case RGB(r, g, b, alpha) => {
                var result = "rgb(" + r.toString() + " " + g.toString() + " " + b.toString()
                var alphaStr = alpha.toCss()
                if (alphaStr != "") {
                    result = result + " / " + alphaStr
                }
                return result + ")"
            }
            case HSL(h, s, l, alpha) => {
                var result = "hsl(" + h.toString() + " " + s.toString() + "% " + l.toString() + "%"
                var alphaStr = alpha.toCss()
                if (alphaStr != "") {
                    result = result + " / " + alphaStr
                }
                return result + ")"
            }
            case LightDark(light, dark) => {
                return "light-dark(" + light.toCss() + ", " + dark.toCss() + ")"
            }
        }
    }
}

// ============================================================================
// Variable
// 严格翻译自 Variable
// ============================================================================

/// CSS var() 引用
/// 严格翻译自 Variable
public class Variable {
    public var name: String                // 变量名 (--name)
    public var fallback: Option<TokenList> // 回退值

    public init(name: String, fallback: Option<TokenList>) {
        this.name = name
        this.fallback = fallback
    }

    public func toCss(): String {
        match (fallback) {
            case Some(fb) => "var(" + name + ", " + fb.toCss() + ")"
            case None => "var(" + name + ")"
        }
    }
}

// ============================================================================
// EnvironmentVariable
// 严格翻译自 EnvironmentVariable
// ============================================================================

/// CSS env() 引用
/// 严格翻译自 EnvironmentVariable
public class EnvironmentVariable {
    public var name: EnvironmentVariableName  // 环境变量名
    public var indices: ArrayList<Int32>      // 维度索引
    public var fallback: Option<TokenList>    // 回退值

    public init(name: EnvironmentVariableName, indices: ArrayList<Int32>, fallback: Option<TokenList>) {
        this.name = name
        this.indices = indices
        this.fallback = fallback
    }

    public func toCss(): String {
        var result = "env(" + name.toCss()
        for (idx in indices) {
            result = result + " " + idx.toString()
        }
        match (fallback) {
            case Some(fb) => result = result + ", " + fb.toCss()
            case None => {}
        }
        return result + ")"
    }
}

// ============================================================================
// EnvironmentVariableName
// 严格翻译自 EnvironmentVariableName
// ============================================================================

/// 环境变量名
/// 严格翻译自 EnvironmentVariableName
public enum EnvironmentVariableName {
    | Ua(UAEnvironmentVariable)        // UA 定义的环境变量
    | Custom(String)                    // 自定义环境变量
    | Unknown(String)                   // 未知环境变量

    public func toCss(): String {
        match (this) {
            case Ua(ua) => ua.toCss()
            case Custom(s) => s
            case Unknown(s) => s
        }
    }
}

// ============================================================================
// UAEnvironmentVariable
// 严格翻译自 UAEnvironmentVariable (DefineEnumProperty)
// ============================================================================

/// UA 定义的环境变量名
/// 严格翻译自 UAEnvironmentVariable
public enum UAEnvironmentVariable {
    | SafeAreaInsetTop
    | SafeAreaInsetRight
    | SafeAreaInsetBottom
    | SafeAreaInsetLeft
    | ViewportSegmentWidth
    | ViewportSegmentHeight
    | ViewportSegmentTop
    | ViewportSegmentLeft
    | ViewportSegmentBottom
    | ViewportSegmentRight

    public func toCss(): String {
        match (this) {
            case SafeAreaInsetTop => "safe-area-inset-top"
            case SafeAreaInsetRight => "safe-area-inset-right"
            case SafeAreaInsetBottom => "safe-area-inset-bottom"
            case SafeAreaInsetLeft => "safe-area-inset-left"
            case ViewportSegmentWidth => "viewport-segment-width"
            case ViewportSegmentHeight => "viewport-segment-height"
            case ViewportSegmentTop => "viewport-segment-top"
            case ViewportSegmentLeft => "viewport-segment-left"
            case ViewportSegmentBottom => "viewport-segment-bottom"
            case ViewportSegmentRight => "viewport-segment-right"
        }
    }
}

// ============================================================================
// Function
// 严格翻译自 Function
// ============================================================================

/// 自定义 CSS 函数
/// 严格翻译自 Function
public class Function {
    public var name: String        // 函数名
    public var arguments: TokenList // 函数参数

    public init(name: String, arguments: TokenList) {
        this.name = name
        this.arguments = arguments
    }

    public func toCss(): String {
        return name + "(" + arguments.toCss() + ")"
    }
}

// ============================================================================
// TokenOrValue
// 严格翻译自 TokenOrValue
// ============================================================================

/// CSS 令牌或已解析值
/// 严格翻译自 TokenOrValue
public enum TokenOrValue {
    | Token(String)                           // 原始令牌
    | Color(String)                           // 已解析颜色
    | UnresolvedColor(UnresolvedColor)        // 未解析颜色
    | Url(String)                             // 已解析 URL
    | Var(Variable)                           // var() 引用
    | Env(EnvironmentVariable)                // env() 引用
    | Function(Function)                      // 自定义函数
    | Length(String)                          // 长度
    | Angle(String)                           // 角度
    | Time(String)                            // 时间
    | Resolution(String)                      // 分辨率
    | DashedIdent(String)                     // 虚线标识符 (--*)
    | AnimationName(String)                   // 动画名称

    public func toCss(): String {
        match (this) {
            case Token(s) => s
            case Color(c) => c
            case UnresolvedColor(uc) => uc.toCss()
            case Url(u) => "url(" + u + ")"
            case Var(v) => v.toCss()
            case Env(e) => e.toCss()
            case Function(f) => f.toCss()
            case Length(l) => l
            case Angle(a) => a
            case Time(t) => t
            case Resolution(r) => r
            case DashedIdent(d) => d
            case AnimationName(n) => n
        }
    }

    public func isWhitespace(): Bool {
        match (this) {
            case Token(s) => s == " "
            case _ => false
        }
    }
}

// ============================================================================
// UnparsedProperty
// 严格翻译自 UnparsedProperty
// ============================================================================

/// 未解析的已知属性值（例如包含 var() 引用）
/// 严格翻译自 UnparsedProperty
public class UnparsedProperty {
    public var propertyId: String   // 属性 ID
    public var value: TokenList     // 原始令牌列表

    public init(propertyId: String, value: TokenList) {
        this.propertyId = propertyId
        this.value = value
    }

    public func toCss(): String {
        return propertyId + ": " + value.toCss()
    }
}

// ============================================================================
// CustomProperty
// 严格翻译自 CustomProperty
// ============================================================================

/// CSS 自定义属性
/// 严格翻译自 CustomProperty
public class CustomProperty {
    public var name: CustomPropertyName  // 自定义属性名
    public var value: TokenList          // 属性值

    public init(name: CustomPropertyName, value: TokenList) {
        this.name = name
        this.value = value
    }

    public func toCss(): String {
        return name.toCss() + ": " + value.toCss()
    }
}

// ============================================================================
// CustomPropertyName
// 严格翻译自 CustomPropertyName
// ============================================================================

/// CSS 自定义属性名
/// 严格翻译自 CustomPropertyName
public enum CustomPropertyName {
    | Custom(String)    // 自定义属性名 (--*)
    | Unknown(String)   // 未知属性名

    public func toCss(): String {
        match (this) {
            case Custom(s) => s
            case Unknown(s) => s
        }
    }
}
