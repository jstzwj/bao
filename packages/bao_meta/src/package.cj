// bao_meta - 类型元编程工具
// 严格翻译自: bun/src/meta/ (meta.zig + bits.zig + traits.zig + tagged_union.zig, ~759行)
//   编译时类型反射、类型特征、位域操作、标签联合
//
// 模块拆分:
//   traits.cj         - 类型特征工具集 (翻译自 traits.zig)
//   bits.cj            - 位域操作工具 (翻译自 bits.zig)
//   tagged_union.cj    - 标签联合辅助 (翻译自 tagged_union.zig)
//   meta.cj            - 类型元编程核心 (翻译自 meta.zig)
package bao_meta

// 重导出所有子模块
// 对应 Zig meta.zig:
//   pub const TaggedUnion = @import("./tagged_union.zig").TaggedUnion;
