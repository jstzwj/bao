// bao_opaque - 不透明 FFI 指针类型工具
// 严格翻译自: src/opaque/lib.rs
//   Bun 通过此 crate 为所有 C/C++ 句柄类型提供统一的 "Nomicon opaque extern type" 模式
//   核心思想: 对只通过指针观察的 C 类型，用零大小 ZST + UnsafeCell 表示
//   这确保:
//     1. !Freeze (UnsafeCell) -> &T 不声称不可变，C 侧可自由修改
//     2. !Send + !Sync (PhantomData<*mut u8>) -> 默认线程不安全
//     3. !Unpin (PhantomPinned) -> 外部对象地址即身份，不可移动
//     4. ZST align-1 -> &T 等价于非空裸指针，FFI 无额外约束
//
// 在仓颉中，使用 foreign 关键字声明外部类型，不透明指针通过 CPointer<T> 表示
// 此包的完整实现在 opaque.cj 中，提供:
//   1. OpaqueHandle<T> / OpaqueHandleMut<T> - 不透明 FFI 句柄的安全包装
//   2. OpaqueDeref - 底层解引用函数 (deref/derefNn/derefMut/derefMutNn)
//   3. Ffi - FFI 切片/字符串工具 (wcslen/wstrUnits/slice/sliceMut)
//   4. FfiLayout + FfiLayoutAssert - FFI 布局验证
//   5. FfiDiscriminantAssert - FFI 枚举判别式验证
package bao_opaque
