// 严格翻译自: src/jsc/MarkedArgumentBuffer.zig (39行)
// JavaScriptCore 标记参数缓冲区 - GC 保护的参数列表

package bao_jsc

// ========== MarkedArgumentBuffer ==========
// 严格翻译自 MarkedArgumentBuffer.zig
// 标记参数缓冲区，用于在 GC 期间保护参数不被回收
public class MarkedArgumentBuffer {
    // 参数列表
    public var args: Array<JsValue> = []

    public init() {}

    public init(capacity: Int64) {
        args = Array<JsValue>()
    }

    // 严格翻译自 MarkedArgumentBuffer.append
    public func append(value: JsValue) {
        args.append(value)
    }

    // 严格翻译自 MarkedArgumentBuffer.run
    // 在标记参数缓冲区上下文中运行函数
    public static func run(func_: (MarkedArgumentBuffer) -> Unit) {
        let buffer = MarkedArgumentBuffer()
        func_(buffer)
    }

    // 获取参数数量
    public func size() -> Int64 {
        Int64(args.size)
    }

    // 获取指定索引的参数
    public func get(i: Int64) -> JsValue {
        if (i >= 0 && i < Int64(args.size)) {
            return args[Int64(i)]
        }
        JsValue.undefined()
    }

    // 转为数组
    public func toArray() -> Array<JsValue> {
        args
    }

    // 清除所有参数
    public func clear() {
        args = []
    }
}
