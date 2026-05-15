// bao_css - CSS Declaration (CSS 声明)
// 严格翻译自: bun/src/css/declaration.zig
//   对应: DeclarationBlock struct - 声明块 (important/normal 分离)
//   对应: PropertyDeclarationParser - 属性声明解析
//   对应: parse_declaration - 声明解析逻辑
//   对应: DeclarationHandler - 声明处理器 (用于 minify)
package bao.css

import bao_core.*
import bao_collections.*

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
    public var position: CssTokenPosition

    public init(name: String, value: String, important: Bool, position: CssTokenPosition) {
        this.name = name
        this.value = value
        this.valueTokens = None
        this.important = important
        this.position = position
    }

    /// 创建带 token 列表的声明
    public init(name: String, tokens: ArrayList<CssToken>, important: Bool, position: CssTokenPosition) {
        this.name = name
        this.value = tokensToString(tokens)
        this.valueTokens = Some(tokens)
        this.important = important
        this.position = position
    }

    /// 将 token 列表转为文本
    private static func tokensToString(tokens: ArrayList<CssToken>): String {
        let sb = StringBuilder()
        for (tok in tokens) {
            sb.append(tok.raw)
            if (sb.length > 0) { sb.append(" ") }
        }
        return sb.toString().trim()
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
        match (name.toLowerCase()) {
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
        name.toLowerCase()
    }
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
            if (decl.name.toLowerCase() == name.toLowerCase()) {
                return Some(decl.value)
            }
        }
        for (decl in importantDeclarations) {
            if (decl.name.toLowerCase() == name.toLowerCase()) {
                return Some(decl.value)
            }
        }
        return None
    }

    /// 是否包含指定属性
    public func hasProperty(name: String): Bool {
        for (decl in declarations) {
            if (decl.name.toLowerCase() == name.toLowerCase()) { return true }
        }
        for (decl in importantDeclarations) {
            if (decl.name.toLowerCase() == name.toLowerCase()) { return true }
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

    /// 哈希属性 ID 列表 (用于规则去重)
    /// 严格翻译自 DeclarationBlock.hashPropertyIds
    public func hashPropertyIds(hasher: Wyhash): Unit {
        for (decl in declarations) {
            hasher.update(decl.propertyId())
        }
        for (decl in importantDeclarations) {
            hasher.update(decl.propertyId())
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
}
