// bao_glob 包入口
// 严格翻译自: src/glob/glob.zig
package bao_glob

// 重新导出匹配函数
public func globMatch(pattern: String, path: String): MatchResult {
    return GlobMatcher.match(pattern, path)
}

public func detectGlobSyntax(potentialPattern: String): Bool {
    return GlobMatcher.detectGlobSyntax(potentialPattern)
}

public type GlobMatchResult = MatchResult
