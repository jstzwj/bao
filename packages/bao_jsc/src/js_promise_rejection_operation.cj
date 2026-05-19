// 严格翻译自: src/jsc/JSPromiseRejectionOperation.zig
// Promise 拒绝操作枚举
// Bun 原始类型: enum(u32) { Reject = 0, Handle = 1 }

package bao_jsc

// ========== JSPromiseRejectionOperation ==========
// 严格翻译自 JSPromiseRejectionOperation
// 定义 Promise 拒绝的处理方式
// 对应 WebKit JSPromiseRejectionOperation
public enum JSPromiseRejectionOperation {
    | Reject
    | Handle
}
