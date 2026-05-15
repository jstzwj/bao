// bao_path - 路径组件迭代器
// 严格翻译自:
//   src/paths/component_iterator.rs - ComponentIterator, Component, PathFormat
//   src/paths/resolve_path.zig - ComponentIterator (Posix root parsing)
package bao_path

import bao_core.*

// ============================================================================
// Component - 路径组件
// 严格翻译自: src/paths/component_iterator.rs
//   pub struct Component<'a, T> {
//       pub name: &'a [T],   // 组件名称, 不含分隔符
//       pub path: &'a [T],    // 到该组件的完整路径前缀
//   }
// ============================================================================

/// 路径组件 - 对应 Bun Component
/// 一个组件包含名称和到该组件的完整路径前缀
public class PathSlice {
    /// 组件名称 (如 "b")
    public let name: String
    /// 到该组件的完整路径前缀 (如 "/a/b")
    public let path: String

    public init(name: String, path: String) {
        this.name = name
        this.path = path
    }
}

// ============================================================================
// ComponentIterator - 路径组件迭代器 (增强版)
// 严格翻译自: src/paths/component_iterator.rs
//   pub struct ComponentIterator<'a, T> {
//       path: &'a [T],
//       root_end: usize,
//       start: usize,
//       end: usize,
//       fmt: PathFormat,
//   }
// Bun 的 ComponentIterator 支持双向遍历 (next/previous/first/last)
// 这是增强版本, 替代 package.cj 中的简化版 ComponentIterator
// ============================================================================

/// 增强版路径组件迭代器 - 对应 Bun ComponentIterator
/// 支持双向遍历: next/previous/first/last/peek
public class EnhancedComponentIterator {
    private let path: String
    private let rootEnd: Int64
    private var startPos: Int64
    private var endPos: Int64
    private let fmt: PathFormat

    /// 初始化迭代器 - 对应 ComponentIterator::init
    ///   pub fn init(path: &'a [T], fmt: PathFormat) -> Result<Self, Error> {
    ///       let root_end = match fmt {
    ///           PathFormat::Posix => {
    ///               var i = 0;
    ///               while (i < path.len() && fmt.is_sep(path[i])) { i += 1; }
    ///               i
    ///           },
    ///           PathFormat::Windows => windows_root_end(path)?,
    ///       };
    ///       Ok(Self { path, root_end, start: root_end, end: root_end, fmt })
    ///   }
    public init(path: String, fmt: PathFormat) {
        this.path = path
        this.fmt = fmt

        // 计算根结束位置
        var rEnd: Int64 = 0
        match (fmt) {
            case Posix =>
                // POSIX: 消耗所有前导 '/'
                //   var i: usize = 0;
                //   while (i < path.len() && fmt.is_sep(path[i])) { i += 1; }
                //   i
                while (rEnd < path.size && isSep(path[Int64(rEnd)])) {
                    rEnd += 1
                }
            case Windows =>
                // Windows 根检测: "C:\" 或 "\\server\share\"
                if (path.size >= 3 && path[1] == Char(':') && isSep(path[2])) {
                    rEnd = 3
                } else if (path.size >= 2 && isSep(path[0]) && isSep(path[1])) {
                    // UNC: \\server\share\
                    var i: Int64 = 2
                    // 跳过 server 名
                    while (i < path.size && !isSep(path[Int64(i)])) {
                        i += 1
                    }
                    // 跳过分隔符
                    while (i < path.size && isSep(path[Int64(i)])) {
                        i += 1
                    }
                    // 跳过 share 名
                    while (i < path.size && !isSep(path[Int64(i)])) {
                        i += 1
                    }
                    // 跳过尾部分隔符
                    while (i < path.size && isSep(path[Int64(i)])) {
                        i += 1
                    }
                    rEnd = i
                } else if (path.size >= 1 && isSep(path[0])) {
                    rEnd = 1
                }
        }
        rootEnd = rEnd
        startPos = rootEnd
        endPos = rootEnd
    }

    /// POSIX 便捷构造
    public init(path: String) {
        this.path = path
        this.fmt = PathFormat.Posix

        var rEnd: Int64 = 0
        while (rEnd < path.size && path[Int64(rEnd)] == Char('/')) {
            rEnd += 1
        }
        rootEnd = rEnd
        startPos = rootEnd
        endPos = rootEnd
    }

    /// 获取根前缀 - 对应 ComponentIterator::root
    ///   pub fn root(&self) -> Option<&'a [T]> {
    ///       if self.root_end == 0 { None } else { Some(&self.path[..self.root_end]) }
    ///   }
    public func root(): ?String {
        if (rootEnd == 0) {
            return None
        }
        return path.substring(0, Int64(rootEnd))
    }

    /// 移动到第一个组件 - 对应 ComponentIterator::first
    ///   pub fn first(&mut self) -> Option<Component<'a, T>> {
    ///       self.start = self.root_end;
    ///       self.end = self.start;
    ///       while (self.end < self.path.len() && !self.is_sep(self.path[self.end])) { self.end += 1; }
    ///       if (self.end == self.start) return None;
    ///       Some(Component { name: &self.path[self.start..self.end], path: &self.path[..self.end] })
    ///   }
    public func first(): ?PathSlice {
        startPos = rootEnd
        endPos = startPos
        while (endPos < path.size && !isSep(path[Int64(endPos)])) {
            endPos += 1
        }
        if (endPos == startPos) {
            return None
        }
        return PathSlice(
            name: path.substring(Int64(startPos), Int64(endPos)),
            path: path.substring(0, Int64(endPos))
        )
    }

    /// 移动到最后一个组件 - 对应 ComponentIterator::last
    ///   pub fn last(&mut self) -> Option<Component<'a, T>> {
    ///       self.end = self.path.len();
    ///       loop {
    ///           if (self.end == self.root_end) { self.start = self.end; return None; }
    ///           if (!self.is_sep(self.path[self.end - 1])) break;
    ///           self.end -= 1;
    ///       }
    ///       self.start = self.end;
    ///       while (self.start > self.root_end && !self.is_sep(self.path[self.start - 1])) { self.start -= 1; }
    ///       if (self.start == self.end) return None;
    ///       Some(Component { ... })
    ///   }
    public func last(): ?PathSlice {
        endPos = path.size
        // 去除尾部分隔符
        while (true) {
            if (endPos == rootEnd) {
                startPos = endPos
                return None
            }
            if (!isSep(path[Int64(endPos - 1)])) {
                break
            }
            endPos -= 1
        }
        startPos = endPos
        // 查找组件起始
        while (startPos > rootEnd && !isSep(path[Int64(startPos - 1)])) {
            startPos -= 1
        }
        if (startPos == endPos) {
            return None
        }
        return PathSlice(
            name: path.substring(Int64(startPos), Int64(endPos)),
            path: path.substring(0, Int64(endPos))
        )
    }

    /// 移动到下一个组件 - 对应 ComponentIterator::next
    ///   pub fn next(&mut self) -> Option<Component<'a, T>> {
    ///       let p = self.peek_next()?;
    ///       self.start = p.path.len() - p.name.len();
    ///       self.end = p.path.len();
    ///       Some(p)
    ///   }
    public func next(): ?PathSlice {
        let p = peekNext()
        if (let Some(comp) = p) {
            startPos = comp.path.size - comp.name.size
            endPos = comp.path.size
            return comp
        }
        return None
    }

    /// 预览下一个组件但不移动 - 对应 ComponentIterator::peek_next
    ///   pub fn peek_next(&self) -> Option<Component<'a, T>> {
    ///       var start = self.end;
    ///       while (start < self.path.len() && self.is_sep(self.path[start])) { start += 1; }
    ///       var end = start;
    ///       while (end < self.path.len() && !self.is_sep(self.path[end])) { end += 1; }
    ///       if (start == end) return None;
    ///       Some(Component { name: &self.path[start..end], path: &self.path[..end] })
    ///   }
    public func peekNext(): ?PathSlice {
        var start: Int64 = endPos
        while (start < path.size && isSep(path[Int64(start)])) {
            start += 1
        }
        var end: Int64 = start
        while (end < path.size && !isSep(path[Int64(end)])) {
            end += 1
        }
        if (start == end) {
            return None
        }
        return PathSlice(
            name: path.substring(Int64(start), Int64(end)),
            path: path.substring(0, Int64(end))
        )
    }

    /// 移动到上一个组件 - 对应 ComponentIterator::previous
    ///   pub fn previous(&mut self) -> Option<Component<'a, T>> {
    ///       let p = self.peek_previous()?;
    ///       self.start = p.path.len() - p.name.len();
    ///       self.end = p.path.len();
    ///       Some(p)
    ///   }
    public func previous(): ?PathSlice {
        let p = peekPrevious()
        if (let Some(comp) = p) {
            startPos = comp.path.size - comp.name.size
            endPos = comp.path.size
            return comp
        }
        return None
    }

    /// 预览上一个组件但不移动 - 对应 ComponentIterator::peek_previous
    ///   pub fn peek_previous(&self) -> Option<Component<'a, T>> {
    ///       var end = self.start;
    ///       loop {
    ///           if (end == self.root_end) return None;
    ///           if (!self.is_sep(self.path[end - 1])) break;
    ///           end -= 1;
    ///       }
    ///       var start = end;
    ///       while (start > self.root_end && !self.is_sep(self.path[start - 1])) { start -= 1; }
    ///       if (start == end) return None;
    ///       Some(Component { ... })
    ///   }
    public func peekPrevious(): ?PathSlice {
        var end: Int64 = startPos
        // 跳过前面的分隔符
        while (true) {
            if (end == rootEnd) {
                return None
            }
            if (!isSep(path[Int64(end - 1)])) {
                break
            }
            end -= 1
        }
        var start: Int64 = end
        while (start > rootEnd && !isSep(path[Int64(start - 1)])) {
            start -= 1
        }
        if (start == end) {
            return None
        }
        return PathSlice(
            name: path.substring(Int64(start), Int64(end)),
            path: path.substring(0, Int64(end))
        )
    }

    /// 获取当前路径
    public func getPath(): String {
        return path
    }

    /// 获取根结束位置
    public func getRootEnd(): Int64 {
        return rootEnd
    }

    /// 收集所有组件到数组 (使用 next)
    public func collectAll(): ArrayList<PathSlice> {
        // 重置到开始
        startPos = rootEnd
        endPos = rootEnd
        var result = ArrayList<PathSlice>()
        while (true) {
            let comp = next()
            if (comp == None) {
                break
            }
            result.append(comp.unwrap())
        }
        return result
    }

    // 内部分隔符判断
    private func isSep(c: Char): Bool {
        match (fmt) {
            case Posix => c == Char('/')
            case Windows => c == Char('/') || c == Char('\\')
        }
    }
}

// ============================================================================
// 路径目录创建辅助
// 严格翻译自: src/paths/component_iterator.rs
//   pub fn make_path_with<'a, T, E>(
//       mut it: ComponentIterator<'a, T>,
//       mut mkdir: impl FnMut(&'a [T]) -> Result<MakePathStep<E>, E>,
//   ) -> Result<(), E>
// Bun 使用回溯-前进算法来创建多级目录
// ============================================================================

/// 创建路径步骤结果 - 对应 Bun MakePathStep
///   pub enum MakePathStep<E> {
///       Created,     // 目录已创建
///       Exists,      // 目录已存在
///       NotFound(E), // 父目录不存在
///   }
public enum MakePathStep {
    | Created
    | Exists
    | NotFound(String)  // 错误信息
}
