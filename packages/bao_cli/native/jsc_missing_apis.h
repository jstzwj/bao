/*
 * jsc_missing_apis.h — Missing global APIs and Bun object extensions
 *
 * Provides:
 *   Bun.wrapAnsi(text, width)
 *   SharedArrayBuffer constructor
 *   Bun.Cookie / Bun.Cookie.parse
 *   Bun.randomUUIDv7()
 *   Markdown.html()
 *   HTMLRewriter constructor stub
 *   MessageEvent constructor
 *   atob() / btoa()
 *   Bun.file() / Bun.spawnSync() stubs
 *   MessageChannel constructor
 *   process.binding() stub
 */

#ifndef JSC_MISSING_APIS_H
#define JSC_MISSING_APIS_H

#include "jsc_worker_types.h"

/*
 * Register all missing APIs on the global object and Bun object.
 * Call this once after the JSC global context is created,
 * after register_bun() so the Bun object already exists.
 *
 * Parameters:
 *   ctx    -- the JSC context
 *   global -- the global object from JSContextGetGlobalObject()
 */
void register_missing_apis(JSContextRef ctx, JSObjectRef global);

#endif /* JSC_MISSING_APIS_H */
