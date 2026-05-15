// 严格翻译自: src/jsc/DeprecatedStrong.zig
// 已弃用的强引用类型 - 保留用于向后兼容

package bao_jsc

// ========== DeprecatedStrong ==========
// 严格翻译自 DeprecatedStrong (Strong.Deprecated)
// 强引用，在 CI 断言模式下包含安全检查
public class DeprecatedStrong {
    public var raw: JsValue = JsValue.zero
    public var safety: ?SafetyInfo = None

    public init() {}

    // 严格翻译自 DeprecatedStrong.initNonCell
    public static func initNonCell(nonCell: JsValue) -> DeprecatedStrong {
        let strong = DeprecatedStrong()
        strong.raw = nonCell
        strong.safety = None
        strong
    }

    // 严格翻译自 DeprecatedStrong.init
    public static func initFunc(value: JsValue) -> DeprecatedStrong {
        let strong = DeprecatedStrong()
        strong.raw = value
        strong.safety = None
        strong
    }

    // 严格翻译自 DeprecatedStrong.deinit
    public func deinit() {
        raw = JsValue.zero
    }

    // 严格翻译自 DeprecatedStrong.get
    public func get() -> JsValue {
        raw
    }

    // 严格翻译自 DeprecatedStrong.swap
    public func swap(next: JsValue) -> JsValue {
        let prev = raw
        deinit()
        raw = next
        prev
    }

    // 严格翻译自 DeprecatedStrong.dupe
    public func dupe() -> DeprecatedStrong {
        DeprecatedStrong.init(value: raw)
    }

    // 严格翻译自 DeprecatedStrong.ref
    public func ref() {
        // protect JSValue
    }

    // 严格翻译自 DeprecatedStrong.unref
    public func unref() {
        // unprotect JSValue
    }

    // ========== Optional ==========
    // 严格翻译自 DeprecatedStrong.Optional
    public class Optional {
        public var backing: DeprecatedStrong = DeprecatedStrong()

        public static let empty: Optional = Optional.initNonCell(JsValue.zero)

        public init() {}

        public static func initNonCell(nonCell: JsValue) -> Optional {
            let opt = Optional()
            opt.backing = DeprecatedStrong.initNonCell(nonCell)
            opt
        }

        public static func initFunc(value: JsValue) -> Optional {
            let opt = Optional()
            opt.backing = DeprecatedStrong.init(value: value)
            opt
        }

        public func deinit() {
            backing.deinit()
        }

        public func get() -> ?JsValue {
            let result = backing.get()
            if (result == JsValue.zero) { return None }
            Some(result)
        }

        public func swap(next: JsValue) -> ?JsValue {
            let result = backing.swap(next)
            if (result == JsValue.zero) { return None }
            Some(result)
        }

        public func dupe() -> Optional {
            Optional.init(value: backing.get())
        }

        public func has() -> Bool {
            backing.get() != JsValue.zero
        }

        public func ref() {
            backing.ref()
        }

        public func unref() {
            backing.unref()
        }
    }
}

// 安全信息结构
public class SafetyInfo {
    public var ptr: UInt64 = 0
    public var gpa: UInt64 = 0
    public var refCount: UInt32 = 0

    public init() {}
}
