// collection.cj - 测试收集
// 严格翻译自 bun/src/runtime/test_runner/Collection.zig

package bao_runtime.test_runner

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
        for item in describeCallbackQueue {
            // 释放
        }
        describeCallbackQueue.clear()
        for item in currentScopeCallbackQueue {
            // 释放
        }
        currentScopeCallbackQueue.clear()
        filterBuffer.clear()
    }

    /// 入队describe回调
    public func enqueueDescribeCallback(newScope: DescribeScope, callback: ?JSValue) {
        if let cb = callback {
            currentScopeCallbackQueue.append(QueuedDescribe(
                activeScope: activeScope,
                callback: cb,
                newScope: newScope
            ))
        }
    }

    /// 单次完成回调
    public func runOneCompleted(globalThis: JSGlobalObject, data: RefDataValue) {
        // TODO: 实现 - 恢复活动作用域
    }

    /// 步骤
    public func step(buntestStrong: BunTestPtr, globalThis: JSGlobalObject, data: RefDataValue): StepResult {
        // TODO: 实现
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
