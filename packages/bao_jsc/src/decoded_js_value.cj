// 严格翻译自: src/jsc/DecodedJSValue.zig (50行)
// JavaScriptCore DecodedJSValue - ABI 兼容的 JS 值解码器

package bao_jsc

// ========== NotCellMask ==========
// 严格翻译自 FFI.zig NotCellMask
// 用于判断 JSValue 是否为 Cell (堆分配对象) 的掩码
// Cell 值的指针低位为 0，因此 (value & NotCellMask) == 0 表示是 Cell
public let NOT_CELL_MASK: UInt64 = 0xFFFF000000000000

// ========== EncodedValueDescriptor ==========
// 严格翻译自 DecodedJSValue.EncodedValueDescriptor
// ABI 兼容的编码值描述符
// 对应 JSC::EncodedValueDescriptor，是 NaN-boxing 编码的核心
public class EncodedValueDescriptor {
    // 作为 Int64 的编码值
    public var asInt64: Int64 = 0
    // 作为指针的值 (用于 Cell 类型)
    public var ptr: CPointer<UInt8> = CPointer<UInt8>()
    // asBits 视图
    public var payload: Int32 = 0
    public var tag: Int32 = 0

    public init() {}

    public init(asInt64: Int64) {
        this.asInt64 = asInt64
    }

    public init(ptr: CPointer<UInt8>) {
        this.ptr = ptr
    }

    public init(payload: Int32, tag: Int32) {
        this.payload = payload
        this.tag = tag
    }
}

// ========== DecodedJSValue ==========
// 严格翻译自 DecodedJSValue.zig
// ABI 兼容于 JSC::JSValue 的解码视图
// 用于将 NaN-boxing 编码的 JS 值解码为不同表示
public class DecodedJSValue {
    // 编码值描述符
    public var u: EncodedValueDescriptor = EncodedValueDescriptor()

    public init() {}

    public init(u: EncodedValueDescriptor) {
        this.u = u
    }

    // ========== 编码/解码 ==========

    // 严格翻译自 DecodedJSValue.encode
    // 等价于 JSC::JSValue::encode
    // 将解码后的值重新编码为 JsValue
    public func encode() -> JsValue {
        // 将 asInt64 编码为 JsValue
        let v = JsValue()
        v.rawPtr = u.ptr
        v
    }

    // ========== 类型检查 ==========

    // asU64 - 获取无符号 64 位视图
    func asU64() -> UInt64 {
        UInt64(u.asInt64)
    }

    // 严格翻译自 DecodedJSValue.isCell
    // 等价于 JSC::JSValue::isCell
    // 注意: 与 JSC 一样，此方法将 0 视为 Cell
    public func isCell() -> Bool {
        (asU64() & NOT_CELL_MASK) == 0
    }

    // 严格翻译自 DecodedJSValue.asCell
    // 等价于 JSC::JSValue::asCell
    // 断言是 Cell 后返回 Cell 指针
    public func asCell() -> ?CPointer<UInt8> {
        if (!isCell()) {
            return None
        }
        u.ptr
    }

    // ========== 位操作 ==========

    // 获取 payload 部分
    public func getPayload() -> Int32 {
        u.payload
    }

    // 获取 tag 部分
    public func getTag() -> Int32 {
        u.tag
    }

    // 设置 payload
    public func setPayload(p: Int32) {
        u.payload = p
    }

    // 设置 tag
    public func setTag(t: Int32) {
        u.tag = t
    }
}
