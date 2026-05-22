// 断言绑定模块 — Myers diff 的 JS 绑定层
// 对应 Bun: src/runtime/node/node_assert_binding.zig
// 严格翻译自: src/runtime/node/node_assert_binding.zig
package bao_runtime.node

import bao_core.*
import bao_jsc.*
import std.collection.ArrayList

// MyersDiff, DiffKind, DiffItem 来自 bao_runtime.node.node_assert (同一包)


// ============================================================================
// Diff 类型枚举（JS 绑定用整数值）
// 对应 Bun: src/runtime/node/node_assert_binding.zig - DiffType
//
// ```ts
// const enum DiffType {
//     Insert = 0,
//     Delete = 1,
//     Equal  = 2,
// }
// type Diff = { operation: DiffType, text: string };
// declare function myersDiff(actual: string, expected: string): Diff[];
// ```
// ============================================================================
public enum DiffType {
    | insert
    | delete
    | equal

    public func value(): Int32 {
        match (this) {
            case insert => 0
            case delete => 1
            case equal => 2
        }
    }
}

// ============================================================================
// Diff 结果项（JS 绑定格式）
// 对应 Bun: src/runtime/node/node_assert_binding.zig - Diff
// ============================================================================
public class JsDiffItem {
    public var operation: DiffType = DiffType.equal
    public var text: String = ""

    public init() {}

    public init(operation: DiffType, text: String) {
        this.operation = operation
        this.text = text
    }
}

// ============================================================================
// 断言绑定 — 将 Myers diff 暴露为 JS 可调用函数
// 对应 Bun: src/runtime/node/node_assert_binding.zig - myersDiff
// ============================================================================
public class NodeAssertBinding {
    // myersDiff 绑定函数
    // 对应 Bun: src/runtime/node/node_assert_binding.zig - myersDiff
    //
    // 参数:
    //   actual: string - 实际值
    //   expected: string - 期望值
    //   checkCommaDisparity: bool (可选, 默认 false) - 是否检查逗号差异
    //   lines: bool (可选, 默认 false) - 是否按行 diff
    //
    // 返回: JsDiffItem[]
    public static func myersDiff(
        actual: String,
        expected: String,
        checkCommaDisparity: Bool,
        lines: Bool
    ): Array<JsDiffItem> {
        if (lines) {
            return myersDiffLines(actual, expected, checkCommaDisparity)
        }
        return myersDiffChars(actual, expected)
    }

    public static func myersDiff(
        actual: String,
        expected: String
    ): Array<JsDiffItem> {
        myersDiff(actual, expected, false, false)
    }

    // 字符级别 diff
    // 对应 Bun: src/runtime/node/node_assert_binding.zig -> assert.myersDiff (chars path)
    private static func myersDiffChars(actual: String, expected: String): Array<JsDiffItem> {
        let diffResult = MyersDiff.diffChars(actual, expected)
        let result = ArrayList<JsDiffItem>()
        for (item in diffResult) {
            let op = match (item.kind) {
                case DiffKind.insert => DiffType.insert
                case DiffKind.delete => DiffType.delete
                case DiffKind.equal  => DiffType.equal
            }
            result.add(JsDiffItem(op, item.value))
        }
        return result.toArray()
    }

    // 行级别 diff
    // 对应 Bun: src/runtime/node/node_assert_binding.zig -> assert.myersDiff (lines path)
    private static func myersDiffLines(actual: String, expected: String, checkCommaDisparity: Bool): Array<JsDiffItem> {
        let diffResult = MyersDiff.diffLines(actual, expected, checkCommaDisparity)
        let result = ArrayList<JsDiffItem>()
        for (item in diffResult) {
            let op = match (item.kind) {
                case DiffKind.insert => DiffType.insert
                case DiffKind.delete => DiffType.delete
                case DiffKind.equal  => DiffType.equal
            }
            result.add(JsDiffItem(op, item.value))
        }
        return result.toArray()
    }

    // 将 diff 结果列表转换为 JS 对象数组
    // 对应 Bun: src/runtime/node/node_assert_binding.zig - diffListToJS
    public static func diffListToJS(diffList: Array<JsDiffItem>): HashMap<String, Object> {
        let array = ArrayList<JsDiffItem>()
        for (line in diffList) {
            array.add(line)
        }
        // 返回合并后的 map
        let result = HashMap<String, Object>()
        result.put("diffs", array)
        return result
    }
}

// ============================================================================
// 导出模块生成
// 对应 Bun: src/runtime/node/node_assert_binding.zig - generate
//
// 导出:
//   myersDiff: function(actual, expected, checkCommaDisparity?, lines?) -> Diff[]
// ============================================================================
public class NodeAssertBindingGenerate {
    // 生成导出对象
    // 对应 Bun: src/runtime/node/node_assert_binding.zig - generate
    public static func generate(): HashMap<String, Object> {
        let exports = HashMap<String, Object>()
        // 导出 myersDiff 函数引用
        exports.put("myersDiff", BaoString("NodeAssertBinding.myersDiff"))
        return exports
    }
}
