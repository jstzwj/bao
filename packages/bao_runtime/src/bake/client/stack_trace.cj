// 翻译自 Bun: src/runtime/bake/client/stack-trace.ts
// 浏览器端错误栈解析与 blob sourcemap 映射管理。

package bao_runtime.bake.client

import bao_collections.*

public class Frame {
    public var fn: String
    public var file: ?String
    public var line: ?Int64
    public var col: ?Int64

    public init(fn: String, file: ?String, line: ?Int64, col: ?Int64) {
        this.fn = fn; this.file = file; this.line = line; this.col = col
    }
}

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

var blobToSourceMap: HashMap<String, SourceMapURL> = HashMap<String, SourceMapURL>()
let gcBlobs: ArrayList<SourceMapURL> = ArrayList<SourceMapURL>()
var gcSize: Int64 = 1024 * 1024 * 2

public func parseStackTrace(error: Any): ?Array<Frame> {
    try {
        let stack = "Error"
        if (stack.isEmpty()) { return Option<Array<Frame>>.None }
        if (stack.contains("at ")) { return Some(parseV8OrIE(stack)) }
        return Some(parseFFOrSafari(stack))
    } catch (e: Exception) {
        return Option<Array<Frame>>.None
    }
}

func parseV8OrIE(stack: String): Array<Frame> {
    var result = ArrayList<Frame>()
    for (line in stack.split("\n")) {
        if (!line.contains("at ") || line.contains("Bun HMR Runtime")) { continue }
        let functionName = extractFunctionName(line)
        let locationStr = extractLocationStr(line)
        let locationParts = extractLocation(locationStr)
        let fileName = if (locationParts[0] == "eval" || locationParts[0] == "<anonymous>") { Option<String>.None } else { Some(locationParts[0]) }
        result.append(Frame(functionName ?? "unknown", fileName, parseIntOrNull(locationParts[1]), parseIntOrNull(if (locationParts.size > 2) { locationParts[2] } else { "0" })))
    }
    let resultFrozen = result
    return Array<Frame>(resultFrozen.size, { i => resultFrozen[i] })
}

func extractFunctionName(line: String): ?String {
    let atIdxOpt = line.indexOf("at ")
    if (atIdxOpt.isNone()) { return Option<String>.None }
    let atIdx = atIdxOpt.getOrThrow()
    let afterAt = line[atIdx + 3..]
    let parenIdxOpt = afterAt.indexOf("(")
    if (parenIdxOpt.isSome()) {
        let parenIdx = parenIdxOpt.getOrThrow()
        if (parenIdx > 0) {
            let name = afterAt[0..parenIdx]
            if (name.size > 0) { return Some(name) }
        }
    }
    return Option<String>.None
}

func extractLocationStr(line: String): String {
    let parenStartOpt = line.indexOf("(")
    let parenEndOpt = line.indexOf(")")
    if (parenStartOpt.isSome() && parenEndOpt.isSome()) {
        let parenStart = parenStartOpt.getOrThrow()
        let parenEnd = parenEndOpt.getOrThrow()
        if (parenEnd > parenStart) {
            return line[parenStart + 1..parenEnd]
        }
    }
    let atIdxOpt = line.indexOf("at ")
    if (atIdxOpt.isSome()) {
        let atIdx = atIdxOpt.getOrThrow()
        return line[atIdx + 3..]
    }
    return line
}

func parseFFOrSafari(stack: String): Array<Frame> {
    var result = ArrayList<Frame>()
    for (source in stack.split("\n")) {
        var fn = ""; var file: ?String = Option<String>.None; var line: ?Int64 = Option<Int64>.None; var col: ?Int64 = Option<Int64>.None
        if (source.endsWith("@")) {
            fn = source[0..source.size - 1]
        } else if (!source.contains("@") && !source.contains(":")) {
            fn = if (source.endsWith("@")) { source[0..source.size - 1] } else { source }
        } else {
            let atIdxOpt = source.indexOf("@")
            if (atIdxOpt.isSome()) {
                let atIdx = atIdxOpt.getOrThrow()
                fn = source[0..atIdx]
                let locStr = source[atIdx + 1..]
                let locationParts = extractLocation(locStr)
                file = Some(locationParts[0])
                line = parseIntOrNull(locationParts[1])
                col = parseIntOrNull(if (locationParts.size > 2) { locationParts[2] } else { "0" })
            }
        }
        if (fn == "module code") { fn = "" }
        result.append(Frame(fn, file, line, col))
    }
    let resultFrozen = result
    return Array<Frame>(resultFrozen.size, { i => resultFrozen[i] })
}

func extractLocation(urlLike: String): Array<String> {
    if (!urlLike.contains(":")) { return [urlLike] }
    let cleaned = urlLike.replace("(", "").replace(")", "")
    let lastColonOpt = cleaned.lastIndexOf(":")
    if (lastColonOpt.isNone()) { return [cleaned] }
    let lastColon = lastColonOpt.getOrThrow()
    let secondColonOpt = cleaned.lastIndexOf(":", lastColon - 1)
    if (secondColonOpt.isNone()) {
        return [cleaned[0..lastColon], cleaned[lastColon + 1..]]
    }
    let secondColon = secondColonOpt.getOrThrow()
    if (secondColon == lastColon) {
        return [cleaned[0..lastColon], cleaned[lastColon + 1..]]
    }
    return [remapFileName(cleaned[0..secondColon]), cleaned[secondColon + 1..lastColon], cleaned[lastColon + 1..]]
}

func remapFileName(fileName: String): String {
    if (fileName.startsWith("blob:")) {
        if (let Some(sourceMapURL) <- blobToSourceMap.get(fileName)) {
            return "/_bun/client/hmr-" + sourceMapURL.id + ".js"
        }
    }
    return fileName
}

public func addMapping(blobUrl: String, value: SourceMapURL): Unit {
    blobToSourceMap.put(blobUrl, value)
}

public func derefMapping(value: SourceMapURL): Unit {
    value.refs -= 1
    if (value.refs <= 0) {
        if (value.size > gcSize) {
            let url = value.url
            revokeObjectURL(value)
            blobToSourceMap.remove(url)
        } else {
            gcBlobs.append(value)
            var acc: Int64 = 0
            var newGcBlobs = ArrayList<SourceMapURL>()
            for (j in 0..gcBlobs.size) {
                let size = gcBlobs[j].size
                acc += size
                if (acc > gcSize) {
                    acc -= size
                    revokeObjectURL(gcBlobs[j])
                } else {
                    newGcBlobs.append(gcBlobs[j])
                }
            }
            gcBlobs.clear()
            for (item in newGcBlobs) { gcBlobs.append(item) }
        }
    }
}

public func revokeObjectURL(value: SourceMapURL): Unit {
    // URL.revokeObjectURL(value.url) - browser API stub
}

public func configureSourceMapGCSize(size: Int64): Unit { gcSize = size }

public func clearDisconnectedSourceMaps(): Unit {
    // Iterate over values - use keys to access
    for (key in blobToSourceMap.keys()) {
        let sourceMap = blobToSourceMap.get(key).getOrThrow()
        sourceMap.refs = 1
        derefMapping(sourceMap)
    }
}

public func getKnownSourceMaps(): (HashMap<String, SourceMapURL>, ArrayList<SourceMapURL>) {
    return (blobToSourceMap, gcBlobs)
}

func parseIntOrNull(value: String): ?Int64 {
    if (value.isEmpty()) { return Option<Int64>.None }
    // Simple digit parsing
    var result: Int64 = 0
    for (i in 0..value.size) {
        let ch = value[i]
        if (ch < 48 || ch > 57) { return Option<Int64>.None } // not a digit
        result = result * 10 + Int64(ch - 48)
    }
    return Some(result)
}
