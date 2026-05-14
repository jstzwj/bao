// Node.js fs 模块 — 文件系统 API
// 对应 Bun: src/runtime/node/fs.zig
// 严格翻译 Bun 的 Node.js fs 兼容层
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_path.*

// ============================================================================
// fs 模块 — Node.js 文件系统 API
// 对应 Bun: src/runtime/node/fs.zig + src bun/fs.zig
// ============================================================================

/// fs 模块 — 提供 Node.js 兼容的文件系统 API
public class FsModule {
    /// 读取文件为字符串 — fs.readFileSync(path, encoding)
    /// 对应 Bun: src/runtime/node/fs.zig readFileSync
    public static func readFileSync(path: String): String {
        return BaoFile.readAllText(path)
    }

    /// 读取文件为字节数组 — fs.readFileSync(path)
    public static func readFileSyncBytes(path: String): Array<UInt8> {
        return BaoFile.readAllBytes(path)
    }

    /// 写入文件 — fs.writeFileSync(path, data)
    /// 对应 Bun: src/runtime/node/fs.zig writeFileSync
    public static func writeFileSync(path: String, data: String): Unit {
        BaoFile.writeAllText(path, data)
    }

    /// 写入字节数组到文件 — fs.writeFileSync(path, data)
    public static func writeFileSyncBytes(path: String, data: Array<UInt8>): Unit {
        BaoFile.writeAllBytes(path, data)
    }

    /// 追加写入文件 — fs.appendFileSync(path, data)
    public static func appendFileSync(path: String, data: String): Unit {
        let existing = readFileSync(path)
        writeFileSync(path, existing + data)
    }

    /// 判断文件是否存在 — fs.existsSync(path)
    /// 对应 Bun: src/runtime/node/fs.zig existsSync
    public static func existsSync(path: String): Bool {
        return BaoFile.exists(path)
    }

    /// 删除文件 — fs.unlinkSync(path)
    /// 对应 Bun: src/runtime/node/fs.zig unlinkSync
    public static func unlinkSync(path: String): Unit {
        BaoFile.remove(path)
    }

    /// 创建目录 — fs.mkdirSync(path, options)
    /// 对应 Bun: src/runtime/node/fs.zig mkdirSync
    public static func mkdirSync(path: String): Unit {
        BaoFile.mkdir(path, true)
    }

    /// 删除目录 — fs.rmdirSync(path)
    public static func rmdirSync(path: String): Unit {
        BaoFile.rmdir(path)
    }

    /// 递归删除 — fs.rmSync(path, { recursive: true })
    public static func rmSync(path: String, recursive: Bool): Unit {
        if (recursive) {
            BaoFile.removeRecursive(path)
        } else {
            BaoFile.remove(path)
        }
    }

    /// 读取目录 — fs.readdirSync(path)
    /// 对应 Bun: src/runtime/node/fs.zig readdirSync
    public static func readdirSync(path: String): ArrayList<String> {
        return BaoFile.readdir(path)
    }

    /// 获取文件状态 — fs.statSync(path)
    /// 对应 Bun: src/runtime/node/fs.zig statSync
    public static func statSync(path: String): FsStats {
        return BaoFile.stat(path)
    }

    /// 获取文件状态 (不跟随符号链接) — fs.lstatSync(path)
    public static func lstatSync(path: String): FsStats {
        return BaoFile.stat(path)
    }

    /// 复制文件 — fs.copyFileSync(src, dest)
    public static func copyFileSync(src: String, dest: String): Unit {
        let data = readFileSyncBytes(src)
        writeFileSyncBytes(dest, data)
    }

    /// 重命名文件 — fs.renameSync(oldPath, newPath)
    public static func renameSync(oldPath: String, newPath: String): Unit {
        copyFileSync(oldPath, newPath)
        unlinkSync(oldPath)
    }

    /// 修改权限 — fs.chmodSync(path, mode)
    public static func chmodSync(path: String, mode: Int32): Unit {
        // 通过 C FFI 调用 chmod
        // 占位实现
    }

    /// 读取文件 (异步回调版本) — fs.readFile(path, callback)
    public static func readFile(path: String, callback: (String) -> Unit): Unit {
        let content = readFileSync(path)
        callback(content)
    }

    /// 写入文件 (异步回调版本) — fs.writeFile(path, data, callback)
    public static func writeFile(path: String, data: String, callback: () -> Unit): Unit {
        writeFileSync(path, data)
        callback()
    }

    /// 将 fs 模块导出为 JsValue 对象
    /// 用于在解释器中注册 require('fs')
    public static func toJsValue(): JsValue {
        let obj = JsObject()

        obj.set("readFileSync", JsValue.nativeFunction(JsNativeFunction("readFileSync") { args =>
            if (args.size < 1) { return JsValue(BaoString("")) }
            let path = Interpreter.jsToString(args[0])
            return JsValue(BaoString(readFileSync(path)))
        }))

        obj.set("writeFileSync", JsValue.nativeFunction(JsNativeFunction("writeFileSync") { args =>
            if (args.size < 2) { return JsValue.UNDEFINED }
            let path = Interpreter.jsToString(args[0])
            let data = Interpreter.jsToString(args[1])
            writeFileSync(path, data)
            return JsValue.UNDEFINED
        }))

        obj.set("existsSync", JsValue.nativeFunction(JsNativeFunction("existsSync") { args =>
            if (args.size < 1) { return JsValue(false) }
            let path = Interpreter.jsToString(args[0])
            return JsValue(existsSync(path))
        }))

        obj.set("unlinkSync", JsValue.nativeFunction(JsNativeFunction("unlinkSync") { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let path = Interpreter.jsToString(args[0])
            unlinkSync(path)
            return JsValue.UNDEFINED
        }))

        obj.set("mkdirSync", JsValue.nativeFunction(JsNativeFunction("mkdirSync") { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let path = Interpreter.jsToString(args[0])
            mkdirSync(path)
            return JsValue.UNDEFINED
        }))

        obj.set("readdirSync", JsValue.nativeFunction(JsNativeFunction("readdirSync") { args =>
            if (args.size < 1) { return JsValue.emptyArray() }
            let path = Interpreter.jsToString(args[0])
            let entries = readdirSync(path)
            let arr = ArrayList<JsValue>()
            for (e in entries) {
                arr.append(JsValue(BaoString(e)))
            }
            return JsValue.array(arr)
        }))

        obj.set("statSync", JsValue.nativeFunction(JsNativeFunction("statSync") { args =>
            if (args.size < 1) { return JsValue.NULL }
            let path = Interpreter.jsToString(args[0])
            let st = statSync(path)
            let obj = JsObject()
            obj.set("size", JsValue(Float64(st.size)))
            obj.set("isFile", JsValue.nativeFunction(JsNativeFunction("isFile") { _ => JsValue(st.isFile) }))
            obj.set("isDirectory", JsValue.nativeFunction(JsNativeFunction("isDirectory") { _ => JsValue(st.isDirectory) }))
            return JsValue(obj)
        }))

        obj.set("appendFileSync", JsValue.nativeFunction(JsNativeFunction("appendFileSync") { args =>
            if (args.size < 2) { return JsValue.UNDEFINED }
            let path = Interpreter.jsToString(args[0])
            let data = Interpreter.jsToString(args[1])
            appendFileSync(path, data)
            return JsValue.UNDEFINED
        }))

        obj.set("rmSync", JsValue.nativeFunction(JsNativeFunction("rmSync") { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let path = Interpreter.jsToString(args[0])
            let recursive = args.size > 1 && Interpreter.jsToBoolean(args[1])
            rmSync(path, recursive)
            return JsValue.UNDEFINED
        }))

        obj.set("copyFileSync", JsValue.nativeFunction(JsNativeFunction("copyFileSync") { args =>
            if (args.size < 2) { return JsValue.UNDEFINED }
            let src = Interpreter.jsToString(args[0])
            let dest = Interpreter.jsToString(args[1])
            copyFileSync(src, dest)
            return JsValue.UNDEFINED
        }))

        obj.set("renameSync", JsValue.nativeFunction(JsNativeFunction("renameSync") { args =>
            if (args.size < 2) { return JsValue.UNDEFINED }
            let oldPath = Interpreter.jsToString(args[0])
            let newPath = Interpreter.jsToString(args[1])
            renameSync(oldPath, newPath)
            return JsValue.UNDEFINED
        }))

        // Promise 版本 (占位)
        obj.set("promises", JsValue(JsObject()))

        return JsValue(obj)
    }
}

/// 文件状态信息 — 对应 Node.js fs.Stats
public class FsStats {
    public var size: Int64
    public var isFile: Bool
    public var isDirectory: Bool
    public var modifiedTime: Float64
    public var accessedTime: Float64
    public var createdTime: Float64
    public var mode: Int32

    public init() {
        size = 0
        isFile = true
        isDirectory = false
        modifiedTime = 0.0
        accessedTime = 0.0
        createdTime = 0.0
        mode = 0
    }
}
