// 严格翻译自: src/sourcemap_jsc/source_provider.zig
//! BakeSourceProvider.
package bao_sourcemap_jsc

import bao_jsc.*
import bao_core.*
import std.collection.ArrayList

// ============================================================================
// BakeSourceProvider - Bake 源码提供者 (stub)
// ============================================================================

/// SourceContentPtr wrapper used by ParsedSourceMap source providers.
public class SourceContentPtr {
    public var provider: ?BakeSourceProvider
    public init() { provider = None }
    public init(provider: BakeSourceProvider) { this.provider = Some(provider) }
}

/// Bake 源码提供者
public class BakeSourceProvider {
    private var ptr: CPointer<Byte>
    private var source: BaoString
    private var externalData: ArrayList<(String, String)>

    public init(ptr: CPointer<Byte>) {
        this.ptr = ptr
        this.source = BaoString()
        this.externalData = ArrayList<(String, String)>()
    }

    public init(source: BaoString) {
        this.ptr = CPointer<Byte>()
        this.source = source
        this.externalData = ArrayList<(String, String)>()
    }

    public func toSourceContentPtr(): SourceContentPtr {
        SourceContentPtr(this)
    }

    /// 获取源码切片
    public func getSourceSlice(): BaoString {
        return source
    }

    public func putExternalData(sourceFilename: String, contents: String): Unit {
        var next = ArrayList<(String, String)>()
        for (item in externalData) {
            if (item[0] != sourceFilename) {
                next.add(item)
            }
        }
        next.add((sourceFilename, contents))
        externalData = next
    }

    /// 获取 Bake 预打包的外部 sourcemap JSON；没有 live Bake global 时返回 None，让调用方回退到磁盘读取。
    public func getExternalData(sourceFilename: String): ?String {
        for (item in externalData) {
            if (item[0] == sourceFilename) {
                return Some(item[1])
            }
        }
        return None
    }
}
