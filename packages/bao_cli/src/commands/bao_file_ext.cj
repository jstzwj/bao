package bao_cli.commands

import bao_io.*
import bao_sys.*
import bao_path.*
import bao_core.*
import bao_collections.*

extend BaoFile {
    public static func deleteTree(path: String): Unit {
        BaoFile.removeRecursive(path)
    }

    public static func readdirRecursive(path: String): Array<String> {
        let result = ArrayList<String>()
        BaoFileExt.collectRecursive(path, "", Int64(10), Int64(0), result)
        return result.items()
    }

    public static func copyPermissions(src: String, dest: String): Unit {}

    public static func getFileSize(path: String): Int64 {
        return Int64(0)
    }

    public static func getEntryKind(path: String): String {
        if (BaoFile.isDirectory(path)) {
            return "directory"
        }
        if (BaoFile.exists(path)) {
            return "file"
        }
        return "unknown"
    }

    public static func setExecutable(path: String): Unit {
        // 对应 Bun: 设置文件可执行权限 (chmod +x)
        // 当前实现为空操作, 需要 FFI 调用 chmod
    }

    public static func isExecutable(path: String): Bool {
        return BaoFile.exists(path)
    }
}

public class BaoFileExt {
    public static func collectRecursive(base: String, prefix: String, maxDepth: Int64, depth: Int64, result: ArrayList<String>): Unit {
        if (depth > maxDepth) { return }
        let dirPath = if (prefix.size > 0) { Path.join([base, prefix]) } else { base }
        if (!BaoFile.isDirectory(dirPath)) { return }
        let entries = BaoFile.readdir(dirPath)
        for (e in entries) {
            let relPath = if (prefix.size > 0) { "${prefix}/${e}" } else { e }
            let fullPath = Path.join([base, relPath])
            if (BaoFile.isDirectory(fullPath)) {
                collectRecursive(base, relPath, maxDepth, depth + Int64(1), result)
            }
            result.append(relPath)
        }
    }
}
