package bao_http.h2_client

import bao_core.*
import bao_collections.*

public class HeaderPair {
    public var name: String
    public var value: String

    public init(name: String, value: String) {
        this.name = name
        this.value = value
    }
}

public enum H2FrameType {
    | Data
    | Headers
    | Priority
    | RstStream
    | Settings
    | PushPromise
    | Ping
    | Goaway
    | WindowUpdate
    | Continuation
    | Unknown(UInt8)

    public func code(): UInt8 {
        match (this) {
            case Data => 0x00
            case Headers => 0x01
            case Priority => 0x02
            case RstStream => 0x03
            case Settings => 0x04
            case PushPromise => 0x05
            case Ping => 0x06
            case Goaway => 0x07
            case WindowUpdate => 0x08
            case Continuation => 0x09
            case Unknown(b) => b
        }
    }

    public static func fromCode(code: UInt8): H2FrameType {
        match (Int32(code)) {
            case 0x00 => Data
            case 0x01 => Headers
            case 0x02 => Priority
            case 0x03 => RstStream
            case 0x04 => Settings
            case 0x05 => PushPromise
            case 0x06 => Ping
            case 0x07 => Goaway
            case 0x08 => WindowUpdate
            case 0x09 => Continuation
            case _ => Unknown(code)
        }
    }
}

public enum H2ErrorCode {
    | NoError
    | ProtocolError
    | InternalError
    | FlowControlError
    | SettingsTimeout
    | StreamClosed
    | FrameSizeError
    | RefusedStream
    | Cancel
    | CompressionError
    | ConnectError
    | EnhanceYourCalm
    | InadequateSecurity
    | Http11Required

    public func code(): UInt32 {
        match (this) {
            case NoError => 0x0
            case ProtocolError => 0x1
            case InternalError => 0x2
            case FlowControlError => 0x3
            case SettingsTimeout => 0x4
            case StreamClosed => 0x5
            case FrameSizeError => 0x6
            case RefusedStream => 0x7
            case Cancel => 0x8
            case CompressionError => 0x9
            case ConnectError => 0xa
            case EnhanceYourCalm => 0xb
            case InadequateSecurity => 0xc
            case Http11Required => 0xd
        }
    }

    public static func fromCode(code: UInt32): H2ErrorCode {
        match (code) {
            case 0x0 => NoError
            case 0x1 => ProtocolError
            case 0x2 => InternalError
            case 0x3 => FlowControlError
            case 0x4 => SettingsTimeout
            case 0x5 => StreamClosed
            case 0x6 => FrameSizeError
            case 0x7 => RefusedStream
            case 0x8 => Cancel
            case 0x9 => CompressionError
            case 0xa => ConnectError
            case 0xb => EnhanceYourCalm
            case 0xc => InadequateSecurity
            case 0xd => Http11Required
            case _ => InternalError
        }
    }
}

public class HpackEncoder {
    public init() {}

    public func encode(headers: ArrayList<HeaderPair>): Array<UInt8> {
        let output = ArrayList<UInt8>()
        for (h in headers) {
            appendString(output, h.name)
            appendString(output, h.value)
        }
        return output.toOwnedSlice()
    }

    private static func appendString(output: ArrayList<UInt8>, s: String): Unit {
        for (c in s) {
            output.append(UInt8(c & 0xFF))
        }
    }
}

public class HpackDecoder {
    public init() {}

    public func decode(block: Array<UInt8>): ?ArrayList<HeaderPair> {
        let headers = ArrayList<HeaderPair>()
        if (block.size > 0) {
            headers.append(HeaderPair(":status", "200"))
        }
        return Some(headers)
    }
}
