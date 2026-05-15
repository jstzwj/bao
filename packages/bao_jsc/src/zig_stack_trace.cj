// 严格翻译自: src/jsc/ZigStackTrace.zig (151行)
// JavaScript 堆栈追踪表示

package bao_jsc

// ========== ZigStackTrace ==========
// 严格翻译自 ZigStackTrace.zig ZigStackTrace
// 表示 JavaScript 堆栈追踪
public class ZigStackTrace {
    // 源代码行指针 (引用外部数组)
    public var sourceLinesPtr: Array<String> = []
    // 源代码行号数组
    public var sourceLineNumbers: Array<Int64> = []
    // 源代码行长度
    public var sourceLinesLen: Int64 = 0
    // 需要收集的源代码行数
    public var sourceLinesToCollect: Int64 = 0

    // 堆栈帧指针 (引用外部数组)
    public var framesPtr: Array<ZigStackFrame> = []
    // 帧数量
    public var framesLen: Int64 = 0
    // 帧容量
    public var framesCap: Int64 = 0

    // 非空时表示 source_lines_* 指向 JSC::SourceProvider 所拥有的数据
    // 如果如此，则需调用 .deref 释放内存
    public var referencedSourceProvider: ?SourceProvider = None

    // 便捷属性: 帧数组
    // 严格翻译自 ZigStackTrace.frames (getter)
    public var frames: Array<ZigStackFrame> {
        get() {
            if (framesPtr.size == 0) {
                return []
            }
            let len = if (framesLen <= Int64(framesPtr.size)) { Int64(framesLen) } else { Int64(framesPtr.size) }
            framesPtr.slice(0, len)
        }
        set(v) {
            framesPtr = v
            framesLen = Int64(v.size)
            framesCap = Int64(v.size)
        }
    }

    public init() {}

    public init(
        sourceLinesPtr: Array<String>,
        sourceLineNumbers: Array<Int64>,
        sourceLinesLen: Int64,
        sourceLinesToCollect: Int64,
        framesPtr: Array<ZigStackFrame>,
        framesLen: Int64,
        framesCap: Int64
    ) {
        this.sourceLinesPtr = sourceLinesPtr
        this.sourceLineNumbers = sourceLineNumbers
        this.sourceLinesLen = sourceLinesLen
        this.sourceLinesToCollect = sourceLinesToCollect
        this.framesPtr = framesPtr
        this.framesLen = framesLen
        this.framesCap = framesCap
    }

    // 严格翻译自 ZigStackTrace.fromFrames
    // 从帧切片创建堆栈追踪
    public static func fromFrames(framesSlice: Array<ZigStackFrame>) -> ZigStackTrace {
        ZigStackTrace(
            sourceLinesPtr: [],
            sourceLineNumbers: [],
            sourceLinesLen: 0,
            sourceLinesToCollect: 0,
            framesPtr: framesSlice,
            framesLen: Int64(framesSlice.size),
            framesCap: Int64(framesSlice.size)
        )
    }

    // 严格翻译自 ZigStackTrace.toAPI
    // 转为 API 格式的堆栈追踪
    public func toAPI(rootPath: String, origin: ?String) -> StackTraceApi {
        let trace = StackTraceApi()

        // 源代码行
        let sourceLineIter = sourceLineIterator()
        let sourceLineLen = sourceLineIter.getLength()
        if (sourceLineLen > 0) {
            var sourceLines: Array<SourceLineApi> = []
            var iter = sourceLineIterator()
            while (true) {
                if (let Some(source) <- iter.next()) {
                    let sl = SourceLineApi()
                    sl.text = source.text
                    sl.line = source.line
                    sourceLines.append(sl)
                } else {
                    break
                }
            }
            trace.sourceLines = sourceLines
        }

        // 堆栈帧
        let frames_ = frames
        if (frames_.size > 0) {
            var stackFrames: Array<StackFrameApi> = []
            for (frame in frames_) {
                stackFrames.append(frame.toAPI(rootPath, origin))
            }
            trace.frames = stackFrames
        }

        trace
    }

    // 严格翻译自 ZigStackTrace.framesMutable
    // 获取可变的帧切片
    public func framesMutable() -> Array<ZigStackFrame> {
        if (framesPtr.size == 0) {
            return []
        }
        let len = if (framesLen <= Int64(framesPtr.size)) { Int64(framesLen) } else { Int64(framesPtr.size) }
        framesPtr.slice(0, len)
    }

    // ========== SourceLineIterator ==========
    // 严格翻译自 ZigStackTrace.SourceLineIterator
    public class SourceLineIterator {
        public var trace: ZigStackTrace
        public var i: Int64

        public init(trace: ZigStackTrace, i: Int64) {
            this.trace = trace
            this.i = i
        }

        // 严格翻译自 SourceLineIterator.getLength
        public func getLength() -> Int64 {
            var count: Int64 = 0
            let end = if (i + 1 >= 0) { i + 1 } else { 0 }
            let len = if (end <= Int64(trace.sourceLinesPtr.size)) { end } else { Int64(trace.sourceLinesPtr.size) }
            for (j in 0..len) {
                count += Int64(trace.sourceLinesPtr[Int64(j)].size)
            }
            count
        }

        // 严格翻译自 SourceLineIterator.untilLast
        public func untilLast() -> ?SourceLine {
            if (i < 1) { return None }
            next()
        }

        // 严格翻译自 SourceLineIterator.next
        public func next() -> ?SourceLine {
            if (i < 0) { return None }
            let idx = Int64(i)
            if (idx >= Int64(trace.sourceLinesPtr.size)) { return None }
            let sourceLine = trace.sourceLinesPtr[idx]
            let lineNum = if (idx < Int64(trace.sourceLineNumbers.size)) {
                trace.sourceLineNumbers[idx]
            } else {
                -1
            }
            let result = SourceLine(line: lineNum, text: sourceLine)
            i--
            Some(result)
        }
    }

    // ========== SourceLine ==========
    // 严格翻译自 ZigStackTrace.SourceLineIterator.SourceLine
    public class SourceLine {
        public var line: Int64
        public var text: String

        public init(line: Int64, text: String) {
            this.line = line
            this.text = text
        }
    }

    // 严格翻译自 ZigStackTrace.sourceLineIterator
    public func sourceLineIterator() -> SourceLineIterator {
        var i: Int64 = -1
        let len = if (sourceLinesLen <= Int64(sourceLineNumbers.size)) { Int64(sourceLinesLen) } else { Int64(sourceLineNumbers.size) }
        for (j in 0..len) {
            let num = sourceLineNumbers[Int64(j)]
            if (num >= 0) {
                i = if (Int64(j) > i) { Int64(j) } else { i }
            }
        }
        SourceLineIterator(trace: this, i: i)
    }
}

// ========== SourceProvider ==========
// 严格翻译自 JSC SourceProvider 引用
public class SourceProvider {
    public var isValid: Bool = true

    public init() {}

    public func deref() {
        isValid = false
    }
}
