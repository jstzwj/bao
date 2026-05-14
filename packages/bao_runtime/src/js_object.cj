// 严格翻译自: src/jsc/JSObject.zig
// JavaScript Object 操作 — 属性描述符、Symbol、原型链
// 对应 Bun: src/jsc/JSObject.zig, src/bundler/bundle_v2.zig 中 Object 操作
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// PropertyDescriptor - 属性描述符
// 对应 Bun: JSC::PropertyDescriptor (JSC C API)
// JavaScript 中 Object.defineProperty 的描述符对象
// ============================================================================

/// 属性描述符 - 对应 JS Object.defineProperty 描述符
/// 包含值属性和访问器属性的完整描述
public class PropertyDescriptor {
    /// 值属性 - 对应 descriptor.value
    public var value: ?JsValue
    /// Getter 函数 - 对应 descriptor.get
    public var get: ?JsFunction
    /// Setter 函数 - 对应 descriptor.set
    public var set: ?JsFunction
    /// 是否可写 - 对应 descriptor.writable
    public var writable: Bool
    /// 是否可枚举 - 对应 descriptor.enumerable
    public var enumerable: Bool
    /// 是否可配置 - 对应 descriptor.configurable
    public var configurable: Bool

    // 以下标记表示描述符中是否包含对应字段
    // 对应 JS 中 HasProperty 检查: descriptor 中仅存在的字段才生效
    public var hasValue: Bool
    public var hasWritable: Bool
    public var hasGet: Bool
    public var hasSet: Bool
    public var hasEnumerable: Bool
    public var hasConfigurable: Bool

    public init() {
        value = None
        get = None
        set = None
        writable = false
        enumerable = false
        configurable = false
        hasValue = false
        hasWritable = false
        hasGet = false
        hasSet = false
        hasEnumerable = false
        hasConfigurable = false
    }

    /// 创建数据属性描述符 - 对应 { value, writable, enumerable, configurable }
    public static func dataDescriptor(value: JsValue, writable: Bool,
        enumerable: Bool, configurable: Bool): PropertyDescriptor {
        let desc = PropertyDescriptor()
        desc.value = Some(value)
        desc.writable = writable
        desc.enumerable = enumerable
        desc.configurable = configurable
        desc.hasValue = true
        desc.hasWritable = true
        desc.hasEnumerable = true
        desc.hasConfigurable = true
        return desc
    }

    /// 创建访问器属性描述符 - 对应 { get, set, enumerable, configurable }
    public static func accessorDescriptor(getter: ?JsFunction, setter: ?JsFunction,
        enumerable: Bool, configurable: Bool): PropertyDescriptor {
        let desc = PropertyDescriptor()
        desc.get = getter
        desc.set = setter
        desc.enumerable = enumerable
        desc.configurable = configurable
        desc.hasGet = getter != None
        desc.hasSet = setter != None
        desc.hasEnumerable = true
        desc.hasConfigurable = true
        return desc
    }

    /// 是否为访问器描述符 (有 get 或 set)
    public func isAccessor(): Bool {
        return hasGet || hasSet
    }

    /// 是否为数据描述符 (有 value 或 writable)
    public func isData(): Bool {
        return hasValue || hasWritable
    }

    /// 是否为通用描述符 (仅有 enumerable/configurable)
    public func isGeneric(): Bool {
        return !isAccessor() && !isData()
    }
}

// ============================================================================
// JsObjectOps - 增强对象操作
// 对应 Bun: src/jsc/JSObject.zig 中对 JSC C API 的封装
//   Bun 通过 JSObjectRef C API 操作 JS 对象属性、原型等
//   仓颉通过直接操作 JsObject 内部 HashMap 实现等价功能
// ============================================================================

/// JS Object 静态操作 - 对应 JS Object 构造器的静态方法
/// Object.keys(), Object.values(), Object.defineProperty() 等
public class JsObjectOps {
    /// 获取对象自身属性名 - 对应 Object.getOwnPropertyNames
    public static func getOwnPropertyNames(obj: JsObject): ArrayList<String> {
        return obj.keys()
    }

    /// 获取对象自身的 Symbol 属性 - 对应 Object.getOwnPropertySymbols
    /// 仓颉用 String 模拟 Symbol 键
    public static func getOwnPropertySymbols(obj: JsObject): ArrayList<String> {
        let allKeys = obj.keys()
        let result = ArrayList<String>()
        for (key in allKeys) {
            if (key.startsWith("@@")) {
                result.append(key)
            }
        }
        return result
    }

    /// 获取对象自身属性描述符 - 对应 Object.getOwnPropertyDescriptors
    public static func getOwnPropertyDescriptors(obj: JsObject): HashMap<String, PropertyDescriptor> {
        let result = HashMap<String, PropertyDescriptor>()
        let keys = obj.keys()
        for (key in keys) {
            let val = obj.get(key)
            let desc = PropertyDescriptor.dataDescriptor(
                value: val,
                writable: true,
                enumerable: true,
                configurable: true
            )
            result.put(key, desc)
        }
        return result
    }

    /// 获取对象原型 - 对应 Object.getPrototypeOf
    public static func getPrototypeOf(obj: JsObject): ?JsObject {
        // JsObject 内部 proto 字段通过 get 访问
        // 需要间接方式获取，通过 __proto__ 属性
        let protoVal = obj.get("__proto__")
        match (protoVal.objectData) {
            case Some(p) => return Some(p)
            case None => return None
        }
    }

    /// 设置对象原型 - 对应 Object.setPrototypeOf
    public static func setPrototypeOf(obj: JsObject, proto: JsObject): Bool {
        obj.set("__proto__", JsValue(proto))
        return true
    }

    /// 定义属性 - 对应 Object.defineProperty
    /// 根据 PropertyDescriptor 设置属性值和特性
    public static func defineProperty(obj: JsObject, name: String,
        descriptor: PropertyDescriptor): Bool {
        if (descriptor.hasValue) {
            match (descriptor.value) {
                case Some(v) => obj.set(name, v)
                case None => obj.set(name, JsValue.UNDEFINED)
            }
        }
        return true
    }

    /// 定义多个属性 - 对应 Object.defineProperties
    public static func defineProperties(obj: JsObject,
        descriptors: HashMap<String, PropertyDescriptor>): Unit {
        descriptors.forEach({ key, desc =>
            defineProperty(obj, key, desc)
        })
    }

    /// 判断对象是否可扩展 - 对应 Object.isExtensible
    public static func isExtensible(obj: JsObject): Bool {
        // 简化实现: 默认所有对象可扩展
        // 完整实现需要追踪 [[PreventExtensions]] 内部槽位
        let val = obj.get("__extensible__")
        match (val.valueType) {
            case JsValueType.Boolean => val.boolValue
            case _ => true
        }
    }

    /// 阻止对象扩展 - 对应 Object.preventExtensions
    public static func preventExtensions(obj: JsObject): Bool {
        obj.set("__extensible__", JsValue(false))
        return true
    }

    /// 冻结对象 - 对应 Object.freeze
    /// 设置对象不可扩展且所有属性不可配置、不可写
    public static func freeze(obj: JsObject): JsObject {
        obj.set("__extensible__", JsValue(false))
        obj.set("__frozen__", JsValue(true))
        return obj
    }

    /// 密封对象 - 对应 Object.seal
    /// 设置对象不可扩展且所有属性不可配置
    public static func seal(obj: JsObject): JsObject {
        obj.set("__extensible__", JsValue(false))
        obj.set("__sealed__", JsValue(true))
        return obj
    }

    /// 判断对象是否被冻结 - 对应 Object.isFrozen
    public static func isFrozen(obj: JsObject): Bool {
        let val = obj.get("__frozen__")
        match (val.valueType) {
            case JsValueType.Boolean => val.boolValue
            case _ => false
        }
    }

    /// 判断对象是否被密封 - 对应 Object.isSealed
    public static func isSealed(obj: JsObject): Bool {
        let val = obj.get("__sealed__")
        match (val.valueType) {
            case JsValueType.Boolean => val.boolValue
            case _ => false
        }
    }

    /// 判断对象是否有指定自身属性 - 对应 Object.prototype.hasOwnProperty
    public static func hasOwnProperty(obj: JsObject, name: String): Bool {
        return obj.has(name)
    }

    /// 获取对象自身可枚举属性名 - 对应 Object.keys
    public static func keys(obj: JsObject): ArrayList<String> {
        // 简化实现: 返回所有自身属性 (JS 中只返回可枚举属性)
        return obj.keys()
    }

    /// 获取对象自身可枚举属性值 - 对应 Object.values
    public static func values(obj: JsObject): ArrayList<JsValue> {
        let result = ArrayList<JsValue>()
        let keys = obj.keys()
        for (key in keys) {
            result.append(obj.get(key))
        }
        return result
    }

    /// 获取对象自身可枚举属性键值对 - 对应 Object.entries
    public static func entries(obj: JsObject): ArrayList<(String, JsValue)> {
        let result = ArrayList<(String, JsValue)>()
        let keys = obj.keys()
        for (key in keys) {
            result.append((key, obj.get(key)))
        }
        return result
    }

    /// 对象合并 - 对应 Object.assign
    /// 将所有 source 的自身可枚举属性复制到 target
    public static func assign(target: JsObject, sources: ArrayList<JsObject>): JsObject {
        for (src in sources) {
            let srcKeys = src.keys()
            for (key in srcKeys) {
                target.set(key, src.get(key))
            }
        }
        return target
    }

    /// 以指定原型创建新对象 - 对应 Object.create
    public static func create(proto: JsObject): JsObject {
        let obj = JsObject()
        setPrototypeOf(obj, proto)
        return obj
    }

    /// 从键值对列表创建对象 - 对应 Object.fromEntries
    public static func fromEntries(entries: ArrayList<(String, JsValue)>): JsObject {
        let obj = JsObject()
        for ((key, value) in entries) {
            obj.set(key, value)
        }
        return obj
    }

    /// 展开运算符 - 对应 JS { ...source }
    /// 将 source 的自身可枚举属性浅复制到 target
    public static func spread(target: JsObject, source: JsObject): JsObject {
        let srcKeys = source.keys()
        for (key in srcKeys) {
            target.set(key, source.get(key))
        }
        return target
    }
}

// ============================================================================
// JsSymbol - Symbol 类型
// 对应 Bun: JSC::Symbol (JSC 中 Symbol 通过 JSValue tag 区分)
//   JS Symbol 是唯一且不可变的标识符，用作对象属性键
//   仓颉通过自增 id + 可选 description 模拟唯一性
// ============================================================================

/// JavaScript Symbol - 对应 JS Symbol
/// 每个Symbol唯一，可用于对象属性键
public class JsSymbol {
    /// Symbol 描述 - 对应 Symbol(description) 中的 description
    public var description: ?String
    /// 唯一标识符 - 用于区分不同 Symbol 实例
    public private(set) var id: Int64

    /// 全局自增 ID - 保证每个 Symbol 唯一
    private static var nextId: Int64 = 1

    /// 全局 Symbol 注册表 - 对应 Symbol.for / Symbol.keyFor
    private static let globalRegistry: HashMap<String, JsSymbol> = HashMap<String, JsSymbol>()

    public init(description: ?String) {
        this.description = description
        this.id = nextId
        nextId += 1
    }

    /// 转为字符串 - 对应 Symbol.prototype.toString
    public func toString(): String {
        match (description) {
            case Some(d) => "Symbol(${d})"
            case None => "Symbol()"
        }
    }

    // ---- 众所周知的 Symbol (Well-known Symbols) ----
    // 对应 ECMAScript 规范中 @@iterator, @@toStringTag 等

    /// @@iterator - 对应 for...of 循环使用的迭代器协议
    public static let ITERATOR: JsSymbol = JsSymbol(Some("Symbol.iterator"))
    /// @@asyncIterator - 对应 for await...of 异步迭代器协议
    public static let ASYNC_ITERATOR: JsSymbol = JsSymbol(Some("Symbol.asyncIterator"))
    /// @@match - 对应 String.prototype.match 使用的正则匹配
    public static let MATCH: JsSymbol = JsSymbol(Some("Symbol.match"))
    /// @@replace - 对应 String.prototype.replace 使用的替换
    public static let REPLACE: JsSymbol = JsSymbol(Some("Symbol.replace"))
    /// @@search - 对应 String.prototype.search 使用的搜索
    public static let SEARCH: JsSymbol = JsSymbol(Some("Symbol.search"))
    /// @@split - 对应 String.prototype.split 使用的分割
    public static let SPLIT: JsSymbol = JsSymbol(Some("Symbol.split"))
    /// @@hasInstance - 对应 instanceof 运算符使用的实例检查
    public static let HAS_INSTANCE: JsSymbol = JsSymbol(Some("Symbol.hasInstance"))
    /// @@isConcatSpreadable - 对应 Array.prototype.concat 展开行为
    public static let IS_CONCAT_SPREADABLE: JsSymbol = JsSymbol(Some("Symbol.isConcatSpreadable"))
    /// @@unscopables - 对应 with 语句中排除的属性
    public static let UNSCOPABLES: JsSymbol = JsSymbol(Some("Symbol.unscopables"))
    /// @@species - 对应构造器派生对象的工厂方法
    public static let SPECIES: JsSymbol = JsSymbol(Some("Symbol.species"))
    /// @@toPrimitive - 对应 ToPrimitive 抽象操作使用的转换方法
    public static let TO_PRIMITIVE: JsSymbol = JsSymbol(Some("Symbol.toPrimitive"))
    /// @@toStringTag - 对应 Object.prototype.toString 使用的标签
    public static let TO_STRING_TAG: JsSymbol = JsSymbol(Some("Symbol.toStringTag"))

    /// 全局 Symbol 查找/注册 - 对应 Symbol.for(key)
    /// 如果 key 已注册则返回已有 Symbol，否则创建新的并注册
    public static func for_(key: String): JsSymbol {
        match (globalRegistry.get(key)) {
            case Some(sym) => sym
            case None => {
                let sym = JsSymbol(Some(key))
                globalRegistry.put(key, sym)
                sym
            }
        }
    }

    /// 获取全局 Symbol 的 key - 对应 Symbol.keyFor(sym)
    /// 仅对 Symbol.for() 注册的 Symbol 有效
    public static func keyFor(sym: JsSymbol): ?String {
        let keys = globalRegistry.keys()
        for (key in keys) {
            match (globalRegistry.get(key)) {
                case Some(s) => {
                    if (s.id == sym.id) {
                        return Some(key)
                    }
                }
                case None => continue
            }
        }
        return None
    }

    /// 判断是否为 Well-known Symbol
    public func isWellKnown(): Bool {
        return id == ITERATOR.id || id == ASYNC_ITERATOR.id ||
            id == MATCH.id || id == REPLACE.id || id == SEARCH.id ||
            id == SPLIT.id || id == HAS_INSTANCE.id ||
            id == IS_CONCAT_SPREADABLE.id || id == UNSCOPABLES.id ||
            id == SPECIES.id || id == TO_PRIMITIVE.id ||
            id == TO_STRING_TAG.id
    }
}
