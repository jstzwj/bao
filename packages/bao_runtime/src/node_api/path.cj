// Node.js path 模块 — 路径操作 API
// 对应 Bun: src/runtime/node/path.zig
// 严格翻译 Bun 的 Node.js path 兼容层
package bao_runtime

import bao_core.*
import bao_path.*

// ============================================================================
// path 模块 — Node.js 路径操作 API
// 对应 Bun: src/runtime/node/path.zig
// ============================================================================

/// path 模块 — 提供 Node.js 兼容的路径操作 API
public class PathModule {
    /// 路径分隔符
    public static let sep: String = "/"
    /// 分隔符 (Windows 兼容)
    public static let delimiter: String = ":"

    /// path.join([...paths]) — 拼接路径
    /// 对应 Bun: path.join
    public static func join(paths: ArrayList<String>): String {
        var result = StringBuilder()
        for (i in 0..paths.size) {
            if (i > 0 && !paths[i].startsWith("/")) {
                result.append("/")
            }
            result.append(paths[i])
        }
        return normalize(result.toString())
    }

    /// path.resolve([...paths]) — 解析为绝对路径
    /// 对应 Bun: path.resolve
    public static func resolve(paths: ArrayList<String>): String {
        if (paths.size == 0) {
            return BaoPath.cwd()
        }
        var result = paths[paths.size - 1]
        if (!result.startsWith("/")) {
            result = BaoPath.cwd() + "/" + result
        }
        return normalize(result)
    }

    /// path.normalize(p) — 规范化路径
    /// 对应 Bun: path.normalize
    public static func normalize(p: String): String {
        if (p.length == 0) { return "." }
        let parts = p.split("/")
        let result = ArrayList<String>()
        for (part in parts) {
            if (part.length == 0 || part == ".") {
                continue
            }
            if (part == "..") {
                if (result.size > 0 && result[result.size - 1] != "..") {
                    result.removeAt(result.size - 1)
                } else if (!p.startsWith("/")) {
                    result.append("..")
                }
            } else {
                result.append(part)
            }
        }
        if (result.size == 0) {
            return if (p.startsWith("/")) { "/" } else { "." }
        }
        let sb = StringBuilder()
        if (p.startsWith("/")) { sb.append("/") }
        for (i in 0..result.size) {
            if (i > 0) { sb.append("/") }
            sb.append(result[i])
        }
        return sb.toString()
    }

    /// path.dirname(p) — 获取目录名
    /// 对应 Bun: path.dirname
    public static func dirname(p: String): String {
        let normalized = normalize(p)
        let idx = normalized.lastIndexOf("/")
        if (idx < 0) { return "." }
        if (idx == 0) { return "/" }
        return normalized.substring(0, idx)
    }

    /// path.basename(p, ext?) — 获取文件名
    /// 对应 Bun: path.basename
    public static func basename(p: String): String {
        let normalized = normalize(p)
        let idx = normalized.lastIndexOf("/")
        if (idx < 0) { return normalized }
        return normalized.substring(idx + 1)
    }

    /// path.basename(p, ext) — 获取文件名 (去除扩展名)
    public static func basename(p: String, ext: String): String {
        let name = basename(p)
        if (name.length > ext.length && name.endsWith(ext)) {
            return name.substring(0, name.length - ext.length)
        }
        return name
    }

    /// path.extname(p) — 获取扩展名
    /// 对应 Bun: path.extname
    public static func extname(p: String): String {
        let name = basename(p)
        let idx = name.lastIndexOf(".")
        if (idx <= 0) { return "" }
        return name.substring(idx)
    }

    /// path.relative(from, to) — 获取相对路径
    /// 对应 Bun: path.relative
    public static func relative(from: String, to: String): String {
        let fromResolved = resolve(ArrayList<String>([from]))
        let toResolved = resolve(ArrayList<String>([to]))
        if (fromResolved == toResolved) { return "" }

        let fromParts = fromResolved.split("/")
        let toParts = toResolved.split("/")
        var commonLength = 0
        let minLen = if (fromParts.size < toParts.size) { fromParts.size } else { toParts.size }
        while (commonLength < minLen && fromParts[commonLength] == toParts[commonLength]) {
            commonLength++
        }

        let sb = StringBuilder()
        for (i in commonLength..fromParts.size) {
            if (sb.length > 0) { sb.append("/") }
            sb.append("..")
        }
        for (i in commonLength..toParts.size) {
            if (sb.length > 0) { sb.append("/") }
            sb.append(toParts[i])
        }
        return sb.toString()
    }

    /// path.isAbsolute(p) — 判断是否为绝对路径
    /// 对应 Bun: path.isAbsolute
    public static func isAbsolute(p: String): Bool {
        return p.startsWith("/") || p.startsWith("~")
    }

    /// path.parse(p) — 解析路径为对象
    /// 对应 Bun: path.parse
    public static func parse(p: String): PathObject {
        let obj = PathObject()
        obj.root = if (p.startsWith("/")) { "/" } else { "" }
        obj.dir = dirname(p)
        obj.base = basename(p)
        obj.ext = extname(p)
        let nameWithoutExt = basename(p)
        let dotIdx = nameWithoutExt.lastIndexOf(".")
        obj.name = if (dotIdx > 0) { nameWithoutExt.substring(0, dotIdx) } else { nameWithoutExt }
        return obj
    }

    /// path.format(pathObject) — 从对象生成路径
    /// 对应 Bun: path.format
    public static func format(obj: PathObject): String {
        var result = obj.dir
        if (result.length > 0 && !result.endsWith("/")) {
            result = result + "/"
        }
        result = result + obj.base
        return result
    }

    /// 将 path 模块导出为 JsValue 对象
    public static func toJsValue(): JsValue {
        let obj = JsObject()

        obj.set("join", JsValue.nativeFunction(JsNativeFunction("join") { args =>
            let paths = ArrayList<String>()
            for (arg in args) {
                paths.append(Interpreter.jsToString(arg))
            }
            return JsValue(BaoString(join(paths)))
        }))

        obj.set("resolve", JsValue.nativeFunction(JsNativeFunction("resolve") { args =>
            let paths = ArrayList<String>()
            for (arg in args) {
                paths.append(Interpreter.jsToString(arg))
            }
            return JsValue(BaoString(resolve(paths)))
        }))

        obj.set("normalize", JsValue.nativeFunction(JsNativeFunction("normalize") { args =>
            if (args.size < 1) { return JsValue(BaoString(".")) }
            return JsValue(BaoString(normalize(Interpreter.jsToString(args[0]))))
        }))

        obj.set("dirname", JsValue.nativeFunction(JsNativeFunction("dirname") { args =>
            if (args.size < 1) { return JsValue(BaoString(".")) }
            return JsValue(BaoString(dirname(Interpreter.jsToString(args[0]))))
        }))

        obj.set("basename", JsValue.nativeFunction(JsNativeFunction("basename") { args =>
            if (args.size < 1) { return JsValue(BaoString("")) }
            let p = Interpreter.jsToString(args[0])
            if (args.size > 1) {
                return JsValue(BaoString(basename(p, Interpreter.jsToString(args[1]))))
            }
            return JsValue(BaoString(basename(p)))
        }))

        obj.set("extname", JsValue.nativeFunction(JsNativeFunction("extname") { args =>
            if (args.size < 1) { return JsValue(BaoString("")) }
            return JsValue(BaoString(extname(Interpreter.jsToString(args[0]))))
        }))

        obj.set("relative", JsValue.nativeFunction(JsNativeFunction("relative") { args =>
            if (args.size < 2) { return JsValue(BaoString("")) }
            return JsValue(BaoString(relative(Interpreter.jsToString(args[0]), Interpreter.jsToString(args[1]))))
        }))

        obj.set("isAbsolute", JsValue.nativeFunction(JsNativeFunction("isAbsolute") { args =>
            if (args.size < 1) { return JsValue(false) }
            return JsValue(isAbsolute(Interpreter.jsToString(args[0])))
        }))

        obj.set("sep", JsValue(BaoString(sep)))
        obj.set("delimiter", JsValue(BaoString(delimiter)))

        return JsValue(obj)
    }
}

/// 路径解析结果 — 对应 Node.js path.parse() 返回的对象
public class PathObject {
    public var root: String
    public var dir: String
    public var base: String
    public var ext: String
    public var name: String

    public init() {
        root = ""
        dir = ""
        base = ""
        ext = ""
        name = ""
    }
}
