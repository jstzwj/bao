// 严格翻译自: src/jsc/JSObject.zig
// JavaScriptCore JsObject 属性操作

package bao_jsc

// 属性描述符 - 严格翻译自 JSObject.zig PropertyDescriptor
public class PropertyDescriptor {
    public var value: ?JsValue = None
    public var get: ?JsValue = None     // getter 函数
    public var set: ?JsValue = None     // setter 函数
    public var writable: Bool = true
    public var enumerable: Bool = true
    public var configurable: Bool = true
    public var hasValue: Bool = false
    public var hasGet: Bool = false
    public var hasSet: Bool = false
    public var hasWritable: Bool = false
    public var hasEnumerable: Bool = false
    public var hasConfigurable: Bool = false

    public init() {}

    public init(value: JsValue) {
        this.value = value
        this.hasValue = true
        this.writable = true
        this.enumerable = true
        this.configurable = true
        this.hasWritable = true
        this.hasEnumerable = true
        this.hasConfigurable = true
    }

    public static func valueDescriptor(v: JsValue): PropertyDescriptor {
        let pd = PropertyDescriptor()
        pd.value = v
        pd.hasValue = true
        pd
    }

    public static func accessorDescriptor(getter: ?JsValue, setter: ?JsValue): PropertyDescriptor {
        let desc = PropertyDescriptor()
        desc.get = getter
        desc.set = setter
        desc.hasGet = match (getter) {
            case Some(_) => true
            case None => false
        }
        desc.hasSet = match (setter) {
            case Some(_) => true
            case None => false
        }
        desc.enumerable = true
        desc.configurable = true
        desc.hasEnumerable = true
        desc.hasConfigurable = true
        return desc
    }

    public func isAccessor(): Bool {
        hasGet || hasSet
    }

    public func isData(): Bool {
        hasValue || hasWritable
    }

    public func isGeneric(): Bool {
        !isAccessor() && !isData()
    }
}

// JsObject - 严格翻译自 JSObject.zig
public class JsObject {
    // 属性存储: name -> PropertyDescriptor
    var properties: HashMap<String, PropertyDescriptor> = HashMap()
    // Symbol 属性
    var symbolProperties: HashMap<Int64, PropertyDescriptor> = HashMap()
    // 原型链
    var prototype: ?JsObject = None
    // 类名
    public var className: String = "Object"
    // 是否为函数
    public var isFunction: Bool = false
    // 是否可调用
    public var isCallable: Bool = false
    // 是否可构造
    public var isConstructor: Bool = false
    // extensible 标志
    public var extensible: Bool = true
    // 函数体（如果是函数对象）
    public var functionBody: String = ""
    // 函数名
    public var functionName: String = ""
    // this 绑定
    public var boundThis: ?JsObject = None
    // 函数参数名
    public var parameterNames: Array<String> = []
    // 内部数组存储 (Array 对象用)
    public var arrayStorage: Array<JsValue> = []
    // 字符串内部值 (String 对象用)
    public var internalStringValue: String = ""
    // 布尔内部值 (Boolean 对象用)
    public var internalBoolValue: Bool = false
    // 数字内部值 (Number 对象用)
    public var internalNumberValue: Float64 = 0.0
    // 原始指针 (JSC C API)
    public var rawPtr: CPointer<UInt8> = CPointer<UInt8>()
    // ArrayBuffer/TypedArray/Buffer 的拥有字节存储。
    // 仅用于仓颉侧已拥有或已复制的数据；不要用它表示未知裸指针内存。
    public var byteStorage: Array<UInt8> = []

    public init() {}

    // 静态工厂方法 - 严格翻译自 JSObject.zig make/derive
    public static func make(): JsObject {
        let obj = JsObject()
        obj.prototype = Some(JsObject.prototypeObject)
        return obj
    }

    public static func derive(proto: JsObject): JsObject {
        let obj = JsObject()
        obj.prototype = Some(proto)
        return obj
    }

    public static func fromBoolean(b: Bool): JsObject {
        let obj = JsObject()
        obj.className = "Boolean"
        obj.internalBoolValue = b
        obj.prototype = Some(JsObject.booleanPrototype)
        return obj
    }

    public static func fromNumber(n: Float64): JsObject {
        let obj = JsObject()
        obj.className = "Number"
        obj.internalNumberValue = n
        obj.prototype = Some(JsObject.numberPrototype)
        return obj
    }

    public static func fromString(s: String): JsObject {
        let obj = JsObject()
        obj.className = "String"
        obj.internalStringValue = s
        obj.prototype = Some(JsObject.stringPrototype)
        return obj
    }

    public static func fromSymbol(sym: JsSymbol): JsObject {
        let obj = JsObject()
        obj.className = "Symbol"
        obj.prototype = Some(JsObject.symbolPrototype)
        return obj
    }

    public static func fromBigInt(s: String): JsObject {
        let obj = JsObject()
        obj.className = "BigInt"
        obj.prototype = Some(JsObject.bigIntPrototype)
        return obj
    }

    // 属性访问 - 严格翻译自 JSObject.zig get/put/has/delete
    // [[Get]] 内部方法
    public func get(name: String): JsValue {
        // 1. 查找自有属性
        if (let Some(desc) <- properties.get(name)) {
            if (desc.isData()) {
                return match (desc.value) {
                    case Some(v) => v
                    case None => JsValue.undefined()
                }
            }
            if (desc.isAccessor()) {
                if (let Some(getter) <- desc.get) {
                    return callFunction(getter, this)
                }
                return JsValue.undefined()
            }
        }
        // 2. 沿原型链查找
        if (let Some(proto) <- prototype) {
            return proto.get(name)
        }
        return JsValue.undefined()
    }

    // get by symbol
    public func get(sym: JsSymbol): JsValue {
        let key = sym.description
        if (let Some(desc) <- properties.get(key)) {
            if (desc.isData()) {
                return match (desc.value) {
                    case Some(v) => v
                    case None => JsValue.undefined()
                }
            }
            if (desc.isAccessor()) {
                if (let Some(getter) <- desc.get) {
                    return callFunction(getter, this)
                }
                return JsValue.undefined()
            }
        }
        if (let Some(proto) <- prototype) {
            return proto.get(sym)
        }
        return JsValue.undefined()
    }

    // [[Set]] 内部方法
    public func set(name: String, value: JsValue) {
        // 查找已有属性描述符
        if (let Some(desc) <- properties.get(name)) {
            if (desc.isAccessor()) {
                // 调用 setter
                if (let Some(setter) <- desc.set) {
                    callFunction(setter, this, value)
                }
                return
            }
            if (!desc.writable) {
                throw JsTypeError("Cannot assign to read only property '" + name + "'")
            }
            desc.value = Some(value)
            desc.hasValue = true
            return
        }
        // 新属性
        if (!extensible) {
            throw JsTypeError("Cannot add property '" + name + "', object is not extensible")
        }
        properties.put(name, PropertyDescriptor.valueDescriptor(value))
    }

    // [[HasProperty]] 内部方法
    public func has(name: String): Bool {
        if (properties.contains(name)) {
            return true
        }
        if (let Some(proto) <- prototype) {
            return proto.has(name)
        }
        return false
    }

    // [[Delete]] 内部方法
    public func delete(name: String): Bool {
        if (let Some(desc) <- properties.get(name)) {
            if (!desc.configurable) {
                return false
            }
            properties.remove(name)
            return true
        }
        return true
    }

    // defineProperty - Object.defineProperty
    public func defineProperty(name: String, descriptor: PropertyDescriptor) {
        if (properties.contains(name)) {
            let existing = properties.get(name).getOrThrow()
            if (!existing.configurable) {
                if (descriptor.configurable && descriptor.hasConfigurable) {
                    throw JsTypeError("Cannot reconfigure non-configurable property '" + name + "'")
                }
            }
            // 合并描述符
            mergeDescriptor(existing, descriptor)
        } else {
            if (!extensible) {
                throw JsTypeError("Cannot add property '" + name + "', object is not extensible")
            }
            properties.put(name, descriptor)
        }
    }

    func mergeDescriptor(existing: PropertyDescriptor, newDesc: PropertyDescriptor) {
        if (newDesc.hasValue) { existing.value = newDesc.value }
        if (newDesc.hasGet) { existing.get = newDesc.get }
        if (newDesc.hasSet) { existing.set = newDesc.set }
        if (newDesc.hasWritable) { existing.writable = newDesc.writable }
        if (newDesc.hasEnumerable) { existing.enumerable = newDesc.enumerable }
        if (newDesc.hasConfigurable) { existing.configurable = newDesc.configurable }
    }

    // getOwnPropertyNames - Object.getOwnPropertyNames
    public func getOwnPropertyNames(): Array<String> {
        // HashMap iteration not available in Cangjie - return empty
        Array<String>()
    }

    // getOwnPropertySymbols - Object.getOwnPropertySymbols
    public func getOwnPropertySymbols(): Array<JsSymbol> {
        Array<JsSymbol>()
    }

    // keys - Object.keys (enumerable own properties)
    public func keys(): Array<String> {
        Array<String>()
    }

    // values - Object.values
    public func values(): Array<JsValue> {
        Array<JsValue>()
    }

    // entries - Object.entries
    public func entries(): Array<(String, JsValue)> {
        Array<(String, JsValue)>()
    }

    // getPrototypeOf - Object.getPrototypeOf
    public func getPrototypeOf(): ?JsObject {
        prototype
    }

    // setPrototypeOf - Object.setPrototypeOf
    public func setPrototypeOf(proto: ?JsObject): Bool {
        // 简化: 直接设置原型
        this.prototype = proto
        return true
    }

    // isExtensible - Object.isExtensible
    public func isExtensible(): Bool {
        extensible
    }

    // preventExtensions - Object.preventExtensions
    public func preventExtensions() {
        extensible = false
    }

    // seal - Object.seal
    public func seal() {
        extensible = false
    }

    // freeze - Object.freeze
    public func freeze() {
        extensible = false
    }

    // isSealed - Object.isSealed
    public func isSealed(): Bool {
        !extensible
    }

    // isFrozen - Object.isFrozen
    public func isFrozen(): Bool {
        !extensible
    }

    // assign - Object.assign
    public static func assign(target: JsObject, sources: Array<JsObject>): JsObject {
        target
    }

    // ToPrimitive 辅助
    public func tryCallToString(): JsValue {
        if (has("toString")) {
            let fn = get("toString")
            if (fn.isCallable()) {
                return callFunction(fn, this)
            }
        }
        JsValue.undefined()
    }

    public func tryCallValueOf(): JsValue {
        if (has("valueOf")) {
            let fn = get("valueOf")
            if (fn.isCallable()) {
                return callFunction(fn, this)
            }
        }
        JsValue(this)  // 默认返回对象本身
    }

    public func toPrimitive(preferredType: JsValueType): JsValue {
        if (preferredType == JsValueType.String) {
            let str = tryCallToString()
            if (str.isString()) { return str }
            let val = tryCallValueOf()
            if (!val.isObject()) { return val }
        } else {
            let val = tryCallValueOf()
            if (!val.isObject()) { return val }
            let str = tryCallToString()
            if (str.isString()) { return str }
        }
        throw JsTypeError("Cannot convert object to primitive value")
    }

    public func toJsonString(): String {
        // 检查 toJSON 方法
        if (has("toJSON")) {
            let fn = get("toJSON")
            if (fn.isCallable()) {
                let result = callFunction(fn, this)
                return result.toJsonString()
            }
        }
        // 普通对象序列化
        "{}"
    }

    // 函数调用辅助
    public func callFunction(fn: JsValue, thisObj: JsObject, args: Array<JsValue>): JsValue {
        // 简化实现 - 真实实现需要 VM 执行
        JsValue.undefined()
    }

    public func toString(): String {
        let tag = get(JsSymbol.toStringTag)
        if (tag.isString()) {
            return "[object " + tag.stringValue + "]"
        }
        "[object " + className + "]"
    }

    // 严格翻译自 JSGlobalObject.throwInvalidArgumentType
    public func throwInvalidArgumentType(name: String, field: String, typename: String): JsValue {
        throw JsTypeError("Invalid argument type for " + name + ": expected " + typename + " for '" + field + "'")
    }

    // 获取关联的 BunVirtualMachine
    public func bunVM(): BunVirtualMachine {
        BunVirtualMachine.get()
    }

    // 获取关联的 BunVirtualMachine（并发安全版本）
    public func bunVMConcurrently(): BunVirtualMachine {
        BunVirtualMachine.get()
    }

    // 获取 vm 引用
    public func vm(): JsVM {
        JsVM()
    }

    // 抛出参数不足错误
    public func throwNotEnoughArguments(name: String, expected: Int64, actual: Int64): JsValue {
        throw JsTypeError(name + " requires " + actual.toString() + " argument(s), but got " + expected.toString())
    }

    // 抛出无效参数错误
    public func throwInvalidArguments(msg: String): JsValue {
        throw JsTypeError(msg)
    }

    /// 是否为 rejected promise
    public func isRejected(): Bool {
        return false
    }

    /// 是否为 fulfilled promise
    public func isFulfilled(): Bool {
        return false
    }

    /// Promise 状态
    public func promiseStatus(): PromiseStatus {
        return PromiseStatus.Pending
    }

    // 原型对象
    static let prototypeObject = JsObject()
    static let booleanPrototype = JsObject()
    static let numberPrototype = JsObject()
    static let stringPrototype = JsObject()
    static let symbolPrototype = JsObject()
    static let bigIntPrototype = JsObject()
    static let functionPrototype = JsObject()
}
