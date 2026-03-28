#pragma once
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

void cmux_ghostty_resolve_key_fns(void* lib_handle);

// Action callback routing
typedef void (*cmux_title_changed_cb)(const char* title);
typedef void (*cmux_pwd_changed_cb)(const char* pwd);
typedef void (*cmux_render_cb)(void);

void cmux_set_action_callbacks(
    cmux_title_changed_cb title_cb,
    cmux_pwd_changed_cb pwd_cb,
    cmux_render_cb render_cb
);

// Notification callbacks
typedef void (*cmux_notification_cb)(const char* title, const char* body);
typedef void (*cmux_bell_cb)(void);
void cmux_set_notification_callbacks(cmux_notification_cb, cmux_bell_cb);

// Get the action handler function pointer (correct ABI for ghostty)
void* cmux_ghostty_get_action_handler(void);

bool cmux_ghostty_surface_key(
    void* surface,
    int action,
    int mods,
    int consumed_mods,
    uint32_t keycode,
    const char* text,
    uint32_t unshifted_codepoint,
    bool composing
);

void cmux_ghostty_surface_text(
    void* surface,
    const char* text,
    size_t len
);

// Paste from GDK clipboard into ghostty surface
void cmux_ghostty_paste_from_clipboard(void* surface);

// Selection copy
void cmux_ghostty_resolve_selection_fns(void* lib_handle);
// Returns malloc'd string (caller must free), or NULL if no selection
char* cmux_ghostty_copy_selection(void* surface);

// Terminal text reading
void cmux_ghostty_resolve_read_text_fn(void* lib_handle);
// Returns malloc'd string of visible terminal text (caller must free), or NULL
char* cmux_ghostty_read_surface_text(void* surface);

// Get the currently bound draw framebuffer (needed for GtkGLArea)
int cmux_gl_get_draw_framebuffer(void);

// GL split compositor — captures ghostty surface_draw output into FBOs
// then blits them to the correct screen regions.
typedef struct {
    unsigned int fbo[2];     // Framebuffer objects
    unsigned int tex[2];     // Color textures
    int width[2], height[2]; // Surface sizes (pixels)
    int initialized;
} cmux_split_compositor;

void cmux_split_init(cmux_split_compositor* comp);
void cmux_split_destroy(cmux_split_compositor* comp);
// Resize FBO i to the given pixel dimensions
void cmux_split_resize(cmux_split_compositor* comp, int idx, int w, int h);
// Bind FBO i as the draw target (call before ghostty surface_draw)
void cmux_split_bind(cmux_split_compositor* comp, int idx);
// Unbind FBO (restore default framebuffer)
void cmux_split_unbind(cmux_split_compositor* comp, int default_fbo);
// Blit both FBOs to the default framebuffer at the given screen regions
void cmux_split_present(cmux_split_compositor* comp, int default_fbo,
                        int x0, int y0, int w0, int h0,
                        int x1, int y1, int w1, int h1);
