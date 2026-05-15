// bao_css - CSS 未知 @规则
// 严格翻译自: bun/src/css/rules/unknown.rs
//   对应: rules/unknown.zig - UnknownAtRule
package bao.css

import bao_core.*
import bao_collections.*

// ============================================================================
// 未知 @规则
// 严格翻译自: rules/unknown.rs UnknownAtRule struct
// ============================================================================

/// CSS 未知 @规则
/// 严格翻译自 UnknownAtRule struct { name, prelude, block, loc }
/// 存储为原始 token
public class CssUnknownAtRuleFull {
    /// @规则名 (不含 @)
    public var name: String
    /// 前导内容
    public var prelude: String
    /// 块内容 (None 表示无块体，以分号结束)
    public var block: ?String
    /// 位置信息
    public var loc: CssLocation

    public init(name: String, prelude: String, block: ?String) {
        this.name = name
        this.prelude = prelude
        this.block = block
        this.loc = CssLocation()
    }

    /// 深拷贝
    /// 严格翻译自 UnknownAtRule.deep_clone
    public func deepClone(): CssUnknownAtRuleFull {
        CssUnknownAtRuleFull(name, prelude, block)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 UnknownAtRule.to_css
    public func toCss(indent: String): String {
        match (block) {
            case Some(blockContent) => {
                let sb = StringBuilder()
                sb.append("${indent}@${name}")
                if (prelude.length > 0) {
                    sb.append(" ${prelude}")
                }
                sb.append(" {\n")
                sb.append("${indent}  ${blockContent}\n")
                sb.append("${indent}}")
                return sb.toString()
            }
            case None => {
                let sb = StringBuilder()
                sb.append("${indent}@${name}")
                if (prelude.length > 0) {
                    sb.append(" ${prelude}")
                }
                sb.append(";")
                return sb.toString()
            }
        }
    }

    public func toString(): String {
        toCss("")
    }
}
