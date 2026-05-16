// bao_collections - ArrayHashMap simplified Cangjie implementation
package bao_collections

import std.collection.*

private let EMPTY_HASH: UInt64 = UInt64.Max
private let DEFAULT_MAX_LOAD_PERCENTAGE: Int64 = 50

public class GetOrPutResult<V> {
    public var value: ?V
    public var foundExisting: Bool

    public init(value: ?V, foundExisting: Bool) {
        this.value = value
        this.foundExisting = foundExisting
    }
}

public interface HashContext<K> {
    func hash(key: K): UInt64
    func eql(a: K, b: K): Bool
}

public class AutoHashContext<K> <: HashContext<K> where K <: Hashable & Equatable<K> {
    public init() {}
    public func hash(key: K): UInt64 { UInt64(key.hashCode()) }
    public func eql(a: K, b: K): Bool { a == b }
}

public class ArrayHashEntry<K, V> {
    public var hash: UInt64
    public var key: ?K
    public var value: ?V

    public init(key: ?K, value: ?V, hash: UInt64) {
        this.key = key
        this.value = value
        this.hash = hash
    }

    public func isEmpty(): Bool { hash == EMPTY_HASH }
}

public class ArrayHashMap<K, V> where K <: Hashable & Equatable<K> & ToString {
    private var map: HashMap<K, V>
    private var maxLoadPercentage: Int64
    private var ctx: HashContext<K>

    public prop size: Int64 { get() { map.size } }

    public init() {
        map = HashMap<K, V>()
        maxLoadPercentage = DEFAULT_MAX_LOAD_PERCENTAGE
        ctx = AutoHashContext<K>()
    }

    public init(ctx: HashContext<K>) {
        map = HashMap<K, V>()
        maxLoadPercentage = DEFAULT_MAX_LOAD_PERCENTAGE
        this.ctx = ctx
    }

    public init(capacity: Int64) {
        map = HashMap<K, V>()
        maxLoadPercentage = DEFAULT_MAX_LOAD_PERCENTAGE
        ctx = AutoHashContext<K>()
    }

    public init(capacity: Int64, ctx: HashContext<K>) {
        map = HashMap<K, V>()
        maxLoadPercentage = DEFAULT_MAX_LOAD_PERCENTAGE
        this.ctx = ctx
    }

    public func isEmpty(): Bool { map.size == 0 }
    public func capacity(): Int64 { map.size }
    public func slice(): ArrayList<ArrayHashEntry<K, V>> { ArrayList<ArrayHashEntry<K, V>>() }

    public func putAssumeCapacity(key: K, value: V): Unit { map.put(key, value) }
    public func put(key: K, value: V): Unit { map.put(key, value) }

    public func getOrPutAssumeCapacity(key: K): GetOrPutResult<V> {
        match (map.get(key)) {
            case Some(v) => GetOrPutResult<V>(Some(v), true)
            case None => GetOrPutResult<V>(Option<V>.None, false)
        }
    }

    public func getOrPut(key: K): GetOrPutResult<V> { getOrPutAssumeCapacity(key) }
    public func get(key: K): ?V { map.get(key) }
    public func has(key: K): Bool { map.contains(key) }
    public func hasWithHash(keyHash: UInt64): Bool { false }
    public func delete(key: K): ?V { map.remove(key) }
    public func clearRetainingCapacity(): Unit { map.clear() }
    public func clear(): Unit { map.clear() }
    public func ensureUnusedCapacity(count: Int64): Unit { () }
    public func ensureTotalCapacity(count: Int64): Unit { () }

    public func allEntries(): ArrayList<(K, V)> {
        let result = ArrayList<(K, V)>()
        for ((k, v) in map.iterator()) { result.append((k, v)) }
        return result
    }

    public func keys(): ArrayList<K> {
        let result = ArrayList<K>()
        for ((k, _) in map.iterator()) { result.append(k) }
        return result
    }

    public func values(): ArrayList<V> {
        let result = ArrayList<V>()
        for ((_, v) in map.iterator()) { result.append(v) }
        return result
    }

    public func forEach(fn: (K, V) -> Unit): Unit {
        for ((k, v) in map.iterator()) { fn(k, v) }
    }

    public func isSorted(): Bool { true }

    public static func computeShift(capacity: Int64): UInt8 {
        if (capacity <= 0) { return UInt8(60) }
        var c = capacity
        var log2: Int64 = 0
        while (c > 1) {
            c = c >> 1
            log2 += 1
        }
        return UInt8(63 - log2 + 1)
    }

    public static func computeOverflow(capacity: Int64, shift: UInt8): Int64 {
        let s = Int64(shift)
        return ((capacity / 10) + (63 - s + 1)) << 1
    }
}

public class AutoHashMap<K, V> where K <: Hashable & Equatable<K> & ToString {
    private var inner: ArrayHashMap<K, V>

    public init() { inner = ArrayHashMap<K, V>() }
    public init(capacity: Int64) { inner = ArrayHashMap<K, V>(capacity) }
    public prop size: Int64 { get() { inner.size } }
    public func isEmpty(): Bool { inner.isEmpty() }
    public func put(key: K, value: V): Unit { inner.put(key, value) }
    public func get(key: K): ?V { inner.get(key) }
    public func has(key: K): Bool { inner.has(key) }
    public func delete(key: K): ?V { inner.delete(key) }
    public func clear(): Unit { inner.clear() }
    public func keys(): ArrayList<K> { inner.keys() }
    public func values(): ArrayList<V> { inner.values() }
    public func forEach(fn: (K, V) -> Unit): Unit { inner.forEach(fn) }
}

public class SortedEntry<V> {
    public var hash: Array<UInt8>
    public var value: ?V
    public static let SORTED_EMPTY_HASH: Array<UInt8> = Array<UInt8>(32, repeat: UInt8(0xFF))

    public init(hash: Array<UInt8>, value: ?V) {
        this.hash = hash
        this.value = value
    }

    public func isEmpty(): Bool { compareHashes(hash, SORTED_EMPTY_HASH) == 0 }
}

private func compareHashes(a: Array<UInt8>, b: Array<UInt8>): Int64 {
    let len = if (a.size < b.size) { a.size } else { b.size }
    for (i in 0..len) {
        if (a[i] < b[i]) { return -1 }
        if (a[i] > b[i]) { return 1 }
    }
    if (a.size < b.size) { return -1 }
    if (a.size > b.size) { return 1 }
    return 0
}

public class SortedHashMap<V> {
    private var entries: ArrayList<SortedEntry<V>>
    private var _len: Int64
    private var maxLoadPercentage: Int64

    public prop size: Int64 { get() { _len } }

    public init() {
        entries = ArrayList<SortedEntry<V>>()
        _len = 0
        maxLoadPercentage = DEFAULT_MAX_LOAD_PERCENTAGE
    }

    public init(capacity: Int64) {
        entries = ArrayList<SortedEntry<V>>()
        _len = 0
        maxLoadPercentage = DEFAULT_MAX_LOAD_PERCENTAGE
    }

    public func isEmpty(): Bool { _len == 0 }

    public func put(key: Array<UInt8>, value: V): Unit { putAssumeCapacity(key, value) }

    public func putAssumeCapacity(key: Array<UInt8>, value: V): Unit {
        for (i in 0..entries.size) {
            if (compareHashes(entries[i].hash, key) == 0) {
                entries[i].value = Some(value)
                return
            }
        }
        entries.append(SortedEntry<V>(key, Some(value)))
        _len += 1
    }

    public func getOrPutAssumeCapacity(key: Array<UInt8>): GetOrPutResult<V> {
        match (get(key)) {
            case Some(v) => GetOrPutResult<V>(Some(v), true)
            case None => GetOrPutResult<V>(Option<V>.None, false)
        }
    }

    public func get(key: Array<UInt8>): ?V {
        for (i in 0..entries.size) {
            if (compareHashes(entries[i].hash, key) == 0) {
                return entries[i].value
            }
        }
        return Option<V>.None
    }

    public func delete(key: Array<UInt8>): ?V {
        for (i in 0..entries.size) {
            if (compareHashes(entries[i].hash, key) == 0) {
                let value = entries[i].value
                entries.orderedRemove(i)
                _len -= 1
                return value
            }
        }
        return Option<V>.None
    }

    public func clear(): Unit {
        entries.clearRetainingCapacity()
        _len = 0
    }

    public func ensureUnusedCapacity(count: Int64): Unit { () }
    public func ensureTotalCapacity(count: Int64): Unit { () }
    public func forEach(fn: (Array<UInt8>, V) -> Unit): Unit {
        for (i in 0..entries.size) {
            match (entries[i].value) {
                case Some(v) => fn(entries[i].hash, v)
                case None => ()
            }
        }
    }
}
