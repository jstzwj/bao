// 严格翻译自: src/paths/component_iterator.rs
//   PathComponentIterator<'a, T> - 路径组件迭代器
//   Component<'a, T> - 路径组件 (name + path prefix)
//   PathFormat - 路径格式 (Posix/Windows)
//   MakePathStep - 创建路径步骤结果
//   make_path_with - 递归创建路径
//
// 注意: component.cj 已有 EnhancedPathComponentIterator，
// 本文件提供 component_iterator.rs 的完整翻译
package bao_path

import bao_core.*
import bao_collections.*

// ============================================================================
// Component - 路径组件
// 严格翻译自: src/paths/component_iterator.rs
//   pub struct Component<'a, T> {
//       pub name: &'a [T],
//       pub path: &'a [T],
//   }
// Component 同时持有组件名称和到该组件的完整路径前缀
// ============================================================================

/// 路径组件 - 对应 Bun Component
/// name: 组件名称 (如 "b")
/// path: 到该组件的完整路径前缀 (如 "/a/b")
public class Component {
    /// 组件名称 (不含分隔符)
    public let name: String
    /// 到该组件的完整路径前缀
    public let path: String

    public init(name: String, path: String) {
        this.name = name
        this.path = path
    }

    public func toString(): String {
        return "Component(name=${name}, path=${path})"
    }
}

// ============================================================================
// PathComponentIterator - 路径组件迭代器
// 严格翻译自: src/paths/component_iterator.rs
//   pub struct PathComponentIterator<'a, T> {
//       path: &'a [T],
//       root_end: usize,
//       start: usize,
//       end: usize,
//       fmt: PathFormat,
//   }
//
// Bun 的 PathComponentIterator 支持双向遍历:
//   next / previous / first / last / peek_next / peek_previous
//   root - 获取根前缀
//   make_path_with - 递归创建路径
// ============================================================================

/// 路径组件迭代器 - 对应 Bun PathComponentIterator
/// 支持双向遍历路径组件，POSIX 和 Windows 格式
public class PathComponentIterator {
    private let path: String
    private let rootEnd: Int64
    private var startPos: Int64
    private var endPos: Int64
    private let fmt: PathFormat

    /// 初始化迭代器 - 对应 PathComponentIterator::init
    ///   pub fn init(path: &[T], fmt: PathFormat) -> Result<Self, Error> {
    ///       let root_end = match fmt {
    ///           PathFormat::Posix => { var i = 0; while (i < path.len() && fmt.is_sep(path[i])) { i += 1; } i },
    ///           PathFormat::Windows => windows_root_end(path)?,
    ///       };
    ///       Ok(Self { path, root_end, start: root_end, end: root_end, fmt })
    ///   }
    public init(path: String, fmt: PathFormat) {
        this.path = path
        this.fmt = fmt

        var rEnd: Int64 = 0
        match (fmt) {
            case Posix =>
                while (rEnd < path.size && isSepForFormat(fmt, path[Int64(rEnd)])) {
                    rEnd += 1
                }
            case Windows =>
                if (path.size >= 3 && path[1] == UInt8(58) && isSepForFormat(fmt, path[2])) {
                    rEnd = 3
                } else if (path.size >= 2 && isSepForFormat(fmt, path[0]) && isSepForFormat(fmt, path[1])) {
                    var i: Int64 = 2
                    while (i < path.size && !isSepForFormat(fmt, path[Int64(i)])) {
                        i += 1
                    }
                    while (i < path.size && isSepForFormat(fmt, path[Int64(i)])) {
                        i += 1
                    }
                    while (i < path.size && !isSepForFormat(fmt, path[Int64(i)])) {
                        i += 1
                    }
                    while (i < path.size && isSepForFormat(fmt, path[Int64(i)])) {
                        i += 1
                    }
                    rEnd = i
                } else if (path.size >= 1 && isSepForFormat(fmt, path[0])) {
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
        while (rEnd < path.size && path[Int64(rEnd)] == UInt8(47)) {
            rEnd += 1
        }
        rootEnd = rEnd
        startPos = rootEnd
        endPos = rootEnd
    }

    /// 获取根前缀 - 对应 PathComponentIterator::root
    ///   pub fn root(&self) -> Option<&[T]> {
    ///       if self.root_end == 0 { None } else { Some(&self.path[..self.root_end]) }
    ///   }
    public func root(): ?String {
        if (rootEnd == 0) {
            return None
        }
        return path[0..rootEnd]
    }

    /// 移动到第一个组件 - 对应 PathComponentIterator::first
    ///   pub fn first(&mut self) -> Option<Component<'a, T>> {
    ///       self.start = self.root_end;
    ///       self.end = self.start;
    ///       while (self.end < self.path.len() && !self.is_sep(self.path[self.end])) { self.end += 1; }
    ///       if (self.end == self.start) return None;
    ///       Some(Component { name: &self.path[self.start..self.end], path: &self.path[..self.end] })
    ///   }
    public func first(): ?Component {
        startPos = rootEnd
        endPos = startPos
        while (endPos < path.size && !isSepForFormat(fmt, path[Int64(endPos)])) {
            endPos += 1
        }
        if (endPos == startPos) {
            return None
        }
        return Component(path[startPos..endPos], path[0..endPos])
    }

    /// 移动到最后一个组件 - 对应 PathComponentIterator::last
    public func last(): ?Component {
        endPos = path.size
        while (true) {
            if (endPos == rootEnd) {
                startPos = endPos
                return None
            }
            if (!isSepForFormat(fmt, path[Int64(endPos - 1)])) {
                break
            }
            endPos -= 1
        }
        startPos = endPos
        while (startPos > rootEnd && !isSepForFormat(fmt, path[Int64(startPos - 1)])) {
            startPos -= 1
        }
        if (startPos == endPos) {
            return None
        }
        return Component(path[startPos..endPos], path[0..endPos])
    }

    /// 移动到下一个组件 - 对应 PathComponentIterator::next
    ///   pub fn next(&mut self) -> Option<Component<'a, T>> {
    ///       let p = self.peek_next()?;
    ///       self.start = p.path.len() - p.name.len();
    ///       self.end = p.path.len();
    ///       Some(p)
    ///   }
    public func next(): ?Component {
        let p = peekNext()
        if (let Some(comp) <- p) {
            startPos = comp.path.size - comp.name.size
            endPos = comp.path.size
            return comp
        }
        return None
    }

    /// 预览下一个组件但不移动 - 对应 PathComponentIterator::peek_next
    ///   pub fn peek_next(&self) -> Option<Component<'a, T>> {
    ///       var start = self.end;
    ///       while (start < self.path.len() && self.is_sep(self.path[start])) { start += 1; }
    ///       var end = start;
    ///       while (end < self.path.len() && !self.is_sep(self.path[end])) { end += 1; }
    ///       if (start == end) return None;
    ///       Some(Component { name: &self.path[start..end], path: &self.path[..end] })
    ///   }
    public func peekNext(): ?Component {
        var start: Int64 = endPos
        while (start < path.size && isSepForFormat(fmt, path[Int64(start)])) {
            start += 1
        }
        var end: Int64 = start
        while (end < path.size && !isSepForFormat(fmt, path[Int64(end)])) {
            end += 1
        }
        if (start == end) {
            return None
        }
        return Component(path[start..end], path[0..end])
    }

    /// 移动到上一个组件 - 对应 PathComponentIterator::previous
    public func previous(): ?Component {
        let p = peekPrevious()
        if (let Some(comp) <- p) {
            startPos = comp.path.size - comp.name.size
            endPos = comp.path.size
            return comp
        }
        return None
    }

    /// 预览上一个组件但不移动 - 对应 PathComponentIterator::peek_previous
    public func peekPrevious(): ?Component {
        var end: Int64 = startPos
        while (true) {
            if (end == rootEnd) {
                return None
            }
            if (!isSepForFormat(fmt, path[Int64(end - 1)])) {
                break
            }
            end -= 1
        }
        var start: Int64 = end
        while (start > rootEnd && !isSepForFormat(fmt, path[Int64(start - 1)])) {
            start -= 1
        }
        if (start == end) {
            return None
        }
        return Component(path[start..end], path[0..end])
    }

    /// 获取原始路径
    public func getPath(): String {
        return path
    }

    /// 获取根结束位置
    public func getRootEnd(): Int64 {
        return rootEnd
    }

    /// 收集所有组件到数组
    public func collectAll(): ArrayList<Component> {
        startPos = rootEnd
        endPos = rootEnd
        var result = ArrayList<Component>()
        while (true) {
            match (next()) {
                case Some(comp) => result.append(comp)
                case None => break
            }
        }
        return result
    }

    /// 收集所有组件名称
    public func collectNames(): ArrayList<String> {
        var result = ArrayList<String>()
        startPos = rootEnd
        endPos = rootEnd
        while (true) {
            match (next()) {
                case Some(comp) => result.append(comp.name)
                case None => break
            }
        }
        return result
    }

    /// 计算组件数量
    public func count(): Int64 {
        var savedStart = startPos
        var savedEnd = endPos
        startPos = rootEnd
        endPos = rootEnd
        var c: Int64 = 0
        while (true) {
            match (next()) {
                case Some(_) => c += 1
                case None => break
            }
        }
        startPos = savedStart
        endPos = savedEnd
        return c
    }

    // 内部分隔符判断
    private static func isSepForFormat(fmt: PathFormat, c: UInt8): Bool {
        match (fmt) {
            case Posix => c == UInt8(47)
            case Windows => c == UInt8(47) || c == UInt8(92)
        }
    }
}

// ============================================================================
// 路径目录创建辅助
// 严格翻译自: src/paths/component_iterator.rs
//   pub fn make_path_with<'a, T, E>(
//       mut it: PathComponentIterator<'a, T>,
//       mut mkdir: impl FnMut(&'a [T]) -> Result<MakePathStep<E>, E>,
//   ) -> Result<(), E>
//
// Bun 使用回溯-前进算法来创建多级目录:
//   1. 前进到最深的不存在的目录
//   2. 创建该目录
//   3. 回退并继续
// ============================================================================

/// 创建路径步骤结果 - 对应 Bun MakePathStep
///   pub enum MakePathStep<E> { Created, Exists, NotFound(E) }
public enum MakePathStep2 {
    | Created      // 目录已创建
    | Exists       // 目录已存在
    | NotFound(String) // 父目录不存在
}

/// 递归创建路径
/// 对应 Bun make_path_with 的简化版本
/// 使用 PathComponentIterator 逐级创建目录
public func makePathWith(
    path: String,
    mkdir: (String) -> MakePathStep2
): MakePathStep2 {
    let it = PathComponentIterator(path)
    var currentPath = ""

    // 收集所有组件
    let components = it.collectAll()
    for (comp in components) {
        currentPath = comp.path
        match (mkdir(currentPath)) {
            case MakePathStep2.Exists => continue
            case MakePathStep2.Created => continue
            case MakePathStep2.NotFound(err) => return MakePathStep2.NotFound(err)
        }
    }
    return MakePathStep2.Exists
}
