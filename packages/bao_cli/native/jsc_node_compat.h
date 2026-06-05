/*
 * jsc_node_compat.h — Node.js compatible API registration for JSC worker
 *
 * Provides:
 *   - global module = { exports: {} }
 *   - global exports = module.exports
 *   - global __filename / __dirname (set per-script)
 *   - process.nextTick(callback)
 *   - require() enhancement for built-in modules:
 *       "events", "util", "os", "assert"
 *   - EventEmitter constructor (via require("events"))
 */

#ifndef JSC_NODE_COMPAT_H
#define JSC_NODE_COMPAT_H

#include "jsc_worker_types.h"

/*
 * Register all Node.js compatibility APIs.
 * Call this once after the JSC global context is created,
 * after register_process() so we can add nextTick to the process object.
 *
 * Parameters:
 *   ctx    — the JSC context
 *   global — the global object from JSContextGetGlobalObject()
 */
void register_node_compat(JSContextRef ctx, JSObjectRef global);

/*
 * Set __filename and __dirname globals for the current script.
 * Call this BEFORE evaluating each script so the script can reference them.
 *
 * Parameters:
 *   ctx      — the JSC context
 *   global   — the global object
 *   filepath — the URL/filepath of the script being evaluated (may be NULL)
 */
void node_compat_set_filename(JSContextRef ctx, JSObjectRef global, const char* filepath);

#endif /* JSC_NODE_COMPAT_H */
