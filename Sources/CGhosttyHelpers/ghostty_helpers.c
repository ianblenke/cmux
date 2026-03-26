// C helper functions that call ghostty APIs with correct ABI.
// ghostty_surface_key takes ghostty_input_key_s BY VALUE (32 bytes),
// which is MEMORY class on x86_64 SysV ABI (hidden pointer).
// Swift dlopen can't match this ABI, so we provide thin wrappers
// that take pointers and forward correctly.

#include <stdbool.h>
#include <stdint.h>
#include <dlfcn.h>
#include <stdio.h>

// Forward declarations matching ghostty.h
typedef void* ghostty_surface_t;

typedef struct {
    int action;
    int mods;
    int consumed_mods;
    uint32_t keycode;
    const char* text;
    uint32_t unshifted_codepoint;
    bool composing;
} ghostty_input_key_s;

typedef bool (*ghostty_surface_key_fn)(ghostty_surface_t, ghostty_input_key_s);
typedef void (*ghostty_surface_text_fn)(ghostty_surface_t, const char*, size_t);

// Resolved function pointers (set by cmux_ghostty_resolve_key_fns)
static ghostty_surface_key_fn g_surface_key = NULL;
static ghostty_surface_text_fn g_surface_text = NULL;

// Resolve the key input functions from the loaded library handle
void cmux_ghostty_resolve_key_fns(void* lib_handle) {
    g_surface_key = dlsym(lib_handle, "ghostty_surface_key");
    g_surface_text = dlsym(lib_handle, "ghostty_surface_text");
}

// Call ghostty_surface_key with correct ABI (struct by value)
bool cmux_ghostty_surface_key(
    ghostty_surface_t surface,
    int action,
    int mods,
    int consumed_mods,
    uint32_t keycode,
    const char* text,
    uint32_t unshifted_codepoint,
    bool composing
) {
    if (!g_surface_key || !surface) return false;

    ghostty_input_key_s key = {
        .action = action,
        .mods = mods,
        .consumed_mods = consumed_mods,
        .keycode = keycode,
        .text = text,
        .unshifted_codepoint = unshifted_codepoint,
        .composing = composing,
    };
    return g_surface_key(surface, key);
}

// Call ghostty_surface_text with correct ABI
void cmux_ghostty_surface_text(
    ghostty_surface_t surface,
    const char* text,
    size_t len
) {
    if (!g_surface_text || !surface) return;
    g_surface_text(surface, text, len);
}
