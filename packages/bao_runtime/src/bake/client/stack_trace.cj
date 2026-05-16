// 翻译自 Bun: src/runtime/bake/client/stack-trace.ts
// 浏览器端错误栈解析与 blob sourcemap 映射管理。

package bao_runtime.bake.client

public class Frame {
    public var fn: String
    public var file: ?String
    public var line: ?Int64
    public var col: ?Int64

    public init(fn: String, file: ?String, line: ?Int64, col: ?Int64) {
        this.fn = fn; this.file = file; this.line = line; this.col = col
    }
}

let chromeIeStackRegexp = Regex("^\\s*at .*(\\S+:\\d+|\\(native\\))", multiline: true)
let locationRegexp = Regex("(.+?)(?::(\\d+))?(?::(\\d+))?$")

public class SourceMapURL {
    public var id: String
    public var url: String
    /// 从模块数开始。模块替换时递减；为 0 后可被 GC。
    public var refs: Int64
    /// 字节数。
    public var size: Int64

    public init(id: String, url: String, refs: Int64, size: Int64) {
        this.id = id; this.url = url; this.refs = refs; this.size = size
    }
}

let blobToSourceMap: Map<String, SourceMapURL> = Map<String, SourceMapURL>()
let gcBlobs: Array<SourceMapURL> = []
var gcSize: Int64 = 1024 * 1024 * 2

public func parseStackTrace(error: Any): ?Array<Frame> {
    if (let Some(stack) = error.stack as? String) {
        if (chromeIeStackRegexp.matches(stack)) { return Some(parseV8OrIE(stack)) }
        return Some(parseFFOrSafari(stack))
    }
    return None
}

func parseV8OrIE(stack: String): Array<Frame> {
    return stack.split("\n")
        .filter({ (line) => chromeIeStackRegexp.matches(line) && !line.contains("Bun HMR Runtime") })
        .map({ (line) =>
            var sanitizedLine = line.trimStart().replace(Regex("\\(eval code"), "(").replace(Regex("^.*?\\s+"), "")
            let loc = sanitizedLine.match(Regex(" (\\(.+\\)$)"))
            if (loc.isSome()) { sanitizedLine = sanitizedLine.replace(loc.get()[0], "") }
            let locationParts = extractLocation(if (loc.isSome()) { loc.get()[1] } else { sanitizedLine })
            let functionName = if (loc.isSome() && !sanitizedLine.isEmpty()) { Some(sanitizedLine) } else { None }
            let fileName = if (locationParts[0] == "eval" || locationParts[0] == "<anonymous>") { None } else { Some(locationParts[0]) }
            Frame(functionName ?? "unknown", fileName, parseIntOrNull(locationParts.getOrDefault(1, "0")), parseIntOrNull(locationParts.getOrDefault(2, "0")))
        })
}

func parseFFOrSafari(stack: String): Array<Frame> {
    return stack.split(Regex("\n")).map({ (source) =>
        var fn = ""; var file: ?String = None; var line: ?Int64 = None; var col: ?Int64 = None
        if (source.endsWith("@")) {
            fn = source.slice(0, source.length - 1)
        } else if (!source.contains("@") && !source.contains(":")) {
            fn = if (source.endsWith("@")) { source.slice(0, source.length - 1) } else { source }
        } else {
            let functionNameRegex = Regex("((.*\".+\"[^@]*)?[^@]*)(?:@)")
            let matches = source.match(functionNameRegex)
            let functionName = if (matches.isSome() && matches.get()[1].length > 0) { matches.get()[1] } else { "" }
            let locationParts = extractLocation(source.replace(functionNameRegex, ""))
            fn = functionName
            file = Some(locationParts[0])
            line = parseIntOrNull(locationParts.getOrDefault(1, "0"))
            col = parseIntOrNull(locationParts.getOrDefault(2, "0"))
        }
        if (fn == "module code") { fn = "" }
        Frame(fn, file, line, col)
    })
}

func extractLocation(urlLike: String): Array<String> {
    if (!urlLike.contains(":")) { return [urlLike] }
    let parts = locationRegexp.exec(urlLike.replace(Regex("[()]"), ""))
    return [remapFileName(parts[1]), parts.getOrDefault(2, ""), parts.getOrDefault(3, "")]
}

func remapFileName(fileName: String): String {
    if (fileName.startsWith("blob:")) {
        if (let Some(sourceMapURL) = blobToSourceMap.get(fileName)) {
            return location.origin + "/_bun/client/hmr-" + sourceMapURL.id + ".js"
        }
    }
    return fileName
}

public func addMapping(blobUrl: String, value: SourceMapURL): Unit {
    DEBUG.ASSERT(!blobToSourceMap.has(blobUrl))
    blobToSourceMap.set(blobUrl, value)
}

public func derefMapping(value: SourceMapURL): Unit {
    value.refs -= 1
    if (value.refs <= 0) {
        if (value.size > gcSize) {
            let url = value.url
            revokeObjectURL(value)
            blobToSourceMap.delete(url)
        } else {
            gcBlobs.append(value)
            var acc: Int64 = 0
            var i = gcBlobs.size - 1
            while (i >= 0) {
                let size = gcBlobs[i].size
                acc += size
                if (acc > gcSize) {
                    acc -= size
                    revokeObjectURL(gcBlobs[i])
                    gcBlobs.remove(at: i)
                }
                i -= 1
            }
        }
    }
}

public func revokeObjectURL(value: SourceMapURL): Unit {
    URL.revokeObjectURL(value.url)
}

public func configureSourceMapGCSize(size: Int64): Unit { gcSize = size }

public func clearDisconnectedSourceMaps(): Unit {
    for (sourceMap in blobToSourceMap.values()) {
        sourceMap.refs = 1
        derefMapping(sourceMap)
    }
}

public func getKnownSourceMaps(): (Map<String, SourceMapURL>, Array<SourceMapURL>) {
    return (blobToSourceMap, gcBlobs)
}

func parseIntOrNull(value: String): ?Int64 {
    if (value.isEmpty()) { return None }
    return Some(Int64.parse(value))
}
