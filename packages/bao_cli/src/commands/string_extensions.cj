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
        if (ch.size == 0) { return 0 }
        let target = ch[0]
        for (i in 0..this.size) {
            if (this[i] == target) {
                count += 1
            }
        }
        return count
    }

    /// indexOfFrom(startIndex, ch) - finds index of ch starting from startIndex
    public func indexOfFrom(startIndex: Int64, ch: String): ?Int64 {
        if (ch.size == 0) { return None }
        let target = ch[0]
        var i = startIndex
        while (i < this.size) {
            if (this[i] == target) {
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

    /// trim - removes leading and trailing whitespace (delegates to trimAscii)
    public func trim(): String {
        return this.trimAscii()
    }

    /// indexOfAny - finds the index of the first occurrence of any character in chars
    /// Returns the index, or -1 if not found
    public func indexOfAny(chars: String): Int64 {
        for (i in 0..this.size) {
            for (j in 0..chars.size) {
                if (this[i] == chars[j]) {
                    return Int64(i)
                }
            }
        }
        return -1
    }

    /// containsAny - returns true if this string contains any of the characters in the given string
    public func containsAny(chars: String): Bool {
        for (i in 0..this.size) {
            for (j in 0..chars.size) {
                if (this[i] == chars[j]) {
                    return true
                }
            }
        }
        return false
    }

    /// equalsIgnoreCase - compares strings case-insensitively
    public func equalsIgnoreCase(other: String): Bool {
        if (this.size != other.size) { return false }
        for (i in 0..this.size) {
            let a = this[i]
            let b = other[i]
            if (a != b) {
                // Try case-insensitive comparison for ASCII letters
                let aLower = if (a >= UInt8(65) && a <= UInt8(90)) { a + UInt8(32) } else { a }
                let bLower = if (b >= UInt8(65) && b <= UInt8(90)) { b + UInt8(32) } else { b }
                if (aLower != bLower) { return false }
            }
        }
        return true
    }

    /// removeTrailingSlash - removes trailing slash characters
    public func removeTrailingSlash(slash: String): String {
        if (slash.size == 0) { return this }
        let ch = slash[0]
        var end = this.size
        while (end > 1 && this[end - 1] == ch) {
            end -= 1
        }
        return this.substring(0, end)
    }

    /// toLower - converts string to lowercase (ASCII only)
    public func toLower(): String {
        var bytes = Array<UInt8>(this.size, { _ => UInt8(0) })
        for (i in 0..this.size) {
            let c = this[i]
            if (c >= UInt8(65) && c <= UInt8(90)) {
                bytes[i] = c + UInt8(32)
            } else {
                bytes[i] = c
            }
        }
        return String.fromUtf8(bytes)
    }

    /// toUpper - converts string to uppercase (ASCII only)
    public func toUpper(): String {
        var bytes = Array<UInt8>(this.size, { _ => UInt8(0) })
        for (i in 0..this.size) {
            let c = this[i]
            if (c >= UInt8(97) && c <= UInt8(122)) {
                bytes[i] = c - UInt8(32)
            } else {
                bytes[i] = c
            }
        }
        return String.fromUtf8(bytes)
    }

}
