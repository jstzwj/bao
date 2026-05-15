// 严格翻译自: src/jsc/sizes.zig (9行)
// JSC C++ 类型的尺寸和对齐常量

package bao_jsc

// ========== Sizes ==========
// 严格翻译自 sizes.zig
// 此命名空间包含从代码生成器导出的 JSC C++ 类型尺寸/对齐常量
// 注意: 不要在新代码中依赖这些值。如果可能，重写旧代码以使用其他方法
// 将 C++ 类解释为原始字节是不可靠的，因为编译器不保证内存布局
public class Sizes {
    // 严格翻译自 Bun_FFI_PointerOffsetToArgumentsList
    // FFI 指针到 ArgumentsList 的偏移量
    public static let FFI_POINTER_OFFSET_TO_ARGUMENTS_LIST: Int64 = 6

    // 严格翻译自 Bun_FFI_PointerOffsetToTypedArrayVector
    // FFI 指针到 TypedArray 向量的偏移量
    public static let FFI_POINTER_OFFSET_TO_TYPED_ARRAY_VECTOR: Int64 = 16

    public init() {}
}
