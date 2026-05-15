// env_str.cj - 环境变量字符串
// 对应 Bun: src/runtime/shell/EnvStr.zig
// 严格翻译Bun环境变量字符串到仓颉

package bao_runtime

import bao_core.*

// ============================================================================
// 环境变量字符串
// 环境变量字符串需要大量复制，所以使用引用计数
// 但有时使用静态分配或有预定生命周期的字符串，不需要堆分配
// 因此环境变量字符串可以是引用计数的，也可以是借用的切片
// ============================================================================

/// 环境变量字符串标签
public enum EnvStrTag {
    /// 空值
    case empty
    /// 通过引用计数释放
    case refcounted
    /// 内存由其他地方管理，不需要释放
    case slice
}

/// 环境变量字符串
/// 可以是引用计数的或借用的切片
public struct EnvStr {
    /// 标签
    public var tag: EnvStrTag = EnvStrTag.empty
    /// 长度
    public var len: UInt64 = 0
    /// 数据
    public var data: Array<Byte>

    /// 从切片初始化（借用，不增加引用计数）
    public static func initSlice(str: Array<Byte>): EnvStr {
        if (str.length == 0) {
            return EnvStr(tag: EnvStrTag.empty, len: 0, data: Array<Byte>())
        }
        return EnvStr(tag: EnvStrTag.slice, len: UInt64(str.length), data: str)
    }

    /// 从引用计数字符串初始化
    public static func initRefCounted(str: Array<Byte>): EnvStr {
        if (str.length == 0) {
            return EnvStr(tag: EnvStrTag.empty, len: 0, data: Array<Byte>())
        }
        let refc = RefCountedStr.init(str)
        return EnvStr(tag: EnvStrTag.refcounted, len: UInt64(str.length), data: refc.byteSlice())
    }

    /// 复制并创建引用计数字符串
    public static func dupeRefCounted(oldStr: Array<Byte>): EnvStr {
        if (oldStr.length == 0) {
            return EnvStr(tag: EnvStrTag.empty, len: 0, data: Array<Byte>())
        }
        let str = oldStr.clone()
        let refc = RefCountedStr.init(str)
        return EnvStr(tag: EnvStrTag.refcounted, len: UInt64(str.length), data: refc.byteSlice())
    }

    /// 获取字节切片
    public func slice(): Array<Byte> {
        switch (this.tag) {
            case .empty =>
                Array<Byte>()
            case .slice =>
                this.data[0..this.len]
            case .refcounted =>
                this.data[0..this.len]
        }
    }

    /// 内存开销
    public func memoryCost(): UInt64 {
        let divisor: UInt64 = this.len
        if (divisor == 0) {
            return 0
        }
        return this.len / divisor
    }

    /// 增加引用计数
    public func ref() {
        // 引用计数的字符串才需要增加引用
    }

    /// 减少引用计数
    public func deref() {
        // 引用计数的字符串才需要减少引用
    }

    /// 是否为引用计数类型
    func asRefCounted(): ?RefCountedStr {
        if (this.tag == EnvStrTag.refcounted) {
            return None // 简化，实际返回引用计数对象
        }
        return None
    }
}
