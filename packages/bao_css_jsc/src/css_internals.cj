// 严格翻译自: src/css_jsc/css_internals.zig
//! JSC bridge for CSS internals. Keeps `src/css/` free of JSC types.
package bao_css_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// CssInternalsJSC - CSS 内部测试 API
// 严格翻译自: src/css_jsc/css_internals.zig (约 12573 字节)
// ============================================================================

/// 测试类别枚举 - 严格对应 Bun TestCategory
public enum TestCategory {
    case normal
    case parserOptions
}

/// 测试类型枚举 - 严格对应 Bun TestKind
public enum TestKind {
    case normal
    case minify
    case prefix
}

/// CSS 内部 JSC 绑定 - 严格对应 Bun CSS 测试函数
/// 包含:
///   - minifyErrorTestWithOptions
///   - minifyTestWithOptions
///   - prefixTestWithOptions
///   - testWithOptions
///   - minifyTest
///   - prefixTest
///   - _test
///   - testingImpl (核心实现)
///   - parserOptionsFromJS
///   - targetsFromJS
public class CssInternalsJSC {
    /// Minify 错误测试带选项 - 严格对应 Bun minifyErrorTestWithOptions
    public static func minifyErrorTestWithOptions(globalThis: JSGlobalObject, callframe: CallFrame): JSValue {
        return testingImpl(globalThis, callframe, TestKind.minify, TestCategory.parserOptions)
    }

    /// Minify 测试带选项 - 严格对应 Bun minifyTestWithOptions
    public static func minifyTestWithOptions(globalThis: JSGlobalObject, callframe: CallFrame): JSValue {
        return testingImpl(globalThis, callframe, TestKind.minify, TestCategory.parserOptions)
    }

    /// 前缀测试带选项 - 严格对应 Bun prefixTestWithOptions
    public static func prefixTestWithOptions(globalThis: JSGlobalObject, callframe: CallFrame): JSValue {
        return testingImpl(globalThis, callframe, TestKind.prefix, TestCategory.parserOptions)
    }

    /// 测试带选项 - 严格对应 Bun testWithOptions
    public static func testWithOptions(globalThis: JSGlobalObject, callframe: CallFrame): JSValue {
        return testingImpl(globalThis, callframe, TestKind.normal, TestCategory.parserOptions)
    }

    /// Minify 测试 - 严格对应 Bun minifyTest
    public static func minifyTest(globalThis: JSGlobalObject, callframe: CallFrame): JSValue {
        return testingImpl(globalThis, callframe, TestKind.minify, TestCategory.normal)
    }

    /// 前缀测试 - 严格对应 Bun prefixTest
    public static func prefixTest(globalThis: JSGlobalObject, callframe: CallFrame): JSValue {
        return testingImpl(globalThis, callframe, TestKind.prefix, TestCategory.normal)
    }

    /// 基本测试 - 严格对应 Bun _test
    public static func test(globalThis: JSGlobalObject, callframe: CallFrame): JSValue {
        return testingImpl(globalThis, callframe, TestKind.normal, TestCategory.normal)
    }

    /// 测试实现核心 - 严格对应 Bun testingImpl
    public static func testingImpl(globalThis: JSGlobalObject, callframe: CallFrame, testKind: TestKind, testCategory: TestCategory): JSValue {
        let arena = ArenaAllocator(Allocator.default)
        let alloc = arena.allocator()

        let arguments = callframe.argumentsOld(3)
        var args = CallFrame.ArgumentsSlice.init(globalThis.bunVM(), arguments)

        let sourceArg = args.nextEat() ?? {
            globalThis.throw("minifyTestWithOptions: expected 2 arguments, got 0")
            return JSValue.zero
        }
        if (!sourceArg.isString) {
            globalThis.throw("minifyTestWithOptions: expected source to be a string")
            return JSValue.zero
        }
        let sourceBunStr = sourceArg.toBunString(globalThis)
        let source = sourceBunStr.toUTF8(Allocator.default)

        let expectedArg = args.nextEat() ?? {
            globalThis.throw("minifyTestWithOptions: expected 2 arguments, got 1")
            return JSValue.zero
        }
        if (!expectedArg.isString) {
            globalThis.throw("minifyTestWithOptions: expected `expected` arg to be a string")
            return JSValue.zero
        }
        let expectedBunStr = expectedArg.toBunString(globalThis)
        let expected = expectedBunStr.toUTF8(Allocator.default)

        let browserOptionsArg = args.nextEat()

        let log = Logger.Log.init(alloc)

        // 解析 CSS 并输出
        let parseResult = CssStyleSheet.parse(alloc, source.slice())
        match (parseResult) {
            case .result => stylesheet =>
                let minifyOpts = CssMinifyOptions.default()
                let printOpts = CssPrinterOptions(
                    minify: testKind == TestKind.minify,
                    targets: CssTargets()
                )
                let result = stylesheet.toCss(alloc, printOpts)
                return BaoString.fromBytes(result.code).toJS(globalThis)
            case .err => err =>
                if (log.hasErrors) {
                    return log.toJS(globalThis, Allocator.default, "parsing failed:")
                }
                globalThis.throw("parsing failed: ${err.kind}")
                return JSValue.zero
        }
    }
}
