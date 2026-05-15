// 严格翻译自: src/jsc/RefString.zig
// 引用计数字符串 - 用于大字符串（如源代码）的昂贵堆分配

package bao_jsc

// ========== RefString ==========
// 严格翻译自 RefString
// 昂贵的堆引用计数字符串类型
// 只用于大字符串（如源代码），不用于小字符串
public class RefString {
    public var ptr: Array<Byte> = []
    public var len: Int64 = 0
    public var hash: UInt32 = 0
    public var impl_: UInt64 = 0  // WTF.StringImpl native pointer
    public var allocator: UInt64 = 0  // std.mem.Allocator
    public var ctx: UInt64 = 0
    public var onBeforeDeinit: ?(UInt64, RefString) -> Void = None

    public init() {}

    // 严格翻译自 RefString.Hash
    public typealias Hash = UInt32

    // 严格翻译自 RefString.computeHash
    public static func computeHash(input: Array<Byte>) -> UInt32 {
        XxHash32.hash(0, input)
    }

    // 严格翻译自 RefString.toJS
    public func toJS(global: JsObject) -> JsValue {
        // FFI: bun.String.init(this.impl).toJS(global)
        JsValue.undefined()
    }

    // 严格翻译自 RefString.slice
    public func slice() -> Array<Byte> {
        ref()
        ptr
    }

    // 严格翻译自 RefString.ref
    public func ref() {
        // impl.ref()
    }

    // 严格翻译自 RefString.leak
    public func leak() -> Array<Byte> {
        ptr
    }

    // 严格翻译自 RefString.deref
    public func deref() {
        // impl.deref()
    }

    // 严格翻译自 RefString.deinit
    public func deinit() {
        if let callback = onBeforeDeinit {
            callback(ctx, self)
        }
        ptr = []
    }
}

// 支撑类型
public class XxHash32 {
    public static func hash(_ seed: UInt32, _ data: Array<Byte>) -> UInt32 {
        0  // placeholder
    }
}
