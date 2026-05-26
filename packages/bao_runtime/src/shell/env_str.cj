// 严格翻译自: src/runtime/shell/EnvStr.zig
// 环境变量字符串 — 环境变量字符串需要大量复制，所以使用引用计数。
// 但有时使用静态分配或有预定生命周期的字符串，不需要堆分配。
// 因此环境变量字符串可以是引用计数的，也可以是借用的切片。

package bao_runtime.shell

import bao_core.*

// ============================================================================
// 环境变量字符串
// 对应 Bun: EnvStr.zig
//
// 环境变量字符串需要大量复制，所以使用引用计数。
// 但有时使用静态分配或有预定生命周期的字符串（例如 AST 中的字符串），
// 在这种情况下不希望产生堆分配和引用计数的开销。
// 因此环境变量字符串可以是引用计数的，也可以是借用的切片。
//
// 在 Bun (Zig) 中，这是一个 packed struct(u128):
//   ptr: u48, tag: Tag(u16), len: usize
// 总共 128 位 (16 字节)，可以直接在寄存器中传递。
// ============================================================================

/// 环境变量字符串标签
/// 对应 Bun: EnvStr.Tag (enum(u16))
public enum EnvStrTag {
    /// 空值
    | empty
    /// 通过引用计数释放
    | refcounted
    /// 内存由其他地方管理，不需要释放
    | slice

    public operator func ==(rhs: EnvStrTag): Bool {
        match (this) {
            case empty => match (rhs) { case empty => true; case _ => false }
            case refcounted => match (rhs) { case refcounted => true; case _ => false }
            case slice => match (rhs) { case slice => true; case _ => false }
        }
    }

    public operator func !=(rhs: EnvStrTag): Bool {
        !(this == rhs)
    }
}

/// 环境变量字符串
/// 可以是引用计数的或借用的切片。
/// 对应 Bun: EnvStr (packed struct(u128))
///
/// 设计目标:
/// - 零拷贝: 借用切片不增加引用计数
/// - 高效复制: 整个结构体只有 16 字节，可以廉价复制
/// - 自动释放: 引用计数字符串在引用计数归零时自动释放
public struct EnvStr {
    /// 标签 — 标识当前是哪种类型的字符串
    public var tag: EnvStrTag = EnvStrTag.empty
    /// 长度
    public var len: UInt64 = 0
    /// 数据
    public var data: Array<Byte>

    public init() {
        data = Array<Byte>()
    }

    // ========================================================================
    // 初始化方法
    // ========================================================================

    /// 从切片初始化（借用，不增加引用计数）
    /// 对应 Bun: EnvStr.initSlice(str)
    /// 零长度字符串返回 empty 标签，避免无效指针。
    public static func initSlice(str: Array<Byte>): EnvStr {
        if (str.size == 0) {
            // 零长度字符串可能有无效指针，导致错误的整数转换。
            var es = EnvStr()
            es.tag = EnvStrTag.empty
            es.len = 0
            es.data = Array<Byte>()
            return es
        }
        var es = EnvStr()
        es.tag = EnvStrTag.slice
        es.len = UInt64(str.size)
        es.data = str
        return es
    }

    /// 从引用计数字符串初始化
    /// 对应 Bun: EnvStr.initRefCounted(str)
    /// 创建一个 RefCountedStr 来管理字符串的生命周期。
    public static func initRefCounted(str: Array<Byte>): EnvStr {
        if (str.size == 0) {
            var es = EnvStr()
            es.tag = EnvStrTag.empty
            es.len = 0
            es.data = Array<Byte>()
            return es
        }
        let refc = RefCountedStr.initFunc(str)
        var es = EnvStr()
        es.tag = EnvStrTag.refcounted
        es.len = UInt64(str.size)
        es.data = refc.byteSlice()
        return es
    }

    /// 复制并创建引用计数字符串
    /// 对应 Bun: EnvStr.dupeRefCounted(old_str)
    /// 与 initRefCounted 不同，此方法会复制传入的字符串。
    /// 适用于字符串生命周期不确定的情况。
    public static func dupeRefCounted(oldStr: Array<Byte>): EnvStr {
        if (oldStr.size == 0) {
            var es = EnvStr()
            es.tag = EnvStrTag.empty
            es.len = 0
            es.data = Array<Byte>()
            return es
        }
        let str = oldStr.clone()
        let refc = RefCountedStr.initFunc(str)
        var es = EnvStr()
        es.tag = EnvStrTag.refcounted
        es.len = UInt64(str.size)
        es.data = refc.byteSlice()
        return es
    }

    // ========================================================================
    // 访问方法
    // ========================================================================

    /// 获取字节切片
    /// 对应 Bun: EnvStr.slice()
    /// 根据标签类型返回不同的切片:
    /// - empty: 空字符串
    /// - slice: 直接返回借用的切片
    /// - refcounted: 返回引用计数字符串的字节切片
    public func slice(): Array<Byte> {
        match (this.tag) {
            case empty =>
                Array<Byte>()
            case slice =>
                if (this.len == 0) {
                    Array<Byte>()
                } else {
                    this.data[0..Int64(this.len)]
                }
            case refcounted =>
                if (this.len == 0) {
                    Array<Byte>()
                } else {
                    this.data[0..Int64(this.len)]
                }
        }
    }

    // ========================================================================
    // 内存管理方法
    // ========================================================================

    /// 内存开销
    /// 对应 Bun: EnvStr.memoryCost()
    /// 计算此字符串占用的实际内存大小。
    /// 对于引用计数字符串，除以引用计数（因为多个 EnvStr 共享同一内存）。
    public func memoryCost(): UInt64 {
        if (this.len == 0) {
            return 0
        }
        let divisor: UInt64 = match (this.asRefCounted()) {
            case Some(refc) => UInt64(refc.refcount)
            case None => 1
        }
        if (divisor == 0) {
            return 0
        }
        return this.len / divisor
    }

    /// 增加引用计数
    /// 对应 Bun: EnvStr.ref()
    /// 仅对引用计数类型的字符串有效。
    public func ref() {
        if (let Some(refc) <- this.asRefCounted()) {
            refc.ref()
        }
    }

    /// 减少引用计数
    /// 对应 Bun: EnvStr.deref()
    /// 仅对引用计数类型的字符串有效。
    /// 引用计数归零时自动释放字符串内存。
    public func deref() {
        if (let Some(refc) <- this.asRefCounted()) {
            refc.deref()
        }
    }

    // ========================================================================
    // 内部辅助方法
    // ========================================================================

    /// 获取引用计数字符串（如果当前是引用计数类型）
    /// 对应 Bun: EnvStr.asRefCounted()
    func asRefCounted(): ?RefCountedStr {
        if (this.tag == EnvStrTag.refcounted) {
            return this.castRefCounted()
        }
        return None
    }

    /// 将数据转换为引用计数字符串
    /// 对应 Bun: EnvStr.castRefCounted()
    /// 从指针重建 RefCountedStr 对象。
    func castRefCounted(): RefCountedStr {
        // 在 Bun (Zig) 中，这是通过 @ptrFromInt 从 ptr 字段重建的。
        // 在 Cangjie 中，我们需要从 data 字段重建。
        let refc = RefCountedStr()
        refc.ptr = this.data
        refc.len = UInt32(this.len)
        return refc
    }
}
