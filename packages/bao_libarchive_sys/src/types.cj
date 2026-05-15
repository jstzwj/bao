// 严格翻译自: src/libarchive_sys/bindings.zig

package bao_libarchive_sys

// ============================================================================
// Type aliases
// ============================================================================

public type LaInt64T = Int64
public type LaSsizeT = Int64
public type TimeT = Int64
public type ModeT = UInt32
public type DevT = UInt64
public type WCharT = UInt16

// ============================================================================
// Opaque types
// ============================================================================

@C
public struct StructArchive {}
@C
public struct StructArchiveEntry {}
@C
public struct StructStat {}
@C
public struct StructArchiveAcl {}
@C
public struct StructArchiveEntryLinkresolver {}

// ============================================================================
// FileType enum
// ============================================================================

public enum FileType {
    | regular
    | link
    | socket
    | character_oriented_device
    | block_oriented_device
    | directory
    | fifo
}

// ============================================================================
// SymlinkType enum
// ============================================================================

public enum SymlinkType {
    | none
    | file
    | directory
}

// ============================================================================
// Result constants
// ============================================================================

public let ARCHIVE_EOF: Int32 = 1
public let ARCHIVE_OK: Int32 = 0
public let ARCHIVE_RETRY: Int32 = -10
public let ARCHIVE_WARN: Int32 = -20
public let ARCHIVE_FAILED: Int32 = -25
public let ARCHIVE_FATAL: Int32 = -30

// ============================================================================
// Result enum
// ============================================================================

public enum ArchiveResult {
    | eof
    | ok
    | retry
    | warn
    | failed
    | fatal
}

// ============================================================================
// Filter constants
// ============================================================================

public let ARCHIVE_FILTER_NONE: Int32 = 0
public let ARCHIVE_FILTER_GZIP: Int32 = 1
public let ARCHIVE_FILTER_BZIP2: Int32 = 2
public let ARCHIVE_FILTER_COMPRESS: Int32 = 3
public let ARCHIVE_FILTER_PROGRAM: Int32 = 4
public let ARCHIVE_FILTER_LZMA: Int32 = 5
public let ARCHIVE_FILTER_XZ: Int32 = 6
public let ARCHIVE_FILTER_UU: Int32 = 7
public let ARCHIVE_FILTER_RPM: Int32 = 8
public let ARCHIVE_FILTER_LZIP: Int32 = 9
public let ARCHIVE_FILTER_LRZIP: Int32 = 10
public let ARCHIVE_FILTER_LZOP: Int32 = 11
public let ARCHIVE_FILTER_GRZIP: Int32 = 12
public let ARCHIVE_FILTER_LZ4: Int32 = 13
public let ARCHIVE_FILTER_ZSTD: Int32 = 14

// ============================================================================
// Format constants
// ============================================================================

public let ARCHIVE_FORMAT_BASE_MASK: Int32 = 0x00ff0000
public let ARCHIVE_FORMAT_CPIO: Int32 = 0x00010000
public let ARCHIVE_FORMAT_CPIO_POSIX: Int32 = 0x00010001
public let ARCHIVE_FORMAT_CPIO_BIN_LE: Int32 = 0x00010002
public let ARCHIVE_FORMAT_CPIO_BIN_BE: Int32 = 0x00010003
public let ARCHIVE_FORMAT_CPIO_SVR4_NOCRC: Int32 = 0x00010004
public let ARCHIVE_FORMAT_CPIO_SVR4_CRC: Int32 = 0x00010005
public let ARCHIVE_FORMAT_CPIO_AFIO_LARGE: Int32 = 0x00010006
public let ARCHIVE_FORMAT_CPIO_PWB: Int32 = 0x00010007
public let ARCHIVE_FORMAT_SHAR: Int32 = 0x00020000
public let ARCHIVE_FORMAT_SHAR_BASE: Int32 = 0x00020001
public let ARCHIVE_FORMAT_SHAR_DUMP: Int32 = 0x00020002
public let ARCHIVE_FORMAT_TAR: Int32 = 0x00030000
public let ARCHIVE_FORMAT_TAR_USTAR: Int32 = 0x00030001
public let ARCHIVE_FORMAT_TAR_PAX_INTERCHANGE: Int32 = 0x00030002
public let ARCHIVE_FORMAT_TAR_PAX_RESTRICTED: Int32 = 0x00030003
public let ARCHIVE_FORMAT_TAR_GNUTAR: Int32 = 0x00030004
public let ARCHIVE_FORMAT_ISO9660: Int32 = 0x00040000
public let ARCHIVE_FORMAT_ISO9660_ROCKRIDGE: Int32 = 0x00040001
public let ARCHIVE_FORMAT_ZIP: Int32 = 0x00050000
public let ARCHIVE_FORMAT_EMPTY: Int32 = 0x00060000
public let ARCHIVE_FORMAT_AR: Int32 = 0x00070000
public let ARCHIVE_FORMAT_AR_GNU: Int32 = 0x00070001
public let ARCHIVE_FORMAT_AR_BSD: Int32 = 0x00070002
public let ARCHIVE_FORMAT_MTREE: Int32 = 0x00080000
public let ARCHIVE_FORMAT_RAW: Int32 = 0x00090000
public let ARCHIVE_FORMAT_XAR: Int32 = 0x000A0000
public let ARCHIVE_FORMAT_LHA: Int32 = 0x000B0000
public let ARCHIVE_FORMAT_CAB: Int32 = 0x000C0000
public let ARCHIVE_FORMAT_RAR: Int32 = 0x000D0000
public let ARCHIVE_FORMAT_7ZIP: Int32 = 0x000E0000
public let ARCHIVE_FORMAT_WARC: Int32 = 0x000F0000
public let ARCHIVE_FORMAT_RAR_V5: Int32 = 0x00100000

// ============================================================================
// Extract flags constants
// ============================================================================

public let ARCHIVE_EXTRACT_OWNER: Int32 = 0x0001
public let ARCHIVE_EXTRACT_PERM: Int32 = 0x0002
public let ARCHIVE_EXTRACT_TIME: Int32 = 0x0004
public let ARCHIVE_EXTRACT_NO_OVERWRITE: Int32 = 0x0008
public let ARCHIVE_EXTRACT_UNLINK: Int32 = 0x0010
public let ARCHIVE_EXTRACT_ACL: Int32 = 0x0020
public let ARCHIVE_EXTRACT_FFLAGS: Int32 = 0x0040
public let ARCHIVE_EXTRACT_XATTR: Int32 = 0x0080
public let ARCHIVE_EXTRACT_SECURE_SYMLINKS: Int32 = 0x0100
public let ARCHIVE_EXTRACT_SECURE_NODOTDOT: Int32 = 0x0200
public let ARCHIVE_EXTRACT_NO_AUTODIR: Int32 = 0x0400
public let ARCHIVE_EXTRACT_NO_OVERWRITE_NEWER: Int32 = 0x0800
public let ARCHIVE_EXTRACT_SPARSE: Int32 = 0x1000
public let ARCHIVE_EXTRACT_MAC_METADATA: Int32 = 0x2000
public let ARCHIVE_EXTRACT_NO_HFS_COMPRESSION: Int32 = 0x4000
public let ARCHIVE_EXTRACT_HFS_COMPRESSION_FORCED: Int32 = 0x00008000
public let ARCHIVE_EXTRACT_SECURE_NOABSOLUTEPATHS: Int32 = 0x00010000
public let ARCHIVE_EXTRACT_CLEAR_NOCHANGE_FFLAGS: Int32 = 0x00020000
public let ARCHIVE_EXTRACT_SAFE_WRITES: Int32 = 0x00040000

// ============================================================================
// Symlink type constants
// ============================================================================

public let AE_SYMLINK_TYPE_UNDEFINED: Int32 = 0
public let AE_SYMLINK_TYPE_FILE: Int32 = 1
public let AE_SYMLINK_TYPE_DIRECTORY: Int32 = 2

// ============================================================================
// Entry digest constants
// ============================================================================

public let ARCHIVE_ENTRY_DIGEST_MD5: Int32 = 0x00000001
public let ARCHIVE_ENTRY_DIGEST_RMD160: Int32 = 0x00000002
public let ARCHIVE_ENTRY_DIGEST_SHA1: Int32 = 0x00000003
public let ARCHIVE_ENTRY_DIGEST_SHA256: Int32 = 0x00000004
public let ARCHIVE_ENTRY_DIGEST_SHA384: Int32 = 0x00000005
public let ARCHIVE_ENTRY_DIGEST_SHA512: Int32 = 0x00000006

// ============================================================================
// ACL constants
// ============================================================================

public let ARCHIVE_ENTRY_ACL_EXECUTE: Int32 = 0x00000001
public let ARCHIVE_ENTRY_ACL_WRITE: Int32 = 0x00000002
public let ARCHIVE_ENTRY_ACL_READ: Int32 = 0x00000004
public let ARCHIVE_ENTRY_ACL_READ_DATA: Int32 = 0x00000008
public let ARCHIVE_ENTRY_ACL_LIST_DIRECTORY: Int32 = 0x00000008
public let ARCHIVE_ENTRY_ACL_WRITE_DATA: Int32 = 0x00000010
public let ARCHIVE_ENTRY_ACL_ADD_FILE: Int32 = 0x00000010
public let ARCHIVE_ENTRY_ACL_APPEND_DATA: Int32 = 0x00000020
public let ARCHIVE_ENTRY_ACL_ADD_SUBDIRECTORY: Int32 = 0x00000020
public let ARCHIVE_ENTRY_ACL_READ_NAMED_ATTRS: Int32 = 0x00000040
public let ARCHIVE_ENTRY_ACL_WRITE_NAMED_ATTRS: Int32 = 0x00000080
public let ARCHIVE_ENTRY_ACL_DELETE_CHILD: Int32 = 0x00000100
public let ARCHIVE_ENTRY_ACL_READ_ATTRIBUTES: Int32 = 0x00000200
public let ARCHIVE_ENTRY_ACL_WRITE_ATTRIBUTES: Int32 = 0x00000400
public let ARCHIVE_ENTRY_ACL_DELETE: Int32 = 0x00000800
public let ARCHIVE_ENTRY_ACL_READ_ACL: Int32 = 0x00001000
public let ARCHIVE_ENTRY_ACL_WRITE_ACL: Int32 = 0x00002000
public let ARCHIVE_ENTRY_ACL_WRITE_OWNER: Int32 = 0x00004000
public let ARCHIVE_ENTRY_ACL_SYNCHRONIZE: Int32 = 0x00008000
public let ARCHIVE_ENTRY_ACL_PERMS_POSIX1E: Int32 = 0x00000007
public let ARCHIVE_ENTRY_ACL_PERMS_NFS4: Int32 = 0x0000FFFF
public let ARCHIVE_ENTRY_ACL_ENTRY_INHERITED: Int32 = 0x01000000
public let ARCHIVE_ENTRY_ACL_ENTRY_FILE_INHERIT: Int32 = 0x02000000
public let ARCHIVE_ENTRY_ACL_ENTRY_DIRECTORY_INHERIT: Int32 = 0x04000000
public let ARCHIVE_ENTRY_ACL_ENTRY_NO_PROPAGATE_INHERIT: Int32 = 0x08000000
public let ARCHIVE_ENTRY_ACL_ENTRY_INHERIT_ONLY: Int32 = 0x10000000
public let ARCHIVE_ENTRY_ACL_ENTRY_SUCCESSFUL_ACCESS: Int32 = 0x20000000
public let ARCHIVE_ENTRY_ACL_ENTRY_FAILED_ACCESS: Int32 = 0x40000000
public let ARCHIVE_ENTRY_ACL_INHERITANCE_NFS4: Int32 = 0x7F000000
public let ARCHIVE_ENTRY_ACL_TYPE_ACCESS: Int32 = 0x00000100
public let ARCHIVE_ENTRY_ACL_TYPE_DEFAULT: Int32 = 0x00000200
public let ARCHIVE_ENTRY_ACL_TYPE_ALLOW: Int32 = 0x00000400
public let ARCHIVE_ENTRY_ACL_TYPE_DENY: Int32 = 0x00000800
public let ARCHIVE_ENTRY_ACL_TYPE_AUDIT: Int32 = 0x00001000
public let ARCHIVE_ENTRY_ACL_TYPE_ALARM: Int32 = 0x00002000
public let ARCHIVE_ENTRY_ACL_TYPE_POSIX1E: Int32 = 0x00000300
public let ARCHIVE_ENTRY_ACL_TYPE_NFS4: Int32 = 0x00003C00
public let ARCHIVE_ENTRY_ACL_USER: Int32 = 10001
public let ARCHIVE_ENTRY_ACL_USER_OBJ: Int32 = 10002
public let ARCHIVE_ENTRY_ACL_GROUP: Int32 = 10003
public let ARCHIVE_ENTRY_ACL_GROUP_OBJ: Int32 = 10004
public let ARCHIVE_ENTRY_ACL_MASK: Int32 = 10005
public let ARCHIVE_ENTRY_ACL_OTHER: Int32 = 10006
public let ARCHIVE_ENTRY_ACL_EVERYONE: Int32 = 10107
public let ARCHIVE_ENTRY_ACL_STYLE_EXTRA_ID: Int32 = 0x00000001
public let ARCHIVE_ENTRY_ACL_STYLE_MARK_DEFAULT: Int32 = 0x00000002
public let ARCHIVE_ENTRY_ACL_STYLE_SOLARIS: Int32 = 0x00000004
public let ARCHIVE_ENTRY_ACL_STYLE_SEPARATOR_COMMA: Int32 = 0x00000008
public let ARCHIVE_ENTRY_ACL_STYLE_COMPACT: Int32 = 0x00000010
public let OLD_ARCHIVE_ENTRY_ACL_STYLE_EXTRA_ID: Int32 = 1024
public let OLD_ARCHIVE_ENTRY_ACL_STYLE_MARK_DEFAULT: Int32 = 2048

// ============================================================================
// Flags enums (nested from Zig)
// ============================================================================

public enum FlagsExtract {
    | owner
    | perm
    | time
    | no_overwrite
    | unlink
    | acl
    | fflags
    | xattr
    | secure_symlinks
    | secure_nodotdot
    | no_autodir
    | no_overwrite_newer
    | sparse
    | mac_metadata
    | no_hfs_compression
    | hfs_compression_forced
    | secure_noabsolutepaths
    | clear_nochange_fflags
    | safe_writes
}

public enum FlagsFormat {
    | base_mask
    | cpio
    | cpio_posix
    | cpio_bin_le
    | cpio_bin_be
    | cpio_svr4_nocrc
    | cpio_svr4_crc
    | cpio_afio_large
    | cpio_pwb
    | shar
    | shar_base
    | shar_dump
    | tar
    | tar_ustar
    | tar_pax_interchange
    | tar_pax_restricted
    | tar_gnutar
    | iso9660
    | iso9660_rockridge
    | zip
    | empty
    | ar
    | ar_gnu
    | ar_bsd
    | mtree
    | raw
    | xar
    | lha
    | cab
    | rar
    | sevenzip
    | warc
    | rar_v5
}

public enum FlagsFilter {
    | none
    | gzip
    | bzip2
    | compress
    | program
    | lzma
    | xz
    | uu
    | rpm
    | lzip
    | lrzip
    | lzop
    | grzip
    | lz4
    | zstd
}

public enum FlagsEntryDigest {
    | md5
    | rmd160
    | sha1
    | sha256
    | sha384
    | sha512
}

// ============================================================================
// Callback function types
// ============================================================================

public type ArchiveReadCallback = CFunc<(CPointer<StructArchive>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> LaSsizeT>
public type ArchiveSkipCallback = CFunc<(CPointer<StructArchive>, CPointer<Unit>, LaInt64T) -> LaInt64T>
public type ArchiveSeekCallback = CFunc<(CPointer<StructArchive>, CPointer<Unit>, LaInt64T, Int32) -> LaInt64T>
public type ArchiveWriteCallback = CFunc<(CPointer<StructArchive>, CPointer<Unit>, CPointer<Unit>, UInt64) -> LaSsizeT>
public type ArchiveOpenCallback = CFunc<(CPointer<StructArchive>, CPointer<Unit>) -> Int32>
public type ArchiveCloseCallback = CFunc<(CPointer<StructArchive>, CPointer<Unit>) -> Int32>
public type ArchiveFreeCallback = CFunc<(CPointer<StructArchive>, CPointer<Unit>) -> Int32>
public type ArchiveSwitchCallback = CFunc<(CPointer<StructArchive>, CPointer<Unit>, CPointer<Unit>) -> Int32>
public type ArchivePassphraseCallback = CFunc<(CPointer<StructArchive>, CPointer<Unit>) -> CPointer<UInt8>>

// ============================================================================
// Block struct (from Archive.next)
// ============================================================================

public class ArchiveBlock {
    public var bytes: Array<UInt8> = Array<UInt8>()
    public var offset: Int64 = 0
    public var result: ArchiveResult = ArchiveResult.ok

    public init() {}
    public init(bytes: Array<UInt8>, offset: Int64, result: ArchiveResult) {
        this.bytes = bytes
        this.offset = offset
        this.result = result
    }
}

// ============================================================================
// Type aliases matching Zig source
// ============================================================================

public type Archive = StructArchive
public type Entry = StructArchiveEntry
public type ArchiveAcl = StructArchiveAcl
public type ArchiveEntryLinkresolver = StructArchiveEntryLinkresolver
