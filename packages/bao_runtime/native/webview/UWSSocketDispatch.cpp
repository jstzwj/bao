#include "root.h"

#include "libusockets.h"
#include "_libusockets.h"

extern "C" us_socket_t* bao_us_dispatch_open(us_socket_t*, int, char*, int);
extern "C" us_socket_t* bao_us_dispatch_data(us_socket_t*, char*, int);
extern "C" us_socket_t* bao_us_dispatch_fd(us_socket_t*, int);
extern "C" us_socket_t* bao_us_dispatch_writable(us_socket_t*);
extern "C" us_socket_t* bao_us_dispatch_close(us_socket_t*, int, void*);
extern "C" us_socket_t* bao_us_dispatch_timeout(us_socket_t*);
extern "C" us_socket_t* bao_us_dispatch_long_timeout(us_socket_t*);
extern "C" us_socket_t* bao_us_dispatch_end(us_socket_t*);
extern "C" us_socket_t* bao_us_dispatch_connect_error(us_socket_t*, int);
extern "C" us_connecting_socket_t* bao_us_dispatch_connecting_error(us_connecting_socket_t*, int);
extern "C" void bao_us_dispatch_handshake(us_socket_t*, int, struct us_bun_verify_error_t, void*);

static constexpr us_socket_vtable_t s_baoSocketDispatchVTable = {
    .on_open = bao_us_dispatch_open,
    .on_data = bao_us_dispatch_data,
    .on_fd = bao_us_dispatch_fd,
    .on_writable = bao_us_dispatch_writable,
    .on_close = bao_us_dispatch_close,
    .on_timeout = bao_us_dispatch_timeout,
    .on_long_timeout = bao_us_dispatch_long_timeout,
    .on_end = bao_us_dispatch_end,
    .on_connect_error = bao_us_dispatch_connect_error,
    .on_connecting_error = bao_us_dispatch_connecting_error,
    .on_handshake = bao_us_dispatch_handshake,
};

extern "C" const us_socket_vtable_t* bao_us_socket_dispatch_vtable()
{
    return &s_baoSocketDispatchVTable;
}
