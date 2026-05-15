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
    public var fast: CPointer<JsValue> = CPointer<JsValue>()

    public init() {}

    // ========== init ==========
    // 严格翻译自 JSArrayIterator.init
    // 从 JSValue 和全局对象创建迭代器
    //
    // 原始 Zig:
    //   pub fn init(value: JSValue, global: *JSGlobalObject) bun.JSError!JSArrayIterator {
    //       var length: u32 = 0;
    //       if (Bun__JSArray__getContiguousVector(value, &length)) |elements| {
    //           return .{ .array = value, .global = global, .len = length, .fast = elements };
    //       }
    //       return .{ .array = value, .global = global, .len = @truncate(try value.getLength(global)) };
    //   }
    public static func initFunc(value: JsValue, global: JsObject) -> JsArrayIterator_ {
        let iter = JsArrayIterator_()
        iter.array = value
        iter.global = global

        // 尝试获取快速连续向量
        // FFI: Bun__JSArray__getContiguousVector(value, &length)
        var length: UInt32 = 0
        let fastPtr = getContiguousVectorFFI(value, length)
        if (fastPtr != CPointer<JsValue>()) {
            iter.fast = fastPtr
            iter.len = length
        } else {
            // 回退到 getLength
            iter.len = UInt32(value.toLength())
        }
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
    public func next() -> ?JsValue {
        if (!(i < len)) {
            return None
        }
        let idx = i
        i++

        // 快速路径: 使用连续向量
        if (fast != CPointer<JsValue>()) {
            // FFI: Bun__JSArray__contiguousVectorIsStillValid(array, fast, len)
            if (contiguousVectorIsStillValidFFI(array, fast, len)) {
                let val = fast[Int64(idx)]
                if (val == JsValue.undefined() || val.rawPtr == CPointer<UInt8>()) {
                    return JsValue.undefined()
                }
                return val
            }
            // 向量不再有效，清除快速指针
            fast = CPointer<JsValue>()
        }

        // 慢速路径: 通过 JSObject.getIndex 获取
        // FFI: JSObject.getIndex(array, global, idx)
        if (array.isObject()) {
            let obj = array.toObject()
            return obj.get(String(Int64(idx)))
        }
        None
    }

    // ========== 是否已完成 ==========
    public func isDone() -> Bool {
        !(i < len)
    }

    // ========== 重置 ==========
    public func reset() {
        i = 0
    }

    // ========== FFI 桩函数 ==========

    // FFI: Bun__JSArray__getContiguousVector(JSValue, *u32) ?[*]const JSValue
    // 获取数组的连续内存向量 (如果可用)
    private static func getContiguousVectorFFI(value: JsValue, length: UInt32) -> CPointer<JsValue> {
        // 真实实现: @extern "c" fn Bun__JSArray__getContiguousVector(...)
        CPointer<JsValue>()
    }

    // FFI: Bun__JSArray__contiguousVectorIsStillValid(JSValue, [*]const JSValue, u32) bool
    // 检查连续向量是否仍然有效 (数组结构未被修改)
    private func contiguousVectorIsStillValidFFI(
        value: JsValue,
        elements: CPointer<JsValue>,
        length: UInt32
    ) -> Bool {
        // 真实实现: @extern "c" fn Bun__JSArray__contiguousVectorIsStillValid(...)
        false
    }
}
