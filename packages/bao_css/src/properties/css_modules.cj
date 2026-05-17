// bao_css - CSS Properties: CSS Modules
// 严格翻译自: bun/src/css/properties/css_modules.rs
//   对应: css_modules.zig - CSS Modules 支持
//   对应: Composes, Specifier
// ============================================================================

package bao_css.properties

import bao_core.*
import bao_collections.*

// ============================================================================
// Composes
// 严格翻译自 Composes
// ============================================================================

/// CSS Modules composes 属性值
/// 严格翻译自 Composes
public class Composes {
    public var names: ArrayList<String>  // 要组合的类名列表
    public var from: Option<Specifier>   // 类名来源

    public init(names: ArrayList<String>, from: Option<Specifier>) {
        this.names = names
        this.from = from
    }

    public func toCss(): String {
        var nameArr = Array<String>(names.size, repeat: "")
        var ni: Int64 = 0
        for (n in names) { nameArr[ni] = n; ni += 1 }
        var result = String.join(nameArr, delimiter: " ")
        match (from) {
            case Some(f) => result = result + " from " + f.toCss()
            case None => ()
        }
        return result
    }
}

// ============================================================================
// Specifier
// 严格翻译自 Specifier
// ============================================================================

/// composes 属性中引用类名的来源
/// 严格翻译自 Specifier
public enum Specifier {
    | Global                     // 全局引用
    | ImportRecordIndex(UInt32)  // 导入记录索引

    public func toCss(): String {
        match (this) {
            case Global => "global"
            case ImportRecordIndex(_) => ""  // 需要上下文才能解析 URL
        }
    }
}
