// bao_unicode - uucode wcwidth 扩展配置
// 严格翻译自: src/unicode/uucode_lib/src/x/config_x/wcwidth.zig
//   计算 wcwidth_standalone 和 wcwidth_zero_in_grapheme
//   基于多种 Unicode 属性: general_category, east_asian_width, grapheme_break 等
//   仓颉实现提供等价的 wcwidth 配置
package bao_unicode.uucode_lib.x.config_x

// wcwidth 扩展的 compute 函数
// 严格翻译自: fn compute(allocator, cp, data, backing, tracking)
//   根据 general_category, is_default_ignorable, east_asian_width, grapheme_break 等
//   计算:
//     wcwidth_standalone: 码点单独显示的宽度 (0-3)
//     wcwidth_zero_in_grapheme: 在字素簇中是否零宽度
// 已在 x/root.cj 的 wcwidthStandalone() 和 wcwidthZeroInGrapheme() 函数中实现
