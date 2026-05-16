// done_callback.cj - 完成回调
// 严格翻译自 bun/src/runtime/test_runner/DoneCallback.zig

package bao_runtime.test_runner

import bao_jsc.*
import std.collection.*

// ========== DoneCallback - 完成回调 ==========

/// Done回调，用于异步测试中的done()函数
///
/// 当测试使用done参数模式时（如test("name", (done) => { ... done(); })），
/// BunTest需要跟踪done是否已被调用。DoneCallback封装了这个跟踪逻辑。
public class DoneCallback {
    public var ref: ?RefData = None  // None = 已调用，有值 = 尚未调用
    public var called: Bool = false

    public init() {}

    /// 最终化 - 在GC回收时调用
    ///
    /// 递减RefData的引用计数。如果RefDataPtr还有效，需要显式递减
    /// 因为RefPtr没有自动Drop实现。
    public func finalize() {
        if (let Some(r) <- ref) {
            r.deref()
            ref = None
        }
    }

    /// 创建未绑定的DoneCallback JS包装对象
    ///
    /// 返回一个JSValue，其中包含新创建的DoneCallback实例。
    /// 该值通过ensureStillAlive确保GC不会在绑定之前回收它。
    public static func createUnbound(globalThis: JSGlobalObject): JSValue {
        let doneCallback = DoneCallback()
        // 将DoneCallback实例转换为JSValue包装
        let value = doneCallback.toJS(global: globalThis)
        value.ensureStillAlive()
        return value
    }

    /// 绑定DoneCallback到JS函数
    ///
    /// 创建一个名为"done"的JS函数，将其绑定到DoneCallback包装对象上。
    /// 当JS代码调用done()时，会触发bunTestDoneCallback。
    public static func bind(value: JSValue, globalThis: JSGlobalObject): ?JSValue {
        let callFn = JSFunction.create(globalThis, "done", BunTest.bunTestDoneCallback, 1)
        return callFn.bind(globalThis, value, BunString.staticStr("done"), 1.0)
    }
}
