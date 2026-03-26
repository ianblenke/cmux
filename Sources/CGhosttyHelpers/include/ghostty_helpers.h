#pragma once
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

void cmux_ghostty_resolve_key_fns(void* lib_handle);

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
