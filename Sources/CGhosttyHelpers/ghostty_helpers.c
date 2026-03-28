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

// Action callback routing
// The ghostty action callback receives structs by value which Swift can't handle.
// This C helper wraps the callback and extracts action data for Swift.

typedef struct {
    int tag;
    // Union follows — we read specific fields based on tag
} ghostty_action_s_header;

typedef struct {
    const char* title;
} ghostty_action_set_title_s;

typedef struct {
    const char* pwd;
} ghostty_action_pwd_s;

// Action tag constants
#define ACTION_RENDER 27
#define ACTION_DESKTOP_NOTIFICATION 31
#define ACTION_SET_TITLE 32
#define ACTION_PWD 34
#define ACTION_RING_BELL 49

// Swift callbacks
typedef void (*cmux_title_changed_cb)(const char* title);
typedef void (*cmux_pwd_changed_cb)(const char* pwd);
typedef void (*cmux_render_cb)(void);
typedef void (*cmux_notification_cb)(const char* title, const char* body);
typedef void (*cmux_bell_cb)(void);

static cmux_title_changed_cb g_title_cb = NULL;
static cmux_pwd_changed_cb g_pwd_cb = NULL;
static cmux_render_cb g_render_cb = NULL;
static cmux_notification_cb g_notification_cb = NULL;
static cmux_bell_cb g_bell_cb = NULL;

void cmux_set_action_callbacks(
    cmux_title_changed_cb title_cb,
    cmux_pwd_changed_cb pwd_cb,
    cmux_render_cb render_cb
) {
    g_title_cb = title_cb;
    g_pwd_cb = pwd_cb;
    g_render_cb = render_cb;
}

void cmux_set_notification_callbacks(
    cmux_notification_cb notification_cb,
    cmux_bell_cb bell_cb
) {
    g_notification_cb = notification_cb;
    g_bell_cb = bell_cb;
}

// ghostty structs we need to receive by value
typedef struct {
    int tag;
    union {
        void* surface;
    };
} ghostty_target_s;

typedef struct {
    int tag;
    int _pad;
    union {
        ghostty_action_set_title_s set_title;
        ghostty_action_pwd_s pwd;
        char _data[24];
    };
} ghostty_action_s;

// C action callback with correct struct-by-value ABI
bool cmux_ghostty_action_handler(
    void* app,
    ghostty_target_s target,
    ghostty_action_s action
) {
    int tag = action.tag;

    switch (tag) {
        case ACTION_RENDER:
            if (g_render_cb) g_render_cb();
            return true;
        case ACTION_SET_TITLE:
            if (g_title_cb && action.set_title.title)
                g_title_cb(action.set_title.title);
            return true;
        case ACTION_PWD:
            if (g_pwd_cb && action.pwd.pwd)
                g_pwd_cb(action.pwd.pwd);
            return true;
        case ACTION_DESKTOP_NOTIFICATION: {
            // Union data starts after tag(4) + pad(4) = offset 8 in the struct
            const char* title = *(const char**)((char*)&action + 8);
            const char* body = *(const char**)((char*)&action + 16);
            if (g_notification_cb)
                g_notification_cb(title ? title : "", body ? body : "");
            return true;
        }
        case ACTION_RING_BELL:
            if (g_bell_cb) g_bell_cb();
            return true;
        default:
            return false;
    }
}

// Get the action handler function pointer for storing in runtime config
void* cmux_ghostty_get_action_handler(void) {
    return (void*)cmux_ghostty_action_handler;
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

// Check GL error state (for debugging)
int cmux_check_gl_error(void) {
    // Try to call glGetError if GLAD is loaded
    typedef unsigned int GLenum;
    typedef GLenum (*glGetError_fn)(void);
    static glGetError_fn fn = NULL;
    if (!fn) {
        fn = (glGetError_fn)dlsym(NULL, "glGetError");
    }
    if (fn) {
        return (int)fn();
    }
    return -1;
}
