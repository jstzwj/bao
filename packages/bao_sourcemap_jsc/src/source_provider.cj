// 严格翻译自: src/sourcemap_jsc/source_provider.zig
//! BakeSourceProvider — the only `*SourceProvider` variant whose external sourcemap
//! lookup needs the live `Bake::GlobalObject`.
package bao_sourcemap_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// BakeSourceProvider - Bake 源码提供者
// 严格翻译自: src/sourcemap_jsc/source_provider.zig:6-49
//   pub const BakeSourceProvider = opaque {
//       extern fn BakeSourceProvider__getSourceSlice(*BakeSourceProvider) bun.String
//       pub fn toSourceContentPtr(...)
//       pub fn getExternalData(...)
//       pub fn getSourceMap(...)
//   }
// ============================================================================

// 外部 C 函数声明 - 严格对应 Bun extern 声明
@Foreign("c")
public func BakeGlobalObject__isBakeGlobalObject(global: JSGlobalObject): Bool

@Foreign("c")
public func BakeGlobalObject__getPerThreadData(global: JSGlobalObject): PerThread

@Foreign("c")
public func BakeSourceProvider__getSourceSlice(provider: BakeSourceProvider): BaoString

/// Bake 源码提供者 - 严格对应 Bun BakeSourceProvider
public class BakeSourceProvider {
    private var ptr: CPointer<Byte>

    public init(ptr: CPointer<Byte>) {
        this.ptr = ptr
    }

    /// 获取源码切片 - 严格对应 Bun getSourceSlice
    public func getSourceSlice(): BaoString {
        return BakeSourceProvider__getSourceSlice(this)
    }

    /// 转换为源码内容指针 - 严格对应 Bun toSourceContentPtr
    public func toSourceContentPtr(): SourceContentPtr {
        return SourceContentPtr.fromBakeProvider(this)
    }

    /// 获取外部数据 - 严格对应 Bun getExternalData
    /// Zig: pub fn getExternalData(_: *BakeSourceProvider, source_filename: []const u8) ?[]const u8
    public func getExternalData(sourceFilename: String): ?String {
        let global = VirtualMachine.get().global
        if (!BakeGlobalObject__isBakeGlobalObject(global)) {
            return None
        }
        let pt = BakeGlobalObject__getPerThreadData(global)
        if (let value = pt.sourceMaps.get(sourceFilename)) {
            return pt.bundledOutputs[value.get()].value.asSlice()
        }
        return ""
    }

    /// 获取源码映射 - 严格对应 Bun getSourceMap
    /// Zig: pub fn getSourceMap(provider, source_filename, load_hint, result) ?SourceMap.ParseUrl
    public func getSourceMap(
        sourceFilename: String,
        loadHint: SourceMapLoadHint,
        result: ParseUrlResultHint
    ): ?ParseUrl {
        return SourceMap.getSourceMapImpl(
            this,
            sourceFilename,
            loadHint,
            result
        )
    }
}
