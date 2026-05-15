// 严格翻译自: src/runtime/api/Archive.zig
package bao_runtime.api

import bao_jsc.*
import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*

// ============================================================================
// Archive - 归档文件(tar/tar.gz)支持
// 对应 Bun: src/runtime/api/Archive.zig
// ============================================================================

/// 压缩选项
public enum Compression {
    case none
    case gzip(GzipOptions)

    public class GzipOptions {
        public var level: UInt8 = 6 // 1 (最快) 到 12 (最大压缩)
    }
}

/// Archive 类 - 用于创建和提取归档文件
public class Archive {
    public var store: BlobStore
    public var compress: Compression = Compression.none

    // ========================================================================
    // 构造函数: new Archive(data, options?)
    // ========================================================================

    /// 构造函数 - 从 JS 参数创建 Archive
    public static func constructor(globalThis: JsGlobalObject, callframe: JsCallFrame): Archive {
        let (dataArg, optionsArg) = callframe.argumentsAsArray2()
        if (dataArg == JsValue.zero) {
            globalThis.throwInvalidArguments("new Archive() requires an argument")
            return Archive()
        }

        // 解析压缩选项
        let compress = try parseCompressionOptions(globalThis, optionsArg)

        // 对于 Blob/Archive, 引用现有 store (零拷贝)
        if (let blobPtr = dataArg.asBlob()) {
            if (let store = blobPtr.store) {
                store.ref()
                return Archive(store: store, compress: compress)
            }
        }

        // 对于 ArrayBuffer/TypedArray, 复制数据
        if (let arrayBuffer = dataArg.asArrayBuffer(globalThis)) {
            let data = try default_allocator.dupe(UInt8, arrayBuffer.slice())
            return createArchive(data, compress)
        }

        // 对于普通对象, 构建 tarball
        if (dataArg.isObject()) {
            let data = try buildTarballFromObject(globalThis, dataArg)
            return createArchive(data, compress)
        }

        globalThis.throwInvalidArguments("Expected an object, Blob, TypedArray, or ArrayBuffer")
        return Archive()
    }

    // ========================================================================
    // 压缩选项解析
    // ========================================================================

    /// 解析压缩选项
    public static func parseCompressionOptions(globalThis: JsGlobalObject, optionsArg: JsValue): Compression {
        if (optionsArg.isUndefinedOrNull()) {
            return Compression.none
        }

        if (!optionsArg.isObject()) {
            globalThis.throwInvalidArguments("Archive: options must be an object")
            return Compression.none
        }

        // 检查 compress 选项
        if (let compressVal = try optionsArg.getTruthy(globalThis, "compress")) {
            if (!compressVal.isString()) {
                globalThis.throwInvalidArguments("Archive: compress option must be a string")
                return Compression.none
            }

            let compressStr = try compressVal.toSlice(globalThis, default_allocator)
            defer compressStr.deinit()

            if (!compressStr.slice().eqlComptime("gzip")) {
                globalThis.throwInvalidArguments("Archive: compress option must be \"gzip\"")
                return Compression.none
            }

            // 解析 level 选项 (1-12, 默认 6)
            var level: UInt8 = 6
            if (let levelVal = try optionsArg.getTruthy(globalThis, "level")) {
                if (!levelVal.isNumber()) {
                    globalThis.throwInvalidArguments("Archive: level must be a number")
                    return Compression.none
                }
                let levelNum = levelVal.toInt64()
                if (levelNum < 1 || levelNum > 12) {
                    globalThis.throwInvalidArguments("Archive: level must be between 1 and 12")
                    return Compression.none
                }
                level = UInt8(levelNum)
            }

            return Compression.gzip(GzipOptions(level: level))
        }

        return Compression.none
    }

    /// 创建 Archive 实例
    public static func createArchive(data: Array<UInt8>, compress: Compression): Archive {
        let store = BlobStore.init(data, default_allocator)
        return Archive(store: store, compress: compress)
    }

    // ========================================================================
    // tarball 构建
    // ========================================================================

    /// 从 JS 对象构建 tarball 字节
    public static func buildTarballFromObject(globalThis: JsGlobalObject, obj: JsValue): Array<UInt8> {
        let jsObj = obj.getObject()
        if (jsObj == null) {
            globalThis.throwInvalidArguments("Expected an object")
            return []
        }

        // 使用 libarchive 构建归档
        let archive = LibArchive.Archive.writeNew()
        defer archive.writeFree()

        if (archive.writeSetFormatPaxRestricted() != LibArchive.Result.ok) {
            globalThis.throwInvalidArguments("Failed to create tarball: ArchiveFormatError")
            return []
        }

        // ... 构建过程
        return []
    }

    // ========================================================================
    // JS 方法
    // ========================================================================

    /// extract - 提取归档到磁盘
    public func extract(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let (pathArg, optionsArg) = callframe.argumentsAsArray2()
        if (pathArg == JsValue.zero || !pathArg.isString()) {
            globalThis.throwInvalidArguments("Archive.extract requires a path argument")
            return JsValue.zero
        }

        let pathSlice = try pathArg.toSlice(globalThis, default_allocator)
        defer pathSlice.deinit()

        // 解析选项 (glob 过滤)
        var globPatterns: ?Array<String> = none

        if (!optionsArg.isUndefinedOrNull()) {
            if (!optionsArg.isObject()) {
                globalThis.throwInvalidArguments("Archive.extract: second argument must be an options object")
                return JsValue.zero
            }

            if (let globVal = try optionsArg.getTruthy(globalThis, "glob")) {
                globPatterns = try parsePatternArg(globalThis, globVal, "Archive.extract", "glob")
            }
        }

        // 启动异步提取任务
        return startExtractTask(globalThis, store, pathSlice.slice(), globPatterns)
    }

    /// blob - 返回归档数据的 Blob
    public func blob(globalThis: JsGlobalObject, _: JsCallFrame): JsValue {
        return startBlobTask(globalThis, store, compress, OutputType.blob)
    }

    /// bytes - 返回归档数据的 Uint8Array
    public func bytes(globalThis: JsGlobalObject, _: JsCallFrame): JsValue {
        return startBlobTask(globalThis, store, compress, OutputType.bytes)
    }

    /// files - 返回归档文件内容的 Map
    public func files(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let globArg = callframe.argument(0)

        var globPatterns: ?Array<String> = none
        if (!globArg.isUndefinedOrNull()) {
            globPatterns = try parsePatternArg(globalThis, globArg, "Archive.files", "glob")
        }

        return startFilesTask(globalThis, store, globPatterns)
    }

    /// write - 静态方法, 写入归档到磁盘
    public static func write(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let (pathArg, dataArg, optionsArg) = callframe.argumentsAsArray3()
        if (dataArg == JsValue.zero) {
            globalThis.throwInvalidArguments("Archive.write requires 2 arguments (path, data)")
            return JsValue.zero
        }

        if (!pathArg.isString()) {
            globalThis.throwInvalidArguments("Archive.write: first argument must be a string path")
            return JsValue.zero
        }

        let pathSlice = try pathArg.toSlice(globalThis, default_allocator)
        defer pathSlice.deinit()

        let optionsCompress = try parseCompressionOptions(globalThis, optionsArg)

        // 对于 Archive 实例, 使用选项覆盖或归档的压缩设置
        // ... 实现省略

        globalThis.throwInvalidArguments("Expected an object, Blob, TypedArray, ArrayBuffer, or Archive")
        return JsValue.zero
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// 解析模式参数 (字符串或字符串数组)
    public static func parsePatternArg(globalThis: JsGlobalObject, arg: JsValue, apiName: String, name: String): ?Array<String> {
        // 单个字符串
        if (arg.isString()) {
            let strSlice = try arg.toSlice(globalThis, default_allocator)
            defer strSlice.deinit()
            if (strSlice.len == 0) { return none }
            let pattern = default_allocator.dupe(UInt8, strSlice.slice())
            return [String.fromUtf8(pattern)]
        }

        // 字符串数组
        if (arg.jsType() == JSType.Array) {
            let len = try arg.getLength(globalThis)
            if (len == 0) { return none }

            var patterns = Array<String>()
            var i: UInt32 = 0
            while (i < len) {
                let item = try arg.getIndex(globalThis, i)
                if (!item.isString()) {
                    globalThis.throwInvalidArguments("\{apiName}: \{name} array must contain only strings")
                    return none
                }
                let strSlice = try item.toSlice(globalThis, default_allocator)
                defer strSlice.deinit()
                if (strSlice.len == 0) { i++; continue }
                let pattern = default_allocator.dupe(UInt8, strSlice.slice())
                patterns.append(String.fromUtf8(pattern))
                i++
            }

            if (patterns.isEmpty()) { return none }
            return patterns
        }

        globalThis.throwInvalidArguments("\{apiName}: \{name} must be a string or array of strings")
        return none
    }

    /// Finalize - GC 回收时调用
    public func finalize(): Unit {
        store.deref()
    }

    // 异步任务启动器 (存根, 实际实现在 AsyncTask 中)
    public static func startExtractTask(globalThis: JsGlobalObject, store: BlobStore, path: String, globPatterns: ?Array<String>): JsValue {
        // 启动异步提取任务, 返回 Promise
        store.ref()
        // ... 异步任务实现
        return JsValue.zero
    }

    public static func startBlobTask(globalThis: JsGlobalObject, store: BlobStore, compress: Compression, outputType: OutputType): JsValue {
        store.ref()
        // ... 异步任务实现
        return JsValue.zero
    }

    public static func startFilesTask(globalThis: JsGlobalObject, store: BlobStore, globPatterns: ?Array<String>): JsValue {
        store.ref()
        // ... 异步任务实现
        return JsValue.zero
    }

    /// 检查路径是否安全 (无绝对路径或路径遍历)
    public static func isSafePath(pathname: String): Bool {
        if (pathname.isEmpty()) { return false }
        if (pathname[0] == '/' || pathname[0] == '\\') { return false }

        // 检查 Windows 驱动器号
        if (pathname.count >= 2 && pathname[1] == ':') { return false }

        // 拒绝包含 ".." 的路径
        for (component in pathname.split('/')) {
            if (component == "..") { return false }
            for (winComponent in component.split('\\')) {
                if (winComponent == "..") { return false }
            }
        }

        return true
    }

    /// 匹配 glob 模式
    public static func matchGlobPatterns(patterns: Array<String>, pathname: String): Bool {
        var hasPositivePatterns = false
        var matchesPositive = false

        for (pattern in patterns) {
            if (pattern.count > 0 && pattern[0] == '!') {
                // 否定模式
                let negPattern = pattern.substring(1)
                if (negPattern.count > 0 && Glob.match(negPattern, pathname).matches()) {
                    return false
                }
            } else {
                hasPositivePatterns = true
                if (Glob.match(pattern, pathname).matches()) {
                    matchesPositive = true
                }
            }
        }

        return !hasPositivePatterns || matchesPositive
    }
}

/// 输出类型
public enum OutputType {
    case blob
    case bytes
}
