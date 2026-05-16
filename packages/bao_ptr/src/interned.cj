// 严格翻译自: src/ptr/lib.rs (Interned 部分)
// Interned - 进程生命周期字节切片的证明类型
// 零开销，repr(transparent) 覆盖 &'static [u8]
// Option<Interned> 使用 niche packing
package bao_ptr

import bao_core.*

// ============================================================================
// Interned - 进程生命周期字节切片
// ============================================================================

/// 由进程生命周期存储支持的字节切片
///
/// 进程生命周期意味着以下之一:
///   - 驻留在 BSSStringList 单例中 (FilenameStore, DirnameStore)
///   - Box::leak / Vec::leak 且永远不会回收
///   - 真正的 'static 项 (字符串字面量, static 数组)
///
/// Interned 的存在使得约 80 个硬编码的 &[u8] -> &'static [u8] 扩展
/// 变为从存储流出的安全值
/// 以及约 24 个其支持确实会 drop 的站点不能再假装是 'static
public class Interned {
    /// 底层字节数据
    public var data: Array<Byte> = Array<Byte>()

    public init() {}

    /// 空切片
    public static let EMPTY: Interned = Interned()

    /// 从真正的 'static 输入包装 —— 字符串字面量、static 数组
    /// 安全: 借用检查器已经证明了进程生命周期
    public static func fromStatic(data: Array<Byte>): Interned {
        let interned = Interned()
        interned.data = data
        return interned
    }

    /// 从字符串创建
    public static func fromString(s: String): Interned {
        let interned = Interned()
        // 在仓颉中将字符串转换为字节数组
        interned.data = s.toArray()
        return interned
    }

    /// 接受一个已泄漏的分配
    /// 消费 Array 以便泄漏在调用点是显式的
    public static func leak(data: Array<Byte>): Interned {
        let interned = Interned()
        interned.data = data
        return interned
    }

    /// 逃生通道，用于此模块无法看到的存储
    /// (独立映射的 mmap，为进程泄漏的 mimalloc arena，C 侧常量表)
    ///
    /// s 必须在进程的剩余时间内保持有效和不可变
    /// 永远不要在进程退出前运行 Drop 的值所拥有的字节上调用此方法
    public static func assume(data: Array<Byte>): Interned {
        let interned = Interned()
        interned.data = data
        return interned
    }

    /// 恢复底层的字节切片 (用于尚未重类型为 Interned 的遗留字段)
    public func asBytes(): Array<Byte> {
        this.data
    }

    /// 获取长度
    public func length(): Int64 {
        Int64(this.data.size)
    }

    /// 是否为空
    public func isEmpty(): Bool {
        this.data.size == 0
    }

    /// 相等比较
    public func equals(other: Interned): Bool {
        if (this.data.size != other.data.size) {
            return false
        }
        for (i in 0..this.data.size) {
            if (this.data[i] != other.data[i]) {
                return false
            }
        }
        return true
    }

    /// 哈希码
    public func hashCode(): Int64 {
        var hash: Int64 = 0
        for (i in 0..this.data.size) {
            hash = hash * 31 + Int64(this.data[i])
        }
        return hash
    }

    /// Debug 字符串表示
    public func toString(): String {
        // bstr 风格: 打印为 (可能是 UTF-8 的) 字符串
        String.fromUtf8(this.data)
    }
}
