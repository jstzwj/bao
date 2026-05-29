// 严格翻译自: src/runtime/api/output_file_jsc.rs
// OutputFile 的 to_js/to_blob 桥接，用于 bundler/OutputFile.zig。
// 作为扩展 trait 暴露，使调用点保持 output.to_js(global) 形式。
//
// 分层说明: 此文件位于 bun_runtime（而非 bun_bundler_jsc），因为它构造
// webcore::Blob、webcore::blob::Store、api::BuildArtifact 和
// node::types::{PathLike, PathOrFileDescriptor} — 这些都是 bun_runtime 类型。
// bun_runtime 已经依赖 bun_bundler，因此没有循环依赖。

package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, PathLike, ZigStringSlice}
import bao_bundler.*
import bao_core.{Allocator, Output}
import bao_http_types.*

// ============================================================================
// SavedFile — 已保存文件的 JS 表示
// 对应 Bun: output_file_jsc.rs SavedFile
// ============================================================================

/// SavedFile — 将文件路径和大小转换为 JS 值
public class SavedFile {
    /// 将已保存文件转换为 JS 值
    /// 对应 Bun: SavedFile.to_js
    public static func toJs(
        globalThis!: JsGlobalObject,
        path!: String,
        byteSize!: Int64
    ): JsValue {
        let mimeType = globalThis.bunVm().mimeType(path)

        // 创建文件 Blob 存储
        let store = BlobStore.initFile(
            PathOrFileDescriptor.path(PathLike.string(PathString.initOwned(path))),
            mimeType,
        )

        var blob = Blob.initWithStore(store, globalThis)
        blob.size = byteSize
        let ptr = Blob.new(blob)

        return ptr.toJs(globalThis)
    }
}

// ============================================================================
// OutputFileJsc — OutputFile 的 JS 桥接扩展
// 对应 Bun: output_file_jsc.rs OutputFileJsc trait + impl
// ============================================================================

/// OutputFileJsc — 将 OutputFile 转换为 JS 值或 Blob 的扩展接口
public class OutputFileJsc {

    /// 将 OutputFile 转换为 JS 值
    /// 对应 Bun: OutputFileJsc::to_js
    public static func toJs(
        outputFile!: OutputFile,
        ownedPathname!: ?String,
        globalObject!: JsGlobalObject
    ): JsValue {
        // 提前返回: 未决的输出文件
        match (outputFile.value) {
            case OutputFileValue.move(_) | OutputFileValue.pending(_) =>
                panic("Unexpected pending output file")
            case OutputFileValue.noop =>
                return JsValue.undefined
            case _ => ()
        }

        // 取出值并重置为空缓冲区
        let value = outputFile.takeValue()

        let mimeHint: String = ownedPathname ?? ""
        let mime = outputFile.loader.toMimeType([mimeHint])

        // 对应 Bun: OutputFileJsc::to_js — 将 OutputFile 转换为 BuildArtifact JS 对象
        match (value) {
            case OutputFileValue.copy(copy) =>
                let pathLike = if (copy.fd.isValid()) {
                    PathOrFileDescriptor.fd(copy.fd)
                } else {
                    PathOrFileDescriptor.path(dupePathLike(copy.pathname))
                }
                match (BlobStore.initFile(pathLike, Some(mime))) {
                    case ok(blobStore) =>
                        let blob = Blob.initWithStore(blobStore, globalObject)
                        return BuildArtifact.toJs(blob, outputFile.hash, outputFile.srcPath.text, globalObject)
                    case err(e) =>
                        return JsValue.jsUndefined()
                }

            case OutputFileValue.saved(_) =>
                let storePath = dupePathLike(outputFile.srcPath.text)
                match (BlobStore.initFile(
                    PathOrFileDescriptor.path(storePath),
                    Some(mime),
                )) {
                    case ok(blobStore) =>
                        let blob = Blob.initWithStore(blobStore, globalObject)
                        return BuildArtifact.toJs(blob, outputFile.hash, outputFile.srcPath.text, globalObject)
                    case err(e) =>
                        return JsValue.jsUndefined()
                }

            case OutputFileValue.buffer(bytes) =>
                let bytesLen = bytes.size
                var blob = Blob(bytes, globalThis)
                setBlobMime(blob, mime)
                blob.size = bytesLen
                return BuildArtifact.toJs(blob, outputFile.hash, outputFile.srcPath.text, globalObject)

            case _ => return JsValue.jsUndefined()
        }
    }

    /// 将 OutputFile 转换为 Blob
    /// 对应 Bun: OutputFileJsc::to_blob
    public static func toBlob(
        outputFile!: OutputFile,
        globalThis!: JsGlobalObject
    ): ?Blob {
        match (outputFile.value) {
            case OutputFileValue.move(_) | OutputFileValue.pending(_) =>
                panic("Unexpected pending output file")
            case OutputFileValue.noop =>
                panic("Cannot convert noop output file to blob")
            case _ => ()
        }

        let value = outputFile.takeValue()

        let mime = outputFile.loader.toMimeType([
            outputFile.destPath,
            outputFile.srcPath.text
        ])

        match (value) {
            case OutputFileValue.copy(copy) =>
                let pathLike = if (copy.fd.isValid()) {
                    PathOrFileDescriptor.fd(copy.fd)
                } else {
                    PathOrFileDescriptor.path(dupePathLike(copy.pathname))
                }
                match (BlobStore.initFile(pathLike, Some(mime))) {
                    case ok(b) => Blob.initWithStore(b, globalThis)
                    case err(e) => None
                }

            case OutputFileValue.saved(_) =>
                let storePath = dupePathLike(outputFile.srcPath.text)
                match (BlobStore.initFile(
                    PathOrFileDescriptor.path(storePath),
                    Some(mime),
                )) {
                    case ok(b) => Blob.initWithStore(b, globalThis)
                    case err(e) => None
                }

            case OutputFileValue.buffer(bytes) =>
                let bytesLen = bytes.size
                var blob = Blob(bytes, globalThis)
                setBlobMime(blob, mime)
                blob.size = bytesLen
                blob

            case _ => None
        }
    }
}

// ============================================================================
// BuildArtifact — 构建产物 JS 对象
// 对应 Bun: api::BuildArtifact — Bun.build() 返回的产物对象
// ============================================================================

/// BuildArtifact 辅助类
/// 将 Blob 转换为 BuildArtifact JS 对象
public class BuildArtifact {
    /// 将 Blob 转换为 BuildArtifact JS 值
    /// 对应 Bun: BuildArtifact::to_js_boxed
    public static func toJs(blob: Blob, hash: String, path: String, globalObject: JsGlobalObject): JsValue {
        let obj = JsValue.createEmptyObject(globalObject.globalThis, 7)
        // 设置 blob 属性
        obj.put(globalObject.globalThis, "blob", blob.toJs(globalObject))
        // 设置 hash 属性
        obj.put(globalObject.globalThis, "hash", JsValue.jsString(hash))
        // 设置 path 属性
        obj.put(globalObject.globalThis, "path", JsValue.jsString(path))
        // 设置 type 属性 (loader)
        obj.put(globalObject.globalThis, "type", JsValue.jsString("application/octet-stream"))
        // 设置 kind 属性
        obj.put(globalObject.globalThis, "kind", JsValue.jsString("asset"))
        // 设置 sourcemap 属性
        obj.put(globalObject.globalThis, "sourcemap", JsValue.jsUndefined())
        // 设置 loader 属性
        obj.put(globalObject.globalThis, "loader", JsValue.jsString("file"))
        return obj
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 堆复制 path 到拥有的 PathLike，使 Blob.Store 存活超过借用源。
/// 对应 Zig: allocator.dupe(u8, path)
func dupePathLike(path!: String): PathLike {
    return PathLike.encodedSlice(ZigStringSlice.initDupe(path))
}

/// 设置 Blob 的 mime_type。
/// 指针从 blob.store 借用（持有 blob 的生命周期），
/// 因此无需单独分配即可保持有效。
func setBlobMime(blob!: Blob, mime!: MimeType): Unit {
    if (let Some(store) <- blob.store.get()) {
        store.mimeType = mime
        blob.contentType = mime.value
    } else {
        // 无存储（空字节）
        blob.contentType = mime.value
        blob.contentTypeAllocated = true
    }
}
