// bao_css - CSS 规则模块入口
// 严格翻译自: bun/src/css/rules/mod.rs
//   对应: rules/rules.zig - CssRule, CssRuleList, MinifyContext, StyleContext
package bao_css.rules

import bao_core.*
import bao_collections.*
import bao_css.values.*
import bao_css.selectors.*

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
    public var declarations: ArrayList<CssProperty>
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
    public var vendorPrefix: CssVendorPrefix
    /// 源码位置
    public var loc: CssLocation

    public init(kind: CssRuleKind) {
        this.kind = kind
        this.selectors = None
        this.declarations = ArrayList<CssProperty>()
        this.rules = None
        this.importUrl = ""
        this.mediaQuery = ""
        this.supportsCondition = ""
        this.keyframesName = ""
        this.layerName = ""
        this.containerCondition = ""
        this.scopeCondition = ""
        this.vendorPrefix = CssVendorPrefix()
        this.loc = CssLocation()
    }

    /// 转为 CSS 文本
    /// 严格翻译自 CssRule::to_css
    public func toCss(dest: CssPrinter): Result<Unit> {
        match (kind) {
            case CssRuleKind.Style => {
                match (selectors) {
                    case Some(sels) => {
                        let r = dest.writeStr(sels.toCss())
                        match (r) {
                            case Ok(_) => {}
                            case Err(e) => return Result<Unit>.err(e)
                        }
                        // 声明块
                        dest.writeStr(" {")
                        dest.indent()
                        for (decl in declarations) {
                            dest.newline()
                            let r2 = dest.writeStr(decl.toCss(dest.minify))
                            match (r2) {
                                case Ok(_) => {}
                                case Err(e) => return Result<Unit>.err(e)
                            }
                            dest.writeStr(";")
                        }
                        dest.dedent()
                        dest.newline()
                        dest.writeStr("}")
                    }
                    case None => {}
                }
                Result<Unit>.ok(())
            }
            case CssRuleKind.Media => {
                dest.writeStr("@media ${mediaQuery}")
                match (rules) {
                    case Some(r) => {
                        dest.writeStr(" {")
                        dest.indent()
                        for (rule in r.v) {
                            dest.newline()
                            rule.toCss(dest)
                        }
                        dest.dedent()
                        dest.newline()
                        dest.writeStr("}")
                    }
                    case None => dest.writeStr(" {}")
                }
                Result<Unit>.ok(())
            }
            case CssRuleKind.Import => {
                dest.writeStr("@import ${importUrl};")
                Result<Unit>.ok(())
            }
            case CssRuleKind.Keyframes => {
                dest.writeStr("@keyframes ${keyframesName}")
                match (rules) {
                    case Some(r) => {
                        dest.writeStr(" {")
                        dest.indent()
                        for (rule in r.v) {
                            dest.newline()
                            rule.toCss(dest)
                        }
                        dest.dedent()
                        dest.newline()
                        dest.writeStr("}")
                    }
                    case None => dest.writeStr(" {}")
                }
                Result<Unit>.ok(())
            }
            case CssRuleKind.Supports => {
                dest.writeStr("@supports ${supportsCondition}")
                match (rules) {
                    case Some(r) => {
                        dest.writeStr(" {")
                        dest.indent()
                        for (rule in r.v) {
                            dest.newline()
                            rule.toCss(dest)
                        }
                        dest.dedent()
                        dest.newline()
                        dest.writeStr("}")
                    }
                    case None => dest.writeStr(" {}")
                }
                Result<Unit>.ok(())
            }
            case CssRuleKind.LayerStatement => {
                dest.writeStr("@layer ${layerName};")
                Result<Unit>.ok(())
            }
            case CssRuleKind.LayerBlock => {
                dest.writeStr("@layer ${layerName}")
                match (rules) {
                    case Some(r) => {
                        dest.writeStr(" {")
                        dest.indent()
                        for (rule in r.v) {
                            dest.newline()
                            rule.toCss(dest)
                        }
                        dest.dedent()
                        dest.newline()
                        dest.writeStr("}")
                    }
                    case None => dest.writeStr(" {}")
                }
                Result<Unit>.ok(())
            }
            case CssRuleKind.Container => {
                dest.writeStr("@container ${containerCondition}")
                match (rules) {
                    case Some(r) => {
                        dest.writeStr(" {")
                        dest.indent()
                        for (rule in r.v) {
                            dest.newline()
                            rule.toCss(dest)
                        }
                        dest.dedent()
                        dest.newline()
                        dest.writeStr("}")
                    }
                    case None => dest.writeStr(" {}")
                }
                Result<Unit>.ok(())
            }
            case CssRuleKind.Scope => {
                dest.writeStr("@scope ${scopeCondition}")
                match (rules) {
                    case Some(r) => {
                        dest.writeStr(" {")
                        dest.indent()
                        for (rule in r.v) {
                            dest.newline()
                            rule.toCss(dest)
                        }
                        dest.dedent()
                        dest.newline()
                        dest.writeStr("}")
                    }
                    case None => dest.writeStr(" {}")
                }
                Result<Unit>.ok(())
            }
            case CssRuleKind.FontFace => {
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
                Result<Unit>.ok(())
            }
            case CssRuleKind.Namespace => {
                dest.writeStr("@namespace ${importUrl};")
                Result<Unit>.ok(())
            }
            case CssRuleKind.Ignored => Result<Unit>.ok(())
            case _ => {
                // Unknown / Custom / 其他
                Result<Unit>.ok(())
            }
        }
    }

    /// 深拷贝
    public func deepClone(): CssRule {
        let r = CssRule(kind)
        r.selectors = match (selectors) { case Some(s) => Some(s.deepClone()) case None => None }
        r.rules = match (rules) { case Some(rl) => Some(rl.deepClone()) case None => None }
        let decls = ArrayList<CssProperty>()
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
        let sb = StringBuilder()
        let printer = CssPrinter(sb)
        toCss(printer)
        sb.toString()
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
    public func toCss(dest: CssPrinter): Result<Unit> {
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
                if (!dest.minify) {
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
        Result<Unit>.ok(())
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
        let sb = StringBuilder()
        let printer = CssPrinter(sb)
        toCss(printer)
        sb.toString()
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
