// matcher.cj - Glob模式匹配器
// 严格翻译自: src/glob/matcher.zig
// Portions derived from works under the MIT License:
// Copyright (c) 2023 Devon Govett, 2023 Stephen Gregoratto, 2024 shulaoda
// 1:1 严格翻译

package bao_glob

import std.collection.*

// ============================================================================
// Brace 结构
// 严格翻译自: matcher.zig Brace
// ============================================================================

/// 花括号追踪结构
class Brace {
    var openBraceIdx: Int64
    var branchIdx: Int64

    init(openBraceIdx: Int64, branchIdx: Int64) {
        this.openBraceIdx = openBraceIdx
        this.branchIdx = branchIdx
    }
}

// ============================================================================
// MatchResult 枚举
// 严格翻译自: matcher.zig MatchResult
// ============================================================================

/// 匹配结果
public enum MatchResult {
    | noMatch
    | match_
    | negateNoMatch
    | negateMatch_

    /// 是否匹配
    public func isMatch(): Bool {
        match (this) {
            case match_ => true
            case negateMatch_ => true
            case _ => false
        }
    }
}

// ============================================================================
// Wildcard 结构
// 严格翻译自: matcher.zig Wildcard
// ============================================================================

/// 通配符状态追踪
class Wildcard {
    var globIndex: Int64
    var pathIndex: Int64
    var braceDepth: Int64

    init() {
        globIndex = 0
        pathIndex = 0
        braceDepth = 0
    }

    init(globIndex: Int64, pathIndex: Int64, braceDepth: Int64) {
        this.globIndex = globIndex
        this.pathIndex = pathIndex
        this.braceDepth = braceDepth
    }
}

// ============================================================================
// State 结构
// 严格翻译自: matcher.zig State
// ============================================================================

/// 匹配状态
class MatcherState {
    var pathIndex: Int64
    var globIndex: Int64
    var wildcard: Wildcard
    var globstar: Wildcard
    var braceDepth: Int64

    init() {
        pathIndex = 0
        globIndex = 0
        wildcard = Wildcard()
        globstar = Wildcard()
        braceDepth = 0
    }

    /// 回溯到上一个通配符位置
    func backtrack(): Unit {
        pathIndex = wildcard.pathIndex
        globIndex = wildcard.globIndex
        braceDepth = wildcard.braceDepth
    }

    /// 跳到下一个路径分隔符
    func skipToSeparator(path: Array<UInt8>, isEndInvalid: Bool): Unit {
        if (pathIndex == path.size) {
            wildcard.pathIndex += 1
            return
        }

        var pi = pathIndex
        while (pi < path.size && !GlobMatcher.isSeparator(path[pi])) {
            pi += 1
        }

        if (isEndInvalid || pi != path.size) {
            pi += 1
        }

        wildcard.pathIndex = pi
        globstar = Wildcard(wildcard.globIndex, wildcard.pathIndex, wildcard.braceDepth)
    }
}

// ============================================================================
// GlobMatcher - 主匹配类
// 严格翻译自: matcher.zig match()
// ============================================================================

/// Glob模式匹配器
public class GlobMatcher {

    /// 最大花括号嵌套深度
    static let MAX_BRACE_DEPTH: Int64 = 10

    /// 匹配路径与glob模式
    /// 对应 Bun: match(glob, path) -> MatchResult
    public static func `match`(glob: String, path: String): MatchResult {
        return matchBytes(glob.toArray(), path.toArray())
    }

    /// 匹配字节数组
    public static func matchBytes(glob: Array<UInt8>, path: Array<UInt8>): MatchResult {
        var state = MatcherState()
        var braceStack = ArrayList<Brace>()

        var negated = false
        while (state.globIndex < glob.size && glob[state.globIndex] == UInt8(33)) {  // '!'
            negated = !negated
            state.globIndex += 1
        }

        let matched = globMatchImpl(state, glob, 0, path, braceStack)

        if (negated) {
            return if (matched) { MatchResult.negateNoMatch } else { MatchResult.negateMatch_ }
        } else {
            return if (matched) { MatchResult.match_ } else { MatchResult.noMatch }
        }
    }

    /// 核心匹配实现
    /// 对应 Bun: globMatchImpl
    static func globMatchImpl(
        state: MatcherState, glob: Array<UInt8>, globStart: Int64,
        path: Array<UInt8>, braceStack: ArrayList<Brace>
    ): Bool {
        while (state.globIndex < glob.size || state.pathIndex < path.size) {
            if (state.globIndex < glob.size) {
                let char = glob[state.globIndex]

                if (char == UInt8(42)) {
                    // 通配符处理
                    let isGlobstar = state.globIndex + 1 < glob.size && glob[state.globIndex + 1] == UInt8(42)

                    if (isGlobstar) {
                        skipGlobstars(glob, state)
                    }

                    state.wildcard.globIndex = state.globIndex
                    state.wildcard.pathIndex = state.pathIndex + (if (state.pathIndex < path.size) { 1 } else { 1 })
                    state.wildcard.braceDepth = state.braceDepth

                    var inGlobstar = false
                    if (isGlobstar) {
                        state.globIndex += 2

                        let isEndInvalid = state.globIndex < glob.size

                        if (isEndInvalid && state.pathIndex == path.size &&
                            glob.size - state.globIndex == 2 &&
                            isSeparator(glob[state.globIndex]) &&
                            glob[state.globIndex + 1] == UInt8(42)) {
                            continue
                        }

                        if ((state.globIndex - globStart < 3 || glob[state.globIndex - 3] == UInt8(47)) &&
                            (!isEndInvalid || glob[state.globIndex] == UInt8(47))) {
                            if (isEndInvalid) {
                                state.globIndex += 1
                            }
                            state.skipToSeparator(path, isEndInvalid)
                            inGlobstar = true
                        }
                    } else {
                        state.globIndex += 1
                    }

                    if (!inGlobstar && state.pathIndex < path.size && isSeparator(path[state.pathIndex])) {
                        state.wildcard = Wildcard(state.globstar.globIndex, state.globstar.pathIndex, state.globstar.braceDepth)
                    }

                    continue
                } else if (char == UInt8(63)) {
                    if (state.pathIndex < path.size) {
                        if (!isSeparator(path[state.pathIndex])) {
                            state.globIndex += 1
                            state.pathIndex += 1
                            continue
                        }
                    } else {
                        // path已结束, ?无法匹配
                    }
                } else if (char == UInt8(91)) {
                    if (state.pathIndex < path.size) {
                        state.globIndex += 1

                        var bracketNegated = false
                        if (state.globIndex < glob.size && (glob[state.globIndex] == UInt8(94) || glob[state.globIndex] == UInt8(33))) {
                            bracketNegated = true
                            state.globIndex += 1
                        }

                        var first = true
                        var isBracketMatch = false

                        let c = UInt32(path[state.pathIndex])

                        while (state.globIndex < glob.size && (first || glob[state.globIndex] != UInt8(93))) {
                            var low = UInt32(glob[state.globIndex])
                            state.globIndex += 1

                            if (low == UInt32(92) && state.globIndex < glob.size) {
                                low = UInt32(glob[state.globIndex])
                                state.globIndex += 1
                            }

                            let high = if (state.globIndex + 1 < glob.size && glob[state.globIndex] == UInt8(45) && glob[state.globIndex + 1] != UInt8(93)) {
                                state.globIndex += 1
                                var h = UInt32(glob[state.globIndex])
                                state.globIndex += 1
                                if (h == UInt32(92) && state.globIndex < glob.size) {
                                    h = UInt32(glob[state.globIndex])
                                    state.globIndex += 1
                                }
                                h
                            } else {
                                low
                            }

                            if (low <= c && c <= high) {
                                isBracketMatch = true
                            }

                            first = false
                        }

                        if (state.globIndex >= glob.size) {
                            return false
                        }

                        state.globIndex += 1
                        if (isBracketMatch != bracketNegated) {
                            state.pathIndex += 1
                            continue
                        }
                    }
                } else if (char == UInt8(123)) {
                    var foundBrace = false
                    for (brace in braceStack) {
                        if (brace.openBraceIdx == state.globIndex) {
                            state.globIndex = brace.branchIdx
                            state.braceDepth += 1
                            foundBrace = true
                            break
                        }
                    }
                    if (foundBrace) {
                        continue
                    }
                    return matchBrace(state, glob, path, braceStack)
                } else if (char == UInt8(44)) {
                    if (state.braceDepth > 0) {
                        skipBranch(state, glob)
                        continue
                    }
                    // 否则作为普通字符处理
                } else if (char == UInt8(125)) {
                    if (state.braceDepth > 0) {
                        skipBranch(state, glob)
                        continue
                    }
                }

                // 普通字符匹配
                if (state.pathIndex < path.size) {
                    var cc = char
                    if (cc == UInt8(92) && state.globIndex + 1 < glob.size) {
                        state.globIndex += 1
                        cc = glob[state.globIndex]
                    }

                    let isCharMatch = if (cc == UInt8(47)) {
                        isSeparator(path[state.pathIndex])
                    } else {
                        path[state.pathIndex] == cc
                    }

                    if (isCharMatch) {
                        state.globIndex += 1
                        state.pathIndex += 1

                        if (cc == UInt8(47)) {
                            state.wildcard = Wildcard(state.globstar.globIndex, state.globstar.pathIndex, state.globstar.braceDepth)
                        }
                        continue
                    }
                }
            }

            // 回溯
            if (state.wildcard.pathIndex > 0 && state.wildcard.pathIndex <= path.size) {
                state.backtrack()
                continue
            }

            return false
        }

        return true
    }

    /// 花括号匹配
    /// 对应 Bun: matchBrace
    static func matchBrace(
        state: MatcherState, glob: Array<UInt8>, path: Array<UInt8>,
        braceStack: ArrayList<Brace>
    ): Bool {
        var braceDepth: Int64 = 0
        var inBrackets = false

        let openBraceIndex = state.globIndex
        var branchIndex: Int64 = 0

        while (state.globIndex < glob.size) {
            let c = glob[state.globIndex]
            if (c == UInt8(123) && !inBrackets) {
                braceDepth += 1
                if (braceDepth == 1) {
                    branchIndex = state.globIndex + 1
                }
            } else if (c == UInt8(125) && !inBrackets) {
                braceDepth -= 1
                if (braceDepth == 0) {
                    if (matchBraceBranch(state, glob, path, openBraceIndex, branchIndex, braceStack)) {
                        return true
                    }
                    break
                }
            } else if (c == UInt8(44) && braceDepth == 1) {
                if (matchBraceBranch(state, glob, path, openBraceIndex, branchIndex, braceStack)) {
                    return true
                }
                branchIndex = state.globIndex + 1
            } else if (c == UInt8(91) && !inBrackets) {
                inBrackets = true
            } else if (c == UInt8(93)) {
                inBrackets = false
            } else if (c == UInt8(92)) {
                state.globIndex += 1
            }
            state.globIndex += 1
        }

        return false
    }

    /// 花括号分支匹配
    /// 对应 Bun: matchBraceBranch
    static func matchBraceBranch(
        state: MatcherState, glob: Array<UInt8>, path: Array<UInt8>,
        openBraceIndex: Int64, branchIndex: Int64, braceStack: ArrayList<Brace>
    ): Bool {
        if (braceStack.size >= MAX_BRACE_DEPTH) {
            return false
        }

        braceStack.add(Brace(openBraceIndex, branchIndex))

        // 克隆状态
        let savedGlobIndex = state.globIndex
        let savedPathIndex = state.pathIndex
        let savedBraceDepth = state.braceDepth
        let savedWildcard = Wildcard(state.wildcard.globIndex, state.wildcard.pathIndex, state.wildcard.braceDepth)
        let savedGlobstar = Wildcard(state.globstar.globIndex, state.globstar.pathIndex, state.globstar.braceDepth)

        state.globIndex = branchIndex
        state.braceDepth = Int64(braceStack.size)

        let matched = globMatchImpl(state, glob, branchIndex, path, braceStack)

        // 恢复状态
        state.globIndex = savedGlobIndex
        state.pathIndex = savedPathIndex
        state.braceDepth = savedBraceDepth
        state.wildcard = savedWildcard
        state.globstar = savedGlobstar

        braceStack.remove(at: braceStack.size - 1)

        return matched
    }

    /// 跳过花括号分支
    /// 对应 Bun: skipBranch
    static func skipBranch(state: MatcherState, glob: Array<UInt8>): Unit {
        var inBrackets = false
        let endBraceDepth = state.braceDepth - 1
        while (state.globIndex < glob.size) {
            let c = glob[state.globIndex]
            if (c == UInt8(123) && !inBrackets) {
                state.braceDepth += 1
            } else if (c == UInt8(125) && !inBrackets) {
                state.braceDepth -= 1
                if (state.braceDepth == endBraceDepth) {
                    state.globIndex += 1
                    return
                }
            } else if (c == UInt8(91) && !inBrackets) {
                inBrackets = true
            } else if (c == UInt8(93)) {
                inBrackets = false
            } else if (c == UInt8(92)) {
                state.globIndex += 1
            }
            state.globIndex += 1
        }
    }

    /// 跳过连续的 **/ 前缀
    /// 对应 Bun: skipGlobstars
    static func skipGlobstars(glob: Array<UInt8>, state: MatcherState): Unit {
        state.globIndex += 2

        while (state.globIndex + 4 <= glob.size) {
            if (glob[state.globIndex] == UInt8(47) &&
                glob[state.globIndex + 1] == UInt8(42) &&
                glob[state.globIndex + 2] == UInt8(42) &&
                (state.globIndex + 3 >= glob.size || glob[state.globIndex + 3] == UInt8(47))) {
                state.globIndex += 3
            } else {
                break
            }
        }

        if (state.globIndex + 3 == glob.size &&
            glob[state.globIndex] == UInt8(47) &&
            glob[state.globIndex + 1] == UInt8(42) &&
            glob[state.globIndex + 2] == UInt8(42)) {
            state.globIndex += 3
        }

        state.globIndex -= 2
    }

    /// 是否路径分隔符
    /// 对应 Bun: isSeparator
    static func isSeparator(c: UInt8): Bool {
        return c == UInt8(47) || c == UInt8(92)
    }
}
