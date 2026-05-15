// 严格翻译自: src/css/values/values.zig
// CSS 值类型模块入口 (re-exports)
package bao.css

// ============================================================================
// values.zig 是 CSS 值类型的总入口
// 严格翻译自 values.zig 中的 re-exports
//
// 所有子模块:
//   angle       -> values/angle.cj / css_values_length.cj
//   ident       -> values/ident.cj
//   string      -> values/css_string.cj (内联在 css_values_color.cj)
//   color       -> values/color.cj
//   image       -> values/image.cj
//   number      -> values/number.zig (内联在 css_values_color.cj)
//   calc        -> values/calc.cj
//   percentage  -> values/percentage.zig (内联在 css_values_color.cj)
//   length      -> values/length.cj / css_values_length.cj
//   position    -> values/position.cj (内联在 remaining_values.cj)
//   syntax      -> values/syntax.cj (内联在 css_values_function.cj)
//   alpha       -> values/alpha.cj
//   ratio       -> values/ratio.cj (内联在 remaining_values.cj)
//   size        -> values/size.cj (内联在 remaining_values.cj)
//   rect        -> values/rect.cj (内联在 remaining_values.cj)
//   time        -> values/time.cj (内联在 remaining_values.cj)
//   easing      -> values/easing.cj
//   url         -> values/url.cj (内联在 css_values_function.cj)
//   resolution  -> values/resolution.cj (内联在 remaining_values.cj)
//   gradient    -> values/gradient.cj
// ============================================================================

/// CSS Modules composes 引用来源
/// 严格翻译自 values.zig css_modules.Specifier
public enum CssModulesSpecifier {
    | global                    // 全局名称
    | file(String)              // 来自指定文件
    | source_index(UInt32)      // 来自源索引 (打包时使用)
}
