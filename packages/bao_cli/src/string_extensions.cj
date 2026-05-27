package bao_cli

extend String {
    public func substring(startIndex: Int64, endIndex: Int64): String {
        if (startIndex < 0) { return "" }
        if (endIndex > this.size) { return this[Int64(startIndex)..Int64(this.size)] }
        if (startIndex >= endIndex) { return "" }
        return this[Int64(startIndex)..Int64(endIndex)]
    }

    public func substring(startIndex: Int64): String {
        if (startIndex < 0) { return "" }
        if (startIndex >= this.size) { return "" }
        return this[Int64(startIndex)..Int64(this.size)]
    }

    public func indexOfFrom(startIndex: Int64, ch: UInt8): ?Int64 {
        var i = startIndex
        while (i < this.size) {
            if (this[i] == ch) {
                return Some(i)
            }
            i += 1
        }
        return None
    }
}
