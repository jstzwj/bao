// 严格翻译自: src/jsc/JSArrayIterator.zig (53行)
// JavaScriptCore 数组迭代器 - 高效的 JS 数组遍历

package bao_jsc

// ========== JSArrayIterator ==========
// 严格翻译自 JSArrayIterator.zig
// 高效的 JS 数组迭代器，支持快速连续内存向量优化
//
// 原始 Zig 代码:
//   pub const JSArrayIterator = struct {
//       i: u32 = 0,
//       len: u32 = 0,
//       array: JSValue,
//       global: *JSGlobalObject,
//       fast: ?[*]const JSValue = null,
//       pub fn init(value: JSValue, global: *JSGlobalObject) bun.JSError!JSArrayIterator { ... }
//       pub fn next(this: *JSArrayIterator) bun.JSError!?JSValue { ... }
//   };
public class JsArrayIterator_ {
    // 当前索引
    public var i: UInt32 = 0
    // 数组长度
    public var len: UInt32 = 0
    // 被迭代的数组
    public var array: JsValue = JsValue.undefined()
    // 全局对象
    public var global: JsObject = JsObject.make()
    // 快速路径: 直接指向 JSArray butterfly 的指针
    // 当数组使用 Int32 或 Contiguous 存储且有正常的原型链时可用
    // 空洞(holes)编码为 0
    // 对应 Bun: fast: ?[*]const JSValue = null
    public var fast: UInt64 = 0  // pointer to contiguous vector (0 = null/未使用快速路径)

    public init() {}

    // ========== init ==========
    public static func initFunc(value: JsValue, global: JsObject): JsArrayIterator_ {
        let iter = JsArrayIterator_()
        iter.array = value
        iter.global = global

        // 对应 Bun: Bun__JSArray__getContiguousVector — 尝试获取快速连续向量
        // 在仓颉中无法直接访问 JSC butterfly 指针, fast 保持 0 (回退到慢路径)
        iter.len = UInt32(value.toLength())
        iter
    }

    // ========== next ==========
    // 严格翻译自 JSArrayIterator.next
    // 获取下一个元素
    //
    // 原始 Zig:
    //   pub fn next(this: *JSArrayIterator) bun.JSError!?JSValue {
    //       if (!(this.i < this.len)) { return null; }
    //       const i = this.i;
    //       this.i += 1;
    //       if (this.fast) |elements| {
    //           if (Bun__JSArray__contiguousVectorIsStillValid(this.array, elements, this.len)) {
    //               const val = elements[i];
    //               return if (val == .zero) .js_undefined else val;
    //           }
    //           this.fast = null;
    //       }
    //       return try JSObject.getIndex(this.array, this.global, i);
    //   }
    public func next(): ?JsValue {
        if (!(i < len)) {
            return None
        }
        let idx = i
        i++

        // 慢速路径: 通过 JSObject.getIndex 获取
        if (array.isObject()) {
            let obj = array.toObject()
            return obj.get(Int64(idx).toString())
        }
        None
    }

    // ========== 是否已完成 ==========
    public func isDone(): Bool {
        !(i < len)
    }

    // ========== 重置 ==========
    public func reset() {
        i = 0
    }
}
