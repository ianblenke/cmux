// GDK keyval to evdev keycode mapping
// Ghostty expects evdev hardware scancodes in the keycode field.
// When using virtual input (wtype) or when GTK provides incorrect
// hardware keycodes, we fall back to this lookup table.

import CGtk4

/// Map GDK keyval to evdev keycode for ghostty
func gdkKeyvalToEvdev(_ keyval: UInt32) -> UInt32 {
    switch keyval {
    // Letters (evdev keycodes)
    case UInt32(GDK_KEY_a), UInt32(GDK_KEY_A): return 38
    case UInt32(GDK_KEY_b), UInt32(GDK_KEY_B): return 56
    case UInt32(GDK_KEY_c), UInt32(GDK_KEY_C): return 54
    case UInt32(GDK_KEY_d), UInt32(GDK_KEY_D): return 40
    case UInt32(GDK_KEY_e), UInt32(GDK_KEY_E): return 26
    case UInt32(GDK_KEY_f), UInt32(GDK_KEY_F): return 41
    case UInt32(GDK_KEY_g), UInt32(GDK_KEY_G): return 42
    case UInt32(GDK_KEY_h), UInt32(GDK_KEY_H): return 43
    case UInt32(GDK_KEY_i), UInt32(GDK_KEY_I): return 31
    case UInt32(GDK_KEY_j), UInt32(GDK_KEY_J): return 44
    case UInt32(GDK_KEY_k), UInt32(GDK_KEY_K): return 45
    case UInt32(GDK_KEY_l), UInt32(GDK_KEY_L): return 46
    case UInt32(GDK_KEY_m), UInt32(GDK_KEY_M): return 58
    case UInt32(GDK_KEY_n), UInt32(GDK_KEY_N): return 57
    case UInt32(GDK_KEY_o), UInt32(GDK_KEY_O): return 32
    case UInt32(GDK_KEY_p), UInt32(GDK_KEY_P): return 33
    case UInt32(GDK_KEY_q), UInt32(GDK_KEY_Q): return 24
    case UInt32(GDK_KEY_r), UInt32(GDK_KEY_R): return 27
    case UInt32(GDK_KEY_s), UInt32(GDK_KEY_S): return 31
    case UInt32(GDK_KEY_t), UInt32(GDK_KEY_T): return 28
    case UInt32(GDK_KEY_u), UInt32(GDK_KEY_U): return 30
    case UInt32(GDK_KEY_v), UInt32(GDK_KEY_V): return 55
    case UInt32(GDK_KEY_w), UInt32(GDK_KEY_W): return 25
    case UInt32(GDK_KEY_x), UInt32(GDK_KEY_X): return 53
    case UInt32(GDK_KEY_y), UInt32(GDK_KEY_Y): return 29
    case UInt32(GDK_KEY_z), UInt32(GDK_KEY_Z): return 52

    // Numbers
    case UInt32(GDK_KEY_0), UInt32(GDK_KEY_parenright): return 19
    case UInt32(GDK_KEY_1), UInt32(GDK_KEY_exclam): return 10
    case UInt32(GDK_KEY_2), UInt32(GDK_KEY_at): return 11
    case UInt32(GDK_KEY_3), UInt32(GDK_KEY_numbersign): return 12
    case UInt32(GDK_KEY_4), UInt32(GDK_KEY_dollar): return 13
    case UInt32(GDK_KEY_5), UInt32(GDK_KEY_percent): return 14
    case UInt32(GDK_KEY_6), UInt32(GDK_KEY_asciicircum): return 15
    case UInt32(GDK_KEY_7), UInt32(GDK_KEY_ampersand): return 16
    case UInt32(GDK_KEY_8), UInt32(GDK_KEY_asterisk): return 17
    case UInt32(GDK_KEY_9), UInt32(GDK_KEY_parenleft): return 18

    // Special keys
    case UInt32(GDK_KEY_Return), UInt32(GDK_KEY_KP_Enter): return 36
    case UInt32(GDK_KEY_Escape): return 9
    case UInt32(GDK_KEY_BackSpace): return 22
    case UInt32(GDK_KEY_Tab), UInt32(GDK_KEY_ISO_Left_Tab): return 23
    case UInt32(GDK_KEY_space): return 65
    case UInt32(GDK_KEY_Delete), UInt32(GDK_KEY_KP_Delete): return 119

    // Arrow keys
    case UInt32(GDK_KEY_Up): return 111
    case UInt32(GDK_KEY_Down): return 116
    case UInt32(GDK_KEY_Left): return 113
    case UInt32(GDK_KEY_Right): return 114

    // Navigation
    case UInt32(GDK_KEY_Home): return 110
    case UInt32(GDK_KEY_End): return 115
    case UInt32(GDK_KEY_Page_Up): return 112
    case UInt32(GDK_KEY_Page_Down): return 117
    case UInt32(GDK_KEY_Insert): return 118

    // Punctuation
    case UInt32(GDK_KEY_minus), UInt32(GDK_KEY_underscore): return 20
    case UInt32(GDK_KEY_equal), UInt32(GDK_KEY_plus): return 21
    case UInt32(GDK_KEY_bracketleft), UInt32(GDK_KEY_braceleft): return 34
    case UInt32(GDK_KEY_bracketright), UInt32(GDK_KEY_braceright): return 35
    case UInt32(GDK_KEY_backslash), UInt32(GDK_KEY_bar): return 51
    case UInt32(GDK_KEY_semicolon), UInt32(GDK_KEY_colon): return 47
    case UInt32(GDK_KEY_apostrophe), UInt32(GDK_KEY_quotedbl): return 48
    case UInt32(GDK_KEY_grave), UInt32(GDK_KEY_asciitilde): return 49
    case UInt32(GDK_KEY_comma), UInt32(GDK_KEY_less): return 59
    case UInt32(GDK_KEY_period), UInt32(GDK_KEY_greater): return 60
    case UInt32(GDK_KEY_slash), UInt32(GDK_KEY_question): return 61

    // Function keys
    case UInt32(GDK_KEY_F1): return 67
    case UInt32(GDK_KEY_F2): return 68
    case UInt32(GDK_KEY_F3): return 69
    case UInt32(GDK_KEY_F4): return 70
    case UInt32(GDK_KEY_F5): return 71
    case UInt32(GDK_KEY_F6): return 72
    case UInt32(GDK_KEY_F7): return 73
    case UInt32(GDK_KEY_F8): return 74
    case UInt32(GDK_KEY_F9): return 75
    case UInt32(GDK_KEY_F10): return 76
    case UInt32(GDK_KEY_F11): return 77
    case UInt32(GDK_KEY_F12): return 78

    // Modifiers (shouldn't produce text but need correct keycodes)
    case UInt32(GDK_KEY_Shift_L): return 50
    case UInt32(GDK_KEY_Shift_R): return 62
    case UInt32(GDK_KEY_Control_L): return 37
    case UInt32(GDK_KEY_Control_R): return 105
    case UInt32(GDK_KEY_Alt_L): return 64
    case UInt32(GDK_KEY_Alt_R): return 108
    case UInt32(GDK_KEY_Super_L): return 133
    case UInt32(GDK_KEY_Super_R): return 134

    default: return 0  // Unknown — ghostty will use text field as fallback
    }
}
