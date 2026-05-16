// 严格翻译自: src/runtime/api/output_file_jsc.rs
// OutputFile 的 to_js/to_blob 桥接，用于 bundler/OutputFile.zig。
// 作为扩展 trait 暴露，使调用点保持 output.to_js(global) 形式。
//
// 分层说明: 此文件位于 bun_runtime（而非 bun_bundler_jsc），因为它构造
// webcore::Blob、webcore::blob::Store、api::BuildArtifact 和
// node::types::{PathLike, PathOrFileDescriptor} — 这些都是 bun_runtime 类型。
// bun_runtime 已经依赖 bun_bundler，因此没有循环依赖。

package bao_runtime.api

import bao_jsc.*
import bao_bundler.*
import bao_core.*
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
        globalThis: JSGlobalObject,
        path: String,
        byteSize: Int64,
    ): JSValue {
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
        outputFile: OutputFile,
        ownedPathname: ?String,
        globalObject: JSGlobalObject,
    ): JSValue {
        // 提前返回: 未决的输出文件
        match (outputFile.value) {
            | OutputFileValue.move(_) | OutputFileValue.pending(_) =>
                panic("Unexpected pending output file")
            | OutputFileValue.noop =>
                return JSValue.undefined
            | _ => ()
        }

        // 取出值并重置为空缓冲区
        let value = outputFile.takeValue()

        let mimeHint: String = ownedPathname ?? ""
        let mime = outputFile.loader.toMimeType([mimeHint])

        match (value) {
            | OutputFileValue.copy(let copy) =>
                // 创建文件 Blob 存储
                let fileBlob = match (
                    copy.fd.isValid(),
                    PathOrFileDescriptor.path(dupePathLike(copy.pathname)),
                ) {
                    (true, _) => BlobStore.initFile(
                        PathOrFileDescriptor.fd(copy.fd),
                        Some(mime),
                    )
                    (_, path) => BlobStore.initFile(path, Some(mime)),
                }

                let buildOutput = BuildArtifact(
                    blob: Blob.initWithStore(fileBlob, globalObject),
                    hash: outputFile.hash,
                    loader: outputFile.inputLoader,
                    outputKind: outputFile.outputKind,
                    path: copy.pathname,
                    sourcemap: StrongOptional.empty(),
                )

                return BuildArtifact.toJsBoxed(buildOutput, globalObject)

            | OutputFileValue.saved(_) =>
                let pathToUse: String = ownedPathname ?? outputFile.srcPath.text

                let storePath = match (ownedPathname) {
                    | Some(p) => PathLike.string(PathString.initOwned(p))
                    | None => dupePathLike(outputFile.srcPath.text)
                }

                let fileBlob = match (
                    BlobStore.initFile(PathOrFileDescriptor.path(storePath), Some(mime)),
                ) {
                    | ok(b) => b
                    | err(err) => panic("Unable to create file blob: " + err.name()),
                }

                let buildOutput = BuildArtifact(
                    blob: Blob.initWithStore(fileBlob, globalObject),
                    hash: outputFile.hash,
                    loader: outputFile.inputLoader,
                    outputKind: outputFile.outputKind,
                    path: pathToUse,
                    sourcemap: StrongOptional.empty(),
                )

                return BuildArtifact.toJsBoxed(buildOutput, globalObject)

            | OutputFileValue.buffer(let bytes) =>
                let bytesLen = bytes.length
                var blob = Blob.init(bytes, globalObject)
                setBlobMime(blob, mime)
                blob.size = bytesLen

                let path: String = match (ownedPathname) {
                    | Some(p) => p
                    | None => outputFile.srcPath.text,
                }

                let buildOutput = BuildArtifact(
                    blob: blob,
                    hash: outputFile.hash,
                    loader: outputFile.inputLoader,
                    outputKind: outputFile.outputKind,
                    path: path,
                    sourcemap: StrongOptional.empty(),
                )

                return BuildArtifact.toJsBoxed(buildOutput, globalObject)

            | _ => panic("Unexpected output file state")
        }
    }

    /// 将 OutputFile 转换为 Blob
    /// 对应 Bun: OutputFileJsc::to_blob
    public static func toBlob(
        outputFile: OutputFile,
        globalThis: JSGlobalObject,
    ): ?Blob {
        match (outputFile.value) {
            | OutputFileValue.move(_) | OutputFileValue.pending(_) =>
                panic("Unexpected pending output file")
            | OutputFileValue.noop =>
                panic("Cannot convert noop output file to blob")
            | _ => ()
        }

        let value = outputFile.takeValue()

        let mime = outputFile.loader.toMimeType([
            outputFile.destPath,
            outputFile.srcPath.text,
        ])

        match (value) {
            | OutputFileValue.copy(let copy) =>
                let pathLike = if (copy.fd.isValid()) {
                    PathOrFileDescriptor.fd(copy.fd)
                } else {
                    PathOrFileDescriptor.path(dupePathLike(copy.pathname))
                }
                match (BlobStore.initFile(pathLike, Some(mime))) {
                    | ok(b) => Blob.initWithStore(b, globalThis)
                    | err(e) => None
                }

            | OutputFileValue.saved(_) =>
                let storePath = dupePathLike(outputFile.srcPath.text)
                match (BlobStore.initFile(
                    PathOrFileDescriptor.path(storePath),
                    Some(mime),
                )) {
                    | ok(b) => Blob.initWithStore(b, globalThis)
                    | err(e) => None
                }

            | OutputFileValue.buffer(let bytes) =>
                let bytesLen = bytes.length
                var blob = Blob.init(bytes, globalThis)
                setBlobMime(blob, mime)
                blob.size = bytesLen
                blob

            | _ => None
        }
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 堆复制 path 到拥有的 PathLike，使 Blob.Store 存活超过借用源。
/// 对应 Zig: allocator.dupe(u8, path)
func dupePathLike(path: String): PathLike {
    return PathLike.encodedSlice(ZigStringSlice.initDupe(path))
}

/// 设置 Blob 的 mime_type。
/// 指针从 blob.store 借用（持有 blob 的生命周期），
/// 因此无需单独分配即可保持有效。
func setBlobMime(blob: Blob, mime: MimeType): Unit {
    if (let Some(store) = blob.store.get()) {
        store.mimeType = mime
        blob.contentType = mime.value
    } else {
        // 无存储（空字节）
        blob.contentType = mime.value
        blob.contentTypeAllocated = true
    }
}
