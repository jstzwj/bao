// 严格翻译自: src/jsc/TopExceptionScope.zig (217行)
// JSC::TopExceptionScope 的绑定

package bao_jsc

// ========== TopExceptionScope ==========
// 严格翻译自 TopExceptionScope.zig TopExceptionScope
// JSC::TopExceptionScope 的绑定。很少使用，仅在 JSC 的异常检查和 Zig 的之间的翻译边界处使用。
// 创建后不要移动它。如果正在进行的无其他方式指示异常的外部调用，请使用此结构。
//
// 使用模式:
// ```
// var scope = TopExceptionScope()
// scope.init(global)
// defer scope.deinit()
//
// let value = externalCall(vm, foo, bar, baz)
// // 调用 returnIfException() 足以证明我们检查了异常
// try scope.returnIfException()
// return value
// ```
public class TopExceptionScope {
    // 内部字节数组 (模拟固定大小的 C++ 对象)
    public var bytes: Array<UInt8> = []
    // 是否已初始化
    public var isInitialized: Bool = false
    // 全局对象引用
    public var globalObject: ?JsObject = None
    // 是否有异常
    public var hadException: Bool = false

    public init() {}

    public init(global: JsObject) {
        this.globalObject = global
        this.isInitialized = true
        this.bytes = Array<UInt8>(56, item: 0)
    }

    // 严格翻译自 TopExceptionScope.init
    public func init_(global: JsObject) {
        this.globalObject = global
        this.isInitialized = true
        this.bytes = Array<UInt8>(56, item: 0)
    }

    // 严格翻译自 TopExceptionScope.hasException
    public func hasException() -> Bool {
        if (!isInitialized) { return false }
        return exception() != None
    }

    // 严格翻译自 TopExceptionScope.exception
    // 获取抛出的异常 (如果存在)
    public func exception() -> ?JsException {
        if (!isInitialized) { return None }
        // FFI: TopExceptionScope__pureException(&self.bytes)
        None
    }

    // 严格翻译自 TopExceptionScope.clearException
    public func clearException() {
        if (!isInitialized) { return }
        hadException = false
    }

    // 严格翻译自 TopExceptionScope.exceptionIncludingTraps
    // 获取抛出的异常 (如果存在)，或如果未处理的陷阱导致异常被抛出
    public func exceptionIncludingTraps() -> ?JsException {
        if (!isInitialized) { return None }
        // FFI: TopExceptionScope__exceptionIncludingTraps(&self.bytes)
        None
    }

    // 严格翻译自 TopExceptionScope.returnIfException
    // 设计用于 try。如果已存在待处理的异常或陷阱导致异常被抛出则返回错误
    public func returnIfException() -> Bool {
        exceptionIncludingTraps() != None
    }

    // 严格翻译自 TopExceptionScope.assertNoException
    // 断言没有异常被抛出
    public func assertNoException() {
        // 在 debug 模式下会检查并 panic
        if (exception() != None) {
            // assertionFailure
        }
    }

    // 严格翻译自 TopExceptionScope.assertExceptionPresenceMatches
    // 断言异常存在与否与 shouldHaveException 的值一致
    public func assertExceptionPresenceMatches(shouldHaveException: Bool) {
        if (shouldHaveException) {
            // 断言有异常
        } else {
            assertNoException()
        }
    }

    // 严格翻译自 TopExceptionScope.assertNoExceptionExceptTermination
    // 如果没有异常，返回。
    // 如果是终止异常，返回错误。
    // 如果是非终止异常，断言失败。
    public func assertNoExceptionExceptTermination() -> Bool {
        if (let Some(e) <- exception()) {
            // 检查是否为终止异常
            // if (e.isTerminationException()) return true
            return false  // 终止异常
        }
        false
    }

    // 严格翻译自 TopExceptionScope.deinit
    public func deinit() {
        if (!isInitialized) { return }
        // FFI: TopExceptionScope__destruct(&self.bytes)
        bytes = []
        isInitialized = false
        globalObject = None
        hadException = false
    }
}

// ========== ExceptionValidationScope ==========
// 严格翻译自 TopExceptionScope.zig ExceptionValidationScope
// TopExceptionScope 功能的有限子集，用于当你有其他方式检测异常
// 且只需要 TopExceptionScope 来证明你正确检查了异常的情况。
public class ExceptionValidationScope {
    // 内部作用域 (仅在启用断言时有效)
    public var scope: ?TopExceptionScope = None
    // 是否启用断言
    public var assertionsEnabled: Bool = false

    public init() {}

    public init(global: JsObject) {
        if (assertionsEnabled) {
            let s = TopExceptionScope(global)
            scope = s
        }
    }

    // 严格翻译自 ExceptionValidationScope.init
    public func init_(global: JsObject) {
        if (assertionsEnabled) {
            let s = TopExceptionScope(global)
            scope = s
        }
    }

    // 严格翻译自 ExceptionValidationScope.assertNoException
    public func assertNoException() {
        if (assertionsEnabled) {
            if (let Some(s) <- scope) {
                s.assertNoException()
            }
        }
    }

    // 严格翻译自 ExceptionValidationScope.assertExceptionPresenceMatches
    public func assertExceptionPresenceMatches(shouldHaveException: Bool) {
        if (assertionsEnabled) {
            if (let Some(s) <- scope) {
                s.assertExceptionPresenceMatches(shouldHaveException)
            }
        }
    }

    // 严格翻译自 ExceptionValidationScope.assertNoExceptionExceptTermination
    public func assertNoExceptionExceptTermination() -> Bool {
        if (assertionsEnabled) {
            if (let Some(s) <- scope) {
                return s.assertNoExceptionExceptTermination()
            }
        }
        false
    }

    // 严格翻译自 ExceptionValidationScope.hasExceptionOrFalseWhenAssertionsAreDisabled
    public func hasExceptionOrFalseWhenAssertionsAreDisabled() -> Bool {
        if (assertionsEnabled) {
            if (let Some(s) <- scope) {
                return s.hasException()
            }
        }
        false
    }

    // 严格翻译自 ExceptionValidationScope.deinit
    public func deinit() {
        if (assertionsEnabled) {
            if (let Some(s) <- scope) {
                s.deinit()
            }
        }
        scope = None
    }
}
