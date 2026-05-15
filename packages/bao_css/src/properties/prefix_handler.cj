// bao_css - CSS Properties: Prefix Handler
// 严格翻译自: bun/src/css/properties/prefix_handler.rs
//   对应: prefix_handler.zig - CSS 供应商前缀回退处理器
//   对应: FallbackHandler (color, text_shadow)
// ============================================================================

package bao_css.properties

import bao_core.*

// ============================================================================
// FallbackHandler
// 严格翻译自 FallbackHandler
// ============================================================================

/// 供应商前缀回退处理器
/// 严格翻译自 FallbackHandler
///
/// 处理需要颜色回退的属性（如 color、text-shadow），
/// 在目标浏览器不支持某些颜色语法时生成降级声明。
///
/// 注意：Handler 逻辑依赖未移植的基础设施（Parser、Printer、
/// PropertyHandlerContext 等），此处仅翻译数据类型定义。
public class FallbackHandler {
    public var color: Option<Int64>       // color 属性声明索引
    public var textShadow: Option<Int64>  // text-shadow 属性声明索引

    public init() {
        this.color = None
        this.textShadow = None
    }

    /// 重置所有字段
    public func finalize(): Unit {
        this.color = None
        this.textShadow = None
    }
}

// ============================================================================
// PREFIX_FLAGS
// 严格翻译自 PREFIX_FLAGS 常量
// ============================================================================

/// 供应商前缀标志列表（按声明顺序：webkit, moz, ms, o, none）
/// 严格翻译自 PREFIX_FLAGS
public func getPrefixFlags(): ArrayList<String> {
    var flags = ArrayList<String>()
    flags.append("-webkit-")
    flags.append("-moz-")
    flags.append("-ms-")
    flags.append("-o-")
    flags.append("")
    return flags
}
