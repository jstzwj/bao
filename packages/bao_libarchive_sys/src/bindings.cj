// 严格翻译自: src/libarchive_sys/bindings.zig (FFI function declarations)

package bao_libarchive_sys

// ============================================================================
// Version functions
// ============================================================================

@Extern
public func archive_version_number(): Int32

@Extern
public func archive_version_string(): CPointer<UInt8>

@Extern
public func archive_version_details(): CPointer<UInt8>

@Extern
public func archive_zlib_version(): CPointer<UInt8>

@Extern
public func archive_liblzma_version(): CPointer<UInt8>

@Extern
public func archive_bzlib_version(): CPointer<UInt8>

@Extern
public func archive_liblz4_version(): CPointer<UInt8>

@Extern
public func archive_libzstd_version(): CPointer<UInt8>

// ============================================================================
// Error functions
// ============================================================================

@Extern
public func archive_error_string(archive: CPointer<StructArchive>): CPointer<UInt8>

@Extern
public func archive_errno(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_clear_error(archive: CPointer<StructArchive>): Unit

@Extern
public func archive_set_error(archive: CPointer<StructArchive>, err: Int32, fmt: CPointer<UInt8>): Unit

@Extern
public func archive_copy_error(dest: CPointer<StructArchive>, src: CPointer<StructArchive>): Unit

@Extern
public func archive_file_count(archive: CPointer<StructArchive>): Int32

// ============================================================================
// General archive functions
// ============================================================================

@Extern
public func archive_free(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_filter_count(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_filter_bytes(archive: CPointer<StructArchive>, arg1: Int32): LaInt64T

@Extern
public func archive_filter_code(archive: CPointer<StructArchive>, arg1: Int32): Int32

@Extern
public func archive_filter_name(archive: CPointer<StructArchive>, arg1: Int32): CPointer<UInt8>

@Extern
public func archive_position_compressed(archive: CPointer<StructArchive>): LaInt64T

@Extern
public func archive_position_uncompressed(archive: CPointer<StructArchive>): LaInt64T

@Extern
public func archive_compression_name(archive: CPointer<StructArchive>): CPointer<UInt8>

@Extern
public func archive_compression(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_format_name(archive: CPointer<StructArchive>): CPointer<UInt8>

@Extern
public func archive_format(archive: CPointer<StructArchive>): Int32

// ============================================================================
// Write archive functions
// ============================================================================

@Extern
public func archive_write_new(): CPointer<StructArchive>

@Extern
public func archive_write_close(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_finish(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_free(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_fail(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_options(archive: CPointer<StructArchive>, opts: CPointer<UInt8>): Int32

@Extern
public func archive_write_set_format_pax_restricted(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_format_gnutar(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_format_7zip(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_format_pax(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_format_ustar(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_format_zip(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_format_shar(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_format(archive: CPointer<StructArchive>, format_code: Int32): Int32

@Extern
public func archive_write_add_filter_gzip(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_add_filter(archive: CPointer<StructArchive>, filter_code: Int32): Int32

@Extern
public func archive_write_add_filter_by_name(archive: CPointer<StructArchive>, name: CPointer<UInt8>): Int32

@Extern
public func archive_write_add_filter_b64encode(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_add_filter_compress(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_add_filter_grzip(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_add_filter_lrzip(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_add_filter_lz4(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_add_filter_lzip(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_add_filter_lzma(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_add_filter_lzop(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_add_filter_none(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_add_filter_uuencode(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_add_filter_xz(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_add_filter_zstd(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_filter_option(archive: CPointer<StructArchive>, m: CPointer<UInt8>, o: CPointer<UInt8>, v: CPointer<UInt8>): Int32

@Extern
public func archive_write_open_filename(archive: CPointer<StructArchive>, filename: CPointer<UInt8>): Int32

@Extern
public func archive_write_open_fd(archive: CPointer<StructArchive>, fd: Int32): Int32

@Extern
public func archive_write_open_memory(archive: CPointer<StructArchive>, buffer: CPointer<None>, buffSize: UInt64, used: CPointer<UInt64>): Int32

@Extern
public func archive_write_header(archive: CPointer<StructArchive>, entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_write_data(archive: CPointer<StructArchive>, data: CPointer<None>, size: UInt64): Int64

@Extern
public func archive_write_finish_entry(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_bytes_per_block(archive: CPointer<StructArchive>, bytes_per_block: Int32): Int32

@Extern
public func archive_write_get_bytes_per_block(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_bytes_in_last_block(archive: CPointer<StructArchive>, bytes_in_last_block: Int32): Int32

@Extern
public func archive_write_get_bytes_in_last_block(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_skip_file(archive: CPointer<StructArchive>, arg1: LaInt64T, arg2: LaInt64T): Int32

@Extern
public func archive_write_set_format_by_name(archive: CPointer<StructArchive>, name: CPointer<UInt8>): Int32

@Extern
public func archive_write_set_format_ar_bsd(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_format_ar_svr4(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_format_cpio(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_format_cpio_bin(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_format_cpio_newc(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_format_cpio_odc(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_format_cpio_pwb(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_format_iso9660(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_format_mtree(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_format_mtree_classic(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_format_raw(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_format_shar_dump(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_format_v7tar(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_format_warc(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_format_xar(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_set_format_filter_by_ext(archive: CPointer<StructArchive>, filename: CPointer<UInt8>): Int32

@Extern
public func archive_write_set_format_filter_by_ext_def(archive: CPointer<StructArchive>, filename: CPointer<UInt8>, def_ext: CPointer<UInt8>): Int32

@Extern
public func archive_write_zip_set_compression_deflate(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_zip_set_compression_store(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_open(archive: CPointer<StructArchive>, client_data: CPointer<None>, open_cb: ArchiveOpenCallback, write_cb: ArchiveWriteCallback, close_cb: ArchiveCloseCallback): Int32

@Extern
public func archive_write_open2(archive: CPointer<StructArchive>, client_data: CPointer<None>, open_cb: ArchiveOpenCallback, write_cb: ArchiveWriteCallback, close_cb: ArchiveCloseCallback, free_cb: ArchiveFreeCallback): Int32

@Extern
public func archive_write_open_filename_w(archive: CPointer<StructArchive>, file: CPointer<WCharT>): Int32

@Extern
public func archive_write_open_file(archive: CPointer<StructArchive>, file: CPointer<UInt8>): Int32

@Extern
public func archive_write_data_block(archive: CPointer<StructArchive>, buff: CPointer<None>, size: UInt64, offset: LaInt64T): LaSsizeT

@Extern
public func archive_write_set_format_option(archive: CPointer<StructArchive>, m: CPointer<UInt8>, o: CPointer<UInt8>, v: CPointer<UInt8>): Int32

@Extern
public func archive_write_set_option(archive: CPointer<StructArchive>, m: CPointer<UInt8>, o: CPointer<UInt8>, v: CPointer<UInt8>): Int32

@Extern
public func archive_write_set_passphrase(archive: CPointer<StructArchive>, p: CPointer<UInt8>): Int32

@Extern
public func archive_write_set_passphrase_callback(archive: CPointer<StructArchive>, client_data: CPointer<None>, cb: ArchivePassphraseCallback): Unit

// ============================================================================
// Write disk functions
// ============================================================================

@Extern
public func archive_write_disk_new(): CPointer<StructArchive>

@Extern
public func archive_write_disk_set_skip_file(archive: CPointer<StructArchive>, arg1: LaInt64T, arg2: LaInt64T): Int32

@Extern
public func archive_write_disk_set_options(archive: CPointer<StructArchive>, flags: Int32): Int32

@Extern
public func archive_write_disk_set_standard_lookup(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_write_disk_set_group_lookup(archive: CPointer<StructArchive>, client_data: CPointer<None>, lookup_cb: CFunctionPointer<(CPointer<None>, CPointer<UInt8>, LaInt64T) -> LaInt64T>, cleanup_cb: CFunctionPointer<(CPointer<None>) -> Unit>): Int32

@Extern
public func archive_write_disk_set_user_lookup(archive: CPointer<StructArchive>, client_data: CPointer<None>, lookup_cb: CFunctionPointer<(CPointer<None>, CPointer<UInt8>, LaInt64T) -> LaInt64T>, cleanup_cb: CFunctionPointer<(CPointer<None>) -> Unit>): Int32

@Extern
public func archive_write_disk_gid(archive: CPointer<StructArchive>, name: CPointer<UInt8>, gid: LaInt64T): LaInt64T

@Extern
public func archive_write_disk_uid(archive: CPointer<StructArchive>, name: CPointer<UInt8>, uid: LaInt64T): LaInt64T

// ============================================================================
// Read archive functions
// ============================================================================

@Extern
public func archive_read_new(): CPointer<StructArchive>

@Extern
public func archive_read_close(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_free(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_finish(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_format_7zip(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_format_all(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_format_ar(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_format_by_code(archive: CPointer<StructArchive>, code: Int32): Int32

@Extern
public func archive_read_support_format_cab(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_format_cpio(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_format_empty(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_format_gnutar(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_format_iso9660(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_format_lha(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_format_mtree(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_format_rar(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_format_rar5(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_format_raw(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_format_tar(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_format_warc(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_format_xar(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_format_zip(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_format_zip_streamable(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_format_zip_seekable(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_set_options(archive: CPointer<StructArchive>, opts: CPointer<UInt8>): Int32

@Extern
public func archive_read_open_memory(archive: CPointer<StructArchive>, buf: CPointer<None>, size: UInt64): Int32

@Extern
public func archive_read_open_memory2(archive: CPointer<StructArchive>, buff: CPointer<None>, size: UInt64, read_size: UInt64): Int32

@Extern
public func archive_read_next_header(archive: CPointer<StructArchive>, entry: CPointer<CPointer<StructArchiveEntry>>): Int32

@Extern
public func archive_read_next_header2(archive: CPointer<StructArchive>, entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_read_data(archive: CPointer<StructArchive>, buff: CPointer<None>, size: UInt64): Int64

@Extern
public func archive_read_data_block(archive: CPointer<StructArchive>, buff: CPointer<CPointer<None>>, size: CPointer<UInt64>, offset: CPointer<LaInt64T>): Int32

@Extern
public func archive_read_data_skip(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_data_into_fd(archive: CPointer<StructArchive>, fd: Int32): Int32

@Extern
public func archive_seek_data(archive: CPointer<StructArchive>, offset: LaInt64T, whence: Int32): LaInt64T

@Extern
public func archive_read_header_position(archive: CPointer<StructArchive>): LaInt64T

@Extern
public func archive_read_has_encrypted_entries(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_format_capabilities(archive: CPointer<StructArchive>): Int32

// ============================================================================
// Read filter support functions
// ============================================================================

@Extern
public func archive_read_support_filter_all(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_filter_by_code(archive: CPointer<StructArchive>, code: Int32): Int32

@Extern
public func archive_read_support_filter_compress(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_filter_gzip(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_filter_grzip(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_filter_lrzip(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_filter_lz4(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_filter_lzip(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_filter_lzma(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_filter_lzop(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_filter_none(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_filter_rpm(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_filter_uu(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_filter_xz(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_support_filter_zstd(archive: CPointer<StructArchive>): Int32

// ============================================================================
// Read compression/program support
// ============================================================================

@Extern
public func archive_read_support_compression_program(archive: CPointer<StructArchive>, command: CPointer<UInt8>): Int32

@Extern
public func archive_read_support_compression_program_signature(archive: CPointer<StructArchive>, arg1: CPointer<UInt8>, arg2: CPointer<None>, arg3: UInt64): Int32

@Extern
public func archive_read_support_filter_program(archive: CPointer<StructArchive>, command: CPointer<UInt8>): Int32

@Extern
public func archive_read_support_filter_program_signature(archive: CPointer<StructArchive>, arg1: CPointer<UInt8>, arg2: CPointer<None>, arg3: UInt64): Int32

// ============================================================================
// Read format/filter setup
// ============================================================================

@Extern
public func archive_read_set_format(archive: CPointer<StructArchive>, format: Int32): Int32

@Extern
public func archive_read_append_filter(archive: CPointer<StructArchive>, filter: Int32): Int32

@Extern
public func archive_read_append_filter_program(archive: CPointer<StructArchive>, arg1: CPointer<UInt8>): Int32

@Extern
public func archive_read_append_filter_program_signature(archive: CPointer<StructArchive>, arg1: CPointer<UInt8>, arg2: CPointer<None>, arg3: UInt64): Int32

// ============================================================================
// Read callback setup
// ============================================================================

@Extern
public func archive_read_set_open_callback(archive: CPointer<StructArchive>, cb: ArchiveOpenCallback): Int32

@Extern
public func archive_read_set_read_callback(archive: CPointer<StructArchive>, cb: ArchiveReadCallback): Int32

@Extern
public func archive_read_set_seek_callback(archive: CPointer<StructArchive>, cb: ArchiveSeekCallback): Int32

@Extern
public func archive_read_set_skip_callback(archive: CPointer<StructArchive>, cb: ArchiveSkipCallback): Int32

@Extern
public func archive_read_set_close_callback(archive: CPointer<StructArchive>, cb: ArchiveCloseCallback): Int32

@Extern
public func archive_read_set_switch_callback(archive: CPointer<StructArchive>, cb: ArchiveSwitchCallback): Int32

@Extern
public func archive_read_set_callback_data(archive: CPointer<StructArchive>, client_data: CPointer<None>): Int32

@Extern
public func archive_read_set_callback_data2(archive: CPointer<StructArchive>, client_data: CPointer<None>, index: UInt32): Int32

@Extern
public func archive_read_add_callback_data(archive: CPointer<StructArchive>, client_data: CPointer<None>, index: UInt32): Int32

@Extern
public func archive_read_append_callback_data(archive: CPointer<StructArchive>, client_data: CPointer<None>): Int32

@Extern
public func archive_read_prepend_callback_data(archive: CPointer<StructArchive>, client_data: CPointer<None>): Int32

@Extern
public func archive_read_open1(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_open(archive: CPointer<StructArchive>, client_data: CPointer<None>, open_cb: ArchiveOpenCallback, read_cb: ArchiveReadCallback, close_cb: ArchiveCloseCallback): Int32

@Extern
public func archive_read_open2(archive: CPointer<StructArchive>, client_data: CPointer<None>, open_cb: ArchiveOpenCallback, read_cb: ArchiveReadCallback, skip_cb: ArchiveSkipCallback, close_cb: ArchiveCloseCallback): Int32

@Extern
public func archive_read_open_filename(archive: CPointer<StructArchive>, filename: CPointer<UInt8>, block_size: UInt64): Int32

@Extern
public func archive_read_open_filenames(archive: CPointer<StructArchive>, filenames: CPointer<CPointer<UInt8>>, block_size: UInt64): Int32

@Extern
public func archive_read_open_filename_w(archive: CPointer<StructArchive>, filename: CPointer<WCharT>, block_size: UInt64): Int32

@Extern
public func archive_read_open_file(archive: CPointer<StructArchive>, filename: CPointer<UInt8>, block_size: UInt64): Int32

@Extern
public func archive_read_open_fd(archive: CPointer<StructArchive>, fd: Int32, block_size: UInt64): Int32

// ============================================================================
// Read option / passphrase
// ============================================================================

@Extern
public func archive_read_set_format_option(archive: CPointer<StructArchive>, m: CPointer<UInt8>, o: CPointer<UInt8>, v: CPointer<UInt8>): Int32

@Extern
public func archive_read_set_filter_option(archive: CPointer<StructArchive>, m: CPointer<UInt8>, o: CPointer<UInt8>, v: CPointer<UInt8>): Int32

@Extern
public func archive_read_add_passphrase(archive: CPointer<StructArchive>, arg1: CPointer<UInt8>): Int32

@Extern
public func archive_read_set_passphrase_callback(archive: CPointer<StructArchive>, client_data: CPointer<None>, cb: ArchivePassphraseCallback): Int32

// ============================================================================
// Read extract
// ============================================================================

@Extern
public func archive_read_extract(archive: CPointer<StructArchive>, entry: CPointer<StructArchiveEntry>, flags: Int32): Int32

@Extern
public func archive_read_extract2(archive: CPointer<StructArchive>, entry: CPointer<StructArchiveEntry>, dest: CPointer<StructArchive>): Int32

@Extern
public func archive_read_extract_set_progress_callback(archive: CPointer<StructArchive>, progress_func: CFunctionPointer<(CPointer<None>) -> Unit>, user_data: CPointer<None>): Unit

@Extern
public func archive_read_extract_set_skip_file(archive: CPointer<StructArchive>, arg1: LaInt64T, arg2: LaInt64T): Unit

// ============================================================================
// Read disk functions
// ============================================================================

@Extern
public func archive_read_disk_new(): CPointer<StructArchive>

@Extern
public func archive_read_disk_set_symlink_logical(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_disk_set_symlink_physical(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_disk_set_symlink_hybrid(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_disk_entry_from_file(archive: CPointer<StructArchive>, entry: CPointer<StructArchiveEntry>, fd: Int32, st: CPointer<StructStat>): Int32

@Extern
public func archive_read_disk_gname(archive: CPointer<StructArchive>, gid: LaInt64T): CPointer<UInt8>

@Extern
public func archive_read_disk_uname(archive: CPointer<StructArchive>, uid: LaInt64T): CPointer<UInt8>

@Extern
public func archive_read_disk_set_standard_lookup(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_disk_set_gname_lookup(archive: CPointer<StructArchive>, client_data: CPointer<None>, lookup_cb: CFunctionPointer<(CPointer<None>, LaInt64T) -> CPointer<UInt8>>, cleanup_cb: CFunctionPointer<(CPointer<None>) -> Unit>): Int32

@Extern
public func archive_read_disk_set_uname_lookup(archive: CPointer<StructArchive>, client_data: CPointer<None>, lookup_cb: CFunctionPointer<(CPointer<None>, LaInt64T) -> CPointer<UInt8>>, cleanup_cb: CFunctionPointer<(CPointer<None>) -> Unit>): Int32

@Extern
public func archive_read_disk_open(archive: CPointer<StructArchive>, path: CPointer<UInt8>): Int32

@Extern
public func archive_read_disk_open_w(archive: CPointer<StructArchive>, path: CPointer<WCharT>): Int32

@Extern
public func archive_read_disk_descend(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_disk_can_descend(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_disk_current_filesystem(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_disk_current_filesystem_is_synthetic(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_disk_current_filesystem_is_remote(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_disk_set_atime_restored(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_read_disk_set_behavior(archive: CPointer<StructArchive>, flags: Int32): Int32

@Extern
public func archive_read_disk_set_matching(archive: CPointer<StructArchive>, matching: CPointer<StructArchive>, excluded_func: CFunctionPointer<(CPointer<StructArchive>, CPointer<None>, CPointer<StructArchiveEntry>) -> Unit>, client_data: CPointer<None>): Int32

@Extern
public func archive_read_disk_set_metadata_filter_callback(archive: CPointer<StructArchive>, metadata_filter_func: CFunctionPointer<(CPointer<StructArchive>, CPointer<None>, CPointer<StructArchiveEntry>) -> Int32>, client_data: CPointer<None>): Int32

// ============================================================================
// Match functions
// ============================================================================

@Extern
public func archive_match_new(): CPointer<StructArchive>

@Extern
public func archive_match_free(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_match_excluded(archive: CPointer<StructArchive>, entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_match_path_excluded(archive: CPointer<StructArchive>, entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_match_set_inclusion_recursion(archive: CPointer<StructArchive>, arg1: Int32): Int32

@Extern
public func archive_match_exclude_pattern(archive: CPointer<StructArchive>, arg1: CPointer<UInt8>): Int32

@Extern
public func archive_match_exclude_pattern_w(archive: CPointer<StructArchive>, arg1: CPointer<WCharT>): Int32

@Extern
public func archive_match_exclude_pattern_from_file(archive: CPointer<StructArchive>, arg1: CPointer<UInt8>, nullSeparator: Int32): Int32

@Extern
public func archive_match_exclude_pattern_from_file_w(archive: CPointer<StructArchive>, arg1: CPointer<WCharT>, nullSeparator: Int32): Int32

@Extern
public func archive_match_include_pattern(archive: CPointer<StructArchive>, arg1: CPointer<UInt8>): Int32

@Extern
public func archive_match_include_pattern_w(archive: CPointer<StructArchive>, arg1: CPointer<WCharT>): Int32

@Extern
public func archive_match_include_pattern_from_file(archive: CPointer<StructArchive>, arg1: CPointer<UInt8>, nullSeparator: Int32): Int32

@Extern
public func archive_match_include_pattern_from_file_w(archive: CPointer<StructArchive>, arg1: CPointer<WCharT>, nullSeparator: Int32): Int32

@Extern
public func archive_match_path_unmatched_inclusions(archive: CPointer<StructArchive>): Int32

@Extern
public func archive_match_path_unmatched_inclusions_next(archive: CPointer<StructArchive>, arg1: CPointer<CPointer<UInt8>>): Int32

@Extern
public func archive_match_path_unmatched_inclusions_next_w(archive: CPointer<StructArchive>, arg1: CPointer<CPointer<WCharT>>): Int32

@Extern
public func archive_match_time_excluded(archive: CPointer<StructArchive>, entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_match_include_time(archive: CPointer<StructArchive>, flag: Int32, sec: TimeT, nsec: Int64): Int32

@Extern
public func archive_match_include_date(archive: CPointer<StructArchive>, flag: Int32, datestr: CPointer<UInt8>): Int32

@Extern
public func archive_match_include_date_w(archive: CPointer<StructArchive>, flag: Int32, datestr: CPointer<WCharT>): Int32

@Extern
public func archive_match_include_file_time(archive: CPointer<StructArchive>, flag: Int32, pathname: CPointer<UInt8>): Int32

@Extern
public func archive_match_include_file_time_w(archive: CPointer<StructArchive>, flag: Int32, pathname: CPointer<WCharT>): Int32

@Extern
public func archive_match_exclude_entry(archive: CPointer<StructArchive>, flag: Int32, entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_match_owner_excluded(archive: CPointer<StructArchive>, entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_match_include_uid(archive: CPointer<StructArchive>, uid: LaInt64T): Int32

@Extern
public func archive_match_include_gid(archive: CPointer<StructArchive>, gid: LaInt64T): Int32

@Extern
public func archive_match_include_uname(archive: CPointer<StructArchive>, uname: CPointer<UInt8>): Int32

@Extern
public func archive_match_include_uname_w(archive: CPointer<StructArchive>, uname: CPointer<WCharT>): Int32

@Extern
public func archive_match_include_gname(archive: CPointer<StructArchive>, gname: CPointer<UInt8>): Int32

@Extern
public func archive_match_include_gname_w(archive: CPointer<StructArchive>, gname: CPointer<WCharT>): Int32

@Extern
public func archive_utility_string_sort(strings: CPointer<CPointer<UInt8>>): Int32

// ============================================================================
// Entry functions
// ============================================================================

@Extern
public func archive_entry_new(): CPointer<StructArchiveEntry>

@Extern
public func archive_entry_new2(archive: CPointer<StructArchive>): CPointer<StructArchiveEntry>

@Extern
public func archive_entry_free(entry: CPointer<StructArchiveEntry>): Unit

@Extern
public func archive_entry_clone(entry: CPointer<StructArchiveEntry>): CPointer<StructArchiveEntry>

@Extern
public func archive_entry_clear(entry: CPointer<StructArchiveEntry>): CPointer<StructArchiveEntry>

// Entry path setters
@Extern
public func archive_entry_set_pathname(entry: CPointer<StructArchiveEntry>, name: CPointer<UInt8>): Unit

@Extern
public func archive_entry_set_pathname_utf8(entry: CPointer<StructArchiveEntry>, name: CPointer<UInt8>): Unit

@Extern
public func archive_entry_copy_pathname(entry: CPointer<StructArchiveEntry>, name: CPointer<UInt8>): Unit

@Extern
public func archive_entry_copy_pathname_w(entry: CPointer<StructArchiveEntry>, name: CPointer<WCharT>): Unit

@Extern
public func archive_entry_update_pathname_utf8(entry: CPointer<StructArchiveEntry>, name: CPointer<UInt8>): Int32

// Entry path getters
@Extern
public func archive_entry_pathname(entry: CPointer<StructArchiveEntry>): CPointer<UInt8>

@Extern
public func archive_entry_pathname_utf8(entry: CPointer<StructArchiveEntry>): CPointer<UInt8>

@Extern
public func archive_entry_pathname_w(entry: CPointer<StructArchiveEntry>): CPointer<WCharT>

// Entry metadata setters
@Extern
public func archive_entry_set_size(entry: CPointer<StructArchiveEntry>, size: Int64): Unit

@Extern
public func archive_entry_set_filetype(entry: CPointer<StructArchiveEntry>, typ: UInt32): Unit

@Extern
public func archive_entry_set_perm(entry: CPointer<StructArchiveEntry>, perm: ModeT): Unit

@Extern
public func archive_entry_set_mode(entry: CPointer<StructArchiveEntry>, mode: ModeT): Unit

@Extern
public func archive_entry_set_mtime(entry: CPointer<StructArchiveEntry>, secs: Int64, nsecs: Int64): Unit

@Extern
public func archive_entry_unset_mtime(entry: CPointer<StructArchiveEntry>): Unit

// Entry metadata getters
@Extern
public func archive_entry_filetype(entry: CPointer<StructArchiveEntry>): ModeT

@Extern
public func archive_entry_perm(entry: CPointer<StructArchiveEntry>): ModeT

@Extern
public func archive_entry_size(entry: CPointer<StructArchiveEntry>): Int64

@Extern
public func archive_entry_size_is_set(entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_entry_mtime(entry: CPointer<StructArchiveEntry>): TimeT

@Extern
public func archive_entry_mtime_nsec(entry: CPointer<StructArchiveEntry>): Int64

@Extern
public func archive_entry_mtime_is_set(entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_entry_mode(entry: CPointer<StructArchiveEntry>): ModeT

@Extern
public func archive_entry_strmode(entry: CPointer<StructArchiveEntry>): CPointer<UInt8>

// Entry symlink
@Extern
public func archive_entry_symlink(entry: CPointer<StructArchiveEntry>): CPointer<UInt8>

@Extern
public func archive_entry_symlink_utf8(entry: CPointer<StructArchiveEntry>): CPointer<UInt8>

@Extern
public func archive_entry_symlink_type(entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_entry_symlink_w(entry: CPointer<StructArchiveEntry>): CPointer<WCharT>

@Extern
public func archive_entry_set_symlink(entry: CPointer<StructArchiveEntry>, arg1: CPointer<UInt8>): Unit

@Extern
public func archive_entry_set_symlink_type(entry: CPointer<StructArchiveEntry>, arg1: Int32): Unit

@Extern
public func archive_entry_set_symlink_utf8(entry: CPointer<StructArchiveEntry>, arg1: CPointer<UInt8>): Unit

@Extern
public func archive_entry_copy_symlink(entry: CPointer<StructArchiveEntry>, arg1: CPointer<UInt8>): Unit

@Extern
public func archive_entry_copy_symlink_w(entry: CPointer<StructArchiveEntry>, arg1: CPointer<WCharT>): Unit

@Extern
public func archive_entry_update_symlink_utf8(entry: CPointer<StructArchiveEntry>, arg1: CPointer<UInt8>): Int32

// Entry time getters/setters
@Extern
public func archive_entry_atime(entry: CPointer<StructArchiveEntry>): TimeT

@Extern
public func archive_entry_atime_nsec(entry: CPointer<StructArchiveEntry>): Int64

@Extern
public func archive_entry_atime_is_set(entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_entry_set_atime(entry: CPointer<StructArchiveEntry>, arg1: TimeT, arg2: Int64): Unit

@Extern
public func archive_entry_unset_atime(entry: CPointer<StructArchiveEntry>): Unit

@Extern
public func archive_entry_birthtime(entry: CPointer<StructArchiveEntry>): TimeT

@Extern
public func archive_entry_birthtime_nsec(entry: CPointer<StructArchiveEntry>): Int64

@Extern
public func archive_entry_birthtime_is_set(entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_entry_set_birthtime(entry: CPointer<StructArchiveEntry>, arg1: TimeT, arg2: Int64): Unit

@Extern
public func archive_entry_unset_birthtime(entry: CPointer<StructArchiveEntry>): Unit

@Extern
public func archive_entry_ctime(entry: CPointer<StructArchiveEntry>): TimeT

@Extern
public func archive_entry_ctime_nsec(entry: CPointer<StructArchiveEntry>): Int64

@Extern
public func archive_entry_ctime_is_set(entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_entry_set_ctime(entry: CPointer<StructArchiveEntry>, arg1: TimeT, arg2: Int64): Unit

@Extern
public func archive_entry_unset_ctime(entry: CPointer<StructArchiveEntry>): Unit

// Entry device ids
@Extern
public func archive_entry_dev(entry: CPointer<StructArchiveEntry>): DevT

@Extern
public func archive_entry_dev_is_set(entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_entry_devmajor(entry: CPointer<StructArchiveEntry>): DevT

@Extern
public func archive_entry_devminor(entry: CPointer<StructArchiveEntry>): DevT

@Extern
public func archive_entry_set_dev(entry: CPointer<StructArchiveEntry>, arg1: DevT): Unit

@Extern
public func archive_entry_set_devmajor(entry: CPointer<StructArchiveEntry>, arg1: DevT): Unit

@Extern
public func archive_entry_set_devminor(entry: CPointer<StructArchiveEntry>, arg1: DevT): Unit

// Entry fflags
@Extern
public func archive_entry_fflags(entry: CPointer<StructArchiveEntry>, set: CPointer<UInt64>, clear: CPointer<UInt64>): Unit

@Extern
public func archive_entry_fflags_text(entry: CPointer<StructArchiveEntry>): CPointer<UInt8>

@Extern
public func archive_entry_set_fflags(entry: CPointer<StructArchiveEntry>, set: UInt64, clear: UInt64): Unit

@Extern
public func archive_entry_copy_fflags_text(entry: CPointer<StructArchiveEntry>, arg1: CPointer<UInt8>): CPointer<UInt8>

@Extern
public func archive_entry_copy_fflags_text_w(entry: CPointer<StructArchiveEntry>, arg1: CPointer<WCharT>): CPointer<WCharT>

// Entry owner
@Extern
public func archive_entry_gid(entry: CPointer<StructArchiveEntry>): LaInt64T

@Extern
public func archive_entry_gname(entry: CPointer<StructArchiveEntry>): CPointer<UInt8>

@Extern
public func archive_entry_gname_utf8(entry: CPointer<StructArchiveEntry>): CPointer<UInt8>

@Extern
public func archive_entry_gname_w(entry: CPointer<StructArchiveEntry>): CPointer<WCharT>

@Extern
public func archive_entry_set_gid(entry: CPointer<StructArchiveEntry>, arg1: LaInt64T): Unit

@Extern
public func archive_entry_set_gname(entry: CPointer<StructArchiveEntry>, arg1: CPointer<UInt8>): Unit

@Extern
public func archive_entry_set_gname_utf8(entry: CPointer<StructArchiveEntry>, arg1: CPointer<UInt8>): Unit

@Extern
public func archive_entry_copy_gname(entry: CPointer<StructArchiveEntry>, arg1: CPointer<UInt8>): Unit

@Extern
public func archive_entry_copy_gname_w(entry: CPointer<StructArchiveEntry>, arg1: CPointer<WCharT>): Unit

@Extern
public func archive_entry_update_gname_utf8(entry: CPointer<StructArchiveEntry>, arg1: CPointer<UInt8>): Int32

@Extern
public func archive_entry_uid(entry: CPointer<StructArchiveEntry>): LaInt64T

@Extern
public func archive_entry_uname(entry: CPointer<StructArchiveEntry>): CPointer<UInt8>

@Extern
public func archive_entry_uname_utf8(entry: CPointer<StructArchiveEntry>): CPointer<UInt8>

@Extern
public func archive_entry_uname_w(entry: CPointer<StructArchiveEntry>): CPointer<WCharT>

@Extern
public func archive_entry_set_uid(entry: CPointer<StructArchiveEntry>, arg1: LaInt64T): Unit

@Extern
public func archive_entry_set_uname(entry: CPointer<StructArchiveEntry>, arg1: CPointer<UInt8>): Unit

@Extern
public func archive_entry_set_uname_utf8(entry: CPointer<StructArchiveEntry>, arg1: CPointer<UInt8>): Unit

@Extern
public func archive_entry_copy_uname(entry: CPointer<StructArchiveEntry>, arg1: CPointer<UInt8>): Unit

@Extern
public func archive_entry_copy_uname_w(entry: CPointer<StructArchiveEntry>, arg1: CPointer<WCharT>): Unit

@Extern
public func archive_entry_update_uname_utf8(entry: CPointer<StructArchiveEntry>, arg1: CPointer<UInt8>): Int32

// Entry hardlink
@Extern
public func archive_entry_hardlink(entry: CPointer<StructArchiveEntry>): CPointer<UInt8>

@Extern
public func archive_entry_hardlink_utf8(entry: CPointer<StructArchiveEntry>): CPointer<UInt8>

@Extern
public func archive_entry_hardlink_w(entry: CPointer<StructArchiveEntry>): CPointer<WCharT>

@Extern
public func archive_entry_set_hardlink(entry: CPointer<StructArchiveEntry>, arg1: CPointer<UInt8>): Unit

@Extern
public func archive_entry_set_hardlink_utf8(entry: CPointer<StructArchiveEntry>, arg1: CPointer<UInt8>): Unit

@Extern
public func archive_entry_copy_hardlink(entry: CPointer<StructArchiveEntry>, arg1: CPointer<UInt8>): Unit

@Extern
public func archive_entry_copy_hardlink_w(entry: CPointer<StructArchiveEntry>, arg1: CPointer<WCharT>): Unit

@Extern
public func archive_entry_update_hardlink_utf8(entry: CPointer<StructArchiveEntry>, arg1: CPointer<UInt8>): Int32

// Entry inode
@Extern
public func archive_entry_ino(entry: CPointer<StructArchiveEntry>): LaInt64T

@Extern
public func archive_entry_ino64(entry: CPointer<StructArchiveEntry>): LaInt64T

@Extern
public func archive_entry_ino_is_set(entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_entry_set_ino(entry: CPointer<StructArchiveEntry>, arg1: LaInt64T): Unit

@Extern
public func archive_entry_set_ino64(entry: CPointer<StructArchiveEntry>, arg1: LaInt64T): Unit

// Entry nlink
@Extern
public func archive_entry_nlink(entry: CPointer<StructArchiveEntry>): UInt32

@Extern
public func archive_entry_set_nlink(entry: CPointer<StructArchiveEntry>, arg1: UInt32): Unit

// Entry rdev
@Extern
public func archive_entry_rdev(entry: CPointer<StructArchiveEntry>): DevT

@Extern
public func archive_entry_rdevmajor(entry: CPointer<StructArchiveEntry>): DevT

@Extern
public func archive_entry_rdevminor(entry: CPointer<StructArchiveEntry>): DevT

@Extern
public func archive_entry_set_rdev(entry: CPointer<StructArchiveEntry>, arg1: DevT): Unit

@Extern
public func archive_entry_set_rdevmajor(entry: CPointer<StructArchiveEntry>, arg1: DevT): Unit

@Extern
public func archive_entry_set_rdevminor(entry: CPointer<StructArchiveEntry>, arg1: DevT): Unit

// Entry sourcepath
@Extern
public func archive_entry_sourcepath(entry: CPointer<StructArchiveEntry>): CPointer<UInt8>

@Extern
public func archive_entry_sourcepath_w(entry: CPointer<StructArchiveEntry>): CPointer<WCharT>

@Extern
public func archive_entry_copy_sourcepath(entry: CPointer<StructArchiveEntry>, arg1: CPointer<UInt8>): Unit

@Extern
public func archive_entry_copy_sourcepath_w(entry: CPointer<StructArchiveEntry>, arg1: CPointer<WCharT>): Unit

// Entry link
@Extern
public func archive_entry_set_link(entry: CPointer<StructArchiveEntry>, arg1: CPointer<UInt8>): Unit

@Extern
public func archive_entry_set_link_utf8(entry: CPointer<StructArchiveEntry>, arg1: CPointer<UInt8>): Unit

@Extern
public func archive_entry_copy_link(entry: CPointer<StructArchiveEntry>, arg1: CPointer<UInt8>): Unit

@Extern
public func archive_entry_copy_link_w(entry: CPointer<StructArchiveEntry>, arg1: CPointer<WCharT>): Unit

@Extern
public func archive_entry_update_link_utf8(entry: CPointer<StructArchiveEntry>, arg1: CPointer<UInt8>): Int32

// Entry unset
@Extern
public func archive_entry_unset_size(entry: CPointer<StructArchiveEntry>): Unit

// Entry encryption
@Extern
public func archive_entry_is_data_encrypted(entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_entry_is_metadata_encrypted(entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_entry_is_encrypted(entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_entry_set_is_data_encrypted(entry: CPointer<StructArchiveEntry>, is_encrypted: UInt8): Unit

@Extern
public func archive_entry_set_is_metadata_encrypted(entry: CPointer<StructArchiveEntry>, is_encrypted: UInt8): Unit

// Entry stat
@Extern
public func archive_entry_stat(entry: CPointer<StructArchiveEntry>): CPointer<StructStat>

@Extern
public func archive_entry_copy_stat(entry: CPointer<StructArchiveEntry>, st: CPointer<StructStat>): Unit

// Entry mac metadata
@Extern
public func archive_entry_mac_metadata(entry: CPointer<StructArchiveEntry>, size: CPointer<UInt64>): CPointer<None>

@Extern
public func archive_entry_copy_mac_metadata(entry: CPointer<StructArchiveEntry>, data: CPointer<None>, size: UInt64): Unit

// Entry digest
@Extern
public func archive_entry_digest(entry: CPointer<StructArchiveEntry>, digest_type: Int32): CPointer<UInt8>

// Entry ACL functions
@Extern
public func archive_entry_acl_clear(entry: CPointer<StructArchiveEntry>): Unit

@Extern
public func archive_entry_acl_add_entry(entry: CPointer<StructArchiveEntry>, type_: Int32, perm: Int32, tag: Int32, qualifier: Int32, name: CPointer<UInt8>): Int32

@Extern
public func archive_entry_acl_add_entry_w(entry: CPointer<StructArchiveEntry>, type_: Int32, perm: Int32, tag: Int32, qualifier: Int32, name: CPointer<WCharT>): Int32

@Extern
public func archive_entry_acl_reset(entry: CPointer<StructArchiveEntry>, type_: Int32): Int32

@Extern
public func archive_entry_acl_next(entry: CPointer<StructArchiveEntry>, type_: Int32, type_ret: CPointer<Int32>, perm_ret: CPointer<Int32>, tag_ret: CPointer<Int32>, qualifier_ret: CPointer<Int32>, name_ret: CPointer<CPointer<UInt8>>): Int32

@Extern
public func archive_entry_acl_to_text_w(entry: CPointer<StructArchiveEntry>, len: CPointer<LaSsizeT>, flags: Int32): CPointer<WCharT>

@Extern
public func archive_entry_acl_to_text(entry: CPointer<StructArchiveEntry>, len: CPointer<LaSsizeT>, flags: Int32): CPointer<UInt8>

@Extern
public func archive_entry_acl_from_text_w(entry: CPointer<StructArchiveEntry>, text: CPointer<WCharT>, flags: Int32): Int32

@Extern
public func archive_entry_acl_from_text(entry: CPointer<StructArchiveEntry>, text: CPointer<UInt8>, flags: Int32): Int32

@Extern
public func archive_entry_acl_text_w(entry: CPointer<StructArchiveEntry>, flags: Int32): CPointer<WCharT>

@Extern
public func archive_entry_acl_text(entry: CPointer<StructArchiveEntry>, flags: Int32): CPointer<UInt8>

@Extern
public func archive_entry_acl_types(entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_entry_acl_count(entry: CPointer<StructArchiveEntry>, flags: Int32): Int32

@Extern
public func archive_entry_acl(entry: CPointer<StructArchiveEntry>): CPointer<StructArchiveAcl>

// Entry xattr functions
@Extern
public func archive_entry_xattr_clear(entry: CPointer<StructArchiveEntry>): Unit

@Extern
public func archive_entry_xattr_add_entry(entry: CPointer<StructArchiveEntry>, name: CPointer<UInt8>, value: CPointer<None>, size: UInt64): Unit

@Extern
public func archive_entry_xattr_count(entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_entry_xattr_reset(entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_entry_xattr_next(entry: CPointer<StructArchiveEntry>, name: CPointer<CPointer<UInt8>>, value: CPointer<CPointer<None>>, size: CPointer<UInt64>): Int32

// Entry sparse functions
@Extern
public func archive_entry_sparse_clear(entry: CPointer<StructArchiveEntry>): Unit

@Extern
public func archive_entry_sparse_add_entry(entry: CPointer<StructArchiveEntry>, offset: LaInt64T, length: LaInt64T): Unit

@Extern
public func archive_entry_sparse_count(entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_entry_sparse_reset(entry: CPointer<StructArchiveEntry>): Int32

@Extern
public func archive_entry_sparse_next(entry: CPointer<StructArchiveEntry>, offset: CPointer<LaInt64T>, length: CPointer<LaInt64T>): Int32

// ============================================================================
// Entry link resolver functions
// ============================================================================

@Extern
public func archive_entry_linkresolver_new(): CPointer<StructArchiveEntryLinkresolver>

@Extern
public func archive_entry_linkresolver_set_strategy(resolver: CPointer<StructArchiveEntryLinkresolver>, format: Int32): Unit

@Extern
public func archive_entry_linkresolver_free(resolver: CPointer<StructArchiveEntryLinkresolver>): Unit

@Extern
public func archive_entry_linkify(resolver: CPointer<StructArchiveEntryLinkresolver>, entry1: CPointer<CPointer<StructArchiveEntry>>, entry2: CPointer<CPointer<StructArchiveEntry>>): Unit

@Extern
public func archive_entry_partial_links(resolver: CPointer<StructArchiveEntryLinkresolver>, links: CPointer<Int32>): CPointer<StructArchiveEntry>
