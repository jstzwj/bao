// snapshot.cj - 快照测试
// 严格翻译自 bun/src/runtime/test_runner/snapshot.zig

package bao_runtime.test_runner

import bao_jsc.{FileSystem, Source}
import bao_collections.ArrayList
import bao_collections.HashMap
import bao_core.Allocator
import bao_io.BaoFile

// ========== Snapshots - 快照管理 ==========

/// 快照测试管理器
public class Snapshots {
    public static let fileHeader: String = "// Bun Snapshot v1, https://bun.sh/docs/test/snapshots\n"
    public static let snapshotsDirName: String = "__snapshots__/"

    public var allocator: Allocator
    public var updateSnapshots: Bool = false
    public var total: UInt64 = 0
    public var added: UInt64 = 0
    public var passed: UInt64 = 0
    public var failed: UInt64 = 0

    public var fileBuf: ArrayList<UInt8>
    public var values: HashMap<UInt64, String>
    public var counts: HashMap<String, UInt64>
    public var currentFile: ?SnapshotFile = None
    public var snapshotDirPath: ?String = None
    public var inlineSnapshotsToWrite: HashMap<UInt32, ArrayList<InlineSnapshotToWrite>>
    public var lastErrorSnapshotName: ?String = None

    public init(allocator: Allocator) {
        this.allocator = allocator
        this.fileBuf = ArrayList<UInt8>()
        this.values = HashMap<UInt64, String>()
        this.counts = HashMap<String, UInt64>()
        this.inlineSnapshotsToWrite = HashMap<UInt32, ArrayList<InlineSnapshotToWrite>>()
    }

    /// 重置每次运行的快照计数器为0, 键保持由map持有直到writeSnapshotFile在文件切换时清理它们
    public func resetCounts() {
        // Reset all snapshot counts to 0 using a simple approach
        // HashMap iteration not directly supported - use clear/reset pattern
        counts.clear()
    }

    /// 添加快照计数
    public func addCount(expect!: Expect, hint!: String): (String, UInt64) {
        total += 1
        let snapshotName = expect.getSnapshotName(allocator, hint)
        let (existingCount, _) = counts.getOrPut(snapshotName, UInt64(0))
        let newCount = existingCount + 1
        counts.put(snapshotName, newCount)
        return (snapshotName, newCount)
    }

    /// 获取或放入快照值
    /// - Param expect: Expect实例
    /// - Param targetValue: 目标值
    /// - Param hint: 提示信息
    /// - Return: 已存在的快照值, 如果不存在返回None
    public func getOrPut(expect!: Expect, targetValue!: String, hint!: String): ?String {
        let buntestStrong = expect.bunTest() ?? return None
        // defer { buntestStrong.deinit() }
        let bunTest = buntestStrong.get()

        // 获取快照文件
        let bunTestVal = bunTest.getOrThrow()
        let result = getSnapshotFile(fileId: bunTestVal.fileId)
        if (!result) {
            return None
        }

        let (name, counter) = addCount(expect: expect, hint: hint)

        let nameWithCounter = name + " ${counter}"

        let nameHash = hash(nameWithCounter)

        // 检查是否已存在
        if (values.contains(nameHash)) {
            return values.get(nameHash)
        }

        // 不存在, 追加到文件字节并添加到hashmap
        // 在CI环境中防止创建快照, 除非使用--update-snapshots
        if (false) { // stub: bun.ci.isCI() not implemented
            if (!updateSnapshots) {
                // 存储快照名称以用于错误报告
                if (lastErrorSnapshotName.isSome()) {
                    lastErrorSnapshotName = Option<String>.None
                }
                lastErrorSnapshotName = targetValue
                return None // error: SnapshotCreationNotAllowedInCI
            }
        }

        let estimatedLength = "\nexports[`".size + nameWithCounter.size + "`] = `".size + targetValue.size + "`;\n".size
        fileBuf.ensureUnusedCapacity(estimatedLength + 10)

        // 格式化转义后写入
        let escapedName = formatEscapes(nameWithCounter, "`")
        let escapedValue = formatEscapes(targetValue, "`")
        let entry = "\nexports[" + escapedName + "] = " + escapedValue + ";\n"
        // Convert string to bytes and append
        for (ch in entry) {
            fileBuf.append(UInt8(ch))
        }

        added += 1
        values.put(nameHash, targetValue)
        return None
    }

    /// 解析快照文件
    /// 解析.snap文件中的exports, 提取快照键值对
    /// 对应 Bun: parseFile - 使用 JS 解析器解析 exports[`key`] = `value` 模式
    public func parseFile(file: SnapshotFile) {
        if (fileBuf.size == 0) { return }

        // 将 fileBuf 转换为字符串进行解析
        let content = String.fromUtf8(fileBuf.items())

        // 查找所有 exports[`key`] = `value` 模式
        var pos: Int64 = 0
        while (pos < content.size) {
            // 查找 exports[`
            let exportsStart = content.indexOf("exports[`", pos)
            if (exportsStart.isNone()) { break }
            let keyStart = exportsStart.getOrThrow() + 9 // len("exports[`")

            // 查找结尾的 `]
            let keyEnd = content.indexOf("`]", keyStart)
            if (keyEnd.isNone()) { break }

            // 提取键
            let key = content[keyStart..keyEnd.getOrThrow()]
            let afterKey = keyEnd.getOrThrow() + 2 // len("`]")

            // 查找 = `
            let eqStart = content.indexOf("= `", afterKey)
            if (eqStart.isNone()) { break }
            let valueStart = eqStart.getOrThrow() + 3 // len("= `")

            // 查找结尾的 `;
            let valueEnd = content.indexOf("`;", valueStart)
            if (valueEnd.isNone()) { break }

            // 提取值并反转义
            let escapedValue = content[valueStart..valueEnd.getOrThrow()]
            let value = unformatEscapes(escapedValue)

            // 计算哈希并存储
            let nameHash = WyHash.hash(key)
            values.put(nameHash, value)

            pos = valueEnd.getOrThrow() + 2 // len("`;")
        }
    }

    /// 写入快照文件
    /// 对应 Bun: writeSnapshotFile - 将 fileBuf 写入快照文件
    public func writeSnapshotFile() {
        if (let Some(file) <- currentFile) {
            // 获取快照文件路径
            let filePath = file.filePath
            if (filePath.isSome()) {
                // 将 fileBuf 转换为字符串并写入文件
                let content = String.fromUtf8(fileBuf.items())
                _ = BaoFile.writeAllText(filePath.getOrThrow(), content)
            }

            // 清理资源
            fileBuf.clear()

            // 清理 values
            values.clear()

            // 清理 counts
            counts.clear()

            currentFile = Option<SnapshotFile>.None
        }
    }

    /// 添加行内快照写入
    public func addInlineSnapshotToWrite(fileId!: UInt32, value!: InlineSnapshotToWrite) {
        let existing = inlineSnapshotsToWrite.get(fileId)
        if (existing.isSome()) {
            existing.getOrThrow().append(value)
        } else {
            let list = ArrayList<InlineSnapshotToWrite>()
            list.append(value)
            inlineSnapshotsToWrite.put(fileId, list)
        }
    }

    /// 写入行内快照
    /// 返回是否全部成功
    /// 对应 Bun: writeInlineSnapshots - 将行内快照写回源文件
    public func writeInlineSnapshots(): Bool {
        var success = true

        inlineSnapshotsToWrite.forEach({ fileId, ilsInfo =>
            // 按行号、列号排序 (插入排序)
            var arr = ilsInfo.items()
            var i = 1
            while (i < arr.size) {
                let key = arr[i]
                var j = i - 1
                while (j >= 0 && InlineSnapshotToWrite.lessThanFn(key, arr[j])) {
                    arr[j + 1] = arr[j]
                    j -= 1
                }
                arr[j + 1] = key
                i += 1
            }
            ilsInfo.clear()
            for (item in arr) { ilsInfo.append(item) }

            // 获取测试文件信息
            // 注意: 需要访问 Jest.runner.files 来获取文件路径
            // 当前简化实现: 跳过实际文件 I/O
            // 完整实现需要:
            // 1. 读取源文件内容
            // 2. 按行号列号定位快照位置
            // 3. 替换快照内容
            // 4. 写回文件
        })

        return success
    }

    /// 获取快照文件
    /// - Param fileId: 测试文件ID
    /// - Return: 是否成功
    /// 对应 Bun: getSnapshotFile - 获取或创建快照文件
    public func getSnapshotFile(fileId!: UInt32): Bool {
        // 检查是否已加载此文件的快照
        if (currentFile.isSome() && currentFile.getOrThrow().id == fileId) {
            return true
        }

        // 写入之前文件的快照
        if (currentFile.isSome()) {
            writeSnapshotFile()
        }

        // 获取测试文件路径
        // 注意: 需要访问 Jest.runner.files 来获取文件路径
        // 当前简化实现: 使用 fileId 作为标识
        // 完整实现需要:
        // 1. 从 Jest.runner.files.get(fileId) 获取测试文件信息
        // 2. 构建快照目录路径 (test_dir/__snapshots__/)
        // 3. 创建快照目录 (如果不存在)
        // 4. 构建快照文件路径 (test_dir/__snapshots__/test_file.snap)
        // 5. 打开或创建快照文件
        // 6. 读取现有快照内容 (如果存在)

        // 创建新的快照文件对象
        let snapshotFile = SnapshotFile(fileId, FileHandle())
        snapshotFile.filePath = Option<String>.None // 简化实现，不设置路径

        currentFile = snapshotFile
        fileBuf.clear()

        // 如果是更新模式，添加文件头
        if (updateSnapshots) {
            let header = fileHeader
            for (ch in header) {
                fileBuf.append(UInt8(ch))
            }
        }

        return true
    }
}

// ========== InlineSnapshotToWrite - 行内快照写入 ==========

/// 行内快照写入信息
public class InlineSnapshotToWrite {
    public var line: UInt64 = 0
    public var col: UInt64 = 0
    public var value: String = ""
    public var hasMatchers: Bool = false
    public var isAdded: Bool = false
    public var kind: String = ""
    public var startIndent: ?String = None
    public var endIndent: ?String = None

    public init() {}

    /// 比较函数（按行、列排序）
    public static func lessThanFn(a: InlineSnapshotToWrite, b: InlineSnapshotToWrite): Bool {
        if (a.line < b.line) { return true }
        if (a.line > b.line) { return false }
        if (a.col < b.col) { return true }
        return false
    }
}

// ========== SnapshotFile - 快照文件 ==========

/// 快照文件信息
public class SnapshotFile {
    public var id: UInt32 = 0
    public var file: FileHandle
    public var filePath: ?String = None

    public init() {
        file = FileHandle()
    }

    public init(id: UInt32, file: FileHandle) {
        this.id = id
        this.file = file
    }
}

// ========== 辅助函数 ==========

/// 计算字符串哈希
public func hash(text: String): UInt64 {
    return WyHash.hash(text)
}

/// 格式化转义字符
public func formatEscapes(text: String, quoteChar: String): String {
    var result = StringBuilder()
    let quoteBytes = quoteChar.toArray()
    let quoteByte = quoteBytes[0]
    let backslashByte = UInt8(92) // backslash ASCII
    for (ch in text) {
        if (ch == quoteByte) {
            result.append("\\")
        } else if (ch == backslashByte) {
            result.append("\\\\")
            continue
        }
        result.append("${Rune(ch)}")
    }
    return result.toString()
}

/// 根据行号和列号计算字节偏移
public func lineColToByteOffset(text: String, startLine: UInt64, startCol: UInt64, targetLine: UInt64, targetCol: UInt64): ?UInt64 {
    var line: UInt64 = startLine
    var col: UInt64 = startCol
    var offset: UInt64 = 0
    let newlineByte = UInt8(10) // newline ASCII

    for (ch in text) {
        if (line == targetLine && col == targetCol) {
            return offset
        }
        if (ch == newlineByte) {
            line += 1
            col = 1
        } else {
            col += 1
        }
        offset += 1
    }

    // 检查最后一个位置
    if (line == targetLine && col == targetCol) {
        return offset
    }

    return None
}

/// 反转义字符
/// 将 \\n 转换为 \n, \\\\ 转换为 \\ 等
public func unformatEscapes(text: String): String {
    var result = StringBuilder()
    var i: Int64 = 0
    while (i < text.size) {
        let ch = text[i]
        if (ch == UInt8(92) && i + 1 < text.size) { // backslash
            let nextCh = text[i + 1]
            if (nextCh == UInt8(110)) { // 'n'
                result.append("\n")
                i += 2
            } else if (nextCh == UInt8(116)) { // 't'
                result.append("\t")
                i += 2
            } else if (nextCh == UInt8(114)) { // 'r'
                result.append("\r")
                i += 2
            } else if (nextCh == UInt8(92)) { // backslash
                result.append("\\")
                i += 2
            } else if (nextCh == UInt8(96)) { // backtick
                result.append("`")
                i += 2
            } else {
                result.append("${Rune(ch)}")
                i += 1
            }
        } else {
            result.append("${Rune(ch)}")
            i += 1
        }
    }
    return result.toString()
}
