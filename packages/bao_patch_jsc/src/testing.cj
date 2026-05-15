// 严格翻译自: src/patch_jsc/testing.zig
//! JS testing bindings for `bun.patch`. Keeps `src/patch/` free of JSC types.
package bao_patch_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// TestingAPIs - Patch 测试 API
// 严格翻译自: src/patch_jsc/testing.zig:3-138
//   pub const TestingAPIs = struct {
//       pub fn makeDiff(...)
//       pub fn apply(...)
//       pub fn parse(...)
//   }
// ============================================================================

/// Patch 测试 API 集合 - 严格对应 Bun TestingAPIs
public class TestingAPIs {
    /// 创建 diff - 严格对应 Bun makeDiff
    /// Zig: pub fn makeDiff(globalThis, callframe) bun.JSError!jsc.JSValue
    public static func makeDiff(globalThis: JSGlobalObject, callframe: CallFrame): JSValue {
        let arguments = callframe.argumentsOld(2)
        var args = CallFrame.ArgumentsSlice.init(globalThis.bunVM(), arguments)

        let oldFolderJsVal = args.nextEat() ?? {
            globalThis.throw("expected 2 strings")
            return JSValue.zero
        }
        let oldFolderBunStr = oldFolderJsVal.toBunString(globalThis)

        let newFolderJsVal = args.nextEat() ?? {
            globalThis.throw("expected 2 strings")
            return JSValue.zero
        }
        let newFolderBunStr = newFolderJsVal.toBunString(globalThis)

        let oldFolder = oldFolderBunStr.toUTF8(Allocator.default)
        let newFolder = newFolderBunStr.toUTF8(Allocator.default)

        let result = gitDiffInternal(Allocator.default, oldFolder.slice(), newFolder.slice())
        match (result) {
            case .result => s =>
                let outstr = BaoString.fromBytes(s.items)
                return outstr.toJS(globalThis)
            case .err => e =>
                globalThis.throw("failed to make diff: ${e.items}")
                return JSValue.zero
        }
    }

    /// Apply 参数结构 - 严格对应 Bun ApplyArgs
    /// Zig: const ApplyArgs = struct { patchfile_txt, patchfile, dirfd, pub fn deinit(...) }
    public class ApplyArgs {
        public var patchfileTxt: ZigString.Slice
        public var patchfile: PatchFile
        public var dirfd: FD

        public init(patchfileTxt: ZigString.Slice, patchfile: PatchFile, dirfd: FD) {
            this.patchfileTxt = patchfileTxt
            this.patchfile = patchfile
            this.dirfd = dirfd
        }

        public func deinit(): Unit {
            patchfileTxt.deinit()
            patchfile.deinit(Allocator.default)
            if (FD.cwd() != dirfd) {
                dirfd.close()
            }
        }
    }

    /// 应用 patch - 严格对应 Bun apply
    /// Zig: pub fn apply(globalThis, callframe) bun.JSError!jsc.JSValue
    public static func apply(globalThis: JSGlobalObject, callframe: CallFrame): JSValue {
        var args = parseApplyArgs(globalThis, callframe)
        if (args.isErr) {
            return args.errValue
        }
        defer {
            args.resultValue.deinit()
        }

        let err = args.resultValue.patchfile.apply(Allocator.default, args.resultValue.dirfd)
        if (err != None) {
            globalThis.throwValue(err.toJS(globalThis))
            return JSValue.zero
        }

        return JSValue.jsTrue
    }

    /// 解析 patch 文件 - 严格对应 Bun parse
    /// Zig: pub fn parse(globalThis, callframe) bun.JSError!jsc.JSValue
    public static func parse(globalThis: JSGlobalObject, callframe: CallFrame): JSValue {
        let arguments = callframe.argumentsOld(2)
        var args = CallFrame.ArgumentsSlice.init(globalThis.bunVM(), arguments)

        let patchfileSrcJs = args.nextEat() ?? {
            globalThis.throw("TestingAPIs.parse: expected at least 1 argument, got 0")
            return JSValue.zero
        }
        let patchfileSrcBunStr = patchfileSrcJs.toBunString(globalThis)
        let patchfileSrc = patchfileSrcBunStr.toUTF8(Allocator.default)

        let patchfile = parsePatchFile(patchfileSrc.slice())
        if (patchfile.isErr) {
            let e = patchfile.errValue
            if (e == Error.hunk_header_integrity_check_failed) {
                globalThis.throwError(e, "this indicates either that the supplied patch file was incorrect, or there is a bug in Bun. Please check your .patch file, or open a GitHub issue :)")
            } else {
                globalThis.throwError(e, "failed to parse patch file")
            }
            return JSValue.zero
        }
        defer {
            patchfile.resultValue.deinit(Allocator.default)
        }

        let str = handleOom(fmtAllocPrint(Allocator.default, "${patchfile.resultValue}"))
        let outstr = BaoString.borrowUTF8(str)
        return outstr.toJS(globalThis)
    }

    /// 解析 apply 参数 - 严格对应 Bun parseApplyArgs
    /// Zig: pub fn parseApplyArgs(globalThis, callframe) bun.jsc.Node.Maybe(ApplyArgs, jsc.JSValue)
    public static func parseApplyArgs(globalThis: JSGlobalObject, callframe: CallFrame): Maybe<ApplyArgs> {
        let arguments = callframe.argumentsOld(2)
        var args = CallFrame.ArgumentsSlice.init(globalThis.bunVM(), arguments)

        let patchfileJs = args.nextEat() ?? {
            globalThis.throw("apply: expected at least 1 argument, got 0")
            return Maybe<ApplyArgs>.initErr(JSValue.jsUndefined)
        }

        let dirFd = if (let next = args.nextEat()) {
            let bunstr = next.toBunString(globalThis)
            let path = bunstr.toOwnedSliceZ(Allocator.default)
            let result = sys_open(path, O.DIRECTORY | O.RDONLY, 0)
            match (result) {
                case .err => e =>
                    globalThis.throwValue(e.withPath(path).toJS(globalThis))
                    return Maybe<ApplyArgs>.initErr(JSValue.jsUndefined)
                case .result => fd => fd
            }
        } else {
            FD.cwd()
        }

        let patchfileBunStr = patchfileJs.toBunString(globalThis)
        let patchfileSrc = patchfileBunStr.toUTF8(Allocator.default)

        let patchFile = parsePatchFile(patchfileSrc.slice())
        if (patchFile.isErr) {
            if (FD.cwd() != dirFd) {
                dirFd.close()
            }
            patchfileSrc.deinit()
            globalThis.throwError(patchFile.errValue, "failed to parse patchfile")
            return Maybe<ApplyArgs>.initErr(JSValue.jsUndefined)
        }

        return Maybe<ApplyArgs>.result(ApplyArgs(
            patchfileTxt: patchfileSrc,
            patchfile: patchFile.resultValue,
            dirfd: dirFd
        ))
    }
}
