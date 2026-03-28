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

// Read visible terminal text via ghostty_surface_read_text
// Uses the struct types from ghostty.h via dlsym
typedef struct {
    int tag;
    int coord;
    uint32_t x;
    uint32_t y;
} cmux_point_s;

typedef struct {
    cmux_point_s top_left;
    cmux_point_s bottom_right;
    bool rectangle;
} cmux_selection_s;

typedef bool (*ghostty_surface_read_text_fn)(ghostty_surface_t, cmux_selection_s, ghostty_text_s*);
static ghostty_surface_read_text_fn g_read_text = NULL;

void cmux_ghostty_resolve_read_text_fn(void* lib_handle) {
    g_read_text = dlsym(lib_handle, "ghostty_surface_read_text");
}

char* cmux_ghostty_read_surface_text(ghostty_surface_t surface) {
    if (!g_read_text || !g_free_text || !surface) return NULL;

    // Select full viewport: top-left (0,0) to bottom-right (9999,9999)
    cmux_selection_s sel = {
        .top_left = { .tag = 1, .coord = 1, .x = 0, .y = 0 },       // VIEWPORT, TOP_LEFT
        .bottom_right = { .tag = 1, .coord = 2, .x = 9999, .y = 9999 }, // VIEWPORT, BOTTOM_RIGHT
        .rectangle = false,
    };

    ghostty_text_s text = {0};
    if (!g_read_text(surface, sel, &text)) return NULL;
    if (!text.text || text.text_len == 0) {
        g_free_text(surface, &text);
        return NULL;
    }

    char* result = malloc(text.text_len + 1);
    if (result) {
        memcpy(result, text.text, text.text_len);
        result[text.text_len] = '\0';
    }
    g_free_text(surface, &text);
    return result;
}

// GL split compositor — uses FBOs to capture ghostty draws and blit to screen regions.
// All GL functions resolved via dlsym since we don't link GL directly.

#include "ghostty_helpers.h"

#define GL_FRAMEBUFFER           0x8D40
#define GL_READ_FRAMEBUFFER      0x8CA8
#define GL_DRAW_FRAMEBUFFER      0x8CA9
#define GL_COLOR_ATTACHMENT0     0x8CE0
#define GL_TEXTURE_2D            0x0DE1
#define GL_RGBA8                 0x8058
#define GL_RGBA                  0x1908
#define GL_UNSIGNED_BYTE         0x1401
#define GL_COLOR_BUFFER_BIT      0x00004000
#define GL_NEAREST               0x2600
#define GL_FRAMEBUFFER_COMPLETE  0x8CD5

typedef void (*glGenFramebuffers_fn)(int, unsigned int*);
typedef void (*glDeleteFramebuffers_fn)(int, const unsigned int*);
typedef void (*glBindFramebuffer_fn)(unsigned int, unsigned int);
typedef void (*glFramebufferTexture2D_fn)(unsigned int, unsigned int, unsigned int, unsigned int, int);
typedef unsigned int (*glCheckFramebufferStatus_fn)(unsigned int);
typedef void (*glGenTextures_fn)(int, unsigned int*);
typedef void (*glDeleteTextures_fn)(int, const unsigned int*);
typedef void (*glBindTexture_fn)(unsigned int, unsigned int);
typedef void (*glTexImage2D_fn)(unsigned int, int, int, int, int, int, unsigned int, unsigned int, const void*);
typedef void (*glTexParameteri_fn)(unsigned int, unsigned int, int);
typedef void (*glBlitFramebuffer_fn)(int,int,int,int,int,int,int,int,unsigned int,unsigned int);
typedef void (*glViewport_fn)(int, int, int, int);

static glGenFramebuffers_fn gl_GenFramebuffers;
static glDeleteFramebuffers_fn gl_DeleteFramebuffers;
static glBindFramebuffer_fn gl_BindFramebuffer;
static glFramebufferTexture2D_fn gl_FramebufferTexture2D;
static glCheckFramebufferStatus_fn gl_CheckFramebufferStatus;
static glGenTextures_fn gl_GenTextures;
static glDeleteTextures_fn gl_DeleteTextures;
static glBindTexture_fn gl_BindTexture;
static glTexImage2D_fn gl_TexImage2D;
static glTexParameteri_fn gl_TexParameteri;
static glBlitFramebuffer_fn gl_BlitFramebuffer;
static glViewport_fn gl_Viewport;

static int gl_fns_resolved = 0;

static void resolve_all_gl(void) {
    if (gl_fns_resolved) return;
    gl_GenFramebuffers = dlsym(NULL, "glGenFramebuffers");
    gl_DeleteFramebuffers = dlsym(NULL, "glDeleteFramebuffers");
    gl_BindFramebuffer = dlsym(NULL, "glBindFramebuffer");
    gl_FramebufferTexture2D = dlsym(NULL, "glFramebufferTexture2D");
    gl_CheckFramebufferStatus = dlsym(NULL, "glCheckFramebufferStatus");
    gl_GenTextures = dlsym(NULL, "glGenTextures");
    gl_DeleteTextures = dlsym(NULL, "glDeleteTextures");
    gl_BindTexture = dlsym(NULL, "glBindTexture");
    gl_TexImage2D = dlsym(NULL, "glTexImage2D");
    gl_TexParameteri = dlsym(NULL, "glTexParameteri");
    gl_BlitFramebuffer = dlsym(NULL, "glBlitFramebuffer");
    gl_Viewport = dlsym(NULL, "glViewport");
    gl_fns_resolved = 1;
}

int cmux_gl_get_draw_framebuffer(void) {
    resolve_all_gl();
    typedef void (*glGetIntegerv_fn)(unsigned int, int*);
    static glGetIntegerv_fn gl_GetIntegerv = NULL;
    if (!gl_GetIntegerv) gl_GetIntegerv = dlsym(NULL, "glGetIntegerv");
    if (!gl_GetIntegerv) return 0;
    int fbo = 0;
    gl_GetIntegerv(0x8CA6, &fbo); // GL_DRAW_FRAMEBUFFER_BINDING
    return fbo;
}

void cmux_split_init(cmux_split_compositor* comp) {
    memset(comp, 0, sizeof(*comp));
    resolve_all_gl();
    if (!gl_GenFramebuffers || !gl_GenTextures) return;
    gl_GenFramebuffers(2, comp->fbo);
    gl_GenTextures(2, comp->tex);
    comp->initialized = 1;
}

void cmux_split_destroy(cmux_split_compositor* comp) {
    if (!comp->initialized) return;
    gl_DeleteFramebuffers(2, comp->fbo);
    gl_DeleteTextures(2, comp->tex);
    memset(comp, 0, sizeof(*comp));
}

void cmux_split_resize(cmux_split_compositor* comp, int idx, int w, int h) {
    if (!comp->initialized || idx < 0 || idx > 1) return;
    if (comp->width[idx] == w && comp->height[idx] == h) return;
    comp->width[idx] = w;
    comp->height[idx] = h;

    // Allocate/resize the texture
    gl_BindTexture(GL_TEXTURE_2D, comp->tex[idx]);
    gl_TexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    gl_TexParameteri(GL_TEXTURE_2D, 0x2801, GL_NEAREST); // GL_TEXTURE_MIN_FILTER
    gl_TexParameteri(GL_TEXTURE_2D, 0x2800, GL_NEAREST); // GL_TEXTURE_MAG_FILTER
    gl_BindTexture(GL_TEXTURE_2D, 0);

    // Attach to FBO
    gl_BindFramebuffer(GL_FRAMEBUFFER, comp->fbo[idx]);
    gl_FramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, comp->tex[idx], 0);
    gl_BindFramebuffer(GL_FRAMEBUFFER, 0);
}

void cmux_split_bind(cmux_split_compositor* comp, int idx) {
    if (!comp->initialized || idx < 0 || idx > 1) return;
    gl_BindFramebuffer(GL_DRAW_FRAMEBUFFER, comp->fbo[idx]);
    if (gl_Viewport) gl_Viewport(0, 0, comp->width[idx], comp->height[idx]);
}

void cmux_split_unbind(cmux_split_compositor* comp, int default_fbo) {
    if (!comp->initialized) return;
    gl_BindFramebuffer(GL_DRAW_FRAMEBUFFER, (unsigned int)default_fbo);
}

void cmux_split_present(cmux_split_compositor* comp, int default_fbo,
                        int x0, int y0, int w0, int h0,
                        int x1, int y1, int w1, int h1) {
    if (!comp->initialized) return;

    // Blit surface 0 to screen region (x0,y0,w0,h0)
    gl_BindFramebuffer(GL_READ_FRAMEBUFFER, comp->fbo[0]);
    gl_BindFramebuffer(GL_DRAW_FRAMEBUFFER, (unsigned int)default_fbo);
    gl_BlitFramebuffer(0, 0, comp->width[0], comp->height[0],
                       x0, y0, x0 + w0, y0 + h0,
                       GL_COLOR_BUFFER_BIT, GL_NEAREST);

    // Blit surface 1 to screen region (x1,y1,w1,h1)
    gl_BindFramebuffer(GL_READ_FRAMEBUFFER, comp->fbo[1]);
    gl_BlitFramebuffer(0, 0, comp->width[1], comp->height[1],
                       x1, y1, x1 + w1, y1 + h1,
                       GL_COLOR_BUFFER_BIT, GL_NEAREST);

    gl_BindFramebuffer(GL_READ_FRAMEBUFFER, 0);
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
