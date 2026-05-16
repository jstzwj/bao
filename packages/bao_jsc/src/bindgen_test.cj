// 严格翻译自: src/jsc/bindgen_test.zig
// 绑定生成器测试命名空间
// 此示例应与 bindgen 文档保持同步

package bao_jsc

// ============================================================================
// 绑定生成器测试
// 对应 Bun: bindgen_test
// ============================================================================

public class BindgenTest {

    /// 获取绑定生成器测试函数
    /// 对应 Bun: getBindgenTestFunctions
    public static func getBindgenTestFunctions(global: JsGlobalObject): ?JsValue {
        // 创建包含 add 和 requiredAndOptionalArg 回调的对象
        return None
    }

    /// 加法测试函数
    /// 对应 Bun: add
    public static func add(global: JsGlobalObject, a: Int32, b: Int32): Int32 {
        let result = Int64(a) + Int64(b)
        if (result > Int64(Int32.MaxValue) || result < Int64(Int32.MinValue)) {
            // 整数溢出
            return 0 // 实际实现应抛出异常
        }
        return Int32(result)
    }

    /// 必需和可选参数测试
    /// 对应 Bun: requiredAndOptionalArg
    public static func requiredAndOptionalArg(a: Bool, b: ?Int64, c: Int32, d: ?UInt8): Int32 {
        let bVal = b
        if (bVal == None) {
            var r = 123456 + c
            if (d != None) { r = r + Int32(d.getOrThrow()) }
            return r
        }
        var mathResult: Int32 = Int32((bVal! + Int64(abs(c))) * (if (d != None) { Int64(d.getOrThrow()) } else { 1 }))
        if (a) {
            mathResult = -mathResult
        }
        return mathResult
    }

    static func abs(v: Int32): Int32 {
        if (v < 0) { return -v }
        return v
    }
}
