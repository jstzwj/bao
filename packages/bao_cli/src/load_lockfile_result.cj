package bao_cli

import bao_core.*

public enum LoadLockfileResult {
    | ok
    | notFound
    | not_found
    | err(BaoError)

    public prop errorValue: BaoError {
        get() {
            match (this) {
                case LoadLockfileResult.err(e) => e
                case _ => BaoError(ErrorCode.Unknown, "no error")
            }
        }
    }

    public operator func ==(other: LoadLockfileResult): Bool {
        match (this) {
            case LoadLockfileResult.ok => match (other) { case LoadLockfileResult.ok => true case _ => false }
            case LoadLockfileResult.notFound => match (other) { case LoadLockfileResult.notFound => true case _ => false }
            case LoadLockfileResult.not_found => match (other) { case LoadLockfileResult.not_found => true case _ => false }
            case LoadLockfileResult.err(e1) => match (other) { case LoadLockfileResult.err(e2) => e1 == e2 case _ => false }
        }
    }

    public operator func !=(other: LoadLockfileResult): Bool {
        return !(this == other)
    }
}
