// 严格翻译自: src/bundler_jsc/output_file_jsc.zig
//! `toJS`/`toBlob` bridges for `bundler/OutputFile.zig`.
package bao_bundler_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// OutputFileJSC - OutputFile 的 JSC 桥接
// 严格翻译自: src/bundler_jsc/output_file_jsc.zig:4-215
// ============================================================================

/// SavedFile JS 桥接 - 严格对应 Bun SavedFile
public class SavedFileJSC {
    /// 转换为 JS 值 - 严格对应 Bun SavedFile.toJS
    public static func toJS(globalThis: JSGlobalObject, path: String, byteSize: Int64): JSValue {
        let mimeType = globalThis.bunVM().mimeType(path)
        let store = BlobStore.initFile(
            PathOrFileDescriptor(
                path: PathLike(string: PathString.init(path))
            ),
            mimeType,
            Allocator.default
        )

        let blob = Allocator.default.create<Blob>()
        blob.initWithStore(store, globalThis)
        if (let mime = mimeType) {
            blob.contentType = mime.value
        }
        blob.size = BlobSizeType(byteSize)
        return blob.toJS(globalThis)
    }
}

/// 将 OutputFile 转换为 JS - 严格对应 Bun toJS
/// Zig: pub fn toJS(this: *OutputFile, owned_pathname, globalObject) bun.jsc.JSValue
public func outputFileToJS(this: OutputFile, ownedPathname: ?String, globalObject: JSGlobalObject): JSValue {
    return match (this.value) {
        case .noop => JSValue.jsUndefined
        case .copy => copy =>
            let fileBlob = BlobStore.initFile(
                if (copy.fd.isValid) {
                    PathOrFileDescriptor(fd: copy.fd)
                } else {
                    PathOrFileDescriptor(path: PathLike(string: PathString.init(globalObject.allocator().dupe(copy.pathname))))
                },
                this.loader.toMimeType([ownedPathname ?? ""]),
                globalObject.allocator()
            )

            let buildOutput = BuildArtifact(
                blob: Blob.initWithStore(fileBlob, globalObject),
                hash: this.hash,
                loader: this.inputLoader,
                outputKind: this.outputKind,
                path: Allocator.default.dupe(copy.pathname)
            )

            this.value = OutputFileValue.buffer(Allocator.default, [])

            buildOutput.toJS(globalObject)
        case .saved =>
            let buildOutput = Allocator.default.create<BuildArtifact>()
            let pathToUse = ownedPathname ?? this.srcPath.text

            let fileBlob = BlobStore.initFile(
                PathOrFileDescriptor(path: PathLike(string: PathString.init(ownedPathname ?? Allocator.default.dupe(this.srcPath.text)))),
                this.loader.toMimeType([ownedPathname ?? ""]),
                globalObject.allocator()
            )

            this.value = OutputFileValue.buffer(Allocator.default, [])

            buildOutput.init(Blob.initWithStore(fileBlob, globalObject), this.hash, this.inputLoader, this.outputKind, Allocator.default.dupe(pathToUse))
            buildOutput.toJS(globalObject)
        case .buffer => buffer =>
            let blob = Blob(buffer.bytes, buffer.allocator, globalObject)
            if (let store = blob.store) {
                store.mimeType = this.loader.toMimeType([ownedPathname ?? ""])
                blob.contentType = store.mimeType.value
            } else {
                blob.contentType = this.loader.toMimeType([ownedPathname ?? ""]).value
            }
            blob.size = BlobSizeType(buffer.bytes.size)

            let buildOutput = Allocator.default.create<BuildArtifact>()
            buildOutput.init(blob, this.hash, this.inputLoader, this.outputKind, ownedPathname ?? Allocator.default.dupe(this.srcPath.text))

            this.value = OutputFileValue.buffer(Allocator.default, [])

            buildOutput.toJS(globalObject)
        default =>
            globalObject.throw("Unexpected pending output file")
            JSValue.zero
    }
}

/// 将 OutputFile 转换为 Blob - 严格对应 Bun toBlob
public func outputFileToBlob(this: OutputFile, allocator: Allocator, globalThis: JSGlobalObject): Blob {
    return match (this.value) {
        case .copy => copy =>
            let fileBlob = BlobStore.initFile(
                if (copy.fd.isValid) {
                    PathOrFileDescriptor(fd: copy.fd)
                } else {
                    PathOrFileDescriptor(path: PathLike(string: PathString.init(allocator.dupe(copy.pathname))))
                },
                this.loader.toMimeType([this.destPath, this.srcPath.text]),
                allocator
            )

            this.value = OutputFileValue.buffer(Allocator.default, [])
            Blob.initWithStore(fileBlob, globalThis)
        case .saved =>
            let fileBlob = BlobStore.initFile(
                PathOrFileDescriptor(path: PathLike(string: PathString.init(allocator.dupe(this.srcPath.text)))),
                this.loader.toMimeType([this.destPath, this.srcPath.text]),
                allocator
            )

            this.value = OutputFileValue.buffer(Allocator.default, [])
            Blob.initWithStore(fileBlob, globalThis)
        case .buffer => buffer =>
            let blob = Blob(buffer.bytes, buffer.allocator, globalThis)
            if (let store = blob.store) {
                store.mimeType = this.loader.toMimeType([this.destPath, this.srcPath.text])
                blob.contentType = store.mimeType.value
            } else {
                blob.contentType = this.loader.toMimeType([this.destPath, this.srcPath.text]).value
            }

            this.value = OutputFileValue.buffer(Allocator.default, [])
            blob.size = BlobSizeType(buffer.bytes.size)
            blob
        default =>
            globalThis.throw("Unexpected pending/noop output file")
            Blob.empty
    }
}
