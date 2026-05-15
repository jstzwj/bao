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

public opaque type StructArchive {}
public opaque type StructArchiveEntry {}
public opaque type StructStat {}
public opaque type StructArchiveAcl {}
public opaque type StructArchiveEntryLinkresolver {}

// ============================================================================
// FileType enum
// ============================================================================

public enum FileType {
    regular = 0o100000
    link = 0o120000
    socket = 0o140000
    character_oriented_device = 0o020000
    block_oriented_device = 0o060000
    directory = 0o040000
    fifo = 0o010000
}

// ============================================================================
// SymlinkType enum
// ============================================================================

public enum SymlinkType {
    none = 0
    file = 1
    directory = 2
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
    eof = 1      // ARCHIVE_EOF
    ok = 0       // ARCHIVE_OK
    retry = -10  // ARCHIVE_RETRY
    warn = -20   // ARCHIVE_WARN
    failed = -25 // ARCHIVE_FAILED
    fatal = -30  // ARCHIVE_FATAL
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
    owner = 0x0001                       // ARCHIVE_EXTRACT_OWNER
    perm = 0x0002                        // ARCHIVE_EXTRACT_PERM
    time = 0x0004                        // ARCHIVE_EXTRACT_TIME
    no_overwrite = 0x0008               // ARCHIVE_EXTRACT_NO_OVERWRITE
    unlink = 0x0010                     // ARCHIVE_EXTRACT_UNLINK
    acl = 0x0020                        // ARCHIVE_EXTRACT_ACL
    fflags = 0x0040                     // ARCHIVE_EXTRACT_FFLAGS
    xattr = 0x0080                      // ARCHIVE_EXTRACT_XATTR
    secure_symlinks = 0x0100            // ARCHIVE_EXTRACT_SECURE_SYMLINKS
    secure_nodotdot = 0x0200            // ARCHIVE_EXTRACT_SECURE_NODOTDOT
    no_autodir = 0x0400                 // ARCHIVE_EXTRACT_NO_AUTODIR
    no_overwrite_newer = 0x0800         // ARCHIVE_EXTRACT_NO_OVERWRITE_NEWER
    sparse = 0x1000                     // ARCHIVE_EXTRACT_SPARSE
    mac_metadata = 0x2000               // ARCHIVE_EXTRACT_MAC_METADATA
    no_hfs_compression = 0x4000         // ARCHIVE_EXTRACT_NO_HFS_COMPRESSION
    hfs_compression_forced = 0x8000     // ARCHIVE_EXTRACT_HFS_COMPRESSION_FORCED
    secure_noabsolutepaths = 0x00010000 // ARCHIVE_EXTRACT_SECURE_NOABSOLUTEPATHS
    clear_nochange_fflags = 0x00020000  // ARCHIVE_EXTRACT_CLEAR_NOCHANGE_FFLAGS
    safe_writes = 0x00040000            // ARCHIVE_EXTRACT_SAFE_WRITES
}

public enum FlagsFormat {
    base_mask = 0x00ff0000               // ARCHIVE_FORMAT_BASE_MASK
    cpio = 0x00010000                    // ARCHIVE_FORMAT_CPIO
    cpio_posix = 0x00010001              // ARCHIVE_FORMAT_CPIO_POSIX
    cpio_bin_le = 0x00010002             // ARCHIVE_FORMAT_CPIO_BIN_LE
    cpio_bin_be = 0x00010003             // ARCHIVE_FORMAT_CPIO_BIN_BE
    cpio_svr4_nocrc = 0x00010004        // ARCHIVE_FORMAT_CPIO_SVR4_NOCRC
    cpio_svr4_crc = 0x00010005          // ARCHIVE_FORMAT_CPIO_SVR4_CRC
    cpio_afio_large = 0x00010006        // ARCHIVE_FORMAT_CPIO_AFIO_LARGE
    cpio_pwb = 0x00010007               // ARCHIVE_FORMAT_CPIO_PWB
    shar = 0x00020000                    // ARCHIVE_FORMAT_SHAR
    shar_base = 0x00020001               // ARCHIVE_FORMAT_SHAR_BASE
    shar_dump = 0x00020002               // ARCHIVE_FORMAT_SHAR_DUMP
    tar = 0x00030000                     // ARCHIVE_FORMAT_TAR
    tar_ustar = 0x00030001               // ARCHIVE_FORMAT_TAR_USTAR
    tar_pax_interchange = 0x00030002    // ARCHIVE_FORMAT_TAR_PAX_INTERCHANGE
    tar_pax_restricted = 0x00030003     // ARCHIVE_FORMAT_TAR_PAX_RESTRICTED
    tar_gnutar = 0x00030004              // ARCHIVE_FORMAT_TAR_GNUTAR
    iso9660 = 0x00040000                 // ARCHIVE_FORMAT_ISO9660
    iso9660_rockridge = 0x00040001      // ARCHIVE_FORMAT_ISO9660_ROCKRIDGE
    zip = 0x00050000                     // ARCHIVE_FORMAT_ZIP
    empty = 0x00060000                   // ARCHIVE_FORMAT_EMPTY
    ar = 0x00070000                      // ARCHIVE_FORMAT_AR
    ar_gnu = 0x00070001                  // ARCHIVE_FORMAT_AR_GNU
    ar_bsd = 0x00070002                  // ARCHIVE_FORMAT_AR_BSD
    mtree = 0x00080000                   // ARCHIVE_FORMAT_MTREE
    raw = 0x00090000                     // ARCHIVE_FORMAT_RAW
    xar = 0x000A0000                     // ARCHIVE_FORMAT_XAR
    lha = 0x000B0000                     // ARCHIVE_FORMAT_LHA
    cab = 0x000C0000                     // ARCHIVE_FORMAT_CAB
    rar = 0x000D0000                     // ARCHIVE_FORMAT_RAR
    sevenzip = 0x000E0000                // ARCHIVE_FORMAT_7ZIP
    warc = 0x000F0000                    // ARCHIVE_FORMAT_WARC
    rar_v5 = 0x00100000                  // ARCHIVE_FORMAT_RAR_V5
}

public enum FlagsFilter {
    none = 0        // ARCHIVE_FILTER_NONE
    gzip = 1        // ARCHIVE_FILTER_GZIP
    bzip2 = 2       // ARCHIVE_FILTER_BZIP2
    compress = 3    // ARCHIVE_FILTER_COMPRESS
    program = 4     // ARCHIVE_FILTER_PROGRAM
    lzma = 5        // ARCHIVE_FILTER_LZMA
    xz = 6          // ARCHIVE_FILTER_XZ
    uu = 7          // ARCHIVE_FILTER_UU
    rpm = 8         // ARCHIVE_FILTER_RPM
    lzip = 9        // ARCHIVE_FILTER_LZIP
    lrzip = 10      // ARCHIVE_FILTER_LRZIP
    lzop = 11       // ARCHIVE_FILTER_LZOP
    grzip = 12      // ARCHIVE_FILTER_GRZIP
    lz4 = 13        // ARCHIVE_FILTER_LZ4
    zstd = 14       // ARCHIVE_FILTER_ZSTD
}

public enum FlagsEntryDigest {
    md5 = 0x00000001      // ARCHIVE_ENTRY_DIGEST_MD5
    rmd160 = 0x00000002   // ARCHIVE_ENTRY_DIGEST_RMD160
    sha1 = 0x00000003     // ARCHIVE_ENTRY_DIGEST_SHA1
    sha256 = 0x00000004   // ARCHIVE_ENTRY_DIGEST_SHA256
    sha384 = 0x00000005   // ARCHIVE_ENTRY_DIGEST_SHA384
    sha512 = 0x00000006   // ARCHIVE_ENTRY_DIGEST_SHA512
}

// ============================================================================
// Callback function types
// ============================================================================

public type ArchiveReadCallback = CFunctionPointer<(CPointer<StructArchive>, CPointer<None>, CPointer<CPointer<None>>) -> LaSsizeT>
public type ArchiveSkipCallback = CFunctionPointer<(CPointer<StructArchive>, CPointer<None>, LaInt64T) -> LaInt64T>
public type ArchiveSeekCallback = CFunctionPointer<(CPointer<StructArchive>, CPointer<None>, LaInt64T, Int32) -> LaInt64T>
public type ArchiveWriteCallback = CFunctionPointer<(CPointer<StructArchive>, CPointer<None>, CPointer<None>, UInt64) -> LaSsizeT>
public type ArchiveOpenCallback = CFunctionPointer<(CPointer<StructArchive>, CPointer<None>) -> Int32>
public type ArchiveCloseCallback = CFunctionPointer<(CPointer<StructArchive>, CPointer<None>) -> Int32>
public type ArchiveFreeCallback = CFunctionPointer<(CPointer<StructArchive>, CPointer<None>) -> Int32>
public type ArchiveSwitchCallback = CFunctionPointer<(CPointer<StructArchive>, CPointer<None>, CPointer<None>) -> Int32>
public type ArchivePassphraseCallback = CFunctionPointer<(CPointer<StructArchive>, CPointer<None>) -> CPointer<UInt8>>

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
