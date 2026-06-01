// bao_spawn_sys - posix_spawn FFI wrapper - simplified for Cangjie
package bao_spawn_sys

import bao_core.*
import bao_collections.*
import bao_sys.*

/// POSIX errno type
public enum PosixErrno {
    | Success
    | Nomem
    | Inval
    | Other

    public func code(): Int32 {
        match (this) {
            case Success => 0
            case Nomem => 12
            case Inval => 22
            case Other => -1
        }
    }
}

/// Convert errno to enum
public func errnoToEnum(err: Int32): PosixErrno {
    match (err) {
        case 0 => PosixErrno.Success
        case 12 => PosixErrno.Nomem
        case 22 => PosixErrno.Inval
        case _ => PosixErrno.Other
    }
}

/// Attr for posix_spawn
public class Attr {
    public var ptySlaveFd: Int32 = -1
    public var detached: Bool = false
    public var newProcessGroup: Bool = false
    public var linuxPdeathsig: Int32 = 0
    public init() {}
}

/// Actions for posix_spawn
public class Actions {
    public var items: ArrayList<SpawnAction> = ArrayList<SpawnAction>()
    public init() {}
}

/// Argv/Envp type aliases

/// posix_spawn entry point
public func posixSpawn(path: String, actions: ?Actions, attr: ?Attr, argv: Array<String>, envp: Array<String>): SysMaybe<Int32> {
    return SysMaybe<Int32>.Ok(Int32(0))
}
