// bao_native_stubs.c
// Auto-generated no-op stubs for all uws_*, us_*, and misc symbols
// Real implementations to be provided by native library integration later
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <time.h>
#include <sys/socket.h>
#include <sys/sendfile.h>
#include <arpa/inet.h>
#include <netdb.h>

#ifdef __cplusplus
extern "C" {
#endif

// ========================================================================
// No-op stubs for uws_* and us_* symbols
// ========================================================================

void us_connecting_socket_close() { }
void* us_connecting_socket_ext() { return (void*)0; }
int us_connecting_socket_get_error() { return 0; }
void* us_connecting_socket_get_loop() { return (void*)0; }
void* us_connecting_socket_get_native_handle() { return (void*)0; }
void* us_connecting_socket_group() { return (void*)0; }
int us_connecting_socket_is_closed() { return 0; }
int us_connecting_socket_is_shut_down() { return 0; }
void* us_connecting_socket_kind() { return (void*)0; }
void us_connecting_socket_long_timeout() { }
void us_connecting_socket_shutdown() { }
void us_connecting_socket_shutdown_read() { }
void us_connecting_socket_timeout() { }
void* us_create_timer() { return (void*)0; }
void* us_create_udp_socket() { return (void*)0; }
void us_internal_free_closed_sockets() { }
int us_listen_socket_add_server_name() { return 0; }
void us_listen_socket_close() { }
void* us_listen_socket_ext() { return (void*)0; }
void* us_listen_socket_find_server_name_userdata() { return (void*)0; }
int us_listen_socket_get_fd() { return 0; }
void* us_listen_socket_group() { return (void*)0; }
void us_listen_socket_on_server_name() { }
void us_listen_socket_remove_server_name() { }
int us_loop_close_all_groups() { return 0; }
void us_loop_free() { }
int64_t us_loop_iteration_number() { return 0; }
void us_loop_pump() { }
void us_loop_run() { }
void us_loop_run_bun_tick() { }
void us_quic_global_init() { }
void us_quic_loop_flush_if_pending() { }
void* us_socket_adopt() { return (void*)0; }
void* us_socket_adopt_tls() { return (void*)0; }
void* us_socket_close() { return (void*)0; }
void* us_socket_ext() { return (void*)0; }
void us_socket_flush() { }
void* us_socket_from_fd() { return (void*)0; }
int us_socket_get_error() { return 0; }
int us_socket_get_fd() { return 0; }
void* us_socket_get_native_handle() { return (void*)0; }
void* us_socket_group() { return (void*)0; }
void us_socket_group_close_all() { }
void* us_socket_group_connect() { return (void*)0; }
void* us_socket_group_connect_unix() { return (void*)0; }
void us_socket_group_deinit() { }
void* us_socket_group_ext() { return (void*)0; }
void us_socket_group_init() { }
void* us_socket_group_listen() { return (void*)0; }
void* us_socket_group_listen_unix() { return (void*)0; }
void* us_socket_group_loop() { return (void*)0; }
void* us_socket_group_next() { return (void*)0; }
int us_socket_ipc_write_fd() { return 0; }
int us_socket_is_closed() { return 0; }
int us_socket_is_established() { return 0; }
int us_socket_is_shut_down() { return 0; }
int us_socket_is_tls() { return 0; }
int us_socket_keepalive() { return 0; }
void* us_socket_kind() { return (void*)0; }
void us_socket_local_address() { }
int us_socket_local_port() { return 0; }
void us_socket_long_timeout() { }
void us_socket_mark_needs_more_not_ssl() { }
void us_socket_nodelay() { }
void* us_socket_open() { return (void*)0; }
void* us_socket_pair() { return (void*)0; }
void us_socket_pause() { }
int us_socket_raw_write() { return 0; }
void us_socket_remote_address() { }
int us_socket_remote_port() { return 0; }
void us_socket_resume() { }
void us_socket_sendfile_needs_more() { }
void us_socket_set_kind() { }
void us_socket_set_ssl_raw_tap() { }
void us_socket_shutdown() { }
void us_socket_shutdown_read() { }
void us_socket_start_tls_handshake() { }
void us_socket_timeout() { }
void* us_socket_verify_error() { return (void*)0; }
int us_socket_write() { return 0; }
int us_socket_write2() { return 0; }
int64_t us_ssl_ctx_live_count() { return 0; }
void us_timer_close() { }
void* us_timer_ext() { return (void*)0; }
void us_timer_set() { }
void* us_udp_packet_buffer_payload() { return (void*)0; }
int us_udp_packet_buffer_payload_length() { return 0; }
void* us_udp_packet_buffer_peer() { return (void*)0; }
int us_udp_packet_buffer_truncated() { return 0; }
int us_udp_socket_bind() { return 0; }
void us_udp_socket_bound_ip() { }
int us_udp_socket_bound_port() { return 0; }
void us_udp_socket_close() { }
int us_udp_socket_connect() { return 0; }
int us_udp_socket_disconnect() { return 0; }
void us_udp_socket_remote_ip() { }
int us_udp_socket_send() { return 0; }
int us_udp_socket_set_broadcast() { return 0; }
int us_udp_socket_set_membership() { return 0; }
int us_udp_socket_set_multicast_interface() { return 0; }
int us_udp_socket_set_multicast_loopback() { return 0; }
int us_udp_socket_set_source_specific_membership() { return 0; }
int us_udp_socket_set_ttl_multicast() { return 0; }
int us_udp_socket_set_ttl_unicast() { return 0; }
void* us_udp_socket_user() { return (void*)0; }
void us_wakeup_loop() { }
void uws_add_server_name() { }
int uws_add_server_name_with_options() { return 0; }
void uws_app_any() { }
void uws_app_clear_routes() { }
void uws_app_close() { }
void uws_app_close_idle() { }
void uws_app_connect() { }
void uws_app_delete() { }
void uws_app_destroy() { }
void uws_app_domain() { }
void uws_app_get() { }
void uws_app_head() { }
void uws_app_listen() { }
void uws_app_listen_domain_with_options() { }
void uws_app_listen_with_config() { }
void uws_app_options() { }
void uws_app_patch() { }
void uws_app_post() { }
void uws_app_put() { }
void uws_app_run() { }
void uws_app_set_flags() { }
void uws_app_set_max_http_header_size() { }
void uws_app_set_on_clienterror() { }
void uws_app_trace() { }
int uws_constructor_failed() { return 0; }
void* uws_create_app() { return (void*)0; }
void uws_filter() { }
void* uws_get_loop() { return (void*)0; }
void* uws_get_native_handle() { return (void*)0; }
int uws_h3_app_add_server_name() { return 0; }
void uws_h3_app_any() { }
void uws_h3_app_clear_routes() { }
void uws_h3_app_close() { }
void uws_h3_app_delete() { }
void uws_h3_app_destroy() { }
void uws_h3_app_get() { }
void uws_h3_app_head() { }
void uws_h3_app_listen_with_config() { }
void uws_h3_app_options() { }
void uws_h3_app_patch() { }
void uws_h3_app_post() { }
void uws_h3_app_put() { }
void* uws_h3_create_app() { return (void*)0; }
void uws_h3_listen_socket_close() { }
int uws_h3_listen_socket_local_address() { return 0; }
int uws_h3_listen_socket_port() { return 0; }
int uws_h3_req_get_yield() { return 0; }
void uws_h3_req_set_yield() { }
void uws_h3_res_clear_on_writable() { }
void uws_h3_res_end() { }
void uws_h3_res_end_sendfile() { }
void uws_h3_res_end_stream() { }
void uws_h3_res_end_without_body() { }
void uws_h3_res_flush_headers() { }
void uws_h3_res_force_close() { }
void* uws_h3_res_get_buffered_amount() { return (void*)0; }
void* uws_h3_res_get_socket_data() { return (void*)0; }
void* uws_h3_res_get_write_offset() { return (void*)0; }
int uws_h3_res_has_responded() { return 0; }
void uws_h3_res_mark_wrote_content_length_header() { }
void uws_h3_res_on_aborted() { }
void uws_h3_res_on_data() { }
void uws_h3_res_on_timeout() { }
void uws_h3_res_override_write_offset() { }
void uws_h3_res_pause() { }
void uws_h3_res_reset_timeout() { }
void uws_h3_res_resume() { }
void uws_h3_res_timeout() { }
int uws_h3_res_try_end() { return 0; }
int uws_h3_res_write() { return 0; }
void uws_h3_res_write_continue() { }
void uws_h3_res_write_header() { }
void uws_h3_res_write_header_int() { }
void uws_h3_res_write_mark() { }
void uws_h3_res_write_status() { }
void uws_loop_date_header_timer_update() { }
void uws_missing_server_name() { }
uint32_t uws_num_subscribers() { return 0; }
int uws_publish() { return 0; }
void uws_remove_server_name() { }
int uws_req_get_yield() { return 0; }
int uws_req_is_ancient() { return 0; }
void uws_req_set_yield() { }
void uws_res_clear_corked_socket() { }
void uws_res_clear_on_writable() { }
void uws_res_end() { }
void uws_res_end_sendfile() { }
void uws_res_end_stream() { }
void uws_res_end_without_body() { }
void uws_res_flush_headers() { }
void* uws_res_get_buffered_amount() { return (void*)0; }
void* uws_res_get_native_handle() { return (void*)0; }
void* uws_res_get_socket_data() { return (void*)0; }
void* uws_res_get_write_offset() { return (void*)0; }
int uws_res_has_responded() { return 0; }
int uws_res_is_connect_request() { return 0; }
int uws_res_is_corked() { return 0; }
void uws_res_mark_wrote_content_length_header() { }
void uws_res_on_aborted() { }
void uws_res_on_data() { }
void uws_res_on_timeout() { }
void uws_res_override_write_offset() { }
void uws_res_pause() { }
void uws_res_prepare_for_sendfile() { }
void uws_res_reset_timeout() { }
void uws_res_resume() { }
void uws_res_timeout() { }
int uws_res_try_end() { return 0; }
void uws_res_uncork() { }
void* uws_res_upgrade() { return (void*)0; }
int uws_res_write() { return 0; }
void uws_res_write_continue() { }
void uws_res_write_header() { }
void uws_res_write_header_int() { }
void uws_res_write_mark() { }
void uws_res_write_status() { }
void uws_ws_close() { }
void uws_ws_cork() { }
void uws_ws_end() { }
size_t uws_ws_get_buffered_amount() { return 0; }
void* uws_ws_get_user_data() { return (void*)0; }
int uws_ws_is_subscribed() { return 0; }
size_t uws_ws_memory_cost() { return 0; }
int uws_ws_publish() { return 0; }
int uws_ws_publish_with_options() { return 0; }
int uws_ws_subscribe() { return 0; }
int uws_ws_unsubscribe() { return 0; }

// ========================================================================
// ssl_* socket wrappers (real implementations)
// ========================================================================

int ssl_socket(int domain, int type_, int protocol) { return socket(domain, type_, protocol); }
int ssl_connect(int sockfd, void *addr, uint32_t addrlen) { return connect(sockfd, (const struct sockaddr *)addr, (socklen_t)addrlen); }
uint16_t ssl_htons(uint16_t hostshort) { return htons(hostshort); }
int ssl_inet_pton(int af, const char *src, void *dst) { return inet_pton(af, src, dst); }
int ssl_getaddrinfo(const char *name, const char *service, void *hints, void **result) { return getaddrinfo(name, service, (const struct addrinfo *)hints, (struct addrinfo **)result); }
void ssl_freeaddrinfo(void *addr) { freeaddrinfo((struct addrinfo *)addr); }

// ========================================================================
// sysSendFile wrapper
// ========================================================================

int64_t sysSendFile(int64_t outFd, int64_t inFd, int64_t offset, int64_t count) {
    off_t off = (off_t)offset;
    return (int64_t)sendfile((int)outFd, (int)inFd, &off, (size_t)count);
}

// ========================================================================
// clock_gettime wrappers
// ========================================================================

static int wrap_clock_gettime(int clockid, int64_t *tp) {
    struct timespec ts;
    int r = clock_gettime((clockid_t)clockid, &ts);
    if (r == 0 && tp) { tp[0] = (int64_t)ts.tv_sec; tp[1] = (int64_t)ts.tv_nsec; }
    return r;
}

int client_clock_gettime(int clockid, int64_t *tp) { return wrap_clock_gettime(clockid, tp); }
int multipart_clock_gettime(int clockid, int64_t *tp) { return wrap_clock_gettime(clockid, tp); }
int proxy_clock_gettime(int clockid, int64_t *tp) { return wrap_clock_gettime(clockid, tp); }
int server_clock_gettime(int clockid, int64_t *tp) { return wrap_clock_gettime(clockid, tp); }
int websocket_clock_gettime(int clockid, int64_t *tp) { return wrap_clock_gettime(clockid, tp); }

// ========================================================================
// ares_inet_ntop fallback
// ========================================================================

const char *ares_inet_ntop(int af, const char *src, char *dst, size_t size) { return inet_ntop(af, src, dst, size); }

#ifdef __cplusplus
}
#endif
