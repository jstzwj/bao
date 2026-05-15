// 严格翻译自: src/string/PathString.zig
// 路径字符串
//   将路径指针和长度打包为紧凑的结构
//   在 64 位系统上,使用 53 位存储指针(因为 x64 只用 46 位),
//   剩余 11 位存储长度,全部塞进一个 64 位整数中
//   在仓颉中用字符串引用实现类似语义
package bao_string

// ============================================================================
// PathString
// 严格翻译自: src/string/PathString.zig
// ============================================================================

/// 路径字符串: 轻量级路径引用
/// 严格翻译自 PathString.zig PathString
/// Zig 原版使用 packed struct 将 ptr+len 塞进一个 u64/u128
/// 仓颉版本用 String 引用实现等价语义
public class PathString {
    /// 底层字符串
    private var path: String

    /// 空构造
    public init() {
        this.path = ""
    }

    /// 从字符串构造
    public init(path: String) {
        this.path = path
    }

    /// 从字节数组构造
    public init(bytes: Array<Byte>) {
        this.path = String.fromUtf8(bytes)
    }

    /// 空 PathString
    /// 严格翻译自 PathString.empty
    public static func empty(): PathString {
        return PathString("")
    }

    /// 创建一个借用切片的 PathString(不分配)
    /// 严格翻译自 PathString.init
    public static func init(str: String): PathString {
        return PathString(str)
    }

    /// 获取底层切片
    /// 严格翻译自 PathString.slice
    public func slice(): String {
        return this.path
    }

    /// 获取以 null 结尾的切片(在仓颉中返回等价字符串)
    /// 严格翻译自 PathString.sliceAssumeZ
    public func sliceAssumeZ(): String {
        return this.path
    }

    /// 判断是否为空
    /// 严格翻译自 PathString.isEmpty
    public func isEmpty(): Bool {
        return this.path.size == 0
    }

    /// 估算大小
    /// 严格翻译自 PathString.estimatedSize
    public func estimatedSize(): Int64 {
        return this.path.size
    }

    /// 字符串表示
    public func toString(): String {
        return this.path
    }
}
