// bao_event_loop - 事件循环包入口
package bao_event_loop

import bao_core.*
import bao_threading.*
import bao_collections.*
import std.time.*

public class AtomicInt64 {
    private var value: Int64

    public init(value: Int64) {
        this.value = value
    }

    public func incrementAndGet(): Int64 {
        value += 1
        return value
    }

    public func decrementAndGet(): Int64 {
        value -= 1
        return value
    }

    public func get(): Int64 {
        return value
    }
}

public class Timespec {
    public var sec: Int64
    public var nsec: Int64

    public init() {
        sec = 0
        nsec = 0
    }

    public init(sec: Int64, nsec: Int64) {
        this.sec = sec
        this.nsec = nsec
    }

    public static let EPOCH: Timespec = Timespec(0, 0)

    public func lessThan(other: Timespec): Bool {
        if (sec != other.sec) { return sec < other.sec }
        return nsec < other.nsec
    }

    public func isZero(): Bool {
        return sec == 0 && nsec == 0
    }

    /// 检查是否为 epoch（零值时间）
    /// 对应 Bun: Timespec.isEpoch
    public func isEpoch(): Bool {
        return sec == 0 && nsec == 0
    }

    /// 忽略 epoch 的比较
    /// 对应 Bun: Timespec.orderIgnoreEpoch
    /// 如果任一为 epoch，返回 false（不排序）；否则返回 this < other
    public func orderIgnoreEpoch(other: Timespec): Bool {
        if (this.isEpoch() || other.isEpoch()) {
            return false
        }
        this.lessThan(other)
    }

    public static func fromMillis(ms: Int64): Timespec {
        return Timespec(ms / 1000, (ms % 1000) * 1000000)
    }

    public func toMillis(): Int64 {
        return sec * 1000 + nsec / 1000000
    }

    public static func nowAllowMocked(): Timespec {
        let ms = DateTime.now().toUnixTimeStamp().toMilliseconds()
        Timespec(ms / 1000, (ms % 1000) * 1000000)
    }

    public static func nowForceRealTime(): Timespec {
        let ms = DateTime.now().toUnixTimeStamp().toMilliseconds()
        Timespec(ms / 1000, (ms % 1000) * 1000000)
    }

    public func addMs(ms: Int64): Timespec {
        let newSec = sec + ms / 1000
        let newNsec = nsec + (ms % 1000) * 1000000
        if (newNsec >= 1000000000) {
            return Timespec(newSec + 1, newNsec - 1000000000)
        }
        Timespec(newSec, newNsec)
    }

    public func duration(other: Timespec): Timespec {
        let dSec = sec - other.sec
        let dNsec = nsec - other.nsec
        if (dNsec < 0) {
            return Timespec(dSec - 1, dNsec + 1000000000)
        }
        Timespec(dSec, dNsec)
    }

    public func greaterThan(other: Timespec): Bool {
        if (sec != other.sec) {
            return sec > other.sec
        }
        return nsec > other.nsec
    }

    public func assign(other: Timespec): Unit {
        sec = other.sec
        nsec = other.nsec
    }
}

public let NS_PER_MS: Int64 = 1000000
public let NS_PER_SEC: Int64 = 1000000000
public let MS_PER_SEC: Int64 = 1000

public enum TaskTagKind {
    | Access
    | AppendFile
    | Chmod
    | Chown
    | Close
    | CopyFile
    | Exists
    | Fchmod
    | Fchown
    | Fdatasync
    | Fstat
    | Fsync
    | Ftruncate
    | Link
    | Lstat
    | Mkdir
    | Open
    | Read
    | Readdir
    | Readlink
    | Rename
    | Rmdir
    | Stat
    | Symlink
    | Truncate
    | Unlink
    | Unlinkat
    | Utimes
    | Write
    | Custom

    public func name(): String {
        match (this) {
            case Access => "Access"
            case AppendFile => "AppendFile"
            case Chmod => "Chmod"
            case Chown => "Chown"
            case Close => "Close"
            case CopyFile => "CopyFile"
            case Exists => "Exists"
            case Fchmod => "Fchmod"
            case Fchown => "Fchown"
            case Fdatasync => "Fdatasync"
            case Fstat => "Fstat"
            case Fsync => "Fsync"
            case Ftruncate => "Ftruncate"
            case Link => "Link"
            case Lstat => "Lstat"
            case Mkdir => "Mkdir"
            case Open => "Open"
            case Read => "Read"
            case Readdir => "Readdir"
            case Readlink => "Readlink"
            case Rename => "Rename"
            case Rmdir => "Rmdir"
            case Stat => "Stat"
            case Symlink => "Symlink"
            case Truncate => "Truncate"
            case Unlink => "Unlink"
            case Unlinkat => "Unlinkat"
            case Utimes => "Utimes"
            case Write => "Write"
            case Custom => "Custom"
        }
    }
}

public interface LegacyTaskable {
    func run(): Unit
}

public class LegacyConcurrentTask {
    public var task: () -> Unit
    public var autoDelete: Bool
    public var done: Bool

    public init(task: () -> Unit) {
        this.task = task
        autoDelete = true
        done = false
    }

    public static func create(task: () -> Unit): LegacyConcurrentTask {
        return LegacyConcurrentTask(task)
    }

    public static func fromCallback(callback: () -> Unit): LegacyConcurrentTask {
        return LegacyConcurrentTask(callback)
    }

    public func run(): Unit {
        if (!done) {
            task()
            done = true
        }
    }
}

public enum LegacyAnyTask {
    | Immediate(() -> Unit)
    | IoEvent(() -> Unit)
}
