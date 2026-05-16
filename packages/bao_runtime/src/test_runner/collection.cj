// collection.cj - 测试收集
// 严格翻译自 bun/src/runtime/test_runner/Collection.zig

package bao_runtime.test_runner

import bao_jsc.*
import std.collection.*

// ========== Collection - 测试收集阶段 ==========

/// 测试收集阶段，负责发现所有test()调用
public class Collection {
    public var locked: Bool = false  // 收集阶段结束后设置为true
    public var describeCallbackQueue: ArrayList<QueuedDescribe> = ArrayList<QueuedDescribe>()
    public var currentScopeCallbackQueue: ArrayList<QueuedDescribe> = ArrayList<QueuedDescribe>()
    public var rootScope: DescribeScope
    public var activeScope: DescribeScope
    public var filterBuffer: ArrayList<UInt8> = ArrayList<UInt8>()

    public init(gpa: Allocator, bunTestRoot: BunTestRoot) {
        rootScope = DescribeScope.create(gpa: gpa, base: BaseScope(
            cfg: BaseScopeCfg(), gpa: gpa, name: None, parent: bunTestRoot.hookScope, hasCallback: false
        ))
        activeScope = rootScope
    }

    public func deinit() {
        for (item in describeCallbackQueue) {
            // 释放
        }
        describeCallbackQueue.clear()
        for (item in currentScopeCallbackQueue) {
            // 释放
        }
        currentScopeCallbackQueue.clear()
        filterBuffer.clear()
    }

    /// 入队describe回调
    public func enqueueDescribeCallback(newScope: DescribeScope, callback: ?JSValue) {
        if (let Some(cb) <- callback) {
            currentScopeCallbackQueue.append(QueuedDescribe(
                activeScope: activeScope,
                callback: cb,
                newScope: newScope
            ))
        }
    }

    /// 单次完成回调 - 恢复活动作用域到调用前状态
    public func runOneCompleted(globalThis: JSGlobalObject, data: RefDataValue) {
        let prevScope: DescribeScope = match (data) {
            case RefDataValue.collection(activeScope) => activeScope
            case _ => activeScope // 不应发生
        }

        activeScope = prevScope
    }

    /// 步骤 - 收集阶段的主循环
    ///
    /// 处理流程:
    /// 1. 如果data不是Start，先调用runOneCompleted恢复作用域
    /// 2. 将currentScopeCallbackQueue中的项移到describeCallbackQueue（逆序，因为pop从末尾取）
    /// 3. 如果队列为空，收集完成
    /// 4. 从队列中取出第一个，设置活动作用域，执行回调
    public func step(buntestStrong: BunTestPtr, globalThis: JSGlobalObject, data: RefDataValue): StepResult {
        let buntest = buntestStrong.get()

        if (!data.isStart()) {
            runOneCompleted(globalThis: globalThis, data: data)
        }

        // 将当前作用域回调队列中的项逆序追加到主队列
        // 逆序因为items会从末尾pop
        var items = currentScopeCallbackQueue.reversed()
        currentScopeCallbackQueue.clear()
        for (item in items ) {
            if (item.newScope.failed) {
                // 如果describe回调中有错误，不再运行该作用域的describe回调
            } else {
                describeCallbackQueue.append(item)
            }
        }

        // 处理主队列
        while (!describeCallbackQueue.isEmpty()) {
            let first = describeCallbackQueue.removeLast()

            if (first.activeScope.failed) {
                continue // 不执行来自失败describe作用域的回调
            }

            let callback = first.callback
            let previousScope = first.activeScope
            let newScope = first.newScope

            // 设置活动作用域到新的作用域
            activeScope = newScope

            // 运行测试回调
            let result = BunTest.runTestCallback(
                strong: buntestStrong,
                globalThis: globalThis,
                callback: callback,
                doneParameter: false,
                data: RefDataValue.collection(RefDataCollection(activeScope: previousScope)),
                timeout: Timespec.epoch
            )

            if (let Some(cfgData) <- result) {
                // 结果立即可用；入队
                buntestStrong.get().addResult(result: cfgData)
            }

            return StepResult.waiting(timeout: Timespec.epoch)
        }

        return StepResult.complete
    }

    /// 处理未捕获异常
    public func handleUncaughtException(userData: RefDataValue): HandleUncaughtExceptionResult {
        activeScope.failed = true
        return HandleUncaughtExceptionResult.showUnhandledErrorInDescribe
    }
}

// ========== QueuedDescribe - 排队的Describe ==========

/// 排队的describe回调
public class QueuedDescribe {
    public var callback: JSValue
    public var activeScope: DescribeScope
    public var newScope: DescribeScope

    public init(callback: JSValue, activeScope: DescribeScope, newScope: DescribeScope) {
        this.callback = callback
        this.activeScope = activeScope
        this.newScope = newScope
    }

    public func deinit() {
        // 释放回调
    }
}
