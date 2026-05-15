// 严格翻译自: src/jsc/JSPromiseRejectionOperation.zig
// Promise 拒绝操作枚举

package bao_jsc

// ========== JSPromiseRejectionOperation ==========
// 严格翻译自 JSPromiseRejectionOperation
// 定义 Promise 拒绝的处理方式
public enum JSPromiseRejectionOperation: UInt32 {
    case Reject = 0
    case Handle = 1
}
