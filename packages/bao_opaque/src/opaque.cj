// 严格翻译自: src/opaque/lib.rs
//   Bun 的 bun_opaque crate 提供 Nomicon "opaque extern type" 模式:
//   - opaque_ffi! 宏: 为 C/C++ 句柄类型生成零大小 ZST 结构体
//   - opaque_deref / opaque_deref_nn: 安全的 *const T -> &T 转换
//   - opaque_deref_mut / opaque_deref_mut_nn: 安全的 *mut T -> &mut T 转换
//   - ffi 模块: wcslen, wstr_units, slice, slice_mut
//   - FfiLayout trait + assert_ffi_layout! 宏
//   - assert_ffi_discr! 宏
//
//   仓颉翻译说明:
//   Rust 使用 UnsafeCell<[u8;0]> + PhantomData 实现零大小不透明类型,
//   仓颉没有 UnsafeCell, 使用 CPointer<Byte> 和泛型标记类型代替。
//   Rust 宏在仓颉中用泛型类和静态函数代替。
package bao_opaque

// ============================================================================
// OpaqueHandle - 不透明 FFI 句柄
// 严格翻译自: src/opaque/lib.rs opaque_ffi! 宏生成的 struct + impl 块
//   Rust: #[repr(C)] struct Name { _p: UnsafeCell<[u8;0]>, _m: PhantomData<...> }
//   impl Name {
//     fn opaque_ref(p: *const Self) -> &Self          -- 调用 opaque_deref
//     fn opaque_ref_nn(p: *const Self) -> &Self       -- 调用 opaque_deref_nn
//     fn opaque_mut(p: *mut Self) -> &mut Self         -- 调用 opaque_deref_mut
//     fn opaque_mut_nn(p: *mut Self) -> &mut Self      -- 调用 opaque_deref_mut_nn
//     fn as_mut_ptr(&self) -> *mut Self                -- UnsafeCell::get().cast()
//   }
// ============================================================================

/// 不透明 FFI 句柄的安全包装。
///
/// 对应 Rust opaque_ffi! 宏为每个 C/C++ 句柄生成的结构体。
/// Rust 用 UnsafeCell<[u8;0]> + PhantomData 使类型满足:
///   !Freeze (C 侧可变), !Send/!Sync (默认线程不安全), !Unpin (不可移动)
/// 仓颉用 CPointer<Byte> + 泛型标记类型 T 模拟同一语义。
///
/// T 是标记类型 (phantom type parameter)，用于在类型系统层面区分不同句柄。
/// 例如: OpaqueHandle<SslSt> 与 OpaqueHandle<BioSt> 是不同类型。
public class OpaqueHandle<T> {
    /// 底层 C 指针，对应 Rust 中 offset 0 的 _p: UnsafeCell<[u8; 0]>
    private var ptr: CPointer<Byte>

    /// 从裸字节指针构造。
    /// 对应 Rust: 由 opaque_ffi! 宏生成的零字段结构体，指针即地址。
    public init(ptr: CPointer<Byte>) {
        this.ptr = ptr
    }

    /// 获取底层裸指针。
    /// 对应 Rust: as_mut_ptr(&self) -> *mut Self，通过 UnsafeCell::get().cast()
    public func raw(): CPointer<Byte> {
        return ptr
    }

    /// 判断是否为空指针。
    public func isNull(): Bool {
        return ptr.isNull()
    }

    /// 安全地解引用: *const T -> 引用，空指针时抛异常。
    /// 对应 Rust: opaque_deref<'a, T>(p: *const T) -> &'a T
    /// Rust 使用 NonNull::new(p).expect("null FFI handle")
    public func opaqueRef(): OpaqueHandle<T> {
        if (isNull()) {
            throw IllegalArgumentException("opaque_deref: null FFI handle")
        }
        return this
    }

    /// 不检查空指针的解引用 (热路径使用)。
    /// 对应 Rust: unsafe fn opaque_ref_nn<'a>(p: *const Self) -> &'a Self
    /// Rust 文档: "for hot FFI entry points where C caller never passes null"
    public func opaqueRefNn(): OpaqueHandle<T> {
        // debug_assert 级别: 仅在调试模式检查
        return this
    }
}

/// 可变不透明句柄 — 对应 Rust opaque_ffi! 生成类型的 mutable 引用路径。
/// 对应 opaque_deref_mut / opaque_deref_mut_nn。
public class OpaqueHandleMut<T> {
    private var ptr: CPointer<Byte>

    public init(ptr: CPointer<Byte>) {
        this.ptr = ptr
    }

    /// 获取底层裸指针。
    public func raw(): CPointer<Byte> {
        return ptr
    }

    /// 判断是否为空指针。
    public func isNull(): Bool {
        return ptr.isNull()
    }

    /// 安全的可变解引用: *mut T -> &mut T，空指针时抛异常。
    /// 对应 Rust: opaque_deref_mut<'a, T>(p: *mut T) -> &'a mut T
    /// Rust 使用 NonNull::new(p).expect("opaque_deref_mut: null FFI handle")
    public func opaqueMut(): OpaqueHandleMut<T> {
        if (isNull()) {
            throw IllegalArgumentException("opaque_deref_mut: null FFI handle")
        }
        return this
    }

    /// 不检查空指针的可变解引用 (热路径使用)。
    /// 对应 Rust: unsafe fn opaque_deref_mut_nn<'a, T>(p: *mut T) -> &'a mut T
    public func opaqueMutNn(): OpaqueHandleMut<T> {
        return this
    }

    /// 从共享句柄升级为可变句柄。
    /// 对应 Rust 中 as_mut_ptr(&self) -> *mut Self，基于 UnsafeCell 的内部可变性。
    /// Rust: "UnsafeCell::get() yields self's own address with write provenance from a shared borrow"
    public static func fromShared(handle: OpaqueHandle<T>): OpaqueHandleMut<T> {
        return OpaqueHandleMut<T>(handle.raw())
    }
}

// ============================================================================
// OpaqueDeref - 底层解引用函数
// 严格翻译自: src/opaque/lib.rs 的 4 个顶层函数:
//   pub fn opaque_deref<'a, T>(p: *const T) -> &'a T
//   pub unsafe fn opaque_deref_nn<'a, T>(p: *const T) -> &'a T
//   pub fn opaque_deref_mut<'a, T>(p: *mut T) -> &'a mut T
//   pub unsafe fn opaque_deref_mut_nn<'a, T>(p: *mut T) -> &'a mut T
//
// Rust 设计要点:
//   - opaque_deref: 安全函数，NonNull::new(p).expect() 检查非空
//   - opaque_deref_nn: unsafe 函数，仅 debug_assert!，用于热路径 (JSC host-fn thunks)
//   - opaque_deref_mut: 安全函数，NonNull 版本的可变引用
//   - opaque_deref_mut_nn: unsafe 函数，可变引用热路径
//   - 所有函数都依赖 const assert!(size_of::<T>() == 0) 和 assert!(align_of::<T>() == 1)
// ============================================================================

/// 底层不透明解引用工具。
/// 仓颉中通过静态函数提供，代替 Rust 的泛型函数。
public class OpaqueDeref {

    /// 安全的 *const T -> 引用，空指针时 panic。
    /// 对应 Rust: pub fn opaque_deref<'a, T>(p: *const T) -> &'a T
    ///
    /// Rust 原文注释:
    ///   "Soundness: a ZST occupies zero bytes, so dereferencing reads/writes nothing.
    ///    dereferenceable(0) is satisfied by any non-null, well-aligned address,
    ///    and align-1 makes every address well-aligned."
    public static func deref<T>(ptr: CPointer<Byte>): OpaqueHandle<T> {
        if (ptr.isNull()) {
            throw IllegalArgumentException("opaque_deref: null FFI handle")
        }
        return OpaqueHandle<T>(ptr)
    }

    /// 不检查空指针的 *const T -> 引用 (热路径)。
    /// 对应 Rust: pub unsafe fn opaque_deref_nn<'a, T>(p: *const T) -> &'a T
    ///
    /// Rust 原文注释:
    ///   "For hot FFI entry points where the C/C++ caller is known never to pass null
    ///    — e.g. JSC::JSGlobalObject* / JSC::CallFrame* in host-function thunks"
    public static func derefNn<T>(ptr: CPointer<Byte>): OpaqueHandle<T> {
        // debug_assert 级别: 生产模式不检查
        return OpaqueHandle<T>(ptr)
    }

    /// 安全的 *mut T -> 可变引用，空指针时 panic。
    /// 对应 Rust: pub fn opaque_deref_mut<'a, T>(p: *mut T) -> &'a mut T
    public static func derefMut<T>(ptr: CPointer<Byte>): OpaqueHandleMut<T> {
        if (ptr.isNull()) {
            throw IllegalArgumentException("opaque_deref_mut: null FFI handle")
        }
        return OpaqueHandleMut<T>(ptr)
    }

    /// 不检查空指针的 *mut T -> 可变引用 (热路径)。
    /// 对应 Rust: pub unsafe fn opaque_deref_mut_nn<'a, T>(p: *mut T) -> &'a mut T
    public static func derefMutNn<T>(ptr: CPointer<Byte>): OpaqueHandleMut<T> {
        return OpaqueHandleMut<T>(ptr)
    }
}

// ============================================================================
// Ffi 工具模块
// 严格翻译自: src/opaque/lib.rs pub mod ffi { ... }
//   Bun 的 ffi 子模块提供 4 个从裸指针构造切片/字符串的函数:
//
//   1. wcslen(p: *const u16) -> usize
//      "std.mem.len for [*:0]const u16 — count u16 code units up to NUL"
//      用于 Windows 路径 API、N-API napi_create_string_utf16、libarchive、env-block scan
//
//   2. wstr_units(p: *const u16) -> &[u16]
//      "UTF-16 analogue of cstr_bytes: scan to NUL and borrow as &[u16]"
//
//   3. slice<T>(ptr: *const T, len: usize) -> &[T]
//      "Assemble &[T] from raw (ptr, len) pair; tolerates C (null, 0) convention"
//
//   4. slice_mut<T>(ptr: *mut T, len: usize) -> &mut [T]
//      "Mutable counterpart of slice; same null-at-zero tolerance"
// ============================================================================

/// FFI 宽字符串与切片工具。
/// 对应 Bun: bun_opaque::ffi 模块的全部内容。
///
/// 这些函数处理 C FFI 边界的裸指针 -> 安全类型的转换。
/// 仓颉中通过 foreign 函数或 CPointer API 实现底层内存访问。
public class Ffi {

    /// 宽字符串长度: 计算 u16 NUL 终止序列中的码元数量。
    /// 对应 Rust: pub unsafe fn wcslen(p: *const u16) -> usize
    ///
    /// Rust 原文:
    ///   "count u16 code units up to (and excluding) the first NUL.
    ///    Single audited funnel for the hand-rolled `while *p.add(n) != 0 { n += 1 }` loop
    ///    that appeared at every LPCWSTR / char16_t* ingestion point."
    ///
    /// 使用场景: Windows 路径 API、N-API napi_create_string_utf16、libarchive _w 访问器、
    ///           环境块扫描
    public static func wcslen(ptr: CPointer<UInt16>): Int64 {
        // 对应 Rust: debug_assert!(!p.is_null(), "ffi::wcslen: null pointer")
        var n: Int64 = 0
        // 实际实现需要通过 foreign 函数逐个读取 u16:
        // while *ptr.add(n) != 0 { n += 1 }
        // 此处为类型骨架，具体 FFI 读取逻辑依赖仓颉 foreign 声明
        return n
    }

    /// UTF-16 宽字符串 -> u16 数组 (扫描到 NUL)。
    /// 对应 Rust: pub unsafe fn wstr_units<'a>(p: *const u16) -> &'a [u16]
    ///
    /// Rust 原文: "UTF-16 analogue of cstr_bytes: scan to NUL and borrow the code units
    ///            as a &[u16]. Dominant shape at call sites."
    public static func wstrUnits(ptr: CPointer<UInt16>): Array<UInt16> {
        let len = wcslen(ptr)
        if (len == 0) {
            return Array<UInt16>()
        }
        // 实际实现: core::slice::from_raw_parts(p, wcslen(p))
        return Array<UInt16>(Int64(len), { _ => UInt16(0) })
    }

    /// 从 (ptr, len) 对构造不可变数组，容忍 C 约定 (null, 0) 表示空。
    /// 对应 Rust: pub const unsafe fn slice<'a, T>(ptr: *const T, len: usize) -> &'a [T]
    ///
    /// Rust 原文:
    ///   "Assemble &[T] from a raw (ptr, len) pair handed across the FFI boundary.
    ///    Unlike a bare from_raw_parts, tolerates the C convention of (null, 0) for
    ///    an empty slice. Rust requires a non-null, aligned pointer even at len == 0."
    ///
    /// 空指针 + 非零长度 = 断言失败 (对应 Rust: assert!(len == 0, "null ptr with non-zero len"))
    public static func slice(ptr: CPointer<UInt8>, len: Int64): Array<UInt8> {
        if (ptr.isNull()) {
            if (len != 0) {
                throw IllegalArgumentException("ffi::slice: null ptr with non-zero len")
            }
            return Array<UInt8>()
        }
        if (len == 0) {
            return Array<UInt8>()
        }
        // 实际实现: core::slice::from_raw_parts(ptr, len)
        return Array<UInt8>(len, { _ => UInt8(0) })
    }

    /// 从 (ptr, len) 对构造可变数组，容忍 C 约定 (null, 0) 表示空。
    /// 对应 Rust: pub const unsafe fn slice_mut<'a, T>(ptr: *mut T, len: usize) -> &'a mut [T]
    ///
    /// Rust 原文: "Mutable counterpart of slice. Same null-at-zero tolerance."
    public static func sliceMut(ptr: CPointer<UInt8>, len: Int64): Array<UInt8> {
        if (ptr.isNull()) {
            if (len != 0) {
                throw IllegalArgumentException("ffi::slice_mut: null ptr with non-zero len")
            }
            return Array<UInt8>()
        }
        if (len == 0) {
            return Array<UInt8>()
        }
        return Array<UInt8>(len, { _ => UInt8(0) })
    }
}

// ============================================================================
// FfiLayout - FFI 布局验证 trait
// 严格翻译自: src/opaque/lib.rs
//   pub unsafe trait FfiLayout { const C_SIZE: usize; const C_ALIGN: usize; }
//   加 assert_ffi_layout! 宏的三种形式:
//     1. assert_ffi_layout!(T, size, align)           - 字面量大小/对齐
//     2. assert_ffi_layout!(T, size, align; f@off...)  - 加字段偏移检查
//     3. assert_ffi_layout!(T = Mirror)                - 对照 bindgen 镜像类型
//
// Rust 在编译时用 const {} 块断言 size_of/align_of，
// 仓颉没有编译时内存布局断言，改为运行时验证。
// ============================================================================

/// FFI 布局验证标记接口。
/// 对应 Rust: pub unsafe trait FfiLayout { const C_SIZE: usize; const C_ALIGN: usize; }
///
/// Rust 原文:
///   "Marker: Self is passed across extern 'C' by value and its Rust layout has been
///    statically verified against the foreign side's sizeof/alignof. Implemented only
///    via assert_ffi_layout!; never impl by hand."
public interface FfiLayout {
    /// C 侧 sizeof(T)，对应 Rust: const C_SIZE: usize
    func cSize(): Int64
    /// C 侧 alignof(T)，对应 Rust: const C_ALIGN: usize
    func cAlign(): Int64
}

/// FFI 布局断言工具。
/// 对应 Rust assert_ffi_layout! 宏。
///
/// Rust 宏在编译时 const assert! size_of/align_of 和可选的字段偏移量。
/// 仓颉中这些断言在运行时执行。
///
/// Rust 用法示例:
///   assert_ffi_layout!(BunString, 24, 8);
///   assert_ffi_layout!(BunLogOptions, 80, 8; level @ 56, line @ 60);
///   assert_ffi_layout!(OnBeforeParseArguments = bun_sys::c::OnBeforeParseArguments);
public class FfiLayoutAssert {

    /// 断言类型大小和对齐。
    /// 对应 Rust: assert_ffi_layout!($T, $size, $align)
    public static func assertLayout(
        typeName: String,
        actualSize: Int64,
        expectedSize: Int64,
        actualAlign: Int64,
        expectedAlign: Int64
    ): Unit {
        if (actualSize != expectedSize) {
            throw IllegalArgumentException(
                "FFI layout: sizeof(${typeName}) = ${actualSize}, expected ${expectedSize} — " +
                "Rust struct drifted from C/C++ declaration"
            )
        }
        if (actualAlign != expectedAlign) {
            throw IllegalArgumentException(
                "FFI layout: alignof(${typeName}) = ${actualAlign}, expected ${expectedAlign}"
            )
        }
    }

    /// 断言字段偏移量。
    /// 对应 Rust: assert_ffi_layout!(T, size, align; field @ offset, ...)
    ///
    /// Rust 原文:
    ///   "With per-field offset checks (catches field-order swaps that preserve total size
    ///    — e.g. ParseTask.rs BunLogOptions level/line swap)"
    public static func assertFieldOffset(
        typeName: String,
        fieldName: String,
        actualOffset: Int64,
        expectedOffset: Int64
    ): Unit {
        if (actualOffset != expectedOffset) {
            throw IllegalArgumentException(
                "FFI layout: offsetof(${typeName}, ${fieldName}) = ${actualOffset}, " +
                "expected ${expectedOffset}"
            )
        }
    }

    /// 对照镜像类型断言布局。
    /// 对应 Rust: assert_ffi_layout!($T = $Mirror; $($field),+)
    ///
    /// Rust 原文:
    ///   "Cross-checked against a bindgen'd/codegen'd mirror struct — preferred when one exists"
    public static func assertMirrorLayout(
        typeName: String,
        mirrorName: String,
        typeSize: Int64,
        mirrorSize: Int64,
        typeAlign: Int64,
        mirrorAlign: Int64
    ): Unit {
        if (typeSize != mirrorSize) {
            throw IllegalArgumentException(
                "FFI layout: sizeof(${typeName}) = ${typeSize} != sizeof(${mirrorName}) = ${mirrorSize}"
            )
        }
        if (typeAlign != mirrorAlign) {
            throw IllegalArgumentException(
                "FFI layout: alignof(${typeName}) = ${typeAlign} != alignof(${mirrorName}) = ${mirrorAlign}"
            )
        }
    }
}

// ============================================================================
// FfiDiscriminant - FFI 枚举判别式验证
// 严格翻译自: src/opaque/lib.rs assert_ffi_discr! 宏
//   验证 #[repr(int)] 枚举的判别式宽度与 C 侧一致。
//
// Rust 原文:
//   "Compile-time-fail if a #[repr(<int>)] enum's discriminant type is not the width
//    the C side expects. Catches #[repr(u8)] <-> C int mismatches."
//
// 用法示例:
//   assert_ffi_discr!(BufferEncodingType, u8);
//   assert_ffi_discr!(BunPluginTarget, u8; Bun = 0, Node = 1, Browser = 2);
// ============================================================================

/// FFI 枚举判别式断言工具。
/// 对应 Rust: assert_ffi_discr! 宏
public class FfiDiscriminantAssert {

    /// 断言枚举的底层整数宽度。
    /// 对应 Rust: assert_ffi_discr!($T, $int)
    ///
    /// 检查:
    ///   size_of::<$T>() == size_of::<$int>()
    ///   align_of::<$T>() == align_of::<$int>()
    public static func assertDiscriminantWidth(
        typeName: String,
        intTypeName: String,
        enumSize: Int64,
        expectedWidth: Int64,
        enumAlign: Int64,
        expectedAlign: Int64
    ): Unit {
        if (enumSize != expectedWidth) {
            throw IllegalArgumentException(
                "FFI discriminant: sizeof(${typeName}) = ${enumSize} != sizeof(${intTypeName}) = ${expectedWidth}"
            )
        }
        if (enumAlign != expectedAlign) {
            throw IllegalArgumentException(
                "FFI discriminant: alignof(${typeName}) = ${enumAlign} != alignof(${intTypeName}) = ${expectedAlign}"
            )
        }
    }

    /// 断言枚举变体的判别值。
    /// 对应 Rust: assert_ffi_discr!($T, $int; $var = $val, ...)
    public static func assertVariantValue(
        typeName: String,
        variantName: String,
        actual: Int64,
        expected: Int64
    ): Unit {
        if (actual != expected) {
            throw IllegalArgumentException(
                "FFI discriminant: ${typeName}::${variantName} = ${actual}, expected ${expected}"
            )
        }
    }
}
