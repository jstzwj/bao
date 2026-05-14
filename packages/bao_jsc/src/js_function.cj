// 严格翻译自: src/jsc/JSFunction.zig
// JavaScriptCore JsFunction 类型

package bao_jsc

// JS 函数回调类型
public type JsCallback = (JsObject, Array<JsValue>) -> JsValue

// JsFunction - 严格翻译自 JSFunction.zig
public class JsFunction {
    var name: String = ""
    var callback: ?JsCallback = None
    var length: Int64 = 0  // 参数数量
    var sourceCode: String = ""
    var isArrow: Bool = false
    var isGenerator: Bool = false
    var isAsync: Bool = false
    var isBound: Bool = false
    var boundThis: ?JsObject = None
    var boundArgs: Array<JsValue> = []
    var closure: JsObject = JsObject()  // 闭包环境
    var prototype: ?JsObject = None
    var homeObject: ?JsObject = None    // super 引用

    public init() {}

    public init(name: String, callback: JsCallback) {
        this.name = name
        this.callback = callback
    }

    public init(name: String, length: Int64, callback: JsCallback) {
        this.name = name
        this.length = length
        this.callback = callback
    }

    // 创建原生函数 - 严格翻译自 JSFunction.zig create/functionCreate
    public static func create(name: String, callback: JsCallback) -> JsFunction {
        let fn = JsFunction(name: name, callback: callback)
        fn.prototype = Some(JsObject.make())
        return fn
    }

    public static func create(name: String, length: Int64, callback: JsCallback) -> JsFunction {
        let fn = JsFunction(name: name, length: length, callback: callback)
        fn.prototype = Some(JsObject.make())
        return fn
    }

    // 从源码创建 - 编译函数
    public static func fromSource(name: String, params: Array<String>, body: String) -> JsFunction {
        let fn = JsFunction()
        fn.name = name
        fn.length = Int64(params.size)
        fn.sourceCode = params.join(",") + " => " + body
        fn.prototype = Some(JsObject.make())
        return fn
    }

    // 调用函数 - 严格翻译自 JSFunction.zig call
    public func call(thisArg: JsValue, args: Array<JsValue>) -> JsValue {
        let thisObj = resolveThis(thisArg)
        if (let Some(cb) <- callback) {
            return cb(thisObj, args)
        }
        // 源码函数需要 VM 执行
        JsValue.undefined()
    }

    // 构造调用 - 严格翻译自 JSFunction.zig construct
    public func construct(args: Array<JsValue>) -> JsObject {
        let newObj = JsObject.make()
        // 设置原型链
        if (let Some(proto) <- prototype) {
            newObj.prototype = Some(proto)
        }
        // 调用构造函数体
        if (let Some(cb) <- callback) {
            let result = cb(newObj, args)
            if (result.isObject()) {
                return result.toObject()
            }
        }
        return newObj
    }

    // 绑定 this - Function.prototype.bind
    public func bind(thisArg: JsValue, args: Array<JsValue>) -> JsFunction {
        let bound = JsFunction()
        bound.name = "bound " + name
        bound.isBound = true
        bound.boundThis = thisArg.toObject()
        bound.boundArgs = args
        bound.callback = callback
        bound.length = Math.max(0, this.length - Int64(args.size))
        bound.prototype = this.prototype
        return bound
    }

    // call - Function.prototype.call
    public func callWith(thisArg: JsValue, args: Array<JsValue>) -> JsValue {
        call(thisArg, args)
    }

    // apply - Function.prototype.apply
    public func apply(thisArg: JsValue, argsArray: JsValue) -> JsValue {
        let args: Array<JsValue>
        if (argsArray.isObject()) {
            let obj = argsArray.toObject()
            if (obj.className == "Array") {
                args = obj.arrayStorage
            } else {
                // array-like
                let len = obj.get("length").toLength()
                args = []
                for (i in 0..len) {
                    args.append(obj.get(String(i)))
                }
            }
        } else {
            args = []
        }
        call(thisArg, args)
    }

    // resolveThis - 严格翻译自 JSFunction.zig resolveThisBinding
    func resolveThis(thisArg: JsValue) -> JsObject {
        if (isBound) {
            return boundThis.getOr(JsObject.make())
        }
        if (isArrow) {
            // 箭头函数继承外层 this
            return closure
        }
        if (thisArg.isNull() || thisArg.isUndefined()) {
            // 非严格模式返回 globalThis
            return JsObject.make()
        }
        if (thisArg.isObject()) {
            return thisArg.toObject()
        }
        // 自动装箱
        thisArg.toObject()
    }

    // toString - Function.prototype.toString
    public func toString() -> String {
        if (!sourceCode.isEmpty) {
            return "function " + name + "(" + sourceCode + ")"
        }
        "function " + name + "() { [native code] }"
    }

    // Getter/Setter 工厂
    public static func getter(name: String, callback: JsCallback) -> JsFunction {
        let fn = JsFunction(name: "get " + name, callback: callback)
        return fn
    }

    public static func setter(name: String, callback: JsCallback) -> JsFunction {
        let fn = JsFunction(name: "set " + name, callback: callback)
        return fn
    }
}

// JsArguments - 函数参数对象
// 严格翻译自 JSC arguments 对象
public class JsArguments {
    var args: Array<JsValue> = []
    var callee: ?JsFunction = None
    var caller: ?JsFunction = None

    public init(args: Array<JsValue>) {
        this.args = args
    }

    public func get(index: Int64) -> JsValue {
        if (index >= 0 && index < args.size) {
            return args[Int64(index)]
        }
        JsValue.undefined()
    }

    public func set(index: Int64, value: JsValue) {
        if (index >= 0 && Int64(index) < args.size) {
            args[Int64(index)] = value
        }
    }

    public func length() -> Int64 {
        Int64(args.size)
    }

    public func toArray() -> Array<JsValue> {
        args
    }

    // Symbol.iterator
    public func iterator() -> Iterator<JsValue> {
        args.iterator()
    }

    // 转为 JsObject
    public func toObject() -> JsObject {
        let obj = JsObject.make()
        obj.className = "Arguments"
        obj.arrayStorage = args
        for (i in 0..args.size) {
            obj.set(String(i), args[i])
        }
        obj.set("length", JsValue(n: Int64(args.size)))
        return obj
    }
}

// ThisBinding - this 绑定类型
public enum ThisBindingType {
    | Global       // 全局对象
    | Strict       // 严格模式 (可能是 undefined)
    | Bound        // bind() 绑定
    | Arrow        // 箭头函数继承
    | With         // with 语句
}

public class ThisBinding {
    var bindingType: ThisBindingType = ThisBindingType.Global
    var value: JsObject = JsObject.make()

    public init(bindingType: ThisBindingType, value: JsObject) {
        this.bindingType = bindingType
        this.value = value
    }
}
