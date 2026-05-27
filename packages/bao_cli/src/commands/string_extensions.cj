// Shared String extensions for bao_cli.commands subpackage
// These methods are needed because Cangjie's String type doesn't have
// substring(), countOf(), indexOfFrom(start, ch), trim() etc.

package bao_cli.commands

// ============================================================================
// String extensions
// ============================================================================
extend String {
    /// substring(startIndex, endIndex) - returns substring from startIndex to endIndex (exclusive)
    public func substring(startIndex: Int64, endIndex: Int64): String {
        if (startIndex < 0) { return "" }
        if (endIndex > this.size) { return this[Int64(startIndex)..Int64(this.size)] }
        if (startIndex >= endIndex) { return "" }
        return this[Int64(startIndex)..Int64(endIndex)]
    }

    /// substring(startIndex) - returns substring from startIndex to end
    public func substring(startIndex: Int64): String {
        if (startIndex < 0) { return "" }
        if (startIndex >= this.size) { return "" }
        return this[Int64(startIndex)..Int64(this.size)]
    }

    /// countOf - counts occurrences of a character
    public func countOf(ch: String): Int64 {
        var count: Int64 = 0
        for (i in 0..this.size) {
            if (this[i].toString() == ch) {
                count += 1
            }
        }
        return count
    }

    /// indexOfFrom(startIndex, ch) - finds index of ch starting from startIndex
    public func indexOfFrom(startIndex: Int64, ch: String): ?Int64 {
        var i = startIndex
        while (i < this.size) {
            if (this[i].toString() == ch) {
                return Some(i)
            }
            i += 1
        }
        return None
    }

    /// indexOfFrom(ch, startIndex) - alternative parameter order
    public func indexOfFrom(ch: String, startIndex: Int64): ?Int64 {
        return indexOfFrom(startIndex, ch)
    }

    /// trim - removes leading and trailing whitespace
    public func trim(): String {
        return this.trimStart().trimEnd()
    }

    public func lastIndexOf(ch: UInt8): ?Int64 {
        var i = Int64(this.size) - 1
        while (i >= 0) {
            if (this[i] == ch) {
                return Some(i)
            }
            i -= 1
        }
        return None
    }
}
