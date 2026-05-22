// 翻译自 Bun: src/runtime/bake/bake.bind.ts
// bake 绑定层导出的可变映射引用。

package bao_runtime.bake

import bao_jsc.*

/// 对应 TypeScript: export let derefMapping = null
/// JavaScript 运行时会在需要时用实际映射替换该值。
public var derefMapping: ?JsValue = None
