// bao_unicode - uucode grapheme_break_no_control 扩展配置
// 严格翻译自: src/unicode/uucode_lib/src/x/config_x/grapheme_break.zig
//   将 grapheme_break 中的 control/CR/LF 映射为 other
//   生成 grapheme_break_no_control 字段
//   仓颉实现提供等价的扩展配置
package bao_unicode.uucode_lib.x.config_x

// grapheme_break_no_control 扩展的 compute 函数
// 严格翻译自: fn compute(allocator, cp, data, backing, tracking)
//   data.grapheme_break_no_control = switch (data.grapheme_break) {
//     .control, .cr, .lf => .other,
//     inline else => |tag| ... @tagName(tag) ...
//   }
// 已在 x/root.cj 的 graphemeBreakNoControl() 函数中实现
