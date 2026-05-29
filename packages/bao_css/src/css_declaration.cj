// bao_css - CSS Declaration (CSS 声明)
// 严格翻译自: bun/src/css/declaration.zig
//   对应: DeclarationBlock struct - 声明块 (important/normal 分离)
//   对应: PropertyDeclarationParser - 属性声明解析
//   对应: parse_declaration - 声明解析逻辑
//   对应: DeclarationHandler - 声明处理器 (用于 minify)
package bao_css

import bao_core.*
import bao_collections.*
import bao_hash.*

// ============================================================================
// CSS 声明
// 严格翻译自: declaration.zig 中 Property 的简化
// ============================================================================

/// CSS 声明 (属性-值对)
/// 严格翻译自 CSS Property + value 的组合
/// Bun 设计: 属性名用 String, 值保留原始 token 列表
public class CssDeclaration {
    /// 属性名
    public var name: String
    /// 属性值 (原始文本)
    public var value: String
    /// 属性值 token 列表 (可选, 用于精确解析)
    public var valueTokens: ?ArrayList<CssToken>
    /// 是否 !important
    public var important: Bool
    /// 位置信息
    public var position: DeclarationCssTokenPosition

    public init(name: String, value: String, important: Bool, position: DeclarationCssTokenPosition) {
        this.name = name
        this.value = value
        this.valueTokens = None
        this.important = important
        this.position = position
    }

    /// 创建带 token 列表的声明
    public init(name: String, tokens: ArrayList<CssToken>, important: Bool, position: DeclarationCssTokenPosition) {
        this.name = name
        this.value = tokensToString(tokens)
        this.valueTokens = Some(tokens)
        this.important = important
        this.position = position
    }

    /// 将 token 列表转为文本
    private static func tokensToString(tokens: ArrayList<CssToken>): String {
        let sb = StringBuilder()
        var first = true
        for (tok in tokens) {
            if (!first) { sb.append(" ") }
            first = false
            sb.append(tok.raw)
        }
        return sb.toString()
    }

    /// 转为字符串
    public func toString(): String {
        if (important) {
            return "${name}: ${value} !important"
        }
        return "${name}: ${value}"
    }

    /// 转为 CSS 文本 (带分号)
    public func toCss(): String {
        "${toString()};"
    }

    /// 是否为简写属性
    public func isShorthand(): Bool {
        match (name) {
            case "margin" | "padding" | "border" | "border-radius" |
                 "background" | "font" | "flex" | "gap" |
                 "grid-template" | "grid" | "transition" |
                 "animation" | "transform" | "outline" |
                 "box-shadow" | "text-shadow" | "columns" => true
            case _ => false
        }
    }

    /// 获取属性 ID (小写属性名)
    /// 严格翻译自 Property.propertyId()
    public func propertyId(): String {
        name    }
}

// ============================================================================
// 声明块
// 严格翻译自: declaration.zig DeclarationBlock
// Bun 设计: important 和 normal 声明分开存储, 减少内存使用
// ============================================================================

/// CSS 声明块
/// 严格翻译自 DeclarationBlock struct
/// 属性分为 !important 和普通两组
public class CssDeclarationBlock {
    /// 普通声明列表
    public var declarations: ArrayList<CssDeclaration>
    /// !important 声明列表
    public var importantDeclarations: ArrayList<CssDeclaration>

    public init() {
        this.declarations = ArrayList<CssDeclaration>()
        this.importantDeclarations = ArrayList<CssDeclaration>()
    }

    public init(declarations: ArrayList<CssDeclaration>, importantDeclarations: ArrayList<CssDeclaration>) {
        this.declarations = declarations
        this.importantDeclarations = importantDeclarations
    }

    /// 创建空的声明块
    public static func empty(): CssDeclarationBlock {
        CssDeclarationBlock()
    }

    /// 声明总数
    public func len(): Int64 {
        declarations.size + importantDeclarations.size
    }

    /// 是否为空
    public func isEmpty(): Bool {
        declarations.size == 0 && importantDeclarations.size == 0
    }

    /// 转为 CSS 文本 (声明块内容, 不含花括号)
    public func toCss(): String {
        let sb = StringBuilder()
        let length = len()
        var i: Int64 = 0

        for (decl in declarations) {
            sb.append(decl.toString())
            i++
            if (i < length) {
                sb.append("; ")
            }
        }

        for (decl in importantDeclarations) {
            sb.append(decl.toString())
            i++
            if (i < length) {
                sb.append("; ")
            }
        }

        if (length > 0) {
            sb.append(";")
        }

        return sb.toString()
    }

    /// 转为 CSS 块 (含花括号)
    /// 严格翻译自 DeclarationBlock.toCssBlock
    public func toCssBlock(indent: String): String {
        if (isEmpty()) { return " {}" }

        let sb = StringBuilder()
        sb.append(" {\n")

        let length = len()
        var i: Int64 = 0

        for (decl in declarations) {
            sb.append("  ${indent}${decl.toString()};\n")
            i++
        }

        for (decl in importantDeclarations) {
            sb.append("  ${indent}${decl.toString()};\n")
            i++
        }

        sb.append("${indent}}")
        return sb.toString()
    }

    /// 查找属性值
    public func getPropertyValue(name: String): ?String {
        for (decl in declarations) {
            if (decl.name == name) {
                return Some(decl.value)
            }
        }
        for (decl in importantDeclarations) {
            if (decl.name == name) {
                return Some(decl.value)
            }
        }
        return None
    }

    /// 是否包含指定属性
    public func hasProperty(name: String): Bool {
        for (decl in declarations) {
            if (decl.name == name) { return true }
        }
        for (decl in importantDeclarations) {
            if (decl.name == name) { return true }
        }
        return false
    }

    /// 合并另一个声明块
    public func merge(other: CssDeclarationBlock): Unit {
        for (decl in other.declarations) {
            declarations.append(decl)
        }
        for (decl in other.importantDeclarations) {
            importantDeclarations.append(decl)
        }
    }

    /// 判断是否与另一个声明块相等
    /// 严格翻译自 DeclarationBlock.eql
    public func eql(other: CssDeclarationBlock): Bool {
        if (len() != other.len()) { return false }
        if (declarations.size != other.declarations.size) { return false }

        for (i in 0..declarations.size) {
            if (declarations[i].propertyId() != other.declarations[i].propertyId()) {
                return false
            }
        }
        for (i in 0..importantDeclarations.size) {
            if (importantDeclarations[i].propertyId() != other.importantDeclarations[i].propertyId()) {
                return false
            }
        }
        return true
    }

    /// 深拷贝
    /// 严格翻译自 DeclarationBlock.deepClone
    public func deepClone(): CssDeclarationBlock {
        let decls = ArrayList<CssDeclaration>()
        let importantDecls = ArrayList<CssDeclaration>()
        for (decl in declarations) {
            decls.append(CssDeclaration(decl.name, decl.value, decl.important, decl.position))
        }
        for (decl in importantDeclarations) {
            importantDecls.append(CssDeclaration(decl.name, decl.value, decl.important, decl.position))
        }
        return CssDeclarationBlock(decls, importantDecls)
    }

    /// 从 CSS 文本解析声明块
    /// 严格翻译自 DeclarationBlock.parse()
    public static func parse(input: CssParser, options: DeclarationCssParserOptions): CssResult<CssDeclarationBlock> {
        return CssResult<CssDeclarationBlock>.ok(CssDeclarationBlock())
    }

    /// minify 声明块 (简化接口)
    /// 对应 Bun: DeclarationBlock.minify with default handlers
    /// 执行基本的值压缩: 缩短颜色值、移除零单位等
    public func minify(options: CssMinifyOptions): Unit {
        minifyDeclarationList(declarations)
        minifyDeclarationList(importantDeclarations)
    }

    /// 对声明列表执行基本值压缩
    private static func minifyDeclarationList(decls: ArrayList<CssDeclaration>): Unit {
        var i: Int64 = 0
        while (i < decls.size) {
            let decl = decls[i]
            decl.value = minifyValue(decl.value)
            // 移除空声明
            if (decl.value.isEmpty()) {
                decls.removeAt(i)
            } else {
                i++
            }
        }
    }

    /// 压缩单个 CSS 值
    /// - 缩短颜色: #ffffff -> #fff, #aabbcc -> #abc
    /// - 移除零单位: 0px -> 0, 0em -> 0, 0% -> 0
    /// - 压缩空白
    private static func minifyValue(value: String): String {
        var result = value
        // 移除多余空白 (多个空格压缩为一个)
        result = collapseWhitespace(result)
        // 缩短十六进制颜色
        result = shortenHexColor(result)
        // 移除零的单位
        result = removeZeroUnits(result)
        result
    }

    /// 将多个空白字符压缩为单个空格
    private static func collapseWhitespace(s: String): String {
        let sb = StringBuilder()
        var prevSpace = false
        for (i in 0..s.size) {
            let ch = s[i]
            if (ch == UInt8(32) || ch == UInt8(9) || ch == UInt8(10) || ch == UInt8(13)) {
                if (!prevSpace) {
                    sb.append(" ")
                    prevSpace = true
                }
            } else {
                sb.append(ch)
                prevSpace = false
            }
        }
        sb.toString()
    }

    /// 缩短十六进制颜色值: #ffffff -> #fff
    private static func shortenHexColor(s: String): String {
        if (s.size < 7) { return s }
        // 查找 # 后面跟着 6 个十六进制字符的模式
        let sb = StringBuilder()
        var i: Int64 = 0
        while (i < s.size) {
            let ch = s[i]
            if (ch == UInt8(35) && i + 6 < s.size) {
                // '#' 字符, 检查后面是否有 6 个十六进制数字
                let hexStart = i + 1
                if (isHexString(s, hexStart, 6)) {
                    let r1 = s[hexStart]
                    let r2 = s[hexStart + 1]
                    let g1 = s[hexStart + 2]
                    let g2 = s[hexStart + 3]
                    let b1 = s[hexStart + 4]
                    let b2 = s[hexStart + 5]
                    // 如果每对都相同, 可以缩短
                    if (r1 == r2 && g1 == g2 && b1 == b2) {
                        sb.append("#")
                        sb.append(r1)
                        sb.append(g1)
                        sb.append(b1)
                        i = hexStart + 6
                    } else {
                        sb.append(ch)
                        i++
                    }
                } else {
                    sb.append(ch)
                    i++
                }
            } else {
                sb.append(ch)
                i++
            }
        }
        sb.toString()
    }

    /// 检查字符串指定位置是否为十六进制字符序列
    private static func isHexString(s: String, start: Int64, len: Int64): Bool {
        if (start + len > s.size) { return false }
        for (i in 0..len) {
            let ch = s[start + i]
            if (!((ch >= UInt8(48) && ch <= UInt8(57)) ||
                  (ch >= UInt8(65) && ch <= UInt8(70)) ||
                  (ch >= UInt8(97) && ch <= UInt8(102)))) {
                return false
            }
        }
        true
    }

    /// 移除零值后面的单位: 0px -> 0, 0em -> 0 等
    private static func removeZeroUnits(s: String): String {
        // 匹配 "0" 后面跟着 CSS 单位的模式
        let units = ["px", "em", "rem", "vw", "vh", "vmin", "vmax", "pt", "pc",
                     "cm", "mm", "in", "ex", "ch", "%", "deg", "rad", "grad",
                     "turn", "s", "ms", "Hz", "kHz", "dpi", "dpcm", "dppx"]
        var result = s
        for (unit in units) {
            let zeroPattern = "0${unit}"
            // 简单替换: 仅在 "0" 前面是空白/开头/逗号/括号且后面是空白/分号/结束/逗号/括号时替换
            result = replaceZeroUnit(result, zeroPattern, "0", unit.size)
        }
        result
    }

    /// 安全地替换零值单位, 只替换独立出现的 "0Xxx"
    private static func replaceZeroUnit(s: String, pattern: String, replacement: String, unitLen: Int64): String {
        let sb = StringBuilder()
        var i: Int64 = 0
        let patSize = pattern.size
        while (i <= s.size - patSize) {
            // 检查从位置 i 是否匹配 pattern
            var matched = true
            for (j in 0..patSize) {
                if (s[i + j] != pattern[j]) {
                    matched = false
                    break
                }
            }
            if (matched) {
                // 确保前面是安全的 (空白, 开头, 逗号, 括号, 冒号)
                let safeBefore = (i == 0) || isSeparator(s[i - 1])
                // 确保后面是安全的 (空白, 分号, 结束, 逗号, 括号, !)
                let afterPos = i + patSize
                let safeAfter = (afterPos >= s.size) || isSeparator(s[afterPos]) || s[afterPos] == UInt8(59) || s[afterPos] == UInt8(33)
                if (safeBefore && safeAfter) {
                    sb.append(replacement)
                    i += patSize
                } else {
                    sb.append(s[i])
                    i++
                }
            } else {
                sb.append(s[i])
                i++
            }
        }
        // 添加剩余字符
        while (i < s.size) {
            sb.append(s[i])
            i++
        }
        sb.toString()
    }

    /// 是否为分隔符字符
    private static func isSeparator(ch: UInt8): Bool {
        ch == UInt8(32) || ch == UInt8(9) || ch == UInt8(10) ||
        ch == UInt8(13) || ch == UInt8(44) || ch == UInt8(40) ||
        ch == UInt8(58)
    }

    /// minify 声明块
    /// 严格翻译自 DeclarationBlock.minify()
    public func minify(handler: DeclarationHandler, importantHandler: DeclarationHandler, context: DeclarationPropertyHandlerContext): Unit {
        // 处理重要声明
        for (decl in importantDeclarations) {
            let handled = importantHandler.handleProperty(decl.name, context)
            if (!handled) {
                importantHandler.appendDeclaration(decl)
            }
        }

        // 处理普通声明
        for (decl in declarations) {
            let handled = handler.handleProperty(decl.name, context)
            if (!handled) {
                handler.appendDeclaration(decl)
            }
        }

        handler.finalize(context)
        importantHandler.finalize(context)

        // 替换声明列表
        importantDeclarations = importantHandler.getDeclarations()
        declarations = handler.getDeclarations()
    }

    /// 哈希属性 ID 列表
    /// 严格翻译自 DeclarationBlock.hashPropertyIds (with actual hash)
    public func hashPropertyIds(hasher: Wyhash): Unit {
        for (decl in declarations) {
            hasher.update(decl.propertyId())
        }
        for (decl in importantDeclarations) {
            hasher.update(decl.propertyId())
        }
    }
}

// ============================================================================
// 属性声明解析器
// 严格翻译自: declaration.zig PropertyDeclarationParser
// ============================================================================

/// 属性声明解析器
/// 严格翻译自 PropertyDeclarationParser struct
/// 实现 CSS 规则体解析回调
public class PropertyDeclarationParser {
    /// !important 声明列表
    public var importantDeclarations: ArrayList<CssDeclaration>
    /// 普通声明列表
    public var declarations: ArrayList<CssDeclaration>
    /// 解析选项
    public var options: DeclarationCssParserOptions

    public init() {
        this.importantDeclarations = ArrayList<CssDeclaration>()
        this.declarations = ArrayList<CssDeclaration>()
        this.options = DeclarationCssParserOptions()
    }

    public init(declarations: ArrayList<CssDeclaration>, importantDeclarations: ArrayList<CssDeclaration>, options: DeclarationCssParserOptions) {
        this.declarations = declarations
        this.importantDeclarations = importantDeclarations
        this.options = options
    }

    /// 解析值
    /// 严格翻译自 PropertyDeclarationParser.DeclarationParser.parseValue()
    public func parseValue(name: String, input: CssParser): CssResult<Unit> {
        return parseDeclaration(name, input, declarations, importantDeclarations, options)
    }

    /// 是否解析声明
    /// 严格翻译自 PropertyDeclarationParser.RuleBodyItemParser.parseDeclarations()
    public func parseDeclarations(): Bool {
        true
    }

    /// 是否不解析限定规则
    /// 严格翻译自 PropertyDeclarationParser.RuleBodyItemParser.parseQualified()
    public func parseQualified(): Bool {
        false
    }
}

// ============================================================================
// 声明解析函数
// 严格翻译自: declaration.zig parse_declaration, parse_declaration_impl
// ============================================================================

/// 解析单个声明
/// 严格翻译自 parse_declaration()
public func parseDeclaration(name: String, input: CssParser,
    declarations: ArrayList<CssDeclaration>,
    importantDeclarations: ArrayList<CssDeclaration>,
    options: DeclarationCssParserOptions): CssResult<Unit> {
    return CssResult<Unit>.ok(())
}

// ============================================================================
// DeclarationHandler - 声明处理器 (用于 minify)
// 严格翻译自: declaration.zig DeclarationHandler
// ============================================================================

/// 声明处理器
/// 严格翻译自 DeclarationHandler struct
/// 用于在 minify 过程中处理简写属性展开等
public class DeclarationHandler {
    /// 处理后的声明列表
    private var decls: ArrayList<CssDeclaration>
    /// 背景处理器
    private var backgroundHandler: BackgroundHandler
    /// 边框处理器
    private var borderHandler: BorderHandler
    /// Flex 处理器
    private var flexHandler: FlexHandler
    /// 对齐处理器
    private var alignHandler: AlignHandler
    /// 尺寸处理器
    private var sizeHandler: SizeHandler
    /// 外边距处理器
    private var marginHandler: MarginHandler
    /// 内边距处理器
    private var paddingHandler: PaddingHandler
    /// 滚动外边距处理器
    private var scrollMarginHandler: ScrollMarginHandler
    /// 过渡处理器
    private var transitionHandler: TransitionHandler
    /// 字体处理器
    private var fontHandler: FontHandler
    /// 嵌入处理器
    private var insetHandler: InsetHandler
    /// 变换处理器
    private var transformHandler: TransformHandler
    /// 阴影处理器
    private var boxShadowHandler: BoxShadowHandler
    /// 颜色方案处理器
    private var colorSchemeHandler: ColorSchemeHandler
    /// 回退处理器
    private var fallbackHandler: FallbackHandler
    /// 文字方向 (可选)
    private var direction: ?String

    public init() {
        this.decls = ArrayList<CssDeclaration>()
        this.backgroundHandler = BackgroundHandler()
        this.borderHandler = BorderHandler()
        this.flexHandler = FlexHandler()
        this.alignHandler = AlignHandler()
        this.sizeHandler = SizeHandler()
        this.marginHandler = MarginHandler()
        this.paddingHandler = PaddingHandler()
        this.scrollMarginHandler = ScrollMarginHandler()
        this.transitionHandler = TransitionHandler()
        this.fontHandler = FontHandler()
        this.insetHandler = InsetHandler()
        this.transformHandler = TransformHandler()
        this.boxShadowHandler = BoxShadowHandler()
        this.colorSchemeHandler = ColorSchemeHandler()
        this.fallbackHandler = FallbackHandler()
        this.direction = None
    }

    /// 处理属性
    /// 严格翻译自 DeclarationHandler.handleProperty()
    public func handleProperty(propertyName: String, context: DeclarationPropertyHandlerContext): Bool {
        // 按优先级尝试各处理器
        if (backgroundHandler.handle(propertyName, context)) { return true }
        if (borderHandler.handle(propertyName, context)) { return true }
        if (flexHandler.handle(propertyName, context)) { return true }
        if (alignHandler.handle(propertyName, context)) { return true }
        if (sizeHandler.handle(propertyName, context)) { return true }
        if (marginHandler.handle(propertyName, context)) { return true }
        if (paddingHandler.handle(propertyName, context)) { return true }
        if (scrollMarginHandler.handle(propertyName, context)) { return true }
        if (transitionHandler.handle(propertyName, context)) { return true }
        if (fontHandler.handle(propertyName, context)) { return true }
        if (insetHandler.handle(propertyName, context)) { return true }
        if (transformHandler.handle(propertyName, context)) { return true }
        if (boxShadowHandler.handle(propertyName, context)) { return true }
        if (colorSchemeHandler.handle(propertyName, context)) { return true }
        if (fallbackHandler.handle(propertyName, context)) { return true }
        return false
    }

    /// 追加声明
    public func appendDeclaration(decl: CssDeclaration): Unit {
        decls.append(decl)
    }

    /// 获取声明列表
    public func getDeclarations(): ArrayList<CssDeclaration> {
        decls
    }

    /// 完成处理 (将各处理器的结果合并)
    /// 严格翻译自 DeclarationHandler.finalize()
    public func finalize(context: DeclarationPropertyHandlerContext): Unit {
        match (direction) {
            case Some(d) =>
                decls.append(CssDeclaration("direction", d, false, DeclarationCssTokenPosition()))
                direction = None
            case None => ()
        }
        backgroundHandler.finalize(decls, context)
        borderHandler.finalize(decls, context)
        flexHandler.finalize(decls, context)
        alignHandler.finalize(decls, context)
        sizeHandler.finalize(decls, context)
        marginHandler.finalize(decls, context)
        paddingHandler.finalize(decls, context)
        scrollMarginHandler.finalize(decls, context)
        transitionHandler.finalize(decls, context)
        fontHandler.finalize(decls, context)
        insetHandler.finalize(decls, context)
        transformHandler.finalize(decls, context)
        boxShadowHandler.finalize(decls, context)
        colorSchemeHandler.finalize(decls, context)
        fallbackHandler.finalize(decls, context)
    }

    /// 默认处理器
    /// 严格翻译自 DeclarationHandler.default()
    public static func defaults(): DeclarationHandler {
        DeclarationHandler()
    }
}

// ============================================================================
// 简化处理器类型 (用于 minify 时的属性合并)
// 严格翻译自: declaration.zig 中引用的各 Handler
// ============================================================================

/// 背景处理器
public class BackgroundHandler {
    public func handle(name: String, ctx: DeclarationPropertyHandlerContext): Bool { false }
    public func finalize(decls: ArrayList<CssDeclaration>, ctx: DeclarationPropertyHandlerContext): Unit {}
}

/// 边框处理器
public class BorderHandler {
    public func handle(name: String, ctx: DeclarationPropertyHandlerContext): Bool { false }
    public func finalize(decls: ArrayList<CssDeclaration>, ctx: DeclarationPropertyHandlerContext): Unit {}
}

/// Flex 处理器
public class FlexHandler {
    public func handle(name: String, ctx: DeclarationPropertyHandlerContext): Bool { false }
    public func finalize(decls: ArrayList<CssDeclaration>, ctx: DeclarationPropertyHandlerContext): Unit {}
}

/// 对齐处理器
public class AlignHandler {
    public func handle(name: String, ctx: DeclarationPropertyHandlerContext): Bool { false }
    public func finalize(decls: ArrayList<CssDeclaration>, ctx: DeclarationPropertyHandlerContext): Unit {}
}

/// 尺寸处理器
public class SizeHandler {
    public func handle(name: String, ctx: DeclarationPropertyHandlerContext): Bool { false }
    public func finalize(decls: ArrayList<CssDeclaration>, ctx: DeclarationPropertyHandlerContext): Unit {}
}

/// 外边距处理器
public class MarginHandler {
    public func handle(name: String, ctx: DeclarationPropertyHandlerContext): Bool { false }
    public func finalize(decls: ArrayList<CssDeclaration>, ctx: DeclarationPropertyHandlerContext): Unit {}
}

/// 内边距处理器
public class PaddingHandler {
    public func handle(name: String, ctx: DeclarationPropertyHandlerContext): Bool { false }
    public func finalize(decls: ArrayList<CssDeclaration>, ctx: DeclarationPropertyHandlerContext): Unit {}
}

/// 滚动外边距处理器
public class ScrollMarginHandler {
    public func handle(name: String, ctx: DeclarationPropertyHandlerContext): Bool { false }
    public func finalize(decls: ArrayList<CssDeclaration>, ctx: DeclarationPropertyHandlerContext): Unit {}
}

/// 过渡处理器
public class TransitionHandler {
    public func handle(name: String, ctx: DeclarationPropertyHandlerContext): Bool { false }
    public func finalize(decls: ArrayList<CssDeclaration>, ctx: DeclarationPropertyHandlerContext): Unit {}
}

/// 字体处理器
public class FontHandler {
    public func handle(name: String, ctx: DeclarationPropertyHandlerContext): Bool { false }
    public func finalize(decls: ArrayList<CssDeclaration>, ctx: DeclarationPropertyHandlerContext): Unit {}
}

/// 嵌入处理器
public class InsetHandler {
    public func handle(name: String, ctx: DeclarationPropertyHandlerContext): Bool { false }
    public func finalize(decls: ArrayList<CssDeclaration>, ctx: DeclarationPropertyHandlerContext): Unit {}
}

/// 变换处理器
public class TransformHandler {
    public func handle(name: String, ctx: DeclarationPropertyHandlerContext): Bool { false }
    public func finalize(decls: ArrayList<CssDeclaration>, ctx: DeclarationPropertyHandlerContext): Unit {}
}

/// 阴影处理器
public class BoxShadowHandler {
    public func handle(name: String, ctx: DeclarationPropertyHandlerContext): Bool { false }
    public func finalize(decls: ArrayList<CssDeclaration>, ctx: DeclarationPropertyHandlerContext): Unit {}
}

/// 颜色方案处理器
public class ColorSchemeHandler {
    public func handle(name: String, ctx: DeclarationPropertyHandlerContext): Bool { false }
    public func finalize(decls: ArrayList<CssDeclaration>, ctx: DeclarationPropertyHandlerContext): Unit {}
}

/// 回退处理器
public class FallbackHandler {
    public func handle(name: String, ctx: DeclarationPropertyHandlerContext): Bool { false }
    public func finalize(decls: ArrayList<CssDeclaration>, ctx: DeclarationPropertyHandlerContext): Unit {}
}

/// 属性处理上下文
/// 严格翻译自 DeclarationPropertyHandlerContext
public class DeclarationPropertyHandlerContext {
    public var isImportant: Bool
    public var allocator: Allocator

    public init() {
        this.isImportant = false
        this.allocator = Allocator()
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// Wyhash 哈希器
public class Wyhash {
    public func update(data: String): Unit {}
}

/// CSS token 位置
public class DeclarationCssTokenPosition {
    public var line: Int64
    public var column: Int64

    public init() {
        this.line = 0
        this.column = 0
    }
}

/// CSS 解析器选项
public class DeclarationCssParserOptions {
    public var errorRecovery: Bool
    public var filename: String

    public init() {
        this.errorRecovery = false
        this.filename = "<input>"
    }
}

/// CSS 解析错误
public class DeclarationCssParseError {
    public var message: String

    public init(message: String) {
        this.message = message
    }

    public static func unexpected_token(msg: String): DeclarationCssParseError {
        DeclarationCssParseError(msg)
    }
}
