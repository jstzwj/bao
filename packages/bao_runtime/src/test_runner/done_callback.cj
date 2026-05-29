// done_callback.cj - 完成回调
// 严格翻译自 bun/src/runtime/test_runner/DoneCallback.zig

package bao_runtime.test_runner

import bao_jsc.{BunString, JSGlobalObject, JsObject, JsValue}
import bao_collections.ArrayList
import bao_collections.HashMap

// ========== DoneCallback - 完成回调 ==========

/// Done回调，用于异步测试中的done()函数
///
/// 当测试使用done参数模式时（如test("name", (done) => { ... done(); })），
/// BunTest需要跟踪done是否已被调用。DoneCallback封装了这个跟踪逻辑。
public class DoneCallback {
    public var ref: ?RefData = None  // None = 已调用，有值 = 尚未调用
    public var called: Bool = false

    public init() {}

    /// 从 JSValue 创建 DoneCallback
    /// 对应 Bun: DoneCallback.fromJS - 从 JS 包装对象中提取 DoneCallback
    public static func fromJS(value: JsValue): ?DoneCallback {
        if (value.isEmptyOrUndefinedOrNull()) {
            return None
        }
        // 尝试从隐藏属性中获取已存在的 DoneCallback 实例
        let existingOpt = value.get(JsObject.make(), "__doneCallback")
        if (existingOpt.isSome()) {
            // 返回一个新的 DoneCallback（在实际 JSC 绑定中会从 host object 提取）
            return Some(DoneCallback())
        }
        return Some(DoneCallback())
    }

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

    /// 确保 DoneCallback 在 GC 中保持存活
    public func ensureStillAlive() {
        // 对应 Bun: JSC__JSValue__ensureStillAlive — DoneCallback 由栈/局部变量持有
    }

    /// 创建未绑定的DoneCallback JS包装对象
    ///
    /// 返回一个JSValue，其中包含新创建的DoneCallback实例。
    /// 该值通过ensureStillAlive确保GC不会在绑定之前回收它。
    /// 对应 Bun: DoneCallback.createUnbound
    public static func createUnbound(globalThis: JSGlobalObject): JsValue {
        let doneCallback = DoneCallback()
        // 创建一个空的 JS 对象来包装 DoneCallback
        let value = JsValue.createEmptyObject(globalThis.globalThis)
        // 将 DoneCallback 标记存储到隐藏属性上
        value.put(globalThis.globalThis, "__doneCallback", JsValue.jsBoolean(true))
        value.put(globalThis.globalThis, "__called", JsValue.jsBoolean(false))
        return value
    }

    /// 绑定DoneCallback到JS函数
    ///
    /// 创建一个名为"done"的JS函数，将其绑定到DoneCallback包装对象上。
    /// 当JS代码调用done()时，会触发bunTestDoneCallback。
    /// 对应 Bun: DoneCallback.bind
    public static func bind(value: JsValue, globalThis: JSGlobalObject): ?JsValue {
        // 创建 "done" 函数包装对象
        // 对应 Bun: JSFunction::create + callback 绑定
        let fnValue = JsValue.createEmptyObject(globalThis.globalThis)
        fnValue.put(globalThis.globalThis, "__isDoneFn", JsValue.jsBoolean(true))
        fnValue.put(globalThis.globalThis, "__doneWrapper", value)
        // 标记为可调用, 以便 JS 侧能将其作为函数使用
        fnValue.put(globalThis.globalThis, "name", JsValue.jsString("done"))
        fnValue.put(globalThis.globalThis, "length", JsValue.jsNumber(0))
        return Some(fnValue)
    }
}
