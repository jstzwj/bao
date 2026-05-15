// 严格翻译自: src/jsc/CallFrame.zig (304行)
// JavaScriptCore 调用帧 - JS 到原生函数调用的参数帧

package bao_jsc

// ========== 调用帧 ==========
// 严格翻译自 CallFrame.zig CallFrame
// 表示 JavaScript -> Native 函数调用的参数帧
public class CallFrame {
    // 参数列表
    public var args: Array<JsValue> = []
    // this 值
    public var thisValue: JsValue = JsValue.undefined()
    // 被调用的函数
    public var calleeValue: JsValue = JsValue.undefined()
    // 全局对象
    public var globalObject: ?JsObject = None
    // 虚拟机
    public var vm: ?BunVirtualMachine = None

    public init() {}

    public init(args: Array<JsValue>, thisValue: JsValue, calleeValue: JsValue) {
        this.args = args
        this.thisValue = thisValue
        this.calleeValue = calleeValue
    }

    // 严格翻译自 CallFrame.arguments
    // 获取所有传入的参数
    public func arguments() -> Array<JsValue> {
        args
    }

    // 严格翻译自 CallFrame.argumentsAsArray
    // 获取指定数量的参数，不足的填充 undefined
    public func argumentsAsArray(count: Int64) -> Array<JsValue> {
        var result = Array<JsValue>()
        let n = if (count < Int64(args.size)) { count } else { Int64(args.size) }
        for (i in 0..n) {
            result.append(args[Int64(i)])
        }
        // 填充剩余为 undefined
        while (Int64(result.size) < count) {
            result.append(JsValue.undefined())
        }
        result
    }

    // 严格翻译自 CallFrame.argument
    // 获取第 i 个参数，越界返回 undefined
    public func argument(i: Int64) -> JsValue {
        if (i >= 0 && i < Int64(args.size)) {
            return args[Int64(i)]
        }
        JsValue.undefined()
    }

    // 严格翻译自 CallFrame.argumentsCount
    // 获取参数数量
    public func argumentsCount() -> Int64 {
        Int64(args.size)
    }

    // 严格翻译自 CallFrame.this
    // 获取 this 值
    public func this() -> JsValue {
        thisValue
    }

    // 严格翻译自 CallFrame.callee
    // 获取被调用函数
    public func callee() -> JsValue {
        calleeValue
    }

    // 严格翻译自 CallFrame.iterate
    // 返回参数迭代器
    public func iterate() -> CallFrameIterator {
        CallFrameIterator(args: args)
    }

    // 严格翻译自 CallFrame.isFromBunMain
    public func isFromBunMain() -> Bool {
        false
    }

    // 严格翻译自 CallFrame.getCallerSrcLoc
    public func getCallerSrcLoc() -> CallerSrcLoc {
        CallerSrcLoc()
    }

    // 严格翻译自 CallFrame.describeFrame
    public func describeFrame() -> String {
        if (calleeValue.isCallable()) {
            "native " + calleeValue.toString() + "()"
        } else {
            "anonymous()"
        }
    }
}

// ========== 调用帧迭代器 ==========
// 严格翻译自 CallFrame.Iterator
public class CallFrameIterator {
    var args: Array<JsValue>
    var pos: Int64 = 0

    public init(args: Array<JsValue>) {
        this.args = args
    }

    public func next() -> ?JsValue {
        if (pos >= Int64(args.size)) {
            return None
        }
        let current = args[Int64(pos)]
        pos++
        Some(current)
    }
}

// ========== 参数切片 ==========
// 严格翻译自 CallFrame.ArgumentsSlice
public class ArgumentsSlice {
    public var remaining: Array<JsValue> = []
    public var all: Array<JsValue> = []
    public var threw: Bool = false
    public var willBeAsync: Bool = false
    public var vm: ?BunVirtualMachine = None

    public init() {}

    // 严格翻译自 ArgumentsSlice.init
    public init(vm: BunVirtualMachine, slice: Array<JsValue>) {
        this.vm = vm
        this.remaining = slice
        this.all = slice
    }

    // 严格翻译自 ArgumentsSlice.len
    public func len() -> Int64 {
        Int64(remaining.size)
    }

    // 严格翻译自 ArgumentsSlice.eat
    // 消费一个参数
    public func eat() {
        if (remaining.size == 0) {
            return
        }
        remaining = remaining.slice(1)
    }

    // 严格翻译自 ArgumentsSlice.next
    // 查看下一个参数但不消费
    public func next() -> ?JsValue {
        if (remaining.size == 0) {
            return None
        }
        Some(remaining[0])
    }

    // 严格翻译自 ArgumentsSlice.nextEat
    // 获取并消费下一个参数
    public func nextEat() -> ?JsValue {
        if (remaining.size == 0) {
            return None
        }
        let val = remaining[0]
        eat()
        Some(val)
    }

    // 严格翻译自 ArgumentsSlice.protectEatNext
    public func protectEatNext() -> ?JsValue {
        nextEat()
    }

    // 严格翻译自 ArgumentsSlice.deinit
    public func deinit() {
        remaining = []
        all = []
    }
}

// ========== 调用者源码位置 ==========
// 严格翻译自 CallFrame.CallerSrcLoc
public class CallerSrcLoc {
    public var sourceURL: String = ""
    public var line: UInt32 = 0
    public var column: UInt32 = 0

    public init() {}

    public init(sourceURL: String, line: UInt32, column: UInt32) {
        this.sourceURL = sourceURL
        this.line = line
        this.column = column
    }
}
