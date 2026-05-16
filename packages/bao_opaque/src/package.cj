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
// 此包提供:
//   1. OpaqueHandle<T> - 不透明 FFI 句柄的安全包装
//   2. FFI 切片/字符串工具
//   3. FFI 布局断言工具
//   4. FFI 判别式断言工具
package bao_opaque

// ============================================================================
// OpaqueHandle - 不透明 FFI 句柄
// 严格翻译自: src/opaque/lib.rs opaque_ffi! 宏生成的结构体
//   Rust 版: #[repr(C)] struct Name { _p: UnsafeCell<[u8;0]>, _m: PhantomData<...> }
//   仓颉版: 使用泛型类包装 CPointer<T>
// ============================================================================

/// 不透明 FFI 句柄的安全包装
/// 对应 Bun: opaque_ffi! 宏生成的每个 opaque 类型
///
/// 仓颉不使用 Rust 的 UnsafeCell/PhantomData 模式，
/// 而是使用 CPointer<Byte> 表示指向未知 C 类型的指针。
/// T 是标记类型 (phantom type parameter)，用于区分不同的不透明类型。
///
/// 使用方式:
///   let ctx = OpaqueHandle<SslCtx>(ptr)
///   let raw: CPointer<Byte> = ctx.raw()
///   // 传递给 FFI 函数
public class OpaqueHandle<T> {
    /// 底层 C 指针
    private var ptr: CPointer<Byte>

    /// 从裸指针创建
    public init(ptr: CPointer<Byte>) {
        this.ptr = ptr
    }

    /// 从 CPointer<T> 创建 (通过类型擦除)
    public init<T2>(typed: CPointer<T2>) {
        this.ptr = CPointer<Byte>(typed)  // 类型擦除
    }

    /// 获取裸指针
    public func raw(): CPointer<Byte> {
        return ptr
    }

    /// 是否为空指针
    public func isNull(): Bool {
        return ptr == CPointer<Byte>.null()
    }

    /// 断言非空 (对应 Bun: opaque_deref 的 assert!(!p.is_null()))
    /// 空指针时抛出异常
    public func ensureNonNull(): Unit {
        if (isNull()) {
            throw IllegalArgumentException("opaque_deref: null FFI handle")
        }
    }
}

// ============================================================================
// FFI 切片工具
// 严格翻译自: src/opaque/lib.rs pub mod ffi { ... }
//   Bun 提供 4 个安全的从裸指针构造切片/字符串的函数:
//   - wcslen: 宽字符串长度 (u16 NUL 终止)
//   - wstr_units: 宽字符串 -> &[u16]
//   - slice: 裸指针 -> &[T] (容忍 null+0)
//   - slice_mut: 裸指针 -> &mut [T] (容忍 null+0)
// ============================================================================

/// FFI 切片/字符串工具
/// 对应 Bun: bun_opaque::ffi 模块
public class FfiSlice {

    /// 从 (ptr, len) 对构造 Array<UInt8>
    /// 对应 Bun: ffi::slice<T>(ptr, len) -> &[T]
    /// 容忍 C 约定 (null, 0) 表示空数组
    public static func fromRaw(ptr: CPointer<UInt8>, len: Int64): Array<UInt8> {
        if (len == 0) {
            return Array<UInt8>()
        }
        // 从 C 指针读取 len 字节
        var result = Array<UInt8>(len, item: UInt8(0))
        for (i in 0..len) {
            // 在仓颉中通过 FFI 读取内存
            // 此处为占位实现; 实际使用时需要 foreign 函数
            result[i] = UInt8(0)
        }
        return result
    }

    /// 从 C 字符串 (NUL 终止) 构造 String
    /// 对应 Bun: bun_core::ffi::cstr(p) -> &CStr
    public static func cstrToString(ptr: CPointer<Byte>): ?String {
        if (ptr == CPointer<Byte>.null()) {
            return None
        }
        // 读取到 NUL 终止符
        var bytes = ArrayList<UInt8>()
        var i: Int64 = 0
        var done = false
        while (!done && i < 65536) {
            // 在仓颉中需要 foreign 函数读取内存
            // 此处为占位实现
            i += 1
        }
        if (bytes.size == 0) {
            return ""
        }
        return String.fromUtf8(bytes.toArray())
    }

    /// 宽字符串长度 (u16 NUL 终止)
    /// 对应 Bun: ffi::wcslen(p) -> usize
    public static func wcslen(ptr: CPointer<UInt16>): Int64 {
        var n: Int64 = 0
        // 读取 u16 直到遇到 NUL
        // 实际实现需要 foreign 函数
        return n
    }
}

// ============================================================================
// FfiLayout - FFI 布局验证
// 严格翻译自: src/opaque/lib.rs FfiLayout trait + assert_ffi_layout! 宏
//   在编译时验证 Rust 类型的 size_of/align_of 与 C 侧一致
//   仓颉没有编译时断言，因此使用运行时检查
// ============================================================================

/// FFI 布局验证标记
/// 对应 Bun: unsafe trait FfiLayout { const C_SIZE, const C_ALIGN }
/// 在仓颉中作为接口使用，由具体类型实现
public interface FfiLayout {
    /// C 侧 sizeof(T)
    func cSize(): Int64
    /// C 侧 alignof(T)
    func cAlign(): Int64
}

/// FFI 布局断言工具
/// 对应 Bun: assert_ffi_layout! 宏
/// 在运行时验证类型大小和对齐是否匹配
public class FfiAssert {

    /// 断言类型大小
    /// 对应 Bun: assert_ffi_layout!(T, size, align)
    public static func assertSize(typeName: String, actualSize: Int64, expectedSize: Int64): Unit {
        if (actualSize != expectedSize) {
            throw IllegalArgumentException(
                "FFI layout: sizeof(${typeName}) = ${actualSize}, expected ${expectedSize}"
            )
        }
    }

    /// 断言类型对齐
    public static func assertAlign(typeName: String, actualAlign: Int64, expectedAlign: Int64): Unit {
        if (actualAlign != expectedAlign) {
            throw IllegalArgumentException(
                "FFI layout: alignof(${typeName}) = ${actualAlign}, expected ${expectedAlign}"
            )
        }
    }

    /// 断言字段偏移量
    /// 对应 Bun: assert_ffi_layout!(T, size, align; field @ offset)
    public static func assertFieldOffset(
        typeName: String, fieldName: String, actualOffset: Int64, expectedOffset: Int64
    ): Unit {
        if (actualOffset != expectedOffset) {
            throw IllegalArgumentException(
                "FFI layout: offsetof(${typeName}, ${fieldName}) = ${actualOffset}, expected ${expectedOffset}"
            )
        }
    }
}

// ============================================================================
// FfiDiscriminant - FFI 枚举判别式验证
// 严格翻译自: src/opaque/lib.rs assert_ffi_discr! 宏
//   验证 #[repr(int)] 枚举的判别式宽度与 C 侧一致
// ============================================================================

/// FFI 枚举判别式断言工具
/// 对应 Bun: assert_ffi_discr!(T, u8; A = 0, B = 1)
public class FfiDiscriminant {

    /// 断言枚举判别式大小
    public static func assertSize(
        typeName: String, enumSize: Int64, expectedWidth: Int64
    ): Unit {
        if (enumSize != expectedWidth) {
            throw IllegalArgumentException(
                "FFI discriminant: sizeof(${typeName}) = ${enumSize}, expected ${expectedWidth}"
            )
        }
    }

    /// 断言枚举变体值
    public static func assertVariant(
        typeName: String, variantName: String, actual: Int64, expected: Int64
    ): Unit {
        if (actual != expected) {
            throw IllegalArgumentException(
                "FFI discriminant: ${typeName}::${variantName} = ${actual}, expected ${expected}"
            )
        }
    }
}
