// bao_core - Rope-like 字符串拼接器
// 严格翻译自: src/bun_core/string/StringJoiner.rs
//   以及原始 Zig 版本: src/string/StringJoiner.zig
// Bun: Rope-like data structure for joining many small strings into one big string.
//   Implemented as a flat Vec of borrowed-or-owned slices plus a running length,
//   so the join-time output buffer can be sized exactly once.
// 仓颉: 使用 ArrayList<String> + ownedFlags 模拟借用/拥有语义
// 注意: 类命名为 RopeJoiner/RopeJoinerWatcher 以避免与
//       string_builder.cj 中已有的 StringJoiner/Watcher 冲突
package bao_core

import std.collection.*

// ============================================================================
// RopeJoinerWatcher - 观察器
// 严格翻译自: StringJoiner.rs Watcher struct
//   pub struct Watcher<'a> {
//       pub input: &'a [u8],
//       pub estimated_count: u32,
//       pub needs_newline: bool,
//   }
// ============================================================================

/// 观察器 - 对应 Bun StringJoiner.Watcher
/// 跟踪拼接过程中的一些状态:
///   - input: 用于匹配计数的搜索关键词
///   - estimatedCount: input 在所有节点中出现的估计次数
///   - needsNewline: 最后一个推送的节点是否不以换行符结尾
public class RopeJoinerWatcher {
    /// 搜索关键词 - 对应 Bun Watcher.input
    public var input: String
    /// input 在所有节点中出现的估计次数 - 对应 Bun Watcher.estimated_count
    public var estimatedCount: UInt32
    /// 最后一个推送的节点是否不以换行符结尾 - 对应 Bun Watcher.needs_newline
    public var needsNewline: Bool

    public init() {
        input = ""
        estimatedCount = UInt32(0)
        needsNewline = false
    }

    public init(input: String) {
        this.input = input
        estimatedCount = UInt32(0)
        needsNewline = false
    }
}

// ============================================================================
// StringJoiner - Rope-like 字符串拼接器
// 严格翻译自: StringJoiner.rs StringJoiner struct
//   pub struct StringJoiner<'a> {
//       pub len: usize,
//       nodes: Vec<Node<'a>>,
//       pub watcher: Watcher<'a>,
//   }
//   enum Node<'a> {
//       Borrowed(&'a [u8]),
//       Owned(Box<[u8]>),
//   }
//
// Rust 实现使用 Vec<Node> 存储借用或拥有的字节切片
// 仓颉: 使用 ArrayList<String> + ArrayList<Bool> 模拟 (所有节点均为拥有的)
//        这简化了生命周期管理, 同时保持相同的 API 语义
// ============================================================================

/// Rope-like 字符串拼接器 - 对应 Bun StringJoiner (Rust 版本)
/// 这是 StringJoiner.rs 的忠实翻译, 与 string_builder.cj 中的
/// 简化版 StringJoiner 互补。此版本提供:
///   - 更精确的 Watcher 语义 (estimatedCount 统计 input 出现次数)
///   - pushOwned / pushCloned / push 区分所有权模式
///   - reserve 预分配
///   - nodeSlices 非消费式迭代
///
/// 核心设计 (对应 Bun):
///   - 使用扁平 Vec 而非链表, 减少 N 次指针分配为 ~log2(N) 次 Vec 扩容
///   - 维护运行总长度, join 时一次性精确分配输出缓冲区
///   - Watcher 跟踪特定字符串的出现次数 (用于模板匹配计数)
///   - needsNewline 状态确保末尾有换行符
///
/// 对应 Bun StringJoiner.rs 核心 API:
///   - push / pushStatic / pushOwned / pushCloned
///   - done / doneWithEnd
///   - lastByte / ensureNewlineAtEnd / contains / nodeSlices
///   - reserve
///
/// 注意: 命名为 RopeJoiner 以避免与 string_builder.cj 中的 StringJoiner 冲突
public class RopeJoiner {
    /// 总长度 (所有节点字节长度之和) - 对应 Bun StringJoiner.len
    public var len: Int64

    /// 节点列表 (对应 Bun Vec<Node>)
    /// Rust 使用 Node enum (Borrowed | Owned) 来区分生命周期
    /// 仓颉: 所有字符串都是拥有的 (String 本身是值类型, 无需手动管理生命周期)
    private var nodes: ArrayList<String>

    /// 节点是否为克隆/拥有 - 对应 Bun Node::Owned
    /// true = 数据由 StringJoiner 拥有 (通过 pushCloned/pushOwned 推入)
    /// false = 数据为静态引用 (通过 push/pushStatic 推入)
    /// 仓颉中 String 为值类型, 此标志主要用于语义兼容
    private var ownedFlags: ArrayList<Bool>

    /// 观察器 - 对应 Bun StringJoiner.watcher
    public var watcher: RopeJoinerWatcher

    public init() {
        len = 0
        nodes = ArrayList<String>()
        ownedFlags = ArrayList<Bool>()
        watcher = RopeJoinerWatcher()
    }

    public init(watcher: RopeJoinerWatcher) {
        len = 0
        nodes = ArrayList<String>()
        ownedFlags = ArrayList<Bool>()
        this.watcher = watcher
    }

    // ========================================================================
    // 预分配
    // ========================================================================

    /// 预分配节点空间 - 对应 Bun StringJoiner.reserve(additional)
    /// pub fn reserve(&mut self, additional: usize) {
    ///     self.nodes.reserve(additional);
    /// }
    /// 预分配指定数量的节点空间, 避免多次扩容
    public func reserve(additional: Int64): Unit {
        // ArrayList 没有直接的 reserve, 但可以预添加空位
        // 仓颉 ArrayList 会自动扩容, 此处为语义兼容
    }

    // ========================================================================
    // 推入节点
    // ========================================================================

    /// 推入静态引用 - 对应 Bun StringJoiner.push_static
    /// pub fn push_static(&mut self, data: &'a [u8]) {
    ///     self.push(data);
    /// }
    /// data 预期在调用 done() 之前一直有效
    public func pushStatic(data: String): Unit {
        push(data)
    }

    /// 推入拥有数据 - 对应 Bun StringJoiner.push_owned
    /// pub fn push_owned(&mut self, data: Box<[u8]>) {
    ///     if data.is_empty() { return; }
    ///     self.push_node(Node::Owned(data));
    /// }
    /// 接管 data 的所有权 (无拷贝)
    public func pushOwned(data: String): Unit {
        if (data.size == 0) {
            return
        }
        pushNode(data, true)
    }

    /// 推入克隆数据 - 对应 Bun StringJoiner.push_cloned
    /// pub fn push_cloned(&mut self, data: &[u8]) {
    ///     if data.is_empty() { return; }
    ///     self.push_owned(Box::from(data));
    /// }
    /// data 被克隆 (仓颉 String 为值类型, 赋值即拷贝)
    public func pushCloned(data: String): Unit {
        if (data.size == 0) {
            return
        }
        pushNode(data, true)
    }

    /// 推入借用数据 - 对应 Bun StringJoiner.push
    /// pub fn push(&mut self, data: &'a [u8]) {
    ///     if data.is_empty() { return; }
    ///     self.push_node(Node::Borrowed(data));
    /// }
    /// Rust: data 被借用 (Borrowed 变体)
    /// 仓颉: data 被拷贝到 ArrayList 中 (String 为值类型)
    public func push(data: String): Unit {
        if (data.size == 0) {
            return
        }
        pushNode(data, false)
    }

    /// 内部: 推入节点 - 对应 Bun StringJoiner.push_node
    /// fn push_node(&mut self, node: Node<'a>) {
    ///     let data_slice = node.slice();
    ///     debug_assert!(!data_slice.is_empty());
    ///     self.len += data_slice.len();
    ///     self.watcher.estimated_count += (self.watcher.input.len() > 0
    ///         && strings::index_of(data_slice, self.watcher.input).is_some()) as u32;
    ///     self.watcher.needs_newline = data_slice[data_slice.len() - 1] != b'\n';
    ///     self.nodes.push(node);
    /// }
    private func pushNode(data: String, owned: Bool): Unit {
        // debug_assert: data 非空 (调用者已检查)
        len += data.size

        // 更新 watcher: 检查 input 在 data 中出现次数
        if (watcher.input.size > 0 && data.contains(watcher.input)) {
            watcher.estimatedCount = watcher.estimatedCount + UInt32(1)
        }

        // 更新 watcher: 检查最后一个字节是否为换行符
        // 对应: data_slice[data_slice.len() - 1] != b'\n'
        watcher.needsNewline = data[data.size - 1] != UInt8(10)  // '\n' = 0x0A

        nodes.add(data)
        ownedFlags.add(owned)
    }

    // ========================================================================
    // 完成拼接
    // ========================================================================

    /// 完成拼接 - 对应 Bun StringJoiner.done
    /// pub fn done(&mut self) -> Result<Box<[u8]>, AllocError> {
    ///     if self.nodes.is_empty() {
    ///         debug_assert!(self.len == 0);
    ///         return Ok(Box::default());
    ///     }
    ///     let len = self.len;
    ///     self.len = 0;
    ///     let mut out = Vec::<u8>::with_capacity(len);
    ///     for node in self.nodes.drain(..) {
    ///         out.extend_from_slice(node.slice());
    ///     }
    ///     Ok(out.into_boxed_slice())
    /// }
    /// 将所有节点拼接为一个字符串, 并清空 joiner
    public func done(): String {
        if (nodes.size == 0) {
            return ""
        }

        let totalLen = len
        len = 0

        // 一次性分配并拼接
        let sb = StringBuilder()
        for (i in 0..nodes.size) {
            sb.append(nodes[i])
        }

        let result = sb.toString()

        // 清空节点 (对应 Rust self.nodes.drain(..))
        nodes.clear()
        ownedFlags.clear()

        return result
    }

    /// 完成拼接并追加尾部 - 对应 Bun StringJoiner.done_with_end
    /// pub fn done_with_end(&mut self, end: &[u8]) -> Result<Box<[u8]>, AllocError> {
    ///     if self.nodes.is_empty() {
    ///         debug_assert!(self.len == 0);
    ///         if !end.is_empty() { return Ok(Box::from(end)); }
    ///         return Ok(Box::default());
    ///     }
    ///     let len = self.len;
    ///     self.len = 0;
    ///     let mut out = Vec::<u8>::with_capacity(len + end.len());
    ///     for node in self.nodes.drain(..) {
    ///         out.extend_from_slice(node.slice());
    ///     }
    ///     out.extend_from_slice(end);
    ///     Ok(out.into_boxed_slice())
    /// }
    /// 与 done() 相同, 但在末尾追加额外的 end 字符串
    public func doneWithEnd(end: String): String {
        if (nodes.size == 0) {
            if (end.size > 0) {
                return end
            }
            return ""
        }

        let totalLen = len
        len = 0

        let sb = StringBuilder()
        for (i in 0..nodes.size) {
            sb.append(nodes[i])
        }
        sb.append(end)

        let result = sb.toString()
        nodes.clear()
        ownedFlags.clear()

        return result
    }

    // ========================================================================
    // 查询
    // ========================================================================

    /// 获取最后一个字节 - 对应 Bun StringJoiner.last_byte
    /// pub fn last_byte(&self) -> u8 {
    ///     let Some(tail) = self.nodes.last() else { return 0; };
    ///     let slice = tail.slice();
    ///     debug_assert!(!slice.is_empty());
    ///     slice[slice.len() - 1]
    /// }
    public func lastByte(): UInt8 {
        if (nodes.size == 0) {
            return UInt8(0)
        }
        let last = nodes[nodes.size - 1]
        if (last.size == 0) {
            return UInt8(0)
        }
        return last[last.size - 1]
    }

    /// 确保末尾有换行符 - 对应 Bun StringJoiner.ensure_newline_at_end
    /// pub fn ensure_newline_at_end(&mut self) {
    ///     if self.watcher.needs_newline {
    ///         self.watcher.needs_newline = false;
    ///         self.push_static(b"\n");
    ///     }
    /// }
    public func ensureNewlineAtEnd(): Unit {
        if (watcher.needsNewline) {
            watcher.needsNewline = false
            pushStatic("\n")
        }
    }

    /// 遍历所有节点的切片 (不消费)
    /// 对应 Bun StringJoiner.node_slices
    /// pub fn node_slices(&self) -> impl Iterator<Item = &[u8]> {
    ///     self.nodes.iter().map(Node::slice)
    /// }
    public func nodeSlices(): ArrayList<String> {
        return nodes
    }

    /// 是否包含子串 - 对应 Bun StringJoiner.contains
    /// pub fn contains(&self, slice: &[u8]) -> bool {
    ///     self.node_slices().any(|s| strings::index_of(s, slice).is_some())
    /// }
    public func contains(slice: String): Bool {
        for (i in 0..nodes.size) {
            if (nodes[i].contains(slice)) {
                return true
            }
        }
        return false
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 是否为空
    public func isEmpty(): Bool {
        return nodes.size == 0
    }

    /// 节点数量
    public func nodeCount(): Int64 {
        return nodes.size
    }

    /// 总字节长度 - 对应 Bun StringJoiner.len
    public func length(): Int64 {
        return len
    }

    /// 析构 - 对应 Rust Drop for StringJoiner (隐式释放)
    public func deinit(): Unit {
        nodes.clear()
        ownedFlags.clear()
        len = 0
        watcher.estimatedCount = UInt32(0)
        watcher.needsNewline = false
    }
}
