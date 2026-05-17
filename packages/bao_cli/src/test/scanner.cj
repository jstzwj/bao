package bao_cli.test

import bao_core.*
import bao_collections.*

public let TEST_NAME_SUFFIXES: Array<String> = [
    ".test",
    "_test",
    ".spec",
    "_spec"
]

public class Scanner {
    public var exclusionNames: ArrayList<String>
    public var filterNames: ArrayList<String>
    public var pathIgnorePatterns: ArrayList<String>
    public var testFiles: ArrayList<String>
    private var hasIterated: Bool
    public var searchCount: Int64

    public init(allocator: Allocator, transpiler: Transpiler, initialResultsCapacity: Int64) {
        exclusionNames = ArrayList<String>()
        filterNames = ArrayList<String>()
        pathIgnorePatterns = ArrayList<String>()
        testFiles = ArrayList<String>()
        hasIterated = false
        searchCount = 0
    }

    public func deinit(): Unit {
        testFiles.clear()
    }

    public func takeFoundTestFiles(): ArrayList<String> {
        let result = testFiles
        testFiles = ArrayList<String>()
        return result
    }

    public func scan(pathLiteral: String): Unit {
        if (isTestFile(pathLiteral)) {
            testFiles.append(pathLiteral)
        }
        hasIterated = true
    }

    public func couldBeTestFile(name: String, needsTestSuffix: Bool): Bool {
        if (!needsTestSuffix) {
            return true
        }
        for (suffix in TEST_NAME_SUFFIXES) {
            if (name.endsWith(suffix)) {
                return true
            }
        }
        return false
    }

    public func doesAbsolutePathMatchFilter(name: String): Bool {
        return doesPathMatchFilter(name)
    }

    public func doesPathMatchFilter(name: String): Bool {
        if (filterNames.size == 0) {
            return true
        }
        for (filterName in filterNames) {
            if (name.contains(filterName)) {
                return true
            }
        }
        return false
    }

    public func matchesPathIgnorePattern(absPath: String): Bool {
        return false
    }

    public func isTestFile(name: String): Bool {
        return couldBeTestFile(name, true) && doesPathMatchFilter(name)
    }
}

public class Transpiler {}

public enum ScannerError {
    | DoesNotExist
}
