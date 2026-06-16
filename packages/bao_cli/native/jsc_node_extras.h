/*
 * jsc_node_extras.h — Additional Node.js compatibility modules for JSC worker
 *
 * Provides:
 *   - require('zlib') stub
 *   - Buffer.compare, Buffer.isBuffer, Buffer.concat, Buffer.byteLength
 *   - Buffer.prototype.write
 *   - process.binding() stub
 *   - Extended assert: match, doesNotMatch, ifError, rejects, doesNotReject
 *   - require('node:tty')
 *   - require('timers')
 */

#ifndef JSC_NODE_EXTRAS_H
#define JSC_NODE_EXTRAS_H

#include "jsc_worker_types.h"

/*
 * Register additional Node.js compatibility APIs.
 * Call this once after register_node_compat().
 *
 * Parameters:
 *   ctx    - the JSC context
 *   global - the global object from JSContextGetGlobalObject()
 */
void register_node_extras(JSContextRef ctx, JSObjectRef global);

#endif /* JSC_NODE_EXTRAS_H */
