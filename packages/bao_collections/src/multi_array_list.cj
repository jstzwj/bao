// bao_collections - MultiArrayList 多列数组
// 严格翻译自: src/collections/multi_array_list.zig
//   列式存储 (Struct of Arrays) 模式
//   用于 AST 节点存储, 提高缓存局部性
package bao_collections

// ============================================================================
// MultiArrayList - 列式存储数组
// 严格翻译自: src/collections/multi_array_list.zig
//   pub fn MultiArrayList(comptime T: type) type
//   Zig 将结构体字段拆分为独立数组, 实现 SoA (Struct of Arrays)
//   仓颉使用 Map<String, ArrayList<Any>> 模拟列式存储
// ============================================================================

/// 多列数组条目 - 用于描述一个"行"
/// 对应 Bun MultiArrayList 的索引访问
public class MultiArrayEntry {
    /// 列数据: 列名 → 值
    public var columns: HashMap<String, Any>

    public init() {
        columns = HashMap<String, Any>()
    }

    public func set(key: String, value: Any): Unit {
        columns.put(key, value)
    }

    public func get(key: String): ?Any {
        return columns.get(key)
    }
}

/// 列式存储数组 - 对应 Bun MultiArrayList
/// 将每列数据存储在独立数组中，提高缓存局部性
/// 适用于大量相同结构对象的存储 (如 AST 节点)
public class MultiArrayList {
    /// 列名列表 (保持顺序)
    private var columnNames: ArrayList<String>
    /// 列数据: 列名 → 该列所有值的数组
    private var columns: HashMap<String, ArrayList<Any>>
    /// 行数
    private var rowCount: Int64

    public init() {
        columnNames = ArrayList<String>()
        columns = HashMap<String, ArrayList<Any>>()
        rowCount = 0
    }

    /// 注册列 - 对应 Bun MultiArrayList 的结构体字段定义
    public func addColumn(name: String): Unit {
        if (!columnNames.contains(name)) {
            columnNames.append(name)
            columns.put(name, ArrayList<Any>())
        }
    }

    /// 行数 - 对应 Bun MultiArrayList.len
    public func len(): Int64 {
        return rowCount
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return rowCount == 0
    }

    /// 添加一行 - 对应 Bun MultiArrayList.append
    public func append(entry: MultiArrayEntry): Unit {
        for (name in columnNames) {
            let list = columns.get(name)
            match (list) {
                case Some(arr) => {
                    match (entry.get(name)) {
                        case Some(val) => arr.append(val)
                        case None => () // 缺失列填空
                    }
                }
                case None => ()
            }
        }
        rowCount += 1
    }

    /// 获取指定行列的值 - 对应 Bun MultiArrayList.items(field)[index]
    public func get(row: Int64, column: String): ?Any {
        if (row < 0 || row >= rowCount) {
            return None
        }
        match (columns.get(column)) {
            case Some(arr) => {
                if (row < arr.size) {
                    return Some(arr[row])
                }
                return None
            }
            case None => return None
        }
    }

    /// 设置指定行列的值
    public func set(row: Int64, column: String, value: Any): Unit {
        if (row < 0 || row >= rowCount) {
            return
        }
        match (columns.get(column)) {
            case Some(arr) => {
                if (row < arr.size) {
                    arr[row] = value
                }
            }
            case None => ()
        }
    }

    /// 获取整列数据 - 对应 Bun MultiArrayList.items(field)
    public func column(name: String): ?ArrayList<Any> {
        return columns.get(name)
    }

    /// 获取所有列名
    public func columnNames(): ArrayList<String> {
        return columnNames
    }

    /// 获取一行数据 (所有列) - 对应 Bun MultiArrayList.get(index)
    public func getRow(index: Int64): MultiArrayEntry {
        let entry = MultiArrayEntry()
        if (index < 0 || index >= rowCount) {
            return entry
        }
        for (name in columnNames) {
            match (columns.get(name)) {
                case Some(arr) => {
                    if (index < arr.size) {
                        entry.set(name, arr[index])
                    }
                }
                case None => ()
            }
        }
        return entry
    }

    /// 删除最后一行 - 对应 Bun MultiArrayList.pop
    public func pop(): Unit {
        if (rowCount == 0) {
            return
        }
        rowCount -= 1
        for (name in columnNames) {
            match (columns.get(name)) {
                case Some(arr) => {
                    if (arr.size > 0) {
                        arr.removeAt(arr.size - 1)
                    }
                }
                case None => ()
            }
        }
    }

    /// 交换删除一行 - 对应 Bun MultiArrayList.swapRemove
    public func swapRemove(index: Int64): Unit {
        if (index < 0 || index >= rowCount) {
            return
        }
        if (index == rowCount - 1) {
            pop()
            return
        }
        // 将最后一行数据复制到要删除的位置
        for (name in columnNames) {
            match (columns.get(name)) {
                case Some(arr) => {
                    if (arr.size > 0) {
                        let lastIdx = arr.size - 1
                        if (index < arr.size) {
                            arr[Int64(index)] = arr[lastIdx]
                        }
                        arr.removeAt(lastIdx)
                    }
                }
                case None => ()
            }
        }
        rowCount -= 1
    }

    /// 清空所有行 - 对应 Bun MultiArrayList.clear
    public func clear(): Unit {
        for (name in columnNames) {
            match (columns.get(name)) {
                case Some(arr) => arr.clear()
                case None => ()
            }
        }
        rowCount = 0
    }

    /// 清空并释放容量 - 对应 Bun MultiArrayList.clearAndFree
    public func clearAndFree(): Unit {
        columns.clear()
        columnNames.clear()
        rowCount = 0
    }

    /// 预分配空间 - 对应 Bun MultiArrayList.ensureTotalCapacity
    public func ensureTotalCapacity(capacity: Int64): Unit {
        // ArrayList 自动扩容
    }

    /// 遍历所有行
    public func forEach(fn: (Int64, MultiArrayEntry) -> Unit): Unit {
        for (i in 0..rowCount) {
            fn(i, getRow(i))
        }
    }
}
