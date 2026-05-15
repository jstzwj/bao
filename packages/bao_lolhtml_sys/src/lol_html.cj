// 严格翻译自: src/lolhtml_sys/lol_html.zig
package bao_lolhtml_sys

// ============================================================================
// MemorySettings - 内存设置结构体
// 严格翻译自: lol_html.zig MemorySettings
// ============================================================================
@C
public struct MemorySettings {
    public var preallocated_parsing_buffer_size: UIntNative = 0
    public var max_allowed_memory_usage: UIntNative = 0
}

// ============================================================================
// SourceLocationBytes - 源码位置字节范围
// 严格翻译自: lol_html.zig SourceLocationBytes
// ============================================================================
@C
public struct SourceLocationBytes {
    public var start: UIntNative = 0
    public var end: UIntNative = 0
}

// ============================================================================
// HTMLString - HTML 字符串
// 严格翻译自: lol_html.zig HTMLString
// ============================================================================
@C
public struct HTMLString {
    public var ptr: CPointer<UInt8> = CPointer<UInt8>()
    public var len: UIntNative = 0
}

// ============================================================================
// Directive - 指令枚举
// 严格翻译自: lol_html.zig Directive
// ============================================================================
public enum Directive {
    | continue_
    | stop
}

// ============================================================================
// Encoding - 编码枚举
// 严格翻译自: lol_html.zig Encoding
// ============================================================================
public enum Encoding {
    | UTF8
    | UTF16
}

// ============================================================================
// 回调函数类型
// 严格翻译自: lol_html.zig 中的 handler 类型定义
// ============================================================================
public type CommentHandler = CFunc<(CPointer<Unit>, CPointer<Unit>) -> Directive>
public type TextHandler = CFunc<(CPointer<Unit>, CPointer<Unit>) -> Directive>
public type ElementHandler = CFunc<(CPointer<Unit>, CPointer<Unit>) -> Directive>
public type DocEndHandler = CFunc<(CPointer<Unit>, CPointer<Unit>) -> Directive>
public type EndTagHandler = CFunc<(CPointer<Unit>, CPointer<Unit>) -> Directive>
public type DocTypeHandler = CFunc<(CPointer<Unit>, CPointer<Unit>) -> Directive>
public type OutputSink = CFunc<(CPointer<UInt8>, UIntNative, CPointer<Unit>) -> Unit>

// ============================================================================
// lolhtml FFI 函数声明
// 严格翻译自: lol_html.zig 中所有 extern fn
// ============================================================================

// --- HTMLRewriter ---
foreign func lol_html_rewriter_write(rewriter: CPointer<Unit>, chunk: CPointer<UInt8>, chunk_len: UIntNative): Int32
foreign func lol_html_rewriter_end(rewriter: CPointer<Unit>): Int32
foreign func lol_html_rewriter_free(rewriter: CPointer<Unit>): Unit

// --- HTMLRewriter.Builder ---
foreign func lol_html_rewriter_builder_new(): CPointer<Unit>
foreign func lol_html_rewriter_builder_add_element_content_handlers(
    builder: CPointer<Unit>,
    selector: CPointer<Unit>,
    element_handler: CPointer<Unit>,
    element_handler_user_data: CPointer<Unit>,
    comment_handler: CPointer<Unit>,
    comment_handler_user_data: CPointer<Unit>,
    text_handler: CPointer<Unit>,
    text_handler_user_data: CPointer<Unit>
): Int32
foreign func lol_html_rewriter_builder_add_document_content_handlers(
    builder: CPointer<Unit>,
    doctype_handler: CPointer<Unit>,
    doctype_handler_user_data: CPointer<Unit>,
    comment_handler: CPointer<Unit>,
    comment_handler_user_data: CPointer<Unit>,
    text_handler: CPointer<Unit>,
    text_handler_user_data: CPointer<Unit>,
    doc_end_handler: CPointer<Unit>,
    doc_end_user_data: CPointer<Unit>
): Unit
foreign func lol_html_rewriter_builder_free(builder: CPointer<Unit>): Unit
foreign func lol_html_rewriter_build(
    builder: CPointer<Unit>,
    encoding: CPointer<UInt8>,
    encoding_len: UIntNative,
    memory_settings: MemorySettings,
    output_sink: OutputSink,
    output_sink_user_data: CPointer<Unit>,
    strict: Bool
): CPointer<Unit>
foreign func unstable_lol_html_rewriter_build_with_esi_tags(
    builder: CPointer<Unit>,
    encoding: CPointer<UInt8>,
    encoding_len: UIntNative,
    memory_settings: MemorySettings,
    output_sink: OutputSink,
    output_sink_user_data: CPointer<Unit>,
    strict: Bool
): CPointer<Unit>

// --- HTMLSelector ---
foreign func lol_html_selector_parse(selector: CPointer<UInt8>, selector_len: UIntNative): CPointer<Unit>
foreign func lol_html_selector_free(selector: CPointer<Unit>): Unit

// --- TextChunk ---
foreign func lol_html_text_chunk_content_get(chunk: CPointer<Unit>): HTMLString
foreign func lol_html_text_chunk_is_last_in_text_node(chunk: CPointer<Unit>): Bool
foreign func lol_html_text_chunk_before(chunk: CPointer<Unit>, content: CPointer<UInt8>, content_len: UIntNative, is_html: Bool): Int32
foreign func lol_html_text_chunk_after(chunk: CPointer<Unit>, content: CPointer<UInt8>, content_len: UIntNative, is_html: Bool): Int32
foreign func lol_html_text_chunk_replace(chunk: CPointer<Unit>, content: CPointer<UInt8>, content_len: UIntNative, is_html: Bool): Int32
foreign func lol_html_text_chunk_remove(chunk: CPointer<Unit>): Unit
foreign func lol_html_text_chunk_is_removed(chunk: CPointer<Unit>): Bool
foreign func lol_html_text_chunk_user_data_set(chunk: CPointer<Unit>, user_data: CPointer<Unit>): Unit
foreign func lol_html_text_chunk_user_data_get(chunk: CPointer<Unit>): CPointer<Unit>
foreign func lol_html_text_chunk_source_location_bytes(chunk: CPointer<Unit>): SourceLocationBytes

// --- Element ---
foreign func lol_html_element_get_attribute(element: CPointer<Unit>, name: CPointer<UInt8>, name_len: UIntNative): HTMLString
foreign func lol_html_element_has_attribute(element: CPointer<Unit>, name: CPointer<UInt8>, name_len: UIntNative): Int32
foreign func lol_html_element_set_attribute(element: CPointer<Unit>, name: CPointer<UInt8>, name_len: UIntNative, value: CPointer<UInt8>, value_len: UIntNative): Int32
foreign func lol_html_element_remove_attribute(element: CPointer<Unit>, name: CPointer<UInt8>, name_len: UIntNative): Int32
foreign func lol_html_element_before(element: CPointer<Unit>, content: CPointer<UInt8>, content_len: UIntNative, is_html: Bool): Int32
foreign func lol_html_element_prepend(element: CPointer<Unit>, content: CPointer<UInt8>, content_len: UIntNative, is_html: Bool): Int32
foreign func lol_html_element_append(element: CPointer<Unit>, content: CPointer<UInt8>, content_len: UIntNative, is_html: Bool): Int32
foreign func lol_html_element_after(element: CPointer<Unit>, content: CPointer<UInt8>, content_len: UIntNative, is_html: Bool): Int32
foreign func lol_html_element_set_inner_content(element: CPointer<Unit>, content: CPointer<UInt8>, content_len: UIntNative, is_html: Bool): Int32
foreign func lol_html_element_replace(element: CPointer<Unit>, content: CPointer<UInt8>, content_len: UIntNative, is_html: Bool): Int32
foreign func lol_html_element_remove(element: CPointer<Unit>): Unit
foreign func lol_html_element_remove_and_keep_content(element: CPointer<Unit>): Unit
foreign func lol_html_element_is_removed(element: CPointer<Unit>): Bool
foreign func lol_html_element_is_self_closing(element: CPointer<Unit>): Bool
foreign func lol_html_element_can_have_content(element: CPointer<Unit>): Bool
foreign func lol_html_element_user_data_set(element: CPointer<Unit>, user_data: CPointer<Unit>): Unit
foreign func lol_html_element_user_data_get(element: CPointer<Unit>): CPointer<Unit>
foreign func lol_html_element_add_end_tag_handler(element: CPointer<Unit>, end_tag_handler: CPointer<Unit>, user_data: CPointer<Unit>): Int32
foreign func lol_html_element_clear_end_tag_handlers(element: CPointer<Unit>): Unit
foreign func lol_html_element_source_location_bytes(element: CPointer<Unit>): SourceLocationBytes
foreign func lol_html_element_tag_name_get(element: CPointer<Unit>): HTMLString
foreign func lol_html_element_tag_name_set(element: CPointer<Unit>, name: CPointer<UInt8>, name_len: UIntNative): Int32
foreign func lol_html_element_namespace_uri_get(element: CPointer<Unit>): CString
foreign func lol_html_attributes_iterator_get(element: CPointer<Unit>): CPointer<Unit>

// --- EndTag ---
foreign func lol_html_end_tag_before(end_tag: CPointer<Unit>, content: CPointer<UInt8>, content_len: UIntNative, is_html: Bool): Int32
foreign func lol_html_end_tag_after(end_tag: CPointer<Unit>, content: CPointer<UInt8>, content_len: UIntNative, is_html: Bool): Int32
foreign func lol_html_end_tag_remove(end_tag: CPointer<Unit>): Unit
foreign func lol_html_end_tag_name_get(end_tag: CPointer<Unit>): HTMLString
foreign func lol_html_end_tag_name_set(end_tag: CPointer<Unit>, name: CPointer<UInt8>, name_len: UIntNative): Int32
foreign func lol_html_end_tag_source_location_bytes(end_tag: CPointer<Unit>): SourceLocationBytes

// --- Attribute ---
foreign func lol_html_attribute_name_get(attribute: CPointer<Unit>): HTMLString
foreign func lol_html_attribute_value_get(attribute: CPointer<Unit>): HTMLString
foreign func lol_html_attributes_iterator_free(iterator: CPointer<Unit>): Unit
foreign func lol_html_attributes_iterator_next(iterator: CPointer<Unit>): CPointer<Unit>

// --- Comment ---
foreign func lol_html_comment_text_get(comment: CPointer<Unit>): HTMLString
foreign func lol_html_comment_text_set(comment: CPointer<Unit>, text: CPointer<UInt8>, text_len: UIntNative): Int32
foreign func lol_html_comment_before(comment: CPointer<Unit>, content: CPointer<UInt8>, content_len: UIntNative, is_html: Bool): Int32
foreign func lol_html_comment_after(comment: CPointer<Unit>, content: CPointer<UInt8>, content_len: UIntNative, is_html: Bool): Int32
foreign func lol_html_comment_replace(comment: CPointer<Unit>, content: CPointer<UInt8>, content_len: UIntNative, is_html: Bool): Int32
foreign func lol_html_comment_remove(comment: CPointer<Unit>): Unit
foreign func lol_html_comment_is_removed(comment: CPointer<Unit>): Bool
foreign func lol_html_comment_user_data_set(comment: CPointer<Unit>, user_data: CPointer<Unit>): Unit
foreign func lol_html_comment_user_data_get(comment: CPointer<Unit>): CPointer<Unit>
foreign func lol_html_comment_source_location_bytes(comment: CPointer<Unit>): SourceLocationBytes

// --- DocEnd ---
foreign func lol_html_doc_end_append(doc_end: CPointer<Unit>, content: CPointer<UInt8>, content_len: UIntNative, is_html: Bool): Int32

// --- DocType ---
foreign func lol_html_doctype_name_get(doctype: CPointer<Unit>): HTMLString
foreign func lol_html_doctype_public_id_get(doctype: CPointer<Unit>): HTMLString
foreign func lol_html_doctype_system_id_get(doctype: CPointer<Unit>): HTMLString
foreign func lol_html_doctype_user_data_set(doctype: CPointer<Unit>, user_data: CPointer<Unit>): Unit
foreign func lol_html_doctype_user_data_get(doctype: CPointer<Unit>): CPointer<Unit>
foreign func lol_html_doctype_remove(doctype: CPointer<Unit>): Unit
foreign func lol_html_doctype_is_removed(doctype: CPointer<Unit>): Bool
foreign func lol_html_doctype_source_location_bytes(doctype: CPointer<Unit>): SourceLocationBytes

// --- HTMLString ---
foreign func lol_html_str_free(str: HTMLString): Unit
foreign func lol_html_take_last_error(...): HTMLString
