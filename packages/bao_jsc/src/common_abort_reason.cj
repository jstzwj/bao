// 严格翻译自: src/jsc/common_abort_reason.zig (9行)
// 常见的中止原因定义

package bao_jsc

// ========== CommonAbortReason ==========
// 严格翻译自 common_abort_reason.zig
// 提供 JSC C++ 类型的尺寸和对齐常量
// 这些值从代码生成器导出，不应在新代码中依赖这些值
// 解释 C++ 类为原始字节不可靠，因为编译器不保证内存布局
public class CommonAbortReason {
    // 严格翻译自 Bun_FFI_PointerOffsetToArgumentsList
    // FFI 中指向 ArgumentsList 的指针偏移量
    public static let FFI_POINTER_OFFSET_TO_ARGUMENTS_LIST: Int64 = 6

    // 严格翻译自 Bun_FFI_PointerOffsetToTypedArrayVector
    // FFI 中指向 TypedArray 向量的指针偏移量
    public static let FFI_POINTER_OFFSET_TO_TYPED_ARRAY_VECTOR: Int64 = 16

    public init() {}
}
