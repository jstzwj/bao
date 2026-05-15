// snapshot.cj - 快照测试
// 严格翻译自 bun/src/runtime/test_runner/snapshot.zig

package bao_runtime.test_runner

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
        for entry in counts {
            counts[entry.key] = 0
        }
    }

    /// 添加快照计数
    public func addCount(expect: Expect, hint: String): Tuple2<String, UInt64> {
        total += 1
        let snapshotName = expect.getSnapshotName(allocator: allocator, hint: hint)
        let countEntry = counts.getOrPut(snapshotName)
        if countEntry.foundExisting {
            allocator.free(snapshotName)
            countEntry.value += 1
            return Tuple2<String, UInt64>(countEntry.key, countEntry.value)
        }
        countEntry.value = 1
        return Tuple2<String, UInt64>(countEntry.key, countEntry.value)
    }

    /// 获取或放入快照值
    /// - Param expect: Expect实例
    /// - Param targetValue: 目标值
    /// - Param hint: 提示信息
    /// - Return: 已存在的快照值, 如果不存在返回None
    public func getOrPut(expect: Expect, targetValue: String, hint: String): ?String {
        let buntestStrong = expect.bunTest() ?? return None
        defer { buntestStrong.deinit() }
        let bunTest = buntestStrong.get()

        // 获取快照文件
        let result = getSnapshotFile(bunTest.fileId)
        if !result {
            return None
        }

        let nameAndCounter = addCount(expect: expect, hint: hint)
        let name = nameAndCounter.0
        let counter = nameAndCounter.1

        let counterString = "${counter}"
        let nameWithCounter = name + " " + counterString

        let nameHash = hash(nameWithCounter)

        // 检查是否已存在
        if values.contains(nameHash) {
            return values[nameHash]
        }

        // 不存在, 追加到文件字节并添加到hashmap
        // 在CI环境中防止创建快照, 除非使用--update-snapshots
        if bun.ci.isCI() {
            if !updateSnapshots {
                // 存储快照名称以用于错误报告
                if lastErrorSnapshotName != None {
                    allocator.free(lastErrorSnapshotName!)
                    lastErrorSnapshotName = None
                }
                lastErrorSnapshotName = allocator.dupe(targetValue)
                return None // error: SnapshotCreationNotAllowedInCI
            }
        }

        let estimatedLength = "\nexports[`".length + nameWithCounter.length + "`] = `".length + targetValue.length + "`;\n".length
        fileBuf.ensureUnusedCapacity(estimatedLength + 10)

        // 格式化转义后写入
        let escapedName = formatEscapes(nameWithCounter, quoteChar: "`")
        let escapedValue = formatEscapes(targetValue, quoteChar: "`")
        let entry = "\nexports[\`${escapedName}\`] = \`${escapedValue}\`;\n"
        fileBuf.append(entry)

        added += 1
        values[nameHash] = allocator.dupe(targetValue)
        return None
    }

    /// 解析快照文件
    /// 解析.snap文件中的exports, 提取快照键值对
    public func parseFile(file: SnapshotFile) {
        if fileBuf.length == 0 { return }

        let testFile = Jest.runner.files.get(file.id)
        let testFilename = testFile.source.path.name.filename
        let dirPath = testFile.source.path.name.dirWithTrailingSlash()

        let snapshotFilePath = dirPath + snapshotsDirName + testFilename + ".snap"

        // 使用JS解析器解析exports
        let source = Source.initPathString(snapshotFilePath, fileBuf.items)

        // 解析文件, 提取exports中的键值对
        // exports[`key`] = `value`;
        let content = fileBuf.items

        // 简单解析: 查找 exports[`...`] = `...` 模式
        var i = 0
        while i < content.length {
            // 查找 exports[`
            let exportsIdx = content.indexOf("exports[`", startIndex: i)
            if exportsIdx == None { break }
            i = exportsIdx!

            // 提取键
            let keyStart = i + "exports[`".length
            let keyEnd = content.indexOf("`]", startIndex: keyStart)
            if keyEnd == None { break }
            let key = content[keyStart..keyEnd!]

            // 查找 = `
            let assignStart = content.indexOf("= `", startIndex: keyEnd! + 2)
            if assignStart == None { break }

            let valueStart = assignStart! + "= `".length
            // 查找未转义的结束反引号
            var valueEnd = valueStart
            while valueEnd < content.length {
                if content[valueEnd] == '`' && content[valueEnd - 1] != '\\' {
                    break
                }
                valueEnd += 1
            }
            let value = content[valueStart..valueEnd]

            let nameHash = hash(key)
            values[nameHash] = allocator.dupe(value)

            i = valueEnd + 1
        }
    }

    /// 写入快照文件
    public func writeSnapshotFile() {
        if let file = currentFile {
            file.file.writeAll(fileBuf.items)
            file.file.close()
            fileBuf.clear()

            // 清理值
            for entry in values {
                allocator.free(entry.value)
            }
            values.clear()

            // 清理计数键
            for entry in counts {
                allocator.free(entry.key)
            }
            counts.clear()
        }
    }

    /// 添加行内快照写入
    public func addInlineSnapshotToWrite(fileId: UInt32, value: InlineSnapshotToWrite) {
        let gpres = inlineSnapshotsToWrite.getOrPut(fileId)
        if !gpres.foundExisting {
            gpres.value = ArrayList<InlineSnapshotToWrite>()
        }
        gpres.value.append(value)
    }

    /// 写入行内快照
    /// 返回是否全部成功
    public func writeInlineSnapshots(): Bool {
        var success = true

        for entry in inlineSnapshotsToWrite {
            let fileId = entry.key
            var ilsInfo = entry.value

            // 1. 按行、列排序
            ilsInfo.sort(InlineSnapshotToWrite.lessThanFn)

            // 2. 加载文件文本
            let testFile = Jest.runner.files.get(fileId)
            let testFilename = testFile.source.path.text

            let fd = Sys.open(testFilename, O.RDWR, 0o644)
            if fd == -1 {
                success = false
                continue
            }

            let file = SnapshotFile(id: fileId, file: FileHandle(fd))
            let fileText = file.file.readToEnd()

            // 3. 遍历查找行/列对应的字节位置
            var resultText = StringBuilder()
            var uncommittedSegmentEnd: UInt64 = 0
            var lastByte: UInt64 = 0
            var lastLine: UInt64 = 1
            var lastCol: UInt64 = 1
            var lastValue: String = ""

            for ils in ilsInfo {
                if ils.line == lastLine && ils.col == lastCol {
                    if ils.value != lastValue {
                        // 同一行的多个行内快照必须具有相同的值
                        success = false
                    }
                    continue
                }

                // 查找字节偏移
                let byteOffsetAdd = lineColToByteOffset(
                    text: fileText[lastByte..],
                    startLine: lastLine,
                    startCol: lastCol,
                    targetLine: ils.line,
                    targetCol: ils.col
                )

                if byteOffsetAdd == None {
                    success = false
                    continue
                }

                let byteOffset = lastByte + byteOffsetAdd!

                // 写入未提交的段
                resultText.append(fileText[uncommittedSegmentEnd..byteOffset])

                // 写入新值
                resultText.append(ils.value)

                uncommittedSegmentEnd = byteOffset + lastValue.length
                lastByte = byteOffset
                lastLine = ils.line
                lastCol = ils.col
                lastValue = ils.value
            }

            // 写入剩余部分
            resultText.append(fileText[uncommittedSegmentEnd..])

            // 写回文件
            file.file.writeAll(resultText.toString())
            file.file.close()
        }

        return success
    }

    /// 获取快照文件
    /// - Param fileId: 测试文件ID
    /// - Return: 是否成功
    public func getSnapshotFile(fileId: UInt32): Bool {
        // 检查是否已加载此文件的快照
        if currentFile != None && currentFile.getOrThrow().id == fileId {
            return true
        }

        // 写入之前文件的快照
        if currentFile != None {
            writeSnapshotFile()
        }

        let testFile = Jest.runner.files.get(fileId)
        let testFilename = testFile.source.path.name.filename
        let dirPath = testFile.source.path.name.dirWithTrailingSlash()

        let snapshotDirPath = dirPath + snapshotsDirName

        // 创建目录(如果不存在)
        if !FileSystem.exists(snapshotDirPath) {
            let mkdirResult = Sys.mkdir(snapshotDirPath, 0o755)
            if mkdirResult == -1 {
                return false
            }
        }

        let snapshotFilePath = snapshotDirPath + testFilename + ".snap"

        // 尝试打开现有快照文件
        let fd = Sys.open(snapshotFilePath, O.RDONLY, 0)
        if fd >= 0 {
            let file = FileHandle(fd)
            fileBuf = file.readToEndAsArrayList()
            file.close()
        } else {
            fileBuf.clear()
        }

        // 设置当前文件(用于后续写入)
        let writeFd = Sys.open(snapshotFilePath, O.WRONLY | O.CREAT | O.TRUNC, 0o644)
        currentFile = SnapshotFile(id: fileId, file: FileHandle(writeFd))
        snapshotDirPath = snapshotDirPath

        // 解析快照
        if fileBuf.length > 0 {
            parseFile(file: currentFile!)
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
        if a.line < b.line { return true }
        if a.line > b.line { return false }
        if a.col < b.col { return true }
        return false
    }
}

// ========== SnapshotFile - 快照文件 ==========

/// 快照文件信息
public class SnapshotFile {
    public var id: UInt32 = 0
    public var file: FileHandle

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
    return text.hash()
}

/// 格式化转义字符
public func formatEscapes(text: String, quoteChar: String): String {
    var result = StringBuilder()
    for ch in text {
        if ch == quoteChar[0] {
            result.append("\\")
        } else if ch == '\\' {
            result.append("\\\\")
            continue
        }
        result.append(ch)
    }
    return result.toString()
}

/// 根据行号和列号计算字节偏移
public func lineColToByteOffset(text: String, startLine: UInt64, startCol: UInt64, targetLine: UInt64, targetCol: UInt64): ?UInt64 {
    var line: UInt64 = startLine
    var col: UInt64 = startCol
    var offset: UInt64 = 0

    for ch in text {
        if line == targetLine && col == targetCol {
            return offset
        }
        if ch == '\n' {
            line += 1
            col = 1
        } else {
            col += 1
        }
        offset += 1
    }

    // 检查最后一个位置
    if line == targetLine && col == targetCol {
        return offset
    }

    return None
}
