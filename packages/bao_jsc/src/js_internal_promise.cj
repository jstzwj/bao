// 严格翻译自: src/jsc/JSInternalPromise.zig (5行)
// JavaScriptCore InternalPromise - 已弃用，现在是 JSPromise 的透明别名

package bao_jsc

// ========== JSInternalPromise ==========
// 严格翻译自 JSInternalPromise.zig
// JSInternalPromise 已从 JavaScriptCore 上游移除
// 新的模块加载器在各处使用常规 JSPromise
// 保持此别名以便现有调用者继续编译
//
// 原始 Zig 代码:
//   pub const JSInternalPromise = @import("./JSPromise.zig").JSPromise;
public type JsInternalPromise = JsPromise
