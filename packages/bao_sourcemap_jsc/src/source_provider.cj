// 严格翻译自: src/sourcemap_jsc/source_provider.zig
//! BakeSourceProvider — stub implementation.
package bao_sourcemap_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// BakeSourceProvider - Bake 源码提供者 (stub)
// ============================================================================

/// SourceContentPtr stub
public class SourceContentPtr {
    public init() {}
}

/// Bake 源码提供者 - stub
public class BakeSourceProvider {
    private var ptr: CPointer<Byte>

    public init(ptr: CPointer<Byte>) {
        this.ptr = ptr
    }

    /// 获取源码切片 - stub
    public func getSourceSlice(): BaoString {
        return BaoString()
    }

    /// 获取外部数据 - stub
    public func getExternalData(sourceFilename: String): ?String {
        return None
    }
}
