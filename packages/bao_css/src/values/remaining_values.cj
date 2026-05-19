package bao_css.values

import bao_core.*
import bao_collections.*

public enum CssParseError {
    | invalidValue
}

public class CssParser {
    public init() {}

    public func expectNumber(): ?Float64 {
        None
    }

    public func expectInteger(): ?Int64 {
        None
    }

    public func expectPercentage(): ?Float64 {
        None
    }

    public func expectString(): ?String {
        None
    }

    public func expectIdent(): ?String {
        None
    }

    public func expectDelim(): ?Rune {
        None
    }

    public func expectDelim(delim: Rune): ?Rune {
        None
    }

    public func tryParse<T>(parser: (CssParser) -> T): ?T {
        Some(parser(this))
    }
}

public class CssBrowsers {
    public var hasBrowsers: Bool

    public init() {
        this.hasBrowsers = false
    }

    public func supportsViewportSmall(): Bool {
        hasBrowsers
    }

    public func supportsViewportLarge(): Bool {
        hasBrowsers
    }

    public func supportsViewportDynamic(): Bool {
        hasBrowsers
    }

    public func supportsContainerQueries(): Bool {
        hasBrowsers
    }
}

public class CssBrowserVersionPlaceholder {
    public var name: String
    public var version: Int64
    public init(name: String, version: Int64) {
        this.name = name
        this.version = version
    }
}

public class VendorPrefix {
    public var webkit: Bool
    public var moz: Bool
    public var ms: Bool
    public var o: Bool

    public init() {
        this.webkit = false
        this.moz = false
        this.ms = false
        this.o = false
    }

    public static func webkitPrefix(): VendorPrefix {
        let prefix = VendorPrefix()
        prefix.webkit = true
        prefix
    }

    public static func mozPrefix(): VendorPrefix {
        let prefix = VendorPrefix()
        prefix.moz = true
        prefix
    }

    public static func oPrefix(): VendorPrefix {
        let prefix = VendorPrefix()
        prefix.o = true
        prefix
    }

    public func isNone(): Bool {
        !webkit && !moz && !ms && !o
    }

    public func isWebkit(): Bool {
        webkit
    }

    public func merge(other: VendorPrefix): Unit {
        this.webkit = this.webkit || other.webkit
        this.moz = this.moz || other.moz
        this.ms = this.ms || other.ms
        this.o = this.o || other.o
    }

    public func eql(other: VendorPrefix): Bool {
        webkit == other.webkit && moz == other.moz && ms == other.ms && o == other.o
    }

    public func deepClone(): VendorPrefix {
        let prefix = VendorPrefix()
        prefix.webkit = webkit
        prefix.moz = moz
        prefix.ms = ms
        prefix.o = o
        prefix
    }

    public func toString(): String {
        if (webkit) { return "-webkit-" }
        if (moz) { return "-moz-" }
        if (ms) { return "-ms-" }
        if (o) { return "-o-" }
        ""
    }
}

public enum Feature {
    | None
}

public class Targets {
    public var browsers: ?ArrayList<CssBrowserVersionPlaceholder>
    public var includeColor: Bool

    public init() {
        this.browsers = None
        this.includeColor = true
    }

    public func prefixes(current: VendorPrefix, feature: Feature): VendorPrefix {
        current
    }
}

