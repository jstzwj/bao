// 严格翻译自: src/runtime/api/Archive.classes.ts
// Archive 的 JSC 绑定 — 连接到 archive.cj 中的 libarchive FFI 实现
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, CallFrame, JsObject}

// ============================================================================
// Archive.classes.ts 类绑定定义
// Bun: Archive 的 JSC 绑定
// construct: true, finalize: true, configurable: false
// klass: { write: { fn: "write", length: 2 } }
// proto: { extract, blob, bytes, files }
// ============================================================================

/// Archive JSC 绑定
/// Bun: Bun.Archive — tar/tgz 打包与解包
/// 委托到 Archive 类实例方法实现 libarchive 操作
public class ArchiveClasses {

    // ========================================================================
    // 静态方法 (klass)
    // ========================================================================

    /// static write fn
    /// 严格翻译自: klass.write { fn: "write", length: 2 }
    /// 参数: (outputPath: string, data: Archive | Blob | TypedArray | object, options?)
    /// 返回: Promise<void>
    /// 委托到 Archive.write() 静态方法
    public static func write(jsGlobalObject!: JsGlobalObject, callframe!: CallFrame, thisValue!: JsValue): JsValue {
        Archive.write(globalThis: jsGlobalObject, callframe: callframe)
    }

    // ========================================================================
    // 实例方法 (proto)
    // ========================================================================

    /// extract fn
    /// 严格翻译自: proto.extract { fn: "extract", length: 2 }
    /// 参数: (path: string, options?: ArchiveExtractOptions)
    /// 返回: Promise<number> — 提取的文件数
    /// 委托到 Archive 实例的 extract() 方法，使用 libarchive FFI 提取归档
    public static func extract(jsGlobalObject!: JsGlobalObject, callframe!: CallFrame, thisValue!: JsValue): JsValue {
        // 从 thisValue 获取 Archive 实例
        let archiveOpt = Archive.fromJS(value: thisValue)
        match (archiveOpt) {
            case Some(archive) => archive.extract(globalThis: jsGlobalObject, callframe: callframe)
            case None =>
                // 如果无法获取 Archive 实例，尝试创建临时实例
                let tmpArchive = Archive()
                tmpArchive.extract(globalThis: jsGlobalObject, callframe: callframe)
        }
    }

    /// blob fn
    /// 严格翻译自: proto.blob { fn: "blob", length: 0 }
    /// 返回: Promise<Blob>
    /// 委托到 Archive 实例的 blob() 方法
    public static func blob(jsGlobalObject!: JsGlobalObject, callframe!: CallFrame, thisValue!: JsValue): JsValue {
        let archiveOpt = Archive.fromJS(value: thisValue)
        match (archiveOpt) {
            case Some(archive) => archive.blob(globalThis: jsGlobalObject, frame: callframe)
            case None =>
                let tmpArchive = Archive()
                tmpArchive.blob(globalThis: jsGlobalObject, frame: callframe)
        }
    }

    /// bytes fn
    /// 严格翻译自: proto.bytes { fn: "bytes", length: 0 }
    /// 返回: Promise<Uint8Array>
    /// 委托到 Archive 实例的 bytes() 方法
    public static func bytes(jsGlobalObject!: JsGlobalObject, callframe!: CallFrame, thisValue!: JsValue): JsValue {
        let archiveOpt = Archive.fromJS(value: thisValue)
        match (archiveOpt) {
            case Some(archive) => archive.bytes(globalThis: jsGlobalObject, frame: callframe)
            case None =>
                let tmpArchive = Archive()
                tmpArchive.bytes(globalThis: jsGlobalObject, frame: callframe)
        }
    }

    /// files fn
    /// 严格翻译自: proto.files { fn: "files", length: 0 }
    /// 返回: Promise<Map<string, ArchiveFile>>
    /// 委托到 Archive 实例的 files() 方法，使用 libarchive FFI 遍历文件
    public static func files(jsGlobalObject!: JsGlobalObject, callframe!: CallFrame, thisValue!: JsValue): JsValue {
        let archiveOpt = Archive.fromJS(value: thisValue)
        match (archiveOpt) {
            case Some(archive) => archive.files(globalThis: jsGlobalObject, callframe: callframe)
            case None =>
                let tmpArchive = Archive()
                tmpArchive.files(globalThis: jsGlobalObject, callframe: callframe)
        }
    }
}
