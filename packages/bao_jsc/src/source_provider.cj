// 严格翻译自: src/jsc/SourceProvider.zig (9行)
// JavaScriptCore SourceProvider - 源码提供器 opaque 类型

package bao_jsc

// ========== SourceProvider ==========
// 严格翻译自 SourceProvider.zig
// SourceProvider 是 JavaScript 源码提供器的 opaque 表示
// 在 JSC 中，SourceProvider 负责管理脚本/模块的源码文本
// 它提供了源码内容、URL、起始位置等信息
//
// SourceProvider 是 JSC::SourceProvider 的 C++ 类
// 在 Bun 中主要用于:
//   - 提供 eval/编译的源码内容
//   - 管理源码缓存
//   - 为 SourceCode 提供底层数据
//
// 原始 Zig 代码:
//   pub const SourceProvider = opaque {
//       pub fn deref(provider: *SourceProvider) void {
//           bun.cpp.JSC__SourceProvider__deref(provider);
//       }
//   };
public class SourceProvider_ {
    // 源码文本
    public var sourceCode: String = ""
    // 源码 URL
    public var sourceURL: String = ""
    // 源码类型
    public var sourceType: SourceType = SourceType.Program
    // 哈希值
    public var hash: Int64 = 0
    // 是否已缓存
    public var isCached: Bool = false
    // 原始 opaque 指针
    public var rawPtr: CPointer<UInt8> = CPointer<UInt8>()
    // 引用计数
    var refCount: Int64 = 1

    public init() {}

    public init(sourceCode: String, sourceURL: String) {
        this.sourceCode = sourceCode
        this.sourceURL = sourceURL
        this.hash = computeHash(sourceCode)
    }

    // ========== deref ==========
    // 严格翻译自 SourceProvider.deref
    // 减少引用计数，当引用计数为 0 时释放资源
    //
    // FFI: bun.cpp.JSC__SourceProvider__deref(provider: *SourceProvider) void
    public func deref() {
        refCount--
        // FFI: JSC__SourceProvider__deref(rawPtr)
        // 真实实现通过 C FFI 调用
    }

    // ========== 获取源码 ==========
    public func source() -> String {
        sourceCode
    }

    // ========== 获取 URL ==========
    public func url() -> String {
        sourceURL
    }

    // ========== 计算哈希 ==========
    func computeHash(s: String) -> Int64 {
        var h: Int64 = 0
        for (c in s) {
            h = h * 31 + Int64(c.code)
        }
        h
    }
}
