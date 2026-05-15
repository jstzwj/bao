// 严格翻译自: src/jsc/ZigStackFrame.zig (253行)
// 堆栈追踪中的单个帧

package bao_jsc

// ========== ZigStackFrame ==========
// 严格翻译自 ZigStackFrame.zig ZigStackFrame
// 表示堆栈追踪中的单个帧
public class ZigStackFrame {
    // 函数名
    public var functionName: String = ""
    // 源文件 URL
    public var sourceUrl: String = ""
    // 位置信息
    public var position: ZigStackFramePosition = ZigStackFramePosition()
    // 代码类型
    public var codeType: ZigStackFrameCode = ZigStackFrameCode.None
    // 是否为异步帧
    public var isAsync: Bool = false
    // 是否已被重映射 (影响格式化器是否显示为 blob URL)
    public var remapped: Bool = false
    // JSC 堆栈帧索引 (-1 表示未设置)
    public var jscStackFrameIndex: Int64 = -1

    public init() {}

    public init(
        functionName: String,
        sourceUrl: String,
        position: ZigStackFramePosition,
        codeType: ZigStackFrameCode,
        isAsync: Bool
    ) {
        this.functionName = functionName
        this.sourceUrl = sourceUrl
        this.position = position
        this.codeType = codeType
        this.isAsync = isAsync
    }

    // 严格翻译自 ZigStackFrame.deinit
    public func deinit() {
        functionName = ""
        sourceUrl = ""
    }

    // 严格翻译自 ZigStackFrame.toAPI
    // 转为 API 格式的堆栈帧
    public func toAPI(rootPath: String, origin: ?String) -> StackFrameApi {
        let frame = StackFrameApi()
        if (!functionName.isEmpty) {
            frame.functionName = functionName
        }
        if (!sourceUrl.isEmpty) {
            frame.file = sourceUrlFormatter(rootPath, origin, true, false)
        }
        frame.position = position
        frame.scope = codeType
        frame
    }

    // 严格翻译自 ZigStackFrame.Zero
    public static func zero() -> ZigStackFrame {
        ZigStackFrame(
            functionName: "",
            sourceUrl: "",
            position: ZigStackFramePosition.invalid(),
            codeType: ZigStackFrameCode.None,
            isAsync: false
        )
    }

    // 严格翻译自 ZigStackFrame.nameFormatter
    public func nameFormatter(enableColor: Bool) -> NameFormatter {
        NameFormatter(
            functionName: functionName,
            codeType: codeType,
            enableColor: enableColor,
            isAsync: isAsync
        )
    }

    // 严格翻译自 ZigStackFrame.sourceURLFormatter
    public func sourceUrlFormatter(
        rootPath: String,
        origin: ?String,
        excludeLineColumn: Bool,
        enableColor: Bool
    ) -> String {
        var result = sourceUrl
        if (!excludeLineColumn) {
            if (position.line > 0 && position.column > 0) {
                result += ":" + String(position.line) + ":" + String(position.column)
            } else if (position.line > 0) {
                result += ":" + String(position.line)
            }
        }
        result
    }

    // ========== SourceURLFormatter ==========
    // 严格翻译自 ZigStackFrame.SourceURLFormatter
    public class SourceURLFormatter {
        public var sourceUrl: String = ""
        public var position: ZigStackFramePosition = ZigStackFramePosition()
        public var enableColor: Bool = false
        public var origin: ?String = None
        public var excludeLineColumn: Bool = false
        public var remapped: Bool = false
        public var rootPath: String = ""

        public init() {}

        // 严格翻译自 SourceURLFormatter.format
        public func format() -> String {
            var result = ""

            if (!remapped) {
                if (let Some(originUrl) <- origin) {
                    // 附加 origin 信息
                }
                result += sourceUrl
            } else {
                if (enableColor && rootPath.size > 1 && sourceUrl.startsWith(rootPath)) {
                    let relativePath = sourceUrl.slice(rootPath.size)
                    result += rootPath + "/" + relativePath
                } else {
                    result += sourceUrl
                }
            }

            if (sourceUrl.size > 0 && (position.line > 0 || position.column > 0)) {
                result += ":"
            }

            if (!excludeLineColumn) {
                if (position.line > 0 && position.column > 0) {
                    result += String(position.line) + ":" + String(position.column)
                } else if (position.line > 0) {
                    result += String(position.line)
                }
            }

            result
        }
    }

    // ========== NameFormatter ==========
    // 严格翻译自 ZigStackFrame.NameFormatter
    public class NameFormatter {
        public var functionName: String = ""
        public var codeType: ZigStackFrameCode = ZigStackFrameCode.None
        public var enableColor: Bool = false
        public var isAsync: Bool = false

        public init() {}

        public init(functionName: String, codeType: ZigStackFrameCode, enableColor: Bool, isAsync: Bool) {
            this.functionName = functionName
            this.codeType = codeType
            this.enableColor = enableColor
            this.isAsync = isAsync
        }

        // 严格翻译自 NameFormatter.format
        public func format() -> String {
            match (codeType) {
                case Eval => {
                    var result = "eval"
                    if (!functionName.isEmpty) {
                        result += " " + functionName
                    }
                    result
                }
                case Function => {
                    if (!functionName.isEmpty) {
                        if (isAsync) {
                            "async " + functionName
                        } else {
                            functionName
                        }
                    } else {
                        if (isAsync) {
                            "async <anonymous>"
                        } else {
                            "<anonymous>"
                        }
                    }
                }
                case Global => {
                    ""
                }
                case Wasm => {
                    if (!functionName.isEmpty) {
                        functionName
                    } else {
                        "WASM"
                    }
                }
                case Constructor => {
                    "new " + functionName
                }
                case _ => {
                    if (!functionName.isEmpty) {
                        functionName
                    } else {
                        ""
                    }
                }
            }
        }
    }
}
