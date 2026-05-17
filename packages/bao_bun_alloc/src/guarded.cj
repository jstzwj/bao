package bao_bun_alloc

public class Guarded<T> {
    private var value: T

    public init(value: T) {
        this.value = value
    }

    public func lock(): T {
        return value
    }

    public func unlock(): Unit {}
}

public class StackTraceLimits {
    public var frameCount: Int64
    public var stopAtJscLlint: Bool
    public var skipStdlib: Bool

    public init(frameCount: Int64, stopAtJscLlint: Bool, skipStdlib: Bool) {
        this.frameCount = frameCount
        this.stopAtJscLlint = stopAtJscLlint
        this.skipStdlib = skipStdlib
    }
}
