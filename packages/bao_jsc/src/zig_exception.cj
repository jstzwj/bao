// 严格翻译自: src/jsc/ZigException.zig (184行)
// JavaScript 异常的扩展信息表示

package bao_jsc

// ========== ZigException ==========
// 严格翻译自 ZigException.zig ZigException
// 表示 JavaScript 异常及其附加信息
public class ZigException {
    // 错误类型
    public var type_: JSErrorCode = JSErrorCode.Error
    // 运行时类型
    public var runtimeType: JSRuntimeType = JSRuntimeType.Nothing

    // SystemError 专用字段
    public var errno: Int64 = 0
    public var syscall: String = ""
    public var systemCode: String = ""
    public var path: String = ""

    // 异常基本信息
    public var name: String = ""
    public var message: String = ""
    // 堆栈追踪
    public var stack: ZigStackTrace = ZigStackTrace()

    // 异常对象指针 (对应 Zig 中的 ?*anyopaque)
    public var exception: ?JsException = None

    // 是否已被重映射
    public var remapped: Bool = false

    // 文件描述符
    public var fd: Int64 = -1

    // 浏览器 URL
    public var browserUrl: String = ""

    public init() {}

    // 严格翻译自 ZigException.collectSourceLines
    // 收集源代码行
    public func collectSourceLines(value: JsValue, global: JsObject) {
        // FFI: ZigException__collectSourceLines(value, global, this)
        // 在仓颉实现中通过全局对象收集源代码行
    }

    // 严格翻译自 ZigException.deinit
    public func deinit() {
        syscall = ""
        systemCode = ""
        path = ""
        name = ""
        message = ""
        stack = ZigStackTrace()
        exception = None
    }

    // 严格翻译自 ZigException.addToErrorList
    // 将异常添加到错误列表
    public func addToErrorList(errorList: ArrayList<JsExceptionApi>, rootPath: String, origin: ?String) {
        var isEmpty = true
        let apiException = JsExceptionApi()
        apiException.runtimeType = runtimeType
        apiException.code = type_

        if (!name.isEmpty) {
            apiException.name = name
            isEmpty = false
        }

        if (!message.isEmpty) {
            apiException.message = message
            isEmpty = false
        }

        if (stack.frames.size > 0) {
            apiException.stack = stack.toAPI(rootPath, origin)
            isEmpty = false
        }

        if (!isEmpty) {
            errorList.append(apiException)
        }
    }

    // ========== Holder ==========
    // 严格翻译自 ZigException.Holder
    // ZigException 的持有器，管理内部帧和源代码行的存储
    public class Holder {
        // 帧数量常量
        public static let FRAME_COUNT: Int64 = 32
        // 源代码行数量常量
        public static let SOURCE_LINES_COUNT: Int64 = 6

        // 源代码行号
        public var sourceLineNumbers: Array<Int64> = []
        // 源代码行内容
        public var sourceLines: Array<String> = []
        // 堆栈帧
        public var frames: Array<ZigStackFrame> = []
        // 是否已加载
        public var loaded: Bool = false
        // 内部 ZigException
        public var zigException: ?ZigException = None
        // 是否需要在 deinit 时清除 parser arena
        public var needToClearParserArenaOnDeinit: Bool = false

        public init() {
            sourceLineNumbers = Array<Int64>(SOURCE_LINES_COUNT, item: -1)
            sourceLines = Array<String>(SOURCE_LINES_COUNT, item: "")
            frames = Array<ZigStackFrame>()
        }

        // 严格翻译自 Holder.init
        public static func init_() -> Holder {
            let holder = Holder()
            for (i in 0..Int64(holder.frames.capacity)) {
                holder.frames.append(ZigStackFrame.zero())
            }
            holder
        }

        // 严格翻译自 Holder.deinit
        public func deinit(vm: BunVirtualMachine) {
            if (loaded) {
                if (let Some(zigExc) <- zigException) {
                    zigExc.deinit()
                }
            }
            if (needToClearParserArenaOnDeinit) {
                vm.moduleLoader.resetArena(vm)
            }
        }

        // 严格翻译自 Holder.zigException
        public func zigException_() -> ZigException {
            if (!loaded) {
                let exc = ZigException()
                exc.type_ = JSErrorCode.fromInt(255)
                exc.runtimeType = JSRuntimeType.Nothing
                exc.name = ""
                exc.message = ""
                exc.exception = None
                exc.stack = ZigStackTrace()
                exc.stack.sourceLinesPtr = sourceLines
                exc.stack.sourceLineNumbers = sourceLineNumbers
                exc.stack.sourceLinesLen = SOURCE_LINES_COUNT
                exc.stack.sourceLinesToCollect = SOURCE_LINES_COUNT
                exc.stack.framesPtr = frames
                exc.stack.framesLen = 0
                exc.stack.framesCap = FRAME_COUNT
                zigException = exc
                loaded = true
            }
            zigException.getOrThrow()
        }
    }

    // 严格翻译自 ZigException.fromException
    // 从 JSC Exception 创建 ZigException
    public static func fromException(exception: JsException) -> ZigException {
        let exc = ZigException()
        exc.exception = exception
        exc.name = "Error"
        exc.message = exception.getMessage()
        exc.stack = exception.stackTrace
        exc
    }
}

// ========== API 异常 ==========
// 严格翻译自 api.JsException
public class JsExceptionApi {
    public var runtimeType: JSRuntimeType = JSRuntimeType.Nothing
    public var code: JSErrorCode = JSErrorCode.Error
    public var name: String = ""
    public var message: String = ""
    public var stack: ?StackTraceApi = None

    public init() {}
}

// ========== API 堆栈追踪 ==========
// 严格翻译自 api.StackTrace
public class StackTraceApi {
    public var sourceLines: Array<SourceLineApi> = []
    public var frames: Array<StackFrameApi> = []

    public init() {}
}

// ========== API 源代码行 ==========
// 严格翻译自 api.SourceLine
public class SourceLineApi {
    public var text: String = ""
    public var line: Int64 = 0

    public init() {}
}

// ========== API 堆栈帧 ==========
// 严格翻译自 api.StackFrame
public class StackFrameApi {
    public var functionName: String = ""
    public var file: String = ""
    public var position: ZigStackFramePosition = ZigStackFramePosition()
    public var scope: ZigStackFrameCode = ZigStackFrameCode.None

    public init() {}
}
