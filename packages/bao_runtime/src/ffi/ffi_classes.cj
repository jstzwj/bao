// FFI 类定义 — JS 绑定描述
// 对应 Bun: src/runtime/ffi/ffi.classes.ts
// 定义 FFI 对象在 JS 侧的类结构: 构造函数、原型方法、属性访问器
package bao_runtime.ffi

// ============================================================================
// FFI 类描述
// 对应 Bun: ffi.classes.ts — define({ name: "FFI", ... })
// ============================================================================

/// FFI JS 类定义
/// 对应 TypeScript: define({ name: "FFI", construct: true, noConstructor: true,
///   finalize: true, klass: {}, proto: { close: ..., symbols: ... } })
///
/// FFI 类不暴露构造函数给 JS 用户代码 (noConstructor: true)，
/// 通过 dlopen() / cc() / linkSymbols() 等工厂方法创建实例。
/// GC 终结器调用 FFI::finalize()。
public class FfiClassDefinition {
    /// 类名
    public static let CLASS_NAME: String = "FFI"

    /// 是否可构造 (construct: true 但 noConstructor: true)
    /// JS 用户代码不能 new FFI()，实例由 C++ 内部创建
    public static let CONSTRUCT: Bool = true

    /// 无公开构造函数
    public static let NO_CONSTRUCTOR: Bool = true

    /// GC 终结器 (finalize: true)
    public static let FINALIZE: Bool = true

    // ========================================================================
    // 静态方法 (klass: {})
    // ========================================================================

    /// FFI 类的静态方法列表
    /// 对应 TypeScript: klass: {}
    /// 注意: Bun 中 FFI 的静态方法 (如 dlopen, callback, cc) 不在 klass 中，
    /// 而是通过 FFIObject.zig 的 toJS() 创建为普通函数属性
    public static let STATIC_METHODS: ArrayList<FfiMethodDef> = {
        let list = ArrayList<FfiMethodDef>()
        // FFI 类无静态方法 — 所有方法通过 FFIObject.toJS() 以字段形式暴露
        return list
    }()

    // ========================================================================
    // 原型方法 (proto: { close, symbols })
    // ========================================================================

    /// FFI 实例的原型方法
    /// 对应 TypeScript: proto: { close: { fn: "close", length: 0 },
    ///   symbols: { cache: "symbolsValue", getter: "getSymbols" } }
    public static let PROTOTYPE_METHODS: ArrayList<FfiPrototypeMethodDef> = {
        let list = ArrayList<FfiPrototypeMethodDef>()

        // close() — 关闭 FFI 实例, 释放动态库
        // 对应 TypeScript: close: { fn: "close", length: 0 }
        list.append(FfiPrototypeMethodDef(
            name: "close",
            functionName: "close",
            argumentCount: 0
        ))

        return list
    }()

    /// FFI 实例的原型属性访问器
    /// 对应 TypeScript: proto: { symbols: { cache: "symbolsValue", getter: "getSymbols" } }
    public static let PROTOTYPE_PROPERTIES: ArrayList<FfiPrototypePropertyDef> = {
        let list = ArrayList<FfiPrototypePropertyDef>()

        // symbols — 已加载符号的缓存 getter
        // cache: "symbolsValue" — 使用 symbolsValue 属性缓存结果
        // getter: "getSymbols" — 首次访问时调用 getSymbols()
        list.append(FfiPrototypePropertyDef(
            name: "symbols",
            cachePropertyName: "symbolsValue",
            getterFunctionName: "getSymbols"
        ))

        return list
    }()

    // ========================================================================
    // 内部缓存值 (values: ["symbolsValue"])
    // ========================================================================

    /// FFI 实例的内部缓存值属性名列表
    /// 对应 TypeScript: values: ["symbolsValue"]
    /// symbolsValue 用于缓存 symbols getter 的返回值
    public static let CACHED_VALUES: ArrayList<String> = {
        let list = ArrayList<String>()
        list.append("symbolsValue")
        return list
    }()
}

// ============================================================================
// FFI 方法定义辅助类型
// ============================================================================

/// FFI 原型方法定义
/// 对应 TypeScript: proto 中的每个方法描述
public class FfiPrototypeMethodDef {
    /// 方法名 (JS 侧可见)
    public var name: String
    /// 对应的 Cangjie 函数名
    public var functionName: String
    /// 参数数量
    public var argumentCount: Int64

    public init(name: String, functionName: String, argumentCount: Int64) {
        this.name = name
        this.functionName = functionName
        this.argumentCount = argumentCount
    }
}

/// FFI 原型属性定义 (getter + cache)
/// 对应 TypeScript: proto 中的 getter/cache 描述
public class FfiPrototypePropertyDef {
    /// 属性名 (JS 侧可见)
    public var name: String
    /// 缓存属性名 (如 "symbolsValue")
    public var cachePropertyName: String
    /// Getter 函数名 (如 "getSymbols")
    public var getterFunctionName: String

    public init(name: String, cachePropertyName: String, getterFunctionName: String) {
        this.name = name
        this.cachePropertyName = cachePropertyName
        this.getterFunctionName = getterFunctionName
    }
}

/// FFI 静态方法定义 (当前为空, 预留扩展)
public class FfiMethodDef {
    /// 方法名
    public var name: String
    /// 函数名
    public var functionName: String
    /// 参数数量
    public var argumentCount: Int64

    public init(name: String, functionName: String, argumentCount: Int64) {
        this.name = name
        this.functionName = functionName
        this.argumentCount = argumentCount
    }
}
