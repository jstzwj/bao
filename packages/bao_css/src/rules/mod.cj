// bao_css - CSS 规则模块入口
// 严格翻译自: bun/src/css/rules/mod.rs
//   对应: rules/rules.zig - CssRule, CssRuleList, MinifyContext, StyleContext
package bao_css.rules

import bao_core.*
import bao_collections.*
import bao_css.*
import bao_css.selectors.*

// ============================================================================
// 本地类型: CssRuleDeclaration (代替 bao_css.properties.CssProperty)
// ============================================================================

/// CSS 规则中的属性声明 (简化版)
/// 用于 CssRule 中的声明列表
public class CssRuleDeclaration {
    public var name: String
    public var value: String
    public var important: Bool

    public init(name: String, value: String) {
        this.name = name
        this.value = value
        this.important = false
    }

    public init(name: String, value: String, important: Bool) {
        this.name = name
        this.value = value
        this.important = important
    }

    public func toCss(minify: Bool): String {
        let importantStr = if (important) { " !important" } else { "" }
        "${name}: ${value}${importantStr}"
    }

    public func deepClone(): CssRuleDeclaration {
        CssRuleDeclaration(name, value, important)
    }

    public func toString(): String {
        toCss(false)
    }
}

// ============================================================================
// CSS 规则类型
// 严格翻译自: rules/mod.rs CssRule<R> enum
// ============================================================================

/// CSS 规则类型标签
/// 严格翻译自 CssRule<R> enum 的变体
public enum CssRuleKind {
    | Media            // @media
    | Import           // @import
    | Style            // style rule
    | Keyframes        // @keyframes
    | FontFace         // @font-face
    | FontPaletteValues  // @font-palette-values
    | Page             // @page
    | Supports         // @supports
    | CounterStyle     // @counter-style
    | Namespace        // @namespace
    | MozDocument      // @-moz-document
    | Nesting          // @nest
    | Viewport         // @viewport
    | CustomMedia      // @custom-media
    | LayerStatement   // @layer statement
    | LayerBlock       // @layer block
    | Property         // @property
    | Container        // @container
    | Scope            // @scope
    | StartingStyle    // @starting-style
    | Ignored          // 已删除的规则占位
    | Unknown          // 未知的 @ 规则
    | Custom           // 自定义规则

    public func toString(): String {
        match (this) {
            case Media => "Media"
            case Import => "Import"
            case Style => "Style"
            case Keyframes => "Keyframes"
            case FontFace => "FontFace"
            case FontPaletteValues => "FontPaletteValues"
            case Page => "Page"
            case Supports => "Supports"
            case CounterStyle => "CounterStyle"
            case Namespace => "Namespace"
            case MozDocument => "MozDocument"
            case Nesting => "Nesting"
            case Viewport => "Viewport"
            case CustomMedia => "CustomMedia"
            case LayerStatement => "LayerStatement"
            case LayerBlock => "LayerBlock"
            case Property => "Property"
            case Container => "Container"
            case Scope => "Scope"
            case StartingStyle => "StartingStyle"
            case Ignored => "Ignored"
            case Unknown => "Unknown"
            case Custom => "Custom"
        }
    }

    public operator func ==(rhs: CssRuleKind): Bool {
        this.toString() == rhs.toString()
    }
}

// ============================================================================
// CSS 规则
// 严格翻译自: rules/mod.rs CssRule<R>
// ============================================================================

/// CSS 单条规则
/// 严格翻译自 CssRule<R> union enum
public class CssRule {
    public var kind: CssRuleKind
    /// 选择器列表 (Style 规则)
    public var selectors: ?CssSelectorListImpl
    /// 声明块
    public var declarations: ArrayList<CssRuleDeclaration>
    /// 嵌套规则列表
    public var rules: ?CssRuleList
    /// @import URL
    public var importUrl: String
    /// @media 查询
    public var mediaQuery: String
    /// @supports 条件
    public var supportsCondition: String
    /// @keyframes 名称
    public var keyframesName: String
    /// @layer 名称
    public var layerName: String
    /// @container 条件
    public var containerCondition: String
    /// @scope 范围
    public var scopeCondition: String
    /// 厂商前缀
    public var vendorPrefix: VendorPrefix
    /// 源码位置
    public var loc: CssLocation

    public init(kind: CssRuleKind) {
        this.kind = kind
        this.selectors = None
        this.declarations = ArrayList<CssRuleDeclaration>()
        this.rules = None
        this.importUrl = ""
        this.mediaQuery = ""
        this.supportsCondition = ""
        this.keyframesName = ""
        this.layerName = ""
        this.containerCondition = ""
        this.scopeCondition = ""
        this.vendorPrefix = VendorPrefix()
        this.loc = CssLocation()
    }

    /// 转为 CSS 文本
    /// 严格翻译自 CssRule::to_css
    public func toCss(dest: CssPrinter): Unit {
        if (kind == CssRuleKind.Style) {
            toCssStyle(dest)
        } else if (kind == CssRuleKind.Media) {
            toCssMedia(dest)
        } else {
            toCssOther(dest)
        }
    }

    private func toCssStyle(dest: CssPrinter): Unit {
        match (selectors) {
            case Some(sels) =>
                dest.writeStr(sels.toCss())
                // 声明块
                dest.writeStr(" {")
                dest.indent()
                for (decl in declarations) {
                    dest.newline()
                    dest.writeStr(decl.toCss(dest.options.minify))
                    dest.writeStr(";")
                }
                dest.dedent()
                dest.newline()
                dest.writeStr("}")
            case None => ()
        }
    }

    private func writeRulesBlock(dest: CssPrinter, prefix: String, rulesOpt: ?CssRuleList): Unit {
        dest.writeStr(prefix)
        match (rulesOpt) {
            case Some(r) =>
                dest.writeStr(" {")
                dest.indent()
                for (rule in r.v) {
                    dest.newline()
                    rule.toCss(dest)
                }
                dest.dedent()
                dest.newline()
                dest.writeStr("}")
            case None => dest.writeStr(" {}")
        }
    }

    private func toCssMedia(dest: CssPrinter): Unit {
        writeRulesBlock(dest, "@media ${mediaQuery}", rules)
    }

    private func toCssOther(dest: CssPrinter): Unit {
        if (kind == CssRuleKind.Import) {
            dest.writeStr("@import ${importUrl};")
        } else if (kind == CssRuleKind.Keyframes) {
            writeRulesBlock(dest, "@keyframes ${keyframesName}", rules)
        } else if (kind == CssRuleKind.Supports) {
            writeRulesBlock(dest, "@supports ${supportsCondition}", rules)
        } else if (kind == CssRuleKind.LayerStatement) {
            dest.writeStr("@layer ${layerName};")
        } else if (kind == CssRuleKind.LayerBlock) {
            writeRulesBlock(dest, "@layer ${layerName}", rules)
        } else if (kind == CssRuleKind.Container) {
            writeRulesBlock(dest, "@container ${containerCondition}", rules)
        } else if (kind == CssRuleKind.Scope) {
            writeRulesBlock(dest, "@scope ${scopeCondition}", rules)
        } else if (kind == CssRuleKind.FontFace) {
            dest.writeStr("@font-face {")
            dest.indent()
            for (decl in declarations) {
                dest.newline()
                dest.writeStr(decl.toCss(false))
                dest.writeStr(";")
            }
            dest.dedent()
            dest.newline()
            dest.writeStr("}")
        } else if (kind == CssRuleKind.Namespace) {
            dest.writeStr("@namespace ${importUrl};")
        } else {
            ()
        }
    }

    /// 深拷贝
    public func deepClone(): CssRule {
        let r = CssRule(kind)
        r.selectors = match (selectors) { case Some(s) => Some(s.deepClone()) case None => Option<CssSelectorListImpl>.None }
        r.rules = match (rules) { case Some(rl) => Some(rl.deepClone()) case None => Option<CssRuleList>.None }
        let decls = ArrayList<CssRuleDeclaration>()
        for (d in declarations) {
            decls.append(d.deepClone())
        }
        r.declarations = decls
        r.importUrl = importUrl
        r.mediaQuery = mediaQuery
        r.supportsCondition = supportsCondition
        r.keyframesName = keyframesName
        r.layerName = layerName
        r.containerCondition = containerCondition
        r.scopeCondition = scopeCondition
        r.vendorPrefix = vendorPrefix
        r.loc = loc
        r
    }

    public func toString(): String {
        let printer = CssPrinter()
        toCss(printer)
        printer.getOutput()
    }
}

// ============================================================================
// CSS 规则列表
// 严格翻译自: rules/mod.rs CssRuleList<R>
// ============================================================================

/// CSS 规则列表
/// 严格翻译自 CssRuleList<R> struct { v: Vec<CssRule<R>> }
public class CssRuleList {
    public var v: ArrayList<CssRule>

    public init() {
        this.v = ArrayList<CssRule>()
    }

    public init(rules: ArrayList<CssRule>) {
        this.v = rules
    }

    /// 是否为空
    public func isEmpty(): Bool {
        v.isEmpty()
    }

    /// 转为 CSS 文本
    /// 严格翻译自 CssRuleList::to_css
    public func toCss(dest: CssPrinter): Unit {
        var first = true
        var lastWithoutBlock = false

        for (rule in v) {
            if (rule.kind == CssRuleKind.Ignored) { continue }

            // 跳过 @import (收集依赖时)
            if (rule.kind == CssRuleKind.Import && dest.removeImports) {
                continue
            }

            if (first) {
                first = false
            } else {
                if (!dest.options.minify) {
                    let isBlockless = rule.kind == CssRuleKind.Import ||
                                     rule.kind == CssRuleKind.Namespace ||
                                     rule.kind == CssRuleKind.LayerStatement
                    if (!(lastWithoutBlock && isBlockless)) {
                        dest.writeStr("\n")
                    }
                }
                dest.newline()
            }

            rule.toCss(dest)

            lastWithoutBlock = rule.kind == CssRuleKind.Import ||
                              rule.kind == CssRuleKind.Namespace ||
                              rule.kind == CssRuleKind.LayerStatement
        }
    }

    /// 深拷贝
    public func deepClone(): CssRuleList {
        let cloned = ArrayList<CssRule>()
        for (r in v) {
            cloned.append(r.deepClone())
        }
        CssRuleList(cloned)
    }

    public func toString(): String {
        let printer = CssPrinter()
        toCss(printer)
        printer.getOutput()
    }
}

// ============================================================================
// 源码位置
// 严格翻译自: Location struct
// ============================================================================

/// CSS 源码位置
public class CssLocation {
    public var sourceIndex: Int64
    public var line: Int64
    public var column: Int64

    public init() {
        this.sourceIndex = 0
        this.line = 0
        this.column = 0
    }

    public init(sourceIndex: Int64, line: Int64, column: Int64) {
        this.sourceIndex = sourceIndex
        this.line = line
        this.column = column
    }
}

// ============================================================================
// 样式上下文
// 严格翻译自: rules/mod.rs StyleContext
// ============================================================================

/// 打印器的嵌套光标
/// 严格翻译自 StyleContext struct
public class CssStyleContext {
    public var selectors: ?CssSelectorListImpl
    public var parent: ?CssStyleContext

    public init() {
        this.selectors = None
        this.parent = None
    }
}
