// bun_test.cj - 测试框架 JavaScript 函数绑定
// 严格翻译自: src/runtime/test_runner/bun_test.zig (js_fns 模块)
//
// 本文件对应 Bun 的 bun_test.zig 中的 js_fns 命名空间，包含:
// - getActiveTestRoot: 获取当前活跃的测试根对象
// - cloneActiveStrong: 克隆当前活跃的 BunTest 强引用
// - genericHook: 通用钩子函数 (beforeAll/beforeEach/afterEach/afterAll/onTestFinished)
//
// 这些函数是 JavaScript 回调 (test(), describe(), beforeAll() 等) 的核心入口，
// 负责将 JS 调用转发到正确的测试生命周期阶段。

package bao_runtime.test_runner

import bao_jsc.{CallFrame, JSGlobalObject, JsValue}
import bao_core.defaultAllocator

// ========== JsFns — JavaScript 函数绑定 ==========

/// JavaScript 函数绑定模块
///
/// 对应 Bun: bun_test.zig 中的 js_fns 命名空间
/// 提供 JS 回调函数的宿主实现，将 JS 层的 test()/describe()/beforeAll() 等调用
/// 转发到正确的测试生命周期阶段。
public class JsFns {

    /// 获取当前活跃的 BunTestRoot
    ///
    /// 对应 Bun: js_fns.getActiveTestRoot
    /// 从 Jest runner 中获取 bun_test_root，并进行有效性检查。
    ///
    /// @param globalThis - JSGlobalObject (JSC 全局对象)
    /// @param signature - 函数签名 (用于错误消息)
    /// @param allowInPreload - 是否允许在预加载阶段调用
    /// @return BunTestRoot 或抛出异常
    public static func getActiveTestRoot(globalThis: JSGlobalObject, signature: Signature, allowInPreload: Bool): ?BunTestRoot {
        // 对应 Bun: if (bun.jsc.Jest.Jest.runner == null)
        let runner = Jest.runner
        if (runner.isNone()) {
            globalThis.throwError(
                "Cannot use " + signature.format() + " outside of the test runner. Run \"bao test\" to run tests."
            )
            return None
        }

        let runnerVal = runner.getOrThrow()
        let bunTestRoot = runnerVal.bunTestRoot

        // 对应 Bun: if (vm.is_in_preload and !cfg.allow_in_preload)
        let vm = VirtualMachine.get()
        if (vm.isInPreload && !allowInPreload) {
            globalThis.throwError(
                "Cannot use " + signature.format() + " during preload."
            )
            return None
        }

        return bunTestRoot
    }

    /// 克隆当前活跃的 BunTest 强引用
    ///
    /// 对应 Bun: js_fns.cloneActiveStrong
    /// 从 Jest runner 中获取活跃的 BunTest 文件引用。
    ///
    /// @param globalThis - JSGlobalObject
    /// @param signature - 函数签名 (用于错误消息)
    /// @param allowInPreload - 是否允许在预加载阶段调用
    /// @return BunTestPtr 或抛出异常
    public static func cloneActiveStrong(globalThis: JSGlobalObject, signature: Signature, allowInPreload: Bool): ?BunTestPtr {
        // 获取 BunTestRoot
        let bunTestRootOpt = getActiveTestRoot(globalThis, signature, allowInPreload)
        if (bunTestRootOpt.isNone()) {
            return None
        }
        let bunTestRoot = bunTestRootOpt.getOrThrow()

        // 对应 Bun: const bunTest = bunTestRoot.cloneActiveFile() orelse { ... }
        let bunTest = bunTestRoot.cloneActiveFile()
        if (bunTest.isNone()) {
            globalThis.throwError(
                "Cannot use " + signature.format() + " outside of a test file."
            )
            return None
        }

        return bunTest
    }

    /// 通用钩子函数
    ///
    /// 对应 Bun: js_fns.genericHook
    /// 处理 beforeAll/beforeEach/afterEach/afterAll/onTestFinished 的 JS 调用。
    ///
    /// 这是一个泛型函数，通过 tag 参数区分不同的钩子类型:
    /// - beforeAll: 在所有测试之前运行
    /// - beforeEach: 在每个测试之前运行
    /// - afterEach: 在每个测试之后运行
    /// - afterAll: 在所有测试之后运行
    /// - onTestFinished: 在测试完成后运行 (只能从测试内部调用)
    ///
    /// @param globalThis - JSGlobalObject
    /// @param callFrame - CallFrame (JS 调用帧)
    /// @param tag - 钩子类型
    /// @return JsValue (js_undefined)
    public static func genericHook(globalThis: JSGlobalObject, callFrame: CallFrame, tag: GenericHookTag): JsValue {
        // 对应 Bun: var args = try ScopeFunctions.parseArguments(...)
        let signature = Signature.str(tag.sig())
        let args = ScopeFunctions.parseArguments(
            globalThis: globalThis,
            callFrame: callFrame,
            signature: signature,
            cfg: ParseArgumentsCfg(callback: CallbackMode.require, kind: FunctionKind.hook)
        )

        // 对应 Bun: const has_done_parameter = if (args.callback) |callback| try callback.getLength(globalThis) > 0 else false
        let hasDoneParameter: Bool = if (let Some(callback) <- args.callback) {
            callback.getLength(globalThis.globalThis) > 0
        } else {
            false
        }

        // 对应 Bun: const cfg: ExecutionEntryCfg = .{ .has_done_parameter = has_done_parameter, .timeout = args.options.timeout }
        let cfg = ExecutionEntryCfg()
        cfg.hasDoneParameter = hasDoneParameter
        cfg.timeout = args.options.timeout

        // 获取 BunTestRoot
        let bunTestRootOpt = getActiveTestRoot(globalThis, signature, true)
        if (bunTestRootOpt.isNone()) {
            return JsValue.jsUndefined()
        }
        let bunTestRoot = bunTestRootOpt.getOrThrow()

        // 获取活跃文件 (允许预加载)
        // 对应 Bun: const bunTest = bunTestRoot.getActiveFileUnlessInPreload(globalThis.bunVM()) orelse { ... }
        let bunTestOpt = bunTestRoot.activeFile
        let vm = VirtualMachine.get()

        if (vm.isInPreload) {
            // 对应 Bun: if tag == .onTestFinished { throw }
            if (tag == GenericHookTag.onTestFinished) {
                globalThis.throwError(
                    "Cannot call " + tag.sig() + " in preload. It can only be called inside a test."
                )
                return JsValue.jsUndefined()
            }

            // 对应 Bun: _ = try bunTestRoot.hook_scope.appendHook(...)
            let hookScope = bunTestRoot.hookScope
            hookScope.appendHook(
                tag: tag.asHookTag() ?? DescribeScopeHookTag.beforeAll,
                callback: args.callback,
                cfg: cfg,
                base: BaseScopeCfg(),
                phase: AddedInPhase.preload
            )
            return JsValue.jsUndefined()
        }

        // 获取 BunTest
        if (bunTestOpt.isNone()) {
            return JsValue.jsUndefined()
        }
        let bunTestPtr = bunTestOpt.getOrThrow()
        let bunTest = bunTestPtr.get()
        if (bunTest.isNone()) {
            return JsValue.jsUndefined()
        }
        let bunTestVal = bunTest.getOrThrow()

        // 根据阶段分发
        match (bunTestVal.phase) {
            case TestPhase.collection =>
                // 对应 Bun: if (tag == .onTestFinished) { throw }
                if (tag == GenericHookTag.onTestFinished) {
                    globalThis.throwError(
                        "Cannot call " + tag.sig() + " outside of a test. It can only be called inside a test."
                    )
                    return JsValue.jsUndefined()
                }

                // 对应 Bun: _ = try bunTest.collection.active_scope.appendHook(...)
                bunTestVal.collection_.activeScope.appendHook(
                    tag: tag.asHookTag() ?? DescribeScopeHookTag.beforeAll,
                    callback: args.callback,
                    cfg: cfg,
                    base: BaseScopeCfg(),
                    phase: AddedInPhase.collection
                )
                return JsValue.jsUndefined()

            case TestPhase.execution =>
                // 对应 Bun: const active = bunTest.getCurrentStateData()
                let active = bunTestVal.getCurrentStateData()

                // 对应 Bun: const sequence, _ = bunTest.execution.getCurrentAndValidExecutionSequence(active) orelse { ... }
                let sequenceResult = bunTestVal.execution_.getCurrentAndValidExecutionSequence(active)
                if (sequenceResult.isNone()) {
                    let message = if (tag == GenericHookTag.onTestFinished) {
                        "Cannot call " + tag.sig() + " here. It cannot be called inside a concurrent test. Use test.serial or remove test.concurrent."
                    } else {
                        "Cannot call " + tag.sig() + " here. It cannot be called inside a concurrent test. Call it inside describe() instead."
                    }
                    globalThis.throwError(message)
                    return JsValue.jsUndefined()
                }

                let (sequence, group) = sequenceResult.getOrThrow()

                // 确定插入点
                // 对应 Bun: switch (tag) { .afterAll, .afterEach => blk: { ... }, .onTestFinished => blk: { ... }, else => ... }
                // Cangjie 不支持 case 合并 (|), 使用 if-else 代替
                var appendPoint: ?ExecutionEntry = None
                match (tag) {
                    case GenericHookTag.afterAll =>
                        appendPoint = findTestEntryOrLast(sequence)
                    case GenericHookTag.afterEach =>
                        appendPoint = findTestEntryOrLast(sequence)
                    case GenericHookTag.onTestFinished =>
                        appendPoint = findLastEntry(sequence)
                    case _ =>
                        // beforeAll/beforeEach: 不能在测试内部调用
                        globalThis.throwError(
                            "Cannot call " + tag.sig() + " inside a test. Call it inside describe() instead."
                        )
                        return JsValue.jsUndefined()
                }

                if (appendPoint.isNone()) {
                    globalThis.throwError(
                        "Cannot call " + tag.sig() + " here. Call it inside describe() instead."
                    )
                    return JsValue.jsUndefined()
                }
                let appendPointEntry = appendPoint.getOrThrow()

                // 对应 Bun: const new_item = ExecutionEntry.create(...)
                let newItem = ExecutionEntry.create(
                    bunTestVal.gpa,
                    None,
                    args.callback,
                    cfg,
                    None,
                    BaseScopeCfg(),
                    AddedInPhase.execution
                )

                // 对应 Bun: new_item.next = append_point.next; append_point.next = new_item
                newItem.next = appendPointEntry.next
                appendPointEntry.next = newItem

                // 对应 Bun: bun.handleOom(bunTest.extra_execution_entries.append(new_item))
                bunTestVal.extraExecutionEntries.append(newItem)

                return JsValue.jsUndefined()

            case TestPhase.done =>
                globalThis.throwError(
                    "Cannot call " + tag.sig() + " after the test run has completed"
                )
                return JsValue.jsUndefined()
        }
    }

    /// 在执行序列中找到测试条目或最后一个已知条目
    /// 对应 Bun: genericHook 中 afterAll/afterEach 的插入点查找逻辑
    private static func findTestEntryOrLast(sequence: ExecutionSequence): ?ExecutionEntry {
        var iter: ?ExecutionEntry = sequence.activeEntry
        while (let Some(entry) <- iter) {
            if (let Some(testEntry) <- sequence.testEntry) {
                if (entry == testEntry) {
                    return sequence.activeEntry
                }
            }
            iter = entry.next
        }
        return sequence.activeEntry
    }

    /// 找到执行序列中的最后一个条目
    /// 对应 Bun: genericHook 中 onTestFinished 的插入点查找逻辑
    private static func findLastEntry(sequence: ExecutionSequence): ?ExecutionEntry {
        var lastEntry: ?ExecutionEntry = sequence.activeEntry
        if (lastEntry.isNone()) { return None }
        var iter: ?ExecutionEntry = lastEntry.getOrThrow().next
        while (let Some(nextEntry) <- iter) {
            lastEntry = Some(nextEntry)
            iter = nextEntry.next
        }
        return lastEntry
    }
}

// ========== DescribeScope 扩展 — appendHook ==========

/// DescribeScope 的钩子追加扩展
///
/// 对应 Bun: DescribeScope.appendHook
/// 向 DescribeScope 追加一个钩子条目 (beforeAll/beforeEach/afterEach/afterAll)
extend DescribeScope {
    /// 追加钩子条目
    ///
    /// 对应 Bun: DescribeScope.appendHook(gpa, tag, callback, cfg, base, phase)
    public func appendHook(tag: DescribeScopeHookTag, callback: ?JsValue, cfg: ExecutionEntryCfg, base: BaseScopeCfg, phase: AddedInPhase): ExecutionEntry {
        let entry = ExecutionEntry.create(
            defaultAllocator,
            None,
            callback,
            cfg,
            this,
            base,
            phase
        )

        // 根据钩子类型追加到对应的列表
        match (tag) {
            case DescribeScopeHookTag.beforeAll =>
                beforeAll.append(entry)
            case DescribeScopeHookTag.beforeEach =>
                beforeEach.append(entry)
            case DescribeScopeHookTag.afterEach =>
                afterEach.append(entry)
            case DescribeScopeHookTag.afterAll =>
                afterAll.append(entry)
        }
        return entry
    }
}
