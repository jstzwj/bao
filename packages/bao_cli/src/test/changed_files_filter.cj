package bao_cli.test

import bao_core.*
import bao_collections.*
import bao_runtime.*

public class ChangedFilesResult {
    public var testFiles: ArrayList<String>
    public var changedCount: Int64
    public var totalTests: Int64
    public var moduleGraphFiles: ArrayList<String>

    public init() {
        testFiles = ArrayList<String>()
        changedCount = 0
        totalTests = 0
        moduleGraphFiles = ArrayList<String>()
    }
}

public class ChangedFilesFilter {
    public static let TRIGGER_FILE_ENV_VAR = "BUN_INTERNAL_TEST_CHANGED_TRIGGER_FILE"

    public static func filter(ctx: CommandContext, vm: VirtualMachine, testFiles: ArrayList<String>, changedSince: String): ChangedFilesResult {
        let result = ChangedFilesResult()
        result.totalTests = testFiles.size
        for (file in testFiles) {
            result.testFiles.append(file)
        }
        return result
    }

    public static func initWatchTrigger(allocator: Allocator): Unit {}
}

public class GitResult {
    public var ok: Bool
    public var spawnFailed: Bool
    public var stdout: String
    public var stderr: String

    public init(ok: Bool, spawnFailed: Bool, stdout: String, stderr: String) {
        this.ok = ok
        this.spawnFailed = spawnFailed
        this.stdout = stdout
        this.stderr = stderr
    }
}

public enum GitError {
    | GitNotFound
    | GitFailed
}
