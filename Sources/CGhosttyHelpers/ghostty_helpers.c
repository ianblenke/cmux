// C helper functions that call ghostty APIs with correct ABI.
// ghostty_surface_key takes ghostty_input_key_s BY VALUE (32 bytes),
// which is MEMORY class on x86_64 SysV ABI (hidden pointer).
// Swift dlopen can't match this ABI, so we provide thin wrappers
// that take pointers and forward correctly.

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
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

// Paste support — read GDK clipboard and send to ghostty surface
#include <gtk/gtk.h>

static ghostty_surface_text_fn g_paste_text_fn = NULL;
static void* g_paste_surface = NULL;

static void clipboard_text_received(GObject *source, GAsyncResult *result, gpointer user_data) {
    GdkClipboard *clipboard = GDK_CLIPBOARD(source);
    char *text = gdk_clipboard_read_text_finish(clipboard, result, NULL);
    if (text && g_paste_text_fn && g_paste_surface) {
        g_paste_text_fn(g_paste_surface, text, strlen(text));
    }
    g_free(text);
}

void cmux_ghostty_paste_from_clipboard(void* surface) {
    if (!g_surface_text || !surface) return;
    g_paste_text_fn = g_surface_text;
    g_paste_surface = surface;

    GdkDisplay *display = gdk_display_get_default();
    if (!display) return;
    GdkClipboard *clipboard = gdk_display_get_clipboard(display);
    gdk_clipboard_read_text_async(clipboard, NULL, clipboard_text_received, NULL);
}

// Selection copy support
typedef struct {
    uint32_t offset_start;
    uint32_t offset_end;
    uint32_t offset_len;
    const char* text;
    size_t text_len;
} ghostty_text_s;

typedef bool (*ghostty_surface_has_selection_fn)(ghostty_surface_t);
typedef bool (*ghostty_surface_read_selection_fn)(ghostty_surface_t, ghostty_text_s*);
typedef void (*ghostty_surface_free_text_fn)(ghostty_surface_t, ghostty_text_s*);

static ghostty_surface_has_selection_fn g_has_selection = NULL;
static ghostty_surface_read_selection_fn g_read_selection = NULL;
static ghostty_surface_free_text_fn g_free_text = NULL;

void cmux_ghostty_resolve_selection_fns(void* lib_handle) {
    g_has_selection = dlsym(lib_handle, "ghostty_surface_has_selection");
    g_read_selection = dlsym(lib_handle, "ghostty_surface_read_selection");
    g_free_text = dlsym(lib_handle, "ghostty_surface_free_text");
}

// Copy selected text. Returns a malloc'd string (caller must free), or NULL.
char* cmux_ghostty_copy_selection(ghostty_surface_t surface) {
    if (!g_has_selection || !g_read_selection || !g_free_text || !surface) return NULL;
    if (!g_has_selection(surface)) return NULL;

    ghostty_text_s text = {0};
    if (!g_read_selection(surface, &text)) return NULL;
    if (!text.text || text.text_len == 0) {
        g_free_text(surface, &text);
        return NULL;
    }

    // Copy the text since ghostty owns the buffer
    char* result = malloc(text.text_len + 1);
    if (result) {
        memcpy(result, text.text, text.text_len);
        result[text.text_len] = '\0';
    }
    g_free_text(surface, &text);
    return result;
}
