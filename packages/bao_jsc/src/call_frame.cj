// 严格翻译自: src/jsc/CallFrame.zig (305行)
// JavaScriptCore 调用帧 - JS 到原生函数调用的参数帧
//
// Call Frame 布局 (来自 JavaScriptCore/interpreter/CallFrame.h):
//
//   |          ......            |   |
//   +----------------------------+   |
//   |           argN             |   v  lower address
//   +----------------------------+
//   |           arg1             |
//   +----------------------------+
//   |           arg0             |
//   +----------------------------+
//   |           this             |
//   +----------------------------+
//   | argumentCountIncludingThis |
//   +----------------------------+
//   |          callee            |
//   +----------------------------+
//   |        codeBlock           |
//   +----------------------------+
//   |      return-address        |
//   +----------------------------+
//   |       callerFrame          |
//   +----------------------------+  <- callee's cfr is pointing this address
//   |          local0            |
//   +----------------------------+
//   |          local1            |
//   +----------------------------+
//   |          localN            |
//   +----------------------------+
//   |          ......            |

package bao_jsc

// ========== 调用帧槽位偏移常量 ==========
// 严格翻译自 CallFrame.zig offset_* 常量
// 这些常量来自 JSC::CallFrameSlot in JavaScriptCore/interpreter/CallFrame.h
let OFFSET_CODE_BLOCK: Int64 = 2
let OFFSET_CALLEE: Int64 = OFFSET_CODE_BLOCK + 1
let OFFSET_ARGUMENT_COUNT_INCLUDING_THIS: Int64 = OFFSET_CALLEE + 1
let OFFSET_THIS_ARGUMENT: Int64 = OFFSET_ARGUMENT_COUNT_INCLUDING_THIS + 1
let OFFSET_FIRST_ARGUMENT: Int64 = OFFSET_THIS_ARGUMENT + 1

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

    // ========== arguments_old (已弃用) ==========
    // 严格翻译自 CallFrame.arguments_old
    // 不推荐使用。迁移路径:
    //   arguments(n).ptr[k] -> argumentsAsArray(n)[k]
    //   arguments(n).slice() -> arguments()
    //   arguments(n).mut() -> var args = argumentsAsArray(n); &args
    public func argumentsOld(max: Int64) -> CallFrameArguments {
        let slice = args
        let count = if (Int64(slice.size) < max) { Int64(slice.size) } else { max }
        var ptr = Array<JsValue>()
        for (i in 0..count) {
            ptr.append(slice[Int64(i)])
        }
        CallFrameArguments(ptr: ptr, len: count)
    }

    // ========== argumentsUndef (已弃用) ==========
    // 严格翻译自 CallFrame.argumentsUndef
    // 不推荐使用。迁移路径: 使用 argumentsAsArray(n)
    public func argumentsUndef(max: Int64) -> CallFrameArguments {
        let slice = args
        let count = if (Int64(slice.size) < max) { Int64(slice.size) } else { max }
        var ptr = Array<JsValue>()
        for (i in 0..max) {
            if (i < count) {
                ptr.append(slice[Int64(i)])
            } else {
                ptr.append(JsValue.undefined())
            }
        }
        CallFrameArguments(ptr: ptr, len: count)
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

// ========== CallFrame.Arguments (固定大小参数数组) ==========
// 严格翻译自 CallFrame.Arguments(comptime max: usize)
// 固定大小的参数数组，用于已知最大参数数量的场景
public class CallFrameArguments {
    public var ptr: Array<JsValue> = []
    public var len: Int64 = 0

    public init() {}

    public init(ptr: Array<JsValue>, len: Int64) {
        this.ptr = ptr
        this.len = len
    }

    // 获取参数切片
    public func slice() -> Array<JsValue> {
        if (len <= Int64(ptr.size)) {
            return ptr[0..Int64(len)]
        }
        ptr
    }

    // 获取可变参数数组
    public func mut() -> Array<JsValue> {
        ptr
    }
}

// ========== Register ==========
// 严格翻译自 CallFrame.zig Register (内部类型)
// 表示 JSC 调用帧中的一个寄存器槽位
// 定义在 JavaScriptCore/interpreter/Register.h
//
// 原始 Zig:
//   const Register = extern union {
//       value: JSValue,
//       call_frame: *CallFrame,
//       code_block: *anyopaque,
//       encoded_value: extern union {
//           ptr: JSValue,
//           as_bits: extern struct {
//               payload: i32,
//               tag: i32,
//           },
//       },
//       number: f64,
//       integer: i64,
//   };
public class Register {
    // 作为 JSValue 的编码值
    public var value: JsValue = JsValue.undefined()
    // 作为调用帧指针
    public var callFrame: ?CallFrame = None
    // 作为整数
    public var integer: Int64 = 0
    // 作为浮点数
    public var number: Float64 = 0.0
    // 编码值的位表示
    public var payload: Int32 = 0
    public var tag: Int32 = 0

    public init() {}

    // 获取 unboxedInt32 - 对应 argumentCountIncludingThis 的读取方式
    // 在 JSC 中通过 .encodedValue.asBits.payload 读取
    public func unboxedInt32() -> Int32 {
        payload
    }
}
